extends "res://equipment_basic_cycle_20261009/model.gd"
## G02 is a player/equipment-name task in the existing run ledger. It adds no
## damage, cooldown, health, timer, wallet, or multiplayer participation rules.
const TrainingTask = preload("task02.gd")
var _g02_trusted: Dictionary = {}
var _g02_original_event: Dictionary = {}

func equipment_runtime_status(id: String) -> Dictionary:
 var out: Dictionary = super.equipment_runtime_status(id)
 if id != TrainingTask.ITEM_ID or not out.get("supported",false): return out
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 if not is_instance_valid(sim) or not sim.has_method("g02_model_is_bound") or not sim.has_method("verify_g02_kill_attribution") or not sim.g02_model_is_bound(self):
  return {"supported":false,"reason":"g02_original_death_bridge_not_bound"}
 out.runtime_complete = true;out.shop_admitted = true
 out.runtime_status = "source_solo_death_task_bound"
 return out

func _g02_bound(sim: Node, run_id: String) -> bool:
 if not is_instance_valid(sim) or _health_sim == null or _live_sim == null or _floor_owner == null or _floor_owner.get_ref() == null: return false
 if not is_same(_health_sim.get_ref(),sim) or not is_same(_live_sim.get_ref(),sim) or run_id.is_empty() or run_id != _run_id: return false
 if not state.has("shop_visit") or str(state.shop_visit.run_id) != run_id or str(sim.hero.actor_id) != str(state.hero_id): return false
 return sim.has_method("g02_model_is_bound") and sim.g02_model_is_bound(self)

func record_battle_event(sim: Node, event: Dictionary, run_id: String) -> Dictionary:
 # Keep the original B01/G06/B04/progression/reward caller order intact.
 var prior: Dictionary = super.record_battle_event(sim,event,run_id)
 if not prior.get("accepted",false) or event.get("kind") != "kill": return prior
 if not _g02_bound(sim,run_id) or not _g02_trusted.is_empty() or not equipment_runtime_status(TrainingTask.ITEM_ID).get("supported",false): return prior
 var selected: Dictionary = TrainingTask.select_unique(state.inventory,runtime_stat_definitions)
 var progress: Dictionary = _g02_state()
 if not selected.equipped or progress.completed: return prior
 var verified: Dictionary = BattleEvents.verify(sim,self,event,run_id)
 if verified.has("error"): return _deny(str(verified.error))
 var evidence: Dictionary = sim.verify_g02_kill_attribution(self,event,run_id)
 if evidence.is_empty(): return prior
 var scope: Dictionary = _g02_scope(sim)
 var proposal: Dictionary = TrainingTask.evaluate(selected,progress.progress,progress.completed,_g02_claims(progress,scope),scope,evidence)
 if not proposal.get("eligible",false): return prior
 var request: Dictionary = {"run_id":run_id,"scope":scope,"evidence":evidence,"proposal":proposal}
 var command_id: String = "equipment-g02:" + JSON.stringify([run_id,state.actor_id,scope.generation,scope.room_id,proposal.target])
 _g02_trusted = request.duplicate(true)
 _g02_original_event = event.duplicate(true)
 var result: Dictionary = command(command_id,"g02_verified_kill",request)
 _g02_original_event = {};_g02_trusted = {}
 if not result.get("accepted",false): return result
 # No task-specific outward event is introduced. Existing observers/rewards
 # remain on the original kill event; the original command owns its receipt.
 var out: Dictionary = prior.duplicate(true)
 out.merge(result,true)
 out.events = prior.get("events",[]).duplicate(true) + result.get("events",[]).duplicate(true)
 out["g02_task"] = _g02_state()
 out["g02_proposal"] = proposal.duplicate(true)
 return out

func _apply(action: String, args: Dictionary) -> String:
 if action != "g02_verified_kill": return super._apply(action,args)
 if _g02_trusted.is_empty() or args != _g02_trusted or _g02_original_event.is_empty(): return "g02_verified_original_kill_required"
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 if not _g02_bound(sim,str(args.run_id)) or state.phase != "combat" or state.get("actor_dead",false) or state.get("test_mode",false): return "g02_live_holder_required"
 # A real death already committed before an observer paused the game remains
 # a death. The source witness rejects new uncommitted work while paused.
 if sim.phase != "combat" or sim.hero.dead or state.combat_level_id != sim.combat_level_id or args.scope != _g02_scope(sim): return "g02_live_scope_required"
 var verified: Dictionary = BattleEvents.verify(sim,self,_g02_original_event,_run_id)
 if verified.has("error"): return str(verified.error)
 var evidence: Dictionary = sim.verify_g02_kill_attribution(self,_g02_original_event,_run_id)
 if evidence.is_empty() or evidence != args.evidence: return "g02_original_witness_changed"
 var next: Dictionary = _g02_state()
 var selected: Dictionary = TrainingTask.select_unique(state.inventory,runtime_stat_definitions)
 var claims: Dictionary = _g02_claims(next,args.scope)
 var proposal: Dictionary = TrainingTask.evaluate(selected,next.progress,next.completed,claims,args.scope,evidence)
 if not proposal.get("eligible",false) or proposal != args.proposal: return "g02_task_proposal_changed"
 var fact: Dictionary = {"equipment_id":TrainingTask.ITEM_ID,"event_id":"g02:" + JSON.stringify([_run_id,state.actor_id,args.scope.generation,args.scope.room_id,proposal.target]),"progress":proposal.progress_after}
 if proposal.completed:
  if state.completed_equipment_tasks.has(TrainingTask.ITEM_ID) or state.bonus_awards.has(TrainingTask.TASK_ID): return "g02_reward_already_recorded"
  fact.stage = proposal.stage_id;fact.reward_key = proposal.reward_key
 var projected: Dictionary = LedgerProjection.evaluate(state,commerce_definitions,"task_effect",fact,true)
 if not projected.get("accepted",false): return str(projected.get("reason","g02_task_receipt_rejected"))
 var reason: String = LedgerProjection.commit(state,projected.patch,int(commerce_definitions.slot_limit))
 if not reason.is_empty(): return reason
 next.progress = int(proposal.progress_after)
 next.completed = bool(proposal.completed)
 next.claim_scope = args.scope.duplicate(true)
 next.targets = claims.targets.duplicate(true)
 next.targets[proposal.target] = true
 if next.completed:
  # Same authored permanent-SP path as B01. G06 still only evolves its passive.
  state.points += int(proposal.reward_skill_points)
  state.bonus_sp = int(state.get("bonus_sp",0)) + int(proposal.reward_skill_points)
  state.completed_equipment_tasks[TrainingTask.ITEM_ID] = {"task_id":TrainingTask.TASK_ID,"event_id":fact.event_id}
  state.bonus_awards[TrainingTask.TASK_ID] = {"amount":int(proposal.reward_skill_points),"source":"authored_equipment_task","definition_version":config.version}
 state["g02_equipment_progress"] = next
 _commerce_result = projected.duplicate(true);_commerce_result.erase("patch")
 return ""

func _g02_state() -> Dictionary:
 var saved: Dictionary = state.get("g02_equipment_progress",{})
 if saved.get("run_id") == _run_id and saved.get("actor_id") == state.actor_id and saved.get("equipment_id") == TrainingTask.ITEM_ID: return saved.duplicate(true)
 return {"run_id":_run_id,"actor_id":state.actor_id,"equipment_id":TrainingTask.ITEM_ID,"progress":0,"completed":false,"claim_scope":{},"targets":{}}
func _g02_scope(sim: Node) -> Dictionary:
 return {"run_id":_run_id,"actor_id":state.actor_id,"generation":sim.encounter_generation,"room_id":sim.room_id}
func _g02_claims(progress: Dictionary, scope: Dictionary) -> Dictionary:
 return {"scope":scope.duplicate(true),"targets":progress.targets.duplicate(true) if progress.claim_scope == scope else {}}
func equipment_task_status() -> Dictionary:
 var out: Dictionary = super.equipment_task_status()
 var definition: Dictionary = runtime_stat_definitions.get(TrainingTask.ITEM_ID,{})
 if not definition.has("taskG02"): return out
 var progress: Dictionary = _g02_state()
 if not out.has("tasks"): out.tasks = {}
 out.tasks[TrainingTask.ITEM_ID] = {"name":"百战修业","progress":int(progress.progress),"threshold":int(definition.taskG02.threshold),"completed":bool(progress.completed),"reward_skill_points":1,"held_only":true,"retained_when_sold":true,"retained_across_rooms":true,"once_per_run":true,"multiplayer_supported":false}
 return out
func snapshot() -> Dictionary:
 var out: Dictionary = super.snapshot()
 out.content_profile = "ordinary_equipment39_potions3"
 out.content_warnings = [{"reason":"other33_finals_flasks_elixirs_held"}]
 out["g02_equipment"] = _g02_state()
 return out
