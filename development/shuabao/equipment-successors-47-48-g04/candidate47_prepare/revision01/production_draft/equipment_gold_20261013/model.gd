extends "res://equipment_counterattack_20261013/model.gd"
## Prepared only. Requires the exact stable successor Sim/bridge/kernel admission.
## Keep the original wallet, reward command, task kernel, Session and stat pipeline.
const GoldTask = preload("task04.gd")
const GoldRegenUnits = preload("res://tests/ink_equipment_regen_20261008/candidate01/regen_units.gd")
var _g04_original_event: Dictionary={}
var _g04_reward_request: Dictionary={}

func _g04_bound(sim: Node)->bool:
 if not _d06_bound(sim) or _floor_owner==null or _commerce_owner==null or _live_sim==null or _floor_owner.get_ref()==null:return false
 if not is_same(_floor_owner.get_ref(),_commerce_owner.get_ref()) or not is_same(_live_sim.get_ref(),sim) or not _bound(_floor_owner.get_ref(),sim):return false
 if _run_id.is_empty() or state.get("shop_visit",{}).get("run_id")!=_run_id or str(state.actor_id).is_empty() or str(sim.hero.actor_id)!=str(state.hero_id):return false
 if sim.progression==null or sim.progression.model==null or not is_same(sim.progression.model,self):return false
 return not _reward_values.is_empty() and JSON.stringify(_reward_values)==_reward_values_frozen

func equipment_runtime_status(id: String)->Dictionary:
 var out: Dictionary=super.equipment_runtime_status(id)
 if id!=GoldTask.ITEM_ID or not out.get("supported",false):return out
 var sim: Node=_health_sim.get_ref() if _health_sim!=null else null
 if not _g04_bound(sim):return {"supported":false,"reason":"g04_original_session_reward_chain_unbound"}
 out.runtime_complete=true;out.shop_admitted=true;out.runtime_status="original_committed_reward_task_bound"
 var stages: int=int(_g04_state().stages)
 var authored: Dictionary=out.g04_authored_source_stats
 # Evolve source-space item BASE stats, then inherit G21/G27 per-UID and count.
 # Regeneration uses the existing exact source-units/5 mapping after evolution.
 out.stats.move_speed=(float(authored.move_speed_pct)+stages*float(out.taskG04.move_per_stage))/100.0
 out.stats.hp_regen=GoldRegenUnits.per_second(float(authored.health_regen)+stages*float(out.taskG04.regen_per_stage))
 out.stats.cooldown_reduction=(float(authored.cdr_pct)+stages*float(out.taskG04.cdr_per_stage))/100.0
 return out

func _g04_state()->Dictionary:
 var saved: Dictionary=state.get("g04_equipment_progress",{})
 if saved.get("run_id")==_run_id and saved.get("actor_id")==state.actor_id and saved.get("equipment_id")==GoldTask.ITEM_ID:return saved.duplicate(true)
 return {"run_id":_run_id,"actor_id":state.actor_id,"equipment_id":GoldTask.ITEM_ID,"progress":0,"stages":0,"completed":false,"last_reward_id":""}

func observe_live_event(owner: RefCounted, sim: Node, event: Dictionary)->Dictionary:
 # The ordinary original caller remains in charge; no second event emission.
 # With no G04 held, the previous 49-equipment pipeline is exactly inherited.
 if event.get("kind")!="kill" or not GoldTask.select_unique(state.inventory,runtime_stat_definitions).equipped:return super.observe_live_event(owner,sim,event)
 if not _g04_original_event.is_empty() or not _g04_reward_request.is_empty():return _deny("g04_reentrant_reward_observation")
 if not _g04_bound(sim) or not _bound(owner,sim) or not is_same(owner,_commerce_owner.get_ref()):return _deny("g04_wrong_reward_owner")
 if event.get("generation",-1)!=sim.encounter_generation or event.get("room_id","")!=sim.room_id or state.combat_level_id!=sim.combat_level_id:return _deny("g04_wrong_reward_scope")
 var verified: Dictionary=LiveEvents.verify(sim,self,event,_run_id)
 if verified.has("error"):return _deny(str(verified.error))
 var target: Dictionary=sim.enemy_by_id(str(event.get("target","")))
 var numeric: Dictionary=reward_for_kind(str(target.get("kind","")))
 if not numeric.get("accepted",false):return numeric
 var reward_id: String="%s|%s|%s|%s" % [_run_id,sim.combat_level_id,sim.encounter_generation,target.actor_id]
 _g04_original_event=event.duplicate(true)
 _g04_reward_request={"event_id":reward_id,"room":sim.combat_level_id,"gold":numeric.gold,"xp":numeric.xp}
 # Original routine verifies again, performs existing battle tasks, dedupes,
 # opens _reward_open, and invokes the one authoritative reward_minion command.
 var result: Dictionary=super.observe_live_event(owner,sim,event)
 _g04_original_event={};_g04_reward_request={}
 return result

func _apply(action: String,args: Dictionary)->String:
 if action!="reward_minion":return super._apply(action,args)
 var selected: Dictionary=GoldTask.select_unique(state.inventory,runtime_stat_definitions)
 if not selected.equipped:return super._apply(action,args)
 var sim: Node=_health_sim.get_ref() if _health_sim!=null else null
 if not _g04_bound(sim) or not _reward_open or _g04_original_event.is_empty() or _g04_reward_request.is_empty() or args!=_g04_reward_request:return "g04_original_reward_required"
 if _g04_original_event.get("generation",-1)!=sim.encounter_generation or _g04_original_event.get("room_id","")!=sim.room_id or state.combat_level_id!=sim.combat_level_id:return "g04_reward_scope_changed"
 var verified: Dictionary=LiveEvents.verify(sim,self,_g04_original_event,_run_id)
 if verified.has("error"):return str(verified.error)
 var target: Dictionary=sim.enemy_by_id(str(_g04_original_event.target))
 var numeric: Dictionary=reward_for_kind(str(target.get("kind","")))
 var reward_id: String="%s|%s|%s|%s" % [_run_id,sim.combat_level_id,sim.encounter_generation,target.actor_id]
 if not numeric.get("accepted",false) or args!={"event_id":reward_id,"room":sim.combat_level_id,"gold":numeric.gold,"xp":numeric.xp}:return "g04_reward_source_changed"
 # Require one fresh original reward. An old credit cannot be imported later.
 if reward_id in state.reward_ids or state.get("credited_rewards",{}).has(reward_id):return "g04_reward_already_credited"
 var reason: String=super._apply(action,args)
 if not reason.is_empty():return reason
 # The committed receipt belongs to THIS event, not wallet delta or all credits.
 var credit: Variant=state.get("credited_rewards",{}).get(reward_id)
 if not credit is Dictionary or credit!={"room":args.room,"gold":args.gold,"xp":args.xp} or reward_id not in state.reward_ids or not credit.get("gold") is int:return "g04_original_credit_missing"
 var next: Dictionary=_g04_state()
 if next.completed or int(credit.gold)==0:return ""
 var proposal: Dictionary=GoldTask.evaluate(selected,next.progress,next.stages,credit.gold)
 if not proposal.get("eligible",false):return str(proposal.get("reason","g04_progress_rejected"))
 # One progress receipt plus zero to three stage receipts. All use the SAME
 # original task evaluator/commit and the original reward command rollback.
 var facts: Array=[{"equipment_id":GoldTask.ITEM_ID,"event_id":"g04:"+JSON.stringify([_run_id,state.actor_id,reward_id,"progress"]),"progress":proposal.progress_after}]
 for stage: int in proposal.new_stages:
  var stage_id: String="task:G04:"+str(stage)
  facts.append({"equipment_id":GoldTask.ITEM_ID,"event_id":"g04:"+JSON.stringify([_run_id,state.actor_id,reward_id,stage]),"progress":proposal.progress_after,"stage":stage_id,"reward_key":stage_id+":permanent_base_growth"})
 for fact: Dictionary in facts:
  var projected: Dictionary=LedgerProjection.evaluate(state,commerce_definitions,"task_effect",fact,true)
  if not projected.get("accepted",false):return str(projected.get("reason","g04_task_receipt_rejected"))
  reason=LedgerProjection.commit(state,projected.patch,int(commerce_definitions.slot_limit))
  if not reason.is_empty():return reason
 next.progress=proposal.progress_after;next.stages=proposal.stages_after;next.completed=proposal.completed;next.last_reward_id=reward_id
 state["g04_equipment_progress"]=next
 if not proposal.new_stages.is_empty():
  if not state.has("evolved_equipment_tasks"):state.evolved_equipment_tasks={}
  state.evolved_equipment_tasks[GoldTask.ITEM_ID]={"task_id":GoldTask.TASK_ID,"reward_event_id":reward_id,"stages":next.stages,"reward":"permanent_item_base_growth","reward_skill_points":0}
 # Never write points, bonus_sp, bonus_awards, or completed_equipment_tasks.
 return ""

func _apply_commerce(envelope: Dictionary)->String:
 # Even the correct Session owner cannot import G04 facts through generic
 # commerce_authority. Only _apply(reward_minion) above imports its own facts.
 var operation: String=str(envelope.get("operation",""))
 var args: Variant=envelope.get("arguments",{})
 if args is Dictionary:
  if operation=="task_effect" and str(args.get("equipment_id",""))==GoldTask.ITEM_ID:return "g04_original_reward_authority_only"
  if operation=="pay_body" and args.get("task_effects",[]) is Array:
   for fact: Variant in args.get("task_effects",[]):
    if fact is Dictionary and str(fact.get("equipment_id",""))==GoldTask.ITEM_ID:return "g04_original_reward_authority_only"
 return super._apply_commerce(envelope)

func equipment_task_status()->Dictionary:
 var out: Dictionary=super.equipment_task_status()
 var definition: Dictionary=runtime_stat_definitions.get(GoldTask.ITEM_ID,{})
 if not definition.has("taskG04"):return out
 var saved: Dictionary=_g04_state()
 var selected: Dictionary=GoldTask.select_unique(state.inventory,runtime_stat_definitions)
 if not out.has("tasks"):out.tasks={}
 out.tasks[GoldTask.ITEM_ID]={"name":"财源滚滚","progress":saved.progress,"threshold":definition.taskG04.thresholds.back(),"thresholds":definition.taskG04.thresholds.duplicate(),"stages":saved.stages,"maximum_stages":3,"completed":saved.completed,"held":selected.equipped,"frozen":not selected.equipped,"owned_copies":selected.owned_copies,"reward_skill_points":0,"retained_when_sold":true,"retained_across_rooms":true,"once_per_run":true,"gold_source_policy":"original_committed_gameplay_reward_only","exclude_sale_and_undo":true}
 return out

func snapshot()->Dictionary:
 var out: Dictionary=super.snapshot()
 out["g04_equipment"]=_g04_state()
 out.content_profile="ordinary_equipment50_potions3_formal_training12_elixirs3"
 out.content_warnings=[{"reason":"other22_finals_flasks_other2_elixirs_held"}]
 return out
func swift_elixir_status()->Dictionary:
 var out: Dictionary=super.swift_elixir_status();out.equipment_count=50;return out
func hunter_elixir_status()->Dictionary:
 var out: Dictionary=super.hunter_elixir_status();out.equipment_count=50;return out
func war_elixir_status()->Dictionary:
 var out: Dictionary=super.war_elixir_status();out.equipment_count=50;return out
