extends RefCounted
## Pure unique selection and refresh-only arithmetic; source authority is separate.
const ITEM_ID := "final:D06"
const PASSIVE_ID := "passive:27"
const BUFF_KEY := "equipment_counterattack_passive27"
static func _number(value: Variant)->bool:
 return (value is int or value is float) and is_finite(float(value))
static func valid_tuning(t: Dictionary)->bool:
 if t.size()!=4 or not _number(t.get("duration")) or float(t.duration)<=0.0:return false
 for key: String in ["move_bonus","damage_bonus","tenacity_bonus"]:
  if not _number(t.get(key)) or float(t[key])<0.0 or float(t[key])>100.0:return false
 return true
static func select_unique(inventory: Array,definitions: Dictionary)->Dictionary:
 var out: Dictionary={"equipped":false,"owned_copies":0,"tuning":{}}
 var definition: Variant=definitions.get(ITEM_ID)
 if not definition is Dictionary or definition.get("mechanism_prepared")!=true or not definition.get("passive27") is Dictionary or not valid_tuning(definition.passive27):return out
 if not definition.get("passives") is Array or PASSIVE_ID not in definition.passives:return out
 var seen: Dictionary={}
 for item: Variant in inventory:
  if not item is Dictionary:return {"equipped":false,"owned_copies":0,"tuning":{}}
  if item.get("id")!=ITEM_ID:continue
  if not item.get("uid") is int or int(item.uid)<0 or not item.get("count") is int or int(item.count)<=0 or seen.has(item.uid):return {"equipped":false,"owned_copies":0,"tuning":{}}
  if int(out.owned_copies)>9223372036854775807-int(item.count):return {"equipped":false,"owned_copies":0,"tuning":{}}
  seen[item.uid]=true;out.owned_copies+=int(item.count)
  out.equipped=true;out.tuning=definition.passive27.duplicate(true)
 return out
static func inspect(selected: Dictionary,buff: Dictionary,scope: Dictionary,now: float)->Dictionary:
 var out: Dictionary={"active":false,"move_fraction":0.0,"tenacity_fraction":0.0,"final_multiplier":1.0,"remaining":0.0}
 if not selected.get("equipped",false) or not valid_tuning(selected.get("tuning",{})) or scope.is_empty() or buff.get("scope")!=scope or not is_finite(now) or now<0.0:return out
 if not _number(buff.get("last_control_end_at")) or not _number(buff.get("expires_at")) or now<float(buff.last_control_end_at) or now>=float(buff.expires_at):return out
 if float(buff.expires_at)!=float(buff.last_control_end_at)+float(selected.tuning.duration):return out
 out.active=true;out.move_fraction=float(selected.tuning.move_bonus)/100.0;out.tenacity_fraction=float(selected.tuning.tenacity_bonus)/100.0
 out.final_multiplier=1.0+float(selected.tuning.damage_bonus)/100.0;out.remaining=float(buff.expires_at)-now
 return out
static func propose(selected: Dictionary,scope: Dictionary,now: float)->Dictionary:
 if not selected.get("equipped",false) or not valid_tuning(selected.get("tuning",{})) or scope.is_empty() or not is_finite(now) or now<0.0:return {}
 var expires: float=now+float(selected.tuning.duration)
 if not is_finite(expires) or expires<=now:return {}
 # Deliberately no previous-strength/stacks input: retrigger replaces one timer.
 return {"scope":scope.duplicate(true),"last_control_end_at":now,"expires_at":expires}
