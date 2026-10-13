extends "res://tests/ink_shop_runtime_stats_20261004/hp_undo_fix01/ink_health_sim.gd"
## Isolated H02 mechanism only. Shared health, Q1/H01, input and damage stay inherited.
## No renderer, new damage packet, stun timer, AI/global clock subdivision or asset.
var ink_vortices:Array=[]
var ink_vortex_finished:Array=[]
var _h02_seen_endpoints:Dictionary={}
var _h02_markers:Dictionary={}
var _h02_target_sources:Dictionary={}
var _h02_target_sampled:Dictionary={}
var _h02_frame_active:bool=false
var _h02_tick_start:float=0.0

func _hero_hex_status(id:String)->Dictionary:
 if id=="yanguizhou_h02":return {"active":hero.loadout.q=="q1" and int(hero.ranks.q)>0,"reason":"" if hero.loadout.q=="q1" and int(hero.ranks.q)>0 else "requires_Q1"}
 return super._hero_hex_status(id)

func _make_motion(context:Dictionary,path:Array,width:float,speed:float,damage:float,source:String,critical:bool)->Dictionary:
 var state:Dictionary=super._make_motion(context,path,width,speed,damage,source,critical)
 # Acquisition after release cannot retrospectively add an effect to an old Q1.
 if source=="q1":state["h02_enabled_at_release"]=hx("yanguizhou_h02")
 return state

func _retire_motion(state:Dictionary,at:float,reason:String)->void:
 if bool(state.get("retired",false)):return
 var endpoint:bool=state.source=="q1" and reason=="path_end" and bool(state.get("h02_enabled_at_release",false)) and float(state.front_distance)>=float(state.path_length)-Geometry.EPS and Vector3(state.front_position).distance_to(state.path.back())<=Geometry.EPS
 super._retire_motion(state,at,reason)
 # finish_cast and the finished event may synchronously cancel/replace this room.
 if not endpoint or not effect_is_current(state):return
 var key:String=str(state.wave_id)
 if _h02_seen_endpoints.has(key):return
 _h02_seen_endpoints[key]=true
 var vortex:Dictionary={"vortex_id":key+":h02","wave_id":key,"cast_id":state.cast_id,"owner_actor_id":hero.actor_id,"generation":state.generation,"room_id":state.room_id,"source":"yanguizhou_h02","position":Vector3(state.path.back()),"radius":T.hex_parameter("H02-1"),"duration":T.hex_parameter("H02-2"),"pull_speed":T.hex_parameter("H02-3"),"born_at":at,"expires_at":at+T.hex_parameter("H02-2"),"sampled_until":{}}
 ink_vortices.append(vortex)
 emit_event("ink_h02_created",_h02_public(vortex))

func _fixed_step(real_dt:float)->void:
 var scope:Dictionary=_ink_scope()
 _h02_frame_active=true;_h02_tick_start=hero_time
 super._fixed_step(real_dt)
 _h02_frame_active=false
 if _ink_scope_current(scope):
  # Old zones already ran before AI. Only newborn endpoint remainder / newly
  # admitted targets remain. Per-zone/per-target watermarks make this idempotent.
  _settle_h02_interval(_h02_tick_start,hero_time)
 _clear_h02_markers()
 if _ink_scope_current(scope):_check_victory()

func _step_pull(enemy:Dictionary,dt:float)->void:
 # Preserve the exact neutral ordering: inherited pulls, this pull, inherited
 # pushes, then AI. H02 never erases an existing Q1 push or another pull.
 super._step_pull(enemy,dt)
 if not _h02_frame_active:return
 _h02_sample_enemy(enemy,_h02_tick_start,hero_time,true)

func _h02_target_current(enemy:Dictionary,vortex:Dictionary)->bool:
 if not effect_is_current(vortex) or paused or hero.dead:return false
 if enemy.is_empty() or bool(enemy.get("dead",true)) or str(enemy.get("state",""))=="spawn":return false
 if not is_same(enemy,enemy_by_id(str(enemy.get("actor_id","")))):return false
 if int(enemy.get("generation",-1))!=encounter_generation or str(enemy.get("room_id",""))!=room_id:return false
 # Existing Boss/pull permission hook is the sole immunity authority.
 return _hero_enemy_control_allowed(enemy,"pull",{"source":"yanguizhou_h02","cast_id":vortex.cast_id})

func _h02_move_target(vortex:Dictionary,enemy:Dictionary,from_time:float,to_time:float,hold_for_ai:bool)->void:
 if not _h02_target_current(enemy,vortex):return
 var id:String=str(enemy.actor_id)
 var begin:float=maxf(maxf(from_time,float(vortex.born_at)),float(vortex.sampled_until.get(id,vortex.born_at)))
 var end:float=minf(to_time,float(vortex.expires_at))
 if end<=begin+TIME_EPS:return
 # Stamp before callbacks, including out-of-radius samples: neither duplicate
 # settlement nor later entry can bank time spent outside the actual region.
 vortex.sampled_until[id]=end
 var offset:Vector3=Geometry.ground(Vector3(vortex.position)-Vector3(enemy.position))
 if offset.length()>float(vortex.radius)+float(enemy.radius)+Geometry.EPS or offset.length()<=Geometry.EPS:return
 var origin:Vector3=enemy.position
 var desired:Vector3=origin+offset.limit_length(float(vortex.pull_speed)*(end-begin))
 var moved:Vector3=_move_clipped(origin,desired,float(enemy.radius))
 enemy.position=moved
 if hold_for_ai and enemy.pull_state.is_empty() and moved.distance_squared_to(desired)<=0.0001 and moved.distance_squared_to(origin)>Geometry.EPS*Geometry.EPS and moved.distance_squared_to(vortex.position)>Geometry.EPS*Geometry.EPS:
  # Temporary pull ownership uses the existing director's forced-displacement
  # interruption, not a new stun/slow duration. Removed before returning a tick.
  var marker:Dictionary={"ink_h02_tick_marker":true,"cast_id":vortex.cast_id,"generation":vortex.generation,"room_id":vortex.room_id}
  enemy.pull_state=marker
  _h02_markers[id]={"enemy":enemy,"marker":marker}
 var receipt:Dictionary={"vortex_id":vortex.vortex_id,"wave_id":vortex.wave_id,"cast_id":vortex.cast_id,"owner_actor_id":vortex.owner_actor_id,"source":"yanguizhou_h02","target_id":id,"generation":vortex.generation,"room_id":vortex.room_id,"from_position":origin,"position":moved,"center":vortex.position,"sample_from":begin,"sample_to":end,"active_seconds":end-begin,"requested_distance":origin.distance_to(desired),"actual_distance":origin.distance_to(moved),"blocked":moved.distance_squared_to(desired)>Geometry.EPS*Geometry.EPS}
 emit_event("ink_h02_pull",receipt)

func _h02_source_for(enemy:Dictionary,at:float)->Dictionary:
 var id:String=str(enemy.get("actor_id",""))
 var eligible:Array=[]
 for vortex in ink_vortices:
  if bool(vortex.get("finished",false)) or not _h02_target_current(enemy,vortex):continue
  if at<float(vortex.born_at)-TIME_EPS or at>=float(vortex.expires_at)-TIME_EPS:continue
  if Geometry.ground(Vector3(vortex.position)-Vector3(enemy.position)).length()>float(vortex.radius)+float(enemy.radius)+Geometry.EPS:continue
  eligible.append(vortex)
 var previous:Dictionary=_h02_target_sources.get(id,{})
 if not previous.is_empty() and is_same(previous.enemy,enemy):
  for vortex in eligible:
   if str(vortex.vortex_id)==str(previous.vortex_id):return vortex
 _h02_target_sources.erase(id)
 if eligible.is_empty():return {}
 # Explicit bounded technical resolution: retain a valid source, otherwise
 # stable creation order. Independent lifetimes; never add two 3m/s velocities.
 var chosen:Dictionary=eligible[0]
 _h02_target_sources[id]={"enemy":enemy,"vortex_id":chosen.vortex_id}
 return chosen

func _h02_sample_enemy(enemy:Dictionary,from_time:float,to_time:float,hold_for_ai:bool)->void:
 var scope:Dictionary=_ink_scope()
 var id:String=str(enemy.get("actor_id",""))
 var sampled:Dictionary=_h02_target_sampled.get(id,{})
 var begin:float=maxf(from_time,float(sampled.until)) if not sampled.is_empty() and is_same(sampled.enemy,enemy) else from_time
 if to_time<=begin+TIME_EPS:return
 var boundaries:Array=[begin,to_time]
 for vortex in ink_vortices:
  for time in [float(vortex.born_at),float(vortex.expires_at)]:
   if time>begin+TIME_EPS and time<to_time-TIME_EPS and not boundaries.has(time):boundaries.append(time)
 boundaries.sort()
 for i in range(boundaries.size()-1):
  var a:float=float(boundaries[i]);var b:float=float(boundaries[i+1])
  var selected:Dictionary=_h02_source_for(enemy,a)
  if hold_for_ai:_h02_clear_enemy_marker(enemy)
  if not selected.is_empty():
   # Reserve this target's interval before callbacks. Even a selected source at
   # center consumes ownership of that interval, but never installs a pull.
   _h02_target_sampled[id]={"enemy":enemy,"until":b}
   _h02_move_target(selected,enemy,a,b,hold_for_ai)
   if not _ink_scope_current(scope):return
  # Existing unselected/outside zones cannot bank elapsed time for later entry.
  # A zone born only after Q1 settles has no such watermark, so gets just its
  # actual endpoint-to-tick-end remainder, unless another source already owned it.
  for vortex in ink_vortices:
   if effect_is_current(vortex):vortex.sampled_until[id]=maxf(float(vortex.sampled_until.get(id,vortex.born_at)),minf(b,float(vortex.expires_at)))

func _settle_h02_interval(from_time:float,to_time:float)->void:
 var scope:Dictionary=_ink_scope()
 for enemy in enemies.duplicate():
  _h02_sample_enemy(enemy,from_time,to_time,false)
  if not _ink_scope_current(scope):return
 for vortex in ink_vortices.duplicate():
  if effect_is_current(vortex) and to_time>=float(vortex.expires_at)-TIME_EPS:_finish_h02(vortex,"expired",float(vortex.expires_at))
  if not _ink_scope_current(scope):return
 ink_vortices=ink_vortices.filter(func(vortex):return effect_is_current(vortex) and not bool(vortex.get("finished",false)))
 for id in _h02_target_sources.keys():
  var record:Dictionary=_h02_target_sources[id]
  if bool(record.enemy.get("dead",true)) or not is_same(record.enemy,enemy_by_id(str(id))) or not ink_vortices.any(func(vortex):return str(vortex.vortex_id)==str(record.vortex_id)):_h02_target_sources.erase(id)
 for id in _h02_target_sampled.keys():
  if not is_same(_h02_target_sampled[id].enemy,enemy_by_id(str(id))) or bool(_h02_target_sampled[id].enemy.get("dead",true)):_h02_target_sampled.erase(id)

func _h02_clear_enemy_marker(enemy:Dictionary)->void:
 var id:String=str(enemy.get("actor_id",""))
 if not _h02_markers.has(id):return
 var record:Dictionary=_h02_markers[id]
 if not is_same(record.enemy,enemy):return
 if is_same(enemy.get("pull_state",{}),record.marker):enemy.pull_state={}
 _h02_markers.erase(id)

func _clear_h02_markers(cast_id:int=-1)->void:
 for id in _h02_markers.keys():
  var record:Dictionary=_h02_markers[id]
  if cast_id>=0 and int(record.marker.cast_id)!=cast_id:continue
  if is_same(record.enemy.get("pull_state",{}),record.marker):record.enemy.pull_state={}
  _h02_markers.erase(id)

func _finish_h02(vortex:Dictionary,reason:String,at:float)->void:
 if bool(vortex.get("finished",false)):return
 vortex["finished"]=true
 for id in _h02_target_sources.keys():
  if str(_h02_target_sources[id].vortex_id)==str(vortex.vortex_id):_h02_target_sources.erase(id)
 var record:Dictionary=_h02_public(vortex)
 record.merge({"reason":reason,"finished_at":at,"settled_at":hero_time},true)
 ink_vortex_finished.append(record)
 if ink_vortex_finished.size()>32:ink_vortex_finished.pop_front()
 emit_event("ink_h02_finished",record)

func cancel_cast(id:int)->void:
 super.cancel_cast(id)
 _clear_h02_markers(id)
 for vortex in ink_vortices.duplicate():
  if int(vortex.cast_id)==id:_finish_h02(vortex,"cast_cancelled",hero_time)
 ink_vortices=ink_vortices.filter(func(vortex):return int(vortex.cast_id)!=id)

func _hero_clear_transients()->void:
 _h02_frame_active=false
 _clear_h02_markers()
 # Encounter cleanup has already invalidated casts. No terminal/spawn callback.
 ink_vortices.clear();ink_vortex_finished.clear();_h02_seen_endpoints.clear();_h02_target_sources.clear();_h02_target_sampled.clear()
 super._hero_clear_transients()

func _hero_victory_pending()->bool:
 return super._hero_victory_pending() or not ink_vortices.is_empty()

func _h02_public(vortex:Dictionary)->Dictionary:
 var out:Dictionary={}
 for key in ["vortex_id","wave_id","cast_id","owner_actor_id","generation","room_id","source","position","radius","duration","pull_speed","born_at","expires_at"]:out[key]=vortex[key]
 out["remaining"]=maxf(0.0,float(vortex.expires_at)-hero_time)
 out["source_time"]=hero_time
 return out.duplicate(true)

func ink_presenter_snapshot()->Dictionary:
 var out:Dictionary=super.ink_presenter_snapshot()
 out["h02_schema"]="ink-q1-h02-presenter-1"
 out["vortices"]=ink_vortices.map(func(vortex):return _h02_public(vortex))
 out["vortex_finished"]=ink_vortex_finished.duplicate(true)
 return out.duplicate(true)

func _hero_snapshot()->Dictionary:
 var out:Dictionary=super._hero_snapshot()
 out["ink_foundation_scope"]="BASIC_Shift_Q1_H01_H02_only_not_full_hero"
 out["ink_unsupported"]=tuning.unsupported.filter(func(value):return value!="H02-H16")
 out["ink_unsupported"].append("H03-H16")
 return out
