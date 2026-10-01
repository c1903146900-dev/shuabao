class_name CombatAudio
extends Node
## Presentation only: instantiate scenes/audio/combat_audio.tscn under the host.
## play_event returns false on mute, invalid ID, throttling or pool saturation.
## No autoload, input-map, simulation, or main-scene dependency.
const IDS := ["sword", "hit", "hit_heavy", "dash", "hurt", "enemy_die", "q_thrust", "e_overload", "r_slam", "ui_confirm", "ui_reject", "level_up", "settlement"]
const MAX_VOICES := 8
const PER_EVENT_LIMIT := 2
const MIN_INTERVAL_USEC := 40000
const HEADROOM_DB := -14.0

@export_range(-60.0, 0.0, 0.5) var volume_db := -3.0:
	set(value):
		volume_db = clampf(value, -60.0, 0.0)
		_apply_settings()
@export var muted := false:
	set(value):
		muted = value
		_apply_settings()
		if muted:
			stop_all()
@export_range(0.0, 0.04, 0.005) var pitch_variation := 0.025

var _bus_name := ""
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _last_usec: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _last_sword := -1

func _ready() -> void:
	_rng.randomize()
	_bus_name = "CombatSFX_%s" % get_instance_id()
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, _bus_name)
	AudioServer.set_bus_send(index, "Master")
	for id in IDS:
		var paths: Array[String] = [id]
		if id == "sword":
			paths = ["sword_1", "sword_2", "sword_3"]
		var bank: Array[AudioStream] = []
		for path in paths:
			var resource := load("res://assets/audio/%s.wav" % path) as AudioStream
			if resource != null:
				bank.append(resource)
		_streams[id] = bank
	for i in MAX_VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%02d" % i
		player.bus = _bus_name
		player.max_polyphony = 1
		player.volume_db = HEADROOM_DB
		add_child(player)
		_players.append(player)
	_apply_settings()

func _exit_tree() -> void:
	stop_all()
	var index := AudioServer.get_bus_index(_bus_name)
	if index > 0:
		AudioServer.remove_bus(index)

func _apply_settings() -> void:
	if _bus_name.is_empty():
		return
	var index := AudioServer.get_bus_index(_bus_name)
	if index > 0:
		AudioServer.set_bus_volume_db(index, volume_db)
		AudioServer.set_bus_mute(index, muted)

func set_volume_db(value: float) -> void:
	volume_db = value

func set_muted(value: bool) -> void:
	muted = value

func stop_all() -> void:
	for player in _players:
		player.stop()
	_last_usec.clear()

func play_event(id: String) -> bool:
	if muted or not _streams.has(id) or _streams[id].is_empty():
		return false
	var now := Time.get_ticks_usec()
	if _last_usec.has(id) and now - int(_last_usec[id]) < MIN_INTERVAL_USEC:
		return false
	var active_for_id := 0
	var available: AudioStreamPlayer = null
	for player in _players:
		if player.playing:
			if player.get_meta("sound_id", "") == id:
				active_for_id += 1
		elif available == null:
			available = player
	# Drop surplus voices instead of abruptly cutting a playing transient.
	if available == null or active_for_id >= PER_EVENT_LIMIT:
		return false
	var bank: Array = _streams[id]
	var variant := 0
	if id == "sword":
		variant = _rng.randi_range(0, bank.size()-1)
		if bank.size() > 1 and variant == _last_sword:
			variant = (variant + 1) % bank.size()
		_last_sword = variant
	available.stream = bank[variant]
	# UI and reward intervals stay tuned; combat gets small pitch variation.
	var variation := clampf(pitch_variation, 0.0, 0.04)
	available.pitch_scale = 1.0 if id in ["ui_confirm", "ui_reject", "level_up", "settlement"] else _rng.randf_range(1.0-variation, 1.0+variation)
	available.set_meta("sound_id", id)
	available.play()
	_last_usec[id] = now
	return true

func snapshot() -> Dictionary:
	var voices: Array = []
	for player in _players:
		if player.playing:
			voices.append({"id": player.get_meta("sound_id"), "stream": player.stream.resource_path,
				"playing": player.playing, "position": player.get_playback_position(),
				"pitch": player.pitch_scale, "volume_db": player.volume_db, "bus": player.bus})
	return {"active": voices.size(), "voices": voices, "muted": muted,
		"volume_db": volume_db, "bus": _bus_name, "loaded_ids": _streams.size(), "limit": MAX_VOICES}
