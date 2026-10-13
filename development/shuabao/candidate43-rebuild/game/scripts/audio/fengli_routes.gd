extends RefCounted
## Actual release markers choose motion; committed damage alone chooses contact.
## No delayed callbacks. Room/cast/occurrence identities separate chained strikes.
const MOTIONS := {
	"attack_motion":"fw_cut_move", "dash_attack_motion":"fw_dash_move", "dash":"fw_dash",
	"q1_motion":"fw_q1_release", "q2_strike_started":"fw_q2_move", "q3_launched":"fw_q3_release",
	"e1_projectile":"fw_e1_throw", "e1_pierce_started":"fw_e1_pierce",
	"e2_spin_started":"fw_e2_spin", "e2_blink":"fw_e2_blink", "e2_return":"fw_e2_blink",
	"r1_release":"fw_r1_release", "r2_throw":"fw_r2_throw"
}
const CONTACTS := {
	"attack":"fw_cut_contact", "dash_attack":"fw_dash_contact", "q1":"fw_q1_contact",
	"q2":"fw_q2_contact", "q3":"fw_q3_contact", "e1_dagger":"fw_e1_contact",
	"e1_pierce":"fw_e1_pierce_contact", "e2":"fw_e2_contact", "e2_spin":"fw_e2_contact",
	"e2_extra":"fw_e2_contact", "r1":"fw_r1_contact", "r1_execute":"fw_r1_contact",
	"r2":"fw_r2_contact", "r2_nail":"fw_r2_contact"
}
const STATUSES := {"e3_started":"fw_e3_start", "e3_ended":"fw_e3_end", "e3_death_prevented":"fw_passive_rescue", "passive_rescue":"fw_passive_rescue", "permanent_attack_gained":"fw_edge_growth"}
const SILENT := ["attack_started", "attack_impact", "dash_attack_started", "dash_attack_impact", "dash_attack_hit", "dash_attack_ended", "q1_started", "q1_impact", "q2_started", "q2_strike", "q2_finished", "q3_started", "q3_finished", "q3_contact", "e1_started", "e1_marked", "e1_finished", "e1_pierce", "e1_pierce_contact", "e2_started", "e2_spin", "e2_spin_contact", "e2_shadow_started", "e2_shadow_expired", "e2_finished", "e3_extended", "ultimate_impact", "ultimate_finished", "r1_started", "r1_impact", "r1_execute", "r1_cooldown_reduced", "r1_finished", "r2_basic_counted", "r2_sequence_ended", "r2_nail_expired", "r2_throw_started", "r2_contact", "r2_started", "r2_finished", "r2_presentation_finished"]
const EXTRA_DAMAGE := ["e3", "e3_true", "overload", "overload_true", "r2_true", "h17"]
var seen: Dictionary = {}
var cancelled: Dictionary = {}
var occurrences: Dictionary = {}
var ended := false
func reset() -> void:
	seen.clear(); cancelled.clear(); occurrences.clear(); ended = false
func end_room() -> void:
	reset(); ended = true
func _remember(table: Dictionary, key: String, value: Variant) -> void:
	table[key] = value
	if table.size() > 256: table.erase(table.keys()[0])
func cast_key(event: Dictionary) -> String:
	return "%s:%s" % [event.get("combat_level_id", ""), event.get("cast_id", -1)]
func _occurrence(event: Dictionary, family: String) -> String:
	var replay: Dictionary = event.get("replay_segment", {})
	return str(event.get("occurrence", event.get("strike", event.get("round", event.get("spin", replay.get("occurrence", occurrences.get(cast_key(event)+":"+family, 1)))))))
func _once(event: Dictionary, id: String, family: String, occurrence: String = "") -> Dictionary:
	var cast: String = cast_key(event)
	# For explicit non-cast status packets, sequence is the authoritative identity.
	if int(event.get("cast_id", -1)) < 0: cast += ":seq:%s" % event.get("sequence", -1)
	var key := "%s:%s:%s" % [cast, family, occurrence]
	if seen.has(key): return {"handled":true, "id":""}
	_remember(seen, key, true)
	return {"handled":true, "id":id, "cast_key":cast_key(event)}
func route(event: Dictionary) -> Dictionary:
	var kind: String = str(event.get("kind", ""))
	var source: String = str(event.get("source", ""))
	var ours: bool = MOTIONS.has(kind) or STATUSES.has(kind) or kind in SILENT or kind in ["ultimate_started", "attack_cancelled", "skill_cancelled", "cast_cancelled", "r1_cancelled"] or (kind == "damage" and str(event.get("target", "")) != "fengli" and (CONTACTS.has(source) or source in EXTRA_DAMAGE))
	if not ours: return {"handled":false, "id":""}
	if ended: return {"handled":true, "id":""}
	if kind in ["attack_cancelled", "skill_cancelled", "cast_cancelled", "r1_cancelled"]:
		var ids: Array = event.get("cast_ids", [event.get("cast_id", -1)])
		for id in ids: _remember(cancelled, "%s:%s" % [event.get("combat_level_id", ""), id], true)
		return {"handled":true, "id":""}
	if cancelled.has(cast_key(event)): return {"handled":true, "id":""}
	if kind == "q2_strike_started":
		_remember(occurrences, cast_key(event)+":q2", int(event.get("strike", 1)))
	if kind == "e2_spin_started":
		_remember(occurrences, cast_key(event)+":e2", event.get("spin", event.get("occurrence", 1)))
	if kind == "r2_throw":
		_remember(occurrences, cast_key(event)+":r2", int(event.get("round", 1)))
	if MOTIONS.has(kind):
		var id: String = MOTIONS[kind]
		if kind == "e2_spin_started" and float(event.get("rotation_duration", .45)) < .25: id = "fw_e2_spin_fast"
		var family: String = "q2" if kind == "q2_strike_started" else "e2" if kind == "e2_spin_started" else "r2" if kind == "r2_throw" else ""
		return _once(event, id, "motion:"+kind, _occurrence(event, family))
	if kind == "ultimate_started":
		if str(event.get("candidate", "")) == "r1": return _once(event, "fw_r1_gather", "gather")
		return {"handled":true, "id":""}
	if STATUSES.has(kind):
		if (kind == "e3_death_prevented" and float(event.get("prevented", 0)) <= 0.0) or (kind == "permanent_attack_gained" and float(event.get("amount", 0)) <= 0.0): return {"handled":true, "id":""}
		return _once(event, STATUSES[kind], "status:"+kind)
	if kind != "damage" or source in EXTRA_DAMAGE: return {"handled":true, "id":""}
	var amount: float = float(event.get("applied_amount", event.get("amount", 0)))
	var absorbed: float = float(event.get("absorbed", 0))
	if bool(event.get("immune", false)) or (amount <= 0.0 and absorbed <= 0.0): return {"handled":true, "id":""}
	var id: String = CONTACTS[source] if amount > 0.0 else "fw_guard_contact"
	var family: String = "e2" if source.begins_with("e2") else "r2" if source.begins_with("r2") else "r1" if source.begins_with("r1") else source
	# e1 dagger vs path are separate stages; q2/e2/r2 retain occurrence identities.
	var occurrence := "1"
	if family in ["q2", "e2"]: occurrence = _occurrence(event, family)
	elif family == "r2": occurrence = str(event.get("round", occurrences.get(cast_key(event)+":r2", 1)))
	return _once(event, id, "contact:"+family, occurrence)
