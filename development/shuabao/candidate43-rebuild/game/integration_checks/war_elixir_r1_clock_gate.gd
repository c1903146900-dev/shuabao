extends "res://integration_checks/war_elixir_source_gate.gd"
## Original authored route earns R1. Earlier rooms use source lethal fixtures;
## no level/rank/clock is written and target R1 enters the original router.
var clock_records: Array=[]
func _initialize() -> void:
 output_path="user://war_r1_clock.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
 run.call_deferred()
func reach_room(f: Dictionary) -> bool:
 var learned: bool=false
 for row in range(1,12):
  if not enter(f,row):return false
  if f.session.status=="service":
   if not check(f.session.complete_service().accepted,"original R preparation service"):return false
  else:
   if learned:return spawn_ready(f)
   if not b04_settle_row(f,row):return false
  if not learned and int(f.session.ledger.model.state.level)>=6:
   if not choose_required_hexes(f) or not check(command(f,"learn",{"slot":"R","candidate":"R1","expected_rank":0}).accepted,"actual earned Lv6/SP learns R1"):return false
   if not check(f.session.open_panel().accepted,"original safe shop before R room") or not buy(f,WAR) or not check(shop_command(f,"consume",{"uid":war_uid(f)}).accepted,"war pending for next real fight") or not check(f.session.close_panel().accepted,"close original R preparation shop"):return false
   learned=true
 return check(false,"original route contains combat after R1 learning")
func r1_case() -> void:
 var f: Dictionary=funded_shop("war_r1_clock")
 if f.is_empty():return
 if not check(f.session.close_panel().accepted,"initial shop closes") or not reach_room(f) or not b04_ready(f):dispose(f);return
 var model=f.session.ledger.model
 var living: Array=f.sim.living()
 if not check(living.size()>1,"original R room retains multiple actual actors"):dispose(f);return
 lethal_enemy_fixture(f,living[0],"war R clock: actual roster first kill fixture")
 if not check(model.war_buff_effect(f.sim).get("active",false),"current battle grants war buff before R1"):dispose(f);return
 var aim: Vector3=f.sim.hero.position
 var rd:=InputEventKey.new();rd.physical_keycode=KEY_R;rd.pressed=true
 var ru:=InputEventKey.new();ru.physical_keycode=KEY_R;ru.pressed=false
 var md:=InputEventMouseButton.new();md.button_index=MOUSE_BUTTON_LEFT;md.pressed=true
 var mu:=InputEventMouseButton.new();mu.button_index=MOUSE_BUTTON_LEFT;mu.pressed=false
 var armed: Dictionary=f.router.handle_event(rd,aim);f.router.handle_event(ru,aim)
 var committed: Dictionary=f.router.handle_event(md,aim);f.router.handle_event(mu,aim)
 if not check(armed.accepted and committed.accepted,"original R and LMB input accepts actual learned R1") or not check(f.sim.clock.domain.snapshot().presentations.has(f.sim.hero.actor_id),"actual original R1 presentation opens"):dispose(f);return
 var slices: Array=[]
 for tick in range(100):
  if not f.sim.clock.domain.snapshot().presentations.has(f.sim.hero.actor_id):break
  if tick==8:
   var before: Dictionary={"clock":float(f.sim.common.runtime.actor_time),"raw":f.sim.hero.cast_state.get("elixir_war_on_kill",{}).duplicate(true),"view":model.war_buff_effect(f.sim),"domain":f.sim.clock.domain.snapshot()}
   check(f.session.set_modal_blocked(true).accepted,"original modal API pauses presentation")
   step(f,12)
   check(float(f.sim.common.runtime.actor_time)==before.clock and f.sim.hero.cast_state.get("elixir_war_on_kill",{})==before.raw and model.war_buff_effect(f.sim)==before.view and f.sim.clock.domain.snapshot()==before.domain,"original pause freezes war duration and presentation")
   check(f.session.set_modal_blocked(false).accepted,"original modal API resumes")
  var world: float=f.sim.clock.world_time
  var actor: float=f.sim.common.runtime.actor_time
  var presentation: float=f.sim.presentation_actor_time
  step(f)
  var delta: Dictionary={"world":float(f.sim.clock.world_time)-world,"actor":float(f.sim.common.runtime.actor_time)-actor,"presentation":float(f.sim.presentation_actor_time)-presentation}
  near_number(delta.actor,delta.world,"war owner clock advances exactly original world dt during R1")
  if float(delta.presentation)>float(delta.world):slices.append(delta)
 check(not slices.is_empty(),"actual presentation and gameplay clock domains diverge")
 check(not f.sim.clock.domain.snapshot().presentations.has(f.sim.hero.actor_id),"original R1 presentation ends within source budget")
 clock_records.append({"armed":armed,"committed":committed,"slow_slices":slices,"buff":f.sim.hero.cast_state.get("elixir_war_on_kill",{}).duplicate(true),"view":model.war_buff_effect(f.sim),"original_earned_level":model.state.level,"learned_rank":f.sim.hero.ranks.r})
 b04_integrity(f,"war R1 original clock");dispose(f)
func run() -> void:
 g03_reset_evidence();r1_case();await process_frame
 check(clock_records.size()==1,"original R1 clock case completed")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"records":clock_records,"economic_fixture":true,"earlier_room_source_damage_fixture":true,"native_CUA":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var err: Error=file.get_error();file.close();quit(0 if report.passed and err==OK else 2)
