extends "res://scripts/audio/combat_audio.gd"
## Wind owns a bounded family inside8 ordinary voices;3 threat voices stay reserved.
const Bank = preload("res://scripts/audio/fengli_bank.gd")
const CommonHex = preload("res://scripts/audio/common_hex_routes.gd")
const WARNING_IDS := ["xl_warning_melee", "xl_warning_ranged", "xl_warning_pouncer", "xl_warning_elite", "xl_warning_armored", "xl_warning_boss", "xl_warning_pitcher", "xl_warning_support"]
const WARNING_VOICES := 3
const CANCEL_FADE_SECONDS := 0.018
var _next_variant: Dictionary = {}
var _fades: Dictionary = {}
var _warning_players: Array[AudioStreamPlayer] = []
var _clock := 0.0
var _warning_last: Dictionary = {}
func _ready() -> void:
	super._ready()
	_streams.merge(Bank.load_streams())
	# Enemy warning vocabulary is global, not a hero weapon. Reuse it unchanged.
	for id in WARNING_IDS + CommonHex.IDS + ["xl_shot"]:
		var stream := load("res://assets/audio/%s.wav" % id) as AudioStream
		_streams[id] = [stream] if stream != null else []
	for index in WARNING_VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "ThreatVoice%d" % index
		player.bus = _bus_name
		player.volume_db = HEADROOM_DB + 1.0
		player.max_polyphony = 1
		add_child(player)
		_warning_players.append(player)
func _process(delta: float) -> void:
	_clock += maxf(delta, 0.0)
	_advance_fades(maxf(delta, 0.0))
func _event_clock_usec() -> int:
	return int(_clock * 1000000.0) if OS.has_feature("movie") else Time.get_ticks_usec()
func play_event(id: String) -> bool:
	_prune_fades()
	if id in Bank.IDS: return play_cast_event(id, "")
	if id.begins_with("hx_"):
		var active_common := 0
		for player in _players:
			if player.playing and str(player.get_meta("sound_id", "")).begins_with("hx_"): active_common += 1
		if active_common >= CommonHex.MAX_COMMON_VOICES: return false
	if id not in WARNING_IDS: return super.play_event(id)
	if muted or not _streams.has(id) or _streams[id].is_empty(): return false
	if _clock - float(_warning_last.get(id, -10.0)) < .04: return false
	for player in _warning_players:
		if player.playing: continue
		player.stream = _streams[id][0]
		player.pitch_scale = 1.0
		player.set_meta("sound_id", id)
		player.play()
		_warning_last[id] = _clock
		return true
	return false
func play_cast_event(id: String, cast_key: String) -> bool:
	_prune_fades()
	if id not in Bank.IDS or muted or not _streams.has(id) or _streams[id].is_empty(): return false
	var now := _event_clock_usec()
	if _last_usec.has(id) and now - int(_last_usec[id]) < MIN_INTERVAL_USEC: return false
	var active_for_id := 0
	var active_hero := 0
	var available: AudioStreamPlayer = null
	for player in _players:
		if player.playing:
			var playing_id: String = str(player.get_meta("sound_id", ""))
			if playing_id == id: active_for_id += 1
			if playing_id in Bank.IDS: active_hero += 1
		elif available == null: available = player
	if available == null or active_for_id >= PER_EVENT_LIMIT or active_hero >= Bank.MAX_HERO_VOICES: return false
	var bank: Array = _streams[id]
	var variant: int = int(_next_variant.get(id, 0)) % bank.size()
	available.stream = bank[variant]
	available.volume_db = HEADROOM_DB
	available.pitch_scale = 1.0
	available.set_meta("sound_id", id)
	available.set_meta("wind_cast", cast_key)
	available.play()
	_next_variant[id] = (variant + 1) % bank.size()
	_last_usec[id] = now
	return true
func cancel_cast_movement(room: String, cast_ids: Array) -> void:
	var keys: Dictionary = {}
	for id in cast_ids: keys["%s:%s" % [room, id]] = true
	for player in _players:
		if not player.playing or str(player.get_meta("sound_id", "")) not in Bank.MOVEMENT_IDS + ["fw_r1_gather"]: continue
		var key: String = str(player.get_meta("wind_cast", ""))
		if not keys.has(key) or _fades.has(player): continue
		_fades[player] = {"cast_key":key, "left":CANCEL_FADE_SECONDS, "start_db":player.volume_db}
func _prune_fades() -> void:
	for player in _fades.keys():
		if not player.playing or str(player.get_meta("wind_cast", "")) != str(_fades[player].cast_key):
			player.volume_db = HEADROOM_DB
			_fades.erase(player)
func _advance_fades(delta: float) -> void:
	_prune_fades()
	for player in _fades.keys():
		var state: Dictionary = _fades[player]
		state.left = maxf(0.0, float(state.left) - delta)
		if float(state.left) <= 0.0:
			player.stop()
			player.volume_db = HEADROOM_DB
			_fades.erase(player)
		else:
			var fraction: float = float(state.left) / CANCEL_FADE_SECONDS
			player.volume_db = float(state.start_db) + linear_to_db(maxf(pow(sin(fraction * PI * .5), 2.0), .00001))
func stop_all() -> void:
	super.stop_all()
	for player in _fades.keys(): player.volume_db = HEADROOM_DB
	_fades.clear()
	for player in _warning_players: player.stop()
	_warning_last.clear()
func snapshot() -> Dictionary:
	var out: Dictionary = super.snapshot()
	out.ordinary_active = out.active
	out.warning_active = 0
	for player in _warning_players:
		if not player.playing: continue
		out.warning_active += 1
		out.voices.append({"id":player.get_meta("sound_id"), "stream":player.stream.resource_path, "playing":true, "position":player.get_playback_position(), "pitch":player.pitch_scale, "volume_db":player.volume_db, "bus":player.bus, "priority":"telegraph"})
	out.active += out.warning_active
	out.limit = MAX_VOICES + WARNING_VOICES
	return out
func _exit_tree() -> void:
	for player in _warning_players:
		player.stop()
		player.stream = null
	_warning_players.clear()
	super._exit_tree()
