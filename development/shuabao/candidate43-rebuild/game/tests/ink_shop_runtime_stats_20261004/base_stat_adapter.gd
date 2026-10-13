extends RefCounted
## Current editable values, explicit units. Existing projection/caps remain downstream.
const MAPPING = {
 "base:B01":["AD", "attack_points", "AD", 1.0],
 "base:B02":["AP", "ability_points", "AP", 1.0],
 "base:B03":["attack_speed_pct", "percent_points", "attack_speed", 0.01],
 "base:B04":["crit_chance_pct", "percent_points", "crit_chance", 0.01],
 "base:B05":["cdr_pct", "percent_points", "cooldown_reduction", 0.01],
 "base:B06":["max_health", "health_points", "max_hp", 1.0],
 "base:B07":["defense", "defense_points", "defense", 1.0],
 "base:B08":["move_speed_pct", "percent_points", "move_speed", 0.01],
 "base:B09":["lifesteal_pct", "percent_points", "lifesteal", 0.01],
 "base:B10":["tenacity_pct", "percent_points", "tenacity", 0.01],
 "base:B11":["penetration", "penetration_points", "penetration", 1.0],
 "base:B12":["health_regen", "health_regen_source_units", "", 1.0]
}
static func build(numeric: Dictionary) -> Dictionary:
 if numeric.get("schema_version", "") != "1.0.0-source-foundation": return _deny("numeric_schema_mismatch")
 if not numeric.get("parameters") is Dictionary: return _deny("numeric_parameters_missing")
 var definitions: Dictionary = {}
 for id in MAPPING:
  var mapping: Array = MAPPING[id]
  var parameter: String = id + ".stat." + str(mapping[0])
  var entry: Dictionary = numeric.parameters.get(parameter, {})
  var value: Variant = entry.get("value", null)
  if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0: return _deny("invalid_stat_value:" + parameter)
  if entry.get("unit", "") != mapping[1]: return _deny("invalid_stat_unit:" + parameter)
  var supported: bool = not str(mapping[2]).is_empty()
  var stats: Dictionary = {}
  if supported: stats[mapping[2]] = float(value) * float(mapping[3])
  definitions[id] = {"supported":supported, "reason":"" if supported else "regen_time_unit_unresolved", "stats":stats, "parameter":parameter, "source_ref":entry.get("source_ref", ""), "source_unit":mapping[1], "current_value":value, "source_value":entry.get("source_value", null), "passives":[], "actives":[], "tier":"base", "rule_provenance":"source_equipment_value_existing_runtime_projection_not_final_balance"}
 return {"accepted":true, "reason":"", "definitions":definitions}
static func _deny(reason: String) -> Dictionary:
 return {"accepted":false, "reason":reason}
