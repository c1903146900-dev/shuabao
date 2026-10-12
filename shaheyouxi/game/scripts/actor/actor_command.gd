extends RefCounted
## Only input intent crosses the actor RPC boundary. No authority/results fields.
const KEYS := ["kind", "sequence", "move", "aim", "action", "phase"]
const MAX_SEQUENCE := 9007199254740991
const MAX_AIM := 2147483647.0

static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != KEYS.size():
		return {"ok": false, "code": "INVALID_INPUT_FIELDS"}
	for key in KEYS:
		if not value.has(key):
			return {"ok": false, "code": "INVALID_INPUT_FIELDS"}
	if value["kind"] != "actor_input":
		return {"ok": false, "code": "INVALID_INPUT_KIND"}
	if not value["sequence"] is int or value["sequence"] < 1 or value["sequence"] > MAX_SEQUENCE:
		return {"ok": false, "code": "INVALID_INPUT_SEQUENCE"}
	var move: Variant = value["move"]
	if not move is Array or move.size() != 2:
		return {"ok": false, "code": "INVALID_MOVE"}
	for component in move:
		if not component is int or component < -1 or component > 1:
			return {"ok": false, "code": "INVALID_MOVE"}
	var aim: Variant = value["aim"]
	if not aim is Array or aim.size() != 2:
		return {"ok": false, "code": "INVALID_AIM"}
	for component in aim:
		if not (component is int or component is float):
			return {"ok": false, "code": "INVALID_AIM"}
		if not is_finite(float(component)) or absf(float(component)) > MAX_AIM:
			return {"ok": false, "code": "INVALID_AIM"}
	if not value["action"] is String or not value["phase"] is String:
		return {"ok": false, "code": "INVALID_ACTION"}
	if value["action"] == "none":
		if value["phase"] != "none":
			return {"ok": false, "code": "INVALID_ACTION_PHASE"}
	elif value["action"] in ["dodge", "interact"]:
		if not value["phase"] in ["pressed", "held", "released"]:
			return {"ok": false, "code": "INVALID_ACTION_PHASE"}
	else:
		return {"ok": false, "code": "INVALID_ACTION"}
	var canonical := {"kind": "actor_input", "sequence": value["sequence"], "move": move.duplicate(), "aim": [float(aim[0]), float(aim[1])], "action": value["action"], "phase": value["phase"]}
	return {"ok": true, "command": canonical, "fingerprint": JSON.stringify(canonical, "", true, true).sha256_text(), "move_direction": Vector2(move[0], move[1]).normalized()}
