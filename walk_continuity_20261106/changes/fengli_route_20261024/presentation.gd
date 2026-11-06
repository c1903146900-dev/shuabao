extends "res://fengli_route_20261024/environment_view.gd"
const LobCue=preload("res://fengli_route_20261024/lob_cue.gd")
const ProjectileCue=preload("res://fengli_route_20261024/projectile_cue.gd")
const EnemyWarningCue=preload("res://fengli_route_20261024/enemy_warning_cue.gd")
const PitcherZones=preload("res://shared_enemy_presentation_20261025/pitcher_zone_reader.gd")
var pitcher_zones=PitcherZones.new()
const BossWaveEffects=preload("res://fengli_route_20261024/boss_wave_effects.gd")
var boss_wave_effects=BossWaveEffects.new()
## Draft isolated source adapter. No Ink snapshot, wave clock, damage or state writes.
const DefaultEffects=preload("res://fengli_route_20261024/skill_effects.gd")
var default_effects=DefaultEffects.new()
const RescueEffects=preload("res://fengli_route_20261024/rescue_effects.gd")
var rescue_effects=RescueEffects.new()
const NailEffects=preload("res://fengli_route_20261024/nail_effects.gd")
var nail_effects=NailEffects.new()
const PuppetMotion=preload("res://fengli_route_20261024/puppet_motion.gd")
var puppet_motion=PuppetMotion.new()
var frames:Dictionary={}
# Derived texture cache; original PNG metadata remains authoritative.
# Quality/performance acceptance pending. No mipmaps or filter-policy change.
const POSE_CACHE_ROOT:String="res://fengli_route_20261024/pose_cache/"
const POSE_CACHE_MANIFEST_SHA256:String="b0f50cee1fa0db5b490c63342a9f0d913b294dea47bd48ed22a7f019c53cb48a"
var pose_cache_manifest:Dictionary={}
var pose_textures:Dictionary={}
var pose_texture_scales:Dictionary={}
var animation:Dictionary={}
var _last_position:Vector3=Vector3.INF
var _walk_distance:float=0.0
var _walking:bool=false
var _forced_motion_pending:bool=false
var _forced_motion_previous:bool=false
const HitReaction=preload("res://fengli_route_20261024/hit_reaction.gd")
var hit_reaction=HitReaction.new()
var enemy_flash:Dictionary={}
var enemy_flash_ratio:Dictionary={}
var contacts:Array=[]
var dash_trail:Array=[]
var enemy_shots:Dictionary={}
var pose_meta:Dictionary={}
var scope:String=""
var receipt:Dictionary={}
var active:bool=false
var _mirror:float=1.0
var font:Font
var _owner_id:int=0
var _sim_id:int=0
var _session_id:int=0
func bind(room:Node)->Dictionary:
 if host!=null:return {"accepted":false,"reason":"fresh_view_required"}
 if not is_instance_valid(room) or not is_instance_valid(room.sim) or room.sim.hero.actor_id!="fengli":return {"accepted":false,"reason":"fengli_host_required"}
 font=ThemeDB.fallback_font
 host=room;camera=room.camera;_owner_id=room.get_instance_id();_sim_id=room.sim.get_instance_id();_session_id=room.shop_session.get_instance_id()
 var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://fengli_route_20261024/assets/frames.json"))
 if not parsed is Dictionary or parsed.get("hero_id","")!="fengli":return {"accepted":false,"reason":"fengli_asset_manifest_invalid"}
 if not parsed.get("frames") is Dictionary:return {"accepted":false,"reason":"frames_dictionary_required"}
 frames=parsed.frames.duplicate(true)
 var required:Array=["idle","walk_upper_frozen_cut","walk_contact_a","walk_passing_a","walk_contact_b","walk_passing_b"]
 required.append("dash")
 for prefix in ["attack","dashattack","q1","e1throw"]:
  for phase in ["windup","contact","recover"]:required.append(prefix+"_"+phase)
 var actual:Array=frames.keys();actual.sort();required.sort()
 if actual!=required:return {"accepted":false,"reason":"exact_pose_set_required"}
 for key in frames:
  if not frames[key] is Dictionary:return {"accepted":false,"reason":"pose_metadata_type:"+str(key)}
  var meta:Dictionary=frames[key]
  if not meta.has_all(["path","sha256","region","anchor","scale"]) or not meta.path is String or not meta.sha256 is String:return {"accepted":false,"reason":"pose_metadata_missing:"+str(key)}
  if not meta.region is Array or meta.region.size()!=4 or not meta.anchor is Array or meta.anchor.size()!=2:return {"accepted":false,"reason":"pose_geometry_shape:"+str(key)}
  for number in meta.region+meta.anchor+[meta.scale]:
   if not (number is int or number is float) or not is_finite(float(number)):return {"accepted":false,"reason":"pose_geometry_nonfinite:"+str(key)}
  for number in meta.region:
   if float(number)!=floor(float(number)):return {"accepted":false,"reason":"pose_region_not_integer:"+str(key)}
  if float(meta.scale)<=0.0 or float(meta.region[2])<=0.0 or float(meta.region[3])<=0.0:return {"accepted":false,"reason":"pose_geometry_nonpositive:"+str(key)}
  if FileAccess.get_sha256(meta.path)!=meta.sha256:return {"accepted":false,"reason":"pose_digest_mismatch:"+str(key)}
  var img:=Image.new()
  if img.load_png_from_buffer(FileAccess.get_file_as_bytes(meta.path))!=OK:return {"accepted":false,"reason":"pose_load_failed:"+str(key)}
  var region:Array=meta.region
  if region.size()!=4 or meta.anchor.size()!=2 or not Rect2i(Vector2i.ZERO,img.get_size()).encloses(Rect2i(region[0],region[1],region[2],region[3])):return {"accepted":false,"reason":"pose_region_invalid:"+str(key)}
  # Original source validation above remains mandatory, including PNG decode.
  var original_size:Vector2i=img.get_size()
  img=null
  var cached:Dictionary=_load_pose_cache(str(key),meta,original_size)
  if not cached.accepted:return cached
  img=cached.image
  cached.clear()
  pose_texture_scales[key]=Vector2(img.get_size())/Vector2(original_size)
  pose_textures[key]=ImageTexture.create_from_image(img)
 for key:String in ["floor","parapet","ventilation","pump","sign","clutter","enemy","elite","armored","boss","ranged","pouncer","support","pitcher"]:
  var img:=Image.new()
  if img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://neon_cartoon_20261021/assets/"+key+".png"))!=OK:return {"accepted":false,"reason":"environment_asset_missing:"+key}
  textures[key]=ImageTexture.create_from_image(img);used[key]=img.get_used_rect()
  if key in ["enemy","elite","armored","boss","ranged","pouncer","support","pitcher"]:
   var mask:Image=img.duplicate()
   var factor:float=minf(1.0,256.0/maxf(img.get_width(),img.get_height()))
   mask.resize(maxi(1,roundi(img.get_width()*factor)),maxi(1,roundi(img.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
   mask.convert(Image.FORMAT_RGBA8)
   var bytes:PackedByteArray=mask.get_data()
   for pixel in range(0,bytes.size(),4):bytes[pixel]=255;bytes[pixel+1]=255;bytes[pixel+2]=255
   mask=Image.create_from_data(mask.get_width(),mask.get_height(),false,Image.FORMAT_RGBA8,bytes)
   enemy_flash[key]=ImageTexture.create_from_image(mask)
   enemy_flash_ratio[key]=Vector2(mask.get_size())/Vector2(img.get_size())
 used.ventilation=Rect2i(331,217,984,640);used.sign=Rect2i(76,305,739,1132);used.clutter=Rect2i(252,163,977,730)
 used.parapet=Rect2i(53,277,2067,231);used.pump=Rect2i(235,243,784,742);used.enemy=Rect2i(216,92,788,1017);used.elite=Rect2i(116,76,1306,864)
 var enemy_meta:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://neon_cartoon_20261021/assets/enemy_regions.json"))
 if not enemy_meta is Dictionary:return {"accepted":false,"reason":"enemy_metadata_missing"}
 enemy_asset_meta=enemy_meta
 for key in ["armored","boss"]:
  if not enemy_asset_meta.get(key) is Dictionary or not enemy_asset_meta[key].get("region") is Array or enemy_asset_meta[key].region.size()!=4 or not enemy_asset_meta[key].get("foot_anchor") is Array or enemy_asset_meta[key].foot_anchor.size()!=2:return {"accepted":false,"reason":"enemy_region_shape:"+key}
  for value in enemy_asset_meta[key].region+enemy_asset_meta[key].foot_anchor:
   if not (value is int or value is float) or not is_finite(float(value)):return {"accepted":false,"reason":"enemy_region_invalid:"+key}
 for key in ["armored","boss"]:
  var r:Array=enemy_asset_meta[key].region;used[key]=Rect2i(r[0],r[1],r[2],r[3])
 var atlas:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://neon_cartoon_20261021/assets/enemy_pose_regions.json"))
 if not atlas is Dictionary or atlas.get("schema","")!="enemy_three_pose_v1" or not _exact_numbers(atlas.get("cell"),[128,96]) or not _exact_numbers(atlas.get("foot_anchor"),[64,70]) or atlas.get("display_scale",0)!=1.0:return {"accepted":false,"reason":"enemy_pose_metadata_invalid"}
 pose_meta=atlas.duplicate(true)
 for key in ["ranged","pouncer","support","pitcher"]:
  if not _exact_regions(pose_meta.get("kinds",{}).get(key,{}).get("regions")) or textures[key].get_size()!=Vector2(384,96):return {"accepted":false,"reason":"enemy_pose_atlas_invalid:"+key}
 for key in textures:
  if not textures[key] is Texture2D or textures[key].get_size().x<=0 or textures[key].get_size().y<=0 or used[key].size.x<=0 or used[key].size.y<=0 or not Rect2i(Vector2i.ZERO,Vector2i(textures[key].get_size())).encloses(used[key]):return {"accepted":false,"reason":"environment_crop_invalid:"+str(key)}
 host.sim.combat_event.connect(_event)
 process_priority=150
 return {"accepted":true,"reason":"assets_bound_not_runtime_acceptance","hero":"fengli","walking_cycle":"layered_four_phase_actual_displacement_unverified"}
func _current_scope()->String:
 return str(host.shop_session.run_id)+":"+str(host.sim.room_id)+":"+str(host.sim.encounter_generation)
func _event(event:Dictionary)->void:
 if bool(event.get("stale_generation",false)):return
 if str(event.get("run_id",""))!=host.shop_session.run_id or str(event.get("room_id",""))!=host.sim.room_id or int(event.get("generation",-1))!=host.sim.encounter_generation:return
 if not pitcher_zones.accept(event,host.sim,str(host.shop_session.run_id)):_visual_error(pitcher_zones.error);return
 var current:String=_current_scope()
 if current!=scope:scope=current;animation.clear();hit_reaction.clear();dash_trail.clear();contacts.clear();enemy_shots.clear();default_effects.clear();rescue_effects.clear();nail_effects.clear();_last_position=Vector3.INF;_walk_distance=0.0;_walking=false;_forced_motion_pending=false;_forced_motion_previous=false
 rescue_effects.accept(event,host.sim)
 var nail_pose:Dictionary=nail_effects.accept(event,host.sim)
 if not nail_pose.is_empty():animation=nail_pose
 var projected_skill:Dictionary=default_effects.accept(event,host.sim)
 if not projected_skill.is_empty():animation=projected_skill
 hit_reaction.accept(event,host.sim)
 var kind:String=str(event.get("kind",""))
 if kind in ["dash","e1_pierce_started","q2_started","q2_strike_started","q2_finished","e2_blink","e2_return"]:_forced_motion_pending=true
 if kind=="encounter_finished":animation.clear()
 if kind=="enemy_shot" and event.has_all(["actor_id","world_time","sequence"]):enemy_shots[str(event.actor_id)]=event.duplicate(true)
 if kind in ["attack_started","dash_attack_started","dash","q1_started","q3_started","e1_started","e1_pierce_started","r1_started"]:
  if host.sim.phase!="combat" or host.sim.hero.dead:return
  if not event.has_all(["cast_id","direction","world_time","real_time","hero_time"]):_visual_error("animation_source_missing");return
  if not event.direction is Vector3 or not event.direction.is_finite() or event.direction.length_squared()<0.000001:_visual_error("animation_direction_invalid");return
  if kind!="r1_started" and not event.get("animation") is Dictionary:_visual_error("animation_contract_missing");return
  animation=event.duplicate(true)
  if kind=="q1_started":animation["pose_prefix"]="q1"
  elif kind=="q3_started":animation["pose_prefix"]="attack" # Explicit existing sword pose reuse; Q3 source timing and real flying wave own mechanics.
  elif kind=="e1_started":animation["pose_prefix"]="e1throw"
  elif kind=="e1_pierce_started":animation["pose_prefix"]="dashattack" # Pose only; original hero clock and real path remain E1-owned.
  elif kind=="r1_started":
   if not event.get("duration") is float or not event.get("contact_after") is float or not is_finite(event.duration) or not is_finite(event.contact_after) or event.contact_after<0 or event.duration<event.contact_after:_visual_error("r1_animation_time_invalid");return
   animation["pose_prefix"]="attack" # Existing sword pose, not a new damage packet.
   animation["animation"]={"time_domain":"real","contact_after":event.contact_after,"recovery":event.duration-event.contact_after}
 elif kind=="attack_cancelled" and int(animation.get("cast_id",-1)) in event.get("cast_ids",[]):animation.clear()
 elif kind in ["r1_finished","e1_finished","q2_finished","e2_finished"] and int(animation.get("cast_id",-1))==int(event.get("cast_id",-2)):animation.clear()
 elif kind=="damage" and float(event.get("amount",0))>0.0 and str(event.get("target",""))!="fengli":
  if event.has_all(["position","cast_id","world_time","real_time","hero_time"]) and event.position is Vector3 and event.position.is_finite():
   contacts.append(event.duplicate(true))
   if contacts.size()>32:contacts.pop_front()
func _process(_dt:float)->void:
 active=is_instance_valid(host) and host.get_instance_id()==_owner_id and is_instance_valid(camera) and is_instance_valid(host.sim) and host.sim.get_instance_id()==_sim_id and is_instance_valid(host.shop_session) and host.shop_session.get_instance_id()==_session_id and host.shop_session._owner_intact() and visual_errors.is_empty()
 if not active:
  visible=false;_visual_error("presentation_owner_or_source_invalid");return
 visible=host.visible
 pitcher_zones.current(host.sim,str(host.shop_session.run_id))
 var current:String=_current_scope()
 if current!=scope:scope=current;animation.clear();hit_reaction.clear();dash_trail.clear();contacts.clear();enemy_shots.clear();default_effects.clear();rescue_effects.clear();nail_effects.clear();_last_position=Vector3.INF;_walk_distance=0.0;_walking=false;_forced_motion_pending=false;_forced_motion_previous=false
 var actual:Vector3=host.sim.hero.position
 var forced_now:bool=host.sim.hero.dash_left>0.0 or host.sim.hero.cast_state.has("e1_pierce") or host.sim.hero.cast_state.has("q2")
 default_effects.sample_q2(host.sim)
 var exclude_displacement:bool=_forced_motion_pending or _forced_motion_previous or forced_now
 _walking=false
 if _last_position.is_finite() and actual.is_finite():
  var distance:float=Vector2(actual.x-_last_position.x,actual.z-_last_position.z).length()
  if not exclude_displacement and distance>0.000001 and host.sim.hero.move_intent.length_squared()>0.000001 and host.sim.hero.dash_left<=0.0 and host.sim._hero_locomotion_allowed() and not host.sim.paused:
   _walk_distance+=distance;_walking=true
 if host.sim.hero.dead or host.sim.phase!="combat":dash_trail.clear()
 else:
  dash_trail=dash_trail.filter(func(sample:Dictionary)->bool:return host.sim.real_time-float(sample.time)<.15)
  if host.sim.hero.dash_left>0 and _last_position.is_finite() and actual.distance_to(_last_position)>.01 and not host.sim.paused:
   if dash_trail.is_empty() or host.sim.real_time-float(dash_trail.back().time)>.025:
    dash_trail.append({"position":actual,"time":host.sim.real_time,"mirror":_mirror})
    if dash_trail.size()>5:dash_trail.pop_front()
 _last_position=actual
 _forced_motion_pending=false;_forced_motion_previous=forced_now
 queue_redraw()
func _frame()->Dictionary:
 if animation.is_empty():
  var key:String="walk_"+["contact_a","passing_a","contact_b","passing_b"][int(floor(_walk_distance/0.45))%4] if _walking else "idle"
  return {"key":key,"direction":host.sim.hero.facing,"cast_id":-1,"phase":"walk" if _walking else "idle"}
 # A Q3 cancelled before or after release must not leave its reused sword pose.
 if str(animation.get("kind","")) in ["q3_started","e2_spin_started","r2_throw_started"] and not host.sim.cast_is_current(int(animation.get("cast_id",-1))):
  animation.clear()
  return {"key":"idle","direction":host.sim.hero.facing,"cast_id":-1,"phase":"idle"}
 var timing:Dictionary=animation.animation
 var domain:String=str(timing.get("time_domain",""))
 if domain not in ["real","world","hero"]:_visual_error("unknown_animation_clock");return {}
 var now:float=host.sim.real_time if domain=="real" else host.sim.hero_time if domain=="hero" else host.sim.clock.world_time
 var then:float=float(animation.real_time if domain=="real" else animation.hero_time if domain=="hero" else animation.world_time)
 var age:float=now-then
 var contact:float=float(timing.contact_after);var recovery:float=float(timing.recovery)
 if not is_finite(age) or not is_finite(contact) or not is_finite(recovery) or age<0 or contact<0 or recovery<0:_visual_error("animation_time_invalid");return {}
 var visual_settle:float=.10 if str(animation.kind)=="dash" else 0.0
 if age>contact+recovery+visual_settle:animation.clear();return {"key":"idle","direction":host.sim.hero.facing,"cast_id":-1,"phase":"idle"}
 if str(animation.kind)=="q2_strike_started":
  var key:String="dash" if age < contact * 0.65 else "dashattack_contact"
  return {"key":key,"direction":host.sim.hero.facing,"cast_id":int(animation.cast_id),"strike":int(animation.strike),"phase":"q2_travel" if key=="dash" else "q2_thrust","time_domain":domain,"age":age,"contact_is_hit":false}
 if str(animation.kind)=="dash":
  return {"key":"dash","direction":animation.direction,"cast_id":int(animation.cast_id),"phase":"dash","time_domain":domain,"age":age,"contact_is_hit":false}
 var phase:String="windup" if age<contact else ("contact" if age<contact+minf(0.08,recovery) else "recover")
 var prefix:String=str(animation.pose_prefix) if animation.has("pose_prefix") else ("dashattack" if animation.kind=="dash_attack_started" else "attack")
 return {"key":prefix+"_"+phase,"direction":animation.direction,"cast_id":int(animation.cast_id),"phase":phase,"time_domain":domain,"age":age,"contact_is_hit":false}
# Only texture sampling coordinates change. Logical destination/anchor/receipt
# coordinates stay in the validated original PNG coordinate system.
func _pose_texture_region(key:String,source:Rect2)->Rect2:
 var ratio:Vector2=pose_texture_scales[key]
 return Rect2(source.position*ratio,source.size*ratio)
func _hero()->void:
 var frame:Dictionary=_frame()
 if frame.is_empty() or not frames.has(frame.key):_visual_error("pose_unmapped");return
 var at:Vector2=p(host.sim.hero.position);var direction:Vector3=frame.direction
 if not direction.is_finite():_visual_error("facing_invalid");return
 var screen_direction:Vector2=p(host.sim.hero.position+direction)-at
 if absf(screen_direction.x)>0.001:_mirror=-1.0 if screen_direction.x<0 else 1.0
 var puppet:bool=int(frame.get("cast_id",-1))>=0 and str(animation.get("kind","")) in ["attack_started","dash","dash_attack_started"]
 if puppet:frame.key=puppet_motion.pose_key(animation,float(frame.get("age",0)))
 var meta:Dictionary=frames[frame.key];var r:Array=meta.region
 var region:=Rect2(r[0],r[1],r[2],r[3]);var anchor:=Vector2(meta.anchor[0],meta.anchor[1]);var scale:float=float(meta.scale)
 for sample:Dictionary in dash_trail:
  var ghost_meta:Dictionary=frames.dash;var ghost_r:Array=ghost_meta.region
  var ghost_region:=Rect2(ghost_r[0],ghost_r[1],ghost_r[2],ghost_r[3])
  var ghost_anchor:=Vector2(ghost_meta.anchor[0],ghost_meta.anchor[1])
  var alpha:float=.18*clampf(1-(host.sim.real_time-float(sample.time))/.15,0,1)
  draw_set_transform(p(sample.position),0,Vector2(float(sample.mirror),1))
  draw_texture_rect_region(pose_textures.dash,Rect2((ghost_region.position-ghost_anchor)*float(ghost_meta.scale),ghost_region.size*float(ghost_meta.scale)),_pose_texture_region("dash",ghost_region),Color(.4,.9,1,alpha))
 var body_rotation:float=0.0
 var body_scale:=Vector2.ONE
 var body_offset:=Vector2.ZERO
 if puppet:
  var body:Dictionary=puppet_motion.body_pose(animation,float(frame.get("age",0)))
  body_rotation=float(body.lean)*_mirror
  body_offset=Vector2(body.offset.x*_mirror,body.offset.y)
  body_scale=body.scale
 elif _walking:
  body_offset.y=-1.8*absf(sin(_walk_distance*PI/.9))
 var moving_basic:bool=puppet and str(animation.get("kind",""))=="attack_started" and _walking
 if moving_basic:
  # Keep the existing four authored leg poses under the attacking upper body.
  # The cycle follows actual permitted walking displacement, never action time.
  var leg_key:String="walk_"+["contact_a","passing_a","contact_b","passing_b"][int(floor(_walk_distance/0.45))%4]
  var leg:Dictionary=frames[leg_key];var lr:Array=leg.region
  var leg_region:=Rect2(lr[0],lr[1],lr[2],lr[3])
  draw_set_transform(at,0,Vector2(_mirror,1))
  draw_texture_rect_region(pose_textures[leg_key],Rect2((leg_region.position-Vector2(leg.anchor[0],leg.anchor[1]))*float(leg.scale),leg_region.size*float(leg.scale)),_pose_texture_region(leg_key,leg_region))
  frame["locomotion_legs"]=leg_key
 draw_set_transform(at+body_offset,body_rotation,Vector2(_mirror,1.0)*body_scale)
 if puppet:
  puppet_motion.draw_pose(self,pose_textures[frame.key],str(frame.key),animation,float(frame.get("age",0)),anchor,scale,moving_basic)
  receipt.puppet_motion=puppet_motion.receipt.duplicate(true)
 else:
  receipt.puppet_motion={}
  draw_texture_rect_region(pose_textures[frame.key],Rect2((region.position-anchor)*scale,region.size*scale),_pose_texture_region(str(frame.key),region))
 if str(frame.key).begins_with("walk_"):
  var upper:Dictionary=frames.walk_upper_frozen_cut;var ur:Array=upper.region
  var src:=Rect2(ur[0],ur[1],ur[2],ur[3])
  draw_texture_rect_region(pose_textures.walk_upper_frozen_cut,Rect2((src.position-Vector2(upper.anchor[0],upper.anchor[1]))*float(upper.scale),src.size*float(upper.scale)),_pose_texture_region("walk_upper_frozen_cut",src))
 draw_set_transform(Vector2.ZERO)
 if screen_direction.length_squared()>0.001:
  var d:Vector2=screen_direction.normalized()
  var cue_at:Vector2=at # Ground aim convention until Wind-specific body-plane calibration.
  if not cue_at.is_finite():_visual_error("basic_cue_projection_nonfinite");return
  var end:Vector2=cue_at+d*23
  draw_line(cue_at+d*14,end,OUTLINE,5,true);draw_line(cue_at+d*14,end,CYAN,3,true)
 receipt.hero_frame=frame.merged({"mirror_x":_mirror,"anchor":meta.anchor,"scale":scale,"world_position":host.sim.hero.position},true)
func _draw()->void:
 if not active:return
 _draw_environment()
 receipt={"host_id":_owner_id,"sim_id":_sim_id,"session_id":_session_id,"scope":scope,"source_time":host.sim.clock.world_time,"real_time":host.sim.real_time,"hero_time":host.sim.hero_time,"errors":visual_errors.duplicate(),"walking_cycle":"layered_four_phase_actual_displacement_unverified"}
 # The actual terminal owns death; never leave a standing sprite after true_dead.
 if host.sim.hero.dead:rescue_effects.clear();nail_effects.clear();return
 _draw_room_exit()
 default_effects.draw_ground(self,host.sim)
 _e2_shadow_body()
 if not default_effects.error.is_empty():_visual_error(default_effects.error);return
 # Hostile telegraphs remain on top of player ground effects.
 _draw_pitcher_zones()
 _draw_warnings()
 var hero_foot:Vector2=p(host.sim.hero.position)
 if not hero_foot.is_finite():_visual_error("actor_depth_nonfinite");return
 var actors:Array=[{"hero":true,"y":hero_foot.y,"tie":0}]
 ellipse(hero_foot+Vector2(0,2),Vector2(20,7),Color("10142690"))
 for index:int in range(host.sim.enemies.size()):
  var enemy:Dictionary=host.sim.enemies[index]
  if enemy.dead:continue
  var foot:Vector2=p(enemy.position)
  if not foot.is_finite():_visual_error("actor_depth_nonfinite");return
  ellipse(foot+Vector2(0,2),Vector2(14,5),Color("10142690"))
  actors.append({"hero":false,"enemy":enemy,"y":foot.y,"tie":index+1})
 actors.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return float(a.y)<float(b.y) if float(a.y)!=float(b.y) else int(a.tie)<int(b.tie))
 var order:Array=[]
 for actor:Dictionary in actors:
  if actor.hero:_hero();order.append({"actor_id":"fengli","screen_y":actor.y})
  else:_draw_enemy(actor.enemy);order.append({"actor_id":actor.enemy.actor_id,"screen_y":actor.y})
 receipt.actor_draw_order=order
 # Bars are readable after all actor sprites, without changing source HP.
 for enemy:Dictionary in host.sim.enemies:
  if enemy.dead:continue
  var at:Vector2=p(enemy.position);var height:float=46.0 if enemy.kind=="minion" else 64.0
  draw_rect(Rect2(at+Vector2(-16,-height-4),Vector2(32,4)),OUTLINE)
  draw_rect(Rect2(at+Vector2(-15,-height-3),Vector2(30*clampf(float(enemy.hp)/float(enemy.max_hp),0,1),2)),RED)
 default_effects.draw_hits(self,host.sim)
 rescue_effects.draw(self,host.sim)
 nail_effects.draw(self,host.sim)
 receipt["r2_effects"]=nail_effects.receipt.duplicate(true)
 receipt["passive_rescue"]=rescue_effects.receipt.duplicate(true)
 receipt["default_skill_effects"]=default_effects.receipt.duplicate(true)
 _draw_enemy_projectiles()
 _draw_enemy_warning_overlay()
 boss_wave_effects.draw_foreground(self)
 receipt["boss_wave_effects"]=boss_wave_effects.receipt.duplicate(true)

func _draw_enemy(enemy:Dictionary)->void:
 var key:String={"minion":"enemy","elite":"elite","armored":"armored","boss":"boss","ranged":"ranged","pouncer":"pouncer","support":"support","pitcher":"pitcher"}.get(str(enemy.kind),"")
 if key.is_empty():_visual_error("enemy_kind_unmapped:"+str(enemy.kind));return
 var at:Vector2=p(enemy.position);var height:float=46.0 if enemy.kind=="minion" else 64.0
 var reaction:Dictionary=hit_reaction.sample(host.sim,enemy)
 var amount:float=float(reaction.amount)
 var tilt:float=0
 if amount>0:
  var projected:Vector2=p(enemy.position+reaction.direction)-at
  tilt=signf(projected.x)*(.018 if key=="boss" else .045)*amount
 var tint:Color=Color.WHITE
 draw_set_transform(at,tilt,Vector2(1+.035*amount,1-.035*amount))
 if not receipt.has("enemy_hit_reactions"):receipt.enemy_hit_reactions=[]
 if amount>0:receipt.enemy_hit_reactions.append({"actor_id":enemy.actor_id,"sequence":reaction.sequence,"pulse":amount,"source_position":enemy.position,"visual_only":true})
 if key in ["ranged","pouncer","support","pitcher"]:
  var pose:int=1 if str(enemy.state)=="warning" else 0
  if key=="pouncer" and str(enemy.state)=="pounce":pose=2
  elif enemy_shots.has(str(enemy.actor_id)):
   var shot_age:float=host.sim.clock.world_time-float(enemy_shots[str(enemy.actor_id)].world_time)
   if shot_age>=0.0 and shot_age<0.16:pose=2
  if key=="pitcher":pose=_pitcher_pose(enemy)
  var destination:=Rect2(-Vector2(64,70),Vector2(128,96));var source:=Rect2(pose*128,0,128,96)
  draw_texture_rect_region(textures[key],destination,source,tint)
  _flash_sprite(key,destination,source,amount)
 else:_reaction_sprite(key,height,tint,amount)
 draw_set_transform(Vector2.ZERO)

func _reaction_sprite(key:String,height:float,tint:Color,amount:float)->void:
 # Same original asset region and authoritative foot anchor as _sprite.
 if not textures.has(key):return
 var src:=Rect2(used[key]);var ratio:float=height/src.size.y
 var anchor:=Vector2(src.size.x*.5,src.size.y)
 if key=="elite":anchor=Vector2(490,910)-src.position
 if key in ["armored","boss"]:
  var foot:Array=enemy_asset_meta.get(key,{}).get("foot_anchor",[])
  if foot.size()!=2:_visual_error("missing_enemy_foot:"+key);return
  anchor=Vector2(float(foot[0]),float(foot[1]))-src.position
 var destination:=Rect2(-anchor*ratio,src.size*ratio)
 draw_texture_rect_region(textures[key],destination,src,tint)
 _flash_sprite(key,destination,src,amount)
func _flash_sprite(key:String,destination:Rect2,source:Rect2,amount:float)->void:
 if amount<=0 or not enemy_flash.has(key):return
 var ratio:Vector2=enemy_flash_ratio[key]
 draw_texture_rect_region(enemy_flash[key],destination,Rect2(source.position*ratio,source.size*ratio),Color(1.0,.95,.82,.62*amount))


func _draw_room_exit()->void:
 var gate:Dictionary=host.shop_session.room_exit_view()
 var at:Vector3=gate.position
 var half:Vector2=gate.half
 var completed:bool=str(host.shop_session.status)=="completed"
 var ready:bool=bool(gate.ready) and not completed
 var color:Color=Color("c1fa59") if completed else (Color("37f5d6") if ready else Color("536371"))
 var left:Vector2=p(at+Vector3(-half.x,0,0))
 var right:Vector2=p(at+Vector3(half.x,0,0))
 var rise:Vector2=Vector2(0,-30)
 line(left,right,Color("182038"),10.0)
 line(left,left+rise,color,5.0);line(left+rise,right+rise,color,5.0);line(right+rise,right,color,5.0)
 if ready:
  for distance:float in [1.2,2.2]:
   var center:Vector3=at+Vector3(0,0,distance)
   line(p(center+Vector3(-.42,0,.25)),p(center+Vector3(0,0,-.25)),Color("c1fa59"),4.0)
   line(p(center+Vector3(0,0,-.25)),p(center+Vector3(.42,0,.25)),Color("c1fa59"),4.0)
 elif not completed:line(left.lerp(right,.25)+rise*.45,left.lerp(right,.75)+rise*.45,Color("ed797f"),5.0)
 var label:String="向上进入路线" if ready else ("完成服务后开启" if str(host.shop_session.status)=="service" else "清敌后开启")
 if completed:label="首层已完成"
 elif ready and bool(gate.reenter_required):label="离开门口再进入"
 draw_string(font,(left+right)*.5+Vector2(-56,-42),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
 receipt["room_exit"]=gate.duplicate(true)
 receipt["room_exit_display"]={"completed":completed,"ready_visual":ready,"label":label,"source_status":str(host.shop_session.status)}


func _draw_warnings()->void:
 boss_wave_effects.draw(self,host.sim)
 receipt["boss_wave_effects"]=boss_wave_effects.receipt.duplicate(true)
 if not boss_wave_effects.error.is_empty():_visual_error(boss_wave_effects.error);return

func _exact_numbers(value:Variant,expected:Array)->bool:
 if not value is Array or value.size()!=expected.size():return false
 for index in range(expected.size()):
  var number:Variant=value[index]
  if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=floor(float(number)) or float(number)!=float(expected[index]):return false
 return true
func _exact_regions(value:Variant)->bool:
 if not value is Array or value.size()!=3:return false
 for index in range(3):
  if not _exact_numbers(value[index],[index*128,0,128,96]):return false
 return true

# Presentation only. Warning comes from committed enemy state; release requires
# the current-scope director's actual lob event, never a presentation timer.
func _pitcher_pose(enemy:Dictionary)->int:
 if str(enemy.state)=="warning":return 1
 if str(enemy.state)!="recover":return 0
 var shot:Dictionary=enemy_shots.get(str(enemy.actor_id),{})
 if shot.is_empty() or str(shot.get("enemy_kind",""))!="pitcher" or str(shot.get("projectile_type",""))!="lob":return 0
 var age:float=host.sim.clock.world_time-float(shot.world_time)
 return 2 if age>=0.0 and age<0.16 else 0

func _draw_pitcher_zones()->void:
 var zones:Array=pitcher_zones.current(host.sim,str(host.shop_session.run_id))
 if not pitcher_zones.error.is_empty():_visual_error(pitcher_zones.error);return
 var shown:Array=[]
 for zone:Dictionary in zones:
  var boundary:=PackedVector2Array()
  for index:int in range(48):
   var angle:float=TAU*float(index)/48.0
   var point:Vector2=p(zone.position+Vector3(cos(angle),0,sin(angle))*float(zone.radius))
   if not point.is_finite():_visual_error("pitcher_zone_projection_nonfinite");return
   boundary.append(point)
  # Filled ink and a continuous edge use the exact active damage disc.
  draw_colored_polygon(boundary,Color(0.42,0.12,0.38,0.24))
  boundary.append(boundary[0])
  draw_polyline(boundary,Color(0.86,0.33,0.67,0.88),2.0,true)
  shown.append({"owner":zone.owner,"position":zone.position,"radius":zone.radius,"left":zone.left,"room_id":host.sim.room_id,"generation":host.sim.encounter_generation})
 receipt["hostile_zones"]=shown

func _e2_shadow_body()->void:
 var shadow:Dictionary=default_effects.e2_shadow(host.sim)
 if shadow.is_empty():return
 # A tinted copy of the existing idle sprite, not a new actor or target.
 var meta:Dictionary=frames.idle;var r:Array=meta.region
 var region:=Rect2(r[0],r[1],r[2],r[3])
 var anchor:=Vector2(meta.anchor[0],meta.anchor[1]);var scale:float=float(meta.scale)
 var at:Vector2=p(shadow.position)
 var along:Vector2=p(shadow.position+shadow.facing)-at
 var mirror:float=-1.0 if along.x<0 else 1.0
 var alpha:float=.28*minf(1.0,float(shadow.left)/.4)
 draw_set_transform(at,0.0,Vector2(mirror,1.0))
 draw_texture_rect_region(pose_textures.idle,Rect2((region.position-anchor)*scale,region.size*scale),_pose_texture_region("idle",region),Color(.75,.45,.72,alpha))
 draw_set_transform(Vector2.ZERO)

# Only authenticated, build-generated native Image resources reach ResourceLoader.
# The manifest digest is pinned in this reviewed source, never learned at runtime.
func _load_pose_cache(key:String,meta:Dictionary,original_size:Vector2i)->Dictionary:
 if pose_cache_manifest.is_empty():
  var manifest_path:String=POSE_CACHE_ROOT+"manifest.json"
  if POSE_CACHE_MANIFEST_SHA256.length()!=64 or FileAccess.get_sha256(manifest_path)!=POSE_CACHE_MANIFEST_SHA256:return {"accepted":false,"reason":"pose_cache_manifest_digest"}
  var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
  if not parsed is Dictionary or parsed.get("schema","")!="fengli-derived-image-cache-1" or not parsed.get("poses") is Dictionary:return {"accepted":false,"reason":"pose_cache_manifest_invalid"}
  var keys:Array=parsed.poses.keys();keys.sort()
  var expected:Array=frames.keys();expected.sort()
  if keys!=expected:return {"accepted":false,"reason":"pose_cache_pose_set"}
  pose_cache_manifest=parsed
 var entry:Variant=pose_cache_manifest.poses.get(key)
 if not entry is Dictionary or not entry.has_all(["source_sha256","resource_sha256","pixel_sha256","resource_bytes","source_size","size","format","mipmaps"]):return {"accepted":false,"reason":"pose_cache_entry:"+key}
 if entry.source_sha256!=meta.sha256 or not _exact_numbers(entry.source_size,[original_size.x,original_size.y]) or not _exact_numbers(entry.size,[384,256]) or entry.format!="RGBA8" or entry.mipmaps!=false:return {"accepted":false,"reason":"pose_cache_contract:"+key}
 var path:String=POSE_CACHE_ROOT+key+".res"
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:return {"accepted":false,"reason":"pose_cache_missing:"+key}
 var length:int=file.get_length();file.close()
 if length!=entry.resource_bytes or length<=0 or length>524288 or FileAccess.get_sha256(path)!=entry.resource_sha256:return {"accepted":false,"reason":"pose_cache_resource_digest:"+key}
 var loaded:Resource=ResourceLoader.load(path,"Image",ResourceLoader.CACHE_MODE_IGNORE)
 if not loaded is Image or loaded.get_script()!=null:return {"accepted":false,"reason":"pose_cache_image_type:"+key}
 var image:Image=loaded as Image
 if image.get_size()!=Vector2i(384,256) or image.get_format()!=Image.FORMAT_RGBA8 or image.has_mipmaps():return {"accepted":false,"reason":"pose_cache_image_shape:"+key}
 var data:PackedByteArray=image.get_data()
 var digest:=HashingContext.new()
 if data.size()!=393216 or digest.start(HashingContext.HASH_SHA256)!=OK or digest.update(data)!=OK or digest.finish().hex_encode()!=entry.pixel_sha256:return {"accepted":false,"reason":"pose_cache_pixel_digest:"+key}
 return {"accepted":true,"image":image}

func _draw_enemy_warning_overlay()->void:
 var shown:Array=[]
 for enemy:Dictionary in host.sim.enemies:
  if enemy.dead or str(enemy.state)!="warning":continue
  if str(enemy.kind)=="boss" and str(enemy.get("attack_shape",""))=="boss_wave_line":
   if boss_wave_effects.handles_warning(enemy):continue
   _visual_error("boss_wave_warning_snapshot_missing");continue
  if not enemy.has_all(["committed_origin","aim","attack_shape","attack_range","attack_angle","attack_width"]):_visual_error("enemy_warning_source_missing");continue
  var origin:Vector3=enemy.committed_origin;var direction:Vector3=enemy.aim
  var reach:float=float(enemy.attack_range);var width:float=float(enemy.attack_width);var angle:float=float(enemy.attack_angle)
  if not origin.is_finite() or not direction.is_finite() or direction.length_squared()<0.000001 or not is_finite(reach) or not is_finite(width) or not is_finite(angle):_visual_error("enemy_warning_source_invalid");continue
  # Director commits a body/weapon warning, NOT a filled lane damage region.
  # This short screen-space cue communicates facing only, never attack_range.
  if str(enemy.get("telegraph_style",""))!="body_weapon" or bool(enemy.get("ground_warning",false)):
   _visual_error("unsupported_warning_contract");continue
  var cue:Dictionary=EnemyWarningCue.project(enemy,p(enemy.position),p(enemy.position+direction)-p(enemy.position))
  if not cue.accepted:_visual_error("enemy_body_cue_invalid");continue
  EnemyWarningCue.draw(self,cue)
  if cue.visible:shown.append(cue.duplicate())
 receipt["enemy_warning_cues"]=shown

func _draw_enemy_projectiles()->void:
 var shown:Array=[]
 for projectile:Dictionary in host.sim.projectiles:
  if str(projectile.get("team",""))!="enemy":continue
  if not projectile.has_all(["position","radius","id","direction","type"]):_visual_error("enemy_projectile_source_missing");continue
  if not projectile.position is Vector3 or not projectile.position.is_finite() or not projectile.direction is Vector3 or not projectile.direction.is_finite():_visual_error("enemy_projectile_source_invalid");continue
  var at:Vector2=p(projectile.position)
  var radius:float=p(projectile.position+Vector3(float(projectile.radius),0,0)).distance_to(at)
  var forward:Vector2=p(projectile.position+projectile.direction)-at
  if str(projectile.type)=="lob":
   var height:Variant=projectile.get("height",null)
   if not (height is float or height is int) or not is_finite(float(height)) or float(height)<0:_visual_error("lob_height_invalid");continue
   var lob:Dictionary=LobCue.project(projectile,at,p(projectile.position+Vector3.UP*float(height)),radius)
   if not lob.accepted:_visual_error("lob_cue_invalid");continue
   LobCue.draw(self,lob);shown.append(lob);continue
  var cue:Dictionary=ProjectileCue.project(projectile,at,forward,radius)
  if not cue.accepted:_visual_error("enemy_projectile_cue_invalid");continue
  ProjectileCue.draw(self,cue)
  shown.append(cue)
 receipt["enemy_projectile_cues"]=shown
