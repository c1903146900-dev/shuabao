extends RefCounted
## Pure server service. Native world/layer collision resolution belongs to its caller.
## accept_input is an action transaction at the CURRENT authority time. Starting a
## dodge commits its cost/cooldown there. A later failed tick cannot refund it.
## Every tick is separately previewed and committed as one all-actor transaction.
const Inputs = preload("res://scripts/actor/actor_inputs.gd")
const State = preload("res://scripts/actor/actor_state.gd")
const InputState = preload("res://scripts/actor/actor_input_state.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const SNAPSHOT_FIELDS := ["schema_version", "project", "artifact_kind", "source_identity", "world_id", "clock", "revision", "actors"]
const MAX_REVISION := 9007199254740991
const RESOLVER_DISTANCE_TOLERANCE := 0.00001 # Vector2 arithmetic only, not free movement.
var ready: bool = false
var last_error: String = ""
var _settings: RefCounted
var _world_id: String = ""
var _clock: float = 0.0
var _revision: int = 0
var _actors: Dictionary = {}
var _active: Dictionary = {}
var _inputs: Dictionary = {}
# Runtime-only activation identity. The owner scopes this revision-derived value
# by server epoch/world/profile/actor/peer; it is never a persistent save field.
var _input_generations: Dictionary = {}
var _preview: Dictionary = {}
var _preview_candidates: Dictionary = {}
var _preview_serial: int = 0
# Server-only identity/presence preparation. Never persisted or published.
var _presence_generation: int = 0
var _prepared_presence: Dictionary = {}
var _transfer_generation: int = 0
var _prepared_transfer: Dictionary = {}
var _interaction_receipts: Dictionary = {}

func _init(world_id: String = "", input_document: Dictionary = {}, initial_clock: float = 0.0) -> void:
	if world_id.is_empty():
		return
	configure(world_id, input_document, initial_clock)

func configure(world_id: String, input_document: Dictionary, initial_clock: float = 0.0) -> Dictionary:
	if ready or not _actors.is_empty():
		return State.error("ALREADY_CONFIGURED", "request")
	var settings := Inputs.new()
	if not SandboxServerAuthority._valid_id(world_id, "world_") or not State.valid_clock(initial_clock) or not settings.load_document(input_document):
		last_error = "INVALID_ACTOR_CONFIGURATION: " + settings.last_error
		return State.error("INVALID_ACTOR_CONFIGURATION", "request")
	_settings = settings
	_world_id = world_id
	_clock = initial_clock
	ready = true
	return {"ok": true}

func clock_seconds() -> float:
	return _clock

func create_actor(actor_id: String, layer: Dictionary, position: Vector2, fallback: Dictionary) -> Dictionary:
	if _revision >= MAX_REVISION:
		return State.error("ACTOR_REVISION_EXHAUSTED", "request")
	if not ready or _actors.has(actor_id) or layer.get("world_id") != _world_id:
		return State.error("INVALID_OR_DUPLICATE_ACTOR", "request")
	var created := State.create(actor_id, layer, position, fallback, _clock, _settings)
	if not created["ok"]:
		return created
	_actors[actor_id] = created["record"]
	_touch()
	return {"ok": true}

func activation_candidate(actor_id: String) -> Dictionary:
	if not ready or not _actors.has(actor_id) or _active.has(actor_id):
		return State.error("ACTOR_NOT_INACTIVE", "request")
	return {"ok": true, "record": State.persistent_record(_actors[actor_id]), "offline_elapsed": _clock - float(_actors[actor_id]["updated_at"])}

func activate(actor_id: String, layer: Dictionary, position: Vector2) -> Dictionary:
	if _revision >= MAX_REVISION:
		return State.error("ACTOR_REVISION_EXHAUSTED", "request")
	# Call ONLY after authentication and native full-body location validation.
	# 011 provisional offline-resource boundary: no inactive loss or gain. Absolute
	# action deadlines keep their original server-clock values; see State.resume_resources.
	var check := activation_candidate(actor_id)
	if not check["ok"]:
		return check
	var candidate: Dictionary = check["record"]
	if check["offline_elapsed"] > 0.0:
		candidate = State.resume_resources(candidate, _clock, _settings)
	candidate["layer"] = layer.duplicate(true)
	candidate["position"] = State.pair(position)
	var checked := State.validate(candidate, _settings, _world_id, _clock)
	if not checked["ok"]:
		return checked
	_actors[actor_id] = candidate
	_active[actor_id] = true
	_inputs[actor_id] = InputState.new()
	_touch()
	_input_generations[actor_id] = _revision
	return {"ok": true}

func deactivate(actor_id: String) -> Dictionary:
	if _revision >= MAX_REVISION:
		return State.error("ACTOR_REVISION_EXHAUSTED", "request")
	if not ready or not _actors.has(actor_id):
		return State.error("UNKNOWN_ACTOR", "request")
	_active.erase(actor_id)
	_inputs.erase(actor_id)
	_input_generations.erase(actor_id)
	_touch()
	return {"ok": true}

func prepare_presence(actor_id: String, layer: Dictionary, position: Vector2, fallback: Dictionary = {}) -> Dictionary:
	# This is a model-only preparation, not authentication or native position approval.
	# Failed preparations preserve an earlier successful candidate and all live state.
	if not ready:
		return State.error("ACTOR_PRESENCE_NOT_READY", "request")
	if _active.has(actor_id) or _inputs.has(actor_id):
		return State.error("ACTOR_NOT_INACTIVE", "request")
	var is_new := not _actors.has(actor_id)
	if not is_new and not fallback.is_empty():
		return State.error("ACTOR_PRESENCE_FALLBACK_OVERRIDE", "request")
	var revision_increment: int = 2 if is_new else 1
	if _revision < 0 or _revision > MAX_REVISION - revision_increment:
		return State.error("ACTOR_REVISION_EXHAUSTED", "request")
	if _presence_generation < 0 or _presence_generation >= MAX_REVISION:
		return State.error("ACTOR_PRESENCE_GENERATION_EXHAUSTED", "request")
	# A separate Motion owns only copied persistent records. In particular, no other
	# live actor's active flag, input latch or prepared movement is copied or modified.
	var candidate: RefCounted = get_script().new(_world_id, _settings.document(), _clock)
	if not candidate.ready:
		return State.error("ACTOR_PRESENCE_CLONE_INVALID", "request")
	var restored: Dictionary = candidate.restore_persistent_state(persistent_state())
	if not restored["ok"]:
		return restored
	if is_new:
		var created: Dictionary = candidate.create_actor(actor_id, layer, position, fallback)
		if not created["ok"]:
			return created
	var activated: Dictionary = candidate.activate(actor_id, layer, position)
	if not activated["ok"]:
		return activated
	var record: Dictionary = candidate.actor_record(actor_id)
	if candidate._revision != _revision + revision_increment:
		return State.error("ACTOR_PRESENCE_REVISION_MISMATCH", "request")
	_presence_generation += 1
	var ticket := {"owner_id": get_instance_id(), "generation": _presence_generation}
	_prepared_presence = {
		"ticket": ticket.duplicate(true), "context": _presence_context(),
		"actor_id": actor_id, "is_new": is_new,
		"revision_increment": revision_increment, "record": record.duplicate(true),
	}
	return {"ok": true, "ticket": ticket, "actor_id": actor_id, "layer": record["layer"].duplicate(true), "position": position, "is_new": is_new}

func validate_prepared_presence(ticket: Variant) -> Dictionary:
	if not ready or not _matches_presence_ticket(ticket):
		return State.error("INVALID_PRESENCE_TICKET", "request")
	if _prepared_presence["context"] != _presence_context():
		return State.error("STALE_PRESENCE_TICKET", "request")
	var actor_id: String = _prepared_presence["actor_id"]
	var is_new: bool = _prepared_presence["is_new"]
	if _active.has(actor_id) or _inputs.has(actor_id) or _actors.has(actor_id) == is_new:
		return State.error("ACTOR_PRESENCE_CONFLICT", "request")
	var revision_increment: int = 2 if is_new else 1
	if _prepared_presence["revision_increment"] != revision_increment or _revision < 0 or _revision > MAX_REVISION - revision_increment:
		return State.error("ACTOR_REVISION_EXHAUSTED", "request")
	var record: Variant = _prepared_presence.get("record")
	var checked := State.validate(record, _settings, _world_id, _clock)
	if not checked["ok"]:
		return checked
	if record["actor_id"] != actor_id or record["updated_at"] != _clock:
		return State.error("ACTOR_PRESENCE_RECORD_MISMATCH", "request")
	return {"ok": true}

func commit_prepared_presence(ticket: Variant) -> Dictionary:
	var checked := validate_prepared_presence(ticket)
	if not checked["ok"]:
		return checked
	# All checks precede this synchronous write set; no await, callbacks or native
	# operations here. Other actors and their InputState objects retain their identity.
	var actor_id: String = _prepared_presence["actor_id"]
	var is_new: bool = _prepared_presence["is_new"]
	var revision_increment: int = _prepared_presence["revision_increment"]
	var record: Dictionary = _prepared_presence["record"].duplicate(true)
	var input := InputState.new()
	_actors[actor_id] = record
	_active[actor_id] = true
	_inputs[actor_id] = input
	_revision += revision_increment - 1
	_touch() # Adds the final reserved revision and clears both pending mechanisms.
	_input_generations[actor_id] = _revision
	return {"ok": true, "actor_id": actor_id, "is_new": is_new}

func cancel_prepared_presence(ticket: Variant) -> Dictionary:
	if not _matches_presence_ticket(ticket):
		return State.error("INVALID_PRESENCE_TICKET", "request")
	_prepared_presence.clear()
	return {"ok": true}

func prepared_presence_effect(ticket: Variant) -> Dictionary:
	var checked := validate_prepared_presence(ticket)
	return {"ok": true, "effect": _prepared_presence.duplicate(true)} if checked["ok"] else checked

func _matches_presence_ticket(ticket: Variant) -> bool:
	if not ticket is Dictionary or ticket.size() != 2 or typeof(ticket.get("owner_id")) != TYPE_INT or typeof(ticket.get("generation")) != TYPE_INT:
		return false
	if ticket["owner_id"] != get_instance_id() or ticket["generation"] < 1 or ticket["generation"] > MAX_REVISION:
		return false
	return not _prepared_presence.is_empty() and ticket == _prepared_presence["ticket"]

func _presence_context() -> Dictionary:
	return {"revision": _revision, "world_id": _world_id, "clock": _clock}

# Dedicated active-layer transaction. Presence, input and resource APIs are not reused.
func prepare_layer_transfer(actor_id: String, destination: Dictionary) -> Dictionary:
	if not ready or not _active.has(actor_id) or not _inputs.has(actor_id) or not _input_generations.has(actor_id):
		return State.error("TRANSFER_ACTOR_NOT_ACTIVE", "request")
	if _revision < 0 or _revision >= MAX_REVISION or _transfer_generation < 0 or _transfer_generation >= MAX_REVISION:
		return State.error("TRANSFER_MODEL_REVISION_EXHAUSTED", "request")
	var source: Dictionary = _actors[actor_id]
	if not Address.valid_layer(destination) or destination["world_id"] != _world_id or destination["body_instance_id"] != source["layer"]["body_instance_id"] or destination == source["layer"]:
		return State.error("TRANSFER_MODEL_LAYER_INVALID", "request")
	var candidate: Dictionary = source.duplicate(true)
	candidate["layer"] = destination.duplicate(true)
	var checked := State.validate(candidate, _settings, _world_id, _clock)
	if not checked["ok"]:
		return checked
	_transfer_generation += 1
	var ticket := {"owner_id": get_instance_id(), "generation": _transfer_generation}
	_prepared_transfer = {"ticket": ticket.duplicate(true), "actor_id": actor_id, "context": _presence_context(), "source": source.duplicate(true), "input": _transfer_input_context(actor_id), "record": candidate}
	return {"ok": true, "ticket": ticket}

func validate_prepared_layer_transfer(ticket: Variant) -> Dictionary:
	if not ready or not _matches_transfer_ticket(ticket):
		return State.error("INVALID_MODEL_TRANSFER_TICKET", "request")
	var actor_id: String = _prepared_transfer["actor_id"]
	if _prepared_transfer["context"] != _presence_context() or not _active.has(actor_id) or not _actors.has(actor_id) or _actors[actor_id] != _prepared_transfer["source"] or _transfer_input_context(actor_id) != _prepared_transfer["input"]:
		return State.error("STALE_MODEL_TRANSFER_TICKET", "request")
	if _revision < 0 or _revision >= MAX_REVISION:
		return State.error("TRANSFER_MODEL_REVISION_EXHAUSTED", "request")
	var expected: Dictionary = _prepared_transfer["source"].duplicate(true)
	expected["layer"] = _prepared_transfer["record"]["layer"].duplicate(true)
	if expected != _prepared_transfer["record"]:
		return State.error("TRANSFER_MODEL_RECORD_CHANGED", "request")
	return State.validate(_prepared_transfer["record"], _settings, _world_id, _clock)

func commit_prepared_layer_transfer(ticket: Variant) -> Dictionary:
	var checked := validate_prepared_layer_transfer(ticket)
	if not checked["ok"]:
		return checked
	var actor_id: String = _prepared_transfer["actor_id"]
	# No new InputState, generation, fallback, anchor, position or deadline.
	_actors[actor_id] = _prepared_transfer["record"].duplicate(true)
	_touch()
	return {"ok": true, "actor_id": actor_id}

func cancel_prepared_layer_transfer(ticket: Variant) -> Dictionary:
	if not _matches_transfer_ticket(ticket):
		return State.error("INVALID_MODEL_TRANSFER_TICKET", "request")
	_prepared_transfer.clear()
	return {"ok": true}

func _matches_transfer_ticket(ticket: Variant) -> bool:
	return ticket is Dictionary and ticket.size() == 2 and typeof(ticket.get("owner_id")) == TYPE_INT and typeof(ticket.get("generation")) == TYPE_INT and not _prepared_transfer.is_empty() and ticket == _prepared_transfer["ticket"]

func _transfer_input_context(actor_id: String) -> Dictionary:
	if not _inputs.has(actor_id) or not _input_generations.has(actor_id):
		return {}
	var input: RefCounted = _inputs[actor_id]
	return {"identity": input.get_instance_id(), "generation": _input_generations[actor_id], "sequence": input.sequence, "fingerprint": input.fingerprint, "move": input.move_direction, "aim": input.aim, "pressed": input.pressed_action, "held": input.held.duplicate(true)}

func frame_projection(source_lease: RefCounted = null) -> RefCounted:
	# Detached proof model only. Never restore this object into a live session.
	# Runtime input VALUES are copied; the live InputState identities are untouched.
	var projection: RefCounted
	if source_lease != null:
		var approved: Dictionary = source_lease.projection_settings(self)
		if not approved.get("ok", false):
			return null
		projection = get_script().new()
		projection._settings = approved["settings"]
		projection._world_id = _world_id
		projection._clock = _clock
		projection.ready = true
	else:
		projection = get_script().new(_world_id, _settings.document(), _clock)
	projection._actors = _actors.duplicate(true)
	projection._active = _active.duplicate(true)
	projection._input_generations = _input_generations.duplicate(true)
	projection._revision = _revision
	projection._preview_serial = _preview_serial
	projection._transfer_generation = _transfer_generation
	for actor_id in _inputs:
		projection._inputs[actor_id] = _copy_input(_inputs[actor_id])
	return projection

func frame_input_state(with_identity: bool = true) -> Dictionary:
	var result: Dictionary = {}
	for actor_id in active_actor_ids():
		result[actor_id] = _transfer_input_context(actor_id)
		if not with_identity:
			result[actor_id].erase("identity")
	return result

func active_actor_ids() -> Array:
	var ids := _active.keys()
	ids.sort()
	return ids

func actor_record(actor_id: String) -> Dictionary:
	return State.persistent_record(_actors[actor_id]) if _actors.has(actor_id) else {}

func public_snapshot() -> Dictionary:
	var actors: Dictionary = {}
	var input_cursors: Dictionary = {}
	for actor_id in active_actor_ids():
		actors[actor_id] = State.public_record(_actors[actor_id], _clock)
		actors[actor_id]["aim_position"] = State.pair(_inputs[actor_id].aim)
		actors[actor_id]["last_valid_move"] = _actors[actor_id]["last_valid_move"].duplicate()
		# Read the committed latch beside the same committed actor/clock/revision.
		# This cursor covers admitted intent, not per-command movement integration
		# or action success. Rejected action edges may still advance the latch.
		input_cursors[actor_id] = {"input_generation": _input_generations[actor_id], "accepted_sequence": _inputs[actor_id].sequence}
	return {"world_id": _world_id, "clock": _clock, "revision": _revision, "actors": actors, "input_cursors": input_cursors}

func accept_input(actor_id: String, request: Variant) -> Dictionary:
	if _revision >= MAX_REVISION:
		return State.error("ACTOR_REVISION_EXHAUSTED", "request")
	if not ready or not _active.has(actor_id):
		return State.error("ACTOR_NOT_ACTIVE", "request")
	# A duplicate/rejected/newer envelope cannot leave an old F receipt usable.
	_interaction_receipts.erase(actor_id)
	var latch := _copy_input(_inputs[actor_id])
	var accepted: Dictionary = latch.accept(request)
	if not accepted["ok"] or accepted.get("duplicate", false):
		return accepted
	var candidate: Dictionary = _actors[actor_id].duplicate(true)
	if _walk_allowed(candidate, _clock) and latch.move_direction != Vector2.ZERO:
		candidate["last_valid_move"] = State.pair(latch.move_direction)
	var action_result := {"ok": true, "dodge_started": false, "interaction_requested": false}
	if latch.pressed_action == "dodge":
		action_result = _start_dodge(candidate)
	elif latch.pressed_action == "interact":
		action_result = {"ok": candidate["health"] > 0.0, "interaction_requested": candidate["health"] > 0.0, "code": "" if candidate["health"] > 0.0 else "ACTOR_DEAD"}
	# A rejected edge is consumed, including while controlled. Never queue it for later.
	latch.pressed_action = ""
	var validated := State.validate(candidate, _settings, _world_id, _clock)
	if not validated["ok"]:
		return validated
	_actors[actor_id] = candidate
	_inputs[actor_id] = latch
	_touch()
	var result := {"ok": true, "duplicate": false, "action": action_result, "aim": latch.aim}
	if action_result.get("interaction_requested", false):
		_interaction_receipts[actor_id] = {"revision": _revision, "cursor": {"input_generation": _input_generations[actor_id], "accepted_sequence": latch.sequence}, "input": _transfer_input_context(actor_id), "admission": result.duplicate(true)}
	return result

func consume_interaction_admission(actor_id: String, admission: Dictionary, cursor: Dictionary) -> Dictionary:
	# One-use model-issued proof; never a client/wire field. External admission
	# dictionaries alone cannot authorize a stale edge paired with a newer cursor.
	if not ready or not _active.has(actor_id) or not _interaction_receipts.has(actor_id):
		return State.error("TRANSFER_FRESH_ADMISSION_REQUIRED", "request")
	var receipt: Dictionary = _interaction_receipts[actor_id]
	if receipt["revision"] != _revision or receipt["cursor"] != cursor or receipt["admission"] != admission or receipt["input"] != _transfer_input_context(actor_id):
		return State.error("TRANSFER_FRESH_ADMISSION_REQUIRED", "request")
	_interaction_receipts.erase(actor_id)
	return {"ok": true}

func can_interact(actor_id: String) -> bool:
	return ready and _active.has(actor_id) and _actors[actor_id]["health"] > 0.0

func set_control(actor_id: String, rooted_until: float, hit_feedback_until: float) -> Dictionary:
	if _revision >= MAX_REVISION:
		return State.error("ACTOR_REVISION_EXHAUSTED", "request")
	# Server-only control input; never accepted in the client envelope.
	if not ready or not _active.has(actor_id) or not State.valid_clock(rooted_until) or not State.valid_clock(hit_feedback_until):
		return State.error("INVALID_CONTROL", "request")
	var candidate: Dictionary = _actors[actor_id].duplicate(true)
	candidate["rooted_until"] = rooted_until
	candidate["hit_feedback_until"] = hit_feedback_until
	var validated := State.validate(candidate, _settings, _world_id, _clock)
	if not validated["ok"]:
		return validated
	_actors[actor_id] = candidate
	_touch()
	return {"ok": true}

func preview_tick(delta: float) -> Dictionary:
	if not ready or not State.valid_clock(_clock) or not is_finite(delta) or delta <= 0.0 or not State.valid_clock(_clock + delta) or _clock + delta <= _clock:
		return State.error("INVALID_OR_IMPRECISE_TICK_CLOCK", "request")
	if _active.is_empty():
		return {"ok": true, "paused": true, "from": _clock, "to": _clock, "actors": {}}
	if _revision >= MAX_REVISION:
		return State.error("ACTOR_REVISION_EXHAUSTED", "request")
	var end := _clock + delta
	var candidates: Dictionary = {}
	var motions: Dictionary = {}
	for actor_id in active_actor_ids():
		var record: Dictionary = _actors[actor_id]
		var checked := State.validate(record, _settings, _world_id, _clock)
		if not checked["ok"] or record["updated_at"] != _clock:
			return State.error("ACTOR_NOT_AT_TICK_START")
		var trajectory := _trajectory(record, _inputs[actor_id], _clock, end)
		var candidate := State.advance(record, end, _settings)
		candidate["last_valid_move"] = trajectory["last_valid_move"]
		checked = State.validate(candidate, _settings, _world_id, end)
		if not checked["ok"]:
			return checked
		candidates[actor_id] = candidate
		var dodge_end_at: Variant = null
		if record["dodge_started_at"] >= 0.0 and record["dodge_until"] > _clock:
			var actual_end: float = minf(float(record["dodge_until"]), float(State.resources_at(record, end, _settings)["death_at"]))
			if actual_end > _clock and actual_end < end:
				dodge_end_at = actual_end
		motions[actor_id] = {
			"actor_id": actor_id, "layer": record["layer"].duplicate(true), "position": State.vector(record["position"]),
			"half_extent": _settings.parameter("actor_diameter_cells") / 2.0,
			"segments": trajectory["segments"], "requested_motion": trajectory["requested_motion"], "maximum_distance": trajectory["maximum_distance"], "dodge_end_at": dodge_end_at,
		}
	_preview_serial += 1
	_preview = {"ok": true, "paused": false, "serial": _preview_serial, "revision": _revision, "from": _clock, "to": end, "actors": motions}
	_preview_candidates = candidates
	return _preview.duplicate(true)

func commit_preview(preview: Dictionary, resolved: Variant) -> Dictionary:
	if _revision >= MAX_REVISION:
		return State.error("ACTOR_REVISION_EXHAUSTED", "request")
	# Resolved shape: {actor_id: {layer: full logical layer, position: Vector2}}.
	# A dodge crossing its end within this tick additionally needs dodge_end_position,
	# the resolver's actual position at that boundary, to avoid including later walk.
	if not ready or _preview.is_empty() or preview != _preview or preview["revision"] != _revision or preview["from"] != _clock:
		return State.error("STALE_OR_CHANGED_PREVIEW", "request")
	if not resolved is Dictionary or resolved.size() != _active.size():
		return State.error("RESOLVER_ACTOR_SET_MISMATCH", "resolver")
	var candidates := _preview_candidates.duplicate(true)
	for actor_id in active_actor_ids():
		if not resolved.has(actor_id):
			return State.error("RESOLVER_ACTOR_SET_MISMATCH", "resolver")
		var result: Variant = resolved[actor_id]
		var motion: Dictionary = _preview["actors"][actor_id]
		var before: Dictionary = _actors[actor_id]
		if not result is Dictionary or not result.get("position") is Vector2 or not result["position"].is_finite() or result.get("layer") != motion["layer"] or not Address.valid_layer(result.get("layer")):
			return State.error("INVALID_RESOLVER_POSITION_OR_LAYER", "resolver")
		for field in result:
			if field not in ["layer", "position", "dodge_end_position"]:
				return State.error("UNKNOWN_RESOLVER_FIELD", "resolver")
		if motion["position"].distance_to(result["position"]) > float(motion["maximum_distance"]) + RESOLVER_DISTANCE_TOLERANCE:
			return State.error("RESOLVER_MOVEMENT_EXCEEDS_BUDGET", "resolver")
		candidates[actor_id]["position"] = State.pair(result["position"])
		if before["dodge_started_at"] >= 0.0 and before["dodge_until"] > _clock:
			var dodge_end: float = minf(float(before["dodge_until"]), float(State.resources_at(before, float(preview["to"]), _settings)["death_at"]))
			if motion["dodge_end_at"] != null:
				dodge_end = float(motion["dodge_end_at"])
				if not result.get("dodge_end_position") is Vector2 or not result["dodge_end_position"].is_finite():
					return State.error("RESOLVER_DODGE_BOUNDARY_REQUIRED", "resolver")
				var budget := _distance_until(motion["segments"], dodge_end)
				if motion["position"].distance_to(result["dodge_end_position"]) > budget + RESOLVER_DISTANCE_TOLERANCE or result["dodge_end_position"].distance_to(result["position"]) > float(motion["maximum_distance"]) - budget + RESOLVER_DISTANCE_TOLERANCE:
					return State.error("RESOLVER_DODGE_BOUNDARY_EXCEEDS_BUDGET", "resolver")
				candidates[actor_id]["dodge_last_position"] = State.pair(result["dodge_end_position"])
			elif dodge_end > _clock:
				candidates[actor_id]["dodge_last_position"] = State.pair(result["position"])
		var checked := State.validate(candidates[actor_id], _settings, _world_id, float(preview["to"]))
		if not checked["ok"]:
			return checked
	# No actor, timer, input, resource or authority clock changed before this point.
	for actor_id in candidates:
		_actors[actor_id] = candidates[actor_id]
	_clock = float(preview["to"])
	_touch()
	return {"ok": true, "clock": _clock}

func tick(delta: float, resolver: Callable) -> Dictionary:
	if not resolver.is_valid():
		return State.error("RESOLVER_REQUIRED", "resolver")
	var preview := preview_tick(delta)
	if not preview["ok"] or preview.get("paused", false):
		return preview
	# Do not retain a resolver reference or expose live candidate records.
	var result: Variant = resolver.call(preview.duplicate(true))
	if not result is Dictionary or not result.get("ok", false) or not result.get("positions") is Dictionary:
		return State.error("RESOLVER_FAILED", "resolver")
	return commit_preview(preview, result["positions"])

func dodge_visual_direction(actor_id: String) -> Dictionary:
	if not ready or not _active.has(actor_id) or _actors[actor_id]["dodge_started_at"] < 0.0:
		return State.error("NO_ACTIVE_DODGE_HISTORY", "request")
	var record: Dictionary = _actors[actor_id]
	var actual := State.vector(record["dodge_last_position"]) - State.vector(record["dodge_start_position"])
	if actual != Vector2.ZERO:
		return {"ok": true, "direction": actual.normalized(), "origin": "actual_displacement"}
	# Aim is ephemeral connection input, never a persistent credential/state field.
	var mouse_direction: Vector2 = _inputs[actor_id].aim - State.vector(record["position"])
	return {"ok": true, "direction": mouse_direction.normalized(), "origin": "mouse_for_zero_displacement"}

func persistent_json() -> String:
	# Explicit exact-codec tree; restore requires decoding, not raw JSON numbers.
	var encoded: Dictionary = preload("res://scripts/save/exact_scalar_codec.gd").encode(persistent_state())
	return JSON.stringify(encoded["value"], "", true, true) if encoded.get("ok", false) else ""

func persistent_state() -> Dictionary:
	var actors: Dictionary = {}
	for actor_id in _actors:
		actors[actor_id] = State.persistent_record(_actors[actor_id])
	return {"schema_version": 1, "project": Inputs.PROJECT, "artifact_kind": "actor_state_011", "source_identity": _settings.source_identity() if ready else {}, "world_id": _world_id, "clock": _clock, "revision": _revision, "actors": actors}

func validate_persistent_state(value: Variant) -> Dictionary:
	if not ready or not value is Dictionary:
		return State.error("INVALID_ACTOR_SNAPSHOT")
	# Compatibility is checked BEFORE corruption/backup decisions. Never automatically
	# fall back to an old save on an unknown schema or changed formal source contract.
	if not Inputs.integer(value.get("schema_version")) or int(value["schema_version"]) != 1 or value.get("project") != Inputs.PROJECT or value.get("artifact_kind") != "actor_state_011":
		return State.error("ACTOR_SNAPSHOT_INCOMPATIBLE_SCHEMA", "incompatible")
	if value.get("source_identity") != _settings.source_identity():
		return State.error("ACTOR_SNAPSHOT_INCOMPATIBLE_SOURCE", "incompatible")
	for field in value:
		if field not in SNAPSHOT_FIELDS:
			return State.error("ACTOR_SNAPSHOT_INCOMPATIBLE_FIELDS", "incompatible")
	if not State.exact_fields(value, SNAPSHOT_FIELDS) or value["world_id"] != _world_id or not State.valid_clock(value["clock"]) or not Inputs.integer(value["revision"]) or value["revision"] < 0 or not value["actors"] is Dictionary:
		return State.error("INVALID_ACTOR_SNAPSHOT")
	for actor_id in value["actors"]:
		var record: Variant = value["actors"][actor_id]
		if not actor_id is String or not record is Dictionary or record.get("actor_id") != actor_id:
			return State.error("ACTOR_SNAPSHOT_KEY_MISMATCH")
		var checked := State.validate(record, _settings, _world_id, float(value["clock"]))
		if not checked["ok"]:
			return checked
	return {"ok": true}

func restore_persistent_state(value: Variant) -> Dictionary:
	# Production owner uses a fresh Motion before listening, under a new server
	# epoch. This is not a live same-epoch rollback API: activation generations
	# derive from revisions and must not be reused by rewinding a running session.
	var checked := validate_persistent_state(value)
	if not checked["ok"]:
		return checked
	_actors = value["actors"].duplicate(true)
	_clock = float(value["clock"])
	_revision = int(value["revision"])
	_active.clear()
	_inputs.clear()
	_input_generations.clear()
	_preview.clear()
	_preview_candidates.clear()
	_prepared_presence.clear() # Do not reset the monotonic generation on restore.
	_prepared_transfer.clear()
	_interaction_receipts.clear()
	return {"ok": true}

func _start_dodge(candidate: Dictionary) -> Dictionary:
	if candidate["health"] <= 0.0:
		return {"ok": false, "code": "ACTOR_DEAD", "dodge_started": false}
	if (_settings.flag("rooted_blocks_dodge") and _clock < candidate["rooted_until"]) or _clock < candidate["hit_feedback_until"]:
		return {"ok": false, "code": "ACTOR_CONTROLLED", "dodge_started": false}
	if _clock < candidate["dodge_cooldown_until"] or _clock < candidate["dodge_until"]:
		return {"ok": false, "code": "DODGE_COOLDOWN", "dodge_started": false}
	if candidate["energy"] < _settings.parameter("dodge_energy_cost"):
		return {"ok": false, "code": "INSUFFICIENT_ENERGY", "dodge_started": false}
	if State.vector(candidate["last_valid_move"]) == Vector2.ZERO:
		return {"ok": false, "code": "NO_MOVEMENT_HISTORY", "dodge_started": false}
	for key in ["dodge_duration_seconds", "dodge_invulnerability_seconds", "dodge_cooldown_seconds", "energy_regeneration_delay_seconds"]:
		if not State.valid_clock(_clock + _settings.parameter(key)):
			return {"ok": false, "code": "IMPRECISE_ACTION_CLOCK", "dodge_started": false}
	var cost: float = _settings.parameter("dodge_energy_cost")
	if cost > 0.0:
		candidate["energy"] -= cost
		candidate["energy_anchor_value"] = candidate["energy"]
		candidate["last_consumption_at"] = _clock
		candidate["energy_anchor_at"] = _clock + _settings.parameter("energy_regeneration_delay_seconds")
	candidate["dodge_started_at"] = _clock
	candidate["dodge_until"] = _clock + _settings.parameter("dodge_duration_seconds")
	candidate["invulnerable_until"] = _clock + _settings.parameter("dodge_invulnerability_seconds")
	candidate["dodge_cooldown_until"] = _clock + _settings.parameter("dodge_cooldown_seconds")
	candidate["dodge_direction"] = candidate["last_valid_move"].duplicate()
	candidate["dodge_start_position"] = candidate["position"].duplicate()
	candidate["dodge_last_position"] = candidate["position"].duplicate()
	return {"ok": true, "dodge_started": true, "interaction_requested": false}

func _walk_allowed(record: Dictionary, now: float) -> bool:
	return record["health"] > 0.0 and not (_settings.flag("rooted_blocks_movement") and now < record["rooted_until"]) and now >= record["hit_feedback_until"]

func _trajectory(record: Dictionary, latch: RefCounted, start: float, end: float) -> Dictionary:
	var boundaries: Array[float] = [start, end]
	var decay: float = _settings.parameter("food_decay_per_second")
	var threshold_at := INF
	if decay > 0.0:
		threshold_at = float(record["food_anchor_at"]) + (float(record["food_anchor_value"]) - _settings.parameter("low_food_threshold")) / decay
	var death_at: float = State.resources_at(record, end, _settings)["death_at"]
	for point in [threshold_at, death_at, float(record["dodge_until"]), float(record["rooted_until"]), float(record["hit_feedback_until"])]:
		if point > start and point < end and not boundaries.has(point):
			boundaries.append(point)
	boundaries.sort()
	var segments: Array[Dictionary] = []
	var requested_motion := Vector2.ZERO
	var maximum_distance := 0.0
	var last_valid: Array = record["last_valid_move"].duplicate()
	for index in range(boundaries.size() - 1):
		var begin: float = boundaries[index]
		var finish: float = boundaries[index + 1]
		var velocity := Vector2.ZERO
		var phase := "idle"
		if begin >= death_at or record["health"] <= 0.0:
			phase = "dead"
		elif not _walk_allowed(record, begin):
			phase = "controlled"
		else:
			if latch.move_direction != Vector2.ZERO:
				last_valid = State.pair(latch.move_direction)
			if begin < record["dodge_until"]:
				phase = "dodge"
				velocity = State.vector(record["dodge_direction"]) * (_settings.parameter("dodge_distance_cells") / _settings.parameter("dodge_duration_seconds"))
			elif latch.move_direction != Vector2.ZERO:
				phase = "walk"
				# At the crossing point itself food equals threshold, but every positive
				# part of this following interval is strictly below it.
				var low_food: bool = (decay > 0.0 and begin >= threshold_at) or (decay == 0.0 and record["food"] < _settings.parameter("low_food_threshold"))
				var multiplier: float = _settings.parameter("low_food_movement_multiplier") if low_food else 1.0
				velocity = latch.move_direction * (_settings.parameter("movement_speed_cells_per_second") * multiplier)
		var motion := velocity * (finish - begin)
		requested_motion += motion
		maximum_distance += float(velocity.length()) * (finish - begin)
		segments.append({"from": begin, "to": finish, "phase": phase, "velocity": velocity, "motion": motion})
	# Held input after control expiry must become history even without a new packet.
	if end < death_at and _walk_allowed(record, end) and latch.move_direction != Vector2.ZERO:
		last_valid = State.pair(latch.move_direction)
	return {"segments": segments, "requested_motion": requested_motion, "maximum_distance": maximum_distance, "last_valid_move": last_valid}

static func _distance_until(segments: Array, until: float) -> float:
	var distance := 0.0
	for segment in segments:
		distance += float(segment["velocity"].length()) * maxf(0.0, minf(float(segment["to"]), until) - float(segment["from"]))
	return distance

static func _copy_input(source: RefCounted) -> RefCounted:
	var result := InputState.new()
	result.sequence = source.sequence
	result.fingerprint = source.fingerprint
	result.move_direction = source.move_direction
	result.aim = source.aim
	result.pressed_action = source.pressed_action
	result.held = source.held.duplicate(true)
	return result

func _touch() -> void:
	_revision += 1
	_preview.clear()
	_preview_candidates.clear()
	_prepared_presence.clear()
	_prepared_transfer.clear()
	_interaction_receipts.clear()

func release_runtime_sessions() -> void:
	# Owner shutdown only: release ephemeral inputs even at exhausted revision.
	# No further broadcast/commands are allowed after owner enters shutdown.
	# Persistent records, clock and revision are unchanged; this is not a live
	# disconnect transaction or a way to avoid the normal revision checks.
	_active.clear()
	_inputs.clear()
	_input_generations.clear()
	_preview.clear()
	_preview_candidates.clear()
	_prepared_presence.clear()
	_prepared_transfer.clear()
	_interaction_receipts.clear()
