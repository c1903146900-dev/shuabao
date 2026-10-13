extends SceneTree
## Pure data fixtures only. Does not authenticate real kills or execute combat.
## Prepared gate, NOT RUN during preparation; requires later candidate integration.
const Adapter = preload("res://equipment_kill_20261009/adapter.gd")
const Passive13 = preload("res://equipment_kill_20261009/passive13.gd")
const Prior = preload("res://equipment_distance_20261009/adapter.gd")
const NUMERIC := "res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json"
const SOURCE := "res://docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json"
const REQUIRED_GROUPS := ["preserve_35_and_prepare_b01", "strict_source_parameters", "unique_selection_and_copy_stats", "current_cd_and_once_per_cast", "verified_attribution_scope_and_purity"]
const INVENTORY := [{"id":"final:B01", "uid":41, "count":1}]
const SCOPE := {"generation":7, "room_id":"fixture:room"}
var checks: int = 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var groups: Array[String] = []
var current_group: String = "startup"
var output_path: String = "user://equipment_b01_mechanism_gate.json"

func _initialize() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--equipment-b01-result="):
   output_path = argument.trim_prefix("--equipment-b01-result=")
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

func fixture_casts(slot: String = "q", finished: bool = false) -> Dictionary:
 return {101:{"slot":slot, "stage":"fixture", "generation":SCOPE.generation, "room_id":SCOPE.room_id, "cancelled":false, "finished":finished}}

func fixture_kill(skill: String = "q1", supplemental: bool = false) -> Dictionary:
 # Explicit fake fixtures test a pure helper contract. They are NEVER submitted
 # to a live source bridge and are not evidence of actual kill authentication.
 var event: Dictionary = {"kind":"kill", "source_bridge_connected":true, "attribution_verified":true, "source":skill, "cast_id":101, "target":"fixture:enemy:1", "generation":SCOPE.generation, "room_id":SCOPE.room_id}
 if supplemental:
  event.source = "yanguizhou_p1"
  event.parent_skill = skill
 return event

func adapter_case(numeric: Dictionary, source: Dictionary) -> Dictionary:
 current_group = REQUIRED_GROUPS[0]
 var before: PackedByteArray = var_to_bytes([numeric, source])
 var prior: Dictionary = Prior.build(numeric)
 var result: Dictionary = Adapter.build(numeric)
 if not check(prior.get("accepted", false) and result.get("accepted", false), "original source accepts prior35 and prepared36 adapters"): return {}
 check(before == var_to_bytes([numeric, source]), "adapter does not mutate either source")
 check(result.definitions.size() == prior.definitions.size() + 1, "only B01 definition is added")
 var prior_count: int = 0
 for item_id: String in prior.definitions:
  check(var_to_bytes(prior.definitions[item_id]) == var_to_bytes(result.definitions[item_id]), "prior definition deeply unchanged: " + item_id)
  if prior.definitions[item_id].get("supported", false): prior_count += 1
 check(prior_count == 35, "exactly 35 original supported items preserved")
 for key: String in prior:
  if key != "definitions": check(var_to_bytes(prior[key]) == var_to_bytes(result[key]), "prior top-level metadata unchanged: " + key)
 var count: int = 0
 for definition: Dictionary in result.definitions.values():
  if definition.get("supported", false): count += 1
 check(count == 36, "exactly 36 prepared definitions")
 var definition: Dictionary = result.definitions[Adapter.ITEM_ID]
 check(definition.stats == {"AD":60.0, "cooldown_reduction":0.18, "penetration":16.0}, "B01 exact original stats with one CDR percent conversion")
 check(definition.passives == [Passive13.PASSIVE_ID] and definition.actives.is_empty() and definition.tier == "final", "only original passive13 named")
 check(definition.passive13 == {"cooldown_refund":35.0}, "sole passive value stays in percent points")
 check(definition.taskB01.threshold == 40.0 and definition.taskB01.reward_skill_points == 1, "task metadata keeps source40 and permanent1SP reward")
 check(definition.runtime_status == "inert_until_source_bridge_connected" and definition.runtime_complete == false, "passive preparation never claims complete equipment")
 check(definition.requires_source_bridge.size() == 4, "real attribution, refund, task and Model bridge requirements retained")
 for reference: Dictionary in definition.parameters + definition.passive13_parameters + definition.taskB01_parameters + definition.commerce_parameters:
  var original: Dictionary = numeric.parameters[reference.parameter]
  check(not str(reference.source_ref).is_empty() and reference.current_value == original.value and reference.source_value == original.source_value and reference.source_unit == original.unit, "unchanged numeric provenance: " + str(reference.parameter))
 var item: Dictionary = {}
 for candidate: Dictionary in source.get("equipment", []):
  if candidate.id == Adapter.ITEM_ID: item = candidate
 check(not item.is_empty(), "B01 exists in original DOCX extraction")
 if not item.is_empty():
  check(item.name == "断界锋" and item.source_price == 3200 and item.source_combine_fee == 350 and item.mechanism_ids == ["passive:13"], "B01 original identity, price3200 and combine350")
  var expected: Array = [["intermediate:I04", "锯齿长刃"], ["intermediate:I13", "战术芯片"], ["base:B01", "黑铁短刃"]]
  check(item.components.size() == expected.size(), "original three-component recipe")
  if item.components.size() == expected.size():
   for index: int in range(expected.size()):
    var component: Dictionary = item.components[index]
    check(component.item_id == expected[index][0] and component.name == expected[index][1] and float(component.quantity) == 1.0, "original recipe component: " + str(expected[index][0]))
 var task_source: Dictionary = {}
 for task: Dictionary in source.get("tasks", []):
  if task.equipment_id == Adapter.ITEM_ID: task_source = task
 check(not task_source.is_empty() and str(task_source.get("source_task", "")).contains("40次击杀") and str(task_source.get("source_task", "")).contains("永久获得1技能点") and str(task_source.get("source_task", "")).contains("本局不可再次完成"), "original task wording retained as required integration obligation")
 complete()
 return result

func validation_case(numeric: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[1]
 check(not Adapter.build({}).get("accepted", false), "numeric parameter map required")
 var keys: Array[String] = ["final:B01.price", "final:B01.stat.AD", "final:B01.stat.cdr_pct", "final:B01.stat.penetration", "passive:13.cooldown_refund", "task:B01.threshold"]
 for key: String in keys:
  var missing: Dictionary = numeric.duplicate(true)
  missing.parameters.erase(key)
  check(not Adapter.build(missing).get("accepted", false), "missing required parameter rejected: " + key)
  for invalid: Variant in [null, true, "35", -1.0, NAN, INF]:
   var bad: Dictionary = numeric.duplicate(true)
   bad.parameters[key].value = invalid
   check(not Adapter.build(bad).get("accepted", false), "invalid numeric rejected: " + key + ": " + str(invalid))
  var wrong_unit: Dictionary = numeric.duplicate(true)
  wrong_unit.parameters[key].unit = "wrong_unit"
  check(not Adapter.build(wrong_unit).get("accepted", false), "wrong unit rejected: " + key)
  var scalar: Dictionary = numeric.duplicate(true)
  scalar.parameters[key] = 35.0
  check(not Adapter.build(scalar).get("accepted", false), "scalar parameter rejected: " + key)
 for refund: float in [0.0, 35.0, 100.0]:
  var valid: Dictionary = numeric.duplicate(true)
  valid.parameters["passive:13.cooldown_refund"].value = refund
  check(Adapter.build(valid).get("accepted", false), "refund percentage inclusive boundary accepted: " + str(refund))
 for refund: float in [-0.000001, 100.000001]:
  var invalid: Dictionary = numeric.duplicate(true)
  invalid.parameters["passive:13.cooldown_refund"].value = refund
  check(not Adapter.build(invalid).get("accepted", false), "refund percentage outside exact bounds rejected: " + str(refund))
 for threshold: float in [0.0, 39.5]:
  var invalid: Dictionary = numeric.duplicate(true)
  invalid.parameters["task:B01.threshold"].value = threshold
  check(not Adapter.build(invalid).get("accepted", false), "task threshold must be positive whole count")
 var extra: Dictionary = numeric.duplicate(true)
 extra.parameters["passive:13.trigger_count"] = {"value":2, "unit":"count"}
 check(not Adapter.build(extra).get("accepted", false), "second passive13 numeric parameter cannot invent a mechanism")
 for invalid: Variant in [null, {}, []]:
  var missing: Dictionary = numeric.duplicate(true)
  missing.task_stages = invalid
  check(not Adapter.build(missing).get("accepted", false), "original B01 task stage is mandatory")
 var duplicate: Dictionary = numeric.duplicate(true)
 var stage: Dictionary = Adapter._task_stage(duplicate.task_stages)
 duplicate.task_stages.append(stage)
 check(not Adapter.build(duplicate).get("accepted", false), "duplicate B01 reward stage rejected")
 var changed_reward: Dictionary = numeric.duplicate(true)
 for candidate: Dictionary in changed_reward.task_stages:
  if candidate.task_id == Adapter.TASK_ID: candidate.reward_skill_points = 2
 check(not Adapter.build(changed_reward).get("accepted", false), "cannot silently change permanent reward to2SP")
 var edited: Dictionary = numeric.duplicate(true)
 edited.parameters["final:B01.stat.AD"].value = 72.5
 edited.parameters["final:B01.stat.cdr_pct"].value = 20.0
 edited.parameters["passive:13.cooldown_refund"].value = 50.0
 edited.parameters["task:B01.threshold"].value = 50.0
 var changed: Dictionary = Adapter.build(edited)
 check(changed.get("accepted", false), "current formally edited source parameters accepted")
 if changed.get("accepted", false):
  near(changed.definitions[Adapter.ITEM_ID].stats.AD, 72.5, "current AD replaces source_value")
  near(changed.definitions[Adapter.ITEM_ID].stats.cooldown_reduction, 0.20, "current CDR converted once")
  near(changed.definitions[Adapter.ITEM_ID].passive13.cooldown_refund, 50.0, "current refund remains percent points")
  near(changed.definitions[Adapter.ITEM_ID].taskB01.threshold, 50.0, "current source count reaches task descriptor")
 for key: String in ["final:A05.stat.AD", "final:B03.stat.AD", "final:C06.stat.AP", "base:B01.stat.AD"]:
  var invalid_prior: Dictionary = numeric.duplicate(true)
  invalid_prior.parameters[key].value = -1.0
  check(not Adapter.build(invalid_prior).get("accepted", false), "prior definition validation stays authoritative: " + key)
 complete()

func selection_case(definitions: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[2]
 var inventory: Array = [{"id":"final:B01", "uid":41, "count":1}, {"id":"final:B01", "uid":41, "count":1}, {"id":"final:B01", "uid":42, "count":2}, {"id":"final:B01", "uid":42, "count":2}]
 var before: PackedByteArray = var_to_bytes([inventory, definitions])
 var selection: Dictionary = Passive13.select_unique(inventory, definitions)
 check(selection.equipped and selection.uid == 41 and selection.owned_copies == 3 and selection.tuning == {"cooldown_refund":35.0}, "one passive selection, duplicate UID ignored, copies observed")
 check(before == var_to_bytes([inventory, definitions]), "selection never mutates inventory or definitions")
 var proposal: Dictionary = Passive13.evaluate_verified_kill(selection, fixture_kill(), fixture_casts(), SCOPE, 10.0, {})
 near(proposal.refund, 3.5, "three copies still refund one35-percent amount")
 var stats: Dictionary = definitions[Adapter.ITEM_ID].stats
 near(float(stats.AD) * 3.0, 180.0, "three per-copy base AD contributions")
 near(float(stats.cooldown_reduction) * 3.0, 0.54, "three per-copy base CDR contributions before existing runtime cap")
 near(float(stats.penetration) * 3.0, 48.0, "three per-copy base penetration contributions")
 selection.tuning.cooldown_refund = 99.0
 near(definitions[Adapter.ITEM_ID].passive13.cooldown_refund, 35.0, "selected tuning detached from definition")
 check(not Passive13.select_unique([], definitions).equipped, "no held B01 means no selection")
 for invalid: Variant in [null, "B01", {}, {"id":"final:B01", "uid":41, "count":0}, {"id":"final:B01", "uid":41, "count":1.5}, {"id":"final:B01", "uid":-1, "count":1}, {"id":"final:B01", "uid":"41", "count":1}, {"id":"base:B01", "uid":41, "count":1}]:
  check(not Passive13.select_unique([invalid], definitions).equipped, "malformed or different held item is inert")
 for invalid: Variant in [null, {}, {"supported":false}, {"supported":true, "passives":[]}, {"supported":true, "passives":["passive:13", "passive:13"], "passive13":{"cooldown_refund":35.0}}]:
  var malformed: Dictionary = definitions.duplicate(true)
  malformed[Adapter.ITEM_ID] = invalid
  check(not Passive13.select_unique(INVENTORY, malformed).equipped, "invalid passive identity or repeated name cannot activate")
 for tuning: Dictionary in [{}, {"cooldown_refund":true}, {"cooldown_refund":"35"}, {"cooldown_refund":-0.000001}, {"cooldown_refund":100.000001}, {"cooldown_refund":NAN}, {"cooldown_refund":INF}, {"cooldown_refund":35.0, "trigger_count":2}]:
  var malformed: Dictionary = definitions.duplicate(true)
  malformed[Adapter.ITEM_ID].passive13 = tuning
  check(not Passive13.valid_tuning(tuning) and not Passive13.select_unique(INVENTORY, malformed).equipped, "invalid or extra tuning cannot activate")
 complete()

func refund_case(definitions: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[3]
 var selection: Dictionary = Passive13.select_unique(INVENTORY, definitions)
 var kills: Dictionary = fixture_kill()
 var casts: Dictionary = fixture_casts()
 for current_cd: float in [0.0, 0.000001, 1.0, 3.7, 10.0, 1000.0]:
  var proposal: Dictionary = Passive13.evaluate_verified_kill(selection, kills, casts, SCOPE, current_cd, {})
  check(proposal.eligible and proposal.consume_claim, "qualifying kill claims once at current CD: " + str(current_cd))
  near(proposal.refund, current_cd * 0.35, "refund uses current remaining CD")
  near(proposal.cooldown_after, current_cd * 0.65, "remaining CD after refund")
 for percent: float in [0.0, 100.0]:
  var edited: Dictionary = selection.duplicate(true)
  edited.tuning.cooldown_refund = percent
  var proposal: Dictionary = Passive13.evaluate_verified_kill(edited, kills, casts, SCOPE, 10.0, {})
  check(proposal.eligible and proposal.consume_claim, "inclusive zero/full refund consumes the original cast")
  near(proposal.refund, percent / 10.0, "exact refund percentage boundary")
 var first: Dictionary = Passive13.evaluate_verified_kill(selection, kills, casts, SCOPE, 10.0, {})
 var claims: Dictionary = {first.claim_key:true}
 check(first.claim_key == "7:fixture:room:101", "claim identity uses original generation/room/cast")
 var next: Dictionary = kills.duplicate(true)
 next.target = "fixture:enemy:2"
 check(not Passive13.evaluate_verified_kill(selection, next, casts, SCOPE, 6.5, claims).eligible, "second kill in same complete cast cannot refund")
 check(not Passive13.evaluate_verified_kill(selection, fixture_kill("q1", true), fixture_casts("q", true), SCOPE, 6.5, claims).eligible, "later P1 kill shares same original cast claim")
 check(Passive13.evaluate_verified_kill(selection, fixture_kill("q1", true), fixture_casts("q", true), SCOPE, 6.5, {}).eligible, "first valid P1 kill may settle after original cast finished")
 var h04: Dictionary = fixture_kill("hex_yanguizhou_h04")
 h04.parent_skill = "q2"
 h04.original_q2_hex_receipt_verified = true
 check(Passive13.evaluate_verified_kill(selection, h04, casts, SCOPE, 10.0, {}).eligible, "verified original live Q2 H04 packet retains source Q2 attribution")
 check(not Passive13.evaluate_verified_kill(selection, h04, casts, SCOPE, 6.5, claims).eligible, "H04 Q2 packet uses same complete original cast claim")
 var new_casts: Dictionary = casts.duplicate(true)
 new_casts[102] = new_casts[101].duplicate(true)
 next.cast_id = 102
 check(Passive13.evaluate_verified_kill(selection, next, new_casts, SCOPE, 6.5, claims).eligible, "a distinct original cast has a fresh claim")
 for slot: String in ["q", "e"]:
  for rank: int in [1, 2, 3]:
   var skill: String = slot + str(rank)
   var proposal: Dictionary = Passive13.evaluate_verified_kill(selection, fixture_kill(skill), fixture_casts(slot), SCOPE, 10.0, {})
   check(proposal.eligible and proposal.slot == slot, "original direct skill identity accepted: " + skill)
 complete()

func invalid_case(definitions: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[4]
 var selection: Dictionary = Passive13.select_unique(INVENTORY, definitions)
 var event: Dictionary = fixture_kill()
 var casts: Dictionary = fixture_casts()
 var claims: Dictionary = {}
 var before: PackedByteArray = var_to_bytes([selection, event, casts, SCOPE, claims, definitions])
 var proposal: Dictionary = Passive13.evaluate_verified_kill(selection, event, casts, SCOPE, 10.0, claims)
 check(proposal.eligible and before == var_to_bytes([selection, event, casts, SCOPE, claims, definitions]), "valid calculation never writes source, CD, claims, selection, or task state")
 check(claims.is_empty(), "pure proposal does not consume the claim itself")
 for field: String in ["source_bridge_connected", "attribution_verified", "kind", "target", "cast_id", "generation", "room_id", "source"]:
  var missing: Dictionary = event.duplicate(true)
  missing.erase(field)
  check(not Passive13.evaluate_verified_kill(selection, missing, casts, SCOPE, 10.0, {}).eligible, "missing required kill proof field is inert: " + field)
 for change: Dictionary in [{"kind":"damage"}, {"source_bridge_connected":false}, {"source_bridge_connected":1}, {"attribution_verified":false}, {"attribution_verified":1}, {"cast_id":0}, {"cast_id":-1}, {"cast_id":101.0}, {"cast_id":"101"}, {"cast_id":999}, {"generation":6}, {"room_id":"other"}, {"target":""}, {"source":"attack"}, {"source":"dash_attack"}, {"source":"r1"}, {"source":"hex_yanguizhou_h04"}, {"source":"hex_yanguizhou_h04", "parent_skill":"q2"}, {"source":"hex_yanguizhou_h04", "parent_skill":"q2", "original_q2_hex_receipt_verified":1}, {"source":"hex_yanguizhou_h04", "parent_skill":"q1", "original_q2_hex_receipt_verified":true}, {"source":"hex_yanguizhou_h05", "parent_skill":"q2", "original_q2_hex_receipt_verified":true}, {"source":"yanguizhou_h09"}, {"source":"e1"}, {"source":"yanguizhou_p1"}, {"source":"yanguizhou_p1", "parent_skill":"e1"}]:
  var invalid: Dictionary = event.duplicate(true)
  invalid.merge(change, true)
  check(not Passive13.evaluate_verified_kill(selection, invalid, casts, SCOPE, 10.0, {}).eligible, "mismatched or unverified attribution inert: " + str(change))
 for change: Dictionary in [{"cancelled":true}, {"cancelled":"false"}, {"finished":null}, {"generation":6}, {"room_id":"other"}, {"slot":"r"}, {"slot":"attack"}, {"slot":"e"}]:
  var invalid: Dictionary = casts.duplicate(true)
  invalid[101].merge(change, true)
  check(not Passive13.evaluate_verified_kill(selection, event, invalid, SCOPE, 10.0, {}).eligible, "original cast mismatch inert: " + str(change))
 var wrong_slot_h04: Dictionary = fixture_kill("hex_yanguizhou_h04")
 wrong_slot_h04.parent_skill = "q2"
 wrong_slot_h04.original_q2_hex_receipt_verified = true
 check(not Passive13.evaluate_verified_kill(selection, wrong_slot_h04, fixture_casts("e"), SCOPE, 10.0, {}).eligible, "verified Q2 H04 cannot be moved to an E cast")
 for invalid_scope: Dictionary in [{}, {"generation":7.0, "room_id":"fixture:room"}, {"generation":7, "room_id":""}, {"generation":8, "room_id":"fixture:room"}]:
  check(not Passive13.evaluate_verified_kill(selection, event, casts, invalid_scope, 10.0, {}).eligible, "invalid current scope is inert")
 for invalid_cd: Variant in [null, true, "10", -0.000001, NAN, INF]:
  check(not Passive13.evaluate_verified_kill(selection, event, casts, SCOPE, invalid_cd, {}).eligible, "invalid current CD is inert")
 for invalid_selection: Dictionary in [{}, {"equipped":true}, Passive13.select_unique([], definitions)]:
  check(not Passive13.evaluate_verified_kill(invalid_selection, event, casts, SCOPE, 10.0, {}).eligible, "unequipped or malformed selection is inert")
 check(before == var_to_bytes([selection, event, casts, SCOPE, claims, definitions]), "all rejection fixtures leave original inputs unchanged")
 complete()

func run() -> void:
 var numeric: Variant = JSON.parse_string(FileAccess.get_file_as_string(NUMERIC))
 var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
 if not check(numeric is Dictionary and source is Dictionary, "both authoritative source files load"):
  finish(); return
 var result: Dictionary = adapter_case(numeric, source)
 if not result.is_empty():
  validation_case(numeric)
  selection_case(result.definitions)
  refund_case(result.definitions)
  invalid_case(result.definitions)
 finish()

func finish() -> void:
 current_group = "report"
 check(groups == REQUIRED_GROUPS, "all five pure mechanism groups completed")
 check(records.size() == checks, "every check has an outcome")
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 check(file != null, "mechanism report path writable")
 var report: Dictionary = {"suite":"equipment_b01_prepared_adapter_and_pure_refund", "passed":failures.is_empty() and groups == REQUIRED_GROUPS, "checks":checks, "failures":failures, "groups":groups, "records":records, "numeric_sha256":FileAccess.get_sha256(NUMERIC), "source_sha256":FileAccess.get_sha256(SOURCE), "adapter_sha256":FileAccess.get_sha256("res://equipment_kill_20261009/adapter.gd"), "consumer_sha256":FileAccess.get_sha256("res://equipment_kill_20261009/passive13.gd"), "runtime_status":"EXECUTED_PURE_FIXTURES_ONLY", "pure_scalar_fixtures":true, "actual_source_kill_authentication":false, "actual_cooldown_commit":false, "persistent_task_and_skill_point_reward":false, "commerce_integration":false, "complete_b01_equipment":false, "native_input":false, "natural_full_floor":false}
 if file != null:
  file.store_string(JSON.stringify(report, "  "))
  var error: Error = file.get_error()
  file.close()
  if error != OK:
   check(false, "mechanism report write completed")
   report.checks = checks; report.failures = failures; report.records = records; report.passed = false
 print("EQUIPMENT_B01_MECHANISM ", JSON.stringify(report))
 quit(0 if report.passed else 1)
