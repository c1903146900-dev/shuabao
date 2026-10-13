extends "res://scripts/integration/run_model.gd"
## Ink-only authority overlay; shared catalog economics and immutable source numbers stay intact.
const LiveEvents = preload("res://data/final_design/event_adapter.gd")
const EXISTING_REWARDS = {"boss":[300,160], "elite":[100,80], "armored":[35,20]}
var _floor_owner: WeakRef
var _live_sim: WeakRef
var _run_id := ""
var _reward_open := false
var _completion_open := false

func bind_floor(owner: RefCounted, sim: Node, run_id: String) -> Dictionary:
 if _floor_owner != null or not is_instance_valid(sim) or run_id.is_empty(): return _deny("floor_binding_invalid")
 if state.hero_id != "yanguizhou" or sim.hero.actor_id != "yanguizhou": return _deny("ink_hero_mismatch")
 _floor_owner = weakref(owner)
 _live_sim = weakref(sim)
 _run_id = run_id
 return {"accepted":true, "reason":""}

func _apply(action: String, args: Dictionary) -> String:
 if action == "learn" and args.get("candidate", "") not in config.get("runtime_candidates", []): return "candidate_not_implemented"
 if action == "reward_minion" and not _reward_open: return "verified_ink_kill_required"
 if action == "complete_act" and not _completion_open: return "floor_coordinator_required"
 # Equivalent boundary to approved safe-only allocation push, expressed as local overlay.
 # No shared production Model rewrite; no old-save migration is claimed.
 var combat_learn: bool = action == "learn" and state.phase == "combat"
 var allocation_count: int = state.allocations.size()
 var result: String = super._apply(action, args)
 if result.is_empty() and combat_learn:
  while state.allocations.size() > allocation_count: state.allocations.pop_back()
 return result

func observe_live_event(owner: RefCounted, sim: Node, event: Dictionary) -> Dictionary:
 if not _bound(owner, sim): return _deny("wrong_floor_binding")
 if event.get("generation", -1) != sim.encounter_generation or event.get("room_id", "") != sim.room_id:
  return _deny("stale_ink_event")
 if state.combat_level_id != sim.combat_level_id: return _deny("wrong_ledger_room")
 var verified: Dictionary = LiveEvents.verify(sim, self, event, _run_id)
 if verified.has("error"): return _deny(verified.error)
 var progression_result: Dictionary = record_battle_event(sim, event, _run_id)
 if not progression_result.accepted: return progression_result
 if event.get("kind", "") != "kill": return progression_result
 var target: Dictionary = sim.enemy_by_id(str(event.get("target", "")))
 var reward_id: String = "%s|%s|%s|%s" % [_run_id, sim.combat_level_id, sim.encounter_generation, target.actor_id]
 if reward_id in state.reward_ids:
  return {"accepted":true, "reason":"already_credited_kill", "changed":false, "reward_id":reward_id}
 var reward: Array = EXISTING_REWARDS.get(target.kind, [20,12])
 _reward_open = true
 var result: Dictionary = command("ink-reward:" + reward_id, "reward_minion", {"event_id":reward_id, "room":sim.combat_level_id, "gold":reward[0], "xp":reward[1]})
 _reward_open = false
 result["reward_id"] = reward_id
 result["changed"] = result.accepted
 return result

func complete_floor(owner: RefCounted, act_id: String, completion_id: String) -> Dictionary:
 if _floor_owner == null or not is_same(_floor_owner.get_ref(), owner): return _deny("floor_coordinator_required")
 _completion_open = true
 var result: Dictionary = super.complete_act(act_id, completion_id)
 _completion_open = false
 return result

func _bound(owner: RefCounted, sim: Node) -> bool:
 return _floor_owner != null and _live_sim != null and is_same(_floor_owner.get_ref(), owner) and is_same(_live_sim.get_ref(), sim)

func _deny(reason: String) -> Dictionary:
 return {"accepted":false, "reason":reason, "changed":false, "events":[]}
