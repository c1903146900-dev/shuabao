extends "res://scripts/audio/audio_demo.gd"
var results: Array = []

func probe_event(id: String) -> Dictionary:
	sfx.stop_all()
	var accepted := sfx.play_event(id)
	var state := sfx.snapshot()
	var result := {"id": id, "accepted": accepted, "state": state,
		"passed": accepted and state.active == 1 and state.voices[0].playing}
	results.append(result)
	return result

func probe_limits() -> Dictionary:
	sfx.stop_all()
	var accepted := 0
	for i in 100:
		if sfx.play_event("sword"):
			accepted += 1
	var same_tick := accepted == 1
	sfx.stop_all()
	for id in ["settlement", "level_up", "e_overload", "r_slam", "enemy_die", "hurt", "hit_heavy", "dash"]:
		sfx.play_event(id)
	var full := sfx.snapshot()
	var rejected := not sfx.play_event("q_thrust")
	var result := {"same_tick_100_accepted": accepted, "global_active": full.active,
		"ninth_rejected": rejected, "passed": same_tick and full.active == 8 and rejected}
	results.append(result)
	return result

func probe_settings() -> Dictionary:
	sfx.set_volume_db(-12)
	var bus := AudioServer.get_bus_index(sfx.snapshot().bus)
	var gain_ok := is_equal_approx(AudioServer.get_bus_volume_db(bus), -12)
	sfx.set_muted(true)
	var mute_ok: bool = AudioServer.is_bus_mute(bus) and sfx.snapshot().active == 0 and not sfx.play_event("hit")
	sfx.set_muted(false)
	sfx.set_volume_db(-3)
	var resumes := sfx.play_event("settlement")
	var result := {"gain_applied": gain_ok, "mute_safe": mute_ok, "resumes": resumes,
		"passed": gain_ok and mute_ok and resumes}
	results.append(result)
	return result

func inject_key(code: int) -> String:
	sfx.stop_all()
	var down := InputEventKey.new()
	down.keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	return "native key queued"

func release_key(code: int) -> Dictionary:
	var state := sfx.snapshot()
	var up := InputEventKey.new()
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	var result := {"key": code, "state": state, "passed": state.active == 1}
	results.append(result)
	return result

func report() -> Dictionary:
	var ok := true
	for item in results:
		ok = ok and item.passed
	return {"passed": ok, "checks": results.size(), "driver": AudioServer.get_driver_name(), "listening_test": false, "results": results}

func start_lifecycle() -> String:
	set_process(false)
	sfx.free()
	var suite = load("res://tests/audio/lifecycle_suite.gd").new()
	suite.name = "AudioLifecycleSuite"
	get_tree().root.add_child(suite)
	return suite.start()
