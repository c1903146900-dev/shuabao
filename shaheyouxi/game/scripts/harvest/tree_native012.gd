extends RefCounted
## Native half of an exclusive completion transaction; no logical publication here.
## Own RIDs separately; never append to the old adapter's frozen static roots.
const Space = preload("res://scripts/actor/actor_terrain_space.gd")
const TREE_SPACE_PATH := "res://scripts/harvest/tree_terrain_space012.gd"
const Session = preload("res://scripts/harvest/tree_world_session012.gd")
const Definition = preload("res://scripts/harvest/tree_definition012.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
var _attempted := false
var _ready := false
var _confirmed := false
var _created_frame := -1
var _space: RefCounted
var _contract: RefCounted
var _authority: RefCounted
var _authority_epoch := ""
var _terrain_store: RefCounted
var _tree_state: Dictionary = {}
var _tree_token := ""
var _static_token := ""
var _static_encoding_proof: Dictionary = {}
var _static_encoding_proof_root: Dictionary = {}
var _encoding_frame_ref: WeakRef
var _encoding_lease_ref: WeakRef
var _spaces_root: Dictionary = {}
var _records: Dictionary = {}
var _records_root: Dictionary = {}
var _probes: Dictionary = {}
var _probe_root: Dictionary = {}
var _bodies: Array[RID] = []
var _shapes: Array[RID] = []
var _half := 0.0
var _epoch := -1
var _detachment: Dictionary = {}

func configure(state: Variant, contract: Variant, space: Variant) -> Dictionary:
	if _attempted: return _bad("TREE_NATIVE_ALREADY_ATTEMPTED")
	_attempted=true
	if not state is Dictionary or not contract is RefCounted or contract.get_script()!=Session or not contract.ready or not _supported_space(space) or space._spaces.is_empty(): return _bad("TREE_NATIVE_SOURCE_TYPES")
	var checked: Dictionary=contract.validate_combined_state(state)
	if not checked.get("ok",false): return checked
	if not is_same(contract._inner_terrain._terrain_store,space._terrain_store): return _bad("TREE_NATIVE_TERRAIN_SERVICE_MISMATCH")
	if Core._exact(state["terrain_component"])!=Core._exact(space._terrain) or state["terrain_component"]["artifact_sha256"]!=space._validated_artifact_sha256: return _bad("TREE_NATIVE_TERRAIN_MISMATCH")
	var definition:=Definition.new()
	if not definition.ready: return _bad("TREE_NATIVE_RULES")
	var planned: Dictionary={}
	for id in state["tree_component"]["trees"]:
		var tree: Dictionary=state["tree_component"]["trees"][id]
		if tree["status"]!="alive": continue
		var key:=Address.key(tree["layer"])
		var regions:=Session.regions_for_layer(state["world_component"],tree["layer"])
		var site:=definition.inspect_fixture_site(tree["layer"],tree["cell"],regions["entries"],regions["protected"])
		if not site.get("ok",false) or not space._spaces.has(key) or space._spaces[key]["identity"]!=tree["layer"]: return _bad("TREE_NATIVE_LAYER_OR_SITE")
		var rect: Array=site["collision_rect"]
		var geometry:=Rect2(rect[0],rect[1],rect[2],rect[3])
		# Restrict this native fixture to actual materialized terrain. No implicit air.
		if not _rect_covered(space,key,geometry): return _bad("TREE_NATIVE_UNMATERIALIZED_SITE")
		if not _rect_is_clear(space._spaces[key]["rid"],geometry): return _bad("TREE_NATIVE_EXISTING_H1_OVERLAP")
		planned[id]={"key":key,"space":space._spaces[key]["rid"],"rect":geometry}
	_space=space
	_contract=contract
	_authority=contract._authority
	_authority_epoch=_authority.server_epoch
	_terrain_store=space._terrain_store
	_spaces_root=space._spaces
	_half=space._half
	_epoch=space._static_epoch
	_static_token=_static_identity()
	if _static_token.is_empty():
		dispose()
		return _bad("TREE_NATIVE_STATIC_COVERAGE_INVALID")
	_tree_state=state["tree_component"].duplicate(true)
	Definition._freeze(_tree_state)
	_tree_token=Core._exact(_tree_state)
	for id in planned:
		var record: Dictionary=planned[id]
		var shape:=PhysicsServer2D.rectangle_shape_create()
		_shapes.append(shape)
		PhysicsServer2D.shape_set_data(shape,record["rect"].size/2.0)
		var body:=_new_body(record["space"],shape,record["rect"].get_center(),PhysicsServer2D.BODY_MODE_STATIC,1,0)
		record["shape"]=shape
		record["body"]=body
		record.make_read_only()
		_records[id]=record
		if not _probes.has(record["key"]):
			var circle:=PhysicsServer2D.circle_shape_create()
			_shapes.append(circle)
			PhysicsServer2D.shape_set_data(circle,_half)
			var probe:=_new_body(record["space"],circle,Vector2.ZERO,PhysicsServer2D.BODY_MODE_KINEMATIC,2,1)
			_probes[record["key"]]={"body":probe,"shape":circle,"space":record["space"]}
			_probes[record["key"]].make_read_only()
	_records.make_read_only()
	_records_root=_records
	_probes.make_read_only()
	_probe_root=_probes
	_created_frame=Engine.get_physics_frames()
	_ready=true
	return {"ok":true,"pending":true,"tree_count":_records.size(),"fixture_only":true}

func _new_body(space: RID, shape: RID, position: Vector2, mode: int, layer: int, mask: int) -> RID:
	var body:=PhysicsServer2D.body_create()
	_bodies.append(body)
	PhysicsServer2D.body_set_mode(body,mode)
	PhysicsServer2D.body_set_collision_layer(body,layer)
	PhysicsServer2D.body_set_collision_mask(body,mask)
	PhysicsServer2D.body_add_shape(body,shape)
	PhysicsServer2D.body_set_state(body,PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(0.0,position))
	PhysicsServer2D.body_set_space(body,space)
	return body

func confirm_initial(tree_state: Variant) -> Dictionary:
	if _confirmed or Engine.get_physics_frames()<=_created_frame: return _bad("TREE_NATIVE_CONFIRMATION_PENDING")
	var checked:=_validate(tree_state)
	if checked.get("ok",false): _confirmed=true
	return checked

func validate(tree_state: Variant) -> Dictionary:
	if not _detachment.is_empty(): return _bad("TREE_NATIVE_COMPLETION_PENDING")
	if not _confirmed: return _bad("TREE_NATIVE_NOT_CONFIRMED")
	return _validate(tree_state)

func _validate(tree_state: Variant, detached_id: String = "") -> Dictionary:
	if not _ready or not _supported_space(_space) or _contract==null or not _contract._binding_valid() or _contract._authority!=_authority or _authority.server_epoch!=_authority_epoch or _space._terrain_store!=_terrain_store or _contract._inner_terrain._terrain_store!=_terrain_store or _space._static_epoch!=_epoch or not is_same(_space._spaces,_spaces_root) or _static_token.is_empty() or _static_identity()!=_static_token or not is_same(_records,_records_root) or not is_same(_probes,_probe_root): return _bad("TREE_NATIVE_CONTEXT_CHANGED")
	if Core._exact(tree_state)!=_tree_token or Core._exact(_tree_state)!=_tree_token: return _bad("TREE_NATIVE_LEDGER_CHANGED")
	for id in _records:
		var record: Dictionary=_records[id]
		var body: RID=record["body"]
		var shape: RID=record["shape"]
		if not _spaces_root.has(record["key"]) or _spaces_root[record["key"]]["rid"]!=record["space"] or not PhysicsServer2D.space_is_active(record["space"]): return _bad("TREE_NATIVE_SPACE_CHANGED")
		if not _body_matches(body,shape,RID() if id==detached_id else record["space"],record["rect"].get_center(),PhysicsServer2D.BODY_MODE_STATIC,1,0): return _bad("TREE_NATIVE_BODY_CHANGED")
		if PhysicsServer2D.shape_get_type(shape)!=PhysicsServer2D.SHAPE_RECTANGLE or PhysicsServer2D.shape_get_data(shape)!=record["rect"].size/2.0: return _bad("TREE_NATIVE_GEOMETRY_CHANGED")
		var probe: Dictionary=_probes[record["key"]]
		if not _body_matches(probe["body"],probe["shape"],record["space"],Vector2.ZERO,PhysicsServer2D.BODY_MODE_KINEMATIC,2,1) or PhysicsServer2D.shape_get_type(probe["shape"])!=PhysicsServer2D.SHAPE_CIRCLE: return _bad("TREE_NATIVE_PROBE_CHANGED")
		var radius: Variant=PhysicsServer2D.shape_get_data(probe["shape"])
		if typeof(radius) not in [TYPE_FLOAT,TYPE_INT] or (radius!=_half and radius!=float((Vector2.ONE*_half).x)): return _bad("TREE_NATIVE_PROBE_GEOMETRY_CHANGED")
		if id==detached_id:
			if not _rect_is_clear(record["space"],record["rect"]): return _bad("TREE_NATIVE_DETACHED_QUERY_OCCUPIED")
			continue
		var checked:=_probe_tree(record,probe["body"])
		if not checked.get("ok",false): return checked
	return {"ok":true,"tree_count":_records.size(),"fixture_only":true}

func validate_actual_actors(tree_state: Variant) -> Dictionary:
	var checked:=validate(tree_state)
	if not checked.get("ok",false): return checked
	return _validate_actor_records()

func _validate_actor_records(detached_id: String = "") -> Dictionary:
	for actor_id in _space._actors:
		var actor: Variant=_space._actors[actor_id]
		if not Core._fields(actor,["layer_key","position","environment_body","peer_body","circle","square"]) or not actor["layer_key"] is String or not actor["position"] is Vector2 or not _spaces_root.has(actor["layer_key"]): return _bad("TREE_NATIVE_ACTOR_IDENTITY")
		for field in ["environment_body","peer_body","circle","square"]:
			if not actor[field] is RID: return _bad("TREE_NATIVE_ACTOR_IDENTITY")
		if not _space._transfer_bodies_match(actor_id,_spaces_root[actor["layer_key"]]["identity"],actor["position"]): return _bad("TREE_NATIVE_ACTOR_SHAPE_CHANGED")
		var body: RID=actor["environment_body"]
		if PhysicsServer2D.body_get_mode(body)!=PhysicsServer2D.BODY_MODE_KINEMATIC or PhysicsServer2D.body_get_collision_layer(body)!=2 or PhysicsServer2D.body_get_collision_mask(body)!=1 or PhysicsServer2D.body_get_shape_transform(body,0)!=Transform2D.IDENTITY: return _bad("TREE_NATIVE_ACTOR_FILTER_CHANGED")
		for id in _records:
			var record: Dictionary=_records[id]
			if id==detached_id or record["key"]!=actor["layer_key"]: continue
			var checked:=_probe_tree(record,body)
			if not checked.get("ok",false): return _bad("TREE_NATIVE_ACTOR_DIRECTION_NOT_BLOCKED")
	return {"ok":true,"tree_count":_records.size(),"actor_count":_space._actors.size(),"fixture_only":true}

# Only the exact TreeSpace/Frame integration may expose these internal native
# operations. A returned ticket is an object identity, not a caller-chosen ID.
# Every normal native/Frame boundary stays red until rollback or publication.
func begin_detachment(tree_state: Variant, tree_plan: Variant) -> Dictionary:
	var checked:=validate_actual_actors(tree_state)
	if not checked.get("ok",false): return checked
	if not tree_plan is Dictionary or not tree_plan.get("ok",false) or tree_plan.get("replay",true) or not tree_plan.get("tree_id") is String or not tree_plan.get("completion_id") is String: return _bad("TREE_NATIVE_COMPLETION_PLAN")
	var id: String=tree_plan["tree_id"]
	var event: String=tree_plan["completion_id"]
	if not _records.has(id) or not tree_plan.get("state") is Dictionary or not tree_plan["state"].get("completions") is Dictionary or not tree_plan["state"]["completions"].has(event): return _bad("TREE_NATIVE_COMPLETION_PLAN")
	var ledger:=Ledger.new(_tree_state["world_id"],_tree_state["seed_decimal"])
	if not ledger.trusted_restore(_tree_state).get("ok",false): return _bad("TREE_NATIVE_LEDGER_INVALID")
	var completion: Variant=tree_plan["state"]["completions"][event]
	if not completion is Dictionary or not completion.get("profile_id") is String or typeof(completion.get("completed_world_seconds"))!=TYPE_FLOAT: return _bad("TREE_NATIVE_COMPLETION_PLAN")
	var expected: Dictionary=ledger.plan_completion(id,event,completion["profile_id"],completion["completed_world_seconds"],ledger.token())
	if not expected.get("ok",false) or expected["replay"] or Ledger.exact_token(tree_plan)!=Ledger.exact_token(expected): return _bad("TREE_NATIVE_COMPLETION_PLAN_CHANGED")
	var ticket:=RefCounted.new()
	var next: Dictionary=expected["state"].duplicate(true)
	Definition._freeze(next)
	_detachment={"ticket":ticket,"tree_id":id,"next":next,"source":_tree_token,"phase":"detached","physics_frame":Engine.get_physics_frames()}
	_detachment.make_read_only()
	PhysicsServer2D.body_set_space(_records[id]["body"],RID())
	return {"ok":true,"pending":true,"ticket":ticket,"logical_published":false}

func validate_detached(ticket: Variant, tree_state: Variant) -> Dictionary:
	if not _detachment_matches(ticket,"detached") or Engine.get_physics_frames()<=_detachment["physics_frame"]: return _bad("TREE_NATIVE_DETACH_TICKET_OR_PHYSICS")
	var checked:=_validate(tree_state,_detachment["tree_id"])
	if not checked.get("ok",false): return checked
	return _validate_actor_records(_detachment["tree_id"])

func begin_rollback(ticket: Variant, tree_state: Variant) -> Dictionary:
	var checked:=validate_detached(ticket,tree_state)
	if not checked.get("ok",false): return checked
	var record: Dictionary=_records[_detachment["tree_id"]]
	var pending: Dictionary=_detachment.duplicate(false)
	pending["phase"]="restoring"
	pending["physics_frame"]=Engine.get_physics_frames()
	pending.make_read_only()
	_detachment=pending
	PhysicsServer2D.body_set_space(record["body"],record["space"])
	return {"ok":true,"pending":true,"ticket":ticket,"rollback_confirmed":false}

func validate_restored(ticket: Variant, tree_state: Variant) -> Dictionary:
	if not _detachment_matches(ticket,"restoring") or Engine.get_physics_frames()<=_detachment["physics_frame"]: return _bad("TREE_NATIVE_ROLLBACK_TICKET_OR_PHYSICS")
	var checked:=_validate(tree_state)
	return _validate_actor_records() if checked.get("ok",false) else checked

func confirm_rollback(ticket: Variant, tree_state: Variant) -> Dictionary:
	var checked:=validate_restored(ticket,tree_state)
	if not checked.get("ok",false): return checked
	_detachment={}
	return {"ok":true,"rollback_confirmed":true,"logical_published":false}

func publication_ready(ticket: Variant, tree_state: Variant, next_tree_state: Variant) -> Dictionary:
	var checked:=validate_detached(ticket,tree_state)
	if not checked.get("ok",false): return checked
	if Core._exact(next_tree_state)!=Core._exact(_detachment["next"]): return _bad("TREE_NATIVE_PUBLICATION_CHANGED")
	return {"ok":true,"native_confirmed":true}

func publish_detachment(ticket: Variant, tree_state: Variant, next_tree_state: Variant) -> Dictionary:
	# The caller must already hold both logical tokens and an exclusive Frame
	# phase. It synchronously swaps the complete tree+ground bundle, then this
	# certificate, with no callbacks/await in between. Any post-swap failure is
	# fatal; it must never restore only the collider after wood was published.
	var checked:=publication_ready(ticket,tree_state,next_tree_state)
	if not checked.get("ok",false): return checked
	var id: String=_detachment["tree_id"]
	var record: Dictionary=_records[id]
	var remaining: Dictionary=_records.duplicate(false)
	remaining.erase(id)
	remaining.make_read_only()
	_tree_state=_detachment["next"]
	_tree_token=Core._exact(_tree_state)
	_records=remaining
	_records_root=remaining
	_bodies.erase(record["body"])
	_shapes.erase(record["shape"])
	PhysicsServer2D.free_rid(record["body"])
	PhysicsServer2D.free_rid(record["shape"])
	_detachment={}
	return {"ok":true,"native_published":true,"tree_count":_records.size()}

func _detachment_matches(ticket: Variant, phase: String) -> bool:
	return ticket is RefCounted and Core._fields(_detachment,["ticket","tree_id","next","source","phase","physics_frame"]) and _detachment.is_read_only() and _detachment["ticket"] is RefCounted and _detachment["tree_id"] is String and _detachment["next"] is Dictionary and _detachment["source"] is String and _detachment["phase"] is String and typeof(_detachment["physics_frame"])==TYPE_INT and _detachment["physics_frame"]>=0 and is_same(ticket,_detachment["ticket"]) and _detachment["phase"]==phase and _detachment["source"]==_tree_token and _records.has(_detachment["tree_id"])

static func _supported_space(value: Variant) -> bool:
	if not value is RefCounted: return false
	var script: Script=value.get_script()
	if script==Space: return true
	# Runtime lookup breaks the Native <-> adapter preload cycle while retaining
	# exact loaded script identity, not just a claimed resource path.
	return script!=null and script.resource_path==TREE_SPACE_PATH and script==load(TREE_SPACE_PATH) and script.get_base_script()==Space

func _body_matches(body: RID, shape: RID, space: RID, position: Vector2, mode: int, layer: int, mask: int) -> bool:
	return body.is_valid() and shape.is_valid() and _bodies.has(body) and _shapes.has(shape) and PhysicsServer2D.body_get_space(body)==space and PhysicsServer2D.body_get_mode(body)==mode and PhysicsServer2D.body_get_collision_layer(body)==layer and PhysicsServer2D.body_get_collision_mask(body)==mask and PhysicsServer2D.body_get_shape_count(body)==1 and PhysicsServer2D.body_get_shape(body,0)==shape and PhysicsServer2D.body_get_shape_transform(body,0)==Transform2D.IDENTITY and PhysicsServer2D.body_get_state(body,PhysicsServer2D.BODY_STATE_TRANSFORM)==Transform2D(0.0,position)

func _probe_tree(record: Dictionary, probe: RID) -> Dictionary:
	var direct:=PhysicsServer2D.space_get_direct_state(record["space"])
	if direct==null: return _bad("TREE_NATIVE_QUERY_UNAVAILABLE")
	# A saved tree cannot overlap an existing H1 body. The query is checked after
	# a real physics boundary, not trusted from a pre-allocation cache.
	if not _rect_is_clear(record["space"],record["rect"],[record["body"]]): return _bad("TREE_NATIVE_EXISTING_H1_OVERLAP")
	var point:=PhysicsPointQueryParameters2D.new()
	point.position=record["rect"].get_center()
	point.collision_mask=1
	var found:=false
	for result in direct.intersect_point(point,512):
		if result.get("rid")==record["body"]: found=true
	if not found: return _bad("TREE_NATIVE_NOT_QUERYABLE")
	var exclude: Array[RID]=[]
	for body in _space._bodies:
		if body!=probe: exclude.append(body)
	for body in _bodies:
		if body!=probe and body!=record["body"]: exclude.append(body)
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		var extent: float=record["rect"].size.x/2.0 if direction.x!=0.0 else record["rect"].size.y/2.0
		var distance:=extent+_half+0.05
		var parameters:=PhysicsTestMotionParameters2D.new()
		parameters.from=Transform2D(0.0,record["rect"].get_center()+direction*distance)
		parameters.motion=-direction*distance
		parameters.margin=0.001
		parameters.exclude_bodies=exclude
		var result:=PhysicsTestMotionResult2D.new()
		if not PhysicsServer2D.body_test_motion(probe,parameters,result) or result.get_collider_rid()!=record["body"]: return _bad("TREE_NATIVE_DIRECTION_NOT_BLOCKED")
	return {"ok":true}

static func _rect_is_clear(space: RID, rect: Rect2, exclude: Array[RID]=[]) -> bool:
	var direct:=PhysicsServer2D.space_get_direct_state(space)
	if direct==null: return false
	var rectangle:=RectangleShape2D.new()
	rectangle.size=rect.size
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=rectangle
	query.transform=Transform2D(0.0,rect.get_center())
	query.collision_mask=1
	query.exclude=exclude
	return direct.intersect_shape(query,1).is_empty()

static func _rect_covered(space: RefCounted, key: String, rect: Rect2) -> bool:
	# Profile6 uses the original composite exact-cell adapter. Legacy rectangle
	# support is not silently treated as equivalent to this contract.
	if not space._spaces.has(key): return false
	var entry: Variant=space._spaces[key]
	if not entry is Dictionary or not entry.get("coverage_mode") is String or entry.get("coverage_mode")!="exact_cell_union_v1" or not entry.get("materialized_cells") is Dictionary or not entry.get("cell_coverage_bounds") is Array: return false
	for corner in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		if corner.length_squared()>space._radius*space._radius: return false
	var bounds: Array=entry["cell_coverage_bounds"]
	if bounds.size()!=4: return false
	for value in bounds:
		if typeof(value)!=TYPE_INT: return false
	if bounds[2]<=0 or bounds[3]<=0 or rect.position.x<bounds[0] or rect.position.y<bounds[1] or rect.end.x>bounds[0]+bounds[2] or rect.end.y>bounds[1]+bounds[3]: return false
	for y in range(floori(rect.position.y),ceili(rect.end.y)):
		for x in range(floori(rect.position.x),ceili(rect.end.x)):
			var covered: Variant=entry["materialized_cells"].get("%d,%d" % [x,y])
			if typeof(covered)!=TYPE_BOOL or not covered: return false
	return true

func _static_identity() -> String:
	# Memoization is subordinate to the real Frame's existing external source
	# certificate. Private memo fields cannot certify a changed live root.
	var context:=_encoding_runtime_context()
	if context.is_empty():
		_static_encoding_proof={}
		_static_encoding_proof_root={}
		_encoding_frame_ref=null
		_encoding_lease_ref=null
		return static_context(_space)
	if _encoding_frame_ref==null or _encoding_lease_ref==null or not is_same(_encoding_frame_ref.get_ref(),context[0]) or not is_same(_encoding_lease_ref.get_ref(),context[1]):
		_static_encoding_proof={}
		_static_encoding_proof_root={}
		_encoding_frame_ref=weakref(context[0])
		_encoding_lease_ref=weakref(context[1])
	return _memoize_static_identity()

func _encoding_runtime_context() -> Array:
	# Runtime loads avoid the existing Owner -> Frame -> Native import cycle.
	if _space==null or _space.get_script()!=load(TREE_SPACE_PATH) or _space._owner_ref==null: return []
	var owner: Object=_space._owner_ref.get_ref()
	if owner==null or owner.get_script()!=load("res://scripts/actor/actor_terrain_network_main.gd") or owner.is_queued_for_deletion() or owner._save_profile!=6 or owner._closing or owner._fatal_shutdown: return []
	if not is_same(owner._actor_space,_space) or not is_same(_space._tree_native,self) or not is_same(owner._inventory_owner,_space._service): return []
	var service: Variant=_space._service
	if not service is RefCounted or service.get_script()!=load("res://scripts/harvest/tree_inventory_owner012.gd") or not is_same(service._tree_contract,_contract): return []
	var frame: Variant=owner._bootstrap_frame
	if not frame is RefCounted or frame.get_script()!=load("res://scripts/actor/actor_frame_transaction.gd") or not is_same(frame._space,_space): return []
	var lease: Variant=frame._source_lease
	if not lease is RefCounted or lease.get_script()!=load("res://scripts/actor/actor_frozen_source_lease.gd"): return []
	# bound_save_owner invokes original guard(), not dynamic_boundary(), so this
	# does not recurse through Native. Unprepared/released roots never get memo.
	return [frame,lease] if is_same(lease.bound_save_owner(),owner) else []

func _memoize_static_identity() -> String:
	# Private pure-encoding seam; only _static_identity authorizes runtime use.
	# This memo reuses encoding only. All native bodies, shapes, actor queries,
	# tree tokens and the caller's authority/service checks still run every time.
	if _static_encoding_matches(): return _static_encoding_proof["encoding"]
	_static_encoding_proof={}
	_static_encoding_proof_root={}
	var encoded:=static_context(_space)
	# Startup precedes SourceLease's recursive freeze. Never cache that phase,
	# shallow-readonly roots, an invalid context, or a changed original token.
	if not encoded.is_empty() and encoded==_static_token and _space!=null and _deep_readonly(_space._terrain) and _deep_readonly(_space._supported_regions) and _deep_readonly(_space._spaces):
		_static_encoding_proof={"space":_space,"script":_space.get_script(),"epoch":_space._static_epoch,"terrain":_space._terrain,"regions":_space._supported_regions,"spaces":_space._spaces,"scalars":_static_scalar_encoding(),"encoding":encoded}
		_static_encoding_proof.make_read_only()
		_static_encoding_proof_root=_static_encoding_proof
	return encoded

func _static_encoding_matches() -> bool:
	var proof: Dictionary=_static_encoding_proof
	if not is_same(proof,_static_encoding_proof_root) or not proof.is_read_only() or not Core._fields(proof,["space","script","epoch","terrain","regions","spaces","scalars","encoding"]): return false
	if not proof["space"] is RefCounted or not proof["script"] is Script or typeof(proof["epoch"])!=TYPE_INT or not proof["scalars"] is String or not proof["encoding"] is String: return false
	return _space!=null and is_same(_space,proof["space"]) and _space.get_script()==proof["script"] and _space._static_epoch==proof["epoch"] and is_same(_space._terrain,proof["terrain"]) and is_same(_space._supported_regions,proof["regions"]) and is_same(_space._spaces,proof["spaces"]) and _space._terrain.is_read_only() and _space._supported_regions.is_read_only() and _space._spaces.is_read_only() and _static_scalar_encoding()==proof["scalars"] and proof["encoding"]==_static_token

func _static_scalar_encoding() -> String:
	# Exact scalar bits/types, including negative zero, rather than numeric ==.
	return Core._exact([_space._supported_cell_count,_space._validated_artifact_sha256,_space._radius,_space._half])

static func _deep_readonly(value: Variant, depth: int = 0) -> bool:
	if depth>64: return false
	if value is Dictionary:
		if not value.is_read_only(): return false
		for key in value:
			if not _deep_readonly(key,depth+1) or not _deep_readonly(value[key],depth+1): return false
	elif value is Array:
		if not value.is_read_only(): return false
		for item in value:
			if not _deep_readonly(item,depth+1): return false
	return true

static func static_context(space: RefCounted) -> String:
	if space==null: return ""
	var spaces: Dictionary={}
	for key in space._spaces:
		var entry: Variant=space._spaces[key]
		if not Core._fields(entry,["rid","identity","materialized_bounds","coverage_mode","materialized_cells","cell_coverage_bounds"]) or not entry.get("rid") is RID or not entry.get("coverage_mode") is String or entry.get("coverage_mode")!="exact_cell_union_v1" or not entry.get("materialized_bounds") is Array or not entry["materialized_bounds"].is_empty() or not entry.get("materialized_cells") is Dictionary or not entry.get("cell_coverage_bounds") is Array: return ""
		spaces[key]={"rid":entry["rid"].get_id(),"identity":entry["identity"],"mode":entry["coverage_mode"],"cells":entry["materialized_cells"],"bounds":entry["cell_coverage_bounds"]}
	var encoded: Dictionary=Core.Codec.encode([space._terrain,space._supported_regions,space._supported_cell_count,space._validated_artifact_sha256,space._radius,space._half,spaces])
	return JSON.stringify(encoded["value"],"",true,true) if encoded.get("ok",false) else ""

func dispose() -> void:
	_encoding_frame_ref=null
	_encoding_lease_ref=null
	_static_encoding_proof={}
	_static_encoding_proof_root={}
	_detachment={}
	_ready=false
	_confirmed=false
	for body in _bodies: PhysicsServer2D.free_rid(body)
	for shape in _shapes: PhysicsServer2D.free_rid(shape)
	_bodies.clear()
	_shapes.clear()
	_records={}
	_probes={}
	_space=null
	_contract=null
	_authority=null
	_terrain_store=null

static func _bad(code: String) -> Dictionary:
	return {"ok":false,"code":code}
