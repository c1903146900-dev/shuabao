extends SceneTree
## Main-owned finite engine gate. Merely reading this script is not a pass.
const Sim=preload("res://tests/ink_q3_foundation_20261004/fix01/ink_q3_sim.gd")
const Before=preload("res://tests/ink_intermediate_stats_20261004/ink_intermediate_sim.gd")
const Geo=preload("res://tests/ink_q3_foundation_20261004/ink_q3_geometry.gd")
var checks:int=0
var failures:Array=[]
var completed:Array=[]
var observations:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func near(a:float,b:float,label:String,tolerance:float=.00001)->void:check(is_finite(a) and absf(a-b)<=tolerance,"%s %.9f expected %.9f"%[label,a,b])
func fresh(rank:int=1,ids:Array=[]):
 var sim=Sim.new();root.add_child(sim);sim.auto_finish=false;sim.ai_enabled=false
 sim.hero.position=Vector3.ZERO;sim.hero.loadout.q="q3";sim.hero.ranks.q=rank
 sim.hero.stats.ap=100.0;sim.hero.stats.crit_chance=0.0
 sim.begin_encounter("q3-finite",[]);sim.set_hexes(ids)
 return sim
func target(sim,at:Vector3,kind:String="minion")->Dictionary:
 var e:Dictionary=sim.spawn_enemy(kind,at,100000.0);e.state="chase";e.defence=0.0;e.radius=.25;return e
func events(sim,kind:String)->Array:return sim.event_log.filter(func(e):return e.kind==kind)
func raise_at(sim,at:Vector3=Vector3(4,0,0))->Dictionary:
 var result:Dictionary=sim.request_action("q",at)
 check(result.accepted,"Q3 first real raise admitted")
 return result
func run()->void:
 test_source_ranks();test_manual_admission();test_recast_and_controls();test_geometry_and_categories();test_actual_projectiles();test_lifecycle_and_clocks();test_root_proc_budget();test_callbacks();test_q3_admission_guard();test_retained_before_after()
 var required:Array=["source_ranks","manual_admission","recast_controls","geometry_categories","actual_projectiles","lifecycle_clocks","root_proc_budget","callbacks","q3_admission_guard","retained_before_after"]
 for label in required:check(label in completed,"case completed: "+label)
 var report:Dictionary={"suite":"ink_q3_foundation_mechanic_gate","passed":failures.is_empty(),"checks":checks,"failures":failures,"completed":completed,"observations":observations,"source_binding_id":FileAccess.get_sha256("res://tests/ink_q3_foundation_20261004/fix01/source_binding.json"),"scope":"finite source mechanics only; no normal input, art, full floor, balance or user acceptance"}
 var f=FileAccess.open("res://tests/ink_q3_foundation_20261004/fix01/q3_result.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("INK_Q3_FOUNDATION_REPORT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func test_source_ranks()->void:
 for rank in range(1,7):
  for h05 in [false,true]:
   var sim=fresh(rank,["yanguizhou_h05"] if h05 else [])
   var initial:Dictionary=target(sim,Vector3(4,0,0));var follow:Dictionary=target(sim,Vector3(7,0,0));var hp:float=initial.hp
   var release:Dictionary=raise_at(sim)
   var state:Dictionary=sim.ink_mountain
   near(state.length,sim.v("Q3-4",rank)*(1.5 if h05 else 1.0),"source mountain rank length H05")
   near(state.width,1.4,"source fixed mountain thickness")
   near(state.expires_at-state.born_at,sim.v("Q3-6",rank),"source rank lifetime")
   near(state.collapse_length,8.0,"source collapse length not H05 expanded")
   near(state.collapse_width,sim.v("Q3-8",rank),"independent collapse width unaffected by H05")
   near(hp-initial.hp,sim.v("Q3-2",rank)+100.0*sim.v("Q3-3",rank)*.01,"ordinary raise exact source damage")
   near(sim.hero.cooldowns.q,sim.v("Q3-12",rank),"source CD begins first effect")
   check(initial.push.is_empty() and initial.stun_left==0,"no source-invented raise push/stun")
   var before:float=follow.hp
   var collapse:Dictionary=sim.request_action("q",Vector3(12,0,0))
   check(collapse.accepted and collapse.cast_id==release.cast_id,"same root cast recast")
   near(before-follow.hp,sim.v("Q3-9",rank)+100.0*sim.v("Q3-10",rank)*.01,"ordinary collapse exact source damage")
   near(follow.push.distance,sim.v("Q3-11",rank),"source rank push distance")
   near(follow.stun_left,0,"base collapse transport adds no separate stun")
   check(sim.ink_mountain.is_empty() and sim._casts[release.cast_id].finished,"collapse retires terrain and completes root")
   sim.free()
 completed.append("source_ranks")
func test_manual_admission()->void:
 var sim=fresh();var before:int=sim.cast_serial
 check(not sim.request_action("q",Vector3.INF).accepted,"manual point required")
 check(not sim.request_action("q",Vector3(9.001,0,0)).accepted,"range outside rejected not clamped")
 check(sim.cast_serial==before and sim.hero.cooldowns.q==0,"invalid point costs no root/CD")
 var preview:Dictionary=sim.q3_preview(Vector3(9,0,0))
 check(preview.accepted and preview.preview_only and sim.ink_mountain.is_empty(),"preview side effect free")
 near(preview.axis.dot(Vector3.RIGHT),0,"preview long axis perpendicular to chosen point")
 check(sim.cast_serial==before,"preview creates no cast")
 sim.hero.facing=Vector3.ZERO
 check(sim.q3_preview(Vector3.ZERO).axis.is_finite(),"coincident point stable nonNaN fallback")
 check(sim.request_action("q",Vector3.ZERO,"dedup").accepted,"coincident target allowed with stable facing")
 var serial:int=sim.cast_serial;var id:int=sim.ink_mountain.cast_id
 check(sim.request_action("q",Vector3.ZERO,"dedup").cast_id==id and not sim.ink_mountain.is_empty(),"replayed command cannot collapse")
 check(sim.cast_serial==serial,"no second root from duplicate command")
 sim.free();completed.append("manual_admission")
func test_recast_and_controls()->void:
 var sim=fresh(1,["yanguizhou_h06"])
 var ordinary:Dictionary=target(sim,Vector3(7,0,0));var elite:Dictionary=target(sim,Vector3(8,0,0),"elite");var boss:Dictionary=target(sim,Vector3(9,0,0),"boss")
 boss.tenacity=.25
 var cast:Dictionary=raise_at(sim);var cd:float=sim.hero.cooldowns.q
 sim.hero.position=Vector3(4,0,4)
 check(sim.request_action("q",Vector3(12,0,0)).accepted,"recast aims from mountain to manual mouse after hero moves")
 near(sim.hero.cooldowns.q,cd,"recast neither spends nor resets CD")
 for enemy in [ordinary,elite]:
  check(not enemy.push.is_empty() and enemy.push.direction==Vector3.RIGHT,"movable ordinary/elite pushed in collapse direction")
  near(enemy.stun_left,.8,"H06 exact hit stun")
 check(boss.push.is_empty(),"Boss immovable remains unpushed")
 near(boss.stun_left,.6,"Boss H06 stun follows tenacity, not invented immunity")
 check(sim.cast_serial==cast.cast_id,"recast one root budget")
 sim.free()
 sim=fresh(1,["yanguizhou_h05","yanguizhou_h06"])
 var extended:Dictionary=target(sim,Vector3(4,0,3.2));var outside:Dictionary=target(sim,Vector3(7,0,3.0))
 var outside_hp:float=outside.hp;var hp:float=extended.hp
 raise_at(sim);check(extended.hp<hp,"H05 extends only actual mountain footprint damage")
 check(extended.stun_left==0,"H06 does not add raise stun")
 sim.request_action("q",Vector3(12,0,0));near(outside.hp,outside_hp,"H05 does not secretly widen collapse")
 sim.free()
 sim=fresh();raise_at(sim);sim.hero.stun_left=.2
 check(not sim.request_action("q",Vector3(12,0,0)).accepted and not sim.ink_mountain.is_empty(),"existing control rejects recast without terrain loss")
 sim.hero.stun_left=0
 check(sim.request_action("shift",Vector3(0,0,9)).accepted and not sim.ink_mountain.is_empty(),"Shift never globally cancels Q3 terrain")
 sim.step(.3);check(not sim.ink_mountain.is_empty(),"terrain remains through completed Shift")
 sim.free();completed.append("recast_controls")
func test_geometry_and_categories()->void:
 near(Geo.entry(Vector3(-10,0,0),Vector3(10,0,0),.25,Vector3.ZERO,Vector3.BACK,4.5,1.4),.4525,"swept circle contacts correct near face")
 check(not Geo.overlaps(Vector3(.94,0,2.49),.25,Vector3.ZERO,Vector3.BACK,4.5,1.4),"rounded corner excludes expanded-AABB false positive")
 var sim=fresh();raise_at(sim)
 for kind in ["minion","elite","boss"]:
  var enemy:Dictionary=target(sim,Vector3(2,0,0),kind)
  sim._q3_movement_actor=enemy
  var result:Vector3=sim._move_clipped(enemy.position,Vector3(6,0,0),enemy.radius)
  check(result.x<3.06 if kind=="minion" else result==Vector3(6,0,0),"ordinary versus elite/Boss terrain "+kind)
  sim._q3_movement_actor={}
 check(sim._move_clipped(Vector3(2,0,0),Vector3(6,0,0),.65)==Vector3(6,0,0),"player and friendly path not blocked")
 var inside:Dictionary=target(sim,Vector3(3.8,0,0));sim._q3_movement_actor=inside
 check(sim._move_clipped(inside.position,Vector3(3.5,0,0),inside.radius).x<3.8,"birth overlap can leave without ejection")
 check(sim._move_clipped(inside.position,Vector3(6,0,0),inside.radius)==inside.position,"birth overlap cannot cross deeper through mountain")
 sim._q3_movement_actor={}
 var pouncer:Dictionary=target(sim,Vector3(2,0,0),"pouncer");pouncer.state="pounce";pouncer.aim=Vector3.RIGHT;pouncer.timer=2
 sim.ai_enabled=true
 for i in range(20):sim.step(.02)
 check(pouncer.position.x<3.1,"actual pounce family obeys terrain, no tunnelling")
 sim.free();completed.append("geometry_categories")
func test_actual_projectiles()->void:
 var matrix:Array=[]
 for kind in ["ranged","support","pitcher"]:
  var sim=fresh();sim.hero.position=Vector3(8,0,0)
  # Manual placement from hero leftwards, vertical mountain at x4.
  raise_at(sim)
  var enemy:Dictionary=target(sim,Vector3(0,0,0),kind);enemy.aim=Vector3.RIGHT;enemy.target_point=Vector3(8,0,0)
  sim.enemy_director._shoot(sim,enemy)
  check(sim.projectiles.size()==1,"actual director produces "+kind)
  var projectile_id:String=sim.projectiles[0].id
  var hp:float=sim.hero.hp
  for i in range(70):sim.step(.02)
  var blocked:Array=events(sim,"ink_q3_projectile_blocked")
  check(blocked.size()==1 and blocked[0].projectile_id==projectile_id,"actual projectile blocked once by source ID "+kind)
  near(sim.hero.hp,hp,"blocked projectile cannot hit hero "+kind)
  check(sim.projectiles.is_empty() and sim.zones.is_empty(),"blocked projectile cannot land zone "+kind)
  if not blocked.is_empty():matrix.append(blocked[0])
  sim.free()
 var sim=fresh();sim.hero.position=Vector3(2,0,0);raise_at(sim,Vector3(6,0,0))
 var enemy:Dictionary=target(sim,Vector3.ZERO,"ranged");enemy.aim=Vector3.RIGHT;enemy.target_point=sim.hero.position
 sim.enemy_director._shoot(sim,enemy);var hp:float=sim.hero.hp
 sim.enemy_director.step_projectiles(sim,1.0)
 check(sim.hero.hp<hp and events(sim,"ink_q3_projectile_blocked").is_empty(),"hero hit before mountain keeps original damage ordering")
 sim.free()
 sim=fresh();sim.hero.position=Vector3(8,0,0);raise_at(sim)
 sim.obstacles=[{"position":Vector3(2,0,0),"half":Vector3(.1,0,2)}]
 enemy=target(sim,Vector3.ZERO,"ranged");enemy.aim=Vector3.RIGHT;enemy.target_point=sim.hero.position
 sim.enemy_director._shoot(sim,enemy);sim.enemy_director.step_projectiles(sim,1.0)
 check(sim.projectiles.is_empty() and events(sim,"ink_q3_projectile_blocked").is_empty(),"earlier static obstacle retains original ownership")
 sim.free();observations["actual_projectile_families"]=matrix;completed.append("actual_projectiles")
func test_lifecycle_and_clocks()->void:
 var sim=fresh();var e:Dictionary=target(sim,Vector3(7,0,0));var hp:float=e.hp;var first:Dictionary=raise_at(sim)
 sim.paused=true;sim.step(8);near(sim.hero_time,0,"pause freezes actor and terrain clock")
 sim.paused=false;sim.move_during_hitstop(.1,Vector3.RIGHT);near(sim.hero_time,0,"hitstop movement does not age terrain")
 sim.step(4.98);check(not sim.ink_mountain.is_empty(),"mountain persists before exact duration")
 sim.step(.02);check(sim.ink_mountain.is_empty(),"natural expiry removes terrain")
 near(e.hp,hp,"natural expiry no invented collapse damage")
 check(sim._casts[first.cast_id].finished,"expiry completes root once")
 near(sim.ink_q3_finished[0].finished_at,5,"exact authored expiry receipt")
 check(not sim.request_action("q",Vector3(4,0,0)).accepted,"expired terrain does not bypass remaining cooldown")
 sim.common_reset_cooldowns(["q"]);var second:Dictionary=raise_at(sim)
 check(second.cast_id!=first.cast_id,"rebuilt terrain has fresh root identity")
 sim.cancel_cast(second.cast_id);check(sim.ink_mountain.is_empty(),"explicit cancellation removes terrain")
 var cd:float=sim.hero.cooldowns.q;sim.cancel_cast(second.cast_id);near(sim.hero.cooldowns.q,cd,"repeated cancellation neither refunds nor duplicates")
 check(sim.ink_q3_finished.size()==2,"expiry/cancel receipt exactly once each")
 sim.end_encounter("safe");sim.begin_encounter("next-q3",[])
 check(sim.ink_mountain.is_empty() and sim.ink_q3_receipts.is_empty(),"room rebuild clears all stale terrain and receipts")
 sim.free()
 sim=fresh();raise_at(sim);sim.ink_mountain.expires_at=.01
 sim._q3_tick_active=true;sim._q3_tick_start=0;sim.hero_time=.02
 check(not sim._q3_terrain_contact(Vector3(3,0,0),Vector3(5,0,0),0).is_empty(),"contact before fractional expiry blocks")
 check(sim._q3_terrain_contact(Vector3(0,0,0),Vector3(4,0,0),0).is_empty(),"contact after fractional expiry passes")
 sim.free();completed.append("lifecycle_clocks")
func test_root_proc_budget()->void:
 var sim=fresh(1,["common_g25"]);sim.hero.hp=sim.hero.stats.max_hp
 var before:float=sim.hero.hp;var first:Dictionary=raise_at(sim);var paid:float=before-sim.hero.hp
 check(paid>0,"actual G25 root commitment cost applies")
 var e:Dictionary=target(sim,Vector3(7,0,0));var after_raise:float=sim.hero.hp
 check(sim.request_action("q",Vector3(12,0,0)).accepted,"actual G25 recast")
 near(sim.hero.hp,after_raise,"recast does not charge second G25 cost")
 check(sim.cast_serial==first.cast_id,"G25 root not recreated")
 check(sim.common.runtime.completed_actions.has(str(first.cast_id)) and not sim.common.runtime.actions.has(str(first.cast_id)),"one common root completion closes the sole ledger")
 sim.free()
 sim=fresh(1,["common_g18"])
 for i in range(int(sim.common.runtime.parameter("g18",1))):
  var charge_target:Dictionary=sim.spawn_enemy("minion",Vector3(18,0,18),1.0);charge_target.state="chase";charge_target.defence=0.0
  sim.damage_enemy(charge_target,1.0,"attack",0)
 check(sim.common.runtime.replay_charges==1,"G18 charge earned from actual finite ordinary kills")
 raise_at(sim)
 var e2:Dictionary=target(sim,Vector3(7,0,0));var initial:float=e2.hp
 sim.request_action("q",Vector3(12,0,0));var direct:float=initial-e2.hp
 sim.step(.32)
 check(e2.hp<initial-direct,"existing G18 consumes captured realized collapse")
 check(sim.ink_mountain.is_empty(),"G18 never regenerates terrain")
 check(events(sim,"ink_q3_raised").size()==1 and events(sim,"ink_q3_collapse_started").size()==1,"G18 never replays actions/control sources")
 sim.free();completed.append("root_proc_budget")
func test_callbacks()->void:
 for trigger in ["ink_q3_raised","damage","ink_q3_collapse_started"]:
  var sim=fresh();var e:Dictionary=target(sim,Vector3(4,0,0));var hp:float=e.hp
  var fired:Array=[false]
  sim.combat_event.connect(func(event):
   if not fired[0] and event.kind==trigger:
    fired[0]=true;sim.end_encounter("cancelled");sim.begin_encounter("callback-new-room",[]))
  raise_at(sim)
  if trigger=="ink_q3_collapse_started":sim.request_action("q",Vector3(12,0,0))
  check(fired[0] and sim.room_id=="callback-new-room","callback rebuild actually reached "+trigger)
  check(sim.ink_mountain.is_empty() and sim.ink_q3_receipts.is_empty(),"callback never leaks old mountain/receipts "+trigger)
  check(sim.common._inside_hit==0,"callback preserves shared damage-depth guard "+trigger)
  if trigger=="ink_q3_raised":near(e.hp,hp,"cancel at raise suppresses unperformed damage")
  sim.free()
 completed.append("callbacks")
func test_retained_before_after()->void:
 var sims:Array=[Before.new(),Sim.new()]
 for sim in sims:
  root.add_child(sim);sim.auto_finish=false;sim.ai_enabled=false;sim.hero.position=Vector3.ZERO;sim.hero.loadout.q="q1";sim.hero.ranks.q=1
  sim.begin_encounter("retained-identical",[]);sim.set_hexes(["yanguizhou_h01","yanguizhou_h02","common_g01","common_g05","common_g06","common_g15"])
  var e:Dictionary=target(sim,Vector3(4,0,0))
  check(sim.request_ink_input("q_down").accepted,"retained Q1 arm")
  check(sim.request_ink_input("left_down",Vector3.ZERO).accepted,"retained Q1 manual start")
  sim.request_ink_input("motion",Vector3(4,0,0));check(sim.request_ink_input("left_up",Vector3(4,0,0)).accepted,"retained physical release")
  sim.step(.4)
  check(sim.request_action("attack",Vector3(9,0,0)).accepted,"retained BASIC manual")
  check(sim.request_action("shift",Vector3(9,0,0)).accepted,"retained Shift manual")
  sim.step(.5)
 check(sims[0].event_log==sims[1].event_log,"before/after Q1 H01/H02 BASIC Shift exact event equality")
 check(sims[0].hero.snapshot()==sims[1].hero.snapshot(),"before/after exact actor/cooldown/control state")
 check(sims[0].enemies==sims[1].enemies,"before/after exact enemy damage/displacement state")
 check(sims[0].ink_core_steps==sims[1].ink_core_steps,"no additional world/AI ticks")
 for sim in sims:sim.free()
 completed.append("retained_before_after")

func test_q3_admission_guard()->void:
 for recast in [false,true]:
  for blocked in ["actual_stun","pause","stale_generation","actual_death"]:
   var sim=fresh()
   if recast:raise_at(sim)
   var cast_count:int=sim.cast_serial
   var cooldown:float=sim.hero.cooldowns.q
   if blocked=="actual_stun":sim.damage_hero(1.0,Vector3.ZERO,.2)
   elif blocked=="pause":sim.paused=true
   elif blocked=="actual_death":sim.damage_hero(100000.0,Vector3.ZERO,0.0,true)
   var result:Dictionary=sim.request_ink_input("q_down",Vector3(8,0,0),"guard","",sim.encounter_generation-1) if blocked=="stale_generation" else sim.request_action("q",Vector3(8,0,0))
   check(not result.accepted,"Q3 "+("recast" if recast else "raise")+" rejects "+blocked)
   check(sim.cast_serial==cast_count,"blocked Q3 does not create root "+blocked)
   near(sim.hero.cooldowns.q,cooldown,"blocked Q3 does not restart/refund cooldown "+blocked)
   if blocked=="actual_death":check(sim.hero.dead and sim.ink_mountain.is_empty(),"actual lethal cleanup removes mountain before blocked new action")
   elif recast:check(not sim.ink_mountain.is_empty(),"rejected nonlethal recast keeps current mountain "+blocked)
   else:check(sim.ink_mountain.is_empty(),"blocked raise has no terrain "+blocked)
   sim.free()
 var sim=fresh();sim.hero.move_intent=Vector3.RIGHT
 raise_at(sim);var at:Vector3=sim.hero.position;sim.step(.02)
 near(sim.hero.position.distance_to(at),sim.hero.speed()*.02,"legal ordinary raise leaves WASD walking live")
 check(sim.request_action("q",Vector3(12,0,0)).accepted,"walking recast legal")
 at=sim.hero.position;sim.step(.02)
 near(sim.hero.position.distance_to(at),sim.hero.speed()*.02,"legal recast leaves WASD walking live")
 sim.free();completed.append("q3_admission_guard")
