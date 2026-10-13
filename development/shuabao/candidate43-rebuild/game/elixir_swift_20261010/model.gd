extends "res://equipment_overload_20261010/model.gd"
## One next-battle elixir. Original commerce owns storage, consumption and lifetime.
const SWIFT_ID := "elixir:05"
const SwiftRuntime = preload("runtime.gd")
var _swift_tuning: Dictionary = {}
var _swift_trusted: Dictionary = {}
var _swift_base_ms: float=0.0
var _swift_original_hero: WeakRef
func bind_swift_elixir(numeric: Dictionary) -> Dictionary:
 if not _swift_tuning.is_empty() or state.revision != 0: return _deny("fresh_elixir_binding_required")
 var parameters: Dictionary = numeric.get("parameters",{})
 var fields: Dictionary = {"price":"gold","move":"percent_points","attack_speed":"percent_points","cdr":"percent_points","after_shift_move":"percent_points","after_shift_duration":"seconds"}
 var next: Dictionary = {}
 for key: String in fields:
  var row: Dictionary = parameters.get(SWIFT_ID+"."+key,{})
  var value: Variant = row.get("value")
  if not (value is int or value is float) or not is_finite(float(value)) or float(value)<0.0 or row.get("unit","")!=fields[key]: return _deny("swift_elixir_numeric_mismatch:"+key)
  next[key] = float(value)
 if next.after_shift_duration <= 0.0 or next.after_shift_move > 100.0 or next.move > 100.0 or next.attack_speed > 100.0 or next.cdr > 100.0: return _deny("swift_elixir_invalid_effect")
 if floor(next.price)!=next.price: return _deny("swift_elixir_integer_price_required")
 var item: Dictionary = commerce_definitions.get("items",{}).get(SWIFT_ID,{})
 if item.get("kind","")!="elixir" or float(item.get("price",-1))!=next.price: return _deny("swift_elixir_definition_mismatch")
 _swift_tuning = next
 return {"accepted":true,"reason":""}
func _swift_sim() -> Node:
 return _health_sim.get_ref() if _health_sim != null else null
func _swift_bound() -> bool:
 return not _swift_tuning.is_empty() and _d01_bound(_swift_sim()) and _swift_original_hero!=null and is_same(_swift_original_hero.get_ref(),_swift_sim().hero) and _swift_base_ms>0.0 and is_finite(_swift_base_ms) and ColossusPassive._number(_swift_sim().hero.base_stats.get("move_speed")) and float(_swift_sim().hero.base_stats.move_speed)==_swift_base_ms
func _swift_terminal_reason() -> String:
 var owner: RefCounted = _commerce_owner.get_ref() if _commerce_owner != null else null
 if owner==null: return "wrong_commerce_authority"
 if str(owner.get("status")) in ["completed","aborted","defeated","faulted","unbound"]: return "elixir_run_finished"
 return ""
func swift_elixir_status() -> Dictionary:
 var visit: Dictionary = state.get("shop_visit",{})
 var effect: Dictionary = visit.get("active_elixir",{})
 var sim: Node = _swift_sim()
 var pending: bool = effect.get("item","")==SWIFT_ID
 var battle: String = str(visit.get("run_id",""))+"|"+str(visit.get("room_id",""))+"|battle"
 var active: bool = _swift_bound() and pending and state.phase=="combat" and visit.get("phase",state.phase)=="combat" and str(effect.get("battle_id",""))==battle and str(visit.get("battle_id",""))==battle and str(visit.get("run_id",""))==_run_id and sim.phase=="combat" and not sim.hero.dead and sim.room_id==str(visit.get("room_id","")) and sim.combat_level_id==state.combat_level_id
 return {"supported":_swift_bound(),"item":SWIFT_ID,"pending":pending and str(effect.get("battle_id","" )).is_empty(),"active":active,"effect":effect.duplicate(true),"tuning":_swift_tuning.duplicate(true),"duration_rule":"next_battle_only","equipment_count":46,"elixirs_supported":3}
func equipment_runtime_status(id: String) -> Dictionary:
 if id==SWIFT_ID:
  return {"supported":_swift_bound(),"reason":"" if _swift_bound() else "swift_elixir_consumer_unbound","stats":{},"consumer":"next_battle_swift_elixir"}
 return super.equipment_runtime_status(id)
func swift_elixir_use_status(uid: int) -> Dictionary:
 if not _swift_bound(): return _deny("swift_elixir_consumer_unbound")
 var found: bool = false
 for item: Dictionary in state.inventory:
  if int(item.uid)==uid and str(item.id)==SWIFT_ID: found=true;break
 if not found: return _deny("missing_item")
 var terminal: String = _swift_terminal_reason()
 if not terminal.is_empty(): return _deny(terminal)
 if _swift_sim().hero.dead: return _deny("not_alive")
 if state.phase!="safe": return _deny("elixir_prebattle_only")
 if state.shop_visit.active_elixir.get("item","")==SWIFT_ID: return _deny("same_name_elixir_active")
 return {"accepted":true,"reason":""}
func commerce_quote(item_id: String) -> Dictionary:
 var result: Dictionary = super.commerce_quote(item_id)
 if item_id==SWIFT_ID and result.get("accepted",false) and result.get("auto_drink",false):
  var terminal: String = _swift_terminal_reason()
  if not terminal.is_empty(): return _deny(terminal)
 return result
func _apply_commerce(envelope: Dictionary) -> String:
 var operation: String = str(envelope.get("operation",""))
 var args: Dictionary = envelope.get("arguments",{})
 if operation=="consume":
  for item: Dictionary in state.inventory:
   if int(item.uid)==int(args.get("uid",-1)) and str(item.id)==SWIFT_ID:
    var status: Dictionary = swift_elixir_use_status(int(item.uid))
    if not status.accepted: return str(status.reason)
    break
 if operation in ["buy","craft"] and str(args.get("item",""))==SWIFT_ID and state.inventory.size()>=int(commerce_definitions.slot_limit):
  var terminal: String = _swift_terminal_reason()
  if not terminal.is_empty(): return terminal
 return super._apply_commerce(envelope)
func equipment_effects() -> Dictionary:
 var result: Dictionary = super.equipment_effects()
 var status: Dictionary = swift_elixir_status()
 if status.active:
  _add_stats(result.stats,{"move_speed":_swift_tuning.move/100.0,"attack_speed":_swift_tuning.attack_speed/100.0,"cooldown_reduction":_swift_tuning.cdr/100.0})
 result["swift_elixir"] = status
 return result

func _d01_bound(sim: Node) -> bool:
 if not is_instance_valid(sim) or _health_sim==null or not is_same(_health_sim.get_ref(),sim) or not _e03_bound(sim) or not sim.b02_model_is_bound(self):return false
 if sim.common.get_script().resource_path!="res://elixir_swift_20261010/common_bridge.gd" or sim.hero.actor_id!="yanguizhou" or _d01_original_hero==null or not is_same(_d01_original_hero.get_ref(),sim.hero):return false
 return _d01_base_hp>0.0 and is_finite(_d01_base_hp) and ColossusPassive._number(sim.hero.base_stats.get("max_hp")) and float(sim.hero.base_stats.max_hp)==_d01_base_hp
func _swift_scope(sim: Node)->Dictionary:
 if not _swift_bound() or not is_same(sim,_swift_sim()) or not swift_elixir_status().active:return {}
 var scope: Dictionary=_c03_scope(sim)
 if scope.is_empty():return {}
 scope["battle_id"]=str(state.shop_visit.active_elixir.battle_id)
 return scope
func swift_buff_effect(sim: Node)->Dictionary:
 var scope: Dictionary=_swift_scope(sim)
 var saved: Variant=sim.hero.cast_state.get(SwiftRuntime.BUFF_KEY,{}) if is_instance_valid(sim) else {}
 if scope.is_empty() or not saved is Dictionary:return {"active":false,"move_fraction":0.0}
 return SwiftRuntime.inspect(saved,scope,float(sim.common.runtime.actor_time))
func _swift_claims(scope: Dictionary)->Dictionary:
 var saved: Dictionary=state.get("swift_shift_claims",{})
 if saved.get("scope")==scope and saved.get("casts") is Dictionary:return saved.duplicate(true)
 return {"scope":scope.duplicate(true),"casts":{}}
func record_swift_end(sim: Node,evidence: Dictionary)->Dictionary:
 if not _swift_trusted.is_empty() or not _swift_bound() or not sim.verify_swift_end(self,evidence):return _deny("swift_original_shift_end_required")
 var scope: Dictionary=_swift_scope(sim)
 if scope.is_empty():return _deny("swift_active_battle_required")
 if _swift_claims(scope).casts.has(str(evidence.cast_id)):return _deny("swift_shift_already_claimed")
 var now: float=float(sim.common.runtime.actor_time)
 var previous: Variant=sim.hero.cast_state.get(SwiftRuntime.BUFF_KEY,{})
 if not previous is Dictionary:return _deny("swift_invalid_buff")
 var proposal: Dictionary=SwiftRuntime.propose(scope,now,_swift_tuning.after_shift_duration,_swift_tuning.after_shift_move/100.0)
 if proposal.is_empty():return _deny("swift_invalid_proposal")
 var args: Dictionary={"scope":scope,"evidence":evidence.duplicate(true),"previous":previous.duplicate(true),"now":now,"proposal":proposal}
 var id: String="elixir-swift:"+JSON.stringify([_run_id,state.actor_id,scope.generation,scope.room_id,evidence.cast_id])
 var existed: bool=receipts.has(id)
 _swift_trusted=args.duplicate(true)
 var result: Dictionary=command(id,"swift_original_shift_end",args)
 _swift_trusted={}
 if result.get("accepted",false) and not existed:
  assert(_swift_scope(sim)==scope and sim.verify_swift_end(self,evidence))
  sim.hero.cast_state[SwiftRuntime.BUFF_KEY]=proposal.duplicate(true)
  # Pure Common derived view is safe within the original world transaction.
  sim.common.refresh_stats()
 return result
func _apply(action: String,args: Dictionary)->String:
 if action!="swift_original_shift_end":return super._apply(action,args)
 var sim: Node=_swift_sim()
 if _swift_trusted.is_empty() or args!=_swift_trusted or not _swift_bound() or not sim.verify_swift_end(self,args.evidence):return "swift_original_shift_end_required"
 if _swift_scope(sim)!=args.scope or float(sim.common.runtime.actor_time)!=float(args.now):return "swift_scope_clock_changed"
 var previous: Variant=sim.hero.cast_state.get(SwiftRuntime.BUFF_KEY,{})
 if not previous is Dictionary or previous!=args.previous:return "swift_buff_changed"
 var proposed: Dictionary=SwiftRuntime.propose(args.scope,float(args.now),_swift_tuning.after_shift_duration,_swift_tuning.after_shift_move/100.0)
 if proposed.is_empty() or proposed!=args.proposal:return "swift_proposal_changed"
 var claims: Dictionary=_swift_claims(args.scope)
 if claims.casts.has(str(args.evidence.cast_id)):return "swift_shift_already_claimed"
 claims.casts[str(args.evidence.cast_id)]=args.evidence.dash_serial
 state["swift_shift_claims"]=claims
 return ""
func hunter_elixir_status()->Dictionary:
 var out: Dictionary=super.hunter_elixir_status();out.elixirs_supported=3;return out
func war_elixir_status()->Dictionary:
 var out: Dictionary=super.war_elixir_status();out.elixirs_supported=3;return out
func snapshot()->Dictionary:
 var out: Dictionary=super.snapshot();out["swift_elixir"]=swift_elixir_status()
 out.content_profile="ordinary_equipment46_potions3_formal_training12_elixirs3"
 out.content_warnings=[{"reason":"other26_finals_flasks_other2_elixirs_held"}]
 return out

func bind_health_sim(sim: Node)->Dictionary:
 if not is_instance_valid(sim) or sim.hero.actor_id!="yanguizhou":return _deny("swift_original_hero_required")
 var original: Dictionary=ColossusInkTuning.hero_stats()
 if not ColossusPassive._number(original.get("move_speed")) or float(original.move_speed)<=0.0 or not ColossusPassive._number(sim.hero.base_stats.get("move_speed")) or float(sim.hero.base_stats.move_speed)!=float(original.move_speed):return _deny("swift_original_base_required")
 var result: Dictionary=super.bind_health_sim(sim)
 if result.get("accepted",false):
  _swift_base_ms=float(original.move_speed)
  _swift_original_hero=weakref(sim.hero)
 return result
func swift_projected_move_addition(sim: Node)->float:
 if not _swift_bound() or not is_same(sim,_swift_sim()):return 0.0
 return _swift_base_ms*float(swift_buff_effect(sim).move_fraction)

func swift_c03_move_base(sim: Node)->Dictionary:
 if _swift_scope(sim).is_empty():return {"active":false}
 return {"active":true,"contribution":_swift_base_ms*_swift_tuning.move/100.0}
