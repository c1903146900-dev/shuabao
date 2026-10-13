extends "res://integration_checks/equipment41_b02_regression_gate.gd"
## Actual original Host/Session, original roster and genuine Q1/P1 settlement.
## Notifications are interrupted through original cancel/focus/death/clear APIs.
const P1_BOUNDARIES := ["cancel_after_atomic", "pause_after_atomic", "clear_after_atomic", "death_after_atomic"]
var p1_partition: String = "all"
var p1_required: Array = P1_BOUNDARIES.duplicate()
var p1_completed: Array = []
var p1_boundaries: Array = []

func _initialize() -> void:
 output_path = "user://equipment40_b02_p1_boundaries_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="): output_path = arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--b02-p1-boundary="): p1_partition = arg.trim_prefix("--b02-p1-boundary=")
 if p1_partition != "all":
  if p1_partition not in P1_BOUNDARIES: push_error("Unknown G02 P1 boundary"); quit(2); return
  p1_required = [p1_partition]
 run.call_deferred()

func funded_shop(label: String) -> Dictionary:
 var f: Dictionary = super.funded_shop(label)
 if f.is_empty(): return {}
 if not buy(f,"final:B02"): dispose(f); return {}
 return f

func on_event(event: Dictionary, f: Dictionary) -> void:
 if f.get("p1_boundary_armed", false) and event.get("kind", "") == "damage" and event.get("source", "") == "yanguizhou_p1":
  f.p1_boundary_armed = false
  f["p1_notification"] = event.duplicate(true)
  var target: Dictionary = f.sim.enemy_by_id(str(event.target))
  var receipt: Array = g06_p1_receipts(f, int(event.cast_id))
  f["b02_before_atomic_notification"] = b02_raw(f)
  f["b02_clock_at_notification"] = b02_now(f)
  check(not target.is_empty() and target.dead and float(target.hp) == 0.0 and receipt.size() == 1 and receipt[0].supplement_killed, "P1 HP/death/receipt atomically committed before the hostile observer")
  f["p1_receipt_at_notification"] = receipt.duplicate(true)
  match str(f.p1_boundary):
   "cancel_after_atomic": f.sim.cancel_cast(int(event.cast_id))
   "pause_after_atomic":
    f.session.focus_lost()
    check(f.sim.paused, "original Session focus-loss API pauses during P1 notification")
   "clear_after_atomic":
    f.sim.end_encounter("g02_p1_notification_clear")
    check(f.sim.phase != "combat", "original source end_encounter clears old P1 scope")
   "death_after_atomic":
    f.sim.damage_hero(float(f.sim.hero.hp) + 100000.0, Vector3.ZERO, 0.0, true, true, {"source":"g02_p1_notification_death_fixture", "fixture":true})
    check(f.sim.hero.dead and f.sim.phase == "true_dead", "original source damage commits hero death during P1 notification")
 super.on_event(event, f) # Exactly one original Session observer; no Model fallback.

func p1_boundary(mode: String) -> void:
 current_group = mode
 var f: Dictionary = funded_shop(mode)
 if f.is_empty(): return
 if not buy(f, "final:G02") or not buy(f, "final:B01") or not check(f.session.close_panel().get("accepted", false), "P1 boundary original shop closes") or not g06_enter_original(f, 1, "r01a") or not settle_fixture_combat(f): dispose(f); return
 if not check(command(f, "learn", {"slot":"P", "candidate":"P1", "expected_rank":0}).get("accepted", false), "original earned SP learns P1 for boundary") or not g06_enter_original(f, 2, "r02a") or not spawn_ready(f): dispose(f); return
 check(f.sim.hero.ranks.passive == 1 and f.sim.hero.loadout.passive == "p1", "boundary uses original projected learned P1")
 var target: Dictionary = {}
 for enemy: Dictionary in f.sim.living():
  if enemy.kind == "minion" and Vector3(enemy.position).distance_to(f.sim.hero.position) < 9.0: target = enemy; break
 if not check(not target.is_empty(), "original P1 roster contains a reachable Q1 target"): dispose(f); return
 var nominal: float = G06Design.parameter("yanguizhou", "Q1-1", 1) + float(f.sim.hero.stats.ap) * G06Design.fraction("yanguizhou", "Q1-2", 1)
 var left: float = minf(5.0, nominal * G06Design.fraction("yanguizhou", "P1-1", 1) * 0.5)
 for enemy: Dictionary in f.sim.living():
  if not is_same(enemy, target): check(Vector3(enemy.position).distance_to(target.position) > 3.0 + float(enemy.radius), "boundary short Q1 excludes original sibling")
 if not g02_prepare_hp(f, target, nominal + left): dispose(f); return
 var before: Dictionary = g02_protected(f)
 f["p1_boundary"] = mode
 f["p1_boundary_armed"] = true
 f["p1_notification"] = {}
 f["p1_receipt_at_notification"] = []
 var released: Dictionary = g02_q1(f, target)
 if released.is_empty(): dispose(f); return
 check(not target.dead and is_equal_approx(float(target.hp), left), "genuine Q1 leaves target alive for independent P1 atomic death")
 for _tick: int in range(140):
  if not f.p1_boundary_armed: break
  step(f)
 if not check(not f.p1_boundary_armed and not f.p1_notification.is_empty(), "original P1 atomic notification actually reaches selected boundary"): dispose(f); return
 var kill: Dictionary = g02_find_kill(f, str(target.actor_id), "yanguizhou_p1")
 var should_count: bool = mode in ["cancel_after_atomic", "pause_after_atomic"]
 if should_count:
  check(not kill.is_empty() and kill.witness.get("witness", {}).get("proof", "") == "original_p1_atomic_death", "already committed same-room P1 death retains original authenticated kill")
  check(int(g02_task(f).progress) == int(before.task.progress) + 1, "G02 counts committed P1 death once after cancellation or pause")
 else:
  check(kill.is_empty() and g02_protected(f) == before, "cleared/dead source suppresses old-room P1 kill and task credit")
 if should_count:
  check(b02_raw(f).origin_scope == kill.witness.witness.scope and b02_view(f).active, "same-room original committed P1 death issues current B02 buff after cancel/pause")
  near_number(float(b02_raw(f).granted_at),float(f.b02_clock_at_notification),"P1 B02 grant uses same atomic notification actor time")
  near_number(float(b02_raw(f).expires_at),float(f.b02_clock_at_notification)+4.0,"P1 B02 refreshes to one new four-second expiry")
 else:
  check(b02_raw(f) == f.b02_before_atomic_notification,"invalidated P1 notification cannot replace the previously issued B02 record")
  if mode == "death_after_atomic": check(not b02_view(f).active,"dead original owner cannot project prior B02 effect")
 check(int(f.session.ledger.model.state.bonus_sp) == int(before.bonus_sp), "subthreshold P1 boundary cannot grant task SP")
 p1_boundaries.append({"mode":mode, "before":before, "after":g02_protected(f), "atomic_damage":f.p1_notification, "atomic_receipt":f.p1_receipt_at_notification, "original_kill":kill, "original_roster":f.session.expected_enemies.duplicate(), "event_errors":f.event_errors.duplicate(true), "source_phase":f.sim.phase, "paused":f.sim.paused, "productionSession":true, "actual_Q1_P1_input":true, "extra_actor":false, "same_id_hero_replacement":false, "direct_Model_fallback":false})
 dispose(f); p1_completed.append(mode)

func run() -> void:
 evidence = {"wallet_fixtures":[], "inputs":[], "cooldown_fixtures":[], "completions":[], "aborts":[], "victory":[], "postcompletion":[], "lifecycle":[], "isolated_common":[], "movement":[], "g02_deaths":[], "pre_damage":[], "inputs_g02":[], "p1_g02":{}, "route_g02":{}, "extra_actor_g02":{}}
 for mode: String in p1_required: p1_boundary(mode)
 check(p1_completed == p1_required, "all selected original P1 boundaries reached")
 var report: Dictionary = {"suite":"equipment40_B02_actual_P1_notification_boundaries", "passed":failures.is_empty() and p1_completed == p1_required, "checks":checks, "failures":failures, "check_records":check_records, "partition":p1_partition, "required_groups":p1_required, "completed_groups":p1_completed, "evidence":evidence, "p1_boundaries":p1_boundaries, "b02_deaths":b02_records, "productionSession":true, "original_Host_factories":true, "actual_Q1_P1_input":true, "source_damage_preparation_fixture":true, "extra_actors":false, "task_progress_written":false, "native_GUI":false, "production_ready":false}
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 if file == null: push_error("Unable to write P1 boundary result"); quit(2); return
 file.store_string(JSON.stringify(report, "  ")); var error: Error = file.get_error(); file.close()
 print("B02_ACTUAL_P1_BOUNDARIES ", JSON.stringify({"passed":report.passed, "checks":checks, "failures":failures, "result":output_path}))
 quit(2 if error != OK else (0 if report.passed else 1))
