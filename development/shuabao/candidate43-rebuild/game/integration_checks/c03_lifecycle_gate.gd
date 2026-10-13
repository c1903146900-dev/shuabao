extends "res://integration_checks/c03_release_gate.gd"
var c03_lifecycle: String="clock"
var c03_lifecycle_records: Array=[]
var c03_lifecycle_completed: Array=[]
func _initialize()->void:
 output_path="user://c03_lifecycle.json"
 c03_family="q1"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--c03-lifecycle="):c03_lifecycle=arg.trim_prefix("--c03-lifecycle=")
 if c03_lifecycle not in ["clock","terminal","death"]:quit(2);return
 run.call_deferred()
func lifecycle_start()->Dictionary:
 var f: Dictionary=funded_shop("C03 actual lifecycle "+c03_lifecycle)
 if f.is_empty():return {}
 if not buy(f,C03) or not check(f.session.close_panel().accepted,"original lifecycle shop closes") or not enter(f,1) or not spawn_ready(f) or not b04_ready(f):dispose(f);return {}
 var point: Vector3=f.sim.hero.position+Vector3(.5,0,0)
 if not check(f.sim.request_ink_input("q_down").accepted,"lifecycle Q1 original armed") or not check(f.sim.request_ink_input("left_down",point).accepted,"lifecycle Q1 original drawing") or not check(f.sim.request_ink_input("motion",point+Vector3(.26,0,0)).accepted,"lifecycle Q1 original path") or not check(f.sim.request_ink_input("left_up",point+Vector3(.26,0,0)).accepted,"lifecycle Q1 original release"):dispose(f);return {}
 if not check(f.session.ledger.model.c03_buff_effect(f.sim).stacks==1,"real original release grants one lifecycle stack"):dispose(f);return {}
 return f
func lifecycle_clock()->void:
 var f: Dictionary=lifecycle_start()
 if f.is_empty():return
 var model=f.session.ledger.model
 var saved: Dictionary=f.sim.hero.cast_state[OverloadFormula.BUFF_KEY].duplicate(true)
 var start: float=float(f.sim.common.runtime.actor_time)
 var before_ap: float=float(f.sim.hero.stats.ap)
 var before_ms: float=float(f.sim.hero.stats.move_speed)
 var projected_ms: float=float(f.sim.hero.projected_base_stats.move_speed)
 near_number(saved.expires_at,start+4.0,"actual release deadline is actor time plus4")
 if not check(f.session.set_modal_blocked(true).accepted,"original modal pause API accepted"):dispose(f);return
 step(f,20)
 check(float(f.sim.common.runtime.actor_time)==start and f.sim.hero.cast_state.get(OverloadFormula.BUFF_KEY,{})==saved and model.c03_buff_effect(f.sim).stacks==1,"original paused steps freeze clock and stack")
 if not check(f.session.set_modal_blocked(false).accepted,"original modal resume API accepted"):dispose(f);return
 var samples: Array=[]
 for tick in range(220):
  if not check(f.sim.phase=="combat" and not f.sim.hero.dead,"original live combat remains available through duration"):dispose(f);return
  var previous: float=float(f.sim.common.runtime.actor_time)
  step(f)
  var now: float=float(f.sim.common.runtime.actor_time)
  f.sim.common.refresh_stats()
  var effect: Dictionary=model.c03_buff_effect(f.sim)
  check(now>previous,"original actor clock advances without private clock write")
  check(bool(effect.active)==(now<float(saved.expires_at)),"active duration follows original actor time")
  if now>=float(saved.expires_at)-.04:samples.append({"actor_time":now,"effect":effect,"AP":f.sim.hero.stats.ap,"MS":f.sim.hero.stats.move_speed})
  if now>=float(saved.expires_at):break
 check(float(f.sim.common.runtime.actor_time)>=float(saved.expires_at) and not model.c03_buff_effect(f.sim).active,"original4second boundary actually reached and expired")
 near_number(f.sim.hero.stats.ap,before_ap-10.0,"expiry removes only C03 AP10")
 near_number(f.sim.hero.stats.move_speed,before_ms-projected_ms*.02,"expiry removes only C03 MS fraction")
 c03_lifecycle_records.append({"case":"clock","initial_buff":saved,"actor_start":start,"boundary_samples":samples,"HP":f.sim.hero.hp})
 c03_lifecycle_completed.append("clock");dispose(f)
func lifecycle_terminal()->void:
 var f: Dictionary=lifecycle_start()
 if f.is_empty():return
 var saved: Dictionary=f.sim.hero.cast_state[OverloadFormula.BUFF_KEY].duplicate(true)
 var before_terminal: float=float(f.sim.common.runtime.actor_time)
 if not check(f.session.ledger.model.c03_buff_effect(f.sim).active and before_terminal<float(saved.expires_at),"actual stack active immediately before original terminal fixture"):dispose(f);return
 if not b04_settle_row(f,1):dispose(f);return
 check(float(f.sim.common.runtime.actor_time)>=before_terminal and float(f.sim.common.runtime.actor_time)<float(saved.expires_at),"battle-end removal occurs before natural expiry on monotonic actor clock")
 check(f.sim.phase=="victory" and not f.sim.hero.cast_state.has(OverloadFormula.BUFF_KEY) and not f.session.ledger.model.c03_buff_effect(f.sim).active,"original battle-end removes actual active stack")
 if not g02_open(f) or not sell(f,C03):dispose(f);return
 check(owned_count(f,C03)==0 and not f.sim.hero.cast_state.has(OverloadFormula.BUFF_KEY),"safe final sale leaves no buff")
 if not undo(f):dispose(f);return
 check(owned_count(f,C03)==1 and not f.sim.hero.cast_state.has(OverloadFormula.BUFF_KEY),"sale undo restores item without old stack")
 if not sell(f,C03) or not buy(f,C03):dispose(f);return
 check(not f.sim.hero.cast_state.has(OverloadFormula.BUFF_KEY),"safe repurchase cannot resurrect stack")
 if not check(f.session.close_panel().accepted,"safe lifecycle shop closes") or not enter(f,2) or not spawn_ready(f):dispose(f);return
 check(not f.sim.hero.cast_state.has(OverloadFormula.BUFF_KEY) and not f.session.ledger.model.c03_buff_effect(f.sim).active,"next original combat starts without prior stack")
 c03_lifecycle_records.append({"case":"terminal","original_buff":saved,"actor_before_terminal":before_terminal,"next_room":f.sim.room_id,"next_generation":f.sim.encounter_generation,"inventory":f.session.ledger.model.state.inventory.duplicate(true)})
 c03_lifecycle_completed.append("terminal");dispose(f)
func lifecycle_death()->void:
 var f: Dictionary=lifecycle_start()
 if f.is_empty():return
 var saved: Dictionary=f.sim.hero.cast_state[OverloadFormula.BUFF_KEY].duplicate(true)
 var before_death: float=float(f.sim.common.runtime.actor_time)
 if not check(f.session.ledger.model.c03_buff_effect(f.sim).active and before_death<float(saved.expires_at),"actual stack active immediately before original fatal fixture"):dispose(f);return
 f.sim.damage_hero(float(f.sim.hero.hp)+100000.0,Vector3.ZERO,0.0,true,true,{"source":"c03_explicit_fatal_fixture","no_reactions":true})
 f.session.update_after_source_step()
 check(f.sim.hero.dead and not f.sim.hero.cast_state.has(OverloadFormula.BUFF_KEY) and not f.session.ledger.model.c03_buff_effect(f.sim).active,"original true death clears actual active stack")
 var now: float=float(f.sim.common.runtime.actor_time)
 check(now==before_death and now<float(saved.expires_at),"fatal removal precedes natural expiry without advancing clock")
 step(f,20)
 check(float(f.sim.common.runtime.actor_time)==now and not f.sim.hero.cast_state.has(OverloadFormula.BUFF_KEY),"post-death original steps cannot advance or restore stack")
 c03_lifecycle_records.append({"case":"death","original_buff":saved,"actor_before_death":before_death,"HP":f.sim.hero.hp,"status":f.session.status})
 c03_lifecycle_completed.append("death");dispose(f)
func run()->void:
 g03_reset_evidence()
 if c03_lifecycle=="clock":lifecycle_clock()
 elif c03_lifecycle=="terminal":lifecycle_terminal()
 else:lifecycle_death()
 check(c03_lifecycle_completed==[c03_lifecycle],"entire requested original lifecycle case completed")
 await process_frame
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"case":c03_lifecycle,"completed":c03_lifecycle_completed,"records":c03_lifecycle_records,"wallet_fixture":60000,"source_settlement_fixture":c03_lifecycle=="terminal","source_fatal_fixture":c03_lifecycle=="death","modal_API_fixture":c03_lifecycle=="clock","private_clock_or_HP_write":false,"natural_play":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var err: Error=file.get_error();file.close();quit(0 if report.passed and err==OK else 2)
