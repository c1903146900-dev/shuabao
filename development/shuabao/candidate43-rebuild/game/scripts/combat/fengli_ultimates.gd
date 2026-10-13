extends RefCounted
## Source-final Wind ultimate state machines. Presentation timings are explicit tuning.
## Simulation owns collision/damage; art and audio consume emitted events only.
const T=preload("res://data/combat/fengli_tuning.gd")
const Sweep=preload("res://scripts/combat/swept_rectangle_geometry.gd")
const EPS:float=0.0000001
var _owner:WeakRef
var nails:Array=[]
var _completed_basics:Dictionary={}
func _init(owner)->void:_owner=weakref(owner)
func s():return _owner.get_ref()
func v(token:String,rank:int)->float:return T.parameter(token,rank)
func f(token:String,rank:int)->float:return T.fraction(token,rank)
func policy(action:String)->Dictionary:
 var h=s().hero
 if h.cast_state.has("r1"):return {"reason":"ultimate_presentation"}
 if action=="r" and h.loadout.r=="r2" and h.cast_state.has("r2"):
  var state:Dictionary=h.cast_state.r2
  if state.sequence_ended:return {"reason":"sequence_finished"}
  if int(state.round)>=int(state.max_rounds):return {"reason":"no_throws"}
  if float(state.window_until)<=s().hero_time+EPS:return {"reason":"recast_expired"}
  if s().hero_time+float(T.runtime().skills.R2.release_after)>float(state.window_until)+EPS:return {"reason":"recast_release_too_late"}
  return {"bypass_cooldown":true,"cast_id":state.cast_id,"stage":"throw"}
 return {}
func start(context:Dictionary)->Dictionary:
 return _start_r1(context) if s().hero.loadout.r=="r1" else _start_r2(context)
func _start_r1(context:Dictionary)->Dictionary:
 var sim=s();var h=sim.hero;var rank:int=int(h.ranks.r)
 var duration:float=v("R1-5",rank)
 var contact:float=float(T.runtime().skills.R1.contact_after)
 h.cast_state.r1={"cast_id":context.cast_id,"rank":rank,"left":duration,"until":sim.real_time+duration,"settled":false,"generation":sim.encounter_generation,"room_id":sim.room_id}
 sim.start_skill_cooldown("r",v("R1-6",rank))
 h.lock_time=maxf(h.lock_time,duration)
 sim.start_presentation(context,duration)
 sim.schedule_effect(context,"wind_r1_contact",contact,{"rank":rank},"real")
 sim.emit_event("r1_started",{"cast_id":context.cast_id,"position":h.position,"direction":context.direction,"radius":v("R1-1",rank),"duration":duration,"contact_after":contact})
 return {"accepted":true}
func _start_r2(context:Dictionary)->Dictionary:
 var sim=s();var h=sim.hero
 if not h.cast_state.has("r2"):
  var rank:int=int(h.ranks.r)
  h.cast_state.r2={"cast_id":context.cast_id,"rank":rank,"round":0,"max_rounds":int(v("R2-9",rank))+(int(sim.hv("h18")) if sim.wind_hex("h18") else 0),"basic_count":0,"window_until":sim.hero_time+float(T.runtime().skills.R2.release_after)+v("R2-10",rank),"throw_until":sim.hero_time,"released":false,"startup_complete":false,"startup_until":sim.hero_time+v("R2-12",rank),"sequence_ended":false,"generation":sim.encounter_generation,"room_id":sim.room_id}
  h.cooldowns.r=0.0
 var state:Dictionary=h.cast_state.r2
 state.round+=1
 var count:int=int(v("R2-11",state.rank))+(int(sim.hv("h19")) if sim.wind_hex("h19") else 0)
 if int(state.round)>1:count+=int(state.basic_count)
 var duration:float=v("R2-12",state.rank)
 var release:float=float(T.runtime().skills.R2.release_after)
 state.throw_until=sim.hero_time+duration
 h.lock_time=maxf(h.lock_time,duration)
 sim.schedule_effect(context,"wind_r2_release",release,{"rank":state.rank,"round":state.round,"count":count,"ad":h.ad()},"hero")
 sim.emit_event("r2_throw_started",{"cast_id":state.cast_id,"round":state.round,"count":count,"position":h.position,"direction":context.direction,"duration":duration,"contact_after":release,"length":v("R2-6",state.rank),"width":v("R2-7",state.rank)})
 return {"accepted":true}
func resolve(effect:Dictionary)->void:
 if not s().effect_is_current(effect):return
 if effect.kind=="wind_r1_contact":_r1_contact(effect)
 elif effect.kind=="wind_r2_release":_r2_release(effect)
func _r1_contact(effect:Dictionary)->void:
 var sim=s();var h=sim.hero
 if not h.cast_state.has("r1") or h.cast_state.r1.settled:return
 h.cast_state.r1.settled=true
 var origin:Vector3=h.position;var radius:float=v("R1-1",effect.rank)
 var targets:Array=sim.circle_targets(origin,radius)
 var amount:float=v("R1-2",effect.rank)+h.ad()*f("R1-3",effect.rank)
 sim.emit_event("r1_release",{"cast_id":effect.cast_id,"position":origin,"direction":effect.direction,"radius":radius})
 var live:Array=sim.common.runtime._enemies(sim.common.context())
 var mode:String="horde" if live.size()>=int(sim.common.runtime.parameter("g22",1)) else "duel" if live.size()==1 and not sim.ordinary(live[0]) else "none"
 var impact:Dictionary={"g22_mode_snapshot":mode,"impact_penetration":float(h.stats.penetration),"impact_lifesteal_rate":h.lifesteal()}
 var ids:Array=[];var executed:Array=[]
 # One target-set and damage amount snapshot; all packets share the same tick.
 for target in targets:
  if not sim.claim_hit(effect.cast_id,target.actor_id,"r1_unified"):continue
  ids.append(target.actor_id)
  var metadata:Dictionary=impact.duplicate()
  metadata.merge({"position":origin,"direction":effect.direction,"cast_damage_share":1.0/maxi(1,targets.size())},true)
  sim.damage_enemy(target,amount,"r1",effect.cast_id,false,false,metadata)
  if not target.dead and float(target.hp)/maxf(EPS,float(target.max_hp))<f("R1-4",effect.rank)-1e-12:
   executed.append(target.actor_id)
   sim._kill_enemy(target,"r1_execute",effect.cast_id)
   sim.emit_event("r1_execute",{"cast_id":effect.cast_id,"target":target.actor_id,"position":target.position})
 sim.emit_event("r1_impact",{"cast_id":effect.cast_id,"position":origin,"direction":effect.direction,"radius":radius,"target_ids":ids,"executed_ids":executed,"hit_count":ids.size()})
func presentation_finished(cast_id:int)->void:
 var sim=s();var h=sim.hero
 if not h.cast_state.has("r1") or int(h.cast_state.r1.cast_id)!=cast_id:return
 var restored:float=0.0
 if sim.wind_hex("h16"):restored=sim.heal(float(h.stats.max_hp)*sim.hf("h16"),false,{"source":"fengli_h16","cast_id":cast_id})
 h.cast_state.erase("r1")
 sim.finish_cast(cast_id)
 sim.emit_event("r1_finished",{"cast_id":cast_id,"position":h.position,"healed":restored})
func _r2_release(effect:Dictionary)->void:
 var sim=s();var h=sim.hero
 if not h.cast_state.has("r2") or int(h.cast_state.r2.cast_id)!=int(effect.cast_id):return
 var state:Dictionary=h.cast_state.r2
 state.released=true;state.window_until=sim.hero_time+v("R2-10",state.rank)
 # All nail fronts share the authored rectangular lane. They are separate actual
 # projectiles, and each may damage each target once; no instant full-lane packet.
 for index in range(int(effect.count)):
  var nail:Dictionary={"id":"bone_nail:%d:%d:%d:%d"%[sim.encounter_generation,effect.cast_id,effect.round,index],"type":"bone_nail","cast_id":effect.cast_id,"round":effect.round,"index":index,"count":effect.count,"rank":effect.rank,"position":h.position,"origin":h.position,"direction":effect.direction,"width":v("R2-7",effect.rank),"range":v("R2-6",effect.rank),"remaining":v("R2-6",effect.rank),"travelled":0.0,"speed":v("R2-8",effect.rank),"last_step_at":sim.clock.world_time,"ad":effect.ad,"hit_ids":[],"true_fraction":sim.hf("h17") if sim.wind_hex("h17") else 0.0,"generation":sim.encounter_generation,"room_id":sim.room_id}
  nails.append(nail)
 sim.emit_event("r2_throw",{"cast_id":effect.cast_id,"round":effect.round,"count":effect.count,"position":h.position,"direction":effect.direction,"length":v("R2-6",effect.rank),"width":v("R2-7",effect.rank),"speed":v("R2-8",effect.rank),"window":v("R2-10",effect.rank)})
func step()->void:
 var sim=s();var h=sim.hero
 if h.cast_state.has("r1"):h.cast_state.r1.left=maxf(0.0,float(h.cast_state.r1.until)-sim.real_time)
 if h.cast_state.has("r2"):
  var state:Dictionary=h.cast_state.r2
  if not bool(state.get("startup_complete",false)) and sim.hero_time+EPS>=float(state.startup_until):
   state.startup_complete=true;sim.common.ultimate_ready(state.cast_id)
   sim.emit_event("r2_presentation_finished",{"cast_id":state.cast_id,"position":h.position})
  if not state.sequence_ended and bool(state.released):
   if (int(state.round)>=int(state.max_rounds) and sim.hero_time+EPS>=float(state.throw_until)) or sim.hero_time+EPS>=float(state.window_until):_end_r2_sequence("last_throw" if int(state.round)>=int(state.max_rounds) else "window_expired")
 _step_nails()
 _finish_r2_if_settled()
func _step_nails()->void:
 var sim=s()
 for nail in nails.duplicate():
  if not sim.effect_is_current(nail) or sim.hero.dead:_expire(nail,"cancelled");continue
  var dt:float=maxf(0.0,sim.clock.world_time-float(nail.last_step_at));nail.last_step_at=sim.clock.world_time
  if dt<=EPS:continue
  var origin:Vector3=nail.position
  var barrier:Dictionary=Sweep.clip_front(origin,nail.direction,nail.remaining,nail.width,sim.obstacles,sim.arena_half_extent)
  var requested:float=minf(nail.remaining,nail.speed*dt)
  var clipped:Dictionary=barrier if float(barrier.distance)<=requested+EPS else {"position":origin+nail.direction*requested,"distance":requested,"blocked":false,"reason":""}
  var shape:Dictionary={"kind":"rectangle","direction":nail.direction,"length":clipped.distance,"width":nail.width,"circle_rectangle":true,"clipped_front":clipped.blocked}
  if barrier.blocked:shape.forward_limit=barrier.distance
  var targets:Array=sim.shape_targets(origin,nail.direction,shape)
  for target in targets:
   if not sim.claim_hit(nail.cast_id,target.actor_id,nail.id):continue
   nail.hit_ids.append(target.actor_id)
   var amount:float=v("R2-1",nail.rank)+float(nail.ad)*f("R2-2",nail.rank)+float(target.max_hp)*f("R2-3",nail.rank)
   sim.damage_enemy(target,amount,"r2_nail",nail.cast_id,false,false,{"position":origin,"direction":nail.direction,"round":nail.round,"occurrence":nail.index+1,"nail_id":nail.id,"r2_true_fraction":nail.true_fraction,"cast_damage_share":1.0/maxi(1,targets.size())})
   if not target.dead:sim.apply_control(target,"slow",v("R2-5",nail.rank),f("R2-4",nail.rank),{"source":"r2_nail"})
   sim.emit_event("r2_contact",{"id":nail.id,"cast_id":nail.cast_id,"round":nail.round,"index":nail.index,"target":target.actor_id,"position":target.position,"direction":nail.direction})
  nail.position=clipped.position;nail.travelled+=float(clipped.distance);nail.remaining=maxf(0.0,float(nail.range)-float(nail.travelled))
  if clipped.blocked or nail.remaining<=EPS:_expire(nail,clipped.reason if clipped.blocked else "range")
func after_damage(enemy:Dictionary,event:Dictionary)->void:
 if event.get("source","")!="r2_nail" or event.get("replay",false) or enemy.dead:return
 var ratio:float=float(event.get("r2_true_fraction",0.0))
 if ratio<=0.0:return
 s().damage_enemy(enemy,float(event.amount)*ratio,"r2_true",event.cast_id,true,bool(event.get("critical",false)),{"position":event.position,"direction":event.direction,"round":event.get("round",0),"occurrence":event.get("occurrence",0),"snapshot_final":true,"no_reactions":true,"hex_generated":true})
func basic_completed(event:Dictionary)->void:
 var sim=s();var h=sim.hero
 var identity:String="%d:%d"%[sim.encounter_generation,int(event.cast_id)]
 if _completed_basics.has(identity):return
 _completed_basics[identity]=true
 if h.loadout.r=="r1" and sim.wind_hex("h15") and h.cooldowns.r>EPS:
  h.cooldowns.r=maxf(0.0,float(h.cooldowns.r)-sim.hv("h15"))
  sim.emit_event("r1_cooldown_reduced",{"cast_id":event.cast_id,"remaining":h.cooldowns.r})
 if h.cast_state.has("r2") and h.cast_state.r2.released and not h.cast_state.r2.sequence_ended:
  h.cast_state.r2.basic_count+=1
  sim.emit_event("r2_basic_counted",{"cast_id":h.cast_state.r2.cast_id,"attack_cast_id":event.cast_id,"basic_count":h.cast_state.r2.basic_count})
func _end_r2_sequence(reason:String)->void:
 var sim=s();var state:Dictionary=sim.hero.cast_state.r2
 if state.sequence_ended:return
 state.sequence_ended=true;sim.start_skill_cooldown("r",v("R2-13",state.rank))
 sim.emit_event("r2_sequence_ended",{"cast_id":state.cast_id,"round":state.round,"basic_count":state.basic_count,"reason":reason})
func _finish_r2_if_settled()->void:
 var sim=s();var h=sim.hero
 if not h.cast_state.has("r2") or not h.cast_state.r2.sequence_ended:return
 var id:int=int(h.cast_state.r2.cast_id)
 if nails.any(func(n):return int(n.cast_id)==id):return
 h.cast_state.erase("r2");sim.finish_cast(id)
 sim.emit_event("r2_finished",{"cast_id":id,"position":h.position})
func _expire(nail:Dictionary,reason:String)->void:
 nails.erase(nail)
 s().emit_event("r2_nail_expired",{"id":nail.id,"cast_id":nail.cast_id,"position":nail.position,"reason":reason})
func cancel(cast_id:int)->void:
 var sim=s();var h=sim.hero
 if h.cast_state.has("r1") and int(h.cast_state.r1.cast_id)==cast_id:
  h.cast_state.erase("r1");sim._presentation.clear();sim.r1_active=false;sim.clock.leave(h.actor_id);h.lock_time=0.0
  sim.emit_event("r1_cancelled",{"cast_id":cast_id,"position":h.position})
 if h.cast_state.has("r2") and int(h.cast_state.r2.cast_id)==cast_id:
  if not h.cast_state.r2.sequence_ended:sim.start_skill_cooldown("r",v("R2-13",h.cast_state.r2.rank))
  h.cast_state.erase("r2")
 for nail in nails.duplicate():
  if int(nail.cast_id)==cast_id:_expire(nail,"cancelled")
func clear()->void:
 var h=s().hero
 for key in ["r1","r2"]:
  if h.cast_state.has(key):cancel(h.cast_state[key].cast_id)
 nails.clear();_completed_basics.clear()
func snapshot()->Dictionary:
 var sim=s();var h=sim.hero;var result:Dictionary={}
 if h.cast_state.has("r1"):
  result={"candidate":"r1","stage":"presentation","remaining":h.cast_state.r1.left,"cast_id":h.cast_state.r1.cast_id}
 elif h.cast_state.has("r2"):
  var state:Dictionary=h.cast_state.r2
  result={"candidate":"r2","stage":"settling" if state.sequence_ended else "throws","remaining":maxf(0.0,float(state.window_until)-sim.hero_time),"cast_id":state.cast_id,"round":state.round,"max_rounds":state.max_rounds,"basic_count":state.basic_count,"next_nails":int(v("R2-11",state.rank))+(int(sim.hv("h19")) if sim.wind_hex("h19") else 0)+int(state.basic_count)}
 return {"wind_ultimate":result,"wind_nails":nails.duplicate(true)}
