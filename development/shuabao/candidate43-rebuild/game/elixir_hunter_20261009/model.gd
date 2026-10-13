extends "res://formal_training_20261009/model.gd"
## One next-battle elixir. Original commerce owns storage, consumption and lifetime.
const HUNTER_ID := "elixir:04"
var _hunter_tuning: Dictionary = {}
func bind_hunter_elixir(numeric: Dictionary) -> Dictionary:
 if not _hunter_tuning.is_empty() or state.revision != 0: return _deny("fresh_elixir_binding_required")
 var parameters: Dictionary = numeric.get("parameters",{})
 var fields: Dictionary = {"price":"gold","penetration":"penetration_points","crit":"percent_points","boss_damage_bonus":"percent_points"}
 var next: Dictionary = {}
 for key: String in fields:
  var row: Dictionary = parameters.get(HUNTER_ID+"."+key,{})
  var value: Variant = row.get("value")
  if not (value is int or value is float) or not is_finite(float(value)) or float(value)<0.0 or row.get("unit","")!=fields[key]: return _deny("hunter_elixir_numeric_mismatch:"+key)
  next[key] = float(value)
 if floor(next.price)!=next.price: return _deny("hunter_elixir_integer_price_required")
 var item: Dictionary = commerce_definitions.get("items",{}).get(HUNTER_ID,{})
 if item.get("kind","")!="elixir" or float(item.get("price",-1))!=next.price: return _deny("hunter_elixir_definition_mismatch")
 _hunter_tuning = next
 return {"accepted":true,"reason":""}
func _hunter_sim() -> Node:
 return _health_sim.get_ref() if _health_sim != null else null
func _hunter_bound() -> bool:
 return not _hunter_tuning.is_empty() and _e03_bound(_hunter_sim())
func _hunter_terminal_reason() -> String:
 var owner: RefCounted = _commerce_owner.get_ref() if _commerce_owner != null else null
 if owner==null: return "wrong_commerce_authority"
 if str(owner.get("status")) in ["completed","aborted","defeated","faulted","unbound"]: return "elixir_run_finished"
 return ""
func hunter_elixir_status() -> Dictionary:
 var visit: Dictionary = state.get("shop_visit",{})
 var effect: Dictionary = visit.get("active_elixir",{})
 var sim: Node = _hunter_sim()
 var pending: bool = effect.get("item","")==HUNTER_ID
 var battle: String = str(visit.get("run_id",""))+"|"+str(visit.get("room_id",""))+"|battle"
 var active: bool = _hunter_bound() and pending and state.phase=="combat" and visit.get("phase",state.phase)=="combat" and str(effect.get("battle_id",""))==battle and str(visit.get("battle_id",""))==battle and str(visit.get("run_id",""))==_run_id and sim.phase=="combat" and not sim.hero.dead and sim.room_id==str(visit.get("room_id","")) and sim.combat_level_id==state.combat_level_id
 return {"supported":_hunter_bound(),"item":HUNTER_ID,"pending":pending and str(effect.get("battle_id","" )).is_empty(),"active":active,"effect":effect.duplicate(true),"tuning":_hunter_tuning.duplicate(true),"duration_rule":"next_battle_only","equipment_count":43,"elixirs_supported":1}
func equipment_runtime_status(id: String) -> Dictionary:
 if id==HUNTER_ID:
  return {"supported":_hunter_bound(),"reason":"" if _hunter_bound() else "hunter_elixir_consumer_unbound","stats":{},"consumer":"next_battle_hunter_elixir"}
 return super.equipment_runtime_status(id)
func hunter_elixir_use_status(uid: int) -> Dictionary:
 if not _hunter_bound(): return _deny("hunter_elixir_consumer_unbound")
 var found: bool = false
 for item: Dictionary in state.inventory:
  if int(item.uid)==uid and str(item.id)==HUNTER_ID: found=true;break
 if not found: return _deny("missing_item")
 var terminal: String = _hunter_terminal_reason()
 if not terminal.is_empty(): return _deny(terminal)
 if _hunter_sim().hero.dead: return _deny("not_alive")
 if state.phase!="safe": return _deny("elixir_prebattle_only")
 if state.shop_visit.active_elixir.get("item","")==HUNTER_ID: return _deny("same_name_elixir_active")
 return {"accepted":true,"reason":""}
func commerce_quote(item_id: String) -> Dictionary:
 var result: Dictionary = super.commerce_quote(item_id)
 if item_id==HUNTER_ID and result.get("accepted",false) and result.get("auto_drink",false):
  var terminal: String = _hunter_terminal_reason()
  if not terminal.is_empty(): return _deny(terminal)
 return result
func _apply_commerce(envelope: Dictionary) -> String:
 var operation: String = str(envelope.get("operation",""))
 var args: Dictionary = envelope.get("arguments",{})
 if operation=="consume":
  for item: Dictionary in state.inventory:
   if int(item.uid)==int(args.get("uid",-1)) and str(item.id)==HUNTER_ID:
    var status: Dictionary = hunter_elixir_use_status(int(item.uid))
    if not status.accepted: return str(status.reason)
    break
 if operation in ["buy","craft"] and str(args.get("item",""))==HUNTER_ID and state.inventory.size()>=int(commerce_definitions.slot_limit):
  var terminal: String = _hunter_terminal_reason()
  if not terminal.is_empty(): return terminal
 return super._apply_commerce(envelope)
func equipment_effects() -> Dictionary:
 var result: Dictionary = super.equipment_effects()
 var status: Dictionary = hunter_elixir_status()
 if status.active:
  _add_stats(result.stats,{"penetration":_hunter_tuning.penetration,"crit_chance":_hunter_tuning.crit/100.0})
 result["hunter_elixir"] = status
 return result
func hunter_elixir_multiplier(enemy: Dictionary) -> float:
 if not hunter_elixir_status().active: return 1.0
 var category: String = str(enemy.get("rank_category",enemy.get("kind","")))
 return 1.0+float(_hunter_tuning.boss_damage_bonus)/100.0 if category in ["elite","boss"] else 1.0
func snapshot() -> Dictionary:
 var result: Dictionary = super.snapshot()
 result["hunter_elixir"] = hunter_elixir_status()
 result.content_warnings = [{"reason":"other29_finals_flasks_other4_elixirs_held"}]
 return result
