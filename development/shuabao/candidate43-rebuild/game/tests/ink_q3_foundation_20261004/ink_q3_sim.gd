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

func _init()->void:
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
 var hit_count:int=0
 for enemy in targets:
  if not effect_is_current(state):return
  if not is_same(enemy,enemy_by_id(str(enemy.actor_id))) or enemy.dead or enemy.state=="spawn":continue
  if not claim_hit(int(state.cast_id),str(enemy.actor_id),segment):continue
  hit_count+=1
  var event_id:String=str(state.terrain_id)+":"+segment+":"+str(enemy.actor_id)
  var receipt:Dictionary={"source_event_id":event_id,"effect_id":event_id,"terrain_id":state.terrain_id,"cast_id":state.cast_id,"segment_id":segment,"target_id":enemy.actor_id,"generation":state.generation,"room_id":state.room_id,"source_time":hero_time,"origin":origin,"direction":direction,"length":length,"width":width,"nominal_damage":amount,"target_position":enemy.position,"target_radius":enemy.radius}
  var metadata:Dictionary={"effect_id":event_id,"generation":state.generation,"room_id":state.room_id,"position":origin,"cast_origin":state.origin,"direction":direction,"saved_aim":direction,"active_skill":true,"area":true,"direct":true,"basic_attack":false,"cast_damage_share":1.0/maxi(1,targets.size()),"replay_segment":{"target_mode":"spatial","segment_id":segment,"shape":shape,"relative_time":hero_time-float(state.born_at)}}
  damage_enemy(enemy,amount,"q3",int(state.cast_id),false,false,metadata)
  if not effect_is_current(state):return
  if collapse and not enemy.dead:
   push_enemy(enemy,direction,float(state.push_distance),"q3",int(state.cast_id),0.0,Q3_PUSH_TRANSPORT_SECONDS,0.0)
   if bool(state.h06_at_raise):apply_control(enemy,"stun",T.hex_parameter("H06-1"),0.0,{"source":"yanguizhou_h06","cast_id":state.cast_id})
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
 var hit:Dictionary=_q3_terrain_contact(origin,destination,radius,_q3_movement_actor)
 if hit.is_empty():return baseline
 var clipped:Vector3=origin.lerp(destination,maxf(0.0,float(hit.fraction)-.00001))
 return clipped if origin.distance_squared_to(clipped)<origin.distance_squared_to(baseline) else baseline

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
