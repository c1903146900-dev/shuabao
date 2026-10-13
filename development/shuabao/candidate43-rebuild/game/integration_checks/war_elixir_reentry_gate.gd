extends "res://integration_checks/war_elixir_source_gate.gd"
## Counterfeit public notification is sent only inside a real admitted-roster
## death callback. This checks the new buff consumer, not new Session policy.
var reentry_records: Array=[]
func _initialize() -> void:
 output_path="user://war_reentry.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
 run.call_deferred()
func on_event(event: Dictionary,f: Dictionary) -> void:
 var capture: bool=f.get("war_reentry_armed",false) and event.get("kind","")=="kill"
 var row: Dictionary={}
 if capture:
  f.war_reentry_armed=false
  var model=f.session.ledger.model
  row={"original_event":event.duplicate(true),"before_buff":f.sim.hero.cast_state.get("elixir_war_on_kill",{}).duplicate(true),"before_claims":model.state.get("war_death_claims",{}).duplicate(true)}
  f.g02_synthetic=true
  f.sim.emit_event("kill",event.duplicate(true))
  f.g02_synthetic=false
  check(f.sim.hero.cast_state.get("elixir_war_on_kill",{})==row.before_buff and model.state.get("war_death_claims",{})==row.before_claims,"nested public matching kill cannot borrow outer death witness for war")
 super.on_event(event,f)
 if capture:
  var model=f.session.ledger.model
  row["after_buff"]=f.sim.hero.cast_state.get("elixir_war_on_kill",{}).duplicate(true)
  row["after_claims"]=model.state.get("war_death_claims",{}).duplicate(true)
  check(not row.after_buff.is_empty(),"original emission still grants once after counterfeit nested notification")
  for i in range(2):model.record_battle_event(f.sim,event,f.session.run_id)
  check(f.sim.hero.cast_state.get("elixir_war_on_kill",{})==row.after_buff and model.state.get("war_death_claims",{})==row.after_claims,"same currently valid original emission repeated twice cannot refresh or duplicate corpse claim")
  reentry_records.append(row)
func reentry_case() -> void:
 var f: Dictionary=funded_shop("war_reentry")
 if f.is_empty():return
 if not buy(f,WAR) or not check(shop_command(f,"consume",{"uid":war_uid(f)}).accepted,"actual original war drink") or not check(f.session.close_panel().accepted,"close original shop") or not enter(f,1) or not spawn_ready(f):dispose(f);return
 f["war_reentry_armed"]=true
 lethal_enemy_fixture(f,f.sim.living()[0],"war live-emission reentry source damage fixture")
 check(not f.war_reentry_armed and reentry_records.size()==1,"one actual death reaches callback and bounded reentry test")
 dispose(f)
func run() -> void:
 g03_reset_evidence();reentry_case();await process_frame
 check(reentry_records.size()==1,"reentry case complete")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"records":reentry_records,"economic_fixture":true,"source_lethal_fixture":true,"counterfeit_public_notification_fixture":true,"natural_play":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var err: Error=file.get_error();file.close();quit(0 if report.passed and err==OK else 2)
