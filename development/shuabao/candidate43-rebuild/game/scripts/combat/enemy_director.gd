extends RefCounted
## Deterministic role-based enemy combat. The simulation owns HP, death, CC and clipping.
## Telegraphs are animation/weapon contracts, NEVER requests for generic ground decals.
const VERSION := "role-director-1"
const MAX_THREAT_WEIGHT := 3
const MIN_COMMIT_GAP := 0.24
const SPAWN_GRACE := 0.72
const ESCAPE_DISTANCE := 3.0
const ESCAPE_SECTORS := 16
const MIN_OPEN_SECTORS := 3
const HERO_RADIUS := 0.65
const EPS := 0.000001
# HP/damage stay near the original fixture; the difficulty comes from decisions and uptime.
#                     HP    hit def speed radius reach warning recovery weight
const PROFILES := {
 "minion": [120.0,16.0,0.0,3.8,0.46,1.75,0.46,0.68,1],
 "pouncer": [160.0,23.0,5.0,5.4,0.50,6.4,0.62,1.10,2],
 "armored": [240.0,25.0,10.0,3.45,0.64,2.0,0.65,1.10,1],
 "ranged": [125.0,18.0,0.0,3.7,0.45,11.5,0.68,1.08,1],
 "pitcher": [155.0,13.0,0.0,3.5,0.52,12.0,0.80,2.20,2],
 "support": [135.0,6.0,0.0,4.0,0.48,10.0,0.76,2.40,1],
 "elite": [650.0,65.0,22.0,3.3,0.90,3.25,0.90,1.45,2],
 "boss": [2200.0,85.0,38.0,2.7,1.25,3.8,1.02,1.55,2]
}
const ROLES := {"minion":"teaching_minion","pouncer":"fast_flanker","armored":"frontal_guard","ranged":"shooter","pitcher":"zone_pitcher","support":"debuff_support","elite":"heavy","boss":"boss"}
var commit_gap_left := 0.0
var encounter_generation := -1
var projectile_serial := 0
var time := 0.0
var last_open_sector_count := ESCAPE_SECTORS
var peak_threat_weight := 0
var commits := 0

func make_enemy(kind: String, at: Vector3, hp_override: float, wave: int, serial: int) -> Dictionary:
 if not PROFILES.has(kind): kind="minion"
 var p: Array=PROFILES[kind]
 var health: float=float(p[0])*(1.0+maxi(0,wave-1)*0.075) if hp_override<0 else hp_override
 var facing:=Vector3.FORWARD
 return {"actor_id":"enemy_%d"%serial,"kind":kind,"role":ROLES[kind],"rank_category":"boss" if kind=="boss" else ("elite" if kind=="elite" else "ordinary"),"position":at,"hp":health,"max_hp":health,"damage":float(p[1])*(1.0+maxi(0,wave-1)*0.055),"defence":p[2],"speed":p[3],"radius":p[4],"state":"spawn","timer":SPAWN_GRACE,"aim":facing,"facing":facing,"target_point":at,"committed_origin":at,"knockback":Vector3.ZERO,"stun_left":0.0,"slow_left":0.0,"slow_amount":0.0,"stagger":0.0,"attack_index":0,"warning_progress":0.0,"warning_duration":p[6],"attack_shape":"lane" if kind in ["pouncer","ranged","support"] else ("landing_material" if kind=="pitcher" else "cone"),"attack_range":p[5],"attack_width":1.25 if kind=="pouncer" else 0.32,"attack_angle":80.0 if kind in ["elite","boss"] else 90.0,"telegraph_style":"body_weapon","ground_warning":false,"threat_weight":int(p[8]),"threat_left":0.0,"dead":false,"push":{},"pull_state":{},"carried":false,"was_controlled":false,"guard_broken_left":0.0,"guard_pressure":0,"guard_flash_left":0.0,"guard_active":kind=="armored","flank_sign":1.0 if serial%2==0 else -1.0,"wait_age":0.0,"serial":serial,"taunted":false,"taunt_source":"","target_actor_id":"xuanlei"}

func make_wave_roster(number: int, count_override: int=-1) -> Array:
 var roster: Array=[]
 var count:=mini(56,8+maxi(0,number-1)*3) if count_override<0 else clampi(count_override,1,180)
 # The first room contains readable examples of every role; repetitions add partners.
 var kinds: Array=["minion","pouncer","armored","ranged","pitcher","support","elite","minion"]
 for i in range(count):
  var kind: String=kinds[i%kinds.size()]
  if number%5==0 and i==0: kind="boss"
  var angle:=TAU*float(i)/float(count)+number*0.37
  var radius:=12.0+float(i%3)
  roster.append({"kind":kind,"position":Vector3(cos(angle)*radius,0,sin(angle)*radius)})
 return roster

func begin_step(sim, dt: float) -> void:
 if _frozen(sim): return
 if encounter_generation!=sim.encounter_generation:
  encounter_generation=sim.encounter_generation
  commit_gap_left=0.0
  time=0.0
  peak_threat_weight=0
  commits=0
  sim.hero.cast_state.erase("exposed")
 _update_taunts(sim)
 time+=dt
 commit_gap_left=maxf(0.0,commit_gap_left-dt)
 if sim.hero.cast_state.has("exposed"):
  var exposed: Dictionary=sim.hero.cast_state.exposed
  exposed.left=maxf(0.0,float(exposed.left)-dt)
  if exposed.left<=0:
   sim.hero.cast_state.erase("exposed")
   sim.emit_event("hero_status_ended",{"status":"exposed"})

func _update_taunts(sim) -> void:
 var fortress: Dictionary=sim.hero.cast_state.get("r1",{})
 var radius:=float(fortress.get("taunt_radius",0.0))
 for enemy in sim.enemies:
  var active: bool=not enemy.dead and enemy.get("rank_category","ordinary")=="ordinary" and not fortress.is_empty() and enemy.position.distance_to(sim.hero.position)<=radius
  var previous: bool=enemy.get("taunted",false)
  enemy.taunted=active
  enemy.taunt_source=sim.hero.actor_id if active else ""
  # The current arena has a single attackable hero. Keep explicit target identity
  # for future ally acquisition, without snapping an already committed attack.
  enemy.target_actor_id=sim.hero.actor_id
  if active!=previous:
   sim.emit_event("enemy_taunt_started" if active else "enemy_taunt_ended",{"actor_id":enemy.actor_id,"enemy_kind":enemy.kind,"position":enemy.position,"source":sim.hero.actor_id,"radius":radius})

func incoming_damage_multiplier(sim) -> float:
 return 1.20 if sim.hero.cast_state.has("exposed") else 1.0

func guard_multiplier(enemy: Dictionary, source_position: Vector3, source: String, is_true: bool=false) -> float:
 if is_true or enemy.kind!="armored" or not enemy.get("guard_active",false) or enemy.get("guard_broken_left",0.0)>0: return 1.0
 var offset:=source_position-Vector3(enemy.position)
 if offset.length_squared()<0.001 or offset.normalized().dot(enemy.get("facing",enemy.aim))<0.65: return 1.0
 # Basic attacks always have a counterplay route: three frontal contacts open the guard.
 if source in ["attack","dash_attack"]:
  enemy.guard_pressure=int(enemy.get("guard_pressure",0))+1
  if enemy.guard_pressure>=3:
   enemy.guard_pressure=0
   enemy.guard_broken_left=2.1
   enemy.guard_active=false
   enemy.guard_flash_left=0.3
   return 1.0
 enemy.guard_flash_left=0.12
 return 0.45

func step_enemy(sim, enemy: Dictionary, dt: float) -> void:
 if _frozen(sim) or not sim.ai_enabled or enemy.dead: return
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
 enemy.timer=maxf(0.0,enemy.timer-dt)
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
   var lunge_speed: float=15.0*(1.0-enemy.slow_amount if enemy.slow_left>0 else 1.0)
   var g01_movement: Dictionary=sim._equipment_q3_movement_begin(enemy,"base_pounce")
   var g01_selected: Dictionary={}
   enemy.position=_clip_motion(sim,previous,previous+enemy.aim*lunge_speed*dt,enemy.radius,g01_selected if not g01_movement.is_empty() else null)
   sim._equipment_q3_movement_finish(g01_movement,g01_selected)
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

func _interrupt(sim, enemy: Dictionary) -> void:
 enemy.nav_points=[]
 enemy.nav_left=0.0
 if enemy.state in ["warning","pounce"]:
  sim.emit_event("enemy_attack_cancelled",{"actor_id":enemy.actor_id,"enemy_kind":enemy.kind,"position":enemy.position,"reason":"crowd_control"})
  enemy.state="recover"
  enemy.timer=0.22
  enemy.warning_progress=0.0
  enemy.threat_left=0.0
  enemy.did_hit=false
 if enemy.kind=="armored":
  enemy.guard_broken_left=maxf(enemy.guard_broken_left,0.85)
  enemy.guard_pressure=0

func _in_position(sim, enemy: Dictionary) -> bool:
 var distance: float=enemy.position.distance_to(sim.hero.position)
 if distance>float(PROFILES[enemy.kind][5]): return false
 if enemy.kind in ["ranged","pitcher","support"] and distance<3.3: return false
 if enemy.kind=="pouncer" and distance<2.2: return false
 return true

func _move_role(sim, enemy: Dictionary, dt: float) -> void:
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
 var speed: float=enemy.speed*(1.0-enemy.slow_amount if enemy.slow_left>0 else 1.0)
 var desired: Vector3=enemy.position+(motion*speed+separation)*dt
 # Collision with the hero is soft spacing; enemies cannot body-stack on the hero.
 if desired.distance_to(sim.hero.position)<enemy.radius+HERO_RADIUS+0.10:
  var away: Vector3=sim.hero.position.direction_to(desired)
  if away.length_squared()<EPS: away=Vector3.RIGHT*float(enemy.flank_sign)
  var perimeter: Vector3=sim.hero.position+away*(enemy.radius+HERO_RADIUS+0.10)
  desired=Vector3(enemy.position).move_toward(perimeter,(speed+separation.length())*dt)
 var g01_movement: Dictionary=sim._equipment_q3_movement_begin(enemy,"base_role")
 var g01_selected: Dictionary={}
 enemy.position=_navigate_step(sim,enemy,desired,dt,g01_selected if not g01_movement.is_empty() else null)
 sim._equipment_q3_movement_finish(g01_movement,g01_selected)
 # Guard turning is limited, so going around it actually works.
 var facing: Vector3=enemy.get("facing",toward)
 enemy.facing=_turn_facing(facing,toward,minf(1.0,dt*(2.7 if enemy.kind=="armored" else 8.0)))
 enemy.aim=enemy.facing

func _turn_facing(facing: Vector3, toward: Vector3, weight: float) -> Vector3:
 # Long cardinal-axis convergence can underflow the float32 squared cross length.
 # Preserve the original slerp unless its nonzero planar axis cannot normalize.
 var axis:=facing.cross(toward)
 var axis_squared:=axis.length_squared()
 if facing.y==0.0 and toward.y==0.0 and axis_squared>0.0 and axis_squared<1.1754943508222875e-38 and not axis.normalized().is_normalized():
  return facing.rotated(Vector3.UP,atan2(axis.y,facing.dot(toward))*weight).normalized()
 return facing.slerp(toward,weight).normalized()

func _frozen(sim) -> bool:
 return sim.paused or sim.phase!="combat" or sim.hero.dead

func _navigate_step(sim, enemy: Dictionary, desired: Vector3, dt: float, g01_output: Variant = null) -> Vector3:
 var origin: Vector3=enemy.position
 var step_length:=origin.distance_to(desired)
 enemy.nav_left=maxf(0.0,float(enemy.get("nav_left",0.0))-dt)
 if enemy.nav_left<=0: enemy.nav_points=[]
 var points: Array=enemy.get("nav_points",[])
 while not points.is_empty() and origin.distance_to(points[0])<=maxf(0.06,step_length): points.pop_front()
 if not points.is_empty():
  var waypoint: Vector3=origin.move_toward(points[0],step_length)
  return _clip_motion(sim,origin,waypoint,enemy.radius,g01_output)
 var g01_result: Variant={} if g01_output is Dictionary else null
 var result:=_clip_motion(sim,origin,desired,enemy.radius,g01_result)
 if result.distance_squared_to(desired)<0.00001:
  if g01_output is Dictionary: sim._equipment_q3_select_output(g01_output,g01_result)
  return result
 # Persist two local corner waypoints. Pure reactive tangent choices oscillate
 # at a pillar because the desired direction flips as an actor slides sideways.
 for obstacle in sim.obstacles:
  var half: Vector3=obstacle.half+Vector3(enemy.radius,0,enemy.radius)
  var center: Vector3=obstacle.position
  if _segment_box_entry(origin,desired,center-half,center+half)>=1.0: continue
  var side: float=enemy.flank_sign
  if absf(origin.z-center.z)>=half.z-0.02:
   var entry_side:=1.0 if origin.z>=center.z else -1.0
   var edge_x:=center.x+side*(half.x+0.22)
   points=[Vector3(edge_x,0,origin.z),Vector3(edge_x,0,center.z-entry_side*(half.z+0.22))]
  else:
   var entry_side:=1.0 if origin.x>=center.x else -1.0
   var edge_z:=center.z+side*(half.z+0.22)
   points=[Vector3(origin.x,0,edge_z),Vector3(center.x-entry_side*(half.x+0.22),0,edge_z)]
  enemy.nav_points=points
  enemy.nav_left=3.0
  return _clip_motion(sim,origin,origin.move_toward(points[0],step_length),enemy.radius,g01_output)
 # Arena edges have no obstacle object; bounded tangent choices avoid pinning
 # kiting ranged roles against the room edge.
 var offset:=desired-origin
 for angle in [PI/3.0,-PI/3.0,PI/2.0,-PI/2.0,PI]:
  var candidate:=origin+offset.rotated(Vector3.UP,float(angle)*float(enemy.flank_sign))
  var g01_candidate: Variant={} if g01_output is Dictionary else null
  var moved:=_clip_motion(sim,origin,candidate,enemy.radius,g01_candidate)
  if moved.distance_squared_to(candidate)<0.00001:
   if g01_output is Dictionary: sim._equipment_q3_select_output(g01_output,g01_candidate)
   return moved
 if g01_output is Dictionary: sim._equipment_q3_select_output(g01_output,g01_result)
 return result

func _clip_motion(sim, origin: Vector3, destination: Vector3, radius: float, g01_output: Variant = null) -> Vector3:
 var g01_probe: Dictionary=sim._equipment_q3_probe_begin(origin,destination,radius) if g01_output is Dictionary else {}
 var clipped: Vector3=sim._move_clipped(origin,destination,radius)
 var g01_static_exact: Variant=null
 # Exact swept AABB check closes the corner-grazing gap of fixed .2m samples,
 # especially important for fast bolts and slim obstacles.
 var fraction:=1.0
 for obstacle in sim.obstacles:
  var half: Vector3=obstacle.half+Vector3(radius,0,radius)
  fraction=minf(fraction,_segment_box_entry(origin,destination,Vector3(obstacle.position)-half,Vector3(obstacle.position)+half))
 if fraction<1.0:
  var exact:=origin.lerp(destination,maxf(0.0,fraction-0.0001))
  g01_static_exact=exact
  if exact.distance_squared_to(origin)<clipped.distance_squared_to(origin): clipped=exact
 if g01_output is Dictionary:
  sim._equipment_q3_probe_end(g01_probe,clipped,g01_static_exact)
  sim._equipment_q3_select_output(g01_output,{"token":g01_probe})
 return clipped

func _segment_box_entry(origin: Vector3, destination: Vector3, lower: Vector3, upper: Vector3) -> float:
 var delta:=destination-origin
 var enter:=0.0
 var leave:=1.0
 for axis in [0,2]:
  if absf(delta[axis])<EPS:
   if origin[axis]<=lower[axis] or origin[axis]>=upper[axis]: return 1.0
   continue
  var a: float=(lower[axis]-origin[axis])/delta[axis]
  var b: float=(upper[axis]-origin[axis])/delta[axis]
  enter=maxf(enter,minf(a,b))
  leave=minf(leave,maxf(a,b))
  if enter>leave: return 1.0
 # Touching a face while moving away or along it does not stick the actor.
 if leave<=EPS or enter>=1.0: return 1.0
 return enter

func _closest_guard(sim, enemy: Dictionary) -> Dictionary:
 var best: Dictionary={}
 var distance:=8.0
 for other in sim._nearby(enemy.position,12,enemy.actor_id):
  if other.dead or other.kind!="armored": continue
  var d: float=other.position.distance_to(enemy.position)
  if d<distance:
   best=other
   distance=d
 return best

func active_threat_weight(sim) -> int:
 var total:=0
 for enemy in sim.enemies:
  if not enemy.dead and float(enemy.get("threat_left",0.0))>EPS: total+=int(enemy.get("threat_weight",1))
 # Handoff is explicit: release clears the actor's token, then the projectile
 # owns it; landing replaces that projectile with a zone. Never deduplicate by
 # actor ID: a previous zone may still exist while its owner starts a NEW attack.
 for projectile in sim.projectiles:
  if projectile.get("team","")=="enemy": total+=int(projectile.get("threat_weight",1))
 for zone in sim.zones:
  if zone.get("team","")=="enemy": total+=int(zone.get("threat_weight",1))
 return total

func _can_commit(sim, enemy: Dictionary) -> bool:
 if commit_gap_left>EPS or active_threat_weight(sim)+int(enemy.threat_weight)>MAX_THREAT_WEIGHT: return false
 # Give an older ready actor priority; array order cannot starve the backline.
 for other in sim.enemies:
  if other==enemy or other.dead or other.state!="chase" or other.timer>EPS or other.stun_left>0 or other.carried or not other.push.is_empty() or not other.pull_state.is_empty(): continue
  if other.wait_age>enemy.wait_age+0.6 and _in_position(sim,other) and active_threat_weight(sim)+int(other.threat_weight)<=MAX_THREAT_WEIGHT:
   if escape_sector_count(sim,_candidate(sim,other))>=MIN_OPEN_SECTORS: return false
 return escape_sector_count(sim,_candidate(sim,enemy))>=MIN_OPEN_SECTORS

func _candidate(sim, enemy: Dictionary) -> Dictionary:
 var direction: Vector3=enemy.position.direction_to(sim.hero.position)
 if direction.length_squared()<0.001: direction=enemy.get("facing",Vector3.FORWARD)
 return {"kind":enemy.kind,"origin":enemy.position,"direction":direction,"target":sim.hero.position,"radius":1.45 if enemy.kind=="pitcher" else float(PROFILES[enemy.kind][5]),"width":1.25 if enemy.kind=="pouncer" else 0.32,"angle":enemy.attack_angle,"owner":enemy.actor_id}

func _commit(sim, enemy: Dictionary) -> void:
 enemy.state="warning"
 enemy.timer=float(PROFILES[enemy.kind][6])
 enemy.warning_duration=enemy.timer
 enemy.warning_progress=0.0
 enemy.aim=enemy.position.direction_to(sim.hero.position)
 if enemy.aim.length_squared()<0.001: enemy.aim=Vector3.FORWARD
 enemy.facing=enemy.aim
 enemy.committed_origin=enemy.position
 enemy.target_point=sim.hero.position
 enemy.wait_age=0.0
 var active_duration:=0.40 if enemy.kind=="pouncer" else 0.10
 enemy.threat_left=enemy.timer+active_duration
 commit_gap_left=MIN_COMMIT_GAP
 commits+=1
 peak_threat_weight=maxi(peak_threat_weight,active_threat_weight(sim))
 sim.emit_event("enemy_warning",{"actor_id":enemy.actor_id,"position":enemy.position,"target_point":enemy.target_point,"direction":enemy.aim,"shape":enemy.attack_shape,"duration":enemy.timer,"radius":enemy.attack_range,"width":enemy.attack_width,"angle":enemy.attack_angle,"enemy_kind":enemy.kind,"role":enemy.role,"telegraph_style":"body_weapon","ground_warning":false,"committed":true})

func _release(sim, enemy: Dictionary) -> void:
 if enemy.kind in ["ranged","support","pitcher"]:
  _shoot(sim,enemy)
  _recover(enemy)
 elif enemy.kind=="pouncer":
  enemy.state="pounce"
  enemy.timer=0.40
  enemy.did_hit=false
  sim.emit_event("enemy_pounce_started",{"actor_id":enemy.actor_id,"position":enemy.position,"direction":enemy.aim,"duration":0.40,"speed":15.0,"enemy_kind":enemy.kind,"shape":"capsule","radius":enemy.radius+HERO_RADIUS})
 else:
  var offset: Vector3=sim.hero.position-enemy.position
  var reach: float=enemy.attack_range
  var hit: bool=offset.length()<=reach+HERO_RADIUS and (offset.length()<EPS or offset.normalized().dot(enemy.aim)>=cos(deg_to_rad(enemy.attack_angle*0.5)))
  if hit: sim.damage_hero(enemy.damage,enemy.aim,0.20 if enemy.kind in ["elite","boss"] else 0.06)
  _impact(sim,enemy,hit)
  _recover(enemy)
 enemy.attack_index+=1

func _recover(enemy: Dictionary) -> void:
 enemy.state="recover"
 enemy.timer=float(PROFILES[enemy.kind][7])
 enemy.guard_active=false
 enemy.threat_left=0.0

func _impact(sim, enemy: Dictionary, hit: bool) -> void:
 sim.emit_event("enemy_impact",{"actor_id":enemy.actor_id,"position":enemy.position,"hit":hit,"direction":enemy.aim,"radius":enemy.attack_range,"width":enemy.attack_width,"angle":enemy.attack_angle,"shape":enemy.attack_shape,"enemy_kind":enemy.kind,"role":enemy.role})

func _shoot(sim, enemy: Dictionary) -> void:
 projectile_serial+=1
 var type: String="lob" if enemy.kind=="pitcher" else ("hex_bolt" if enemy.kind=="support" else "bolt")
 var origin: Vector3=enemy.position+enemy.aim*(enemy.radius+0.18)
 var duration:=0.82 if type=="lob" else 1.7
 var projectile: Dictionary={"id":"enemy_projectile_%d"%projectile_serial,"position":origin,"origin":origin,"direction":enemy.aim,"speed":11.5 if type=="bolt" else 8.5,"left":duration,"duration":duration,"damage":enemy.damage,"owner":enemy.actor_id,"team":"enemy","type":type,"role":enemy.role,"radius":0.17 if type=="hex_bolt" else 0.14,"height":0.0,"target_point":enemy.target_point,"threat_weight":enemy.threat_weight}
 sim.projectiles.append(projectile)
 sim.emit_event("enemy_shot",{"actor_id":enemy.actor_id,"position":origin,"direction":enemy.aim,"target_point":enemy.target_point,"enemy_kind":enemy.kind,"projectile_type":type,"duration":duration})

func step_projectiles(sim, dt: float) -> void:
 if _frozen(sim): return
 for projectile in sim.projectiles.duplicate():
  # Legacy/friendly projectile contracts can be handled by their own owner.
  if projectile.get("team","enemy")!="enemy": continue
  var travel_dt:=minf(dt,maxf(0.0,float(projectile.left)))
  projectile.left-=dt
  if projectile.get("type","bolt")=="lob":
   var progress:=clampf(1.0-projectile.left/projectile.duration,0,1)
   projectile.position=Vector3(projectile.origin).lerp(projectile.target_point,progress)
   projectile.height=sin(progress*PI)*3.2
   if projectile.left<=EPS:
    _land_zone(sim,projectile)
    sim.projectiles.erase(projectile)
   continue
  var previous: Vector3=projectile.position
  var next: Vector3=previous+projectile.direction*projectile.speed*travel_dt
  var clipped: Vector3=_clip_motion(sim,previous,next,projectile.get("radius",0.14))
  if _segment_distance(sim.hero.position,previous,clipped)<=HERO_RADIUS+float(projectile.get("radius",0.14)):
   var immune: bool=sim.hero_damage_immune() if sim.has_method("hero_damage_immune") else (sim.hero.dead or sim.hero.invulnerable_left>0 or sim.hero.dash_left>EPS or sim.dash_step_immune or sim.r1_active)
   var control_immune: bool=sim.hero_control_immune() if sim.has_method("hero_control_immune") else immune
   if not immune and not control_immune and projectile.get("type","")=="hex_bolt":
    sim.hero.cast_state.exposed={"left":2.4,"duration":2.4,"multiplier":1.20,"source":projectile.owner,"label":"易伤 +20%"}
    sim.emit_event("hero_status_applied",{"status":"exposed","duration":2.4,"multiplier":1.20,"source":projectile.owner,"position":sim.hero.position})
   sim.damage_hero(projectile.damage,projectile.direction,0)
   sim.projectiles.erase(projectile)
   sim.emit_event("projectile_hit",{"position":sim.hero.position,"type":projectile.get("type","bolt"),"dodged":immune})
  elif clipped.distance_squared_to(next)>0.00001 or projectile.left<=EPS: sim.projectiles.erase(projectile)
  else: projectile.position=next

func _land_zone(sim, projectile: Dictionary) -> void:
 var point: Vector3=projectile.target_point
 # Exact physical boundary is supplied to presentation, with no larger fake danger ring.
 var zone: Dictionary={"team":"enemy","owner":projectile.owner,"position":point,"radius":1.45,"shape":"disc","material":"corrosive_ink","left":2.4,"duration":2.4,"damage":projectile.damage,"tick_left":0.16,"tick_interval":0.60,"threat_weight":1,"armed_after":0.16,"boundary_matches_damage":true}
 sim.zones.append(zone)
 sim.emit_event("enemy_zone_landed",{"position":point,"radius":zone.radius,"duration":zone.left,"material":zone.material,"owner":zone.owner,"shape":"disc","team":"enemy"})

func step_hostile_zones(sim, dt: float) -> void:
 if _frozen(sim): return
 for zone in sim.zones.duplicate():
  if zone.get("team","")!="enemy": continue
  zone.left-=dt
  zone.tick_left-=dt
  if zone.tick_left<=EPS:
   zone.tick_left+=zone.tick_interval
   # Center-in-material test: the rendered disc is the exact damaging boundary.
   if sim.hero.position.distance_to(zone.position)<=zone.radius:
    sim.damage_hero(zone.damage,Vector3.ZERO,0)
    sim.emit_event("enemy_zone_tick",{"position":zone.position,"owner":zone.owner,"radius":zone.radius})
  if zone.left<=EPS: sim.zones.erase(zone)

func escape_sector_count(sim, candidate: Dictionary={}) -> int:
 var hazards: Array=[]
 for enemy in sim.enemies:
  if enemy.dead or enemy.state not in ["warning","pounce"]: continue
  hazards.append({"kind":enemy.kind,"origin":enemy.get("committed_origin",enemy.position),"direction":enemy.aim,"target":enemy.target_point,"radius":1.45 if enemy.kind=="pitcher" else enemy.attack_range,"width":enemy.attack_width,"angle":enemy.attack_angle})
 for projectile in sim.projectiles:
  if projectile.get("team","")!="enemy": continue
  hazards.append({"kind":"pitcher" if projectile.type=="lob" else "ranged","origin":projectile.position,"direction":projectile.direction,"target":projectile.get("target_point",projectile.position),"radius":1.45 if projectile.type=="lob" else 12.0,"width":0.4,"angle":0.0})
 for zone in sim.zones:
  if zone.get("team","")=="enemy": hazards.append({"kind":"pitcher","target":zone.position,"radius":zone.radius})
 if not candidate.is_empty(): hazards.append(candidate)
 var available: Array[bool]=[]
 for i in range(ESCAPE_SECTORS):
  var direction:=Vector3(cos(TAU*float(i)/ESCAPE_SECTORS),0,sin(TAU*float(i)/ESCAPE_SECTORS))
  var destination: Vector3=sim.hero.position+direction*ESCAPE_DISTANCE
  var safe: bool=sim._move_clipped(sim.hero.position,destination,HERO_RADIUS).distance_squared_to(destination)<0.001
  # Evaluate after the reaction interval: threats aim at the start, so t=0 cannot be safe.
  for fraction in [0.65,1.0]:
   if not safe: break
   var point: Vector3=sim.hero.position+direction*ESCAPE_DISTANCE*fraction
   for hazard in hazards:
    if _hazard_contains(hazard,point):
     safe=false
     break
  available.append(safe)
 var longest:=0
 var run:=0
 for i in range(ESCAPE_SECTORS*2):
  run=run+1 if available[i%ESCAPE_SECTORS] else 0
  longest=maxi(longest,mini(run,ESCAPE_SECTORS))
 last_open_sector_count=longest
 return longest

func _hazard_contains(hazard: Dictionary, point: Vector3) -> bool:
 if hazard.kind=="pitcher": return point.distance_to(hazard.target)<=float(hazard.radius)+0.20
 var offset: Vector3=point-Vector3(hazard.origin)
 var direction: Vector3=hazard.direction
 if hazard.kind in ["pouncer","ranged","support"]:
  var length: float=6.0 if hazard.kind=="pouncer" else 15.0
  var along:=offset.dot(direction)
  var lateral:=absf(offset.dot(Vector3(-direction.z,0,direction.x)))
  return along>=-0.25 and along<=length+0.5 and lateral<=float(hazard.width)*0.5+HERO_RADIUS+0.10
 return offset.length()<=float(hazard.radius)+HERO_RADIUS+0.12 and offset.normalized().dot(direction)>=cos(deg_to_rad(float(hazard.angle)*0.5+8.0))

func _segment_distance(point: Vector3, start: Vector3, finish: Vector3) -> float:
 var delta:=finish-start
 var fraction:=clampf((point-start).dot(delta)/maxf(EPS,delta.length_squared()),0,1)
 return point.distance_to(start+delta*fraction)

func debug_snapshot(sim) -> Dictionary:
 return {"version":VERSION,"active_threat_weight":active_threat_weight(sim),"max_threat_weight":MAX_THREAT_WEIGHT,"peak_threat_weight":peak_threat_weight,"commit_gap_left":commit_gap_left,"commits":commits,"open_escape_sectors":last_open_sector_count}
