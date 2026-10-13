extends SceneTree
const Sim=preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_sim.gd")
const Geometry=preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_geometry.gd")
const InputAdapter=preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_input_adapter.gd")
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func near(a:float,b:float,label:String,tolerance:float=0.00001)->void:check(absf(a-b)<=tolerance,"%s: %s vs %s"%[label,a,b])
func fresh(rank:int=1,h01:bool=false):
 var sim=Sim.new();root.add_child(sim)
 sim.hero.position=Vector3.ZERO;sim.ai_enabled=false;sim.auto_finish=false
 sim.hero.loadout.q="q1";sim.hero.ranks.q=rank
 if h01:sim.set_hexes(["yanguizhou_h01"])
 sim.begin_encounter("ink-test",[])
 return sim
func target(sim,position:Vector3,kind:String="minion",hp:float=10000.0)->Dictionary:
 var enemy:Dictionary=sim.spawn_enemy(kind,position,hp);enemy.state="chase";enemy.defence=0.0
 return enemy
func draw(sim,start:Vector3,end:Vector3)->Dictionary:
 check(sim.request_ink_input("q_down").accepted,"Q arms")
 check(sim.request_ink_input("left_down",start).accepted,"LMB admits fixed start")
 sim.request_ink_input("motion",end)
 return sim.request_ink_input("left_up",end)
func _initialize()->void:call_deferred("run")
func run()->void:
 test_source();test_input_boundaries();test_time_and_movement();test_h01();test_wave_contacts();test_basic_and_shift();test_geometry();test_lifecycle_and_readonly();test_event_adapter();test_partition();test_cross_family_order();test_world_cadence();test_hold_input();test_wall_and_retrace()
 var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"isolated finite BASIC/Shift/Q1/H01 engine mechanism checks only; not art/input-device/full hero acceptance"}
 var file=FileAccess.open("res://tests/ink_q1_foundation_20261004/revision02/engine_result.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "));file.close()
 print("INK_FOUNDATION_REPORT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func test_source()->void:
 var sim=fresh()
 check(sim.source_rules_hash==sim.EXPECTED_RULES_HASH,"actual source13 hash")
 for pair in [["ATK-1",100.0],["ATK-2",0.85],["ATK-3",9.0],["ATK-4",0.55],["ATK-5",22.0],["D-1",4.5],["D-2",0.25],["D-3",0.2],["D-4",4.0],["Q1-1",65.0],["Q1-2",85.0],["Q1-3",1.5],["Q1-4",11.0],["Q1-5",1.6],["Q1-6",0.75],["Q1-7",24.0],["Q1-8",7.0]]:near(sim.v(pair[0]),pair[1],"source "+pair[0])
 sim.free()
func test_input_boundaries()->void:
 var sim=fresh();var enemy=target(sim,Vector3(10,0,0))
 var rng_before:int=sim.rng.state
 sim.request_ink_input("q_down")
 var serial:int=sim.cast_serial
 var rejected:Dictionary=sim.request_ink_input("left_down",Vector3(10.00001,0,0))
 check(not rejected.accepted and rejected.reason=="initial_point_out_of_range","outside range rejected, not clamped")
 check(sim.ink_input.phase=="armed" and sim.ink_input.path.is_empty(),"rejected start produces no geometry")
 sim.request_ink_input("left_up",Vector3(10,0,0))
 check(sim.request_ink_input("left_down",Vector3(10,100,0)).accepted,"exact boundary uses ground XZ")
 var gesture:String=sim.ink_input.gesture_id
 sim.request_ink_input("motion",Vector3(10,0,-11))
 check(sim.ink_input.phase=="frozen" and sim.ink_input.freeze_reason=="length_limit","exact11m freezes")
 var fixed:Array=sim.ink_input.path.duplicate(true)
 sim.request_ink_input("motion",Vector3.ZERO)
 check(sim.ink_input.path==fixed,"length freeze cannot reopen")
 check(sim.cast_serial==serial and sim.ink_waves.is_empty() and sim.ink_basics.is_empty(),"preview creates no cast, wave, or stolen basic")
 near(enemy.hp,10000,"preview has no damage");near(sim.hero.cooldowns.q,0,"preview no cooldown");check(sim.rng.state==rng_before,"preview consumes no crit roll")
 sim.request_ink_input("q_up")
 check(sim.ink_waves.is_empty(),"Q-up never releases")
 var release:Dictionary=sim.request_ink_input("left_up",Vector3.ZERO,"release-once",gesture,sim.encounter_generation)
 check(release.accepted and sim.cast_serial==serial+1,"physical mouse-up one cast")
 var count:int=sim.ink_waves.size()
 check(sim.request_ink_input("left_up",Vector3.ZERO,"release-once",gesture,sim.encounter_generation)==release,"duplicate command returns original receipt")
 check(sim.ink_waves.size()==count,"duplicate release no second wave")
 check(not sim.request_ink_input("left_up").accepted,"unpaired up rejected")
 sim.free()
 for action in ["right_down","escape","focus_lost"]:
  sim=fresh();sim.request_ink_input("q_down");sim.request_ink_input("left_down",Vector3.ZERO);sim.request_ink_input("motion",Vector3(0,0,-8));sim.request_ink_input(action)
  check(sim.ink_input.phase=="idle" and sim.cast_serial==0 and sim.ink_waves.is_empty(),"cancel no effects "+action)
  check(not sim.request_ink_input("left_up",Vector3(0,0,-8)).accepted,"cancel suppresses stale up "+action);sim.free()
 sim=fresh();sim.request_ink_input("q_down");check(not sim.request_ink_input("left_down",Vector3.INF).accepted,"invalid projection rejected");sim.request_ink_input("left_up")
 sim.request_ink_input("left_down",Vector3.ZERO);check(sim.request_ink_input("left_up",Vector3.ZERO).reason=="zero_length","zero-length cancels without damage/CD");near(sim.hero.cooldowns.q,0,"zero-length no cooldown");sim.free()
func test_time_and_movement()->void:
 var sim=fresh();sim.request_ink_input("q_down");sim.request_ink_input("left_down",Vector3(7,0,0));sim.request_ink_input("motion",Vector3(7,0,-6))
 sim.hero.move_intent=Vector3.LEFT;sim.step(0.74)
 check(sim.ink_input.phase=="drawing","before .75 still drawing")
 sim.step(0.02)
 check(sim.ink_input.phase=="frozen",".75 freezes within core tick");near(sim.ink_input.frozen_at,0.75,"exact draw freeze source clock")
 near(sim.ink_input.start.x,7,"hero walking never drags start");check(sim.hero.position.x<0,"walking remains enabled during drawing")
 var path:Array=sim.ink_input.path.duplicate(true)
 sim.move_during_hitstop(0.2,Vector3.LEFT);check(sim.ink_input.path==path,"hitstop movement does not move fixed start")
 check(sim.request_ink_input("left_up",Vector3(7,0,-1)).accepted,"release valid after hero moved outside initial radius")
 check(sim.ink_waves[0].path==path,"release uses frozen path, not current cursor")
 var snapshot:Dictionary=sim.snapshot();sim.paused=true;var pause_snap:Dictionary=sim.snapshot();sim.step(1.0);check(sim.snapshot()==pause_snap,"pause freezes source state");sim.paused=false
 check(snapshot.ink.waves[0].path==path,"released immutable path");sim.free()
func test_h01()->void:
 var sim=fresh(1,true);sim.request_ink_input("q_down");sim.request_ink_input("left_down",Vector3.ZERO)
 near(sim.ink_input.length_cap,13.2,"H01 length +20 percent");near(sim.tuning.q1_initial_placement_range_m,10,"H01 does not change placement radius")
 for p in [Vector3(3,0,0),Vector3(3,0,3),Vector3(6,0,3),Vector3(6,0,10)]:sim.request_ink_input("motion",p)
 check(sim.ink_input.path.size()==4 and sim.ink_input.committed_corners==2,"H01 max two corners")
 near(Geometry.path_length(sim.ink_input.path),13.2,"H01 clips actual total arc length")
 check(sim.ink_input.phase=="frozen","H01 total length freezes")
 sim.free()
 sim=fresh();sim.request_ink_input("q_down");sim.request_ink_input("left_down",Vector3.ZERO)
 for p in [Vector3(3,0,0),Vector3(3,0,3),Vector3(6,0,3)]:sim.request_ink_input("motion",p)
 check(sim.ink_input.path.size()==2,"base never gets free corners");sim.free()
func test_wave_contacts()->void:
 var sim=fresh();sim.hero.stats.ap=100;var near_enemy=target(sim,Vector3(0,0,-3));var far_enemy=target(sim,Vector3(0,0,-9));var off=target(sim,Vector3(3,0,-5));var boss=target(sim,Vector3(0,0,-6),"boss")
 var release:Dictionary=draw(sim,Vector3.ZERO,Vector3(0,0,-11));check(release.accepted,"wave released")
 near(near_enemy.hp,10000,"release no whole-line hitscan")
 sim.step(0.04);near(sim.ink_waves[0].front_distance,0.96,"actual24m/s front");near(far_enemy.hp,10000,"future path enemy not hit")
 sim.step(0.10);near(near_enemy.hp,9850,"rank1 ordinary65+85percent AP")
 check(not near_enemy.push.is_empty(),"movable target receives source push");near(near_enemy.push.distance,1.5,"source push distance")
 sim.step(0.34);near(far_enemy.hp,9850,"moving front eventually reaches far enemy");near(off.hp,10000,"off-path excluded");near(boss.hp,9850,"Boss receives normal damage");check(boss.push.is_empty(),"Boss classification rejects push")
 check(sim.ink_waves.is_empty() and sim.ink_finished.size()==1,"wave retires at actual endpoint")
 near(sim.ink_finished[0].finished_at,11.0/24.0,"source terminal time exact");near(sim.hero.cooldowns.q,7.0-0.48,"Q cooldown began at release")
 var receipts:Array=sim.ink_receipts.duplicate(true);check(receipts.size()==3,"one authoritative receipt per target")
 sim.step(1.0);near(far_enemy.hp,9850,"no persistent wake repeats damage");near(near_enemy.position.z,-4.5,"push completes source distance without fabricated collision damage")
 sim.free()
 sim=fresh();var at_start=target(sim,Vector3.ZERO);draw(sim,Vector3.ZERO,Vector3(0,0,-4));near(at_start.hp,9935,"start overlap hits at release without visual delay");near(sim.ink_receipts[0].contact_time,0,"zero travel contact timestamp");sim.free()
func test_basic_and_shift()->void:
 var sim=fresh();var off=target(sim,Vector3(3,0,-4));var on=target(sim,Vector3(0,0,-6))
 check(not sim.request_action("attack").accepted,"BASIC requires manual ground aim")
 check(sim.request_action("attack",Vector3(0,0,-9)).accepted,"manual BASIC accepted")
 near(on.hp,10000,"BASIC is traveling not hitscan");sim.step(0.1);near(sim.ink_basics[0].front_distance,2.2,"BASIC speed22");check(not sim.request_action("attack",Vector3(0,0,-9)).accepted,"BASIC source cadence enforced")
 sim.step(0.3);near(on.hp,9964,"BASIC100percent AD");near(off.hp,10000,"BASIC no target auto-lock")
 sim.free()
 sim=fresh();sim.hero.stats.crit_chance=1.0;var enemy=target(sim,Vector3(0,0,-2));sim.request_action("attack",Vector3(0,0,-9));sim.step(.1);near(enemy.hp,10000-36*1.75,"BASIC shared crit multiplier once");check(sim.ink_receipts[0].critical,"critical receipt retained");sim.free()
 sim=fresh();sim.hero.move_intent=Vector3.LEFT;check(sim.request_action("shift",Vector3(0,0,-10)).accepted,"mouse Shift accepted despite opposite movement")
 sim.damage_hero(100,Vector3.ZERO,1);near(sim.hero.hp,360,"Shift damage immunity starts");sim.step(.18);sim.damage_hero(100,Vector3.ZERO,1);near(sim.hero.hp,360,"Shift before .20 immune")
 sim.step(.02);sim.damage_hero(100,Vector3.ZERO,1);check(sim.hero.hp<360 and sim.hero.stun_left>0,"Shift .20 damage/control immunity ends")
 sim.step(.06);near(sim.hero.position.z,-3.6,"post-iframe control stops remaining accepted Shift travel");near(sim.hero.position.x,0.0,"control blocks remaining walking");near(sim.hero.cooldowns.shift,3.74,"Shift source CD4");sim.free()
func test_geometry()->void:
 near(Geometry.moving_front_contact(Vector3.ZERO,Vector3(0,0,-10),Vector3.FORWARD,1.6,Vector3(0,0,-5),Vector3(0,0,-5),0.5),.45,"finite front exact stationary circle entry")
 check(not is_finite(Geometry.moving_front_contact(Vector3.ZERO,Vector3(0,0,-10),Vector3.FORWARD,1.6,Vector3(1.31,0,-5),Vector3(1.31,0,-5),.5)),"outside width plus radius misses")
 check(is_finite(Geometry.moving_front_contact(Vector3.ZERO,Vector3(0,0,-10),Vector3.FORWARD,1.6,Vector3(-5,0,-5),Vector3(5,0,-5),.2)),"moving target crossing between samples caught")
 check(not is_finite(Geometry.moving_front_contact(Vector3.ZERO,Vector3(0,0,-1),Vector3.FORWARD,1.6,Vector3(1.2,0,-1.4),Vector3(1.2,0,-1.4),.5)),"rounded corner does not use false expanded-box hit")
func test_lifecycle_and_readonly()->void:
 var sim=fresh();target(sim,Vector3(0,0,-6));draw(sim,Vector3.ZERO,Vector3(0,0,-11))
 var snap:Dictionary=sim.ink_presenter_snapshot();snap.waves[0].path[0]=Vector3(999,0,999);snap.waves.clear()
 check(sim.ink_waves.size()==1 and sim.ink_waves[0].path[0]==Vector3.ZERO,"presenter snapshots detached")
 var old_generation:int=sim.encounter_generation;sim.end_encounter("victory");sim.begin_encounter("next",[]);var enemy=target(sim,Vector3(0,0,-6));sim.step(1.0)
 near(enemy.hp,10000,"old wave cannot hit new room");check(not sim.request_ink_input("left_up",Vector3.ZERO,"late","old",old_generation).accepted,"stale generation input rejected")
 sim.free()
 sim=fresh();var holder:Array=[sim];target(sim,Vector3(0,0,-3))
 var attempted:Array=[]
 sim.combat_event.connect(func(event):
  if event.kind=="damage":
   holder[0].end_encounter("forced_callback")
   attempted.append(holder[0].begin_encounter("legal_reentry",[])))
 draw(sim,Vector3.ZERO,Vector3(0,0,-4));sim.step(.2)
 check(attempted.size()==1 and attempted[0].accepted,"step damage callback retains legal end/begin reentry")
 check(sim.room_id=="legal_reentry","new epoch retained")
 check(sim.ink_receipts.is_empty() and sim.ink_waves.is_empty(),"ended epoch does not publish stale contact receipt")
 check(sim.common._inside_hit==0,"scope abort releases hit nesting")
 sim.free()

func test_event_adapter()->void:
 var sim=fresh();var adapter=InputAdapter.new();adapter.bind(sim)
 var q=InputEventKey.new();q.physical_keycode=KEY_Q;q.pressed=true
 check(adapter.handle_event(q).accepted,"OS key adapter arms")
 q.echo=true;check(not adapter.handle_event(q).accepted,"OS key repeat ignored")
 var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true
 check(adapter.handle_event(down,Vector3.ZERO).accepted,"OS mouse-down adapter")
 var motion=InputEventMouseMotion.new();adapter.handle_event(motion,Vector3(0,0,-5));down.pressed=false
 check(adapter.handle_event(down,Vector3(0,0,-5)).accepted,"OS mouse-up releases")
 adapter.focus_lost();check(sim.hero.move_intent==Vector3.ZERO,"focus clears held movement")
 sim.free()
func test_partition()->void:
 var a=fresh();var b=fresh();target(a,Vector3(0,0,-8));target(b,Vector3(0,0,-8))
 draw(a,Vector3.ZERO,Vector3(0,0,-11));draw(b,Vector3.ZERO,Vector3(0,0,-11));a.step(.6)
 for _i in range(30):b.step(.02)
 check(a.snapshot()==b.snapshot(),"fixed-step partitions identical");check(a.event_log==b.event_log,"fixed-step contact/event ordering identical");a.free();b.free()

func test_cross_family_order()->void:
 # BASIC is accepted first, but a remotely placed Q1 front reaches the 40HP
 # target earlier during the same shared tick. Wrong family-order gives BASIC.
 var sim=fresh();var enemy=target(sim,Vector3(0,0,-2),"minion",40.0)
 sim.request_action("attack",Vector3(0,0,-9))
 sim.step(.04)
 draw(sim,Vector3(0,0,-1.0),Vector3(0,0,-5.0))
 sim.step(.04)
 check(enemy.dead,"cross-family lethal target dies")
 var receipts:Array=sim.ink_receipts.filter(func(r):return r.target_id==enemy.actor_id)
 # The source setup above produces BASIC at .07 and Q1 at .0625: Q1 must
 # be lethal first, so only the Q1 contact may commit. Keep exact assertion.
 check(receipts.size()==1 and receipts[0].source=="q1","earlier Q1 arrival beats later BASIC despite family/accept order")
 sim.free()
 # Reverse order: BASIC arrives sooner and is lethal; later Q1 cannot claim hit.
 sim=fresh();enemy=target(sim,Vector3(0,0,-2),"minion",30.0)
 draw(sim,Vector3(0,0,1),Vector3(0,0,-6));sim.request_action("attack",Vector3(0,0,-9));sim.step(.14)
 receipts=sim.ink_receipts.filter(func(r):return r.target_id==enemy.actor_id)
 check(receipts.size()==1 and receipts[0].source=="attack","earlier BASIC arrival beats later Q1")
 sim.free()
func test_world_cadence()->void:
 var a=fresh();var b=fresh();a.ai_enabled=true;b.ai_enabled=true
 target(a,Vector3(15,0,15));target(b,Vector3(15,0,15))
 draw(b,Vector3(-8,0,0),Vector3(-8,0,-11))
 a.step(1.3);b.step(1.3)
 check(a.ink_core_steps==65 and b.ink_core_steps==65,"65 external ticks produce exactly65 shared core calls")
 near(a.clock.world_time,b.clock.world_time,"Q1 terminal adds no world time step")
 near(a.enemy_director.time,b.enemy_director.time,"Q1 terminal adds no AI time step")
 check(a.enemies==b.enemies,"65-step actual enemy AI state matches no-wave reference")
 check(a.rng.state==b.rng.state and a.common.runtime.rng.state==b.common.runtime.rng.state,"65-step hero/common RNG unchanged by extra world calls")
 a.free();b.free()
func key_event(code:int,pressed:bool=true)->InputEventKey:
 var event=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed;return event
func mouse_event(pressed:bool)->InputEventMouseButton:
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;return event
func test_hold_input()->void:
 var sim=fresh();var adapter=InputAdapter.new();adapter.bind(sim)
 adapter.handle_event(mouse_event(true),Vector3(0,0,-9))
 check(not adapter.handle_event(key_event(KEY_Q),Vector3.ZERO).accepted,"Q cannot steal already held BASIC gesture")
 sim.step(1.18);check(adapter.update_held_basic(Vector3(9,0,0)).accepted,"held BASIC repeats after source cadence")
 check(sim.ink_basics.back().front_direction==Vector3.RIGHT,"each held BASIC samples current mouse aim")
 check(not adapter.update_held_basic(Vector3(9,0,0)).accepted,"held poll cannot bypass cooldown")
 adapter.handle_event(mouse_event(false),Vector3.ZERO);sim.step(1.2);check(not adapter.update_held_basic(Vector3(9,0,0)).accepted,"mouse-up stops repeated BASIC")
 check(adapter.handle_event(key_event(KEY_Q)).accepted,"release then Q arm succeeds")
 adapter.handle_event(mouse_event(true),Vector3.ZERO);sim.request_ink_input("motion",Vector3(0,0,-5));sim.step(.8)
 check(sim.ink_input.phase=="frozen","held Q preview time-freezes")
 var count:int=sim.hero.attack_index
 check(not adapter.update_held_basic(Vector3(0,0,-9)).accepted and sim.hero.attack_index==count,"frozen Q hold never leaks BASIC")
 adapter.handle_event(key_event(KEY_ESCAPE));sim.step(1.2)
 check(not adapter.update_held_basic(Vector3(0,0,-9)).accepted,"cancel while physical held suppresses BASIC")
 check(not adapter.handle_event(mouse_event(true),Vector3.ZERO).accepted,"duplicate physical down after cancel rejected")
 adapter.handle_event(mouse_event(false),Vector3.ZERO)
 check(adapter.handle_event(mouse_event(true),Vector3(0,0,-9)).accepted,"fresh physical down after release can fire")
 adapter.focus_lost();sim.step(1.2);check(not adapter.update_held_basic(Vector3(0,0,-9)).accepted,"focus loss suppresses physical hold")
 adapter.handle_event(mouse_event(false),Vector3.ZERO);adapter.handle_event(mouse_event(true),Vector3(0,0,-9));sim.paused=true;adapter.update_held_basic(Vector3(0,0,-9));sim.paused=false;sim.step(1.2)
 check(not adapter.update_held_basic(Vector3(0,0,-9)).accepted,"pause resumes without auto-firing old held input")
 sim.end_encounter("victory");sim.begin_encounter("next",[]);check(not adapter.update_held_basic(Vector3(0,0,-9)).accepted,"new room suppresses old held input")
 sim.free()
func test_wall_and_retrace()->void:
 var sim=fresh();sim.obstacles=[{"position":Vector3(0,0,-3),"half":Vector3(1,0,0.2)}]
 var enemy=target(sim,Vector3(0,0,-5));sim.request_action("attack",Vector3(0,0,-9));sim.step(.4);near(enemy.hp,10000,"BASIC obstacle stops front")
 draw(sim,Vector3.ZERO,Vector3(0,0,-7));sim.step(.4);near(enemy.hp,9935,"Q1-only current static-wall interpretation documented")
 sim.free()
 sim=fresh(1,true);enemy=target(sim,Vector3(2,0,0),"boss");enemy.radius=.2
 sim.request_ink_input("q_down");sim.request_ink_input("left_down",Vector3.ZERO)
 for point in [Vector3(4,0,0),Vector3(0,0,0)]:sim.request_ink_input("motion",point)
 sim.request_ink_input("left_up",Vector3.ZERO);sim.step(.5)
 near(enemy.hp,9935,"H01 retrace same enemy once current technical interpretation")
 check(sim.ink_receipts.size()==1,"H01 retrace no duplicate contact receipt")
 sim.free()
