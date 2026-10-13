extends "res://tests/ink_e3_ordinary_20261006/ordinary01/e3_base.gd"
## Only discontinuity seams. Current Q1/Q2 ordered solver, P1 batch barriers,
## R1/E1 hostile-hit delivery and every world/AI/common step remain inherited.
var _qe_jumps: Array = []
var _qe_jump_history: Array = []
var _qe_jump_serial: int = 0
var _qe_return_capture: Dictionary = {}
var _qe_motion_frames: Array = []
var _qe_tick_begin: float = -1.0
var ink_qe_discontinuities: Array = []
var ink_qe_holds: Array = []

func _qe_prepare_tick(start: float) -> void:
 if _qe_tick_begin == start: return
 _qe_tick_begin = start
 _qe_jumps.clear()

func _fixed_step(real_dt: float) -> void:
 if _q2_motion_resume.is_empty(): _qe_prepare_tick(hero_time)
 super._fixed_step(real_dt)

func _settle_motion_interval(before: Dictionary, tick_start: float, tick_end: float) -> void:
 _qe_prepare_tick(tick_start)
 # Select the existing resumable solver when only a jump requires it. This
 # keeps the actual P1 interval wrapper and endpoint repair in the call chain.
 if not _qe_jumps.is_empty() and _q2_resume_from < 0.0: _q2_resume_from = tick_start
 super._settle_motion_interval(before,tick_start,tick_end)

func emit_event(kind: String, data: Dictionary = {}) -> void:
 var scope: Dictionary = _ink_scope()
 if kind == "ink_e3_exchanged": _qe_observe_exchange(data)
 elif kind == "ink_e3_returned": _qe_observe_return(data)
 if kind in ["ink_e3_exchanged","ink_e3_returned"] and not _ink_scope_current(scope): return
 super.emit_event(kind,data)

func _qe_push_motion(enemy: Dictionary, kind: String) -> Dictionary:
 if _q2_tick_active: _qe_prepare_tick(_q2_tick_start)
 var frame: Dictionary = {"enemy":enemy,"kind":kind,"sequence":_qe_jump_serial}
 _qe_motion_frames.append(frame)
 return frame

func _qe_pop_motion(frame: Dictionary) -> void:
 if not _qe_motion_frames.is_empty() and is_same(_qe_motion_frames.back(),frame): _qe_motion_frames.pop_back()

func _step_pull(enemy: Dictionary, dt: float) -> void:
 var frame: Dictionary = _qe_push_motion(enemy,"pull")
 super._step_pull(enemy,dt)
 _qe_pop_motion(frame)

func _step_push(enemy: Dictionary, dt: float) -> void:
 var frame: Dictionary = _qe_push_motion(enemy,"push")
 super._step_push(enemy,dt)
 _qe_pop_motion(frame)

func _step_enemy(enemy: Dictionary, dt: float) -> void:
 var frame: Dictionary = _qe_push_motion(enemy,"enemy")
 super._step_enemy(enemy,dt)
 _qe_pop_motion(frame)

func _h02_move_target(vortex: Dictionary, enemy: Dictionary, from_time: float, to_time: float, hold_for_ai: bool) -> void:
 var frame: Dictionary = _qe_push_motion(enemy,"h02")
 super._h02_move_target(vortex,enemy,from_time,to_time,hold_for_ai)
 _qe_pop_motion(frame)
 # The inherited pull cursor has now advanced past this real H02 leg.
 for i in range(_qe_motion_frames.size()-1,-1,-1):
  var prior: Dictionary = _qe_motion_frames[i]
  if is_same(prior.enemy,enemy) and prior.kind == "pull":
   prior.sequence = _qe_jump_serial
   break

func _q2_record_motion(enemy: Dictionary, origin: Vector3, destination: Vector3, begin: float = -1.0, end: float = -1.0) -> void:
 if not _q2_tick_active: return
 _qe_prepare_tick(_q2_tick_start)
 var sequence: int = -1
 for i in range(_qe_motion_frames.size()-1,-1,-1):
  var frame: Dictionary = _qe_motion_frames[i]
  if not is_same(frame.enemy,enemy): continue
  # Q2's H02 pre-leg callback first flushes the prior pull cursor.
  if frame.kind == "h02" and begin < 0.0: continue
  sequence = int(frame.sequence)
  break
 var start: float = _q2_tick_start if begin < 0.0 else begin
 var finish: float = hero_time if end < 0.0 else end
 for leg in _qe_motion_legs(enemy,origin,destination,start,finish,sequence):
  if Vector3(leg.from).distance_squared_to(leg.to) > Geometry.EPS * Geometry.EPS:
   _q2_motion_traces.append(leg.merged({"enemy":enemy},true))

func _q2_hit_impact(hit: Dictionary) -> Dictionary:
 var out: Dictionary = super._q2_hit_impact(hit).duplicate(true)
 # Both inherited dispatch paths call this immediately before _q2_damage.
 # Attach observation validity without replacing their P1 or pause barriers.
 out["_qe_contact_current"] = _qe_queued_river_current(hit)
 return out

func _q2_damage(state: Dictionary, enemy: Dictionary, at: float, kind: String, tick: int, position: Vector3, impact: Dictionary) -> void:
 if not bool(impact.get("_qe_contact_current",true)): return
 var clean: Dictionary = impact.duplicate(true)
 clean.erase("_qe_contact_current")
 super._q2_damage(state,enemy,at,kind,tick,position,clean)

func _hero_clear_transients() -> void:
 _qe_jumps.clear(); _qe_jump_history.clear(); _qe_return_capture={}; _qe_motion_frames.clear(); _qe_tick_begin=-1.0
 ink_qe_discontinuities.clear(); ink_qe_holds.clear()
 super._hero_clear_transients()

func _q2_birth_contacts(state: Dictionary) -> void:
 var contacts: Array = []
 var impact: Dictionary = _q2_impact_snapshot()
 for enemy in enemies.duplicate():
  if _q2_target_current(enemy, state) and RiverGeometry.overlaps(enemy.position, enemy.radius, state.path, state.width):
   contacts.append({"state":state, "enemy":enemy, "time":hero_time, "kind":"river", "tick":0, "position":enemy.position, "impact":impact,"contact_authority":"realized_birth","qe_jump_epoch":_qe_jump_serial})
 _q2_dispatch_contacts(contacts)

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
    if bool(path.get("end_exclusive",false)) and at >= float(path.end): continue
    if at < float(state.expires_at) - TIME_EPS and at >= float(state.born_at) - TIME_EPS and at < best:
     best = at; best_position = Vector3(path.from).lerp(path.to, fraction)
   if is_finite(best): contacts.append({"state":state, "enemy":enemy, "time":best, "kind":"river", "tick":0, "position":best_position,"contact_authority":"swept_trace","qe_jump_epoch":_qe_jump_serial})
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

func _q2_motion_events(before: Dictionary, tick_start: float, tick_end: float, from_time: float) -> Dictionary:
 if _qe_jumps.is_empty(): return super._q2_motion_events(before,tick_start,tick_end,from_time)
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
   for enemy in enemies:
    var id: String = str(enemy.actor_id)
    if enemy.dead or enemy.state == "spawn" or state.hits.has(id) or not before.has(id): continue
    if not is_same(before[id].identity, enemy) or before[id].state == "spawn": continue
    # Clip both moving fronts to each actual continuous leg; never interpolate
    # an enemy through the empty space between E3/H12 teleport endpoints.
    for leg in _qe_motion_legs(enemy, before[id].position, enemy.position, tick_start, tick_end):
     var lo: float = maxf(a, float(leg.start)); var hi: float = minf(b, float(leg.end))
     if hi < lo: continue
     var front_lo: float = clampf((lo-a)/maxf(TIME_EPS,b-a),0,1)
     var front_hi: float = clampf((hi-a)/maxf(TIME_EPS,b-a),0,1)
     var front_start: Vector3 = Vector3(span.start).lerp(span.end,front_lo)
     var front_end: Vector3 = Vector3(span.start).lerp(span.end,front_hi)
     var start: Vector3 = _qe_leg_position(leg,lo)
     var end: Vector3 = _qe_leg_position(leg,hi)
     var u: float = Geometry.moving_front_contact(front_start,front_end,span.direction,state.width,start,end,float(enemy.radius))
     if not is_finite(u): continue
     var contact_at: float = lerpf(lo,hi,u)
     if bool(leg.get("end_exclusive",false)) and contact_at >= float(leg.end): continue
     var source_u: float = lerpf(front_lo,front_hi,u)
     candidates.append({"kind":"contact", "state":state, "enemy":enemy, "distance":lerpf(float(span.from), float(span.to), source_u), "position":front_start.lerp(front_end,u), "target_position":start.lerp(end,u), "direction":span.direction, "time":contact_at, "segment_index":span.segment_index})
  if blocked or to_distance >= float(state.path_length) - Geometry.EPS:
   candidates.append({"kind":"terminal", "state":state, "time":finish_time, "distance":to_distance, "reason":"blocked" if blocked else "path_end", "segment_index":Geometry.frame_at(state.path, to_distance).segment_index})
 candidates.sort_custom(_q2_motion_before)
 return {"events":candidates, "advances":advances}

func _e3_return(state: Dictionary) -> Dictionary:
 var prior: Dictionary = _qe_return_capture
 var captured: Dictionary = {"state":state,"members":_e3_return_plan(state) if _e3_live(state) else [],"scope":_ink_scope()}
 _qe_return_capture = captured
 var result: Dictionary = super._e3_return(state)
 if is_same(_qe_return_capture,captured): _qe_return_capture = prior if _ink_scope_current(captured.scope) else {}
 return result

func _qe_observe_exchange(data: Dictionary) -> void:
 if ink_frames.is_empty() or int(ink_frames.cast_id) != int(data.get("cast_id",0)) or not _e3_context_current(ink_frames): return
 _qe_record_jumps(ink_frames,ink_frames.members,"e3_exchange")

func _qe_observe_return(data: Dictionary) -> void:
 if _qe_return_capture.is_empty() or not _ink_scope_current(_qe_return_capture.scope): return
 var state: Dictionary = _qe_return_capture.state
 if int(state.cast_id) != int(data.get("cast_id",0)) or not _e3_context_current(state): return
 _qe_record_jumps(state,_qe_return_capture.members,"h12_return")

func _qe_record_jumps(state: Dictionary, members: Array, source: String) -> void:
 var scope: Dictionary = _ink_scope()
 var realized: Array = []
 for member in members:
  if member.team != "enemy" or not _e3_entry_current(member,state): continue
  var enemy: Dictionary = member.actor
  var origin: Vector3 = member.from; var destination: Vector3 = enemy.position
  if origin.distance_squared_to(destination) <= Geometry.EPS * Geometry.EPS: continue
  _qe_jump_serial += 1
  var jump: Dictionary = {"enemy":enemy,"from":origin,"to":destination,"at":hero_time,"sequence":_qe_jump_serial,"source":source,"cast_id":state.cast_id,"room_id":room_id,"generation":encounter_generation}
  _qe_jumps.append(jump); _qe_jump_history.append(jump); realized.append(jump)
  _qe_split_prior_traces(jump)
  ink_qe_discontinuities.append({"target_id":enemy.actor_id,"from":origin,"to":destination,"source_time":hero_time,"source":source,"cast_id":state.cast_id,"generation":encounter_generation,"room_id":room_id,"continuous_motion":false})
 # All atomically moved positions are recorded before immediate arrival hits can
 # reenter. Arrival is real touch; the absent teleport path is never a trace.
 for river in ink_rivers.duplicate():
  if bool(river.get("h04_at_completion",false)) and _q2_current(river):
   ink_qe_holds.append({"reason":"H04_discontinuity_sampling_unresolved","river_id":river.river_id,"source_time":hero_time,"source_cast_id":state.cast_id,"production_admission":false})
 var contacts: Array = []
 for river in ink_rivers.duplicate():
  if not _q2_current(river) or hero_time >= float(river.expires_at) - TIME_EPS: continue
  var impact: Dictionary = _q2_impact_snapshot()
  for jump in realized:
   var enemy: Dictionary = jump.enemy
   if not _q2_target_current(enemy,river) or river.hits.has(str(enemy.actor_id)): continue
   if not is_finite(RiverGeometry.entry(jump.to,jump.to,enemy.radius,river.path,river.width)): continue
   contacts.append({"state":river,"enemy":enemy,"time":hero_time,"kind":"river","tick":0,"position":jump.to,"impact":impact,"contact_authority":"realized_arrival","qe_jump_epoch":_qe_jump_serial})
 contacts.sort_custom(_q2_event_before)
 if _ink_scope_current(scope): _q2_dispatch_contacts(contacts)

func _qe_motion_legs(enemy: Dictionary, origin: Vector3, destination: Vector3, start: float, end: float, after_sequence: int = -1) -> Array:
 var jumps: Array = []
 for jump in _qe_jumps:
  if is_same(jump.enemy,enemy) and int(jump.sequence) > after_sequence and float(jump.at) >= start and float(jump.at) <= end and int(jump.generation) == encounter_generation and str(jump.room_id) == room_id: jumps.append(jump)
 if jumps.is_empty(): return [{"from":origin,"to":destination,"start":start,"end":end,"end_exclusive":false}]
 jumps.sort_custom(func(a,b):return int(a.sequence)<int(b.sequence) if float(a.at)==float(b.at) else float(a.at)<float(b.at))
 var legs: Array = []
 var cursor: Vector3 = origin; var at: float = start
 for jump in jumps:
  if float(jump.at) > at: legs.append({"from":cursor,"to":jump.from,"start":at,"end":jump.at,"end_exclusive":true})
  cursor = jump.to; at = float(jump.at)
 if end > at: legs.append({"from":cursor,"to":destination,"start":at,"end":end,"end_exclusive":false})
 else: legs.append({"from":destination,"to":destination,"start":end,"end":end,"end_exclusive":false})
 return legs

func _qe_leg_position(leg: Dictionary, at: float) -> Vector3:
 if float(leg.end) <= float(leg.start): return leg.to
 return Vector3(leg.from).lerp(leg.to,clampf((at-float(leg.start))/(float(leg.end)-float(leg.start)),0.0,1.0))

func _qe_queued_river_current(hit: Dictionary) -> bool:
 if str(hit.get("kind","")) != "river": return true # H04 remains outside this repair.
 var authority: String = str(hit.get("contact_authority",""))
 if authority in ["realized_birth","realized_arrival"]: return true
 # A predicted trace needs the exact observation epoch that produced it.
 if authority != "swept_trace" or not hit.has("qe_jump_epoch"): return false
 for jump in _qe_jump_history:
  if not is_same(jump.enemy,hit.enemy) or int(jump.sequence) <= int(hit.qe_jump_epoch): continue
  if int(jump.generation) != int(hit.state.generation) or str(jump.room_id) != str(hit.state.room_id): continue
  if float(hit.time) >= float(jump.at): return false
 return true

func _qe_split_prior_traces(jump: Dictionary) -> void:
 var kept: Array = []
 for trace in _q2_motion_traces:
  if not is_same(trace.enemy,jump.enemy) or float(trace.end) < float(jump.at):
   kept.append(trace)
   continue
  if float(trace.start) >= float(jump.at): continue
  var clipped: Dictionary = trace.duplicate(false)
  # Re-sample BEFORE shortening the interval, not just its time field.
  clipped.to = _qe_leg_position(trace,float(jump.at))
  clipped.end = float(jump.at)
  clipped.end_exclusive = true
  kept.append(clipped)
 _q2_motion_traces = kept

