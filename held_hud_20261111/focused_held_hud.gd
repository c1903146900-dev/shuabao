extends RefCounted
## Run only after the original authenticated Boot has loaded the candidate pack.
## Real route Sim + real Router + simulated InputEvents, NOT OS-input acceptance.
## Explicit fixtures: empty encounters, AI/auto-finish disabled, temporary paused
## and dead flags for negative boundary tests. No production clock/rule changes.
var checks:Array=[]
var failures:Array=[]
var observations:Array=[]
var serial:int=0
var completed:Dictionary={}
const AIM_RIGHT=Vector3(8,0,0)
const AIM_LEFT=Vector3(-8,0,0)
const AIM_NORTH=Vector3(0,0,-8)

func check(label:String,ok:bool,detail:Variant=null)->void:
 var row:Dictionary={"check":label,"passed":ok,"detail":detail}
 checks.append(row)
 if not ok:failures.append(row)

func fresh(label:String)->Dictionary:
 serial+=1
 var sim=load("res://fengli_route_20261024/sim.gd").new()
 sim.ai_enabled=false;sim.auto_finish=false
 var begun:Dictionary=sim.begin_encounter("held-hud-fixture-%d-%s"%[serial,label],[])
 check(label+"_real_source_begin",bool(begun.get("accepted",false)),begun)
 var router=load("res://fengli_route_20261024/input_router.gd").new()
 router.bind(sim)
 return {"sim":sim,"router":router,"label":label}

func discard(f:Dictionary)->void:
 if is_instance_valid(f.sim):f.sim.free()

func mouse(f:Dictionary,pressed:bool,aim:Vector3=AIM_RIGHT,over_ui:bool=false,blocked:bool=false,button:int=MOUSE_BUTTON_LEFT)->Dictionary:
 var event:=InputEventMouseButton.new()
 event.button_index=button;event.pressed=pressed
 return f.router.handle_event(event,aim,blocked,over_ui)

func motion(f:Dictionary,over_ui:bool,blocked:bool=false)->Dictionary:
 return f.router.handle_event(InputEventMouseMotion.new(),AIM_RIGHT,blocked,over_ui)

func key(f:Dictionary,code:int,pressed:bool,aim:Vector3=AIM_RIGHT,blocked:bool=false,over_ui:bool=false)->Dictionary:
 var event:=InputEventKey.new()
 event.physical_keycode=code;event.keycode=code;event.pressed=pressed
 return f.router.handle_event(event,aim,blocked,over_ui)

func advance(f:Dictionary,seconds:float)->void:
 for index in range(ceili(seconds/.02)):f.sim.step(.02)

func last_event(f:Dictionary,kind:String)->Dictionary:
 for index in range(f.sim.event_log.size()-1,-1,-1):
  if str(f.sim.event_log[index].kind)==kind:return f.sim.event_log[index]
 return {}

func attack_count(f:Dictionary)->int:return int(f.sim.hero.attack_index)

func aim_direction(f:Dictionary,point:Vector3)->Vector3:
 var direction:Vector3=point-f.sim.hero.position
 direction.y=0
 return direction.normalized()

func arm(f:Dictionary)->void:
 check(f.label+"_battlefield_press_accepted",mouse(f,true).get("accepted",false))
 advance(f,.30)
 check(f.label+"_hold_origin_eligible",f.router._left_physical and not f.router._held_suppressed)

func run()->Dictionary:
 checks.clear();failures.clear();observations.clear();completed.clear()
 hold_recovery_case();origin_and_click_cases();boundary_cases();movement_and_shift_cases();buffer_cases()
 for name in ["hold","origin","boundaries","movement_shift","buffer"]:
  check(name+"_reached_tail",completed.get(name,false))
 var result:Dictionary={"status":"FAIL" if not failures.is_empty() else "FIXTURE_PASS_NOT_NATIVE_ACCEPTANCE","checks":checks,"failures":failures,"observations":observations,"completed":completed,"scope":{"real_route_source":true,"real_router":true,"simulated_input_events":true,"empty_encounter_fixture":true,"ai_and_auto_finish_disabled":true,"pause_and_dead_flag_negative_fixtures":true,"source_clock_advanced_by_step":true,"OS_mouse":"NOT_RUN","full_floor":"NOT_RUN","engine_run_by_author":false}}
 print("FOCUSED_HELD_HUD ",JSON.stringify(result))
 return result

func hold_recovery_case()->void:
 var f:Dictionary=fresh("hover")
 arm(f)
 var count:int=attack_count(f)
 var before_cd:float=f.sim.hero.cooldowns.attack
 check("hover_still_inside_original_cooldown",before_cd>.12)
 check("hover_motion_ignored_without_permanent_suppression",not motion(f,true).get("accepted",false) and not f.router._held_suppressed)
 check("hover_update_never_attacks",not f.router.update_held_basic(AIM_LEFT,true).get("accepted",false) and attack_count(f)==count and f.router._left_physical and not f.router._held_suppressed)
 var leave:Dictionary=f.router.update_held_basic(AIM_LEFT,false)
 check("leave_before_cooldown_does_not_force_attack",not leave.get("accepted",false) and leave.get("reason","")=="cooldown" and attack_count(f)==count and not f.router._held_suppressed,leave)
 for index in range(60):
  f.sim.step(.02)
  f.router.update_held_basic(AIM_LEFT,false)
 check("same_hold_resumes_after_real_cooldown_without_new_down",attack_count(f)==count+1,attack_count(f))
 var resumed:Dictionary=last_event(f,"attack_started")
 check("resumed_hold_uses_current_aim_not_old_click",resumed.get("direction",Vector3.ZERO).is_equal_approx(aim_direction(f,AIM_LEFT)),resumed)
 count=attack_count(f)
 for index in range(70):
  motion(f,true)
  f.router.update_held_basic(AIM_RIGHT,true)
  f.sim.step(.02)
 check("hover_longer_than_full_cycle_has_no_attack",attack_count(f)==count and f.sim.hero.cooldowns.attack<=0 and not f.router._held_suppressed)
 check("leave_ready_hover_resumes_immediately_once",f.router.update_held_basic(AIM_NORTH,false).get("accepted",false) and attack_count(f)==count+1)
 f.router.update_held_basic(AIM_NORTH,false)
 check("same_frame_retry_cannot_duplicate_attack",attack_count(f)==count+1)
 check("physical_release_stops_resumed_hold",mouse(f,false).get("accepted",false) and not f.router._left_physical)
 advance(f,1.2);f.router.update_held_basic(AIM_RIGHT,false)
 check("released_hold_never_resumes",attack_count(f)==count+1)
 observations.append({"case":"hover_resume","original_cooldown_on_entry":before_cd,"attacks":attack_count(f),"native_evidence":false})
 discard(f);completed.hold=true

func origin_and_click_cases()->void:
 var f:Dictionary=fresh("UI_origin")
 key(f,KEY_W,true)
 var move:Vector3=f.router.movement()
 check("UI_origin_press_rejected",not mouse(f,true,AIM_RIGHT,true).get("accepted",false))
 check("UI_click_preserves_held_movement",f.router.movement()==move and f.sim.hero.move_intent==move)
 advance(f,1.2);motion(f,false);f.router.update_held_basic(AIM_RIGHT,false)
 check("UI_origin_cannot_start_by_dragging_to_field",attack_count(f)==0 and f.router._left_physical and f.router._held_suppressed)
 check("duplicate_down_cannot_rearm_UI_origin",mouse(f,true).get("reason","")=="duplicate_physical_down")
 mouse(f,false,AIM_RIGHT,true);key(f,KEY_W,false)
 check("fresh_release_and_battlefield_down_rearms",mouse(f,true).get("accepted",false) and attack_count(f)==1)
 discard(f)
 for button in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
  f=fresh("UI_click_%d"%button);arm(f)
  var count:int=attack_count(f)
  mouse(f,true,AIM_RIGHT,true,false,button)
  advance(f,1.2);motion(f,false);f.router.update_held_basic(AIM_RIGHT,false)
  check("actual_UI_click_invalidates_existing_hold_%d"%button,attack_count(f)==count and f.router._held_suppressed)
  mouse(f,false);check("UI_click_then_fresh_down_recovers_%d"%button,mouse(f,true).get("accepted",false))
  discard(f)
 completed.origin=true

func boundary_cases()->void:
 for boundary in ["focus","modal","host_blocked","pause","generation","phase","death","release_over_UI","rebind"]:
  var f:Dictionary=fresh(boundary);arm(f)
  var count:int=attack_count(f)
  f.router.update_held_basic(AIM_RIGHT,true)
  match boundary:
   "focus":f.router.focus_lost()
   "modal":f.router.suspend_input("modal")
   "host_blocked":motion(f,true,true)
   "pause":f.sim.paused=true;f.router.update_held_basic(AIM_RIGHT,true);f.sim.paused=false
   "generation":
    f.sim.end_encounter("victory")
    check("generation_source_restart",f.sim.begin_encounter("held-hud-next-%d"%serial,[]).get("accepted",false))
    f.router.update_held_basic(AIM_RIGHT,true)
   "phase":
    f.sim.end_encounter("victory");f.router.update_held_basic(AIM_RIGHT,true)
    check("phase_source_restart",f.sim.begin_encounter("held-hud-phase-next-%d"%serial,[]).get("accepted",false))
   "death":f.sim.hero.dead=true;f.router.update_held_basic(AIM_RIGHT,true);f.sim.hero.dead=false
   "release_over_UI":mouse(f,false,AIM_RIGHT,true)
   "rebind":f.router.bind(f.sim)
  check(boundary+"_permanent_suppression_retained",f.router._held_suppressed and f.router.pending.is_empty())
  advance(f,1.2);motion(f,false);f.router.update_held_basic(AIM_RIGHT,false)
  check(boundary+"_leaving_UI_never_revives_old_hold",attack_count(f)==count)
  mouse(f,false)
  check(boundary+"_fresh_battlefield_press_works",mouse(f,true).get("accepted",false) and attack_count(f)==count+1)
  discard(f)
 # A press while a modal blocks input cannot become an eligible hold either.
 var f:Dictionary=fresh("blocked_origin")
 mouse(f,true,AIM_RIGHT,false,true);advance(f,1.2);f.router.update_held_basic(AIM_RIGHT,false)
 check("blocked_origin_stays_suppressed",attack_count(f)==0 and f.router._held_suppressed)
 discard(f);completed.boundaries=true

func movement_and_shift_cases()->void:
 for code in [KEY_W,KEY_A,KEY_S,KEY_D]:
  var f:Dictionary=fresh("movement_%d"%code)
  key(f,code,true);var move:Vector3=f.router.movement()
  arm(f);motion(f,true);f.router.update_held_basic(AIM_LEFT,true)
  check("hover_preserves_WASD_%d"%code,f.router.movement()==move and f.sim.hero.move_intent==move)
  var shifted:Dictionary=key(f,KEY_SHIFT,true,AIM_LEFT)
  check("moving_Shift_uses_movement_not_mouse_%d"%code,shifted.get("accepted",false) and f.sim.hero.dash_direction.is_equal_approx(move),shifted)
  key(f,code,false,AIM_RIGHT,false,true)
  check("movement_release_over_UI_still_clears_%d"%code,f.router.movement()==Vector3.ZERO and f.sim.hero.move_intent==Vector3.ZERO)
  discard(f)
 var f:Dictionary=fresh("standing_Shift")
 check("standing_aimed_attack",mouse(f,true,AIM_LEFT).get("accepted",false));mouse(f,false)
 advance(f,.30)
 var facing:Vector3=f.sim.hero.facing
 check("standing_Shift_preserves_prior_facing",key(f,KEY_SHIFT,true,AIM_RIGHT).get("accepted",false) and f.sim.hero.dash_direction.is_equal_approx(facing) and facing.is_equal_approx(aim_direction(f,AIM_LEFT)))
 discard(f)
 f=fresh("precontact_Shift")
 mouse(f,true,AIM_RIGHT);var basic:Dictionary=last_event(f,"attack_started")
 var cancelled_id:int=int(basic.get("cast_id",-1))
 advance(f,.06)
 check("precontact_Shift_still_cancels_basic",key(f,KEY_SHIFT,true,AIM_LEFT).get("accepted",false) and cancelled_id in last_event(f,"attack_cancelled").get("cast_ids",[]))
 advance(f,.50)
 var old_impact:bool=false
 for event:Dictionary in f.sim.event_log:
  if str(event.kind)=="attack_impact" and int(event.get("cast_id",-2))==cancelled_id:old_impact=true
 check("cancelled_precontact_basic_has_no_impact",not old_impact)
 discard(f);completed.movement_shift=true

func queued(f:Dictionary)->void:
 mouse(f,true,AIM_RIGHT);mouse(f,false)
 advance(f,.86)
 var result:Dictionary=mouse(f,true,AIM_NORTH)
 check(f.label+"_near_cooldown_tap_buffers",result.get("buffered",false) and not f.router.pending.is_empty(),result)
 if not f.router.pending.is_empty():check(f.label+"_buffer_remains_120ms",is_equal_approx(float(f.router.pending.expires)-float(f.sim.real_time),.12))

func buffer_cases()->void:
 var f:Dictionary=fresh("buffer_original");queued(f)
 advance(f,.10)
 check("existing_buffer_retries_saved_aim",f.router.update_held_basic(AIM_RIGHT,false).get("accepted",false) and last_event(f,"attack_started").get("direction",Vector3.ZERO).is_equal_approx(aim_direction(f,AIM_NORTH)) and f.router.pending.is_empty())
 discard(f)
 f=fresh("buffer_hover");queued(f)
 f.router.update_held_basic(AIM_RIGHT,true)
 check("hover_clears_buffer_without_rearming_it",f.router.pending.is_empty() and not f.router._held_suppressed)
 advance(f,.10)
 check("after_hover_hold_uses_current_aim_not_cleared_tap",f.router.update_held_basic(AIM_LEFT,false).get("accepted",false) and last_event(f,"attack_started").get("direction",Vector3.ZERO).is_equal_approx(aim_direction(f,AIM_LEFT)))
 discard(f)
 f=fresh("buffer_expiry");queued(f);mouse(f,false);advance(f,.14)
 f.router.update_held_basic(AIM_RIGHT,false)
 check("expired_tap_does_not_execute_without_hold",attack_count(f)==1 and f.router.pending.is_empty())
 discard(f)
 for boundary in ["focus","modal","pause","generation","death","UI_click","UI_motion"]:
  f=fresh("queued_"+boundary);queued(f)
  match boundary:
   "focus":f.router.focus_lost()
   "modal":f.router.suspend_input("modal")
   "pause":f.sim.paused=true;f.router.update_held_basic(AIM_RIGHT,true);f.sim.paused=false
   "generation":
    f.sim.end_encounter("victory");f.sim.begin_encounter("queued-next-%d"%serial,[]);f.router.update_held_basic(AIM_RIGHT,true)
   "death":f.sim.hero.dead=true;f.router.update_held_basic(AIM_RIGHT,true);f.sim.hero.dead=false
   "UI_click":mouse(f,true,AIM_RIGHT,true)
   "UI_motion":motion(f,true)
  check("queued_"+boundary+"_clears_pending",f.router.pending.is_empty())
  if boundary!="UI_motion":
   advance(f,.14);f.router.update_held_basic(AIM_RIGHT,false)
   check("queued_"+boundary+"_never_fires_later",attack_count(f)==1)
  discard(f)
 completed.buffer=true
