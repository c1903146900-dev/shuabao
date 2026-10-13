extends Node
## Deterministic hero-neutral combat services. Concrete heroes own every skill and value.
## This class deliberately does not inherit Xuanlei and grants no progression rewards.
signal combat_event(event: Dictionary)
signal encounter_finished(result: Dictionary)
signal state_changed(snapshot: Dictionary)
const ActorCore=preload("res://scripts/actors/hero_model_core.gd")
const Clock=preload("res://scripts/combat/world_clock.gd")
const Ledger=preload("res://scripts/combat/loadout_fixture.gd")
const CommonBridge=preload("res://scripts/combat/common_hex_bridge.gd")
const EnemyDirector=preload("res://scripts/combat/enemy_director.gd")
const Design=preload("res://data/final_design/catalog.gd")
const SweptRectangle=preload("res://scripts/combat/swept_rectangle_geometry.gd")
const FIXED_TICK: float=0.02
const TIME_EPS: float=0.0000001
var hero=ActorCore.new()
var progression=Ledger.new()
var common=CommonBridge.new(self)
var clock=Clock.new()
var enemy_director=EnemyDirector.new()
var allies: Array=[]
var phase: String="preparation"
var paused: bool=false
var combat_level_id: String="hero-room-1"
var room_id: String="hero-room-1"
var wave: int=0
var enemies: Array=[]
var pending: Array=[]
var projectiles: Array=[]
var zones: Array=[]
var event_log: Array=[]
var sequence: int=0
var cast_serial: int=0
var enemy_serial: int=0
var revision: int=0
var encounter_generation: int=0
var auto_finish: bool=true
var ai_enabled: bool=true
var transaction_active: bool=false
var seen_commands: Dictionary={}
var real_accumulator: float=0.0
var real_time: float=0.0
var hero_time: float=0.0 # Actor action clock; concrete ultimate casters may ignore world slow.
var rng=_create_seeded_rng()
var arena_half_extent: float=22.0 # Host geometry default, independently configurable.
var hero_radius: float=0.65
var obstacles: Array=[]
var spatial: Dictionary={}
var pair_checks: int=0
var collision_pairs: Dictionary={}
var frozen_snapshot: Dictionary={}
var r1_active: bool=false # Legacy director compatibility: presentation only.
var dash_attack: Dictionary={}
var dash_serial: int=0
var dash_step_immune: bool=false
var dash_iframe_left: float=0.0
var _dash_state: Dictionary={}
var _presentation: Dictionary={}
var _casts: Dictionary={}
var _hit_claims: Dictionary={}
var _effect_claims: Dictionary={}
var _effect_serial: int=0
var _action_stage: String=""
var _common_zone_tick: bool=false

func _create_seeded_rng() -> RandomNumberGenerator:
 var generator=RandomNumberGenerator.new()
 generator.seed=20261001
 return generator

func emit_event(kind: String, data: Dictionary={}) -> void:
 sequence+=1
 var event=data.duplicate(true)
 event.merge(_hero_animation(kind,event.duplicate(true)),true)
 event.merge({"kind":kind,"sequence":sequence,"world_time":clock.world_time,"real_time":real_time,"combat_level_id":combat_level_id,"room_id":room_id,"wave":wave,"generation":encounter_generation},true)
 event_log.append(event.duplicate(true))
 if event_log.size()>300: event_log.pop_front()
 combat_event.emit(event.duplicate(true))

func snapshot() -> Dictionary:
 var h: Dictionary=hero.snapshot()
 h.invulnerable=hero_damage_immune()
 var friends: Array=[]
 for ally in allies: friends.append(ally.snapshot())
 var result: Dictionary={"definition_version":"hero-combat-core-1","phase":phase,"paused":paused,"combat_level_id":combat_level_id,"room_id":room_id,"wave":wave,"generation":encounter_generation,"world_time":clock.world_time,"real_time":real_time,"hero_time":hero_time,"hero_time_scale":_hero_time_delta(clock.scale_factor(),1.0),"world_scale":clock.scale_factor(),"revision":revision,"hero":h,"allies":friends,"enemies":enemies,"pending":pending,"projectiles":projectiles,"zones":zones,"event_sequence":sequence,"common_hexes":common_snapshot(),"progression":progression.snapshot(),"pair_checks":pair_checks,"arena_half_extent":arena_half_extent}
 result.merge(_hero_snapshot(),true)
 return result.duplicate(true)

func begin_encounter(next_id: String, roster: Array) -> Dictionary:
 if transaction_active or phase=="combat" or hero.dead: return {"accepted":false,"reason":"invalid_phase"}
 if next_id.is_empty(): return {"accepted":false,"reason":"missing_room_id"}
 _clear_wave_transients()
 combat_level_id=next_id;room_id=next_id;wave+=1;encounter_generation+=1
 enemies.clear();seen_commands.clear();_casts.clear();_hit_claims.clear();_effect_claims.clear();collision_pairs.clear()
 phase="combat";paused=false;real_accumulator=0
 progression.begin_encounter()
 for entry in roster: spawn_enemy(entry.kind,entry.position,entry.get("hp",-1.0))
 common.begin_room()
 emit_event("encounter_started")
 return {"accepted":true,"reason":"ok"}

func _clear_wave_transients() -> void:
 for id in _casts:
  if not _casts[id].cancelled: _casts[id].cancelled=true
 pending.clear();projectiles.clear();zones.clear();dash_attack.clear();_dash_state.clear();_presentation.clear()
 hero.dash_left=0;dash_iframe_left=0;dash_step_immune=false;hero.lock_time=0;hero.movement_lock_left=0
 r1_active=false;clock.clear()
 _hero_clear_transients()

func end_encounter(result: String) -> void:
 if phase!="combat": return
 # Invalidate trajectories without settling old-room damage or refreshing resources.
 phase=result
 _clear_wave_transients()
 common.end_room();real_accumulator=0
 if progression.snapshot().get("in_combat",false): progression.end_encounter()
 emit_event("encounter_finished",{"result":result})
 frozen_snapshot=snapshot()
 encounter_finished.emit(frozen_snapshot.duplicate(true))

func _check_victory() -> void:
 if phase=="combat" and auto_finish and not enemies.is_empty() and living().is_empty() and not _hero_victory_pending(): end_encounter("victory")

func new_cast(slot: String, stage: String="", extra: Dictionary={}) -> Dictionary:
 cast_serial+=1
 var context: Dictionary=extra.duplicate(true)
 context.merge({"cast_id":cast_serial,"origin":hero.position,"direction":hero.facing,"due":clock.world_time,"kind":slot,"slot":slot,"candidate":hero.loadout.get(slot,slot),"generation":encounter_generation,"room_id":room_id,"stage":stage},true)
 _casts[cast_serial]={"generation":encounter_generation,"room_id":room_id,"cancelled":false,"finished":false,"slot":slot,"stage":stage}
 _action_stage=stage
 common.start_action(slot,cast_serial,hero.position)
 _action_stage=""
 return context

func cast_is_current(id: int) -> bool:
 if id==0: return true
 return _casts.has(id) and not _casts[id].cancelled and _casts[id].generation==encounter_generation and _casts[id].room_id==room_id

func effect_is_current(effect: Dictionary) -> bool:
 return phase=="combat" and int(effect.get("generation",-1))==encounter_generation and str(effect.get("room_id",""))==room_id and cast_is_current(int(effect.get("cast_id",0)))

func schedule_effect(context: Dictionary, kind: String, delay: float, extra: Dictionary={}, time_domain: String="world") -> Dictionary:
 if not effect_is_current(context): return {}
 _effect_serial+=1
 var event=context.duplicate(true)
 event.merge(extra.duplicate(true),true)
 event.merge({"kind":kind,"effect_id":"scheduled:%d"%_effect_serial,"due":_domain_time(time_domain)+maxf(0,delay),"time_domain":time_domain,"generation":context.generation,"room_id":context.room_id,"cast_id":context.cast_id},true)
 pending.append(event)
 return event.duplicate(true)

func _domain_time(domain: String) -> float:
 return real_time if domain=="real" else hero_time if domain=="hero" else clock.world_time

func finish_cast(id: int, cancelled: bool=false, wait_for_motion: bool=false) -> void:
 if not cast_is_current(id) or id==0: return
 if cancelled: cancel_cast(id);return
 if _casts[id].finished: return
 _casts[id].finished=true
 common.complete_action(id,false,wait_for_motion)

func cancel_cast(id: int) -> void:
 if not _casts.has(id) or _casts[id].cancelled: return
 _casts[id].cancelled=true
 pending=pending.filter(func(e): return int(e.get("cast_id",0))!=id)
 projectiles=projectiles.filter(func(e): return e.get("team","")!="hero" or int(e.get("cast_id",0))!=id)
 zones=zones.filter(func(e): return e.get("team","")!="hero" or int(e.get("cast_id",0))!=id)
 common.complete_action(id,true)

func claim_hit(id: int, target_id: String, channel: String="damage") -> bool:
 if not cast_is_current(id): return false
 var key="%d:%d:%s:%s"%[encounter_generation,id,channel,target_id]
 if _hit_claims.has(key): return false
 _hit_claims[key]=true
 return true

var _equipment_action_dispatch_frames:Array=[]

func request_action(action: String, aim: Vector3=Vector3.INF, command_id: String="") -> Dictionary:
 var key="%d:%s"%[encounter_generation,command_id]
 if not command_id.is_empty() and seen_commands.has(key): return seen_commands[key].duplicate(true)
 if transaction_active: return {"accepted":false,"reason":"transaction_in_progress"}
 transaction_active=true
 var result=_request_action(action,aim)
 transaction_active=false
 if not command_id.is_empty(): seen_commands[key]=result.duplicate(true)
 _check_victory()
 return result.duplicate(true)

func _request_action(action: String, aim: Vector3) -> Dictionary:
 if phase!="combat" or paused: return {"accepted":false,"reason":"encounter_frozen"}
 if hero.dead: return {"accepted":false,"reason":"not_alive"}
 if action not in ["attack","shift","q","e","r","e_release"]: return {"accepted":false,"reason":"unknown_action"}
 common.ensure_combat();common.refresh_stats()
 var policy: Dictionary=_hero_action_policy(action,aim)
 if not str(policy.get("reason","")).is_empty(): return {"accepted":false,"reason":policy.reason}
 var dash_basic: bool=action=="attack" and hero.dash_left>TIME_EPS
 if dash_basic and not dash_attack.is_empty(): return {"accepted":false,"reason":"dash_attack_used"}
 if not dash_basic and not policy.get("bypass_lock",false) and hero.lock_time>TIME_EPS: return {"accepted":false,"reason":"action_locked"}
 if not dash_basic and not policy.get("bypass_dash",false) and hero.dash_left>TIME_EPS: return {"accepted":false,"reason":"dashing"}
 if action in ["q","e","r"] and hero.ranks.get(action,0)<=0 and not policy.get("bypass_rank",false): return {"accepted":false,"reason":"unlearned"}
 if not dash_basic and hero.cooldowns.get(action,0.0)>TIME_EPS and not policy.get("bypass_cooldown",false): return {"accepted":false,"reason":"cooldown"}
 if aim.is_finite():
  hero.aim_point=aim
  var direction: Vector3=aim-hero.position;direction.y=0
  if direction.length_squared()>0.001: hero.facing=direction.normalized()
 var context: Dictionary
 var prior_cast: int=int(policy.get("cast_id",0))
 if prior_cast>0:
  if not cast_is_current(prior_cast): return {"accepted":false,"reason":"stale_cast"}
  context=policy.get("context",{}).duplicate(true)
  context.merge({"cast_id":prior_cast,"origin":hero.position,"direction":hero.facing,"generation":encounter_generation,"room_id":room_id,"slot":action,"candidate":hero.loadout.get(action,action),"stage":policy.get("stage","")},true)
 else: context=new_cast(action,str(policy.get("stage","")))
 context["cancel_basic"]=policy.get("cancel_basic",false)
 var equipment_dispatch:Dictionary={"action":action,"context":context,"cast":_casts.get(context.cast_id,{}),"hero":hero,"generation":encounter_generation,"room_id":room_id}
 _equipment_action_dispatch_frames.append(equipment_dispatch)
 var result: Dictionary
 match action:
  "attack": result=start_basic(context,dash_basic)
  "shift": result=start_dash(context)
  _: result=_hero_cast_skill(action,context)
 assert(is_same(_equipment_action_dispatch_frames.back(),equipment_dispatch))
 _equipment_action_dispatch_frames.pop_back()
 if not result.get("accepted",false):
  if prior_cast<=0: cancel_cast(context.cast_id)
  return result
 revision+=1
 result.merge({"reason":"ok","cast_id":context.cast_id,"state_revision":revision},false)
 return result

func start_basic(context: Dictionary, dash: bool=false) -> Dictionary:
 var payload: Dictionary=_hero_basic_payload(context.duplicate(true),dash)
 if payload.is_empty(): return {"accepted":false,"reason":"basic_unimplemented"}
 var event: Dictionary=context.duplicate(true);event.merge(payload,true)
 event["source"]=payload.get("source","dash_attack" if dash else "attack")
 event["dash"]=dash
 event["follow_origin"]=payload.get("follow_origin",true)
 hero.attack_index+=1
 event["combo"]=payload.get("combo",hero.attack_index)
 var cooldown: float=float(payload.get("cooldown",1.0/hero.attack_speed()))
 hero.cooldowns.attack=maxf(hero.cooldowns.attack,cooldown)
 hero.lock_time=maxf(hero.lock_time,float(payload.get("contact_after",0.0)))
 if dash:
  event.direction=hero.dash_direction
  dash_attack=event.duplicate(true)
  dash_attack["hits"]=[]
  dash_attack["dash_id"]=dash_serial
  dash_attack["contact_due"]=real_time+float(payload.get("contact_after",0.0))
 schedule_effect(context,"core_dash_contact" if dash and payload.get("swept",false) else "core_basic",float(payload.get("contact_after",0.0)),event,str(payload.get("time_domain","real" if dash else "world")))
 emit_event("dash_attack_started" if dash else "attack_started",event)
 if dash and payload.get("swept",false) and float(payload.get("contact_after",0))<=TIME_EPS: _sweep_dash_attack(hero.position,hero.position)
 return {"accepted":true,"reason":"dash_attack" if dash else "attack"}

func _resolve_basic(event: Dictionary) -> void:
 if event.get("follow_origin",true): event.origin=hero.position
 var targets: Array=[]
 if event.get("delivery","")=="hero": _hero_basic_impact(event)
 else:
  targets=shape_targets(event.origin,event.direction,event.get("shape",{}))
  for target in targets:
   if claim_hit(event.cast_id,target.actor_id,"basic"):
    var metadata: Dictionary=event.get("metadata",{}).duplicate(true)
    metadata.merge({"position":event.origin,"direction":event.direction,"basic_attack":true,"combo":event.get("combo",0)},false)
    damage_enemy(target,float(event.get("damage",0)),event.source,event.cast_id,event.get("is_true",false),event.get("critical",false),metadata)
 _hero_basic_completed(event,targets)
 if not event.get("defer_completion",false): finish_cast(event.cast_id)
 emit_event("attack_impact",{"position":event.origin,"direction":event.direction,"cast_id":event.cast_id,"source":event.source,"combo":event.combo,"hit_count":targets.size(),"target_ids":targets.map(func(t): return t.actor_id),"contact_after":event.get("contact_after",0),"recovery":event.get("recovery",0)})

func start_dash(context: Dictionary) -> Dictionary:
 var spec: Dictionary=_hero_dash_spec()
 if spec.is_empty() or float(spec.get("duration",0))<=0: return {"accepted":false,"reason":"dash_unimplemented"}
 if context.get("cancel_basic",false):
  var cancelled: Array=[]
  for effect in pending.duplicate():
   if effect.kind=="core_basic" and not effect.get("dash",false):
    cancelled.append(effect.cast_id);cancel_cast(effect.cast_id)
  if not cancelled.is_empty():
   hero.lock_time=0
   emit_event("attack_cancelled",{"cast_ids":cancelled,"position":hero.position})
 hero.dash_direction=hero.move_intent.normalized() if hero.move_intent.length_squared()>0.001 else hero.facing
 hero.dash_left=float(spec.duration)
 dash_iframe_left=maxf(0,float(spec.get("iframe_duration",0)))
 dash_serial+=1;dash_attack.clear()
 _dash_state=context.duplicate(true);_dash_state.merge(spec,true)
 start_skill_cooldown("shift",float(spec.get("cooldown",0)))
 emit_event("dash",{"position":hero.position,"direction":hero.dash_direction,"duration":spec.duration,"distance":spec.get("distance",0),"iframe_duration":dash_iframe_left,"invulnerable":dash_iframe_left>0,"dash_id":dash_serial,"cast_id":context.cast_id})
 return {"accepted":true}

func _sweep_dash_attack(before: Vector3, after: Vector3) -> void:
 if dash_attack.is_empty() or not dash_attack.get("swept",false) or not effect_is_current(dash_attack) or real_time+TIME_EPS<float(dash_attack.contact_due): return
 var direction: Vector3=dash_attack.direction
 var shape: Dictionary=dash_attack.get("shape",{}).duplicate(true)
 var travel: float=maxf(0,(after-before).dot(direction))
 var targets: Array=[]
 if shape.get("kind","")=="rectangle":
  shape.length=float(shape.get("length",0))+travel
  targets=shape_targets(before,direction,shape)
 else: targets=shape_targets(after,direction,shape)
 for target in targets:
  if target.actor_id in dash_attack.hits: continue
  var contact: Vector3=before.lerp(after,clampf((Vector3(target.position)-before).dot(direction)/maxf(travel,.001),0,1))
  if _move_clipped(contact,target.position,.05).distance_squared_to(target.position)>.01: continue
  if not claim_hit(dash_attack.cast_id,target.actor_id,"basic"): continue
  dash_attack.hits.append(target.actor_id)
  var metadata: Dictionary=dash_attack.get("metadata",{}).duplicate(true)
  metadata.merge({"direction":direction,"basic_attack":true,"combo":dash_attack.get("combo",0)},false)
  damage_enemy(target,float(dash_attack.get("damage",0)),str(dash_attack.source),int(dash_attack.cast_id),dash_attack.get("is_true",false),dash_attack.get("critical",false),metadata)
  emit_event("dash_attack_hit",{"position":target.position,"target":target.actor_id,"cast_id":dash_attack.cast_id,"dash_id":dash_serial})

func _step_player_locomotion(real_dt: float) -> void:
 var before: Vector3=hero.position
 var slice: float=minf(hero.dash_left,real_dt)
 var immune_before: float=dash_iframe_left
 dash_step_immune=immune_before>TIME_EPS and immune_before+TIME_EPS>=real_dt
 dash_iframe_left=maxf(0,dash_iframe_left-real_dt)
 if slice>0 and not _dash_state.is_empty():
  hero.position=_move_clipped(before,before+hero.dash_direction*float(_dash_state.distance)/float(_dash_state.duration)*slice,hero_radius)
  _sweep_dash_attack(before,hero.position)
  hero.dash_left=maxf(0,hero.dash_left-slice)
  if hero.dash_left<=TIME_EPS:
   hero.dash_left=0
   common.movement_complete(_dash_state.cast_id)
   finish_cast(_dash_state.cast_id)
   common.dash_complete()
   if not dash_attack.is_empty() and dash_attack.get("swept",false) and real_time+TIME_EPS>=float(dash_attack.contact_due):
    _hero_basic_completed(dash_attack,[])
    finish_cast(dash_attack.cast_id)
    emit_event("dash_attack_ended",{"position":hero.position,"cast_id":dash_attack.cast_id,"dash_id":dash_serial,"hit_count":dash_attack.hits.size()})
   _dash_state.clear()
 if _hero_locomotion_allowed() and hero.movement_lock_left<=TIME_EPS and real_dt>slice:
  hero.position=_move_clipped(hero.position,hero.position+hero.move_intent.limit_length(1)*hero.speed()*(real_dt-slice),hero_radius)
 hero.standing_time=0.0 if hero.position.distance_squared_to(before)>0.000001 else hero.standing_time+real_dt

func free_move(dt: float, move: Vector3) -> void:
 if paused or hero.dead or phase=="combat" or dt<=0: return
 hero.move_intent=move.limit_length(1)
 if _hero_locomotion_allowed(): hero.position=_move_clipped(hero.position,hero.position+hero.move_intent*hero.speed()*dt,hero_radius)

func move_during_hitstop(real_dt: float, move: Vector3) -> void:
 if phase!="combat" or paused or hero.dead or real_dt<=0: return
 hero.move_intent=move.limit_length(1)
 # A newly accepted caster presentation must not inherit an earlier impact's
 # cosmetic freeze. Its own clock continues, while other objects retain ult slow.
 if not _presentation.is_empty() and _hero_time_delta(0.0,real_dt)>TIME_EPS:
  step(real_dt)
  return
 real_time+=real_dt
 _step_player_locomotion(real_dt)
 _dispatch_pending(true)
 dash_step_immune=false
 revision+=1

func hero_damage_immune() -> bool: return hero.dead or hero.untargetable or hero.invulnerable_left>TIME_EPS or dash_iframe_left>TIME_EPS or dash_step_immune or r1_active
func hero_control_immune() -> bool: return hero_damage_immune() or not _hero_control_allowed()
func start_presentation(context: Dictionary, duration: float) -> void:
 if not effect_is_current(context): return
 _presentation=context.duplicate(true);_presentation["left"]=maxf(0,duration)
 r1_active=true;clock.enter(hero.actor_id,duration)
 emit_event("ultimate_started",{"position":hero.position,"cast_id":context.cast_id,"candidate":context.candidate,"duration":duration})
func finish_presentation() -> void:
 if _presentation.is_empty(): return
 var id: int=int(_presentation.cast_id)
 _presentation.clear();r1_active=false;clock.leave(hero.actor_id)
 if cast_is_current(id): common.ultimate_ready(id);_hero_presentation_finished(id)

func step(real_delta: float) -> void:
 if phase!="combat" or paused or real_delta<=0: return
 real_accumulator+=real_delta
 while real_accumulator+TIME_EPS>=FIXED_TICK and phase=="combat" and not paused:
  real_accumulator-=FIXED_TICK
  _fixed_step(FIXED_TICK)
  dash_step_immune=false

func _fixed_step(real_dt: float) -> void:
 common.ensure_combat();common.refresh_stats()
 var dt: float=clock.step(real_dt,true)
 var actor_dt: float=_hero_time_delta(dt,real_dt)
 hero_time+=actor_dt
 real_time+=real_dt
 common.begin_tick(dt,actor_dt)
 var presentation_ending: bool=false
 if not _presentation.is_empty():
  _presentation.left-=real_dt
  presentation_ending=_presentation.left<=TIME_EPS
 for key in hero.cooldowns: hero.cooldowns[key]=maxf(0,float(hero.cooldowns[key])-actor_dt)
 for key in ["lock_time","movement_lock_left","invulnerable_left","stun_left","slow_left"]: hero.set(key,maxf(0,float(hero.get(key))-actor_dt))
 for actor in [hero]+allies:
  for id in actor.shields.keys():
   if float(actor.shields[id].left)<0: continue
   actor.shields[id].left-=actor_dt if actor==hero else dt
   if actor.shields[id].left<=TIME_EPS: actor.shields.erase(id)
 if presentation_ending: finish_presentation()
 _hero_pre_step(actor_dt,real_dt)
 _step_player_locomotion(real_dt)
 heal(float(hero.stats.regen)*actor_dt,false,{"source":"regeneration"})
 _build_spatial()
 _dispatch_pending()
 if phase!="combat": return
 _hero_step(actor_dt,real_dt)
 if phase!="combat": return
 enemy_director.begin_step(self,dt)
 for enemy in enemies:
  _step_pull(enemy,dt);_step_push(enemy,dt)
  if ai_enabled: _step_enemy(enemy,dt)
  else:
   for key in ["stun_left","slow_left"]: enemy[key]=maxf(0,float(enemy[key])-dt)
   if enemy.state=="spawn":
    enemy.timer-=dt
    if enemy.timer<=TIME_EPS: enemy.state="chase"
  if phase!="combat": return
 enemy_director.step_projectiles(self,dt)
 _common_zone_tick=true
 enemy_director.step_hostile_zones(self,dt)
 _common_zone_tick=false
 common.tick(dt,actor_dt)
 _check_victory();revision+=1

func _dispatch_pending(real_only: bool=false) -> void:
 for effect in pending.duplicate():
  if not effect_is_current(effect): pending.erase(effect);continue
  var realtime: bool=effect.get("time_domain","world")=="real"
  if real_only and not realtime: continue
  if float(effect.due)>_domain_time(str(effect.get("time_domain","world")))+TIME_EPS: continue
  pending.erase(effect)
  var identity: String="dispatch:"+str(effect.effect_id)
  if _effect_claims.has(identity): continue
  _effect_claims[identity]=true
  if effect.kind=="core_basic": _resolve_basic(effect)
  elif effect.kind=="core_dash_contact":
   if hero.dash_left>TIME_EPS: _sweep_dash_attack(hero.position,hero.position)
   else: _resolve_basic(effect)
  else: _hero_resolve_effect(effect)
  if phase!="combat": return

func damage_enemy(enemy: Dictionary, amount: float, source: String, cast_id: int=0, is_true: bool=false, critical: bool=false, metadata: Dictionary={}) -> bool:
 if phase!="combat" or paused or hero.dead or enemy.is_empty() or enemy.dead or enemy.state=="spawn" or not cast_is_current(cast_id): return false
 if not is_same(enemy,enemy_by_id(str(enemy.actor_id))): return false
 if metadata.has("generation") and int(metadata.generation)!=encounter_generation: return false
 if metadata.has("room_id") and str(metadata.room_id)!=room_id: return false
 if metadata.has("effect_id"):
  var key="damage:%s:%s"%[metadata.effect_id,enemy.actor_id]
  if _effect_claims.has(key): return false
  _effect_claims[key]=true
 common._inside_hit+=1
 # Replays already contain their original nominal amount and suppress reactions.
 var adjusted: float=amount if metadata.get("replay",false) or metadata.get("no_reactions",false) else _hero_outgoing_damage(enemy,amount,source,cast_id,is_true,metadata)
 var event: Dictionary=common.before_hit(enemy,adjusted,source,cast_id,is_true,critical,metadata)
 # Hero final multipliers follow common final multipliers and precede mitigation.
 # Already-snapshotted packets (G18, proportional true riders) must not apply twice.
 var hero_final: float=1.0 if event.get("snapshot_final",false) or event.get("replay",false) else _hero_final_outgoing_multiplier(enemy,event)
 event.amount*=hero_final
 event.hero_final_multiplier=hero_final
 if event.has("cast_bonus_final"): event.cast_bonus_final*=hero_final
 var source_position: Vector3=event.get("position",hero.position)
 var guard_factor: float=enemy_director.guard_multiplier(enemy,source_position,source,is_true)
 var packet: float=maxf(0,float(event.amount))*guard_factor
 var penetration: float=float(event.get("saved_stats",{}).get("penetration",hero.stats.penetration)) if event.get("replay",false) else float(event.get("impact_penetration",hero.stats.penetration))
 if not is_true: packet*=100.0/(100.0+maxf(0,float(enemy.defence)-penetration))
 var actual: float=minf(float(enemy.hp),packet)
 enemy.hp=maxf(0,float(enemy.hp)-packet)
 emit_event("damage",{"target":enemy.actor_id,"position":enemy.position,"source_position":source_position,"amount":actual,"source":source,"cast_id":cast_id,"critical":event.get("critical",critical),"damage_type":"true" if is_true else "ordinary","hex_generated":event.get("hex_generated",false),"replay":event.get("replay",false),"saved_aim":event.get("saved_aim",hero.facing),"occurrence":event.get("occurrence",event.get("replay_segment",{}).get("occurrence",0)),"strike":event.get("strike",0),"round":event.get("round",0),"combo":event.get("combo",0),"direction":event.get("direction",hero.facing),"enemy_kind":enemy.kind,"target_radius":enemy.radius,"guard_factor":guard_factor,"guarded":guard_factor<1.0,"absorbed":0.0,"basic_attack":event.get("basic_attack",false)})
 if not is_true and not event.get("no_reactions",false): heal(actual*float(event.get("impact_lifesteal_rate",_hero_lifesteal_rate(event)))*_hero_lifesteal_factor(event),true,{"source":"lifesteal"})
 if event.has("replay_segment"):
  var segment: Dictionary=event.replay_segment
  var extra: Dictionary={"critical":event.get("critical",false),"occurrence":segment.get("occurrence",0)}
  for field in ["replay_hit_group","replay_hit_limit","relative_time","saved_aim"]:
   if segment.has(field): extra[field]=segment[field]
  if segment.get("target_mode","")=="bound": common.record_bound(cast_id,segment.segment_id,enemy,event.amount,source_position,extra)
  else:
   extra.merge({"original_target_id":enemy.actor_id,"cast_bonus_final":event.get("cast_bonus_final",0.0),"hero_final_multiplier":event.get("hero_final_multiplier",1.0)},true)
   common.record_spatial(cast_id,segment.segment_id,event.amount,source_position,segment.shape,extra)
 if enemy.hp<=0: _kill_enemy(enemy,source,cast_id)
 if not event.get("no_reactions",false): _hero_after_damage(enemy,event,actual)
 common.after_hit(event,actual)
 common._inside_hit-=1
 common.drain()
 return enemy.dead

func _kill_enemy(enemy: Dictionary, source: String, cast_id: int) -> void:
 if phase!="combat" or enemy.dead or not cast_is_current(cast_id) or not is_same(enemy,enemy_by_id(str(enemy.actor_id))): return
 enemy.hp=0.0;enemy.dead=true;enemy.state="dead";enemy.push={};enemy.pull_state={};enemy.carried=false
 common.killed(enemy,source,cast_id)
 _hero_killed(enemy,source,cast_id)
 emit_event("kill",{"target":enemy.actor_id,"position":enemy.position,"source":source,"cast_id":cast_id,"credit":"solo_lethal","enemy_kind":enemy.kind})

func damage_hero(amount: float, direction: Vector3=Vector3.ZERO, control: float=0.0, is_true: bool=false, mandatory: bool=false, metadata: Dictionary={}) -> void:
 if phase!="combat" or paused or hero.dead or (not mandatory and hero_damage_immune()): return
 if metadata.has("generation") and int(metadata.generation)!=encounter_generation: return
 common.ensure_combat();common.refresh_stats()
 var event: Dictionary=metadata.duplicate(true)
 var before_hp: float=hero.hp
 var raw: float=maxf(0,amount)*(1.0 if mandatory else enemy_director.incoming_damage_multiplier(self))
 event.merge({"raw":raw,"direction":direction,"is_true":is_true,"mandatory":mandatory},false)
 var packet: float=raw*(1.0 if is_true else 100.0/(100.0+maxf(0,hero.defence())))
 packet=maxf(0,_hero_incoming_damage(packet,event))
 var before_shields: float=packet
 packet=_absorb_shields(hero,packet,"self_sacrifice" if mandatory else str(event.get("damage_provenance","enemy_damage")))
 event["absorbed"]=before_shields-packet
 packet=common.incoming(packet,bool(event.get("direct",not mandatory and not _common_zone_tick)))
 packet=maxf(0,_hero_before_hp_commit(packet,event))
 var lost: float=minf(hero.hp,packet)
 hero.hp=maxf(0,hero.hp-packet)
 # Surviving threshold passives inspect exact before/after HP and cannot heal a lethal packet.
 _hero_after_incoming(before_hp,lost,event)
 if control>0 and not hero_control_immune(): hero.stun_left=maxf(hero.stun_left,control*(1.0-hero.tenacity()))
 emit_event("damage",{"target":hero.actor_id,"position":hero.position,"amount":lost,"raw":raw,"absorbed":event.absorbed,"direction":direction,"source":event.get("source","enemy"),"damage_type":"true" if is_true else "ordinary"})
 if hero.hp<=0 and not _hero_death(): _common_true_death()
 common.drain()

func apply_committed_health_loss(amount:float,nonlethal:bool=false,metadata:Dictionary={})->float:
 # Already-settled debt/cost is a raw HP change, not a second damage transaction.
 # No mitigation, shield absorption, deferral, reflection or damage hooks repeat.
 if phase!="combat" or paused or hero.dead:return 0.0
 var before_hp:float=hero.hp
 hero.hp=maxf(minf(1.0,before_hp) if nonlethal else 0.0,before_hp-maxf(0.0,amount))
 var actual:float=maxf(0.0,before_hp-hero.hp)
 _hero_after_hp_loss(before_hp,actual,metadata)
 if hero.hp<=0 and not hero.dead:_common_true_death()
 return actual

func _absorb_shields(actor, packet: float, reason: String) -> float:
 for id in actor.shields.keys():
  var absorbed: float=minf(maxf(0,float(actor.shields[id].amount)),packet)
  actor.shields[id].amount-=absorbed;packet-=absorbed
  common.absorbed(actor,actor.shields[id],absorbed,reason)
  if actor.shields[id].amount<=TIME_EPS: actor.shields.erase(id)
  if packet<=TIME_EPS: break
 return maxf(0,packet)

func damage_ally(actor: RefCounted, amount: float, is_true: bool=false) -> void:
 if phase!="combat" or paused or actor.dead or actor not in allies: return
 var packet: float=maxf(0,amount)*(1.0 if is_true else 100.0/(100.0+maxf(0,actor.defence())))
 packet=_absorb_shields(actor,packet,"enemy_damage")
 actor.hp=maxf(0,actor.hp-packet)
 if actor.hp<=0: actor.dead=true
 common.drain()

func heal(amount: float, _is_lifesteal: bool=false, metadata: Dictionary={}) -> float: return heal_actor(hero,amount,metadata)
func heal_actor(actor: RefCounted, amount: float, metadata: Dictionary={}) -> float:
 if actor==null or actor.dead: return 0.0
 if actor!=hero and actor not in allies: return 0.0
 var actual: float=minf(maxf(0,float(actor.stats.max_hp)-actor.hp),maxf(0,amount))
 actor.hp+=actual
 if phase=="combat": common.ensure_combat();common.healed(actor,actual,metadata);common.drain()
 return actual
func add_shield(id: String, amount: float, duration: float, metadata: Dictionary={}) -> void:
 if amount<=0 or hero.dead: return
 hero.shields[id]=common.shield_metadata(id,amount,duration,metadata)
 emit_event("shield",{"target":hero.actor_id,"source":id,"amount":amount,"initial_amount":amount,"owner_id":hero.actor_id,"duration":duration})
func register_ally(actor: RefCounted) -> void:
 if actor!=hero and actor not in allies: allies.append(actor)
func _common_true_death() -> void:
 if hero.dead: return
 hero.dead=true;hero.death_state="true_dead"
 common.runtime.hero_died(true)
 end_encounter("true_dead")
func self_rescue() -> bool: return false

func ordinary(enemy: Dictionary) -> bool: return enemy.get("rank_category","ordinary")=="ordinary"
func living() -> Array: return enemies.filter(func(e): return not e.dead)
func enemy_by_id(id: String) -> Dictionary:
 for enemy in enemies:
  if enemy.actor_id==id: return enemy
 return {}
func spawn_enemy(kind: String, at: Vector3, hp_override: float=-1.0) -> Dictionary:
 enemy_serial+=1
 var enemy: Dictionary=enemy_director.make_enemy(kind,at,hp_override,wave,enemy_serial)
 enemy.position=clamp_position(enemy.position,enemy.radius);enemy.target_actor_id=hero.actor_id
 enemy["generation"]=encounter_generation;enemy["room_id"]=room_id
 enemies.append(enemy)
 emit_event("enemy_spawned",{"actor_id":enemy.actor_id,"enemy_kind":enemy.kind,"position":enemy.position,"duration":enemy.timer})
 return enemy
func make_wave_roster(number: int, count_override: int=-1) -> Array: return enemy_director.make_wave_roster(number,count_override)
func circle_targets(origin: Vector3, radius: float) -> Array:
 return enemies.filter(func(e): return not e.dead and e.state!="spawn" and e.position.distance_to(origin)<=radius+e.radius)
func cone_targets(origin: Vector3, direction: Vector3, radius: float, degrees: float) -> Array:
 var result: Array=[];direction=direction.normalized()
 for enemy in circle_targets(origin,radius):
  var offset: Vector3=enemy.position-origin
  if offset.length()<enemy.radius or offset.normalized().dot(direction)>=cos(deg_to_rad(degrees*.5)): result.append(enemy)
 return result
func rectangle_targets(origin: Vector3, direction: Vector3, length: float, width: float) -> Array:
 var result: Array=[];direction=direction.normalized()
 var side=Vector3(-direction.z,0,direction.x)
 for enemy in enemies:
  if enemy.dead or enemy.state=="spawn": continue
  var offset: Vector3=enemy.position-origin
  if offset.dot(direction)>=-enemy.radius and offset.dot(direction)<=length+enemy.radius and absf(offset.dot(side))<=width*.5+enemy.radius: result.append(enemy)
 return result
func shape_targets(origin: Vector3, direction: Vector3, shape: Dictionary) -> Array:
 match str(shape.get("kind","")):
  "cone": return cone_targets(origin,direction,float(shape.get("radius",0)),float(shape.get("degrees",0)))
  "circle": return circle_targets(origin,float(shape.get("radius",0)))
  "rectangle":
   if shape.get("circle_rectangle",false):
    return enemies.filter(func(e): return not e.dead and e.state!="spawn" and SweptRectangle.circle_intersects(origin,direction,float(shape.get("length",0)),float(shape.get("width",0)),e.position,float(e.radius),shape.get("clipped_front",false),float(shape.get("forward_limit",INF))))
   return rectangle_targets(origin,direction,float(shape.get("length",0)),float(shape.get("width",0)))
 return []
func clamp_position(at: Vector3, radius: float=.65) -> Vector3:
 var bound: float=maxf(0,arena_half_extent-radius)
 var point=Vector3(clampf(at.x,-bound,bound),0,clampf(at.z,-bound,bound))
 for obstacle in obstacles:
  var center: Vector3=obstacle.position
  var half: Vector3=obstacle.half+Vector3(radius,0,radius)
  var offset=point-center
  if absf(offset.x)<half.x and absf(offset.z)<half.z:
   if half.x-absf(offset.x)<half.z-absf(offset.z): point.x=center.x+half.x*(1.0 if offset.x>=0 else -1.0)
   else: point.z=center.z+half.z*(1.0 if offset.z>=0 else -1.0)
 return point
func _move_clipped(origin: Vector3, destination: Vector3, radius: float=.65) -> Vector3:
 # Exact swept AABB prevents tunnelling through thin obstacles at any travel speed.
 var target=Vector3(destination.x,0,destination.z)
 var bound: float=maxf(0,arena_half_extent-radius)
 var fraction: float=1.0
 var delta: Vector3=target-origin
 for axis in [0,2]:
  if delta[axis]>0 and target[axis]>bound: fraction=minf(fraction,(bound-origin[axis])/delta[axis])
  elif delta[axis]<0 and target[axis]<-bound: fraction=minf(fraction,(-bound-origin[axis])/delta[axis])
 for obstacle in obstacles:
  var half: Vector3=obstacle.half+Vector3(radius,0,radius)
  fraction=minf(fraction,enemy_director._segment_box_entry(origin,target,Vector3(obstacle.position)-half,Vector3(obstacle.position)+half))
 return origin.lerp(target,clampf(fraction-(.00001 if fraction<1 else 0),0,1))
func _cell(at: Vector3) -> Vector2i: return Vector2i(floori(at.x/2.5),floori(at.z/2.5))
func _build_spatial() -> void:
 spatial.clear();pair_checks=0
 for enemy in enemies:
  if enemy.dead: continue
  var cell=_cell(enemy.position)
  if not spatial.has(cell): spatial[cell]=[]
  spatial[cell].append(enemy)
func _nearby(at: Vector3, limit: int=0, exclude: String="") -> Array:
 var result: Array=[];var cell=_cell(at)
 for x in range(-1,2):
  for z in range(-1,2):
   for enemy in spatial.get(cell+Vector2i(x,z),[]):
    if enemy.actor_id==exclude: continue
    result.append(enemy)
    if limit>0 and result.size()>=limit: return result
 return result
func apply_control(enemy: Dictionary, kind: String, duration: float, amount: float=0, metadata: Dictionary={}) -> bool:
 if phase!="combat" or paused or enemy.dead or enemy.state=="spawn" or not is_same(enemy,enemy_by_id(str(enemy.actor_id))): return false
 if not _hero_enemy_control_allowed(enemy,kind,metadata): return false
 var adjusted: float=maxf(0,duration)*(1.0-clampf(float(enemy.get("tenacity",0)),0,1))
 var g01_stun_before: float=float(enemy.stun_left)
 match kind:
  "stun": enemy.stun_left=maxf(enemy.stun_left,adjusted)
  "slow":
   var previous: float=float(enemy.slow_amount) if float(enemy.slow_left)>TIME_EPS else 0.0
   enemy.slow_left=maxf(enemy.slow_left,adjusted)
   enemy.slow_amount=maxf(previous,clampf(amount,0,1))
  _: return false
 if kind=="stun": _equipment_original_stun_committed(enemy,metadata,g01_stun_before,float(enemy.stun_left),adjusted)
 emit_event("enemy_control",{"target":enemy.actor_id,"control":kind,"duration":adjusted,"amount":amount})
 return true
func push_enemy(enemy: Dictionary, direction: Vector3, distance: float, source: String, id: int, collision_damage: float=0.0, duration: float=.35, collision_stun: float=0.0) -> void:
 if not cast_is_current(id) or enemy.dead or not is_same(enemy,enemy_by_id(str(enemy.actor_id))) or not _hero_enemy_control_allowed(enemy,"push",{}): return
 enemy.push={"direction":direction.normalized(),"left":maxf(TIME_EPS,duration),"duration":maxf(TIME_EPS,duration),"distance":maxf(0,distance)/maxf(.01,float(enemy.get("common_knockback_resistance_multiplier",1))),"source":source,"cast_id":id,"collision_damage":collision_damage,"collision_stun":collision_stun,"generation":encounter_generation,"room_id":room_id,"hits":[],"count":0}
 enemy.stun_left=maxf(enemy.stun_left,duration)
func knock_enemy(enemy: Dictionary, direction: Vector3, strength: float) -> void: push_enemy(enemy,direction,strength*.2,"knockback",0)
func _step_pull(enemy: Dictionary, dt: float) -> void:
 if enemy.dead or enemy.pull_state.is_empty(): return
 var state: Dictionary=enemy.pull_state
 if state.has("generation") and int(state.generation)!=encounter_generation: enemy.pull_state={};return
 state.left-=dt
 var desired: Vector3=Vector3(state.origin).lerp(state.destination,clampf(1.0-float(state.left)/maxf(TIME_EPS,float(state.duration)),0,1))
 var g01_movement: Dictionary=_equipment_q3_movement_begin(enemy,"core_pull")
 var g01_probe: Dictionary=_equipment_q3_probe_begin(enemy.position,desired,enemy.radius) if not g01_movement.is_empty() else {}
 var moved: Vector3=_move_clipped(enemy.position,desired,enemy.radius)
 _equipment_q3_probe_end(g01_probe,moved)
 enemy.position=moved
 _equipment_q3_movement_finish(g01_movement,{"token":g01_probe})
 if state.left<=TIME_EPS or moved.distance_squared_to(desired)>.0001: enemy.pull_state={}
func _step_push(enemy: Dictionary, dt: float) -> void:
 if enemy.dead or enemy.push.is_empty() or enemy.carried: return
 var state: Dictionary=enemy.push
 if not effect_is_current(state): enemy.push={};return
 var g01_push_from: Vector3=enemy.position
 var proposed: Vector3=enemy.position+state.direction*state.distance/state.duration*minf(dt,state.left)
 var g01_movement: Dictionary=_equipment_q3_movement_begin(enemy,"core_push")
 var g01_probe: Dictionary=_equipment_q3_probe_begin(enemy.position,proposed,enemy.radius) if not g01_movement.is_empty() else {}
 var moved: Vector3=_move_clipped(enemy.position,proposed,enemy.radius)
 _equipment_q3_probe_end(g01_probe,moved)
 var blocked: bool=moved.distance_squared_to(proposed)>.0001
 enemy.position=moved
 _equipment_q3_movement_finish(g01_movement,{"token":g01_probe})
 if str(state.get("source","")) in ["q1","q3"]:
  _equipment_effect_committed(str(state.source),state,"source_push_moved",{"enemy":enemy,"push":state,"from":g01_push_from,"to":Vector3(enemy.position)})
 _hero_push_collision(enemy,state,blocked)
 state.left-=dt
 if state.left<=TIME_EPS or blocked: enemy.push={}
func _step_enemy(enemy: Dictionary, dt: float) -> void:
 var damage: float=enemy.damage
 enemy.damage=damage*float(enemy.get("common_damage_multiplier",1))
 enemy_director.step_enemy(self,enemy,dt)
 enemy.damage=damage

func effective_cd(base: float) -> float: return maxf(0,base)*(1.0-clampf(float(hero.stats.cdr),0,.65))
func start_skill_cooldown(slot: String, base: float) -> void: hero.cooldowns[slot]=effective_cd(common.base_cooldown(slot,base))
func set_projected_stats(projected: Dictionary) -> void: common.set_projected(projected)
func set_common_model(model: RefCounted) -> void: common.bind_model(model)
func configure_common_hexes(options: Dictionary) -> void: common.configure(options)
func set_common_context(values: Dictionary) -> void: common.context_values.merge(values,true);common.refresh_stats()
func common_snapshot() -> Dictionary: return common.runtime.snapshot()
func potion_used(item_id: String) -> void: common.potion_used(item_id)
func set_hexes(ids: Array) -> void:
 hero.hexes.clear()
 var allowed: Array=Design.hex_ids(hero.actor_id,true)
 for id in ids:
  if str(id) in allowed and id not in hero.hexes: hero.hexes.append(str(id))
 common.sync_selected();common.refresh_stats()
func hex_status(id: String) -> Dictionary:
 if id.begins_with("common_"): return {"active":common.runtime.active(id),"reason":"" if common.runtime.active(id) else "尚未激活或提案未确认"}
 return _hero_hex_status(id)
func hx(id: String) -> bool: return hero.has_hex(id) and bool(hex_status(id).get("active",false))
func common_action_metadata(slot: String, stage: String="") -> Dictionary:
 return {"hero_id":hero.actor_id,"candidate":hero.loadout.get(slot,slot),"slot":slot,"stage":stage if not stage.is_empty() else _action_stage,"active_skill":slot in ["q","e","r"],"ultimate":slot=="r","active_movement":slot=="shift"}
func common_cooldown_metadata(slot: String) -> Dictionary: return common_action_metadata(slot)
func common_damage_metadata(source: String) -> Dictionary:
 return {"active_skill":false,"basic_attack":source in ["attack","dash_attack"],"direct":not source.begins_with("dot_"),"area":false,"hex_generated":source.begins_with("hex_") or source.begins_with("common_")}
func common_reset_cooldowns(slots: Array) -> void:
 for slot in slots:
  if int(hero.ranks.get(slot,0))>0: hero.cooldowns[slot]=0.0
 _hero_reset_cooldowns(slots)
func status_effects() -> Array:
 var result: Array=common.status_effects()
 result.append_array(_hero_status_effects())
 if hero.cast_state.has("exposed"): result.append({"id":"exposed","name":"咒针易伤","kind":"debuff","stacks":1,"remaining":hero.cast_state.exposed.left,"description":"受到的伤害提高20%"})
 if hero.slow_left>0: result.append({"id":"slow","name":"减速","kind":"debuff","stacks":1,"remaining":hero.slow_left,"description":"移动速度降低"})
 for id in hero.shields:
  result.append({"id":id,"name":"护盾","kind":"buff","stacks":0,"remaining":hero.shields[id].left,"description":"剩余护盾 %.0f"%hero.shields[id].amount})
 return result.duplicate(true)
func set_progression(ledger: RefCounted) -> void:
 progression=ledger
 _sync_loadout_from_ledger()
func _sync_loadout_from_ledger() -> void:
 var slots: Dictionary=progression.snapshot().slots
 for pair in [["Q","q"],["E","e"],["R","r"],["P","passive"]]:
  hero.loadout[pair[1]]=str(slots[pair[0]].skill).to_lower()
  hero.ranks[pair[1]]=slots[pair[0]].rank
func learn_ability(slot: String, candidate: String) -> Dictionary:
 var result: Dictionary=progression.invest(slot,candidate)
 if result.get("ok",false): _sync_loadout_from_ledger()
 return result
func undo_new_investment() -> Dictionary:
 var result: Dictionary=progression.undo_last_investment()
 if result.get("ok",false): _sync_loadout_from_ledger()
 return result
func reset_at_training() -> Dictionary:
 var result: Dictionary=progression.reset_at_training()
 if result.get("ok",false): _sync_loadout_from_ledger()
 return result
func configure_test_loadout(preset: Dictionary) -> Dictionary:
 if clock.world_time>0 or phase=="combat": return {"ok":false,"reason":"not_new_fixture"}
 progression.set_level(18);progression.set_training_node(true);progression.reset_at_training()
 for pair in [["Q","q"],["E","e"],["R","r"],["P","passive"]]:
  var candidate: String=preset.get(pair[1],"")
  if candidate.is_empty(): continue
  for _i in range(4 if pair[0] in ["P","R"] else 6): progression.invest(pair[0],candidate.to_upper())
 _sync_loadout_from_ledger()
 return {"ok":true,"test_fixture":true,"spent":progression.snapshot().spent}

# Only explicit hero hooks below may introduce candidate/passive-specific mechanics.
func _hero_time_delta(world_dt: float, _real_dt: float) -> float: return world_dt
func _hero_victory_pending() -> bool: return false
func _hero_action_policy(_action: String, _aim: Vector3=Vector3.INF) -> Dictionary: return {}
func _hero_cast_skill(_action: String, _context: Dictionary) -> Dictionary: return {"accepted":false,"reason":"skill_unimplemented"}
func _hero_pre_step(_world_dt: float, _real_dt: float) -> void: pass
func _hero_step(_world_dt: float, _real_dt: float) -> void: pass
func _hero_resolve_effect(_effect: Dictionary) -> void: pass
func _hero_locomotion_allowed() -> bool: return true
func _hero_basic_payload(_context: Dictionary, _dash: bool) -> Dictionary: return {}
func _hero_basic_impact(_effect: Dictionary) -> void: pass
func _hero_basic_completed(_effect: Dictionary, _targets: Array) -> void: pass
func _hero_dash_spec() -> Dictionary: return {}
func _hero_animation(_kind: String, _event: Dictionary) -> Dictionary: return {}
func _hero_final_outgoing_multiplier(_enemy: Dictionary, _event: Dictionary) -> float: return 1.0
func _hero_outgoing_damage(_enemy: Dictionary, amount: float, _source: String, _cast_id: int, _is_true: bool, _metadata: Dictionary) -> float: return amount
func _hero_after_damage(_enemy: Dictionary, _event: Dictionary, _actual: float) -> void: pass
func _hero_killed(_enemy: Dictionary, _source: String, _cast_id: int) -> void: pass
func _hero_incoming_damage(packet: float, _metadata: Dictionary) -> float: return packet
func _hero_before_hp_commit(packet: float, _metadata: Dictionary) -> float: return packet
func _hero_after_incoming(_before_hp: float, _lost: float, _metadata: Dictionary) -> void: pass
func _hero_after_hp_loss(_before_hp: float, _lost: float, _metadata: Dictionary) -> void: pass
func _hero_control_allowed() -> bool: return true
func _hero_lifesteal_rate(_event: Dictionary) -> float: return hero.lifesteal()
func _hero_lifesteal_factor(event: Dictionary) -> float:
 if not event.get("direct",true): return .25
 if event.get("area",false): return .4
 return 1.0 if event.get("basic_attack",false) else 0.0
func _hero_death() -> bool: return false
func _hero_clear_transients() -> void: pass
func _hero_reset_cooldowns(_slots: Array) -> void: pass
func _hero_snapshot() -> Dictionary: return {}
func _hero_status_effects() -> Array: return []
func _hero_hex_status(_id: String) -> Dictionary: return {"active":false,"reason":"尚未实现"}
func _hero_presentation_finished(_cast_id: int) -> void: pass
func _hero_push_collision(_enemy: Dictionary, _state: Dictionary, _blocked: bool) -> void: pass
func _hero_enemy_control_allowed(enemy: Dictionary, kind: String, _metadata: Dictionary) -> bool: return enemy.kind!="boss" or kind=="slow"

# A source success seam, after original packet snapshots and before notification.
# In the original core there is no equipment consumer.
func _equipment_release_committed(_family: String, _state: Dictionary) -> void:
 pass

# A source effect seam only. No observer, ledger, event or stat change in core.
# The final consumer must verify its original call frame and successful root
# release; callers cannot authorize G01 by supplying this dictionary alone.
func _equipment_effect_committed(_family: String, _state: Dictionary, _kind: String, _commit: Dictionary) -> void:
 pass

# Attribution only: scheduling a push never counts as actual displacement.
func _equipment_push_bound(_family: String, _source_state: Dictionary, _enemy: Dictionary, _before_push: Dictionary, _committed_push: Dictionary) -> void:
 pass

# Candidate capture is disabled by default. Q3 supplies the private protocol.
func _equipment_q3_movement_begin(_enemy: Dictionary, _source: String) -> Dictionary: return {}
func _equipment_q3_probe_begin(_origin: Vector3, _destination: Vector3, _radius: float) -> Dictionary: return {}
func _equipment_q3_probe_end(_token: Dictionary, _returned: Vector3, _static_exact: Variant = null) -> void: pass
func _equipment_q3_select_output(_output: Variant, _selected: Dictionary) -> void: pass
func _equipment_q3_movement_finish(_frame: Dictionary, _selected: Dictionary) -> void: pass

# Attribution-only grant binding; vortex creation itself never grants G01.
func _equipment_h02_vortex_bound(_wave: Dictionary, _vortex: Dictionary) -> void: pass
# Original accepted stun assignment, before its public notification.
func _equipment_original_stun_committed(_enemy: Dictionary, _metadata: Dictionary, _before: float, _after: float, _adjusted: float) -> void: pass

# Original damage routing seam: inert unless the exact successor authenticates it.
func _equipment_skill_damage(_family: String,_state: Dictionary,enemy: Dictionary,amount: float,source: String,cast_id: int,is_true: bool,critical: bool,metadata: Dictionary)->bool:
 return damage_enemy(enemy,amount,source,cast_id,is_true,critical,metadata)
