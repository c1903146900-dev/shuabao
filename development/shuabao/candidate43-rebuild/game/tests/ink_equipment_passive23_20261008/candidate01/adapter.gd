extends RefCounted
## Narrow successor: all prior holds preserved, only D05/E05 gain a complete consumer.
const Prior = preload("res://tests/ink_intermediate_stats_20261004/intermediate_stat_adapter.gd")
const ITEMS = ["final:D05", "final:E05"]
const STATS = [["max_health", "health_points", "max_hp", 1.0], ["defense", "defense_points", "defense", 1.0], ["tenacity_pct", "percent_points", "tenacity", 0.01]]
const PASSIVE = {"radius":"meters", "enemy_cap":"count", "defense_per_enemy":"defense_points", "tenacity_per_enemy":"percent_points"}
static func build(numeric: Dictionary) -> Dictionary:
 var prior: Dictionary = Prior.build(numeric)
 if not prior.accepted: return prior
 var parameters: Dictionary = numeric.parameters
 var tuning: Dictionary = {}
 for key in PASSIVE:
  var id: String = "passive:23." + key
  if not _valid(parameters.get(id), PASSIVE[key]): return {"accepted":false,"reason":"invalid_passive_parameter:" + id}
  tuning[key] = float(parameters[id].value)
 if tuning.enemy_cap != floor(tuning.enemy_cap): return {"accepted":false,"reason":"noninteger_enemy_cap"}
 for id in ITEMS:
  var stats: Dictionary = {}
  var refs: Array = []
  for spec in STATS:
   var key: String = id + ".stat." + spec[0]
   if not _valid(parameters.get(key), spec[1]): return {"accepted":false,"reason":"invalid_final_stat:" + key}
   stats[spec[2]] = float(parameters[key].value) * spec[3]
   refs.append({"parameter":key,"source_ref":parameters[key].get("source_ref", ""),"scale":spec[3]})
  prior.definitions[id] = {"supported":true,"reason":"","stats":stats,"parameters":refs,"passives":["passive:23"],"actives":[],"tier":"final","passive23":tuning.duplicate(true)}
 return prior
static func _valid(entry: Variant, unit: String) -> bool:
 if not entry is Dictionary: return false
 var value: Variant = entry.get("value")
 return (value is float or value is int) and is_finite(float(value)) and float(value) >= 0.0 and entry.get("unit", "") == unit
