extends RefCounted
## Pure window arithmetic; authority lives in the exact original-source bridge.
const ITEM_ID := "final:C02"
const PASSIVE_ID := "passive:10"
static func valid_tuning(t: Dictionary) -> bool:
 return t.size()==2 and _number(t.get("window")) and float(t.window)>0.0 and _number(t.get("damage_bonus")) and float(t.damage_bonus)>=0.0 and float(t.damage_bonus)<=100.0

static func select_unique(inventory: Array, definitions: Dictionary) -> Dictionary:
 var out: Dictionary = {"equipped":false,"owned_copies":0,"tuning":{}}
 var definition: Variant = definitions.get(ITEM_ID)
 if not definition is Dictionary or definition.get("mechanism_prepared") != true or not definition.get("passive10") is Dictionary or not valid_tuning(definition.passive10): return out
 if not definition.get("passives") is Array or PASSIVE_ID not in definition.passives: return out
 var seen: Dictionary = {}
 for item: Variant in inventory:
  if not item is Dictionary: return {"equipped":false,"owned_copies":0,"tuning":{}}
  if item.get("id") != ITEM_ID: continue
  if not item.get("uid") is int or int(item.uid) < 0 or not item.get("count") is int or int(item.count) <= 0 or seen.has(item.uid): return {"equipped":false,"owned_copies":0,"tuning":{}}
  if int(out.owned_copies) > 9223372036854775807-int(item.count): return {"equipped":false,"owned_copies":0,"tuning":{}}
  seen[item.uid] = true;out.owned_copies += int(item.count)
  out.equipped = true;out.tuning = definition.passive10.duplicate(true)
 return out


static func propose(selected: Dictionary, previous: Dictionary, scope: Dictionary, family: String, cast_id: int, now: float) -> Dictionary:
 if not selected.get("equipped",false) or not valid_tuning(selected.get("tuning",{})) or scope.is_empty() or family not in ["q1","q2","q3","e1","e2","e3"] or cast_id<=0 or not is_finite(now) or now<0.0:return {}
 var slot: String=family.left(1)
 var alternating: bool=previous.get("scope")==scope and previous.get("slot","") in ["q","e"] and previous.slot!=slot and previous.get("cast_id",-1)!=cast_id and _number(previous.get("at")) and now>=float(previous.at) and now-float(previous.at)<=float(selected.tuning.window)
 return {"scope":scope.duplicate(true),"slot":slot,"cast_id":cast_id,"at":now,"multiplier":1.0+float(selected.tuning.damage_bonus)/100.0 if alternating else 1.0}

static func _number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))
