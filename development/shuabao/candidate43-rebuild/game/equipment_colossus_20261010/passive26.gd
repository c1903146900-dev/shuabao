extends RefCounted
## Pure unique conversion. No HP, base-stat, clock, receipt or actor mutation.
const ITEM_ID := "final:D01"
const PASSIVE_ID := "passive:26"

static func valid_tuning(t: Dictionary) -> bool:
 return t.size()==4 and _number(t.get("health_step")) and float(t.health_step)>0.0 and _number(t.get("health_cap")) and float(t.health_cap)>=0.0 and _number(t.get("ad_per_step")) and float(t.ad_per_step)>=0.0 and _number(t.get("ap_per_step")) and float(t.ap_per_step)>=0.0

static func select_unique(inventory: Array, definitions: Dictionary) -> Dictionary:
 var out: Dictionary = {"equipped":false,"owned_copies":0,"tuning":{}}
 var definition: Variant = definitions.get(ITEM_ID)
 if not definition is Dictionary or definition.get("mechanism_prepared") != true or not definition.get("passive26") is Dictionary or not valid_tuning(definition.passive26): return out
 if not definition.get("passives") is Array or PASSIVE_ID not in definition.passives: return out
 var seen: Dictionary = {}
 for item: Variant in inventory:
  if not item is Dictionary: return {"equipped":false,"owned_copies":0,"tuning":{}}
  if item.get("id") != ITEM_ID: continue
  if not item.get("uid") is int or int(item.uid) < 0 or not item.get("count") is int or int(item.count) <= 0 or seen.has(item.uid): return {"equipped":false,"owned_copies":0,"tuning":{}}
  if int(out.owned_copies) > 9223372036854775807-int(item.count): return {"equipped":false,"owned_copies":0,"tuning":{}}
  seen[item.uid] = true;out.owned_copies += int(item.count)
  out.equipped = true;out.tuning = definition.passive26.duplicate(true)
 return out

static func inspect(selected: Dictionary, final_max_hp: Variant, original_base_hp: Variant) -> Dictionary:
 var out: Dictionary = {"active":false,"owned_copies":selected.get("owned_copies",0),"extra_hp":0.0,"counted_hp":0.0,"AD":0.0,"AP":0.0}
 if selected.get("equipped")!=true or not selected.get("owned_copies") is int or int(selected.owned_copies)<=0 or not selected.get("tuning") is Dictionary or not valid_tuning(selected.tuning): return out
 if not _number(final_max_hp) or not _number(original_base_hp) or float(final_max_hp)<=0.0 or float(original_base_hp)<=0.0: return out
 var extra: float = maxf(0.0,float(final_max_hp)-float(original_base_hp))
 if not is_finite(extra): return out
 var t: Dictionary = selected.tuning
 var counted: float = minf(extra,float(t.health_cap))
 var ad: float = counted/float(t.health_step)*float(t.ad_per_step)
 var ap: float = counted/float(t.health_step)*float(t.ap_per_step)
 if not is_finite(ad) or not is_finite(ap): return out
 out.active=true;out.extra_hp=extra;out.counted_hp=counted;out.AD=ad;out.AP=ap
 return out
static func _number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))
