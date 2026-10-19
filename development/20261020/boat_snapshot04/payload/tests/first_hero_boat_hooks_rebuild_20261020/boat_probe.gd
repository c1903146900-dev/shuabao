extends Node
## Explicit mechanism fixture. Does not test natural acquisition or production admission.
const Sim = preload("res://tests/ink_river_hexes_20261006/ordinary01/sim.gd")
var checks: int = 0
var failures: Array = []
var groups: Array = []
var observations: Array = []
var serial: int = 0
var output_path: String = ""

func _ready() -> void:
 for arg in OS.get_cmdline_user_args():
  if str(arg).begins_with("--boat-result="): output_path = str(arg).trim_prefix("--boat-result=")
 run.call_deferred()

func check(ok: bool, label: String) -> bool:
 checks += 1
 if not ok: failures.append(label)
 return ok

func near(a: float, b: float, label: String) -> void:
 check(is_finite(a) and is_finite(b) and absf(a-b)<0.0001,label+" actual="+str(a)+" expected="+str(b))

func fresh(h09: bool, h10: bool, p1_rank: int = 1, extent: float = 30.0):
 serial += 1
 var sim = Sim.new(); add_child(sim)
 sim.auto_finish = false; sim.ai_enabled = false; sim.arena_half_extent = extent; sim.obstacles = []
 sim.hero.loadout.e = "e2"; sim.hero.ranks.e = 1
 sim.hero.loadout.passive = "p1"; sim.hero.ranks.passive = p1_rank
 sim.hero.stats.crit_chance = 0.0; sim.hero.stats.cdr = 0.0
 check(sim.begin_encounter("boat-rebuild-%d"%serial,[]).accepted,"fixture encounter")
 sim.hero.position = Vector3.ZERO
 var ids: Array = []
 if h09: ids.append("yanguizhou_h09")
 if h10: ids.append("yanguizhou_h10")
 sim.set_hexes(ids)
 check(sim.hero.has_hex("yanguizhou_h09") == h09 and sim.hero.has_hex("yanguizhou_h10") == h10,"fixture owns requested Hexes")
 sim.combat_event.connect(func(event: Dictionary):
  if str(event.get("kind","")) in ["ink_e2_launched","ink_e2_boarded","ink_e2_return_started","ink_e2_finished","ink_p1_settled"]:
   observations.append({"fixture":serial,"event":event.duplicate(true),"hero_time":sim.hero_time,"cooldown":sim.hero.cooldowns.get("e",0.0)})
 )
 return sim

func target(sim, point: Vector3) -> Dictionary:
 var enemy: Dictionary = sim.spawn_enemy("minion",point,10000.0)
 enemy.state = "chase"; enemy.radius = 0.25; enemy.defence = 0.0
 return enemy

func tick(sim, duration: float) -> void:
 var left: float = duration
 while left > 0.000001:
  var dt: float = minf(left,0.02)
  sim.step(dt); left -= dt

func record(sim, stage: String, id: int) -> void:
 observations.append({"stage":stage,"cast_id":id,"hero_time":sim.hero_time,"cd":sim.hero.cooldowns.get("e",0.0),"boat":sim._e2_public(sim.ink_boat) if not sim.ink_boat.is_empty() else {},"p1":sim.ink_p1_receipts.duplicate(true)})

func receipts(sim, id: int) -> Array:
 return sim.ink_p1_receipts.filter(func(r): return int(r.cast_id)==id)

func branch(h09: bool, h10: bool, p1_rank: int) -> void:
 var name: String = ("branch_" if p1_rank>0 else "cooldown_no_p1_")+str(int(h09))+str(int(h10))
 groups.append(name)
 var sim = fresh(h09,h10,p1_rank)
 var enemy: Dictionary = target(sim,Vector3(0.5,0,0))
 var launch: Dictionary = sim.request_action("e",Vector3(20,0,0))
 if not check(bool(launch.get("accepted",false)),name+" launch"): sim.free(); return
 var id: int = int(launch.cast_id)
 var launch_time: float = sim.hero_time
 var launch_cd: float = sim.hero.cooldowns.e
 record(sim,"launch",id)
 tick(sim,0.5)
 if not check(not sim.ink_boat.is_empty(),name+" boat before board"): sim.free(); return
 var state: Dictionary = sim.ink_boat
 var before: float = sim.hero.cooldowns.e
 near(before,maxf(0,launch_cd-(sim.hero_time-launch_time)),name+" preboard natural countdown")
 check(sim._e2_landing_legal(state.position),name+" exact landing legal")
 check(Vector3(enemy.position).distance_to(state.position)>float(enemy.radius)+sim.hero_radius,name+" enemy not occupying landing")
 record(sim,"pre_board",id)
 var board: Dictionary = sim.request_action("e",Vector3.INF)
 if not check(bool(board.get("accepted",false)),name+" same cast boards"): sim.free(); return
 near(Vector3(sim.hero.position).distance_to(state.boarding_position),0,name+" hero teleported")
 record(sim,"post_board",id)
 if h09:
  check(sim.ink_boat.get("phase","")=="return",name+" return branch")
  check(receipts(sim,id).is_empty(),name+" no early P1")
  near(sim.hero.cooldowns.e,before,name+" boarding does not restart CD")
 elif p1_rank>0:
  var immediate: Array = receipts(sim,id)
  if check(immediate.size()==1,name+" immediate P1 once"):
   near(immediate[0].cooldown_before,before,name+" actual pre-refund CD")
   near(sim.hero.cooldowns.e,before*0.95,name+" current CD refunds 5 percent")
 else: near(sim.hero.cooldowns.e,before,name+" unlearned P1 preserves CD")
 var hero_board: Vector3 = sim.hero.position
 tick(sim,1.0)
 record(sim,"return_complete",id)
 check(sim.ink_boat.is_empty(),name+" complete")
 near(Vector3(sim.hero.position).distance_to(hero_board),0,name+" return does not carry hero")
 check(sim.ink_e2_finished.size()==1,name+" one finish")
 var returns: Array = sim.ink_e2_receipts.filter(func(r): return str(r.segment_id)=="return_voyage")
 var seen: Dictionary = {}
 for r in returns:
  check(not seen.has(r.target_id),name+" unique return enemy"); seen[r.target_id]=true
 check(not returns.is_empty() if h09 else returns.is_empty(),name+" return hits only H09")
 var p1: Array = receipts(sim,id)
 if p1_rank>0:
  if check(p1.size()==1,name+" single P1 settlement"):
   check(p1[0].distinct_targets==1 and p1[0].qualified,name+" original target set")
   near(p1[0].cooldown_before,maxf(0,launch_cd-(float(p1[0].settled_at)-launch_time)),name+" refund basis at real settlement")
   near(p1[0].cooldown_refund,float(p1[0].cooldown_before)*0.05,name+" exact refund")
   near(sim.hero.cooldowns.e,maxf(0,float(p1[0].cooldown_after)-(sim.hero_time-float(p1[0].settled_at))),name+" post refund countdown")
 else:
  check(p1.is_empty(),name+" no P1 receipts")
  near(sim.hero.cooldowns.e,maxf(0,launch_cd-(sim.hero_time-launch_time)),name+" no hidden refund or restart")
 tick(sim,4.0)
 check(sim.ink_e2_finished.size()==1,name+" no delayed second finish")
 check(sim.ink_e2_lifecycle.filter(func(e): return e.event=="launched").size()==1,name+" one release lifecycle")
 sim.free()

func boundary() -> void:
 groups.append("boundary_unboarded")
 var sim = fresh(true,true,0,2.0)
 var launch: Dictionary = sim.request_action("e",Vector3(20,0,0))
 if not check(launch.get("accepted",false),"boundary launch"): sim.free(); return
 var state: Dictionary = sim.ink_boat
 tick(sim,float(state.boundary_route.motion_until)-sim.hero_time+0.02)
 check(state.boundary_parked and sim.hero_time<float(state.voyage_until),"parking before natural deadline")
 var cd: float = sim.hero.cooldowns.e
 var reject: Dictionary = sim.request_action("e",Vector3.INF)
 check(not reject.get("accepted",false) and reject.get("reason","")=="illegal_current_boat_landing","illegal boundary landing rejected")
 check(is_same(sim.ink_boat,state),"illegal boarding preserves original boat")
 near(sim.hero.cooldowns.e,cd,"illegal boarding no CD restart")
 tick(sim,float(state.voyage_until)-sim.hero_time+0.02)
 check(state.phase=="decoy" and sim.ink_e2_finished.is_empty(),"unboarded waits complete then decoy")
 tick(sim,3.1)
 check(sim.ink_e2_finished.size()==1 and sim.ink_boat.is_empty(),"one deferred finish")
 check(sim.ink_e2_lifecycle.filter(func(e): return e.event=="natural_burst").size()==1,"one natural burst")
 sim.free()

func decoy() -> void:
 groups.append("decoy_target_lifecycle")
 var sim = fresh(false,true,0)
 if not check(sim.request_action("e",Vector3(20,0,0)).get("accepted",false),"decoy launch"): sim.free(); return
 var state: Dictionary = sim.ink_boat
 tick(sim,float(state.voyage_until)-sim.hero_time+0.02)
 if not check(state.phase=="decoy","decoy phase"): sim.free(); return
 var enemy: Dictionary = target(sim,Vector3(state.position)+Vector3(1,0,0))
 sim._e2_refresh_taunts(state)
 check(enemy.target_actor_id==state.decoy_actor_id,"real target points to decoy")
 var candidate: Dictionary = sim.enemy_director._candidate(sim,enemy)
 near(Vector3(candidate.target).distance_to(state.position),0,"new attack aims at decoy")
 sim.enemy_director._commit(sim,enemy)
 var committed: Vector3 = enemy.target_point
 tick(sim,3.1)
 check(enemy.target_actor_id==sim.hero.actor_id and not enemy.has("ink_e2_decoy_position"),"normal target restored")
 near(Vector3(enemy.target_point).distance_to(committed),0,"committed attack not retargeted")
 sim.free()

func decoy_reentrant_cancel(on_start: bool) -> void:
 var sim = fresh(false,true,0)
 var end_point: Vector3 = Vector3.RIGHT*sim.v("E2-1",1)*sim.v("E2-2",1)
 target(sim,end_point+Vector3(0,0,1))
 var observed: Dictionary = {"cancelled":false,"natural":0,"started":0}
 sim.combat_event.connect(func(event: Dictionary):
  var kind: String = str(event.get("kind",""))
  if kind=="ink_e2_natural_burst": observed.natural+=1
  if kind=="ink_e2_decoy_started": observed.started+=1
  if not observed.cancelled and kind==("enemy_taunt_started" if on_start else "enemy_taunt_ended") and not sim.ink_boat.is_empty():
   observed.cancelled=true; sim.cancel_cast(int(sim.ink_boat.cast_id))
 )
 if check(sim.request_action("e",Vector3(20,0,0)).get("accepted",false),"reentrant cancel launch"):
  tick(sim,7.0)
  check(observed.cancelled,"taunt callback cancels current cast")
  check(observed.natural==0 and sim.ink_e2_finished.is_empty(),"reentrant taunt cancellation never emits natural burst or finish")
  if on_start: check(observed.started==0,"cancelled taunt projection emits no stale decoy start")
 sim.free()

func paused_return() -> void:
 groups.append("return_pause_resume")
 var sim = fresh(true,false,0)
 target(sim,Vector3(0.5,0,0))
 if not check(sim.request_action("e",Vector3(20,0,0)).get("accepted",false),"pause launch"): sim.free(); return
 tick(sim,0.5)
 if not check(sim.request_action("e",Vector3.INF).get("accepted",false),"pause boards"): sim.free(); return
 var state: Dictionary = sim.ink_boat
 var route: Array = state.return_route.duplicate()
 var at: float = sim.hero_time
 var position: Vector3 = state.position
 sim.paused=true; tick(sim,1.0)
 near(sim.hero_time,at,"paused clock")
 near(Vector3(state.position).distance_to(position),0,"paused return position")
 sim.paused=false
 var interruption: Dictionary = {"seen":false}
 sim.combat_event.connect(func(event: Dictionary):
  if not interruption.seen and event.get("kind","")=="ink_e2_contact" and event.get("segment_id","")=="return_voyage":
   interruption.seen=true; sim.paused=true
 )
 tick(sim,1.0)
 check(interruption.seen and sim.paused,"pause inside return contact callback")
 sim.paused=false; tick(sim,1.0)
 check(sim.ink_e2_receipts.filter(func(r): return r.segment_id=="return_voyage").size()==1,"callback resume never repeats target")
 check(state.return_route==route and sim.ink_e2_finished.size()==1,"resume same route once")
 sim.free()

func retire(mode: String) -> void:
 groups.append("retire_"+mode)
 for returning: bool in [false,true]:
  var sim = fresh(returning,not returning,1)
  if not check(sim.request_action("e",Vector3(20,0,0)).get("accepted",false),"retire launch"): sim.free(); continue
  var state: Dictionary = sim.ink_boat
  if returning:
   tick(sim,0.5)
   if not check(sim.request_action("e",Vector3.INF).get("accepted",false),"retire board"): sim.free(); continue
  else: tick(sim,float(state.voyage_until)-sim.hero_time+0.02)
  if mode=="cancel": sim.cancel_cast(int(state.cast_id))
  elif mode=="owner_death": sim.damage_hero(10000000.0,Vector3.ZERO,0.0,true,true,{"fixture":"owner_death_cleanup"}); tick(sim,0.02)
  else: sim.begin_encounter("replacement-room",[])
  tick(sim,5.0)
  check(sim.ink_boat.is_empty(),mode+" clears boat")
  check(sim.ink_e2_finished.is_empty() and sim.ink_p1_receipts.is_empty(),mode+" no terminal or P1")
  check(sim.ink_e2_lifecycle.filter(func(e): return e.event=="natural_burst").is_empty(),mode+" no delayed burst")
  sim.free()

func permission() -> void:
 groups.append("taunt_permission")
 var sim = fresh(false,true,0)
 for kind: String in ["minion","pouncer","armored","ranged","pitcher","support","elite","boss"]:
  var enemy: Dictionary = sim.enemy_director.make_enemy(kind,Vector3.ZERO,1000,1,1)
  check(sim.enemy_director.e2_decoy_eligible(enemy)==(kind!="boss"),"actual class "+kind)
 check(not sim.enemy_director.e2_decoy_eligible({"kind":"unknown","rank_category":"ordinary"}),"unknown class rejected")
 sim.free()

func target_scope(two_base: bool) -> void:
 groups.append("p1_two_base_targets" if two_base else "p1_return_only_new_target")
 var sim = fresh(true,false,1)
 target(sim,Vector3(0.5,0,0))
 if two_base: target(sim,Vector3(0.5,0,0.3))
 var launch: Dictionary = sim.request_action("e",Vector3(20,0,0))
 if not check(launch.get("accepted",false),"scope launch"): sim.free(); return
 tick(sim,0.5)
 if not check(sim.request_action("e",Vector3.INF).get("accepted",false),"scope board"): sim.free(); return
 var added: Dictionary = {}
 if not two_base: added=target(sim,Vector3(0.9,0,0))
 tick(sim,1.0)
 var rows: Array = receipts(sim,int(launch.cast_id))
 if check(rows.size()==1,"scope one P1"):
  check(rows[0].distinct_targets==(2 if two_base else 1),"original source set distinct count")
  check(bool(rows[0].qualified) == (not two_base),"scope qualification")
  if two_base: near(rows[0].cooldown_refund,0,"two base no refund")
  else:
   var hits: Array = sim.ink_e2_receipts.filter(func(r): return r.target_id==added.actor_id)
   check(hits.size()==1 and hits[0].segment_id=="return_voyage","new enemy return only")
   near(rows[0].cooldown_refund,float(rows[0].cooldown_before)*0.05,"return-only new enemy does not change base P1")
 sim.free()

func run() -> void:
 for rank: int in [1,0]:
  for h09: bool in [false,true]:
   for h10: bool in [false,true]: branch(h09,h10,rank)
 boundary(); decoy(); decoy_reentrant_cancel(true); decoy_reentrant_cancel(false); paused_return()
 for mode: String in ["cancel","owner_death","room_change"]: retire(mode)
 permission(); target_scope(true); target_scope(false)
 check(groups.size()==17,"all 17 groups completed")
 var unique: Dictionary = {}
 for group in groups: unique[group]=true
 check(unique.size()==17,"17 unique groups")
 var report: Dictionary = {"schema":"boat-rebuild-mechanism-1","passed":failures.is_empty(),"checks":checks,"failures":failures,"groups":groups,"expected_groups":17,"observations":observations,"scope":"mechanics fixtures only; no natural acquisition or rendering"}
 if not output_path.is_empty():
  var file = FileAccess.open(output_path,FileAccess.WRITE)
  if file: file.store_string(JSON.stringify(report," ")); file.close()
  else: failures.append("report write failed")
 print("BOAT_REBUILD_CHECKS=",checks," FAILURES=",failures.size()," GROUPS=",groups.size())
 get_tree().quit(0 if failures.is_empty() else 1)
