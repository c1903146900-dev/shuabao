extends "res://elixir_hunter_20261009/model.gd"
## One next-battle elixir. Original commerce owns storage, consumption and lifetime.
const WAR_ID := "elixir:01"
const WarRuntime = preload("runtime.gd")
var _war_tuning: Dictionary = {}
var _war_trusted: Dictionary = {}
var _war_original_event: Dictionary = {}
func bind_war_elixir(numeric: Dictionary) -> Dictionary:
 if not _war_tuning.is_empty() or state.revision != 0: return _deny("fresh_elixir_binding_required")
 var parameters: Dictionary = numeric.get("parameters",{})
 var fields: Dictionary = {"price":"gold","ad":"attack_points","lifesteal":"percent_points","on_kill_as":"percent_points","on_kill_duration":"seconds"}
 var next: Dictionary = {}
 for key: String in fields:
  var row: Dictionary = parameters.get(WAR_ID+"."+key,{})
  var value: Variant = row.get("value")
  if not (value is int or value is float) or not is_finite(float(value)) or float(value)<0.0 or row.get("unit","")!=fields[key]: return _deny("war_elixir_numeric_mismatch:"+key)
  next[key] = float(value)
 if next.on_kill_duration <= 0.0 or next.on_kill_as > 100.0 or next.lifesteal > 100.0: return _deny("war_elixir_invalid_effect")
 if floor(next.price)!=next.price: return _deny("war_elixir_integer_price_required")
 var item: Dictionary = commerce_definitions.get("items",{}).get(WAR_ID,{})
 if item.get("kind","")!="elixir" or float(item.get("price",-1))!=next.price: return _deny("war_elixir_definition_mismatch")
 _war_tuning = next
 return {"accepted":true,"reason":""}
func _war_sim() -> Node:
 return _health_sim.get_ref() if _health_sim != null else null
func _war_bound() -> bool:
 return not _war_tuning.is_empty() and _e03_bound(_war_sim()) and _b02_bound(_war_sim())
func _war_terminal_reason() -> String:
 var owner: RefCounted = _commerce_owner.get_ref() if _commerce_owner != null else null
 if owner==null: return "wrong_commerce_authority"
 if str(owner.get("status")) in ["completed","aborted","defeated","faulted","unbound"]: return "elixir_run_finished"
 return ""
func war_elixir_status() -> Dictionary:
 var visit: Dictionary = state.get("shop_visit",{})
 var effect: Dictionary = visit.get("active_elixir",{})
 var sim: Node = _war_sim()
 var pending: bool = effect.get("item","")==WAR_ID
 var battle: String = str(visit.get("run_id",""))+"|"+str(visit.get("room_id",""))+"|battle"
 var active: bool = _war_bound() and pending and state.phase=="combat" and visit.get("phase",state.phase)=="combat" and str(effect.get("battle_id",""))==battle and str(visit.get("battle_id",""))==battle and str(visit.get("run_id",""))==_run_id and sim.phase=="combat" and not sim.hero.dead and sim.room_id==str(visit.get("room_id","")) and sim.combat_level_id==state.combat_level_id
 return {"supported":_war_bound(),"item":WAR_ID,"pending":pending and str(effect.get("battle_id","" )).is_empty(),"active":active,"effect":effect.duplicate(true),"tuning":_war_tuning.duplicate(true),"duration_rule":"next_battle_only","equipment_count":43,"elixirs_supported":2}
func equipment_runtime_status(id: String) -> Dictionary:
 if id==WAR_ID:
  return {"supported":_war_bound(),"reason":"" if _war_bound() else "war_elixir_consumer_unbound","stats":{},"consumer":"next_battle_war_elixir"}
 return super.equipment_runtime_status(id)
func war_elixir_use_status(uid: int) -> Dictionary:
 if not _war_bound(): return _deny("war_elixir_consumer_unbound")
 var found: bool = false
 for item: Dictionary in state.inventory:
  if int(item.uid)==uid and str(item.id)==WAR_ID: found=true;break
 if not found: return _deny("missing_item")
 var terminal: String = _war_terminal_reason()
 if not terminal.is_empty(): return _deny(terminal)
 if _war_sim().hero.dead: return _deny("not_alive")
 if state.phase!="safe": return _deny("elixir_prebattle_only")
 if state.shop_visit.active_elixir.get("item","")==WAR_ID: return _deny("same_name_elixir_active")
 return {"accepted":true,"reason":""}
func commerce_quote(item_id: String) -> Dictionary:
 var result: Dictionary = super.commerce_quote(item_id)
 if item_id==WAR_ID and result.get("accepted",false) and result.get("auto_drink",false):
  var terminal: String = _war_terminal_reason()
  if not terminal.is_empty(): return _deny(terminal)
 return result
func _apply_commerce(envelope: Dictionary) -> String:
 var operation: String = str(envelope.get("operation",""))
 var args: Dictionary = envelope.get("arguments",{})
 if operation=="consume":
  for item: Dictionary in state.inventory:
   if int(item.uid)==int(args.get("uid",-1)) and str(item.id)==WAR_ID:
    var status: Dictionary = war_elixir_use_status(int(item.uid))
    if not status.accepted: return str(status.reason)
    break
 if operation in ["buy","craft"] and str(args.get("item",""))==WAR_ID and state.inventory.size()>=int(commerce_definitions.slot_limit):
  var terminal: String = _war_terminal_reason()
  if not terminal.is_empty(): return terminal
 return super._apply_commerce(envelope)
func equipment_effects() -> Dictionary:
 var result: Dictionary = super.equipment_effects()
 var status: Dictionary = war_elixir_status()
 if status.active:
  _add_stats(result.stats,{"AD":_war_tuning.ad,"lifesteal":_war_tuning.lifesteal/100.0})
 result["war_elixir"] = status
 return result
func record_battle_event(sim: Node, event: Dictionary, run_id: String) -> Dictionary:
 # All original progression, B01, G06, B04 and G02 processing stays first.
 var prior: Dictionary = super.record_battle_event(sim,event,run_id)
 if not prior.get("accepted",false) or event.get("kind") != "kill" or run_id != _run_id or not _war_bound() or not _war_trusted.is_empty(): return prior
 var selected: Dictionary = _war_selection()
 if not selected.equipped: return prior
 var evidence: Dictionary = sim.verify_g02_kill_attribution(self,event,run_id)
 if evidence.is_empty(): return prior
 var context: Dictionary = _war_context(sim)
 if context.is_empty(): return prior
 var previous: Variant = sim.hero.cast_state.get(WarRuntime.BUFF_KEY,{})
 if not previous is Dictionary: return prior
 var proposal: Dictionary = WarRuntime.propose(selected,previous,_war_claims(context.scope),context,evidence)
 if not proposal.get("eligible",false): return prior
 var request: Dictionary = {"run_id":run_id,"context":context,"evidence":evidence,"proposal":proposal}
 var command_id: String = "elixir-war:" + JSON.stringify([run_id,state.actor_id,context.scope.generation,context.scope.room_id,proposal.claim_to_add.target_id])
 _war_trusted = request.duplicate(true)
 _war_original_event = event
 var result: Dictionary = command(command_id,"war_verified_death_buff",request)
 # Original non-commerce command path has no outward callbacks. Claim/receipt
 # commit and real buff publication happen synchronously before any observer.
 if result.get("accepted",false) and not result.get("replayed",false):
  assert(_war_bound() and _war_context(sim) == context)
  assert(sim.hero.cast_state.get(WarRuntime.BUFF_KEY,{}) == proposal.prior_buff)
  sim.hero.cast_state[WarRuntime.BUFF_KEY] = proposal.buff.duplicate(true)
  # Valid also inside the original synchronous birth transaction. This bridge
  # only projects stats; do not call the transaction-guarded stat consumer.
  sim.common.refresh_stats()
  result["war_buff"] = proposal.buff.duplicate(true)
  if receipts.has(command_id): receipts[command_id].result = result.duplicate(true)
 _war_original_event = {};_war_trusted = {}
 if not result.get("accepted",false): return result
 var out: Dictionary = prior.duplicate(true)
 out.merge(result,true)
 out.events = prior.get("events",[]).duplicate(true) + result.get("events",[]).duplicate(true)
 out["war_pursuit"] = war_elixir_status()
 return out

func _apply(action: String, args: Dictionary) -> String:
 if action != "war_verified_death_buff": return super._apply(action,args)
 if _war_trusted.is_empty() or args != _war_trusted or _war_original_event.is_empty(): return "war_original_death_required"
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 if not _war_bound() or args.run_id != _run_id or state.phase != "combat" or state.get("actor_dead",false) or state.get("test_mode",false): return "war_live_original_owner_required"
 if sim.phase != "combat" or sim.hero.dead or state.combat_level_id != sim.combat_level_id or args.context != _war_context(sim): return "war_original_scope_clock_changed"
 var verified: Dictionary = BattleEvents.verify(sim,self,_war_original_event,_run_id)
 if verified.has("error"): return str(verified.error)
 var evidence: Dictionary = sim.verify_g02_kill_attribution(self,_war_original_event,_run_id)
 if evidence.is_empty() or evidence != args.evidence: return "war_original_death_witness_changed"
 var previous: Variant = sim.hero.cast_state.get(WarRuntime.BUFF_KEY,{})
 if not previous is Dictionary: return "war_invalid_actual_buff"
 var selected: Dictionary = _war_selection()
 var claims: Dictionary = _war_claims(args.context.scope)
 var proposal: Dictionary = WarRuntime.propose(selected,previous,claims,args.context,evidence)
 if not proposal.get("eligible",false) or proposal != args.proposal: return "war_buff_proposal_changed"
 claims.by_target[proposal.claim_to_add.target_id] = proposal.claim_to_add.death_commit_id
 state["war_death_claims"] = claims
 return ""

func _war_claims(scope: Dictionary) -> Dictionary:
 var saved: Dictionary = state.get("war_death_claims",{})
 if saved.get("scope") == scope and saved.get("by_target") is Dictionary: return saved.duplicate(true)
 return {"scope":scope.duplicate(true),"by_target":{}}

func _war_selection() -> Dictionary:
 return {"equipped":bool(war_elixir_status().active),"owned_copies":1,"item_id":WarRuntime.ITEM_ID,"passive_id":WarRuntime.PASSIVE_ID,"tuning":{"move_bonus":0.0,"attack_speed_bonus":float(_war_tuning.get("on_kill_as",0.0)),"duration":float(_war_tuning.get("on_kill_duration",0.0))}}
func _war_context(sim: Node) -> Dictionary:
 if not _war_bound() or not war_elixir_status().active: return {}
 var context: Dictionary = _b02_context(sim)
 if context.is_empty(): return {}
 context["battle_id"] = str(state.shop_visit.active_elixir.get("battle_id",""))
 return context
func war_buff_effect(sim: Node) -> Dictionary:
 if not _war_bound() or not war_elixir_status().active: return {"active":false,"attack_speed_fraction":0.0}
 var saved: Variant = sim.hero.cast_state.get(WarRuntime.BUFF_KEY,{})
 if not saved is Dictionary: return {"active":false,"attack_speed_fraction":0.0}
 return WarRuntime.inspect(saved,_war_context(sim))
func snapshot() -> Dictionary:
 var result: Dictionary = super.snapshot()
 result["war_elixir"] = war_elixir_status()
 result.content_warnings = [{"reason":"other29_finals_flasks_other3_elixirs_held"}]
 return result
