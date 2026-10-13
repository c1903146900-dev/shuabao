extends Node
## Deterministic fixed-step single-player Xuanlei test arena. No rewards/SP authority here.
signal combat_event(event: Dictionary)
signal encounter_finished(result: Dictionary)
signal state_changed(snapshot: Dictionary)
const T = preload("res://data/combat/xuanlei_tuning.gd")
const Hero = preload("res://scripts/actors/xuanlei_model.gd")
const Clock = preload("res://scripts/combat/world_clock.gd")
const Ledger = preload("res://scripts/combat/loadout_fixture.gd")
const FIXED_TICK = 0.02
const TIME_EPS = 0.0000001
const CommonBridge = preload("res://scripts/combat/common_hex_bridge.gd")
var common
var _common_zone_tick = false
const EnemyDirector = preload("res://scripts/combat/enemy_director.gd")
var enemy_director = EnemyDirector.new()
var allies: Array = []
# Authoritative action/contact timing. Animation source shares this contract.
# Damage/cooldowns are unchanged; anticipation and cancelable recovery are separate.
const ANIMATION_TIMING = {
 "attack_1":[0.16,0.48],"attack_2":[0.14,0.44],"attack_3":[0.18,0.52],
 "q1":[0.26,0.64],"q2":[0.18,0.52],"q3":[0.22,0.60],
 "e1_guard":[0.0,1.2],"e1_release":[0.12,0.38],"e2":[0.8,0.94],"e3":[0.20,0.48],
 "r1_start":[0.34,0.66],"r1_end":[0.32,0.78],"r2_charge":[0.12,0.72],"r2_end":[0.30,0.70],"dash":[0.0,0.26],"dash_attack":[0.06,0.44]
}
# Dash duration and collision movement share one real-time interval, including hitstop.
const DASH_DURATION := 0.18
const DASH_DISTANCE := 4.2
const DASH_ATTACK_REACH := 1.55
const DASH_ATTACK_WIDTH := 1.70
const DASH_ATTACK_SCALE := 1.15
const ATTACK_RELEASE := {1:0.10,2:0.08,3:0.12}
const DASH_ATTACK_RELEASE := 0.035
const DASH_ATTACK_CONTACT := 0.06
const DASH_ATTACK_PRESENTATION := 0.44 # Readable upper-body stroke, never extra movement/iframes.
var dash_attack: Dictionary = {}
var dash_serial := 0
var dash_step_immune := false
var hero = Hero.new()
var progression = Ledger.new()
var clock = Clock.new()
var phase = "preparation"
var paused = false
var combat_level_id = "xuanlei-room-1"
var room_id = "xuanlei-room-1"
var wave = 0
var enemies: Array = []
var pending: Array = []
var projectiles: Array = []
var zones: Array = []
var event_log: Array = []
var sequence = 0
var cast_serial = 0
var enemy_serial = 0
var revision = 0
var encounter_generation = 0
var auto_finish = true
var ai_enabled = true
var transaction_active = false
var seen_commands: Dictionary = {}
var r1_active = false # compatibility: ultimate presentation, NOT full buff
var real_accumulator = 0.0
var rng = RandomNumberGenerator.new()
var arena_half_extent = T.ARENA_HALF_EXTENT
var obstacles: Array = [] # {position: Vector3, half: Vector3}, optional solid AABBs
var spatial: Dictionary = {}
var pair_checks = 0
var bone_timer = 0.0
var layer_timer = 0.0
var loss_window: Array = []
var retaliation_left = 0.0
var chain_recharges: Array = []
var chain_charges = 2
var collision_pairs: Dictionary = {}
var frozen_snapshot: Dictionary = {}
func _init() -> void:
 rng.seed = 20261001
 common = CommonBridge.new(self)
 # No free SP: new-run ledger has exactly one point; standalone harness chooses fixture explicitly.
 hero.ranks = {"q":0,"e":0,"r":0,"passive":0}
 hero.loadout = {"q":"","e":"","r":"","passive":""}
func emit_event(kind: String, data: Dictionary = {}) -> void:
 sequence += 1
 var event = data.duplicate(true)
 _attach_animation(kind,event)
 event.merge({"kind":kind,"sequence":sequence,"world_time":clock.world_time,"combat_level_id":combat_level_id,"room_id":room_id,"wave":wave})
 event_log.append(event)
 if event_log.size()>300: event_log.pop_front()
 combat_event.emit(event.duplicate(true))
func _attach_animation(kind: String,event: Dictionary) -> void:
 var mapping={"q1_windup":"q1","q1":"q1","q2_windup":"q2","q2_chain":"q2","q3_windup":"q3","q3":"q3","e1_guard_started":"e1_guard","e1_release_windup":"e1_release","e1_release":"e1_release","e2_charge_started":"e2","e2_charge_extended":"e2","e2_release":"e2","e2_wall":"e2","e3_windup":"e3","e3_aura_started":"e3","r1_release_windup":"r1_end","r1_release":"r1_end","r1_fortress_started":"r1_start","r2_charge_started":"r2_charge","r2_finish_windup":"r2_end","r2_finish":"r2_end","dash":"dash","dash_attack_started":"dash_attack","dash_attack_impact":"dash_attack"}
 var clip: String=mapping.get(kind,"")
 if kind in ["attack_started","attack_impact"]: clip="attack_%d"%event.get("combo",hero.attack_index)
 if kind=="ultimate_started": clip="r1_start" if event.get("candidate",hero.loadout.r)=="r1" else "r2_charge"
 if clip.is_empty(): return
 var timing: Array=ANIMATION_TIMING[clip]
 # E2 preserves 0.8s gameplay travel; the authored clip hits at frame20 of24.
 var authored: Array=[0.66,0.80] if clip=="e2" else timing
 var contact: float=event.get("contact_after",timing[0])
 var recovery: float=event.get("recovery",float(timing[1])-float(timing[0]))
 var impact: bool=kind in ["attack_impact","dash_attack_impact","q1","q2_chain","q3","e1_release","e2_release","e2_wall","e3_aura_started","r1_fortress_started","r1_release","r2_finish"]
 event["clip"]=clip
 event["contact_after"]=contact
 event["recovery"]=recovery
 event["impact"]=impact
 event["animation"]={"clip":clip,"contact_after":contact,"recovery":recovery,"impact":impact,"authored_contact":authored[0],"authored_duration":authored[1],"time_domain":"real" if kind in ["ultimate_started","dash","dash_attack_started","dash_attack_impact"] else "world"}
func _lock_animation(clip: String,contact: float=-1.0,duration: float=-1.0) -> void:
 var timing: Array=ANIMATION_TIMING[clip]
 var hit: float=timing[0] if contact<0 else contact
 var total: float=timing[1] if duration<0 else duration
 # The visible recovery can be interrupted after contact. Attack rate remains a cooldown.
 hero.lock_time=maxf(hero.lock_time,hit+0.04)
 # Attack/cast lock limits action chaining only; locomotion is never action-locked.
 hero.movement_lock_left=0.0
func snapshot() -> Dictionary:
 var h = hero.snapshot()
 h.invulnerable = h.invulnerable or r1_active
 h["chain_charges"] = chain_charges
 h["chain_recharges"] = chain_recharges.duplicate()
 h["retaliation_left"] = retaliation_left
 var friendly_snapshots:Array=[]
 for ally in allies: friendly_snapshots.append(ally.snapshot())
 return {"definition_version":T.VERSION,"phase":phase,"paused":paused,"combat_level_id":combat_level_id,"room_id":room_id,"wave":wave,"world_time":clock.world_time,"world_scale":clock.scale_factor(),"revision":revision,"hero":h,"allies":friendly_snapshots,"enemies":enemies.duplicate(true),"pending":pending.duplicate(true),"projectiles":projectiles.duplicate(true),"zones":zones.duplicate(true),"event_sequence":sequence,"common_hexes":common_snapshot(),"progression":progression.snapshot(),"pair_checks":pair_checks,"arena_half_extent":arena_half_extent}
func set_hexes(ids: Array) -> void:
 var allowed: Array=T.Design.hex_ids("xuanlei",true)
 hero.hexes.clear()
 for id in ids:
  var canonical: String=id if str(id).begins_with("common_") else T.hex_id(id)
  if canonical in allowed and canonical not in hero.hexes: hero.hexes.append(canonical)
 common.sync_selected()
 common.refresh_stats()

func hex_status(id: String) -> Dictionary:
 if id.begins_with("common_"): return {"active":common.runtime.active(id),"reason":"" if common.runtime.active(id) else "尚未激活或提案未确认"}
 for entry in T.hex_catalog():
  if entry.id == id:
   var dependency: String = entry.dependency
   if dependency.is_empty(): return {"active":id in hero.hexes,"reason":""}
   var slot = "passive" if dependency.begins_with("p") else dependency.left(1)
   var active: bool = hero.loadout[slot] == dependency and hero.ranks[slot]>0
   return {"active":active and id in hero.hexes,"reason":"" if active else "休眠：需要学习并装备"+dependency.to_upper()}
 return {"active":false,"reason":"未知专属海克斯"}
func hx(id: String) -> bool: return hero.has_hex(id) and hex_status(T.hex_id(id)).active
func v(token: String, rank: int=1) -> float: return T.parameter(token,rank)
func f(token: String, rank: int=1) -> float: return T.fraction(token,rank)
func hv(id: String, index: int=1) -> float: return T.hex_value(id,index)
func hf(id: String, index: int=1) -> float: return hv(id,index)/100.0
func ordinary(enemy: Dictionary) -> bool: return enemy.get("rank_category","ordinary" if enemy.kind not in ["elite","boss"] else enemy.kind)=="ordinary"
func value(key: String, slot: String) -> float: return T.ranked(key,int(hero.ranks[slot]))
func effective_cd(base: float) -> float: return base*(1.0-clampf(hero.stats.cdr,0.0,0.65))
func start_skill_cooldown(slot: String, base: float) -> void: hero.cooldowns[slot] = effective_cd(common.base_cooldown(slot,base))
func living() -> Array: return enemies.filter(func(e): return not e.dead)
func enemy_by_id(id: String) -> Dictionary:
 for enemy in enemies:
  if enemy.actor_id==id: return enemy
 return {}
func spawn_enemy(kind: String, at: Vector3, hp_override: float=-1.0) -> Dictionary:
 enemy_serial+=1
 var enemy: Dictionary=enemy_director.make_enemy(kind,at,hp_override,wave,enemy_serial)
 enemy.position=clamp_position(enemy.position,enemy.radius)
 enemies.append(enemy)
 emit_event("enemy_spawned",{"actor_id":enemy.actor_id,"enemy_kind":enemy.kind,"position":enemy.position,"duration":enemy.timer})
 return enemy

func make_wave_roster(number: int,count_override: int=-1) -> Array:
 return enemy_director.make_wave_roster(number,count_override)

func begin_encounter(next_id: String, roster: Array) -> Dictionary:
 if transaction_active or phase=="combat" or hero.dead: return {"accepted":false,"reason":"invalid_phase"}
 if next_id.is_empty(): return {"accepted":false,"reason":"missing_room_id"}
 # Waves may intentionally share room_id: consumable budget belongs to the external room ledger.
 combat_level_id=next_id
 room_id=next_id
 wave+=1
 encounter_generation+=1
 _clear_wave_transients()
 enemies.clear()
 pending.clear()
 projectiles.clear()
 zones.clear()
 collision_pairs.clear()
 phase="combat"
 paused=false
 real_accumulator=0.0
 progression.begin_encounter()
 for entry in roster: spawn_enemy(entry.kind,entry.position,entry.get("hp",-1.0))
 common.begin_room()
 emit_event("encounter_started")
 return {"accepted":true,"reason":"ok"}
func _clear_wave_transients() -> void:
 dash_attack.clear()
 hero.dash_left=0
 dash_step_immune=false
 # Target identities and partially travelled trajectories belong to one enemy collection.
 # Do not resolve their landing/impact while replacing that collection.
 for key in ["chain_flight","e2","r2_charge","presentation"]: hero.cast_state.erase(key)
 r1_active=false
 clock.clear()
 if hero.cast_state.has("r2") and hero.cast_state.r2.count>=hero.cast_state.r2.maximum:
  # A final charge interrupted by room victory is spent, not a reusable form.
  # Its cancelled old-room impact must never resolve against a replacement roster.
  common.complete_action(hero.cast_state.r2.cast_id,true)
  hero.cast_state.erase("r2")
 if hero.cast_state.has("r2"):
  # Remaining ultimate charges are a retained resource. Require a fresh R command;
  # an old automatic continuation must never attack the replacement wave.
  hero.cast_state.r2.awaiting_rearm=true
  hero.cast_state.r2.adjust=2.0
func end_encounter(result: String) -> void:
 if phase!="combat": return
 # A dash is an in-flight action, not a stored between-wave resource.
 hero.dash_left=0
 dash_attack.clear()
 dash_step_immune=false
 phase=result
 common.end_room()
 real_accumulator=0
 hero.bone_stacks=0
 bone_timer=0
 layer_timer=0
 clock.clear()
 r1_active=false
 # Time-valued combat state is frozen across a safe interval, not silently refreshed.
 if progression.snapshot().in_combat: progression.end_encounter()
 emit_event("encounter_finished",{"result":result})
 frozen_snapshot=snapshot()
 encounter_finished.emit(frozen_snapshot.duplicate(true))
func _check_victory() -> void:
 if phase=="combat" and auto_finish and not enemies.is_empty() and living().is_empty(): end_encounter("victory")
func free_move(dt: float, move: Vector3) -> void:
 if paused or hero.dead or phase=="combat": return
 hero.move_intent=move.limit_length(1)
 hero.position=_move_clipped(hero.position,hero.position+hero.move_intent*hero.speed()*dt,0.65)
func clamp_position(at: Vector3, radius: float = 0.65) -> Vector3:
 var bound = arena_half_extent-radius
 var p=Vector3(clampf(at.x,-bound,bound),0,clampf(at.z,-bound,bound))
 for obstacle in obstacles:
  var c: Vector3=obstacle.position
  var half: Vector3=obstacle.half+Vector3(radius,0,radius)
  var offset=p-c
  if absf(offset.x)<half.x and absf(offset.z)<half.z:
   if half.x-absf(offset.x)<half.z-absf(offset.z): p.x=c.x+half.x*(1.0 if offset.x>=0 else -1.0)
   else: p.z=c.z+half.z*(1.0 if offset.z>=0 else -1.0)
 return p
func circle_targets(origin: Vector3, radius: float) -> Array:
 return enemies.filter(func(e):return not e.dead and e.state!="spawn" and e.position.distance_to(origin)<=radius+e.radius)
func cone_targets(origin: Vector3,direction: Vector3,radius: float,degrees: float) -> Array:
 var result: Array=[]
 for e in circle_targets(origin,radius):
  var offset: Vector3=e.position-origin
  if offset.length()<e.radius or offset.normalized().dot(direction)>=cos(deg_to_rad(degrees*0.5)): result.append(e)
 return result
func rectangle_targets(origin: Vector3,direction: Vector3,length: float,width: float) -> Array:
 var result: Array=[]
 var side=Vector3(-direction.z,0,direction.x)
 for e in enemies:
  if e.dead or e.state=="spawn": continue
  var offset: Vector3=e.position-origin
  if offset.dot(direction)>=-e.radius and offset.dot(direction)<=length+e.radius and absf(offset.dot(side))<=width*0.5+e.radius: result.append(e)
 return result
func request_action(action: String, aim: Vector3 = Vector3.INF, command_id: String = "") -> Dictionary:
 if not command_id.is_empty() and seen_commands.has(command_id): return seen_commands[command_id].duplicate(true)
 if transaction_active: return {"accepted":false,"reason":"transaction_in_progress"}
 common.ensure_combat()
 common.refresh_stats()
 transaction_active=true
 var result=_request_action(action,aim)
 transaction_active=false
 if not command_id.is_empty(): seen_commands[command_id]=result.duplicate(true)
 _check_victory()
 return result
func _request_action(action: String, aim: Vector3) -> Dictionary:
 if phase!="combat" or paused: return {"accepted":false,"reason":"encounter_frozen"}
 if hero.dead: return {"accepted":false,"reason":"not_alive"}
 if action not in ["attack","shift","q","e","r","e_release"]: return {"accepted":false,"reason":"unknown_action"}
 if hero.cast_state.has("r2_charge"): return {"accepted":false,"reason":"charging"}
 if action=="e_release":
  if hero.cast_state.has("e1"): hero.cast_state.e1.generation=encounter_generation; _release_guard(); return {"accepted":true,"reason":"released"}
  return {"accepted":false,"reason":"not_guarding"}
 # A press during the live dash is a distinct attack, never a queued normal swing.
 # It may combine with a dash which just cancelled a basic; once-per-dash bounds it.
 if action=="attack" and hero.dash_left>TIME_EPS:
  return _begin_dash_attack()
 # Repeat controls are checked before slot cooldowns.
 if action=="e" and hero.cast_state.has("e1"): hero.cast_state.e1.generation=encounter_generation; _release_guard(); return {"accepted":true,"reason":"released"}
 if action=="r" and hero.cast_state.has("r1"): hero.cast_state.r1.generation=encounter_generation; _finish_r1(); return {"accepted":true,"reason":"detonated"}
 # Shift can cancel a basic windup/recovery. Cancelled swings never resolve later.
 if action=="shift" and not r1_active and hero.dash_left<=0 and hero.cooldowns.shift<=0 and not hero.cast_state.has("e2") and not hero.cast_state.has("r2_charge"):
  var cancelled: Array=[]
  for entry in pending:
   if entry.kind=="attack_hit": cancelled.append(entry.cast_id)
  if not cancelled.is_empty():
   pending=pending.filter(func(entry):return not int(entry.get("cast_id",0)) in cancelled)
   for cancelled_id in cancelled: common.complete_action(cancelled_id,true)
   emit_event("attack_cancelled",{"cast_ids":cancelled,"position":hero.position})
   hero.lock_time=0
   hero.movement_lock_left=0
 if r1_active or hero.lock_time>0 or hero.dash_left>0: return {"accepted":false,"reason":"action_locked"}
 if hero.cast_state.has("e2") or hero.cast_state.has("r2_charge"): return {"accepted":false,"reason":"charging"}
 if action in ["q","e","r"] and hero.ranks[action]<=0: return {"accepted":false,"reason":"unlearned"}
 var repeating_r2=action=="r" and hero.cast_state.has("r2")
 if repeating_r2 and hero.cast_state.r2.count>=hero.cast_state.r2.maximum:
  return {"accepted":false,"reason":"no_charges"}
 var charged_q=action=="q" and hero.loadout.q=="q2" and hx("double_chain")
 if charged_q:
  if chain_charges<=0: return {"accepted":false,"reason":"no_charges"}
 elif hero.cooldowns[action]>0 and not repeating_r2: return {"accepted":false,"reason":"cooldown"}
 if action=="e" and hero.cast_state.has("e3"): return {"accepted":false,"reason":"already_active"}
 if aim.is_finite():
  hero.aim_point=aim
  var direction=aim-hero.position
  direction.y=0
  if direction.length_squared()>0.001: hero.facing=direction.normalized()
 cast_serial+=1
 var context={"cast_id":cast_serial,"origin":hero.position,"direction":hero.facing,"due":clock.world_time,"kind":action,"generation":encounter_generation}
 if not repeating_r2: common.start_action(action,cast_serial,hero.position)
 match action:
  "shift":
   if hero.cast_state.has("e1"): _release_guard()
   hero.dash_direction=hero.move_intent.normalized() if hero.move_intent.length_squared()>0.01 else hero.facing
   hero.dash_left=DASH_DURATION
   dash_serial+=1
   dash_attack.clear()
   hero.cooldowns.shift=effective_cd(v("D-4"))
   emit_event("dash",{"position":hero.position,"direction":hero.dash_direction,"duration":DASH_DURATION,"distance":DASH_DISTANCE,"invulnerable":true,"iframe_duration":DASH_DURATION,"dash_id":dash_serial})
  "attack":
   hero.attack_index=(hero.attack_index%int(v("ATK-1")))+1
   hero.cooldowns.attack=1.0/hero.attack_speed()
   var attack_contact: float=ANIMATION_TIMING["attack_%d"%hero.attack_index][0]*(T.BASE_ATTACK_SPEED/hero.attack_speed())
   _lock_animation("attack_%d"%hero.attack_index,attack_contact,1.0/hero.attack_speed())
   context.kind="attack_hit"
   context.due+=attack_contact
   context.contact_after=attack_contact
   context.recovery=(ANIMATION_TIMING["attack_%d"%hero.attack_index][1]-ANIMATION_TIMING["attack_%d"%hero.attack_index][0])*(T.BASE_ATTACK_SPEED/hero.attack_speed())
   context.combo=hero.attack_index
   context.damage=hero.ad()*f("ATK-3" if hero.attack_index==int(v("ATK-1")) else "ATK-2")
   context.critical=rng.randf()<clampf(hero.stats.crit_chance,0,1)
   if context.critical: context.damage*=1.75
   pending.append(context)
   var motion:Dictionary=context.duplicate(true)
   motion.kind="attack_motion"
   motion.due=clock.world_time+float(ATTACK_RELEASE[hero.attack_index])*(T.BASE_ATTACK_SPEED/hero.attack_speed())
   pending.append(motion)
   emit_event("attack_started",{"position":hero.position,"direction":hero.facing,"combo":hero.attack_index,"cast_id":cast_serial,"duration":attack_contact+context.recovery,"contact_after":attack_contact,"recovery":context.recovery})
  "q":
   if hero.loadout.q=="q2":
    var cd=effective_cd(common.base_cooldown("q",value("q2_cd","q")))
    if hx("double_chain"):
     chain_charges-=1
     chain_recharges.append(cd)
     hero.cooldowns.q=0 if chain_charges>0 else chain_recharges.min()
    else: hero.cooldowns.q=cd
    context.rank=hero.ranks.q
    context.kind="q2_release"
    context.due+=ANIMATION_TIMING.q2[0]
    pending.append(context)
    _lock_animation("q2")
    emit_event("q2_windup",{"position":hero.position,"direction":hero.facing,"cast_id":cast_serial,"duration":1.2})
   else:
    context.kind=hero.loadout.q
    context.due+=ANIMATION_TIMING[hero.loadout.q][0]
    _lock_animation(hero.loadout.q)
    context.rank=hero.ranks.q
    context.ad=hero.ad()
    context.max_hp=hero.stats.max_hp
    pending.append(context)
    start_skill_cooldown("q",value(hero.loadout.q+"_cd","q"))
    emit_event(hero.loadout.q+"_windup",{"position":hero.position,"direction":hero.facing,"cast_id":cast_serial,"duration":context.due-clock.world_time})
  "e":
   match hero.loadout.e:
    "e1":
     hero.cast_state.e1={"left":value("e1_duration","e"),"absorbed":0.0,"rank":hero.ranks.e,"cast_id":cast_serial,"generation":encounter_generation}
     emit_event("e1_guard_started",{"position":hero.position,"direction":hero.facing,"duration":value("e1_duration","e")})
    "e2":
     hero.cast_state.e2={"left":v("E2-2",hero.ranks.e),"duration":v("E2-2",hero.ranks.e),"distance":v("E2-1",hero.ranks.e),"extension":0.0,"direction":hero.facing,"carried":[],"touched":[],"rank":hero.ranks.e,"cast_id":cast_serial,"speed":v("E2-1",hero.ranks.e)/v("E2-2",hero.ranks.e),"wall":false,"generation":encounter_generation}
     start_skill_cooldown("e",value("e2_cd","e"))
     emit_event("e2_charge_started",{"position":hero.position,"direction":hero.facing,"duration":0.8})
    "e3":
     context.kind="e3_activate"
     context.due+=ANIMATION_TIMING.e3[0]
     context.rank=hero.ranks.e
     pending.append(context)
     _lock_animation("e3")
     start_skill_cooldown("e",value("e3_cd","e"))
     emit_event("e3_windup",{"position":hero.position,"radius":v("E3-1",hero.ranks.e),"duration":ANIMATION_TIMING.e3[1]})
  "r":
   if repeating_r2: _start_r2_charge()
   else:
    r1_active=true
    var show_time: float=ANIMATION_TIMING.r1_start[0] if hero.loadout.r=="r1" else ANIMATION_TIMING.r2_charge[0]
    clock.enter(hero.actor_id,show_time)
    hero.cast_state.presentation={"left":show_time,"candidate":hero.loadout.r,"rank":hero.ranks.r,"generation":encounter_generation,"cast_id":cast_serial}
    start_skill_cooldown("r",value(hero.loadout.r+"_cd","r"))
    emit_event("ultimate_started",{"position":hero.position,"candidate":hero.loadout.r,"duration":show_time,"contact_after":show_time,"radius":6.0})
 revision+=1
 return {"accepted":true,"reason":"ok","cast_id":cast_serial,"state_revision":revision}
func _begin_dash_attack() -> Dictionary:
 if not dash_attack.is_empty(): return {"accepted":false,"reason":"dash_attack_used"}
 cast_serial+=1
 var critical: bool=rng.randf()<clampf(hero.stats.crit_chance,0,1)
 var base_damage:float=hero.ad()*T.BASIC_DAMAGE_SCALE*DASH_ATTACK_SCALE*(1.75 if critical else 1.0)
 dash_attack={"cast_id":cast_serial,"dash_id":dash_serial,"generation":encounter_generation,"hits":[],"direction":hero.dash_direction,"base_damage":base_damage,"damage":base_damage,"critical":critical,"retaliation":false,"elapsed":0.0,"window_end":maxf(hero.dash_left,DASH_ATTACK_CONTACT),"motion_emitted":false,"contact_handled":false,"ended":false}
 hero.cooldowns.attack=maxf(hero.cooldowns.attack,1.0/hero.attack_speed())
 hero.lock_time=maxf(hero.lock_time,maxf(hero.dash_left,DASH_ATTACK_CONTACT+0.04))
 emit_event("dash_attack_started",{"position":hero.position,"direction":hero.dash_direction,"combo":0,"cast_id":cast_serial,"dash_id":dash_serial,"duration":DASH_ATTACK_PRESENTATION,"contact_after":DASH_ATTACK_CONTACT,"motion_after":DASH_ATTACK_RELEASE,"recovery":DASH_ATTACK_PRESENTATION-DASH_ATTACK_CONTACT,"active_duration":dash_attack.window_end,"reach":DASH_ATTACK_REACH,"width":DASH_ATTACK_WIDTH})
 revision+=1
 return {"accepted":true,"reason":"dash_attack","cast_id":cast_serial,"dash_id":dash_serial,"state_revision":revision}
func _sweep_dash_attack(before: Vector3, after: Vector3) -> void:
 if dash_attack.is_empty() or dash_attack.get("generation",-1)!=encounter_generation or dash_attack.get("ended",false) or float(dash_attack.get("elapsed",0))+TIME_EPS<DASH_ATTACK_CONTACT: return
 var direction: Vector3=dash_attack.direction
 var lateral:=Vector3(-direction.z,0,direction.x)
 var travel: float=maxf(0,(after-before).dot(direction))
 var hit_ids: Array=[]
 var hit_positions: Array=[]
 for enemy in living():
  if enemy.state=="spawn" or enemy.actor_id in dash_attack.hits: continue
  var offset: Vector3=enemy.position-before
  var forward: float=offset.dot(direction)
  # A swept forward box: no retrospective trail damage and no hits through walls.
  if forward < -float(enemy.radius) or forward > travel+DASH_ATTACK_REACH+float(enemy.radius): continue
  if absf(offset.dot(lateral))>DASH_ATTACK_WIDTH*0.5+float(enemy.radius): continue
  var contact_origin: Vector3=before.lerp(after,clampf(forward/maxf(travel,0.001),0,1))
  if _move_clipped(contact_origin,enemy.position,0.05).distance_squared_to(enemy.position)>0.01: continue
  dash_attack.hits.append(enemy.actor_id)
  hit_ids.append(enemy.actor_id)
  hit_positions.append(enemy.position)
  damage_enemy(enemy,dash_attack.damage,"dash_attack",dash_attack.cast_id,false,dash_attack.critical,{"position":contact_origin,"direction":direction,"combo":0,"dash_id":dash_attack.dash_id})
 if not hit_ids.is_empty(): emit_event("dash_attack_hit",{"position":after,"direction":direction,"cast_id":dash_attack.cast_id,"dash_id":dash_serial,"target_ids":hit_ids,"target_positions":hit_positions,"hit_count":hit_ids.size(),"reach":DASH_ATTACK_REACH,"width":DASH_ATTACK_WIDTH})
func _step_player_locomotion(real_dt: float) -> void:
 if hero.cast_state.has("r2_charge"):
  dash_step_immune=false
  return
 var prior: Vector3=hero.position
 var slice: float=minf(hero.dash_left,real_dt)
 dash_step_immune=slice>0 and slice+TIME_EPS>=real_dt
 if slice>0:
  hero.position=_move_clipped(prior,prior+hero.dash_direction*(DASH_DISTANCE/DASH_DURATION)*slice)
  hero.dash_left=maxf(0,hero.dash_left-slice)
  if hero.dash_left<=TIME_EPS:
   hero.dash_left=0
   common.dash_complete()
  # Finish the unused part of a fixed step as normal locomotion, not extra dash.
  if real_dt>slice: hero.position=_move_clipped(hero.position,hero.position+hero.move_intent.limit_length(1)*hero.speed()*(real_dt-slice))
 else:
  # Player input stays live during attacks, casts, guard, ultimate presentation and
  # soft hit reactions. Authored skill displacement is added separately below.
  hero.position=_move_clipped(prior,prior+hero.move_intent.limit_length(1)*hero.speed()*real_dt)
 _advance_dash_attack(real_dt,prior,hero.position)
 if hero.position.distance_squared_to(prior)>0.000001: hero.standing_time=0
 else: hero.standing_time+=real_dt
func _advance_dash_attack(real_dt:float,before:Vector3,after:Vector3)->void:
 if dash_attack.is_empty() or dash_attack.get("ended",false) or dash_attack.get("generation",-1)!=encounter_generation:return
 var previous:float=dash_attack.elapsed
 dash_attack.elapsed+=maxf(0,real_dt)
 if not dash_attack.motion_emitted and dash_attack.elapsed+TIME_EPS>=DASH_ATTACK_RELEASE:
  dash_attack.motion_emitted=true
  emit_event("dash_attack_motion",{"position":after,"direction":dash_attack.direction,"combo":0,"cast_id":dash_attack.cast_id,"dash_id":dash_attack.dash_id,"elapsed":dash_attack.elapsed,"release_after":DASH_ATTACK_RELEASE})
 if dash_attack.elapsed+TIME_EPS>=DASH_ATTACK_CONTACT:
  var first_contact:bool=not dash_attack.contact_handled
  var payload:Dictionary={}
  if first_contact:
   # Snapshot at contact, then preserve basic damage/lifesteal -> P2 heal order.
   payload=_retaliation_payload()
   dash_attack.damage=dash_attack.base_damage+payload.damage
   dash_attack.retaliation=payload.active;dash_attack.contact_handled=true
   # Timing authority resumes recovery even on a miss. This is not a hit cue.
   emit_event("dash_attack_impact",{"position":after,"direction":dash_attack.direction,"combo":0,"cast_id":dash_attack.cast_id,"dash_id":dash_attack.dash_id,"contact_after":DASH_ATTACK_CONTACT,"recovery":DASH_ATTACK_PRESENTATION-DASH_ATTACK_CONTACT})
  var ratio:float=clampf((DASH_ATTACK_CONTACT-previous)/maxf(real_dt,TIME_EPS),0.0,1.0)
  _sweep_dash_attack(before.lerp(after,ratio),after)
  if first_contact:_consume_retaliation(payload)
  if dash_attack.elapsed+TIME_EPS>=float(dash_attack.window_end):
   dash_attack.ended=true
   emit_event("dash_attack_ended",{"position":after,"cast_id":dash_attack.cast_id,"dash_id":dash_attack.dash_id,"hit_count":dash_attack.hits.size()})
func move_during_hitstop(real_dt: float, move: Vector3) -> void:
 if phase!="combat" or paused or hero.dead or real_dt<=0: return
 hero.move_intent=move.limit_length(1)
 _step_player_locomotion(real_dt)
 dash_step_immune=false
 revision+=1
func _cast_chain(context: Dictionary) -> void:
 var rank: int=int(context.get("rank",hero.ranks.q))
 var radius: float=v("Q2-1",rank)*(1.0+hf("close_chain") if hx("close_chain") else 1.0)
 var targets: Array=circle_targets(hero.position,radius).filter(func(e):return ordinary(e))
 var endpoints: Array=[]
 var target_ids: Array=[]
 for target in targets:
  var direction: Vector3=hero.position.direction_to(target.position)
  if direction.length_squared()<0.001: direction=context.direction
  endpoints.append(target.position)
  target_ids.append(target.actor_id)
  var amount: float=(v("Q2-4",rank)+hero.ad()*f("Q2-5",rank))*(1.0-hf("double_chain",2) if hx("double_chain") else 1.0)
  damage_enemy(target,amount,"q2",context.cast_id,false,false,{"position":hero.position,"cast_origin":context.origin,"direction":context.direction,"cast_damage_share":1.0/maxi(1,targets.size()),"replay_segment":{"target_mode":"bound","segment_id":"chain_damage"}})
  if not target.dead:
   target.pull_state={"origin":target.position,"destination":clamp_position(hero.position+direction*v("Q2-2",rank),target.radius),"left":v("Q2-3",rank),"duration":v("Q2-3",rank)}
   target.push={}
 # Shield belongs to this cast even if no ordinary enemy is in range.
 add_shield("q2",hero.stats.max_hp*f("Q2-6",rank),v("Q2-7",rank))
 common.complete_action(context.cast_id)
 emit_event("q2_chain",{"position":hero.position,"endpoint":hero.position+context.direction*radius,"endpoints":endpoints,"target_ids":target_ids,"direction":context.direction,"radius":radius,"duration":v("Q2-3",rank),"cast_id":context.cast_id,"hit":not targets.is_empty()})

func _resolve_pending(event: Dictionary) -> void:
 if event.get("generation",encounter_generation)!=encounter_generation: return
 if event.kind in ["attack_hit","q1","q3","q2_release"]: event.origin=hero.position
 match event.kind:
  "attack_motion":
   emit_event("attack_motion",{"position":hero.position,"direction":event.direction,"combo":event.combo,"cast_id":event.cast_id,"contact_after":event.contact_after})
  "q2_release": _cast_chain(event)
  "e3_activate":
   var duration: float=v("E3-2",event.rank)
   hero.cast_state.e3={"left":duration,"duration":duration,"rank":event.rank,"cast_id":event.cast_id,"radius":v("E3-1",event.rank),"entered":[],"saves":0}
   _issue_aura_shields()
   emit_event("e3_aura_started",{"position":hero.position,"radius":v("E3-1",event.rank),"duration":duration,"cast_id":event.cast_id})
  "e1_impact": _resolve_guard(event)
  "r2_final_impact": _resolve_r2_finish(event)
  "attack_hit":
   var targets: Array=cone_targets(event.origin,event.direction,hero.stats.get("attack_range",v("ATK-6")),v("ATK-7"))
   var retaliation:Dictionary=_retaliation_payload()
   var extra:float=retaliation.damage
   for target in targets:
    damage_enemy(target,event.damage+extra,"attack",event.cast_id,false,event.critical,{"position":event.origin,"cast_origin":event.origin,"direction":event.direction,"combo":event.combo})
    if event.combo==int(v("ATK-1")) and ordinary(target): push_enemy(target,event.direction,v("ATK-4"),"attack",event.cast_id)
   _consume_retaliation(retaliation)
   common.complete_action(event.cast_id)
   emit_event("attack_impact",{"position":event.origin,"direction":event.direction,"combo":event.combo,"cast_id":event.cast_id,"contact_after":event.contact_after,"recovery":event.recovery,"hit_count":targets.size(),"target_ids":targets.map(func(t):return t.actor_id),"radius":hero.stats.get("attack_range",v("ATK-6")),"angle":v("ATK-7")})
  "q1","q1_echo":
   var echo: bool=event.kind=="q1_echo"
   if not echo:
    hero.position=_move_clipped(hero.position,hero.position+event.direction*v("Q1-1",event.rank))
    event.origin=hero.position
    common.movement_complete(event.cast_id)
   var radius: float=v("Q1-2",event.rank)
   var angle: float=v("Q1-3",event.rank)
   var targets: Array=cone_targets(event.origin,event.direction,radius,angle)
   var damage: float=v("Q1-4",event.rank)+event.ad*f("Q1-5",event.rank)+event.max_hp*f("Q1-6",event.rank)
   var centre_angle: float=hv("gate_cleave") if hx("gate_cleave") else v("Q1-7",event.rank)
   for target in targets:
    var offset: Vector3=target.position-event.origin
    var central: bool=offset.length_squared()<0.001 or offset.normalized().dot(event.direction)>=cos(deg_to_rad(centre_angle*0.5))
    var multiplier: float=hf("double_echo",3) if echo else (1.0+hf("gate_cleave",2) if central and hx("gate_cleave") else 1.0)
    var metadata: Dictionary={"position":event.origin,"cast_origin":event.origin,"direction":event.direction,"cast_damage_share":1.0/maxi(1,targets.size())}
    if not echo: metadata.replay_segment={"target_mode":"spatial","segment_id":"gate_smash","shape":{"kind":"cone","direction":event.direction,"radius":radius,"degrees":angle}}
    damage_enemy(target,damage*multiplier,event.kind,event.cast_id,false,false,metadata)
    if central and not echo and ordinary(target): target.stun_left=maxf(target.stun_left,v("Q1-8",event.rank))
   if not echo and hx("double_echo") and targets.size()>=int(hv("double_echo")):
    var after: Dictionary=event.duplicate(true)
    after.kind="q1_echo"
    after.due=clock.world_time+hv("double_echo",2)
    pending.append(after)
   if not echo:
    if targets.is_empty(): common.record_spatial(event.cast_id,"gate_smash",damage*hero.stats.get("common_damage_multiplier",1.0),event.origin,{"kind":"cone","direction":event.direction,"radius":radius,"degrees":angle})
    common.complete_action(event.cast_id)
   emit_event(event.kind,{"position":event.origin,"direction":event.direction,"radius":radius,"angle":angle,"centre_angle":centre_angle,"cast_id":event.cast_id,"hit_count":targets.size()})
  "q3":
   var pushed: int=0
   var radius: float=v("Q3-1",event.rank)
   var angle: float=v("Q3-2",event.rank)
   var targets: Array=cone_targets(event.origin,event.direction,radius,angle)
   var amount: float=v("Q3-3",event.rank)+event.ad*f("Q3-4",event.rank)
   for target in targets:
    damage_enemy(target,amount,"q3",event.cast_id,false,false,{"position":event.origin,"direction":event.direction,"cast_origin":event.origin,"cast_damage_share":1.0/maxi(1,targets.size()),"replay_segment":{"target_mode":"spatial","segment_id":"sweep_damage","shape":{"kind":"cone","direction":event.direction,"radius":radius,"degrees":angle}}})
    if not target.dead and ordinary(target):
     pushed+=1
     var direction: Vector3=event.origin.direction_to(target.position)
     if direction.length_squared()<0.01: direction=event.direction
     push_enemy(target,direction,v("Q3-5",event.rank),"q3",event.cast_id,v("Q3-7",event.rank)+event.ad*f("Q3-8",event.rank),v("Q3-6",event.rank),v("Q3-9",event.rank))
   if hx("no_crowding") and pushed>=int(hv("no_crowding")): hero.cooldowns.q=maxf(0,hero.cooldowns.q-effective_cd(v("Q3-10",event.rank))*hf("no_crowding",2))
   if targets.is_empty(): common.record_spatial(event.cast_id,"sweep_damage",amount*hero.stats.get("common_damage_multiplier",1.0),event.origin,{"kind":"cone","direction":event.direction,"radius":radius,"degrees":angle})
   common.complete_action(event.cast_id,false,true)
   emit_event("q3",{"position":event.origin,"direction":event.direction,"radius":radius,"angle":angle,"pushed":pushed,"cast_id":event.cast_id})

func _release_guard() -> void:
 if not hero.cast_state.has("e1"): return
 var state: Dictionary=hero.cast_state.e1
 hero.cast_state.erase("e1")
 start_skill_cooldown("e",v("E1-10",state.rank))
 if state.get("generation",encounter_generation)!=encounter_generation:
  emit_event("e1_expired",{"position":hero.position,"stale_generation":true})
  return
 var boosted: bool=hx("again") and state.absorbed>=hero.stats.max_hp*hf("again")
 var amount: float=(v("E1-7",state.rank)+hero.ad()*f("E1-8",state.rank))*(1.0+hf("again",2) if boosted else 1.0)
 var event: Dictionary={"kind":"e1_impact","due":clock.world_time+ANIMATION_TIMING.e1_release[0],"generation":encounter_generation,"rank":state.rank,"cast_id":state.cast_id,"boosted":boosted,"stacks":1 if boosted else 0,"direction":hero.facing,"damage":amount,"welcome":hx("welcome")}
 if hx("welcome"):
  hero.cast_state.guard_step={"left":hv("welcome",2),"duration":hv("welcome",2),"distance":hv("welcome"),"direction":hero.facing}
  event.due=clock.world_time+hv("welcome",2)
 pending.append(event)
 _lock_animation("e1_release",event.due-clock.world_time,event.due-clock.world_time+0.25)
 emit_event("e1_release_windup",{"position":hero.position,"direction":hero.facing,"contact_after":event.due-clock.world_time,"duration":event.due-clock.world_time+0.25,"cast_id":state.cast_id})

func _resolve_guard(event: Dictionary) -> void:
 var scale: float=1.0+hf("again",3) if event.boosted else 1.0
 var length: float=v("E1-5",event.rank)*scale
 var width: float=v("E1-6",event.rank)*scale
 var targets: Array=rectangle_targets(hero.position,event.direction,length,width)
 for target in targets:
  damage_enemy(target,event.damage,"e1",event.cast_id,false,false,{"position":hero.position,"cast_origin":hero.position,"direction":event.direction,"cast_damage_share":1.0/maxi(1,targets.size()),"replay_segment":{"target_mode":"spatial","segment_id":"guard_release","shape":{"kind":"rectangle","direction":event.direction,"length":length,"width":width}}})
  if ordinary(target):
   push_enemy(target,event.direction,v("E1-9",event.rank)+(hv("welcome",3) if event.welcome else 0.0),"e1",event.cast_id)
   if event.boosted: target.stun_left=maxf(target.stun_left,hv("again",4))
 if targets.is_empty(): common.record_spatial(event.cast_id,"guard_release",event.damage*hero.stats.get("common_damage_multiplier",1.0),hero.position,{"kind":"rectangle","direction":event.direction,"length":length,"width":width})
 common.complete_action(event.cast_id)
 emit_event("e1_release",{"position":hero.position,"direction":event.direction,"radius":length,"length":length,"width":width,"shape":"rectangle","stacks":event.stacks,"cast_id":event.cast_id})

func _finish_e2(wall: bool) -> void:
 if not hero.cast_state.has("e2"): return
 var state: Dictionary=hero.cast_state.e2
 hero.cast_state.erase("e2")
 _lock_animation("e2",0.0,4.0/30.0)
 var amount: float=v("E2-5",state.rank)+hero.ad()*f("E2-6",state.rank)
 for id in state.touched:
  var target: Dictionary=enemy_by_id(id)
  if target.is_empty() or target.dead: continue
  target.carried=false
  damage_enemy(target,amount,"e2",state.cast_id,false,false,{"position":hero.position,"direction":state.direction,"cast_damage_share":1.0/maxi(1,state.touched.size()),"replay_segment":{"target_mode":"bound","segment_id":"charge_release_damage"}})
  if not ordinary(target): continue
  if wall or id in state.get("wall_targets",[]):
   _e2_wall_impact(target,state.rank,state.cast_id)
  elif not target.dead:
   push_enemy(target,state.direction,v("E2-4",state.rank),"e2_throw",state.cast_id)
   target.push.rank=state.rank
 common.movement_complete(state.cast_id)
 common.complete_action(state.cast_id,false,true)
 emit_event("e2_wall" if wall else "e2_release",{"position":hero.position,"direction":state.direction,"radius":v("E2-3",state.rank),"width":v("E2-3",state.rank),"carried":state.carried.size(),"cast_id":state.cast_id})
func _e2_wall_impact(target: Dictionary,rank: int,id: int) -> void:
 var key: String="e2wall:%d:%s"%[id,target.actor_id]
 if collision_pairs.has(key): return
 collision_pairs[key]=true
 var amount: float=v("E2-7",rank)+hero.ad()*f("E2-8",rank)
 damage_enemy(target,amount,"e2_wall",id,false,false,{"position":target.position,"cast_damage_share":0.0,"replay_segment":{"target_mode":"bound","segment_id":"actual_wall_impact_damage"}})
 target.stun_left=maxf(target.stun_left,v("E2-9",rank))
 var at_edge: bool=maxf(absf(target.position.x),absf(target.position.z))>=arena_half_extent-target.radius-0.45
 if hx("wall_kill") and at_edge:
  for other in circle_targets(target.position,hv("wall_kill")):
   if other.actor_id!=target.actor_id: damage_enemy(other,amount*hf("wall_kill",2),"hex_wall_kill",id)
  emit_event("wall_shock",{"position":target.position,"radius":hv("wall_kill"),"cast_id":id})

func _finish_r1() -> void:
 if not hero.cast_state.has("r1"): return
 var state: Dictionary=hero.cast_state.r1
 hero.cast_state.erase("r1")
 state.left=ANIMATION_TIMING.r1_end[0]
 state.low=hero.hp<hero.stats.max_hp*(hf("unbroken") if hx("unbroken") else 0.0)
 state.damage=v("R1-8",state.rank)+hero.ad()*f("R1-9",state.rank)
 hero.cast_state.r1_release=state
 _lock_animation("r1_end")
 emit_event("r1_release_windup",{"position":hero.position,"radius":v("R1-7",state.rank),"pressure":state.pressure,"duration":ANIMATION_TIMING.r1_end[1]})

func _resolve_r1_finish(state: Dictionary) -> void:
 var radius: float=v("R1-7",state.rank)
 for target in (circle_targets(hero.position,radius) if state.get("generation",encounter_generation)==encounter_generation else []):
  damage_enemy(target,state.damage+state.pressure*f("R1-10",state.rank),"r1",state.cast_id)
 add_shield("r1",state.pressure*f("R1-11",state.rank)*(1.0-hf("target",2) if hx("target") else 1.0),v("R1-12",state.rank))
 if state.low and hx("unbroken"): heal(hero.stats.max_hp*hf("unbroken",2),false)
 common.complete_action(state.cast_id)
 emit_event("r1_release",{"position":hero.position,"radius":radius,"pressure":state.pressure,"cast_id":state.cast_id,"stale_generation":state.get("generation",encounter_generation)!=encounter_generation})

func _start_r2_charge(skip_windup: bool=false) -> void:
 if not hero.cast_state.has("r2"): return
 var state: Dictionary=hero.cast_state.r2
 if state.count>=state.maximum: return
 state.generation=encounter_generation
 state.awaiting_rearm=false
 var direction: Vector3=hero.facing
 var reversing: bool=hx("return_gate") and state.count>0 and direction.dot(state.last_direction)<=cos(deg_to_rad(hv("return_gate")))
 state.count+=1
 state.last_direction=direction
 var speed_scale: float=1.0+hf("return_gate",3) if reversing else 1.0
 var duration: float=v("R2-5",state.rank)/speed_scale
 hero.cast_state.r2_charge={"left":duration,"duration":duration,"windup":0.0 if skip_windup else ANIMATION_TIMING.r2_charge[0],"direction":direction,"speed":v("R2-3",state.rank)/duration,"hits":[],"damage_bonus":1.0+hf("return_gate",2) if reversing else 1.0,"rank":state.rank,"cast_id":state.cast_id,"wall_hit":false,"carried":[],"generation":encounter_generation}
 emit_event("r2_charge_started",{"position":hero.position,"direction":direction,"charge":state.count,"maximum":state.maximum,"reverse":reversing,"duration":duration,"width":v("R2-4",state.rank),"distance":v("R2-3",state.rank),"contact_after":0.0 if skip_windup else ANIMATION_TIMING.r2_charge[0],"presentation_completed":skip_windup})

func _finish_r2_charge(wall: bool) -> void:
 if not hero.cast_state.has("r2_charge"): return
 var charge: Dictionary=hero.cast_state.r2_charge
 hero.cast_state.erase("r2_charge")
 common.movement_complete(charge.cast_id)
 hero.lock_time=maxf(hero.lock_time,4.0/30.0)
 if wall:
  var radius: float=v("R2-10",charge.rank)
  for target in circle_targets(hero.position,radius):
   damage_enemy(target,v("R2-11",charge.rank)+hero.ad()*f("R2-12",charge.rank),"r2_wall",charge.cast_id)
   if ordinary(target): target.stun_left=maxf(target.stun_left,v("R2-13",charge.rank))
  emit_event("r2_wall",{"position":hero.position,"radius":radius,"cast_id":charge.cast_id})
 if not hero.cast_state.has("r2"): return
 var state: Dictionary=hero.cast_state.r2
 if state.count>=state.maximum or state.left<=TIME_EPS: _finish_r2()
 else: emit_event("r2_adjust",{"position":hero.position,"remaining":state.maximum-state.count,"duration":state.left})

func _finish_r2() -> void:
 if not hero.cast_state.has("r2"): return
 var state: Dictionary=hero.cast_state.r2
 hero.cast_state.erase("r2")
 hero.cast_state.erase("r2_charge")
 var amount: float=v("R2-15",state.rank)+hero.ad()*f("R2-16",state.rank)+hero.stats.max_hp*f("R2-17",state.rank)
 pending.append({"kind":"r2_final_impact","due":clock.world_time+ANIMATION_TIMING.r2_end[0],"generation":state.get("generation",encounter_generation),"damage":amount,"cast_id":state.cast_id,"rank":state.rank,"charges":state.count})
 _lock_animation("r2_end")
 emit_event("r2_finish_windup",{"position":hero.position,"radius":v("R2-14",state.rank),"charges":state.count,"duration":ANIMATION_TIMING.r2_end[1]})

func _resolve_r2_finish(event: Dictionary) -> void:
 var radius: float=v("R2-14",event.rank)
 for target in circle_targets(hero.position,radius): damage_enemy(target,event.damage,"r2_finish",event.cast_id)
 common.complete_action(event.cast_id)
 emit_event("r2_finish",{"position":hero.position,"radius":radius,"charges":event.charges,"cast_id":event.cast_id})

func add_shield(id: String, amount: float, duration: float, metadata: Dictionary = {}) -> void:
 if amount<=0: return
 hero.shields[id]=common.shield_metadata(id,amount,duration,metadata)
 emit_event("shield",{"target":hero.actor_id,"source":id,"amount":amount,"initial_amount":amount,"owner_id":hero.actor_id,"duration":duration})
func heal(amount: float, _is_lifesteal: bool, metadata: Dictionary = {}) -> float:
 return heal_actor(hero,amount,metadata)
func heal_actor(actor: RefCounted, amount: float, metadata: Dictionary = {}) -> float:
 if actor.dead: return 0.0
 var actual: float=minf(actor.stats.max_hp-actor.hp,maxf(0,amount))
 actor.hp+=actual
 if phase=="combat":
  common.ensure_combat()
  common.healed(actor,actual,metadata)
  common.drain()
 return actual

func _kill_enemy(enemy: Dictionary,source: String,cast_id: int) -> void:
 if enemy.dead: return
 enemy.hp=0.0
 enemy.dead=true
 enemy.state="dead"
 enemy.push={}
 enemy.carried=false
 common.killed(enemy,source,cast_id)
 emit_event("kill",{"target":enemy.actor_id,"position":enemy.position,"source":source,"cast_id":cast_id,"credit":"solo_lethal","enemy_kind":enemy.kind})

func damage_enemy(enemy: Dictionary, amount: float, source: String, cast_id: int = 0, is_true: bool = false, critical: bool = false, metadata: Dictionary = {}) -> bool:
 if phase!="combat" or paused or enemy.dead or enemy.state=="spawn": return false
 common._inside_hit+=1
 var event: Dictionary=common.before_hit(enemy,amount,source,cast_id,is_true,critical,metadata)
 # Guard must face the original source/impact, not the player's later position.
 var source_position: Vector3=event.get("position",hero.position)
 var guard_factor:float=enemy_director.guard_multiplier(enemy,source_position,source,is_true)
 var packet: float=maxf(0,event.amount)*guard_factor
 var penetration:float=float(event.get("saved_stats",{}).get("penetration",hero.stats.penetration)) if event.get("replay",false) else hero.stats.penetration
 if not is_true: packet*=100.0/(100.0+maxf(0,enemy.defence-penetration))
 var actual: float=minf(enemy.hp,packet)
 enemy.hp=maxf(0,enemy.hp-packet)
 emit_event("damage",{"target":enemy.actor_id,"position":enemy.position,"source_position":source_position,"amount":actual,"source":source,"cast_id":cast_id,"critical":event.get("critical",critical),"damage_type":"true" if is_true else "ordinary","hex_generated":event.get("hex_generated",false),"replay":event.get("replay",false),"saved_aim":event.get("saved_aim",hero.facing),"generation":encounter_generation,"combo":int(event.get("combo",0)),"enemy_kind":enemy.kind,"target_radius":enemy.radius,"guarded":guard_factor<1.0,"guard_factor":guard_factor,"absorbed":0.0,"basic_attack":source in ["attack","dash_attack"]})
 if not is_true and not event.get("no_reactions",false): heal(actual*hero.lifesteal()*(1.0 if source=="attack" and int(event.get("combo",hero.attack_index))!=3 else 0.4),true,{"source":"lifesteal"})
 if event.has("replay_segment"):
  var segment: Dictionary=event.replay_segment
  if segment.get("target_mode","")=="bound": common.record_bound(cast_id,segment.segment_id,enemy,event.amount,source_position,{"critical":event.get("critical",false)})
  else: common.record_spatial(cast_id,segment.segment_id,event.amount,source_position,segment.shape,{"critical":event.get("critical",false),"original_target_id":enemy.actor_id,"cast_bonus_final":event.get("cast_bonus_final",0.0)})
 if enemy.hp<=0: _kill_enemy(enemy,source,cast_id)
 common.after_hit(event,actual)
 common._inside_hit-=1
 common.drain()
 return enemy.dead
func damage_hero(amount: float,direction: Vector3=Vector3.ZERO,control: float=0.0,is_true: bool=false,mandatory: bool=false,metadata: Dictionary = {}) -> void:
 if phase!="combat" or paused or hero.dead: return
 if not mandatory and (r1_active or hero.invulnerable_left>0 or hero.dash_left>TIME_EPS or dash_step_immune): return
 common.ensure_combat()
 common.refresh_stats()
 var raw: float=maxf(0,amount)*(1.0 if mandatory else enemy_director.incoming_damage_multiplier(self))
 if hero.cast_state.has("r1"):
  var state: Dictionary=hero.cast_state.r1
  var ratio: float=f("R1-5",state.rank)+(hf("target") if hx("target") else 0.0)
  state.pressure=minf(hero.stats.max_hp*f("R1-6",state.rank),state.pressure+raw*ratio)
 var frontal: bool=direction.length_squared()<0.001 or hero.facing.dot(-direction.normalized())>=cos(deg_to_rad(v("E1-3",hero.ranks.e)*0.5))
 var guard: bool=hero.cast_state.has("e1") and frontal
 var packet: float=raw
 if not is_true:
  packet*=100.0/(100.0+maxf(0,hero.defence()))
  if guard: packet*=1.0-f("E1-4",hero.cast_state.e1.rank)
  if hero.cast_state.has("r1"): packet*=1.0-f("R1-2",hero.cast_state.r1.rank)
  if hero.cast_state.has("r2_charge") and hero.cast_state.r2_charge.get("windup",0.0)<=0: packet*=1.0-f("R2-6",hero.cast_state.r2_charge.rank)
 var before_shields: float=packet
 for id in hero.shields.keys():
  var absorbed: float=minf(hero.shields[id].amount,packet)
  hero.shields[id].amount-=absorbed
  packet-=absorbed
  common.absorbed(hero,hero.shields[id],absorbed,"self_sacrifice" if mandatory else str(metadata.get("damage_provenance","enemy_damage")))
  if hero.shields[id].amount<=TIME_EPS: hero.shields.erase(id)
  if packet<=0: break
 var absorbed_total: float=maxf(0,before_shields-packet)
 packet=common.incoming(packet,bool(metadata.get("direct",not mandatory and not _common_zone_tick)))
 var lost: float=minf(hero.hp,packet)
 hero.hp=maxf(0,hero.hp-packet)
 # H08 uses actual damage received, unlike R1 which explicitly records pre-reduction damage.
 if hero.cast_state.has("e1"): hero.cast_state.e1.absorbed+=lost
 loss_window.append({"time":clock.world_time,"amount":lost})
 _prune_losses()
 if hero.loadout.passive=="p2" and hero.ranks.passive>0 and hero.cooldowns.passive<=0 and retaliation_left<=0 and not hero.dead:
  var total: float=0.0
  for entry in loss_window: total+=entry.amount
  if total>=hero.stats.max_hp*f("P2-2",hero.ranks.passive):
   retaliation_left=INF
   hero.cooldowns.passive=v("P2-6",hero.ranks.passive)
   loss_window.clear()
   emit_event("retaliation_ready",{"duration":-1.0})
 var immune_control: bool=hero.cast_state.has("r2_charge")
 if control>0 and not guard and not immune_control: hero.stun_left=maxf(hero.stun_left,control*(1.0-hero.tenacity()))
 emit_event("damage",{"target":hero.actor_id,"position":hero.position,"amount":lost,"raw":raw,"absorbed":absorbed_total,"guarded":guard,"direction":direction,"source":"comrades" if mandatory else "enemy","damage_type":"true" if is_true else "ordinary"})
 if hero.hp<=0: _common_true_death()
 common.drain()

func _prune_losses() -> void:
 var duration: float=v("P2-1",hero.ranks.passive)
 loss_window=loss_window.filter(func(e):return clock.world_time-e.time<=duration)

func knock_enemy(enemy: Dictionary,direction: Vector3,strength: float) -> void:
 if enemy.kind=="boss": return
 push_enemy(enemy,direction,strength*0.2,"knockback",cast_serial)
func push_enemy(enemy: Dictionary,direction: Vector3,distance: float,source: String,id: int,collision_damage: float=0.0,duration: float=0.35,collision_stun: float=0.0) -> void:
 if enemy.dead or enemy.kind=="boss": return
 enemy.push={"direction":direction.normalized(),"left":duration,"duration":duration,"distance":distance/maxf(0.01,float(enemy.get("common_knockback_resistance_multiplier",1.0))),"source":source,"cast_id":id,"collision_damage":collision_damage,"collision_stun":collision_stun,"hits":[],"count":0}
 enemy.stun_left=maxf(enemy.stun_left,duration)

func self_rescue() -> bool: return false # No invented extra life in this single-room test mode.
func step(real_delta: float) -> void:
 if phase!="combat" or paused or real_delta<=0: return
 real_accumulator+=real_delta
 while real_accumulator+0.0000001>=FIXED_TICK and phase=="combat" and not paused:
  real_accumulator-=FIXED_TICK
  _fixed_step(FIXED_TICK)
  dash_step_immune=false
func _fixed_step(real_dt: float) -> void:
 common.ensure_combat()
 common.refresh_stats()
 var dt=clock.step(real_dt,true)
 if hero.cast_state.has("presentation"):
  hero.cast_state.presentation.left-=real_dt
  if hero.cast_state.presentation.left<=0.000001:
   var show: Dictionary=hero.cast_state.presentation
   hero.cast_state.erase("presentation")
   r1_active=false
   common.ultimate_ready(int(show.get("cast_id",cast_serial)))
   if show.candidate=="r1":
    hero.cast_state.r1={"left":v("R1-1",show.rank),"pressure":0.0,"rank":show.rank,"cast_id":cast_serial,"generation":show.generation,"taunt_radius":v("R1-4",show.rank)}
    hero.lock_time=maxf(hero.lock_time,0.08)
    emit_event("r1_fortress_started",{"position":hero.position,"duration":v("R1-1",show.rank),"radius":v("R1-4",show.rank)})
   else:
    hero.cast_state.r2={"left":v("R2-1",show.rank),"count":0,"maximum":int(v("R2-2",show.rank))+(int(hv("fourth")) if hx("fourth") else 0),"last_direction":Vector3.ZERO,"rank":show.rank,"cast_id":cast_serial,"generation":show.generation,"awaiting_rearm":false}
    _start_r2_charge(true)
 # Player and all battle timers obey world time; only ultimate presentation uses real time.
 for key in hero.cooldowns: hero.cooldowns[key]=0.0 if hero.cooldowns[key]-dt<=TIME_EPS else hero.cooldowns[key]-dt
 for key in ["lock_time","movement_lock_left","invulnerable_left","stun_left","slow_left"]: hero.set(key,0.0 if hero.get(key)-dt<=TIME_EPS else hero.get(key)-dt)
 retaliation_left=maxf(0,retaliation_left-dt)
 for i in range(chain_recharges.size()-1,-1,-1):
  chain_recharges[i]-=dt
  if chain_recharges[i]<=0:
   chain_recharges.remove_at(i)
   chain_charges=mini(int(hv("double_chain")),chain_charges+1)
 if hx("double_chain"):
  hero.cooldowns.q=0.0 if chain_charges>0 else (chain_recharges.min() if not chain_recharges.is_empty() else 0.0)
 for id in hero.shields.keys():
  if hero.shields[id].left<0: continue
  hero.shields[id].left-=dt
  if hero.shields[id].left<=0: hero.shields.erase(id)
 for ally in allies:
  for id in ally.shields.keys():
   if ally.shields[id].left<0: continue
   ally.shields[id].left-=dt
   if ally.shields[id].left<=0: ally.shields.erase(id)
 _step_player_locomotion(real_dt)
 heal(hero.stats.regen*dt,false,{"source":"regeneration"})
 _build_spatial()
 hero.crowd_count=mini(5,circle_targets(hero.position,6).size())
 if hero.loadout.passive=="p1" and hero.ranks.passive>0:
  bone_timer+=dt
  while bone_timer>=v("P1-1",hero.ranks.passive):
   bone_timer-=v("P1-1",hero.ranks.passive)
   hero.bone_stacks=mini(int(v("P1-3",hero.ranks.passive)),hero.bone_stacks+int(v("P1-2",hero.ranks.passive)))
 else:
  hero.bone_stacks=0
  bone_timer=0
 _prune_losses()
 for entry in pending.duplicate():
  if entry.due<=clock.world_time+TIME_EPS:
   pending.erase(entry)
   _resolve_pending(entry)
   if phase!="combat": return
 _step_abilities(dt)
 if phase!="combat": return
 enemy_director.begin_step(self,dt)
 for enemy in enemies:
  _step_pull(enemy,dt)
  _step_push(enemy,dt)
  if ai_enabled: _step_enemy(enemy,dt)
  elif enemy.state=="spawn":
   enemy.timer-=dt
   if enemy.timer<=0: enemy.state="chase"
  if phase!="combat": return
 _step_projectiles(dt)
 _step_zones(dt)
 common.tick(dt)
 _check_victory()
 revision+=1
func _step_abilities(dt: float) -> void:
 if hero.cast_state.has("guard_step"):
  var step_state: Dictionary=hero.cast_state.guard_step
  hero.position=_move_clipped(hero.position,hero.position+step_state.direction*step_state.distance/step_state.duration*minf(dt,step_state.left))
  step_state.left-=dt
  if step_state.left<=TIME_EPS: hero.cast_state.erase("guard_step")
 if hero.cast_state.has("r1_release"):
  hero.cast_state.r1_release.left-=dt
  if hero.cast_state.r1_release.left<=TIME_EPS:
   var release: Dictionary=hero.cast_state.r1_release
   hero.cast_state.erase("r1_release")
   _resolve_r1_finish(release)
 if hero.cast_state.has("e1"):
  hero.cast_state.e1.left-=dt
  if hero.cast_state.e1.left<=TIME_EPS: _release_guard()
 if hero.cast_state.has("e3"):
  var aura: Dictionary=hero.cast_state.e3
  aura.left-=dt
  var extra: float=hf("this_city",2) if hx("this_city") and hero.standing_time>hv("this_city") else 0.0
  aura.radius=v("E3-1",aura.rank)*(1.0+extra)
  _issue_aura_shields()
  if aura.left<=TIME_EPS:
   hero.cast_state.erase("e3")
   common.complete_action(aura.cast_id)
   emit_event("e3_aura_ended")
 if hero.cast_state.has("r1"):
  hero.cast_state.r1.left-=dt
  if hero.cast_state.r1.left<=TIME_EPS: _finish_r1()
 if hero.cast_state.has("e2"):
  var state: Dictionary=hero.cast_state.e2
  var before: Vector3=hero.position
  var delta: Vector3=state.direction*state.speed*minf(dt,state.left)
  var desired: Vector3=before+delta
  var result: Vector3=_move_clipped(before,desired)
  var wall: bool=result.distance_squared_to(desired)>0.0001
  hero.position=result
  hero.standing_time=0
  for target in rectangle_targets(before,state.direction,before.distance_to(result)+1.2,v("E2-3",state.rank)):
   if target.actor_id in state.touched: continue
   state.touched.append(target.actor_id)
   if ordinary(target):
    state.carried.append(target.actor_id)
    target.carried=true
    target.push={}
    target.pull_state={}
    if hx("no_brakes"):
     var extension: float=minf(hf("no_brakes"),maxf(0,hf("no_brakes",2)-state.extension))
     state.extension+=extension
     state.left+=state.duration*extension
     emit_event("e2_charge_extended",{"position":hero.position,"contact_after":state.left,"recovery":4.0/30.0,"resume":true})
   elif target.kind!="boss":
    push_enemy(target,state.direction,state.distance*f("E2-10",state.rank),"e2_elite",state.cast_id,0,state.duration)
    target.push.rank=state.rank
  for i in range(state.carried.size()):
   var target: Dictionary=enemy_by_id(state.carried[i])
   if target.is_empty() or target.dead: continue
   var side: Vector3=Vector3(-state.direction.z,0,state.direction.x)
   var spacing: float=0.45*float((i%5)-2)
   var intended: Vector3=hero.position+state.direction*(1.1+float(i/5)*0.2)+side*spacing
   var placed: Vector3=_move_clipped(target.position,intended,target.radius)
   if placed.distance_squared_to(intended)>0.001:
    if not state.has("wall_targets"): state.wall_targets=[]
    if target.actor_id not in state.wall_targets: state.wall_targets.append(target.actor_id)
   target.position=placed
  state.left-=dt
  if state.left<=TIME_EPS or wall: _finish_e2(wall)
 if hero.cast_state.has("r2"):
  var state: Dictionary=hero.cast_state.r2
  state.left-=dt
  if hero.cast_state.has("r2_charge"):
   var charge: Dictionary=hero.cast_state.r2_charge
   if charge.windup>0:
    charge.windup=maxf(0,charge.windup-dt)
    return
   var before: Vector3=hero.position
   var desired: Vector3=before+charge.direction*charge.speed*minf(dt,charge.left)
   var result: Vector3=_move_clipped(before,desired)
   var wall: bool=result.distance_squared_to(desired)>0.0001
   hero.position=result
   hero.standing_time=0
   for target in rectangle_targets(before,charge.direction,before.distance_to(result)+0.7,v("R2-4",charge.rank)):
    if target.actor_id in charge.hits: continue
    charge.hits.append(target.actor_id)
    var amount: float=(v("R2-7",charge.rank)+hero.ad()*f("R2-8",charge.rank)+hero.stats.max_hp*f("R2-9",charge.rank))*charge.damage_bonus*(1.0-hf("fourth",2) if hx("fourth") else 1.0)
    damage_enemy(target,amount,"r2_charge",charge.cast_id)
   charge.left-=dt
   if charge.left<=TIME_EPS or wall or state.left<=TIME_EPS: _finish_r2_charge(wall)
  elif state.left<=TIME_EPS: _finish_r2()

func _cell(at: Vector3) -> Vector2i: return Vector2i(floori(at.x/2.5),floori(at.z/2.5))
func _build_spatial() -> void:
 spatial.clear()
 pair_checks=0
 for enemy in enemies:
  if enemy.dead: continue
  var cell=_cell(enemy.position)
  if not spatial.has(cell): spatial[cell]=[]
  spatial[cell].append(enemy)
func _nearby(at: Vector3, limit: int = 0, exclude: String = "") -> Array:
 var result: Array=[]
 var cell=_cell(at)
 for x in range(-1,2):
  for z in range(-1,2):
   for enemy in spatial.get(cell+Vector2i(x,z),[]):
    if enemy.actor_id==exclude: continue
    result.append(enemy)
    if limit>0 and result.size()>=limit: return result
 return result
func _step_pull(enemy: Dictionary,dt: float) -> void:
 if enemy.dead or enemy.pull_state.is_empty(): return
 var pull: Dictionary=enemy.pull_state
 pull.left-=dt
 var desired: Vector3=pull.origin.lerp(pull.destination,clampf(1.0-pull.left/pull.duration,0,1))
 var moved=_move_clipped(enemy.position,desired,enemy.radius)
 var blocked=moved.distance_squared_to(desired)>0.0001
 enemy.position=moved
 if pull.left<=TIME_EPS or blocked: enemy.pull_state={}
func _move_clipped(origin: Vector3,destination: Vector3,radius: float=0.65) -> Vector3:
 var steps=maxi(1,ceili(origin.distance_to(destination)/0.2))
 var result=origin
 for i in range(1,steps+1):
  var intended=origin.lerp(destination,float(i)/steps)
  var constrained=clamp_position(intended,radius)
  if intended.distance_squared_to(constrained)>0.0001: return result
  result=constrained
 return result
func _step_push(enemy: Dictionary,dt: float) -> void:
 if enemy.dead or enemy.push.is_empty() or enemy.carried: return
 var push: Dictionary=enemy.push
 var proposed: Vector3=enemy.position+push.direction*push.distance/maxf(0.001,push.duration)*minf(dt,push.left)
 var moved: Vector3=_move_clipped(enemy.position,proposed,enemy.radius)
 var blocked: bool=moved.distance_squared_to(proposed)>0.0001
 enemy.position=moved
 if blocked and push.source in ["e2_throw","e2_elite"]: _e2_wall_impact(enemy,int(push.get("rank",hero.ranks.e)),push.cast_id)
 if push.source=="q3" and push.collision_damage>0:
  for other in _nearby(enemy.position):
   if other.actor_id==enemy.actor_id or other.dead or other.state=="spawn" or other.actor_id in push.hits: continue
   if enemy.position.distance_to(other.position)>enemy.radius+other.radius+0.1: continue
   var maximum=int(hv("body_weapon")) if hx("body_weapon") else 1
   if push.count>=maximum: break
   var pair=[enemy.actor_id,other.actor_id]
   pair.sort()
   var pair_key=str(push.cast_id)+":"+pair[0]+":"+pair[1]
   if collision_pairs.has(pair_key): continue
   # Base limit means each target may participate in only one collision this cast.
   if not hx("body_weapon") and (collision_pairs.has(str(push.cast_id)+":"+enemy.actor_id) or collision_pairs.has(str(push.cast_id)+":"+other.actor_id)): continue
   collision_pairs[pair_key]=true
   collision_pairs[str(push.cast_id)+":"+enemy.actor_id]=true
   collision_pairs[str(push.cast_id)+":"+other.actor_id]=true
   push.hits.append(other.actor_id)
   var decay: float=pow(1.0-hf("body_weapon",2),push.count) if hx("body_weapon") else 1.0
   var amount: float=push.collision_damage*decay
   push.count+=1
   damage_enemy(enemy,amount,"q3_collision",push.cast_id)
   damage_enemy(other,amount,"q3_collision",push.cast_id)
   if enemy.kind!="boss": enemy.stun_left=maxf(enemy.stun_left,push.collision_stun*decay)
   if other.kind!="boss": other.stun_left=maxf(other.stun_left,push.collision_stun*decay)
   emit_event("enemy_collision",{"position":enemy.position,"other":other.actor_id,"amount":amount,"count":push.count})
 push.left-=dt
 if push.left<=TIME_EPS or blocked: enemy.push={}
func _step_enemy(enemy: Dictionary,dt: float) -> void:
 var base_damage: float=enemy.damage
 enemy.damage=base_damage*float(enemy.get("common_damage_multiplier",1.0))
 enemy_director.step_enemy(self,enemy,dt)
 enemy.damage=base_damage

func _step_projectiles(dt: float) -> void:
 enemy_director.step_projectiles(self,dt)

func _step_zones(dt: float) -> void:
 _common_zone_tick=true
 enemy_director.step_hostile_zones(self,dt)
 _common_zone_tick=false
 for zone in zones.duplicate():
  if zone.get("team","hero")!="hero": continue
  for target in circle_targets(zone.position,zone.radius):
   var key="zone:%d:%s"%[zone.cast_id,target.actor_id]
   if target.actor_id==zone.exclude or collision_pairs.has(key): continue
   collision_pairs[key]=true
   damage_enemy(target,zone.damage,"hex_wall_kill",zone.cast_id)
  zone.left-=dt
  if zone.left<=0: zones.erase(zone)

func _sync_loadout_from_ledger() -> void:
 var slots: Dictionary=progression.snapshot().slots
 for pair in [["Q","q"],["E","e"],["R","r"],["P","passive"]]:
  hero.loadout[pair[1]]=slots[pair[0]].skill.to_lower()
  hero.ranks[pair[1]]=slots[pair[0]].rank
func learn_ability(slot: String,candidate: String) -> Dictionary:
 var result: Dictionary=progression.invest(slot,candidate)
 if result.ok: _sync_loadout_from_ledger()
 return result
func undo_new_investment() -> Dictionary:
 var result: Dictionary=progression.undo_last_investment()
 if result.ok: _sync_loadout_from_ledger()
 return result
func reset_at_training() -> Dictionary:
 var result: Dictionary=progression.reset_at_training()
 if result.ok: _sync_loadout_from_ledger()
 return result
func configure_test_loadout(preset: Dictionary) -> Dictionary:
 if clock.world_time>0: return {"ok":false,"reason":"not_new_fixture"}
 progression.set_level(18)
 progression.set_training_node(true)
 progression.reset_at_training()
 for pair in [["Q","q"],["E","e"],["R","r"],["P","passive"]]:
  var candidate: String=preset.get(pair[1],"")
  if candidate.is_empty(): continue
  for _i in range(4 if pair[0] in ["P","R"] else 6): progression.invest(pair[0],candidate.to_upper())
 _sync_loadout_from_ledger()
 return {"ok":true,"test_fixture":true,"spent":progression.snapshot().spent}
func set_projected_stats(projected: Dictionary) -> void:
 common.set_projected(projected)
func set_common_model(model: RefCounted) -> void:
 common.bind_model(model)
func configure_common_hexes(options: Dictionary) -> void:
 common.configure(options)
func set_common_context(values: Dictionary) -> void:
 common.context_values.merge(values,true)
 common.refresh_stats()
func common_snapshot() -> Dictionary:
 return common.runtime.snapshot()
func potion_used(item_id: String) -> void:
 common.potion_used(item_id)
func _common_true_death() -> void:
 if hero.dead: return
 hero.dead=true
 hero.death_state="true_dead"
 common.runtime.hero_died(true)
 end_encounter("true_dead")

# Cooperative mechanics are part of the simulation contract, independent of transport.
# Each registered ally is a live actor with actor_id, position, hp, stats, shields and dead.
func register_ally(actor: RefCounted) -> void:
 if actor!=hero and actor not in allies: allies.append(actor)
func _issue_aura_shields() -> void:
 if not hero.cast_state.has("e3"): return
 var state: Dictionary=hero.cast_state.e3
 # Fractional ultimate-slow ticks can cross zero before entry detection.
 # Negative shield lifetime means permanent elsewhere, so expired casts issue nothing.
 if float(state.left)<=TIME_EPS:return
 for actor in [hero]+allies:
  if actor.dead or actor.actor_id in state.entered: continue
  if actor.position.distance_to(hero.position)>state.radius: continue
  state.entered.append(actor.actor_id)
  var amount: float=hero.stats.max_hp*f("E3-3",state.rank)*(v("E3-4",state.rank) if actor==hero else 1.0)
  # The per-cast shield ends naturally with the field's original duration.
  var shield_id: String="e3:%s:%d"%[hero.actor_id,state.cast_id]
  actor.shields[shield_id]=common.shield_metadata("e3",amount,state.left,{"source_cast":state.cast_id})
  emit_event("shield",{"target":actor.actor_id,"source":"e3","amount":amount,"initial_amount":amount,"owner_id":hero.actor_id,"duration":state.left,"cast_id":state.cast_id})
func damage_ally(actor: RefCounted,amount: float,is_true: bool=false) -> void:
 if phase!="combat" or paused or actor.dead or actor not in allies: return
 var packet: float=maxf(0,amount)*(1.0 if is_true else 100.0/(100.0+maxf(0,actor.defence())))
 for id in actor.shields.keys():
  var absorbed: float=minf(actor.shields[id].amount,packet)
  actor.shields[id].amount-=absorbed
  packet-=absorbed
  common.absorbed(actor,actor.shields[id],absorbed)
  if actor.shields[id].amount<=TIME_EPS: actor.shields.erase(id)
  if packet<=0: break
 var rescued: bool=false
 if actor.hp-packet<=0 and hx("comrades") and hero.cast_state.has("e3"):
  var state: Dictionary=hero.cast_state.e3
  if actor.position.distance_to(hero.position)<=state.radius and state.saves<int(hv("comrades",3)):
   state.saves+=1
   actor.hp=hv("comrades")
   rescued=true
   emit_event("comrades_rescue",{"target":actor.actor_id,"position":actor.position,"cast_id":state.cast_id})
   damage_hero(actor.stats.max_hp*hf("comrades",2),Vector3.ZERO,0,true,true)
 if not rescued: actor.hp=maxf(0,actor.hp-packet)
 if actor.hp<=0: actor.dead=true
 common.drain()

func status_effects() -> Array:
 var result: Array=common.status_effects()
 if hero.bone_stacks>0: result.append({"id":"bone","name":"城骨","kind":"buff","stacks":hero.bone_stacks,"remaining":-1.0,"description":"每层提高防御，战斗结束清空"})
 if retaliation_left>0: result.append({"id":"retaliation","name":"反震重击","kind":"buff","stacks":1,"remaining":-1.0,"description":"下一次普攻附加伤害并恢复已损生命"})
 if hero.cast_state.has("e1"): result.append({"id":"guard","name":"镇门","kind":"buff","stacks":1,"remaining":hero.cast_state.e1.left,"description":"正面减伤；松开E顶出城门"})
 if hero.cast_state.has("e3"): result.append({"id":"aura","name":"合垒","kind":"buff","stacks":1,"remaining":hero.cast_state.e3.left,"description":"每名友方每次施法入阵获盾一次；离阵保留至本次防御阵自然结束，重入不刷新"})
 if hero.cast_state.has("r1"): result.append({"id":"fortress","name":"背城","kind":"buff","stacks":int(hero.cast_state.r1.pressure),"remaining":hero.cast_state.r1.left,"description":"最终减伤并记录减伤前承伤为城压；再次R释放"})
 if hero.cast_state.has("r2"): result.append({"id":"rams","name":"叩关","kind":"buff","stacks":hero.cast_state.r2.maximum-hero.cast_state.r2.count,"remaining":hero.cast_state.r2.left,"description":"按R沿鼠标方向冲锋；只在单次冲锋中锁定自由移动"})
 if hero.cast_state.has("exposed"): result.append({"id":"exposed","name":"咒针易伤","kind":"debuff","stacks":1,"remaining":hero.cast_state.exposed.left,"description":"受到的伤害提高20%"})
 if hero.slow_left>0: result.append({"id":"slow","name":"减速","kind":"debuff","stacks":1,"remaining":hero.slow_left,"description":"移动速度降低"})
 for id in hero.shields:
  var shield: Dictionary=hero.shields[id]
  result.append({"id":id,"name":"合垒护盾" if str(id).begins_with("e3:") else "护盾","kind":"buff","stacks":0,"remaining":shield.left,"description":"剩余护盾 %.0f"%shield.amount})
 return result

func _retaliation_payload()->Dictionary:
 var active:bool=retaliation_left>0 and hero.loadout.passive=="p2" and hero.ranks.passive>0
 return {"active":active,"damage":v("P2-3",hero.ranks.passive)+hero.ad()*f("P2-4",hero.ranks.passive) if active else 0.0,"heal_fraction":f("P2-5",hero.ranks.passive) if active else 0.0}
func _consume_retaliation(payload:Dictionary)->void:
 if not payload.active:return
 retaliation_left=0
 heal((hero.stats.max_hp-hero.hp)*payload.heal_fraction,false,{"source":"p2_retaliation"})
