extends RefCounted
## Extend the tested base adapter only with original intermediate stat parameters.
## Fixed IDs/units/sinks; edited numeric values come from the formal parameter map.
## I12 is wholly blocked. Its known HP does not justify selling inert regen.
const BaseAdapter=preload("res://tests/ink_shop_runtime_stats_20261004/base_stat_adapter.gd")
const INTERMEDIATE_MAPPING={
 "intermediate:I01": [
  [
   "AD",
   "attack_points",
   "AD",
   1.0
  ]
 ],
 "intermediate:I02": [
  [
   "AP",
   "ability_points",
   "AP",
   1.0
  ]
 ],
 "intermediate:I03": [
  [
   "attack_speed_pct",
   "percent_points",
   "attack_speed",
   0.01
  ],
  [
   "crit_chance_pct",
   "percent_points",
   "crit_chance",
   0.01
  ],
  [
   "move_speed_pct",
   "percent_points",
   "move_speed",
   0.01
  ]
 ],
 "intermediate:I04": [
  [
   "AD",
   "attack_points",
   "AD",
   1.0
  ],
  [
   "penetration",
   "penetration_points",
   "penetration",
   1.0
  ]
 ],
 "intermediate:I05": [
  [
   "AP",
   "ability_points",
   "AP",
   1.0
  ],
  [
   "cdr_pct",
   "percent_points",
   "cooldown_reduction",
   0.01
  ]
 ],
 "intermediate:I06": [
  [
   "AD",
   "attack_points",
   "AD",
   1.0
  ],
  [
   "lifesteal_pct",
   "percent_points",
   "lifesteal",
   0.01
  ]
 ],
 "intermediate:I07": [
  [
   "max_health",
   "health_points",
   "max_hp",
   1.0
  ],
  [
   "defense",
   "defense_points",
   "defense",
   1.0
  ]
 ],
 "intermediate:I08": [
  [
   "max_health",
   "health_points",
   "max_hp",
   1.0
  ],
  [
   "tenacity_pct",
   "percent_points",
   "tenacity",
   0.01
  ]
 ],
 "intermediate:I09": [
  [
   "move_speed_pct",
   "percent_points",
   "move_speed",
   0.01
  ],
  [
   "cdr_pct",
   "percent_points",
   "cooldown_reduction",
   0.01
  ]
 ],
 "intermediate:I10": [
  [
   "attack_speed_pct",
   "percent_points",
   "attack_speed",
   0.01
  ],
  [
   "lifesteal_pct",
   "percent_points",
   "lifesteal",
   0.01
  ]
 ],
 "intermediate:I11": [
  [
   "crit_chance_pct",
   "percent_points",
   "crit_chance",
   0.01
  ],
  [
   "penetration",
   "penetration_points",
   "penetration",
   1.0
  ]
 ],
 "intermediate:I12": [
  [
   "max_health",
   "health_points",
   "max_hp",
   1.0
  ],
  [
   "health_regen",
   "health_regen_source_units",
   "",
   1.0
  ]
 ],
 "intermediate:I13": [
  [
   "AD",
   "attack_points",
   "AD",
   1.0
  ],
  [
   "cdr_pct",
   "percent_points",
   "cooldown_reduction",
   0.01
  ]
 ],
 "intermediate:I14": [
  [
   "AP",
   "ability_points",
   "AP",
   1.0
  ],
  [
   "penetration",
   "penetration_points",
   "penetration",
   1.0
  ]
 ],
 "intermediate:I15": [
  [
   "defense",
   "defense_points",
   "defense",
   1.0
  ],
  [
   "tenacity_pct",
   "percent_points",
   "tenacity",
   0.01
  ]
 ],
 "intermediate:I16": [
  [
   "defense",
   "defense_points",
   "defense",
   1.0
  ],
  [
   "move_speed_pct",
   "percent_points",
   "move_speed",
   0.01
  ]
 ],
 "intermediate:I17": [
  [
   "max_health",
   "health_points",
   "max_hp",
   1.0
  ],
  [
   "AP",
   "ability_points",
   "AP",
   1.0
  ]
 ],
 "intermediate:I18": [
  [
   "AD",
   "attack_points",
   "AD",
   1.0
  ],
  [
   "move_speed_pct",
   "percent_points",
   "move_speed",
   0.01
  ]
 ]
}
static func build(numeric: Dictionary)->Dictionary:
 if not numeric.get("parameters") is Dictionary:return _deny("numeric_parameters_missing")
 # Validate node shapes before the inherited base adapter or typed Dictionary
 # access can fail. Serialized scalar/null parameter nodes are malformed input.
 for id in BaseAdapter.MAPPING:
  var key: String=id+".stat."+str(BaseAdapter.MAPPING[id][0])
  if not numeric.parameters.get(key) is Dictionary:return _deny("invalid_stat_entry:"+key)
 for id in INTERMEDIATE_MAPPING:
  for mapping in INTERMEDIATE_MAPPING[id]:
   var key: String=id+".stat."+str(mapping[0])
   if not numeric.parameters.get(key) is Dictionary:return _deny("invalid_stat_entry:"+key)
 var result: Dictionary=BaseAdapter.build(numeric)
 if not result.accepted:return result
 var definitions: Dictionary=result.definitions
 for id in INTERMEDIATE_MAPPING:
  var stats: Dictionary={}
  var sources: Array=[]
  var supported: bool=true
  for mapping in INTERMEDIATE_MAPPING[id]:
   var parameter: String=id+".stat."+str(mapping[0])
   var entry: Dictionary=numeric.parameters.get(parameter,{})
   var value: Variant=entry.get("value",null)
   if not (value is int or value is float) or not is_finite(float(value)) or float(value)<0.0:return _deny("invalid_stat_value:"+parameter)
   if entry.get("unit","")!=mapping[1]:return _deny("invalid_stat_unit:"+parameter)
   if str(mapping[2]).is_empty():supported=false
   else:stats[mapping[2]]=float(value)*float(mapping[3])
   sources.append({"parameter":parameter,"source_ref":entry.get("source_ref",""),"source_unit":mapping[1],"current_value":value,"source_value":entry.get("source_value",null),"runtime_stat":mapping[2],"scale":mapping[3]})
  if not supported:stats.clear()
  definitions[id]={"supported":supported,"reason":"" if supported else "regen_time_unit_unresolved","stats":stats,"parameters":sources,"passives":[],"actives":[],"tier":"intermediate","rule_provenance":"source_equipment_value_existing_runtime_projection_not_final_balance"}
 return {"accepted":true,"reason":"","definitions":definitions}
static func _deny(reason: String)->Dictionary:return {"accepted":false,"reason":reason}
