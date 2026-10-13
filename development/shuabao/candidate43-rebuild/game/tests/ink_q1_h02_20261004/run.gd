extends SceneTree
const Sim=preload("res://tests/ink_q1_h02_20261004/ink_h02_sim.gd")
const Adapter=preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_input_adapter.gd")
var checks:int=0
var failures:Array=[]
var observations:Dictionary={}
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func near(a:float,b:float,label:String,tolerance:float=.00001)->void:check(absf(a-b)<=tolerance,"%s: %.9f vs %.9f"%[label,a,b])
func fresh(selected:bool=true):
 var sim=Sim.new();root.add_child(sim);sim.hero.position=Vector3.ZERO;sim.auto_finish=false;sim.ai_enabled=false;sim.hero.loadout.q="q1";sim.hero.ranks.q=1
 sim.begin_encounter("h02-finite",[])
 if selected:sim.set_hexes(["yanguizhou_h02"])
 return sim
func target(sim,at:Vector3,kind:String="minion")->Dictionary:
 var enemy:Dictionary=sim.spawn_enemy(kind,at,10000)
 enemy.state="chase";enemy.defence=0;enemy.radius=.25
 return enemy
func cast(sim,points:Array)->Dictionary:
 check(sim.request_ink_input("q_down").accepted,"Q1 manually armed")
 check(sim.request_ink_input("left_down",points[0]).accepted,"Q1 mouse start admitted")
 for point in points.slice(1):sim.request_ink_input("motion",point)
 return sim.request_ink_input("left_up",points.back())
func events(sim,kind:String)->Array:return sim.event_log.filter(func(event):return event.kind==kind)
func _initialize()->void:call_deferred("run")
func run()->void:
 test_source_and_endpoint();test_precise_lifetime();test_wall_and_eligibility();test_ai_center_and_damage();test_h01_endpoint();test_ownership_cancel_rooms();test_callback_cleanup();test_concurrent_sources()
 var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"scope":"finite real H02 source mechanism; no engine run claimed until this report is emitted by main's Godot; no renderer or complete hero acceptance"}
 var f=FileAccess.open("res://tests/ink_q1_h02_20261004/engine_result.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("INK_H02_FINITE_REPORT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func test_source_and_endpoint()->void:
 var sim=fresh();var enemy:Dictionary=target(sim,Vector3(4,0,2));var hp:float=enemy.hp
 check(sim.hx("yanguizhou_h02"),"H02 active with learned Q1")
 sim.request_ink_input("q_down");sim.request_ink_input("left_down",Vector3.ZERO);sim.request_ink_input("motion",Vector3(4,0,0));sim.step(.1)
 check(sim.ink_vortices.is_empty() and sim.ink_waves.is_empty(),"held preview never creates wave or H02")
 check(sim.request_ink_input("left_up",Vector3(4,0,0)).accepted,"actual mouse release starts Q1")
 var released:float=sim.hero_time
 near(sim.ink_waves[0].width,1.6,"Q1 unchanged width");near(sim.ink_waves[0].speed,24,"Q1 unchanged speed")
 sim.step(.16);check(sim.ink_vortices.is_empty(),"H02 not spawned before actual endpoint")
 sim.step(.02);check(sim.ink_vortices.size()==1,"one H02 at actual endpoint")
 var v:Dictionary=sim.ink_vortices[0]
 near(v.born_at,released+4.0/24.0,"subtick actual endpoint source time")
 near(v.radius,3.2,"source H02 radius");near(v.duration,2.5,"source H02 duration");near(v.pull_speed,3,"source H02 pull speed")
 check(v.position==Vector3(4,0,0),"actual endpoint is vortex center")
 near(enemy.position.z,1.96,"newborn H02 exact remaining .013333s pull")
 var before:Vector3=enemy.position
 sim._settle_h02_interval(released+.16,sim.hero_time);sim._settle_h02_interval(released+.16,sim.hero_time)
 check(enemy.position==before and sim.ink_vortices.size()==1,"duplicate interval samples neither re-pull nor respawn")
 sim.step(.02);near(enemy.position.z,1.9,"normal .02s interval pulls exactly .06m")
 near(enemy.hp,hp,"H02 adds no damage")
 var snapshot:Dictionary=sim.ink_presenter_snapshot();snapshot.vortices[0].position=Vector3(999,0,999)
 check(v.position==Vector3(4,0,0),"presenter snapshot detached from mechanism")
 check(events(sim,"ink_h02_created").size()==1,"exactly one readable creation event")
 observations["subtick_birth"]={"born_at":v.born_at,"first_step_pull_m":.04,"wave_width_m":1.6,"wave_speed_mps":24.0}
 sim.free()
 sim=fresh(false);cast(sim,[Vector3.ZERO,Vector3(4,0,0)]);sim.set_hexes(["yanguizhou_h02"]);sim.step(.2)
 check(sim.ink_vortices.is_empty(),"late acquisition does not retrofit a released wave")
 sim.hero.ranks.q=0;check(not sim.hx("yanguizhou_h02"),"unlearned Q1 keeps H02 inactive")
 sim.free()
func test_precise_lifetime()->void:
 var sim=fresh();var enemy:Dictionary=target(sim,Vector3(4,0,2));cast(sim,[Vector3.ZERO,Vector3(4,0,0)])
 var total:float=0.0
 for i in range(140):
  enemy.position=Vector3(4,0,2)
  var before:Vector3=enemy.position;sim.step(.02);total+=before.distance_to(enemy.position)
 near(total,7.5,"exact 2.5 seconds times 3m/s accumulated real distance")
 check(sim.ink_vortices.is_empty(),"vortex expires without extra tick lifetime")
 check(sim.ink_vortex_finished.size()==1 and sim.ink_vortex_finished[0].reason=="expired","one expiry receipt")
 near(sim.ink_vortex_finished[0].finished_at,4.0/24.0+2.5,"exact expiry time")
 observations["active_distance_budget_m"]=total
 sim.free()
 sim=fresh();cast(sim,[Vector3.ZERO,Vector3(4,0,0)]);sim.step(.2)
 var before:float=sim.hero_time;var remaining:float=sim.ink_presenter_snapshot().vortices[0].remaining
 sim.paused=true;sim.step(5.0);near(sim.hero_time,before,"pause freezes source clock");near(sim.ink_presenter_snapshot().vortices[0].remaining,remaining,"pause does not consume H02 lifetime")
 sim.paused=false;sim.move_during_hitstop(.1,Vector3.RIGHT);near(sim.hero_time,before,"hitstop locomotion does not advance H02 source time")
 sim.free()
func test_wall_and_eligibility()->void:
 var sim=fresh();var ordinary:Dictionary=target(sim,Vector3(4,0,2));var elite:Dictionary=target(sim,Vector3(4,0,-2),"elite");var boss:Dictionary=target(sim,Vector3(6,0,2),"boss")
 var outside:Dictionary=target(sim,Vector3(4,0,3.46));var boundary:Dictionary=target(sim,Vector3(4,0,-3.45))
 var spawn:Dictionary=target(sim,Vector3(5,0,2));spawn.state="spawn";spawn.timer=10
 var dead:Dictionary=target(sim,Vector3(3,0,2));dead.dead=true
 cast(sim,[Vector3.ZERO,Vector3(4,0,0)]);sim.step(.2)
 near(ordinary.position.z,1.9,"ordinary eligible");near(elite.position.z,-1.9,"elite not given new immunity")
 check(boss.position==Vector3(6,0,2),"existing Boss pull immunity")
 check(outside.position==Vector3(4,0,3.46),"outside circle plus enemy radius excluded")
 near(boundary.position.z,-3.35,"existing touching-circle boundary admitted")
 check(spawn.position==Vector3(5,0,2) and dead.position==Vector3(3,0,2),"spawn/dead excluded")
 sim.free()
 sim=fresh();ordinary=target(sim,Vector3(4,0,2));sim.obstacles=[{"position":Vector3(4,0,1),"half":Vector3(.7,0,.05)}]
 cast(sim,[Vector3.ZERO,Vector3(4,0,0)]);sim.step(1.4)
 check(ordinary.position.z>=1.3 and ordinary.position.z<1.301,"pull blocked at expanded wall face with no tunnelling")
 check(events(sim,"ink_h02_pull").any(func(event):return event.blocked),"wall blocked distance is readable")
 check(ordinary.pull_state.is_empty(),"no leaked pull state after wall sample")
 sim.free()
 sim=fresh();sim.obstacles=[{"position":Vector3(2,0,0),"half":Vector3(.05,0,.8)}]
 cast(sim,[Vector3.ZERO,Vector3(4,0,0)]);sim.step(.18)
 check(sim.ink_vortices.size()==1 and sim.ink_vortices[0].position==Vector3(4,0,0),"base Q1 wall-transparent path keeps actual final endpoint")
 check(sim.ink_finished[0].reason=="path_end","Q1 not changed into wall termination")
 sim.free()
func test_ai_center_and_damage()->void:
 var sim=fresh();cast(sim,[Vector3.ZERO,Vector3(4,0,0)]);sim.step(.18)
 var enemy:Dictionary=target(sim,Vector3(4,0,2));enemy.speed=8;enemy.timer=0;sim.ai_enabled=true
 var hp:float=enemy.hp;sim.step(.02)
 near(enemy.position.z,1.94,"active pull does not get a second AI movement in same interval")
 near(enemy.position.x,4,"active pull does not drift toward hero from AI")
 near(enemy.stun_left,0,"H02 never adds stun timer")
 check(enemy.pull_state.is_empty(),"tick-local forced-movement marker cleared after AI")
 enemy.position=Vector3(4,0,0);enemy.state="chase";enemy.timer=0;enemy.was_controlled=false
 var pulls:int=events(sim,"ink_h02_pull").size();sim.step(.02)
 check(enemy.position!=Vector3(4,0,0),"at center zero-distance H02 does not hold/disable AI")
 check(events(sim,"ink_h02_pull").size()==pulls,"at center no repeated zero-distance pull events")
 near(enemy.hp,hp,"active/center H02 never creates damage")
 sim.free()
 sim=fresh();enemy=target(sim,Vector3(2,0,0));var boss:Dictionary=target(sim,Vector3(3,0,0),"boss")
 cast(sim,[Vector3.ZERO,Vector3(4,0,0)]);sim.step(.18)
 near(enemy.hp,9935,"Q1 source damage remains once");near(boss.hp,9935,"H02 Boss immovability does not add damage immunity")
 check(not enemy.push.is_empty(),"H02 does not erase actual Q1 push")
 near(float(enemy.push.distance),1.5,"Q1 actual push parameter unchanged")
 sim.free()
func test_h01_endpoint()->void:
 var sim=fresh();sim.set_hexes(["yanguizhou_h01","yanguizhou_h02"])
 var result:Dictionary=cast(sim,[Vector3.ZERO,Vector3(3,0,0),Vector3(3,0,3),Vector3(6,0,3),Vector3(3,0,3)])
 check(result.accepted,"H01/H02 manual cast accepted")
 check(sim.ink_waves[0].path==[Vector3.ZERO,Vector3(3,0,0),Vector3(3,0,3),Vector3(3,0,3)],"legal H01 repeated endpoint path unchanged")
 sim.step(.24);check(sim.ink_vortices.is_empty(),"H01 corners are not premature H02 endpoints")
 sim.step(.02);check(sim.ink_vortices.size()==1 and sim.ink_vortices[0].position==Vector3(3,0,3),"H01 final repeated endpoint creates exactly one vortex")
 near(sim.ink_vortices[0].born_at,.25,"H01 actual six-meter travel time")
 check(sim.ink_finished[0].front_direction==Vector3.BACK,"H01 final valid segment direction retained")
 sim.free()
func test_ownership_cancel_rooms()->void:
 var sim=fresh();sim.request_ink_input("q_down");sim.request_ink_input("left_down",Vector3.ZERO);sim.request_ink_input("motion",Vector3(4,0,0));sim.request_ink_input("escape");sim.step(.2)
 check(sim.ink_vortices.is_empty() and sim.ink_waves.is_empty(),"cancelled preview never spawns H02")
 cast(sim,[Vector3.ZERO,Vector3(4,0,0)]);var wave:Dictionary=sim.ink_waves[0];sim.step(.1);sim.cancel_cast(int(wave.cast_id));sim.step(.2)
 check(sim.ink_vortices.is_empty(),"mid-flight cast cancellation is not endpoint")
 sim.hero.cooldowns.q=0;cast(sim,[Vector3.ZERO,Vector3(4,0,0)]);sim.step(.18);var old:Dictionary=sim.ink_vortices[0]
 check(old.cast_id==sim.ink_finished.back().cast_id and old.generation==sim.encounter_generation and old.room_id==sim.room_id and old.owner_actor_id=="yanguizhou","cast room generation owner propagated")
 sim.cancel_cast(int(old.cast_id));check(sim.ink_vortices.is_empty(),"active cast cancellation clears H02")
 sim.hero.cooldowns.q=0;cast(sim,[Vector3.ZERO,Vector3(4,0,0)]);sim.step(.18);old=sim.ink_vortices[0]
 var enemy:Dictionary=target(sim,Vector3(4,0,2));sim.end_encounter("victory")
 check(sim.ink_vortices.is_empty() and enemy.pull_state.is_empty(),"room end clears vortex and owned pull")
 sim.begin_encounter("h02-next",[]);var new_enemy:Dictionary=target(sim,Vector3(4,0,2));var before:Vector3=new_enemy.position
 sim._h02_move_target(old,new_enemy,0,100,false);sim.step(.02)
 check(new_enemy.position==before and sim.ink_vortices.is_empty(),"old-room retained effect cannot pull new room")
 sim.free()
func test_callback_cleanup()->void:
 var sim=fresh();sim.combat_event.connect(func(event:Dictionary):
  if event.kind=="ink_q1_finished":sim.end_encounter("victory")
 )
 cast(sim,[Vector3.ZERO,Vector3(4,0,0)]);sim.step(.2)
 check(sim.ink_vortices.is_empty() and events(sim,"ink_h02_created").is_empty(),"endpoint callback departure cannot spawn late H02")
 sim.free()
 sim=fresh();cast(sim,[Vector3.ZERO,Vector3(4,0,0)]);sim.step(.18);target(sim,Vector3(4,0,2));target(sim,Vector3(4,0,-2))
 sim.combat_event.connect(func(event:Dictionary):
  if event.kind=="ink_h02_pull":sim.end_encounter("victory")
 )
 sim.step(.02)
 check(sim.ink_vortices.is_empty() and sim._h02_markers.is_empty(),"pull event departure clears all owned state")
 check(sim.enemies.all(func(enemy):return enemy.pull_state.is_empty()),"no old tick AI marker survives cleanup callback")
 sim.free()

func test_concurrent_sources()->void:
 var sim=fresh();sim.hero.ranks.q=6;sim.hero.stats.cdr=.65
 cast(sim,[Vector3.ZERO,Vector3(4,0,0)]);sim.step(1.9)
 check(sim.hero.cooldowns.q<=sim.TIME_EPS,"natural rank6/CDR source cooldown allows independent second cast")
 cast(sim,[Vector3(1,0,0),Vector3(5,0,0)]);sim.step(.18)
 check(sim.ink_vortices.size()==2,"two independent casts naturally coexist")
 var first:Dictionary=sim.ink_vortices[0];var second:Dictionary=sim.ink_vortices[1]
 check(int(first.cast_id)<int(second.cast_id) and first.vortex_id!=second.vortex_id,"creation order is stable distinct cast identity")
 var enemy:Dictionary=target(sim,Vector3(4,0,2));sim.step(.02)
 near(enemy.position.z,1.94,"overlap uses only one 3m/s speed")
 near(enemy.position.x,4,"stable creation order selects first center")
 check(sim._h02_target_sources[enemy.actor_id].vortex_id==first.vortex_id,"selected source identity retained")
 enemy.position=Vector3(5,0,1);sim.step(.02)
 check(sim._h02_target_sources[enemy.actor_id].vortex_id==first.vortex_id,"closer later source does not steal valid current pull")
 enemy.position=Vector3(7.8,0,0);sim.step(.02)
 check(sim._h02_target_sources[enemy.actor_id].vortex_id==second.vortex_id,"leaving current radius selects next legal creation")
 near(enemy.position.x,7.74,"handoff remains 3m/s without sum")
 var expires:float=second.expires_at
 sim.step(.56)
 check(sim.ink_vortices.size()==1 and sim.ink_vortices[0].vortex_id==second.vortex_id,"older source expires independently")
 near(sim.ink_vortices[0].expires_at,expires,"source change never extends lifetime")
 enemy.dead=true;sim.step(.02);check(not sim._h02_target_sources.has(enemy.actor_id),"dead target releases selected source")
 observations["concurrency"]={"natural_cooldown_s":1.89,"first_cast":first.cast_id,"second_cast":second.cast_id,"policy":"retain current legal source; stable creation order on leave/expiry; one velocity"}
 sim.free()
 # Expiry inside a fixed tick splits only the target-local budget; no extra
 # world/AI ticks and no gap/double count at the source handoff.
 sim=fresh();sim.hero.ranks.q=6;sim.hero.stats.cdr=.65
 cast(sim,[Vector3.ZERO,Vector3(4,0,0)]);sim.step(1.9);cast(sim,[Vector3.ZERO,Vector3(4,0,0)]);sim.step(.18)
 enemy=target(sim,Vector3(4,0,2));sim.step(.58)
 enemy.position=Vector3(4,0,2);var steps:int=sim.ink_core_steps;sim.step(.02)
 near(enemy.position.z,1.94,"expiry handoff source fractions total exactly one tick at 3m/s")
 check(sim.ink_core_steps==steps+1,"source handoff does not subdivide world/AI step")
 check(sim._h02_target_sources[enemy.actor_id].vortex_id==sim.ink_vortices[0].vortex_id,"expired owner hands off to surviving source")
 sim.free()
