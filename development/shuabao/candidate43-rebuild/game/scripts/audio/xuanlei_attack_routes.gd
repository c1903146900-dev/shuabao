extends RefCounted
## Presentation observes actual release markers and committed positive damage.
## No timers/queued sounds: a cancelled windup cannot leak a delayed swing.
var casts: Dictionary = {}
var movements: Dictionary = {}
var contacts: Dictionary = {}
var cancelled: Dictionary = {}
var ended := false

func reset() -> void:
	casts.clear(); movements.clear(); contacts.clear(); cancelled.clear()
	ended = false

func end_room() -> void:
	reset()
	ended = true

func _key(event: Dictionary) -> String:
	if int(event.get("cast_id", -1)) >= 0:
		return "%s:%s" % [event.get("combat_level_id", ""), event.cast_id]
	# Real simulation attacks have cast IDs; malformed/legacy presentation tests
	# without one still must not silence unrelated future contacts forever.
	return "%s:unscoped:%s:%s" % [event.get("combat_level_id", ""), event.get("source", ""), event.get("world_time", 0)]

func _remember(table: Dictionary, key: String, value: Variant) -> void:
	table[key] = value
	if table.size() > 128: table.erase(table.keys()[0])

func route(event: Dictionary) -> Dictionary:
	var kind: String = str(event.get("kind", ""))
	var source: String = str(event.get("source", ""))
	var handled: bool = kind in ["attack_started", "attack_motion", "attack_impact", "attack_cancelled", "dash_attack_started", "dash_attack_motion", "dash_attack_impact", "dash_attack_hit", "dash_attack_ended"] or (kind == "damage" and source in ["attack", "dash_attack"] and str(event.get("target", "")) != "xuanlei")
	if not handled: return {"handled":false, "id":""}
	if ended: return {"handled":true, "id":""}
	var key: String = _key(event)
	var id := ""
	if kind == "attack_cancelled":
		for cast_id in event.get("cast_ids", []):
			_remember(cancelled, "%s:%s" % [event.get("combat_level_id", ""), cast_id], true)
		return {"handled":true, "id":""}
	if cancelled.has(key): return {"handled":true, "id":""}
	if kind in ["attack_started", "attack_motion"]:
		_remember(casts, key, clampi(int(event.get("combo", event.get("combo_index", 1))), 1, 3))
	if kind in ["attack_motion", "dash_attack_motion"]:
		if movements.has(key): return {"handled":true, "id":""}
		_remember(movements, key, true)
		id = "xa_dash_move" if kind == "dash_attack_motion" else "xa_swing_%d" % int(casts.get(key, 1))
	elif kind == "damage":
		# amount is HP-committed; applied_amount, when provided, overrides it.
		# An actual shield absorption has its own short block material sound,
		# never a fabricated damage-body thump. Guard stance alone proves nothing.
		var amount: float = float(event.get("applied_amount", event.get("amount", 0)))
		var absorbed: float = float(event.get("absorbed", 0))
		if bool(event.get("immune", false)) or (amount <= 0.0 and absorbed <= 0.0):
			return {"handled":true, "id":""}
		if contacts.has(key): return {"handled":true, "id":""}
		_remember(contacts, key, true)
		var combo: int = clampi(int(event.get("combo", event.get("combo_index", casts.get(key, 1)))), 1, 3)
		if amount <= 0.0 and absorbed > 0.0: id = "xa_guard_contact"
		else: id = "xa_dash_contact" if source == "dash_attack" else "xa_contact_%d" % combo
	return {"handled":true, "id":id}
