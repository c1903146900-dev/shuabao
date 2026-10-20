extends Node
const PACK_SHA: String = "00e2180c6556b26ce0f74ad19e8005ff5243bbd1c424a514e87a218c289f28fe"
const GATE_PATH: String = "res://yan_p3_reimplementation_20261018b/gate.gd"
const BINDING_PATH: String = "res://visual_rework_20261009/binding/live_binding.gd"
const MIGRATION_PATH: String = "res://yan_p3_reimplementation_20261018b/migration.json"
const SOURCE_PATH: String = "res://visual_rework_20261009/binding/source_binding.json"
var report: Dictionary = {"status":"RUNNING", "scope":"standalone_read_only_gate_micro_not_world_initialization", "read_capabilities":{"status":"NOT_RUN_REAL_SIM_REQUIRED", "reason":"requires exact live Sim/clock/director; no world is instantiated or replaced"}, "rows":[]}
var evidence: String = ""

func _ready() -> void:
	print("TEST_LP_NUM_THREADS=",OS.get_environment("LP_NUM_THREADS"))
	if OS.get_environment("LP_NUM_THREADS")!="2": get_tree().quit(4); return
	report["test_LP_NUM_THREADS"] = OS.get_environment("LP_NUM_THREADS")
	_run.call_deferred()

func _record(label: String, begin: int, fields: Dictionary) -> void:
	var row: Dictionary = fields.duplicate(false)
	row["label"] = label
	row["elapsed_usec"] = Time.get_ticks_usec() - begin
	report.rows.append(row)

func _fail(reason: String) -> void:
	report.status = "FAIL"
	report.reason = reason
	_finish(4)

func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var pack: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source-pack="): pack = arg.trim_prefix("--source-pack=")
		if arg.begins_with("--evidence="): evidence = arg.trim_prefix("--evidence=")
	if not pack.is_absolute_path() or not evidence.is_absolute_path():
		_fail("explicit_absolute_pack_and_evidence_required")
		return
	# Outside component timings. This primes OS file cache: no cold-cache claim.
	var check_started: int = Time.get_ticks_usec()
	if FileAccess.get_sha256(pack) != PACK_SHA:
		_fail("exact_source09_pack_required")
		return
	report.pack_sha256 = PACK_SHA
	report.pack_precheck_usec = Time.get_ticks_usec() - check_started
	if not ProjectSettings.load_resource_pack(pack, false):
		_fail("pack_mount_failed")
		return
	var load_started: int = Time.get_ticks_usec()
	var gate: Script = load(GATE_PATH) as Script
	var binding: Script = load(BINDING_PATH) as Script
	_record("load_original_scripts_no_instances", load_started, {})
	if gate == null or binding == null:
		_fail("script_load_failed")
		return
	var began: int = Time.get_ticks_usec()
	var checked: Variant = gate.call("verify")
	_record("original_verify_once", began, {"accepted":checked is Dictionary and checked.get("accepted",false)})
	if not checked is Dictionary or not checked.get("accepted", false):
		_fail("original_verify_rejected:" + str(checked))
		return
	var migration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MIGRATION_PATH))
	var prior: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(migration.predecessor)))
	var visual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(migration.visual_path)))
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE_PATH))
	var map_specs: Array = [{"label":"source", "map":source.runtime_map}, {"label":"visual", "map":visual.runtime_map}]
	for spec: Dictionary in map_specs:
		began = Time.get_ticks_usec()
		checked = gate.call("verify_legacy_map", spec.map)
		_record("original_verify_legacy_map_" + str(spec.label), began, {"accepted":checked is Dictionary and checked.get("accepted",false), "entries":spec.map.size(), "includes_nested_verify":true})
		if not checked is Dictionary or not checked.get("accepted", false):
			_fail("original_legacy_map_rejected:" + str(checked))
			return
	# Duplicate instrumentation ONLY, not a substitute for the real acceptance calls above.
	for path: String in [MIGRATION_PATH, str(migration.predecessor), str(migration.visual_path)]:
		began = Time.get_ticks_usec()
		var text: String = FileAccess.get_file_as_string(path)
		_record("replay_read_text", began, {"resource":path})
		began = Time.get_ticks_usec()
		var parsed: Variant = JSON.parse_string(text)
		_record("replay_parse_existing_text_once", began, {"resource":path, "characters":text.length()})
		if not parsed is Dictionary:
			_fail("replay_json_invalid")
			return
	for spec: Dictionary in map_specs:
		var actual_paths: Array = []
		var expected_hashes: Array = []
		var bytes: int = 0
		for path: String in spec.map:
			var actual: String = path
			if migration.changes.has(path):
				actual = str(migration.changes[path].preimage)
			elif migration.presentation_changes.has(path):
				var change: Dictionary = migration.presentation_changes[path]
				var expected_map: Dictionary = prior.runtime_map if change.map_scope == "source" else visual.runtime_map
				if spec.map != expected_map:
					_fail("replay_map_scope_mismatch")
					return
				actual = str(change.preimage)
			var file: FileAccess = FileAccess.open(actual, FileAccess.READ)
			if file == null:
				_fail("replay_input_missing")
				return
			bytes += file.get_length()
			file.close()
			actual_paths.append(actual)
			expected_hashes.append(str(spec.map[path]))
		# Stat/path resolution above is outside SHA loop timing.
		began = Time.get_ticks_usec()
		var matches: int = 0
		for index in range(actual_paths.size()):
			if FileAccess.get_sha256(actual_paths[index]) == expected_hashes[index]: matches += 1
		_record("replay_sha_loop_" + str(spec.label), began, {"files":actual_paths.size(), "logical_bytes":bytes, "matches":matches, "warm_after_original_checks":true, "authority_admission":false})
		if matches != actual_paths.size():
			_fail("replay_hash_mismatch")
			return
	report.status = "PASS"
	report.world_instances_created = 0
	report.cache_order = "whole_pack_sha_precheck; script_load; original_verify; source_legacy; visual_legacy; three_text_read_and_parse_pairs; source_sha_replay; visual_sha_replay"
	report.independent_intervals_not_initialize_floor_sum = true
	_finish(0)

func _finish(code: int) -> void:
	if not evidence.is_empty():
		var path: String = evidence.path_join("report.json")
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			get_tree().quit(4)
			return
		var text: String = JSON.stringify(report, "  ") + "\n"
		file.store_string(text)
		file.flush()
		file.close()
		if FileAccess.get_file_as_string(path) != text: code = 4
		print(JSON.stringify({"status":report.status,"report_sha256":FileAccess.get_sha256(path)}))
	get_tree().quit(code)
