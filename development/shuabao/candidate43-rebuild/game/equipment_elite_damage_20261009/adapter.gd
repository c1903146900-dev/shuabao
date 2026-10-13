extends RefCounted
## Add one prepared definition to the unchanged equipment_kill adapter chain.
## This 36 -> 37 data admission does not claim live G06 task implementation.
const Prior = preload("res://equipment_kill_20261009/adapter.gd")
const Passive18 = preload("passive18.gd")
const ITEM_ID := "final:G06"
const TASK_ID := "task:G06"
const STAT_SPECS := [["AD", "attack_points", "AD", 1.0], ["AP", "ability_points", "AP", 1.0], ["penetration", "penetration_points", "penetration", 1.0]]
const TASK_SPECS := [["threshold", "damage_points"], ["evolved_base_bonus", "percent_points"], ["evolved_bonus_cap", "percent_points"]]
const RECIPE := {"intermediate:I04":1, "intermediate:I14":1, "base:B11":1}

static func build(numeric: Dictionary) -> Dictionary:
 if not numeric.get("parameters") is Dictionary: return _deny("numeric_parameters_missing")
 var parameters: Dictionary = numeric.parameters
 var stats: Dictionary = {}
 var references: Array = []
 for spec: Array in STAT_SPECS:
  var key: String = ITEM_ID + ".stat." + str(spec[0])
  var entry: Variant = parameters.get(key)
  if not _valid(entry, str(spec[1])): return _deny("invalid_g06_stat:" + key)
  stats[str(spec[2])] = float(entry.value) * float(spec[3])
  references.append(_reference(key, entry, float(spec[3])))
 var tuning: Dictionary = {}
 var passive_references: Array = []
 var allowed: Array[String] = []
 for field: String in Passive18.TUNING_KEYS:
  var key: String = Passive18.PASSIVE_ID + "." + field
  var entry: Variant = parameters.get(key)
  if not _valid(entry, "percent_points"): return _deny("invalid_passive18_parameter:" + key)
  tuning[field] = float(entry.value)
  passive_references.append(_reference(key, entry, 1.0))
  allowed.append(key)
 if not Passive18.valid_tuning(tuning): return _deny("invalid_passive18_bounds")
 var task: Dictionary = {}
 var task_references: Array = []
 for spec: Array in TASK_SPECS:
  var key: String = TASK_ID + "." + str(spec[0])
  var entry: Variant = parameters.get(key)
  if not _valid(entry, str(spec[1])): return _deny("invalid_g06_task_parameter:" + key)
  task[str(spec[0])] = float(entry.value)
  task_references.append(_reference(key, entry, 1.0))
  allowed.append(key)
 if float(task.threshold) <= 0.0: return _deny("invalid_g06_task_threshold")
 for key: Variant in parameters:
  if (str(key).begins_with(Passive18.PASSIVE_ID + ".") or str(key).begins_with(TASK_ID + ".")) and key not in allowed:
   return _deny("unsupported_giant_hunter_parameter:" + str(key))
 var evolved: Dictionary = tuning.duplicate(true)
 evolved.base_damage_bonus = float(task.evolved_base_bonus)
 evolved.damage_bonus_cap = float(task.evolved_bonus_cap)
 if not Passive18.valid_tuning(evolved): return _deny("invalid_evolved_passive18_bounds")
 # No new per-evolution step field: both forms retain the same authored 25/2.
 var stage: Dictionary = _task_stage(numeric.get("task_stages"))
 if stage.is_empty(): return _deny("exact_original_g06_task_stage_required")
 task.task_id = TASK_ID
 task.stage_id = str(stage.stage_id)
 task.reward_skill_points = 0
 var commerce: Dictionary = _commerce(numeric)
 if not commerce.get("accepted", false): return commerce
 var result: Dictionary = Prior.build(numeric)
 if not result.get("accepted", false): return result
 if not result.get("definitions") is Dictionary: return _deny("prior_equipment_definitions_missing")
 var prior_count: int = 0
 for definition: Dictionary in result.definitions.values():
  if definition.get("supported", false): prior_count += 1
 if prior_count != 36 or result.definitions.has(ITEM_ID): return _deny("exact_36_prior_equipment_required")
 result.definitions[ITEM_ID] = {
  "supported":true, "reason":"", "stats":stats, "parameters":references,
  "passives":[Passive18.PASSIVE_ID], "actives":[], "tier":"final",
  "passive18":tuning, "passive18_parameters":passive_references,
  "passive18_evolved":evolved, "taskG06":task,
  "taskG06_parameters":task_references, "taskG06_source_stage":stage.duplicate(true),
  "commerce_parameters":commerce.parameters, "commerce":commerce.projection,
  "taskG06_contract":{"name":"王血试炼", "equipment_name":"猎王徽章", "scope":"player_equipment_name", "target_ranks":["elite", "boss"], "damage_measure":"holder_actual_target_hp_loss", "held_only":true, "once_per_run":true, "retained_when_sold":true, "evolution_retained_when_sold":true, "duplicate_copies_multiply_progress":false, "reward_skill_points":0},
  "runtime_status":"inert_until_source_bridge_connected", "runtime_complete":false,
  "requires_source_bridge":["verified_holder_actual_elite_boss_hp_loss", "persistent_player_equipment_name_task_ledger", "shared_a05_g06_unique_passive18_selection", "trusted_model_evolution_without_skill_point_reward"],
  "rule_provenance":"source_g06_holder_actual_hp_loss_task_and_shared_giant_hunter_only_once"
 }
 var admitted: int = 0
 for definition: Dictionary in result.definitions.values():
  if definition.get("supported", false): admitted += 1
 if admitted != 37: return _deny("exact_37_equipment_required")
 return result

static func _task_stage(stages: Variant) -> Dictionary:
 if not stages is Array: return {}
 var found: Dictionary = {}
 for stage: Variant in stages:
  if not stage is Dictionary: continue
  if stage.get("task_id") != TASK_ID and stage.get("equipment_id") != ITEM_ID and stage.get("stage_id") != TASK_ID + ":1": continue
  if not found.is_empty(): return {}
  if stage.get("task_id") != TASK_ID or stage.get("equipment_id") != ITEM_ID or stage.get("stage_id") != TASK_ID + ":1" or stage.get("threshold_parameter_id") != TASK_ID + ".threshold": return {}
  if not _number(stage.get("stage")) or float(stage.stage) != 1.0: return {}
  if not _number(stage.get("reward_skill_points")) or float(stage.reward_skill_points) != 0.0: return {}
  if not stage.get("source_ref") is String or str(stage.source_ref).is_empty(): return {}
  found = stage.duplicate(true)
 return found

static func _commerce(numeric: Dictionary) -> Dictionary:
 var parameters: Dictionary = numeric.parameters
 var price_key: String = ITEM_ID + ".price"
 var price: Variant = parameters.get(price_key)
 if not _valid(price, "gold") or float(price.value) != floor(float(price.value)): return _deny("invalid_g06_price")
 var rows: Variant = numeric.get("recipes")
 if not rows is Array: return _deny("g06_source_recipe_missing")
 var found: Dictionary = {}
 var source_rows: Array = []
 for row: Variant in rows:
  if not row is Dictionary or row.get("result_id") != ITEM_ID: continue
  var component: String = str(row.get("component_id", ""))
  if not RECIPE.has(component) or found.has(component): return _deny("invalid_g06_recipe_component")
  if not _number(row.get("quantity")) or float(row.quantity) != float(RECIPE[component]): return _deny("invalid_g06_recipe_quantity")
  if row.get("recipe_id") != ITEM_ID + "<-" + component or not row.get("source_ref") is String or str(row.source_ref).is_empty(): return _deny("invalid_g06_recipe_identity")
  found[component] = true
  source_rows.append(row.duplicate(true))
 if found.size() != RECIPE.size(): return _deny("exact_original_g06_recipe_required")
 var total: float = 0.0
 var references: Array = [_reference(price_key, price, 1.0)]
 for component: String in RECIPE:
  var key: String = component + ".price"
  var entry: Variant = parameters.get(key)
  if not _valid(entry, "gold") or float(entry.value) != floor(float(entry.value)): return _deny("invalid_g06_component_price:" + key)
  total += float(entry.value) * float(RECIPE[component])
  references.append(_reference(key, entry, 1.0))
 var fee: float = float(price.value) - total
 if not is_finite(total) or not is_finite(fee) or fee < 0.0: return _deny("invalid_g06_combine_fee")
 return {"accepted":true, "parameters":references, "projection":{"price":float(price.value), "component_total":total, "combine_fee":fee, "unit":"gold", "recipe":source_rows}}

static func _number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))

static func _valid(entry: Variant, unit: String) -> bool:
 return entry is Dictionary and entry.get("unit", "") == unit and _number(entry.get("value")) and float(entry.value) >= 0.0

static func _reference(key: String, entry: Dictionary, scale: float) -> Dictionary:
 return {"parameter":key, "source_ref":entry.get("source_ref", ""), "source_unit":entry.unit, "current_value":entry.value, "source_value":entry.get("source_value"), "scale":scale}

static func _deny(reason: String) -> Dictionary:
 return {"accepted":false, "reason":reason}
