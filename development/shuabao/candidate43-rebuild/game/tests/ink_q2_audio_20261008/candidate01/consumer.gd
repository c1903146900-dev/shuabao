extends RefCounted
## Detached Q2/H03/H04 sibling consumer. Owns no player, Sim, RNG or gameplay command.
## Feed only synchronous deep copies; route output into the EXISTING shared bus.
const Bank = preload("res://tests/ink_benchmark_audio_20261004/bank.gd")
const RULES_HASH := "aef68e35a4becc25fcfa4158cfc2d55ee538a942023f99b7e7cefb07dac7cf53"
const ROOT := "res://tests/ink_q2_audio_20261008/candidate01/wav/"
const STABLE := ["river_id","cast_id","generation","room_id","path","width","rank","born_at","expires_at","sunset_expires_at","h04_at_completion","h03_at_completion"]
const PUBLIC := ["next_sunset_tick","river_expired","hit_target_ids"]
const MARKER := ["cast_id","generation","room_id","path","rank","born_at","expires_at"]
const CONTACT := ["effect_id","river_id","cast_id","generation","room_id","target_id","tick","source_time","target_position","actual_damage","settled_at"]
var paused: bool = false
var ended: bool = false
var closed: bool = false
var event_room: String = ""
var generation: int = -1
var last_sequence: int = -1
var retired_scopes: Dictionary = {}
var markers: Dictionary = {}
var rivers: Dictionary = {}
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
 markers.clear();rivers.clear();finished.clear();contacts.clear();segments.clear();damage_packets.clear()
func _reject(reason: String) -> Array:
 rejected[reason]=int(rejected.get(reason,0))+1
 return []
func set_paused(value: bool) -> Array:
 if paused==value:return []
 paused=value
 return [{"action":"stop_all","reason":"pause"}] if paused else []
func clear(reason: String="host_clear") -> Array:
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
func _cue(id: String,event: Dictionary,state: Dictionary,identity: String,at: float,point: Vector3) -> Dictionary:
 var variant: int=_variant(identity)
 var command: Dictionary={"action":"play","id":id,"path":ROOT+id+("_a.wav" if variant==0 else "_b.wav"),"variant_index":variant,"gain_db":Bank.GAIN_DB,"max_voices":Bank.MAX_VOICES,"loop":false,"pitch_scale":1.0,"cast_key":"%s:%d:%s"%[event_room,generation,str(event.cast_id)],"identity":identity,"room_id":event_room,"generation":generation,"sequence":int(event.sequence),"source_clock":"hero","source_time":at,"observed_source_time":float(state.source_time),"settled_at":float(event.get("settled_at",state.source_time)),"world_time":float(event.world_time),"position":point,"priority":2 if id in ["ink_q2_crossing","ink_q2_sunset_tick"] else 1,"river_id":event.get("river_id",""),"actual_damage":event.get("actual_damage",0.0),"candidate":"ink_q2_audio_20261008"}
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
 if kind=="damage" and event.get("source","") in ["q2","hex_yanguizhou_h04"]:
  damage_packets.append(event.duplicate(true))
  if damage_packets.size()>128:damage_packets.pop_front()
  return output
 if kind not in ["ink_q2_first_placed","ink_q2_corner_placed","ink_q2_placement_expired","ink_q2_river_created","ink_q2_crossing","ink_h04_contact","ink_q2_finished"]:return output
 if state.get("q2_schema","")!="ink-q2-isolated-source-candidate-1":return _reject("q2_schema")
 if bool(event.get("preview_only",false)):return _reject("preview")
 var cast: int=int(event.get("cast_id",-1))
 var now: float=float(state.get("source_time",-1.0))
 var muted: bool=paused or bool(state.get("paused",false))
 if cast<0 or not is_finite(now) or now<0.0:return _reject("identity_or_time")
 if kind in ["ink_q2_first_placed","ink_q2_corner_placed"]:
  if not _matching(event,state.get("q2_input",{}),MARKER):return _reject("marker_not_in_snapshot")
  var path: Array=event.path
  if path.is_empty() or path.size()>3 or float(event.born_at)>now or float(event.expires_at)<=now:return _reject("marker_path_or_time")
  for point in path:
   if not point is Vector3 or not point.is_finite():return _reject("marker_position")
  if kind=="ink_q2_first_placed":
   if markers.has(cast) or path.size()!=1 or absf(float(event.born_at)-now)>.00001:return _reject("duplicate_or_invalid_first")
  else:
   if not markers.has(cast) or bool(markers[cast].get("retired",false)) or path.size()!=markers[cast].path.size()+1 or not _matching(event,markers[cast],["cast_id","generation","room_id","rank","born_at","expires_at"]):return _reject("corner_without_marker")
   for i: int in range(path.size()-1):
    if path[i]!=markers[cast].path[i]:return _reject("changed_marker_path")
  markers[cast]=event.duplicate(true)
  if not muted:output.append(_cue("ink_q2_marker",event,state,"%d:marker:%d"%[cast,path.size()],now,path.back()))
  return output
 if kind=="ink_q2_placement_expired":
  if not markers.has(cast) or bool(markers[cast].get("retired",false)) or not state.get("q2_input",{}).is_empty() or bool(event.get("release_completed",true)) or absf(float(event.get("source_time",-1.0))-float(markers[cast].expires_at))>.00001 or now<float(markers[cast].expires_at)-.00001:return _reject("invalid_marker_expiry")
  markers[cast].retired=true
  return output # Expiry is not completion and has no invented hit/river sound.
 var river: String=str(event.get("river_id",""))
 if river.is_empty():return _reject("missing_river")
 if kind=="ink_q2_river_created":
  if not _find(event,state.get("rivers",[]),STABLE+PUBLIC) or not state.get("q2_input",{}).is_empty():return _reject("completion_not_in_snapshot")
  if rivers.has(river) or not markers.has(cast) or bool(markers[cast].get("retired",false)) or not bool(event.get("release_completed",false)) or absf(float(event.born_at)-now)>.00001:return _reject("completion_without_marker")
  var path: Array=event.path
  if path.size()!=markers[cast].path.size()+1 or (path.size()>2 and not bool(event.h03_at_completion)):return _reject("completion_path")
  for i: int in range(path.size()):
   if not path[i] is Vector3 or not path[i].is_finite():return _reject("completion_position")
   if i<path.size()-1 and path[i]!=markers[cast].path[i]:return _reject("completion_changed_path")
  markers[cast].retired=true;rivers[river]=event.duplicate(true)
  if not muted:output.append(_cue("ink_q2_collapse" if bool(event.h04_at_completion) else "ink_q2_complete",event,state,river+":complete",now,path.back()))
  return output
 if not rivers.has(river) or finished.has(river) or int(rivers[river].cast_id)!=cast:return _reject("unobserved_or_retired_river")
 if kind=="ink_q2_finished":
  if not _matching(event,rivers[river],STABLE) or not _find(event,state.get("q2_finished",[]),STABLE+PUBLIC+["reason","finished_at"]):return _reject("finish_not_in_snapshot")
  finished[river]=true;return output
 # A cancelled river disappears without an explicit cancel event. Live public
 # presence is mandatory; presentation-only sunset arrays never trigger audio.
 var live: bool=false
 for row: Dictionary in state.get("rivers",[]):
  if _matching(row,rivers[river],STABLE):live=true;break
 if not live:return _reject("river_no_longer_live")
 if not _find(event,state.get("q2_receipts",[]),CONTACT):return _reject("contact_not_in_snapshot")
 var sunset: bool=kind=="ink_h04_contact"
 var tick: int=int(event.tick)
 var segment: String="sunset:%d"%tick if sunset else "river_touch"
 var receipt: String=str(event.effect_id)
 var at: float=float(event.source_time)
 var settled: float=float(event.settled_at)
 var actual: float=float(event.actual_damage)
 var born: float=float(rivers[river].born_at)
 if receipt!=river+":"+segment+":"+str(event.target_id) or contacts.has(receipt):return _reject("contact_identity")
 if not is_finite(at) or not is_finite(settled) or not is_finite(actual) or at<born-.00001 or at>settled+.00001 or settled>now+.00001 or not event.target_position is Vector3 or not event.target_position.is_finite():return _reject("contact_time_or_position")
 if sunset:
  if not bool(rivers[river].h04_at_completion) or tick<1 or tick>8 or absf(at-(born+.5*tick))>.00001:return _reject("sunset_cadence")
 else:
  if tick!=0 or at>=float(rivers[river].expires_at):return _reject("river_contact_time")
 # The receipt's own kind is overwritten by the signal envelope. Match its
 # original kind separately against the exact stored receipt.
 var typed: bool=false
 for row: Dictionary in state.get("q2_receipts",[]):
  if _matching(event,row,CONTACT) and row.get("kind","")==("sunset" if sunset else "river"):typed=true;break
 if not typed:return _reject("receipt_kind")
 contacts[receipt]=true
 if actual<=0.0:return output
 var damage_index: int=-1
 for i: int in range(damage_packets.size()-1,-1,-1):
  var damage: Dictionary=damage_packets[i]
  if damage.get("source","")!=("hex_yanguizhou_h04" if sunset else "q2"):continue
  if int(damage.get("cast_id",-1))==cast and damage.get("target","")==event.target_id and damage.get("room_id","")==room and int(damage.get("generation",-1))==gen and int(damage.sequence)<seq and absf(float(damage.get("amount",-1.0))-actual)<.00001 and absf(float(damage.get("world_time",-1.0))-float(event.world_time))<.00001:
   damage_index=i;break
 if damage_index<0:return _reject("contact_without_damage")
 damage_packets.remove_at(damage_index)
 var mix: String=river+":"+segment
 if segments.has(mix):coalesced+=1;return output
 segments[mix]=true # Consume paused tick/segment, so remainder cannot replay it.
 if not muted:output.append(_cue("ink_q2_sunset_tick" if sunset else "ink_q2_crossing",event,state,mix,at,event.target_position))
 return output
func snapshot() -> Dictionary:
 return {"scope":{"room_id":event_room,"generation":generation},"last_sequence":last_sequence,"paused":paused,"ended":ended,"closed":closed,"counts":counts.duplicate(true),"rejected":rejected.duplicate(true),"coalesced":coalesced,"history":history.duplicate(true),"max_voices":Bank.MAX_VOICES,"hardware_listening":false,"runtime_qualified":false}
