extends RefCounted
## Bounded, disposable presentation only. No world, position, resources or timers.
## Admission cursors NEVER confirm an action or authorize positional replay.
const Pending = preload("res://scripts/actor/actor_input_pending.gd")
const Command = preload("res://scripts/actor/actor_command.gd")
var ready: bool = false
var _closed: bool = false
var _checkpoint: Dictionary = {}
var _aim: Array = []
var _authoritative_aim: Array = []
var _actions: Dictionary = {}
var _server_dodging: bool = false
var _sequence: int = 0
var _provisional: bool = false

func configure(checkpoint: Dictionary, public_aim: Array, server_dodging: bool) -> Dictionary:
	if ready or _closed:
		return {"ok":false,"code":"PRESENTATION_REBIND_REQUIRES_NEW_INSTANCE"}
	if not _valid_checkpoint(checkpoint) or not _valid_public_aim(public_aim):
		return {"ok":false,"code":"PRESENTATION_BINDING_INVALID"}
	_checkpoint = checkpoint.duplicate(true)
	_aim = public_aim.duplicate()
	_authoritative_aim = public_aim.duplicate()
	_server_dodging = server_dodging
	_sequence = checkpoint["accepted_sequence"]
	ready = true
	return {"ok":true}

func record_sent(checkpoint: Dictionary, request: Dictionary) -> Dictionary:
	# Called ONLY after production send success, with that stream's checkpoint.
	# This API is not an RPC, simulation entrypoint, receipt or command producer.
	if not ready:
		return {"ok":false,"code":"PRESENTATION_NOT_READY"}
	if checkpoint != _checkpoint:
		return _invalidate("PRESENTATION_SEND_CONTEXT_CHANGED")
	var checked := Command.validate(request)
	if not checked["ok"] or request["sequence"] <= _sequence:
		return _invalidate("PRESENTATION_SENT_COMMAND_INVALID")
	_sequence = request["sequence"]
	_aim = request["aim"].duplicate()
	if request["action"] != "none":
		# At most the two supported actions; latest phase, not an unbounded queue.
		_actions[request["action"]] = {"phase":request["phase"],"sequence":_sequence,"provisional":true}
	_provisional = true
	return {"ok":true,"provisional":true}

func synchronize(checkpoint: Dictionary, public_aim: Array, server_dodging: bool) -> Dictionary:
	if not ready:
		return {"ok":false,"code":"PRESENTATION_NOT_READY"}
	if not _valid_checkpoint(checkpoint) or not _valid_public_aim(public_aim):
		return _invalidate("PRESENTATION_SNAPSHOT_INVALID")
	for key in Pending.IDENTITY_FIELDS + ["input_generation"]:
		if checkpoint[key] != _checkpoint[key]:
			return _invalidate("PRESENTATION_STREAM_CHANGED")
	for key in ["actor_revision","authority_revision","world_seconds","accepted_sequence"]:
		if checkpoint[key] < _checkpoint[key]:
			return _invalidate("PRESENTATION_SNAPSHOT_REGRESSION")
	if checkpoint["actor_revision"] == _checkpoint["actor_revision"]:
		if checkpoint["accepted_sequence"] != _checkpoint["accepted_sequence"] or public_aim != _authoritative_aim or server_dodging != _server_dodging:
			return _invalidate("PRESENTATION_REVISION_CONFLICT")
		# Duplicate/authority-only snapshots do not silently erase fresh input.
		_checkpoint = checkpoint.duplicate(true)
		return {"ok":true,"corrected":false}
	# Conservative first slice: EVERY newer actor revision supersedes local
	# display, even without cursor coverage. No inferred success/rejection receipt.
	_checkpoint = checkpoint.duplicate(true)
	_aim = public_aim.duplicate()
	_authoritative_aim = public_aim.duplicate()
	_server_dodging = server_dodging
	_actions.clear()
	_provisional = false
	_sequence = maxi(_sequence, checkpoint["accepted_sequence"])
	return {"ok":true,"corrected":true}

func drawing_state() -> Dictionary:
	if not ready:
		return {}
	return {"aim":_aim.duplicate(),"action_intents":_actions.duplicate(true),"server_dodging":_server_dodging,"provisional":_provisional,"local_sequence":_sequence,"binding":_checkpoint.duplicate(true)}

func close() -> void:
	ready = false
	_closed = true
	_checkpoint.clear()
	_aim.clear()
	_authoritative_aim.clear()
	_actions.clear()
	_server_dodging = false
	_sequence = 0
	_provisional = false

func _invalidate(code: String) -> Dictionary:
	close()
	return {"ok":false,"code":code}

static func _valid_checkpoint(value: Dictionary) -> bool:
	var identity: Dictionary = {}
	for key in Pending.IDENTITY_FIELDS:
		if not value.has(key):
			return false
		identity[key] = value[key]
	return Pending._valid_identity(identity) and Pending._validate_checkpoint(value, identity)["ok"]

static func _valid_public_aim(value: Array) -> bool:
	if value.size() != 2:
		return false
	# Public aim round-trips through Vector2, allowing its existing binary32 edge.
	for scalar in value:
		if typeof(scalar) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(scalar)) or absf(float(scalar)) > 2147483648.0:
			return false
	return true
