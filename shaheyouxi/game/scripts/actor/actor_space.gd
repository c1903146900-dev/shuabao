extends RefCounted
## Native query adapter for the materialized technical room only.
## Peer CCD is actor_geometry; these environment queries exclude peer proxy bodies.
## This adapter does not generate missing terrain or interpret a ground row as air.
const Address = preload("res://scripts/world/spatial_address.gd")
const CircleBoundary = preload("res://scripts/actor/actor_circle_boundary.gd")
const Geometry = preload("res://scripts/actor/actor_geometry.gd")
const PeerReconnect = preload("res://scripts/actor/actor_peer_reconnect.gd")
const MAX_TICKET_GENERATION := 9007199254740991
var _spaces: Dictionary = {}
var _actors: Dictionary = {}
var _bodies: Array[RID] = []
var _shapes: Array[RID] = []
var _radius: float = 0.0
var _half: float = 0.0
var _pending_positions: Dictionary = {}
var _pending_activation: Dictionary = {}
var _pending_transfer: Dictionary = {}
var _rollback_transfer: Dictionary = {}
var _native_frame: Dictionary = {}
var _native_frame_generation: int = 0
var _frame_write_scope: bool = false
var _ticket_generation: int = 0
var _last_target_submit_frame: int = -1
var _ticket_owner_id: int = get_instance_id()
const MAX_ENDPOINT_REFINEMENTS := 48 # Bounded numerical certification, not gameplay tuning.
var last_error: String = ""

func configure(world: RefCounted, inputs: RefCounted) -> bool:
	if not _spaces.is_empty() or world == null or inputs == null or not world.ready or not inputs.ready:
		return _reject("SPACE_ALREADY_CONFIGURED_OR_INPUTS_INVALID")
	if not _invalidate_tickets():
		return _reject("NATIVE_TICKET_GENERATION_EXHAUSTED")
	var component: Dictionary = world.public_component()
	var checked: Dictionary = world.validate_component(component, component.get("layout", {}).get("world_id", ""))
	if not checked.get("ok", false):
		return _reject("UNVALIDATED_WORLD_COMPONENT")
	_half = inputs.parameter("actor_diameter_cells") / 2.0
	_radius = float(component["layout"]["body"]["radius_cells"])
	if not CircleBoundary.parameters(_radius, _half).get("ok", false):
		return _reject("INVALID_WORLD_OR_ACTOR_RADIUS")
	# Precheck the complete supported geometry before allocating native resources.
	for instance in component["prefab_instances"]:
		for object in instance["objects"]:
			if object["blocking"] and object["content_namespace"] != "technical_fixture":
				return _reject("FORMAL_ENVIRONMENT_COLLISION_NOT_IMPLEMENTED")
	for instance in component["prefab_instances"]:
		for layer in instance["layers"]:
			var identity: Dictionary = layer["address"]
			var key := Address.key(identity)
			if not _spaces.has(key):
				var space := PhysicsServer2D.space_create()
				PhysicsServer2D.space_set_active(space, true)
				_spaces[key] = {"rid": space, "identity": identity.duplicate(true), "materialized_bounds": []}
			# Underground H0 does not prove default rock was carved. Keep unknown
			# until generated terrain occupancy is explicitly materialized.
			if identity["map_kind"] == "surface":
				_spaces[key]["materialized_bounds"].append(layer["bounds"].duplicate())
		for object in instance["objects"]:
			if object["blocking"]:
				var rect: Array = object["rect"]
				_add_static_rectangle(_spaces[Address.key(object["layer"])]["rid"], Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3])))
	return true

func add_actor(actor_id: String, layer: Dictionary, position: Vector2) -> bool:
	if not _invalidate_tickets():
		return _reject("NATIVE_TICKET_GENERATION_EXHAUSTED")
	var placement_error := _actor_placement_error(actor_id, layer, position)
	if not placement_error.is_empty():
		return _reject(placement_error)
	var key := Address.key(layer)
	var circle := PhysicsServer2D.circle_shape_create()
	PhysicsServer2D.shape_set_data(circle, _half)
	_shapes.append(circle)
	var square := PhysicsServer2D.rectangle_shape_create()
	PhysicsServer2D.shape_set_data(square, Vector2.ONE * _half)
	_shapes.append(square)
	var environment_body := _add_kinematic(_spaces[key]["rid"], circle, position, 2, 1)
	var peer_body := _add_kinematic(_spaces[key]["rid"], square, position, 4, 0)
	_actors[actor_id] = {"layer_key": key, "position": position, "environment_body": environment_body, "peer_body": peer_body, "circle": circle, "square": square}
	return true

func remove_actor(actor_id: String) -> void:
	if not _actors.has(actor_id):
		return
	_invalidate_tickets() # Cleanup must still work at exhausted generation.
	var actor: Dictionary = _actors[actor_id]
	for key in ["environment_body", "peer_body"]:
		_bodies.erase(actor[key])
		PhysicsServer2D.free_rid(actor[key])
	for key in ["circle", "square"]:
		_shapes.erase(actor[key])
		PhysicsServer2D.free_rid(actor[key])
	_actors.erase(actor_id)

func query_environment_motion(actor_id: String, start: Vector2, motion: Vector2) -> Dictionary:
	if not _actors.has(actor_id) or not full_environment_body_inside(start) or not motion.is_finite():
		return {"ok": false, "code": "INVALID_MOTION_QUERY"}
	if not full_environment_body_inside(start + motion):
		return {"ok": false, "code": "MAP_BOUNDARY_CLIP_REQUIRED"}
	var actor: Dictionary = _actors[actor_id]
	if not _covered(actor["layer_key"], start) or not _covered(actor["layer_key"], start + motion):
		return {"ok": false, "code": "UNMATERIALIZED_COLLISION_REGION"}
	if not _covered_sweep(actor["layer_key"], start, motion):
		return {"ok": false, "code": "UNCERTIFIED_SWEPT_COLLISION_REGION"}
	# Zero-motion body_test_motion need not report recovery overlap. Check the
	# actual shape explicitly, including every virtual trajectory start.
	if not environment_clear(_spaces[actor["layer_key"]]["identity"], start):
		return {"ok": false, "code": "ENVIRONMENT_START_BLOCKED_OR_NOT_READY"}
	var parameters := PhysicsTestMotionParameters2D.new()
	parameters.from = Transform2D(0.0, start)
	parameters.motion = motion
	parameters.margin = 0.001
	var result := PhysicsTestMotionResult2D.new()
	var hit := PhysicsServer2D.body_test_motion(actor["environment_body"], parameters, result)
	var fraction: float = result.get_collision_safe_fraction() if hit else 1.0
	if not is_finite(fraction) or fraction < 0.0 or fraction > 1.0:
		return {"ok":false,"code":"NATIVE_MOTION_FRACTION_INVALID"}
	var identity: Dictionary = _spaces[actor["layer_key"]]["identity"]
	# Native short sweeps may report no hit even while their endpoint overlaps.
	# Never turn that absence into permission or invent a contact normal.
	if not _motion_endpoint_clear(identity,start,motion,fraction):
		if not hit:
			return {"ok":false,"code":"ENVIRONMENT_END_BLOCKED_WITHOUT_NATIVE_CONTACT"}
		# Preserve the actual native contact normal. Only reduce the original
		# prefix; no pushout, radius epsilon, extra motion or tangent cancellation.
		var lower := 0.0
		var upper := fraction
		for refinement in range(MAX_ENDPOINT_REFINEMENTS):
			var middle := lower + (upper-lower)*0.5
			if middle <= lower or middle >= upper:
				break
			if _motion_endpoint_clear(identity,start,motion,middle):
				lower = middle
			else:
				upper = middle
		fraction = lower
		# If even the initial certified position is no longer queryable, stop.
		if not _motion_endpoint_clear(identity,start,motion,fraction):
			return {"ok":false,"code":"ENVIRONMENT_PREFIX_UNCERTIFIED"}
	return {"ok": true, "layer_key": actor["layer_key"], "hit": hit, "fraction": fraction, "normal": result.get_collision_normal() if hit else Vector2.ZERO}

func _motion_endpoint_clear(layer: Dictionary, start: Vector2, motion: Vector2, fraction: float) -> bool:
	# Certify both native Vector2 multiply/add and the solver's scalar-double
	# prefix construction. They can round to adjacent floats near a wall.
	var native_endpoint: Vector2 = start + motion * fraction
	var scalar_endpoint := Vector2(float(start.x)+float(motion.x)*fraction,float(start.y)+float(motion.y)*fraction)
	return environment_clear(layer,native_endpoint) and (scalar_endpoint == native_endpoint or environment_clear(layer,scalar_endpoint))

func full_environment_body_inside(position: Vector2) -> bool:
	# Environment body retains006's circle; only peer geometry is mandated AABB.
	var checked: Dictionary = CircleBoundary.contains(position, _radius, _half)
	return checked.get("ok", false) and checked.get("inside", false)

func circle_boundaries() -> Dictionary:
	# Trusted server geometry only; detached scalars keyed by full logical layer.
	# Returning an empty map after disposal never disables a caller's constraints.
	var result: Dictionary = {}
	for key in _spaces:
		result[key] = {"map_radius": _radius, "body_radius": _half}
	return result

func environment_clear(layer: Dictionary, position: Vector2) -> bool:
	var key := Address.key(layer)
	if not _spaces.has(key) or not full_environment_body_inside(position) or not _covered(key, position):
		return false
	var state := PhysicsServer2D.space_get_direct_state(_spaces[key]["rid"])
	if state == null:
		return false
	var shape := CircleShape2D.new()
	shape.radius = _half
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, position)
	query.collision_mask = 1
	return state.intersect_shape(query, 1).is_empty()

func _covered(key: String, position: Vector2) -> bool:
	# Query support boundary, not a newly invented gameplay wall. Unknown fails closed.
	for box in _spaces[key]["materialized_bounds"]:
		if position.x - _half >= box[0] and position.y - _half >= box[1] and position.x + _half <= box[0] + box[2] and position.y + _half <= box[1] + box[3]:
			return true
	return false

func _covered_sweep(key: String, start: Vector2, motion: Vector2) -> bool:
	# Endpoints in different known rectangles do not certify the space between.
	# Conservatively certify the whole circle's swept AABB inside ONE region.
	# This is a query-support certificate, not a new wall or a claim about unions.
	var end_x := float(start.x) + float(motion.x)
	var end_y := float(start.y) + float(motion.y)
	for box in _spaces[key]["materialized_bounds"]:
		if minf(float(start.x), end_x) - _half >= float(box[0]) and maxf(float(start.x), end_x) + _half <= float(box[0]) + float(box[2]) and minf(float(start.y), end_y) - _half >= float(box[1]) and maxf(float(start.y), end_y) + _half <= float(box[1]) + float(box[3]):
			return true
	return false

func _add_kinematic(space: RID, shape: RID, position: Vector2, layer: int, mask: int) -> RID:
	var body := PhysicsServer2D.body_create()
	_bodies.append(body)
	PhysicsServer2D.body_set_mode(body, PhysicsServer2D.BODY_MODE_KINEMATIC)
	PhysicsServer2D.body_set_collision_layer(body, layer)
	PhysicsServer2D.body_set_collision_mask(body, mask)
	PhysicsServer2D.body_add_shape(body, shape)
	PhysicsServer2D.body_set_state(body, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, position))
	PhysicsServer2D.body_set_space(body, space)
	return body

func _add_static_rectangle(space: RID, rect: Rect2) -> void:
	var shape := PhysicsServer2D.rectangle_shape_create()
	PhysicsServer2D.shape_set_data(shape, rect.size / 2.0)
	_shapes.append(shape)
	var body := _add_kinematic(space, shape, rect.get_center(), 1, 0)
	PhysicsServer2D.body_set_mode(body, PhysicsServer2D.BODY_MODE_STATIC)

func dispose() -> void:
	_invalidate_tickets() # Do not block RID release on generation exhaustion.
	for body in _bodies:
		PhysicsServer2D.free_rid(body)
	for shape in _shapes:
		PhysicsServer2D.free_rid(shape)
	for space in _spaces.values():
		PhysicsServer2D.free_rid(space["rid"])
	_bodies.clear()
	_shapes.clear()
	if _spaces.is_read_only():
		_spaces = {} # Drop an opt-in frozen root; never clear through old aliases.
	else:
		_spaces.clear()
	_actors.clear()
	_radius = 0.0
	_half = 0.0
	_last_target_submit_frame = -1

func _reject(code: String) -> bool:
	last_error = code
	return false

func actor_view(actor_id: String) -> Dictionary:
	if not _actors.has(actor_id):
		return {}
	return {"layer_key": _actors[actor_id]["layer_key"], "position": _actors[actor_id]["position"], "half_extent": _half}

func prepare_positions(preview: Dictionary, resolved: Variant) -> Dictionary:
	# Read-only physical validation before the model's all-candidate commit.
	if not _invalidate_tickets():
		return {"ok": false, "code": "NATIVE_TICKET_GENERATION_EXHAUSTED"}
	if not preview.get("actors") is Dictionary or not resolved is Dictionary or preview["actors"].size() != _actors.size() or resolved.size() != _actors.size():
		return {"ok": false, "code": "NATIVE_ACTOR_SET_MISMATCH"}
	var candidates: Dictionary = {}
	for actor_id in _actors:
		if not preview["actors"].has(actor_id) or not resolved.has(actor_id):
			return {"ok": false, "code": "NATIVE_ACTOR_SET_MISMATCH"}
		var source: Variant = preview["actors"][actor_id]
		var target: Variant = resolved[actor_id]
		var current: Dictionary = _actors[actor_id]
		if not source is Dictionary or not target is Dictionary or not source.get("layer") is Dictionary or not target.get("layer") is Dictionary:
			return {"ok": false, "code": "NATIVE_POSITION_FIELDS_INVALID"}
		if source.get("position") != current["position"] or Address.key(source["layer"]) != current["layer_key"] or Address.key(target["layer"]) != current["layer_key"]:
			return {"ok": false, "code": "NATIVE_PREVIEW_STALE_OR_LAYER_CHANGED"}
		if not target.get("position") is Vector2 or not environment_clear(target["layer"], target["position"]):
			return {"ok": false, "code": "NATIVE_TARGET_BLOCKED_OR_UNKNOWN"}
		candidates[actor_id] = {"layer_key": current["layer_key"], "position": target["position"]}
	var ids := candidates.keys()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a: Dictionary = candidates[ids[i]]
			var b: Dictionary = candidates[ids[j]]
			if a["layer_key"] == b["layer_key"] and Geometry.overlaps(a["position"], b["position"], _half, _half):
				return {"ok": false, "code": "NATIVE_TARGET_PEER_OVERLAP"}
	_pending_positions = {"owner_id": _ticket_owner_id, "generation": _ticket_generation, "before": _positions_snapshot(), "after": candidates}
	return {"ok": true, "ticket": _pending_positions.duplicate(true)}

func commit_prepared_positions(ticket: Dictionary) -> bool:
	if _pending_positions.is_empty() or ticket != _pending_positions or ticket["before"] != _positions_snapshot():
		return false
	# No await, scene mutation, callback or failure-prone file operation in this loop.
	for actor_id in _pending_positions["after"]:
		var position: Vector2 = _pending_positions["after"][actor_id]["position"]
		var actor: Dictionary = _actors[actor_id]
		for key in ["environment_body", "peer_body"]:
			PhysicsServer2D.body_set_state(actor[key], PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, position))
		actor["position"] = position
	_last_target_submit_frame = Engine.get_physics_frames()
	_invalidate_tickets()
	return true

func commit_actor_preview(model: RefCounted, preview: Dictionary, resolved: Dictionary) -> Dictionary:
	var staged := prepare_positions(preview, resolved)
	if not staged["ok"]:
		return staged
	var committed: Dictionary = model.commit_preview(preview, resolved)
	if not committed["ok"]:
		_pending_positions.clear()
		return committed
	if not commit_prepared_positions(staged["ticket"]):
		# Defensive impossible-under-this-synchronous-owner path. Network owner MUST
		# stop without broadcast/save and dispose all RIDs; never keep playing.
		return {"ok": false, "code": "NATIVE_COMMIT_AFTER_MODEL_FAILED", "fatal": true}
	return {"ok": true, "clock": committed["clock"], "native_target_submitted": true}

func validate_applied_actor_targets() -> Dictionary:
	# Kinematic body_set_state queues a target until the backend physics step.
	# Only one state-advancing controller tick may submit targets per physics frame.
	# The next owner physics callback must verify application BEFORE querying again.
	if not _actors.is_empty() and _last_target_submit_frame >= 0 and Engine.get_physics_frames() <= _last_target_submit_frame:
		return {"ok": false, "code": "NATIVE_TARGET_PHYSICS_STEP_PENDING"}
	return _validate_actual_actor_targets()

func _validate_actual_actor_targets() -> Dictionary:
	for actor in _actors.values():
		if not _spaces.has(actor["layer_key"]):
			return {"ok": false, "code": "NATIVE_APPLIED_SPACE_MISMATCH"}
		for key in ["environment_body", "peer_body"]:
			if PhysicsServer2D.body_get_space(actor[key]) != _spaces[actor["layer_key"]]["rid"]:
				return {"ok": false, "code": "NATIVE_APPLIED_SPACE_MISMATCH"}
			var transform: Transform2D = PhysicsServer2D.body_get_state(actor[key], PhysicsServer2D.BODY_STATE_TRANSFORM)
			if transform != Transform2D(0.0, actor["position"]):
				return {"ok": false, "code": "NATIVE_APPLIED_TARGET_MISMATCH"}
	return {"ok": true}

func _positions_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for actor_id in _actors:
		result[actor_id] = {"layer_key": _actors[actor_id]["layer_key"], "position": _actors[actor_id]["position"]}
	return result

func active_actor_ids() -> Array:
	var ids := _actors.keys()
	ids.sort()
	return ids

func _invalidate_tickets() -> bool:
	if not _frame_write_scope:
		_native_frame.clear()
	_pending_positions.clear()
	_pending_activation.clear()
	_pending_transfer.clear()
	_rollback_transfer.clear()
	if _ticket_generation >= MAX_TICKET_GENERATION:
		return false
	_ticket_generation += 1
	return true

# Presence preparation creates no persistent body/shape RID or actor registration.
# It is server-only validation, not a client-provided collision result.
func check_actor_placement(actor_id: String, layer: Dictionary, position: Vector2) -> Dictionary:
	var code := _actor_placement_error(actor_id, layer, position)
	return {"ok": true} if code.is_empty() else {"ok": false, "code": code}

func nearest_peer_reconnect(actor_id: String, layer: Dictionary, original: Vector2) -> Dictionary:
	# Read-only, server-owned subset. Original full placement always comes first.
	var initial := check_actor_placement(actor_id, layer, original)
	if initial.get("ok", false):
		return {"ok": true, "layer": layer.duplicate(true), "position": original, "distance_squared": 0.0, "metric": PeerReconnect.METRIC}
	if initial.get("code", "") != "PEER_OCCUPIED":
		return initial
	var key := Address.key(layer)
	var peers: Array[Vector2] = []
	for other in _actors.values():
		if other["layer_key"] == key:
			peers.append(other["position"])
	var candidates := PeerReconnect.nearest(original, peers, _half)
	if not candidates.get("ok", false):
		return {"ok": false, "code": "ACTOR_RECONNECT_PLACEMENT_UNRESOLVED", "candidate_reason": candidates.get("code", "UNKNOWN")}
	# All returned points share the global relaxed minimum numerical distance.
	# Never advance to a farther partial candidate when the nearest group fails
	# full environmental body/native/known-region placement. These checks have
	# no await and allocate no actor bodies or activation tickets.
	for position in candidates["positions"]:
		var checked := check_actor_placement(actor_id, layer, position)
		if checked.get("ok", false):
			return {"ok": true, "layer": layer.duplicate(true), "position": position, "distance_squared": candidates["distance_squared"], "metric": candidates["metric"]}
	return {"ok": false, "code": "ACTOR_RECONNECT_PLACEMENT_UNRESOLVED", "candidate_reason": "NEAREST_PEER_GROUP_ENVIRONMENT_UNRESOLVED"}

func _actor_placement_error(actor_id: String, layer: Dictionary, position: Vector2) -> String:
	var key := Address.key(layer)
	if actor_id.is_empty() or _actors.has(actor_id) or not _spaces.has(key) or not full_environment_body_inside(position):
		return "INVALID_ACTOR_PLACEMENT"
	if not _covered(key, position):
		return "UNMATERIALIZED_COLLISION_REGION"
	if not environment_clear(layer, position):
		return "ENVIRONMENT_BLOCKED_OR_NOT_READY"
	for other in _actors.values():
		if other["layer_key"] == key and Geometry.overlaps(position, other["position"], _half, _half):
			return "PEER_OCCUPIED"
	return ""

func prepare_actor_placement(actor_id: String, layer: Dictionary, position: Vector2) -> Dictionary:
	var checked := check_actor_placement(actor_id, layer, position)
	if not checked["ok"]:
		return checked
	# One generation for this preparation and one for add_actor at commit.
	if _ticket_generation >= MAX_TICKET_GENERATION - 1:
		return {"ok": false, "code": "NATIVE_TICKET_GENERATION_EXHAUSTED"}
	if not _invalidate_tickets():
		return {"ok": false, "code": "NATIVE_TICKET_GENERATION_EXHAUSTED"}
	var ticket := {"owner_id": _ticket_owner_id, "generation": _ticket_generation}
	_pending_activation = {"ticket": ticket.duplicate(true), "before": _positions_snapshot(), "actor_id": actor_id, "layer": layer.duplicate(true), "position": position}
	return {"ok": true, "ticket": ticket}

func _matches_activation_ticket(ticket: Variant) -> bool:
	return ticket is Dictionary and ticket.size() == 2 and ticket.get("owner_id") is int and ticket.get("generation") is int and not _pending_activation.is_empty() and ticket == _pending_activation["ticket"]

func validate_prepared_actor_placement(ticket: Variant) -> Dictionary:
	if not _matches_activation_ticket(ticket):
		return {"ok": false, "code": "INVALID_NATIVE_ACTIVATION_TICKET"}
	if _pending_activation["before"] != _positions_snapshot():
		return {"ok": false, "code": "STALE_NATIVE_ACTIVATION_TICKET"}
	return check_actor_placement(_pending_activation["actor_id"], _pending_activation["layer"], _pending_activation["position"])

func commit_prepared_actor_placement(ticket: Variant) -> Dictionary:
	var checked := validate_prepared_actor_placement(ticket)
	if not checked["ok"]:
		return checked
	var candidate: Dictionary = _pending_activation.duplicate(true)
	# add_actor invalidates pending tickets and repeats the placement precheck,
	# then allocates/records the same two bodies as the existing direct path.
	# No await or script callback can interleave these operations.
	if not add_actor(candidate["actor_id"], candidate["layer"], candidate["position"]):
		return {"ok": false, "code": last_error}
	return {"ok": true, "actor_id": candidate["actor_id"], "layer": candidate["layer"].duplicate(true), "position": candidate["position"]}

func cancel_prepared_actor_placement(ticket: Variant) -> Dictionary:
	if not _matches_activation_ticket(ticket):
		return {"ok": false, "code": "INVALID_NATIVE_ACTIVATION_TICKET"}
	_pending_activation.clear()
	return {"ok": true}

func commit_bootstrap_actor_placement(ticket: Variant) -> Dictionary:
	# This wrapper accounts only for the existing placement's two body/two shape
	# allocations. Its receipt cannot absorb changes to any existing binding.
	var checked := validate_prepared_actor_placement(ticket)
	if not checked.get("ok", false):
		return checked
	var before := _transfer_bindings()
	var candidate: Dictionary = _pending_activation.duplicate(true)
	var generation: int = _ticket_generation
	var committed := commit_prepared_actor_placement(ticket)
	if not committed.get("ok", false):
		return committed
	var actor_id: String = candidate["actor_id"]
	var actor: Dictionary = _actors.get(actor_id, {})
	if actor.is_empty() or _ticket_generation != generation + 1:
		return {"ok": false, "fatal": true, "code": "BOOTSTRAP_NATIVE_GENERATION_MISMATCH"}
	var expected_actor := {"layer_key": Address.key(candidate["layer"]), "position": candidate["position"]}
	var added: Array = []
	for field in ["environment_body", "peer_body", "circle", "square"]:
		var rid: Variant = actor.get(field)
		if not rid is RID or not rid.is_valid() or added.has(rid) or before["bodies"].has(rid) or before["shapes"].has(rid):
			return {"ok": false, "fatal": true, "code": "BOOTSTRAP_NATIVE_ALLOCATION_INVALID"}
		added.append(rid)
		expected_actor[field] = rid
	var expected: Dictionary = before.duplicate(true)
	expected["actors"][actor_id] = expected_actor
	expected["bodies"].append(expected_actor["environment_body"])
	expected["bodies"].append(expected_actor["peer_body"])
	expected["shapes"].append(expected_actor["circle"])
	expected["shapes"].append(expected_actor["square"])
	if _transfer_bindings() != expected:
		return {"ok": false, "fatal": true, "code": "BOOTSTRAP_NATIVE_WRITE_SET_MISMATCH"}
	_last_target_submit_frame = Engine.get_physics_frames()
	return {"ok": true, "pending": true, "boundary": {"native_generation": generation + 1, "bindings": expected}}

func prepared_actor_placement_effect(ticket: Variant) -> Dictionary:
	var checked := validate_prepared_actor_placement(ticket)
	return {"ok": true, "effect": _pending_activation.duplicate(true)} if checked.get("ok", false) else checked

# Active transfers rebind the existing circle and peer-square bodies. They never
# allocate/remove a body and never route through inactive placement/presence.
func prepare_actor_transfer(actor_id: String, source: Dictionary, destination: Dictionary, position: Vector2) -> Dictionary:
	var checked := _check_actor_transfer(actor_id, source, destination, position)
	if not checked["ok"]:
		return checked
	# Reserve preparation, submission and a possible pre-model rollback generation.
	if _ticket_generation < 0 or _ticket_generation > MAX_TICKET_GENERATION - 3:
		return {"ok": false, "code": "NATIVE_TICKET_GENERATION_EXHAUSTED"}
	_invalidate_tickets()
	var ticket := {"owner_id": _ticket_owner_id, "generation": _ticket_generation}
	_pending_transfer = {"ticket": ticket.duplicate(true), "before": _transfer_bindings(), "actor_id": actor_id, "source": source.duplicate(true), "destination": destination.duplicate(true), "position": position}
	return {"ok": true, "ticket": ticket}

func validate_prepared_actor_transfer(ticket: Variant) -> Dictionary:
	if not _matches_actor_transfer_ticket(ticket, _pending_transfer):
		return {"ok": false, "code": "INVALID_NATIVE_TRANSFER_TICKET"}
	if _pending_transfer["before"] != _transfer_bindings():
		return {"ok": false, "code": "STALE_NATIVE_TRANSFER_TICKET"}
	if _ticket_generation < 0 or _ticket_generation > MAX_TICKET_GENERATION - 2:
		return {"ok": false, "code": "NATIVE_TICKET_GENERATION_EXHAUSTED"}
	return _check_actor_transfer(_pending_transfer["actor_id"], _pending_transfer["source"], _pending_transfer["destination"], _pending_transfer["position"])

func commit_prepared_actor_transfer(ticket: Variant) -> Dictionary:
	var checked := validate_prepared_actor_transfer(ticket)
	if not checked["ok"]:
		return checked
	var transfer := _pending_transfer.duplicate(true)
	var actor_id: String = transfer["actor_id"]
	var target_space: RID = _spaces[Address.key(transfer["destination"])]["rid"]
	# Same XY means no new transform target is queued. Both actual bindings and
	# transforms are checked now and again at the later confirmation boundary.
	_last_target_submit_frame = Engine.get_physics_frames()
	_set_transfer_body_spaces(actor_id, target_space)
	if not _transfer_bodies_match(actor_id, transfer["destination"], transfer["position"]):
		_set_transfer_body_spaces(actor_id, _spaces[Address.key(transfer["source"])]["rid"])
		var restored := _transfer_bodies_match(actor_id, transfer["source"], transfer["position"])
		_invalidate_tickets()
		return {"ok": false, "code": "NATIVE_TRANSFER_SUBMISSION_REJECTED" if restored else "NATIVE_TRANSFER_ROLLBACK_FAILED", "restored": restored, "fatal": not restored}
	_actors[actor_id]["layer_key"] = Address.key(transfer["destination"])
	_last_target_submit_frame = Engine.get_physics_frames()
	_invalidate_tickets()
	transfer["after"] = _transfer_bindings()
	_rollback_transfer = transfer
	return {"ok": true, "submitted": true, "confirmation_pending": true}

func rollback_actor_transfer(ticket: Variant) -> Dictionary:
	# Used only if the still-unmodified model refuses its synchronous commit.
	if not _matches_actor_transfer_ticket(ticket, _rollback_transfer) or _rollback_transfer["after"] != _transfer_bindings() or _ticket_generation >= MAX_TICKET_GENERATION:
		return {"ok": false, "code": "NATIVE_TRANSFER_ROLLBACK_STALE", "fatal": true}
	var transfer := _rollback_transfer.duplicate(true)
	var actor_id: String = transfer["actor_id"]
	_set_transfer_body_spaces(actor_id, _spaces[Address.key(transfer["source"])]["rid"])
	if not _transfer_bodies_match(actor_id, transfer["source"], transfer["position"]):
		_invalidate_tickets()
		return {"ok": false, "code": "NATIVE_TRANSFER_ROLLBACK_FAILED", "fatal": true}
	_actors[actor_id]["layer_key"] = Address.key(transfer["source"])
	_last_target_submit_frame = Engine.get_physics_frames()
	_invalidate_tickets()
	return {"ok": true, "restored": true}

func finish_actor_transfer(ticket: Variant) -> Dictionary:
	if not _matches_actor_transfer_ticket(ticket, _rollback_transfer) or _rollback_transfer["after"] != _transfer_bindings():
		return {"ok": false, "code": "NATIVE_TRANSFER_CONFIRMATION_STALE"}
	var checked := validate_applied_actor_targets()
	if not checked["ok"]:
		return checked
	if not _transfer_bodies_match(_rollback_transfer["actor_id"], _rollback_transfer["destination"], _rollback_transfer["position"]):
		return {"ok": false, "code": "NATIVE_TRANSFER_CONFIRMED_SHAPE_OR_BINDING_MISMATCH"}
	_rollback_transfer.clear()
	return {"ok": true}

func cancel_prepared_actor_transfer(ticket: Variant) -> Dictionary:
	if not _matches_actor_transfer_ticket(ticket, _pending_transfer):
		return {"ok": false, "code": "INVALID_NATIVE_TRANSFER_TICKET"}
	_pending_transfer.clear()
	return {"ok": true}

func _check_actor_transfer(actor_id: String, source: Dictionary, destination: Dictionary, position: Vector2) -> Dictionary:
	var applied := _validate_actual_actor_targets() if _frame_write_scope else validate_applied_actor_targets()
	if not applied["ok"]:
		return applied
	var source_key := Address.key(source)
	var target_key := Address.key(destination)
	if not _actors.has(actor_id) or not _spaces.has(source_key) or not _spaces.has(target_key) or source_key == target_key or source.get("world_id") != destination.get("world_id") or source.get("body_instance_id") != destination.get("body_instance_id"):
		return {"ok": false, "code": "NATIVE_TRANSFER_LAYER_INVALID"}
	var actor: Dictionary = _actors[actor_id]
	if actor["layer_key"] != source_key or actor["position"] != position or _spaces[source_key]["identity"] != source or _spaces[target_key]["identity"] != destination or not _transfer_bodies_match(actor_id, source, position):
		return {"ok": false, "code": "NATIVE_TRANSFER_SOURCE_MISMATCH"}
	if not full_environment_body_inside(position) or not _covered(source_key, position) or not _covered(target_key, position):
		return {"ok": false, "code": "UNMATERIALIZED_COLLISION_REGION"}
	if not environment_clear(source, position) or not environment_clear(destination, position):
		return {"ok": false, "code": "ENVIRONMENT_BLOCKED_OR_NOT_READY"}
	for other_id in _actors:
		if other_id == actor_id:
			continue
		var other: Dictionary = _actors[other_id]
		if other["layer_key"] == target_key and Geometry.overlaps(position, other["position"], _half, _half):
			return {"ok": false, "code": "PEER_OCCUPIED"}
	return {"ok": true}

func _transfer_bodies_match(actor_id: String, layer: Dictionary, position: Vector2) -> bool:
	if not _actors.has(actor_id) or not _spaces.has(Address.key(layer)):
		return false
	var actor: Dictionary = _actors[actor_id]
	if actor["environment_body"] == actor["peer_body"]:
		return false
	for fields in [["environment_body", "circle"], ["peer_body", "square"]]:
		var body: RID = actor[fields[0]]
		if not body.is_valid() or not _bodies.has(body) or not _shapes.has(actor[fields[1]]) or PhysicsServer2D.body_get_shape_count(body) != 1 or PhysicsServer2D.body_get_shape(body, 0) != actor[fields[1]]:
			return false
		if PhysicsServer2D.body_get_space(body) != _spaces[Address.key(layer)]["rid"] or PhysicsServer2D.body_get_state(body, PhysicsServer2D.BODY_STATE_TRANSFORM) != Transform2D(0.0, position):
			return false
	if PhysicsServer2D.shape_get_type(actor["circle"]) != PhysicsServer2D.SHAPE_CIRCLE or PhysicsServer2D.shape_get_type(actor["square"]) != PhysicsServer2D.SHAPE_RECTANGLE:
		return false
	var radius: Variant = PhysicsServer2D.shape_get_data(actor["circle"])
	# Accept only the trusted scalar or its exact native binary32 representation,
	# matching existing join-native checks. This is not a geometric epsilon.
	if typeof(radius) not in [TYPE_INT, TYPE_FLOAT] or (radius != _half and radius != float((Vector2.ONE * _half).x)):
		return false
	return PhysicsServer2D.shape_get_data(actor["square"]) == Vector2.ONE * _half

func _set_transfer_body_spaces(actor_id: String, space: RID) -> void:
	for key in ["environment_body", "peer_body"]:
		PhysicsServer2D.body_set_space(_actors[actor_id][key], space)

func _transfer_bindings() -> Dictionary:
	return {"actors": _actors.duplicate(true), "spaces": _spaces.duplicate(true), "bodies": _bodies.duplicate(), "shapes": _shapes.duplicate()}

func _matches_actor_transfer_ticket(ticket: Variant, prepared: Dictionary) -> bool:
	return ticket is Dictionary and ticket.size() == 2 and typeof(ticket.get("owner_id")) == TYPE_INT and typeof(ticket.get("generation")) == TYPE_INT and not prepared.is_empty() and ticket == prepared["ticket"]

# A bounded frame owns the complete verified transfer -> movement write chain.
# Legacy operations still invalidate this capability. Only these synchronous,
# ticket-validated wrappers may preserve it across their known child operations.
func begin_actor_frame(max_transfers: int) -> Dictionary:
	var applied := validate_actor_frame_boundary()
	if not applied["ok"]:
		return applied
	if not _native_frame.is_empty() or _frame_write_scope or max_transfers < 0 or max_transfers > 64:
		return {"ok": false, "code": "NATIVE_FRAME_INVALID_BEGIN"}
	var reserve := max_transfers * 3 + 3
	if _ticket_generation < 0 or _ticket_generation > MAX_TICKET_GENERATION - reserve or _native_frame_generation >= MAX_TICKET_GENERATION:
		return {"ok": false, "code": "NATIVE_FRAME_GENERATION_EXHAUSTED"}
	_invalidate_tickets()
	_native_frame_generation += 1
	var ticket := {"owner_id": _ticket_owner_id, "generation": _native_frame_generation}
	_native_frame = {"ticket": ticket.duplicate(true), "physics_frame": Engine.get_physics_frames(), "native_generation": _ticket_generation, "bindings": _transfer_bindings(), "chain": [], "mode": "open", "max_transfers": max_transfers, "transfer_count": 0}
	return {"ok": true, "ticket": ticket}

func frame_boundary_context() -> Dictionary:
	return {"native_generation": _ticket_generation, "bindings": _transfer_bindings()}

func _validate_open_actor_frame(ticket: Variant) -> Dictionary:
	if not _matches_actor_transfer_ticket(ticket, _native_frame) or _native_frame.get("mode") != "open" or _frame_write_scope or _native_frame["physics_frame"] != Engine.get_physics_frames():
		return {"ok": false, "code": "NATIVE_FRAME_NOT_OPEN"}
	if _native_frame["native_generation"] != _ticket_generation or _native_frame["bindings"] != _transfer_bindings():
		return {"ok": false, "code": "NATIVE_FRAME_CHAIN_CHANGED", "fatal": true}
	var actual := _validate_actual_actor_targets()
	if not actual["ok"]:
		return actual
	for actor_id in _actors:
		var actor: Dictionary = _actors[actor_id]
		if not _transfer_bodies_match(actor_id, _spaces[actor["layer_key"]]["identity"], actor["position"]):
			return {"ok": false, "code": "NATIVE_FRAME_ACTUAL_SHAPE_CHANGED", "fatal": true}
	return {"ok": true}

func prepare_frame_actor_transfer(frame_ticket: Variant, actor_id: String, source: Dictionary, destination: Dictionary, position: Vector2) -> Dictionary:
	var checked := _validate_open_actor_frame(frame_ticket)
	if not checked["ok"]:
		return checked
	if _native_frame["transfer_count"] >= _native_frame["max_transfers"]:
		return {"ok": false, "code": "NATIVE_FRAME_TRANSFER_CAPACITY"}
	var before_generation: int = _native_frame["native_generation"]
	_frame_write_scope = true
	var prepared := prepare_actor_transfer(actor_id, source, destination, position)
	_frame_write_scope = false
	var expected_generation: int = before_generation + (1 if prepared.get("ok", false) else 0)
	if _ticket_generation != expected_generation:
		return {"ok": false, "code": "NATIVE_FRAME_CHILD_GENERATION_MISMATCH", "fatal": true}
	_native_frame["native_generation"] = expected_generation
	if prepared.get("ok", false):
		_native_frame["transfer_ticket"] = prepared["ticket"].duplicate(true)
	return prepared

func commit_frame_actor_transfer(frame_ticket: Variant, transfer_ticket: Variant) -> Dictionary:
	var checked := _validate_open_actor_frame(frame_ticket)
	if not checked["ok"]:
		return checked
	if _native_frame.get("transfer_ticket", {}) != transfer_ticket or not _matches_actor_transfer_ticket(transfer_ticket, _pending_transfer):
		return {"ok": false, "code": "NATIVE_FRAME_TRANSFER_TICKET_MISMATCH"}
	var transfer: Dictionary = _pending_transfer.duplicate(true)
	var expected: Dictionary = _native_frame["bindings"].duplicate(true)
	expected["actors"][transfer["actor_id"]]["layer_key"] = Address.key(transfer["destination"])
	var before_generation: int = _native_frame["native_generation"]
	_frame_write_scope = true
	var committed := commit_prepared_actor_transfer(transfer_ticket)
	_frame_write_scope = false
	var expected_generation: int = before_generation + (1 if committed.get("ok", false) or committed.has("restored") else 0)
	if _ticket_generation != expected_generation:
		return {"ok": false, "code": "NATIVE_FRAME_CHILD_GENERATION_MISMATCH", "fatal": true}
	_native_frame["native_generation"] = expected_generation
	if committed.get("ok", false):
		if _transfer_bindings() != expected:
			return {"ok": false, "code": "NATIVE_FRAME_TRANSFER_POSTCONDITION", "fatal": true}
		_native_frame["bindings"] = expected
		_native_frame["transfer_count"] += 1
		_native_frame["chain"].append({"kind": "transfer", "ticket": transfer_ticket.duplicate(true), "actor_id": transfer["actor_id"], "source": transfer["source"], "destination": transfer["destination"], "position": transfer["position"]})
	elif _transfer_bindings() != _native_frame["bindings"]:
		return {"ok": false, "code": "NATIVE_FRAME_RESTORATION_POSTCONDITION", "fatal": true}
	return committed

func rollback_frame_actor_transfer(frame_ticket: Variant, transfer_ticket: Variant) -> Dictionary:
	var checked := _validate_open_actor_frame(frame_ticket)
	if not checked["ok"]:
		return checked
	if not _matches_actor_transfer_ticket(transfer_ticket, _rollback_transfer):
		return {"ok": false, "code": "NATIVE_FRAME_ROLLBACK_TICKET_MISMATCH", "fatal": true}
	var transfer: Dictionary = _rollback_transfer.duplicate(true)
	var expected: Dictionary = _native_frame["bindings"].duplicate(true)
	expected["actors"][transfer["actor_id"]]["layer_key"] = Address.key(transfer["source"])
	var before_generation: int = _native_frame["native_generation"]
	_frame_write_scope = true
	var restored := rollback_actor_transfer(transfer_ticket)
	_frame_write_scope = false
	var expected_generation: int = before_generation + (1)
	if _ticket_generation != expected_generation:
		return {"ok": false, "code": "NATIVE_FRAME_CHILD_GENERATION_MISMATCH", "fatal": true}
	_native_frame["native_generation"] = expected_generation
	if not restored.get("ok", false) or _transfer_bindings() != expected:
		return {"ok": false, "code": "NATIVE_FRAME_ROLLBACK_POSTCONDITION", "fatal": true}
	_native_frame["bindings"] = expected
	_native_frame["chain"].append({"kind": "rollback", "ticket": transfer_ticket.duplicate(true)})
	return restored

func query_frame_environment_motion(actor_id: String, start: Vector2, motion: Vector2, frame_ticket: Variant) -> Dictionary:
	var checked := _validate_open_actor_frame(frame_ticket)
	if not checked["ok"]:
		return checked
	return query_environment_motion(actor_id, start, motion)

func prepare_frame_positions(frame_ticket: Variant, preview: Dictionary, resolved: Variant) -> Dictionary:
	var checked := _validate_open_actor_frame(frame_ticket)
	if not checked["ok"]:
		return checked
	var before_generation: int = _native_frame["native_generation"]
	_frame_write_scope = true
	var prepared := prepare_positions(preview, resolved)
	_frame_write_scope = false
	var expected_generation: int = before_generation + (1)
	if _ticket_generation != expected_generation:
		return {"ok": false, "code": "NATIVE_FRAME_CHILD_GENERATION_MISMATCH", "fatal": true}
	_native_frame["native_generation"] = expected_generation
	if prepared.get("ok", false):
		_native_frame["movement_ticket"] = prepared["ticket"].duplicate(true)
	return prepared

func commit_frame_positions(frame_ticket: Variant, movement_ticket: Dictionary) -> Dictionary:
	var checked := _validate_open_actor_frame(frame_ticket)
	if not checked["ok"]:
		return checked
	if movement_ticket != _native_frame.get("movement_ticket", {}) or movement_ticket != _pending_positions:
		return {"ok": false, "code": "NATIVE_FRAME_MOVEMENT_TICKET_MISMATCH", "fatal": true}
	var expected: Dictionary = _native_frame["bindings"].duplicate(true)
	for actor_id in movement_ticket["after"]:
		expected["actors"][actor_id]["position"] = movement_ticket["after"][actor_id]["position"]
	var before_generation: int = _native_frame["native_generation"]
	_frame_write_scope = true
	var committed := commit_prepared_positions(movement_ticket)
	_frame_write_scope = false
	var expected_generation: int = before_generation + (1)
	if _ticket_generation != expected_generation:
		return {"ok": false, "code": "NATIVE_FRAME_CHILD_GENERATION_MISMATCH", "fatal": true}
	_native_frame["native_generation"] = expected_generation
	if not committed or _transfer_bindings() != expected:
		return {"ok": false, "code": "NATIVE_FRAME_MOVEMENT_POSTCONDITION", "fatal": true}
	_native_frame["bindings"] = expected
	_native_frame["chain"].append({"kind": "movement", "ticket": movement_ticket.duplicate(true)})
	_native_frame["mode"] = "sealed"
	return {"ok": true, "sealed": true, "pending": true}

func confirm_actor_frame(frame_ticket: Variant) -> Dictionary:
	if not _matches_actor_transfer_ticket(frame_ticket, _native_frame) or _native_frame.get("mode") != "sealed" or _frame_write_scope:
		return {"ok": false, "code": "INVALID_NATIVE_FRAME_CONFIRMATION", "fatal": true}
	if Engine.get_physics_frames() <= _native_frame["physics_frame"]:
		return {"ok": false, "code": "NATIVE_FRAME_PHYSICS_PENDING", "pending": true}
	if _ticket_generation != _native_frame["native_generation"] or _transfer_bindings() != _native_frame["bindings"]:
		return {"ok": false, "code": "NATIVE_FRAME_SEALED_CHAIN_CHANGED", "fatal": true}
	var applied := validate_applied_actor_targets()
	if not applied["ok"]:
		return applied
	for actor_id in _actors:
		var actor: Dictionary = _actors[actor_id]
		if not _transfer_bodies_match(actor_id, _spaces[actor["layer_key"]]["identity"], actor["position"]):
			return {"ok": false, "code": "NATIVE_FRAME_SEALED_SHAPE_CHANGED", "fatal": true}
	var boundary := {"native_generation": _native_frame["native_generation"], "bindings": _native_frame["bindings"].duplicate(true)}
	_native_frame.clear()
	return {"ok": true, "boundary": boundary}

func actor_frame_expected_boundary(frame_ticket: Variant) -> Dictionary:
	if not _matches_actor_transfer_ticket(frame_ticket, _native_frame) or _native_frame.get("mode") != "sealed":
		return {"ok": false, "code": "NATIVE_FRAME_NOT_SEALED"}
	return {"ok": true, "boundary": {"native_generation": _native_frame["native_generation"], "bindings": _native_frame["bindings"].duplicate(true)}}

func validate_actor_frame_boundary() -> Dictionary:
	# Publication and the next submit must recheck actual shapes, not only the
	# tracked RID arrays; body_remove_shape does not alter those dictionaries.
	var applied := validate_applied_actor_targets()
	if not applied["ok"]:
		return applied
	for actor_id in _actors:
		var actor: Dictionary = _actors[actor_id]
		if not _transfer_bodies_match(actor_id, _spaces[actor["layer_key"]]["identity"], actor["position"]):
			return {"ok": false, "code": "NATIVE_FRAME_BOUNDARY_SHAPE_CHANGED"}
	return {"ok": true}
