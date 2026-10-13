extends "res://equipment_kill_20261009/model.gd"
## Authenticated, already committed HP loss. The original commerce command owns
## rollback, idempotency and task lineage; this layer never recalculates damage.
const ElitePassive = preload("res://equipment_elite_damage_20261009/passive18.gd")
var _g06_trusted: Dictionary = {}

func equipment_runtime_status(id: String) -> Dictionary:
 var out: Dictionary = super.equipment_runtime_status(id)
 if id != "final:G06" or not out.get("supported",false): return out
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 if not is_instance_valid(sim) or not sim.has_method("verify_g06_damage_attribution"):
  return {"supported":false,"reason":"g06_actual_damage_bridge_not_bound"}
 out.runtime_complete=true;out.runtime_status="source_actual_elite_damage_task_bound"
 return out

func passive18_multiplier(enemy: Dictionary, _event: Dictionary) -> float:
 var selected: Dictionary = ElitePassive.select_unique(state.inventory,runtime_stat_definitions,bool(_g06_state().completed))
 return ElitePassive.factor(enemy,selected.tuning)

func record_battle_event(sim: Node, event: Dictionary, run_id: String) -> Dictionary:
 var prior: Dictionary = super.record_battle_event(sim,event,run_id)
 if not prior.get("accepted",false) or str(event.get("kind",""))!="damage": return prior
 if _health_sim==null or not is_instance_valid(_health_sim.get_ref()) or not is_same(_health_sim.get_ref(),sim) or run_id!=_run_id or not _g06_trusted.is_empty(): return prior
 if not equipment_runtime_status("final:G06").get("supported",false) or not _g06_held(): return prior
 var progress: Dictionary = _g06_state()
 if bool(progress.completed): return prior
 var verified: Dictionary = BattleEvents.verify(sim,self,event,run_id)
 if verified.has("error"): return _deny(str(verified.error))
 var attribution: Dictionary = sim.verify_g06_damage_attribution(event)
 if attribution.is_empty(): return prior
 var scope: String = "%d:%s" % [sim.encounter_generation,sim.room_id]
 var sequence: int = int(event.sequence)
 # Outward callbacks may deliver nested sequence N+1 before the outer N reaches
 # this observer. The original command/event receipt deduplicates exact IDs;
 # a maximum sequence is diagnostic only, never proof that N was consumed.
 var p1_claim: String = str(attribution.get("p1_receipt_key",""))
 if not p1_claim.is_empty() and str(progress.cursor_scope)==scope and progress.p1_claims.has(p1_claim): return prior
 var request: Dictionary = {"run_id":run_id,"scope":scope,"room_id":sim.room_id,"sequence":sequence,"event_key":verified.fact.event_key,"amount":attribution.amount,"attribution":attribution}
 _g06_trusted=request.duplicate(true)
 var result: Dictionary = command("equipment-g06:"+str(verified.fact.event_key),"g06_verified_damage",request)
 _g06_trusted={}
 if result.get("accepted",false): result["g06_task"]=_g06_state()
 return result

func _apply(action: String, args: Dictionary) -> String:
 if action!="g06_verified_damage": return super._apply(action,args)
 if _g06_trusted.is_empty() or args!=_g06_trusted: return "g06_verified_live_damage_required"
 if state.phase!="combat" or state.get("actor_dead",false) or str(args.run_id)!=_run_id or str(args.room_id)!=state.combat_level_id: return "g06_live_scope_required"
 if not _g06_held(): return "g06_not_equipped"
 var next: Dictionary = _g06_state()
 if bool(next.completed): return "g06_already_complete"
 if str(next.cursor_scope)!=str(args.scope): next.p1_claims={}
 var p1_claim: String = str(args.attribution.get("p1_receipt_key",""))
 if not p1_claim.is_empty():
  if next.p1_claims.has(p1_claim): return "g06_p1_receipt_already_recorded"
  next.p1_claims[p1_claim]=true
 var amount: float = float(args.amount)
 if not is_finite(amount) or amount<=0.0: return "g06_invalid_actual_damage"
 var task: Dictionary = runtime_stat_definitions["final:G06"].taskG06
 # Keep fractional HP loss between packets. Integer commerce progress is merely
 # a monotonic receipt; threshold adjudication never rounds individual hits.
 next.progress=minf(float(task.threshold),float(next.progress)+amount)
 next.completed=float(next.progress)>=float(task.threshold)
 next.cursor_sequence=maxi(int(next.cursor_sequence),int(args.sequence)) if str(next.cursor_scope)==str(args.scope) else int(args.sequence)
 next.cursor_scope=str(args.scope)
 var fact: Dictionary = {"equipment_id":"final:G06","event_id":"g06:"+str(args.event_key),"progress":int(floor(float(next.progress)))}
 if next.completed:
  fact.stage=str(task.stage_id);fact.reward_key="task:G06:permanent_evolution"
 var projected: Dictionary = LedgerProjection.evaluate(state,commerce_definitions,"task_effect",fact,true)
 if not projected.get("accepted",false): return str(projected.get("reason","g06_task_receipt_rejected"))
 var reason: String = LedgerProjection.commit(state,projected.patch,int(commerce_definitions.slot_limit))
 if not reason.is_empty(): return reason
 state["g06_equipment_progress"]=next
 if next.completed:
  # The ancestor's completed_equipment_tasks feeds G17's SP-task counter.
  # This evolution awards no SP and must not enter that distinct counter.
  if not state.has("evolved_equipment_tasks"): state.evolved_equipment_tasks={}
  state.evolved_equipment_tasks["final:G06"]={"task_id":"task:G06","event_id":str(args.event_key),"reward":"permanent_passive18_evolution","reward_skill_points":0}
 _commerce_result=projected.duplicate(true);_commerce_result.erase("patch")
 return ""

func _g06_held() -> bool:
 for item: Dictionary in state.inventory:
  if item.get("id","")=="final:G06" and int(item.get("count",0))>0: return true
 return false
func _g06_state() -> Dictionary:
 return state.get("g06_equipment_progress",{"progress":0.0,"completed":false,"cursor_scope":"","cursor_sequence":-1,"p1_claims":{}}).duplicate(true)
func equipment_task_status() -> Dictionary:
 var out: Dictionary = super.equipment_task_status()
 var definition: Dictionary = runtime_stat_definitions.get("final:G06",{})
 if not definition.has("taskG06"): return out
 var progress: Dictionary = _g06_state()
 if not out.has("tasks"): out.tasks={}
 out.tasks["final:G06"]={"name":"王血试炼","progress":float(progress.progress),"threshold":float(definition.taskG06.threshold),"completed":bool(progress.completed),"reward_skill_points":0,"retained_when_sold":true,"once_per_run":true,"evolved_base_bonus":definition.taskG06.evolved_base_bonus,"evolved_bonus_cap":definition.taskG06.evolved_bonus_cap}
 return out
func snapshot() -> Dictionary:
 var out: Dictionary = super.snapshot()
 out.content_profile="ordinary_equipment37_potions3"
 out.content_warnings=[{"reason":"other35_finals_flasks_elixirs_held"}]
 out["g06_equipment"]=_g06_state()
 out["passive18_equipment"]=ElitePassive.select_unique(state.inventory,runtime_stat_definitions,bool(_g06_state().completed))
 return out
