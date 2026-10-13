extends RefCounted
## Pure selection and original-clock interval projection. No healing, ticking,
## persistent buff or task authority is introduced by this helper.
const ITEM_ID := "final:E03"
const PASSIVE_ID := "passive:24"

static func valid_tuning(t: Dictionary) -> bool:
 return t.size() == 2 and _number(t.get("combat_time")) and float(t.combat_time) > 0.0 and _number(t.get("regen_bonus")) and float(t.regen_bonus) >= 0.0

static func select_unique(inventory: Array, definitions: Dictionary) -> Dictionary:
 var out: Dictionary = {"equipped":false,"owned_copies":0,"tuning":{}}
 var definition: Variant = definitions.get(ITEM_ID)
 if not definition is Dictionary or definition.get("mechanism_prepared") != true or not definition.get("passive24") is Dictionary or not valid_tuning(definition.passive24): return out
 var seen: Dictionary = {}
 for item: Variant in inventory:
  if not item is Dictionary: return {"equipped":false,"owned_copies":0,"tuning":{}}
  if item.get("id") != ITEM_ID: continue
  if not item.get("uid") is int or int(item.uid) < 0 or not item.get("count") is int or int(item.count) <= 0 or seen.has(item.uid): return {"equipped":false,"owned_copies":0,"tuning":{}}
  if int(out.owned_copies) > 9223372036854775807-int(item.count): return {"equipped":false,"owned_copies":0,"tuning":{}}
  seen[item.uid] = true;out.owned_copies += int(item.count)
  out.equipped = true;out.tuning = definition.passive24.duplicate(true)
 return out

static func inspect(selected: Dictionary, context: Dictionary, interval: Dictionary = {}) -> Dictionary:
 var out: Dictionary = {"equipped":selected.get("equipped",false),"owned_copies":selected.get("owned_copies",0),"active":false,"factor":1.0,"applied_factor":1.0,"combat_started_at":-1.0,"elapsed":0.0,"combat_time":0.0,"regen_bonus":0.0,"clock":"original_common_actor_time","interval_weighted":false,"active_interval":0.0,"interval_duration":0.0}
 if selected.get("equipped") != true or not selected.get("owned_copies") is int or int(selected.owned_copies) <= 0 or not selected.get("tuning") is Dictionary or not valid_tuning(selected.tuning): return out
 out.combat_time = float(selected.tuning.combat_time);out.regen_bonus = float(selected.tuning.regen_bonus)
 if context.get("combat") != true or context.get("owner_alive") != true or context.get("bound") != true or context.get("clock") != "original_common_actor_time": return out
 for key: String in ["now","combat_started_at"]:
  if not _number(context.get(key)) or float(context[key]) < 0.0: return out
 var now: float = float(context.now)
 var started: float = float(context.combat_started_at)
 if now < started: return out
 out.combat_started_at = started;out.elapsed = now-started
 var threshold: float = started+float(selected.tuning.combat_time)
 if not is_finite(threshold): return out
 out.active = now >= threshold
 out.factor = 1.0 + float(selected.tuning.regen_bonus)/100.0 if out.active else 1.0
 out.applied_factor = out.factor
 if interval.is_empty(): return out
 for key: String in ["start","end","duration"]:
  if not _number(interval.get(key)): return out
 var begin: float = float(interval.start)
 var end: float = float(interval.end)
 var duration: float = float(interval.duration)
 if begin < started or end != now or end < begin or duration <= 0.0 or interval.get("episode") != context.get("episode") or interval.get("generation") != context.get("generation") or interval.get("room_id") != context.get("room_id"): return out
 # The original fixed-step amount is rate*actor_dt. Only the accepted part after
 # six original combat seconds receives extra rate; no gameplay epsilon.
 var active_duration: float = 0.0
 if begin >= threshold: active_duration = duration
 elif end > threshold: active_duration = clampf(end-threshold,0.0,duration)
 out.interval_weighted = true;out.active_interval = active_duration;out.interval_duration = duration
 out.applied_factor = 1.0 + float(selected.tuning.regen_bonus)/100.0*(active_duration/duration)
 return out

static func _number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))
