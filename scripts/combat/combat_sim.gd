extends Node
## Single authoritative simulation. Views consume detached snapshots/events only.
signal combat_event(event: Dictionary)
signal encounter_finished(result: Dictionary)
signal state_changed(snapshot: Dictionary)
const T = preload("res://data/combat/tuning.gd")
const Hero = preload("res://scripts/actors/fengli_model.gd")
const Clock = preload("res://scripts/combat/world_clock.gd")
const Ledger = preload("res://scripts/combat/loadout_fixture.gd")
const Extensions = preload("res://scripts/combat/ability_extensions.gd")
var hero = Hero.new()
var progression = Ledger.new()
var extensions = Extensions.new(self)
var clock = Clock.new()
var phase: String = "combat"
var combat_level_id: String = "training-01"
var enemies: Array = []
var pending: Array = []
var encounter_generation: int = 0
var active_r1_cast: int = -1
var event_log: Array = []
var sequence: int = 0
var cast_serial: int = 0
var enemy_serial: int = 0
var revision: int = 0
var auto_finish: bool = true
var ai_enabled: bool = true
var rng = RandomNumberGenerator.new()
var seen_commands: Dictionary = {}
var r1_active: bool = false
var r1_world_remaining: float = 0.0
var frozen_snapshot: Dictionary = {}
var real_accumulator: float = 0.0
var transaction_active: bool = false
const FIXED_TICK: float = 0.005

func _init() -> void:
 rng.seed = 20260930
 # Explicit level-6 test fixture, not a normal new-run progression grant.
 progression.set_level(6)
 for item in [["Q","Q1"],["E","E3"],["R","R1"],["P","P3"]]: progression.invest(item[0],item[1])
 progression.begin_encounter()

func emit_event(kind: String, data: Dictionary = {}) -> void:
 sequence += 1
 var event: Dictionary = data.duplicate(true)
 event.merge({"kind":kind,"sequence":sequence,"world_time":clock.world_time,"combat_level_id":combat_level_id})
 event_log.append(event)
 if event_log.size() > 200: event_log.pop_front()
 combat_event.emit(event.duplicate(true))

func snapshot() -> Dictionary:
 var hero_state: Dictionary = hero.snapshot()
 hero_state.invulnerable = hero_state.invulnerable or r1_active or extensions.is_immune()
 return {"definition_version":T.VERSION,"phase":phase,"combat_level_id":combat_level_id,
 "world_time":clock.world_time,"world_scale":clock.scale_factor(),"revision":revision,
 "hero":hero_state,"enemies":enemies.duplicate(true),"pending":pending.duplicate(true),"event_sequence":sequence,"progression":progression.snapshot()}

func spawn_enemy(kind: String, at: Vector3, hp_override: float = -1.0) -> Dictionary:
 assert(kind in ["minion","elite","boss"])
 enemy_serial += 1
 var health: float = T.INITIAL[kind + "_hp"] if hp_override < 0 else hp_override
 var enemy: Dictionary = {"actor_id":"enemy_%d" % enemy_serial,"kind":kind,"position":at,
 "hp":health,"max_hp":health,"defence":0.0,"radius":0.5 if kind == "minion" else (0.75 if kind == "elite" else 1.15),
 "state":"chase","timer":0.5 + enemy_serial * 0.12,"aim":Vector3.FORWARD,"target_point":at,
 "knockback":Vector3.ZERO,"stun_left":0.0,"slow_left":0.0,"slow_amount":0.0,"stagger":0.0,
 "attack_index":0,"warning_progress":0.0,"attack_shape":"circle","dead":false}
 enemies.append(enemy)
 emit_event("enemy_spawned", {"actor_id":enemy.actor_id,"enemy_kind":kind})
 return enemy

func enemy_by_id(id: String) -> Dictionary:
 for enemy in enemies:
  if enemy.actor_id == id: return enemy
 return {}

func living() -> Array:
 return enemies.filter(func(e): return not e.dead)

func request_action(action: String, aim: Vector3 = Vector3.INF, command_id: String = "") -> Dictionary:
 if transaction_active: return {"accepted":false,"reason":"transaction_in_progress"}
 if not command_id.is_empty() and seen_commands.has(command_id): return seen_commands[command_id].duplicate(true)
 var prior_aim: Vector3 = hero.aim_point
 var prior_facing: Vector3 = hero.facing
 var prior_serial: int = cast_serial
 transaction_active = true
 var result: Dictionary = _request_action(action, aim)
 transaction_active = false
 if not result.accepted:
  hero.aim_point = prior_aim
  hero.facing = prior_facing
  cast_serial = prior_serial
 if not command_id.is_empty(): seen_commands[command_id] = result.duplicate(true)
 return result

func _request_action(action: String, aim: Vector3) -> Dictionary:
 if phase != "combat": return {"accepted":false,"reason":"encounter_frozen"}
 if hero.dead: return {"accepted":false,"reason":"not_alive"}
 if not action in ["attack","shift","q","e","r"]: return {"accepted":false,"reason":"unknown_action"}
 if hero.cooldowns[action] > 0: return {"accepted":false,"reason":"cooldown"}
 if hero.lock_time > 0 or hero.dash_left > 0 or hero.stun_left > 0 or r1_active or extensions.blocks_actions():
  return {"accepted":false,"reason":"action_locked"}
 if action in ["q","e","r"] and hero.ranks[action] == 0: return {"accepted":false,"reason":"unlearned"}
 # Conservative adapter policy: a retained old-slot effect must finish before
 # a newly selected candidate can begin; respec never grants concurrent E/R states.
 var retained: String = ""
 if action == "e":
  if hero.overload_left > 0: retained = "e3"
  elif hero.cast_state.has("e1"): retained = "e1"
  elif hero.cast_state.has("e2"): retained = "e2"
 elif action == "r" and hero.cast_state.has("r2"): retained = "r2"
 if retained != "" and hero.loadout[action] != retained: return {"accepted":false,"reason":"previous_candidate_active"}
 if aim.is_finite():
  hero.aim_point = aim
  var direction: Vector3 = aim - hero.position
  direction.y = 0
  if direction.length_squared() > 0.001: hero.facing = direction.normalized()
 cast_serial += 1
 var context: Dictionary = {"cast_id":cast_serial,"action":action,"origin":hero.position,"direction":hero.facing,
 "hits":[],"kills":[],"due":clock.world_time,"kind":action,
 "encounter_id":combat_level_id,"encounter_generation":encounter_generation,"simulation_instance":get_instance_id()}
 match action:
  "shift":
   hero.dash_direction = hero.move_intent.normalized() if hero.move_intent.length_squared() > 0.01 else hero.facing
   hero.dash_left = T.INITIAL.dash_duration
   hero.cooldowns.shift = T.cooldown(T.INITIAL.dash_cd, hero.stats.cdr) * (T.CONFIRMED.e3_dash_factor if hero.overload_left > 0 else 1.0)
   emit_event("dash", {"position":hero.position,"direction":hero.dash_direction})
  "attack":
   hero.cooldowns.attack = 1.0 / hero.attack_speed()
   hero.lock_time = T.INITIAL.attack_startup
   context.kind = "attack_hit"
   context.due += T.INITIAL.attack_startup
   context.damage = hero.ad() * T.INITIAL.attack_ad
   context.critical = rng.randf() < clampf(hero.stats.crit_chance, 0.0, 1.0)
   if context.critical: context.damage *= T.INITIAL.crit_multiplier
   pending.append(context)
   emit_event("attack_started", {"cast_id":cast_serial,"position":hero.position,"direction":hero.facing})
  "q":
   if hero.loadout.q != "q1": return extensions.request(action,context)
   context.kind = "q1_resolve"
   context.due += T.INITIAL.kill_grace
   var factor: float = 1.0 + hero.q1_stacks * T.CONFIRMED.q1_stack_gain
   var cast_damage: float = hero.ad() * T.ranked("q1_ad",hero.ranks.q) * factor
   var targets: Array = rectangle_targets(hero.position, hero.facing, T.INITIAL.q1_length * factor, T.INITIAL.q1_width)
   for target in targets:
    context.hits.append(target.actor_id)
    if damage_enemy(target, cast_damage, "q1", cast_serial): context.kills.append(target.actor_id)
   # The same cast can never repeat-hit a target or gain multiple stacks from a pack.
   pending.append(context)
   hero.lock_time = T.INITIAL.kill_grace
   emit_event("q1", {"cast_id":cast_serial,"position":hero.position,"direction":hero.facing,"length":T.INITIAL.q1_length * factor,"width":T.INITIAL.q1_width})
  "e":
   if hero.loadout.e != "e3": return extensions.request(action,context)
   if hero.overload_left > 0: return {"accepted":false,"reason":"already_active"}
   hero.overload_left = T.ranked("e3_duration",hero.ranks.e)
   emit_event("overload_started")
  "r":
   if hero.loadout.r != "r1": return extensions.request(action,context)
   r1_active = true
   clock.enter(hero.actor_id, T.INITIAL.r1_show_duration)
   context.damage = hero.ad() * T.ranked("r1_ad",hero.ranks.r)
   active_r1_cast = context.cast_id
   context.kind = "r1_damage"
   context.due += 0.06
   pending.append(context)
   emit_event("ultimate_started", {"position":hero.position,"radius":T.INITIAL.r1_radius,"duration":T.INITIAL.r1_show_duration})
 revision += 1
 _check_victory()
 return {"accepted":true,"reason":"ok","cast_id":cast_serial,"state_revision":revision}

func rectangle_targets(origin: Vector3, direction: Vector3, length: float, width: float) -> Array:
 var result: Array = []
 var side: Vector3 = Vector3(-direction.z, 0, direction.x)
 for enemy in enemies:
  if enemy.dead: continue
  var offset: Vector3 = enemy.position - origin
  var longitudinal: float = offset.dot(direction)
  if longitudinal >= -enemy.radius and longitudinal <= length + enemy.radius and absf(offset.dot(side)) <= width * 0.5 + enemy.radius:
   result.append(enemy)
 return result

func circle_targets(origin: Vector3, radius: float) -> Array:
 return enemies.filter(func(e): return not e.dead and e.position.distance_to(origin) <= radius)

func damage_enemy(enemy: Dictionary, amount: float, source: String, cast_id: int, is_true: bool = false, critical: bool = false) -> bool:
 if phase != "combat" or enemy.dead: return false
 var value: float = T.damage(amount, enemy.defence, hero.stats.penetration, is_true)
 var actual: float = minf(enemy.hp, value)
 enemy.hp = maxf(0.0, enemy.hp - value)
 emit_event("damage", {"target":enemy.actor_id,"position":enemy.position,"amount":actual,"damage_type":"true" if is_true else "ordinary","source":source,"cast_id":cast_id,"critical":critical})
 if source == "attack" and not is_true:
  var leech: float = hero.stats.lifesteal
  if hero.loadout.passive == "p1" and hero.ranks.passive > 0: leech += T.ranked("p1_leech",hero.ranks.passive)
  hero.hp = minf(hero.stats.max_hp, hero.hp + actual * leech * T.INITIAL.area_leech)
 if enemy.hp <= 0:
  enemy.dead = true
  enemy.state = "dead"
  enemy.knockback = Vector3.ZERO
  emit_event("kill", {"target":enemy.actor_id,"position":enemy.position,"source":source,"cast_id":cast_id,"credit":"solo_lethal"})
  if hero.overload_left > 0: hero.overload_left += T.CONFIRMED.e3_kill_extension
  if hero.loadout.passive == "p3" and hero.ranks.passive > 0:
   hero.kill_progress += 1
   var threshold: int = T.CONFIRMED.p3_thresholds[hero.ranks.passive - 1]
   while hero.kill_progress >= threshold:
    hero.kill_progress -= threshold
    hero.permanent_ad += 1.0
    emit_event("permanent_ad_gained", {"ad":hero.ad()})
  return true
 return false

func damage_hero(amount: float, direction: Vector3 = Vector3.ZERO, control: float = 0.0) -> void:
 if phase != "combat" or hero.dead or hero.invulnerable_left > 0 or r1_active or extensions.is_immune(): return
 var old_hp: float = hero.hp
 hero.hp = maxf(0, hero.hp - T.damage(amount, hero.stats.defence, 0.0))
 hero.stun_left = maxf(hero.stun_left, T.control_duration(control, hero.tenacity()))
 hero.knockback += direction * 3.0
 emit_event("hero_damaged", {"amount":old_hp-hero.hp,"position":hero.position})
 if hero.hp > 0 and old_hp >= hero.stats.max_hp * 0.1 and hero.hp < hero.stats.max_hp * 0.1 and hero.loadout.passive == "p2" and hero.ranks.passive > 0 and hero.cooldowns.passive <= 0:
  _trigger_low_health_passive()
 if hero.hp <= 0:
  hero.dead = true
  hero.death_state = "downed" if not hero.self_rescue_used else "true_dead"
  clock.leave(hero.actor_id)
  r1_active = false
  hero.invulnerable_left = 0
  if hero.death_state == "true_dead": hero.xp_progress *= 0.7
  end_encounter(hero.death_state)

func _trigger_low_health_passive() -> void:
 for slot in ["q","e"]:
  hero.cooldowns[slot] = 0.0
  var active: bool = hero.overload_left > 0 if slot == "e" else false
  for key in hero.cast_state:
   if key.begins_with(slot) and hero.cast_state[key] is Dictionary and not hero.cast_state[key].is_empty(): active = true
  for event in pending:
   if event.action == slot: active = true
  if active: hero.cast_state[slot + "_reset_credit"] = true
 hero.hp = minf(hero.stats.max_hp,hero.hp+hero.stats.max_hp*T.ranked("p2_heal",hero.ranks.passive))
 hero.cooldowns.passive = T.cooldown(T.ranked("p2_cd",hero.ranks.passive),hero.stats.cdr)
 emit_event("low_health_passive", {"policy":"active_cast_finishes_then_skips_next_cooldown"})

func start_skill_cooldown(slot: String, base: float) -> void:
 var key: String = slot + "_reset_credit"
 if hero.cast_state.get(key,false):
  hero.cast_state.erase(key)
  hero.cooldowns[slot] = 0.0
 else: hero.cooldowns[slot] = T.cooldown(base,hero.stats.cdr)

func self_rescue() -> bool:
 if hero.death_state != "downed" or hero.self_rescue_used: return false
 # Explicit test timing: user-triggered rescue, 35% HP, same frozen cooldowns/states.
 hero.self_rescue_used = true
 hero.death_state = "alive"
 hero.dead = false
 hero.hp = hero.stats.max_hp * 0.35
 phase = "combat"
 if not progression.snapshot().in_combat: progression.begin_encounter()
 hero.invulnerable_left = 1.0
 emit_event("self_rescue", {"provenance":"test_initial"})
 return true

func knock_enemy(enemy: Dictionary, direction: Vector3, strength: float) -> void:
 if enemy.dead: return
 if enemy.kind == "boss":
  enemy.stagger += strength * 0.12 # test conversion; no hidden damage reduction
  if enemy.stagger >= 1.0:
   enemy.stagger = 0.0
   enemy.stun_left = 0.65
   enemy.state = "recover"
   enemy.timer = 0.65
  return
 enemy.knockback += direction * strength

func step(real_delta: float) -> void:
 if phase != "combat": return
 _check_victory()
 if phase != "combat": return
 real_accumulator += maxf(0.0, real_delta)
 while real_accumulator + 0.00000001 >= FIXED_TICK and phase == "combat":
  real_accumulator = maxf(0.0, real_accumulator - FIXED_TICK)
  transaction_active = true
  _fixed_step(FIXED_TICK)
  transaction_active = false
 state_changed.emit(snapshot())

func _fixed_step(real_delta: float) -> void:
 if phase != "combat": return
 var dt: float = clock.step(maxf(0.0, real_delta), true)
 for key in hero.cooldowns:
  hero.cooldowns[key] = T.countdown(hero.cooldowns[key],dt)
 if r1_active and not clock.presenters.has(hero.actor_id):
  r1_active = false
  start_skill_cooldown("r",T.ranked("r1_cd",hero.ranks.r))
  emit_event("ultimate_finished")
 hero.lock_time = T.countdown(hero.lock_time,dt)
 hero.stun_left = maxf(0.0, hero.stun_left - dt)
 hero.invulnerable_left = T.countdown(hero.invulnerable_left,dt)
 hero.slow_left = maxf(0.0, hero.slow_left - dt)
 if hero.overload_left > 0:
  var before: float = hero.overload_left
  hero.overload_left = T.countdown(before,dt)
  if hero.overload_left == 0:
   start_skill_cooldown("e",T.ranked("e3_cd",hero.ranks.e))
   hero.cooldowns.e = maxf(0.0, hero.cooldowns.e-maxf(0.0, dt-before))
   emit_event("overload_finished")
 hero.hp = minf(hero.stats.max_hp, hero.hp + hero.stats.regen * dt)
 var velocity: Vector3 = Vector3.ZERO
 if hero.dash_left > 0:
  var dash_dt: float = minf(dt, hero.dash_left)
  hero.position += hero.dash_direction * T.INITIAL.dash_distance / T.INITIAL.dash_duration * dash_dt
  hero.dash_left = T.countdown(hero.dash_left,dt)
 elif hero.lock_time <= 0 and hero.stun_left <= 0 and not r1_active and not extensions.blocks_movement():
  velocity = hero.move_intent.limit_length(1.0) * hero.speed()
 hero.position = clamp_position(hero.position + (velocity + hero.knockback) * dt, T.INITIAL.player_radius)
 hero.knockback = hero.knockback.move_toward(Vector3.ZERO, dt * 18.0)
 var due_events: Array = pending.filter(func(p): return p.due <= clock.world_time + 0.000001)
 for event in due_events:
  pending.erase(event)
  _resolve_pending(event)
  _check_victory()
  if phase != "combat": return
 extensions.step(dt)
 _check_victory()
 if phase != "combat": return
 if ai_enabled:
  for enemy in enemies:
   _step_enemy(enemy, dt)
   if phase != "combat": return
 revision += 1
 _check_victory()

func _resolve_pending(event: Dictionary) -> void:
 # A detached due-list/callback must still belong to this live simulation and room.
 if phase != "combat" or event.get("simulation_instance",-1) != get_instance_id(): return
 if event.get("encounter_id","") != combat_level_id or event.get("encounter_generation",-1) != encounter_generation: return
 if event.kind == "r1_damage":
  if active_r1_cast < 0 or event.cast_id != active_r1_cast: return
  active_r1_cast = -1 # Commit before effects, so repeated/reentrant callbacks cannot hit twice.
 match event.kind:
  "attack_hit":
   var hit: bool = false
   for target in rectangle_targets(event.origin, event.direction, T.INITIAL.attack_range, T.INITIAL.attack_width):
    hit = true
    damage_enemy(target, event.damage, "attack", event.cast_id, false, event.critical)
    if hero.overload_left > 0: damage_enemy(target, event.damage * T.ranked("e3_true",hero.ranks.e), "attack", event.cast_id, true)
    knock_enemy(target, event.direction, 2.2)
   var completed: Dictionary = event.duplicate()
   completed["hit"] = hit
   extensions.on_basic_attack_completed(completed)
   emit_event("attack_completed", {"cast_id":event.cast_id,"hit":hit})
  "q1_resolve":
   if not event.kills.is_empty():
    hero.q1_stacks = mini(T.CONFIRMED.q1_max_stacks, hero.q1_stacks + 1)
    hero.cooldowns.q = 0.0
    hero.cast_state.erase("q_reset_credit")
   else:
    hero.q1_stacks = 0
    start_skill_cooldown("q",T.ranked("q1_cd",hero.ranks.q) * (1.0 - T.CONFIRMED.q1_refund if not event.hits.is_empty() else 1.0))
   emit_event("q1_resolved", {"cast_id":event.cast_id,"hits":event.hits.size(),"kills":event.kills.size(),"stacks":hero.q1_stacks})
  "r1_damage":
   for target in circle_targets(event.origin, T.INITIAL.r1_radius):
    damage_enemy(target, event.damage, "r1", event.cast_id)
    if not target.dead and target.hp / target.max_hp < T.CONFIRMED.r1_execute:
     damage_enemy(target, target.hp, "r1_execute", event.cast_id, true)
   emit_event("ultimate_impact", {"position":event.origin,"radius":T.INITIAL.r1_radius})

func clamp_position(at: Vector3, radius: float = 0.4) -> Vector3:
 var limit: float = T.INITIAL.arena_half_extent - radius
 return Vector3(clampf(at.x, -limit, limit), 0, clampf(at.z, -limit, limit))

func _step_enemy(enemy: Dictionary, dt: float) -> void:
 if enemy.dead: return
 enemy.stun_left = maxf(0.0, enemy.stun_left - dt)
 enemy.slow_left = maxf(0.0, enemy.slow_left - dt)
 enemy.position = clamp_position(enemy.position + enemy.knockback * dt, enemy.radius)
 enemy.knockback = enemy.knockback.move_toward(Vector3.ZERO, 12.0 * dt)
 if enemy.stun_left > 0: return
 enemy.timer = maxf(0.0, enemy.timer - dt)
 var distance: float = enemy.position.distance_to(hero.position)
 var range_value: float = T.INITIAL[enemy.kind + "_range"]
 match enemy.state:
  "chase":
   if not hero.untargetable:
    if distance <= range_value + 0.8 and enemy.timer <= 0:
     enemy.state = "warning"
     enemy.timer = T.INITIAL[enemy.kind + "_warning"]
     enemy.aim = enemy.position.direction_to(hero.position)
     enemy.target_point = hero.position
     enemy.attack_shape = "cone" if enemy.kind == "boss" and enemy.attack_index % 2 == 0 else "circle"
     emit_event("enemy_warning", {"actor_id":enemy.actor_id,"duration":enemy.timer})
    elif distance > 1.0:
     var speed: float = 2.35 if enemy.kind == "minion" else (1.95 if enemy.kind == "elite" else 1.5)
     if enemy.slow_left > 0: speed *= (1.0 - enemy.slow_amount)
     var separation: Vector3 = Vector3.ZERO
     for other in enemies:
      if other == enemy or other.dead: continue
      var away: Vector3 = enemy.position - other.position
      var personal: float = enemy.radius + other.radius + 0.2
      if away.length_squared() > 0.001 and away.length() < personal: separation += away.normalized() * (personal - away.length()) * 2.0
     enemy.position = clamp_position(enemy.position + (enemy.position.direction_to(hero.position) * speed + separation) * dt, enemy.radius)
  "warning":
   enemy.warning_progress = 1.0 - enemy.timer / T.INITIAL[enemy.kind + "_warning"]
   if enemy.timer <= 0:
    var hit: bool = false
    if enemy.attack_shape == "cone":
     var offset: Vector3 = hero.position - enemy.position
     hit = offset.length() <= range_value + T.INITIAL.player_radius and offset.normalized().dot(enemy.aim) >= 0.45
    else:
     hit = hero.position.distance_to(enemy.target_point) <= range_value * 0.65 + T.INITIAL.player_radius
    if hit: damage_hero(T.INITIAL[enemy.kind + "_damage"], enemy.position.direction_to(hero.position), 0.15)
    if phase != "combat": return
    enemy.state = "recover"
    enemy.timer = 1.1 if enemy.kind != "boss" else 1.6
    enemy.attack_index += 1
    emit_event("enemy_impact", {"actor_id":enemy.actor_id,"hit":hit})
  "recover":
   if enemy.timer <= 0: enemy.state = "chase"

func _check_victory() -> void:
 if phase != "combat" or not auto_finish or enemies.is_empty() or not living().is_empty(): return
 # Close attribution grace at room end after the lethal transaction; preserve its earned Q1 stack.
 for event in pending.duplicate():
  if event.kind == "q1_resolve":
   pending.erase(event)
   _resolve_pending(event)
 end_encounter("victory")

func end_encounter(result: String) -> void:
 if phase != "combat": return
 phase = result
 # R1 presentation ends here; its delayed impact is cancelled, never resumed.
 # Other retained buffs and same-room grace state keep their existing freeze policy.
 active_r1_cast = -1
 pending = pending.filter(func(event): return event.kind != "r1_damage")
 real_accumulator = 0.0
 clock.clear()
 extensions.on_encounter_end()
 if result != "downed" and progression.snapshot().in_combat: progression.end_encounter()
 # Presentation is not persisted; all actual HP/CD/buff/charge/stack states stay frozen.
 if r1_active:
  r1_active = false
  start_skill_cooldown("r",T.ranked("r1_cd",hero.ranks.r))
 emit_event("encounter_finished", {"result":result})
 frozen_snapshot = snapshot()
 encounter_finished.emit(frozen_snapshot.duplicate(true))

func learn_ability(slot: String, candidate: String) -> Dictionary:
 var result: Dictionary = progression.invest(slot,candidate)
 if result.ok:
  _sync_loadout_from_ledger()
  revision += 1
  emit_event("skill_invested", {"slot":slot,"candidate":candidate})
 return result

func undo_new_investment() -> Dictionary:
 var result: Dictionary = progression.undo_last_investment()
 if result.ok:
  _sync_loadout_from_ledger()
  revision += 1
 return result

func reset_at_training() -> Dictionary:
 # Keep HP, slot cooldowns, active effects and passive progress intact.
 var result: Dictionary = progression.reset_at_training()
 if result.ok:
  _sync_loadout_from_ledger()
  revision += 1
 return result

func _sync_loadout_from_ledger() -> void:
 var slots: Dictionary = progression.snapshot().slots
 for pair in [["Q","q"],["E","e"],["R","r"],["P","passive"]]:
  hero.loadout[pair[1]] = slots[pair[0]].skill.to_lower()
  hero.ranks[pair[1]] = slots[pair[0]].rank

func configure_test_loadout(preset: Dictionary) -> Dictionary:
 # Only for a completely new arena fixture, never used as a combat respec operation.
 if clock.world_time > 0 or sequence > enemies.size(): return {"ok":false,"reason":"not_new_fixture"}
 progression.end_encounter()
 progression.set_training_node(true)
 progression.reset_at_training()
 for pair in [["Q","q"],["E","e"],["R","r"],["P","passive"]]:
  if preset.has(pair[1]) and preset[pair[1]] != "": progression.invest(pair[0],preset[pair[1]].to_upper())
 progression.begin_encounter()
 _sync_loadout_from_ledger()
 return {"ok":true}

func begin_encounter(next_id: String, roster: Array) -> Dictionary:
 if transaction_active: return {"accepted":false,"reason":"transaction_in_progress"}
 if phase == "combat" or hero.dead: return {"accepted":false,"reason":"invalid_phase"}
 if next_id.is_empty() or next_id == combat_level_id: return {"accepted":false,"reason":"new_level_id_required"}
 extensions.on_room_change()
 encounter_generation += 1
 pending.clear() # Room-targeted callbacks cannot refer to the replacement enemy collection.
 active_r1_cast = -1
 combat_level_id = next_id
 enemies.clear()
 phase = "combat"
 progression.begin_encounter()
 for entry in roster: spawn_enemy(entry.kind,entry.position,entry.get("hp",-1.0))
 emit_event("encounter_started")
 return {"accepted":true,"reason":"ok"}
