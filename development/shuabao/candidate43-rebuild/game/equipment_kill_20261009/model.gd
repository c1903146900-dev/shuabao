extends "res://equipment_distance_20261009/model.gd"
## One existing ledger and source Sim. New task/refund only consumes authenticated
## original Q/E kills; no UI command may manufacture task or cooldown entitlement.
const KillPassive = preload("res://equipment_kill_20261009/passive13.gd")
var _b01_trusted: Dictionary = {}

func equipment_runtime_status(id: String) -> Dictionary:
 var out: Dictionary = super.equipment_runtime_status(id)
 if id != "final:B01" or not out.get("supported",false): return out
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 if not is_instance_valid(sim) or not sim.has_method("verify_b01_kill_attribution"):
  return {"supported":false,"reason":"b01_actual_source_bridge_not_bound"}
 out.runtime_complete=true;out.runtime_status="source_kill_refund_and_task_bound"
 return out

func record_battle_event(sim: Node, event: Dictionary, run_id: String) -> Dictionary:
 var prior: Dictionary = super.record_battle_event(sim,event,run_id)
 if not prior.get("accepted",false) or str(event.get("kind",""))!="kill": return prior
 if _health_sim == null or not is_instance_valid(_health_sim.get_ref()) or not is_same(_health_sim.get_ref(),sim) or run_id!=_run_id or not _b01_trusted.is_empty(): return prior
 var verified: Dictionary = BattleEvents.verify(sim,self,event,run_id)
 if verified.has("error"): return _deny(str(verified.error))
 if not equipment_runtime_status("final:B01").get("supported",false): return prior
 var selection: Dictionary = KillPassive.select_unique(state.inventory,runtime_stat_definitions)
 if not selection.equipped: return prior
 var attribution: Dictionary = sim.verify_b01_kill_attribution(event)
 if attribution.is_empty(): return prior
 var scope: Dictionary = {"generation":sim.encounter_generation,"room_id":sim.room_id}
 var slot: String = str(sim._casts[int(attribution.cast_id)].slot)
 var progress: Dictionary = _b01_state()
 var claims: Dictionary = progress.refund_claims if str(progress.refund_scope)==_b01_scope(scope) else {}
 var proposal: Dictionary = KillPassive.evaluate_verified_kill(selection,attribution,sim._casts,scope,sim.hero.cooldowns.get(slot,0.0),claims)
 var target_key: String = "%s|%s|%s" % [run_id,_b01_scope(scope),str(attribution.target)]
 var task_new: bool = not bool(progress.completed) and not progress.targets.has(target_key)
 if not proposal.eligible and not task_new: return prior
 var request: Dictionary = {"run_id":run_id,"scope":scope,"target_key":target_key,"attribution":attribution,"proposal":proposal,"task_new":task_new}
 var command_id: String = "equipment-b01:"+str(verified.fact.event_key)
 _b01_trusted=request.duplicate(true)
 var result: Dictionary = command(command_id,"b01_verified_kill",request)
 _b01_trusted={}
 # Model.command is synchronous and has no callback that steps the Sim. The
 # original packet/kill stack still owns this exact scope and current CD.
 if result.get("accepted",false) and not result.get("replayed",false) and proposal.eligible:
  assert(sim.cast_is_current(int(attribution.cast_id)) and sim.room_id==scope.room_id and sim.encounter_generation==scope.generation)
  assert(is_equal_approx(float(sim.hero.cooldowns[slot]),float(proposal.cooldown_before)))
  sim.hero.cooldowns[slot]=float(proposal.cooldown_after)
  sim.emit_event("equipment_b01_refund",{"cast_id":attribution.cast_id,"source":attribution.source,"parent_skill":attribution.parent_skill,"slot":slot,"cooldown_before":proposal.cooldown_before,"cooldown_after":proposal.cooldown_after,"refund":proposal.refund,"claim_key":proposal.claim_key})
 if result.get("accepted",false):
  result["b01_task"]=_b01_state().duplicate(true)
  result["b01_refund"]=proposal.duplicate(true)
 return result

func _apply(action: String, args: Dictionary) -> String:
 if action!="b01_verified_kill": return super._apply(action,args)
 if _b01_trusted.is_empty() or args!=_b01_trusted: return "b01_verified_live_kill_required"
 if state.phase!="combat" or state.get("actor_dead",false) or str(args.run_id)!=_run_id or str(args.scope.room_id)!=state.combat_level_id: return "b01_live_scope_required"
 var selected: Dictionary = KillPassive.select_unique(state.inventory,runtime_stat_definitions)
 if not selected.equipped: return "b01_not_equipped"
 var task: Dictionary = runtime_stat_definitions["final:B01"].taskB01
 var before: Dictionary = _b01_state()
 var next: Dictionary = before.duplicate(true)
 var projected: Dictionary = {}
 if bool(args.task_new):
  if next.completed or next.targets.has(args.target_key): return "b01_task_duplicate"
  next.progress=mini(int(task.threshold),int(next.progress)+1)
  next.targets[args.target_key]=true
  var complete: bool = int(next.progress)>=int(task.threshold)
  var fact: Dictionary = {"equipment_id":"final:B01","event_id":"b01:"+str(args.target_key),"progress":int(next.progress)}
  if complete:
   fact.stage=str(task.stage_id);fact.reward_key="task:B01:permanent_sp"
  projected=LedgerProjection.evaluate(state,commerce_definitions,"task_effect",fact,true)
  if not projected.get("accepted",false): return str(projected.get("reason","b01_task_receipt_rejected"))
  var reason: String = LedgerProjection.commit(state,projected.patch,int(commerce_definitions.slot_limit))
  if not reason.is_empty(): return reason
  if complete:
   next.completed=true;next.targets.clear()
   state.points+=int(task.reward_skill_points)
   state.bonus_sp=int(state.get("bonus_sp",0))+int(task.reward_skill_points)
   state.completed_equipment_tasks["final:B01"]={"task_id":"task:B01","event_id":str(args.target_key)}
   state.bonus_awards["task:B01"]={"amount":int(task.reward_skill_points),"source":"authored_equipment_task","definition_version":config.version}
 if bool(args.proposal.eligible):
  var scope_key: String = _b01_scope(args.scope)
  if str(next.refund_scope)!=scope_key: next.refund_scope=scope_key;next.refund_claims={}
  if next.refund_claims.has(args.proposal.claim_key): return "b01_cast_already_refunded"
  next.refund_claims[args.proposal.claim_key]=true
 state["b01_equipment_progress"]=next
 if not projected.is_empty():
  _commerce_result=projected.duplicate(true);_commerce_result.erase("patch")
 return ""

func _b01_state() -> Dictionary:
 return state.get("b01_equipment_progress",{"progress":0,"completed":false,"targets":{},"refund_scope":"","refund_claims":{}}).duplicate(true)
func _b01_scope(scope: Dictionary) -> String:
 return "%d:%s" % [int(scope.generation),str(scope.room_id)]
func equipment_task_status() -> Dictionary:
 var out: Dictionary = super.equipment_task_status()
 var progress: Dictionary = _b01_state()
 var definition: Dictionary = runtime_stat_definitions.get("final:B01",{})
 if not definition.has("taskB01"): return out
 out.status="source_bound_equipment_tasks"
 out["tasks"]={"final:B01":{"name":"断界试炼","progress":int(progress.progress),"threshold":int(definition.taskB01.threshold),"completed":bool(progress.completed),"reward_skill_points":int(definition.taskB01.reward_skill_points),"retained_when_sold":true,"once_per_run":true}}
 return out
func snapshot() -> Dictionary:
 var out: Dictionary = super.snapshot()
 out.content_profile="ordinary_equipment36_potions3"
 out.content_warnings=[{"reason":"other36_finals_flasks_elixirs_held"}]
 out["b01_equipment"]=_b01_state()
 return out
