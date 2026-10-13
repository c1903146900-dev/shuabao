extends "res://scripts/integration/audio_router.gd"
## Presentation only. Pass every authoritative event once, including enemy_spawned.
## Room must call set_paused(simulation.paused) when its custom pause state changes.
const XuanleiAudio = preload("res://scripts/audio/xuanlei_audio.gd")
const CommonHex = preload("res://scripts/audio/common_hex_routes.gd")
var common_hex := CommonHex.new()
const AttackRoutes = preload("res://scripts/audio/xuanlei_attack_routes.gd")
var attack_routes := AttackRoutes.new()
const EVENT_CUES := {
	"attack_started":"", "attack_motion":"xa_swing_1", "attack_impact":"",
	"q1_windup":"xl_heft", "q1":"xl_door", "q1_echo":"xl_door",
	"q2_windup":"xl_heft", "q2_chain":"xl_chain", "chain_landing":"xl_door",
	"q3_windup":"xl_heft", "q3":"xl_door", "enemy_collision":"xl_door",
	"e1_guard_started":"xl_guard", "e1_release_windup":"xl_heft", "e1_release":"xl_door",
	"e2_charge_started":"xl_charge", "e2_charge_extended":"xl_charge", "e2_release":"xl_door", "e2_wall":"xl_fortress",
	"e3_windup":"xl_heft", "e3_aura_started":"xl_stone",
	"ultimate_started":"xl_heft", "r1_fortress_started":"xl_fortress", "r1_release_windup":"xl_heft", "r1_release":"xl_fortress",
	"r2_charge_started":"xl_charge", "r2_wall":"xl_fortress", "r2_adjust":"xl_guard", "r2_finish_windup":"xl_heft", "r2_finish":"xl_fortress",
	"dash":"dash", "dash_attack_started":"", "dash_attack_motion":"xa_dash_move", "enemy_pounce_started":"dash", "shield":"xl_guard", "retaliation_ready":"xl_guard", "retaliation_wave":"xl_door", "enemy_shot":"xl_shot", "enemy_zone_landed":"xl_stone", "comrades_rescue":"xl_guard", "wall_shock":"xl_stone"
}
var paused := false
var enemy_kinds: Dictionary = {}
var guard_active := false
var event_room := ""
func _ready() -> void:
	sfx = XuanleiAudio.new()
	add_child(sfx)
func set_paused(value: bool) -> void:
	if paused == value: return
	paused = value
	if paused:
		sfx.stop_all()
		# Keep seen identities/generation; no events are queued during pause.
func combat(event: Dictionary) -> void:
	var room: String = str(event.get("combat_level_id", ""))
	if event_room != room:
		event_room = room
		last_sequence = -1
		enemy_kinds.clear()
		guard_active = false
		hit_groups.clear()
		common_hex.reset()
		attack_routes.reset()
		sfx.stop_all()
	var seq: int = event.get("sequence", -1)
	if seq <= last_sequence: return
	last_sequence = seq
	var kind: String = event.get("kind", "")
	if kind == "enemy_spawned":
		enemy_kinds[str(event.get("actor_id", ""))] = event.get("enemy_kind", "melee")
		return
	if kind == "e1_guard_started": guard_active = true
	if kind in ["e1_release_windup", "e1_release", "e1_expired", "encounter_started", "encounter_finished"]: guard_active = false
	if kind in ["encounter_started", "encounter_finished"]:
		sfx.stop_all()
		hit_groups.clear()
		attack_routes.reset()
		if kind == "encounter_finished":
			enemy_kinds.clear()
			common_hex.end_room()
			attack_routes.end_room()
		return
	var common: Dictionary = common_hex.route(event)
	if common.handled:
		if not paused and not str(common.id).is_empty(): cue(str(common.id), "common_hex:%s:%d" % [room,seq])
		return
	if kind == "attack_cancelled":
		sfx.cancel_attack_movement(room, event.get("cast_ids", []))
	var attack: Dictionary = attack_routes.route(event)
	if attack.handled:
		if not paused and not str(attack.id).is_empty():
			_attack_cue(str(attack.id), "xuanlei:%s:%d" % [room,seq], "%s:%s" % [room, event.get("cast_id", -1)])
		return
	if paused: return
	var id: String = EVENT_CUES.get(kind, "")
	if kind == "enemy_warning":
		var enemy_kind: String = str(event.get("enemy_kind", enemy_kinds.get(str(event.get("actor_id", "")), "melee")))
		id = "xl_warning_" + enemy_kind if enemy_kind in ["melee", "ranged", "pouncer", "armored", "elite", "boss", "pitcher", "support"] else "xl_warning_melee"
	if kind == "enemy_impact": id = "xl_door" if event.get("hit",false) else ""
	if kind == "damage":
		if event.get("amount", 0) <= 0: return
		if event.get("target", "") == "xuanlei":
			id = "xl_guard" if bool(event.get("guarded",false)) else "hurt"
		else:
			# Only authoritative nonzero damage receives the dry target-contact transient.
			# A swing into empty air has its whoosh, never the same impact as a hit.
			var group := "%s:%s:%s" % [room,event.get("cast_id",0),event.get("world_time",0)]
			if hit_groups.has(group): return
			hit_groups[group] = true
			if hit_groups.size() > 128: hit_groups.erase(hit_groups.keys()[0])
			id = "hit_heavy" if event.get("critical",false) else "hit"
	if kind == "kill":
		id = "enemy_die"
		enemy_kinds.erase(str(event.get("target", "")))
	if not id.is_empty(): cue(id, "xuanlei:%s:%d" % [room, seq])
func _attack_cue(id: String, source: String, cast_key: String) -> void:
	var played: bool = sfx.play_attack_event(id, cast_key)
	counts[id] = int(counts.get(id, 0)) + 1
	history.append({"id":id, "source":source, "played":played})
	if history.size() > 64: history.pop_front()
