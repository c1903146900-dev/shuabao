extends "res://scripts/integration/audio_router.gd"
## Dedicated Wind presentation observer. Feed each simulation event exactly once.
const FengliAudio = preload("res://scripts/audio/fengli_audio.gd")
const Routes = preload("res://scripts/audio/fengli_routes.gd")
const CommonHex = preload("res://scripts/audio/common_hex_routes.gd")
var routes := Routes.new()
var common_hex := CommonHex.new()
var paused := false
var ended := false
var event_room := ""
var generation := -1
var retired_rooms: Dictionary = {}
var enemy_kinds: Dictionary = {}
func _ready() -> void:
	sfx = FengliAudio.new()
	add_child(sfx)
func set_paused(value: bool) -> void:
	if paused == value: return
	paused = value
	if paused: sfx.stop_all()
func _reset_room(room: String, incoming_generation: int = -1) -> void:
	if not event_room.is_empty() and event_room != room:
		retired_rooms[event_room] = true
		if retired_rooms.size() > 32: retired_rooms.erase(retired_rooms.keys()[0])
	event_room = room
	generation = incoming_generation
	last_sequence = -1
	ended = false
	enemy_kinds.clear(); hit_groups.clear(); routes.reset(); common_hex.reset()
	sfx.stop_all()
func combat(event: Dictionary) -> void:
	var room: String = str(event.get("combat_level_id", ""))
	var incoming_generation: int = int(event.get("generation", -1))
	if incoming_generation >= 0 and generation >= 0 and incoming_generation < generation: return
	if room != event_room or (incoming_generation >= 0 and incoming_generation > generation):
		if incoming_generation < 0 and retired_rooms.has(room): return
		_reset_room(room, incoming_generation)
	var sequence: int = int(event.get("sequence", -1))
	if sequence <= last_sequence: return
	last_sequence = sequence
	var kind: String = str(event.get("kind", ""))
	if kind == "encounter_started":
		ended = false
		sfx.stop_all(); hit_groups.clear(); routes.reset(); common_hex.reset()
		return
	if kind in ["encounter_finished", "hero_died", "hero_death"]:
		ended = true
		sfx.stop_all(); hit_groups.clear(); enemy_kinds.clear(); routes.end_room(); common_hex.end_room()
		return
	if ended: return
	if kind == "enemy_spawned":
		enemy_kinds[str(event.get("actor_id", ""))] = str(event.get("enemy_kind", "melee"))
		return
	if kind in ["attack_cancelled", "skill_cancelled", "cast_cancelled", "r1_cancelled"]:
		sfx.cancel_cast_movement(room, event.get("cast_ids", [event.get("cast_id", -1)]))
	var common: Dictionary = common_hex.route(event)
	if common.handled:
		if not paused and not str(common.id).is_empty(): cue(common.id, "common:%s:%s" % [room, sequence])
		return
	var wind: Dictionary = routes.route(event)
	if wind.handled:
		if not paused and not str(wind.id).is_empty(): _cast_cue(wind.id, "wind:%s:%s" % [room, sequence], wind.cast_key)
		return
	if paused: return
	var id := ""
	if kind == "enemy_warning":
		var enemy: String = str(event.get("enemy_kind", enemy_kinds.get(str(event.get("actor_id", "")), "melee")))
		id = "xl_warning_" + enemy
		if id not in FengliAudio.WARNING_IDS: id = "xl_warning_melee"
	elif kind == "enemy_shot": id = "xl_shot"
	elif kind == "enemy_pounce_started": id = "dash"
	elif kind == "damage" and str(event.get("target", "")) == "fengli":
		if float(event.get("applied_amount", event.get("amount", 0))) > 0.0: id = "hurt"
		elif float(event.get("absorbed", 0)) > 0.0: _cast_cue("fw_guard_contact", "guard:%s:%s" % [room, sequence], routes.cast_key(event))
	elif kind == "kill":
		enemy_kinds.erase(str(event.get("target", "")))
		# One death punctuation per cast, never a crowd of simultaneous death cues.
		var key := "%s:%s" % [room, event.get("cast_id", -1)]
		if not hit_groups.has(key):
			hit_groups[key] = true
			if hit_groups.size() > 128: hit_groups.erase(hit_groups.keys()[0])
			id = "enemy_die"
	if not id.is_empty(): cue(id, "world:%s:%s" % [room, sequence])
func _cast_cue(id: String, source: String, cast_key: String) -> void:
	var played: bool = sfx.play_cast_event(id, cast_key)
	counts[id] = int(counts.get(id, 0)) + 1
	history.append({"id":id, "source":source, "cast_key":cast_key, "played":played})
	if history.size() > 64: history.pop_front()
