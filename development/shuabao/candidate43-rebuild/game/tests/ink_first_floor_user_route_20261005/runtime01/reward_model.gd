extends "res://tests/ink_intermediate_stats_20261004/ink_intermediate_model.gd"
## Same authority and same authenticated kill pipeline; only per-kind gold/XP differ.
## Fresh construction only. No grants, active-world replacement or alternate wallet.
const RewardAdapter = preload("res://tests/ink_first_floor_user_route_20261005/runtime01/reward_adapter.gd")
var _reward_values: Dictionary = {}
var _reward_binding: Dictionary = {}
var _reward_values_frozen := ""

func bind_reward_table(table_path: String, csv_path: String, receipt_path: String, allow_trial: bool = false) -> Dictionary:
 if not _reward_values.is_empty() or _floor_owner != null or _commerce_owner != null: return _deny("fresh_reward_model_required")
 if state.hero_id != "yanguizhou" or state.level != 1 or state.gold != 0 or state.xp != 0 or state.points != 1 or not state.reward_ids.is_empty(): return _deny("fresh_zero_resource_model_required")
 var loaded: Dictionary = RewardAdapter.load_table(table_path, csv_path, receipt_path, allow_trial)
 if not loaded.accepted: return loaded
 _reward_values = loaded.rewards.duplicate(true)
 _reward_values_frozen = JSON.stringify(_reward_values)
 _reward_binding = loaded.binding.duplicate(true)
 return {"accepted":true, "reason":"", "binding":reward_binding()}

func bind_floor(owner: RefCounted, sim: Node, run_id: String) -> Dictionary:
 if _reward_values.is_empty(): return _deny("reward_table_not_bound")
 return super.bind_floor(owner, sim, run_id)

func reward_binding() -> Dictionary:
 return _reward_binding.duplicate(true)

func reward_for_kind(kind: String) -> Dictionary:
 if _reward_values.is_empty(): return _deny("reward_table_not_bound")
 if JSON.stringify(_reward_values) != _reward_values_frozen: return _deny("reward_snapshot_changed")
 if not _reward_values.has(kind): return _deny("unknown_reward_kind:" + kind)
 return {"accepted":true, "reason":"", "gold":_reward_values[kind].gold, "xp":_reward_values[kind].xp}

func observe_live_event(owner: RefCounted, sim: Node, event: Dictionary) -> Dictionary:
 if not _bound(owner, sim): return _deny("wrong_floor_binding")
 if event.get("generation", -1) != sim.encounter_generation or event.get("room_id", "") != sim.room_id:
  return _deny("stale_ink_event")
 if state.combat_level_id != sim.combat_level_id: return _deny("wrong_ledger_room")
 var verified: Dictionary = LiveEvents.verify(sim, self, event, _run_id)
 if verified.has("error"): return _deny(verified.error)
 var numeric: Dictionary = {}
 if event.get("kind", "") == "kill":
  var actual_target: Dictionary = sim.enemy_by_id(str(event.get("target", "")))
  numeric = reward_for_kind(str(actual_target.get("kind", "")))
  if not numeric.accepted: return _deny(numeric.reason)
 var progression_result: Dictionary = record_battle_event(sim, event, _run_id)
 if not progression_result.accepted: return progression_result
 if event.get("kind", "") != "kill": return progression_result
 var target: Dictionary = sim.enemy_by_id(str(event.get("target", "")))
 var reward_id: String = "%s|%s|%s|%s" % [_run_id, sim.combat_level_id, sim.encounter_generation, target.actor_id]
 if reward_id in state.reward_ids:
  return {"accepted":true, "reason":"already_credited_kill", "changed":false, "reward_id":reward_id}
 var reward: Array = [numeric.gold, numeric.xp]
 _reward_open = true
 var result: Dictionary = command("ink-reward:" + reward_id, "reward_minion", {"event_id":reward_id, "room":sim.combat_level_id, "gold":reward[0], "xp":reward[1]})
 _reward_open = false
 result["reward_id"] = reward_id
 result["changed"] = result.accepted
 result["numeric_reward_binding"] = reward_binding()
 return result

