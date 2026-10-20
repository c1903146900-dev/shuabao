extends "res://tests/ink_ultimate_presentation_20261006/r1_consumer01/timed_director.gd"
## H10 target-only composition. Existing warnings, projectiles, Boss behavior,
## collision, hostile damage, R1 rates and G01 delivery remain inherited.

static func e2_decoy_eligibility_reason(enemy: Dictionary) -> String:
 if bool(enemy.get("dead",false)): return "dead"
 var kind: String = str(enemy.get("kind",""))
 var rank: String = str(enemy.get("rank_category",""))
 if kind == "boss" or rank == "boss": return "boss_immune"
 if rank == "elite" and kind == "elite": return "eligible"
 if rank == "ordinary" and kind in ["minion","pouncer","armored","ranged","pitcher","support"]: return "eligible"
 return "unknown_or_mismatched_enemy_class"

static func e2_decoy_eligible(enemy: Dictionary) -> bool:
 return e2_decoy_eligibility_reason(enemy) == "eligible"

func _update_taunts(sim) -> void:
 var scope: Dictionary = sim._ink_scope()
 var boat: Dictionary = sim.ink_boat
 var live: bool = not boat.is_empty() and boat.get("phase","") == "decoy" and not bool(boat.get("decoy_cleared",false)) and sim._e2_live(boat) and not bool(sim.hero.dead) and sim.hero_time < float(boat.get("decoy_until",0.0))-sim.TIME_EPS
 var decoy_id: String = str(boat.get("decoy_actor_id","")) if live else ""
 var fortress: Dictionary = sim.hero.cast_state.get("r1",{})
 var radius: float = float(fortress.get("taunt_radius",0.0))
 for enemy: Dictionary in sim.enemies:
  var decoy_active: bool = live and not decoy_id.is_empty() and e2_decoy_eligible(enemy) and sim._e2_target_current(enemy,boat) and enemy.position.distance_to(Vector3(boat.position)) <= float(boat.get("taunt_radius",0.0))
  var fortress_active: bool = not enemy.dead and enemy.get("rank_category","ordinary") == "ordinary" and not fortress.is_empty() and enemy.position.distance_to(sim.hero.position) <= radius
  var active: bool = decoy_active or fortress_active
  var source: String = decoy_id if decoy_active else str(sim.hero.actor_id) if fortress_active else ""
  var previous: bool = bool(enemy.get("taunted",false))
  var previous_source: String = str(enemy.get("taunt_source",""))
  var had_decoy: bool = enemy.has("ink_e2_decoy_position")
  enemy.taunted = active
  enemy.taunt_source = source
  enemy.target_actor_id = decoy_id if decoy_active else sim.hero.actor_id
  if decoy_active: enemy.ink_e2_decoy_position = Vector3(boat.position)
  else: enemy.erase("ink_e2_decoy_position")
  if previous == active and previous_source == source: continue
  if had_decoy or decoy_active:
   enemy.nav_points = []
   enemy.nav_left = 0.0
  # One final projection and one transition receipt per actor. No warning,
  # committed aim, committed target or already launched projectile is edited.
  sim.emit_event("enemy_taunt_started" if active else "enemy_taunt_ended", {"actor_id":enemy.actor_id,"enemy_kind":enemy.kind,"position":enemy.position,"source":source if active else previous_source,"previous_source":previous_source,"target_actor_id":enemy.target_actor_id,"target_position":Vector3(boat.position) if decoy_active else sim.hero.position,"radius":float(boat.get("taunt_radius",0.0)) if decoy_active else radius})
  if not sim._ink_scope_current(scope): return
  if live and (not sim._e2_live(boat) or boat.get("phase","") != "decoy" or bool(boat.get("decoy_cleared",false))): return

func _decoy(sim, enemy: Dictionary) -> Dictionary:
 if not e2_decoy_eligible(enemy): return {}
 var boat: Dictionary = sim.ink_boat
 if boat.is_empty() or boat.get("phase","") != "decoy" or bool(boat.get("decoy_cleared",false)): return {}
 if not sim._e2_live(boat) or bool(sim.hero.dead): return {}
 if not sim._e2_target_current(enemy,boat): return {}
 if enemy.position.distance_to(Vector3(boat.position)) > float(boat.get("taunt_radius",0.0)): return {}
 if sim.hero_time >= float(boat.get("decoy_until",0.0))-sim.TIME_EPS: return {}
 var actor_id: String = str(boat.get("decoy_actor_id",""))
 if actor_id.is_empty() or str(enemy.get("taunt_source","")) != actor_id: return {}
 if not bool(enemy.get("taunted",false)) or str(enemy.get("target_actor_id","")) != actor_id: return {}
 var position: Variant = enemy.get("ink_e2_decoy_position")
 if not position is Vector3 or not Vector3(position).is_finite(): return {}
 return {"actor_id":actor_id,"position":position}

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
 if decoy.is_empty():
  super._move_role(sim,enemy,dt)
  return
 var snow: Dictionary = sim.r1_step_enemy_rates(enemy,dt)
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
 var speed: float=enemy.speed*(1.0-enemy.slow_amount if enemy.slow_left>0 else 1.0)*(float(snow.move_rate) if bool(snow.in_domain) else 1.0)
 var desired: Vector3=enemy.position+(motion*speed+separation)*dt
 # Collision with the hero is soft spacing; enemies cannot body-stack on the hero.
 if desired.distance_to(sim.hero.position)<enemy.radius+HERO_RADIUS+0.10:
  var away: Vector3=sim.hero.position.direction_to(desired)
  if away.length_squared()<EPS: away=Vector3.RIGHT*float(enemy.flank_sign)
  var perimeter: Vector3=sim.hero.position+away*(enemy.radius+HERO_RADIUS+0.10)
  desired=Vector3(enemy.position).move_toward(perimeter,(speed+separation.length())*dt)
 var g01_movement: Dictionary=sim._equipment_q3_movement_begin(enemy,"r1_role" if bool(snow.in_domain) else "base_role")
 var g01_selected: Dictionary={}
 enemy.position=_navigate_step(sim,enemy,desired,dt,g01_selected if not g01_movement.is_empty() else null)
 sim._equipment_q3_movement_finish(g01_movement,g01_selected)
 # Guard turning is limited, so going around it actually works.
 var facing: Vector3=enemy.get("facing",toward)
 enemy.facing=_turn_facing(facing,toward,minf(1.0,dt*(2.7 if enemy.kind=="armored" else 8.0)))
 enemy.aim=enemy.facing

func _navigate_step(sim, enemy: Dictionary, desired: Vector3, dt: float, g01_output: Variant = null) -> Vector3:
 var decoy: Dictionary = _decoy(sim,enemy)
 if decoy.is_empty(): return super._navigate_step(sim,enemy,desired,dt,g01_output)
 var origin: Vector3 = enemy.position
 var step_length: float = origin.distance_to(desired)
 enemy.nav_left = maxf(0.0,float(enemy.get("nav_left",0.0))-dt)
 var points: Array = enemy.get("nav_points",[])
 if enemy.nav_left <= 0.0 or not _nav_path_legal(sim,origin,points,enemy.radius): points = []
 # Reach a corner before dropping it. The old step-length shortcut could cut it.
 while not points.is_empty() and origin.distance_squared_to(points[0]) <= NAV_TOLERANCE_SQ:
  points.pop_front()
 enemy.nav_points = points
 if step_length <= EPS: return _clip_motion(sim,origin,desired,enemy.radius,g01_output)
 if not points.is_empty():
  var waypoint: Vector3 = origin.move_toward(points[0],step_length)
  var g01_progress: Variant = {} if g01_output is Dictionary else null
  var progress: Vector3 = _clip_motion(sim,origin,waypoint,enemy.radius,g01_progress)
  if progress.distance_squared_to(origin) > NAV_TOLERANCE_SQ:
   if g01_output is Dictionary: sim._equipment_q3_select_output(g01_output,g01_progress)
   return progress
  # Replan a persisted, now blocked route in this call; never wait out a bad point.
  points = []; enemy.nav_points = []; enemy.nav_left = 0.0
 var g01_result: Variant = {} if g01_output is Dictionary else null
 var result: Vector3 = _clip_motion(sim,origin,desired,enemy.radius,g01_result)
 if _nav_point_legal(sim,desired,enemy.radius) and result.distance_squared_to(desired) <= NAV_TOLERANCE_SQ:
  if g01_output is Dictionary: sim._equipment_q3_select_output(g01_output,g01_result)
  return result
 # Retain the small local detour, but try both sides and validate the whole chain
 # against ALL solids, boundary and inherited swept motion before accepting it.
 for obstacle: Dictionary in sim.obstacles:
  var half: Vector3 = obstacle.half+Vector3(enemy.radius,0,enemy.radius)
  var center: Vector3 = obstacle.position
  if _segment_box_entry(origin,desired,center-half,center+half) >= 1.0: continue
  for side: float in [float(enemy.flank_sign),-float(enemy.flank_sign)]:
   if absf(origin.z-center.z) >= half.z-0.02:
    var entry_side: float = 1.0 if origin.z >= center.z else -1.0
    var edge_x: float = center.x+side*(half.x+NAV_MARGIN)
    points = [Vector3(edge_x,0,origin.z),Vector3(edge_x,0,center.z-entry_side*(half.z+NAV_MARGIN))]
   else:
    var entry_side: float = 1.0 if origin.x >= center.x else -1.0
    var edge_z: float = center.z+side*(half.z+NAV_MARGIN)
    points = [Vector3(origin.x,0,edge_z),Vector3(center.x-entry_side*(half.x+NAV_MARGIN),0,edge_z)]
   if _nav_path_legal(sim,origin,points,enemy.radius):
    return _nav_accept(sim,enemy,origin,points,step_length,g01_output)
 # Overlapping walls / boundary-attached solids may invalidate both local routes.
 # This finite visibility graph has no grid, navmesh, engine service or RNG calls.
 var goal: Vector3 = Vector3(decoy.position)
 var offset: Vector3 = desired-origin
 if offset.dot(goal-origin) <= 0.0:
  # Preserve a retreat / strafe request instead of converting it into a chase.
  goal = origin+offset.normalized()*3.0
  var bound: float = maxf(0.0,sim.arena_half_extent-enemy.radius)
  goal = Vector3(clampf(goal.x,-bound,bound),0,clampf(goal.z,-bound,bound))
 points = _nav_corner_path(sim,origin,goal,enemy.radius,float(enemy.flank_sign))
 if not points.is_empty(): return _nav_accept(sim,enemy,origin,points,step_length,g01_output)
 # Original bounded tangent fallback; physical clipping remains the last word.
 for angle: float in [PI/3.0,-PI/3.0,PI/2.0,-PI/2.0,PI]:
  var candidate: Vector3 = origin+offset.rotated(Vector3.UP,angle*float(enemy.flank_sign))
  if _nav_leg_legal(sim,origin,candidate,enemy.radius): return _clip_motion(sim,origin,candidate,enemy.radius,g01_output)
 if g01_output is Dictionary: sim._equipment_q3_select_output(g01_output,g01_result)
 return result

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
