extends "res://integration_checks/equipment39_source_gate.gd"
## Original lethal-HP-commit authentication, not a claim about one caller line.
## An observer invokes the original same-parameter kill routine after real HP
## reaches zero. The resumed original core must not emit/pay/advance twice.
var committed_completed: bool = false
var committed_records: Array = []

func _initialize() -> void:
 output_path = "user://equipment39_g02_committed_death_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="): output_path = arg.trim_prefix("--equipment-result=")
 run.call_deferred()

func on_event(event: Dictionary, f: Dictionary) -> void:
 if f.get("commit_probe_armed", false) and event.get("kind", "") == "damage" and event.get("target", "") == f.get("commit_target_id", "") and int(event.get("cast_id", -1)) == int(f.get("commit_cast_id", -2)):
  f.commit_probe_armed = false
  var original: Dictionary = f.sim.enemy_by_id(str(event.target))
  check(not original.is_empty() and is_same(original, f.commit_target) and not original.dead and float(original.hp) == 0.0 and float(event.amount) > 0.0, "observer runs after genuine original lethal HP commit and before original death notification")
  f["commit_damage_event"] = event.duplicate(true)
  f["task_before_early_kill"] = g02_protected(f)
  # Same real actor, source and cast. No fabricated event or copied receipt.
  f.sim._kill_enemy(original, str(event.source), int(event.cast_id))
  f["task_after_early_kill"] = g02_protected(f)
 super.on_event(event, f) # Exactly one original Session submission per event.

func target_kills(f: Dictionary, enemy: Dictionary) -> Array:
 var result: Array = []
 for event: Dictionary in f.events:
  if event.get("kind", "") == "kill" and event.get("target", "") == enemy.actor_id and int(event.get("generation", -1)) == int(enemy.generation): result.append(event.duplicate(true))
 return result

func committed_packet(f: Dictionary, target: Dictionary, expected_weight: int) -> bool:
 var model = f.session.ledger.model
 var before: Dictionary = {"task":g02_protected(f), "gold":model.state.gold, "xp":model.state.xp, "points":model.state.points, "level_grants":model.state.granted_level_ids.size(), "reward_ids":model.state.reward_ids.size(), "kill_receipts":f.session.kill_receipts.size(), "hp":target.hp, "kills":target_kills(f,target).size()}
 var reward: Dictionary = model.reward_for_kind(str(target.kind))
 if not check(reward.get("accepted", false), "original target has original authored reward"): return false
 var context: Dictionary = f.sim.new_cast("q", "g02_original_lethal_commit_probe")
 f.sim.start_skill_cooldown("q", 10.0)
 f["commit_target"] = target
 f["commit_target_id"] = str(target.actor_id)
 f["commit_cast_id"] = int(context.cast_id)
 f["commit_probe_armed"] = true
 f["commit_damage_event"] = {}
 var killed: bool = f.sim.damage_enemy(target, float(target.hp) + 100000.0, "q1", int(context.cast_id), true, false, {"fixture":true, "direct":true, "active_skill":true, "no_reactions":true, "generation":f.sim.encounter_generation, "room_id":f.sim.room_id})
 if not check(killed and target.dead and not f.commit_probe_armed and not f.commit_damage_event.is_empty(), "real lethal packet returns after observer kill and resumed original core"): return false
 var kills: Array = target_kills(f, target)
 check(kills.size() == int(before.kills) + 1, "observer call plus resumed original core emit exactly one original kill")
 check(f.session.kill_receipts.size() == int(before.kill_receipts) + 1 and model.state.reward_ids.size() == int(before.reward_ids) + 1, "original Session records one kill and one reward identity")
 check(int(model.state.gold) == int(before.gold) + int(reward.gold) and int(model.state.xp) == int(before.xp) + int(reward.xp), "original authored gold and XP paid exactly once")
 check(int(model.state.points) - int(before.points) == model.state.granted_level_ids.size() - int(before.level_grants), "only original level SP is paid below the G02 threshold")
 check(int(g02_task(f).progress) == int(before.task.task.progress) + expected_weight and model.state.bonus_sp == before.task.bonus_sp, "one real lethal commit contributes exactly one original-rank G02 weight")
 check(f.task_after_early_kill == g02_protected(f), "resumed original core cannot grant G02 a second time")
 var attribution: Dictionary = g02_find_kill(f, str(target.actor_id), "q1")
 check(not attribution.is_empty() and attribution.witness.get("witness", {}).get("proof", "") == "original_damage_death", "same original Session observes authenticated original lethal commit")
 var saved: Dictionary = {"task":g02_protected(f), "gold":model.state.gold, "xp":model.state.xp, "rewards":model.state.reward_ids.duplicate(true)}
 var replay: Dictionary = f.session.observe_event(f.sim, kills.back())
 check(replay.get("accepted", false) and saved == {"task":g02_protected(f), "gold":model.state.gold, "xp":model.state.xp, "rewards":model.state.reward_ids.duplicate(true)}, "historical real kill replay cannot pay or count again")
 committed_records.append({"target":target.actor_id, "kind":target.kind, "rank":target.rank_category, "before":before, "authored_reward":reward, "genuine_damage":f.commit_damage_event, "single_original_kill":kills.back(), "attribution":attribution, "after":saved, "observer_calls_original_kill":true, "original_core_resumed":true, "original_lethal_commit_authenticated":true, "exact_callsite_identity_claimed":false, "actual_skill_input":false, "productionSession":true})
 return true

func committed_route() -> void:
 current_group = "original_committed_death_observer_and_core"
 var f: Dictionary = funded_shop(current_group)
 if f.is_empty(): return
 if not buy(f, "final:G02") or not buy(f, "final:G02") or not check(f.session.close_panel().get("accepted", false), "committed-death original shop closes") or not enter(f,1) or not spawn_ready(f): dispose(f); return
 var actors: Array = f.sim.enemies.duplicate()
 for index: int in range(actors.size()-1): lethal_enemy_fixture(f,actors[index],"original row prefix before last-actor committed-death probe")
 check(f.sim.living().size() == 1, "ordinary probe targets actual last entered original enemy")
 var terminals_before: int = f.terminals.size()
 if not committed_packet(f,actors.back(),1) or not settle_original_row(f,1): dispose(f); return
 check(f.terminals.size() == terminals_before + 1 and f.session.row_state.snapshot().completed_rows.size() == 1, "last ordinary actor produces one terminal and one original row advancement")
 if not traverse_to_boss(f,2): dispose(f); return
 var cast: Dictionary = wait_for_boss_warning(f)
 if cast.is_empty(): dispose(f); return
 var cast_id: String = str(cast.boss_cast_id)
 check(events_of(f,"boss_cast_cancelled",cast_id).is_empty(), "original live Boss warning has not already been cancelled")
 terminals_before = f.terminals.size()
 if not committed_packet(f,f.boss,25): dispose(f); return
 var cancellations: Array = events_of(f,"boss_cast_cancelled",cast_id)
 var kills: Array = target_kills(f,f.boss)
 check(cancellations.size() == 1 and cancellations[0].reason == "owner_died", "observer kill and resumed core cancel original Boss warning exactly once")
 check(not cancellations.is_empty() and int(cancellations[0].sequence) < int(kills.back().sequence), "original Boss cancellation precedes its one authentic kill")
 if not settle_original_row(f,12): dispose(f); return
 check(f.terminals.size() == terminals_before + 1 and f.session.row_state.snapshot().completed_rows.size() == 12 and f.session.status == "completed", "last original Boss advances the whole floor exactly once")
 check(f.session.settlement.has("major_floor_event") and int(g02_task(f).progress) == 73 and not g02_task(f).completed, "original floor reward settles once and all-held authored route remains73 below500")
 var saved: PackedByteArray = var_to_bytes(f.session.ledger.model.state)
 step(f,150)
 check(saved == var_to_bytes(f.session.ledger.model.state) and events_of(f,"boss_cast_cancelled",cast_id).size() == 1 and events_of(f,"boss_attack_released",cast_id).is_empty() and events_of(f,"boss_hit_receipt",cast_id).is_empty(), "later original steps cannot duplicate reward/cancellation or revive the Boss warning")
 check(f.event_errors.is_empty() and f.scope_errors.is_empty() and f.session.fault.is_empty(), "early original kill preserves every original Session event and scope contract")
 b04_integrity(f,current_group)
 dispose(f); committed_completed = true

func run() -> void:
 evidence = {"wallet_fixtures":[], "inputs":[], "cooldown_fixtures":[], "completions":[], "aborts":[], "victory":[], "postcompletion":[], "lifecycle":[], "isolated_common":[], "movement":[], "g02_deaths":[], "pre_damage":[], "inputs_g02":[], "p1_g02":{}, "route_g02":{}, "extra_actor_g02":{}}
 committed_route()
 check(committed_completed and committed_records.size() == 2, "both actual last-enemy and Boss committed-death probes complete")
 var report: Dictionary = {"suite":"equipment39_g02_original_lethal_commit_once", "passed":failures.is_empty() and committed_completed, "checks":checks, "failures":failures, "check_records":check_records, "committed_records":committed_records, "evidence":evidence, "productionSession":true, "original_Host_factories":true, "extra_actors":false, "original_lethal_commit_authenticated":true, "exact_core_callsite_identity_claimed":false, "source_API_packet_fixture":true, "task_progress_written":false, "natural":false, "native_GUI":false, "production_ready":false}
 var file: FileAccess = FileAccess.open(output_path,FileAccess.WRITE)
 if file == null: push_error("Unable to write committed-death result"); quit(2); return
 file.store_string(JSON.stringify(report,"  ")); var error: Error = file.get_error(); file.close()
 print("G02_ORIGINAL_LETHAL_COMMIT ", JSON.stringify({"passed":report.passed,"checks":checks,"failures":failures,"result":output_path}))
 quit(2 if error != OK else (0 if report.passed else 1))
