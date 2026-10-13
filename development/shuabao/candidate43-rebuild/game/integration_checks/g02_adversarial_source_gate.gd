extends "res://integration_checks/g02_threshold_source_gate.gd"
## Exact production Sim/Bridge/Model with adversarial source notification observers.
## Never creates Host or Session. The only actor replacement is a labelled
## negative fixture, using another unchanged original Sim constructor's hero.
const ATTACKS := ["damage_fake_emit", "damage_premature_kill", "damage_same_id_owner", "kill_same_id_owner", "damage_room_change", "kill_room_change", "damage_true_death", "kill_true_death", "original_cast_zero"]
var attack_partition: String = "all"
var attack_required: Array = ATTACKS.duplicate()
var attack_completed: Array = []
var adversarial: Array = []

func _initialize() -> void:
 output_path = "user://g02_adversarial_source_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="): output_path = arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--g02-attack="): attack_partition = arg.trim_prefix("--g02-attack=")
 if attack_partition != "all":
  if attack_partition not in ATTACKS: push_error("Unknown G02 exact-source attack"); quit(2); return
  attack_required = [attack_partition]
 run.call_deferred()

func attack_protected(f: Dictionary) -> Dictionary:
 return {"task":task(f.model), "ledger":task_ledger(f.model), "completed":f.model.state.completed_equipment_tasks.duplicate(true), "awards":f.model.state.bonus_awards.duplicate(true), "bonus_sp":f.model.state.bonus_sp, "points":f.model.state.points}

func observe(event: Dictionary, f: Dictionary) -> void:
 var matches: bool = f.get("armed", false) and event.get("kind", "") == f.get("trigger", "") and event.get("source", "") == "g02_adversarial_packet"
 if matches:
  f.armed = false
  var attack: String = str(f.attack)
  f["trigger_event"] = event.duplicate(true)
  f["witness_before_attack"] = f.sim.verify_g02_kill_attribution(f.model, event, f.run_id) if event.kind == "kill" else {}
  if attack == "damage_fake_emit":
   var enemy: Dictionary = f.target
   f.synthetic = true
   f.sim.emit_event("kill", {"target":enemy.actor_id, "position":enemy.position, "source":event.source, "cast_id":event.cast_id, "credit":"solo_lethal", "enemy_kind":enemy.kind})
   f.synthetic = false
   check(not enemy.dead and float(enemy.hp) > 0.0, "forged damage-observer kill cannot make a real death")
  elif attack == "damage_premature_kill":
   # Intentional negative call to the original kill routine while HP is still
   # positive. Its outward kill is NOT an authenticated original lethal packet.
   f.sim._kill_enemy(f.target, str(event.source), int(event.cast_id))
  elif attack in ["damage_same_id_owner", "kill_same_id_owner"]:
   check(not is_same(f.original_hero, f.donor.hero) and f.original_hero.actor_id == f.donor.hero.actor_id, "same-id negative uses two separately constructed original hero objects")
   f.sim.hero = f.donor.hero
   f["owner_replaced"] = true
  elif attack in ["damage_room_change", "kill_room_change"]:
   f.sim.end_encounter("g02_adversarial_room_exit")
   f["new_room_accepted"] = start_room(f, [{"kind":"minion", "hp":1.0}])
  elif attack in ["damage_true_death", "kill_true_death"]:
   f.sim.damage_hero(float(f.sim.hero.hp) + 100000.0, Vector3.ZERO, 0.0, true, true, {"source":"g02_adversarial_original_death", "fixture":true})
   check(f.sim.hero.dead and f.sim.phase == "true_dead", "notification reentry uses original actual hero death")
  f["after_attack_before_submission"] = attack_protected(f)
 # One observer directly invokes only this standalone Model. No Session exists,
 # and no event rejected by a Session is ever submitted through this path.
 super.observe(event, f)

func run_attack(mode: String) -> void:
 current = mode
 var f: Dictionary = fresh(["final:G02", "final:G02"])
 if f.is_empty(): return
 if not start_room(f, [{"kind":"minion", "hp":10.0}, {"kind":"minion", "hp":1.0}]): dispose(f); return
 f["attack"] = mode
 f["trigger"] = "kill" if mode.begins_with("kill_") else "damage"
 f["target"] = f.sim.enemies[0]
 f["original_hero"] = f.sim.hero
 f["owner_replaced"] = false
 f["armed"] = mode != "original_cast_zero"
 f["trigger_event"] = {}
 f["witness_before_attack"] = {}
 var donor = Sim.new()
 f["donor"] = donor
 var before: Dictionary = attack_protected(f)
 var old_generation: int = f.sim.encounter_generation
 var original_target: Dictionary = f.target
 var count: int = f.kills.size()
 var id: int = 0
 if mode != "original_cast_zero": id = int(f.sim.new_cast("q", "g02_adversarial_original_packet").cast_id)
 var nominal: float = 1.0 if mode in ["damage_fake_emit", "damage_premature_kill"] else 100000.0
 var result: bool = f.sim.damage_enemy(original_target, nominal, "g02_adversarial_packet", id, true, false, {"fixture":true, "direct":true, "active_skill":false, "no_reactions":true, "generation":old_generation, "room_id":f.sim.room_id})
 var after: Dictionary = attack_protected(f)
 var attacked_kills: Array = f.kills.slice(count)
 if mode == "original_cast_zero":
  check(result and original_target.dead and f.sim.cast_is_current(0), "original core explicitly accepts cast zero actual damage/death")
  check(attacked_kills.size() == 1 and not attacked_kills[0].live_witness.is_empty() and int(task(f.model).progress) == 1, "one genuine cast-zero death counts G02 exactly once despite two copies")
 else:
  check(not f.armed and not f.trigger_event.is_empty(), "requested adversarial notification boundary was actually reached")
  check(after == before, "notification attack cannot grant G02 progress or SP: " + mode)
  for record: Dictionary in attacked_kills:
   check(record.live_witness.is_empty() and record.before == record.after, "every adversarial original/counterfeit kill lacks a dynamic eligible death witness")
  if mode.begins_with("kill_"): check(not f.witness_before_attack.is_empty(), "real original kill had a live witness before observer invalidated its owner/scope")
  if mode == "damage_premature_kill": check(original_target.dead and attacked_kills.size() == 1, "forced early original kill emits once but cannot borrow nonlethal damage")
  if mode.ends_with("room_change"): check(f.get("new_room_accepted", false) and f.sim.encounter_generation > old_generation, "original room APIs commit a genuinely new source generation")
 # Restore only the exact original object after the entire hostile source call
 # has unwound. No property (HP, position, rank, cooldown, progress) is copied.
 if f.owner_replaced:
  f.sim.hero = f.original_hero
  check(f.sim.verify_g02_kill_attribution(f.model, f.trigger_event, f.run_id).is_empty(), "restoring original owner cannot revive the expired old notification")
 var resume_record: Dictionary = {}
 if mode != "original_cast_zero" and not mode.ends_with("true_death"):
  var fresh_target: Dictionary = f.sim.enemies[0] if mode.ends_with("room_change") else f.sim.enemies[1]
  resume_record = kill_packet(f, fresh_target)
  check(not resume_record.is_empty() and int(task(f.model).progress) == 1, "a later new legitimate packet remains countable after the rejected notification")
 adversarial.append({"mode":mode, "before":before, "after_attacked_call":after, "trigger":f.trigger_event, "live_witness_before_mutation":f.witness_before_attack, "attacked_kills":attacked_kills, "new_source_death_after_rejection":resume_record, "declared_observer_denials":f.errors, "productionSession":false, "Host_created":false, "Session_created":false, "same_id_owner_replacement_fixture":f.owner_replaced, "natural":false})
 donor.free()
 dispose(f)
 attack_completed.append(mode)

func run() -> void:
 for mode: String in attack_required: run_attack(mode)
 check(attack_completed == attack_required, "all selected exact-source adversarial boundaries reached")
 var report: Dictionary = {"suite":"g02_exact_source_adversarial_notifications", "passed":failures.is_empty() and attack_completed == attack_required, "checks":checks, "failures":failures, "check_records":records, "partition":attack_partition, "required_groups":attack_required, "completed_groups":attack_completed, "evidence":evidence, "adversarial":adversarial, "productionSession":false, "Host_created":false, "Session_created":false, "natural":false, "task_progress_written":false, "native_GUI":false, "hero_killed_recursive_case_executed":false, "hero_killed_recursion_limit":"Original inherited hook exposes no outward callback; exact source binding rejects a subclass. No fake owner or binding bypass is used.", "production_ready":false}
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 if file == null: push_error("Unable to write adversarial result"); quit(2); return
 file.store_string(JSON.stringify(report, "  ")); var error: Error = file.get_error(); file.close()
 print("G02_EXACT_ADVERSARIAL ", JSON.stringify({"passed":report.passed, "checks":checks, "failures":failures, "result":output_path}))
 quit(2 if error != OK else (0 if report.passed else 1))
