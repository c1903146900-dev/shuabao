extends "res://tests/ink_q3_foundation_20261004/ink_q3_enemy_director.gd"
## Local target-position seams only. No decoy HP, hitbox, damage interception,
## or forced attack retargeting after commitment. With no eligible decoy every
## original role method delegates byte-for-byte to the inherited implementation.

func _decoy(sim, enemy: Dictionary) -> Dictionary:
 return sim.e2_decoy_target(enemy)

func _update_taunts(sim) -> void:
 var scope: Dictionary = sim._ink_scope()
 var active_decoy: bool = not sim.ink_boat.is_empty() and sim.ink_boat.get("phase","")=="decoy" and sim._e2_live(sim.ink_boat) and sim.hero_time<float(sim.ink_boat.decoy_until)-sim.TIME_EPS
 if not active_decoy:
  for enemy in sim.enemies:
   if not str(enemy.get("taunt_source","")).ends_with(":decoy"): continue
   var previous_source: String = str(enemy.taunt_source)
   enemy.taunted=false; enemy.taunt_source=""; enemy.target_actor_id=sim.hero.actor_id; enemy.erase("ink_e2_decoy_position")
   enemy.nav_points=[]; enemy.nav_left=0.0
   sim.emit_event("enemy_taunt_ended",{"actor_id":enemy.actor_id,"enemy_kind":enemy.kind,"position":enemy.position,"source":previous_source,"target_actor_id":sim.hero.actor_id})
   if not sim._ink_scope_current(scope): return
  super._update_taunts(sim)
  return
 var fortress: Dictionary = sim.hero.cast_state.get("r1",{})
 var fortress_radius: float = float(fortress.get("taunt_radius",0.0))
 for enemy in sim.enemies:
  var target: Dictionary = _decoy(sim,enemy)
  var previous: bool = enemy.get("taunted",false)
  var previous_source: String = str(enemy.get("taunt_source",""))
  # Original fortress eligibility is retained only for the original fortress.
  var fortress_active: bool = not enemy.dead and enemy.get("rank_category","ordinary")=="ordinary" and not fortress.is_empty() and enemy.position.distance_to(sim.hero.position)<=fortress_radius
  var active: bool = not target.is_empty() or fortress_active
  var source: String = str(target.actor_id) if not target.is_empty() else str(sim.hero.actor_id) if fortress_active else ""
  enemy.taunted=active; enemy.taunt_source=source
  enemy.target_actor_id=target.actor_id if not target.is_empty() else sim.hero.actor_id
  if not target.is_empty(): enemy.ink_e2_decoy_position=target.position
  else: enemy.erase("ink_e2_decoy_position")
  if active!=previous or previous_source!=source:
   if previous_source.ends_with(":decoy") or not target.is_empty(): enemy.nav_points=[]; enemy.nav_left=0.0
   if previous and previous_source!=source:
    sim.emit_event("enemy_taunt_ended",{"actor_id":enemy.actor_id,"enemy_kind":enemy.kind,"position":enemy.position,"source":previous_source,"target_actor_id":enemy.target_actor_id})
    if not sim._ink_scope_current(scope): return
   if active:
    sim.emit_event("enemy_taunt_started",{"actor_id":enemy.actor_id,"enemy_kind":enemy.kind,"position":enemy.position,"source":source,"target_actor_id":enemy.target_actor_id,"target_position":target.position if not target.is_empty() else sim.hero.position,"radius":target.radius if not target.is_empty() else fortress_radius})
    if not sim._ink_scope_current(scope): return

func _in_position(sim, enemy: Dictionary) -> bool:
 var decoy: Dictionary = _decoy(sim,enemy)
 if decoy.is_empty(): return super._in_position(sim,enemy)
 var distance: float=enemy.position.distance_to(Vector3(decoy.position))
 if distance>float(PROFILES[enemy.kind][5]): return false
 if enemy.kind in ["ranged","pitcher","support"] and distance<3.3: return false
 if enemy.kind=="pouncer" and distance<2.2: return false
 return true


func _move_role(sim, enemy: Dictionary, dt: float) -> void:
 var decoy: Dictionary = _decoy(sim,enemy)
 if decoy.is_empty(): super._move_role(sim,enemy,dt); return
 var offset: Vector3=Vector3(decoy.position)-enemy.position
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
     var behind: Vector3=guard.position+Vector3(decoy.position).direction_to(guard.position)*2.2
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
 var speed: float=enemy.speed*(1.0-enemy.slow_amount if enemy.slow_left>0 else 1.0)
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


func _candidate(sim, enemy: Dictionary) -> Dictionary:
 var decoy: Dictionary = _decoy(sim,enemy)
 if decoy.is_empty(): return super._candidate(sim,enemy)
 var direction: Vector3=enemy.position.direction_to(Vector3(decoy.position))
 if direction.length_squared()<0.001: direction=enemy.get("facing",Vector3.FORWARD)
 return {"kind":enemy.kind,"origin":enemy.position,"direction":direction,"target":Vector3(decoy.position),"radius":1.45 if enemy.kind=="pitcher" else float(PROFILES[enemy.kind][5]),"width":1.25 if enemy.kind=="pouncer" else 0.32,"angle":enemy.attack_angle,"owner":enemy.actor_id}


func _commit(sim, enemy: Dictionary) -> void:
 var decoy: Dictionary = _decoy(sim,enemy)
 if decoy.is_empty():
  # Keep the old committed warning intact until this actual next commitment.
  if enemy.has("committed_target_actor_id"): enemy.committed_target_actor_id=sim.hero.actor_id
  super._commit(sim,enemy)
  return
 enemy.committed_target_actor_id=decoy.actor_id
 enemy.state="warning"
 enemy.timer=float(PROFILES[enemy.kind][6])
 enemy.warning_duration=enemy.timer
 enemy.warning_progress=0.0
 enemy.aim=enemy.position.direction_to(Vector3(decoy.position))
 if enemy.aim.length_squared()<0.001: enemy.aim=Vector3.FORWARD
 enemy.facing=enemy.aim
 enemy.committed_origin=enemy.position
 enemy.target_point=Vector3(decoy.position)
 enemy.wait_age=0.0
 var active_duration:=0.40 if enemy.kind=="pouncer" else 0.10
 enemy.threat_left=enemy.timer+active_duration
 commit_gap_left=MIN_COMMIT_GAP
 commits+=1
 peak_threat_weight=maxi(peak_threat_weight,active_threat_weight(sim))
 sim.emit_event("enemy_warning",{"actor_id":enemy.actor_id,"position":enemy.position,"target_point":enemy.target_point,"direction":enemy.aim,"shape":enemy.attack_shape,"duration":enemy.timer,"radius":enemy.attack_range,"width":enemy.attack_width,"angle":enemy.attack_angle,"enemy_kind":enemy.kind,"role":enemy.role,"telegraph_style":"body_weapon","ground_warning":false,"committed":true,"target_actor_id":decoy.actor_id,"target_is_decoy":true})

