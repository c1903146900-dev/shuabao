extends RefCounted
## 裂庭守卫: isolated source component, never an alternative Sim or encounter owner.
## All dt is admitted by the inherited Sim. World dt is NOT wall/real time.
const Geometry = preload("res://tests/ink_first_floor_boss_20261008/source01/geometry.gd")
const EPS := 0.000001
const HERO_RADIUS := 0.65
const WARNING := {"A":1.1,"B":1.35,"C":1.5}
const RECOVERY := {"A":1.6,"B":1.7,"C":2.0}
const DAMAGE := {"A":1.0,"B":0.75,"C":0.55}
const PHASE_DURATION := 1.6
const ROCK_GAP := 0.65
const FRONT_SPEED := 10.0
var serial: int = 0
var receipts: Array = []

func _run_id(sim) -> String:
 # Read the already bound real progression owner, never create a run identity.
 if sim.progression==null: return ""
 var model=sim.progression.get("model")
 return "" if model==null else str(model.get("_run_id"))

func _runtime(sim, enemy: Dictionary) -> Dictionary:
 if not enemy.has("boss_runtime"):
  enemy.boss_runtime={"phase":1,"pending_phase":false,"transition_done":false,"cast":{},"serial":0,"last_move":"","generation":sim.encounter_generation,"room_id":sim.room_id,"hero_instance_id":sim.hero.get_instance_id(),"run_id":_run_id(sim),"source_instance_id":sim.get_instance_id()}
 return enemy.boss_runtime

func _current(sim, enemy: Dictionary, runtime: Dictionary) -> bool:
 return str(runtime.run_id)==_run_id(sim) and int(runtime.source_instance_id)==sim.get_instance_id() and sim.phase=="combat" and not sim.hero.dead and not enemy.dead and sim.hero.get_instance_id()==int(runtime.hero_instance_id) and int(runtime.generation)==sim.encounter_generation and str(runtime.room_id)==sim.room_id and is_same(enemy,sim.enemy_by_id(str(enemy.actor_id)))

func snapshot(sim, enemy: Dictionary) -> Dictionary:
 var runtime: Dictionary=_runtime(sim,enemy)
 var out: Dictionary={}
 for key: String in ["phase","pending_phase","transition_done","cast","serial","last_move","generation","room_id","run_id","source_instance_id"]: out[key]=runtime[key]
 out=out.duplicate(true)
 out.merge({"state":enemy.state,"timer":enemy.timer,"current":_current(sim,enemy,runtime)},true)
 return out

func prune(_director, sim) -> void:
 for enemy: Dictionary in sim.enemies:
  if enemy.kind=="boss" and enemy.has("boss_runtime") and not _current(sim,enemy,enemy.boss_runtime): cancel(sim,enemy,"owner_or_scope_invalid")

func cancel(sim, enemy: Dictionary, reason: String) -> void:
 if not enemy.has("boss_runtime"): return
 var runtime: Dictionary=enemy.boss_runtime
 var cast: Dictionary=runtime.cast
 if cast.is_empty(): return
 runtime.cast={}
 enemy.threat_left=0.0
 enemy.warning_progress=0.0
 # Retire before emission: an event listener cannot release this old cast again.
 _event(sim,enemy,cast,"boss_cast_cancelled",{"reason":reason})
 sim.emit_event("enemy_attack_cancelled",{"actor_id":enemy.actor_id,"enemy_kind":"boss","boss_cast_id":cast.boss_cast_id,"position":enemy.position,"reason":reason})

func step(director, sim, enemy: Dictionary, dt: float) -> void:
 var runtime: Dictionary=_runtime(sim,enemy)
 if not _current(sim,enemy,runtime):
  cancel(sim,enemy,"owner_or_scope_invalid")
  return
 if sim.paused or not sim.ai_enabled or dt<=0.0: return
 if not runtime.transition_done and float(enemy.hp)<=float(enemy.max_hp)*0.5: runtime.pending_phase=true
 var controlled: bool=enemy.carried or not enemy.push.is_empty() or not enemy.pull_state.is_empty() or float(enemy.stun_left)>0.0
 for key: String in ["stun_left","slow_left","guard_broken_left","guard_flash_left"]: enemy[key]=maxf(0.0,float(enemy.get(key,0.0))-dt)
 enemy.guard_active=false
 if controlled and not enemy.get("was_controlled",false) and enemy.state=="warning":
  cancel(sim,enemy,"crowd_control")
  enemy.state="recover"; enemy.timer=0.22
 enemy.was_controlled=controlled
 # Already detached fronts/stones use the same rule as existing projectiles:
 # owner CC does not undo their release. Owner death/room invalidation still does.
 if controlled and enemy.state not in ["boss_active","boss_transition"]: return
 var rate: float=float(sim.r1_step_enemy_rates(enemy,dt).get("attack_rate",1.0))
 var remaining: float=dt
 var offset: float=0.0
 for _part in range(5):
  if remaining<=EPS or not _current(sim,enemy,runtime) or sim.paused: return
  match str(enemy.state):
   "spawn":
    enemy.timer=maxf(0.0,float(enemy.timer)-remaining)
    enemy.warning_progress=1.0-float(enemy.timer)/director.SPAWN_GRACE
    if enemy.timer<=EPS:
     enemy.state="chase"; enemy.timer=0.10+float(int(enemy.serial)%5)*0.055; enemy.warning_progress=0.0
    return
   "chase":
    if runtime.pending_phase:
     _begin_phase(sim,enemy,runtime)
     continue
    enemy.timer=maxf(0.0,float(enemy.timer)-remaining*rate)
    enemy.wait_age+=remaining
    if enemy.timer<=EPS and Vector3(enemy.position).distance_to(sim.hero.position)<=10.0:
     var move: String=_choose(enemy,runtime,sim.hero.position)
     var result: Dictionary=_commit(director,sim,enemy,move)
     if result.accepted: return
    director._move_role(sim,enemy,remaining)
    return
   "warning":
    var due: float=float(enemy.timer)/maxf(EPS,rate)
    var used: float=minf(remaining,due)
    enemy.timer=maxf(0.0,float(enemy.timer)-used*rate)
    enemy.warning_progress=clampf(1.0-float(enemy.timer)/float(enemy.warning_duration),0.0,1.0)
    enemy.threat_left=float(enemy.timer)+1.0
    offset+=used; remaining-=used
    if enemy.timer>EPS: return
    _release(director,sim,enemy,runtime,offset)
   "boss_active":
    var used: float=_advance_active(director,sim,enemy,runtime,remaining,offset,dt)
    remaining-=used; offset+=used
    if enemy.state=="boss_active" or controlled: return
   "recover":
    var due: float=float(enemy.timer)/maxf(EPS,rate)
    var used: float=minf(remaining,due)
    enemy.timer=maxf(0.0,float(enemy.timer)-used*rate)
    remaining-=used; offset+=used
    if enemy.timer>EPS: return
    if runtime.pending_phase: _begin_phase(sim,enemy,runtime)
    else:
     enemy.state="chase"; enemy.warning_progress=0.0; enemy.wait_age=0.0
     return # no new warning in the same tick as recovery completion
   "boss_transition":
    var used: float=minf(remaining,float(enemy.timer))
    enemy.timer=maxf(0.0,float(enemy.timer)-used)
    remaining-=used; offset+=used
    if enemy.timer>EPS: return
    enemy.state="chase"; enemy.warning_progress=0.0; enemy.wait_age=0.0
    sim.emit_event("boss_phase_finished",{"actor_id":enemy.actor_id,"phase":2,"generation":runtime.generation,"room_id":runtime.room_id,"duration":PHASE_DURATION,"source_time":sim.hero_time})
    return
   _:
    return

func _choose(enemy: Dictionary, runtime: Dictionary, point: Vector3) -> String:
 # C is interleaved after two attacks; ranged B/C never occur consecutively.
 # If distant after B/C, pursuit creates a real near-A opening instead of
 # stationary empty swings or repeating ranged area denial.
 if runtime.last_move in ["B","C"]: return "A"
 if int(runtime.serial)%3==2 and runtime.last_move!="C": return "C"
 return "A" if Vector3(enemy.position).distance_to(point)<=3.8 else "B"

func commit_for_test(sim, enemy: Dictionary, move: String) -> Dictionary:
 # Explicit deterministic selector only. It uses the exact normal validation,
 # geometry, event, state, damage and real-clock path. It writes no wallet/HP.
 return _commit(sim.enemy_director,sim,enemy,move)

func _commit(director, sim, enemy: Dictionary, move: String) -> Dictionary:
 var runtime: Dictionary=_runtime(sim,enemy)
 if move not in ["A","B","C"]: return {"accepted":false,"reason":"unknown_move"}
 if not _current(sim,enemy,runtime) or sim.paused or not sim.ai_enabled: return {"accepted":false,"reason":"inactive_scope"}
 if enemy.state!="chase" or float(enemy.timer)>EPS or not runtime.cast.is_empty() or runtime.pending_phase or (not runtime.transition_done and float(enemy.hp)<=float(enemy.max_hp)*0.5): return {"accepted":false,"reason":"not_ready"}
 if enemy.carried or not enemy.push.is_empty() or not enemy.pull_state.is_empty() or float(enemy.stun_left)>0.0: return {"accepted":false,"reason":"controlled"}
 var distance: float=Vector3(enemy.position).distance_to(sim.hero.position)
 if distance>(3.8 if move=="A" else 10.0): return {"accepted":false,"reason":"out_of_reach"}
 if director.commit_gap_left>EPS or director.active_threat_weight(sim)+int(enemy.threat_weight)>director.MAX_THREAT_WEIGHT: return {"accepted":false,"reason":"threat_budget"}
 var direction: Vector3=Vector3(enemy.position).direction_to(sim.hero.position)
 if direction.length_squared()<EPS: direction=Vector3.FORWARD
 var geometry: Dictionary=_shape(director,sim,enemy,move,direction,int(runtime.phase))
 var escape: Dictionary=_escape(director,sim,enemy,geometry,float(WARNING[move]))
 if escape.is_empty() and move=="B" and geometry.lines.size()==2:
  geometry=_shape(director,sim,enemy,move,direction,1)
  escape=_escape(director,sim,enemy,geometry,float(WARNING[move]))
 if escape.is_empty() and move=="C" and geometry.points.size()>1:
  geometry.points.resize(1)
  escape=_escape(director,sim,enemy,geometry,float(WARNING[move]))
 if escape.is_empty(): return {"accepted":false,"reason":"no_walkable_escape"}
 serial+=1; runtime.serial+=1
 var cast: Dictionary={"boss_cast_id":"%d:%d:%s:%s:boss:%d"%[sim.get_instance_id(),sim.encounter_generation,sim.room_id,enemy.actor_id,serial],"move":move,"origin":enemy.position,"direction":direction,"target_point":sim.hero.position,"target_actor_id":sim.hero.actor_id,"generation":sim.encounter_generation,"room_id":sim.room_id,"phase":runtime.phase,"run_id":runtime.run_id,"source_instance_id":runtime.source_instance_id,"geometry":geometry,"elapsed":0.0,"hits":{},"fronts":[],"rocks_done":0,"released":false,"damage":float(enemy.damage)*float(DAMAGE[move]),"escape":escape}
 runtime.cast=cast; runtime.last_move=move
 enemy.state="warning"; enemy.timer=float(WARNING[move]); enemy.warning_duration=enemy.timer; enemy.warning_progress=0.0
 enemy.aim=direction; enemy.facing=direction; enemy.committed_origin=enemy.position; enemy.target_point=sim.hero.position; enemy.target_actor_id=sim.hero.actor_id; enemy.wait_age=0.0
 enemy.attack_shape=geometry.shape; enemy.attack_range=3.8 if move=="A" else (10.0 if move=="B" else 1.5); enemy.attack_angle=80.0 if move=="A" else 0.0; enemy.attack_width=1.6 if move=="B" else 0.0
 enemy.threat_left=enemy.timer+1.0
 director.commit_gap_left=director.MIN_COMMIT_GAP; director.commits+=1
 director.peak_threat_weight=maxi(director.peak_threat_weight,director.active_threat_weight(sim))
 _event(sim,enemy,cast,"enemy_warning",{"duration":enemy.timer,"shape":geometry.shape,"radius":enemy.attack_range,"width":enemy.attack_width,"angle":enemy.attack_angle,"telegraph_style":"boss_body_and_exact_material","ground_warning":move=="C","committed":true,"escape":escape})
 return {"accepted":true,"reason":"","boss_cast_id":cast.boss_cast_id,"cast":cast.duplicate(true)}

func _shape(director, sim, enemy: Dictionary, move: String, direction: Vector3, phase: int) -> Dictionary:
 var shape: Dictionary={"shape":"cone" if move=="A" else ("fronts" if move=="B" else "discs"),"origin":enemy.position,"direction":direction,"radius":3.8 if move=="A" else 1.5,"angle":80.0 if move=="A" else 0.0,"length":10.0,"width":1.6,"lines":[],"points":[]}
 if move=="B":
  for angle: float in ([-18.0,18.0] if phase==2 else [0.0]):
   var heading: Vector3=direction.rotated(Vector3.UP,deg_to_rad(angle))
   var end: Vector3=director._clip_motion(sim,enemy.position,Vector3(enemy.position)+heading*10.0,0.8)
   shape.lines.append({"origin":enemy.position,"direction":heading,"length":Vector3(enemy.position).distance_to(end)})
 elif move=="C":
  shape.points.append(sim.hero.position)
  var side: Vector3=Vector3(-direction.z,0.0,direction.x)
  for sign_value: float in [1.0,-1.0]:
   var point: Vector3=sim.hero.position+side*4.0*sign_value
   # Never clamp two stones into an overlap/corridor. Drop the second instead.
   if director._nav_point_legal(sim,point,1.5) and point.distance_to(shape.points[0])>=3.8:
    shape.points.append(point)
    break
 return shape

func _escape(director, sim, enemy: Dictionary, geometry: Dictionary, warning: float) -> Dictionary:
 # Conservative walk certificate: 0.2s response, real hero speed, one straight
 # collision-checked route then stand outside the ENTIRE locked attack shape.
 # This is admission safety, not a substitute for real input/playtest acceptance.
 var travel: float=minf(3.0,maxf(0.0,sim.hero.speed())*maxf(0.0,warning-0.2))
 var origin: Vector3=sim.hero.position
 for index in range(32):
  var direction: Vector3=Vector3(cos(TAU*float(index)/32.0),0.0,sin(TAU*float(index)/32.0))
  var finish: Vector3=origin+direction*travel
  if Geometry.segment_distance(enemy.position,origin,finish)<float(enemy.radius)+HERO_RADIUS+0.02: continue
  if not director._nav_leg_legal(sim,origin,finish,HERO_RADIUS): continue
  if Geometry.contains(geometry,finish,HERO_RADIUS+0.10): continue
  return {"origin":origin,"destination":finish,"direction":direction,"walk_distance":travel,"response_seconds":0.2,"walk_speed":sim.hero.speed(),"minimum_warning_world_seconds":warning,"stationary_after_arrival":true}
 return {}

func _release(_director, sim, enemy: Dictionary, runtime: Dictionary, offset: float) -> void:
 var cast: Dictionary=runtime.cast
 if cast.is_empty() or cast.released: return
 cast.released=true; cast.elapsed=0.0; enemy.attack_index+=1
 enemy.state="boss_active"; enemy.timer=0.0; enemy.warning_progress=1.0
 _event(sim,enemy,cast,"boss_attack_released",{})
 if not _valid_cast(sim,enemy,runtime,cast): return
 match str(cast.move):
  "A":
   if Geometry.cone_contains(cast.geometry,sim.hero.position): _hit(sim,enemy,runtime,cast,"sweep",offset)
   if _valid_cast(sim,enemy,runtime,cast): _finish(sim,enemy,runtime,cast)
  "B":
   for line: Dictionary in cast.geometry.lines: cast.fronts.append({"line":line.duplicate(true),"distance":0.0,"stopped":float(line.length)<=EPS})
  "C":
   _rock(sim,enemy,runtime,cast,0,offset)
   if _valid_cast(sim,enemy,runtime,cast) and cast.geometry.points.size()==1: _finish(sim,enemy,runtime,cast)

func _advance_active(director, sim, enemy: Dictionary, runtime: Dictionary, dt: float, offset: float, tick_dt: float) -> float:
 var cast: Dictionary=runtime.cast
 if cast.is_empty(): return dt
 if cast.move=="C":
  var used: float=minf(dt,maxf(0.0,ROCK_GAP-float(cast.elapsed)))
  cast.elapsed+=used
  if float(cast.elapsed)>=ROCK_GAP-EPS:
   _rock(sim,enemy,runtime,cast,1,offset+used)
   if _valid_cast(sim,enemy,runtime,cast): _finish(sim,enemy,runtime,cast)
  return used
 var duration_left: float=0.0
 for front: Dictionary in cast.fronts:
  if not front.stopped: duration_left=maxf(duration_left,(float(front.line.length)-float(front.distance))/FRONT_SPEED)
 var used: float=minf(dt,duration_left)
 var any_live: bool=false
 for index in range(cast.fronts.size()):
  var front: Dictionary=cast.fronts[index]
  if front.stopped: continue
  var line: Dictionary=front.line
  var previous: float=float(front.distance)
  var next: float=minf(float(line.length),previous+FRONT_SPEED*used)
  var a: Vector3=Vector3(line.origin)+Vector3(line.direction)*previous
  var b: Vector3=Vector3(line.origin)+Vector3(line.direction)*next
  var clipped: Dictionary=_front_clip(director,sim,a,b,offset,(next-previous)/FRONT_SPEED,tick_dt)
  var finish: float=previous+a.distance_to(clipped.position)
  front.distance=finish
  front.stopped=bool(clipped.blocked) or finish>=float(line.length)-EPS
  any_live=any_live or not front.stopped
  if Geometry.front_contains(line,previous,finish,sim.hero.position,float(cast.geometry.width)):
   # First contact against the physical swept front, not the full warning lane.
   var local: float=_front_entry(line,previous,finish,sim.hero.position,float(cast.geometry.width))
   _hit(sim,enemy,runtime,cast,"front",offset+maxf(0.0,local-previous)/FRONT_SPEED)
  if not _valid_cast(sim,enemy,runtime,cast): return used
  _event(sim,enemy,cast,"boss_front_advanced",{"line_index":index,"previous_distance":previous,"distance":finish,"position":clipped.position,"stopped":front.stopped,"blocked_by":clipped.blocked_by,"speed":FRONT_SPEED,"width":cast.geometry.width})
  if not _valid_cast(sim,enemy,runtime,cast): return used
 cast.elapsed+=used
 if not any_live: _finish(sim,enemy,runtime,cast)
 return used

func _front_entry(line: Dictionary, start: float, finish: float, point: Vector3, width: float) -> float:
 var relative: Vector3=point-Vector3(line.origin)
 var along: float=relative.dot(line.direction)
 var lateral: float=absf(relative.dot(Vector3(-Vector3(line.direction).z,0.0,Vector3(line.direction).x)))
 var excess: float=maxf(0.0,lateral-width*0.5)
 var expansion: float=sqrt(maxf(0.0,HERO_RADIUS*HERO_RADIUS-excess*excess))
 return clampf(along-expansion,start,finish)

func _front_clip(director, sim, a: Vector3, b: Vector3, offset: float, travel_dt: float, tick_dt: float) -> Dictionary:
 # Match inherited exact static AABB/arena clipping, then explicitly include Q3.
 # Boss body itself retains the original Q3 control exception; released attack
 # is terrain-blockable like hostile projectiles and supplies no actor exemption.
 var result: Vector3=director._clip_motion(sim,a,b,0.8)
 var reason: String="static" if result.distance_squared_to(b)>0.00001 else ""
 var terrain: Dictionary=sim._q3_terrain_contact(a,b,0.8,{},travel_dt/maxf(EPS,tick_dt))
 if not terrain.is_empty() and not sim.ink_mountain.is_empty():
  var actual_contact: float=sim.hero_time-tick_dt+offset+float(terrain.fraction)*travel_dt
  if actual_contact>=float(sim.ink_mountain.expires_at)-EPS: terrain={}
 if not terrain.is_empty() and a.distance_squared_to(terrain.position)<=a.distance_squared_to(result)+EPS:
  result=a.lerp(b,maxf(0.0,float(terrain.fraction)-0.00001)); reason=str(terrain.terrain_id)
 return {"position":result,"blocked":not reason.is_empty(),"blocked_by":reason}

func _rock(sim, enemy: Dictionary, runtime: Dictionary, cast: Dictionary, index: int, offset: float) -> void:
 if index>=cast.geometry.points.size() or int(cast.rocks_done)>index: return
 cast.rocks_done=index+1
 var point: Vector3=cast.geometry.points[index]
 if sim.hero.position.distance_to(point)<=float(cast.geometry.radius)+HERO_RADIUS: _hit(sim,enemy,runtime,cast,"rock:%d"%index,offset)
 if _valid_cast(sim,enemy,runtime,cast): _event(sim,enemy,cast,"boss_rock_landed",{"segment_id":"rock:%d"%index,"position":point,"radius":cast.geometry.radius,"stone_index":index,"damage_pool":false,"control":0.0})

func _hit(sim, enemy: Dictionary, runtime: Dictionary, cast: Dictionary, segment: String, offset: float) -> void:
 if not _valid_cast(sim,enemy,runtime,cast): return
 var target: String=sim.hero.actor_id
 if cast.move=="C":
  var segments: Dictionary=cast.hits.get(target,{})
  if segments.has(segment): return
  segments[segment]=true; cast.hits[target]=segments
 else:
  if cast.hits.has(target): return
  cast.hits[target]=true
 # Spend once even if immune/absorbed; no late re-hit.
 var context: Dictionary=sim.presentation_push_contact(offset,"boss_"+str(cast.move))
 var before: float=float(sim.hero.hp)
 var receipt: Dictionary={"boss_cast_id":cast.boss_cast_id,"segment_id":segment,"target_actor_id":target,"nominal_damage":cast.damage,"run_id":cast.run_id,"source_instance_id":cast.source_instance_id,"generation":cast.generation,"room_id":cast.room_id,"source_time":float(context.get("world_at",sim.hero_time)),"geometry":cast.geometry.duplicate(true),"boss_move":cast.move,"actor_id":enemy.actor_id}
 sim.damage_hero(float(cast.damage),cast.direction,0.20 if cast.move=="A" else 0.0,false,false,{"boss_cast_id":cast.boss_cast_id,"segment_id":segment,"target_actor_id":target,"generation":cast.generation,"room_id":cast.room_id,"direct":true,"damage_provenance":"first_floor_boss"})
 sim.presentation_pop_contact(context)
 receipt["observed_hp_loss"]=maxf(0.0,before-float(sim.hero.hp))
 # Queued real Sim damage may settle after this call; nominal contact is not a
 # fabricated HP receipt. The ordinary damage event remains HP authority.
 receipts.append(receipt.duplicate(true))
 if receipts.size()>128: receipts.pop_front()
 if _current(sim,enemy,runtime): sim.emit_event("boss_hit_receipt",receipt)

func _finish(sim, enemy: Dictionary, runtime: Dictionary, cast: Dictionary) -> void:
 if not _valid_cast(sim,enemy,runtime,cast): return
 runtime.cast={}
 enemy.threat_left=0.0; enemy.state="recover"; enemy.timer=float(RECOVERY[cast.move]); enemy.warning_progress=0.0
 _event(sim,enemy,cast,"boss_cast_finished",{"recovery_duration":enemy.timer})

func _begin_phase(sim, enemy: Dictionary, runtime: Dictionary) -> void:
 if runtime.transition_done or not runtime.cast.is_empty(): return
 runtime.transition_done=true; runtime.pending_phase=false; runtime.phase=2
 enemy.state="boss_transition"; enemy.timer=PHASE_DURATION; enemy.threat_left=0.0; enemy.warning_progress=0.0
 sim.emit_event("boss_phase_started",{"actor_id":enemy.actor_id,"phase":2,"duration":PHASE_DURATION,"vulnerable":true,"generation":runtime.generation,"room_id":runtime.room_id,"source_time":sim.hero_time})

func _valid_cast(sim, enemy: Dictionary, runtime: Dictionary, cast: Dictionary) -> bool:
 return _current(sim,enemy,runtime) and not sim.paused and not runtime.cast.is_empty() and is_same(runtime.cast,cast)

func _event(sim, enemy: Dictionary, cast: Dictionary, kind: String, extra: Dictionary) -> void:
 var data: Dictionary={"actor_id":enemy.actor_id,"enemy_kind":"boss","role":"boss","position":cast.origin,"direction":cast.direction,"target_point":cast.target_point,"target_actor_id":cast.target_actor_id,"boss_cast_id":cast.boss_cast_id,"boss_move":cast.move,"generation":cast.generation,"room_id":cast.room_id,"phase":cast.phase,"run_id":cast.run_id,"source_instance_id":cast.source_instance_id,"geometry":cast.geometry.duplicate(true),"source_time":sim.hero_time}
 data.merge(extra,true)
 sim.emit_event(kind,data)
