extends "res://tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd"
## Isolated Q2/H03/H04 source candidate. No ordinary-host capability promotion.
const RiverGeometry = preload("res://tests/ink_q2_foundation_20261005/fix01/river_geometry.gd")
const Q2_DECISIONS_PATH = "res://docs/source_decisions/20261005-ink-six-resolutions.json"
const EXPECTED_Q2_DECISIONS_HASH = "62cbd6c20607748cb4c426abd42d4656d6de1ab922fda179102bd8b8afdf6634"
var q2_decisions_hash: String = ""
var ink_q2_pending: Dictionary = {}
var ink_rivers: Array = []
var ink_q2_receipts: Array = []
var ink_q2_finished: Array = []
var _q2_serial: int = 0
var _q2_expected_cast: int = -1
var _q2_tick_start: float = 0.0
var _q2_tick_active: bool = false
var _q2_move_depth: int = 0
var _q2_motion_traces: Array = []
var _q2_deferred_contacts: Array = []
var _q2_pull_context: Dictionary = {}
var _q2_enemy_context: Dictionary = {}
var _q2_enemy_hits: Array = []
var _q2_last_enemy_hit: Dictionary = {}
var _q2_motion_resume: Dictionary = {}
var _q2_resume_from: float = -1.0

func _init() -> void:
 super._init()
 q2_decisions_hash = FileAccess.get_sha256(Q2_DECISIONS_PATH)

func request_q2(kind: String, point: Vector3 = Vector3.INF, command_id: String = "", expected_cast: int = -1, expected_generation: int = -1) -> Dictionary:
 if expected_generation >= 0 and expected_generation != encounter_generation: return {"accepted":false, "reason":"stale_input_generation"}
 if transaction_active: return {"accepted":false, "reason":"transaction_in_progress"}
 _q2_expected_cast = expected_cast
 var result: Dictionary = request_action("q2_" + kind, point, command_id)
 _q2_expected_cast = -1
 return result

func _q2_input_reason() -> String:
 if phase != "combat" or paused: return "encounter_frozen"
 if hero.dead: return "not_alive"
 if source_rules_hash != EXPECTED_RULES_HASH: return "source_binding_mismatch"
 if q2_decisions_hash != EXPECTED_Q2_DECISIONS_HASH: return "decision_binding_mismatch"
 if hero.loadout.q != "q2" or int(hero.ranks.q) <= 0: return "q2_unlearned"
 if _ink_action_controlled("q"): return "controlled"
 if not ink_q2_pending.is_empty():
  if not effect_is_current(ink_q2_pending): return "stale_marker"
  if _q2_expected_cast >= 0 and _q2_expected_cast != int(ink_q2_pending.cast_id): return "stale_marker_identity"
  if hero_time >= float(ink_q2_pending.expires_at) - TIME_EPS: return "marker_expired"
 return ""

func q2_preview(point: Vector3) -> Dictionary:
 var reason: String = _q2_input_reason()
 if not reason.is_empty(): return {"accepted":false, "reason":reason, "preview_only":true}
 if not point.is_finite(): return {"accepted":false, "reason":"manual_aim_required", "preview_only":true}
 var at: Vector3 = Geometry.ground(point)
 var rank: int = int(hero.ranks.q)
 if ink_q2_pending.is_empty():
  if at.distance_to(Geometry.ground(hero.position)) > v("Q2-1", rank) + Geometry.EPS: return {"accepted":false, "reason":"first_point_out_of_range", "preview_only":true}
  return {"accepted":true, "phase":"first", "point":at, "preview_only":true}
 var path: Array = ink_q2_pending.path.duplicate(true)
 path.append(at)
 var length: float = Geometry.path_length(path)
 if Vector3(path[-2]).distance_to(at) <= Geometry.EPS: return {"accepted":false, "reason":"zero_length_leg", "preview_only":true}
 if length > v("Q2-3", rank) + Geometry.EPS: return {"accepted":false, "reason":"river_total_length_exceeded", "preview_only":true}
 return {"accepted":true, "phase":"second", "path":path, "point":at, "length":length, "width":v("Q2-4", rank), "cast_id":ink_q2_pending.cast_id, "preview_only":true}

func _request_action(action: String, aim: Vector3) -> Dictionary:
 if action == "q2_preview": return q2_preview(aim)
 if action == "q2_corner":
  var preview: Dictionary = q2_preview(aim)
  if not preview.accepted: return preview
  if ink_q2_pending.is_empty(): return {"accepted":false, "reason":"first_marker_required"}
  if not hx("yanguizhou_h03"): return {"accepted":false, "reason":"requires_H03"}
  if ink_q2_pending.path.size() - 1 >= int(T.hex_parameter("H03-1")): return {"accepted":false, "reason":"corner_limit"}
  ink_q2_pending.path.append(preview.point)
  revision += 1
  emit_event("ink_q2_corner_placed", _q2_pending_public())
  return {"accepted":true, "consumed":true, "cast_id":preview.cast_id}
 if action in ["q2_first", "q2_second"]:
  var reason: String = _q2_input_reason()
  if not reason.is_empty(): return {"accepted":false, "reason":reason}
  if action == "q2_first" and not ink_q2_pending.is_empty(): return {"accepted":false, "reason":"marker_already_pending"}
  if action == "q2_second" and ink_q2_pending.is_empty(): return {"accepted":false, "reason":"first_marker_required"}
  action = "q"
 if hero.loadout.q == "q2" and action in ["q", "ink_q_down"]:
  var saved: bool = _committing_q1
  _committing_q1 = true
  var result: Dictionary = super._request_action("q", aim)
  _committing_q1 = saved
  return result
 # Focus loss/escape do not complete or refund a pending marker. Its original
 # source window continues. No fabricated cancellation-cooldown rule.
 if hero.loadout.q == "q2" and action == "ink_q_up": return {"accepted":true, "consumed":true, "reason":"q2_release_no_effect"}
 return super._request_action(action, aim)

func _hero_action_policy(action: String, aim: Vector3 = Vector3.INF) -> Dictionary:
 if action != "q" or hero.loadout.q != "q2": return super._hero_action_policy(action, aim)
 var preview: Dictionary = q2_preview(aim)
 if not preview.accepted: return {"reason":preview.reason}
 if not ink_q2_pending.is_empty(): return {"cast_id":ink_q2_pending.cast_id, "context":ink_q2_pending.context, "bypass_cooldown":true, "stage":"river_complete"}
 return {"stage":"river_first_marker"}

func _hero_cast_skill(action: String, context: Dictionary) -> Dictionary:
 if action != "q" or hero.loadout.q != "q2": return super._hero_cast_skill(action, context)
 if not effect_is_current(context): return {"accepted":false, "reason":"stale_cast"}
 var preview: Dictionary = q2_preview(hero.aim_point)
 if not preview.accepted: return {"accepted":false, "reason":preview.reason}
 var rank: int = int(hero.ranks.q)
 if ink_q2_pending.is_empty():
  ink_q2_pending = context.duplicate(true)
  ink_q2_pending.merge({"context":context.duplicate(true), "path":[preview.point], "rank":rank, "born_at":hero_time, "expires_at":hero_time + v("Q2-2", rank)}, true)
  # USER 03:13: first marker NEVER starts the cooldown.
  emit_event("ink_q2_first_placed", _q2_pending_public())
  return {"accepted":true, "phase":"first", "release_completed":false}
 var pending: Dictionary = ink_q2_pending
 if int(context.cast_id) != int(pending.cast_id): return {"accepted":false, "reason":"stale_marker_identity"}
 if pending.path.size() > 1 and not hx("yanguizhou_h03"): return {"accepted":false, "reason":"H03_no_longer_available"}
 ink_q2_pending = {}
 _q2_serial += 1
 var state: Dictionary = pending.context.duplicate(true)
 state.merge({"river_id":"%d:%s:river:%d" % [encounter_generation, room_id, _q2_serial], "path":preview.path.duplicate(true), "width":v("Q2-4", rank), "rank":rank, "born_at":hero_time, "expires_at":hero_time + v("Q2-5", rank), "sunset_expires_at":hero_time + T.hex_parameter("H04-1"), "h04_at_completion":hx("yanguizhou_h04"), "h03_at_completion":hx("yanguizhou_h03"), "damage":v("Q2-6", rank) + float(hero.stats.ap) * T.fraction("Q2-7", rank), "sunset_damage":T.hex_parameter("H04-5") + float(hero.stats.ap) * T.hex_parameter("H04-6") * .01, "range_fraction":T.fraction("Q2-8", rank), "speed_fraction":T.fraction("Q2-9", rank), "hits":{}, "next_sunset_tick":1, "river_expired":false, "retired":false}, true)
 var equipment_river_array:Array=ink_rivers
 ink_rivers.append(state)
 start_skill_cooldown("q", v("Q2-10", rank))
 _equipment_release_committed("q2",state)
 emit_event("ink_q2_river_created", _q2_public(state).merged({"release_completed":true}, true))
 if not _q2_current(state): return {"accepted":true, "cancelled_during_callback":true}
 # USER 03:13: already inside at activation is an immediate first touch.
 _q2_birth_contacts(state)
 if _q2_current(state):
  var equipment_river:Dictionary={"kind":"river_completion","river":state,"pending":pending,"states":equipment_river_array,"context":context,"at":hero_time,"dispatch":_equipment_action_dispatch_frames.back() if not _equipment_action_dispatch_frames.is_empty() else {}}
  _equipment_sync_settlement_frames.append(equipment_river)
  _settle_motion_interval(_enemy_motion_snapshot(), hero_time, hero_time)
  assert(is_same(_equipment_sync_settlement_frames.back(),equipment_river))
  _equipment_sync_settlement_frames.pop_back()
 return {"accepted":true, "phase":"river", "river_id":state.river_id, "release_completed":true}

func _q2_valid(state: Dictionary) -> bool:
 return not state.is_empty() and effect_is_current(state) and not bool(state.get("retired", false)) and not hero.dead
func _q2_current(state: Dictionary) -> bool:
 return not paused and _q2_valid(state)
func _q2_target_current(enemy: Dictionary, state: Dictionary) -> bool:
 return _q2_current(state) and not enemy.is_empty() and not bool(enemy.dead) and enemy.state != "spawn" and is_same(enemy, enemy_by_id(str(enemy.actor_id))) and int(enemy.generation) == encounter_generation and str(enemy.room_id) == room_id
func _q2_impact_snapshot() -> Dictionary:
 common.refresh_stats()
 var live: Array = common.runtime._enemies(common.context())
 var mode: String = "horde" if live.size() >= int(common.runtime.parameter("g22", 1)) else "duel" if live.size() == 1 and not ordinary(live[0]) else "none"
 return {"g22_mode_snapshot":mode, "impact_penetration":float(hero.stats.penetration), "impact_lifesteal_rate":hero.lifesteal()}
func _q2_birth_contacts(state: Dictionary) -> void:
 var contacts: Array = []
 var impact: Dictionary = _q2_impact_snapshot()
 for enemy in enemies.duplicate():
  if _q2_target_current(enemy, state) and RiverGeometry.overlaps(enemy.position, enemy.radius, state.path, state.width):
   contacts.append({"state":state, "enemy":enemy, "time":hero_time, "kind":"river", "tick":0, "position":enemy.position, "impact":impact})
 _q2_dispatch_contacts(contacts)
func _q2_dispatch_contacts(contacts: Array) -> void:
 var scope: Dictionary = _ink_scope()
 while not contacts.is_empty():
  if not _ink_scope_current(scope): return
  if paused:
   _q2_deferred_contacts.append_array(contacts)
   return
  var hit: Dictionary = contacts.pop_front()
  if not _q2_current(hit.state): continue
  _q2_damage(hit.state, hit.enemy, hit.time, hit.kind, hit.tick, hit.position, _q2_hit_impact(hit))
func _q2_damage(state: Dictionary, enemy: Dictionary, at: float, kind: String, tick: int, position: Vector3, impact: Dictionary) -> void:
 if not _q2_target_current(enemy, state): return
 var id: String = str(enemy.actor_id)
 if kind == "river":
  if state.hits.has(id): return
  state.hits[id] = true # Reserve before callbacks and shared damage.
 var segment: String = "river_touch" if kind == "river" else "sunset:%d" % tick
 if not claim_hit(int(state.cast_id), id, segment): return
 var effect_id: String = str(state.river_id) + ":" + segment + ":" + id
 var receipt: Dictionary = {"river_id":state.river_id, "cast_id":state.cast_id, "generation":state.generation, "room_id":state.room_id, "target_id":id, "kind":kind, "tick":tick, "source_time":at, "target_position":position, "effect_id":effect_id}
 var metadata: Dictionary = {"effect_id":effect_id, "generation":state.generation, "room_id":state.room_id, "position":RiverGeometry.closest_point(position, state.path) if kind == "river" else state.path.back(), "active_skill":true, "basic_attack":false, "area":true, "direct":kind == "river", "hex_generated":kind != "river", "q2_receipt":receipt}
 if kind == "river": metadata["replay_segment"] = {"target_mode":"bound", "segment_id":"realized_river_crossing_damage", "relative_time":at - float(state.born_at)}
 metadata.merge(impact, false)
 _equipment_skill_damage("q2",state,enemy, float(state.damage if kind == "river" else state.sunset_damage), "q2" if kind == "river" else "hex_yanguizhou_h04", int(state.cast_id), false, false, metadata)
func _hero_after_damage(enemy: Dictionary, event: Dictionary, actual: float) -> void:
 super._hero_after_damage(enemy, event, actual)
 if not event.has("q2_receipt") or not effect_is_current(event.q2_receipt): return
 var receipt: Dictionary = event.q2_receipt.duplicate(true)
 receipt.merge({"actual_damage":actual, "settled_at":hero_time}, true)
 ink_q2_receipts.append(receipt)
 if ink_q2_receipts.size() > 128: ink_q2_receipts.pop_front()
 emit_event("ink_q2_crossing" if receipt.kind == "river" else "ink_h04_contact", receipt)

func _fixed_step(real_dt: float) -> void:
 # A callback can pause partway through local settlement after the one shared
 # clock already advanced. Resume exactly that remainder before a new world
 # step; never replay AI/common/RNG or discard already-admitted simulation time.
 if not _q2_motion_resume.is_empty() and not paused:
  var resume_scope: Dictionary = _ink_scope()
  var resume: Dictionary = _q2_motion_resume
  _q2_motion_resume = {}; _q2_resume_from = float(resume.cursor)
  _settle_motion_interval(resume.before, resume.start, resume.end)
  if not _ink_scope_current(resume_scope): return
  if paused:
   real_accumulator += real_dt
   return
  _q2_settle(resume.before, resume.start, resume.end)
  if not _ink_scope_current(resume_scope): return
  if paused:
   real_accumulator += real_dt
   return
 var scope: Dictionary = _ink_scope()
 var before: Dictionary = _enemy_motion_snapshot()
 _q2_tick_start = hero_time; _q2_tick_active = true; _q2_motion_traces.clear()
 super._fixed_step(real_dt) # Exactly one shared clock/AI/common/RNG step.
 _q2_tick_active = false
 if not _ink_scope_current(scope) or paused: return
 _q2_settle(before, _q2_tick_start, hero_time)
 if not _ink_scope_current(scope): return
 if not ink_q2_pending.is_empty() and hero_time >= float(ink_q2_pending.expires_at) - TIME_EPS:
  var pending: Dictionary = ink_q2_pending
  ink_q2_pending = {} # Remove marker BEFORE starting cooldown.
  start_skill_cooldown("q", v("Q2-10", int(pending.rank)))
  hero.cooldowns.q = maxf(0.0, float(hero.cooldowns.q) - maxf(0.0, hero_time - float(pending.expires_at)))
  emit_event("ink_q2_placement_expired", {"cast_id":pending.cast_id, "source_time":pending.expires_at, "release_completed":false, "cooldown":hero.cooldowns.q})
  if effect_is_current(pending): finish_cast(int(pending.cast_id))
 if _ink_scope_current(scope): _check_victory()

func _q2_record_motion(enemy: Dictionary, origin: Vector3, destination: Vector3, begin: float = -1.0, end: float = -1.0) -> void:
 if _q2_tick_active and origin.distance_squared_to(destination) > Geometry.EPS * Geometry.EPS:
  _q2_motion_traces.append({"enemy":enemy, "from":origin, "to":destination, "start":_q2_tick_start if begin < 0.0 else begin, "end":hero_time if end < 0.0 else end})
func _step_pull(enemy: Dictionary, dt: float) -> void:
 var previous: Dictionary = _q2_pull_context
 _q2_pull_context = {"enemy":enemy, "cursor":enemy.position}
 super._step_pull(enemy, dt)
 _q2_record_motion(enemy, _q2_pull_context.cursor, enemy.position)
 _q2_pull_context = previous
func _step_push(enemy: Dictionary, dt: float) -> void:
 var origin: Vector3 = enemy.position
 super._step_push(enemy, dt)
 _q2_record_motion(enemy, origin, enemy.position)
func _step_enemy(enemy: Dictionary, dt: float) -> void:
 var origin: Vector3 = enemy.position
 var previous: Dictionary = _q2_enemy_context
 _q2_enemy_context = {"enemy":enemy, "origin":origin, "state":enemy.state, "timer":enemy.timer, "dt":dt}
 _q2_last_enemy_hit = {}
 super._step_enemy(enemy, dt)
 _q2_enemy_context = previous; _q2_last_enemy_hit = {}
 _q2_record_motion(enemy, origin, enemy.position)

func damage_hero(amount: float, direction: Vector3 = Vector3.ZERO, control: float = 0.0, is_true: bool = false, mandatory: bool = false, metadata: Dictionary = {}) -> void:
 if _q2_tick_active and not _q2_enemy_context.is_empty() and (not ink_rivers.is_empty() or not _q2_enemy_hits.is_empty()):
  var enemy: Dictionary = _q2_enemy_context.enemy
  var fraction: float = 1.0
  if _q2_enemy_context.state == "pounce":
   var origin: Vector3 = _q2_enemy_context.origin
   var offset: Vector3 = Geometry.ground(origin - hero.position)
   var motion: Vector3 = Geometry.ground(Vector3(enemy.position) - origin)
   fraction = Geometry._circle_entry(Vector2(offset.x, offset.z), Vector2(motion.x, motion.z), Vector2.ZERO, float(enemy.radius) + enemy_director.HERO_RADIUS)
   if not is_finite(fraction): fraction = 1.0
  elif _q2_enemy_context.state == "warning":
   fraction = clampf(float(_q2_enemy_context.timer) / maxf(TIME_EPS, float(_q2_enemy_context.dt)), 0.0, 1.0)
  var hit: Dictionary = {"kind":"enemy_hit", "enemy":enemy, "time":lerpf(_q2_tick_start, hero_time, fraction), "amount":amount, "direction":direction, "control":control, "is_true":is_true, "mandatory":mandatory, "metadata":metadata.duplicate(true), "generation":encounter_generation, "room_id":room_id, "impacts":[]}
  _q2_enemy_hits.append(hit); _q2_last_enemy_hit = hit
  return
 super.damage_hero(amount, direction, control, is_true, mandatory, metadata)

func emit_event(kind: String, data: Dictionary = {}) -> void:
 # Keep the original AI's impact event tied to its actual damage transaction.
 # If an earlier river/projectile kills the attacker, no false hit is emitted.
 if kind == "enemy_impact" and not _q2_enemy_context.is_empty() and not _q2_last_enemy_hit.is_empty() and str(data.get("actor_id", "")) == str(_q2_enemy_context.enemy.actor_id):
  _q2_last_enemy_hit.impacts.append({"kind":kind, "data":data.duplicate(true)})
  return
 super.emit_event(kind, data)

func _q2_enemy_hit_current(hit: Dictionary) -> bool:
 return phase == "combat" and int(hit.generation) == encounter_generation and str(hit.room_id) == room_id and not hero.dead and not bool(hit.enemy.dead) and is_same(hit.enemy, enemy_by_id(str(hit.enemy.actor_id)))
func _q2_deliver_enemy_hit(hit: Dictionary) -> void:
 if paused or not _q2_enemy_hit_current(hit): return
 var scope: Dictionary = _ink_scope()
 super.damage_hero(hit.amount, hit.direction, hit.control, hit.is_true, hit.mandatory, hit.metadata)
 if not _ink_scope_current(scope): return
 for impact in hit.impacts:
  super.emit_event(impact.kind, impact.data)
  if not _ink_scope_current(scope): return

func _h02_move_target(vortex: Dictionary, enemy: Dictionary, from_time: float, to_time: float, hold_for_ai: bool) -> void:
 var origin: Vector3 = enemy.position
 var actual_start: float = maxf(maxf(from_time, float(vortex.born_at)), float(vortex.sampled_until.get(str(enemy.actor_id), vortex.born_at)))
 var actual_end: float = minf(to_time, float(vortex.expires_at))
 var nested: bool = not _q2_pull_context.is_empty() and is_same(_q2_pull_context.enemy, enemy)
 # Capture inherited pull before H02 starts, then H02 separately. A round trip
 # is real two-leg movement, never its zero-length start/end chord.
 if nested: _q2_record_motion(enemy, _q2_pull_context.cursor, origin)
 super._h02_move_target(vortex, enemy, from_time, to_time, hold_for_ai)
 _q2_record_motion(enemy, origin, enemy.position, actual_start, actual_end)
 if nested: _q2_pull_context.cursor = enemy.position

func _q2_collect_contacts(before: Dictionary, start: float, end: float) -> Array:
 var contacts: Array = _q2_deferred_contacts.duplicate()
 _q2_deferred_contacts.clear()
 for state in ink_rivers.duplicate():
  if not _q2_current(state): continue
  for enemy in enemies:
   if not _q2_target_current(enemy, state): continue
   var id: String = str(enemy.actor_id)
   if state.hits.has(id) or start >= float(state.expires_at) - TIME_EPS: continue
   var paths: Array = _q2_motion_traces.filter(func(trace): return is_same(trace.enemy, enemy))
   if paths.is_empty(): paths = [{"from":enemy.position, "to":enemy.position}]
   var best: float = INF
   var best_position: Vector3 = enemy.position
   for path in paths:
    var fraction: float = RiverGeometry.entry(path.from, path.to, enemy.radius, state.path, state.width)
    var at: float = lerpf(float(path.get("start", start)), float(path.get("end", end)), fraction) if is_finite(fraction) else INF
    if at < float(state.expires_at) - TIME_EPS and at >= float(state.born_at) - TIME_EPS and at < best:
     best = at; best_position = Vector3(path.from).lerp(path.to, fraction)
   if is_finite(best): contacts.append({"state":state, "enemy":enemy, "time":best, "kind":"river", "tick":0, "position":best_position})
  if bool(state.h04_at_completion):
   var interval: float = T.hex_parameter("H04-4")
   var maximum: int = int(round(T.hex_parameter("H04-1") / interval))
   while int(state.next_sunset_tick) <= maximum:
    var tick: int = int(state.next_sunset_tick)
    var at: float = float(state.born_at) + tick * interval
    if at > end + TIME_EPS: break
    state.next_sunset_tick += 1
    var radius: float = lerpf(T.hex_parameter("H04-2"), T.hex_parameter("H04-3"), clampf((at - float(state.born_at)) / T.hex_parameter("H04-1"), 0.0, 1.0))
    for enemy in enemies:
     if not _q2_target_current(enemy, state): continue
     var id: String = str(enemy.actor_id)
     var position: Vector3 = enemy.position
     if before.has(id) and is_same(before[id].identity, enemy): position = Vector3(before[id].position).lerp(enemy.position, clampf((at - start) / maxf(TIME_EPS, end - start), 0.0, 1.0))
     if Geometry.ground(position - Vector3(state.path.back())).length() <= radius + float(enemy.radius) + Geometry.EPS: contacts.append({"state":state, "enemy":enemy, "time":at, "kind":"sunset", "tick":tick, "position":position})
 contacts.sort_custom(_q2_event_before)
 var batches: Dictionary = {}
 for hit in contacts:
  if hit.has("impact") or hit.has("batch"): continue
  var key: String = str(hit.state.river_id) + ":" + str(hit.kind) + ":" + str(hit.time)
  if not batches.has(key): batches[key] = {}
  hit["batch"] = batches[key]
 return contacts

func _q2_hit_impact(hit: Dictionary) -> Dictionary:
 if hit.has("impact"): return hit.impact
 if not hit.batch.has("impact"): hit.batch["impact"] = _q2_impact_snapshot()
 return hit.batch.impact

func _q2_settle(before: Dictionary, start: float, end: float) -> void:
 if paused: return
 var scope: Dictionary = _ink_scope()
 _q2_dispatch_contacts(_q2_collect_contacts(before, start, end))
 if not _ink_scope_current(scope) or paused: return
 for state in ink_rivers.duplicate():
  if not _q2_current(state): continue
  state.river_expired = end >= float(state.expires_at) - TIME_EPS
  var finish_at: float = maxf(float(state.expires_at), float(state.sunset_expires_at) if state.h04_at_completion else float(state.expires_at))
  if end >= finish_at - TIME_EPS: _q2_finish(state, "expired", finish_at)
 ink_rivers = ink_rivers.filter(func(state): return _q2_valid(state))

func _q2_finish(state: Dictionary, reason: String, at: float) -> void:
 if bool(state.get("retired", false)): return
 state.retired = true
 finish_cast(int(state.cast_id))
 if not effect_is_current(state): return
 var receipt: Dictionary = _q2_public(state).merged({"reason":reason, "finished_at":at}, true)
 ink_q2_finished.append(receipt)
 if ink_q2_finished.size() > 32: ink_q2_finished.pop_front()
 emit_event("ink_q2_finished", receipt)
func _hero_hex_status(id: String) -> Dictionary:
 if id in ["yanguizhou_h03", "yanguizhou_h04"]:
  var active: bool = hero.loadout.q == "q2" and int(hero.ranks.q) > 0
  return {"active":active, "reason":"" if active else "requires_Q2"}
 return super._hero_hex_status(id)
func common_damage_metadata(source: String) -> Dictionary:
 if source in ["q2", "hex_yanguizhou_h04"]: return {"active_skill":true, "basic_attack":false, "direct":source == "q2", "area":true, "hex_generated":source != "q2"}
 return super.common_damage_metadata(source)
func cancel_cast(id: int) -> void:
 if not ink_q2_pending.is_empty() and int(ink_q2_pending.cast_id) == id: ink_q2_pending = {}
 for state in ink_rivers:
  if int(state.cast_id) == id: state.retired = true
 ink_rivers = ink_rivers.filter(func(state): return int(state.cast_id) != id)
 _q2_deferred_contacts = _q2_deferred_contacts.filter(func(hit): return int(hit.state.cast_id) != id)
 super.cancel_cast(id)
func _hero_clear_transients() -> void:
 ink_q2_pending = {}; ink_rivers.clear(); ink_q2_receipts.clear(); ink_q2_finished.clear(); _q2_motion_traces.clear(); _q2_deferred_contacts.clear(); _q2_enemy_hits.clear(); _q2_motion_resume = {}; _q2_resume_from = -1.0; _q2_tick_active = false
 super._hero_clear_transients()
func _hero_victory_pending() -> bool:
 return super._hero_victory_pending() or not ink_q2_pending.is_empty() or not ink_rivers.is_empty()
func _q2_pending_public() -> Dictionary:
 var out: Dictionary = ink_q2_pending.duplicate(true)
 out.erase("context")
 return out
func _q2_public(state: Dictionary) -> Dictionary:
 var out: Dictionary = {}
 for key in ["river_id", "cast_id", "generation", "room_id", "path", "width", "rank", "born_at", "expires_at", "sunset_expires_at", "h04_at_completion", "h03_at_completion", "next_sunset_tick", "river_expired"]: out[key] = state[key]
 out["hit_target_ids"] = state.hits.keys()
 return out.duplicate(true)
func ink_presenter_snapshot() -> Dictionary:
 var out: Dictionary = super.ink_presenter_snapshot()
 out["q2_schema"] = "ink-q2-isolated-source-candidate-1"
 out["q2_input"] = _q2_pending_public()
 out["rivers"] = ink_rivers.map(func(state): return _q2_public(state))
 out["q2_receipts"] = ink_q2_receipts.duplicate(true)
 out["q2_finished"] = ink_q2_finished.duplicate(true)
 return out.duplicate(true)
func _hero_snapshot() -> Dictionary:
 var out: Dictionary = super._hero_snapshot()
 out["ink_foundation_scope"] = "isolated_Q2_H03_H04_candidate_not_ordinary_host"
 out["q2_ordinary_entry_ready"] = false
 return out

func _make_motion(context: Dictionary, path: Array, width: float, speed: float, damage: float, source: String, critical: bool) -> Dictionary:
 var state: Dictionary = super._make_motion(context, path, width, speed, damage, source, critical)
 if source in ["attack", "dash_attack"]:
  state["q2_original_total_range"] = float(state.path_length)
  state["q2_enhanced_once"] = false
 return state

func _q2_projectile_contact(state: Dictionary, origin: Vector3, destination: Vector3, start: float, end: float) -> Dictionary:
 if state.source not in ["attack", "dash_attack"] or bool(state.get("q2_enhanced_once", false)): return {}
 var best: Dictionary = {}
 for river in ink_rivers:
  if not _q2_current(river) or start >= float(river.expires_at) - TIME_EPS: continue
  var fraction: float = RiverGeometry.entry(origin, destination, float(state.width) * .5, river.path, river.width)
  if not is_finite(fraction): continue
  var at: float = lerpf(start, end, fraction)
  if at >= float(river.expires_at) - TIME_EPS or at < float(river.born_at) - TIME_EPS: continue
  if best.is_empty() or at < float(best.time): best = {"river":river, "time":at, "fraction":fraction}
 return best

func _q2_enhance_projectile(state: Dictionary, river: Dictionary, at: float) -> void:
 if not effect_is_current(state) or bool(state.get("retired", false)) or not _q2_current(river) or bool(state.get("q2_enhanced_once", false)): return
 var g01_before: Dictionary = {"path_length":float(state.path_length), "speed":float(state.speed), "enhanced_once":bool(state.get("q2_enhanced_once", false))}
 state.q2_enhanced_once = true # Across ALL rivers and H03 legs, before callback.
 var added: float = float(state.q2_original_total_range) * float(river.range_fraction)
 var path: Array = state.path.duplicate(true)
 var direction: Vector3 = Geometry.frame_at(path, float(state.path_length)).direction
 path[-1] = Vector3(path.back()) + direction * added
 state.path = path; state.path_length = Geometry.path_length(path)
 state.speed = float(state.speed) * (1.0 + float(river.speed_fraction))
 _equipment_effect_committed("q2",river,"q2_projectile_enhanced",{"projectile":state,"before":g01_before,"after":{"path_length":float(state.path_length),"speed":float(state.speed),"enhanced_once":bool(state.q2_enhanced_once)},"source_time":at})
 emit_event("ink_q2_projectile_enhanced", {"projectile_id":state.wave_id, "river_id":river.river_id, "cast_id":state.cast_id, "generation":state.generation, "room_id":state.room_id, "source_time":at, "added_range":added, "speed":state.speed, "range_basis":"original_total_range", "all_rivers_lifetime_applications":1})

func _q2_motion_events(before: Dictionary, tick_start: float, tick_end: float, from_time: float) -> Dictionary:
 var candidates: Array = []
 var advances: Array = []
 for state in ink_basics + ink_waves:
  if not effect_is_current(state) or bool(state.get("retired", false)): continue
  var basic: bool = state.source in ["attack", "dash_attack"]
  var begin: float = maxf(from_time, float(state.released_at))
  var dt: float = maxf(0.0, tick_end - begin)
  var distance: float = float(state.front_distance)
  var to_distance: float = minf(float(state.path_length), distance + float(state.speed) * dt)
  var blocked: bool = false
  var destination: Vector3 = Geometry.frame_at(state.path, to_distance).position
  if basic:
   var clipped: Vector3 = _move_clipped(state.front_position, destination, float(state.width) * .5)
   if clipped.distance_squared_to(destination) > Geometry.EPS * Geometry.EPS:
    to_distance = distance + Vector3(state.front_position).distance_to(clipped); destination = clipped; blocked = true
  var finish_time: float = begin + (to_distance - distance) / maxf(Geometry.EPS, float(state.speed))
  advances.append({"state":state, "from":distance, "to":to_distance, "begin":begin})
  if basic:
   var touch: Dictionary = _q2_projectile_contact(state, state.front_position, destination, begin, finish_time)
   if not touch.is_empty() and (not blocked or float(touch.time) < finish_time - TIME_EPS):
    candidates.append({"kind":"enhance", "state":state, "river":touch.river, "time":touch.time, "segment_index":0})
  for span in Geometry.spans(state.path, distance, to_distance):
   var a: float = begin + (float(span.from) - distance) / maxf(Geometry.EPS, float(state.speed))
   var b: float = begin + (float(span.to) - distance) / maxf(Geometry.EPS, float(state.speed))
   var ua: float = clampf((a - tick_start) / maxf(TIME_EPS, tick_end - tick_start), 0.0, 1.0)
   var ub: float = clampf((b - tick_start) / maxf(TIME_EPS, tick_end - tick_start), 0.0, 1.0)
   for enemy in enemies:
    var id: String = str(enemy.actor_id)
    if enemy.dead or enemy.state == "spawn" or state.hits.has(id) or not before.has(id): continue
    if not is_same(before[id].identity, enemy) or before[id].state == "spawn": continue
    var start: Vector3 = Vector3(before[id].position).lerp(enemy.position, ua)
    var end: Vector3 = Vector3(before[id].position).lerp(enemy.position, ub)
    var u: float = Geometry.moving_front_contact(span.start, span.end, span.direction, state.width, start, end, float(enemy.radius))
    if not is_finite(u): continue
    candidates.append({"kind":"contact", "state":state, "enemy":enemy, "distance":lerpf(float(span.from), float(span.to), u), "position":Vector3(span.start).lerp(span.end, u), "target_position":start.lerp(end, u), "direction":span.direction, "time":lerpf(a, b, u), "segment_index":span.segment_index})
  if blocked or to_distance >= float(state.path_length) - Geometry.EPS:
   candidates.append({"kind":"terminal", "state":state, "time":finish_time, "distance":to_distance, "reason":"blocked" if blocked else "path_end", "segment_index":Geometry.frame_at(state.path, to_distance).segment_index})
 candidates.sort_custom(_q2_motion_before)
 return {"events":candidates, "advances":advances}

func _q2_motion_before(a: Dictionary, b: Dictionary) -> bool:
 return _q2_event_before(a, b)
func _q2_event_before(a: Dictionary, b: Dictionary) -> bool:
 if float(a.time) != float(b.time): return float(a.time) < float(b.time)
 var priority: Dictionary = {"enhance":0, "river":1, "sunset":2, "contact":3, "enemy_hit":4, "terminal":5}
 if a.kind != b.kind: return priority[a.kind] < priority[b.kind]
 if a.kind == "enemy_hit": return str(a.enemy.actor_id) < str(b.enemy.actor_id)
 if a.kind in ["river", "sunset"]:
  return str(a.state.river_id) + ":" + str(a.enemy.actor_id) < str(b.state.river_id) + ":" + str(b.enemy.actor_id)
 return _contact_before(a, b)

func _settle_motion_interval(before: Dictionary, tick_start: float, tick_end: float) -> void:
 var resuming: bool = _q2_resume_from >= 0.0
 if ink_rivers.is_empty() and _q2_enemy_hits.is_empty() and not resuming: super._settle_motion_interval(before, tick_start, tick_end); return
 var scope: Dictionary = _ink_scope()
 var cursor: float = maxf(tick_start, _q2_resume_from) if resuming else tick_start
 _q2_resume_from = -1.0
 var river_contacts: Array = _q2_collect_contacts(before, tick_start, tick_end)
 # Replan after each enhancement/contact/callback. Do not advance a whole tick
 # at old speed, temporarily move targets, or execute extra world/AI ticks.
 # Every zero-time event consumes a target, projectile, or lifetime buff bit.
 while _ink_scope_current(scope):
  if paused:
   _q2_deferred_contacts.append_array(river_contacts)
   _q2_motion_resume = {"before":before, "start":tick_start, "end":tick_end, "cursor":cursor}
   return
  river_contacts = river_contacts.filter(func(hit): return _q2_valid(hit.state) and _q2_target_current(hit.enemy, hit.state) and (hit.kind != "river" or not hit.state.hits.has(str(hit.enemy.actor_id))))
  _q2_enemy_hits = _q2_enemy_hits.filter(func(hit): return _q2_enemy_hit_current(hit))
  _q2_enemy_hits.sort_custom(_q2_event_before)
  var plan: Dictionary = _q2_motion_events(before, tick_start, tick_end, cursor)
  if not river_contacts.is_empty() and (plan.events.is_empty() or _q2_event_before(river_contacts[0], plan.events[0])):
   plan.events.push_front(river_contacts.pop_front())
  if not _q2_enemy_hits.is_empty() and (plan.events.is_empty() or _q2_event_before(_q2_enemy_hits[0], plan.events[0])):
   # A river popped for comparison must stay queued if an earlier hostile hit wins.
   if not plan.events.is_empty() and plan.events[0].kind in ["river", "sunset"]: river_contacts.push_front(plan.events.pop_front())
   plan.events.push_front(_q2_enemy_hits.pop_front())
  var at: float = tick_end if plan.events.is_empty() else maxf(cursor, minf(tick_end, float(plan.events[0].time)))
  for advance in plan.advances:
   var state: Dictionary = advance.state
   if effect_is_current(state) and not bool(state.get("retired", false)):
    _set_front(state, minf(float(advance.to), float(advance.from) + float(state.speed) * maxf(0.0, at - float(advance.begin))))
  if plan.events.is_empty(): break
  var event: Dictionary = plan.events[0]
  var state: Dictionary = event.get("state", {})
  cursor = at
  if event.kind == "enemy_hit": _q2_deliver_enemy_hit(event)
  elif event.kind in ["river", "sunset"]:
   _q2_damage(state, event.enemy, event.time, event.kind, event.tick, event.position, _q2_hit_impact(event))
  elif event.kind == "enhance": _q2_enhance_projectile(state, event.river, at)
  elif event.kind == "terminal": _retire_motion(state, at, event.reason)
  else:
   var enemy: Dictionary = event.enemy
   var id: String = str(enemy.actor_id)
   var basic: bool = state.source in ["attack", "dash_attack"]
   state.hits[id] = true
   if not claim_hit(int(state.cast_id), id, "ink_basic" if basic else "ink_q1"): continue
   var receipt_id: String = str(state.wave_id) + ":contact:" + id
   var receipt: Dictionary = {"receipt_id":receipt_id, "cast_id":state.cast_id, "wave_id":state.wave_id, "target_id":id, "contact_position":event.position, "target_contact_position":event.target_position, "contact_time":at, "direction":event.direction, "segment_index":event.segment_index, "source":state.source, "room_id":room_id, "generation":encounter_generation, "released_at":state.released_at, "path_length":state.path_length, "segment_id":str(state.wave_id) + ":segment:" + str(event.segment_index)}
   var metadata: Dictionary = {"effect_id":receipt_id, "generation":encounter_generation, "room_id":room_id, "position":event.position, "direction":event.direction, "saved_aim":state.direction, "basic_attack":basic, "active_skill":not basic, "area":not basic, "direct":true, "ink_receipt":receipt}
   _equipment_skill_damage("q1",state,enemy, float(state.damage), state.source, int(state.cast_id), false, bool(state.critical), metadata)
   if not _ink_scope_current(scope): return
   if not effect_is_current(state): continue
   if not basic and not enemy.dead:
    var g01_push_before: Dictionary = enemy.push
    push_enemy(enemy, event.direction, float(state.push_distance), "q1", int(state.cast_id), 0.0, float(tuning.q1_push_duration_s), 0.0)
    _equipment_push_bound("q1",state,enemy,g01_push_before,enemy.push)
   if basic: _retire_motion(state, at, "contact")
  if not _ink_scope_current(scope): return
 ink_basics = ink_basics.filter(func(state): return effect_is_current(state) and not bool(state.get("retired", false)))
 ink_waves = ink_waves.filter(func(state): return effect_is_current(state) and not bool(state.get("retired", false)))
