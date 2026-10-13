extends RefCounted
const Regen=preload("res://tests/ink_equipment_regen_20261008/candidate01/regen_stat_adapter.gd")
const Passive=preload("res://tests/ink_equipment_passive23_20261008/candidate01/adapter.gd")
static func build(numeric: Dictionary) -> Dictionary:
 var result: Dictionary=Regen.build(numeric)
 if not result.accepted: return result
 var passive: Dictionary=Passive.build(numeric)
 if not passive.accepted: return passive
 for id in Passive.ITEMS: result.definitions[id]=passive.definitions[id].duplicate(true)
 var admitted: int=0
 for definition in result.definitions.values():
  if definition.supported: admitted+=1
 if admitted!=32: return {"accepted":false,"reason":"exact_32_equipment_required"}
 return result
