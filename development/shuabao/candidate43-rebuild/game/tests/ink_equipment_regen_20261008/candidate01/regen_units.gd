extends RefCounted
## Developer balancing decision 2026-10-08; never a quotation from the source.
## Original values stay untouched. Shared by equipment, G04 stages and training12.
const SOURCE_UNIT = "health_regen_source_units"
const RUNTIME_UNIT = "health_points_per_actor_combat_second"
const SOURCE_PERIOD_SECONDS = 5.0
const REQUIRED_PARAMETERS = ["base:B12.stat.health_regen", "intermediate:I12.stat.health_regen", "final:E01.stat.health_regen", "final:E03.stat.health_regen", "final:E04.stat.health_regen", "final:G04.stat.health_regen", "task:G04.regen_per_stage", "training:12.value"]
static func build(numeric: Dictionary) -> Dictionary:
 if not numeric.get("parameters") is Dictionary: return {"accepted":false,"reason":"numeric_parameters_missing"}
 var projected: Dictionary = {}
 for key in REQUIRED_PARAMETERS:
  if not numeric.parameters.get(key) is Dictionary: return {"accepted":false,"reason":"invalid_regen_entry:"+key}
  if numeric.parameters[key].get("unit", "") != SOURCE_UNIT: return {"accepted":false,"reason":"invalid_regen_unit:"+key}
 for key in numeric.parameters:
  var entry: Variant = numeric.parameters[key]
  if not entry is Dictionary or entry.get("unit", "") != SOURCE_UNIT: continue
  var value: Variant = entry.get("value", null)
  if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0: return {"accepted":false,"reason":"invalid_regen_value:"+str(key)}
  projected[key] = {"parameter":key,"current_value":value,"source_value":entry.get("source_value",null),"source_ref":entry.get("source_ref", ""),"source_unit":SOURCE_UNIT,"resolved_source_unit":"health_points_per_5_actor_combat_seconds","runtime_stat":"hp_regen","runtime_unit":RUNTIME_UNIT,"scale":1.0/SOURCE_PERIOD_SECONDS,"runtime_value":float(value)/SOURCE_PERIOD_SECONDS,"rule_provenance":"developer_balance_regen_per5_combat_seconds_20261008"}
 return {"accepted":true,"reason":"","parameters":projected}
static func per_second(source_value: float) -> float:
 return source_value / SOURCE_PERIOD_SECONDS
static func label(source_value: float) -> String:
 return "战斗生命恢复 +%s/5秒（+%s/秒；随角色战斗时间）" % [str(source_value),str(per_second(source_value))]
