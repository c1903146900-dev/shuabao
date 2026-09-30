extends RefCounted
const Sim = preload("res://scripts/combat/combat_sim.gd")
const T = preload("res://data/combat/tuning.gd")
const Clock = preload("res://scripts/combat/world_clock.gd")
var checks: int = 0
var failures: Array = []
var cases: Array = []
func check(condition: bool, label: String) -> void:
 checks += 1
 if not condition: failures.append(label)
func near(actual: float, expected: float, label: String, tolerance: float = 0.011) -> void:
 check(absf(actual-expected)<=tolerance,"%s expected %.5f actual %.5f" % [label,expected,actual])
func fixture():
 var s = Sim.new()
 s.auto_finish = false
 s.ai_enabled = false
 s.hero.position = Vector3.ZERO
 s.hero.facing = Vector3.FORWARD
 s.hero.stats.regen = 0.0
 return s
func run() -> Dictionary:
 checks=0
 failures.clear()
 cases.clear()
 _test_q1()
 _test_overload()
 _test_ultimate()
 _test_damage()
 _test_freeze()
 _test_input_movement()
 _test_clock()
 _test_death()
 _test_passives()
 _test_progression_integration()
 _test_transaction_boundaries()
 _test_independent_slots()
 return {"suite":"fengli-core","checks":checks,"passed":checks-failures.size(),"failures":failures.duplicate(),"cases":cases.duplicate(),"definition_version":T.VERSION}
func _test_q1() -> void:
 cases.append("Q1 geometry/refund/lethal attribution/stacks/grace")
 var s = fixture()
 var e = s.spawn_enemy("minion",Vector3(0,0,-2),1000)
 var behind = s.spawn_enemy("minion",Vector3(0,0,2),1000)
 check(s.request_action("q").accepted,"Q1 accepted")
 near(e.hp,1000-32*1.2,"Q1 base 1.2AD once")
 near(behind.hp,1000,"Q1 behind excluded")
 check(not s.request_action("q").accepted,"Q1 grace rejects recast")
 s.step(0.2)
 near(s.hero.cooldowns.q,3.5,"Q1 single full-CD refund")
 near(s.hero.q1_stacks,0,"Q1 no kill resets stacks")
 s.free()
 s=fixture()
 for i in range(6):
  s.spawn_enemy("minion",Vector3(0,0,-2),1)
  check(s.request_action("q").accepted,"Q1 lethal cast %d"%i)
  s.step(0.2)
  near(s.hero.cooldowns.q,0,"Q1 kill refresh")
  near(s.hero.q1_stacks,mini(i+1,4),"Q1 once-per-cast capped stack")
 var long_target=s.spawn_enemy("minion",Vector3(0,0,-8),1000)
 s.request_action("q")
 near(long_target.hp,1000-32*1.2*2.2,"Q1 additive max length+damage")
 s.step(0.2)
 near(s.hero.q1_stacks,0,"Q1 failed kill drops all stacks")
 s.free()
 s=fixture()
 for i in 3: s.spawn_enemy("minion",Vector3(i*0.2,0,-2),1)
 s.request_action("q")
 s.step(0.2)
 near(s.hero.q1_stacks,1,"Q1 multikill grants one stack")
 s.free()
 # Killing with a different packet during grace must not turn an assist into a Q1 kill.
 s=fixture()
 e=s.spawn_enemy("minion",Vector3(0,0,-2),50)
 s.request_action("q")
 s.damage_enemy(e,100,"attack",999)
 s.step(0.2)
 near(s.hero.q1_stacks,0,"Q1 no ordinary assist refresh")
 near(s.hero.cooldowns.q,3.5,"Q1 assist still only hit refund")
 s.free()
func _test_overload() -> void:
 cases.append("E3 duration/CD/true damage/dash/P3 permanent run growth")
 var s=fixture()
 s.request_action("e")
 near(s.hero.overload_left,7,"E3 initial duration")
 near(s.hero.speed(),7.8,"E3 speed additive")
 near(s.hero.attack_speed(),2.21,"E3 attack speed")
 near(s.hero.tenacity(),0.3,"E3 tenacity")
 near(s.hero.cooldowns.e,0,"E3 no early cooldown")
 check(not s.request_action("e").accepted,"E3 cannot duplicate buff")
 s.hero.cooldowns.shift=0
 s.request_action("shift")
 near(s.hero.cooldowns.shift,1.6,"E3 half dash cooldown")
 s.hero.dash_left=0
 var e=s.spawn_enemy("minion",Vector3(0,0,-2),1000)
 e.defence=100
 s.request_action("attack")
 s.step(0.1)
 near(e.hp,1000-16-8,"E3 true component bypasses defence")
 s.step(0.1)
 var kill=s.spawn_enemy("minion",Vector3(8,0,8),1)
 var before:float=s.hero.overload_left
 s.damage_enemy(kill,100,"q1",88)
 near(s.hero.overload_left,before+1.5,"E3 kill extends duration not CD")
 s.step(s.hero.overload_left)
 near(s.hero.cooldowns.e,32,"E3 cooldown begins at end")
 near(s.hero.speed(),6,"E3 speed reverts")
 s.free()
 for rank in [1,2,3]:
  s=fixture()
  s.hero.ranks.passive=rank
  var threshold:int=T.CONFIRMED.p3_thresholds[rank-1]
  for i in threshold*2+1:
   e=s.spawn_enemy("minion",Vector3(0,0,-2),1)
   s.damage_enemy(e,10,"attack",i)
   s.damage_enemy(e,10,"attack",i)
  near(s.hero.permanent_ad,2,"P3 threshold rank %d"%rank)
  near(s.hero.kill_progress,1,"P3 subtract threshold carry remainder")
  near(s.hero.stats.ad,32,"P3 does not write base AD")
  s.free()
 # Same chronological result for a coarse caller and fine caller.
 var coarse=fixture()
 var fine=fixture()
 for x in [coarse,fine]:
  x.hero.overload_left=0.15
  x.spawn_enemy("minion",Vector3(0,0,-2),1000)
  x.request_action("attack")
 coarse.step(0.2)
 for i in 20: fine.step(0.01)
 near(coarse.enemies[0].hp,fine.enemies[0].hp,"E3 expiry frame invariance",0.0001)
 near(coarse.enemies[0].hp,960,"E3 attack before expiry")
 coarse.free()
 fine.free()
func _test_ultimate() -> void:
 cases.append("R1 circle/strict execution/Boss/invulnerability/end CD")
 var s=fixture()
 var in_range=s.spawn_enemy("minion",Vector3(9,0,0),1000)
 var outside=s.spawn_enemy("minion",Vector3(10.1,0,0),1000)
 var boss=s.spawn_enemy("boss",Vector3(0,0,-5),1000)
 boss.hp=97
 var exact=s.spawn_enemy("elite",Vector3(0,0,5),1000)
 exact.hp=98
 s.request_action("r")
 near(s.clock.scale_factor(),0.2,"R1 world slow")
 s.damage_hero(999)
 near(s.hero.hp,240,"R1 invulnerable")
 s.step(0.31)
 near(in_range.hp,952,"R1 in circle 1.5AD")
 near(outside.hp,1000,"R1 outside circle safe")
 check(boss.dead,"R1 Boss below5% executed")
 near(exact.hp,50,"R1 exactly5% not executed")
 near(s.hero.cooldowns.r,0,"R1 CD not during presentation")
 s.step(0.79)
 near(s.hero.cooldowns.r,130,"R1 CD starts after presentation")
 near(s.clock.scale_factor(),1,"R1 restores world clock")
 check(not s.r1_active,"R1 action lock released")
 s.free()
func _test_damage() -> void:
 cases.append("ordinary/true/crit/leech/caps/control/targetability")
 near(T.damage(100,100,0),50,"unified defence formula")
 near(T.damage(100,100,50),100/1.5,"penetration subtracts defence")
 near(T.damage(100,-10,20),100,"no negative armour amplification")
 near(T.damage(100,10000,0,true),100,"true damage")
 near(T.cooldown(100,1),35,"65% CDR cap")
 near(T.control_duration(2,1),0,"100% tenacity no minimum")
 var s=fixture()
 s.hero.stats.crit_chance=1
 s.hero.stats.attack_speed=10
 s.hero.stats.tenacity=1
 s.hero.stats.lifesteal=0.2
 s.hero.hp=100
 near(s.hero.attack_speed(),2.5,"attack speed cap")
 s.damage_hero(0,Vector3.ZERO,1)
 near(s.hero.stun_left,0,"100% actual stun immunity")
 var e=s.spawn_enemy("minion",Vector3(0,0,-2),1000)
 s.request_action("attack")
 s.step(0.1)
 near(e.hp,944,"basic crit175%")
 near(s.hero.hp,100+56*0.2*0.4,"area basic leech40%")
 s.hero.lock_time=0
 s.request_action("q")
 near(e.hp,944-38.4,"Q skill cannot crit")
 s.hero.untargetable=true
 s.damage_hero(10)
 check(s.hero.hp<104.5,"untargetable alone does not block area damage")
 s.hero.invulnerable_left=1
 var old:float=s.hero.hp
 s.damage_hero(100,Vector3.RIGHT,2)
 near(s.hero.hp,old,"invulnerable blocks damage")
 near(s.hero.stun_left,0,"invulnerable blocks control")
 s.free()
func _test_freeze() -> void:
 cases.append("60s post-room freeze/last kill attribution/death transaction")
 var s=fixture()
 s.hero.hp=130
 s.hero.cooldowns.q=2
 s.hero.cooldowns.shift=1
 s.hero.overload_left=5
 s.hero.q1_stacks=3
 s.hero.kill_progress=7
 s.end_encounter("victory")
 var before:Dictionary=s.snapshot()
 s.step(60)
 check(before==s.snapshot(),"HP/CD/all retained state frozen60s")
 check(not s.request_action("attack").accepted,"frozen commands reject")
 check(before==s.snapshot(),"rejected command does not mutate snapshot")
 s.free()
 s=fixture()
 s.auto_finish=true
 s.hero.hp=100
 s.hero.stats.regen=10
 s.spawn_enemy("minion",Vector3(0,0,-2),1)
 s.request_action("q")
 check(s.phase=="victory","last kill settles immediately")
 near(s.hero.hp,100,"no last-kill regen frame")
 near(s.hero.q1_stacks,1,"last-kill Q1 settles attribution before freeze")
 check(s.pending.is_empty(),"no dangling Q1 grace at room end")
 check(s.frozen_snapshot==s.snapshot(),"atomic victory snapshot")
 s.free()
 s=fixture()
 s.ai_enabled=true
 s.hero.hp=1
 var e=s.spawn_enemy("boss",Vector3(0,0,-1))
 e.state="warning"
 e.timer=0
 e.target_point=Vector3.ZERO
 s.step(0.01)
 check(s.frozen_snapshot==s.snapshot(),"no enemy mutations after death freeze")
 near(s.clock.scale_factor(),1,"death leaves normal time")
 s.free()
func _test_input_movement() -> void:
 cases.append("commands/movement/dash/bounds")
 var s=fixture()
 s.hero.move_intent=Vector3(1,0,1)
 s.step(1)
 near(s.hero.position.length(),6,"diagonal movement normalized")
 var first:Dictionary=s.request_action("q",Vector3.ZERO,"id-1")
 check(s.request_action("q",Vector3.ZERO,"id-1")==first,"duplicate command same receipt")
 s.step(0.2)
 s.hero.move_intent=Vector3.RIGHT
 s.hero.position=Vector3.ZERO
 s.request_action("shift")
 s.step(0.16)
 near(s.hero.position.x,4.2,"dash distance")
 near(s.hero.invulnerable_left,0,"dash does not invent invulnerability")
 s.hero.position=Vector3(13,0,0)
 s.hero.cooldowns.shift=0
 s.request_action("shift")
 s.step(0.16)
 check(s.hero.position.x<=13.08,"dash respects arena bounds")
 s.free()
func _test_clock() -> void:
 cases.append("shared ultimate slow single layer/normal actor presentation channels")
 var c=Clock.new()
 c.enter("a",1)
 c.enter("b",2)
 near(c.scale_factor(),0.2,"two ultimates do not multiply")
 near(c.step(1,true),0.2,"world slower than presentation")
 check(not c.presenters.has("a") and c.presenters.has("b"),"actor channels expire independently")
 near(c.step(2,true),1.2,"clock partitions partial slow frame")
 near(c.scale_factor(),1,"all presentation channels released")
 near(c.step(60,false),0,"inactive world clock no progress")
func _test_death() -> void:
 cases.append("single self-rescue/true death penalty/idempotence")
 var s=fixture()
 s.damage_hero(999)
 check(s.hero.death_state=="downed","first lethal is downed")
 near(s.hero.xp_progress,100,"downed no XP penalty")
 check(s.self_rescue(),"one rescue accepted")
 near(s.hero.hp,84,"explicit test rescue HP35%")
 s.hero.invulnerable_left=0
 s.damage_hero(999)
 check(s.hero.death_state=="true_dead","second lethal true death")
 near(s.hero.xp_progress,70,"true death loses30% progress")
 s.damage_hero(999)
 near(s.hero.xp_progress,70,"duplicate death no extra penalty")
 check(not s.self_rescue(),"no second rescue")
 s.free()

func _test_passives() -> void:
 cases.append("P1 attack-only leech/P2 nonlethal threshold/reset active states")
 var s=fixture()
 s.hero.loadout.passive="p1"
 s.hero.hp=100
 var e=s.spawn_enemy("minion",Vector3(0,0,-2),1000)
 s.request_action("attack")
 s.step(0.1)
 near(s.hero.hp,100+32*0.02*0.4,"P1 basic area lifesteal only")
 var old:float=s.hero.hp
 s.request_action("q")
 near(s.hero.hp,old,"P1 does not leech skill damage")
 s.free()
 for rank in [1,2,3]:
  s=fixture()
  s.hero.loadout.passive="p2"
  s.hero.ranks.passive=rank
  s.hero.hp=24
  s.hero.cooldowns.q=4
  s.hero.cooldowns.e=10
  s.damage_hero(1)
  near(s.hero.hp,23+240*T.ranked("p2_heal",rank),"P2 threshold heal rank%d"%rank)
  near(s.hero.cooldowns.q,0,"P2 resets Q")
  near(s.hero.cooldowns.e,0,"P2 resets E")
  near(s.hero.cooldowns.passive,T.ranked("p2_cd",rank),"P2 new test CD table")
  s.hero.hp=24
  s.damage_hero(1)
  near(s.hero.hp,23,"P2 cannot retrigger on cooldown")
  s.free()
 s=fixture()
 s.hero.loadout.passive="p2"
 s.hero.hp=25
 s.damage_hero(1)
 near(s.hero.hp,24,"P2 exactly10% excluded")
 near(s.hero.cooldowns.passive,0,"P2 exactly10% no cooldown")
 s.hero.hp=20
 s.damage_hero(1)
 near(s.hero.hp,19,"P2 below-to-below excluded")
 s.hero.hp=24
 s.damage_hero(100)
 near(s.hero.hp,0,"P2 lethal cannot save")
 near(s.hero.cooldowns.passive,0,"P2 lethal cannot trigger")
 s.free()
 s=fixture()
 s.hero.loadout.passive="p2"
 s.request_action("e")
 s.hero.hp=24
 s.damage_hero(1)
 near(s.hero.overload_left,7,"P2 does not restart/duplicate E3")
 check(not s.request_action("e").accepted,"P2 no two simultaneous E3 states")
 s.step(7)
 near(s.hero.cooldowns.e,0,"P2 active E3 finishes then skips one cooldown")
 check(s.request_action("e").accepted,"P2 E ready after natural finish")
 s.step(7)
 near(s.hero.cooldowns.e,32,"P2 reset credit consumed only once")
 s.free()
 s=fixture()
 s.hero.loadout.passive="p2"
 s.hero.loadout.q="q2"
 s.spawn_enemy("minion",Vector3(0,0,-2),1000)
 s.request_action("q",Vector3(0,0,-2))
 s.hero.hp=24
 s.damage_hero(1)
 near(s.hero.hp,24,"Q2 immune damage cannot trigger P2")
 s.free()

func _test_progression_integration() -> void:
 cases.append("ledger integration preserves HP/CD/time; no mechanic branches")
 var s=fixture()
 s.hero.hp=123
 s.hero.cooldowns.q=3
 s.hero.cooldowns.e=8
 var old_time:float=s.clock.world_time
 check(s.learn_ability("Q","Q1").ok,"learn numeric upgrade during combat")
 near(s.hero.ranks.q,2,"ledger rank applied to runtime")
 near(s.hero.hp,123,"upgrade no heal")
 near(s.hero.cooldowns.q,3,"upgrade no cooldown refresh")
 near(s.clock.world_time,old_time,"upgrade does not pause/change time")
 s.step(0.1)
 check(s.clock.world_time>old_time,"combat keeps advancing after investment")
 s.end_encounter("victory")
 old_time=s.clock.world_time
 var cd:float=s.hero.cooldowns.q
 check(s.undo_new_investment().ok,"new combat investment undo between rooms")
 near(s.hero.ranks.q,1,"undo only new rank")
 near(s.hero.hp,123,"undo no heal")
 near(s.hero.cooldowns.q,cd,"undo no cooldown refresh")
 check(not s.undo_new_investment().ok,"committed old ranks not undoable")
 check(not s.reset_at_training().ok,"old loadout reset outside training refused")
 s.progression.set_training_node(true)
 check(s.reset_at_training().ok,"training reset allowed")
 near(s.hero.ranks.q,0,"unlearned slot represented")
 near(s.hero.cooldowns.q,cd,"training reset preserves old slot CD")
 near(s.hero.hp,123,"training reset preserves HP")
 near(s.clock.world_time,old_time,"training reset frozen time")
 near(s.progression.snapshot().available,6,"reset returns actual costs no new points")
 s.free()

func _test_transaction_boundaries() -> void:
 cases.append("room frame budget/no phantom actions/R2 event order/reentrancy")
 var s=fixture()
 var before:Dictionary=s.snapshot()
 check(not s.request_action("passive").accepted,"passive is not an action")
 check(s.snapshot()==before,"unknown action no mutation")
 s.hero.loadout.q="q2"
 before=s.snapshot()
 var serial:int=s.cast_serial
 check(not s.request_action("q",Vector3.RIGHT*5).accepted,"Q2 no target refused")
 check(s.snapshot()==before and serial==s.cast_serial,"failed targeting restores aim/facing/serial")
 s.free()
 s=fixture()
 s.auto_finish=true
 s.spawn_enemy("minion",Vector3(0,0,-2),1)
 s.request_action("attack")
 s.step(1)
 check(s.phase=="victory","coarse frame last kill victory")
 near(s.real_accumulator,0,"room end discards old real frame tail")
 var old_time:float=s.clock.world_time
 s.hero.cooldowns.q=5
 check(s.begin_encounter("training-02",[{"kind":"minion","position":Vector3(0,0,-5)}]).accepted,"next room API accepted")
 s.step(0)
 near(s.clock.world_time,old_time,"next room cannot consume prior frame")
 near(s.hero.cooldowns.q,5,"next room preserves cooldown")
 s.step(0.1)
 near(s.hero.cooldowns.q,4.9,"next room resumes only new world time")
 s.free()
 s=fixture()
 s.hero.loadout.r="r2"
 s.request_action("r")
 s.step(0.25)
 var observations:Array=[]
 s.combat_event.connect(func(ev):
  if ev.kind=="attack_completed":
   observations.append({"count":s.hero.cast_state.r2.attacks,"reentrant":s.request_action("r")})
 )
 s.request_action("attack")
 s.step(0.1)
 check(observations.size()==1,"attack completion emitted exactly once")
 check(observations[0].count==1,"R2 count visible atomically at completion event")
 check(not observations[0].reentrant.accepted and observations[0].reentrant.reason=="transaction_in_progress","signal cannot reenter incomplete damage transaction")
 check(s.request_action("r").accepted,"next input can cast after transaction")
 near(s.hero.cast_state.r2.last_nails,2,"next R2 uses completed attack count")
 s.free()

 s=fixture()
 s.hero.invulnerable_left=1.0
 s.request_action("r")
 s.step(1.1)
 near(s.hero.invulnerable_left,0.78,"R1 preserves overlapping E2/rescue immunity in world time")
 check(s.snapshot().hero.invulnerable,"snapshot unions independent immunity sources")
 s.free()

 s=fixture()
 s.hero.loadout.e="e1"
 var marked=s.spawn_enemy("minion",Vector3(0,0,-2),1000)
 s.request_action("e",marked.position)
 s.step(0.2)
 s.damage_enemy(marked,2000,"test",777)
 before=s.snapshot()
 check(not s.request_action("e",Vector3.RIGHT).accepted,"dead E1 mark refuses second stage")
 check(s.snapshot()==before,"failed E1 does not mutate existing cast or CD")
 s.step(0.005)
 near(s.hero.cooldowns.e,18,"next authoritative tick finalizes lost mark")
 s.free()

func _test_independent_slots() -> void:
 cases.append("all11 candidates independently learned/empty other slots; R2 window bounds")
 for slot in ["q","e","r","passive"]:
  var candidates:Array = {"q":["q1","q2","q3"],"e":["e1","e2","e3"],"r":["r1","r2"],"passive":["p1","p2","p3"]}[slot]
  for candidate in candidates:
   var s=fixture()
   check(s.configure_test_loadout({slot:candidate}).ok,"independent fixture "+candidate)
   for other in ["q","e","r","passive"]:
    if other!=slot: check(s.hero.ranks[other]==0,"empty other slot "+candidate+"/"+other)
   var target=s.spawn_enemy("elite",Vector3(0,0,-2),1000)
   if slot!="passive":
    check(s.request_action(slot,target.position).accepted,"standalone action "+candidate)
   elif candidate=="p1":
    s.hero.hp=100
    s.request_action("attack",target.position)
    s.step(0.1)
    check(s.hero.hp>100,"P1 independent lifesteal")
   elif candidate=="p2":
    s.hero.hp=24
    s.damage_hero(1)
    check(s.hero.hp>24,"P2 independent low health trigger")
   else:
    for i in 10:
     var victim=s.spawn_enemy("minion",Vector3(8,0,8),1)
     s.damage_enemy(victim,100,"test",i)
    near(s.hero.permanent_ad,1,"P3 independent permanent run growth")
   s.free()
 for offset in [-0.001,0.0,0.001]:
  var s=fixture()
  s.hero.loadout.r="r2"
  s.request_action("r")
  s.step(0.25)
  s.clock.world_time=s.hero.cast_state.r2.expires+offset
  var before:Dictionary=s.snapshot()
  var result:Dictionary=s.request_action("r")
  check(result.accepted==(offset<0),"R2 exclusive world window boundary "+str(offset))
  if offset>=0: check(s.snapshot()==before,"late R2 rejection leaves settlement to tick")
  s.free()

 for pair in [["e3","e1","E","e"],["r2","r1","R","r"]]:
  var s=fixture()
  s.hero.loadout[pair[3]]=pair[0]
  s.request_action(pair[3])
  s.end_encounter("victory")
  s.progression.set_training_node(true)
  s.reset_at_training()
  s.learn_ability(pair[2],pair[1].to_upper())
  s.begin_encounter("after-training",[{"kind":"elite","position":Vector3(0,0,-2),"hp":1000}])
  var refused:Dictionary=s.request_action(pair[3],Vector3(0,0,-2))
  check(not refused.accepted and refused.reason=="previous_candidate_active","retained "+pair[0]+" blocks free parallel "+pair[1])
  s.free()
