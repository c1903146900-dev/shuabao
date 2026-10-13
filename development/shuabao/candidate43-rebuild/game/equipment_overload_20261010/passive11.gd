extends RefCounted
## Unique source selection and pure timed-stack arithmetic.
const ITEM_ID := "final:C03"
const PASSIVE_ID := "passive:11"
const BUFF_KEY := "equipment_overload_passive11"
static func valid_tuning(t: Dictionary) -> bool:
 return t.size()==4 and _number(t.get("ap_per_stack")) and float(t.ap_per_stack)>=0.0 and _number(t.get("ms_per_stack")) and float(t.ms_per_stack)>=0.0 and float(t.ms_per_stack)<=100.0 and _number(t.get("duration")) and float(t.duration)>0.0 and _number(t.get("max_stacks")) and float(t.max_stacks)>=1.0 and floor(float(t.max_stacks))==float(t.max_stacks) and float(t.max_stacks)<=2147483647.0

static func select_unique(inventory: Array, definitions: Dictionary) -> Dictionary:
 var out: Dictionary = {"equipped":false,"owned_copies":0,"tuning":{}}
 var definition: Variant = definitions.get(ITEM_ID)
 if not definition is Dictionary or definition.get("mechanism_prepared") != true or not definition.get("passive11") is Dictionary or not valid_tuning(definition.passive11): return out
 if not definition.get("passives") is Array or PASSIVE_ID not in definition.passives: return out
 var seen: Dictionary = {}
 for item: Variant in inventory:
  if not item is Dictionary: return {"equipped":false,"owned_copies":0,"tuning":{}}
  if item.get("id") != ITEM_ID: continue
  if not item.get("uid") is int or int(item.uid) < 0 or not item.get("count") is int or int(item.count) <= 0 or seen.has(item.uid): return {"equipped":false,"owned_copies":0,"tuning":{}}
  if int(out.owned_copies) > 9223372036854775807-int(item.count): return {"equipped":false,"owned_copies":0,"tuning":{}}
  seen[item.uid] = true;out.owned_copies += int(item.count)
  out.equipped = true;out.tuning = definition.passive11.duplicate(true)
 return out

static func inspect(selected: Dictionary, buff: Dictionary, scope: Dictionary, now: float) -> Dictionary:
 var out: Dictionary = {"active":false,"stacks":0,"AP":0.0,"move_fraction":0.0}
 if not selected.get("equipped",false) or not valid_tuning(selected.get("tuning",{})) or not is_finite(now) or now<0.0 or buff.get("scope")!=scope: return out
 if not buff.get("stacks") is int or int(buff.stacks)<1 or int(buff.stacks)>int(selected.tuning.max_stacks): return out
 if not _number(buff.get("expires_at")) or now>=float(buff.expires_at): return out
 var ap: float = int(buff.stacks)*float(selected.tuning.ap_per_stack)
 var ms: float = int(buff.stacks)*float(selected.tuning.ms_per_stack)/100.0
 if not is_finite(ap) or not is_finite(ms): return out
 out.active=true;out.stacks=int(buff.stacks);out.AP=ap;out.move_fraction=ms
 return out

static func propose(selected: Dictionary, previous: Dictionary, scope: Dictionary, now: float) -> Dictionary:
 if not selected.get("equipped",false) or not valid_tuning(selected.get("tuning",{})) or not is_finite(now) or now<0.0: return {}
 var active: Dictionary = inspect(selected,previous,scope,now)
 var stacks: int = mini(int(active.stacks)+1,int(selected.tuning.max_stacks))
 var expires: float = now+float(selected.tuning.duration)
 if not is_finite(expires): return {}
 return {"scope":scope.duplicate(true),"stacks":stacks,"expires_at":expires,"last_release_at":now}

static func _number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))
