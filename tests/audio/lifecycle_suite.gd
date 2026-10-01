extends Node
const Component = preload("res://scripts/audio/combat_audio.gd")
const Drain = preload("res://tests/audio/playback_drain.gd")
var results: Dictionary = {"done": false}
var failures: Array[String] = []
var samples: Array = []
var max_active := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func metrics() -> Dictionary:
	var rss_kb := 0
	var proc_status := FileAccess.open("/proc/self/status", FileAccess.READ)
	while proc_status != null and not proc_status.eof_reached():
		var line := proc_status.get_line()
		if line.begins_with("VmRSS:"):
			rss_kb = line.trim_prefix("VmRSS:").strip_edges().to_int()
	return {"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"static_bytes": OS.get_static_memory_usage(), "rss_kb": rss_kb, "buses": AudioServer.bus_count}

func cycle(index: int) -> void:
	var component := Component.new()
	get_tree().root.add_child(component)
	var drain := Drain.new()
	var node_ref: WeakRef = weakref(component)
	for id in ["sword", "hit", "hurt", "dash", "r_slam", "q_thrust", "e_overload", "settlement"]:
		check(component.play_event(id), "pool starts " + id)
	max_active = maxi(max_active, component.snapshot().active)
	check(not component.play_event("enemy_die"), "ninth rejected")
	drain.watch(component)
	match index % 3:
		0: component.stop_all()
		1: component.set_muted(true)
		2: pass # free while all eight voices still play
	component.queue_free()
	await get_tree().process_frame
	var released: Dictionary = await drain.wait_for_release(get_tree())
	check(released.passed and node_ref.get_ref() == null, "cycle releases all weak references")

func start() -> String:
	call_deferred("run")
	return "lifecycle started"

func run() -> void:
	var base_buses := AudioServer.bus_count
	for i in 20:
		await cycle(i)
	# Preallocate sample dictionaries so telemetry itself does not look like growth.
	samples.resize(11)
	for i in samples.size():
		samples[i] = metrics()
	samples[0] = metrics()
	for batch in 10:
		for i in 20:
			await cycle(i)
		samples[batch + 1] = metrics()
		check(AudioServer.bus_count == base_buses, "batch bus count restored")
	# Genuine SceneTree scene replacement, not just deleting a child container.
	# Suite is a root sibling and survives; probes contain one component each.
	var packed := PackedScene.new()
	var prototype := Component.new()
	prototype.name = "LifecycleScene"
	packed.pack(prototype)
	prototype.free()
	for i in 20:
		check(get_tree().change_scene_to_packed(packed) == OK, "scene transition accepted")
		await get_tree().scene_changed
		var scene: Node = get_tree().current_scene
		check(scene.play_event("settlement"), "scene audio starts")
		var drain := Drain.new()
		drain.watch(scene)
		var node_ref: WeakRef = weakref(scene)
		check(get_tree().change_scene_to_file("res://tests/audio/empty.tscn") == OK, "empty scene transition")
		await get_tree().scene_changed
		var released: Dictionary = await drain.wait_for_release(get_tree())
		check(released.passed and node_ref.get_ref() == null, "scene replacement releases sound and node")
	check(AudioServer.bus_count == base_buses, "scene buses restored")
	# Compare only steady-state component batches: scene replacement changes host nodes.
	var first: Dictionary = samples[0]
	var last: Dictionary = samples[-1]
	for key in ["objects", "resources", "nodes", "orphans", "buses"]:
		check(last[key] == first[key], "no steady-state growth " + key)
	check(int(last.static_bytes) - int(first.static_bytes) < 65536, "static memory bounded")
	results = {"done": true, "passed": failures.is_empty(), "failures": failures,
		"component_cycles": 220, "scene_round_trips": 20, "max_active": max_active,
		"samples": samples, "static_delta": int(last.static_bytes)-int(first.static_bytes),
		"rss_delta_kb": int(last.rss_kb)-int(first.rss_kb), "driver": AudioServer.get_driver_name()}
	print("AUDIO_LIFECYCLE_RESULT " + JSON.stringify(results))

func report() -> Dictionary:
	return results
