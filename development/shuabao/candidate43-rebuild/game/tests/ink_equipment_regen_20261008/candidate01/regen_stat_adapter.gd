extends RefCounted
const Prior = preload("res://tests/ink_intermediate_stats_20261004/intermediate_stat_adapter.gd")
const Units = preload("res://tests/ink_equipment_regen_20261008/candidate01/regen_units.gd")
static func build(numeric: Dictionary) -> Dictionary:
 var units: Dictionary = Units.build(numeric)
 if not units.accepted: return units
 var result: Dictionary = Prior.build(numeric)
 if not result.accepted: return result
 for id in ["base:B12", "intermediate:I12"]:
  var parameter: String = id + ".stat.health_regen"
  var mapping: Dictionary = units.parameters[parameter]
  var definition: Dictionary = result.definitions[id]
  definition.supported = true
  definition.reason = ""
  definition.stats = {"hp_regen":mapping.runtime_value}
  if id == "intermediate:I12": definition.stats.max_hp = float(numeric.parameters["intermediate:I12.stat.max_health"].value)
  definition["regen_mapping"] = mapping.duplicate(true)
  definition["unit_aware_label"] = Units.label(float(mapping.current_value))
  definition.rule_provenance = mapping.rule_provenance
  if definition.has("parameters"):
   for index in range(definition.parameters.size()):
    if definition.parameters[index].parameter == parameter: definition.parameters[index] = mapping.duplicate(true)
  else:
   definition["runtime_stat"] = "hp_regen"
   definition["scale"] = mapping.scale
 result["regen_parameters"] = units.parameters
 return result
