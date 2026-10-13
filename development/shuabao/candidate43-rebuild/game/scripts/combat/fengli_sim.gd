extends "res://scripts/combat/hero_combat_core.gd"
## Wind final-design runtime. Implemented candidates own real source state machines.
## Remaining candidates stay explicitly unavailable. Never inherits Xuanlei skills.
const T=preload("res://data/combat/fengli_tuning.gd")
const Ultimates=preload("res://scripts/combat/fengli_ultimates.gd")
var ultimates=Ultimates.new(self)
const WindHero=preload("res://scripts/actors/fengli_final_model.gd")
var q1_casts:Dictionary={}
var _wind_kill_credits:Dictionary={}
var wind_projectiles:Array=[]
var _q3_recoveries:Array=[]
var _q3_charges_initialized:bool=false
func _init()->void:
 hero=WindHero.new()
 arena_half_extent=float(T.runtime().arena_half_extent)
 hero_radius=float(T.runtime().player_radius)
 room_id="fengli-room-1";combat_level_id=room_id
func v(token:String,rank:int=1)->float:return T.parameter(token,rank)
func f(token:String,rank:int=1)->float:return T.fraction(token,rank)
func hv(id:String,index:int=1)->float:return T.hex_value(id,index)
func hf(id:String,index:int=1)->float:return T.hex_fraction(id,index)
func wind_hex(id:String)->bool:
 var canonical:String=T.hex_id(id)
 return canonical in hero.hexes and bool(_hero_hex_status(canonical).get("active",false))
func _hero_action_policy(action:String, _aim:Vector3=Vector3.INF)->Dictionary:
 if hero.cast_state.has("r1"):return {"reason":"ultimate_presentation"}
 if hero.cast_state.has("e1_pierce"):return {"reason":"piercing"}
 if hero.cast_state.has("q2"):
  return {"reason":"charging"}
 var ultimate_policy:Dictionary=ultimates.policy(action)
 if not ultimate_policy.is_empty():return ultimate_policy
 if action=="e" and hero.loadout.e=="e1" and hero.ranks.e>0:return _e1_action_policy(_aim)
 if action=="e" and hero.loadout.e=="e3" and hero.ranks.e>0 and _e3_active():return {"reason":"already_active"}
 if action=="e" and hero.loadout.e=="e2" and hero.ranks.e>0:
  if hero.cast_state.has("e2_shadow"):
   var shadow:Dictionary=hero.cast_state.e2_shadow
   if float(shadow.left)>TIME_EPS and int(shadow.generation)==encounter_generation and _wind_point_legal(shadow.position):
    return {"bypass_cooldown":true,"bypass_lock":true,"cast_id":shadow.cast_id,"stage":"return"}
   return {"reason":"illegal_return"}
  if hero.cast_state.has("e2_spin"):return {"reason":"action_locked"}
 if action=="q" and hero.loadout.q=="q3" and hero.ranks.q>0:
  _sync_q3_charges()
  if _q3_available()<=0:return {"reason":"no_charges"}
  return {"bypass_cooldown":true}
 if action=="q" and hero.loadout.q=="q2" and hero.ranks.q>0:
  var target:Dictionary=_wind_target(v("Q2-1",hero.ranks.q),_aim)
  if target.is_empty():return {"reason":"no_target"}
  if not _wind_point_legal(_q2_landing(target,hero.ranks.q)):return {"reason":"illegal_landing"}
 if action=="shift":
  var pending_basic:bool=pending.any(func(e):return e.kind=="core_basic" and not e.get("dash",false))
  if pending_basic:return {"bypass_lock":true,"cancel_basic":true}
 if action in ["q","e","r"] and not ((action=="q" and hero.loadout.q in ["q1","q2","q3"]) or (action=="e" and hero.loadout.e in ["e1","e2","e3"]) or (action=="r" and hero.loadout.r in ["r1","r2"])):
  return {"reason":"candidate_not_implemented"}
 return {}
func _hero_cast_skill(action:String,context:Dictionary)->Dictionary:
 if action=="r":return ultimates.start(context)
 if action=="e" and hero.loadout.e=="e1":return _start_e1(context)
 if action=="e" and hero.loadout.e=="e3":return _start_e3(context)
 if action=="e" and hero.loadout.e=="e2":return _start_e2(context)
 if action=="q" and hero.loadout.q=="q3":return _start_q3(context)
 if action=="q" and hero.loadout.q=="q2":return _start_q2(context)
 if action!="q" or hero.loadout.q!="q1":return {"accepted":false,"reason":"candidate_not_implemented"}
 var rank:int=int(hero.ranks.q)
 var stacks:int=hero.q1_stacks
 var length:float=v("Q1-3",rank)*(1.0+f("Q1-9",rank)*stacks)
 var damage:float=(v("Q1-1",rank)+hero.permanent_q1_damage+hero.ad()*f("Q1-2",rank))*(1.0+f("Q1-8",rank)*stacks)
 var total:float=v("Q1-5",rank)
 var contact:float=float(T.runtime().skills.Q1.contact_after)
 start_skill_cooldown("q",v("Q1-11",rank))
 hero.lock_time=maxf(hero.lock_time,total)
 q1_casts[context.cast_id]={"rank":rank,"hits":0,"kills":0,"stacks_before":stacks,"resolved":false}
 schedule_effect(context,"wind_q1_motion",float(T.animation("q1").get("phase_markers_s",{}).get("anticipation_end",4.0/60.0)),{"length":length,"width":v("Q1-4",rank),"stacks":stacks})
 schedule_effect(context,"wind_q1_contact",contact,{"rank":rank,"damage":damage,"length":length,"width":v("Q1-4",rank),"stacks":stacks})
 schedule_effect(context,"wind_q1_end",total)
 emit_event("q1_started",{"cast_id":context.cast_id,"position":hero.position,"direction":context.direction,"duration":total,"contact_after":contact,"length":length,"width":v("Q1-4",rank),"stacks":stacks})
 return {"accepted":true}
func _hero_resolve_effect(effect:Dictionary)->void:
 if str(effect.kind).begins_with("wind_r"):
  ultimates.resolve(effect);return
 if effect.kind=="wind_e1_release":_release_e1(effect);return
 if str(effect.kind).begins_with("wind_e2_"):_resolve_e2(effect);return
 if effect.kind in ["wind_basic_motion","wind_q1_motion"]:
  if not effect_is_current(effect) or hero.dead:return
  var cue:Dictionary=effect.duplicate(true);cue.position=hero.position
  emit_event("q1_motion" if effect.kind=="wind_q1_motion" else "dash_attack_motion" if effect.get("dash",false) else "attack_motion",cue)
  return
 if effect.kind=="wind_q3_launch":
  _launch_q3(effect);return
 if effect.kind=="wind_q1_end":
  finish_cast(effect.cast_id);q1_casts.erase(effect.cast_id);return
 if effect.kind!="wind_q1_contact" or not q1_casts.has(effect.cast_id):return
 if q1_casts[effect.cast_id].resolved:return
 q1_casts[effect.cast_id].resolved=true
 var origin:Vector3=hero.position
 var targets:Array=rectangle_targets(origin,effect.direction,effect.length,effect.width)
 var killed:int=0
 var hit_ids:Array=[]
 for target in targets:
  if not claim_hit(effect.cast_id,target.actor_id,"q1_thrust"):continue
  var was_alive:bool=not target.dead
  var lethal:bool=damage_enemy(target,effect.damage,"q1",effect.cast_id,false,false,{"position":origin,"cast_origin":origin,"direction":effect.direction,"cast_damage_share":1.0/maxi(1,targets.size()),"replay_segment":{"target_mode":"spatial","segment_id":"thrust","shape":{"kind":"rectangle","direction":effect.direction,"length":effect.length,"width":effect.width}}})
  hit_ids.append(target.actor_id)
  if was_alive and lethal:
   killed+=1
   if wind_hex("h01") and not hero.q1_kill_ids.has(target.actor_id):
    hero.q1_kill_ids[target.actor_id]=true;hero.permanent_q1_damage+=hv("h01")
 if targets.is_empty():common.record_spatial(effect.cast_id,"thrust",effect.damage*hero.stats.get("common_damage_multiplier",1.0),origin,{"kind":"rectangle","direction":effect.direction,"length":effect.length,"width":effect.width})
 if not hit_ids.is_empty():
  hero.cooldowns.q*=1.0-f("Q1-6",effect.rank) # Remaining CD, once for the full cast.
  if wind_hex("h02"):hero.cast_state.h02={"left":hv("h02",2),"until":hero_time+hv("h02",2)}
 if killed>0:
  hero.cooldowns.q=0.0
  hero.q1_stacks=mini(int(v("Q1-10",effect.rank)),hero.q1_stacks+int(v("Q1-7",effect.rank)))
 else:hero.q1_stacks=0
 q1_casts[effect.cast_id].hits=hit_ids.size();q1_casts[effect.cast_id].kills=killed
 emit_event("q1_impact",{"cast_id":effect.cast_id,"position":origin,"direction":effect.direction,"length":effect.length,"width":effect.width,"stacks":effect.stacks,"next_stacks":hero.q1_stacks,"hit_count":hit_ids.size(),"kill_count":killed,"target_ids":hit_ids})
func _hero_step(_world_dt:float,_real_dt:float)->void:
 ultimates.step()
 if hero.cast_state.has("e2_spin"):hero.cast_state.e2_spin.left=maxf(0.0,float(hero.cast_state.e2_spin.until)-hero_time)
 if hero.cast_state.has("e2_shadow"):
  hero.cast_state.e2_shadow.left=maxf(0.0,float(hero.cast_state.e2_shadow.until)-hero_time)
  if float(hero.cast_state.e2_shadow.left)<=TIME_EPS:
   var expired:Dictionary=hero.cast_state.e2_shadow;hero.cast_state.erase("e2_shadow")
   emit_event("e2_shadow_expired",{"cast_id":expired.cast_id,"position":expired.position,"reason":"duration"})
 _step_q3_charges(_world_dt)
 _step_q3_projectiles()
 _step_e1(_world_dt)
 if hero.cast_state.has("q2"):_step_q2(_world_dt)
func _hero_basic_payload(context:Dictionary,dash:bool)->Dictionary:
 var clip:String="dash_attack" if dash else "attack"
 var timing:Array=T.timing(clip)
 var timing_scale:float=1.0 if dash else v("ATK-2")/maxf(TIME_EPS,hero.attack_speed())
 var contact:float=float(timing[0])*timing_scale
 var duration:float=float(timing[1])*timing_scale
 var motion:float=float(T.animation(clip).get("phase_markers_s",{}).get("release",.05 if dash else .15))*timing_scale
 schedule_effect(context,"wind_basic_motion",motion,{"source":"dash_attack" if dash else "attack","dash":dash,"combo":hero.attack_index+1},"real" if dash else "hero")
 var critical:bool=rng.randf()<hero.critical_chance()
 var amount:float=hero.ad()*(float(T.runtime().dash_attack.ad_multiplier) if dash else f("ATK-1"))*(float(T.runtime().critical_multiplier) if critical else 1.0)
 return {"damage":amount,"contact_after":contact,"recovery":duration-contact,"duration":duration,"critical":critical,"shape":{"kind":"cone","radius":float(T.runtime().dash_attack.reach) if dash else float(hero.stats.attack_range),"degrees":float(T.runtime().dash_attack.degrees) if dash else float(T.runtime().basic_shape.degrees)},"swept":dash,"follow_origin":true,"time_domain":"real" if dash else "hero"}
func _hero_dash_spec()->Dictionary:
 return {"distance":v("D-1"),"duration":v("D-2"),"iframe_duration":v("D-3"),"cooldown":v("D-4")*(1.0-f("E3-6",int(hero.cast_state.e3.rank)) if _e3_active() else 1.0)}
func _hero_lifesteal_rate(event:Dictionary)->float:
 return hero.basic_lifesteal() if event.get("basic_attack",false) else hero.lifesteal()
func _hero_lifesteal_factor(event:Dictionary)->float:
 return 1.0 if event.get("basic_attack",false) else .4 if event.get("active_skill",false) else super._hero_lifesteal_factor(event)
func _hero_animation(kind:String,event:Dictionary)->Dictionary:
 var clip:String={"attack_started":"attack","dash":"dash","dash_attack_started":"dash_attack","q1_started":"q1","q3_started":"q3","e1_started":"e1_throw","e1_pierce_started":"e1_pierce"}.get(kind,"")
 if clip.is_empty():return {}
 var timing:Array=T.timing(clip)
 var duration:float=float(event.get("duration",timing[1]))
 return {"animation":{"clip":clip,"authored_contact":timing[0],"authored_duration":timing[1],"contact_after":float(event.get("contact_after",timing[0])),"recovery":maxf(0,duration-float(event.get("contact_after",timing[0]))),"time_domain":"real" if kind in ["dash","dash_attack_started"] else "hero"},"duration":duration}
func _hero_hex_status(id:String)->Dictionary:
 var canonical:String=T.hex_id(id)
 if canonical in ["fengli_h15","fengli_h16"]:return {"active":canonical in hero.hexes and hero.loadout.r=="r1" and hero.ranks.r>0,"reason":"需要乱星斩"}
 if canonical in ["fengli_h17","fengli_h18","fengli_h19"]:return {"active":canonical in hero.hexes and hero.loadout.r=="r2" and hero.ranks.r>0,"reason":"需要骨钉雨"}
 if canonical in ["fengli_h07","fengli_h08","fengli_h09"]:return {"active":canonical in hero.hexes and hero.loadout.e=="e1" and hero.ranks.e>0,"reason":"需要匕首标记·二段穿刺"}
 if canonical in ["fengli_h13","fengli_h14"]:return {"active":canonical in hero.hexes and hero.loadout.e=="e3" and hero.ranks.e>0,"reason":"需要超载"}
 if canonical in ["fengli_h10","fengli_h11","fengli_h12"]:return {"active":canonical in hero.hexes and hero.loadout.e=="e2" and hero.ranks.e>0,"reason":"需要旋斩瞬移"}
 if canonical not in ["fengli_h01","fengli_h02","fengli_h03","fengli_h04","fengli_h05","fengli_h06"]:return {"active":false,"reason":"尚未接入此候选的最终机制"}
 var candidate:String="q1" if canonical in ["fengli_h01","fengli_h02"] else "q2" if canonical in ["fengli_h03","fengli_h04"] else "q3"
 return {"active":canonical in hero.hexes and hero.loadout.q==candidate and hero.ranks.q>0,"reason":"需要对应Q候选"}
func common_action_metadata(slot:String,stage:String="")->Dictionary:
 var data:Dictionary=super.common_action_metadata(slot,stage)
 data.active_movement=slot=="shift" or (slot=="q" and hero.loadout.q=="q2") or (slot=="e" and hero.loadout.e in ["e1","e2"])
 return data
func common_damage_metadata(source:String)->Dictionary:
 var data:Dictionary=super.common_damage_metadata(source)
 data.active_skill=source in ["q1","q2","q3","e1_dagger","e1_pierce","e2","e2_extra","r1","r2_nail"]
 data.area=source in ["q1","q3","e1_pierce","e2","e2_extra","r1","r2_nail","attack","dash_attack"]
 return data
func _hero_clear_transients()->void:
 ultimates.clear()
 if hero.cast_state.has("e1"):_finish_e1("encounter_closed",false,false)
 hero.cast_state.erase("h09")
 if hero.dead and hero.cast_state.has("e3"):_end_e3("death")
 _wind_kill_credits.clear()
 hero.cast_state.erase("e2_spin");hero.cast_state.erase("e2_shadow")
 for wave_state in wind_projectiles.duplicate():_expire_q3(wave_state,"encounter_closed",false)
 q1_casts.clear();hero.q1_kill_ids.clear()
 if hero.cast_state.has("q2"):
  var state:Dictionary=hero.cast_state.q2
  _wind_stop_displacement(state)
  start_skill_cooldown("q",v("Q2-8",state.rank))
  hero.cast_state.erase("q2");hero.untargetable=false
func _hero_snapshot()->Dictionary:
 _sync_q3_charges()
 var result:Dictionary={"definition_version":T.VERSION,"wind_projectiles":wind_projectiles.duplicate(true),"wind_mark":_e1_mark_snapshot(),"wind_phantom":hero.cast_state.get("e2_shadow",{}).duplicate(true),"wind_charges":{"q3":{"available":_q3_available(),"capacity":_q3_capacity(),"recoveries":_q3_recoveries.duplicate(),"next_recovery":float(_q3_recoveries.min()) if not _q3_recoveries.is_empty() else 0.0}}}
 result.merge(ultimates.snapshot(),true)
 return result
func _hero_status_effects()->Array:
 var out:Array=[]
 if _e3_active():out.append({"id":"fengli_e3","name":"超载","kind":"buff","stacks":1,"remaining":hero.cast_state.e3.left,"description":"攻速、移速与韧性提高；普攻追加真实伤害"})
 if hero.loadout.passive=="p3" and hero.ranks.passive>0:out.append({"id":"fengli_p3","name":"杀意淬锋","kind":"buff","stacks":hero.p3_progress,"remaining":-1.0,"description":"永久攻击力 +%d；下一次成长击杀进度 %d/%d"%[hero.permanent_ad,hero.p3_progress,int(v("P3-1",hero.ranks.passive))]})
 if hero.cast_state.has("e2_shadow"):out.append({"id":"fengli_h10","name":"留影","kind":"buff","stacks":1,"remaining":hero.cast_state.e2_shadow.left,"description":"再次使用E返回不可选中的虚影位置"})
 if hero.q1_stacks>0:out.append({"id":"fengli_q1_chain","name":"连杀剑势","kind":"buff","stacks":hero.q1_stacks,"remaining":-1.0,"description":"下一次连杀突刺增加伤害与长度；未造成击杀则清空"})
 if hero.cast_state.has("h09"):out.append({"id":"fengli_h09","name":"穿影余势","kind":"buff","stacks":1,"remaining":hero.cast_state.h09.left,"description":"攻速提高25%，持续3秒"})
 if hero.cast_state.has("e1_mark"):out.append({"id":"fengli_e1_mark","name":"匕首标记","kind":"buff","stacks":1,"remaining":hero.cast_state.e1_mark.remaining,"description":"再次释放E选择标记目标周围合法落点并穿刺"})
 if hero.cast_state.has("h02"):out.append({"id":"fengli_h02","name":"杀意未歇","kind":"buff","stacks":1,"remaining":hero.cast_state.h02.left,"description":"攻速提高18%，命中/击杀刷新但不叠加"})
 return out

func _wind_target(radius:float,aim:Vector3)->Dictionary:
 var point:Vector3=hero.aim_point if not aim.is_finite() else aim
 var candidates:Array=circle_targets(hero.position,radius).filter(func(t):return t.state!="spawn")
 candidates.sort_custom(func(a,b):
  var da:float=a.position.distance_squared_to(point);var db:float=b.position.distance_squared_to(point)
  return str(a.actor_id)<str(b.actor_id) if is_equal_approx(da,db) else da<db)
 return candidates[0] if not candidates.is_empty() else {}
func _start_q2(context:Dictionary)->Dictionary:
 var rank:int=int(hero.ranks.q)
 var first:Dictionary=_wind_target(v("Q2-1",rank),hero.aim_point)
 if first.is_empty():return {"accepted":false,"reason":"no_target"}
 hero.cast_state.q2={"rank":rank,"cast_id":context.cast_id,"generation":encounter_generation,"target_id":first.actor_id,"origin":hero.position,"duration":v("Q2-6",rank),"elapsed":0.0,"count":0,"hits":{},"kills":0,"ad":hero.ad(),"last_position":first.position,"last_facing":first.get("facing",Vector3.FORWARD),"last_legal_position":hero.position}
 hero.untargetable=true;hero.cooldowns.q=0.0
 emit_event("q2_started",{"cast_id":context.cast_id,"position":hero.position,"target_id":first.actor_id,"duration":v("Q2-6",rank)})
 emit_event("q2_strike_started",{"cast_id":context.cast_id,"origin":hero.position,"destination":first.position,"target_id":first.actor_id,"duration":v("Q2-6",rank),"strike":1})
 return {"accepted":true}
func _step_q2(dt:float)->void:
 var state:Dictionary=hero.cast_state.q2
 var target:Dictionary=enemy_by_id(state.target_id)
 if target.is_empty() or target.dead or state.generation!=encounter_generation or not cast_is_current(state.cast_id):
  _finish_q2(false);return
 if not _wind_point_legal(_q2_landing(target,state.rank)):
  _finish_q2(false);return
 state.elapsed+=dt
 var travel_direction:Vector3=state.origin.direction_to(target.position)
 if travel_direction.length_squared()>.001:hero.facing=travel_direction
 state.last_position=target.position;state.last_facing=target.get("facing",Vector3.FORWARD)
 var next_position:Vector3=state.origin.lerp(target.position,clampf(state.elapsed/state.duration,0.0,1.0))
 # User resolution 20261003: walls along a Q2 displacement do not clip travel.
 hero.position=next_position
 if _wind_point_legal(hero.position):state.last_legal_position=hero.position
 if state.elapsed+TIME_EPS<state.duration:return
 var previous:int=int(state.hits.get(target.actor_id,0))
 var repeat_factor:float=hf("h04",2) if previous>0 and wind_hex("h04") else 1.0
 var amount:float=(v("Q2-2",state.rank)+state.ad*f("Q2-3",state.rank))*(1.0+hf("h03")*state.kills if wind_hex("h03") else 1.0)*repeat_factor
 state.hits[target.actor_id]=previous+1;state.count+=1
 var lethal:bool=damage_enemy(target,amount,"q2",state.cast_id,false,false,{"position":target.position,"cast_origin":state.origin,"direction":state.origin.direction_to(target.position),"replay_segment":{"target_mode":"bound","segment_id":"assault_strike","occurrence":state.count}})
 if lethal:state.kills+=1
 emit_event("q2_strike",{"cast_id":state.cast_id,"position":target.position,"target_id":target.actor_id,"strike":state.count,"repeat":previous>0,"damage":amount,"killed":lethal})
 if state.count>=int(v("Q2-5",state.rank)):_finish_q2();return
 var cap:int=int(hv("h04")) if wind_hex("h04") else 1
 var choices:Array=circle_targets(target.position,v("Q2-4",state.rank)).filter(func(t):return t.state!="spawn" and int(state.hits.get(t.actor_id,0))<cap and _wind_point_legal(_q2_landing(t,state.rank)))
 choices.sort_custom(func(a,b):
  var ac:int=int(state.hits.get(a.actor_id,0));var bc:int=int(state.hits.get(b.actor_id,0))
  if (ac==0)!=(bc==0):return ac==0
  var da:float=a.position.distance_squared_to(target.position);var db:float=b.position.distance_squared_to(target.position)
  return str(a.actor_id)<str(b.actor_id) if is_equal_approx(da,db) else da<db)
 if choices.is_empty():_finish_q2();return
 state.origin=hero.position;state.target_id=choices[0].actor_id;state.elapsed=0.0
 emit_event("q2_strike_started",{"cast_id":state.cast_id,"origin":hero.position,"destination":choices[0].position,"target_id":choices[0].actor_id,"duration":state.duration,"strike":state.count+1})
func _finish_q2(land:bool=true)->void:
 if not hero.cast_state.has("q2"):return
 var state:Dictionary=hero.cast_state.q2
 if land and state.count>0:
  var facing:Vector3=state.last_facing.normalized()
  if facing.length_squared()<.001:facing=hero.facing
  var destination:Vector3=state.last_position-facing*v("Q2-7",state.rank)
  if _wind_point_legal(destination):hero.position=destination
 _wind_stop_displacement(state)
 hero.cast_state.erase("q2");hero.untargetable=false
 start_skill_cooldown("q",v("Q2-8",state.rank))
 if int(state.count)>0:common.movement_complete(state.cast_id)
 finish_cast(state.cast_id)
 emit_event("q2_finished",{"cast_id":state.cast_id,"position":hero.position,"strikes":state.count,"kills":state.kills})
func _q2_landing(target:Dictionary,rank:int)->Vector3:
 var facing:Vector3=Vector3(target.get("facing",Vector3.FORWARD)).normalized()
 if facing.length_squared()<.001:facing=hero.facing
 return Vector3(target.position)-facing*v("Q2-7",rank)
func _wind_stop_displacement(state:Dictionary)->void:
 # A cancelled through-wall path must never leave a free-moving hero inside cover.
 # Do not sweep the rollback: it is recovery to the last legal sample, not a hit.
 if _wind_point_legal(hero.position):return
 var fallback:Vector3=state.get("last_legal_position",state.get("origin",hero.position))
 if not _wind_point_legal(fallback):
  for _i in range(8):fallback=clamp_position(fallback,hero_radius)
 hero.position=fallback
func _hero_locomotion_allowed()->bool:return not hero.cast_state.has("q2") and not hero.cast_state.has("e1_pierce")


func _q3_capacity()->int:return int(hv("h05")) if wind_hex("h05") else 1
func _q3_available()->int:return maxi(0,_q3_capacity()-_q3_recoveries.size())
func _sync_q3_charges()->void:
 if hero.loadout.q!="q3":return
 if not _q3_charges_initialized:
  _q3_charges_initialized=true
  if float(hero.cooldowns.q)>TIME_EPS:_q3_recoveries.append(float(hero.cooldowns.q))
 _q3_recoveries.sort()
 hero.cooldowns.q=float(_q3_recoveries[0]) if _q3_available()==0 and not _q3_recoveries.is_empty() else 0.0
func _step_q3_charges(dt:float)->void:
 if not _q3_charges_initialized:return
 for i in range(_q3_recoveries.size()):_q3_recoveries[i]=maxf(0.0,float(_q3_recoveries[i])-dt)
 _q3_recoveries=_q3_recoveries.filter(func(left):return float(left)>TIME_EPS)
 _sync_q3_charges()
func _hero_reset_cooldowns(slots:Array)->void:
 if "q" in slots and hero.ranks.q>0:
  _q3_recoveries.clear()
  _sync_q3_charges()
func set_hexes(ids:Array)->void:
 super.set_hexes(ids)
 # Capacity can change, but already-spent charges keep their original deadlines.
 _sync_q3_charges()
func _start_q3(context:Dictionary)->Dictionary:
 var rank:int=int(hero.ranks.q)
 var timing:Dictionary=T.runtime().skills.Q3
 var cooldown:float=v("Q3-9",rank)*(1.0+hf("h05",2) if wind_hex("h05") else 1.0)
 _q3_recoveries.append(effective_cd(common.base_cooldown("q",cooldown)))
 _sync_q3_charges()
 hero.lock_time=maxf(hero.lock_time,float(timing.contact_after)+float(timing.action_commitment_after_release))
 var state:Dictionary={"rank":rank,"damage":v("Q3-1",rank)+hero.ad()*f("Q3-2",rank),"length":v("Q3-5",rank),"width":v("Q3-6",rank),"speed":v("Q3-7",rank),"push_distance":v("Q3-3",rank),"push_duration":v("Q3-4",rank),"stun_duration":hv("h06") if wind_hex("h06") else 0.0,"started_at":clock.world_time,"saved_aim":hero.aim_point}
 schedule_effect(context,"wind_q3_launch",float(timing.contact_after),state)
 emit_event("q3_started",{"cast_id":context.cast_id,"origin":context.origin,"position":context.origin,"direction":context.direction,"contact_after":timing.contact_after,"duration":timing.duration,"length":state.length,"width":state.width})
 return {"accepted":true}
func _launch_q3(effect:Dictionary)->void:
 if not effect_is_current(effect):return
 if hero.dead:cancel_cast(effect.cast_id);return
 var state:Dictionary={"id":"sword_wave:%d:%d"%[encounter_generation,effect.cast_id],"type":"sword_wave","cast_id":effect.cast_id,"position":hero.position,"origin":hero.position,"direction":effect.direction,"width":effect.width,"speed":effect.speed,"remaining":effect.length,"travelled":0.0,"range":effect.length,"hit_ids":[],"rank":effect.rank,"generation":effect.generation,"room_id":effect.room_id,"damage":effect.damage,"push_distance":effect.push_distance,"push_duration":effect.push_duration,"stun_duration":effect.stun_duration,"started_at":effect.started_at,"saved_aim":effect.saved_aim,"last_step_at":clock.world_time,"occurrence":0}
 wind_projectiles.append(state)
 emit_event("q3_launched",{"id":state.id,"cast_id":state.cast_id,"position":state.position,"origin":state.origin,"direction":state.direction,"speed":state.speed,"remaining":state.remaining,"width":state.width})
func _step_q3_projectiles()->void:
 for state in wind_projectiles.duplicate():
  if state.get("type","")!="sword_wave":continue
  if hero.dead or not effect_is_current(state):
   _expire_q3(state,"cancelled",false);continue
  var dt:float=maxf(0.0,clock.world_time-float(state.last_step_at))
  state.last_step_at=clock.world_time
  if dt<=TIME_EPS:continue
  var origin:Vector3=state.position
  var requested:float=minf(float(state.remaining),float(state.speed)*dt)
  var barrier:Dictionary=SweptRectangle.clip_front(origin,state.direction,state.remaining,state.width,obstacles,arena_half_extent)
  var clipped:Dictionary=barrier if float(barrier.distance)<=requested+TIME_EPS else {"position":origin+state.direction*requested,"distance":requested,"blocked":false,"reason":""}
  var length:float=clipped.distance
  state.occurrence+=1
  var shape:Dictionary={"kind":"rectangle","direction":state.direction,"length":length,"width":state.width,"circle_rectangle":true,"clipped_front":clipped.blocked}
  # Preserve the stopping plane even before the terminal sweep. Otherwise target
  # radius could reach backward through thin cover during a preceding slice.
  if barrier.blocked:shape["forward_limit"]=barrier.distance
  var targets:Array=shape_targets(origin,state.direction,shape).filter(func(t):return t.actor_id not in state.hit_ids)
  var extra:Dictionary={"occurrence":state.occurrence,"replay_hit_group":"sword_wave_contact","replay_hit_limit":1,"relative_time":clock.world_time-float(state.started_at),"saved_aim":state.saved_aim}
  var hit_count:int=0
  for target in targets:
   if not effect_is_current(state) or hero.dead:break
   if not claim_hit(state.cast_id,target.actor_id,"sword_wave_contact"):continue
   state.hit_ids.append(target.actor_id);hit_count+=1
   var segment:Dictionary=extra.duplicate(true)
   segment.merge({"target_mode":"spatial","segment_id":"sword_wave_contact","shape":shape},true)
   damage_enemy(target,state.damage,"q3",state.cast_id,false,false,{"position":origin,"cast_origin":state.origin,"direction":state.direction,"cast_damage_share":1.0/maxi(1,targets.size()),"replay_segment":segment})
   if not target.dead and effect_is_current(state):
    push_enemy(target,state.direction,state.push_distance,"q3",state.cast_id,0.0,state.push_duration)
    if float(state.stun_duration)>0.0:apply_control(target,"stun",state.stun_duration,0.0,{"source":"fengli_h06"})
   emit_event("q3_contact",{"id":state.id,"cast_id":state.cast_id,"target":target.actor_id,"position":target.position,"direction":state.direction,"hit_count":state.hit_ids.size()})
  if not effect_is_current(state):continue
  # Empty means no new original target. The queried geometry must still exist for G18.
  if hit_count==0:common.record_spatial(state.cast_id,"sword_wave_contact",float(state.damage)*float(hero.stats.get("common_damage_multiplier",1.0)),origin,shape,extra)
  state.position=clipped.position
  state.travelled=float(state.travelled)+length
  state.remaining=maxf(0.0,float(state.range)-float(state.travelled))
  if clipped.blocked:_expire_q3(state,clipped.reason)
  elif float(state.remaining)<=TIME_EPS:_expire_q3(state,"range")
func _expire_q3(state:Dictionary,reason:String,complete:bool=true)->void:
 if state not in wind_projectiles:return
 wind_projectiles.erase(state)
 emit_event("q3_expired",{"id":state.id,"cast_id":state.cast_id,"position":state.position,"reason":reason})
 if complete:finish_cast(state.cast_id)
func cancel_cast(id:int)->void:
 super.cancel_cast(id)
 ultimates.cancel(id)
 if hero.cast_state.has("e1") and int(hero.cast_state.e1.cast_id)==id:_finish_e1("cancelled",false,false)
 if hero.cast_state.has("e3") and int(hero.cast_state.e3.cast_id)==id:_end_e3("cancelled")
 q1_casts.erase(id)
 if hero.cast_state.has("q2") and int(hero.cast_state.q2.cast_id)==id:
  var chain:Dictionary=hero.cast_state.q2
  _wind_stop_displacement(chain)
  hero.cast_state.erase("q2");hero.untargetable=false
  start_skill_cooldown("q",v("Q2-8",chain.rank))
  emit_event("q2_finished",{"cast_id":id,"position":hero.position,"strikes":chain.count,"kills":chain.kills,"cancelled":true})
 if hero.cast_state.has("e2_spin") and int(hero.cast_state.e2_spin.cast_id)==id:
  hero.cast_state.erase("e2_spin");hero.lock_time=0.0
 if hero.cast_state.has("e2_shadow") and int(hero.cast_state.e2_shadow.cast_id)==id:
  var shadow:Dictionary=hero.cast_state.e2_shadow;hero.cast_state.erase("e2_shadow")
  emit_event("e2_shadow_expired",{"cast_id":id,"position":shadow.position,"reason":"cancelled"})
 for state in wind_projectiles.duplicate():
  if int(state.cast_id)==id:_expire_q3(state,"cancelled",false)
func _hero_enemy_control_allowed(enemy:Dictionary,kind:String,metadata:Dictionary)->bool:
 # Source mechanics paragraph41 and global rules row20 do not grant Boss stun immunity.
 # Boss immovability blocks push/pull only; it cannot be inferred to forbid authored H06.
 if kind=="stun" and metadata.get("source","") in ["fengli_h06","fengli_h08"]:return true
 return super._hero_enemy_control_allowed(enemy,kind,metadata)

# E2 uses actual moving centers. The optional return is a stage of the same cast.
func _start_e2(context:Dictionary)->Dictionary:
 if context.get("stage","")=="return":
  var shadow:Dictionary=hero.cast_state.e2_shadow
  var origin:Vector3=hero.position
  hero.position=shadow.position
  hero.cast_state.erase("e2_shadow")
  emit_event("e2_return",{"cast_id":context.cast_id,"origin":origin,"position":hero.position,"duration":0.0})
  return {"accepted":true,"reason":"e2_return"}
 var rank:int=int(hero.ranks.e)
 var duration:float=v("E2-5",rank)
 var count:int=int(v("E2-1",rank))+(int(hv("h12",1)) if wind_hex("h12") else 0)
 var coefficient:float=f("E2-4",rank)-(hf("h12",2) if wind_hex("h12") else 0.0)
 var cooldown:float=v("E2-9",rank)*(1.0+hf("h10",2) if wind_hex("h10") else 1.0)
 start_skill_cooldown("e",cooldown)
 hero.lock_time=maxf(hero.lock_time,duration)
 hero.cast_state.e2_spin={"cast_id":context.cast_id,"rank":rank,"generation":context.generation,"room_id":context.room_id,"phase":"initial","left":duration,"until":hero_time+duration}
 var state:Dictionary={"rank":rank,"count":count,"radius":v("E2-2",rank),"damage":v("E2-3",rank)+hero.ad()*maxf(0,coefficient),"phase":"initial","rotation_duration":duration/count,"target_point":hero.aim_point,"return_enabled":wind_hex("h10"),"extra_enabled":wind_hex("h11"),"ad":hero.ad()}
 for index in range(count):
  var rotation:Dictionary=state.duplicate(true);rotation.occurrence=index+1
  schedule_effect(context,"wind_e2_motion",float(index)*duration/count,rotation)
  schedule_effect(context,"wind_e2_contact",(float(index)+0.5)*duration/count,rotation)
 schedule_effect(context,"wind_e2_blink",duration,state)
 emit_event("e2_started",{"cast_id":context.cast_id,"position":hero.position,"duration":duration,"rotations":count,"radius":state.radius,"target_point":state.target_point})
 return {"accepted":true}
func _resolve_e2(effect:Dictionary)->void:
 if not effect_is_current(effect) or hero.dead:return
 match str(effect.kind):
  "wind_e2_motion":
   emit_event("e2_spin_started",{"cast_id":effect.cast_id,"position":hero.position,"occurrence":effect.occurrence,"phase":effect.phase,"rotation_duration":effect.rotation_duration,"radius":effect.radius})
  "wind_e2_contact":
   var origin:Vector3=hero.position
   var shape:Dictionary={"kind":"circle","radius":effect.radius}
   var targets:Array=circle_targets(origin,effect.radius)
   var source:String="e2" if effect.phase=="initial" else "e2_extra"
   var ids:Array=[]
   for target in targets:
    if not claim_hit(effect.cast_id,target.actor_id,"e2:%d"%int(effect.occurrence)):continue
    var metadata:Dictionary={"position":origin,"cast_origin":origin,"direction":hero.facing,"occurrence":effect.occurrence,"phase":effect.phase,"cast_damage_share":1.0/maxi(1,targets.size())}
    # The already-performed H11 spin is E2 damage, not a fresh Hex proc on replay.
    metadata["replay_segment"]={"target_mode":"spatial","segment_id":"initial_spin" if effect.phase=="initial" else "extra_spin","occurrence":effect.occurrence,"shape":shape}
    damage_enemy(target,effect.damage,source,effect.cast_id,false,false,metadata)
    ids.append(target.actor_id)
   if ids.is_empty():common.record_spatial(effect.cast_id,"initial_spin" if effect.phase=="initial" else "extra_spin",effect.damage*hero.stats.get("common_damage_multiplier",1.0),origin,shape,{"occurrence":effect.occurrence})
   emit_event("e2_spin_contact",{"cast_id":effect.cast_id,"position":origin,"occurrence":effect.occurrence,"phase":effect.phase,"radius":effect.radius,"target_ids":ids,"hit_count":ids.size()})
  "wind_e2_blink":
   var origin:Vector3=hero.position
   var destination:Vector3=_wind_blink_destination(origin,effect.target_point,v("E2-6",effect.rank))
   hero.position=destination
   var landing_enemy:bool=not circle_targets(destination,v("E2-7",effect.rank)).is_empty()
   var immunity:float=v("E2-8",effect.rank) if landing_enemy else 0.0
   hero.invulnerable_left=maxf(hero.invulnerable_left,immunity)
   common.movement_complete(effect.cast_id)
   emit_event("e2_blink",{"cast_id":effect.cast_id,"origin":origin,"position":destination,"landing_enemy":landing_enemy,"invulnerability":immunity})
   if effect.return_enabled:
    hero.cast_state.e2_shadow={"cast_id":effect.cast_id,"id":"shadow:%d"%int(effect.cast_id),"position":origin,"facing":hero.facing,"left":hv("h10",1),"until":hero_time+hv("h10",1),"generation":encounter_generation,"room_id":room_id,"untargetable":true}
    emit_event("e2_shadow_started",{"id":hero.cast_state.e2_shadow.id,"cast_id":effect.cast_id,"position":origin,"facing":hero.facing,"duration":hv("h10",1),"untargetable":true})
   if effect.extra_enabled:
    var extra_count:int=int(hv("h11",1));var extra_duration:float=hv("h11",5)
    hero.cast_state.e2_spin.phase="extra";hero.cast_state.e2_spin.left=extra_duration;hero.cast_state.e2_spin.until=hero_time+extra_duration
    hero.lock_time=maxf(hero.lock_time,extra_duration)
    for index in range(extra_count):
     var extra:Dictionary={"occurrence":int(effect.count)+index+1,"phase":"extra","radius":hv("h11",4),"damage":hv("h11",2)+effect.ad*hf("h11",3),"rotation_duration":extra_duration/extra_count}
     schedule_effect(effect,"wind_e2_motion",float(index)*extra_duration/extra_count,extra)
     schedule_effect(effect,"wind_e2_contact",(float(index)+0.5)*extra_duration/extra_count,extra)
    schedule_effect(effect,"wind_e2_end",extra_duration)
   else:_finish_e2(int(effect.cast_id))
  "wind_e2_end":_finish_e2(int(effect.cast_id))
func _finish_e2(cast_id:int)->void:
 if hero.cast_state.has("e2_spin") and int(hero.cast_state.e2_spin.cast_id)==cast_id:hero.cast_state.erase("e2_spin")
 finish_cast(cast_id)
 emit_event("e2_finished",{"cast_id":cast_id,"position":hero.position})
func _wind_point_legal(point:Vector3)->bool:
 var bound:float=arena_half_extent-hero_radius
 if absf(point.x)>bound+TIME_EPS or absf(point.z)>bound+TIME_EPS:return false
 for obstacle in obstacles:
  var d:Vector3=point-Vector3(obstacle.position)
  var half:Vector3=Vector3(obstacle.half)+Vector3(hero_radius,0,hero_radius)
  if absf(d.x)<half.x-TIME_EPS and absf(d.z)<half.z-TIME_EPS:return false
 return true
func _wind_blink_destination(origin:Vector3,aim:Vector3,reach:float)->Vector3:
 var offset:Vector3=aim-origin;offset.y=0
 var desired:Vector3=origin+offset.limit_length(reach)
 var candidate:Vector3=desired
 for iteration in range(8):candidate=clamp_position(candidate,hero_radius)
 if _wind_point_legal(candidate) and candidate.distance_to(origin)<=reach+TIME_EPS:return candidate
 # Endpoint legalization only: blink can cross intervening terrain, never land inside it.
 for index in range(64,-1,-1):
  candidate=origin+offset.limit_length(reach)*(float(index)/64.0)
  if _wind_point_legal(candidate):return candidate
 return origin

func _start_e3(context:Dictionary)->Dictionary:
 var rank:int=int(hero.ranks.e)
 var duration:float=v("E3-1",rank)
 hero.cast_state.e3={"rank":rank,"cast_id":context.cast_id,"left":duration,"until":hero_time+duration,"saves":0}
 hero.cooldowns.e=0.0
 emit_event("e3_started",{"cast_id":context.cast_id,"position":hero.position,"duration":duration,"visual_duration":0.30,"rank":rank})
 return {"accepted":true}
func _end_e3(reason:String="duration")->void:
 if not hero.cast_state.has("e3"):return
 var state:Dictionary=hero.cast_state.e3
 hero.cast_state.erase("e3")
 start_skill_cooldown("e",v("E3-8",state.rank))
 finish_cast(state.cast_id)
 emit_event("e3_ended",{"cast_id":state.cast_id,"position":hero.position,"reason":reason})
func _e3_active()->bool:
 return hero.cast_state.has("e3") and float(hero.cast_state.e3.until)>hero_time+TIME_EPS
func _hero_pre_step(_world_dt:float,_real_dt:float)->void:
 _update_e1_mark()
 # Expire stat/forms before this tick's movement and contact packets, not afterward.
 if hero.cast_state.has("e3"):
  hero.cast_state.e3.left=maxf(0.0,float(hero.cast_state.e3.until)-hero_time)
  if float(hero.cast_state.e3.left)<=TIME_EPS:_end_e3()
 for id in ["h02","h09"]:
  if hero.cast_state.has(id):
   hero.cast_state[id].left=maxf(0.0,float(hero.cast_state[id].until)-hero_time)
   if float(hero.cast_state[id].left)<=TIME_EPS:hero.cast_state.erase(id)
func _hero_after_damage(enemy:Dictionary,event:Dictionary,_actual:float)->void:
 ultimates.after_damage(enemy,event)
 if not _e3_active() or not event.get("basic_attack",false) or event.get("damage_type","")=="true" or enemy.dead:return
 if not claim_hit(int(event.cast_id),str(enemy.actor_id),"e3_true"):return
 # Nominal committed basic packet already contains crit/final multipliers once.
 # The proportional true addition cannot re-trigger attacks, Hexes or itself.
 var amount:float=float(event.amount)*f("E3-5",int(hero.cast_state.e3.rank))
 damage_enemy(enemy,amount,"overload_true",int(event.cast_id),true,bool(event.get("critical",false)),{"position":event.get("position",hero.position),"direction":event.get("direction",hero.facing),"basic_attack":true,"snapshot_final":true,"no_reactions":true,"combo":event.get("combo",0)})
func _hero_incoming_damage(packet:float,metadata:Dictionary)->float:
 # The core reserves G29 after this hook and before HP commit. Preserve references
 # to older committed entries so H13 erases only debt created by this transaction.
 metadata["wind_prior_debt"]=common.runtime.debt.duplicate()
 return packet
func _hero_before_hp_commit(packet:float,metadata:Dictionary)->float:
 if _e3_active() and wind_hex("h13") and packet>=hero.hp and hero.hp>0 and int(hero.cast_state.e3.saves)<int(hv("h13")):
  hero.cast_state.e3.saves+=1
  var cancelled_debt:float=0.0
  var prior:Array=metadata.get("wind_prior_debt",[])
  for entry in common.runtime.debt.duplicate():
   if prior.any(func(old):return is_same(old,entry)):continue
   cancelled_debt+=float(entry.remaining)
   # Array.erase compares dictionaries by value; remove by index/identity instead.
   for index in range(common.runtime.debt.size()-1,-1,-1):
    if is_same(common.runtime.debt[index],entry):common.runtime.debt.remove_at(index);break
  emit_event("e3_death_prevented",{"cast_id":hero.cast_state.e3.cast_id,"position":hero.position,"prevented":packet,"cancelled_debt":cancelled_debt,"remaining":maxi(0,int(hv("h13"))-int(hero.cast_state.e3.saves))})
  return 0.0
 return packet
func _hero_after_incoming(before_hp:float,lost:float,metadata:Dictionary)->void:
 _wind_hp_threshold(before_hp,lost,metadata)
func _hero_after_hp_loss(before_hp:float,lost:float,metadata:Dictionary)->void:
 _wind_hp_threshold(before_hp,lost,metadata)
func _wind_hp_threshold(before_hp:float,lost:float,_metadata:Dictionary)->void:
 if hero.loadout.passive!="p2" or int(hero.ranks.passive)<=0 or hero.hp<=0 or lost<=0 or hero.cooldowns.passive>TIME_EPS:return
 var rank:int=int(hero.ranks.passive)
 var threshold:float=float(hero.stats.max_hp)*f("P2-1",rank)
 if before_hp<threshold or hero.hp>=threshold:return
 common_reset_cooldowns(["q","e"])
 # Passive trigger cooldown is source-fixed; skill CDR does not silently alter it.
 hero.cooldowns.passive=v("P2-3",rank)
 var actual:float=heal(float(hero.stats.max_hp)*f("P2-2",rank),false,{"source":"p2"})
 emit_event("passive_rescue",{"position":hero.position,"before_hp":before_hp,"healed":actual,"hp":hero.hp,"cooldown":hero.cooldowns.passive})
func _hero_killed(enemy:Dictionary,source:String,cast_id:int)->void:
 if hero.cast_state.has("e1_mark") and str(hero.cast_state.e1_mark.target_id)==str(enemy.actor_id):_e1_mark_lost("target_dead")
 var identity:String="%s:%d:%s"%[room_id,encounter_generation,enemy.actor_id]
 if _wind_kill_credits.has(identity):return
 _wind_kill_credits[identity]=true
 if _e3_active():
  var extension:float=v("E3-7",int(hero.cast_state.e3.rank))
  hero.cast_state.e3.until+=extension;hero.cast_state.e3.left=maxf(0.0,float(hero.cast_state.e3.until)-hero_time)
  emit_event("e3_extended",{"cast_id":hero.cast_state.e3.cast_id,"target":enemy.actor_id,"extension":extension,"remaining":hero.cast_state.e3.left})
 if hero.loadout.passive=="p3" and int(hero.ranks.passive)>0:
  hero.credited_kills+=1;hero.p3_progress+=1
  _redeem_p3_progress(source,cast_id)
func _sync_loadout_from_ledger()->void:
 var old_candidate:String=hero.loadout.passive
 var old_rank:int=int(hero.ranks.passive)
 super._sync_loadout_from_ledger()
 if hero.loadout.passive!=old_candidate or int(hero.ranks.passive)!=old_rank:
  _redeem_p3_progress("p3_rank_change",0)
func _redeem_p3_progress(source:String,cast_id:int)->void:
 if hero.loadout.passive!="p3" or int(hero.ranks.passive)<=0:return
 var rank:int=int(hero.ranks.passive)
 var requirement:int=maxi(1,int(v("P3-1",rank)))
 var gains:int=floori(float(hero.p3_progress)/requirement)
 if gains<=0:return
 # Only unredeemed progress is spendable. Historical credited_kills is never used.
 hero.p3_progress-=gains*requirement
 hero.permanent_ad+=gains*v("P3-2",rank)
 emit_event("permanent_attack_gained",{"cast_id":cast_id,"source":source,"amount":gains*v("P3-2",rank),"total":hero.permanent_ad,"kills":hero.credited_kills,"remaining_kills":hero.p3_progress})

# E1 owns a single full-cast identity from dagger acceptance until pierce/mark loss.
# User resolution 20261003 permits the whole targeted E1 through intervening
# walls, including its positioning dagger. Every player landing remains legal.
func _e1_target(aim:Vector3)->Dictionary:
 var point:Vector3=hero.aim_point if not aim.is_finite() else aim
 var choices:Array=living().filter(func(t):return t.state!="spawn" and hero.position.distance_to(t.position)<=v("E1-1",hero.ranks.e)+TIME_EPS)
 choices.sort_custom(func(a,b):
  var da:float=a.position.distance_squared_to(point);var db:float=b.position.distance_squared_to(point)
  return str(a.actor_id)<str(b.actor_id) if is_equal_approx(da,db) else da<db)
 return choices[0] if not choices.is_empty() else {}
func _e1_landing(target:Dictionary,aim:Vector3,rank:int)->Dictionary:
 var requested:Vector3=hero.aim_point if not aim.is_finite() else aim
 requested.y=0
 var destination:Vector3=target.position+(requested-Vector3(target.position)).limit_length(v("E1-6",rank))
 destination.y=0
 if not _wind_point_legal(destination):return {"reason":"illegal_landing"}
 return {"destination":destination}
func _e1_action_policy(aim:Vector3)->Dictionary:
 _update_e1_mark()
 if hero.cast_state.has("e1"):
  var state:Dictionary=hero.cast_state.e1
  if not hero.cast_state.has("e1_mark"):return {"reason":"dagger_in_flight"}
  var target:Dictionary=enemy_by_id(state.target_id)
  if target.is_empty() or target.dead or target.state=="spawn":return {"reason":"mark_lost"}
  var landing:Dictionary=_e1_landing(target,aim,state.rank)
  if landing.has("reason"):return landing
  return {"bypass_cooldown":true,"bypass_lock":true,"cast_id":state.cast_id,"stage":"pierce","context":{"destination":landing.destination}}
 var target:Dictionary=_e1_target(aim)
 if target.is_empty():return {"reason":"no_target"}
 return {}
func _start_e1(context:Dictionary)->Dictionary:
 if context.get("stage","")=="pierce":
  var state:Dictionary=hero.cast_state.e1
  var destination:Vector3=context.destination
  var duration:float=float(T.runtime().skills.E1.recast_travel_duration)
  var direction:Vector3=hero.position.direction_to(destination)
  if direction.length_squared()<.001:direction=hero.facing
  state.phase="pierce"
  hero.cast_state.e1_pierce={"cast_id":state.cast_id,"origin":hero.position,"destination":destination,"direction":direction,"duration":duration,"elapsed":0.0,"points":[hero.position],"damage":v("E1-8",state.rank)+hero.ad()*f("E1-9",state.rank),"width":v("E1-7",state.rank),"hits":[],"started_at":clock.world_time,"saved_aim":hero.aim_point,"last_legal_position":hero.position}
  hero.facing=direction
  emit_event("e1_pierce_started",{"cast_id":state.cast_id,"origin":hero.position,"position":hero.position,"destination":destination,"direction":direction,"target_id":state.target_id,"duration":duration,"width":v("E1-7",state.rank)})
  return {"accepted":true}
 var target:Dictionary=_e1_target(hero.aim_point)
 if target.is_empty():return {"accepted":false,"reason":"no_target"}
 var rank:int=int(hero.ranks.e)
 var timing:Dictionary=T.runtime().skills.E1
 hero.cast_state.e1={"cast_id":context.cast_id,"rank":rank,"generation":encounter_generation,"room_id":room_id,"target_id":target.actor_id,"phase":"windup","cooldown_started":false,"started_at":clock.world_time,"saved_aim":hero.aim_point}
 hero.cooldowns.e=0.0
 # The .30s throw is visual recovery. Only the release interval commits actions;
 # locomotion stays live, and a valid marked recast can blend out visual recovery.
 hero.lock_time=maxf(hero.lock_time,float(timing.throw_release))
 schedule_effect(context,"wind_e1_release",float(timing.throw_release),{"rank":rank,"target_id":target.actor_id,"damage":v("E1-3",rank)+hero.ad()*f("E1-4",rank)})
 emit_event("e1_started",{"cast_id":context.cast_id,"position":hero.position,"direction":context.direction,"target_id":target.actor_id,"duration":timing.throw_duration,"contact_after":timing.throw_release})
 return {"accepted":true}
func _release_e1(effect:Dictionary)->void:
 if not effect_is_current(effect) or not hero.cast_state.has("e1") or hero.dead:return
 var state:Dictionary=hero.cast_state.e1
 if int(state.cast_id)!=int(effect.cast_id) or state.phase!="windup":return
 var target:Dictionary=enemy_by_id(state.target_id)
 if target.is_empty() or target.dead or target.state=="spawn":_finish_e1("target_lost");return
 state.phase="flight"
 var projectile:Dictionary={"id":"dagger:%d:%d"%[encounter_generation,state.cast_id],"type":"dagger","cast_id":state.cast_id,"position":hero.position,"origin":hero.position,"direction":hero.position.direction_to(target.position),"target_id":target.actor_id,"generation":encounter_generation,"room_id":room_id,"speed":v("E1-2",state.rank),"damage":effect.damage,"last_step_at":clock.world_time}
 wind_projectiles.append(projectile)
 emit_event("e1_projectile",projectile)
func _step_e1(dt:float)->void:
 if not hero.cast_state.has("e1"):return
 var state:Dictionary=hero.cast_state.e1
 if hero.dead or not effect_is_current(state):_finish_e1("cancelled",false,false);return
 if state.phase=="windup":
  var selected:Dictionary=enemy_by_id(state.target_id)
  if selected.is_empty() or selected.dead or selected.state=="spawn":_finish_e1("target_lost")
  return
 if state.phase=="flight":
  for projectile in wind_projectiles.duplicate():
   if projectile.get("type","")!="dagger" or int(projectile.cast_id)!=int(state.cast_id):continue
   var target:Dictionary=enemy_by_id(state.target_id)
   if target.is_empty() or target.dead or target.state=="spawn":_finish_e1("target_lost");return
   var elapsed:float=maxf(0.0,clock.world_time-float(projectile.last_step_at))
   projectile.last_step_at=clock.world_time
   if elapsed<=TIME_EPS:return
   var origin:Vector3=projectile.position
   var offset:Vector3=Vector3(target.position)-origin
   projectile.direction=offset.normalized() if offset.length_squared()>.001 else hero.facing
   var distance:float=maxf(0.0,offset.length()-float(target.radius))
   var travel:float=minf(distance,float(projectile.speed)*elapsed)
   # Whole-E1 exception only: its positioning dagger must reach the locked target
   # through cover before the legal-landing recast is possible. Preserve real
   # travel/contact and arena clipping; ordinary projectile callers keep cover.
   var clipped:Dictionary=SweptRectangle.clip_front(origin,projectile.direction,travel,0.0,[],arena_half_extent)
   projectile.position=clipped.position
   if clipped.blocked:
    emit_event("e1_projectile_blocked",{"id":projectile.id,"cast_id":state.cast_id,"position":projectile.position,"reason":clipped.reason})
    _finish_e1(str(clipped.reason));return
   if travel+TIME_EPS>=distance:_e1_dagger_contact(state,projectile,target)
   return
 if state.phase=="pierce":_step_e1_pierce(dt)
func _e1_dagger_contact(state:Dictionary,projectile:Dictionary,target:Dictionary)->void:
 wind_projectiles.erase(projectile)
 if not claim_hit(state.cast_id,target.actor_id,"e1_dagger"):return
 damage_enemy(target,projectile.damage,"e1_dagger",state.cast_id,false,false,{"position":projectile.position,"cast_origin":projectile.origin,"direction":projectile.direction,"replay_segment":{"target_mode":"bound","segment_id":"dagger_hit","saved_aim":state.saved_aim,"relative_time":clock.world_time-float(state.started_at)}})
 if not hero.cast_state.has("e1"):return
 if target.dead:_finish_e1("target_dead");return
 var duration:float=v("E1-5",state.rank)+(hv("h07",1) if wind_hex("h07") else 0.0)
 hero.cast_state.e1_mark={"cast_id":state.cast_id,"target_id":target.actor_id,"position":target.position,"duration":duration,"remaining":duration,"until":hero_time+duration,"generation":encounter_generation,"room_id":room_id}
 state.phase="mark"
 if wind_hex("h08"):apply_control(target,"stun",hv("h08"),0.0,{"source":"fengli_h08"})
 emit_event("e1_marked",_e1_mark_snapshot())
func _e1_mark_snapshot()->Dictionary:
 if not hero.cast_state.has("e1_mark"):return {}
 var mark:Dictionary=hero.cast_state.e1_mark.duplicate(true)
 var target:Dictionary=enemy_by_id(mark.target_id)
 if not target.is_empty():mark.position=target.position
 mark.remaining=maxf(0.0,float(mark.until)-hero_time)
 return mark
func _update_e1_mark()->void:
 if not hero.cast_state.has("e1_mark"):return
 var mark:Dictionary=hero.cast_state.e1_mark
 var target:Dictionary=enemy_by_id(mark.target_id)
 if target.is_empty() or target.dead or target.state=="spawn" or not effect_is_current(mark):_e1_mark_lost("target_lost");return
 mark.position=target.position;mark.remaining=maxf(0.0,float(mark.until)-hero_time)
 if float(mark.remaining)<=TIME_EPS:_e1_mark_lost("mark_expired")
func _e1_start_cooldown()->void:
 if not hero.cast_state.has("e1") or hero.cast_state.e1.cooldown_started:return
 hero.cast_state.e1.cooldown_started=true
 start_skill_cooldown("e",v("E1-10",hero.cast_state.e1.rank))
func _e1_mark_lost(reason:String)->void:
 hero.cast_state.erase("e1_mark")
 _e1_start_cooldown()
 # Once accepted, the authored forced path continues even if its marked target
 # dies. Cooldown begins on that mark loss, without resetting again on arrival.
 if not hero.cast_state.has("e1_pierce"):_finish_e1(reason)
func _step_e1_pierce(dt:float)->void:
 if not hero.cast_state.has("e1_pierce") or dt<=TIME_EPS:return
 var state:Dictionary=hero.cast_state.e1
 var path:Dictionary=hero.cast_state.e1_pierce
 var before:Vector3=hero.position
 if not _wind_point_legal(path.destination):_finish_e1("illegal_landing");return
 path.elapsed=minf(path.duration,float(path.elapsed)+dt)
 var destination:Vector3=Vector3(path.origin).lerp(path.destination,clampf(float(path.elapsed)/float(path.duration),0,1))
 hero.position=destination;hero.facing=path.direction
 if _wind_point_legal(hero.position):path.last_legal_position=hero.position
 path.points.append(destination)
 var shape:Dictionary={"kind":"recorded_path","points":path.points.duplicate(),"width":path.width}
 var extra:Dictionary={"relative_time":float(path.started_at)-float(state.started_at),"saved_aim":path.saved_aim}
 var delta:Vector3=destination-before
 var targets:Array=living().filter(func(t):
  var along:float=clampf((Vector3(t.position)-before).dot(delta)/maxf(TIME_EPS,delta.length_squared()),0,1)
  return t.state!="spawn" and Vector3(t.position).distance_to(before+delta*along)<=float(path.width)*.5+float(t.radius)+TIME_EPS)
 for target in targets:
  if not hero.cast_state.has("e1") or not effect_is_current(state):return
  if not claim_hit(state.cast_id,target.actor_id,"e1_pierce"):continue
  path.hits.append(target.actor_id)
  var marked:bool=hero.cast_state.has("e1_mark") and str(hero.cast_state.e1_mark.target_id)==str(target.actor_id)
  var segment:Dictionary=extra.duplicate(true);segment.merge({"target_mode":"spatial","segment_id":"second_pierce","shape":shape},true)
  damage_enemy(target,path.damage,"e1_pierce",state.cast_id,false,false,{"position":path.origin,"cast_origin":path.origin,"direction":path.direction,"replay_segment":segment})
  if marked and not target.dead and wind_hex("h08"):apply_control(target,"stun",hv("h08"),0.0,{"source":"fengli_h08"})
  emit_event("e1_pierce_contact",{"cast_id":state.cast_id,"target_id":target.actor_id,"position":target.position,"direction":path.direction,"marked":marked})
 if not hero.cast_state.has("e1") or not effect_is_current(state):return
 # One cumulative actual path, one replay query, one hit per target. Empty slices
 # extend geometry but never synthesize a future path beyond actual displacement.
 common.record_spatial(state.cast_id,"second_pierce",float(path.damage)*float(hero.stats.get("common_damage_multiplier",1.0)),path.origin,shape,extra)
 if float(path.elapsed)+TIME_EPS>=float(path.duration):_finish_e1("pierce_complete",true)
func _finish_e1(reason:String,pierced:bool=false,complete:bool=true)->void:
 if not hero.cast_state.has("e1"):return
 var state:Dictionary=hero.cast_state.e1
 if hero.cast_state.has("e1_pierce"):_wind_stop_displacement(hero.cast_state.e1_pierce)
 _e1_start_cooldown()
 pending=pending.filter(func(e):return int(e.get("cast_id",0))!=int(state.cast_id))
 wind_projectiles=wind_projectiles.filter(func(p):return p.get("type","")!="dagger" or int(p.cast_id)!=int(state.cast_id))
 hero.cast_state.erase("e1");hero.cast_state.erase("e1_mark");hero.cast_state.erase("e1_pierce")
 if pierced and wind_hex("h09"):
  hero.cast_state.h09={"left":hv("h09",2),"until":hero_time+hv("h09",2)}
 if complete:
  if pierced:common.movement_complete(state.cast_id)
  finish_cast(state.cast_id)
 emit_event("e1_finished",{"cast_id":state.cast_id,"position":hero.position,"reason":reason,"pierced":pierced})
func _hero_final_outgoing_multiplier(enemy:Dictionary,_event:Dictionary)->float:
 if wind_hex("h07") and hero.cast_state.has("e1_mark"):
  var mark:Dictionary=hero.cast_state.e1_mark
  if str(mark.target_id)==str(enemy.actor_id) and float(mark.until)>hero_time+TIME_EPS and effect_is_current(mark):return 1.0+hf("h07",2)
 return 1.0

# Concrete caster owns actor clocks; projectile travel and replay timelines remain world-time.
func _hero_time_delta(world_dt:float,real_dt:float)->float:
 return real_dt if not _presentation.is_empty() else world_dt
func schedule_effect(context:Dictionary,kind:String,delay:float,extra:Dictionary={},time_domain:String="hero")->Dictionary:
 return super.schedule_effect(context,kind,delay,extra,time_domain)
func _hero_victory_pending()->bool:return hero.cast_state.has("r1")
func _hero_presentation_finished(cast_id:int)->void:ultimates.presentation_finished(cast_id)
func _hero_basic_completed(event:Dictionary,_targets:Array)->void:ultimates.basic_completed(event)

func common_requires_explicit_movement()->bool:return true
