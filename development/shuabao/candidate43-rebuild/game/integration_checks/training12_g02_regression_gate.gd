extends "res://integration_checks/training12_b04_regression_gate.gd"
## PREPARED ONLY: original Host/Session gate. Threshold500 belongs to a
## separate standalone source/Model gate; no rejected Session event is retried
## directly against this Model. Parent owns all engine execution.
const G02Prior = preload("res://equipment_basic_cycle_20261009/adapter.gd")
const G02_GROUPS := ["definitions_and_commerce", "actual_basic_q_e_inputs", "actual_p1_atomic_kill", "original_route_and_lifecycle", "extra_actor_admission_rejected"]
var g02_groups: Array = []
var g02_required: Array = G02_GROUPS.duplicate()
var g02_partition: String = "all"

func _initialize() -> void:
 output_path = "user://equipment39_source_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="): output_path = arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--g02-source-group="): g02_partition = arg.trim_prefix("--g02-source-group=")
 if g02_partition != "all":
  if g02_partition not in G02_GROUPS: push_error("Unknown G02 source group"); quit(2); return
  g02_required = [g02_partition]
 run.call_deferred()

func funded_shop(label: String) -> Dictionary:
 var f: Dictionary = super.funded_shop(label)
 if f.is_empty(): return {}
 f["g02_kills"] = []
 f["g02_synthetic"] = false
 if not check(f.sim.g02_model_is_bound(f.session.ledger.model) and f.session.ledger.model.equipment_runtime_status("final:G02").get("runtime_complete", false), "G02 original death bridge binds same exact Model"):
  dispose(f); return {}
 return f

func g02_task(f: Dictionary) -> Dictionary:
 return f.session.ledger.model._g02_state().duplicate(true)

func g02_protected(f: Dictionary) -> Dictionary:
 var model = f.session.ledger.model
 return {"task":g02_task(f), "ledger":model.state.shop_visit.taskLedger.get(str(model.state.actor_id) + "|final:G02", {}).duplicate(true), "completed":model.state.completed_equipment_tasks.duplicate(true), "awards":model.state.bonus_awards.duplicate(true), "bonus_sp":model.state.bonus_sp}

func on_event(event: Dictionary, f: Dictionary) -> void:
 var record: Dictionary = {}
 if event.get("kind", "") == "kill" and f.has("g02_kills"):
  var target: Dictionary = f.sim.enemy_by_id(str(event.target))
  record = {"event":event.duplicate(true), "witness":f.sim.verify_g02_kill_attribution(f.session.ledger.model, event, f.session.run_id), "before":g02_protected(f), "rank":target.get("rank_category", ""), "original_roster":str(event.target) in f.session.expected_enemies, "held":owned_count(f, "final:G02") > 0, "synthetic":f.g02_synthetic, "points_before":f.session.ledger.model.state.points, "level_grants_before":f.session.ledger.model.state.granted_level_ids.size()}
 super.on_event(event, f) # Exactly one original Session submission.
 if record.is_empty(): return
 record["after"] = g02_protected(f)
 record["points_after"] = f.session.ledger.model.state.points
 record["level_grants_after"] = f.session.ledger.model.state.granted_level_ids.size()
 var expected: int = int(record.before.task.progress)
 if record.held and record.original_roster and not record.synthetic and not record.witness.is_empty() and not record.before.task.completed:
  expected = mini(500, expected + (25 if record.rank == "boss" else 10 if record.rank == "elite" else 1))
 check(int(record.after.task.progress) == expected, "original Session G02 change matches real held/roster/source/rank eligibility")
 if not record.before.task.completed and expected < 500:
  check(int(record.after.bonus_sp) == int(record.before.bonus_sp), "subthreshold original death grants no G02 bonus SP")
 f.g02_kills.append(record)
 evidence.g02_deaths.append(record)

func g02_done() -> void:
 check(current_group in G02_GROUPS and current_group not in g02_groups, "unique original G02 source group " + current_group)
 g02_groups.append(current_group)

func g02_stats(f: Dictionary, copies: int, label: String) -> void:
 var now: Dictionary = authority(f)
 for row: Array in [["AD", "ad", 30.0], ["AP", "ap", 45.0], ["max_hp", "max_hp", 250.0], ["cooldown_reduction", "cdr", 0.10]]:
  near_number(float(now.equipment.stats.get(row[0], 0.0)) - float(f.baseline.equipment.stats.get(row[0], 0.0)), float(row[2]) * copies, label + ": original G02 per-copy " + str(row[0]))
  near_number(float(now.current_sim_stats[row[1]]) - float(f.baseline.current_sim_stats[row[1]]), float(row[2]) * copies, label + ": same live source stat " + str(row[1]))
 check(owned_count(f, "final:G02") == copies, label + ": original inventory copies")

func g02_open(f: Dictionary) -> bool:
 return choose_required_hexes(f) and check(f.session.open_panel().get("accepted", false), "original safe shop opens")

func g02_definitions() -> void:
 current_group = G02_GROUPS[0]
 var f: Dictionary = funded_shop(current_group)
 if f.is_empty(): return
 var model = f.session.ledger.model
 var prior: Dictionary = G02Prior.build(JSON.parse_string(FileAccess.get_file_as_string(B01_NUMERIC)))
 if not check(prior.get("accepted", false), "original38 adapter accepts original numeric source"): dispose(f); return
 check(model.runtime_stat_definitions.size() == prior.definitions.size() + 5, "G02 B02 D04 G03 E03 add exactly five original runtime entries")
 for id: String in prior.definitions:
  check(var_to_bytes(prior.definitions[id]) == var_to_bytes(model.runtime_stat_definitions.get(id, {})), "every prior38 definition remains byte-equivalent " + id)
 var admitted: int = 0
 for definition: Dictionary in model.runtime_stat_definitions.values():
  if definition.get("supported", false): admitted += 1
 var g02: Dictionary = model.equipment_runtime_status("final:G02")
 check(admitted == 43 and model.snapshot().content_profile == "ordinary_equipment43_potions3", "truthful equipment43 content profile")
 check(g02.stats == {"AD":30.0, "AP":45.0, "max_hp":250.0, "cooldown_reduction":0.10} and g02.passives.is_empty() and g02.actives.is_empty(), "original G02 base attributes and task-only mechanism")
 check(g02.taskG02 == {"threshold":500, "normal_weight":1, "elite_weight":10, "boss_weight":25, "stage_id":"task:G02:1", "reward_skill_points":1}, "original500 and1/10/25 task authority")
 check(int(g02.commerce.price) == 2750 and int(g02.commerce.component_total) == 2350 and int(g02.commerce.combine_fee) == 400, "original2750 full price and400 fee")
 var hp: float = f.sim.hero.hp
 var gold: int = model.state.gold
 if not buy(f, "final:G02"): dispose(f); return
 g02_stats(f, 1, "one G02")
 check(int(model.state.gold) == gold - 2750 and float(f.sim.hero.hp) == hp, "original price debit; maxHP250 does not heal current HP")
 buy(f, "final:G02"); g02_stats(f, 2, "two G02")
 sell(f, "final:G02"); g02_stats(f, 1, "one remains")
 undo(f); g02_stats(f, 2, "sale undo")
 undo(f); undo(f); g02_stats(f, 0, "purchase undo")
 buy(f, "intermediate:I13"); buy(f, "intermediate:I17")
 gold = model.state.gold
 var crafted: Dictionary = shop_command(f, "craft", {"item":"final:G02"})
 check(crafted.get("accepted", false) and model.state.gold == gold - 400 and owned_count(f, "intermediate:I13") == 0 and owned_count(f, "intermediate:I17") == 0 and owned_count(f, "final:G02") == 1, "original I13+I17 recipe charges400")
 undo(f)
 check(owned_count(f, "final:G02") == 0 and owned_count(f, "intermediate:I13") == 1 and owned_count(f, "intermediate:I17") == 1, "original craft undo restores components")
 var before: Dictionary = g02_protected(f)
 var denied: Dictionary = command(f, "g02_verified_kill", {"progress":500})
 check(not denied.get("accepted", false) and g02_protected(f) == before, "public command cannot mint G02 task or SP")
 b04_integrity(f, current_group); dispose(f); g02_done()

func g02_nearest(f: Dictionary) -> Dictionary:
 var target: Dictionary = {}
 var distance: float = INF
 for enemy: Dictionary in f.sim.living():
  var next_distance: float = Vector3(enemy.position).distance_to(f.sim.hero.position)
  if next_distance < distance: target = enemy; distance = next_distance
 return target

func g02_prepare_hp(f: Dictionary, target: Dictionary, remaining: float) -> bool:
 if not check(str(target.actor_id) in f.session.expected_enemies and float(target.hp) > remaining and remaining > 0.0, "source pre-damage uses only an original entered live actor"): return false
 var before: Dictionary = g02_protected(f)
 var hp: float = target.hp
 var killed: bool = f.sim.damage_enemy(target, hp - remaining, "equipment39_nonlethal_setup", 0, true, false, {"fixture":true, "direct":false, "no_reactions":true, "snapshot_final":true, "generation":f.sim.encounter_generation, "room_id":f.sim.room_id})
 evidence.pre_damage.append({"target":target.actor_id, "before":hp, "after":target.hp, "requested_remaining":remaining, "original_roster":true, "direct_HP_write":false})
 return check(not killed and not target.dead and is_equal_approx(float(target.hp), remaining) and g02_protected(f) == before, "original source nonlethal setup creates no kill/task entitlement")

func g02_find_kill(f: Dictionary, target: String, source: String) -> Dictionary:
 for record: Dictionary in f.g02_kills:
  if not record.synthetic and str(record.event.target) == target and str(record.event.source) == source: return record
 return {}

func g02_q1(f: Dictionary, target: Dictionary) -> Dictionary:
 var start: Vector3 = target.position
 var endpoint: Vector3 = start + Vector3(0.26, 0, 0)
 if not check(Vector3(start).distance_to(f.sim.hero.position) < 9.0, "real Q1 start remains inside original placement radius"): return {}
 if not check(f.sim.request_ink_input("q_down").get("accepted", false), "actual Q1 arm") or not check(f.sim.request_ink_input("left_down", start).get("accepted", false), "actual Q1 mouse down") or not check(f.sim.request_ink_input("motion", endpoint).get("accepted", false), "actual short Q1 drawing"): return {}
 var result: Dictionary = f.sim.request_ink_input("left_up", endpoint)
 check(result.get("accepted", false), "actual Q1 release creates original source cast")
 return result

func g02_inputs() -> void:
 current_group = G02_GROUPS[1]
 var f: Dictionary = funded_shop(current_group)
 if f.is_empty(): return
 if not buy(f, "final:G02") or not check(f.session.close_panel().get("accepted", false), "G02 input shop closes") or not enter(f, 1) or not spawn_ready(f): dispose(f); return
 var target: Dictionary = g02_nearest(f)
 if target.is_empty() or not g02_prepare_hp(f, target, 1.0): dispose(f); return
 var basic: Dictionary = b04_launch(f, target.position)
 if basic.is_empty(): dispose(f); return
 for _tick: int in range(180):
  if target.dead: break
  step(f)
 var first: Dictionary = g02_find_kill(f, str(target.actor_id), "attack")
 if not check(not first.is_empty() and not first.witness.is_empty() and int(first.after.task.progress) == 1, "actual original basic death grants one ordinary equivalent"): dispose(f); return
 var saved: Dictionary = g02_protected(f)
 var replay: Dictionary = f.session.observe_event(f.sim, first.event)
 f.g02_synthetic = true; f.sim.emit_event("kill", first.event.duplicate(true)); f.g02_synthetic = false
 f.sim.damage_enemy(target, 100000.0, "attack", int(first.event.cast_id), true, false, {"fixture":true})
 check(replay.get("accepted", false) and g02_protected(f) == saved, "original Session replay, public fresh-sequence corpse and repeat source damage cannot count twice")
 target = g02_nearest(f)
 if target.is_empty() or not g02_prepare_hp(f, target, 1.0) or g02_q1(f, target).is_empty(): dispose(f); return
 var qkill: Dictionary = g02_find_kill(f, str(target.actor_id), "q1")
 check(not qkill.is_empty() and not qkill.witness.is_empty() and g02_task(f).progress == 2, "actual Q1 death independently counts once")
 if not b04_settle_row(f, 1): dispose(f); return
 check(g02_task(f).progress == 6, "all six original row1 deaths count independently of cast source")
 if not check(command(f, "learn", {"slot":"E", "candidate":"E1", "expected_rank":0}).get("accepted", false), "original earned SP learns actual E1") or not enter(f, 2) or not spawn_ready(f): dispose(f); return
 check(f.sim.hero.loadout.e == "e1" and f.sim.hero.ranks.e == 1, "original Model projects actual paid E1")
 target = g02_nearest(f)
 if target.is_empty() or not b04_approach(f, target, 1.0) or not g02_prepare_hp(f, target, 1.0): dispose(f); return
 var down := InputEventKey.new(); down.physical_keycode = KEY_E; down.pressed = true
 var up := InputEventKey.new(); up.physical_keycode = KEY_E; up.pressed = false
 var e_start: Dictionary = f.router.handle_event(down, target.position)
 var e_end: Dictionary = f.router.handle_event(up, target.position)
 check(e_start.get("accepted", false) and e_end.get("accepted", false), "original router E-down/up accepts the same E1 form")
 for _tick: int in range(160):
  if target.dead: break
  step(f)
 var ekill: Dictionary = g02_find_kill(f, str(target.actor_id), "e1")
 check(not ekill.is_empty() and not ekill.witness.is_empty(), "actual E1 reform owns original target death")
 evidence.inputs_g02.append({"basic":first, "q1":qkill, "e1":ekill, "actual_source_inputs":true, "native_GUI":false})
 b04_integrity(f, current_group); dispose(f); g02_done()

func g02_p1() -> void:
 current_group = G02_GROUPS[2]
 var f: Dictionary = funded_shop(current_group)
 if f.is_empty(): return
 if not buy(f, "final:G02") or not buy(f, "final:B01") or not check(f.session.close_panel().get("accepted", false), "P1 original shop closes") or not g06_enter_original(f, 1, "r01a") or not settle_fixture_combat(f): dispose(f); return
 if not check(command(f, "learn", {"slot":"P", "candidate":"P1", "expected_rank":0}).get("accepted", false), "original row1 earned SP learns P1") or not g06_enter_original(f, 2, "r02a") or not spawn_ready(f): dispose(f); return
 check(f.sim.hero.ranks.passive == 1 and f.sim.hero.loadout.passive == "p1", "real passive slot projects P1 rank1")
 var target: Dictionary = {}
 for enemy: Dictionary in f.sim.living():
  if enemy.kind == "minion" and Vector3(enemy.position).distance_to(f.sim.hero.position) < 9.0: target = enemy; break
 if not check(not target.is_empty(), "original P1 room has a nearby minion"): dispose(f); return
 var nominal: float = G06Design.parameter("yanguizhou", "Q1-1", 1) + float(f.sim.hero.stats.ap) * G06Design.fraction("yanguizhou", "Q1-2", 1)
 var supplement: float = nominal * G06Design.fraction("yanguizhou", "P1-1", 1)
 var left: float = minf(5.0, supplement * 0.5)
 for enemy: Dictionary in f.sim.living():
  if not is_same(enemy, target): check(Vector3(enemy.position).distance_to(target.position) > 3.0 + float(enemy.radius), "short P1 Q1 excludes original sibling")
 if not g02_prepare_hp(f, target, nominal + left): dispose(f); return
 var before: int = int(g02_task(f).progress)
 var released: Dictionary = g02_q1(f, target)
 if released.is_empty(): dispose(f); return
 var cast_id: int = int(released.cast_id)
 check(not target.dead and is_equal_approx(float(target.hp), left) and g02_task(f).progress == before, "real Q1 leaves live target for original atomic P1 settlement")
 for _tick: int in range(140):
  if target.dead: break
  step(f)
 var kill: Dictionary = g02_find_kill(f, str(target.actor_id), "yanguizhou_p1")
 var receipts: Array = g06_p1_receipts(f, cast_id)
 if not check(not kill.is_empty() and receipts.size() == 1, "real P1 terminal owns one actual lethal supplement"): dispose(f); return
 check(receipts[0].supplement_killed and kill.witness.get("witness", {}).get("proof", "") == "original_p1_atomic_death", "G02 authenticates the independent original P1 death path")
 check(g02_task(f).progress == before + 1 and int(task_state(f).progress) == 1, "same original P1 kill advances G02 and B01 once each")
 var saved: Dictionary = g02_protected(f)
 var replay: Dictionary = f.session.observe_event(f.sim, kill.event)
 f.g02_synthetic = true; f.sim.emit_event("kill", kill.event.duplicate(true)); f.g02_synthetic = false
 check(replay.get("accepted", false) and g02_protected(f) == saved, "historical P1 receipt cannot be replayed as another G02 death")
 evidence.p1_g02 = {"kill":kill, "receipt":receipts[0], "nominal_with_original_G02_AP":nominal, "actual_Q1_P1_input":true, "extra_actor":false}
 b04_integrity(f, current_group); dispose(f); g02_done()

func g02_lifecycle() -> void:
 current_group = G02_GROUPS[3]
 var f: Dictionary = funded_shop(current_group)
 if f.is_empty(): return
 if not buy(f, "final:G02") or not buy(f, "final:G02") or not check(f.session.close_panel().get("accepted", false), "original lifecycle shop closes"): dispose(f); return
 var equivalent: int = 0
 var deaths: int = 0
 var held: bool = true
 var rank_counts: Dictionary = {"ordinary":0, "elite":0, "boss":0}
 for row: int in range(1, 13):
  if not enter(f, row): dispose(f); return
  if f.session.status == "service":
   if not check(f.session.complete_service().get("accepted", false), "original service completes"): dispose(f); return
   if row == 3:
    if not g02_open(f) or not buy(f, "final:G02") or not buy(f, "final:G02"): dispose(f); return
    check(g02_task(f).progress == equivalent and equivalent == 6, "repurchase resumes frozen6 after real unequipped room")
    if not check(f.session.close_panel().get("accepted", false), "repurchased original shop closes"): dispose(f); return
    held = true
   continue
  if not spawn_ready(f): dispose(f); return
  for enemy: Dictionary in f.sim.enemies.duplicate():
   var rank: String = enemy.rank_category
   var weight: int = 25 if rank == "boss" else 10 if rank == "elite" else 1
   var before: int = int(g02_task(f).progress)
   lethal_enemy_fixture(f, enemy, "G02 original route weights and held-only lifecycle")
   deaths += 1; rank_counts[rank] += 1
   if held: equivalent += weight
   check(int(g02_task(f).progress) == equivalent and int(g02_task(f).progress) - before == (weight if held else 0), "original roster " + rank + " adds exact held-only weight")
  if not settle_original_row(f, row): dispose(f); return
  if row == 1:
   if not g02_open(f): dispose(f); return
   var protected: Dictionary = g02_protected(f)
   sell(f, "final:G02")
   check(owned_count(f, "final:G02") == 1 and g02_protected(f) == protected, "sell one of two retains task")
   undo(f)
   check(owned_count(f, "final:G02") == 2 and g02_protected(f) == protected, "original sale undo preserves task progress")
   sell(f, "final:G02"); sell(f, "final:G02")
   check(g02_protected(f) == protected and owned_count(f, "final:G02") == 0, "last sale freezes task6")
   if not check(f.session.close_panel().get("accepted", false), "sold-empty original shop closes"): dispose(f); return
   held = false
 check(deaths == 40 and equivalent == 69 and rank_counts == {"ordinary":38, "elite":1, "boss":1}, "original40 actor route yields73 total minus4 unequipped=69")
 check(not g02_task(f).completed and int(f.session.ledger.model.state.bonus_sp) == 0, "actual first-floor route remains below500 and grants no G02 SP")
 evidence.route_g02 = {"route":B01_ROUTE, "actual_original_deaths":deaths, "weights":rank_counts, "held_equivalents":equivalent, "all_held_route_equivalents":73, "authoritative_maximum_first_floor":79, "task":g02_protected(f), "complete_original_floor":f.session.status == "completed", "natural_play":false, "500_completed":false}
 b04_integrity(f, current_group); dispose(f); g02_done()

func g02_extra_rejected() -> void:
 current_group = G02_GROUPS[4]
 var f: Dictionary = funded_shop(current_group)
 if f.is_empty(): return
 if not buy(f, "final:G02") or not check(f.session.close_panel().get("accepted", false), "admission-negative shop closes") or not enter(f, 1) or not spawn_ready(f): dispose(f); return
 var roster: Array = f.session.expected_enemies.duplicate()
 var before: Dictionary = g02_protected(f)
 var gold: int = f.session.ledger.model.state.gold
 var xp: int = f.session.ledger.model.state.xp
 var enemy: Dictionary = f.sim.spawn_enemy("elite", f.sim.hero.position + Vector3(0, 0, -4), 1.0)
 for _tick: int in range(100):
  if enemy.state != "spawn": break
  step(f)
 check(not enemy.dead and enemy.state != "spawn", "declared extra source actor completes original spawn grace")
 f.sim.damage_enemy(enemy, 100000.0, "equipment39_extra_actor_negative", 0, true, false, {"fixture":true, "direct":false, "no_reactions":true})
 if not check(enemy.dead and f.g02_kills.size() == 1, "extra actor actually dies through the source"): dispose(f); return
 var record: Dictionary = f.g02_kills[0]
 check(not record.witness.is_empty() and not record.original_roster, "live source witness does not imply original Session roster admission")
 check(f.event_errors.size() == 1 and f.event_errors[0].result.get("reason", "") == "enemy_not_in_entered_roster", "unchanged Session rejects extra actor before the Model")
 check(g02_protected(f) == before and f.session.ledger.model.state.gold == gold and f.session.ledger.model.state.xp == xp and f.session.kill_receipts.is_empty(), "rejected extra source death changes no G02 progress/SP/gold/XP/route reward")
 check(f.session.expected_enemies == roster and f.session.fault.is_empty(), "test never rewrites original roster or substitutes Session authority")
 check_owners(f, "extra actor negative")
 evidence.extra_actor_g02 = {"record":record, "denial":f.event_errors[0], "Model_direct_fallback_called":false, "route_advanced":false, "productionSession":true, "extra_actor_fixture_only":true}
 dispose(f); g02_done()

func run() -> void:
 evidence = {"wallet_fixtures":[], "inputs":[], "cooldown_fixtures":[], "completions":[], "aborts":[], "victory":[], "postcompletion":[], "lifecycle":[], "isolated_common":[], "movement":[], "g02_deaths":[], "pre_damage":[], "inputs_g02":[], "p1_g02":{}, "route_g02":{}, "extra_actor_g02":{}}
 if G02_GROUPS[0] in g02_required: g02_definitions()
 if G02_GROUPS[1] in g02_required: g02_inputs()
 if G02_GROUPS[2] in g02_required: g02_p1()
 if G02_GROUPS[3] in g02_required: g02_lifecycle()
 if G02_GROUPS[4] in g02_required: g02_extra_rejected()
 finish()

func finish() -> void:
 check(g02_groups == g02_required, "all selected original G02 source groups reached")
 var report: Dictionary = {"suite":"equipment39_g02_original_Host_Session_source", "passed":failures.is_empty() and g02_groups == g02_required, "runtime_status":"EXECUTED", "partition":g02_partition, "checks":checks, "failures":failures, "check_records":check_records, "required_groups":g02_required, "completed_groups":g02_groups, "evidence":evidence, "productionSession":true, "original_Host_factories":true, "source_damage_fixture":true, "wallet_fixture":true, "route_actor_HP_rank_position_AI_written":false, "extra_actor_only_in_admission_negative":true, "direct_Model_fallback_after_Session_denial":false, "threshold500_tested_here":false, "authored_first_floor_maximum":79, "natural_play":false, "native_GUI":false, "multiplayer_participation":false, "production_ready":false}
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 if file == null: push_error("Unable to write G02 source report"); quit(2); return
 file.store_string(JSON.stringify(report, "  "))
 var write_error: Error = file.get_error(); file.close()
 print("EQUIPMENT39_G02_SOURCE ", JSON.stringify({"passed":report.passed, "checks":checks, "failures":failures, "result":output_path}))
 quit(2 if write_error != OK else (0 if report.passed else 1))
