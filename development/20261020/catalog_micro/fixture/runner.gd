extends Node
const Original = preload("original.gd")
const Candidate = preload("candidate.gd")
const ITERATIONS: int = 1000
var checks: int = 0
var failures: Array = []
var report: Dictionary = {}

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 32:
		failures.append(label)

func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var started: int = Time.get_ticks_usec()
	var source_before: Dictionary = Candidate.data()
	var overrides_before: Dictionary = Candidate.effective_overrides()
	var cells: int = 0
	var spellings: int = 0
	var fractions: int = 0
	var ids: Array = Original.hex_ids()
	_check(ids == Candidate.hex_ids(), "hex_ids")
	for raw_id in ids:
		var id: String = str(raw_id)
		var definition: Dictionary = Original.hex_definition(id)
		_check(definition == Candidate.hex_definition(id), "definition:" + id)
		for raw_token in definition.get("parameters", {}):
			var token: String = str(raw_token)
			var original_value: float = Original.hex_parameter(id, token)
			cells += 1
			for spelling in [token, token.to_lower(), "[" + token.to_lower() + "]"]:
				_check(original_value == Candidate.hex_parameter(id, spelling), "scalar:" + id + ":" + spelling)
				spellings += 1
			if str(definition.parameters[token].get("unit", "")).contains("%"):
				_check(Original.hex_fraction(id, token) == Candidate.hex_fraction(id, token), "fraction:" + id + ":" + token)
				fractions += 1
		# Public return mutation must not escape into canonical data or scalar reads.
		var returned: Dictionary = Candidate.hex_definition(id)
		returned.clear()
		_check(Candidate.hex_definition(id) == definition, "isolation:definition:" + id)
	for id in ["", "unknown", "common_no_such_hex", "COMMON_G24", "common_G24"]:
		_check(Original.hex_definition(id) == Candidate.hex_definition(id), "lookup:" + id)
	# Verify nested public data and overrides are still independent deep copies.
	var public_data: Dictionary = Candidate.data()
	public_data.common_hexes.G24.parameters["G24-1"].values[0] = -987654
	var public_overrides: Dictionary = Candidate.effective_overrides()
	_mutate_nested(public_overrides)
	_check(Candidate.data() == source_before, "isolation:data_nested")
	_check(Candidate.effective_overrides() == overrides_before, "isolation:override_nested")
	# Isolated fixture-only synthetic overrides cover the dormant authored Hex override branch.
	# These are independent Script caches, not world/model state; restore before timing.
	var original_saved: Dictionary = Original._override_cache.duplicate(true)
	var candidate_saved: Dictionary = Candidate._override_cache.duplicate(true)
	Original._override_cache = {"hexes": {"common_g24": {"G24-1": {"values": [12.5]}}}}
	Candidate._override_cache = Original._override_cache.duplicate(true)
	_check(Original.hex_parameter("common_g24", "[g24-1]") == Candidate.hex_parameter("common_g24", "[g24-1]"), "synthetic_override_equivalence")
	_check(Candidate.hex_parameter("common_g24", "G24-1") == 12.5, "synthetic_override_value")
	var override_copy: Dictionary = Candidate.effective_overrides()
	override_copy.hexes.common_g24["G24-1"].values[0] = 99.0
	_check(Candidate.hex_parameter("common_g24", "G24-1") == 12.5, "synthetic_override_isolation")
	Candidate._override_cache.hexes.common_g24["G24-1"].values[0] = 13.5
	_check(Candidate.hex_parameter("common_g24", "G24-1") == 13.5, "no_cross_call_scalar_cache")
	Original._override_cache = original_saved
	Candidate._override_cache = candidate_saved
	# Hero scalar API is unchanged; compare every authored rank as a regression check.
	var hero_cells: int = 0
	for hero_id in source_before.get("heroes", {}):
		for token in source_before.heroes[hero_id].get("parameters", {}):
			var parameter: Dictionary = source_before.heroes[hero_id].parameters[token]
			for rank in range(1, parameter.get("values", []).size() + 1):
				_check(Original.parameter(hero_id, token, rank) == Candidate.parameter(hero_id, token, rank), "hero:" + hero_id + ":" + token + ":" + str(rank))
				hero_cells += 1
	var rounds: Array = []
	# Four paired rounds, AB / BA / AB / BA. Both caches already initialized.
	for round_index in range(4):
		var order: Array = ["original", "candidate"] if round_index % 2 == 0 else ["candidate", "original"]
		for arm in order:
			var timer: int = Time.get_ticks_usec()
			var sum: float = 0.0
			if arm == "original":
				for iteration in range(ITERATIONS):
					for token in ["G24-1", "G24-2", "G24-3"]:
						sum += Original.hex_parameter("common_g24", token)
			else:
				for iteration in range(ITERATIONS):
					for token in ["G24-1", "G24-2", "G24-3"]:
						sum += Candidate.hex_parameter("common_g24", token)
			var elapsed: int = Time.get_ticks_usec() - timer
			var expected: float = ITERATIONS * (Original.hex_parameter("common_g24", "G24-1") + Original.hex_parameter("common_g24", "G24-2") + Original.hex_parameter("common_g24", "G24-3"))
			_check(sum == expected, "benchmark_checksum:" + arm)
			rounds.append({"round": round_index, "arm": arm, "calls": ITERATIONS * 3, "elapsed_usec": elapsed, "sum": sum})
	_check(Candidate.data() == source_before, "final_source_unchanged")
	_check(Candidate.effective_overrides() == overrides_before, "final_overrides_unchanged")
	report = {"status": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures, "hex_cells": cells, "spellings": spellings, "percent_cells": fractions, "hero_rank_cells": hero_cells, "rounds": rounds, "total_usec": Time.get_ticks_usec() - started, "scope": "source06_catalog_only_GUI_microbenchmark_not_game_frame", "source_unchanged": Candidate.data() == source_before, "override_unchanged": Candidate.effective_overrides() == overrides_before}
	var output: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="):
			output = arg.trim_prefix("--evidence=")
	if output.is_empty() or not output.is_absolute_path():
		push_error("Explicit absolute --evidence directory required")
		get_tree().quit(4)
		return
	var path: String = output.path_join("report.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		get_tree().quit(4)
		return
	var encoded: String = JSON.stringify(report, "  ") + "\n"
	file.store_string(encoded)
	file.flush()
	file.close()
	if FileAccess.get_file_as_string(path) != encoded:
		get_tree().quit(4)
		return
	$Status.text = str(report.status) + ": " + str(checks) + " checks"
	print(JSON.stringify({"status": report.status, "report_path": path, "sha256": FileAccess.get_sha256(path)}))
	get_tree().quit(0 if failures.is_empty() else 4)

func _mutate_nested(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if _mutate_nested(value[key]):
				return true
		value["__isolation_probe"] = true
		return true
	if value is Array:
		value.append("__isolation_probe")
		return true
	return false
