extends RefCounted
## Pure semantic key/mouse sampling. Outputs are four-field local intents;
## the owner producer supplies connection identity, generation and sequence.
## No Input singleton, scene, RPC, tick, position/resource prediction or target
## interaction result is owned here. One instance belongs to one local input life.
const Command = preload("res://scripts/actor/actor_command.gd")
const KEYS := ["move_up", "move_down", "move_left", "move_right", "dodge", "interact"]
const ACTIONS := ["dodge", "interact"]
const INTENT_FIELDS := ["move", "aim", "action", "phase"]
var ready: bool = false
var _enabled: bool = false
var _focused: bool = false
var _keys := {"move_up": false, "move_down": false, "move_left": false, "move_right": false, "dodge": false, "interact": false}
var _aim: Array = [] # No invented (0,0) target before a valid world point.
var _aim_dirty: bool = false

func configure(initial_aim: Variant) -> Dictionary:
	if ready:
		return _error("INPUT_SAMPLER_ALREADY_CONFIGURED")
	if not _valid_aim(initial_aim):
		return _error("INPUT_SAMPLER_INVALID_AIM")
	_aim = [float(initial_aim[0]), float(initial_aim[1])]
	_enabled = true
	_focused = true
	ready = true
	return _ok([])

func key_event(key: Variant, pressed: Variant, echo: Variant = false) -> Dictionary:
	if not ready:
		return _error("INPUT_SAMPLER_NOT_CONFIGURED")
	if not key is String or key not in KEYS or typeof(pressed) != TYPE_BOOL or typeof(echo) != TYPE_BOOL:
		return _error("INPUT_SAMPLER_INVALID_KEY_EVENT")
	if not _active():
		return _ok([])
	# OS repeat never rearms a key, including a still-physical press after focus
	# returns. A release is processed even if a caller also marked it as echo.
	if (pressed and echo) or _keys[key] == pressed:
		return _ok([])
	_keys[key] = pressed
	_aim_dirty = false # This immediate key intent carries the latest mouse sample.
	if key in ACTIONS:
		# No synthetic held packets: P84 uses one pressed edge, and the existing
		# InputState retains each action latch until its explicit release.
		return _ok([_intent(key, "pressed" if pressed else "released")])
	return _ok([_intent("none", "none")])

func interact_pointer_event(pressed: Variant, echo: Variant, world_point: Variant) -> Dictionary:
	# Live F adapter supplies a fresh pointer for this press, never cached aim.
	# Invalid/out-of-view pointers consume the physical press without sending an
	# interaction. Keep the key held until release, so re-entry/repeat cannot fire.
	# Releases remain unconditional and use the normal sampler cleanup semantics.
	if not ready:
		return _error("INPUT_SAMPLER_NOT_CONFIGURED")
	if typeof(pressed) != TYPE_BOOL or typeof(echo) != TYPE_BOOL:
		return _error("INPUT_SAMPLER_INVALID_KEY_EVENT")
	if not _active() or (pressed and echo) or _keys["interact"] == pressed:
		return _ok([])
	if not pressed:
		return key_event("interact", false, echo)
	if not _valid_aim(world_point):
		_keys["interact"] = true
		return _ok([]) # No intent was sent: retain any pending ordinary aim sample.
	set_aim(world_point)
	return key_event("interact", true, false)

func set_aim(world_point: Variant) -> Dictionary:
	# The adapter supplies a world-space Array[2], after its own screen/camera
	# conversion. Store doubles; do not quantize aim with body sprite direction.
	if not ready:
		return _error("INPUT_SAMPLER_NOT_CONFIGURED")
	if not _valid_aim(world_point):
		return _error("INPUT_SAMPLER_INVALID_AIM")
	if not _active():
		return _ok([]) # Do not queue pointer activity across disabled/focus intervals.
	var next: Array = [float(world_point[0]), float(world_point[1])]
	if next != _aim:
		_aim = next
		_aim_dirty = true
	return _ok([])

func flush() -> Dictionary:
	if not ready:
		return _error("INPUT_SAMPLER_NOT_CONFIGURED")
	if not _active() or not _aim_dirty:
		return _ok([])
	_aim_dirty = false
	return _ok([_intent("none", "none")])

func set_focused(value: Variant) -> Dictionary:
	return _set_gate("focused", value)

func set_enabled(value: Variant) -> Dictionary:
	return _set_gate("enabled", value)

func state() -> Dictionary:
	return {"ready": ready, "enabled": _enabled, "focused": _focused, "keys": _keys.duplicate(true), "aim": _aim.duplicate(), "aim_dirty": _aim_dirty}

func _set_gate(gate: String, value: Variant) -> Dictionary:
	if not ready:
		return _error("INPUT_SAMPLER_NOT_CONFIGURED")
	if typeof(value) != TYPE_BOOL:
		return _error("INPUT_SAMPLER_INVALID_GATE")
	var was_active := _active()
	if gate == "focused":
		_focused = value
	else:
		_enabled = value
	if not was_active or _active():
		return _ok([])
	var held_actions: Array = []
	for action in ACTIONS:
		if _keys[action]:
			held_actions.append(action)
	for key in KEYS:
		_keys[key] = false
	_aim_dirty = false
	# Caller sends this ordered batch synchronously while its owner/connection is
	# usable: zero move, then releases for actually held dodge/interact. Releases
	# only clear input latches; they neither cancel a started authoritative dodge
	# nor invent a successful/failed target interaction. Never replay on reconnect.
	var intents: Array = [_intent("none", "none")]
	for action in held_actions:
		intents.append(_intent(action, "released"))
	return _ok(intents)

func _active() -> bool:
	return ready and _enabled and _focused

func _movement() -> Array:
	# Keep native integer WASD components. Server Command normalizes the diagonal;
	# this sampler never substitutes fractional speed or mouse-relative movement.
	return [int(_keys["move_right"]) - int(_keys["move_left"]), int(_keys["move_down"]) - int(_keys["move_up"])]

func _intent(action: String, phase: String) -> Dictionary:
	return {"move": _movement(), "aim": _aim.duplicate(), "action": action, "phase": phase}

static func _valid_aim(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for component in value:
		if typeof(component) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(component)) or absf(float(component)) > Command.MAX_AIM:
			return false
	return true

static func _ok(intents: Array) -> Dictionary:
	return {"ok": true, "intents": intents.duplicate(true)}

static func _error(code: String) -> Dictionary:
	return {"ok": false, "code": code, "intents": []}
