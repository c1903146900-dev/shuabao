extends "res://tests/ink_r2_ordinary_20261006/candidate01/sim.gd"
## Isolated H03 input/H04 sampling successor. Ordinary admission remains closed.
## Every world/AI/common/P1/P2/E1/R1/R2 authority stays in the current parent.
var h04_sample_receipts: Array = []

func _h04_sample_position(member: Dictionary, batch: Dictionary) -> Vector3:
 var enemy: Dictionary = member.enemy
 var state: Dictionary = batch.state
 var jumps: Array = []
 for jump: Dictionary in _qe_jump_history:
  if not is_same(jump.enemy,enemy) or int(jump.generation) != int(state.generation) or str(jump.room_id) != str(state.room_id): continue
  if float(jump.at) >= float(batch.start) and float(jump.at) <= float(batch.end): jumps.append(jump)
 jumps.sort_custom(func(a,b): return int(a.sequence)<int(b.sequence) if float(a.at)==float(b.at) else float(a.at)<float(b.at))
 var cursor: Vector3 = member.origin
 var begin: float = float(batch.start)
 var at: float = float(batch.time)
 var endpoint: Vector3 = member.endpoint
 for jump: Dictionary in jumps:
  if at < float(jump.at):
   return cursor.lerp(jump.from,clampf((at-begin)/maxf(TIME_EPS,float(jump.at)-begin),0.0,1.0))
  # Equality belongs to the committed arrival. Never interpolate the gap.
  cursor = jump.to; begin = float(jump.at)
  # A callback after collection may have replaced the old interval endpoint.
  # At its timestamp only the committed arrival is real, not the old future.
  if int(jump.sequence) > int(member.jump_epoch): endpoint = jump.to
 if float(batch.end) <= begin: return cursor
 return cursor.lerp(endpoint,clampf((at-begin)/maxf(TIME_EPS,float(batch.end)-begin),0.0,1.0))

func _h04_lock_batch(batch: Dictionary) -> void:
 if bool(batch.locked): return
 batch.locked = true
 var state: Dictionary = batch.state
 var radius: float = lerpf(T.hex_parameter("H04-2"),T.hex_parameter("H04-3"),clampf((float(batch.time)-float(state.born_at))/T.hex_parameter("H04-1"),0.0,1.0))
 var sampled: Array = []
 for member: Dictionary in batch.members:
  var enemy: Dictionary = member.enemy
  if not _q2_target_current(enemy,state): continue
  var position: Vector3 = _h04_sample_position(member,batch)
  var inside: bool = Geometry.ground(position-Vector3(state.path.back())).length() <= radius+float(enemy.radius)+Geometry.EPS
  batch.samples[str(enemy.actor_id)] = {"enemy":enemy,"position":position,"inside":inside}
  sampled.append({"target_id":enemy.actor_id,"position":position,"inside":inside})
 # Detached diagnostics, no callback during the atomic snapshot. A pause or
 # later equal-time jump retains this tick's snapshot; later ticks sample anew.
 h04_sample_receipts.append({"river_id":state.river_id,"cast_id":state.cast_id,"generation":state.generation,"room_id":state.room_id,"tick":batch.tick,"source_time":batch.time,"radius":radius,"jump_epoch":_qe_jump_serial,"targets":sampled})
 if h04_sample_receipts.size()>64: h04_sample_receipts.pop_front()

func _q2_hit_impact(hit: Dictionary) -> Dictionary:
 if str(hit.get("kind","")) != "sunset": return super._q2_hit_impact(hit)
 # An old frozen sampler contact cannot silently enter this new leaf.
 if not hit.has("h04_batch"): return {"_h04_sample_current":false}
 var batch: Dictionary = hit.h04_batch
 _h04_lock_batch(batch)
 var out: Dictionary = super._q2_hit_impact(hit)
 var sample: Dictionary = batch.samples.get(str(hit.enemy.actor_id),{})
 out["_h04_sample_current"] = not sample.is_empty() and is_same(sample.enemy,hit.enemy) and bool(sample.inside)
 out["_h04_sample_position"] = sample.get("position",hit.position)
 return out

func _q2_damage(state: Dictionary, enemy: Dictionary, at: float, kind: String, tick: int, position: Vector3, impact: Dictionary) -> void:
 if kind != "sunset":
  super._q2_damage(state,enemy,at,kind,tick,position,impact)
  return
 if not bool(impact.get("_h04_sample_current",false)): return
 var sampled_position: Vector3 = impact._h04_sample_position
 var clean: Dictionary = impact.duplicate(true)
 clean.erase("_h04_sample_current"); clean.erase("_h04_sample_position")
 super._q2_damage(state,enemy,at,kind,tick,sampled_position,clean)

func _hero_clear_transients() -> void:
 h04_sample_receipts.clear()
 super._hero_clear_transients()

func river_hex_fixture_status() -> Dictionary:
 return {"source_candidate":true,"h04_ordering":"committed_jumps_then_atomic_tick_snapshot","h03_input":"Ctrl+fresh_LMB_in_Q2_B_preview","engine":"NOT_RUN","ordinary_admission":false,"p1_hex_ownership":"HOLD_existing_guard_preserved","p2_h04_eligibility":"HOLD_existing_provenance_preserved","native_input":"NOT_RUN","art_audio_accepted":false,"real_multiplayer":false}

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
    # Candidate tickets include outside enemies too. A committed jump before
    # this tick's first dispatch can move one into the circle. Membership is
    # decided atomically at dispatch, never by an obsolete before/after chord.
    var batch: Dictionary = {"state":state,"time":at,"tick":tick,"start":start,"end":end,"members":[],"locked":false,"samples":{}}
    for enemy in enemies:
     if not _q2_target_current(enemy,state): continue
     var id: String = str(enemy.actor_id)
     var origin: Vector3 = enemy.position
     if before.has(id) and is_same(before[id].identity,enemy): origin = before[id].position
     batch.members.append({"enemy":enemy,"origin":origin,"endpoint":enemy.position,"jump_epoch":_qe_jump_serial})
     contacts.append({"state":state,"enemy":enemy,"time":at,"kind":"sunset","tick":tick,"position":enemy.position,"batch":batch,"h04_batch":batch})
 contacts.sort_custom(_q2_event_before)
 var batches: Dictionary = {}
 for hit in contacts:
  if hit.has("impact") or hit.has("batch"): continue
  var key: String = str(hit.state.river_id) + ":" + str(hit.kind) + ":" + str(hit.time)
  if not batches.has(key): batches[key] = {}
  hit["batch"] = batches[key]
 return contacts


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
 # H04 tickets are sampled lazily as one atomic batch. This leaf therefore
 # replaces the old unresolved-sampler diagnostic, not E3 landing authority.
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
