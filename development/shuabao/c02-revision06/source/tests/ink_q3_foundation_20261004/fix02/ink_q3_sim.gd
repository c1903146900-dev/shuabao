extends "res://tests/ink_intermediate_stats_20261004/ink_intermediate_sim.gd"
## Isolated extension of exact a79fc Sim chain. Source-only candidate, not a host.
const MountainGeometry=preload("res://tests/ink_q3_foundation_20261004/ink_q3_geometry.gd")
const MountainDirector=preload("res://tests/ink_q3_foundation_20261004/ink_q3_enemy_director.gd")
const Q3_PUSH_TRANSPORT_SECONDS:float=0.35 # Declared implementation tuning, not XLSX.
var ink_mountain:Dictionary={}
var ink_q3_receipts:Array=[]
var ink_q3_finished:Array=[]
var _q3_last_direction:Vector3=Vector3.FORWARD
var _q3_movement_actor:Dictionary={}
var _q3_tick_active:bool=false
var _q3_tick_start:float=0.0
var _q3_serial:int=0

# Exact original collapse -> apply_control binding. A public control event has
# no authority; this frame is seen before that event and cannot grant twice.
var _g01_h06_control_frames: Array = []

func _equipment_original_stun_committed(enemy: Dictionary, metadata: Dictionary, before: float, after: float, adjusted: float) -> void:
 super._equipment_original_stun_committed(enemy,metadata,before,after,adjusted)
 if _g01_h06_control_frames.is_empty(): return
 var frame: Dictionary = _g01_h06_control_frames.back()
 if frame.seen or not is_same(frame.enemy,enemy) or not is_same(frame.metadata,metadata): return
 frame.seen = true
 if not is_finite(before) or not is_finite(after) or not is_finite(adjusted) or after <= before or after != maxf(before,adjusted): return
 if float(enemy.stun_left) != after: return
 var commit: Dictionary = {"enemy":enemy,"metadata":metadata,"before":before,"after":after,"adjusted":adjusted,"duration":frame.duration}
 frame.commit = commit
 _equipment_effect_committed("q3",frame.state,"q3_h06_stun",commit)
 frame.commit = {}

func verify_g01_h06_stun(state: Dictionary, commit: Dictionary) -> bool:
 if _g01_h06_control_frames.is_empty(): return false
 var frame: Dictionary = _g01_h06_control_frames.back()
 if not frame.seen or not is_same(frame.state,state) or not is_same(frame.commit,commit): return false
 if not is_same(commit.get("enemy"),frame.enemy) or not is_same(commit.get("metadata"),frame.metadata): return false
 if not bool(state.get("h06_at_raise",false)) or not effect_is_current(state): return false
 var enemy: Dictionary = frame.enemy
 if enemy.dead or not is_same(enemy,enemy_by_id(str(enemy.actor_id))): return false
 if frame.metadata.get("source") != "yanguizhou_h06" or frame.metadata.get("cast_id") != state.get("cast_id"): return false
 if not is_finite(float(commit.before)) or not is_finite(float(commit.after)) or not is_finite(float(commit.adjusted)): return false
 return float(commit.after) > float(commit.before) and float(commit.after) == maxf(float(commit.before),float(commit.adjusted)) and float(enemy.stun_left) == float(commit.after)

# Original movement and candidate-probe stacks. Tokens never escape as events.
var _g01_q3_movement_frames: Array = []
var _g01_q3_probe_frames: Array = []

func _equipment_q3_movement_begin(enemy: Dictionary, source: String) -> Dictionary:
 if enemy.is_empty() or not is_same(_q3_movement_actor,enemy) or not ordinary(enemy) or enemy.dead or not is_same(enemy,enemy_by_id(str(enemy.actor_id))): return {}
 var mountain: Dictionary = ink_mountain
 if mountain.is_empty() or not effect_is_current(mountain) or bool(mountain.get("retired",true)): return {}
 var frame: Dictionary = {"enemy":enemy,"mountain":mountain,"from":Vector3(enemy.position),"source":source,"tokens":[],"commit":{},"closed":false}
 _g01_q3_movement_frames.append(frame)
 return frame

func _equipment_q3_probe_begin(origin: Vector3, destination: Vector3, radius: float) -> Dictionary:
 if _g01_q3_movement_frames.is_empty(): return {}
 var frame: Dictionary = _g01_q3_movement_frames.back()
 if frame.closed or not is_same(_q3_movement_actor,frame.enemy) or origin != frame.from: return {}
 var token: Dictionary = {"enemy":frame.enemy,"mountain":frame.mountain,"from":origin,"attempted_to":destination,"radius":radius,"captured":false,"closed":false,"consumed":false,"effective":false}
 frame.tokens.append(token)
 _g01_q3_probe_frames.append(token)
 return token

func _g01_q3_capture_probe(mountain: Dictionary, origin: Vector3, destination: Vector3, radius: float, baseline: Vector3, chosen: Vector3, hit: Dictionary, q3_selected: bool) -> void:
 if _g01_q3_probe_frames.is_empty() or _g01_q3_movement_frames.is_empty(): return
 var token: Dictionary = _g01_q3_probe_frames.back()
 if token.closed or token.captured or not is_same(token.enemy,_q3_movement_actor) or not is_same(token.mountain,mountain): return
 if token.from != origin or token.attempted_to != destination or token.radius != radius: return
 token.captured = true
 token.baseline = baseline
 token.q3_result = chosen
 token.q3_selected = q3_selected
 token.hit = hit.duplicate(true)

func _equipment_q3_probe_end(token: Dictionary, returned: Vector3, static_exact: Variant = null) -> void:
 if token.is_empty() or _g01_q3_probe_frames.is_empty() or not is_same(_g01_q3_probe_frames.back(),token): return
 _g01_q3_probe_frames.pop_back()
 token.closed = true
 token.returned = returned
 token.static_exact = static_exact
 if not token.captured or not token.get("q3_selected",false): return
 var baseline: Vector3 = token.baseline
 # Same original director comparison, using its already-computed exact point.
 if static_exact is Vector3 and static_exact.distance_squared_to(token.from) < baseline.distance_squared_to(token.from): baseline = static_exact
 token.full_static_baseline = baseline
 token.effective = returned == token.q3_result and returned.distance_squared_to(token.from) < baseline.distance_squared_to(token.from)

func _equipment_q3_select_output(output: Variant, selected: Dictionary) -> void:
 if not output is Dictionary: return
 output.clear()
 var token: Variant = selected.get("token")
 if token is Dictionary and not token.is_empty(): output["token"] = token

func _g01_q3_selected_token(frame: Dictionary, selected: Dictionary) -> Dictionary:
 var token: Variant = selected.get("token")
 if not token is Dictionary or token.is_empty(): return {}
 var registered: bool = false
 for original: Dictionary in frame.tokens:
  if is_same(original,token): registered = true; break
 if not registered or not token.closed or token.consumed or not token.effective: return {}
 if not is_same(token.enemy,frame.enemy) or not is_same(token.mountain,frame.mountain) or token.from != frame.from: return {}
 if not is_same(ink_mountain,frame.mountain) or not effect_is_current(frame.mountain) or bool(frame.mountain.get("retired",true)): return {}
 if not is_same(frame.enemy,enemy_by_id(str(frame.enemy.actor_id))) or frame.enemy.dead or not ordinary(frame.enemy): return {}
 if not is_same(_q3_movement_actor,frame.enemy) or Vector3(frame.enemy.position) != token.returned: return {}
 return token

func _equipment_q3_movement_finish(frame: Dictionary, selected: Dictionary) -> void:
 if frame.is_empty() or _g01_q3_movement_frames.is_empty() or not is_same(_g01_q3_movement_frames.back(),frame): return
 var token: Dictionary = _g01_q3_selected_token(frame,selected)
 if not token.is_empty():
  token.consumed = true
  var commit: Dictionary = {"enemy":frame.enemy,"token":token,"from":frame.from,"to":Vector3(frame.enemy.position),"movement_source":frame.source}
  frame.commit = commit
  _equipment_effect_committed("q3",frame.mountain,"q3_movement_blocked",commit)
  frame.commit = {}
 frame.closed = true
 assert(is_same(_g01_q3_movement_frames.back(),frame))
 _g01_q3_movement_frames.pop_back()

func verify_g01_q3_movement(state: Dictionary, commit: Dictionary) -> bool:
 if _g01_q3_movement_frames.is_empty(): return false
 var frame: Dictionary = _g01_q3_movement_frames.back()
 if frame.closed or not is_same(frame.commit,commit) or not is_same(frame.mountain,state) or not is_same(commit.get("enemy"),frame.enemy): return false
 var token: Dictionary = commit.token
 var registered: bool = false
 for original: Dictionary in frame.tokens:
  if is_same(original,token): registered = true; break
 if not registered or not token.closed or not token.consumed or not token.effective: return false
 if not is_same(token.enemy,frame.enemy) or not is_same(token.mountain,state) or token.from != frame.from or commit.from != frame.from: return false
 if not is_same(ink_mountain,state) or not effect_is_current(state) or bool(state.get("retired",true)): return false
 if not is_same(_q3_movement_actor,frame.enemy) or not is_same(frame.enemy,enemy_by_id(str(frame.enemy.actor_id))) or frame.enemy.dead or not ordinary(frame.enemy): return false
 if Vector3(frame.enemy.position) != token.returned or commit.to != token.returned: return false
 return token.returned == token.q3_result and Vector3(token.returned).distance_squared_to(token.from) < Vector3(token.full_static_baseline).distance_squared_to(token.from)

func _init()->void:
 super._init()
 enemy_director=MountainDirector.new()

func _q3_direction(from:Vector3,to:Vector3)->Vector3:
 var delta:Vector3=Geometry.ground(to-from)
 if delta.length_squared()>Geometry.EPS*Geometry.EPS:return delta.normalized()
 if hero.facing.is_finite() and Geometry.ground(hero.facing).length_squared()>Geometry.EPS*Geometry.EPS:return Geometry.ground(hero.facing).normalized()
 return _q3_last_direction

func q3_preview(point:Vector3)->Dictionary:
 if not point.is_finite():return {"accepted":false,"reason":"manual_aim_required","preview_only":true}
 var rank:int=int(hero.ranks.q)
 if hero.loadout.q!="q3" or rank<=0:return {"accepted":false,"reason":"q3_unlearned","preview_only":true}
 var at:Vector3=Geometry.ground(point)
 if not ink_mountain.is_empty() and effect_is_current(ink_mountain):
  var direction:Vector3=_q3_direction(ink_mountain.position,at)
  return {"accepted":true,"preview_only":true,"phase":"collapse","origin":ink_mountain.position,"direction":direction,"length":ink_mountain.collapse_length,"width":ink_mountain.collapse_width,"cast_id":ink_mountain.cast_id}
 if Geometry.ground(at-hero.position).length()>v("Q3-1",rank)+Geometry.EPS:return {"accepted":false,"reason":"outside_placement_range","preview_only":true}
 var facing:Vector3=_q3_direction(hero.position,at)
 var axis:Vector3=Vector3(-facing.z,0.0,facing.x)
 return {"accepted":true,"preview_only":true,"phase":"raise","position":at,"axis":axis,"facing":facing,"length":v("Q3-4",rank)*(1.0+T.hex_parameter("H05-1")*.01 if hx("yanguizhou_h05") else 1.0),"width":v("Q3-5",rank),"placement_range":v("Q3-1",rank),"orientation_provenance":"declared_implementation_convention"}

func _request_action(action:String,aim:Vector3)->Dictionary:
 if hero.loadout.q=="q3" and action in ["q","ink_q_down"]:
  # The retained Q1 entry gate arms a mouse gesture unless this narrow internal
  # dispatch guard is set. Only this Q3 request passes through to the same core
  # transaction, action policy, on-cast/proc budget, dedup and admission service.
  var saved:bool=_committing_q1
  _committing_q1=true
  var result:Dictionary=super._request_action("q",aim)
  _committing_q1=saved
  return result
 return super._request_action(action,aim)

func _hero_action_policy(action:String,aim:Vector3=Vector3.INF)->Dictionary:
 if action!="q" or hero.loadout.q!="q3":return super._hero_action_policy(action,aim)
 if source_rules_hash!=EXPECTED_RULES_HASH:return {"reason":"source_binding_mismatch"}
 if _ink_action_controlled(action):return {"reason":"controlled"}
 var preview:Dictionary=q3_preview(aim)
 if not preview.accepted:return {"reason":preview.reason}
 if not ink_mountain.is_empty():
  if not effect_is_current(ink_mountain):return {"reason":"stale_mountain"}
  if hero_time>=float(ink_mountain.expires_at)-TIME_EPS:return {"reason":"mountain_expired"}
  return {"bypass_cooldown":true,"cast_id":ink_mountain.cast_id,"context":ink_mountain.context,"stage":"collapse"}
 return {"stage":"raise"}

func _hero_cast_skill(action:String,context:Dictionary)->Dictionary:
 if action!="q" or hero.loadout.q!="q3":return super._hero_cast_skill(action,context)
 if not effect_is_current(context):return {"accepted":false,"reason":"stale_cast"}
 if not ink_mountain.is_empty():return _q3_collapse(context)
 var preview:Dictionary=q3_preview(hero.aim_point)
 if not preview.accepted:return {"accepted":false,"reason":preview.reason}
 var rank:int=int(hero.ranks.q)
 _q3_serial+=1
 _q3_last_direction=preview.facing
 var state:Dictionary=context.duplicate(true)
 state.merge({"terrain_id":"%d:%s:mountain:%d"%[encounter_generation,room_id,_q3_serial],"context":context.duplicate(true),"position":preview.position,"axis":preview.axis,"length":preview.length,"width":preview.width,"rank":rank,"born_at":hero_time,"expires_at":hero_time+v("Q3-6",rank),"raise_damage":v("Q3-2",rank)+float(hero.stats.ap)*T.fraction("Q3-3",rank),"collapse_damage":v("Q3-9",rank)+float(hero.stats.ap)*T.fraction("Q3-10",rank),"collapse_length":v("Q3-7",rank),"collapse_width":v("Q3-8",rank),"push_distance":v("Q3-11",rank),"h05_at_raise":hx("yanguizhou_h05"),"h06_at_raise":hx("yanguizhou_h06"),"retired":false},true)
 ink_mountain=state
 start_skill_cooldown("q",v("Q3-12",rank))
 _equipment_release_committed("q3",state)
 emit_event("ink_q3_raised",_q3_public(state))
 if not effect_is_current(state) or not is_same(ink_mountain,state):return {"accepted":true,"terrain_id":state.terrain_id,"cancelled_during_callback":true}
 var origin:Vector3=Vector3(state.position)-Vector3(state.axis)*float(state.length)*.5
 _q3_damage_segment(state,"mountain_raise_burst",origin,state.axis,state.length,state.width,state.raise_damage,false)
 return {"accepted":true,"terrain_id":state.terrain_id,"phase":"raise"}

func _q3_collapse(context:Dictionary)->Dictionary:
 var state:Dictionary=ink_mountain
 if int(state.cast_id)!=int(context.cast_id) or not effect_is_current(state):return {"accepted":false,"reason":"stale_mountain"}
 var direction:Vector3=_q3_direction(state.position,hero.aim_point)
 _q3_last_direction=direction
 # Remove collision ownership before any damage or callback; never rebuild it
 # from a stale damage loop. The original root remains alive until settlement.
 ink_mountain={};state.retired=true
 emit_event("ink_q3_collapse_started",_q3_public(state).merged({"direction":direction,"length":state.collapse_length,"width":state.collapse_width},true))
 if effect_is_current(state):_q3_damage_segment(state,"mountain_collapse",state.position,direction,state.collapse_length,state.collapse_width,state.collapse_damage,true)
 if effect_is_current(state):
  finish_cast(int(state.cast_id))
  if effect_is_current(state):_q3_finish_receipt(state,"collapsed",hero_time)
 return {"accepted":true,"terrain_id":state.terrain_id,"phase":"collapse"}

func _q3_damage_segment(state:Dictionary,segment:String,origin:Vector3,direction:Vector3,length:float,width:float,amount:float,collapse:bool)->void:
 var shape:Dictionary={"kind":"rectangle","circle_rectangle":true,"direction":direction,"length":length,"width":width}
 var targets:Array=shape_targets(origin,direction,shape)
 # Each raise/collapse is one simultaneous area batch. Re-evaluate for the next
 # independent segment, but never let this batch's first kill change later hits.
 # These are the existing Wind R1/common/Ink damage-pipeline snapshot interfaces.
 common.refresh_stats()
 var live:Array=common.runtime._enemies(common.context())
 var mode:String="horde" if live.size()>=int(common.runtime.parameter("g22",1)) else "duel" if live.size()==1 and not ordinary(live[0]) else "none"
 var impact:Dictionary={"g22_mode_snapshot":mode,"impact_penetration":float(hero.stats.penetration),"impact_lifesteal_rate":hero.lifesteal()}
 var hit_count:int=0
 for enemy in targets:
  if not effect_is_current(state):return
  if not is_same(enemy,enemy_by_id(str(enemy.actor_id))) or enemy.dead or enemy.state=="spawn":continue
  if not claim_hit(int(state.cast_id),str(enemy.actor_id),segment):continue
  hit_count+=1
  var event_id:String=str(state.terrain_id)+":"+segment+":"+str(enemy.actor_id)
  var receipt:Dictionary={"source_event_id":event_id,"effect_id":event_id,"terrain_id":state.terrain_id,"cast_id":state.cast_id,"segment_id":segment,"target_id":enemy.actor_id,"generation":state.generation,"room_id":state.room_id,"source_time":hero_time,"origin":origin,"direction":direction,"length":length,"width":width,"nominal_damage":amount,"target_position":enemy.position,"target_radius":enemy.radius}
  var metadata:Dictionary={"effect_id":event_id,"generation":state.generation,"room_id":state.room_id,"position":origin,"cast_origin":state.origin,"direction":direction,"saved_aim":direction,"active_skill":true,"area":true,"direct":true,"basic_attack":false,"cast_damage_share":1.0/maxi(1,targets.size()),"replay_segment":{"target_mode":"spatial","segment_id":segment,"shape":shape,"relative_time":hero_time-float(state.born_at)}}
  metadata.merge(impact,false)
  _equipment_skill_damage("q3",state,enemy,amount,"q3",int(state.cast_id),false,false,metadata)
  if not effect_is_current(state):return
  if collapse and not enemy.dead:
   var g01_push_before:Dictionary=enemy.push
   push_enemy(enemy,direction,float(state.push_distance),"q3",int(state.cast_id),0.0,Q3_PUSH_TRANSPORT_SECONDS,0.0)
   _equipment_push_bound("q3",state,enemy,g01_push_before,enemy.push)
   if bool(state.h06_at_raise):
    var g01_h06_metadata:Dictionary={"source":"yanguizhou_h06","cast_id":state.cast_id}
    var g01_h06_duration:float=T.hex_parameter("H06-1")
    var g01_h06_frame:Dictionary={"state":state,"enemy":enemy,"metadata":g01_h06_metadata,"duration":g01_h06_duration,"seen":false,"commit":{}}
    _g01_h06_control_frames.append(g01_h06_frame)
    apply_control(enemy,"stun",g01_h06_duration,0.0,g01_h06_metadata)
    assert(is_same(_g01_h06_control_frames.back(),g01_h06_frame))
    _g01_h06_control_frames.pop_back()
  if not effect_is_current(state):return
  ink_q3_receipts.append(receipt)
  if ink_q3_receipts.size()>128:ink_q3_receipts.pop_front()
  emit_event("ink_q3_contact",receipt)
 if hit_count==0 and effect_is_current(state):common.record_spatial(int(state.cast_id),segment,amount*float(hero.stats.get("common_damage_multiplier",1.0)),origin,shape,{"relative_time":hero_time-float(state.born_at)})

func _hero_hex_status(id:String)->Dictionary:
 if id in ["yanguizhou_h05","yanguizhou_h06"]:
  var active:bool=hero.loadout.q=="q3" and int(hero.ranks.q)>0
  return {"active":active,"reason":"" if active else "requires_Q3"}
 return super._hero_hex_status(id)

func common_damage_metadata(source:String)->Dictionary:
 if source=="q3":return {"active_skill":true,"basic_attack":false,"direct":true,"area":true,"hex_generated":false}
 return super.common_damage_metadata(source)

func _hero_enemy_control_allowed(enemy:Dictionary,kind:String,metadata:Dictionary)->bool:
 if kind=="stun" and metadata.get("source","")=="yanguizhou_h06":return true
 return super._hero_enemy_control_allowed(enemy,kind,metadata)

func push_enemy(enemy:Dictionary,direction:Vector3,distance:float,source:String,id:int,collision_damage:float=0.0,duration:float=.35,collision_stun:float=0.0)->void:
 if source!="q3":super.push_enemy(enemy,direction,distance,source,id,collision_damage,duration,collision_stun);return
 if not cast_is_current(id) or enemy.dead or not is_same(enemy,enemy_by_id(str(enemy.actor_id))) or not _hero_enemy_control_allowed(enemy,"push",{}):return
 # Same existing transport state, resistance, collision, and director interrupt.
 # Do not copy generic push_enemy's additional stun_left=duration assignment.
 enemy.push={"direction":direction.normalized(),"left":maxf(TIME_EPS,duration),"duration":maxf(TIME_EPS,duration),"distance":maxf(0.0,distance)/maxf(.01,float(enemy.get("common_knockback_resistance_multiplier",1))),"source":source,"cast_id":id,"collision_damage":0.0,"collision_stun":0.0,"generation":encounter_generation,"room_id":room_id,"hits":[],"count":0}

func _fixed_step(real_dt:float)->void:
 var scope:Dictionary=_ink_scope()
 _q3_tick_active=true;_q3_tick_start=hero_time
 super._fixed_step(real_dt)
 _q3_tick_active=false;_q3_movement_actor={}
 if not _ink_scope_current(scope):return
 if not ink_mountain.is_empty() and hero_time>=float(ink_mountain.expires_at)-TIME_EPS:
  var state:Dictionary=ink_mountain
  ink_mountain={};state.retired=true
  finish_cast(int(state.cast_id))
  if effect_is_current(state):_q3_finish_receipt(state,"expired",float(state.expires_at))
 _check_victory()

func _q3_terrain_contact(origin:Vector3,destination:Vector3,radius:float,actor:Dictionary={},interval_fraction:float=1.0)->Dictionary:
 var state:Dictionary=ink_mountain
 if state.is_empty() or not effect_is_current(state) or bool(state.retired):return {}
 var start:float=_q3_tick_start if _q3_tick_active else hero_time
 if start>=float(state.expires_at)-TIME_EPS:return {}
 if not actor.is_empty():
  if not ordinary(actor) or actor.dead or not is_same(actor,enemy_by_id(str(actor.actor_id))):return {}
  if MountainGeometry.overlaps(origin,radius,state.position,state.axis,state.length,state.width):
   # No teleport, ejection, birth stun, or permanent trapping. Permit only a
   # decreasing penetration from an already overlapping birth position.
   if MountainGeometry.escaping_overlap(origin,destination,state.position,state.axis,state.length,state.width):return {}
 var fraction:float=MountainGeometry.entry(origin,destination,radius,state.position,state.axis,state.length,state.width)
 if not is_finite(fraction):return {}
 var contact_at:float=lerpf(start,hero_time,fraction*clampf(interval_fraction,0.0,1.0)) if _q3_tick_active else hero_time
 if contact_at>=float(state.expires_at)-TIME_EPS:return {}
 return {"fraction":fraction,"position":origin.lerp(destination,fraction),"terrain_id":state.terrain_id,"cast_id":state.cast_id,"generation":state.generation,"room_id":state.room_id,"source_time":contact_at}

func _move_clipped(origin:Vector3,destination:Vector3,radius:float=.65)->Vector3:
 var baseline:Vector3=super._move_clipped(origin,destination,radius)
 if _q3_movement_actor.is_empty():return baseline
 var g01_mountain:Dictionary=ink_mountain
 var hit:Dictionary=_q3_terrain_contact(origin,destination,radius,_q3_movement_actor)
 if hit.is_empty():return baseline
 var clipped:Vector3=origin.lerp(destination,maxf(0.0,float(hit.fraction)-.00001))
 var g01_q3_selected:bool=origin.distance_squared_to(clipped)<origin.distance_squared_to(baseline)
 var g01_chosen:Vector3=clipped if g01_q3_selected else baseline
 _g01_q3_capture_probe(g01_mountain,origin,destination,radius,baseline,g01_chosen,hit,g01_q3_selected)
 return g01_chosen

func _step_pull(enemy:Dictionary,dt:float)->void:
 var prior:Dictionary=_q3_movement_actor;_q3_movement_actor=enemy
 super._step_pull(enemy,dt)
 _q3_movement_actor=prior
func _step_push(enemy:Dictionary,dt:float)->void:
 var prior:Dictionary=_q3_movement_actor;_q3_movement_actor=enemy
 super._step_push(enemy,dt)
 _q3_movement_actor=prior
func _step_enemy(enemy:Dictionary,dt:float)->void:
 var prior:Dictionary=_q3_movement_actor;_q3_movement_actor=enemy
 super._step_enemy(enemy,dt)
 _q3_movement_actor=prior

func _q3_finish_receipt(state:Dictionary,reason:String,at:float)->void:
 var receipt:Dictionary=_q3_public(state).merged({"reason":reason,"finished_at":at,"settled_at":hero_time},true)
 ink_q3_finished.append(receipt)
 if ink_q3_finished.size()>32:ink_q3_finished.pop_front()
 emit_event("ink_q3_finished",receipt)

func cancel_cast(id:int)->void:
 var state:Dictionary=ink_mountain if not ink_mountain.is_empty() and int(ink_mountain.cast_id)==id else {}
 if not state.is_empty():ink_mountain={};state.retired=true
 super.cancel_cast(id)
 if not state.is_empty() and phase=="combat" and int(state.generation)==encounter_generation and str(state.room_id)==room_id:_q3_finish_receipt(state,"cast_cancelled",hero_time)

func _hero_clear_transients()->void:
 ink_mountain={};ink_q3_receipts.clear();ink_q3_finished.clear();_q3_movement_actor={};_q3_tick_active=false
 super._hero_clear_transients()
func _hero_victory_pending()->bool:return super._hero_victory_pending() or not ink_mountain.is_empty()
func _q3_public(state:Dictionary)->Dictionary:
 var out:Dictionary={}
 for key in ["terrain_id","cast_id","generation","room_id","position","axis","length","width","rank","born_at","expires_at","collapse_length","collapse_width","push_distance","h05_at_raise","h06_at_raise"]:out[key]=state[key]
 out["remaining"]=maxf(0.0,float(state.expires_at)-hero_time)
 out["source_time"]=hero_time
 out["debug_geometry_only"]=true
 return out.duplicate(true)
func ink_presenter_snapshot()->Dictionary:
 var out:Dictionary=super.ink_presenter_snapshot()
 out["q3_schema"]="ink-q3-mechanic-foundation-1"
 out["mountain"]={} if ink_mountain.is_empty() else _q3_public(ink_mountain)
 out["q3_receipts"]=ink_q3_receipts.duplicate(true)
 out["q3_finished"]=ink_q3_finished.duplicate(true)
 return out
func _hero_snapshot()->Dictionary:
 var out:Dictionary=super._hero_snapshot()
 out["ink_foundation_scope"]="BASIC_Shift_Q1_H01_H02_plus_isolated_Q3_H05_H06_source_candidate"
 out["q3_ordinary_entry_ready"]=false
 return out
