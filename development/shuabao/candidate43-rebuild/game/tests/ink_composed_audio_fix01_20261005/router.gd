extends "res://tests/ink_benchmark_audio_20261004/router.gd"
## New Q3 presentation candidate. Original BASIC/Q1/dash router remains inherited.
## All inputs are deep-detached synchronous producer packets/public snapshots.
const Q3Bank = preload("res://tests/ink_composed_audio_fix01_20261005/bank.gd")
const Feedback = preload("res://tests/ink_q3_visual_20261004/dynamic03/target_feedback.gd")
const Q3_PUBLIC := ["terrain_id","cast_id","generation","room_id","position","axis","length","width","rank","born_at","expires_at","collapse_length","collapse_width","push_distance","h05_at_raise","h06_at_raise","remaining","source_time"]
const Q3_STABLE := ["terrain_id","cast_id","generation","room_id","position","axis","rank","born_at","expires_at","collapse_length","collapse_width","push_distance","h05_at_raise","h06_at_raise"]
const Q3_CONTACT := ["source_event_id","effect_id","terrain_id","cast_id","segment_id","target_id","generation","room_id","source_time","origin","direction","length","width","nominal_damage","target_position","target_radius"]
var q3_raised: Dictionary = {}
var q3_collapsed: Dictionary = {}
var q3_finished: Dictionary = {}
var q3_contacts: Dictionary = {}
var q3_segments: Dictionary = {}
var q3_damage: Array = []
var q3_feedback: RefCounted = Feedback.new()
var q3_coalesced_contacts: int = 0
func _q3_clear_scope() -> void:
 q3_raised.clear(); q3_collapsed.clear(); q3_finished.clear()
 q3_contacts.clear(); q3_segments.clear(); q3_damage.clear()
 q3_feedback = Feedback.new()
func reset() -> Array:
 var output: Array = super.reset()
 _q3_clear_scope()
 return output
func _q3_reject(reason: String, output: Array) -> Array:
 _reject("q3_"+reason)
 return output
func _q3_cue(id: String,event: Dictionary,state: Dictionary,identity: String,point: Vector3,actual: Dictionary = {}) -> Dictionary:
 var variant: int = _variant(identity)
 var command: Dictionary = {"action":"play","id":id,"path":Q3Bank.path_for(id,variant),"variant_index":variant,
  "gain_db":Bank.GAIN_DB,"max_voices":Bank.MAX_VOICES,"loop":false,"pitch_scale":1.0,
  "cast_key":"%s:%d:%s" % [event_room,generation,str(event.cast_id)],"identity":identity,
  "room_id":event_room,"generation":generation,"sequence":int(event.sequence),"source_clock":"hero",
  "source_time":float(event.source_time),"observed_source_time":float(state.source_time),
  "settled_at":float(state.source_time),"world_time":float(event.world_time),
  "receipt_id":str(event.get("source_event_id","")),"wave_id":"","terrain_id":str(event.terrain_id),
  "position":point,"priority":2 if id == "ink_q3_contact" else 1,
  "candidate":"ink_composed_audio_fix01_20261005","contact_mix_policy":"one real positive contact per cast/segment, never one voice per target",
  "actual_damage":actual.get("actual_damage",0.0),"damage_sequence":actual.get("damage_sequence",-1)}
 counts[id] = int(counts.get(id,0))+1
 history.append(command.duplicate(true))
 if history.size()>64: history.pop_front()
 return command
func consume(event: Dictionary,state: Dictionary) -> Array:
 # Let every packet pass through the ORIGINAL schema/rules/scope/retirement/
 # sequence/end fences first. A rejected packet never reaches the extension.
 var previous_room: String = event_room
 var previous_generation: int = generation
 var before_rejected: Dictionary = rejected.duplicate(true)
 var output: Array = super.consume(event,state)
 if rejected != before_rejected: return output
 if event_room != previous_room or generation != previous_generation: _q3_clear_scope()
 if ended: return output
 var kind: String = str(event.get("kind",""))
 if kind == "damage" and event.get("source","") == "q3":
  q3_damage.append(event.duplicate(true))
  if q3_damage.size()>32: q3_damage.pop_front()
  return output
 if kind not in ["ink_q3_raised","ink_q3_collapse_started","ink_q3_contact","ink_q3_finished"]: return output
 if str(state.get("q3_schema","")) != "ink-q3-mechanic-foundation-1": return _q3_reject("snapshot_schema",output)
 if bool(event.get("preview_only",false)): return _q3_reject("preview_packet",output)
 var terrain: String = str(event.get("terrain_id",""))
 var cast: int = int(event.get("cast_id",-1))
 var at: float = float(event.get("source_time",-1.0))
 var now: float = float(state.get("source_time",-1.0))
 if terrain.is_empty() or cast<0 or not is_finite(at) or not is_finite(now) or at<0.0 or absf(at-now)>.00001: return _q3_reject("identity_or_clock",output)
 if kind == "ink_q3_finished":
  if not q3_raised.has(terrain) or not _find_match(event,state.get("q3_finished",[]),Q3_PUBLIC+["reason","finished_at","settled_at"]): return _q3_reject("finish_not_in_snapshot",output)
  _remember(q3_finished,terrain)
  return output
 if q3_finished.has(terrain): return _q3_reject("finished_terrain",output)
 if kind == "ink_q3_raised":
  var mountain: Dictionary = state.get("mountain",{})
  if not _matching(event,mountain,Q3_PUBLIC): return _q3_reject("raise_not_in_snapshot",output)
  if q3_raised.has(terrain): return _q3_reject("duplicate_raise",output)
  _remember(q3_raised,terrain,event.duplicate(true))
  if not paused: output.append(_q3_cue("ink_q3_raise",event,state,terrain+":raise",event.position))
  return output
 if not q3_raised.has(terrain): return _q3_reject("without_raise",output)
 var raised: Dictionary = q3_raised[terrain]
 if cast != int(raised.cast_id): return _q3_reject("cast_mismatch",output)
 if kind == "ink_q3_collapse_started":
  # Source removes its mountain BEFORE this synchronous callback and appends
  # q3_finished AFTER damage. Authenticate against the already confirmed raise,
  # exact retained public fields and the direct source signal; do not invent a
  # nonexistent live row or pretend finished-receipt proof is available here.
  if not _matching(event,raised,Q3_STABLE): return _q3_reject("collapse_identity",output)
  if not state.get("mountain",{}).is_empty(): return _q3_reject("collapse_still_live",output)
  if not event.get("direction") is Vector3 or not event.direction.is_finite() or absf(event.direction.length()-1.0)>.0001: return _q3_reject("collapse_direction",output)
  if event.get("length") != raised.collapse_length or event.get("width") != raised.collapse_width or at<float(raised.born_at) or at>float(raised.expires_at)+.00001: return _q3_reject("collapse_shape_or_time",output)
  if q3_collapsed.has(terrain): return _q3_reject("duplicate_collapse",output)
  _remember(q3_collapsed,terrain,event.duplicate(true))
  if not paused: output.append(_q3_cue("ink_q3_collapse",event,state,terrain+":collapse",event.position))
  return output
 if not _find_match(event,state.get("q3_receipts",[]),Q3_CONTACT): return _q3_reject("contact_not_in_snapshot",output)
 var segment: String = str(event.get("segment_id",""))
 if segment not in ["mountain_raise_burst","mountain_collapse"]: return _q3_reject("contact_segment",output)
 if segment == "mountain_collapse" and not q3_collapsed.has(terrain): return _q3_reject("contact_without_collapse",output)
 if segment == "mountain_raise_burst" and q3_collapsed.has(terrain): return _q3_reject("raise_contact_after_collapse",output)
 var receipt: String = str(event.get("source_event_id",""))
 if receipt.is_empty() or q3_contacts.has(receipt): return _q3_reject("duplicate_contact",output)
 var joined: Array = q3_damage.duplicate(true)
 joined.append(event)
 var confirmed: Array = q3_feedback.project(state,joined)
 if confirmed.size()!=1: return _q3_reject("contact_without_actual_damage",output)
 if q3_feedback._seen.size()>256: q3_feedback._seen.erase(q3_feedback._seen.keys()[0])
 _remember(q3_contacts,receipt)
 var mix_key: String = terrain+":"+segment
 if q3_segments.has(mix_key):
  q3_coalesced_contacts += 1
  return output
 # Consume identity even while paused: unpause never replays old impacts.
 _remember(q3_segments,mix_key)
 if not paused: output.append(_q3_cue("ink_q3_contact",event,state,receipt,event.target_position,confirmed[0]))
 return output
func snapshot() -> Dictionary:
 var result: Dictionary = super.snapshot()
 result["candidate"] = "ink_composed_audio_fix01_20261005"
 result["q3_coalesced_contacts"] = q3_coalesced_contacts
 result["q3_mix"] = "one raise/collapse cue plus at most one actual contact per segment; original four-player global cap"
 return result
