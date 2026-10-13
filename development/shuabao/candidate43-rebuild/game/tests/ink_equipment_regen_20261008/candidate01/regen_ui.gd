extends RefCounted
const Text = preload("res://scripts/ui/content_text.gd")
const Units = preload("res://tests/ink_equipment_regen_20261008/candidate01/regen_units.gd")
## Pass the runtime definition from equipment_runtime_status, never raw source
## health_regen as hp_regen. Suitable for the detail panel and item tooltip.
static func describe(runtime_definition: Dictionary) -> String:
 var ordinary: Dictionary = runtime_definition.get("stats",{}).duplicate(true)
 ordinary.erase("hp_regen")
 var pieces: PackedStringArray = []
 if not ordinary.is_empty(): pieces.append(Text.stats(ordinary))
 if runtime_definition.has("regen_mapping"):
  pieces.append(Units.label(float(runtime_definition.regen_mapping.current_value)))
 elif runtime_definition.get("stats",{}).has("hp_regen"):
  pieces.append("战斗生命恢复 +%s/秒（角色战斗时间）" % str(runtime_definition.stats.hp_regen))
 return " · ".join(pieces)
