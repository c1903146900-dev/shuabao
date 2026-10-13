extends SceneTree
## Prepared pure fixtures only. This author did not run Godot or real combat.
const Adapter = preload("adapter.gd")
const Passive18 = preload("passive18.gd")
const Prior = preload("res://equipment_kill_20261009/adapter.gd")
const Original = preload("res://equipment_expansion_20261009/passive18.gd")
const NUMERIC := "res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json"
const SOURCE := "res://docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json"
const REQUIRED_GROUPS := ["preserve_36_prepare_37", "strict_parameters_and_edited_values", "source_recipe_and_zero_sp_stage", "shared_unique_and_evolution", "exact_original_prehit_boundaries", "pure_fail_closed_inputs"]
var checks: int = 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var groups: Array[String] = []
var current_group: String = "startup"
var output_path: String = "user://equipment_g06_mechanism_gate.json"

func _initialize() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--equipment-g06-result="):
   output_path = argument.trim_prefix("--equipment-g06-result=")
 run.call_deferred()

func check(accepted: bool, label: String) -> bool:
 checks += 1
 records.append({"group":current_group, "passed":accepted, "label":label})
 if not accepted:
  failures.append(label)
  push_error(label)
 return accepted

func near(actual: float, expected: float, label: String) -> void:
 check(is_finite(actual) and absf(actual - expected) <= 0.000000001, label + ": " + str(actual) + " expected " + str(expected))

func complete() -> void:
 check(current_group in REQUIRED_GROUPS and current_group not in groups, "unique group completion: " + current_group)
 groups.append(current_group)

func adapter_case(numeric: Dictionary, source: Dictionary) -> Dictionary:
 current_group = REQUIRED_GROUPS[0]
 var before: PackedByteArray = var_to_bytes([numeric, source])
 var prior: Dictionary = Prior.build(numeric)
 var result: Dictionary = Adapter.build(numeric)
 if not check(prior.get("accepted", false) and result.get("accepted", false), "original source accepts prior36 and prepared37 adapters"): return {}
 check(before == var_to_bytes([numeric, source]), "adapter does not mutate either source")
 check(result.definitions.size() == prior.definitions.size() + 1, "only G06 definition added")
 var prior_count: int = 0
 for item_id: String in prior.definitions:
  check(var_to_bytes(prior.definitions[item_id]) == var_to_bytes(result.definitions[item_id]), "prior definition deeply unchanged: " + item_id)
  if prior.definitions[item_id].get("supported", false): prior_count += 1
 check(prior_count == 36, "exactly36 prior supported items")
 for key: String in prior:
  if key != "definitions": check(var_to_bytes(prior[key]) == var_to_bytes(result[key]), "prior top-level metadata unchanged: " + key)
 var admitted: int = 0
 for definition: Dictionary in result.definitions.values():
  if definition.get("supported", false): admitted += 1
 check(admitted == 37, "exactly37 prepared definitions")
 var g06: Dictionary = result.definitions[Adapter.ITEM_ID]
 check(g06.stats == {"AD":45.0, "AP":65.0, "penetration":20.0}, "G06 source base stats")
 check(g06.passives == ["passive:18"] and g06.actives.is_empty() and g06.tier == "final", "exact original single passive identity")
 check(g06.passive18 == result.definitions["final:A05"].passive18, "unevolved G06 and A05 share equal tuning")
 check(g06.passive18_evolved == {"base_damage_bonus":15.0, "damage_bonus_cap":25.0, "lost_hp_step":25.0, "step_damage_bonus":2.0}, "evolution changes only source base12to15 and cap20to25")
 check(g06.taskG06.threshold == 100000.0 and g06.taskG06.reward_skill_points == 0 and g06.taskG06.stage_id == "task:G06:1", "single100000 actual damage task with zero SP")
 check(g06.runtime_complete == false and g06.runtime_status == "inert_until_source_bridge_connected", "prepared data never claims runtime completion")
 check(g06.requires_source_bridge.size() == 4, "four live integration obligations retained")
 check(g06.taskG06_contract.scope == "player_equipment_name" and g06.taskG06_contract.held_only and g06.taskG06_contract.retained_when_sold and g06.taskG06_contract.evolution_retained_when_sold and not g06.taskG06_contract.duplicate_copies_multiply_progress, "source task persistence and duplicate-copy contract")
 for reference: Dictionary in g06.parameters + g06.passive18_parameters + g06.taskG06_parameters + g06.commerce_parameters:
  var original: Dictionary = numeric.parameters[reference.parameter]
  check(not str(reference.source_ref).is_empty() and reference.current_value == original.value and reference.source_value == original.source_value and reference.source_unit == original.unit, "numeric provenance retained: " + str(reference.parameter))
 complete()
 return result

func validation_case(numeric: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[1]
 check(not Adapter.build({}).get("accepted", false), "numeric map required")
 var keys: Array[String] = ["final:G06.price", "final:G06.stat.AD", "final:G06.stat.AP", "final:G06.stat.penetration", "passive:18.base_damage_bonus", "passive:18.damage_bonus_cap", "passive:18.lost_hp_step", "passive:18.step_damage_bonus", "task:G06.threshold", "task:G06.evolved_base_bonus", "task:G06.evolved_bonus_cap", "intermediate:I04.price", "intermediate:I14.price", "base:B11.price"]
 for key: String in keys:
  var missing: Dictionary = numeric.duplicate(true)
  missing.parameters.erase(key)
  check(not Adapter.build(missing).get("accepted", false), "missing parameter rejected: " + key)
  for invalid: Variant in [null, true, "15", -1.0, NAN, INF]:
   var bad: Dictionary = numeric.duplicate(true)
   bad.parameters[key].value = invalid
   check(not Adapter.build(bad).get("accepted", false), "bad value rejected: " + key + ": " + str(invalid))
  var wrong_unit: Dictionary = numeric.duplicate(true)
  wrong_unit.parameters[key].unit = "wrong_unit"
  check(not Adapter.build(wrong_unit).get("accepted", false), "wrong unit rejected: " + key)
  var scalar: Dictionary = numeric.duplicate(true)
  scalar.parameters[key] = 15.0
  check(not Adapter.build(scalar).get("accepted", false), "scalar node rejected: " + key)
 for pair: Array in [["task:G06.threshold", 0.0], ["passive:18.lost_hp_step", 0.0], ["passive:18.damage_bonus_cap", 11.0], ["task:G06.evolved_bonus_cap", 14.0], ["final:G06.price", 3400.5], ["base:B11.price", 450.5]]:
  var bad: Dictionary = numeric.duplicate(true)
  bad.parameters[pair[0]].value = pair[1]
  check(not Adapter.build(bad).get("accepted", false), "invalid parameter bound: " + str(pair))
 for key: String in ["task:G06.evolved_lost_hp_step", "task:G06.reward_skill_points", "passive:18.hit_count"]:
  var extra: Dictionary = numeric.duplicate(true)
  extra.parameters[key] = {"value":1, "unit":"count"}
  check(not Adapter.build(extra).get("accepted", false), "unsupported extra mechanism field rejected: " + key)
 var edited: Dictionary = numeric.duplicate(true)
 edited.parameters["final:G06.stat.AD"].value = 47.5
 edited.parameters["final:G06.stat.AP"].value = 70.25
 edited.parameters["final:G06.price"].value = 3500
 edited.parameters["intermediate:I14.price"].value += 50
 edited.parameters["task:G06.threshold"].value = 100000.5
 edited.parameters["task:G06.evolved_base_bonus"].value = 16.0
 edited.parameters["task:G06.evolved_bonus_cap"].value = 26.0
 var changed: Dictionary = Adapter.build(edited)
 check(changed.get("accepted", false), "edited current values accepted without freezing original numeric values")
 if changed.get("accepted", false):
  var g06: Dictionary = changed.definitions[Adapter.ITEM_ID]
  check(g06.stats.AD == 47.5 and g06.stats.AP == 70.25 and g06.taskG06.threshold == 100000.5, "stats and damage threshold use exact current values")
  check(g06.commerce.price == 3500.0 and g06.commerce.component_total == 2950.0 and g06.commerce.combine_fee == 550.0, "commerce recomputed from current prices, not stale derived metadata")
  check(g06.passive18_evolved.base_damage_bonus == 16.0 and g06.passive18_evolved.damage_bonus_cap == 26.0, "evolution reads current task parameters")
  check(g06.passive18_evolved.lost_hp_step == 25.0 and g06.passive18_evolved.step_damage_bonus == 2.0, "evolution preserves step parameters")
  near(Passive18.factor({"rank_category":"boss", "hp":1000.0, "max_hp":1000.0}, g06.passive18_evolved), 1.16, "edited source reaches unchanged factor")
 for key: String in ["base:B01.stat.AD", "final:A05.stat.AD", "final:B03.stat.AD", "final:C06.stat.AP", "final:B01.stat.AD"]:
  var bad_prior: Dictionary = numeric.duplicate(true)
  bad_prior.parameters[key].value = -1.0
  check(not Adapter.build(bad_prior).get("accepted", false), "prior validation remains authoritative: " + key)
 complete()

func source_case(numeric: Dictionary, source: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[2]
 var item: Dictionary = {}
 var task: Dictionary = {}
 for candidate: Dictionary in source.get("equipment", []):
  if candidate.id == Adapter.ITEM_ID: item = candidate
 for candidate: Dictionary in source.get("tasks", []):
  if candidate.equipment_id == Adapter.ITEM_ID: task = candidate
 check(not item.is_empty() and item.get("name") == "猎王徽章" and item.get("source_price") == 3400 and item.get("source_component_total") == 2900 and item.get("source_combine_fee") == 500 and item.get("mechanism_ids") == ["passive:18"], "extraction agrees on G06 identity, price, recipe totals and passive")
 var recipe: Dictionary = {}
 for component: Dictionary in item.get("components", []): recipe[component.item_id] = int(component.quantity)
 check(recipe == Adapter.RECIPE, "both sources agree on I04+I14+baseB11 x1")
 for phrase: String in ["100000", "实际造成", "目标实际损失生命", "12%→15%", "20%→25%", "不奖励技能点", "只能完成1次"]:
  check(str(task.get("source_task", "")).contains(phrase), "task authority retains: " + phrase)
 var built: Dictionary = Adapter.build(numeric)
 if built.get("accepted", false):
  check(built.definitions[Adapter.ITEM_ID].commerce.combine_fee == 500.0, "current source combine fee500")
 for invalid: Variant in [null, {}, []]:
  var bad: Dictionary = numeric.duplicate(true)
  bad.task_stages = invalid
  check(not Adapter.build(bad).get("accepted", false), "source task stage mandatory")
 var duplicate: Dictionary = numeric.duplicate(true)
 duplicate.task_stages.append(Adapter._task_stage(duplicate.task_stages))
 check(not Adapter.build(duplicate).get("accepted", false), "duplicate completion stage rejected")
 for patch: Dictionary in [{"reward_skill_points":1}, {"reward_skill_points":true}, {"stage":2}, {"stage_id":"task:G06:2"}, {"threshold_parameter_id":"task:B01.threshold"}, {"source_ref":""}]:
  var bad: Dictionary = numeric.duplicate(true)
  for stage: Dictionary in bad.task_stages:
   if stage.task_id == Adapter.TASK_ID: stage.merge(patch, true)
  check(not Adapter.build(bad).get("accepted", false), "invalid task stage rejected: " + str(patch))
 var missing_recipe: Dictionary = numeric.duplicate(true)
 missing_recipe.recipes = []
 check(not Adapter.build(missing_recipe).get("accepted", false), "recipe cannot be inferred if absent")
 for patch: Dictionary in [{"quantity":2}, {"component_id":"base:B01"}, {"recipe_id":"other"}, {"source_ref":""}]:
  var bad: Dictionary = numeric.duplicate(true)
  for row: Dictionary in bad.recipes:
   if row.result_id == Adapter.ITEM_ID and row.component_id == "base:B11": row.merge(patch, true)
  check(not Adapter.build(bad).get("accepted", false), "unauthorized recipe change rejected: " + str(patch))
 var duplicate_recipe: Dictionary = numeric.duplicate(true)
 for row: Dictionary in numeric.recipes:
  if row.result_id == Adapter.ITEM_ID:
   duplicate_recipe.recipes.append(row.duplicate(true))
   break
 check(not Adapter.build(duplicate_recipe).get("accepted", false), "duplicate source recipe row rejected")
 complete()

func selection_case(definitions: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[3]
 var a05: Dictionary = {"id":"final:A05", "uid":11, "count":1}
 var g06: Dictionary = {"id":"final:G06", "uid":21, "count":1}
 for held: Array in [[a05, g06], [g06, a05]]:
  var unevolved: Dictionary = Passive18.select_unique(held, definitions, false)
  check(unevolved.equipped and unevolved.owned_copies == 2 and not unevolved.evolved, "two equal-name final suppliers select only one unevolved passive")
  near(Passive18.factor({"rank_category":"boss", "hp":1000.0, "max_hp":1000.0}, unevolved.tuning), 1.12, "A05 plus unevolved G06 is one12percent multiplier")
  var evolved: Dictionary = Passive18.select_unique(held, definitions, true)
  check(evolved.equipped and evolved.item_id == "final:G06" and evolved.evolved, "stronger evolved G06 selected regardless of inventory order")
  near(Passive18.factor({"rank_category":"boss", "hp":1000.0, "max_hp":1000.0}, evolved.tuning), 1.15, "A05 plus evolved G06 is one15percent multiplier")
 var copies: Array = [a05, a05, g06, g06, {"id":"final:G06", "uid":22, "count":2}]
 var selection: Dictionary = Passive18.select_unique(copies, definitions, true)
 check(selection.owned_copies == 4 and selection.uid == 21 and selection.item_id == "final:G06", "repeat UIDs ignored and true copies counted without stacking")
 near(float(definitions[Adapter.ITEM_ID].stats.AD) * 3.0, 135.0, "three G06 base-stat copies remain independent of unique passive")
 var sold: Dictionary = Passive18.select_unique([a05], definitions, true)
 check(sold.item_id == "final:A05" and not sold.evolved, "permanent G06 evolution does not upgrade remaining A05 when G06 sold")
 near(Passive18.factor({"rank_category":"boss", "hp":250.0, "max_hp":1000.0}, sold.tuning), 1.18, "sold G06 leaves original A05 multiplier")
 check(not Passive18.select_unique([], definitions, true).equipped, "evolution alone never grants an unheld item passive")
 check(Passive18.select_unique([g06], definitions, true).evolved, "repurchased G06 can consume retained Model evolution")
 var downgraded: Dictionary = definitions.duplicate(true)
 downgraded[Adapter.ITEM_ID].passive18_evolved.base_damage_bonus = 11.0
 downgraded[Adapter.ITEM_ID].passive18_evolved.damage_bonus_cap = 19.0
 check(Passive18.select_unique([g06, a05], downgraded, true).item_id == "final:A05", "same-tier current stronger values win rather than blindly preferring evolution label")
 var crossed: Dictionary = definitions.duplicate(true)
 crossed[Adapter.ITEM_ID].passive18_evolved.damage_bonus_cap = 19.0
 var ambiguous: Dictionary = Passive18.select_unique([a05, g06], crossed, true)
 check(not ambiguous.equipped and ambiguous.reason == "ambiguous_same_tier_strength", "crossed edited strengths reported without inventing a tie rule")
 complete()

func boundary_case(definitions: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[4]
 for evolved: bool in [false, true]:
  var tuning: Dictionary = definitions[Adapter.ITEM_ID]["passive18_evolved" if evolved else "passive18"]
  var offset: float = 0.03 if evolved else 0.0
  for rank: String in ["elite", "boss"]:
   for pair: Array in [[1000.0, 1.12], [750.000001, 1.12], [750.0, 1.14], [749.999999, 1.14], [500.000001, 1.14], [500.0, 1.16], [499.999999, 1.16], [250.000001, 1.16], [250.0, 1.18], [249.999999, 1.18], [0.001, 1.18], [0.0, 1.20]]:
    var target: Dictionary = {"rank_category":rank, "hp":float(pair[0]), "max_hp":1000.0}
    near(Passive18.factor(target, tuning), float(pair[1]) + offset, "exact floor boundary evolved=" + str(evolved) + " " + rank + " hp=" + str(pair[0]))
    check(Passive18.factor(target, tuning) == Original.factor(target, tuning), "delegation is exactly original floating-point result")
  for rank: String in ["ordinary", "minion", "armored", "", "BOSS"]:
   near(Passive18.factor({"rank_category":rank, "hp":250.0, "max_hp":1000.0}, tuning), 1.0, "non-elite/boss rank neutral")
  near(Passive18.factor({"kind":"boss", "hp":250.0, "max_hp":1000.0}, tuning), 1.0, "enemy name or kind cannot replace actual rank")
 var capped: Dictionary = definitions[Adapter.ITEM_ID].passive18_evolved.duplicate(true)
 capped.damage_bonus_cap = 16.0
 near(Passive18.factor({"rank_category":"boss", "hp":0.0, "max_hp":1000.0}, capped), 1.16, "formally edited cap enforced")
 var zero: Dictionary = definitions[Adapter.ITEM_ID].passive18_evolved.duplicate(true)
 zero.step_damage_bonus = 0.0
 zero.lost_hp_step = 1e-20
 near(Passive18.factor({"rank_category":"boss", "hp":0.0, "max_hp":1000.0}, zero), 1.15, "zero increment preserved with tiny source step")
 complete()

func invalid_case(definitions: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[5]
 var held: Array = [{"id":"final:A05", "uid":11, "count":1}, {"id":"final:G06", "uid":21, "count":2}]
 var target: Dictionary = {"rank_category":"boss", "hp":250.0, "max_hp":1000.0}
 var before: PackedByteArray = var_to_bytes([held, definitions, target])
 var selected: Dictionary = Passive18.select_unique(held, definitions, true)
 near(Passive18.factor(target, selected.tuning), 1.21, "living evolved75percent-lost target remains21percent despite cap25")
 selected.tuning.base_damage_bonus = 99.0
 check(definitions[Adapter.ITEM_ID].passive18_evolved.base_damage_bonus == 15.0, "selected tuning detached")
 for malformed: Variant in [null, "G06", {}, {"id":"final:G06", "uid":21, "count":0}, {"id":"final:G06", "uid":21, "count":1.5}, {"id":"final:G06", "uid":-1, "count":1}, {"id":"final:G06", "uid":"21", "count":1}, {"id":"base:G06", "uid":21, "count":1}]:
  check(not Passive18.select_unique([malformed], definitions, true).equipped, "invalid/foreign inventory entry inert")
 var conflict: Array = [{"id":"final:A05", "uid":11, "count":1}, {"id":"final:G06", "uid":11, "count":1}]
 check(Passive18.select_unique(conflict, definitions, true).reason == "conflicting_inventory_uid", "one UID cannot represent two equipment identities")
 for malformed: Variant in [null, {}, {"supported":false}, {"supported":true, "tier":"base", "passives":["passive:18"]}, {"supported":true, "tier":"final", "passives":["passive:18", "passive:18"]}]:
  var bad: Dictionary = definitions.duplicate(true)
  bad[Adapter.ITEM_ID] = malformed
  check(not Passive18.select_unique([held[1]], bad, true).equipped, "invalid G06 definition inert")
 var missing_evolved: Dictionary = definitions.duplicate(true)
 missing_evolved[Adapter.ITEM_ID].erase("passive18_evolved")
 check(not Passive18.select_unique([held[1]], missing_evolved, true).equipped, "evolution cannot fabricate missing tuned definition")
 var tuning: Dictionary = definitions[Adapter.ITEM_ID].passive18_evolved
 for hp: Variant in [null, "100", true, -0.000001, 1000.000001, NAN, INF]:
  near(Passive18.factor({"rank_category":"boss", "hp":hp, "max_hp":1000.0}, tuning), 1.0, "invalid target HP inert")
 for maximum: Variant in [null, "1000", true, -1.0, 0.0, NAN, INF]:
  near(Passive18.factor({"rank_category":"boss", "hp":0.0, "max_hp":maximum}, tuning), 1.0, "invalid max HP inert")
 for key: String in Passive18.TUNING_KEYS:
  var missing: Dictionary = tuning.duplicate(true)
  missing.erase(key)
  near(Passive18.factor(target, missing), 1.0, "missing tuning field inert")
  for invalid: Variant in [null, "2", true, -1.0, NAN, INF]:
   var bad: Dictionary = tuning.duplicate(true)
   bad[key] = invalid
   near(Passive18.factor(target, bad), 1.0, "bad tuning value inert")
 var extra: Dictionary = tuning.duplicate(true)
 extra.hit_count = 2
 near(Passive18.factor(target, extra), 1.0, "unknown tuning field not silently admitted")
 check(before == var_to_bytes([held, definitions, target]), "all calculations and rejections preserve caller inputs")
 complete()

func run() -> void:
 var numeric: Variant = JSON.parse_string(FileAccess.get_file_as_string(NUMERIC))
 var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
 if not check(numeric is Dictionary and source is Dictionary, "both authoritative files load"):
  finish(); return
 var result: Dictionary = adapter_case(numeric, source)
 if not result.is_empty():
  validation_case(numeric)
  source_case(numeric, source)
  selection_case(result.definitions)
  boundary_case(result.definitions)
  invalid_case(result.definitions)
 finish()

func finish() -> void:
 current_group = "report"
 check(groups == REQUIRED_GROUPS, "all six pure groups completed")
 check(records.size() == checks, "each check recorded")
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 check(file != null, "mechanism report path writable")
 var report: Dictionary = {"suite":"equipment_g06_prepared_adapter_shared_pure_passive18", "passed":failures.is_empty() and groups == REQUIRED_GROUPS, "checks":checks, "failures":failures, "groups":groups, "records":records, "numeric_sha256":FileAccess.get_sha256(NUMERIC), "source_sha256":FileAccess.get_sha256(SOURCE), "runtime_status":"EXECUTED_PURE_FIXTURES_ONLY", "pure_scalar_fixtures":true, "actual_source_damage_authentication":false, "actual_damage_progress":false, "persistent_task_evolution":false, "commerce_integration":false, "complete_g06_equipment":false, "godot_engine_executed_by_preparer":false, "native_input":false, "natural_full_floor":false}
 if file != null:
  file.store_string(JSON.stringify(report, "  "))
  var error: Error = file.get_error()
  file.close()
  if error != OK:
   check(false, "mechanism report write completed")
   report.checks = checks; report.failures = failures; report.records = records; report.passed = false
 print("EQUIPMENT_G06_MECHANISM ", JSON.stringify(report))
 quit(0 if report.passed else 1)
