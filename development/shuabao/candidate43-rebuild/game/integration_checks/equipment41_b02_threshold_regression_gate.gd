extends "res://integration_checks/equipment41_g02_threshold_regression_gate.gd"
## Same separately bound production Model/Sim/Bridge fixture as frozen G02.
## No Host or Session is ever created. No rejected Session event is retried.
var b02_threshold_deaths: Array=[]
var b02_after_g02_complete: Array=[]

func _initialize() -> void:
 super._initialize()
 if output_path=="user://g02_threshold_source_gate.json":output_path="user://equipment40_b02_threshold_gate.json"

func fresh(items: Array) -> Dictionary:
 var with_b02: Array=items.duplicate()
 with_b02.append("final:B02")
 var f: Dictionary=super.fresh(with_b02)
 if f.is_empty():return {}
 check(f.sim.b02_model_is_bound(f.model) and f.model.equipment_runtime_status("final:B02").get("runtime_complete",false),"standalone formal original B02 common/death/clock binding")
 check(f.sim.common.get_script().resource_path=="res://equipment_pursuit_20261009/common_bridge.gd","standalone uses exact new Common leaf")
 return f

func observe(event: Dictionary,f: Dictionary) -> void:
 var candidate: bool=event.get("kind","")=="kill"
 var before: Dictionary=f.sim.hero.cast_state.get("equipment_passive28",{}).duplicate(true) if candidate else {}
 var prior_g02_complete: bool=bool(f.model._g02_state().completed) if candidate else false
 var witness: Dictionary=f.sim.verify_g02_kill_attribution(f.model,event,f.run_id) if candidate else {}
 var now: float=float(f.sim.common.runtime.actor_time)
 super.observe(event,f) # Original fixture submits once to its own bound Model.
 if not candidate:return
 var after: Dictionary=f.sim.hero.cast_state.get("equipment_passive28",{}).duplicate(true)
 var view: Dictionary=f.model.pursuit_buff_status()
 if not witness.is_empty() and not f.synthetic:
  check(view.active and view.active_copies==1 and not after.is_empty(),"every genuine standalone source death issues one B02 effect")
  near(float(after.granted_at),now,"shared-source B02 uses original common actor time")
  near(float(after.expires_at),now+4.0,"shared-source B02 expiry is current clock plus4")
  near(float(after.move_fraction),0.12,"shared-source B02 move remains unique12percent")
  near(float(after.attack_speed_fraction),0.20,"shared-source B02 attack remains unique20percent")
  var record: Dictionary={"event":event.duplicate(true),"witness":witness,"before":before,"after":after,"prior_G02_complete":prior_g02_complete,"G02":f.model._g02_state(),"B01":f.model.snapshot().b01_equipment,"G06":f.model.snapshot().g06_equipment,"productionSession":false,"natural":false}
  b02_threshold_deaths.append(record)
  if prior_g02_complete:b02_after_g02_complete.append(record)
 else:
  check(after==before,"historical/public corpse event cannot refresh B02 in shared threshold fixture")
 check(not f.model.state.shop_visit.taskLedger.has(str(f.model.state.actor_id)+"|final:B02") and not f.model.state.bonus_awards.has("task:B02"),"B02 adds no task ledger or bonus reward to shared source event")

func run() -> void:
 if GROUPS[0] in required:exact500()
 if GROUPS[1] in required:shared_finish()
 check(completed==required,"all inherited standalone threshold groups complete unchanged")
 if GROUPS[0] in required:check(b02_after_g02_complete.size()==1,"one further genuine death after G02 completion still issues B02")
 if GROUPS[1] in required:
  var shared: Array=b02_threshold_deaths.filter(func(record: Dictionary):return record.G02.completed and record.B01.completed and record.G06.completed)
  check(shared.size()==1 and shared[0].after.expires_at==shared[0].after.granted_at+4.0,"same final real death completes B01/G02/G06 and issues one B02 buff")
 var report: Dictionary={"suite":"equipment40_B02_with_original_G02_threshold_sources","passed":failures.is_empty() and completed==required,"partition":partition,"checks":checks,"failures":failures,"check_records":records,"required_groups":required,"completed_groups":completed,"evidence":evidence,"b02_deaths":b02_threshold_deaths,"after_G02_complete":b02_after_g02_complete,"productionSession":false,"Host_created":false,"Session_created":false,"all_inherited_threshold_assertions_retained":true,"source_API_packet_fixture":true,"source_spawn_HP_override_fixture":true,"natural":false,"natural_first_floor_500":false,"authored_first_floor_maximum":79,"task_progress_written":false,"native_GUI":false,"production_ready":false}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:push_error("Unable to write B02 shared threshold result");quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close()
 print("B02_ORIGINAL_THRESHOLDS ",JSON.stringify({"passed":report.passed,"checks":checks,"failures":failures,"result":output_path}))
 quit(2 if error!=OK else (0 if report.passed else 1))
