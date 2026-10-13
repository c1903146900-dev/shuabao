extends RefCounted
## Prepared 35 -> 36 definition adapter; inert until source bridge connected.
## This admission alone does NOT implement the B01 task, cooldown, or commerce.
## Preserve the prior 35 definitions exactly. Base stats remain per-copy stats.
const Prior = preload("res://equipment_distance_20261009/adapter.gd")
const Passive13 = preload("res://equipment_kill_20261009/passive13.gd")
const ITEM_ID := "final:B01"
const TASK_ID := "task:B01"
const STAT_SPECS := [["AD", "attack_points", "AD", 1.0], ["cdr_pct", "percent_points", "cooldown_reduction", 0.01], ["penetration", "penetration_points", "penetration", 1.0]]

static func build(numeric: Dictionary) -> Dictionary:
 if not numeric.get("parameters") is Dictionary: return _deny("numeric_parameters_missing")
 var parameters: Dictionary = numeric.parameters
 var stats: Dictionary = {}
 var references: Array = []
 for spec: Array in STAT_SPECS:
  var key: String = ITEM_ID + ".stat." + str(spec[0])
  var entry: Variant = parameters.get(key)
  if not _valid(entry, str(spec[1])): return _deny("invalid_b01_stat:" + key)
  stats[str(spec[2])] = float(entry.value) * float(spec[3])
  references.append(_reference(key, entry, float(spec[3])))
 var refund_key: String = Passive13.PASSIVE_ID + ".cooldown_refund"
 var refund_entry: Variant = parameters.get(refund_key)
 if not _valid(refund_entry, "percent_points"): return _deny("invalid_passive13_parameter:" + refund_key)
 # The original passive has exactly one editable numeric parameter. A second
 # parameter must never silently invent a trigger count, window, or base CD.
 for key: Variant in parameters:
  if str(key).begins_with(Passive13.PASSIVE_ID + ".") and key != refund_key:
   return _deny("unsupported_passive13_parameter:" + str(key))
 var tuning: Dictionary = {"cooldown_refund":float(refund_entry.value)}
 if not Passive13.valid_tuning(tuning): return _deny("invalid_passive13_bounds")
 var threshold_key: String = TASK_ID + ".threshold"
 var threshold: Variant = parameters.get(threshold_key)
 if not _valid(threshold, "count") or float(threshold.value) <= 0.0 or float(threshold.value) != floor(float(threshold.value)):
  return _deny("invalid_b01_task_threshold")
 var stage: Dictionary = _task_stage(numeric.get("task_stages"))
 if stage.is_empty(): return _deny("exact_original_b01_task_stage_required")
 var price_key: String = ITEM_ID + ".price"
 var price: Variant = parameters.get(price_key)
 if not _valid(price, "gold"): return _deny("invalid_b01_price")
 var result: Dictionary = Prior.build(numeric)
 if not result.get("accepted", false): return result
 if not result.get("definitions") is Dictionary: return _deny("prior_equipment_definitions_missing")
 var prior_count: int = 0
 for definition: Dictionary in result.definitions.values():
  if definition.get("supported", false): prior_count += 1
 if prior_count != 35 or result.definitions.has(ITEM_ID): return _deny("exact_35_prior_equipment_required")
 result.definitions[ITEM_ID] = {
  "supported":true, "reason":"", "stats":stats, "parameters":references,
  "passives":[Passive13.PASSIVE_ID], "actives":[], "tier":"final",
  "passive13":tuning, "passive13_parameters":[_reference(refund_key, refund_entry, 1.0)],
  "taskB01":{"task_id":TASK_ID, "stage_id":str(stage.stage_id), "threshold":float(threshold.value), "reward_skill_points":int(stage.reward_skill_points)},
  "taskB01_parameters":[_reference(threshold_key, threshold, 1.0)], "taskB01_source_stage":stage.duplicate(true),
  "commerce_parameters":[_reference(price_key, price, 1.0)],
  "runtime_status":"inert_until_source_bridge_connected", "runtime_complete":false,
  "requires_source_bridge":["verified_qe_kill_attribution", "once_per_original_cast_refund", "persistent_once_per_run_b01_task", "trusted_model_skill_point_reward"],
  "rule_provenance":"source_passive13_current_cooldown_once_per_complete_original_cast_and_b01_task_required"
 }
 var admitted: int = 0
 for definition: Dictionary in result.definitions.values():
  if definition.get("supported", false): admitted += 1
 if admitted != 36: return _deny("exact_36_equipment_required")
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
  if not _number(stage.get("reward_skill_points")) or float(stage.reward_skill_points) != 1.0: return {}
  if not stage.get("source_ref") is String or str(stage.source_ref).is_empty(): return {}
  found = stage.duplicate(true)
 return found

static func _number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))

static func _valid(entry: Variant, unit: String) -> bool:
 return entry is Dictionary and entry.get("unit", "") == unit and _number(entry.get("value")) and float(entry.value) >= 0.0

static func _reference(key: String, entry: Dictionary, scale: float) -> Dictionary:
 return {"parameter":key, "source_ref":entry.get("source_ref", ""), "source_unit":entry.unit, "current_value":entry.value, "source_value":entry.get("source_value"), "scale":scale}

static func _deny(reason: String) -> Dictionary:
 return {"accepted":false, "reason":reason}
