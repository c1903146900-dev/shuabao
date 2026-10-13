extends "res://integration_checks/swift05_source_gate.gd"
const SwiftGateRuntime=preload("res://elixir_swift_20261010/runtime.gd")
var swift_shift_samples: Array=[]
var swift_active_fixture: Dictionary={}
var swift_shift_attempts: Array=[]
func _initialize()->void:
 output_path="user://swift_shift.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
 run.call_deferred()
func swift_natural_shift()->void:
 var f: Dictionary=funded_shop("Swift original entry and natural Shift")
 if f.is_empty():return
 swift_active_fixture=f
 var model=f.session.ledger.model
 for id: String in f.sim.common.runtime.selected:
  if id.begins_with("g") and id!="g01":check(false,"uncovered actual Common modifier "+id);dispose(f);return
 var safe: Dictionary=f.sim.hero.stats.duplicate(true)
 var base: Dictionary=f.sim.hero.base_stats.duplicate(true)
 if not buy(f,SWIFT) or not check(shop_command(f,"consume",{"uid":swift_uid(f)}).get("accepted",false),"original real UID drink"):dispose(f);return
 check(model.swift_elixir_status().pending and f.sim.hero.stats==safe,"safe pending grants no stats")
 if not check(f.session.close_panel().accepted,"original shop closes") or not enter(f,1):dispose(f);return
 var entry: Dictionary=f.sim.hero.stats.duplicate(true)
 check(model.swift_elixir_status().active and not model.swift_elixir_status().pending,"original next battle binds Swift effect")
 near_number(entry.move_speed,float(safe.move_speed)+float(base.move_speed)*.15,"first entry permanent MS15 percent")
 near_number(entry.attack_speed,float(safe.attack_speed)+float(base.attack_speed)*.15,"first entry permanent AS15 percent")
 if not check(entry.has("cdr") and safe.has("cdr"),"original actor cdr fields exist"):dispose(f);return
 near_number(entry.cdr,float(safe.cdr)+.08,"first entry permanent CDR8 percent")
 check(not model.swift_buff_effect(f.sim).active,"entry alone gives no after-Shift buff")
 if not spawn_ready(f) or not b04_ready(f):dispose(f);return
 var projected: Dictionary=f.sim.hero.projected_base_stats.duplicate(true)
 var before_clock: float=float(f.sim.common.runtime.actor_time)
 var aim: Vector3=f.sim.hero.position+Vector3.RIGHT*8.0
 var input_before: Dictionary={"hero":f.sim.hero.snapshot().duplicate(true),"phase":f.sim.phase,"paused":f.sim.paused,"actor_time":f.sim.common.runtime.actor_time,"room":f.sim.room_id,"generation":f.sim.encounter_generation,"run_id":model.state.shop_visit.run_id}
 var key:=InputEventKey.new();key.physical_keycode=KEY_SHIFT;key.pressed=true
 var action: Dictionary=f.router.handle_event(key,aim)
 key=InputEventKey.new();key.physical_keycode=KEY_SHIFT;key.pressed=false
 var up_result: Dictionary=f.router.handle_event(key,aim)
 swift_shift_attempts.append({"aim":aim,"before":input_before,"down_result":action.duplicate(true),"up_result":up_result.duplicate(true),"after":f.sim.hero.snapshot().duplicate(true)})
 if not check(action.get("accepted",false),"original Router Shift key pair accepted: "+str(action)):dispose(f);return
 var original: Dictionary=f.sim._dash_state
 if not check(not original.is_empty() and f.sim.hero.dash_left>0.0,"original live dash state exists"):dispose(f);return
 var cast_id: int=int(original.cast_id)
 check(not model.swift_buff_effect(f.sim).active and model.state.get("swift_shift_claims",{}).is_empty(),"Shift start does not grant or claim")
 for _tick in range(120):
  if f.sim.hero.dash_left<=0.0:break
  step(f)
 if not check(f.sim.phase=="combat" and not f.sim.hero.dead and f.sim.hero.dash_left==0.0,"original step reaches live natural dash end"):dispose(f);return
 check(f.sim._casts.get(cast_id,{}).get("finished",false) and not f.sim._casts.get(cast_id,{}).get("cancelled",true),"same original cast finished without cancellation")
 var buff: Dictionary=f.sim.hero.cast_state.get(SwiftGateRuntime.BUFF_KEY,{}).duplicate(true)
 var claims: Dictionary=model.state.get("swift_shift_claims",{}).duplicate(true)
 if not check(not buff.is_empty() and model.swift_buff_effect(f.sim).active,"natural Shift end grants actual short buff"):dispose(f);return
 near_number(buff.expires_at,float(buff.last_shift_end_at)+1.5,"original actor deadline exactly plus1.5")
 near_number(buff.move_fraction,.15,"single short MS15 percent")
 check(float(buff.last_shift_end_at)>=before_clock and float(buff.last_shift_end_at)<=float(f.sim.common.runtime.actor_time),"grant occurs on actual current actor timeline")
 check(claims.get("casts",{}).size()==1 and claims.casts.has(str(cast_id)),"exactly one claim for original Shift cast")
 near_number(f.sim.hero.stats.move_speed,float(safe.move_speed)+float(base.move_speed)*.30,"approved same-base permanent plus short30 percent")
 near_number(f.sim.hero.stats.attack_speed,entry.attack_speed,"short effect does not add AS")
 if not check(f.sim.hero.stats.has("cdr"),"original after-Shift actor cdr field exists"):dispose(f);return
 near_number(f.sim.hero.stats.cdr,entry.cdr,"short effect does not add CDR")
 for _i in range(4):f.sim.common.refresh_stats()
 check(f.sim.hero.base_stats==base and f.sim.hero.projected_base_stats==projected,"pure derived view never bakes base or projected input")
 check(f.sim.hero.cast_state.get(SwiftGateRuntime.BUFF_KEY,{})==buff and model.state.get("swift_shift_claims",{})==claims,"repeated stat refresh changes no buff or claim")
 swift_shift_samples.append({"action":action.duplicate(true),"cast_id":cast_id,"safe":safe,"entry":entry,"after":f.sim.hero.stats.duplicate(true),"base":base,"projected":projected,"buff":buff,"claims":claims,"actor_time":f.sim.common.runtime.actor_time,"selected_hexes":f.sim.common.runtime.selected.duplicate()})
 dispose(f)
func run()->void:
 g03_reset_evidence();swift_natural_shift()
 # Also releases the retained fixture if an unexpected script error returns here.
 dispose(swift_active_fixture)
 await process_frame
 check(swift_shift_samples.size()==1,"one complete real natural Shift sample required")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"group":"natural_shift","completed":["natural_shift"] if swift_shift_samples.size()==1 else [],"samples":swift_shift_samples,"input_attempts":swift_shift_attempts,"wallet_fixture":60000,"native_input":false,"original_Router_input":true,"HP_or_clock_written":false,"expiry_or_second_cast_verified":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file:=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close();quit(0 if report.passed and error==OK else 2)
