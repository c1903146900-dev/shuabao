extends RefCounted
## Preserve the exact prior 32 definitions; admit only A05 with its full consumer.
## Commerce still owns source price, recipes, UID stacking and transaction undo.
const Prior = preload("res://tests/ink_equipment_live_20261008/content01/adapter.gd")
const Passive18 = preload("res://equipment_expansion_20261009/passive18.gd")
const ITEM_ID := "final:A05"
const STAT_SPECS := [["AD", "attack_points", "AD", 1.0], ["crit_chance_pct", "percent_points", "crit_chance", 0.01], ["penetration", "penetration_points", "penetration", 1.0]]

static func build(numeric: Dictionary) -> Dictionary:
 if not numeric.get("parameters") is Dictionary: return _deny("numeric_parameters_missing")
 var parameters: Dictionary = numeric.parameters
 var stats: Dictionary = {}
 var references: Array = []
 for spec: Array in STAT_SPECS:
  var key: String = ITEM_ID + ".stat." + str(spec[0])
  var entry: Variant = parameters.get(key)
  if not _valid(entry, str(spec[1])): return _deny("invalid_a05_stat:" + key)
  stats[str(spec[2])] = float(entry.value) * float(spec[3])
  references.append(_reference(key, entry, float(spec[3])))
 var tuning: Dictionary = {}
 var passive_references: Array = []
 for field: String in Passive18.TUNING_KEYS:
  var key: String = Passive18.PASSIVE_ID + "." + field
  var entry: Variant = parameters.get(key)
  if not _valid(entry, "percent_points"): return _deny("invalid_passive18_parameter:" + key)
  tuning[field] = float(entry.value)
  passive_references.append(_reference(key, entry, 1.0))
 if not Passive18.valid_tuning(tuning): return _deny("invalid_passive18_bounds")
 var result: Dictionary = Prior.build(numeric)
 if not result.get("accepted", false): return result
 if not result.get("definitions") is Dictionary: return _deny("prior_equipment_definitions_missing")
 var prior_count: int = 0
 for definition: Dictionary in result.definitions.values():
  if definition.get("supported", false): prior_count += 1
 if prior_count != 32 or result.definitions.has(ITEM_ID): return _deny("exact_32_prior_equipment_required")
 result.definitions[ITEM_ID] = {"supported":true, "reason":"", "stats":stats, "parameters":references, "passives":[Passive18.PASSIVE_ID], "actives":[], "tier":"final", "passive18":tuning, "passive18_parameters":passive_references, "rule_provenance":"source_equipment_passive18_discrete_lost_hp_floor_original_values"}
 var admitted: int = 0
 for definition: Dictionary in result.definitions.values():
  if definition.get("supported", false): admitted += 1
 if admitted != 33: return _deny("exact_33_equipment_required")
 return result

static func _valid(entry: Variant, unit: String) -> bool:
 if not entry is Dictionary or entry.get("unit", "") != unit: return false
 var value: Variant = entry.get("value")
 return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0

static func _reference(key: String, entry: Dictionary, scale: float) -> Dictionary:
 return {"parameter":key, "source_ref":entry.get("source_ref", ""), "source_unit":entry.unit, "current_value":entry.value, "source_value":entry.get("source_value"), "scale":scale}

static func _deny(reason: String) -> Dictionary:
 return {"accepted":false, "reason":reason}
