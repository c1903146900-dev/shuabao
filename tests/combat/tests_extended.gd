extends RefCounted
const Sim = preload("res://scripts/combat/combat_sim.gd")
var checks := 0
var failures: Array[String] = []
func check(condition: bool, label: String) -> void:
 checks+=1
 if not condition: failures.append(label)
func near(a: float,b: float,tolerance: float=0.011) -> bool:
 return absf(a-b)<=tolerance
func fresh():
 var sim=Sim.new()
 sim.auto_finish=false
 sim.ai_enabled=false
 sim.hero.stats.regen=0.0
 sim.hero.loadout.passive="p1"
 return sim
func run() -> Dictionary:
 checks=0
 failures.clear()
 var s=fresh()
 s.hero.loadout.q="q2"
 s.hero.ranks.e=0
 s.hero.ranks.r=0
 for i in range(5): s.spawn_enemy("minion",Vector3(i*0.8,0,3),200)
 check(s.request_action("q",Vector3(0,0,3)).accepted,"Q2 standalone starts")
 check(s.hero.untargetable and s.extensions.is_immune(),"Q2 untargetable AND immune")
 s.damage_hero(500,Vector3.RIGHT,5)
 check(s.hero.hp==240 and s.hero.stun_left==0,"Q2 damage/control immunity")
 check(not s.request_action("attack").accepted,"Q2 locks other inputs")
 s.step(0.8)
 var damaged:=0
 for enemy in s.enemies:
  if enemy.hp<200:
   damaged+=1
   check(near(enemy.hp,152),"Q2 each target hit once for 1.5 AD")
 check(damaged==4,"Q2 exactly four unique targets maximum")
 check(not s.hero.untargetable and not s.extensions.is_immune(),"Q2 finishes immunity")
 check(near(s.hero.cooldowns.q,12.0),"Q2 cooldown only after full chain")
 s.free()
 s=fresh()
 s.hero.loadout.q="q2"
 var target: Dictionary=s.spawn_enemy("minion",Vector3(0,0,3),200)
 s.request_action("q",target.position)
 s.step(0.2)
 check(near(target.hp,152) and not s.hero.cast_state.has("q2"),"Q2 single enemy is not hit four times")
 s.free()
 s=fresh()
 s.hero.loadout.q="q2"
 target=s.spawn_enemy("minion",Vector3(0,0,3),200)
 s.request_action("q",target.position)
 s.damage_enemy(target,1000,"test",999)
 s.step(0.2)
 check(not s.hero.cast_state.has("q2") and s.hero.cooldowns.q>11.9,"Q2 target death safely ends with cooldown")
 s.free()
 s=fresh()
 s.hero.loadout.q="q3"
 target=s.spawn_enemy("minion",Vector3(0,0,-2),200)
 var boss: Dictionary=s.spawn_enemy("boss",Vector3(0,0,-4),1000)
 var outside: Dictionary=s.spawn_enemy("minion",Vector3(5,0,-2),200)
 check(s.request_action("q",target.position).accepted,"Q3 standalone")
 check(near(target.hp,174.4) and near(boss.hp,974.4),"Q3 base .8 AD once")
 check(outside.hp==200,"Q3 rectangle excludes side enemy")
 check(target.knockback.length()>0 and boss.stun_left>0,"Q3 knockback and boss stagger conversion")
 check(near(s.hero.cooldowns.q,11),"Q3 cooldown")
 s.free()
 s=fresh()
 s.hero.loadout.e="e1"
 target=s.spawn_enemy("elite",Vector3(0,0,0),300)
 check(s.request_action("e",target.position).accepted,"E1 standalone flight")
 check(s.hero.cooldowns.e==0,"E1 no cooldown during flight")
 target.position.x=1
 s.step(0.4)
 check(s.hero.cast_state.has("e1") and s.hero.cast_state.e1.stage=="marked","E1 tracks moving target then marks")
 check(near(target.hp,252),"E1 dagger 1.5 AD")
 var origin: Vector3=s.hero.position
 check(s.request_action("e",Vector3(1,0,-30)).accepted,"E1 recast")
 check(s.hero.position.distance_to(target.position)<=3.001,"E1 recast constrained to target circle")
 check(s.hero.position!=origin and near(target.hp,236),"E1 path .5 AD and movement")
 check(not s.hero.cast_state.has("e1") and near(s.hero.cooldowns.e,18),"E1 recast consumes mark and starts CD")
 s.free()
 s=fresh()
 s.hero.loadout.e="e1"
 target=s.spawn_enemy("elite",Vector3(0,0,3),300)
 s.request_action("e",target.position)
 s.step(0.2)
 check(s.hero.cast_state.e1.stage=="marked","E1 mark ready for expiry")
 s.step(5)
 check(not s.hero.cast_state.has("e1") and s.hero.cooldowns.e>17.8,"E1 expiry starts cooldown")
 s.free()
 s=fresh()
 s.hero.loadout.e="e1"
 target=s.spawn_enemy("elite",Vector3(0,0,0),300)
 s.request_action("e",target.position)
 s.damage_enemy(target,1000,"test",999)
 s.step(0.005)
 check(not s.hero.cast_state.has("e1") and near(s.hero.cooldowns.e,18),"E1 lost projectile target starts CD")
 s.free()
 s=fresh()
 s.hero.loadout.e="e2"
 target=s.spawn_enemy("elite",Vector3(0,0,4),300)
 outside=s.spawn_enemy("minion",Vector3(0,0,-1),200)
 s.hero.move_intent=Vector3.RIGHT
 check(s.request_action("e",Vector3(0,0,-30)).accepted,"E2 standalone spin")
 check(near(target.hp,277.6),"E2 single spin .7 AD")
 var initial: Vector3=s.hero.position
 s.step(0.1)
 check(s.hero.position.x>initial.x,"E2 permits movement while spinning")
 check(not s.request_action("attack").accepted,"E2 spin prevents other cast")
 var before_blink: Vector3=s.hero.position
 s.step(0.15)
 check(s.hero.position.distance_to(before_blink)<=6.91,"E2 blink distance clamped")
 check(s.hero.invulnerable_left>0.99,"E2 occupied landing gives one second immunity")
 check(near(target.hp,277.6) and outside.hp==200,"E2 no extra spin or landing damage")
 check(near(s.hero.cooldowns.e,17),"E2 cooldown after spin and blink")
 s.free()
 s=fresh()
 s.hero.loadout.e="e2"
 s.request_action("e",Vector3(0,0,-30))
 s.step(0.25)
 check(s.hero.invulnerable_left==0,"E2 empty landing has no immunity")
 s.free()
 s=fresh()
 s.hero.loadout.r="r2"
 boss=s.spawn_enemy("boss",Vector3(0,0,0),10000)
 check(s.request_action("r",boss.position).accepted,"R2 standalone first throw")
 check(s.hero.cast_state.r2.last_nails==1 and near(boss.hp,9959),"R2 first nail .5 AD + .25 percent max HP")
 check(boss.slow_left==0 and near(boss.stagger,0.3),"R2 boss control converts to explicit test stagger")
 check(s.extensions.is_immune() and s.clock.scale_factor()==0.2,"R2 independent immune slow presentation")
 s.damage_hero(100)
 check(s.hero.hp==240,"R2 presentation damage immune")
 check(not s.request_action("r").accepted,"R2 cannot cast during presentation")
 s.step(0.25)
 for id in [100,101]: s.extensions.on_basic_attack_completed({"cast_id":id,"hit":false})
 s.extensions.on_basic_attack_completed({"cast_id":100,"hit":false})
 check(s.hero.cast_state.r2.attacks==2,"R2 miss completion counts; duplicate events do not")
 check(s.request_action("r",boss.position).accepted,"R2 second throw")
 check(s.hero.cast_state.r2.last_nails==3 and near(boss.hp,9836),"R2 second has 1+2 nails")
 s.step(0.25)
 s.extensions.on_basic_attack_completed({"cast_id":102,"hit":true})
 check(s.request_action("r",boss.position).accepted,"R2 third throw")
 check(s.hero.cast_state.r2.last_nails==4 and near(boss.hp,9672),"R2 cumulative not reset: third 1+3 nails")
 check(s.hero.cooldowns.r==0,"R2 CD waits for third presentation")
 s.step(0.25)
 check(not s.hero.cast_state.has("r2") and near(s.hero.cooldowns.r,130),"R2 ends third show then cooldown")
 check(s.clock.scale_factor()==1 and not s.extensions.is_immune(),"R2 presentation clean exit")
 s.free()
 s=fresh()
 s.hero.loadout.r="r2"
 s.request_action("r")
 s.step(0.25)
 for id in range(200): s.extensions.on_basic_attack_completed({"cast_id":id})
 s.request_action("r")
 check(s.hero.cast_state.r2.last_nails==201,"R2 no arbitrary nail cap")
 s.step(0.25)
 s.step(3)
 check(not s.hero.cast_state.has("r2") and s.hero.cooldowns.r>129,"R2 abandoned window starts cooldown")
 s.free()
 s=fresh()
 s.hero.loadout.r="r2"
 s.request_action("r")
 s.end_encounter("victory")
 var frozen: Dictionary=s.hero.cast_state.duplicate(true)
 s.step(20)
 check(s.clock.presenters.is_empty() and not s.extensions.is_immune(),"room end clears R2 presentation")
 check(s.hero.cast_state==frozen and s.hero.cast_state.r2.round==1,"room end retains and freezes unused rounds")
 s.free()
 s=fresh()
 s.hero.loadout.r="r2"
 target=s.spawn_enemy("elite",Vector3(0,0,0),1000)
 s.request_action("r",target.position)
 check(near(target.slow_amount,0.3) and near(target.slow_left,3),"R2 ordinary enemy 30 percent slow for 3 seconds")
 s.step(0.25)
 s.extensions.on_basic_attack_completed({"cast_id":500})
 s.request_action("r",target.position)
 check(near(target.slow_amount,0.3) and near(target.slow_left,3),"R2 multiple nails refresh duration without stacking slow")
 s.free()
 s=fresh()
 s.hero.loadout.q="q3"
 s.hero.ranks.q=5
 target=s.spawn_enemy("elite",Vector3(0,0,3),1000)
 s.request_action("q",target.position)
 check(near(target.hp,1000-32*0.8*1.4),"Q3 rank five numeric-only explicit test growth")
 s.free()
 s=fresh()
 s.hero.loadout.r="r2"
 s.hero.ranks.r=3
 target=s.spawn_enemy("boss",Vector3(0,0,3),10000)
 s.request_action("r",target.position)
 check(near(target.hp,10000-(32*0.5*1.2+25)),"R2 numeric AD growth preserves .25 percent HP coefficient")
 s.free()
 s=fresh()
 s.hero.loadout.r="r2"
 s.request_action("r")
 s.step(0.25)
 check(s.request_action("attack").accepted,"R2 window allows basic attacks")
 s.step(0.1)
 check(s.hero.cast_state.r2.attacks==1,"actual attack_completed host hook counts empty swing")
 s.step(0.6)
 s.request_action("attack")
 s.step(0.1)
 s.request_action("r")
 check(s.hero.cast_state.r2.last_nails==3,"actual two empty attacks generate three nails")
 s.free()
 s=fresh()
 s.hero.loadout.r="r2"
 s.clock.enter("another_caster",1.0)
 s.request_action("r")
 check(near(s.clock.scale_factor(),0.2),"overlapping ultimate slowdown does not multiply")
 s.step(0.25)
 check(not s.extensions.is_immune() and s.clock.presenters.has("another_caster"),"own presentation ends independently of another caster")
 s.free()
 s=fresh()
 s.hero.loadout.q="q2"
 target=s.spawn_enemy("elite",Vector3(0,0,3),300)
 s.request_action("q",target.position)
 s.end_encounter("training_stop")
 var q_frozen: Dictionary=s.hero.cast_state.duplicate(true)
 s.step(10)
 check(s.hero.cast_state==q_frozen and not s.hero.untargetable,"Q2 room end freezes chain but clears selection presentation")
 s.free()
 s=fresh()
 s.hero.loadout.q="q2"
 target=s.spawn_enemy("elite",Vector3(0,0,3),300)
 s.request_action("q",target.position)
 target.position=Vector3(12,0,-12)
 s.step(0.2)
 check(target.hp==300 and not s.hero.cast_state.has("q2"),"Q2 initial target moving out of range is not hit")
 s.free()
 s=fresh()
 s.hero.loadout.q="q2"
 target=s.spawn_enemy("elite",Vector3(0,0,3),300)
 outside=s.spawn_enemy("elite",Vector3(0,0,0),300)
 var far: Dictionary=s.spawn_enemy("elite",Vector3(12,0,-12),300)
 s.request_action("q",target.position)
 s.step(0.2)
 s.damage_enemy(outside,1000,"test",999)
 s.step(0.2)
 check(not s.hero.cast_state.has("q2") and far.hp==300,"Q2 dead next target never retargets outside chain radius")
 s.free()
 s=fresh()
 s.hero.loadout.r="r2"
 s.auto_finish=true
 target=s.spawn_enemy("elite",Vector3(0,0,3),300)
 s.request_action("r",target.position)
 s.step(0.25)
 s.request_action("r",target.position)
 s.step(0.25)
 target.hp=1
 s.request_action("r",target.position)
 check(s.phase=="victory" and not s.hero.cast_state.has("r2"),"R2 final third throw lethal finishes room and sequence")
 check(near(s.hero.cooldowns.r,130) and s.clock.presenters.is_empty(),"R2 final lethal clears slow and commits cooldown")
 check(s.frozen_snapshot==s.snapshot(),"R2 lethal terminal snapshot is authoritative")
 s.free()
 return {"suite":"extended_abilities","passed":failures.is_empty(),"checks":checks,"failures":failures.duplicate()}
