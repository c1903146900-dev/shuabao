extends "res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_damage_scope_guard.gd"
## Isolated Ink BASIC/Shift/Q1 candidate. No normal-entry or complete-hero claim.
const InkBridge=preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_common_bridge.gd")
const T=preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd")
const Geometry=preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_geometry.gd")
var _initial_runtime_snapshot:Dictionary=T.runtime()
var tuning:Dictionary=_initial_runtime_snapshot.duplicate(true)
var ink_input:Dictionary={"phase":"idle","gesture_id":"","path":[],"cancel_reason":""}
var ink_waves:Array=[]
var ink_basics:Array=[]
var _equipment_sync_settlement_frames:Array=[]
var ink_receipts:Array=[]
var ink_finished:Array=[]
var source_rules_hash:String=""
const EXPECTED_RULES_HASH="aef68e35a4becc25fcfa4158cfc2d55ee538a942023f99b7e7cefb07dac7cf53"
var gesture_serial:int=0
var motion_serial:int=0
var ink_core_steps:int=0
var _left_held:bool=false
var _left_consumed:bool=false
var _committing_q1:bool=false
var _expected_gesture:String=""
var _manual_direction:Vector3=Vector3.INF
var _control_frame_active:bool=false
var _control_frame_left:float=0.0
var _control_frame_clock:float=0.0
var _control_motion_blocking:bool=false

func _init()->void:
 source_rules_hash=FileAccess.get_sha256("res://data/final_design/effective_rule_resolutions.json")
 hero.actor_id="yanguizhou"
 hero.initialize_stats(T.hero_stats_from_runtime(_initial_runtime_snapshot))
 common=InkBridge.new(self)
 common.context_values["ranged"]=true
 room_id="ink-q1-isolated";combat_level_id=room_id
func v(token:String,rank:int=1)->float:return T.parameter(token,rank)
func _input_reject(reason:String)->Dictionary:return {"accepted":false,"reason":reason,"consumed":_left_consumed}
func _q_ready()->String:
 if source_rules_hash!=EXPECTED_RULES_HASH:return "source_binding_mismatch"
 if phase!="combat" or paused:return "encounter_frozen"
 if hero.dead:return "not_alive"
 if _ink_action_controlled("q"):return "controlled"
 if hero.loadout.q!="q1" or int(hero.ranks.q)<=0:return "q1_unlearned"
 if hero.cooldowns.q>TIME_EPS:return "cooldown"
 if hero.lock_time>TIME_EPS:return "action_locked"
 return ""
func request_ink_input(kind:String,ground_point:Vector3=Vector3.INF,command_id:String="",expected_gesture_id:String="",expected_generation:int=-1)->Dictionary:
 if expected_generation>=0 and expected_generation!=encounter_generation:return _input_reject("stale_input_generation")
 if transaction_active:return _input_reject("transaction_in_progress")
 _expected_gesture=expected_gesture_id
 var result:Dictionary=request_action("ink_"+kind,ground_point,command_id)
 _expected_gesture=""
 return result
func _request_action(action:String,aim:Vector3)->Dictionary:
 if action=="q" and not _committing_q1:return _arm_q1()
 if action.begins_with("ink_"):return _handle_ink_input(action.trim_prefix("ink_"),aim)
 return super._request_action(action,aim)
func _arm_q1()->Dictionary:
 var reason:String=_q_ready()
 if not reason.is_empty():return _input_reject(reason)
 if ink_input.phase!="idle":return _input_reject("q1_already_armed")
 if _left_held:return _input_reject("mouse_already_held")
 gesture_serial+=1;revision+=1
 ink_input={"phase":"armed","gesture_id":"%d:%s:gesture:%d"%[encounter_generation,room_id,gesture_serial],"path":[],"cancel_reason":"","armed_at":hero_time}
 emit_event("ink_q1_armed",{"gesture_id":ink_input.gesture_id,"placement_radius":float(tuning.q1_initial_placement_range_m),"preview_only":true})
 return {"accepted":true,"reason":"armed","gesture_id":ink_input.gesture_id,"consumed":true}
func _handle_ink_input(kind:String,point:Vector3)->Dictionary:
 if kind in ["right_down","escape","focus_lost"]:
  if kind!="focus_lost" and ink_input.phase=="idle":return {"accepted":false,"reason":"no_preview_to_cancel","consumed":false}
  return cancel_ink_preview(kind)
 if kind=="q_up":return {"accepted":false,"reason":"q_up_never_releases","consumed":ink_input.phase!="idle"}
 if kind=="q_down":return _arm_q1()
 if phase!="combat" or paused or hero.dead:return _input_reject("encounter_frozen")
 if kind in ["motion","left_up"] and not _expected_gesture.is_empty() and _expected_gesture!=ink_input.gesture_id:return _input_reject("stale_gesture")
 match kind:
  "left_down":
   if _left_held:return _input_reject("duplicate_mouse_down")
   _left_held=true;_left_consumed=ink_input.phase!="idle"
   if not _left_consumed:return super._request_action("attack",point)
   if ink_input.phase!="armed":return _input_reject("gesture_already_started")
   var reason:String=_q_ready()
   if not reason.is_empty():return _input_reject(reason)
   if not point.is_finite():return _input_reject("invalid_ground_point")
   var start:Vector3=Geometry.ground(point)
   # Exactly one range test, at mouse-down. This start never follows the hero.
   if start.distance_to(Geometry.ground(hero.position))>float(tuning.q1_initial_placement_range_m):return _input_reject("initial_point_out_of_range")
   var rank:int=int(hero.ranks.q)
   var h01:bool=hx("yanguizhou_h01")
   var length_cap:float=v("Q1-4",rank)*(1.0+T.hex_parameter("H01-2")/100.0 if h01 else 1.0)
   revision+=1
   ink_input.merge({"phase":"drawing","start":start,"path":[start,start],"started_at":hero_time,"draw_limit":v("Q1-6",rank),"rank":rank,"length_cap":length_cap,"corner_cap":int(T.hex_parameter("H01-1")) if h01 else 0,"committed_corners":0,"freeze_reason":"","frozen_at":-1.0,"admitted_hero_position":Geometry.ground(hero.position),"width":v("Q1-5",rank)},true)
   emit_event("ink_q1_preview_started",{"gesture_id":ink_input.gesture_id,"start":start,"path":ink_input.path.duplicate(true),"preview_only":true})
   return {"accepted":true,"reason":"drawing","gesture_id":ink_input.gesture_id,"consumed":true}
  "motion":
   if _ink_action_controlled("q"):return _input_reject("controlled")
   if not _left_held or ink_input.phase not in ["drawing","frozen"]:return _input_reject("no_drawing_gesture")
   _freeze_time_if_due()
   if ink_input.phase=="frozen":return {"accepted":true,"reason":"frozen_no_change","consumed":true}
   if not point.is_finite():return _input_reject("invalid_ground_point")
   _update_preview(Geometry.ground(point))
   return {"accepted":true,"reason":ink_input.phase,"consumed":true}
  "left_up":
   if not _left_held:return _input_reject("unpaired_mouse_up")
   var consumed:bool=_left_consumed
   _left_held=false;_left_consumed=false
   if not consumed:return {"accepted":false,"reason":"basic_mouse_up","consumed":false}
   if ink_input.phase=="armed":return {"accepted":false,"reason":"rejected_start_mouse_up","consumed":true}
   if ink_input.phase not in ["drawing","frozen"]:return _input_reject("no_drawing_gesture")
   _freeze_time_if_due()
   if ink_input.phase=="drawing" and point.is_finite():_update_preview(Geometry.ground(point))
   if Geometry.path_length(ink_input.path)<=Geometry.EPS:return cancel_ink_preview("zero_length")
   var reason:String=_q_ready()
   if not reason.is_empty():
    cancel_ink_preview("release_"+reason)
    return _input_reject(reason)
   _committing_q1=true
   var result:Dictionary=super._request_action("q",ink_input.path.back())
   _committing_q1=false
   if not result.get("accepted",false):cancel_ink_preview("release_"+str(result.reason))
   result["consumed"]=true
   return result
 return _input_reject("unknown_ink_input")
func cancel_ink_preview(reason:String="cancelled")->Dictionary:
 var previous:Dictionary=ink_input.duplicate(true)
 revision+=1
 _left_held=false;_left_consumed=false
 ink_input={"phase":"idle","gesture_id":"","path":[],"cancel_reason":reason}
 if previous.phase!="idle":emit_event("ink_q1_preview_cancelled",{"gesture_id":previous.gesture_id,"reason":reason,"preview_only":true})
 return {"accepted":previous.phase!="idle","reason":reason,"consumed":previous.phase!="idle"}
func _freeze_time_if_due()->void:
 if ink_input.phase=="drawing" and hero_time>=float(ink_input.started_at)+float(ink_input.draw_limit)-TIME_EPS:_freeze_preview("time_limit",float(ink_input.started_at)+float(ink_input.draw_limit))
func _freeze_preview(reason:String,at:float)->void:
 if ink_input.phase!="drawing":return
 revision+=1
 ink_input.phase="frozen";ink_input.freeze_reason=reason;ink_input.frozen_at=at
 emit_event("ink_q1_preview_frozen",{"gesture_id":ink_input.gesture_id,"path":ink_input.path.duplicate(true),"reason":reason,"frozen_at":at,"preview_only":true})
func _update_preview(point:Vector3)->void:
 var path:Array=ink_input.path.duplicate(true)
 var anchor:Vector3=path[path.size()-2]
 var previous:Vector3=path.back()
 var leg:Vector3=previous-anchor
 var motion:Vector3=point-previous
 if int(ink_input.committed_corners)<int(ink_input.corner_cap) and leg.length()>=float(tuning.h01_corner_min_leg_m) and motion.length()>=float(tuning.h01_corner_min_motion_m):
  var turn:float=rad_to_deg(acos(clampf(leg.normalized().dot(motion.normalized()),-1.0,1.0)))
  if turn>=float(tuning.h01_corner_angle_degrees):
   path.append(previous);ink_input.committed_corners+=1;anchor=previous
 var fixed_length:float=0.0
 for i in range(1,path.size()-1):fixed_length+=Vector3(path[i-1]).distance_to(path[i])
 var remaining:float=maxf(0.0,float(ink_input.length_cap)-fixed_length)
 var desired:Vector3=point-anchor
 path[path.size()-1]=anchor+desired.limit_length(remaining)
 ink_input.path=path;revision+=1
 if desired.length()>=remaining:_freeze_preview("length_limit",hero_time)
func _hero_action_policy(action:String,aim:Vector3=Vector3.INF)->Dictionary:
 if action in ["attack","shift","q"] and _ink_action_controlled(action):return {"reason":"controlled"}
 if source_rules_hash!=EXPECTED_RULES_HASH:return {"reason":"source_binding_mismatch"}
 if action in ["e","e_release","r"]:return {"reason":"candidate_not_implemented"}
 if action=="q" and (not _committing_q1 or hero.loadout.q!="q1"):return {"reason":"q1_requires_mouse_release"}
 _manual_direction=Vector3.INF
 if action in ["attack","shift"]:
  if not aim.is_finite():return {"reason":"manual_aim_required"}
  var offset:Vector3=Geometry.ground(aim-hero.position)
  if offset.length_squared()<=Geometry.EPS*Geometry.EPS:return {"reason":"zero_manual_aim"}
  _manual_direction=offset.normalized()
 if action=="attack":
  if ink_input.phase in ["drawing","frozen"]:return {"reason":"q1_preview_consumes_basic"}
  if hero.cooldowns.attack>TIME_EPS:return {"reason":"cooldown"}
  if hero.lock_time>TIME_EPS:return {"reason":"action_locked"}
 return {}
func _ink_action_ignores_control(_action:String)->bool:
 # Extension point for future source-explicit exceptions (E1/H07); not available yet.
 return false
func _ink_action_controlled(action:String)->bool:
 # Immunity prevents applying new control; it does not cleanse an existing stun.
 return phase=="combat" and (hero.stun_left>TIME_EPS or _control_motion_blocking) and not _ink_action_ignores_control(action)
func _hero_locomotion_allowed()->bool:
 return not _ink_action_controlled("movement")
func _step_player_locomotion(real_dt:float)->void:
 var blocked:float=real_dt if _ink_action_controlled("movement") else 0.0
 if _control_frame_active:
  # Shared core already decremented stun before locomotion. Use the captured
  # interval-start timer to avoid moving a full tick on the expiration boundary.
  var actor_dt:float=hero_time-_control_frame_clock
  blocked=minf(real_dt,_control_frame_left*real_dt/actor_dt) if actor_dt>TIME_EPS else (real_dt if _control_frame_left>TIME_EPS else 0.0)
 if blocked>TIME_EPS:
  var original_scope:Dictionary=_ink_scope()
  var prior_dash:Dictionary=_dash_state
  var distance:float=float(prior_dash.get("distance",0.0))
  _control_motion_blocking=true
  if not prior_dash.is_empty():prior_dash.distance=0.0
  # Action/iframe time still elapses. A controlled dash neither moves nor banks
  # a delayed displacement to replay after control ends.
  super._step_player_locomotion(blocked)
  _control_motion_blocking=false
  if not _ink_scope_current(original_scope):return
  if is_same(prior_dash,_dash_state) and not _dash_state.is_empty():_dash_state.distance=distance
 if real_dt-blocked>TIME_EPS:super._step_player_locomotion(real_dt-blocked)
func _hero_dash_spec()->Dictionary:return {"distance":v("D-1"),"duration":v("D-2"),"iframe_duration":v("D-3"),"cooldown":v("D-4"),"time_domain":"real"}
func start_dash(context:Dictionary)->Dictionary:
 # Supply the source-required mouse direction while preserving core dash service.
 var saved_move:Vector3=hero.move_intent
 hero.move_intent=_manual_direction
 context.direction=_manual_direction;hero.facing=_manual_direction
 var result:Dictionary=super.start_dash(context)
 hero.move_intent=saved_move
 return result
func start_basic(context:Dictionary,dash:bool=false)->Dictionary:
 if not effect_is_current(context):return {"accepted":false,"reason":"stale_cast"}
 context.direction=_manual_direction;hero.facing=_manual_direction
 var critical:bool=rng.randf()<clampf(float(hero.stats.crit_chance),0.0,1.0)
 var damage:float=hero.ad()*T.fraction("ATK-1")*(float(hero.stats.get("crit_damage",1.75)) if critical else 1.0)
 hero.cooldowns.attack=1.0/hero.attack_speed();hero.attack_index+=1
 if dash:dash_attack=context.duplicate(true)
 var state:Dictionary=_make_motion(context,[hero.position,hero.position+_manual_direction*float(hero.stats.attack_range)],v("ATK-4"),v("ATK-5"),damage,"dash_attack" if dash else "attack",critical)
 var equipment_birth_array:Array=ink_basics
 ink_basics.append(state)
 emit_event("ink_basic_released",_motion_public(state))
 var equipment_birth:Dictionary={"kind":"basic_birth","projectile":state,"states":equipment_birth_array,"context":context,"at":hero_time,"dispatch":_equipment_action_dispatch_frames.back() if not _equipment_action_dispatch_frames.is_empty() else {}}
 _equipment_sync_settlement_frames.append(equipment_birth)
 _settle_birth(ink_basics,true)
 assert(is_same(_equipment_sync_settlement_frames.back(),equipment_birth))
 _equipment_sync_settlement_frames.pop_back()
 return {"accepted":true,"projectile_id":state.wave_id}
func _hero_cast_skill(action:String,context:Dictionary)->Dictionary:
 if not effect_is_current(context):return {"accepted":false,"reason":"stale_cast"}
 if action!="q" or not _committing_q1 or ink_input.phase not in ["drawing","frozen"]:return {"accepted":false,"reason":"candidate_not_implemented"}
 var saved:Dictionary=ink_input.duplicate(true)
 var rank:int=int(saved.rank)
 var state:Dictionary=_make_motion(context,saved.path,v("Q1-5",rank),v("Q1-7",rank),v("Q1-1",rank)+float(hero.stats.ap)*T.fraction("Q1-2",rank),"q1",false)
 state["push_distance"]=v("Q1-3",rank);state["gesture_id"]=saved.gesture_id;state["rank"]=rank
 ink_waves.append(state)
 start_skill_cooldown("q",v("Q1-8",rank))
 ink_input={"phase":"idle","gesture_id":"","path":[],"cancel_reason":""}
 _equipment_release_committed("q1",state)
 emit_event("ink_q1_released",_motion_public(state).merged({"gesture_id":saved.gesture_id,"preview_only":false},true))
 _settle_birth(ink_waves,false)
 return {"accepted":true,"wave_id":state.wave_id,"gesture_id":saved.gesture_id}
func _make_motion(context:Dictionary,path:Array,width:float,speed:float,damage:float,source:String,critical:bool)->Dictionary:
 motion_serial+=1
 var state:Dictionary=context.duplicate(true)
 state.merge({"motion_serial":motion_serial,"direction":Geometry.frame_at(path,0.0).direction,"wave_id":"%d:%s:motion:%d"%[encounter_generation,room_id,motion_serial],"path":path.duplicate(true),"path_length":Geometry.path_length(path),"front_distance":0.0,"width":width,"speed":speed,"damage":damage,"source":source,"critical":critical,"released_at":hero_time,"hits":{},"front_position":path[0],"front_direction":Geometry.frame_at(path,0.0).direction,"segment_index":0},true)
 return state
func _enemy_motion_snapshot()->Dictionary:
 var before:Dictionary={}
 for enemy in enemies:before[enemy.actor_id]={"position":enemy.position,"state":enemy.state,"identity":enemy}
 return before
func _settle_birth(_states:Array,_basic:bool)->void:
 _settle_motion_interval(_enemy_motion_snapshot(),hero_time,hero_time)
func _fixed_step(real_dt:float)->void:
 # Exactly one shared clock/AI/common/RNG step. Boundaries are local receipts,
 # never extra calls to the world's fixed-step routine.
 var original_scope:Dictionary=_ink_scope()
 var before:Dictionary=_enemy_motion_snapshot()
 var tick_start:float=hero_time
 _control_frame_active=true;_control_frame_left=hero.stun_left;_control_frame_clock=hero_time
 super._fixed_step(real_dt)
 _control_frame_active=false
 ink_core_steps+=1
 if _ink_scope_current(original_scope):
  _freeze_time_if_due()
  _settle_motion_interval(before,tick_start,hero_time)
  _check_victory()
func _settle_motion_interval(before:Dictionary,tick_start:float,tick_end:float)->void:
 var candidates:Array=[]
 var advances:Array=[]
 for state in ink_basics+ink_waves:
  if not effect_is_current(state):continue
  var basic:bool=state.source in ["attack","dash_attack"]
  var interval_start:float=maxf(tick_start,float(state.released_at))
  var dt:float=maxf(0.0,tick_end-interval_start)
  var from_distance:float=float(state.front_distance)
  var to_distance:float=minf(float(state.path_length),from_distance+float(state.speed)*dt)
  var blocked:bool=false
  if basic:
   var destination:Vector3=Geometry.frame_at(state.path,to_distance).position
   var clipped:Vector3=_move_clipped(state.front_position,destination,float(state.width)*0.5)
   if clipped.distance_squared_to(destination)>Geometry.EPS*Geometry.EPS:
    to_distance=from_distance+Vector3(state.front_position).distance_to(clipped);blocked=true
  advances.append({"state":state,"distance":to_distance})
  for span in Geometry.spans(state.path,from_distance,to_distance):
   var local_a:float=(float(span.from)-from_distance)/maxf(Geometry.EPS,float(state.speed)*dt)
   var local_b:float=(float(span.to)-from_distance)/maxf(Geometry.EPS,float(state.speed)*dt)
   for enemy in enemies:
    var id:String=str(enemy.actor_id)
    if enemy.dead or enemy.state=="spawn" or state.hits.has(id) or not before.has(id):continue
    if not is_same(before[id].identity,enemy) or before[id].state=="spawn":continue
    var start:Vector3=Vector3(before[id].position).lerp(enemy.position,local_a)
    var end:Vector3=Vector3(before[id].position).lerp(enemy.position,local_b)
    var u:float=Geometry.moving_front_contact(span.start,span.end,span.direction,state.width,start,end,float(enemy.radius))
    if not is_finite(u):continue
    candidates.append({"kind":"contact","state":state,"enemy":enemy,"distance":lerpf(float(span.from),float(span.to),u),"position":Vector3(span.start).lerp(span.end,u),"target_position":start.lerp(end,u),"direction":span.direction,"time":interval_start+dt*lerpf(local_a,local_b,u),"segment_index":span.segment_index})
  if blocked or to_distance>=float(state.path_length)-Geometry.EPS:
   candidates.append({"kind":"terminal","state":state,"time":interval_start+(to_distance-from_distance)/float(state.speed),"distance":to_distance,"reason":"blocked" if blocked else "path_end","segment_index":Geometry.frame_at(state.path,to_distance).segment_index})
 # One queue across BASIC and Q1. Exact ties: contact before terminal, accepted
 # motion serial, stable target ID, source segment index. No per-family priority.
 candidates.sort_custom(_contact_before)
 for candidate in candidates:
  var state:Dictionary=candidate.state
  if not effect_is_current(state) or bool(state.get("retired",false)):continue
  if candidate.kind=="terminal":
   _set_front(state,float(candidate.distance))
   _retire_motion(state,float(candidate.time),str(candidate.reason))
   continue
  var enemy:Dictionary=candidate.enemy
  var id:String=str(enemy.actor_id)
  if enemy.dead or enemy.state=="spawn" or state.hits.has(id) or not is_same(enemy,enemy_by_id(id)):continue
  if int(enemy.generation)!=encounter_generation or str(enemy.room_id)!=room_id:continue
  var basic:bool=state.source in ["attack","dash_attack"]
  if not claim_hit(int(state.cast_id),id,"ink_basic" if basic else "ink_q1"):continue
  state.hits[id]=true
  state.front_distance=candidate.distance;state.front_position=candidate.position;state.front_direction=candidate.direction;state.segment_index=candidate.segment_index
  var receipt_id:String=str(state.wave_id)+":contact:"+id
  var receipt:Dictionary={"receipt_id":receipt_id,"cast_id":state.cast_id,"wave_id":state.wave_id,"target_id":id,"contact_position":candidate.position,"target_contact_position":candidate.target_position,"contact_time":candidate.time,"direction":candidate.direction,"segment_index":candidate.segment_index,"source":state.source,"room_id":room_id,"generation":encounter_generation,"released_at":state.released_at,"path_length":state.path_length,"segment_id":str(state.wave_id)+":segment:"+str(candidate.segment_index)}
  var metadata:Dictionary={"effect_id":receipt_id,"generation":encounter_generation,"room_id":room_id,"position":candidate.position,"direction":candidate.direction,"saved_aim":state.direction,"basic_attack":basic,"active_skill":not basic,"area":not basic,"direct":true,"ink_receipt":receipt}
  _equipment_skill_damage("q1",state,enemy,float(state.damage),state.source,int(state.cast_id),false,bool(state.critical),metadata)
  if not effect_is_current(state):continue
  if not basic and not enemy.dead:
   var g01_push_before:Dictionary=enemy.push
   push_enemy(enemy,candidate.direction,float(state.push_distance),"q1",int(state.cast_id),0.0,float(tuning.q1_push_duration_s),0.0)
   _equipment_push_bound("q1",state,enemy,g01_push_before,enemy.push)
  if basic:_retire_motion(state,float(candidate.time),"contact")
 for advance in advances:
  var state:Dictionary=advance.state
  if effect_is_current(state) and not bool(state.get("retired",false)):_set_front(state,float(advance.distance))
 ink_basics=ink_basics.filter(func(s):return effect_is_current(s) and not bool(s.get("retired",false)))
 ink_waves=ink_waves.filter(func(s):return effect_is_current(s) and not bool(s.get("retired",false)))
func _contact_before(a:Dictionary,b:Dictionary)->bool:
 if float(a.time)!=float(b.time):return float(a.time)<float(b.time)
 if a.kind!=b.kind:return a.kind=="contact"
 if int(a.state.motion_serial)!=int(b.state.motion_serial):return int(a.state.motion_serial)<int(b.state.motion_serial)
 var left:String=str(a.get("enemy",{}).get("actor_id",""))
 var right:String=str(b.get("enemy",{}).get("actor_id",""))
 return int(a.segment_index)<int(b.segment_index) if left==right else left<right
func _set_front(state:Dictionary,distance:float)->void:
 state.front_distance=distance
 var front:Dictionary=Geometry.frame_at(state.path,distance)
 state.front_position=front.position;state.front_direction=front.direction;state.segment_index=front.segment_index
func _retire_motion(state:Dictionary,at:float,reason:String)->void:
 state["retired"]=true
 finish_cast(int(state.cast_id))
 if not effect_is_current(state):return
 var finished:Dictionary=_motion_public(state)
 finished["finished_at"]=at;finished["settled_at"]=hero_time;finished["reason"]=reason
 ink_finished.append(finished)
 if ink_finished.size()>32:ink_finished.pop_front()
 emit_event("ink_q1_finished" if state.source=="q1" else "ink_basic_finished",finished)
func _hero_after_damage(_enemy:Dictionary,event:Dictionary,actual:float)->void:
 if not event.has("ink_receipt"):return
 if not effect_is_current(event.ink_receipt):return
 var receipt:Dictionary=event.ink_receipt.duplicate(true)
 receipt["actual_damage"]=actual;receipt["critical"]=bool(event.get("critical",false));receipt["settled_at"]=hero_time
 ink_receipts.append(receipt)
 if ink_receipts.size()>128:ink_receipts.pop_front()
 emit_event("ink_q1_contact" if receipt.source=="q1" else "ink_basic_contact",receipt)
func _hero_victory_pending()->bool:return not ink_waves.is_empty() or not ink_basics.is_empty()
func cancel_cast(id:int)->void:
 super.cancel_cast(id)
 ink_waves=ink_waves.filter(func(s):return int(s.cast_id)!=id)
 ink_basics=ink_basics.filter(func(s):return int(s.cast_id)!=id)
func _hero_clear_transients()->void:
 hero.stun_left=0.0
 _control_frame_active=false;_control_motion_blocking=false
 cancel_ink_preview("encounter_ended")
 ink_waves.clear();ink_basics.clear();ink_receipts.clear();ink_finished.clear()
func _hero_hex_status(id:String)->Dictionary:
 if id=="yanguizhou_h01":return {"active":hero.loadout.q=="q1" and int(hero.ranks.q)>0,"reason":"" if hero.loadout.q=="q1" and int(hero.ranks.q)>0 else "requires_Q1"}
 return {"active":false,"reason":"outside_q1_foundation"}
func common_damage_metadata(source:String)->Dictionary:
 return {"active_skill":source=="q1","basic_attack":source in ["attack","dash_attack"],"direct":true,"area":source=="q1","hex_generated":source.begins_with("common_")}
func _motion_public(state:Dictionary)->Dictionary:
 var result:Dictionary={}
 for key in ["cast_id","wave_id","path","path_length","front_distance","front_position","front_direction","segment_index","width","speed","released_at","source","generation","room_id"]:result[key]=state[key]
 result["travel_fraction"]=clampf(float(state.front_distance)/maxf(Geometry.EPS,float(state.path_length)),0.0,1.0)
 result["hit_target_ids"]=state.hits.keys()
 return result.duplicate(true)
func ink_presenter_snapshot()->Dictionary:
 var input:Dictionary=ink_input.duplicate(true)
 input["draw_elapsed"]=clampf((float(input.frozen_at) if input.get("frozen_at",-1.0)>=0 else hero_time)-float(input.get("started_at",hero_time)),0.0,float(input.get("draw_limit",0.0)))
 input["draw_fraction"]=float(input.draw_elapsed)/maxf(Geometry.EPS,float(input.get("draw_limit",0.0)))
 input["draw_limit"]=input.get("draw_limit",v("Q1-6",maxi(1,int(hero.ranks.q))))
 input["width"]=input.get("width",v("Q1-5",maxi(1,int(hero.ranks.q))))
 input["placement_range"]=float(tuning.q1_initial_placement_range_m)
 input["placement_range_status"]="provisional_independent_test_value_not_source"
 input["start"]=input.get("start",Vector3.ZERO);input["freeze_reason"]=input.get("freeze_reason","")
 return {"schema":"ink-q1-presenter-1","scope":{"room_id":room_id,"generation":encounter_generation},"world_time":clock.world_time,"hero_time":hero_time,"source_time":hero_time,"revision":revision,"rules_hash":source_rules_hash,"hero":{"position":hero.position,"facing":hero.facing,"move_intent":hero.move_intent,"dash_left":hero.dash_left},"input":input,"waves":ink_waves.map(func(s):return _motion_public(s)),"basics":ink_basics.map(func(s):return _motion_public(s)),"receipts":ink_receipts.duplicate(true),"finished":ink_finished.duplicate(true)}.duplicate(true)
func _hero_snapshot()->Dictionary:
 return {"ink":ink_presenter_snapshot(),"ink_foundation_scope":"BASIC_Shift_Q1_H01_only_not_normal_entry","ink_unsupported":tuning.unsupported.duplicate(true)}

func initial_source_hero_stats()->Dictionary:
 # One private source snapshot per Sim construction; callers receive a fresh copy.
 # Catalog parameters remain live through the original tuning helper.
 return T.hero_stats_from_runtime(_initial_runtime_snapshot)
