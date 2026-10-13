extends "res://tests/ink_composed_audio_fix01_20261005/router.gd"
## Detached E1 audio only. Original Q1/Q3/BASIC/Shift and voice budget inherit.
const E1_ROOT := "res://tests/ink_e1_audio_20261008/candidate01/wav/"
const E1_STABLE := ["form_id","cast_id","generation","room_id","rank","born_at","expires_at","damage_reduction","speed_bonus","mark_limit","radius","base_damage","bonus_damage","h07_at_entry","h08_at_entry"]
const E1_CONTACT := ["source_event_id","effect_id","form_id","cast_id","segment_id","target_id","generation","room_id","source_time","settled_at","position","nominal_damage","actual_damage"]
var e1_entered: Dictionary = {}
var e1_reformed: Dictionary = {}
var e1_finished: Dictionary = {}
var e1_contacts: Dictionary = {}
var e1_mix: Dictionary = {}
var e1_damage: Array = []
var e1_coalesced: int = 0
func _e1_clear() -> void:
 e1_entered.clear(); e1_reformed.clear(); e1_finished.clear(); e1_contacts.clear(); e1_mix.clear(); e1_damage.clear()
func reset() -> Array:
 var result: Array = super.reset()
 _e1_clear()
 return result
func _e1_reject(reason: String, output: Array) -> Array:
 _reject("e1_" + reason)
 return output
func _e1_cue(id: String, event: Dictionary, state: Dictionary, identity: String, at: float, point: Vector3, damage: float = 0.0) -> Dictionary:
 var variant: int = _variant(identity)
 var command: Dictionary = {"action":"play","id":id,"path":E1_ROOT+id+("_a.wav" if variant==0 else "_b.wav"),"variant_index":variant,"gain_db":Bank.GAIN_DB,"max_voices":Bank.MAX_VOICES,"loop":false,"pitch_scale":1.0,"cast_key":"%s:%d:%s" % [event_room,generation,str(event.cast_id)],"identity":identity,"room_id":event_room,"generation":generation,"sequence":int(event.sequence),"source_clock":"hero","source_time":at,"observed_source_time":float(state.source_time),"settled_at":float(state.source_time),"world_time":float(event.world_time),"position":point,"priority":2 if id=="ink_e1_contact" else 1,"form_id":event.form_id,"actual_damage":damage,"candidate":"ink_e1_audio_20261008","mix_policy":"one enter, one reform even on miss, one positive contact per cast"}
 counts[id]=int(counts.get(id,0))+1
 history.append(command.duplicate(true))
 if history.size()>64: history.pop_front()
 return command
func consume(event: Dictionary, state: Dictionary) -> Array:
 var old_room: String = event_room
 var old_gen: int = generation
 var before: Dictionary = rejected.duplicate(true)
 var output: Array = super.consume(event,state)
 if before != rejected: return output
 if old_room != event_room or old_gen != generation: _e1_clear()
 if ended: return output
 var kind: String = str(event.get("kind",""))
 if kind=="damage" and event.get("source","")=="e1":
  e1_damage.append(event.duplicate(true))
  if e1_damage.size()>128: e1_damage.pop_front()
  return output
 if kind not in ["ink_e1_entered","ink_e1_reform_started","ink_e1_contact","ink_e1_finished"]: return output
 if state.get("e1_schema","")!="ink-e1-source-foundation-1": return _e1_reject("snapshot_schema",output)
 if bool(event.get("preview_only",false)): return _e1_reject("preview",output)
 var form: String = str(event.get("form_id",""))
 var cast: int = int(event.get("cast_id",-1))
 var now: float = float(state.get("source_time",-1.0))
 if form.is_empty() or cast<0 or not is_finite(now) or now<0.0: return _e1_reject("identity_clock",output)
 if kind=="ink_e1_entered":
  var rain: Dictionary = state.get("rain",{})
  if not _matching(event,rain,E1_STABLE+["mark_target_ids","remaining"]): return _e1_reject("entry_not_in_snapshot",output)
  if e1_entered.has(form): return _e1_reject("duplicate_entry",output)
  var at: float = float(event.born_at)
  if not is_finite(at) or absf(at-now)>.00001: return _e1_reject("entry_time",output)
  _remember(e1_entered,form,event.duplicate(true))
  var point: Variant = state.get("hero",{}).get("position",Vector3.ZERO)
  if not point is Vector3 or not point.is_finite(): return _e1_reject("entry_position",output)
  if not paused: output.append(_e1_cue("ink_e1_enter",event,state,form+":enter",at,point))
  return output
 if not e1_entered.has(form) or e1_finished.has(form): return _e1_reject("retired_or_unobserved_form",output)
 if int(e1_entered[form].cast_id)!=cast: return _e1_reject("cast_mismatch",output)
 if kind=="ink_e1_reform_started":
  if not _matching(event,e1_entered[form],E1_STABLE) or not state.get("rain",{}).is_empty(): return _e1_reject("reform_identity",output)
  var at: float = float(event.get("finished_at",-1.0))
  if not is_finite(at) or at<float(event.born_at) or at>now+.00001 or at>float(event.expires_at)+.00001: return _e1_reject("reform_time",output)
  if not event.get("position") is Vector3 or not event.position.is_finite(): return _e1_reject("reform_position",output)
  if e1_reformed.has(form): return _e1_reject("duplicate_reform",output)
  _remember(e1_reformed,form,event.duplicate(true))
  if not paused: output.append(_e1_cue("ink_e1_reform",event,state,form+":reform",at,event.position))
  return output
 if not e1_reformed.has(form): return _e1_reject("contact_without_reform",output)
 if kind=="ink_e1_finished":
  if not _find_match(event,state.get("e1_finished",[]),E1_STABLE+["finished_at","position","damage_stages_complete","hit_target_ids"]): return _e1_reject("finish_not_in_snapshot",output)
  _remember(e1_finished,form)
  return output
 if not _find_match(event,state.get("e1_receipts",[]),E1_CONTACT): return _e1_reject("contact_not_in_snapshot",output)
 var receipt: String = str(event.source_event_id)
 var actual: float = float(event.actual_damage)
 if receipt.is_empty() or e1_contacts.has(receipt): return _e1_reject("duplicate_contact",output)
 if str(event.segment_id) not in ["reform_burst","rain_mark_bonus"] or not is_finite(actual) or actual<=0.0: return _e1_reject("nonpositive_contact",output)
 var joined: bool = false
 for damage: Dictionary in e1_damage:
  if int(damage.get("cast_id",-1))==cast and damage.get("target","")==event.target_id and damage.get("room_id","")==event_room and int(damage.get("generation",-1))==generation and int(damage.get("sequence",-1))<int(event.sequence) and absf(float(damage.get("amount",-1.0))-actual)<.00001 and absf(float(damage.get("world_time",-1.0))-float(event.world_time))<.00001:
   joined=true; break
 if not joined: return _e1_reject("contact_without_actual_damage",output)
 var at: float = float(event.source_time)
 var settled: float = float(event.settled_at)
 if not is_finite(settled) or not event.get("position") is Vector3 or not event.position.is_finite(): return _e1_reject("contact_position_or_settlement",output)
 if not is_finite(at) or at<float(e1_entered[form].born_at)-.00001 or at>float(event.settled_at)+.00001 or float(event.settled_at)>now+.00001: return _e1_reject("contact_time",output)
 _remember(e1_contacts,receipt)
 if e1_mix.has(form): e1_coalesced+=1; return output
 _remember(e1_mix,form)
 if not paused: output.append(_e1_cue("ink_e1_contact",event,state,form+":contact",at,event.position,actual))
 return output
func snapshot() -> Dictionary:
 var result: Dictionary = super.snapshot()
 result["e1_candidate"]="ink_e1_audio_20261008"
 result["e1_coalesced_contacts"]=e1_coalesced
 result["e1_form_counts"]={"entered":e1_entered.size(),"reformed":e1_reformed.size(),"finished":e1_finished.size()}
 result["audio_quality_accepted"]=false
 return result
