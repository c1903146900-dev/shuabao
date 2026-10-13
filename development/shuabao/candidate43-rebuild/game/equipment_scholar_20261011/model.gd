extends "res://elixir_swift_20261010/model.gd"
## Draft successor: stays unadmitted until the exact original effect bridge binds.
const Scholar = preload("task01.gd")
var _g01_trusted: Dictionary={}
func _g01_bound(sim: Node)->bool:
 return is_instance_valid(sim) and _health_sim!=null and is_same(_health_sim.get_ref(),sim) and _d01_bound(sim) and sim.has_method("g01_model_is_bound") and sim.has_method("verify_g01_effect") and sim.g01_model_is_bound(self)
func equipment_runtime_status(id: String)->Dictionary:
 var out: Dictionary=super.equipment_runtime_status(id)
 if id!=Scholar.ITEM_ID or not out.get("supported",false):return out
 var sim: Node=_health_sim.get_ref() if _health_sim!=null else null
 if not _g01_bound(sim):return {"supported":false,"reason":"g01_original_effect_bridge_unbound"}
 out.runtime_complete=true;out.shop_admitted=true;out.runtime_status="original_first_effect_task_bound"
 out["g01_authored_base_stats"]=out.stats.duplicate(true)
 if _g01_state().completed:
  # Evolve the item's authored base before the original per-UID G21/G27
  # multipliers and count aggregation. Do not add an unscaled final delta.
  out.stats.AP=float(out.taskG01.evolved_ap)
  out.stats.cooldown_reduction=float(out.taskG01.evolved_cdr)/100.0
 return out
func _g01_scope(sim: Node)->Dictionary:
 if not _g01_bound(sim) or sim.phase!="combat" or sim.paused or sim.hero.dead or state.phase!="combat" or state.get("actor_dead",false) or state.get("test_mode",false) or state.combat_level_id!=sim.combat_level_id:return {}
 return {"run_id":_run_id,"actor_id":str(state.actor_id),"generation":sim.encounter_generation,"room_id":sim.room_id}
func _g01_state()->Dictionary:
 var saved: Dictionary=state.get("g01_equipment_progress",{})
 if saved.get("run_id")==_run_id and saved.get("actor_id")==state.actor_id and saved.get("equipment_id")==Scholar.ITEM_ID:return saved.duplicate(true)
 return {"run_id":_run_id,"actor_id":state.actor_id,"equipment_id":Scholar.ITEM_ID,"progress":0,"completed":false,"claim_scope":{},"casts":{}}
func _g01_claims(progress: Dictionary, scope: Dictionary)->Dictionary:
 return {"scope":scope.duplicate(true),"casts":progress.casts.duplicate(true) if progress.claim_scope==scope else {}}
func record_g01_effect(sim: Node,evidence: Dictionary)->Dictionary:
 if not _g01_trusted.is_empty() or not _g01_bound(sim) or not sim.verify_g01_effect(self,evidence):return _deny("g01_original_effect_required")
 var scope: Dictionary=_g01_scope(sim)
 var previous: Dictionary=_g01_state()
 var selected: Dictionary=Scholar.select_unique(state.inventory,runtime_stat_definitions)
 var proposal: Dictionary=Scholar.evaluate(selected,previous.progress,previous.completed,_g01_claims(previous,scope),scope,evidence)
 if not proposal.get("eligible",false):return _deny(str(proposal.get("reason","g01_ineligible")))
 var request: Dictionary={"scope":scope,"evidence":evidence.duplicate(true),"previous":previous,"proposal":proposal}
 var id: String="equipment-g01:"+JSON.stringify([_run_id,state.actor_id,scope.generation,scope.room_id,evidence.cast_id])
 _g01_trusted=request.duplicate(true)
 var result: Dictionary=command(id,"g01_verified_effect",request)
 _g01_trusted={}
 result["g01_completed_now"]=result.get("accepted",false) and not result.get("replayed",false) and bool(proposal.completed)
 return result
func _apply(action: String,args: Dictionary)->String:
 if action!="g01_verified_effect":return super._apply(action,args)
 var sim: Node=_health_sim.get_ref() if _health_sim!=null else null
 if _g01_trusted.is_empty() or args!=_g01_trusted or not _g01_bound(sim) or not sim.verify_g01_effect(self,args.evidence):return "g01_original_effect_required"
 if _g01_scope(sim)!=args.scope or _g01_state()!=args.previous:return "g01_state_changed"
 var selected: Dictionary=Scholar.select_unique(state.inventory,runtime_stat_definitions)
 var next: Dictionary=_g01_state()
 var claims: Dictionary=_g01_claims(next,args.scope)
 var proposal: Dictionary=Scholar.evaluate(selected,next.progress,next.completed,claims,args.scope,args.evidence)
 if not proposal.get("eligible",false) or proposal!=args.proposal:return "g01_proposal_changed"
 var event_id: String="g01:"+JSON.stringify([_run_id,state.actor_id,args.scope.generation,args.scope.room_id,args.evidence.cast_id])
 var fact: Dictionary={"equipment_id":Scholar.ITEM_ID,"event_id":event_id,"progress":proposal.progress_after}
 if proposal.completed:fact.stage=proposal.stage_id;fact.reward_key=proposal.reward_key
 var projected: Dictionary=LedgerProjection.evaluate(state,commerce_definitions,"task_effect",fact,true)
 if not projected.get("accepted",false):return str(projected.get("reason","g01_task_receipt_rejected"))
 var reason: String=LedgerProjection.commit(state,projected.patch,int(commerce_definitions.slot_limit))
 if not reason.is_empty():return reason
 next.progress=proposal.progress_after;next.completed=proposal.completed
 next.claim_scope=args.scope.duplicate(true);next.casts=claims.casts.duplicate(true);next.casts[proposal.cast_key]=true
 state["g01_equipment_progress"]=next
 if next.completed:
  # G17 counts SP tasks, not this zero-SP evolution. Do not touch points,
  # bonus_sp, completed_equipment_tasks or bonus_awards.
  if not state.has("evolved_equipment_tasks"):state.evolved_equipment_tasks={}
  state.evolved_equipment_tasks[Scholar.ITEM_ID]={"task_id":Scholar.TASK_ID,"event_id":event_id,"reward":"permanent_stat_evolution","reward_skill_points":0}
 _commerce_result=projected.duplicate(true);_commerce_result.erase("patch")
 return ""
func equipment_task_status()->Dictionary:
 var out: Dictionary=super.equipment_task_status()
 var definition: Dictionary=runtime_stat_definitions.get(Scholar.ITEM_ID,{})
 if not definition.has("taskG01"):return out
 var progress: Dictionary=_g01_state()
 if not out.has("tasks"):out.tasks={}
 out.tasks[Scholar.ITEM_ID]={"name":"无尽书写","progress":progress.progress,"threshold":definition.taskG01.threshold,"completed":progress.completed,"reward_skill_points":0,"retained_when_sold":true,"once_per_run":true,"evolved_AP":definition.taskG01.evolved_ap,"evolved_CDR":definition.taskG01.evolved_cdr}
 return out
func snapshot()->Dictionary:
 var out: Dictionary=super.snapshot();out["g01_equipment"]=_g01_state()
 out.content_profile="ordinary_equipment47_potions3_formal_training12_elixirs3"
 out.content_warnings=[{"reason":"other25_finals_flasks_other2_elixirs_held"}]
 return out
func swift_elixir_status()->Dictionary:
 var out: Dictionary=super.swift_elixir_status();out.equipment_count=47;return out
