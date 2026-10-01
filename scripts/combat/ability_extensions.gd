extends RefCounted
## Optional-slot mechanics. All spatial/duration choices in INITIAL are TEST INITIALS.
## Flat arena clamp is the current legal landing policy; internal wall sweep awaits geometry.
const T = preload("res://data/combat/tuning.gd")
const A = preload("res://data/combat/ability_tuning.gd")
const INITIAL = A.INITIAL
const POLICIES = A.POLICIES
const TEST_RANK_DAMAGE = A.TEST_RANK_DAMAGE
var s: Node
var _counted_attacks: Dictionary = {}

func _init(sim: Node) -> void:
 s = sim

func _bind_room(state: Dictionary, context: Dictionary) -> void:
 for key in ["encounter_id","encounter_generation","simulation_instance"]: state[key] = context[key]

func _same_room(state: Dictionary) -> bool:
 return state.get("encounter_id","") == s.combat_level_id and state.get("encounter_generation",-1) == s.encounter_generation and state.get("simulation_instance",-1) == s.get_instance_id()

func _q2_current(state: Dictionary) -> bool:
 return s.phase == "combat" and not s.hero.dead and _same_room(state) and s.hero.cast_state.has("q2") and s.hero.cast_state.q2.cast_id == state.cast_id

func _power(slot: String) -> float:
 return TEST_RANK_DAMAGE[slot][clampi(int(s.hero.ranks[slot])-1,0,TEST_RANK_DAMAGE[slot].size()-1)]

func _key() -> String:
 return s.hero.actor_id + ":r2"

func blocks_actions() -> bool:
 return s.hero.cast_state.has("q2") or s.hero.cast_state.has("e2") or _r2_showing()

func blocks_movement() -> bool:
 return s.hero.cast_state.has("q2") or _r2_showing()

func is_immune() -> bool:
 return s.phase == "combat" and (s.hero.cast_state.has("q2") or _r2_showing())

func _r2_showing() -> bool:
 return s.hero.cast_state.has("r2") and bool(s.hero.cast_state.r2.get("presenting", false))

func _ok(context: Dictionary) -> Dictionary:
 s.revision += 1
 s._check_victory()
 return {"accepted":true,"reason":"ok","cast_id":context.cast_id,"state_revision":s.revision}

func _no(reason: String) -> Dictionary:
 return {"accepted":false,"reason":reason}

func request(action: String, context: Dictionary) -> Dictionary:
 if s.phase != "combat" or s.hero.dead: return _no("encounter_frozen")
 if blocks_actions(): return _no("action_locked")
 if not action in ["q","e","r"]: return _no("unknown_action")
 if s.hero.ranks[action] <= 0: return _no("unlearned")
 if s.hero.cooldowns[action] > 0: return _no("cooldown")
 var skill: String = s.hero.loadout[action]
 match skill:
  "q2":
   var target: Dictionary = _pick(s.hero.position, INITIAL.q2_initial_range, [], s.hero.aim_point)
   if target.is_empty(): return _no("no_target")
   s.hero.cast_state.q2 = {"cast_id":context.cast_id,"damage":s.hero.ad()*1.5*_power("q"),"visited":[],"next":s.clock.world_time+INITIAL.q2_interval,"target":target.actor_id,"search_center":s.hero.position,"search_range":INITIAL.q2_initial_range,"last_position":s.hero.position,"landing":s.hero.position}
   _bind_room(s.hero.cast_state.q2,context)
   s.hero.untargetable = true
   s.emit_event("q2_started", {"cast_id":context.cast_id,"target":target.actor_id})
  "q3":
   var damage: float = s.hero.ad()*0.8*_power("q")
   for target in s.rectangle_targets(context.origin,context.direction,INITIAL.q3_length,INITIAL.q3_width):
    s.damage_enemy(target,damage,"q3",context.cast_id)
    s.knock_enemy(target,context.direction,INITIAL.q3_impulse)
   s.start_skill_cooldown("q",11.0)
   s.emit_event("q3_wave", {"cast_id":context.cast_id,"position":context.origin,"direction":context.direction,"length":INITIAL.q3_length,"width":INITIAL.q3_width})
  "e1":
   if s.hero.cast_state.has("e1"):
    if not _same_room(s.hero.cast_state.e1):
     _finish_e1()
     return _no("mark_target_dead")
    if s.hero.cast_state.e1.stage != "marked": return _no("projectile_in_flight")
    if s.clock.world_time >= s.hero.cast_state.e1.expires: return _no("mark_expired")
    var target: Dictionary = s.enemy_by_id(s.hero.cast_state.e1.target)
    if target.is_empty() or target.dead:
     return _no("mark_target_dead")
    var destination: Vector3 = target.position + (s.hero.aim_point-target.position).limit_length(INITIAL.e1_recast_radius)
    destination = s.clamp_position(destination,T.INITIAL.player_radius)
    var origin: Vector3 = s.hero.position
    var delta: Vector3 = destination-origin
    var direction: Vector3 = delta.normalized() if delta.length_squared()>0.000001 else s.hero.facing
    var damage: float = s.hero.ad()*0.5*_power("e")
    for victim in s.rectangle_targets(origin,direction,delta.length(),INITIAL.e1_width):
     s.damage_enemy(victim,damage,"e1_pierce",context.cast_id)
    s.hero.position = destination
    _finish_e1()
    s.emit_event("e1_pierce", {"cast_id":context.cast_id,"position":destination,"origin":origin})
   else:
    var target: Dictionary = _pick(s.hero.position,INITIAL.e1_range,[],s.hero.aim_point)
    if target.is_empty(): return _no("no_target")
    s.hero.cast_state.e1 = {"stage":"flying","target":target.actor_id,"position":s.hero.position,"deadline":s.clock.world_time+INITIAL.e1_timeout,"damage":s.hero.ad()*1.5*_power("e"),"cast_id":context.cast_id}
    _bind_room(s.hero.cast_state.e1,context)
    s.emit_event("e1_projectile", {"cast_id":context.cast_id,"target":target.actor_id})
  "e2":
   var damage: float = s.hero.ad()*0.7*_power("e")
   s.hero.cast_state.e2 = {"cast_id":context.cast_id,"until":s.clock.world_time+INITIAL.e2_spin,"pointer":s.hero.aim_point}
   for target in s.circle_targets(s.hero.position,INITIAL.e2_radius): s.damage_enemy(target,damage,"e2_spin",context.cast_id)
   s.emit_event("e2_spin", {"cast_id":context.cast_id,"position":s.hero.position,"radius":INITIAL.e2_radius})
  "r2":
   if s.hero.cast_state.has("r2"):
    var state: Dictionary = s.hero.cast_state.r2
    if state.round >= 3: return _no("all_rounds_used")
    if s.clock.world_time >= state.expires:
     return _no("recast_window_expired")
   else:
    _counted_attacks.clear()
    s.hero.cast_state.r2 = {"round":0,"attacks":0,"expires":0.0,"presenting":false,"last_nails":0}
   _throw_r2(context)
  _:
   return _no("candidate_not_implemented")
 return _ok(context)

func _pick(center: Vector3, radius: float, excluded: Array, preference: Vector3) -> Dictionary:
 var best: Dictionary = {}
 var best_distance: float = INF
 for target in s.living():
  if target.actor_id in excluded or target.position.distance_to(center)>radius: continue
  var distance: float = target.position.distance_squared_to(preference)
  if distance < best_distance or (is_equal_approx(distance,best_distance) and (best.is_empty() or target.actor_id < best.actor_id)):
   best=target
   best_distance=distance
 return best

func step(dt: float) -> void:
 if s.phase != "combat" or s.hero.dead: return
 if s.hero.cast_state.has("q2"):
  s.hero.untargetable = true
  _step_q2()
  s._check_victory()
  if s.phase != "combat": return
 if s.hero.cast_state.has("e1"):
  _step_e1(dt)
  s._check_victory()
  if s.phase != "combat": return
 if s.hero.cast_state.has("e2") and s.clock.world_time+0.000001 >= s.hero.cast_state.e2.until:
  var state: Dictionary = s.hero.cast_state.e2
  var destination: Vector3 = s.hero.position+(state.pointer-s.hero.position).limit_length(INITIAL.e2_blink)
  s.hero.position = s.clamp_position(destination,T.INITIAL.player_radius)
  if not s.circle_targets(s.hero.position,INITIAL.e2_landing_radius).is_empty(): s.hero.invulnerable_left=maxf(s.hero.invulnerable_left,1.0)
  s.hero.cast_state.erase("e2")
  s.start_skill_cooldown("e",17.0)
  s.emit_event("e2_blink",{"cast_id":state.cast_id,"position":s.hero.position,"invulnerable":s.hero.invulnerable_left>0})
 if s.hero.cast_state.has("r2"):
  var state: Dictionary=s.hero.cast_state.r2
  if state.presenting and not s.clock.presenters.has(_key()):
   state.presenting=false
   s.emit_event("r2_presentation_finished")
   if state.round>=3: _finish_r2()
  if s.hero.cast_state.has("r2") and s.clock.world_time+0.000001>=state.expires: _finish_r2()

func _step_q2() -> void:
 if s.phase != "combat" or s.hero.dead or not s.hero.cast_state.has("q2"): return
 var state: Dictionary=s.hero.cast_state.q2
 if not _same_room(state):
  _finish_q2(false)
  return
 if s.clock.world_time+0.000001<state.next: return
 var target: Dictionary=s.enemy_by_id(state.target)
 if target.is_empty() or target.dead or target.position.distance_to(state.search_center)>state.search_range:
  target=_pick(state.search_center,state.search_range,state.visited,state.search_center)
 if target.is_empty():
  _finish_q2()
  return
 state.visited.append(target.actor_id)
 state.last_position=target.position
 var behind: Vector3=target.aim
 if behind.length_squared()<0.000001: behind=s.hero.facing
 state.landing=s.clamp_position(target.position-behind.normalized()*INITIAL.q2_behind,T.INITIAL.player_radius)
 s.hero.position=state.landing
 s.damage_enemy(target,state.damage,"q2",state.cast_id)
 if not _q2_current(state): return
 s.emit_event("q2_hit",{"cast_id":state.cast_id,"target":target.actor_id,"position":s.hero.position,"strike":state.visited.size()})
 if not _q2_current(state): return
 var next: Dictionary=_pick(state.last_position,INITIAL.q2_chain_range,state.visited,state.last_position)
 if state.visited.size()>=4 or next.is_empty():
  _finish_q2()
 else:
  state.target=next.actor_id
  state.search_center=state.last_position
  state.search_range=INITIAL.q2_chain_range
  state.next+=INITIAL.q2_interval

func _finish_q2(restore_landing: bool = true) -> void:
 if not s.hero.cast_state.has("q2"): return
 var state: Dictionary=s.hero.cast_state.q2
 if restore_landing: s.hero.position=state.landing
 s.hero.cast_state.erase("q2")
 s.hero.untargetable=false
 s.start_skill_cooldown("q",12.0)
 s.emit_event("q2_finished",{"hits":state.visited.size(),"position":s.hero.position})

func _step_e1(dt: float) -> void:
 if s.phase != "combat" or s.hero.dead or not s.hero.cast_state.has("e1"): return
 var state: Dictionary=s.hero.cast_state.e1
 if not _same_room(state):
  _finish_e1()
  return
 var target: Dictionary=s.enemy_by_id(state.target)
 if target.is_empty() or target.dead:
  _finish_e1()
  return
 if state.stage=="marked":
  if s.clock.world_time+0.000001>=state.expires: _finish_e1()
  return
 if s.clock.world_time+0.000001>=state.deadline:
  _finish_e1()
  return
 state.position=state.position.move_toward(target.position,INITIAL.e1_speed*dt)
 if state.position.distance_to(target.position)<=target.radius:
  s.damage_enemy(target,state.damage,"e1_dagger",state.cast_id)
  if s.phase != "combat" or not _same_room(state) or not s.hero.cast_state.has("e1") or s.hero.cast_state.e1.cast_id != state.cast_id: return
  if target.dead:
   _finish_e1()
  else:
   state.stage="marked"
   state.expires=s.clock.world_time+5.0
   s.emit_event("e1_marked",{"target":target.actor_id,"duration":5.0})

func _finish_e1() -> void:
 s.hero.cast_state.erase("e1")
 s.start_skill_cooldown("e",18.0)
 s.emit_event("e1_finished")

func _throw_r2(context: Dictionary) -> void:
 var state: Dictionary=s.hero.cast_state.r2
 state.round+=1
 var count: int=1 if state.round==1 else 1+int(state.attacks)
 state.last_nails=count
 state.expires=s.clock.world_time+3.0
 state.presenting=true
 s.clock.enter(_key(),INITIAL.r2_show_real)
 var damage: float=s.hero.ad()*0.5*_power("r")
 # No arbitrary cap: each nail is an ordinary packet, no boss percentage override.
 var targets: Array=s.rectangle_targets(context.origin,context.direction,INITIAL.r2_length,INITIAL.r2_width)
 for target in targets:
  for nail in range(count):
   if target.dead: break
   s.damage_enemy(target,damage+float(target.max_hp)*0.0025,"r2",context.cast_id)
  if not target.dead:
   if target.kind=="boss":
    # One nonstacking control application per throw; TEST INITIAL conversion.
    target.stagger+=INITIAL.r2_boss_stagger
    if target.stagger>=1.0:
     target.stagger=0.0
     target.stun_left=maxf(float(target.stun_left),INITIAL.r2_boss_stun)
     target.state="recover"
     target.timer=INITIAL.r2_boss_stun
   else:
    target.slow_amount=maxf(float(target.slow_amount) if target.slow_left>0 else 0.0,0.3)
    target.slow_left=maxf(float(target.slow_left),3.0)
 s.emit_event("r2_throw",{"cast_id":context.cast_id,"round":state.round,"nails":count,"attacks":state.attacks,"position":context.origin,"direction":context.direction,"length":INITIAL.r2_length,"width":INITIAL.r2_width})

func on_basic_attack_completed(event: Dictionary) -> void:
 if s.phase!="combat" or not _same_room(event) or not s.hero.cast_state.has("r2"): return
 var state: Dictionary=s.hero.cast_state.r2
 if state.round>=3 or s.clock.world_time>=state.expires: return
 var id: int=int(event.get("cast_id",-1))
 if id<0 or _counted_attacks.has(id): return
 _counted_attacks[id]=true
 state.attacks+=1

func _finish_r2() -> void:
 s.clock.leave(_key())
 s.hero.cast_state.erase("r2")
 _counted_attacks.clear()
 s.start_skill_cooldown("r",130.0)
 s.emit_event("r2_finished")

func on_encounter_end() -> void:
 # Called before the host captures terminal snapshot. No timer advancement here.
 s.clock.leave(_key())
 if s.hero.cast_state.has("q2"): _finish_q2()
 if s.hero.cast_state.has("r2"):
  s.hero.cast_state.r2.presenting=false
  if s.hero.cast_state.r2.round>=3: _finish_r2()

func on_room_change() -> void:
 # Targeted chains/projectiles cannot select from the replacement enemy roster.
 # E2 blink, E3 buff and R2 unused throws keep their established freeze policy.
 if s.hero.cast_state.has("q2"): _finish_q2(false)
 if s.hero.cast_state.has("e1"): _finish_e1()
