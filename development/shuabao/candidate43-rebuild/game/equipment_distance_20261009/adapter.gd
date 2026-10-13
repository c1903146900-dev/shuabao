extends RefCounted
## Preserve all prior 33 definitions. Commerce retains source prices and recipes.
## Base stats stack per copy; the distance consumer grants unique constant stats.
const Prior = preload("res://equipment_expansion_20261009/adapter.gd")
const Passives = preload("res://equipment_distance_20261009/passives.gd")
const STAT_SPECS := {
 "final:B03":[["AD", "attack_points", "AD", 1.0], ["max_health", "health_points", "max_hp", 1.0], ["cdr_pct", "percent_points", "cooldown_reduction", 0.01]],
 "final:C06":[["AP", "ability_points", "AP", 1.0], ["penetration", "penetration_points", "penetration", 1.0], ["move_speed_pct", "percent_points", "move_speed", 0.01]]
}

static func build(numeric: Dictionary) -> Dictionary:
 if not numeric.get("parameters") is Dictionary: return _deny("numeric_parameters_missing")
 var parameters: Dictionary = numeric.parameters
 var additions: Dictionary = {}
 for item_id: String in Passives.ITEMS:
  var stats: Dictionary = {}
  var references: Array = []
  for spec: Array in STAT_SPECS[item_id]:
   var key: String = item_id + ".stat." + str(spec[0])
   var entry: Variant = parameters.get(key)
   if not _valid(entry, str(spec[1])): return _deny("invalid_distance_item_stat:" + key)
   stats[str(spec[2])] = float(entry.value) * float(spec[3])
   references.append(_reference(key, entry, float(spec[3])))
  var passive_id: String = Passives.ITEMS[item_id]
  var tuning: Dictionary = {}
  var passive_references: Array = []
  for spec: Array in Passives.TUNING_SPECS[passive_id]:
   var key: String = passive_id + "." + str(spec[0])
   var entry: Variant = parameters.get(key)
   if not _valid(entry, str(spec[1])): return _deny("invalid_distance_passive_parameter:" + key)
   tuning[str(spec[0])] = float(entry.value)
   passive_references.append(_reference(key, entry, 1.0))
  if not Passives.valid_tuning(passive_id, tuning): return _deny("invalid_distance_passive_bounds:" + passive_id)
  additions[item_id] = {"supported":true, "reason":"", "stats":stats, "parameters":references, "passives":[passive_id], "actives":[], "tier":"final", "distance_passive":tuning, "distance_passive_parameters":passive_references, "rule_provenance":"source_distance_final_damage_inclusive_user_20261009_constant_unique_extra_stat"}
 var result: Dictionary = Prior.build(numeric)
 if not result.get("accepted", false): return result
 if not result.get("definitions") is Dictionary: return _deny("prior_equipment_definitions_missing")
 var prior_count: int = 0
 for definition: Dictionary in result.definitions.values():
  if definition.get("supported", false): prior_count += 1
 if prior_count != 33: return _deny("exact_33_prior_equipment_required")
 for item_id: String in additions:
  if result.definitions.has(item_id): return _deny("distance_item_already_defined:" + item_id)
 for item_id: String in additions: result.definitions[item_id] = additions[item_id]
 var admitted: int = 0
 for definition: Dictionary in result.definitions.values():
  if definition.get("supported", false): admitted += 1
 if admitted != 35: return _deny("exact_35_equipment_required")
 return result

static func _valid(entry: Variant, unit: String) -> bool:
 if not entry is Dictionary or entry.get("unit", "") != unit: return false
 var value: Variant = entry.get("value")
 return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0

static func _reference(key: String, entry: Dictionary, scale: float) -> Dictionary:
 return {"parameter":key, "source_ref":entry.get("source_ref", ""), "source_unit":entry.unit, "current_value":entry.value, "source_value":entry.get("source_value"), "scale":scale}

static func _deny(reason: String) -> Dictionary:
 return {"accepted":false, "reason":reason}
