extends SceneTree
## Pure source/adapter/selection gate; this does not prove live damage or commerce.
const Adapter = preload("res://equipment_distance_20261009/adapter.gd")
const Passives = preload("res://equipment_distance_20261009/passives.gd")
const Prior = preload("res://equipment_expansion_20261009/adapter.gd")
const NUMERIC := "res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json"
const SOURCE := "res://docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json"
const REQUIRED_GROUPS := ["preserve_33_and_admit_two", "source_parameter_validation", "inclusive_distance_boundaries", "unique_constant_and_stacked_base_stats", "invalid_inputs_and_purity"]
const INVENTORY := [{"id":"final:B03", "uid":11, "count":1}, {"id":"final:C06", "uid":12, "count":1}]
var checks: int = 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var groups: Array[String] = []
var current_group: String = "startup"
var output_path: String = "user://equipment_distance_mechanism_gate.json"

func _initialize() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--equipment-distance-result="):
   output_path = argument.trim_prefix("--equipment-distance-result=")
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

func recipe_matches(actual: Variant, expected: Array) -> bool:
 # JSON decodes quantities as float. Validate exact recipe fields and numeric
 # quantities, rather than nested Dictionary equality against int literals.
 if not actual is Array or actual.size() != expected.size(): return false
 for index: int in range(expected.size()):
  var component: Variant = actual[index]
  if not component is Dictionary or component.size() != 3: return false
  if component.get("item_id") != expected[index][0] or component.get("name") != expected[index][1]: return false
  var quantity: Variant = component.get("quantity")
  if not (quantity is int or quantity is float) or not is_finite(float(quantity)): return false
  if float(quantity) != float(expected[index][2]): return false
 return true

func adapter_case(numeric: Dictionary, source: Dictionary) -> Dictionary:
 current_group = REQUIRED_GROUPS[0]
 var before: PackedByteArray = var_to_bytes([numeric, source])
 var old: Dictionary = Prior.build(numeric)
 var result: Dictionary = Adapter.build(numeric)
 if not check(old.get("accepted", false) and result.get("accepted", false), "33-item and 35-item adapters accept original numeric source"): return {}
 check(before == var_to_bytes([numeric, source]), "adapter never mutates either authoritative source")
 check(result.definitions.size() == old.definitions.size() + 2, "exactly two definitions added")
 var prior_count: int = 0
 for key: String in old.definitions:
  check(var_to_bytes(old.definitions[key]) == var_to_bytes(result.definitions[key]), "prior definition deeply unchanged: " + key)
  if old.definitions[key].get("supported", false): prior_count += 1
 check(prior_count == 33, "all original 33 supported definitions preserved")
 for key: String in old:
  if key != "definitions": check(var_to_bytes(old[key]) == var_to_bytes(result[key]), "prior adapter metadata unchanged: " + key)
 var count: int = 0
 for definition: Dictionary in result.definitions.values():
  if definition.get("supported", false): count += 1
 check(count == 35, "exactly 35 supported items")
 check(not result.definitions.has("final:D04"), "D04 remains outside this admission")
 check(not result.definitions.has("final:D03"), "another source item sharing passive14 remains outside this admission")
 var b03: Dictionary = result.definitions["final:B03"]
 var c06: Dictionary = result.definitions["final:C06"]
 check(b03.stats == {"AD":45.0, "max_hp":320.0, "cooldown_reduction":0.12}, "B03 exact source base stats with one percent conversion")
 check(c06.stats == {"AP":90.0, "penetration":18.0, "move_speed":0.10}, "C06 exact source base stats with one percent conversion")
 check(not b03.stats.has("lifesteal") and float(c06.stats.penetration) == 18.0, "unique constant bonuses are absent from per-copy base stats")
 check(b03.distance_passive == {"range_threshold":4.5, "damage_bonus":12.0, "lifesteal":5.0}, "B03 tuning preserves original numeric values and units")
 check(c06.distance_passive == {"range_threshold":9.0, "damage_bonus":15.0, "penetration":12.0}, "C06 tuning preserves original numeric values and units")
 for item_id: String in Passives.ITEMS:
  var definition: Dictionary = result.definitions[item_id]
  check(definition.supported and definition.passives == [Passives.ITEMS[item_id]] and definition.actives.is_empty() and definition.tier == "final", "only complete original passive admitted: " + item_id)
  check(definition.parameters.size() == 3 and definition.distance_passive_parameters.size() == 3, "six consumed parameters retain provenance: " + item_id)
  for reference: Dictionary in definition.parameters + definition.distance_passive_parameters:
   check(not str(reference.source_ref).is_empty(), "source reference retained: " + str(reference.parameter))
   var original: Dictionary = numeric.parameters[reference.parameter]
   check(reference.current_value == original.value and reference.source_value == original.source_value and reference.source_unit == original.unit, "parameter provenance not rewritten: " + str(reference.parameter))
 var source_items: Dictionary = {}
 for item: Dictionary in source.get("equipment", []): source_items[item.id] = item
 check(source_items.has("final:B03") and source_items.has("final:C06"), "both items exist in original DOCX extraction")
 if source_items.has("final:B03") and source_items.has("final:C06"):
  var near_source: Dictionary = source_items["final:B03"]
  var far_source: Dictionary = source_items["final:C06"]
  check(near_source.source_price == 3000 and near_source.source_combine_fee == 700 and near_source.mechanism_ids == ["passive:14"], "B03 original 3000 gold, 700 combine fee, passive14")
  check(far_source.source_price == 3250 and far_source.source_combine_fee == 350 and far_source.mechanism_ids == ["passive:15"], "C06 original 3250 gold, 350 combine fee, passive15")
  check(recipe_matches(near_source.components, [["intermediate:I13", "战术芯片", 1.0], ["intermediate:I07", "生命合金", 1.0]]), "B03 original recipe retained")
  check(recipe_matches(far_source.components, [["intermediate:I14", "奥术穿针", 1.0], ["intermediate:I09", "相位推进器", 1.0], ["base:B02", "奥术结晶", 1.0]]), "C06 original recipe retained")
 var edited: Dictionary = numeric.duplicate(true)
 edited.parameters["final:B03.stat.AD"].value = 77.5
 edited.parameters["final:C06.stat.AP"].value = 123.5
 edited.parameters["passive:14.range_threshold"].value = 3.0
 edited.parameters["passive:14.damage_bonus"].value = 20.0
 edited.parameters["passive:14.lifesteal"].value = 7.0
 edited.parameters["passive:15.range_threshold"].value = 10.0
 edited.parameters["passive:15.damage_bonus"].value = 25.0
 edited.parameters["passive:15.penetration"].value = 16.0
 var changed: Dictionary = Adapter.build(edited)
 check(changed.get("accepted", false), "formally edited current parameters remain supported")
 if changed.get("accepted", false):
  near(float(changed.definitions["final:B03"].stats.AD), 77.5, "current AD reaches adapter instead of original source_value")
  near(float(changed.definitions["final:C06"].stats.AP), 123.5, "current AP reaches adapter instead of original source_value")
  var selection: Dictionary = Passives.select_unique(INVENTORY, changed.definitions)
  near(Passives.factor(Vector3.ZERO, Vector3(3,0,0), selection), 1.20, "edited near threshold and bonus reach factor")
  near(Passives.factor(Vector3.ZERO, Vector3(4,0,0), selection), 1.0, "edited threshold replaces original near threshold")
  near(Passives.factor(Vector3.ZERO, Vector3(9,0,0), selection), 1.0, "edited threshold replaces original far threshold")
  near(Passives.factor(Vector3.ZERO, Vector3(10,0,0), selection), 1.25, "edited far threshold and bonus reach factor")
  near(float(selection.constant_stats.lifesteal), 0.07, "edited constant lifesteal converted once")
  near(float(selection.constant_stats.penetration), 16.0, "edited constant penetration is flat")
 complete()
 return result

func validation_case(numeric: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[1]
 check(not Adapter.build({}).get("accepted", false), "missing numeric map rejected")
 var keys: Array[String] = []
 for item_id: String in Passives.ITEMS:
  for spec: Array in Adapter.STAT_SPECS[item_id]: keys.append(item_id + ".stat." + str(spec[0]))
  var passive_id: String = Passives.ITEMS[item_id]
  for spec: Array in Passives.TUNING_SPECS[passive_id]: keys.append(passive_id + "." + str(spec[0]))
 check(keys.size() == 12, "all twelve new numeric fields validated")
 for key: String in keys:
  var missing: Dictionary = numeric.duplicate(true)
  missing.parameters.erase(key)
  check(not Adapter.build(missing).get("accepted", false), "missing parameter rejected: " + key)
  for invalid: Variant in [null, "12", true, -1.0, NAN, INF]:
   var bad: Dictionary = numeric.duplicate(true)
   bad.parameters[key].value = invalid
   check(not Adapter.build(bad).get("accepted", false), "invalid numeric rejected: " + key + ": " + str(invalid))
  var wrong_unit: Dictionary = numeric.duplicate(true)
  wrong_unit.parameters[key].unit = "incorrect_unit"
  check(not Adapter.build(wrong_unit).get("accepted", false), "wrong parameter unit rejected: " + key)
  var scalar: Dictionary = numeric.duplicate(true)
  scalar.parameters[key] = 12.0
  check(not Adapter.build(scalar).get("accepted", false), "scalar parameter rejected: " + key)
 var invalid_prior: Dictionary = numeric.duplicate(true)
 invalid_prior.parameters["final:A05.stat.AD"].value = -1.0
 check(not Adapter.build(invalid_prior).get("accepted", false), "prior A05 validation remains authoritative")
 var invalid_base: Dictionary = numeric.duplicate(true)
 invalid_base.parameters["base:B01.stat.AD"].value = -1.0
 check(not Adapter.build(invalid_base).get("accepted", false), "original base validation remains authoritative")
 complete()

func boundary_case(definitions: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[2]
 var selection: Dictionary = Passives.select_unique(INVENTORY, definitions)
 var origin: Vector3 = Vector3.ZERO
 for pair: Array in [[0.0,1.12], [4.49999,1.12], [4.5,1.12], [4.50001,1.0], [8.99999,1.0], [9.0,1.15], [9.00001,1.15], [100.0,1.15]]:
  for axis: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3.UP, Vector3.DOWN]:
   var position: Vector3 = axis * float(pair[0])
   var before: PackedByteArray = var_to_bytes([origin, position, selection, definitions])
   near(Passives.factor(origin, position, selection), float(pair[1]), "inclusive distance boundary " + str(pair[0]) + " axis " + str(axis))
   check(before == var_to_bytes([origin, position, selection, definitions]), "factor is read-only at boundary " + str(pair[0]))
   near(float(selection.constant_stats.lifesteal), 0.05, "lifesteal constant at distance " + str(pair[0]))
   near(float(selection.constant_stats.penetration), 12.0, "penetration constant at distance " + str(pair[0]))
 near(Passives.factor(Vector3(10,2,-5), Vector3(14.5,2,-5), selection), 1.12, "near factor uses relative positions")
 near(Passives.factor(Vector3(10,2,-5), Vector3(19,2,-5), selection), 1.15, "far factor uses relative positions")
 var only_near: Dictionary = Passives.select_unique([INVENTORY[0]], definitions)
 var only_far: Dictionary = Passives.select_unique([INVENTORY[1]], definitions)
 near(Passives.factor(origin, Vector3(9,0,0), only_near), 1.0, "B03 alone cannot grant far multiplier")
 near(Passives.factor(origin, Vector3(4.5,0,0), only_far), 1.0, "C06 alone cannot grant near multiplier")
 var moving_target: Vector3 = Vector3(4,0,0)
 near(Passives.factor(origin, moving_target, selection), 1.12, "target at current near contact qualifies")
 moving_target = Vector3(6,0,0)
 near(Passives.factor(origin, moving_target, selection), 1.0, "later current position stops near qualification")
 moving_target = Vector3(10,0,0)
 near(Passives.factor(origin, moving_target, selection), 1.15, "later current position starts far qualification")
 var zeroed: Dictionary = definitions.duplicate(true)
 zeroed["final:B03"].distance_passive.range_threshold = 0.0
 zeroed["final:B03"].distance_passive.damage_bonus = 0.0
 zeroed["final:C06"].distance_passive.damage_bonus = 0.0
 var zero_selection: Dictionary = Passives.select_unique(INVENTORY, zeroed)
 near(Passives.factor(origin, origin, zero_selection), 1.0, "zero editable bonus remains zero at zero distance")
 near(Passives.factor(origin, Vector3(100,0,0), zero_selection), 1.0, "zero editable far bonus remains zero")
 complete()

func selection_case(definitions: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[3]
 var inventory: Array = [{"id":"final:B03", "uid":11, "count":1}, {"id":"final:B03", "uid":11, "count":1}, {"id":"final:B03", "uid":12, "count":1}, {"id":"final:C06", "uid":21, "count":2}, {"id":"final:C06", "uid":21, "count":2}]
 var before: PackedByteArray = var_to_bytes([inventory, definitions])
 var selection: Dictionary = Passives.select_unique(inventory, definitions)
 check(selection.equipped and selection.passives.size() == 2, "one selection per unique passive name")
 check(selection.passives["passive:14"].uid == 11 and selection.passives["passive:14"].owned_copies == 2, "two B03 UIDs observed; repeated UID ignored")
 check(selection.passives["passive:15"].uid == 21 and selection.passives["passive:15"].owned_copies == 2, "count-two C06 observed; repeated UID ignored")
 check(selection.constant_stats == {"lifesteal":0.05, "penetration":12.0}, "multiple copies grant exactly one constant bonus per passive")
 near(Passives.factor(Vector3.ZERO, Vector3(4.5,0,0), selection), 1.12, "two B03 copies retain one near multiplier")
 near(Passives.factor(Vector3.ZERO, Vector3(9,0,0), selection), 1.15, "two C06 copies retain one far multiplier")
 # These are scalar adapter assertions. Live ledger/projection stacking is covered
 # by the separate integration gate, not claimed by this pure fixture.
 near(float(definitions["final:B03"].stats.AD) * 2.0, 90.0, "two source B03 base AD contributions")
 near(float(definitions["final:B03"].stats.max_hp) * 2.0, 640.0, "two source B03 base HP contributions")
 near(float(definitions["final:B03"].stats.cooldown_reduction) * 2.0, 0.24, "two source B03 base CDR contributions")
 near(float(definitions["final:C06"].stats.AP) * 2.0, 180.0, "two source C06 base AP contributions")
 near(float(definitions["final:C06"].stats.move_speed) * 2.0, 0.20, "two source C06 base speed contributions")
 near(float(definitions["final:C06"].stats.penetration) * 2.0 + float(selection.constant_stats.penetration), 48.0, "two C06 base penetration contributions plus one unique constant")
 check(before == var_to_bytes([inventory, definitions]), "selection never changes inventory or definitions")
 selection.passives["passive:14"].tuning.damage_bonus = 99.0
 selection.constant_stats.lifesteal = 0.99
 near(float(definitions["final:B03"].distance_passive.damage_bonus), 12.0, "returned tuning is detached from runtime definition")
 var fresh: Dictionary = Passives.select_unique(inventory, definitions)
 near(float(fresh.constant_stats.lifesteal), 0.05, "returned constant stats do not persist into next selection")
 var empty: Dictionary = Passives.select_unique([], definitions)
 check(not empty.equipped and empty.passives.is_empty() and empty.constant_stats.is_empty(), "empty inventory grants no multiplier or constant stats")
 near(Passives.factor(Vector3.ZERO, Vector3.ZERO, empty), 1.0, "unequipped factor is exactly one")
 var near_only: Dictionary = Passives.select_unique([INVENTORY[0]], definitions)
 var far_only: Dictionary = Passives.select_unique([INVENTORY[1]], definitions)
 check(near_only.constant_stats == {"lifesteal":0.05}, "B03 alone grants only its named constant")
 check(far_only.constant_stats == {"penetration":12.0}, "C06 alone grants only its named constant")
 complete()

func invalid_case(definitions: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[4]
 var selection: Dictionary = Passives.select_unique(INVENTORY, definitions)
 for bad: Variant in [null, true, "4.5", {}, Vector2.ZERO, Vector3(NAN,0,0), Vector3(0,INF,0), Vector3(0,0,-INF)]:
  near(Passives.factor(bad, Vector3.ZERO, selection), 1.0, "invalid hero position is inert: " + str(bad))
  near(Passives.factor(Vector3.ZERO, bad, selection), 1.0, "invalid enemy position is inert: " + str(bad))
 for bad_selection: Dictionary in [{}, {"equipped":true}, {"equipped":false, "passives":selection.passives}, {"equipped":true, "passives":[]}, {"equipped":true, "passives":{"passive:14":null, "passive:15":"bad"}}]:
  near(Passives.factor(Vector3.ZERO, Vector3(4,0,0), bad_selection), 1.0, "malformed/unequipped selection is inert")
 for item_id: String in Passives.ITEMS:
  var passive_id: String = Passives.ITEMS[item_id]
  var held: Dictionary = {"id":item_id, "uid":1, "count":1}
  for bad: Variant in [null, "B03", {}, {"id":item_id, "uid":1, "count":0}, {"id":item_id, "uid":1, "count":-1}, {"id":item_id, "uid":1, "count":1.5}, {"id":item_id, "uid":-1, "count":1}, {"id":item_id, "uid":"1", "count":1}]:
   var inert: Dictionary = Passives.select_unique([bad], definitions)
   check(not inert.equipped and inert.constant_stats.is_empty(), "malformed held entry grants no effect: " + str(bad))
  for replacement: Variant in [null, {}, {"supported":false}, {"supported":true, "passives":[]}, {"supported":true, "passives":[passive_id], "distance_passive":[]}]:
   var malformed: Dictionary = definitions.duplicate(true)
   malformed[item_id] = replacement
   check(not Passives.select_unique([held], malformed).equipped, "invalid runtime definition remains inert: " + item_id)
  for spec: Array in Passives.TUNING_SPECS[passive_id]:
   var key: String = str(spec[0])
   var missing: Dictionary = definitions.duplicate(true)
   missing[item_id].distance_passive.erase(key)
   check(not Passives.select_unique([held], missing).equipped, "missing tuning field grants neither effect: " + passive_id + "." + key)
   for invalid: Variant in [null, true, "5", -1.0, NAN, INF]:
    var malformed: Dictionary = definitions.duplicate(true)
    malformed[item_id].distance_passive[key] = invalid
    var inert: Dictionary = Passives.select_unique([held], malformed)
    check(not inert.equipped and inert.constant_stats.is_empty(), "invalid tuning grants no selected constant: " + passive_id + "." + key)
    var bad_selection: Dictionary = Passives.select_unique([held], definitions)
    bad_selection.passives[passive_id].tuning[key] = invalid
    near(Passives.factor(Vector3.ZERO, Vector3.ZERO if passive_id == "passive:14" else Vector3(100,0,0), bad_selection), 1.0, "invalid direct tuning grants no distance factor: " + passive_id + "." + key)
 check(not Passives.select_unique(INVENTORY, {}).equipped, "missing definitions are inert")
 var fabricated: Dictionary = definitions.duplicate(true)
 fabricated["final:D03"] = definitions["final:B03"].duplicate(true)
 check(not Passives.select_unique([{"id":"final:D03", "uid":99, "count":1}], fabricated).equipped, "unadmitted item cannot activate a copied same-name passive")
 var bad_entry: Dictionary = selection.duplicate(true)
 bad_entry.passives["passive:14"].item_id = "final:D03"
 near(Passives.factor(Vector3.ZERO, Vector3.ZERO, bad_entry), 1.0, "forged unadmitted selection identity is inert")
 check(not Passives.valid_tuning("passive:18", {}), "other mechanism cannot be interpreted as a distance passive")
 complete()

func run() -> void:
 var numeric: Variant = JSON.parse_string(FileAccess.get_file_as_string(NUMERIC))
 var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
 if not check(numeric is Dictionary and source is Dictionary, "both authoritative source JSON files load"):
  finish(); return
 var result: Dictionary = adapter_case(numeric, source)
 if not result.is_empty():
  validation_case(numeric)
  boundary_case(result.definitions)
  selection_case(result.definitions)
  invalid_case(result.definitions)
 finish()

func finish() -> void:
 current_group = "report"
 check(groups == REQUIRED_GROUPS, "all five pure mechanism groups complete")
 check(records.size() == checks, "every check has an outcome")
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 check(file != null, "mechanism report path writable")
 var report: Dictionary = {"suite":"equipment_b03_c06_source_adapter_and_pure_distance_passives", "passed":failures.is_empty() and groups == REQUIRED_GROUPS, "checks":checks, "failures":failures, "groups":groups, "records":records, "numeric_sha256":FileAccess.get_sha256(NUMERIC), "source_sha256":FileAccess.get_sha256(SOURCE), "adapter_sha256":FileAccess.get_sha256("res://equipment_distance_20261009/adapter.gd"), "consumer_sha256":FileAccess.get_sha256("res://equipment_distance_20261009/passives.gd"), "runtime_status":"EXECUTED", "pure_scalar_fixtures":true, "actual_source_damage":false, "commerce_integration":false, "native_input":false, "natural_full_floor":false}
 if file != null:
  file.store_string(JSON.stringify(report, "  "))
  var error: Error = file.get_error()
  file.close()
  if error != OK:
   check(false, "mechanism report write completed")
   report.checks = checks; report.failures = failures; report.records = records; report.passed = false
 print("EQUIPMENT_DISTANCE_MECHANISM ", JSON.stringify(report))
 quit(0 if report.passed else 1)
