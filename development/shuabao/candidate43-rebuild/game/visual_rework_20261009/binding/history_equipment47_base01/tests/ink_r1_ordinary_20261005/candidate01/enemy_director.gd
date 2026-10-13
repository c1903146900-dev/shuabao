extends "res://tests/ink_enemy_navigation_fix01_20261005/enemy_director.gd"
## R1-only rate consumption. No-R calls delegate to the original exact methods.
## These two bodies preserve the base director state machine/navigation; the
## source checker verifies their explicitly listed rate substitutions.
## Source slow fields and tenacity are never written by the snow projection.

func step_enemy(sim, enemy: Dictionary, dt: float) -> void:
 if _frozen(sim) or not sim.ai_enabled or enemy.dead: return
 var snow: Dictionary = sim.r1_step_enemy_rates(enemy,dt)
 if not bool(snow.in_domain):
  super.step_enemy(sim,enemy,dt)
  return
 var controlled: bool=enemy.carried or not enemy.push.is_empty() or not enemy.pull_state.is_empty() or enemy.stun_left>0
 enemy.stun_left=maxf(0.0,enemy.stun_left-dt)
 enemy.slow_left=maxf(0.0,enemy.slow_left-dt)
 enemy.guard_broken_left=maxf(0.0,float(enemy.get("guard_broken_left",0.0))-dt)
 enemy.guard_flash_left=maxf(0.0,float(enemy.get("guard_flash_left",0.0))-dt)
 enemy.threat_left=maxf(0.0,float(enemy.get("threat_left",0.0))-dt)
 if controlled:
  if not enemy.get("was_controlled",false): _interrupt(sim,enemy)
  enemy.was_controlled=true
  enemy.guard_active=false
  return
 enemy.was_controlled=false
 # Only attack preparation/cadence clocks use attack rate. Spawn and active
 # pounce retain their authored world-time durations; no other timer is scaled.
 var attack_dt: float = dt*float(snow.attack_rate) if enemy.state in ["chase","warning","recover"] else dt
 enemy.timer=maxf(0.0,enemy.timer-attack_dt)
 # A slowed warning must keep its threat reservation until actual release.
 # The ordinary world-time decrement above is retained, as are release handoffs.
 if enemy.state == "warning":
  enemy.threat_left=maxf(float(enemy.threat_left),float(enemy.timer)+(0.40 if enemy.kind=="pouncer" else 0.10))
 enemy.guard_active=enemy.kind=="armored" and enemy.guard_broken_left<=0 and enemy.state in ["chase","warning"] and enemy.warning_progress<0.65
 match enemy.state:
  "spawn":
   enemy.warning_progress=1.0-enemy.timer/SPAWN_GRACE
   if enemy.timer<=EPS:
    enemy.state="chase"
    enemy.warning_progress=0.0
    enemy.timer=0.10+float(int(enemy.serial)%5)*0.055
  "chase":
   enemy.wait_age+=dt
   if enemy.timer<=EPS and _in_position(sim,enemy) and _can_commit(sim,enemy): _commit(sim,enemy)
   else: _move_role(sim,enemy,dt)
  "warning":
   enemy.warning_progress=clampf(1.0-enemy.timer/maxf(EPS,enemy.warning_duration),0,1)
   if enemy.timer<=EPS: _release(sim,enemy)
  "pounce":
   var previous: Vector3=enemy.position
   var lunge_speed: float=15.0*(1.0-enemy.slow_amount if enemy.slow_left>0 else 1.0)*float(snow.move_rate)
   enemy.position=_clip_motion(sim,previous,previous+enemy.aim*lunge_speed*dt,enemy.radius)
   if not enemy.get("did_hit",false) and _segment_distance(sim.hero.position,previous,enemy.position)<=enemy.radius+HERO_RADIUS:
    enemy.did_hit=true
    sim.damage_hero(enemy.damage,enemy.aim,0.12)
    _impact(sim,enemy,true)
   if enemy.timer<=EPS or enemy.position.distance_squared_to(previous)<0.000001:
    if not enemy.get("did_hit",false): _impact(sim,enemy,false)
    _recover(enemy)
  "recover":
   enemy.guard_active=false
   if enemy.timer<=EPS:
    enemy.state="chase"
    enemy.warning_progress=0.0
    enemy.wait_age=0.0

func _move_role(sim, enemy: Dictionary, dt: float) -> void:
 var snow: Dictionary = sim.r1_step_enemy_rates(enemy,dt)
 if not bool(snow.in_domain):
  super._move_role(sim,enemy,dt)
  return
 var offset: Vector3=sim.hero.position-enemy.position
 var distance:=offset.length()
 var toward:=offset.normalized() if distance>EPS else Vector3.RIGHT
 var side:=Vector3(-toward.z,0,toward.x)*float(enemy.flank_sign)
 var motion:=toward
 match enemy.kind:
  "pouncer":
   motion=(toward*0.75+side*0.70).normalized() if distance>4.2 else (side*0.95-toward*0.32).normalized()
  "ranged","pitcher","support":
   var preferred:=8.5 if enemy.kind=="pitcher" else 7.3
   motion=-toward if distance<preferred-0.9 else (toward if distance>preferred+1.4 else side*0.5)
   # A guard provides a moving front, never a stationary invulnerable escort wall.
   if enemy.kind=="support":
    var guard: Dictionary=_closest_guard(sim,enemy)
    if not guard.is_empty() and distance>5.0:
     var behind: Vector3=guard.position+sim.hero.position.direction_to(guard.position)*2.2
     motion=enemy.position.direction_to(behind) if enemy.position.distance_to(behind)>1.6 else side*0.35
  _:
   if distance<enemy.radius+HERO_RADIUS+0.12: motion=side*0.5
 # Separate actors with the existing bounded spatial index (no all-pairs crowd loop).
 var separation:=Vector3.ZERO
 for other in sim._nearby(enemy.position,12,enemy.actor_id):
  if other.dead or other.actor_id==enemy.actor_id: continue
  sim.pair_checks+=1
  var away: Vector3=enemy.position-other.position
  var personal: float=enemy.radius+other.radius+0.18
  if away.length_squared()<personal*personal and away.length_squared()>0.001:
   separation+=away.normalized()*(personal-away.length())*5.0
 var speed: float=enemy.speed*(1.0-enemy.slow_amount if enemy.slow_left>0 else 1.0)*float(snow.move_rate)
 var desired: Vector3=enemy.position+(motion*speed+separation)*dt
 # Collision with the hero is soft spacing; enemies cannot body-stack on the hero.
 if desired.distance_to(sim.hero.position)<enemy.radius+HERO_RADIUS+0.10:
  var away: Vector3=sim.hero.position.direction_to(desired)
  if away.length_squared()<EPS: away=Vector3.RIGHT*float(enemy.flank_sign)
  var perimeter: Vector3=sim.hero.position+away*(enemy.radius+HERO_RADIUS+0.10)
  desired=Vector3(enemy.position).move_toward(perimeter,(speed+separation.length())*dt)
 enemy.position=_navigate_step(sim,enemy,desired,dt)
 # Guard turning is limited, so going around it actually works.
 var facing: Vector3=enemy.get("facing",toward)
 enemy.facing=_turn_facing(facing,toward,minf(1.0,dt*(2.7 if enemy.kind=="armored" else 8.0)))
 enemy.aim=enemy.facing

