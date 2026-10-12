extends RefCounted
## Ephemeral per-authenticated-connection state; never persisted as held input.
const Command = preload("res://scripts/actor/actor_command.gd")
var sequence: int = 0
var fingerprint: String = ""
var move_direction := Vector2.ZERO
var aim := Vector2.ZERO
var pressed_action: String = ""
var held: Dictionary = {"dodge": false, "interact": false}

func accept(value: Variant) -> Dictionary:
	# A pressed edge is a result of this call, never queued behind a rejection.
	pressed_action = ""
	var checked := Command.validate(value)
	if not checked["ok"]:
		return checked
	var command: Dictionary = checked["command"]
	if command["sequence"] < sequence:
		return {"ok": false, "code": "STALE_INPUT"}
	if command["sequence"] == sequence:
		if checked["fingerprint"] != fingerprint:
			return {"ok": false, "code": "CHANGED_DUPLICATE_INPUT"}
		return {"ok": true, "duplicate": true, "pressed_action": ""}
	var action: String = command["action"]
	var phase: String = command["phase"]
	if action != "none":
		if phase == "pressed" and held[action]:
			return {"ok": false, "code": "ALREADY_HELD"}
		if phase == "held" and not held[action]:
			return {"ok": false, "code": "NOT_PRESSED"}
	# No state mutation until the complete envelope and transition are valid.
	sequence = command["sequence"]
	fingerprint = checked["fingerprint"]
	move_direction = checked["move_direction"]
	aim = Vector2(command["aim"][0], command["aim"][1])
	if action != "none":
		held[action] = phase != "released"
		if phase == "pressed":
			pressed_action = action
	return {"ok": true, "duplicate": false, "pressed_action": pressed_action}

func clear_motion() -> void:
	move_direction = Vector2.ZERO
	pressed_action = ""

func reset_connection() -> void:
	sequence = 0
	fingerprint = ""
	move_direction = Vector2.ZERO
	aim = Vector2.ZERO
	pressed_action = ""
	held = {"dodge": false, "interact": false}
