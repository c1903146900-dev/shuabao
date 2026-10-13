extends "res://tests/ink_q2_foundation_20261005/fix01/ink_q2_sim.gd"
## Isolated E1/H07/H08 mechanism candidate. No host/catalog capability promotion.
## Shared core, Q1/Q3/BASIC/Shift and one inherited fixed step stay unchanged.
const RainCommonBridge = preload("res://tests/ink_e1_rain_foundation_20261005/rain_common_bridge.gd")
const RainActor = preload("res://tests/ink_e1_rain_foundation_20261005/rain_actor.gd")
var ink_rain: Dictionary = {}
var ink_rain_guard: Dictionary = {}
var ink_e1_marks: Array = []
var ink_e1_receipts: Array = []
var ink_e1_finished: Array = []
var _e1_serial: int = 0
var _e1_tick_active: bool = false
var _e1_tick_start: float = 0.0
var _e1_locomotion: bool = false
var _e1_motion_state: Dictionary = {}
var _e1_paths: Array = []

func _init() -> void:
 super._init()
 # Constructor-only local actor specialization. No live actor replacement or
 # change to shared core/stat ownership; all neutral ActorCore methods inherit.
 var original = hero
 hero = RainActor.new()
 hero.actor_id = original.actor_id
 hero.initialize_stats(original.base_stats)
 hero.position = original.position
 var original_context: Dictionary = common.context_values.duplicate(true)
 common = RainCommonBridge.new(self)
 common.context_values = original_context

func _e1_set_speed_bonus(value: float) -> void:
 if hero.has_method("set_rain_speed_bonus"): hero.set_rain_speed_bonus(value)

func _e1_current(state: Dictionary) -> bool:
 return source_rules_hash == EXPECTED_RULES_HASH and not state.is_empty() and effect_is_current(state) and not hero.dead and is_same(hero, state.owner)
func _e1_form_current() -> bool:
 return _e1_current(ink_rain) and not bool(ink_rain.retired)
func _e1_guard_current() -> bool:
 return _e1_current(ink_rain_guard) and hero_time < float(ink_rain_guard.expires_at) - TIME_EPS

func _request_action(action: String, aim: Vector3) -> Dictionary:
 if action == "ink_e_down": action = "e"
 elif action == "ink_e_up": action = "e_release"
 if _e1_form_current() and action in ["q", "ink_q_down", "attack", "r"]:
  return {"accepted":false, "reason":"rain_form_forbids_action", "consumed":true}
 # Physical release is retained as intent while paused; never runs a paused
 # damage transaction or clock. It settles at the first resumed source step.
 if action == "e_release" and paused and _e1_form_current():
  ink_rain.release_pending = true
  return {"accepted":true, "reason":"rain_release_queued_while_paused", "cast_id":ink_rain.cast_id, "consumed":true}
 return super._request_action(action, aim)

func _q_ready() -> String:
 return "rain_form_forbids_action" if _e1_form_current() else super._q_ready()

func _hero_action_policy(action: String, aim: Vector3 = Vector3.INF) -> Dictionary:
 if _e1_form_current() and action in ["attack", "q", "r"]: return {"reason":"rain_form_forbids_action"}
 if action == "e_release":
  if source_rules_hash != EXPECTED_RULES_HASH: return {"reason":"source_binding_mismatch"}
  if not _e1_form_current(): return {"reason":"no_rain_form"}
  return {"cast_id":ink_rain.cast_id, "context":ink_rain.context, "stage":"reform", "bypass_cooldown":true, "bypass_lock":true, "bypass_dash":true}
 if action != "e" or hero.loadout.e != "e1": return super._hero_action_policy(action, aim)
 if source_rules_hash != EXPECTED_RULES_HASH: return {"reason":"source_binding_mismatch"}
 if _e1_form_current(): return {"reason":"rain_form_already_active"}
 if _ink_action_controlled(action): return {"reason":"controlled"}
 return {"stage":"rain_entry"}

func _ink_action_ignores_control(action: String) -> bool:
 if action == "e" and hero.loadout.e == "e1" and int(hero.ranks.e) > 0 and hx("yanguizhou_h07"): return true
 return super._ink_action_ignores_control(action)

func _hero_cast_skill(action: String, context: Dictionary) -> Dictionary:
 if action == "e_release":
  if not _e1_form_current() or int(context.cast_id) != int(ink_rain.cast_id): return {"accepted":false, "reason":"stale_rain_release"}
  _e1_reform(ink_rain, "physical_release", hero_time)
  return {"accepted":true, "phase":"reformed"}
 if action != "e" or hero.loadout.e != "e1": return super._hero_cast_skill(action, context)
 if not effect_is_current(context): return {"accepted":false, "reason":"stale_cast"}
 var rank: int = int(hero.ranks.e)
 _e1_serial += 1
 var state: Dictionary = context.duplicate(true)
 state.merge({"owner":hero, "context":context.duplicate(true), "form_id":"%d:%s:rain:%d" % [encounter_generation, room_id, _e1_serial], "rank":rank, "born_at":hero_time, "expires_at":hero_time + v("E1-1", rank), "damage_reduction":T.fraction("E1-2", rank), "speed_bonus":T.fraction("E1-3", rank), "mark_limit":int(v("E1-4", rank)), "radius":v("E1-5", rank), "base_damage":v("E1-6", rank) + float(hero.stats.ap) * T.fraction("E1-7", rank), "bonus_damage":v("E1-8", rank) + float(hero.stats.ap) * T.fraction("E1-9", rank), "h07_at_entry":hx("yanguizhou_h07"), "h08_at_entry":hx("yanguizhou_h08"), "marks":{}, "hit_targets":{}, "retired":false, "release_pending":false}, true)
 ink_rain = state
 _e1_set_speed_bonus(float(state.speed_bonus))
 # E1 already grants form, DR and speed here. Same accepted-effect convention
 # as inherited Q1 release/Q3 raise; never borrowed from preview-only E3/Q2.
 start_skill_cooldown("e", v("E1-10", rank))
 if bool(state.h07_at_entry):
  hero.stun_left = 0.0; hero.slow_left = 0.0; hero.slow_amount = 0.0; hero.knockback = Vector3.ZERO
  _control_frame_left = 0.0; _control_motion_blocking = false
 if bool(state.h08_at_entry):
  ink_rain_guard = context.duplicate(true)
  ink_rain_guard.merge({"owner":hero, "form_id":state.form_id, "born_at":hero_time, "expires_at":hero_time + T.hex_parameter("H08-1")}, true)
 # An uncommitted Q1 cannot survive into form and release around its Q gate.
 if ink_input.phase != "idle": cancel_ink_preview("rain_form_entered")
 if not _e1_current(state) or not is_same(ink_rain, state): return {"accepted":true, "cancelled_during_callback":true}
 _equipment_release_committed("e1",state)
 emit_event("ink_e1_entered", _e1_public(state))
 return {"accepted":true, "phase":"rain", "form_id":state.form_id}

func _hero_hex_status(id: String) -> Dictionary:
 if id in ["yanguizhou_h07", "yanguizhou_h08"]:
  var active: bool = hero.loadout.e == "e1" and int(hero.ranks.e) > 0
  return {"active":active, "reason":"" if active else "requires_E1"}
 return super._hero_hex_status(id)

func _hero_incoming_damage(packet: float, metadata: Dictionary) -> float:
 var inherited: float = super._hero_incoming_damage(packet, metadata)
 # Narrow damage-only hook, including true packets. Core still executes legal
 # control after HP commit. No shared immune flag, attack early-return or cleanse.
 if _e1_guard_current(): return 0.0
 if _e1_form_current() and hero_time < float(ink_rain.expires_at) - TIME_EPS:
  return inherited * (1.0 - float(ink_rain.damage_reduction))
 return inherited

func _fixed_step(real_dt: float) -> void:
 if not ink_rain.is_empty() and not _e1_current(ink_rain):
  if is_same(hero, ink_rain.owner): _e1_set_speed_bonus(0.0)
  ink_rain.retired = true; ink_rain.marks.clear(); ink_rain = {}
 if not ink_rain_guard.is_empty() and not _e1_current(ink_rain_guard): ink_rain_guard = {}
 var scope: Dictionary = _ink_scope()
 _e1_tick_active = true; _e1_tick_start = hero_time
 super._fixed_step(real_dt) # Exactly one shared clock/AI/common/RNG step.
 _e1_tick_active = false
 if not _ink_scope_current(scope): return
 if not ink_rain_guard.is_empty() and (not _e1_current(ink_rain_guard) or hero_time >= float(ink_rain_guard.expires_at) - TIME_EPS): ink_rain_guard = {}
 _check_victory()

func _hero_pre_step(actor_dt: float, real_dt: float) -> void:
 super._hero_pre_step(actor_dt, real_dt)
 if _e1_form_current() and bool(ink_rain.release_pending): _e1_reform(ink_rain, "queued_physical_release", _e1_tick_start)

func _step_player_locomotion(real_dt: float) -> void:
 if not _e1_form_current(): super._step_player_locomotion(real_dt); return
 var state: Dictionary = ink_rain
 var start: float = _e1_tick_start if _e1_tick_active else hero_time
 var actor_dt: float = maxf(0.0, hero_time - start) if _e1_tick_active else 0.0
 var active_real: float = real_dt
 if actor_dt > TIME_EPS: active_real = minf(real_dt, maxf(0.0, float(state.expires_at) - start) * real_dt / actor_dt)
 var scope: Dictionary = _ink_scope()
 if active_real > TIME_EPS:
  _e1_locomotion = true; _e1_motion_state = state; _e1_paths = []
  _e1_move_interval(active_real, start, minf(hero_time, float(state.expires_at)))
  _e1_locomotion = false; _e1_motion_state = {}
  var paths: Array = _e1_paths; _e1_paths = []
  if not _e1_current(state) or not is_same(ink_rain, state): return
  _e1_mark_paths(state, paths, start, minf(hero_time, float(state.expires_at)))
 if not _ink_scope_current(scope) or hero.dead: return
 if _e1_current(state) and is_same(ink_rain, state) and hero_time >= float(state.expires_at) - TIME_EPS:
  _e1_reform(state, "duration_deadline", float(state.expires_at))
 if not _ink_scope_current(scope) or hero.dead: return
 # Only locomotion is sliced. The rest of the world is not stepped again.
 if real_dt - active_real > TIME_EPS: _e1_move_interval(real_dt - active_real, minf(hero_time, float(state.expires_at)), hero_time)

func _e1_move_interval(real_dt: float, from_time: float, to_time: float) -> void:
 var saved_left: float = _control_frame_left
 var saved_clock: float = _control_frame_clock
 var scope: Dictionary = _ink_scope()
 if _control_frame_active:
  _control_frame_left = maxf(0.0, saved_left - maxf(0.0, from_time - saved_clock))
  _control_frame_clock = hero_time - maxf(0.0, to_time - from_time)
 super._step_player_locomotion(real_dt)
 if _ink_scope_current(scope):
  _control_frame_left = saved_left; _control_frame_clock = saved_clock

static func _e1_circle_entry(origin: Vector3, destination: Vector3, center: Vector3, radius: float) -> float:
 var delta: Vector3 = Geometry.ground(destination - origin)
 var offset: Vector3 = Geometry.ground(origin - center)
 var c: float = offset.length_squared() - radius * radius
 if c <= 0.0: return 0.0
 var a: float = delta.length_squared()
 if a <= Geometry.EPS * Geometry.EPS: return INF
 var b: float = 2.0 * offset.dot(delta)
 var discriminant: float = b * b - 4.0 * a * c
 if discriminant < 0.0: return INF
 var fraction: float = (-b - sqrt(discriminant)) / (2.0 * a)
 return fraction if fraction >= 0.0 and fraction <= 1.0 else INF

func _move_clipped(origin: Vector3, destination: Vector3, radius: float = .65) -> Vector3:
 if not _e1_locomotion or not _e1_current(_e1_motion_state) or not _q3_movement_actor.is_empty(): return super._move_clipped(origin, destination, radius)
 var moved: Vector3 = super._move_clipped(origin, destination, radius)
 # Preserve existing actor collision semantics pending the parent's narrow
 # collision-interface review. Core clips walls/arena but no unit bodies. This
 # candidate does not claim the ordinary-only collision distinction passed.
 if origin.distance_squared_to(moved) > Geometry.EPS * Geometry.EPS:
  _e1_paths.append({"from":origin, "to":moved})
 return moved

func _e1_target_current(enemy: Dictionary, state: Dictionary) -> bool:
 return _e1_current(state) and not enemy.is_empty() and not enemy.dead and enemy.state != "spawn" and is_same(enemy, enemy_by_id(str(enemy.actor_id))) and int(enemy.generation) == encounter_generation and str(enemy.room_id) == room_id

func _e1_mark_paths(state: Dictionary, paths: Array, from_time: float, to_time: float) -> void:
 for path in paths:
  var contacts: Array = []
  for enemy in enemies:
   if not _e1_target_current(enemy, state) or state.marks.has(str(enemy.actor_id)): continue
   var fraction: float = _e1_circle_entry(path.from, path.to, enemy.position, hero_radius + float(enemy.radius))
   if is_finite(fraction): contacts.append({"enemy":enemy, "fraction":fraction})
  contacts.sort_custom(func(a, b): return str(a.enemy.actor_id) < str(b.enemy.actor_id) if a.fraction == b.fraction else float(a.fraction) < float(b.fraction))
  for contact in contacts:
   if not _e1_current(state) or not is_same(ink_rain, state): return
   var enemy: Dictionary = contact.enemy
   var id: String = str(enemy.actor_id)
   if not _e1_target_current(enemy, state) or state.marks.has(id): continue
   _e1_mark_contact(state, enemy, path.from, path.to, float(contact.fraction), lerpf(from_time, to_time, float(contact.fraction)), "hero")

func _e1_mark_contact(state: Dictionary, enemy: Dictionary, origin: Vector3, destination: Vector3, fraction: float, at: float, mover: String) -> void:
 if not _e1_current(state) or not is_same(ink_rain, state) or not _e1_target_current(enemy, state): return
 var id: String = str(enemy.actor_id)
 if state.marks.has(id) or not claim_hit(int(state.cast_id), id, "ink_e1_rain_mark"): return
 state.marks[id] = {"enemy":enemy, "count":mini(1, int(state.mark_limit))}
 var receipt: Dictionary = {"form_id":state.form_id, "cast_id":state.cast_id, "generation":state.generation, "room_id":state.room_id, "target_id":id, "count":state.marks[id].count, "from_position":origin, "to_position":destination, "motion_actor":mover, "contact_position":origin.lerp(destination, fraction), "source_time":at, "damage":0.0}
 ink_e1_marks.append(receipt)
 emit_event("ink_e1_rain_marked", receipt)

func _e1_enemy_motion(state: Dictionary, enemy: Dictionary, before: Vector3) -> void:
 if not _e1_current(state) or not is_same(ink_rain, state) or not _e1_target_current(enemy, state): return
 if before.distance_squared_to(enemy.position) <= Geometry.EPS * Geometry.EPS: return
 # Preserve core's actual phase order: hero motion, then pull/push/AI. Each
 # moving body's realized segment sweeps relative to the other body's current
 # location. No final-point-only overlap or invented simultaneous teleport.
 var fraction: float = _e1_circle_entry(before, enemy.position, hero.position, hero_radius + float(enemy.radius))
 if is_finite(fraction): _e1_mark_contact(state, enemy, before, enemy.position, fraction, hero_time, "enemy")

func _step_pull(enemy: Dictionary, dt: float) -> void:
 var state: Dictionary = ink_rain; var before: Vector3 = enemy.position
 super._step_pull(enemy, dt)
 _e1_enemy_motion(state, enemy, before)
func _step_push(enemy: Dictionary, dt: float) -> void:
 var state: Dictionary = ink_rain; var before: Vector3 = enemy.position
 super._step_push(enemy, dt)
 _e1_enemy_motion(state, enemy, before)
func _step_enemy(enemy: Dictionary, dt: float) -> void:
 var state: Dictionary = ink_rain; var before: Vector3 = enemy.position
 super._step_enemy(enemy, dt)
 _e1_enemy_motion(state, enemy, before)

func _e1_reform(state: Dictionary, reason: String, at: float) -> void:
 if not _e1_current(state) or not is_same(ink_rain, state) or bool(state.retired): return
 var origin: Vector3 = hero.position
 var targets: Array = circle_targets(origin, float(state.radius))
 var marked: Array = []
 var all_mark_ids: Array = state.marks.keys()
 for enemy in targets:
  var mark: Dictionary = state.marks.get(str(enemy.actor_id), {})
  if not mark.is_empty() and is_same(mark.enemy, enemy): marked.append(enemy)
 # Detach the form before callbacks can reenter. Only the saved original
 # identities in these two finite batches may receive this settlement. The
 # complete mark map is cleared after settlement, including every abort path.
 state.retired = true; ink_rain = {}
 _e1_set_speed_bonus(0.0)
 var receipt: Dictionary = _e1_public(state).merged({"position":origin, "reason":reason, "finished_at":at, "cleared_mark_target_ids":all_mark_ids, "radius_target_ids":targets.map(func(e): return e.actor_id), "bonus_target_ids":marked.map(func(e): return e.actor_id)}, true)
 common.refresh_stats()
 var impact: Dictionary = {"impact_penetration":float(hero.stats.penetration), "impact_lifesteal_rate":hero.lifesteal(), "ink_e1_impact_stats":common.context().hero.stats.duplicate(true)}
 emit_event("ink_e1_reform_started", receipt)
 if not _e1_current(state): state.marks.clear(); return
 _e1_damage_batch(state, targets, "reform_burst", float(state.base_damage), origin, at, impact)
 if not _e1_current(state): state.marks.clear(); return
 _e1_damage_batch(state, marked, "rain_mark_bonus", float(state.bonus_damage), origin, at, impact)
 state.marks.clear()
 if not _e1_current(state): return
 finish_cast(int(state.cast_id))
 if not _e1_current(state): return
 receipt["hit_target_ids"] = state.hit_targets.keys()
 receipt["damage_stages_complete"] = true
 ink_e1_finished.append(receipt)
 emit_event("ink_e1_finished", receipt)

func _e1_damage_batch(state: Dictionary, targets: Array, segment: String, amount: float, origin: Vector3, at: float, impact: Dictionary) -> void:
 for enemy in targets:
  if not _e1_current(state): return
  if not _e1_target_current(enemy, state): continue
  var id: String = str(enemy.actor_id)
  if not claim_hit(int(state.cast_id), id, "ink_e1_" + segment): continue
  var event_id: String = str(state.form_id) + ":" + segment + ":" + id
  var metadata: Dictionary = {"effect_id":event_id, "generation":state.generation, "room_id":state.room_id, "position":origin, "cast_origin":state.origin, "direction":state.direction, "saved_aim":state.direction, "active_skill":true, "area":true, "direct":true, "basic_attack":false, "hex_generated":false, "segment_id":segment}
  metadata.merge(impact, false)
  state.hit_targets[id] = true
  var before: float = float(enemy.hp)
  damage_enemy(enemy, amount, "e1", int(state.cast_id), false, false, metadata)
  if not _e1_current(state): return
  var receipt: Dictionary = {"source_event_id":event_id, "effect_id":event_id, "form_id":state.form_id, "cast_id":state.cast_id, "segment_id":segment, "target_id":id, "generation":state.generation, "room_id":state.room_id, "source_time":at, "settled_at":hero_time, "position":origin, "nominal_damage":amount, "actual_damage":before - float(enemy.hp)}
  ink_e1_receipts.append(receipt)
  emit_event("ink_e1_contact", receipt)

func common_damage_metadata(source: String) -> Dictionary:
 if source == "e1": return {"active_skill":true, "basic_attack":false, "direct":true, "area":true, "hex_generated":false}
 return super.common_damage_metadata(source)

func cancel_cast(id: int) -> void:
 if not ink_rain.is_empty() and int(ink_rain.cast_id) == id:
  ink_rain.retired = true; ink_rain.marks.clear(); ink_rain = {}
  _e1_set_speed_bonus(0.0)
 if not ink_rain_guard.is_empty() and int(ink_rain_guard.cast_id) == id: ink_rain_guard = {}
 super.cancel_cast(id)

func _hero_clear_transients() -> void:
 _e1_set_speed_bonus(0.0)
 if not ink_rain.is_empty(): ink_rain.retired = true; ink_rain.marks.clear()
 ink_rain = {}; ink_rain_guard = {}; _e1_locomotion = false; _e1_motion_state = {}; _e1_paths = []; _e1_tick_active = false
 ink_e1_marks.clear(); ink_e1_receipts.clear(); ink_e1_finished.clear()
 super._hero_clear_transients()

func _hero_victory_pending() -> bool: return super._hero_victory_pending() or not ink_rain.is_empty()
func _e1_public(state: Dictionary) -> Dictionary:
 var out: Dictionary = {}
 for key in ["form_id", "cast_id", "generation", "room_id", "rank", "born_at", "expires_at", "damage_reduction", "speed_bonus", "mark_limit", "radius", "base_damage", "bonus_damage", "h07_at_entry", "h08_at_entry"]: out[key] = state[key]
 out["mark_target_ids"] = state.marks.keys()
 out["remaining"] = maxf(0.0, float(state.expires_at) - hero_time)
 return out
func ink_presenter_snapshot() -> Dictionary:
 var out: Dictionary = super.ink_presenter_snapshot()
 out["e1_schema"] = "ink-e1-source-foundation-1"
 out["rain"] = {} if ink_rain.is_empty() else _e1_public(ink_rain)
 out["rain_damage_only_protection"] = {"active":_e1_guard_current(), "remaining":maxf(0.0, float(ink_rain_guard.get("expires_at", hero_time)) - hero_time)}
 out["e1_marks"] = ink_e1_marks.duplicate(true); out["e1_receipts"] = ink_e1_receipts.duplicate(true); out["e1_finished"] = ink_e1_finished.duplicate(true)
 return out
func _hero_snapshot() -> Dictionary:
 var out: Dictionary = super._hero_snapshot()
 out["e1_ordinary_entry_ready"] = false
 out["e1_source_candidate"] = {"runtime_validation":"NOT_RUN", "normal_host_enabled":false, "walking_speed":hero.speed(), "h08_damage_only":_e1_guard_current()}
 return out
