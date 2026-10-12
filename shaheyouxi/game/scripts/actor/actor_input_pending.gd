extends RefCounted
## Local bounded intent bookkeeping, not prediction or a second authority.
## A snapshot cursor covers obsolete pending intents; it does not prove that each
## command succeeded or that movement has been integrated through that command.
const Command = preload("res://scripts/actor/actor_command.gd")
const State = preload("res://scripts/actor/actor_state.gd")
const MAX_PENDING := 256 # Technical memory bound, not a gameplay rate or timer.
const IDENTITY_FIELDS := ["world_id", "server_epoch", "player_profile_id", "player_instance_id", "peer_id"]
const CHECKPOINT_FIELDS := ["world_id", "server_epoch", "player_profile_id", "player_instance_id", "peer_id", "input_generation", "accepted_sequence", "actor_revision", "authority_revision", "world_seconds"]
var ready: bool = false
var last_error: String = ""
var _cache: RefCounted
var _identity: Dictionary = {}
var _checkpoint: Dictionary = {}
var _next_sequence: int = 1
var _pending: Dictionary = {}

func configure(cache: RefCounted, identity: Variant) -> Dictionary:
	if ready:
		return _reject("INPUT_PENDING_ALREADY_CONFIGURED")
	if cache == null or not cache.has_method("input_checkpoint") or not _valid_identity(identity):
		return _reject("INPUT_PENDING_CONFIGURATION_INVALID")
	var checkpoint: Variant = cache.input_checkpoint(identity["player_profile_id"], identity["peer_id"])
	var checked := _validate_checkpoint(checkpoint, identity)
	if not checked["ok"]:
		return _reject(checked["code"])
	_cache = cache
	_identity = identity.duplicate(true)
	_checkpoint = checkpoint.duplicate(true)
	_next_sequence = checkpoint["accepted_sequence"] + 1
	_pending.clear()
	ready = true
	last_error = ""
	return {"ok": true, "cursor": _checkpoint.duplicate(true), "admission_only": true}

func issue(move: Variant, aim: Variant, action: Variant = "none", phase: Variant = "none") -> Dictionary:
	if not ready:
		return _reject("INPUT_PENDING_NOT_CONFIGURED")
	# Read the small projection from the already-validated public cache before
	# issuing. A newly received stream change cannot reuse an old local sequence.
	var synchronized := synchronize()
	if not synchronized["ok"]:
		return synchronized
	if _next_sequence > Command.MAX_SEQUENCE:
		return _reject("INPUT_SEQUENCE_EXHAUSTED")
	if _pending.size() >= MAX_PENDING:
		return _reject("INPUT_PENDING_CAPACITY")
	var checked := Command.validate({"kind":"actor_input", "sequence":_next_sequence, "move":move, "aim":aim, "action":action, "phase":phase})
	if not checked["ok"]:
		return _reject(str(checked["code"]))
	var command: Dictionary = checked["command"]
	_pending[_next_sequence] = command.duplicate(true)
	_next_sequence += 1
	last_error = ""
	# This is a local command ready to send, never a server acceptance/result.
	return {"ok": true, "request":command.duplicate(true), "provisional":true, "input_generation":_checkpoint["input_generation"]}

func synchronize() -> Dictionary:
	if not ready or _cache == null:
		return _reject("INPUT_PENDING_NOT_CONFIGURED")
	var checkpoint: Variant = _cache.input_checkpoint(_identity["player_profile_id"], _identity["peer_id"])
	if checkpoint is Dictionary and checkpoint.is_empty():
		var discarded := _pending.size()
		close()
		last_error = "INPUT_BINDING_UNAVAILABLE"
		return {"ok":false, "code":"INPUT_BINDING_UNAVAILABLE", "discarded_pending":discarded, "requires_rebind":true}
	var checked := _validate_checkpoint(checkpoint, _identity)
	if not checked["ok"]:
		return _reject(checked["code"])
	if checkpoint["input_generation"] != _checkpoint["input_generation"]:
		var discarded := _pending.size()
		close()
		last_error = "INPUT_STREAM_CHANGED"
		return {"ok":false, "code":"INPUT_STREAM_CHANGED", "discarded_pending":discarded, "requires_rebind":true}
	if checkpoint["accepted_sequence"] < _checkpoint["accepted_sequence"] or checkpoint["actor_revision"] < _checkpoint["actor_revision"] or checkpoint["authority_revision"] < _checkpoint["authority_revision"] or checkpoint["world_seconds"] < _checkpoint["world_seconds"]:
		return _reject("INPUT_CURSOR_REGRESSION")
	if checkpoint["actor_revision"] == _checkpoint["actor_revision"] and checkpoint["accepted_sequence"] != _checkpoint["accepted_sequence"]:
		return _reject("INPUT_CURSOR_SAME_REVISION_CONFLICT")
	var covered: Array = []
	for sequence in _pending.keys():
		if sequence <= checkpoint["accepted_sequence"]:
			covered.append(sequence)
	covered.sort()
	for sequence in covered:
		_pending.erase(sequence)
	_checkpoint = checkpoint.duplicate(true)
	# The authority may legally accept a sequence jump. Align future allocation;
	# never infer that skipped requests or locally unknown numbers were successes.
	_next_sequence = maxi(_next_sequence, checkpoint["accepted_sequence"] + 1)
	last_error = ""
	return {"ok":true, "covered_sequences":covered, "cursor":_checkpoint.duplicate(true), "admission_only":true}

func pending() -> Array:
	var result: Array = []
	var sequences := _pending.keys()
	sequences.sort()
	for sequence in sequences:
		result.append(_pending[sequence].duplicate(true))
	return result

func cursor() -> Dictionary:
	return _checkpoint.duplicate(true)

func close() -> void:
	ready = false
	_cache = null
	_identity.clear()
	_checkpoint.clear()
	_pending.clear()
	_next_sequence = 1
	last_error = ""

static func _valid_identity(value: Variant) -> bool:
	return State.exact_fields(value, IDENTITY_FIELDS) and SandboxServerAuthority._valid_id(value["world_id"],"world_") and SandboxServerAuthority._valid_id(value["server_epoch"],"session_") and SandboxServerAuthority._valid_id(value["player_profile_id"],"player_") and SandboxServerAuthority._valid_id(value["player_instance_id"],"entity_player_") and typeof(value["peer_id"]) == TYPE_INT and value["peer_id"] >= 1 and value["peer_id"] <= 2147483647

static func _validate_checkpoint(value: Variant, identity: Dictionary) -> Dictionary:
	if not State.exact_fields(value, CHECKPOINT_FIELDS):
		return {"ok":false,"code":"INPUT_CURSOR_FIELDS_INVALID"}
	for key in IDENTITY_FIELDS:
		if typeof(value[key]) != typeof(identity[key]) or value[key] != identity[key]:
			return {"ok":false,"code":"INPUT_CURSOR_IDENTITY_MISMATCH"}
	for key in ["input_generation","accepted_sequence","actor_revision","authority_revision"]:
		if typeof(value[key]) != TYPE_INT or value[key] < 0 or value[key] > Command.MAX_SEQUENCE:
			return {"ok":false,"code":"INPUT_CURSOR_NUMBER_INVALID"}
	if value["input_generation"] < 1 or value["input_generation"] > value["actor_revision"] or not State.valid_clock(value["world_seconds"]):
		return {"ok":false,"code":"INPUT_CURSOR_NUMBER_INVALID"}
	return {"ok":true}

func _reject(code: String) -> Dictionary:
	last_error = code
	return {"ok":false,"code":code}
