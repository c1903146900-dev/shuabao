extends SceneTree
const BASE: String = "res://tests/ink_ultimate_presentation_20261006/r1_consumer01/"
const FILES: Array = [BASE + "clock_facade.gd", BASE + "timed_director.gd", BASE + "sim.gd", BASE + "finite_gate.gd"]

func _initialize() -> void:
	var failures: Array[String] = []
	for path: String in FILES:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failures.append(path)
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "source_binding.json"))
	var observed: Dictionary = {}
	for path: String in binding.runtime_map:
		observed[path] = FileAccess.get_sha256("res://" + path)
		if observed[path] != binding.runtime_map[path].sha256:
			failures.append("staged source mismatch: " + path)
	print("INK_R1_PRESENTATION_CONSUMER_PARSE ", JSON.stringify({"passed": failures.is_empty(), "failures": failures, "scripts": FILES, "source_binding_sha256": FileAccess.get_sha256(BASE + "source_binding.json"), "observed_runtime_sha256": observed, "runtime_pass": false}))
	quit(0 if failures.is_empty() else 1)
