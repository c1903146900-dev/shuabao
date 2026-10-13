extends "res://integration_checks/swift05_source_gate.gd"
const SwiftGateRuntime=preload("res://elixir_swift_20261010/runtime.gd")
var swift_shift_samples: Array=[]
var swift_active_fixture: Dictionary={}
var swift_shift_attempts: Array=[]
var swift_repeat_evidence: Dictionary={}
var swift_repeat_scene_log: Array=[]
var swift_repeat_final_events: Array=[]
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
 for _copy in range(3):
  if not buy(f,C03):dispose(f);return
 check(owned_count(f,C03)==3,"three original purchased C03 items supply legal CDR")
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
 near_number(entry.cdr,clampf(float(safe.cdr)+.08,0.0,.65),"first entry permanent CDR8 percent")
 check(not model.swift_buff_effect(f.sim).active,"entry alone gives no after-Shift buff")
 if not spawn_ready(f) or not b04_ready(f):dispose(f);return
 near_number(f.sim.hero.stats.cdr,.65,"original65percent CDR cap reached through three real items")
 near_number(f.sim.v("D-4"),4.0,"original Shift base cooldown4")
 near_number(f.sim.v("D-2"),.25,"original Shift duration.25")
 check(model.c03_buff_effect(f.sim).stacks==0,"buying three C03 grants no Q/E stack")
 var projected: Dictionary=f.sim.hero.projected_base_stats.duplicate(true)
 var before_clock: float=float(f.sim.common.runtime.actor_time)
 var aim: Vector3=f.sim.hero.position+Vector3.FORWARD*8.0
 var input_before: Dictionary={"hero":f.sim.hero.snapshot().duplicate(true),"phase":f.sim.phase,"paused":f.sim.paused,"actor_time":f.sim.common.runtime.actor_time,"room":f.sim.room_id,"generation":f.sim.encounter_generation,"run_id":model.state.shop_visit.run_id}
 var key:=InputEventKey.new();key.physical_keycode=KEY_SHIFT;key.pressed=true
 swift_repeat_scene_log.append(swift_repeat_scene(f,"before_first"))
 var action: Dictionary=f.router.handle_event(key,aim)
 key=InputEventKey.new();key.physical_keycode=KEY_SHIFT;key.pressed=false
 var up_result: Dictionary=f.router.handle_event(key,aim)
 swift_shift_attempts.append({"aim":aim,"before":input_before,"down_result":action.duplicate(true),"up_result":up_result.duplicate(true),"after":f.sim.hero.snapshot().duplicate(true)})
 if not check(action.get("accepted",false),"original Router Shift key pair accepted: "+str(action)):dispose(f);return
 near_number(f.sim.hero.cooldowns.shift,1.4,"first original Shift cooldown consumes real65percent CDR")
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
 for _tick in range(100):
  if float(f.sim.hero.cooldowns.shift)<=f.sim.TIME_EPS and float(f.sim.hero.lock_time)<=f.sim.TIME_EPS and not f.sim._ink_action_controlled("shift"):break
  if not check(f.sim.phase=="combat" and not f.sim.hero.dead,"original combat remains live while CD elapses"):dispose(f);return
  step(f)
 swift_repeat_scene_log.append(swift_repeat_scene(f,"before_second_readiness"))
 if not check(f.sim.phase=="combat" and not f.sim.hero.dead and float(f.sim.hero.lock_time)<=f.sim.TIME_EPS and float(f.sim.hero.cooldowns.shift)<=f.sim.TIME_EPS and not f.sim._ink_action_controlled("shift") and model.swift_buff_effect(f.sim).active and float(f.sim.common.runtime.actor_time)<float(buff.expires_at),"legal original second Shift becomes ready inside first short duration"):dispose(f);return
 var second_aim: Vector3=f.sim.hero.position+Vector3.FORWARD*8.0
 var second_before: Dictionary=f.sim.hero.snapshot().duplicate(true)
 var second_key:=InputEventKey.new();second_key.physical_keycode=KEY_SHIFT;second_key.pressed=true
 swift_repeat_scene_log.append(swift_repeat_scene(f,"before_second"))
 var second_action: Dictionary=f.router.handle_event(second_key,second_aim)
 second_key=InputEventKey.new();second_key.physical_keycode=KEY_SHIFT;second_key.pressed=false
 var second_up: Dictionary=f.router.handle_event(second_key,second_aim)
 swift_shift_attempts.append({"aim":second_aim,"before":second_before,"down_result":second_action.duplicate(true),"up_result":second_up.duplicate(true),"actor_time":f.sim.common.runtime.actor_time})
 if not check(second_action.get("accepted",false),"second original Shift accepted after real cooldown: "+str(second_action)):dispose(f);return
 var second_state: Dictionary=f.sim._dash_state
 if not check(not second_state.is_empty() and int(second_state.cast_id)!=cast_id,"second original cast is distinct"):dispose(f);return
 var second_id: int=int(second_state.cast_id)
 check(f.sim.hero.cast_state.get(SwiftGateRuntime.BUFF_KEY,{})==buff and model.state.get("swift_shift_claims",{})==claims,"second Shift start does not refresh before completion")
 for _tick in range(120):
  if f.sim.hero.dash_left<=0.0:break
  step(f)
 if not check(f.sim.phase=="combat" and not f.sim.hero.dead and f.sim.hero.dash_left==0.0,"second original Shift naturally finishes alive"):dispose(f);return
 check(f.sim._casts.get(second_id,{}).get("finished",false) and not f.sim._casts.get(second_id,{}).get("cancelled",true),"second original cast finished without cancellation")
 var refreshed: Dictionary=f.sim.hero.cast_state.get(SwiftGateRuntime.BUFF_KEY,{}).duplicate(true)
 var new_claims: Dictionary=model.state.get("swift_shift_claims",{}).duplicate(true)
 if not check(model.swift_buff_effect(f.sim).active and float(refreshed.get("last_shift_end_at",-1))>float(buff.last_shift_end_at) and float(refreshed.get("last_shift_end_at",INF))<float(buff.expires_at),"second natural grant refreshes while first buff still active"):dispose(f);return
 near_number(refreshed.expires_at,float(refreshed.last_shift_end_at)+1.5,"second grant refreshes deadline to new actor time plus1.5")
 near_number(refreshed.move_fraction,.15,"second grant does not stack short fraction")
 check(new_claims.get("casts",{}).size()==2 and new_claims.casts.has(str(cast_id)) and new_claims.casts.has(str(second_id)),"two and only two real cast claims")
 near_number(f.sim.hero.stats.move_speed,float(safe.move_speed)+float(base.move_speed)*.30,"two natural completions retain30percent rather than stacked45")
 check(model.c03_buff_effect(f.sim).stacks==0,"Shift does not trigger Q/E C03 stacks")
 check(f.sim.hero.base_stats==base and f.sim.hero.projected_base_stats==projected,"second completion does not bake stats inputs")
 swift_repeat_evidence={"first_cast":cast_id,"second_cast":second_id,"first_buff":buff,"second_buff":refreshed,"first_claims":claims,"second_claims":new_claims,"actor_time":f.sim.common.runtime.actor_time,"grant_interval":float(refreshed.last_shift_end_at)-float(buff.last_shift_end_at),"actual_CDR":f.sim.hero.stats.cdr,"inventory":model.state.inventory.duplicate(true)}
 swift_shift_samples.append({"action":action.duplicate(true),"cast_id":cast_id,"safe":safe,"entry":entry,"after":f.sim.hero.stats.duplicate(true),"base":base,"projected":projected,"buff":buff,"claims":claims,"actor_time":f.sim.common.runtime.actor_time,"selected_hexes":f.sim.common.runtime.selected.duplicate()})
 dispose(f)
func run()->void:
 g03_reset_evidence();swift_natural_shift()
 # Also releases the retained fixture if an unexpected script error returns here.
 dispose(swift_active_fixture)
 await process_frame
 check(swift_shift_samples.size()==1,"one complete real natural Shift sample required")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"group":"repeat_shift","completed":["repeat_shift"] if swift_shift_samples.size()==1 else [],"samples":swift_shift_samples,"input_attempts":swift_shift_attempts,"wallet_fixture":60000,"native_input":false,"original_Router_input":true,"HP_or_clock_written":false,"expiry_verified":false,"second_cast_verified":failures.is_empty() and swift_shift_samples.size()==1 and not swift_repeat_evidence.is_empty(),"repeat_evidence":swift_repeat_evidence,"scene_log":swift_repeat_scene_log,"source_events":swift_repeat_final_events,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file:=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close();quit(0 if report.passed and error==OK else 2)

func swift_repeat_scene(f: Dictionary,label: String)->Dictionary:
 return {"label":label,"actor_time":f.sim.common.runtime.actor_time,"hero_position":f.sim.hero.position,"stun_left":f.sim.hero.stun_left,"control_motion_blocking":f.sim._control_motion_blocking,"controlled":f.sim._ink_action_controlled("shift"),"cooldowns":f.sim.hero.cooldowns.duplicate(true),"enemies":f.sim.enemies.duplicate(true),"events":f.events.duplicate(true)}
func dispose(f: Dictionary)->void:
 if not f.is_empty():
  swift_repeat_scene_log.append(swift_repeat_scene(f,"before_dispose"))
  swift_repeat_final_events=f.events.duplicate(true)
 super.dispose(f)
