extends "res://integration_checks/d03_regen_gate.gd"
var d03_lifecycle_case: String="terminal"
func _initialize() -> void:
 output_path="user://d03_lifecycle.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--d03-lifecycle-case="):d03_lifecycle_case=arg.trim_prefix("--d03-lifecycle-case=")
 if d03_lifecycle_case not in ["terminal","death"]:quit(2);return
 run.call_deferred()
func d03_lifecycle() -> void:
 current_group=E03_GROUPS[2]
 var f: Dictionary=e03_start(current_group)
 if f.is_empty():return
 if not e03_until(f,6.05,"firstcombat") or not b04_settle_row(f,1):dispose(f);return
 check(not e03_view(f).active and f.sim.phase=="victory","original true terminal immediately removes E03 condition")
 e03_projection(f,"terminal")
 var now: float=e03_now(f)
 var hp: float=f.sim.hero.hp
 step(f,20)
 check(e03_now(f)==now and f.sim.hero.hp==hp,"safephase neither advances combatclock nor naturalregen")
 if not g02_open(f):dispose(f);return
 sell(f,D03);e03_projection(f,"soldempty")
 buy(f,D03);e03_projection(f,"reboughtsafe")
 undo(f);check(owned_count(f,D03)==0,"repurchaseundo removes item without restoring oldcombat")
 undo(f);check(owned_count(f,D03)==1,"saleundo restores helditem only")
 if not check(f.session.close_panel().get("accepted",false),"lifecycle shopcloses") or not e03_enter(f,2) or not spawn_ready(f):dispose(f);return
 check(e03_now(f)>6.0 and not e03_view(f).active,"new original combat waits6 despite runclock already above6")
 if not e03_damage_deficit(f,150.0,"secondcombat deficit") or not e03_tick(f,"secondcombat firstsample"):dispose(f);return
 e03_records.append({"kind":"original_shop_next_room","view":e03_view(f),"run_clock":e03_now(f),"combat_start":f.e03_combat_start,"original_roster":f.session.expected_enemies.duplicate(true)})
 b04_integrity(f,current_group);dispose(f);e03_completed.append(current_group)

func d03_death() -> void:
 current_group="death"
 var f: Dictionary=e03_start(current_group)
 if f.is_empty():return
 if not e03_until(f,6.05,"before original death"):dispose(f);return
 check(e03_view(f).active,"D03 active before original fatal damage fixture")
 f.sim.damage_hero(float(f.sim.hero.hp)+100000.0,Vector3.ZERO,0.0,true,true,{"source":"d03_explicit_fatal_fixture","no_reactions":true})
 f.session.update_after_source_step()
 check(f.sim.hero.dead and not e03_view(f).active and float(e03_view(f).factor)==1.0,"original fatal damage immediately clears D03 regen eligibility")
 var hp: float=f.sim.hero.hp
 var now: float=e03_now(f)
 step(f,20)
 check(f.sim.hero.hp==hp and e03_now(f)==now,"original death does not heal or advance actor clock")
 d03_note(f,"actual death");dispose(f);e03_completed.append("death")
func run() -> void:
 g03_reset_evidence()
 if d03_lifecycle_case=="terminal":d03_lifecycle()
 else:d03_death()
 check(e03_completed==[E03_GROUPS[2] if d03_lifecycle_case=="terminal" else "death"],"entire selected D03 lifecycle group completed")
 await process_frame
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"case":d03_lifecycle_case,"records":d03_records,"e03_records":e03_records,"fixtures":e03_source_fixtures,"wallet_fixture":true,"source_settlement_and_health_fixture":true,"natural_play":false,"GUI_verified":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close();quit(0 if report.passed and error==OK else 2)
