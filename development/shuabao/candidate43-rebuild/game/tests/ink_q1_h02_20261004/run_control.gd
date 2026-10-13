extends SceneTree
const Sim=preload("res://tests/ink_q1_h02_20261004/ink_h02_sim.gd")
const Adapter=preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_input_adapter.gd")
const Geometry=preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_geometry.gd")
var checks:int=0
var failures:Array=[]
var natural_observations:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func near(a:float,b:float,label:String)->void:check(absf(a-b)<=0.00001,"%s: %s vs %s"%[label,a,b])
func fresh(boss:bool=false):
 var sim=Sim.new();root.add_child(sim);sim.hero.position=Vector3.ZERO;sim.auto_finish=false;sim.ai_enabled=boss;sim.hero.loadout.q="q1";sim.hero.ranks.q=1
 sim.begin_encounter("ink-control-rev02",[{"kind":"boss","position":Vector3(0,0,-2.5)}] if boss else [])
 return sim
func key(code:int)->InputEventKey:
 var e=InputEventKey.new();e.physical_keycode=code;e.pressed=true;return e
func mouse(pressed:bool)->InputEventMouseButton:
 var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;return e
func await_natural_control(sim)->int:
 var steps:int=0
 while steps<250 and sim.hero.stun_left<=sim.TIME_EPS and not sim.hero.dead:
  sim.step(.02);steps+=1
 check(sim.hero.stun_left>sim.TIME_EPS and not sim.hero.dead,"natural Boss supplied actual control")
 return steps
func release_q(sim,start:Vector3,end:Vector3)->void:
 check(sim.request_ink_input("q_down").accepted,"Q armed")
 check(sim.request_ink_input("left_down",start).accepted,"Q start admitted")
 sim.request_ink_input("motion",end)
 check(sim.request_ink_input("left_up",end).accepted,"Q released")
func _initialize()->void:call_deferred("run")
func run()->void:
 test_natural_control();test_duration_immunity_and_recovery();test_motion_and_live_flights();test_idle_cancel();test_terminal_frame()
 var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"natural_boss_observations":natural_observations,"scope":"revision02 finite control/input/terminal-frame checks; not OS/art/full-hero acceptance"}
 var f=FileAccess.open("res://tests/ink_q1_h02_20261004/control_result.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("INK_CONTROL_REV02_REPORT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func test_natural_control()->void:
 for operation in ["walk","new_basic","new_shift","q_arm","accepted_preview_release"]:
  var sim=fresh(true);var adapter=Adapter.new();adapter.bind(sim)
  if operation=="accepted_preview_release":
   adapter.handle_event(key(KEY_Q));adapter.handle_event(mouse(true),Vector3.ZERO)
   var motion=InputEventMouseMotion.new();adapter.handle_event(motion,Vector3(4,0,0))
  var steps:int=await_natural_control(sim)
  check(steps==95,"same natural Boss first-hit step95 "+operation)
  near(sim.hero.stun_left,.2,"same source .20s stun "+operation)
  var before:Vector3=sim.hero.position
  var action:Dictionary={}
  match operation:
   "walk":action=adapter.handle_event(key(KEY_D));sim.step(.02)
   "new_basic":action=adapter.handle_event(mouse(true),Vector3(9,0,0))
   "new_shift":action=adapter.handle_event(key(KEY_SHIFT),Vector3(9,0,0));sim.step(.02)
   "q_arm":action=adapter.handle_event(key(KEY_Q))
   "accepted_preview_release":action=adapter.handle_event(mouse(false),Vector3(4,0,0))
  near(before.distance_to(sim.hero.position),0,"controlled zero displacement "+operation)
  if operation!="walk":check(not action.accepted and action.reason=="controlled","controlled admission rejected "+operation)
  check(sim.ink_basics.is_empty() and sim.ink_waves.is_empty() and sim.hero.dash_left==0,"control creates no new gameplay motion "+operation)
  if operation=="accepted_preview_release":check(sim.ink_input.phase=="idle","rejected physical release cancels only its preview")
  natural_observations.append({"operation":operation,"steps":steps,"source_time":sim.hero_time,"action":action,"distance_moved":before.distance_to(sim.hero.position),"stun_left":sim.hero.stun_left,"basic_count":sim.ink_basics.size(),"wave_count":sim.ink_waves.size()})
  while sim.hero.stun_left>sim.TIME_EPS:sim.step(.02)
  adapter.handle_event(mouse(false),Vector3.ZERO)
  check(sim.request_action("attack",Vector3(9,0,0)).accepted,"BASIC restored after natural control "+operation)
  check(sim.request_action("shift",Vector3(9,0,0)).accepted,"Shift restored after natural control "+operation)
  sim.free()
func test_duration_immunity_and_recovery()->void:
 var sim=fresh();sim.hero.stats.tenacity=.25;sim.damage_hero(1,Vector3.ZERO,.20)
 near(sim.hero.stun_left,.15,"shared tenacity applied exactly once")
 sim.hero.move_intent=Vector3.RIGHT;sim.step(.14);near(sim.hero.position.x,0,"no walk before .15 control expires")
 sim.step(.02);near(sim.hero.position.x,.06,"only .01s leftover locomotion after .15 expiry")
 check(sim.ink_core_steps==8,"subtick control boundary adds no world/AI steps")
 check(sim.request_action("attack",Vector3(9,0,0)).accepted,"attack restored at actual expiry")
 sim.free()
 sim=fresh();sim.request_action("shift",Vector3(9,0,0));sim.damage_hero(100,Vector3.ZERO,.20)
 near(sim.hero.hp,360,"Shift source immunity prevents damage");near(sim.hero.stun_left,0,"Shift immunity prevents control")
 sim.step(.2);sim.damage_hero(1,Vector3.ZERO,.20);near(sim.hero.stun_left,.2,"post-source-iframe control applies")
 var at:Vector3=sim.hero.position;sim.step(.06);check(sim.hero.position==at,"controlled remaining dash consumes time without moving")
 near(sim.hero.dash_left,0,"controlled dash cannot bank delayed travel")
 sim.step(.14);check(sim.hero.position==at,"no delayed dash after control clears")
 sim.free()
 sim=fresh();sim.damage_hero(1,Vector3.ZERO,.2);sim.hero.invulnerable_left=.5
 check(not sim.request_action("attack",Vector3(9,0,0)).accepted,"new immunity does not cleanse existing stun")
 sim.step(.2);check(sim.request_action("attack",Vector3(9,0,0)).accepted,"existing control expires normally while immune")
 sim.free()
 sim=fresh();sim.damage_hero(1,Vector3.ZERO,1);sim.end_encounter("victory");sim.free_move(.1,Vector3.RIGHT)
 near(sim.hero.position.x,.6,"safe movement never locked by undrained combat stun");near(sim.hero.stun_left,0,"encounter boundary clears stale stun")
 sim.begin_encounter("next",[]);check(sim.request_action("attack",Vector3(9,0,0)).accepted,"next room has no stale combat control")
 check(not sim.request_action("e",Vector3(9,0,0)).accepted,"unimplemented E/H07 not opened by future exception hook")
 sim.free()
func test_motion_and_live_flights()->void:
 var sim=fresh();var enemy:Dictionary=sim.spawn_enemy("minion",Vector3(0,0,-6),10000);enemy.state="chase";enemy.defence=0
 sim.request_action("attack",Vector3(0,0,-9));release_q(sim,Vector3.ZERO,Vector3(0,0,-11))
 sim.damage_hero(1,Vector3.ZERO,.5);sim.hero.move_intent=Vector3.RIGHT;sim.step(.3)
 near(sim.hero.position.x,0,"control blocks walking while flight stays live")
 near(enemy.hp,9899,"already flying BASIC and Q1 both retain normal damage")
 check(sim.ink_receipts.size()==2,"no blanket projectile cancellation on control")
 sim.move_during_hitstop(.1,Vector3.RIGHT);near(sim.hero.position.x,0,"hitstop does not bypass actual stun")
 sim.free()
 sim=fresh();sim.hero.move_intent=Vector3.RIGHT
 sim.request_ink_input("q_down");sim.request_ink_input("left_down",Vector3.ZERO);sim.request_ink_input("motion",Vector3(0,0,-5));sim.step(.02)
 near(sim.hero.position.x,.12,"ordinary Q drawing permits walking")
 sim.request_ink_input("left_up",Vector3(0,0,-5));sim.request_action("attack",Vector3(0,0,-9));sim.step(.02)
 near(sim.hero.position.x,.24,"ordinary Q/BASIC casting permits walking")
 sim.move_during_hitstop(.1,Vector3.RIGHT);near(sim.hero.position.x,.84,"cosmetic hitstop alone permits walking")
 sim.free()
func test_idle_cancel()->void:
 var sim=fresh();var adapter=Adapter.new();adapter.bind(sim)
 adapter.handle_event(mouse(true),Vector3(9,0,0));var serial:int=sim.cast_serial
 var result:Dictionary=adapter.handle_event(key(KEY_ESCAPE));check(not result.accepted and result.reason=="no_preview_to_cancel","idle Esc is preview no-op")
 sim.step(1.18);check(adapter.update_held_basic(Vector3(9,0,0)).accepted,"idle Esc preserves held BASIC")
 var right=InputEventMouseButton.new();right.button_index=MOUSE_BUTTON_RIGHT;right.pressed=true
 adapter.handle_event(right);sim.step(1.18);check(adapter.update_held_basic(Vector3(9,0,0)).accepted,"idle RMB preserves held BASIC")
 check(sim.cast_serial==serial+2,"idle cancel never inserts additional cast")
 check(not adapter.handle_event(key(KEY_Q)).accepted,"idle cancel does not clear physical-held ownership")
 sim.request_ink_input("escape");check(not sim.request_ink_input("q_down").accepted,"direct idle cancel retains simulated-held ownership")
 adapter.handle_event(mouse(false));adapter.handle_event(key(KEY_Q));adapter.handle_event(mouse(true),Vector3.ZERO)
 var motion=InputEventMouseMotion.new();adapter.handle_event(motion,Vector3(0,0,-5));adapter.handle_event(right);sim.step(1.2)
 check(not adapter.update_held_basic(Vector3(9,0,0)).accepted,"real preview cancellation still suppresses same held gesture")
 adapter.handle_event(mouse(false));check(adapter.handle_event(mouse(true),Vector3(9,0,0)).accepted,"fresh down after canceled preview restores BASIC")
 sim.free()
func test_terminal_frame()->void:
 var path:Array=[Vector3.ZERO,Vector3(3,0,0),Vector3(3,0,3),Vector3(3,0,3)]
 var frame:Dictionary=Geometry.frame_at(path,6.0)
 check(frame.position==Vector3(3,0,3),"zero final leg terminal retains endpoint")
 check(frame.direction==Vector3.BACK and frame.segment_index==1,"zero final leg retains last valid direction and segment")
 var sim=fresh();sim.set_hexes(["yanguizhou_h01"]);sim.request_ink_input("q_down");sim.request_ink_input("left_down",Vector3.ZERO)
 for point in [Vector3(3,0,0),Vector3(3,0,3),Vector3(6,0,3),Vector3(3,0,3)]:sim.request_ink_input("motion",point)
 check(sim.ink_input.path==path,"legal H01 zero trailing leg remains unchanged")
 sim.request_ink_input("left_up",Vector3(3,0,3));sim.step(.26)
 check(sim.ink_finished.size()==1,"six-metre wave terminates once")
 check(sim.ink_finished[0].front_direction==Vector3.BACK and sim.ink_finished[0].segment_index==1,"authoritative terminal presenter frame fixed")
 near(sim.ink_finished[0].path_length,6,"no path length rewrite")
 sim.free()
