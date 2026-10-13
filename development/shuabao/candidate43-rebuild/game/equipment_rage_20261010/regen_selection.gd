extends RefCounted
const Original = preload("res://equipment_regeneration_20261009/passive24.gd")
const ITEMS := ["final:E03", "final:D03"]
static func select_unique(inventory: Array, definitions: Dictionary) -> Dictionary:
 var out: Dictionary = {"equipped":false,"owned_copies":0,"tuning":{}}
 var seen: Dictionary = {}
 for item: Variant in inventory:
  if not item is Dictionary: return _empty()
  if item.get("id") not in ITEMS: continue
  if not item.get("uid") is int or int(item.uid)<0 or not item.get("count") is int or int(item.count)<=0 or seen.has(item.uid): return _empty()
  var definition: Variant = definitions.get(item.id)
  if not definition is Dictionary or definition.get("mechanism_prepared") != true or not definition.get("passive24") is Dictionary or not Original.valid_tuning(definition.passive24): return _empty()
  if not definition.get("passives") is Array or "passive:24" not in definition.passives: return _empty()
  if out.equipped and out.tuning != definition.passive24: return _empty()
  if int(out.owned_copies)>9223372036854775807-int(item.count): return _empty()
  seen[item.uid]=true;out.owned_copies+=int(item.count)
  out.equipped=true;out.tuning=definition.passive24.duplicate(true)
 return out
static func _empty() -> Dictionary:
 return {"equipped":false,"owned_copies":0,"tuning":{}}
