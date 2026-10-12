extends RefCounted
## Server-owned composition seam. No RPC is declared here; the network owner
## passes get_remote_sender_id(), never a client-selected profile/actor ID.
const Solver = preload("res://scripts/actor/actor_joint_solver.gd")
const Session = preload("res://scripts/actor/actor_session_state.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const State = preload("res://scripts/actor/actor_state.gd")
const InteractionSelector = preload("res://scripts/actor/actor_interaction_selector.gd")
const JoinPlacement = preload("res://scripts/actor/actor_join_placement_selector.gd")
var ready: bool = false
var fatal_error: String = ""
var _authority: RefCounted
var _world: RefCounted
var _actors: RefCounted
var _space: RefCounted
var _session: RefCounted
var _half: float = 0.0
var _interaction_range: float = 0.0

func _init(authority: RefCounted, world: RefCounted, actors: RefCounted, space: RefCounted, inputs: RefCounted) -> void:
	if authority == null or world == null or actors == null or space == null or inputs == null or not world.ready or not actors.ready or not inputs.ready:
		fatal_error = "ACTOR_CONTROLLER_INPUTS_INVALID"
		return
	_authority = authority
	_world = world
	_actors = actors
	_space = space
	_session = Session.new(world, inputs.document())
	_half = inputs.parameter("actor_diameter_cells") / 2.0
	_interaction_range = inputs.parameter("interaction_range_cells")
	ready = _session.ready and is_finite(_half) and _half > 0.0 and is_finite(_interaction_range) and _interaction_range > 0.0
	if not ready:
		fatal_error = "ACTOR_CONTROLLER_CONTRACT_INVALID"
		return
	var initial: Dictionary = _session.combine(_authority.persistent_state(), _actors)
	if not initial["ok"] or not _all_bindings_valid():
		ready = false
		fatal_error = "ACTOR_CONTROLLER_INITIAL_BINDING_INVALID"
	# On construction failure the caller retains ownership and must clean up its
	# partially built services. Runtime fatal failures after ready use shutdown_runtime.

func join_peer(peer_id: int, request: Dictionary, local_host: bool = false) -> Dictionary:
	# Server-only entry. The network owner supplies sender ID and local_host;
	# neither a position nor an actor ID is accepted from the request.
	if not ready:
		return State.error("ACTOR_CONTROLLER_STOPPED", "request")
	if not _all_bindings_valid() or _actors.clock_seconds() != _authority.world_seconds:
		return _fatal("ACTOR_AUTHORITY_RUNTIME_MISMATCH")
	var prior: Dictionary = _session.combine(_authority.persistent_state(), _actors)
	if not prior.get("ok", false):
		return _fatal("ACTOR_JOIN_PRIOR_STATE_INVALID")
	var identity: Dictionary = _authority.prepare_join(peer_id, request, local_host)
	if not identity.get("ok", false):
		return identity
	var identity_ticket: Dictionary = identity["ticket"]
	var actor_id: String = identity["player_instance_id"]
	if identity["already_active"]:
		# Preserve all input latches, resources and native bodies for duplicate hello.
		if _actor_for_peer(peer_id) != actor_id or not _binding_valid(actor_id):
			_authority.cancel_prepared_join(identity_ticket)
			return _fatal("ACTOR_DUPLICATE_JOIN_BINDING_INVALID")
		var duplicate: Dictionary = _authority.commit_prepared_join(identity_ticket)
		if not duplicate.get("ok", false):
			_authority.cancel_prepared_join(identity_ticket)
			return _fatal("ACTOR_DUPLICATE_JOIN_COMMIT_FAILED")
		return duplicate
	var placement: Dictionary = _choose_join_placement(actor_id, identity["is_new"])
	if not placement.get("ok", false):
		_authority.cancel_prepared_join(identity_ticket)
		return placement
	var fallback: Dictionary = {"layer": placement["layer"].duplicate(true), "position": State.pair(placement["position"])} if identity["is_new"] else {}
	var presence: Dictionary = _actors.prepare_presence(actor_id, placement["layer"], placement["position"], fallback)
	if not presence.get("ok", false):
		_authority.cancel_prepared_join(identity_ticket)
		return presence
	var presence_ticket: Dictionary = presence["ticket"]
	var native: Dictionary = _space.prepare_actor_placement(actor_id, placement["layer"], placement["position"])
	if not native.get("ok", false):
		_cancel_join(identity_ticket, presence_ticket)
		return native
	var native_ticket: Dictionary = native["ticket"]
	# All three read sets are validated immediately before the synchronous commits.
	# These production methods contain no await, signals or user-supplied callbacks.
	for checked in [_authority.validate_prepared_join(identity_ticket), _actors.validate_prepared_presence(presence_ticket), _space.validate_prepared_actor_placement(native_ticket)]:
		if not checked.get("ok", false):
			_cancel_join(identity_ticket, presence_ticket, native_ticket)
			return checked
	var native_commit: Dictionary = _space.commit_prepared_actor_placement(native_ticket)
	if not native_commit.get("ok", false):
		_cancel_join(identity_ticket, presence_ticket, native_ticket)
		return _fatal("ACTOR_JOIN_NATIVE_COMMIT_FAILED")
	var model_commit: Dictionary = _actors.commit_prepared_presence(presence_ticket)
	if not model_commit.get("ok", false):
		_cancel_join(identity_ticket, presence_ticket)
		return _fatal("ACTOR_JOIN_MODEL_COMMIT_FAILED")
	var welcome: Dictionary = _authority.commit_prepared_join(identity_ticket)
	if not welcome.get("ok", false):
		_authority.cancel_prepared_join(identity_ticket)
		return _fatal("ACTOR_JOIN_AUTHORITY_COMMIT_FAILED")
	var combined: Dictionary = _session.combine(_authority.persistent_state(), _actors)
	if not combined.get("ok", false) or not _all_bindings_valid():
		return _fatal("ACTOR_JOIN_FINAL_BINDING_INVALID")
	return welcome

func _cancel_join(identity_ticket: Dictionary, presence_ticket: Dictionary, native_ticket: Dictionary = {}) -> void:
	if not native_ticket.is_empty():
		_space.cancel_prepared_actor_placement(native_ticket)
	_actors.cancel_prepared_presence(presence_ticket)
	_authority.cancel_prepared_join(identity_ticket)

func _choose_join_placement(actor_id: String, is_new: bool) -> Dictionary:
	var retained: Dictionary = _actors.actor_record(actor_id)
	if not is_new:
		if retained.is_empty():
			return State.error("ACTOR_RETAINED_RECORD_MISSING", "request")
		var original := State.vector(retained["position"])
		var legal: Dictionary = _space.check_actor_placement(actor_id, retained["layer"], original)
		if not legal.get("ok", false):
			# Supported subset: a peer occupies otherwise valid original terrain.
			# Other geometry/unknown layers are not permission to use spawn anchors.
			if legal.get("code", "") == "PEER_OCCUPIED" and _space.has_method("nearest_peer_reconnect"):
				var nearest: Dictionary = _space.nearest_peer_reconnect(actor_id, retained["layer"], original)
				if nearest.get("ok", false):
					if nearest.get("layer") != retained["layer"] or not nearest.get("position") is Vector2:
						return {"ok": false, "code": "ACTOR_RECONNECT_PLACEMENT_UNRESOLVED", "placement_reason": "INVALID_NEAREST_RECONNECT_RESULT"}
					return {"ok": true, "layer": retained["layer"].duplicate(true), "position": nearest["position"]}
				return {"ok": false, "code": "ACTOR_RECONNECT_PLACEMENT_UNRESOLVED", "placement_reason": legal["code"], "candidate_reason": nearest.get("candidate_reason", nearest.get("code", "UNKNOWN"))}
			return {"ok": false, "code": "ACTOR_RECONNECT_PLACEMENT_UNRESOLVED", "placement_reason": legal.get("code", "UNKNOWN")}
		return {"ok": true, "layer": retained["layer"].duplicate(true), "position": original}
	if not retained.is_empty():
		return State.error("ACTOR_NEW_ID_ALREADY_RETAINED", "request")
	var component: Dictionary = _world.public_component()
	var validated: Dictionary = _world.validate_component(component, _authority.world_id)
	if not validated.get("ok", false):
		return State.error("ACTOR_SPAWN_COMPONENT_INVALID", "request")
	return JoinPlacement.choose_new(component, actor_id, _space)

func accept_peer_input(peer_id: int, request: Variant) -> Dictionary:
	if not ready:
		return State.error("ACTOR_CONTROLLER_STOPPED", "request")
	var actor_id := _actor_for_peer(peer_id)
	if actor_id.is_empty():
		return State.error("ACTOR_PEER_NOT_JOINED", "request")
	if not _binding_valid(actor_id):
		return _fatal("AUTHENTICATED_ACTOR_NOT_ACTIVATED")
	var result: Dictionary = _actors.accept_input(actor_id, request)
	if result.get("code") == "ACTOR_REVISION_EXHAUSTED":
		return _fatal("ACTOR_REVISION_EXHAUSTED")
	if result.get("ok", false) and not result.get("duplicate", false) and result.get("action", {}).get("interaction_requested", false):
		# Internal result only, after Motion consumed the fresh pressed edge.
		# Held/released/duplicate/rejected commands never enter this selector.
		result["interaction"] = _select_interaction(actor_id, result["aim"])
	return result

func _select_interaction(actor_id: String, aim: Vector2) -> Dictionary:
	var component: Dictionary = _world.public_component()
	var verified: Dictionary = _world.validate_component(component, _authority.world_id)
	if not verified.get("ok", false):
		return {"ok": false, "selected": false, "code": "INTERACTION_WORLD_COMPONENT_INVALID"}
	var record: Dictionary = _actors.actor_record(actor_id)
	var selected := InteractionSelector.select_natural_entry(verified["component"], record["layer"], State.vector(record["position"]), aim, _interaction_range)
	if not selected["ok"]:
		return selected
	# Natural endpoints are declared in layout, but the active actor world has no
	# materialized entry/underground placement or transfer transaction. Selection
	# must never be reported as successful transfer, move a body, or change saves.
	return {"ok": false, "selected": true, "code": "INTERACTION_TRANSFER_UNSUPPORTED", "candidate": selected["candidate"].duplicate(true)}

func step(delta: float) -> Dictionary:
	if not ready:
		return State.error("ACTOR_CONTROLLER_STOPPED", "request")
	var applied: Dictionary = _space.validate_applied_actor_targets()
	if not applied.get("ok", false):
		return _fatal(str(applied.get("code", "NATIVE_APPLIED_TARGET_MISMATCH")))
	if not _all_bindings_valid() or _actors.clock_seconds() != _authority.world_seconds:
		return _fatal("ACTOR_AUTHORITY_RUNTIME_MISMATCH")
	var preview: Dictionary = _actors.preview_tick(delta)
	if not preview["ok"]:
		return _fatal(str(preview.get("code", "ACTOR_PREVIEW_FAILED")))
	if preview.get("paused", false):
		return {"ok": true, "paused": true, "clock": _authority.world_seconds}
	if not _space.has_method("circle_boundaries"):
		return _fatal("ACTOR_CIRCLE_DESCRIPTOR_UNAVAILABLE")
	var circles: Variant = _space.circle_boundaries()
	if not circles is Dictionary:
		return _fatal("ACTOR_CIRCLE_DESCRIPTOR_INVALID")
	var solved := Solver.resolve(preview, _space.query_environment_motion, _half, {}, circles)
	if not solved["ok"]:
		# Diagnostic whitelist only; no profile, credentials, pending inputs or saves.
		var diagnostic := {"actor_id":str(solved.get("actor_id","")),"cause":str(solved.get("cause","")),"clock_before":_authority.world_seconds,"attempted_delta":delta,"actor_revision":preview["revision"],"authority_revision":_authority.revision}
		for field in ["query_start","query_motion"]:
			if solved.get(field) is Array:
				diagnostic[field] = solved[field].duplicate()
		var failed := _fatal(str(solved.get("code", "ACTOR_RESOLUTION_FAILED")))
		failed["diagnostic"] = diagnostic
		return failed
	var committed: Dictionary = _space.commit_actor_preview(_actors, preview, solved["positions"])
	if not committed["ok"]:
		return _fatal(str(committed.get("code", "ACTOR_COMMIT_FAILED")))
	_authority.advance(delta)
	if _authority.world_seconds != _actors.clock_seconds():
		return _fatal("ACTOR_CLOCK_COMMIT_MISMATCH")
	return {"ok": true, "paused": false, "clock": _authority.world_seconds, "trajectory": solved["trajectory"], "events": solved["events"]}

func disconnect_peer(peer_id: int) -> Dictionary:
	if not ready:
		return State.error("ACTOR_CONTROLLER_STOPPED", "request")
	var actor_id := _actor_for_peer(peer_id)
	if actor_id.is_empty():
		return {"ok": true}
	# Release native occupancy regardless of whether a persistent revision can advance.
	_space.remove_actor(actor_id)
	var removed: Dictionary = _actors.deactivate(actor_id)
	if not removed["ok"] or _authority.revision >= SandboxServerAuthority.MAX_EXACT_JSON_INTEGER:
		return _fatal("DISCONNECT_REVISION_EXHAUSTED")
	_authority.disconnect_peer(peer_id)
	return {"ok": true}

func public_snapshot() -> Dictionary:
	if not ready:
		return {}
	var snapshot: Dictionary = _authority.public_snapshot()
	snapshot["world_component"] = _world.public_component()
	snapshot["actor_public"] = _actors.public_snapshot()
	return snapshot

func combined_save_state(advance_auto: bool = false) -> Dictionary:
	if not ready or not _all_bindings_valid():
		return State.error("ACTOR_CONTROLLER_NOT_SAVE_READY", "request")
	var state: Dictionary = _authority.state_for_automatic_save() if advance_auto else _authority.persistent_state()
	return _session.combine(state, _actors)

func shutdown_runtime() -> void:
	# Caller saves a normal shutdown first; fatal shutdown MUST NOT save/broadcast.
	ready = false
	if _actors != null:
		_actors.release_runtime_sessions()
	if _space != null:
		_space.dispose()

func _actor_for_peer(peer_id: int) -> String:
	if peer_id <= 0:
		return ""
	for player in _authority.public_snapshot()["players"].values():
		if player["peer_id"] == peer_id:
			return player["player_instance_id"]
	return ""

func _binding_valid(actor_id: String) -> bool:
	if not actor_id in _actors.active_actor_ids():
		return false
	var record: Dictionary = _actors.actor_record(actor_id)
	var native: Dictionary = _space.actor_view(actor_id)
	return not native.is_empty() and native.get("layer_key") == Address.key(record["layer"]) and native.get("position") == State.vector(record["position"])

func _all_bindings_valid() -> bool:
	var expected: Array = []
	for player in _authority.public_snapshot()["players"].values():
		expected.append(player["player_instance_id"])
	expected.sort()
	if expected != _actors.active_actor_ids() or expected != _space.active_actor_ids():
		return false
	for actor_id in expected:
		if not _binding_valid(actor_id):
			return false
	return true

func _fatal(code: String) -> Dictionary:
	fatal_error = code
	shutdown_runtime()
	return {"ok": false, "code": code, "fatal": true, "recoverable_corruption": false}
