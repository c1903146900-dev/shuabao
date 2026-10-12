extends RefCounted
## Standalone server-owned candidate. No controller, RPC, save or owner wiring.
## prepare consumes one trusted fresh F admission. Pending/failed edges are never
## replayed. commit is NOT final success; confirm after the backend physics step.
const Address = preload("res://scripts/world/spatial_address.gd")
const State = preload("res://scripts/actor/actor_state.gd")
const Session = preload("res://scripts/actor/actor_session_state.gd")
const Selector = preload("res://scripts/actor/actor_interaction_selector.gd")
const MAX_GENERATION := 9007199254740991
var _authority: RefCounted
var _world: RefCounted
var _model: RefCounted
var _space: RefCounted
var _session: RefCounted
var _range: float = 0.0
var _half: float = 0.0
var _generation: int = 0
var _prepared: Dictionary = {}
var _confirmation: Dictionary = {}
var _attempted: Dictionary = {}
var fatal_error: String = ""

func _init(authority: RefCounted, world: RefCounted, model: RefCounted, space: RefCounted, inputs: RefCounted) -> void:
	_authority = authority
	_world = world
	_model = model
	_space = space
	if inputs != null and inputs.ready and world != null:
		_session = Session.new(world, inputs.document())
		_range = inputs.parameter("interaction_range_cells")
		_half = inputs.parameter("actor_diameter_cells") / 2.0

func prepare(actor_id: String, admission: Dictionary, cursor: Dictionary) -> Dictionary:
	# admission is the immediate trusted Motion.accept_input return; cursor is
	# captured beside it. Motion additionally verifies and consumes its internal
	# one-use receipt, binding the exact result to revision/cursor/input identity.
	if not fatal_error.is_empty():
		return _fatal(fatal_error)
	if _model == null or not _model.ready or not actor_id in _model.active_actor_ids():
		return _reject("TRANSFER_ACTOR_NOT_ACTIVE")
	var public: Dictionary = _model.public_snapshot()
	if not admission.get("ok", false) or admission.get("duplicate", false) or not admission.get("action") is Dictionary or not admission["action"].get("interaction_requested", false) or not admission.get("aim") is Vector2 or cursor != public["input_cursors"][actor_id] or admission["aim"] != State.vector(public["actors"][actor_id]["aim_position"]):
		return _reject("TRANSFER_FRESH_ADMISSION_REQUIRED")
	if _attempted.get(actor_id, {}) == cursor:
		return _reject("TRANSFER_ADMISSION_ALREADY_CONSUMED")
	var receipt: Dictionary = _model.consume_interaction_admission(actor_id, admission, cursor)
	if not receipt.get("ok", false):
		return receipt
	_attempted[actor_id] = cursor.duplicate(true)
	# Ordinary rejection never rewinds accepted_sequence or the already-held edge.
	if not _confirmation.is_empty():
		return _pending("TRANSFER_CONFIRMATION_PENDING")
	if not _prepared.is_empty():
		_cancel_prepared()
	var bound := _validate_context()
	if not bound["ok"]:
		return _phase_result(bound)
	if _generation < 0 or _generation >= MAX_GENERATION:
		return _reject("TRANSFER_GENERATION_EXHAUSTED")
	var record: Dictionary = _model.actor_record(actor_id)
	var selected := Selector.select_natural_entry(_world.public_component(), record["layer"], State.vector(record["position"]), admission["aim"], _range)
	if not selected["ok"]:
		return selected
	var candidate: Dictionary = selected["candidate"]
	var model: Dictionary = _model.prepare_layer_transfer(actor_id, candidate["destination_endpoint"]["layer"])
	if not model["ok"]:
		return model
	var native: Dictionary = _space.prepare_actor_transfer(actor_id, record["layer"], candidate["destination_endpoint"]["layer"], State.vector(record["position"]))
	if not native["ok"]:
		_model.cancel_prepared_layer_transfer(model["ticket"])
		return _phase_result(native)
	_generation += 1
	var ticket := {"owner_id": get_instance_id(), "generation": _generation}
	_prepared = {"ticket": ticket.duplicate(true), "actor_id": actor_id, "model_ticket": model["ticket"], "native_ticket": native["ticket"], "context": bound["context"], "candidate": candidate.duplicate(true), "aim": admission["aim"], "cursor": cursor.duplicate(true)}
	return {"ok": true, "prepared": true, "transferred": false, "save_ready": false, "ticket": ticket}

func validate(ticket: Variant) -> Dictionary:
	if not _matches(ticket, _prepared):
		return _reject("INVALID_TRANSFER_TICKET")
	var current := _validate_context()
	if not current["ok"]:
		return _phase_result(current)
	if current["context"] != _prepared["context"]:
		return _reject("STALE_TRANSFER_CONTEXT")
	var record: Dictionary = _model.actor_record(_prepared["actor_id"])
	var selected := Selector.select_natural_entry(_world.public_component(), record["layer"], State.vector(record["position"]), _prepared["aim"], _range)
	if not selected["ok"] or selected["candidate"] != _prepared["candidate"]:
		return _reject("STALE_TRANSFER_SELECTION")
	for checked in [_model.validate_prepared_layer_transfer(_prepared["model_ticket"]), _space.validate_prepared_actor_transfer(_prepared["native_ticket"])]:
		if not checked.get("ok", false):
			return _phase_result(checked)
	return {"ok": true}

func commit(ticket: Variant) -> Dictionary:
	var checked := validate(ticket)
	if not checked["ok"]:
		if _matches(ticket, _prepared):
			_cancel_prepared()
		return checked
	var transfer := _prepared.duplicate(true)
	var before: Dictionary = _model.persistent_state()
	# All capacity, staleness, shape, support, peer and actual source-space checks
	# precede the first write. No await/save/broadcast/callback occurs in this path.
	var native: Dictionary = _space.commit_prepared_actor_transfer(transfer["native_ticket"])
	if not native.get("ok", false):
		_cancel_prepared()
		return _fatal(native["code"]) if native.get("fatal", false) else native
	var model: Dictionary = _model.commit_prepared_layer_transfer(transfer["model_ticket"])
	if not model.get("ok", false):
		var restored: Dictionary = _space.rollback_actor_transfer(transfer["native_ticket"])
		_cancel_prepared()
		if not restored.get("ok", false) or _model.persistent_state() != before:
			return _fatal("TRANSFER_MODEL_FAILURE_ROLLBACK_UNPROVED")
		return {"ok": false, "code": "TRANSFER_MODEL_COMMIT_REJECTED", "restored": true, "transferred": false, "save_ready": false}
	_prepared.clear()
	transfer["expected_model"] = _model.persistent_state()
	transfer["expected_public"] = _model.public_snapshot()
	transfer["submitted_frame"] = Engine.get_physics_frames()
	_confirmation = transfer
	return _pending("TRANSFER_BACKEND_CONFIRMATION_PENDING", true)

func confirm(ticket: Variant) -> Dictionary:
	if not fatal_error.is_empty():
		return _fatal(fatal_error)
	if not _matches(ticket, _confirmation):
		return _reject("INVALID_TRANSFER_CONFIRMATION_TICKET")
	if Engine.get_physics_frames() <= _confirmation["submitted_frame"]:
		return _pending("TRANSFER_BACKEND_CONFIRMATION_PENDING", true)
	# No intervening actor/input/world update is allowed inside this standalone
	# observation boundary. A future owner must implement its publication gate.
	if _model.persistent_state() != _confirmation["expected_model"] or _model.public_snapshot() != _confirmation["expected_public"]:
		return _fatal("TRANSFER_CONFIRMATION_MODEL_CHANGED")
	var current := _validate_context()
	if not current.get("ok", false):
		return _fatal("TRANSFER_CONFIRMATION_BINDING_FAILED")
	for field in ["authority", "terrain"]:
		if current["context"][field] != _confirmation["context"][field]:
			return _fatal("TRANSFER_CONFIRMATION_CONTEXT_CHANGED")
	var finished: Dictionary = _space.finish_actor_transfer(_confirmation["native_ticket"])
	if not finished.get("ok", false):
		return _fatal(str(finished.get("code", "TRANSFER_CONFIRMATION_FAILED")))
	var actor_id: String = _confirmation["actor_id"]
	_confirmation.clear()
	return {"ok": true, "transferred": true, "pending": false, "save_ready": true, "actor_id": actor_id}

func cancel(ticket: Variant) -> Dictionary:
	if not _matches(ticket, _prepared):
		return _reject("INVALID_TRANSFER_TICKET")
	_cancel_prepared()
	return {"ok": true, "cancelled": true, "transferred": false}

func status() -> Dictionary:
	var applied: Dictionary = _space.validate_applied_actor_targets() if _space != null else {"ok": false}
	var native_pending: bool = applied.get("code") == "NATIVE_TARGET_PHYSICS_STEP_PENDING"
	return {"pending": not _confirmation.is_empty() or native_pending, "prepared": not _prepared.is_empty(), "fatal": not fatal_error.is_empty(), "save_ready": _prepared.is_empty() and _confirmation.is_empty() and fatal_error.is_empty() and applied.get("ok", false)}

func _validate_context() -> Dictionary:
	if _authority == null or _world == null or not _world.ready or _model == null or not _model.ready or _space == null or _session == null or not _session.ready or not _space.has_method("transfer_context"):
		return _reject("TRANSFER_CONTEXT_NOT_READY")
	if _authority.world_seconds != _model.clock_seconds():
		return _reject("TRANSFER_AUTHORITY_CLOCK_MISMATCH")
	var combined: Dictionary = _session.combine(_authority.persistent_state(), _model)
	if not combined.get("ok", false):
		return combined
	var public: Dictionary = _authority.public_snapshot()
	var expected: Array = []
	for player in public["players"].values():
		expected.append(player["player_instance_id"])
	expected.sort()
	if expected != _model.active_actor_ids() or expected != _space.active_actor_ids():
		return _reject("TRANSFER_ACTOR_BINDING_MISMATCH")
	for actor_id in expected:
		var record: Dictionary = _model.actor_record(actor_id)
		var native: Dictionary = _space.actor_view(actor_id)
		if native.get("layer_key") != Address.key(record["layer"]) or native.get("position") != State.vector(record["position"]) or native.get("half_extent") != _half:
			return _reject("TRANSFER_ACTOR_BINDING_MISMATCH")
	var applied: Dictionary = _space.validate_applied_actor_targets()
	if not applied.get("ok", false):
		return applied
	var terrain: Dictionary = _space.transfer_context(_world)
	if not terrain.get("ok", false):
		return terrain
	return {"ok": true, "context": {"authority": public, "model": _model.persistent_state(), "public": _model.public_snapshot(), "terrain": terrain}}

func _cancel_prepared() -> void:
	if _prepared.is_empty():
		return
	_model.cancel_prepared_layer_transfer(_prepared["model_ticket"])
	_space.cancel_prepared_actor_transfer(_prepared["native_ticket"])
	_prepared.clear()

func _matches(ticket: Variant, prepared: Dictionary) -> bool:
	return ticket is Dictionary and ticket.size() == 2 and typeof(ticket.get("owner_id")) == TYPE_INT and typeof(ticket.get("generation")) == TYPE_INT and not prepared.is_empty() and ticket == prepared["ticket"]

func _phase_result(result: Dictionary) -> Dictionary:
	return _pending(result["code"]) if result.get("code") == "NATIVE_TARGET_PHYSICS_STEP_PENDING" else result

func _pending(code: String, committed: bool = false) -> Dictionary:
	return {"ok": false, "code": code, "pending": true, "committed": committed, "transferred": false, "save_ready": false}

func _fatal(code: String) -> Dictionary:
	# Mandatory caller contract: stop controller/owner, do not save or broadcast.
	# A nested interaction.fatal alone is insufficient for the current network owner.
	fatal_error = code
	return {"ok": false, "code": code, "fatal": true, "transferred": false, "save_ready": false}

func _reject(code: String) -> Dictionary:
	return {"ok": false, "code": code, "transferred": false}
