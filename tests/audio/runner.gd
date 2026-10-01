extends SceneTree
const Component = preload("res://scripts/audio/combat_audio.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var initial_buses := AudioServer.bus_count
	var sfx := Component.new()
	root.add_child(sfx)
	check(AudioServer.bus_count == initial_buses + 1, "bus created")
	check(sfx.snapshot().loaded_ids == 13, "all 13 event banks loaded")
	check(not sfx.play_event("unknown"), "unknown ID harmless")
	for id in Component.IDS:
		sfx.stop_all()
		check(sfx.play_event(id), id + " starts")
		var state := sfx.snapshot()
		check(state.active == 1, id + " one active player")
		check(state.voices[0].playing, id + " actual playing flag")
		check(state.voices[0].stream.ends_with(".wav"), id + " imported WAV assigned")
		check(state.voices[0].pitch >= .975 and state.voices[0].pitch <= 1.025, id + " bounded pitch")
		check(not sfx.play_event(id), id + " same tick suppressed")
		await create_timer(1.05).timeout
		check(sfx.snapshot().active == 0, id + " finishes and releases voice")
	sfx.play_event("settlement")
	await create_timer(.06).timeout
	check(sfx.snapshot().voices[0].position > 0.0, "playback time advances")
	check(sfx.play_event("settlement"), "second same event allowed")
	await create_timer(.06).timeout
	check(not sfx.play_event("settlement"), "third same event rejected")
	check(sfx.snapshot().active == 2, "per-event cap remains two")
	sfx.stop_all()
	for id in ["settlement", "level_up", "e_overload", "r_slam", "enemy_die", "hurt", "hit_heavy", "dash"]:
		check(sfx.play_event(id), "fill pool " + id)
	check(sfx.snapshot().active == 8, "global cap reached")
	check(not sfx.play_event("q_thrust"), "ninth voice rejected")
	sfx.set_muted(true)
	check(sfx.snapshot().active == 0, "mute stops voices")
	check(not sfx.play_event("hit"), "muted event harmless")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(sfx.snapshot().bus)), "bus mute applied")
	sfx.set_muted(false)
	check(sfx.play_event("hit"), "unmute resumes new event")
	sfx.set_volume_db(50)
	check(sfx.volume_db == 0, "positive gain clamped")
	sfx.set_volume_db(-100)
	check(sfx.volume_db == -60, "floor clamped")
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(sfx.snapshot().bus)) == -60, "bus gain applied")
	var other := Component.new()
	root.add_child(other)
	check(other.snapshot().bus != sfx.snapshot().bus, "instances own separate buses")
	check(not other.muted and other.volume_db == -3, "instance settings isolated")
	other.free()
	sfx.stop_all()
	var last := ""
	for i in 12:
		check(sfx.play_event("sword"), "sword variant starts")
		var path: String = sfx.snapshot().voices[0].stream
		check(path != last, "no immediate sword variant repeat")
		last = path
		sfx.stop_all()
	sfx.free()
	check(AudioServer.bus_count == initial_buses, "buses removed on teardown")
	var result := {"checks": checks, "failures": failures, "passed": failures.is_empty(), "audio_driver": AudioServer.get_driver_name(), "listening_test": false}
	print("AUDIO_TEST_RESULT " + JSON.stringify(result))
	await process_frame
	await process_frame
	quit.call_deferred(0 if failures.is_empty() else 1)
