extends "res://integration_checks/equipment39_b01_regression_gate.gd"
## PREPARED ONLY: dedicated actual P1 supplemental-kill attribution gate.
## No engine/GUI run while authoring. The inherited equipment36 gate is frozen.
## Existing row1 rewards learn P1; existing row2 actor receives explicit source
## pre-damage to70 HP, then genuine rank1 Q1/P1 owns the actual65+5 lethal result.
const B01P1Design = preload("res://data/final_design/catalog.gd")
const B01_P1_GROUP := "actual_q1_p1_supplement_kill"
var b01_p1_completed: bool = false
var b01_p1_evidence: Dictionary = {}

func _initialize() -> void:
 output_path = "user://equipment36_p1_gate.json"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--equipment-result="): output_path = argument.trim_prefix("--equipment-result=")
 run.call_deferred()

func p1_cast_events(f: Dictionary, kind: String, cast_id: int, source: String = "") -> Array:
 var found: Array = []
 for event: Dictionary in f.events:
  if event.get("kind", "") == kind and int(event.get("cast_id", 0)) == cast_id and (source.is_empty() or event.get("source", "") == source):
   found.append(event.duplicate(true))
 return found

func p1_cast_receipts(f: Dictionary, cast_id: int) -> Array:
 var found: Array = []
 for receipt: Dictionary in f.sim.ink_p1_receipts:
  if int(receipt.cast_id) == cast_id: found.append(receipt.duplicate(true))
 return found

func p1_enter_original(f: Dictionary, row: int, node_id: String) -> bool:
 if not choose_required_hexes(f): return false
 if not check(f.session.select_node(row, node_id).get("accepted", false), "P1 case selects connected original " + node_id): return false
 var entered: Dictionary = f.session.enter_selected_node()
 if not check(entered.get("accepted", false), "P1 case enters original " + node_id + ": " + str(entered.get("reason", ""))): return false
 check(f.sim.enemies.size() == 4 and f.session.expected_enemies.size() == 4, "original " + node_id + " has exactly four source actors")
 for enemy: Dictionary in f.sim.enemies:
  check(str(enemy.actor_id) in f.session.expected_enemies, "P1 case actor belongs to Session roster: " + str(enemy.actor_id))
 check_owners(f, "P1 original " + node_id)
 return check(f.sim.ai_enabled and f.sim.auto_finish and f.session.fault.is_empty(), "P1 original AI and terminal owners remain enabled")

func prepare_real_p1(f: Dictionary) -> bool:
 # funded_shop already checked zero-start and used the genuine initial1SP Q1
 # learning, then disclosed its60000-gold testwallet. No second initialization.
 if not buy(f, "final:B01") or not buy(f, "final:B01"): return false
 if not check(f.session.close_panel().get("accepted", false), "P1 case closes original shop"): return false
 if not p1_enter_original(f, 1, "r01a") or not settle_fixture_combat(f): return false
 assert_task(f, 0, false, "row1 non-QE fixture kills do not progress equipped B01")
 var model = f.session.ledger.model
 var earned: Dictionary = model.snapshot()
 if not check(int(earned.level) == 2 and int(earned.points) == 1 and f.session.row_state.snapshot().completed_rows.size() == 1, "four original row1 rewards earn Lv2 and1SP for P1"): return false
 var learned: Dictionary = command(f, "learn", {"slot":"P", "candidate":"P1", "expected_rank":0})
 if not check(learned.get("accepted", false), "original command spends earned1SP on P1: " + str(learned.get("reason", ""))): return false
 check(int(model.state.points) == 0 and int(f.sim.hero.ranks.passive) == 1 and f.sim.hero.loadout.passive == "p1", "same original Model projects P1 rank1")
 check(int(f.sim.hero.ranks.q) == 1 and f.sim.hero.loadout.q == "q1" and owned_count(f, "final:B01") == 2, "actual Q1 rank1 and two original B01 copies retained")
 near_number(float(f.sim.hero.stats.ap), 0.0, "no AP fixture changes the authored rank1 Q1 damage")
 b01_p1_evidence["earned_learning"] = {"route_prefix":["r01a", "r02a"], "before_p1_learning":earned, "learn_result":learned, "row1_damage_fixture":true, "natural_acquisition":false}
 return p1_enter_original(f, 2, "r02a") and spawn_ready(f)

func actual_p1_supplement(f: Dictionary) -> bool:
 var target: Dictionary = {}
 for enemy: Dictionary in f.sim.enemies:
  if enemy.kind == "minion" and Vector3(enemy.position).distance_to(f.sim.hero.position) < 9.0:
   target = enemy; break
 if not check(not target.is_empty(), "original row2 contains a legal nearby minion"): return false
 var start: Vector3 = target.position
 var endpoint: Vector3 = start + Vector3(0.26, 0.0, 0.0)
 for enemy: Dictionary in f.sim.living():
  if enemy.actor_id != target.actor_id:
   if not check(Vector3(enemy.position).distance_to(start) > 3.0 + float(enemy.radius), "short real Q1 excludes original sibling " + str(enemy.actor_id)): return false
 var nominal: float = B01P1Design.parameter("yanguizhou", "Q1-1", 1) + float(f.sim.hero.stats.ap) * B01P1Design.fraction("yanguizhou", "Q1-2", 1)
 near_number(nominal, 65.0, "original rank1 Q1 nominal65")
 near_number(B01P1Design.fraction("yanguizhou", "P1-1", 1), 0.12, "original P1 rank1 supplement12%")
 near_number(B01P1Design.fraction("yanguizhou", "P1-2", 1), 0.05, "original P1 rank1 current-CD refund5%")
 near_number(maxf(0.0, float(target.defence) - float(f.sim.hero.stats.penetration)), 0.0, "original minion imposes no remaining Q1 defence")
 if not check(float(target.hp) > 70.0, "original minion has enough HP for declared pre-damage"): return false
 var health_before: float = target.hp
 var pre_damage: float = health_before - 70.0
 var start_event: int = f.events.size()
 var preparation: Dictionary = {"fixture":true, "active_skill":false, "direct":false, "no_reactions":true, "generation":f.sim.encounter_generation, "room_id":f.sim.room_id}
 var killed: bool = f.sim.damage_enemy(target, pre_damage, "equipment36_p1_pre_damage_fixture", 0, true, false, preparation)
 near_number(float(target.hp), 70.0, "real non-QE source pre-damage leaves70 HP without HP assignment")
 if not check(not killed and not target.dead and f.session.kill_receipts.is_empty(), "pre-damage creates no kill/reward receipt"): return false
 assert_task(f, 0, false, "non-QE pre-damage grants no B01 entitlement")
 b01_p1_evidence["pre_damage_fixture"] = {"target_id":target.actor_id, "original_roster":f.session.expected_enemies.duplicate(), "hp_before":health_before, "requested_amount":pre_damage, "hp_after":target.hp, "source":"equipment36_p1_pre_damage_fixture", "cast_id":0, "metadata":preparation, "events":f.events.slice(start_event)}
 var model = f.session.ledger.model
 var gold_before: int = int(model.state.gold)
 var points_before: int = int(model.state.points)
 var levels_before: int = model.state.granted_level_ids.size()
 var reward: Dictionary = model.reward_for_kind(str(target.kind))
 if not check(reward.get("accepted", false), "original target retains authored reward mapping"): return false
 if not check(f.sim.request_ink_input("q_down").get("accepted", false), "P1 case genuine Q1 arm"): return false
 if not check(f.sim.request_ink_input("left_down", start).get("accepted", false), "P1 case genuine Q1 legal start"): return false
 if not check(f.sim.request_ink_input("motion", endpoint).get("accepted", false), "P1 case genuine short Q1 path"): return false
 var released: Dictionary = f.sim.request_ink_input("left_up", endpoint)
 if not check(released.get("accepted", false), "P1 case genuine Q1 release"): return false
 var releases: Array = events_of(f, "ink_q1_released")
 if not check(releases.size() == 1, "one actual input-created Q1 root"): return false
 var cast_id: int = int(releases[0].cast_id)
 check(cast_id > 0 and f.sim.p1.roots.has(cast_id), "real learned P1 owns the original Q1 root")
 near_number(float(target.hp), 5.0, "genuine65 Q1 birth hit leaves5 HP for P1")
 check(not target.dead and p1_cast_receipts(f, cast_id).is_empty() and events_of(f, "equipment_b01_refund").is_empty(), "ordinary nonlethal Q1 does not prematurely pay P1 or B01")
 assert_task(f, 0, false, "before real whole-wave completion")
 for _tick: int in range(100):
  if not p1_cast_receipts(f, cast_id).is_empty() or f.sim.phase != "combat": break
  step(f)
 var receipts: Array = p1_cast_receipts(f, cast_id)
 var ordinary: Array = p1_cast_events(f, "damage", cast_id, "q1")
 var supplements: Array = p1_cast_events(f, "damage", cast_id, "yanguizhou_p1")
 var kills: Array = p1_cast_events(f, "kill", cast_id, "yanguizhou_p1")
 var endings: Array = p1_cast_events(f, "ink_q1_finished", cast_id, "q1")
 var refunds: Array = p1_cast_events(f, "equipment_b01_refund", cast_id)
 if not check(receipts.size() == 1 and ordinary.size() == 1 and supplements.size() == 1 and kills.size() == 1 and endings.size() == 1 and refunds.size() == 1, "exactly one real Q1 hit, terminal, P1 receipt/supplement/kill and B01 refund"): return false
 var receipt: Dictionary = receipts[0]
 var refund: Dictionary = refunds[0]
 var kill: Dictionary = kills[0]
 check(receipt.qualified and int(receipt.distinct_targets) == 1 and int(receipt.ordinary_packet_count) == 1 and receipt.target_status == "live_original" and receipt.supplement_killed, "real completed single-target root owns lethal P1 supplement")
 check(target.dead and float(target.hp) == 0.0 and str(receipt.target_id) == str(target.actor_id), "P1 kills exact original minion")
 near_number(float(ordinary[0].amount), 65.0, "original Q1 actual damage65")
 near_number(float(receipt.final_basis), 65.0, "P1 captures actual original65 basis")
 near_number(float(receipt.requested_supplement), 7.8, "original P1 requests12% of65")
 near_number(float(receipt.actual_supplement), 5.0, "original remaining-HP cap commits final5")
 near_number(float(supplements[0].amount), 5.0, "P1 source damage event agrees with committed5")
 check(kill.get("p1_supplement", false) and supplements[0].get("final_damage_already_settled", false), "source kill retains P1 settled-final provenance")
 check(f.sim._casts.has(cast_id) and bool(f.sim._casts[cast_id].finished) and not bool(f.sim._casts[cast_id].cancelled), "P1 kill retains the original finished, uncancelled Q1 cast")
 check(endings[0].reason == "path_end" and int(endings[0].sequence) < int(supplements[0].sequence) and int(supplements[0].sequence) < int(kill.sequence), "whole-wave terminal precedes original P1 damage and kill")
 near_number(float(receipt.cooldown_refund), float(receipt.cooldown_before) * 0.05, "P1 first refunds5% of its current remaining CD")
 near_number(float(receipt.cooldown_after), float(receipt.cooldown_before) * 0.95, "original P1 current-CD result")
 near_number(float(refund.cooldown_before), float(receipt.cooldown_after), "B01 samples current CD after original P1 refund")
 near_number(float(refund.cooldown_after), float(refund.cooldown_before) * 0.65, "two B01 copies then refund exactly35% once")
 near_number(float(refund.refund), float(refund.cooldown_before) * 0.35, "B01 refund amount uses P1-reduced current CD")
 check(float(refund.cooldown_before) > 0.0 and refund.source == "yanguizhou_p1" and refund.parent_skill == "q1" and refund.slot == "q", "B01 source receipt retains positive original-Q1 P1 attribution")
 var attributed: Array = []
 for observation: Dictionary in f.live_kills:
  if int(observation.event.get("cast_id", 0)) == cast_id and observation.event.source == "yanguizhou_p1": attributed.append(observation)
 check(attributed.size() == 1 and not attributed[0].live_attribution.is_empty() and attributed[0].live_attribution.parent_skill == "q1", "original source P1 receipt verifies during actual kill callback")
 assert_task(f, 1, false, "one P1 supplemental original-Q1 enemy kill")
 check(task_state(f).refund_claims.size() == 1, "single original Q1 cast owns one B01 claim")
 check(int(model.state.gold) == gold_before + int(reward.gold) and int(model.state.points) - points_before == model.state.granted_level_ids.size() - levels_before, "original minion reward occurs once with only normal level SP")
 check(f.session.kill_receipts.size() == 1 and f.session.kill_receipts.has(str(target.actor_id)), "existing Session admits exact original target reward")
 var saved: Dictionary = protected_task(f)
 var replay: Dictionary = f.session.observe_event(f.sim, kill)
 check(replay.get("accepted", false) and protected_task(f) == saved and int(model.state.gold) == gold_before + int(reward.gold), "authentic P1 kill replay cannot duplicate task/refund/SP/gold")
 step(f, 10)
 check(p1_cast_receipts(f, cast_id).size() == 1 and p1_cast_events(f, "equipment_b01_refund", cast_id).size() == 1 and protected_task(f) == saved, "continued actual source steps cannot settle completed P1/B01 twice")
 check(f.session.status == "combat" and f.session.row_state.snapshot().completed_rows.size() == 1 and f.sim.living().size() == 3, "row2 retains only its three surviving original actors")
 check(f.sim.ai_enabled and f.sim.auto_finish and not f.sim.hero.dead and f.event_errors.is_empty() and f.scope_errors.is_empty() and f.session.fault.is_empty(), "original AI, source scope and reward ownership remain intact")
 check_owners(f, "P1 supplemental kill complete")
 b01_p1_evidence["actual_p1"] = {"cast_id":cast_id, "target_id":target.actor_id, "original_q1_damage":ordinary[0], "real_terminal":endings[0], "p1_receipt":receipt, "p1_supplement":supplements[0], "p1_kill":kill, "b01_refund":refund, "attribution":attributed, "task":protected_task(f), "two_equipped_copies":true, "original_finished_cast":true, "real_q1_input":true, "new_qe_cast_fixture":false, "extra_actor_spawned":false, "replay_result":replay}
 return true

func run() -> void:
 current_group = B01_P1_GROUP
 evidence = {"wallet_fixtures":[], "commerce":[], "cooldown_fixtures":[], "packets":[], "cases":[], "actual_q1":{}, "forty_route":{}}
 var f: Dictionary = funded_shop(current_group)
 if not f.is_empty():
  if prepare_real_p1(f): b01_p1_completed = actual_p1_supplement(f)
  dispose(f)
 finish()

func finish() -> void:
 check(b01_p1_completed, "dedicated actual P1 supplemental-kill case reached completion")
 check(check_records.size() == checks, "every dedicated P1 assertion retained")
 var report: Dictionary = {"suite":"equipment36_b01_actual_p1_supplement_gate", "passed":failures.is_empty() and b01_p1_completed, "runtime_status":"EXECUTED", "checks":checks, "failures":failures, "check_records":check_records, "completed_groups":[B01_P1_GROUP] if b01_p1_completed else [], "required_groups":[B01_P1_GROUP], "evidence":b01_p1_evidence, "wallet_fixtures":evidence.wallet_fixtures, "row1_lethal_fixture_packets":fixture_packets, "source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH), "testwallet_fixture":true, "source_pre_damage_to70_fixture":true, "p1_supplement_case_executed":b01_p1_completed, "real_q1_input_case_executed":b01_p1_completed, "original_factory_session":true, "extra_spawned_targets_fixture":false, "task40_threshold_case_covered":false, "h04_original_packet_case_covered":false, "natural_play":false, "natural_full_floor":false, "native_gui_input":false, "scope":"Dedicated actual P1 supplement from original finished Q1 cast; base equipment36 six-group suite is not rerun by this entry."}
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 if file == null:
  push_error("Unable to write equipment36 P1 result: " + output_path); quit(2); return
 file.store_string(JSON.stringify(report, "  "))
 var write_error: Error = file.get_error()
 file.close()
 print("EQUIPMENT36_P1_SOURCE ", JSON.stringify(report))
 quit(2 if write_error != OK else (0 if report.passed else 1))
