extends SceneTree
## Pure adapter/consumer gate. Synthetic scalar cases are not real-hit evidence.
const Adapter = preload("res://equipment_expansion_20261009/adapter.gd")
const Passive18 = preload("res://equipment_expansion_20261009/passive18.gd")
const Prior = preload("res://tests/ink_equipment_live_20261008/content01/adapter.gd")
const NUMERIC := "res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json"
const REQUIRED_GROUPS := ["preserve_32_and_admit_a05", "source_parameter_validation", "target_rank_and_hp_boundaries", "unique_passive_selection"]
var checks: int = 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var groups: Array[String] = []
var current_group: String = "startup"
var output_path: String = "user://equipment_a05_mechanism_gate.json"

func _initialize() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--equipment-a05-result="):
   output_path = argument.trim_prefix("--equipment-a05-result=")
 run.call_deferred()

func check(accepted: bool, label: String) -> bool:
 checks += 1
 records.append({"group":current_group, "passed":accepted, "label":label})
 if not accepted:
  failures.append(label)
  push_error(label)
 return accepted

func near(actual: float, expected: float, label: String) -> void:
 check(is_finite(actual) and absf(actual - expected) < 0.000000001, label + ": " + str(actual) + " expected " + str(expected))

func complete() -> void:
 check(current_group in REQUIRED_GROUPS and current_group not in groups, "unique group completion: " + current_group)
 groups.append(current_group)

func adapter_case(numeric: Dictionary) -> Dictionary:
 current_group = REQUIRED_GROUPS[0]
 var before: PackedByteArray = var_to_bytes(numeric)
 var old: Dictionary = Prior.build(numeric)
 var result: Dictionary = Adapter.build(numeric)
 if not check(old.get("accepted", false) and result.get("accepted", false), "old and A05 adapters accept original source numeric map"): return {}
 check(before == var_to_bytes(numeric), "adapter never mutates supplied source numeric map")
 check(result.definitions.size() == old.definitions.size() + 1 and result.definitions.has("final:A05"), "A05 is the only extra definition")
 var count: int = 0
 for key: String in old.definitions:
  check(var_to_bytes(old.definitions[key]) == var_to_bytes(result.definitions[key]), "original definition unchanged: " + key)
  if old.definitions[key].get("supported", false): count += 1
 check(count == 32, "exactly 32 original supported items remain supported")
 for key: String in old:
  if key != "definitions": check(var_to_bytes(old[key]) == var_to_bytes(result[key]), "original adapter metadata unchanged: " + key)
 var a05: Dictionary = result.definitions["final:A05"]
 check(a05.supported and a05.passives == ["passive:18"] and a05.actives.is_empty() and a05.tier == "final", "A05 has its one complete source passive and no invented active")
 near(float(a05.stats.AD), 55.0, "source A05 AD")
 near(float(a05.stats.crit_chance), 0.20, "source A05 crit percent points converted once")
 near(float(a05.stats.penetration), 20.0, "source A05 penetration")
 check(a05.parameters.size() == 3 and a05.passive18_parameters.size() == 4, "all seven consumed parameters retain provenance")
 for reference: Dictionary in a05.parameters + a05.passive18_parameters:
  check(not str(reference.source_ref).is_empty(), "source reference retained for " + str(reference.parameter))
 check(a05.passive18 == {"base_damage_bonus":12.0, "damage_bonus_cap":20.0, "lost_hp_step":25.0, "step_damage_bonus":2.0}, "four passive source values remain in percent-point units")
 var changed: Dictionary = numeric.duplicate(true)
 changed.parameters["final:A05.stat.AD"].value = 77.5
 changed.parameters["passive:18.base_damage_bonus"].value = 15.0
 changed.parameters["passive:18.damage_bonus_cap"].value = 25.0
 var edited: Dictionary = Adapter.build(changed)
 check(edited.get("accepted", false), "formally editable current values stay supported")
 if edited.get("accepted", false):
  near(float(edited.definitions["final:A05"].stats.AD), 77.5, "edited current AD used instead of source_value")
  near(Passive18.factor({"rank_category":"boss", "hp":1000.0, "max_hp":1000.0}, edited.definitions["final:A05"].passive18), 1.15, "edited passive current value reaches consumer")
 complete()
 return result

func validation_case(numeric: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[1]
 check(not Adapter.build({}).get("accepted", false), "missing numeric map is rejected")
 var keys: Array[String] = ["final:A05.stat.AD", "final:A05.stat.crit_chance_pct", "final:A05.stat.penetration", "passive:18.base_damage_bonus", "passive:18.damage_bonus_cap", "passive:18.lost_hp_step", "passive:18.step_damage_bonus"]
 for key: String in keys:
  var missing: Dictionary = numeric.duplicate(true)
  missing.parameters.erase(key)
  check(not Adapter.build(missing).get("accepted", false), "missing required parameter rejected: " + key)
  for invalid: Variant in [null, "12", true, -1.0, NAN, INF]:
   var bad: Dictionary = numeric.duplicate(true)
   bad.parameters[key].value = invalid
   check(not Adapter.build(bad).get("accepted", false), "invalid numeric type/range rejected: " + key + ": " + str(invalid))
  var wrong_unit: Dictionary = numeric.duplicate(true)
  wrong_unit.parameters[key].unit = "incorrect_unit"
  check(not Adapter.build(wrong_unit).get("accepted", false), "wrong parameter unit rejected: " + key)
  var scalar: Dictionary = numeric.duplicate(true)
  scalar.parameters[key] = 12.0
  check(not Adapter.build(scalar).get("accepted", false), "scalar parameter node rejected: " + key)
 var zero_step: Dictionary = numeric.duplicate(true)
 zero_step.parameters["passive:18.lost_hp_step"].value = 0.0
 check(not Adapter.build(zero_step).get("accepted", false), "zero loss-step denominator rejected")
 var invalid_cap: Dictionary = numeric.duplicate(true)
 invalid_cap.parameters["passive:18.damage_bonus_cap"].value = 11.0
 check(not Adapter.build(invalid_cap).get("accepted", false), "cap below base bonus rejected")
 var prior_invalid: Dictionary = numeric.duplicate(true)
 prior_invalid.parameters["base:B01.stat.AD"].value = -1.0
 check(not Adapter.build(prior_invalid).get("accepted", false), "prior adapter validation remains authoritative")
 complete()

func boundary_case(tuning: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[2]
 for rank: String in ["ordinary", "minion", "armored", "", "BOSS"]:
  near(Passive18.factor({"rank_category":rank, "hp":250.0, "max_hp":1000.0}, tuning), 1.0, "non-source rank never qualifies: " + rank)
 near(Passive18.factor({"kind":"boss", "hp":100.0, "max_hp":1000.0}, tuning), 1.0, "kind/name does not substitute for actual rank category")
 for rank: String in ["elite", "boss"]:
  for pair: Array in [[1000.0,1.12], [750.000001,1.12], [750.0,1.14], [749.999999,1.14], [500.000001,1.14], [500.0,1.16], [499.999999,1.16], [250.000001,1.16], [250.0,1.18], [249.999999,1.18], [0.001,1.18], [0.0,1.20]]:
   var target: Dictionary = {"rank_category":rank, "hp":float(pair[0]), "max_hp":1000.0}
   var before: PackedByteArray = var_to_bytes([target,tuning])
   near(Passive18.factor(target, tuning), float(pair[1]), rank + " pre-hit HP boundary " + str(pair[0]))
   check(before == var_to_bytes([target,tuning]), "pure factor does not mutate target or tuning")
 var capped: Dictionary = tuning.duplicate(true)
 capped.damage_bonus_cap = 15.0
 near(Passive18.factor({"rank_category":"boss", "hp":0.0, "max_hp":1000.0}, capped), 1.15, "edited cap is enforced without raising source step bonus")
 var zero_increment: Dictionary = tuning.duplicate(true)
 zero_increment.step_damage_bonus = 0.0
 near(Passive18.factor({"rank_category":"elite", "hp":0.0, "max_hp":1000.0}, zero_increment), 1.12, "zero edited increment leaves base bonus")
 for hp: Variant in [null, "100", true, -0.000001, 1000.000001, NAN, INF]:
  near(Passive18.factor({"rank_category":"boss", "hp":hp, "max_hp":1000.0}, tuning), 1.0, "invalid current HP is inert: " + str(hp))
 for maximum: Variant in [null, "1000", true, -1.0, 0.0, NAN, INF]:
  near(Passive18.factor({"rank_category":"boss", "hp":0.0, "max_hp":maximum}, tuning), 1.0, "invalid maximum HP is inert: " + str(maximum))
 near(Passive18.factor({}, tuning), 1.0, "missing actual target is inert")
 for key: String in Passive18.TUNING_KEYS:
  var missing: Dictionary = tuning.duplicate(true)
  missing.erase(key)
  near(Passive18.factor({"rank_category":"boss", "hp":100.0, "max_hp":1000.0}, missing), 1.0, "missing tuning parameter is inert: " + key)
  for value: Variant in [null, "2", true, -1.0, NAN, INF]:
   var malformed: Dictionary = tuning.duplicate(true)
   malformed[key] = value
   near(Passive18.factor({"rank_category":"boss", "hp":100.0, "max_hp":1000.0}, malformed), 1.0, "invalid direct tuning is inert: " + key + ": " + str(value))
 var zero_denominator: Dictionary = tuning.duplicate(true)
 zero_denominator.lost_hp_step = 0.0
 near(Passive18.factor({"rank_category":"boss", "hp":100.0, "max_hp":1000.0}, zero_denominator), 1.0, "direct zero denominator is inert")
 var below_base: Dictionary = tuning.duplicate(true)
 below_base.damage_bonus_cap = 1.0
 near(Passive18.factor({"rank_category":"boss", "hp":100.0, "max_hp":1000.0}, below_base), 1.0, "direct cap below base is inert")
 complete()

func selection_case(definitions: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[3]
 var inventory: Array = [{"id":"final:A05", "uid":11, "count":1}, {"id":"final:A05", "uid":11, "count":1}, {"id":"final:A05", "uid":12, "count":2}]
 var original: PackedByteArray = var_to_bytes([inventory,definitions])
 var chosen: Dictionary = Passive18.select_unique(inventory, definitions)
 check(chosen.equipped and chosen.item_id == "final:A05" and chosen.uid == 11 and chosen.owned_copies == 3, "duplicate UID ignored and actual copies observed without multiplying passive")
 near(Passive18.factor({"rank_category":"boss", "hp":1000.0, "max_hp":1000.0}, chosen.tuning), 1.12, "three copies still supply one 12% passive")
 check(original == var_to_bytes([inventory,definitions]), "selection never changes ledger inventory or runtime definitions")
 chosen.tuning.base_damage_bonus = 99.0
 check(float(definitions["final:A05"].passive18.base_damage_bonus) == 12.0, "returned tuning is a detached copy")
 var empty: Dictionary = Passive18.select_unique([], definitions)
 check(not empty.equipped and empty.tuning.is_empty(), "no held A05 produces no active passive")
 near(Passive18.factor({"rank_category":"boss", "hp":10.0, "max_hp":1000.0}, empty.tuning), 1.0, "unequipped multiplier is exactly one")
 for held: Variant in [null, "A05", {}, {"id":"final:A05", "uid":1, "count":0}, {"id":"final:A05", "uid":1, "count":-1}, {"id":"final:A05", "uid":1, "count":1.5}, {"id":"final:A05", "uid":-1, "count":1}, {"id":"final:A05", "uid":"1", "count":1}, {"id":"final:G06", "uid":1, "count":1}]:
  check(not Passive18.select_unique([held], definitions).equipped, "invalid/unadmitted held entry cannot activate passive: " + str(held))
 var unsupported: Dictionary = definitions.duplicate(true)
 unsupported["final:A05"].supported = false
 check(not Passive18.select_unique(inventory, unsupported).equipped, "held but unsupported item remains inert")
 var unnamed: Dictionary = definitions.duplicate(true)
 unnamed["final:A05"].passives = []
 check(not Passive18.select_unique(inventory, unnamed).equipped, "stats alone cannot infer a passive")
 var bad_tuning: Dictionary = definitions.duplicate(true)
 bad_tuning["final:A05"].passive18.lost_hp_step = 0.0
 check(not Passive18.select_unique(inventory, bad_tuning).equipped, "invalid active definition cannot grant a multiplier")
 check(not Passive18.select_unique(inventory, {}).equipped, "missing runtime definition is inert")
 complete()

func run() -> void:
 var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NUMERIC))
 if not check(parsed is Dictionary, "source numeric JSON loads"):
  finish(); return
 var result: Dictionary = adapter_case(parsed)
 if not result.is_empty():
  validation_case(parsed)
  boundary_case(result.definitions["final:A05"].passive18)
  selection_case(result.definitions)
 finish()

func finish() -> void:
 current_group = "report"
 check(groups == REQUIRED_GROUPS, "all four pure mechanism groups complete")
 check(records.size() == checks, "every check has an outcome")
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 check(file != null, "mechanism report path writable")
 var report: Dictionary = {"suite":"equipment_a05_source_adapter_and_pure_passive18", "passed":failures.is_empty() and groups == REQUIRED_GROUPS, "checks":checks, "failures":failures, "groups":groups, "records":records, "numeric_sha256":FileAccess.get_sha256(NUMERIC), "adapter_sha256":FileAccess.get_sha256("res://equipment_expansion_20261009/adapter.gd"), "consumer_sha256":FileAccess.get_sha256("res://equipment_expansion_20261009/passive18.gd"), "runtime_status":"EXECUTED", "pure_scalar_fixtures":true, "actual_source_damage":false, "commerce_integration":false, "native_input":false, "natural_full_floor":false}
 if file != null:
  file.store_string(JSON.stringify(report, "  "))
  var error: Error = file.get_error()
  file.close()
  if error != OK:
   check(false, "mechanism report write completed")
   report.checks = checks; report.failures = failures; report.records = records; report.passed = false
 print("EQUIPMENT_A05_MECHANISM ", JSON.stringify(report))
 quit(0 if report.passed else 1)
