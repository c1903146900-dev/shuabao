extends "res://tests/ink_p1_ordinary_20261006/candidate01/settlement.gd"
## Exact current-parent P1 mechanism leaf. Q1 lifecycle copied from tested c2;
## Q2 lifecycle is new and requires its own finite evidence. No UI promotion.
var _p1_q1_waves: Dictionary = {}
var _p1_q1_terminal_frames: Array = []
var _p1_q1_order_frames: Array = []
var ink_q1_endpoint_time_fixes: Array = []
var _p1_q2_rivers: Dictionary = {}
var _p1_q2_terminal_frames: Array = []

func _make_motion(context: Dictionary, path: Array, width: float, speed: float, damage: float, source: String, critical: bool) -> Dictionary:
 var state: Dictionary = super._make_motion(context,path,width,speed,damage,source,critical)
 if source == "q1" and p1.roots.has(int(context.cast_id)) and _p1_current(p1.roots[int(context.cast_id)]) and str(p1.roots[int(context.cast_id)].context.candidate) == "q1":
  var id: int = int(context.cast_id)
  if _p1_q1_waves.has(id):
   # The pinned Q1 emits one physical wave per root. An unsupported duplicate
   # cannot make the first wave falsely prove all future damage is over.
   p1.cancel(id); _p1_q1_waves.erase(id)
  else: _p1_q1_waves[id] = state
 return state

func _p1_q1_owned_wave(state: Dictionary) -> bool:
 var id: int = int(state.get("cast_id",0))
 return state.get("source","") == "q1" and _p1_q1_waves.has(id) and is_same(_p1_q1_waves[id],state) and p1.roots.has(id) and str(p1.roots[id].context.candidate) == "q1" and _p1_current(p1.roots[id])

func _p1_q1_at_endpoint(state: Dictionary) -> bool:
 return not state.path.is_empty() and float(state.front_distance) >= float(state.path_length) - Geometry.EPS and Vector3(state.front_position).distance_to(state.path.back()) <= Geometry.EPS

func _retire_motion(state: Dictionary, at: float, reason: String) -> void:
 if not _p1_q1_owned_wave(state) or bool(state.get("retired",false)):
  super._retire_motion(state,at,reason)
  return
 var id: int = int(state.cast_id)
 if reason != "path_end" or not _p1_q1_at_endpoint(state):
  # An abort or an invalid terminal indication is not a successful whole-damage
  # milestone. Do not manufacture P1 from generic core finish_cast.
  p1.cancel(id); _p1_q1_waves.erase(id)
  super._retire_motion(state,at,reason)
  return
 var frame: Dictionary = {"state":state,"cast_id":id,"wave_id":state.wave_id,"seen":false}
 _p1_q1_terminal_frames.append(frame)
 p1.enter(id)
 super._retire_motion(state,at,reason)
 if not _p1_q1_terminal_frames.is_empty() and is_same(_p1_q1_terminal_frames.back(),frame): _p1_q1_terminal_frames.pop_back()
 if _p1_q1_waves.has(id) and is_same(_p1_q1_waves[id],state): _p1_q1_waves.erase(id)
 p1.leave(id); _p1_flush(id)

func emit_event(kind: String, data: Dictionary = {}) -> void:
 if kind == "ink_q2_river_created": _p1_bind_q2_river(data)
 if kind == "ink_q2_placement_expired": p1.cancel(int(data.get("cast_id",0)))
 var milestone: int = _p1_q2_terminal_milestone(kind,data)
 if kind == "ink_q1_finished" and not _p1_q1_terminal_frames.is_empty():
  var frame: Dictionary = _p1_q1_terminal_frames.back()
  var state: Dictionary = frame.state
  if not bool(frame.seen) and int(data.get("cast_id",0)) == int(frame.cast_id) and str(data.get("wave_id","")) == str(frame.wave_id) and str(data.get("reason","")) == "path_end" and str(data.get("source","")) == "q1" and int(data.get("generation",-1)) == int(state.generation) and str(data.get("room_id","")) == str(state.room_id) and str(state.wave_id) == str(frame.wave_id) and bool(state.get("retired",false)) and _p1_q1_owned_wave(state) and _p1_q1_at_endpoint(state):
   frame.seen = true; milestone = int(frame.cast_id)
   p1.enter(milestone); p1.complete(milestone)
 super.emit_event(kind,data)
 if milestone != 0: p1.leave(milestone); _p1_flush(milestone)

func _settle_motion_interval(before: Dictionary, tick_start: float, tick_end: float) -> void:
 # The actual gate01 exposed legacy dispatch claiming contacts after a pause.
 # For a live P1-owned Q1, use the inherited resumable interval solver. This is
 # the REAL start cursor of this already-admitted interval, not a fake river,
 # hit, elapsed step or saved remainder. Q2 consumes _q2_resume_from to -1 at
 # entry; only an actual callback pause then creates _q2_motion_resume.
 if _q2_resume_from < 0.0 and ink_rivers.is_empty() and _q2_enemy_hits.is_empty():
  for wave in ink_waves:
   if not bool(wave.get("retired",false)) and _p1_q1_owned_wave(wave) and not bool(p1.roots[int(wave.cast_id)].settled):
    _q2_resume_from = tick_start
    break
 # Only the pinned legacy fallback has the unequal arithmetic forms diagnosed
 # in actual Godot. The existing Q2 ordered solver already shares its end time.
 var legacy: bool = ink_rivers.is_empty() and _q2_enemy_hits.is_empty() and _q2_resume_from < 0.0
 var order_frame: Dictionary = {"scope":_ink_scope(),"enabled":legacy,"endpoints":[]}
 if legacy:
  for wave in ink_waves:
   if wave.source != "q1" or not effect_is_current(wave) or bool(wave.get("retired",false)): continue
   var begin: float = maxf(tick_start,float(wave.released_at))
   var distance: float = float(wave.front_distance)
   var end: float = minf(float(wave.path_length),distance+float(wave.speed)*maxf(0.0,tick_end-begin))
   if end == float(wave.path_length):
    order_frame.endpoints.append({"wave":wave,"distance":end,"time":begin+(end-distance)/float(wave.speed)})
 _p1_q1_order_frames.append(order_frame)
 # The terminal event can share an exact source time with multiple contacts.
 # Hold the entire inherited interval; never pay between two queued targets.
 var held: Array = []
 for id in p1.roots.keys():
  var state: Dictionary = p1.roots[id]
  if str(state.context.candidate) in ["q1","q2"] and not bool(state.settled) and _p1_current(state):
   held.append(int(id)); p1.enter(int(id))
 super._settle_motion_interval(before,tick_start,tick_end)
 if not _p1_q1_order_frames.is_empty() and is_same(_p1_q1_order_frames.back(),order_frame): _p1_q1_order_frames.pop_back()
 for id in held: p1.leave(int(id)); _p1_flush(int(id))

func cancel_cast(id: int) -> void:
 _p1_q2_rivers.erase(id)
 _p1_q2_terminal_frames = _p1_q2_terminal_frames.filter(func(frame):return int(frame.cast_id) != id)
 _p1_q1_waves.erase(id)
 _p1_q1_terminal_frames = _p1_q1_terminal_frames.filter(func(frame):return int(frame.cast_id) != id)
 super.cancel_cast(id)

func _hero_clear_transients() -> void:
 _p1_q2_rivers.clear(); _p1_q2_terminal_frames.clear()
 _p1_q1_waves.clear(); _p1_q1_terminal_frames.clear(); _p1_q1_order_frames.clear(); ink_q1_endpoint_time_fixes.clear()
 super._hero_clear_transients()


func _contact_before(a: Dictionary, b: Dictionary) -> bool:
 _p1_q1_normalize_endpoint_time(a)
 _p1_q1_normalize_endpoint_time(b)
 # Original strict comparator and its contact-before-terminal exact-tie rule.
 return super._contact_before(a,b)

func _p1_q1_normalize_endpoint_time(candidate: Dictionary) -> void:
 if _p1_q1_order_frames.is_empty() or str(candidate.get("kind","")) not in ["contact","terminal"]: return
 var frame: Dictionary = _p1_q1_order_frames.back()
 if not bool(frame.enabled) or not _ink_scope_current(frame.scope): return
 var wave: Dictionary = candidate.get("state",{})
 if wave.get("source","") != "q1": return
 for endpoint in frame.endpoints:
  # Exact represented distance equality, never a time EPS or collision change.
  if not is_same(wave,endpoint.wave) or float(candidate.get("distance",-1.0)) != float(endpoint.distance): continue
  if float(candidate.time) != float(endpoint.time):
   ink_q1_endpoint_time_fixes.append({"wave_id":wave.wave_id,"cast_id":wave.cast_id,"kind":candidate.kind,"distance":candidate.distance,"raw_time":candidate.time,"canonical_time":endpoint.time,"raw_bits":PackedFloat64Array([float(candidate.time)]).to_byte_array().hex_encode(),"canonical_bits":PackedFloat64Array([float(endpoint.time)]).to_byte_array().hex_encode()})
   # Each event gets the same independent, idempotent key before comparison.
   # Mutate the real queued receipt time too, so dispatch evidence is consistent.
   candidate.time = float(endpoint.time)
  return


func _p1_bind_q2_river(data: Dictionary) -> void:
 var id: int = int(data.get("cast_id",0))
 if not p1.roots.has(id) or not _p1_current(p1.roots[id]) or str(p1.roots[id].context.candidate) != "q2": return
 var matched: Dictionary = {}
 for state in ink_rivers:
  if int(state.cast_id) != id or str(state.river_id) != str(data.get("river_id","")) or not _q2_current(state): continue
  if not matched.is_empty() or _p1_q2_rivers.has(id):
   p1.cancel(id); _p1_q2_rivers.erase(id); return
  matched = state
 if matched.is_empty(): return
 # Existing ordinary admission excludes H03/H04. Do not silently admit their
 # alternate path/sunset damage semantics through this base-P1 implementation.
 if bool(matched.h03_at_completion) or bool(matched.h04_at_completion):
  p1.cancel(id); return
 _p1_q2_rivers[id] = matched

func _p1_q2_owned_river(state: Dictionary) -> bool:
 var id: int = int(state.get("cast_id",0))
 return _p1_q2_rivers.has(id) and is_same(_p1_q2_rivers[id],state) and p1.roots.has(id) and str(p1.roots[id].context.candidate) == "q2" and _p1_current(p1.roots[id])

func _p1_packet_allowed(source: String, id: int, metadata: Dictionary) -> bool:
 if not super._p1_packet_allowed(source,id,metadata): return false
 if source != "q2": return true
 if not _p1_q2_rivers.has(id) or not _p1_q2_owned_river(_p1_q2_rivers[id]): return false
 var state: Dictionary = _p1_q2_rivers[id]
 var receipt: Dictionary = metadata.get("q2_receipt",{})
 return str(receipt.get("river_id","")) == str(state.river_id) and int(receipt.get("cast_id",0)) == id and int(receipt.get("generation",-1)) == int(state.generation) and str(receipt.get("room_id","")) == str(state.room_id) and str(receipt.get("kind","")) == "river"

func _q2_finish(state: Dictionary, reason: String, at: float) -> void:
 if not _p1_q2_owned_river(state) or bool(state.get("retired",false)):
  super._q2_finish(state,reason,at); return
 var id: int = int(state.cast_id)
 # A genuine base-river expiry ends all of this river's damage. A first-marker
 # timeout, abort, or fabricated early terminal cannot supply this milestone.
 if reason != "expired" or at != float(state.expires_at) or hero_time < float(state.expires_at)-TIME_EPS:
  p1.cancel(id); _p1_q2_rivers.erase(id)
  super._q2_finish(state,reason,at); return
 var frame: Dictionary = {"state":state,"cast_id":id,"river_id":state.river_id,"seen":false}
 _p1_q2_terminal_frames.append(frame); p1.enter(id)
 super._q2_finish(state,reason,at)
 if not _p1_q2_terminal_frames.is_empty() and is_same(_p1_q2_terminal_frames.back(),frame): _p1_q2_terminal_frames.pop_back()
 if _p1_q2_rivers.has(id) and is_same(_p1_q2_rivers[id],state): _p1_q2_rivers.erase(id)
 p1.leave(id); _p1_flush(id)

func _p1_q2_terminal_milestone(kind: String, data: Dictionary) -> int:
 if kind != "ink_q2_finished" or _p1_q2_terminal_frames.is_empty(): return 0
 var frame: Dictionary = _p1_q2_terminal_frames.back()
 var state: Dictionary = frame.state
 if bool(frame.seen) or not _p1_q2_owned_river(state) or not bool(state.get("retired",false)): return 0
 if int(data.get("cast_id",0)) != int(frame.cast_id) or str(data.get("river_id","")) != str(frame.river_id) or str(data.get("reason","")) != "expired" or float(data.get("finished_at",-1.0)) != float(state.expires_at) or int(data.get("generation",-1)) != int(state.generation) or str(data.get("room_id","")) != str(state.room_id): return 0
 frame.seen = true
 var id: int = int(frame.cast_id)
 p1.enter(id); p1.complete(id)
 return id

func _q2_dispatch_contacts(contacts: Array) -> void:
 # Includes immediate activation contacts and queued contacts resumed after a
 # pause. Keep the complete real batch behind the same one-shot payment gate.
 var held: Array = []
 for id in p1.roots.keys():
  var state: Dictionary = p1.roots[id]
  if str(state.context.candidate) == "q2" and not bool(state.settled) and _p1_current(state):
   held.append(int(id)); p1.enter(int(id))
 super._q2_dispatch_contacts(contacts)
 for id in held: p1.leave(int(id)); _p1_flush(int(id))
