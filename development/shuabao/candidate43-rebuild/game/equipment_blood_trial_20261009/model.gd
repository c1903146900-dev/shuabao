extends "res://equipment_lifeline_20261009/model.gd"
## Player/equipment-name task in the original ledger. Each packet uses the
## owner HP/maxHP sealed by the source before any external damage callback.
const BloodTask = preload("task03.gd")
var _g03_trusted: Dictionary = {}
var _g03_original_event: Dictionary = {}

func equipment_runtime_status(id: String) -> Dictionary:
 var out: Dictionary = super.equipment_runtime_status(id)
 if id != BloodTask.ITEM_ID or not out.get("supported",false): return out
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 if not _g03_bound(sim,_run_id):
  return {"supported":false,"reason":"g03_original_damage_bridge_not_bound"}
 out.runtime_complete = true;out.shop_admitted = true
 out.runtime_status = "source_low_health_ratio_task_bound"
 return out

func _g03_bound(sim: Node, run_id: String) -> bool:
 return run_id == _run_id and not run_id.is_empty() and _d04_bound(sim) and sim.has_method("g03_model_is_bound") and sim.has_method("verify_g03_damage_attribution") and sim.g03_model_is_bound(self)

func record_battle_event(sim: Node, event: Dictionary, run_id: String) -> Dictionary:
 # Keep the original B01/G06/B04/G02/B02/D04/progression/reward caller order intact.
 var prior: Dictionary = super.record_battle_event(sim,event,run_id)
 if not prior.get("accepted",false) or event.get("kind") != "damage": return prior
 if not _g03_bound(sim,run_id) or not _g03_trusted.is_empty() or not equipment_runtime_status(BloodTask.ITEM_ID).get("supported",false): return prior
 var selected: Dictionary = BloodTask.select_unique(state.inventory,runtime_stat_definitions)
 var progress: Dictionary = _g03_state()
 if not selected.equipped or progress.completed: return prior
 var verified: Dictionary = BattleEvents.verify(sim,self,event,run_id)
 if verified.has("error"): return _deny(str(verified.error))
 var evidence: Dictionary = sim.verify_g03_damage_attribution(self,event,run_id)
 if evidence.is_empty(): return prior
 var scope: Dictionary = _g02_scope(sim)
 var proposal: Dictionary = BloodTask.evaluate(selected,progress.progress,progress.completed,_g03_claims(progress,scope),scope,evidence,progress.progress_carry)
 if not proposal.get("eligible",false): return prior
 var request: Dictionary = {"run_id":run_id,"scope":scope,"evidence":evidence,"proposal":proposal}
 var command_id: String = "equipment-g03:" + JSON.stringify([run_id,state.actor_id,scope.generation,scope.room_id,proposal.sequence])
 _g03_trusted = request.duplicate(true)
 _g03_original_event = event.duplicate(true)
 var result: Dictionary = command(command_id,"g03_verified_damage",request)
 _g03_original_event = {};_g03_trusted = {}
 if not result.get("accepted",false): return result
 # Existing damage, lifesteal and kill observers stay in their original order.
 # This original command contributes only its separate ratio task receipt.
 var out: Dictionary = prior.duplicate(true)
 out.merge(result,true)
 out.events = prior.get("events",[]).duplicate(true) + result.get("events",[]).duplicate(true)
 out["g03_task"] = _g03_state()
 out["g03_proposal"] = proposal.duplicate(true)
 return out

func _apply(action: String, args: Dictionary) -> String:
 if action != "g03_verified_damage": return super._apply(action,args)
 if _g03_trusted.is_empty() or args != _g03_trusted or _g03_original_event.is_empty(): return "g03_verified_original_damage_required"
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 if not _g03_bound(sim,str(args.run_id)) or state.phase != "combat" or state.get("actor_dead",false) or state.get("test_mode",false): return "g03_live_holder_required"
 # The source captured a real commit before notification. Original authority
 # still decides whether this event reaches the Model; do not loosen it here.
 if sim.phase != "combat" or sim.hero.dead or state.combat_level_id != sim.combat_level_id or args.scope != _g02_scope(sim): return "g03_live_scope_required"
 var verified: Dictionary = BattleEvents.verify(sim,self,_g03_original_event,_run_id)
 if verified.has("error"): return str(verified.error)
 var evidence: Dictionary = sim.verify_g03_damage_attribution(self,_g03_original_event,_run_id)
 if evidence.is_empty() or evidence != args.evidence: return "g03_original_witness_changed"
 var next: Dictionary = _g03_state()
 var selected: Dictionary = BloodTask.select_unique(state.inventory,runtime_stat_definitions)
 var claims: Dictionary = _g03_claims(next,args.scope)
 var proposal: Dictionary = BloodTask.evaluate(selected,next.progress,next.completed,claims,args.scope,evidence,next.progress_carry)
 if not proposal.get("eligible",false) or proposal != args.proposal: return "g03_task_proposal_changed"
 var fact: Dictionary = {"equipment_id":BloodTask.ITEM_ID,"event_id":"g03:" + JSON.stringify([_run_id,state.actor_id,args.scope.generation,args.scope.room_id,proposal.sequence]),"progress":int(proposal.ledger_progress)}
 if proposal.completed:
  if state.completed_equipment_tasks.has(BloodTask.ITEM_ID) or state.bonus_awards.has(BloodTask.TASK_ID): return "g03_reward_already_recorded"
  fact.stage = proposal.stage_id;fact.reward_key = proposal.reward_key
 var projected: Dictionary = LedgerProjection.evaluate(state,commerce_definitions,"task_effect",fact,true)
 if not projected.get("accepted",false): return str(projected.get("reason","g03_task_receipt_rejected"))
 var reason: String = LedgerProjection.commit(state,projected.patch,int(commerce_definitions.slot_limit))
 if not reason.is_empty(): return reason
 next.progress = float(proposal.progress_after)
 next.progress_carry = float(proposal.progress_carry_after)
 next.completed = bool(proposal.completed)
 next.claim_scope = args.scope.duplicate(true)
 next.sequences = claims.sequences.duplicate(true)
 next.sequences[proposal.sequence] = true
 if next.completed:
  # Same authored permanent-SP path as B01. G06 still only evolves its passive.
  state.points += int(proposal.reward_skill_points)
  state.bonus_sp = int(state.get("bonus_sp",0)) + int(proposal.reward_skill_points)
  state.completed_equipment_tasks[BloodTask.ITEM_ID] = {"task_id":BloodTask.TASK_ID,"event_id":fact.event_id}
  state.bonus_awards[BloodTask.TASK_ID] = {"amount":int(proposal.reward_skill_points),"source":"authored_equipment_task","definition_version":config.version}
 state["g03_equipment_progress"] = next
 _commerce_result = projected.duplicate(true);_commerce_result.erase("patch")
 return ""

func _g03_state() -> Dictionary:
 var saved: Dictionary = state.get("g03_equipment_progress",{})
 if saved.get("run_id") == _run_id and saved.get("actor_id") == state.actor_id and saved.get("equipment_id") == BloodTask.ITEM_ID: return saved.duplicate(true)
 return {"run_id":_run_id,"actor_id":state.actor_id,"equipment_id":BloodTask.ITEM_ID,"progress":0.0,"progress_carry":0.0,"completed":false,"claim_scope":{},"sequences":{}}
func _g03_claims(progress: Dictionary, scope: Dictionary) -> Dictionary:
 return {"scope":scope.duplicate(true),"sequences":progress.sequences.duplicate(true) if progress.claim_scope == scope else {}}
func equipment_task_status() -> Dictionary:
 var out: Dictionary = super.equipment_task_status()
 var definition: Dictionary = runtime_stat_definitions.get(BloodTask.ITEM_ID,{})
 if not definition.has("taskG03"): return out
 var progress: Dictionary = _g03_state()
 if not out.has("tasks"): out.tasks = {}
 out.tasks[BloodTask.ITEM_ID] = {"name":"血战修业","progress":float(progress.progress),"threshold":float(definition.taskG03.threshold),"progress_percent":float(progress.progress)*100.0,"health_threshold":float(definition.taskG03.health_threshold),"completed":bool(progress.completed),"reward_skill_points":1,"held_only":true,"retained_when_sold":true,"retained_across_rooms":true,"once_per_run":true,"pause_when_healed":true,"ratio_sample":"per_packet_owner_max_hp_at_commit"}
 return out
func snapshot() -> Dictionary:
 var out: Dictionary = super.snapshot()
 out.content_profile = "ordinary_equipment42_potions3"
 out.content_warnings = [{"reason":"other30_finals_flasks_elixirs_held"}]
 out["g03_equipment"] = _g03_state()
 return out
