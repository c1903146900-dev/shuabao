extends RefCounted
## Detached E3 sibling consumer. Owns no player, Sim, RNG or gameplay command.
## Feed only synchronous deep copies; route output into the EXISTING shared bus.
const Bank = preload("res://tests/ink_benchmark_audio_20261004/bank.gd")
const RULES_HASH := "aef68e35a4becc25fcfa4158cfc2d55ee538a942023f99b7e7cefb07dac7cf53"
const ROOT := "res://tests/ink_e3_audio_20261008/candidate01/wav/"
const STABLE := ["frame_id","cast_id","generation","room_id","rank","a","radius","max_distance","born_at","expires_at","h11","h12"]
const PUBLIC := ["phase","damage_stages_complete","release_completed","retired","return_consumed","member_ids"]
const CONTACT := ["source_event_id","effect_id","frame_id","cast_id","generation","room_id","segment_id","target_id","from","to","actual_distance","nominal_damage","actual_damage","source_time","settled_at"]
var paused: bool = false
var ended: bool = false
var closed: bool = false
var event_room: String = ""
var generation: int = -1
var last_sequence: int = -1
var retired_scopes: Dictionary = {}
var launches: Dictionary = {}
var branches: Dictionary = {}
var finished: Dictionary = {}
var contacts: Dictionary = {}
var segments: Dictionary = {}
var damage_packets: Array = []
var counts: Dictionary = {}
var rejected: Dictionary = {}
var history: Array = []
var coalesced: int = 0
func _scope(room: String, gen: int) -> String: return "%s:%d" % [room,gen]
func _clear_scope() -> void:
 launches.clear();branches.clear();finished.clear();contacts.clear();segments.clear();damage_packets.clear()
func _reject(reason: String) -> Array:
 rejected[reason]=int(rejected.get(reason,0))+1
 return []
func set_paused(value: bool) -> Array:
 if paused==value:return []
 paused=value
 return [{"action":"stop_all","reason":"pause"}] if paused else []
func clear(reason: String="host_clear") -> Array:
 # Focus loss stops voices, retaining identity. Use close() for terminal exit.
 return [{"action":"stop_all","reason":reason}]
func close(reason: String="exit") -> Array:
 closed=true;ended=true
 return clear(reason)
func reset() -> Array:
 if not event_room.is_empty():retired_scopes[_scope(event_room,generation)]=true
 event_room="";generation=-1;last_sequence=-1;ended=false;closed=false;_clear_scope()
 return clear("reset")
func _matching(event: Dictionary,row: Dictionary,fields: Array) -> bool:
 for key in fields:
  if not event.has(key) or not row.has(key) or event[key]!=row[key]:return false
 return true
func _find(event: Dictionary,rows: Array,fields: Array) -> bool:
 for row in rows:
  if row is Dictionary and _matching(event,row,fields):return true
 return false
func _variant(identity: String) -> int:
 var value: int=2166136261
 for byte in identity.to_utf8_buffer():value=((value^int(byte))*16777619)&0xffffffff
 return value%2
func _cue(id: String,event: Dictionary,state: Dictionary,identity: String) -> Dictionary:
 var variant: int=_variant(identity)
 var position: Vector3=event.get("to",event.get("b",event.get("a",Vector3.ZERO)))
 var command: Dictionary={"action":"play","id":id,"path":ROOT+id+("_a.wav" if variant==0 else "_b.wav"),"variant_index":variant,"gain_db":Bank.GAIN_DB,"max_voices":Bank.MAX_VOICES,"loop":false,"pitch_scale":1.0,"cast_key":"%s:%d:%s"%[event_room,generation,str(event.cast_id)],"identity":identity,"room_id":event_room,"generation":generation,"sequence":int(event.sequence),"source_clock":"hero","source_time":float(event.source_time),"observed_source_time":float(state.source_time),"settled_at":float(event.get("settled_at",event.get("finished_at",event.source_time))),"world_time":float(event.world_time),"position":position,"priority":2 if id=="ink_e3_contact" else 1,"frame_id":event.frame_id,"segment_id":event.get("segment_id",""),"actual_damage":event.get("actual_damage",0.0),"candidate":"ink_e3_audio_20261008"}
 counts[id]=int(counts.get(id,0))+1;history.append(command.duplicate(true))
 if history.size()>64:history.pop_front()
 return command
func consume(event: Dictionary,state: Dictionary) -> Array:
 if closed:return []
 if state.get("schema","")!="ink-q1-presenter-1" or state.get("rules_hash","")!=RULES_HASH:return _reject("unbound_snapshot")
 var scope: Dictionary=state.get("scope",{})
 var room: String=str(event.get("room_id",""))
 var gen: int=int(event.get("generation",-1))
 var seq: int=int(event.get("sequence",-1))
 if room.is_empty() or gen<0 or seq<0 or room!=scope.get("room_id","") or gen!=int(scope.get("generation",-1)):return _reject("scope_or_sequence")
 if retired_scopes.has(_scope(room,gen)) or (generation>=0 and gen<generation):return _reject("retired_scope")
 var output: Array=[]
 if room!=event_room or gen!=generation:
  if not event_room.is_empty():retired_scopes[_scope(event_room,generation)]=true;output.append_array(clear("scope_changed"))
  event_room=room;generation=gen;last_sequence=-1;ended=false;_clear_scope()
 if seq<=last_sequence:return _reject("duplicate_or_old_sequence")
 last_sequence=seq
 var kind: String=str(event.get("kind",""))
 if kind in ["encounter_finished","hero_died","hero_death"]:
  ended=true;output.append_array(clear(kind));return output
 if ended:return output
 if kind=="damage" and event.get("source","")=="e3":
  damage_packets.append(event.duplicate(true))
  if damage_packets.size()>128:damage_packets.pop_front()
  return output
 if kind not in ["ink_e3_first_placed","ink_e3_exchanged","ink_e3_contact","ink_e3_damage_finished","ink_e3_placement_expired","ink_e3_returned","ink_e3_return_expired"]:return output
 if state.get("e3_schema","")!="ink-e3-clear-space-foundation-1":return _reject("e3_schema")
 if bool(event.get("preview_only",false)):return _reject("preview")
 var frame: String=str(event.get("frame_id",""))
 var cast: int=int(event.get("cast_id",-1))
 var now: float=float(state.get("source_time",-1.0))
 var at: float=float(event.get("source_time",-1.0))
 var settled: float=float(event.get("settled_at",event.get("finished_at",at)))
 if frame.is_empty() or cast<0 or not is_finite(now) or not is_finite(at) or not is_finite(settled) or at<0.0 or at>settled+.00001 or settled>now+.00001:return _reject("identity_or_time")
 if kind=="ink_e3_first_placed":
  if not _matching(event,state.get("frames",{}),STABLE+PUBLIC) or not _find(event,state.get("e3_lifecycle",[]),STABLE+PUBLIC+["event","source_time","settled_at"]):return _reject("placement_not_in_snapshot")
  if launches.has(frame) or event.event!="first_placed" or event.phase!="first" or bool(event.release_completed) or bool(event.retired) or absf(at-float(event.born_at))>.00001:return _reject("placement_identity")
  if not event.a is Vector3 or not event.a.is_finite():return _reject("position")
  launches[frame]=event.duplicate(true)
  if not paused and not bool(state.get("paused",false)):output.append(_cue("ink_e3_place",event,state,frame+":place"))
  return output
 if not launches.has(frame) or int(launches[frame].cast_id)!=cast:return _reject("unobserved_frame")
 if at<float(launches[frame].born_at)-.00001:return _reject("before_placement")
 if kind=="ink_e3_contact":
  if not branches.has(frame) or finished.has(frame):return _reject("contact_outside_exchange")
  if not _find(event,state.get("e3_receipts",[]),CONTACT):return _reject("contact_not_in_snapshot")
  var receipt: String=str(event.source_event_id)
  if event.segment_id!="swap_damage" or receipt!=frame+":swap_damage:"+str(event.target_id) or event.effect_id!=receipt or contacts.has(receipt):return _reject("contact_identity")
  if not event.get("from") is Vector3 or not event.get("to") is Vector3 or not event.from.is_finite() or not event.to.is_finite():return _reject("position")
  if not is_finite(float(event.actual_distance)) or float(event.actual_distance)<=0.0 or absf(event.from.distance_to(event.to)-float(event.actual_distance))>.00001:return _reject("not_moved")
  if absf(at-float(branches[frame].exchange_at))>.00001:return _reject("contact_time")
  contacts[receipt]=true
  var actual: float=float(event.actual_damage)
  if not is_finite(actual) or actual<=0.0:return output
  var damage_index: int=-1
  for i: int in range(damage_packets.size()-1,-1,-1):
   var damage: Dictionary=damage_packets[i]
   if int(damage.get("cast_id",-1))==cast and damage.get("target","")==event.target_id and damage.get("room_id","")==room and int(damage.get("generation",-1))==gen and int(damage.sequence)<seq and absf(float(damage.get("amount",-1.0))-actual)<.00001 and damage.get("position") == event.to and absf(float(damage.get("world_time",-1.0))-float(event.world_time))<.00001:
    damage_index=i;break
  if damage_index<0:return _reject("contact_without_damage")
  damage_packets.remove_at(damage_index)
  var mix: String=frame+":swap_damage"
  if segments.has(mix):coalesced+=1;return output
  segments[mix]=true
  if not paused and not bool(state.get("paused",false)):output.append(_cue("ink_e3_contact",event,state,mix))
  return output
 if not _matching(event,launches[frame],STABLE):return _reject("changed_frame")
 if kind=="ink_e3_damage_finished":
  if finished.has(frame) or not branches.has(frame) or not _find(event,state.get("e3_finished",[]),STABLE+PUBLIC+["b","exchange_at","finished_at","source_time","hit_target_ids"]):return _reject("finish_not_in_snapshot")
  if not bool(event.damage_stages_complete) or not bool(event.release_completed) or event.phase not in ["complete","return_window"]:return _reject("finish_state")
  finished[frame]=true;return output
 # Returned has no event/settled_at in its source packet. It is movement-only.
 var fields: Array=STABLE+PUBLIC+["source_time"]
 if kind!="ink_e3_returned":fields.append_array(["event","settled_at"])
 if not _find(event,state.get("e3_lifecycle",[]),fields):return _reject("lifecycle_not_in_snapshot")
 if kind=="ink_e3_exchanged":
  if branches.has(frame) or finished.has(frame) or not _matching(event,state.get("frames",{}),STABLE+PUBLIC+["b","exchange_at"]):return _reject("duplicate_or_unbound_exchange")
  if event.event!="exchanged" or event.phase!="settling" or not bool(event.release_completed) or bool(event.retired) or at>=float(event.expires_at) or not event.b is Vector3 or not event.b.is_finite():return _reject("exchange_state")
  branches[frame]=event.duplicate(true)
  if not paused and not bool(state.get("paused",false)):output.append(_cue("ink_e3_complete",event,state,frame+":exchange"))
 elif kind=="ink_e3_placement_expired":
  if branches.has(frame) or finished.has(frame) or event.phase!="expired" or not bool(event.retired) or bool(event.release_completed) or absf(at-float(event.expires_at))>.00001:return _reject("expiry_state")
  finished[frame]=true
  if not paused and not bool(state.get("paused",false)):output.append(_cue("ink_e3_expire",event,state,frame+":expiry"))
 # H12 return and return-window expiry deliberately emit no base E3 cue.
 return output
func snapshot() -> Dictionary:
 return {"scope":{"room_id":event_room,"generation":generation},"last_sequence":last_sequence,"paused":paused,"ended":ended,"closed":closed,"counts":counts.duplicate(true),"rejected":rejected.duplicate(true),"coalesced":coalesced,"history":history.duplicate(true),"max_voices":Bank.MAX_VOICES,"hardware_listening":false,"runtime_qualified":false}
