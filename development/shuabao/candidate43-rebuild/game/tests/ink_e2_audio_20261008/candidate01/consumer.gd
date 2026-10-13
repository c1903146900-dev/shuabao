extends RefCounted
## Detached E2 sibling consumer. Owns no player, Sim, RNG or gameplay command.
## Feed only synchronous deep copies; route output into the EXISTING shared bus.
const Bank = preload("res://tests/ink_benchmark_audio_20261004/bank.gd")
const RULES_HASH := "aef68e35a4becc25fcfa4158cfc2d55ee538a942023f99b7e7cefb07dac7cf53"
const ROOT := "res://tests/ink_e2_audio_20261008/candidate01/wav/"
const STABLE := ["boat_id","cast_id","generation","room_id","rank","born_at","launch_position","direction","voyage_until","speed","width","boarding_radius","natural_radius","h09","h10"]
const PUBLIC := ["position","phase","phase_started_at","last_advanced_at","boarded","natural_burst_done","damage_stages_complete","retired","outward_hit_target_ids","return_hit_target_ids","traveled_route","boundary_route","boundary_parked"]
const CONTACT := ["source_event_id","effect_id","boat_id","cast_id","generation","room_id","segment_id","target_id","position","source_time","settled_at","nominal_damage","actual_damage","hex_generated"]
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
 ended=true;closed=true
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
 var command: Dictionary={"action":"play","id":id,"path":ROOT+id+("_a.wav" if variant==0 else "_b.wav"),"variant_index":variant,"gain_db":Bank.GAIN_DB,"max_voices":Bank.MAX_VOICES,"loop":false,"pitch_scale":1.0,"cast_key":"%s:%d:%s"%[event_room,generation,str(event.cast_id)],"identity":identity,"room_id":event_room,"generation":generation,"sequence":int(event.sequence),"source_clock":"hero","source_time":float(event.source_time),"observed_source_time":float(state.source_time),"settled_at":float(event.settled_at),"world_time":float(event.world_time),"position":event.position,"priority":2 if id=="ink_e2_contact" else 1,"boat_id":event.boat_id,"segment_id":event.get("segment_id",""),"actual_damage":event.get("actual_damage",0.0),"candidate":"ink_e2_audio_20261008"}
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
  event_room=room;generation=gen;last_sequence=-1;ended=false;closed=false;_clear_scope()
 if seq<=last_sequence:return _reject("duplicate_or_old_sequence")
 last_sequence=seq
 var kind: String=str(event.get("kind",""))
 if kind in ["encounter_finished","hero_died","hero_death"]:
  ended=true;output.append_array(clear(kind));return output
 if ended:return output
 if kind=="damage" and event.get("source","")=="e2":
  damage_packets.append(event.duplicate(true))
  if damage_packets.size()>128:damage_packets.pop_front()
  return output
 if kind not in ["ink_e2_launched","ink_e2_boarded","ink_e2_natural_burst","ink_e2_contact","ink_e2_finished"]:return output
 if state.get("e2_schema","")!="ink-e2-ordinary-source-candidate-1":return _reject("e2_schema")
 if bool(event.get("preview_only",false)):return _reject("preview")
 var boat: String=str(event.get("boat_id",""))
 var cast: int=int(event.get("cast_id",-1))
 var now: float=float(state.get("source_time",-1.0))
 var at: float=float(event.get("source_time",event.get("finished_at",-1.0)))
 var settled: float=float(event.get("settled_at",-1.0))
 if boat.is_empty() or cast<0 or not is_finite(now) or not is_finite(at) or not is_finite(settled) or at<0.0 or at>settled+.00001 or settled>now+.00001:return _reject("identity_or_time")
 if not event.get("position") is Vector3 or not event.position.is_finite():return _reject("position")
 if kind=="ink_e2_launched":
  if not _matching(event,state.get("boat",{}),STABLE+PUBLIC) or not _find(event,state.get("e2_lifecycle",[]),STABLE+PUBLIC+["event","source_time","settled_at"]):return _reject("launch_not_in_snapshot")
  if launches.has(boat) or event.event!="launched" or event.phase!="outward" or bool(event.boarded) or bool(event.h09) or bool(event.h10) or absf(at-float(event.born_at))>.00001:return _reject("launch_identity")
  launches[boat]=event.duplicate(true)
  if not paused and not bool(state.get("paused",false)):output.append(_cue("ink_e2_launch",event,state,boat+":launch"))
  return output
 if not launches.has(boat) or finished.has(boat) or int(launches[boat].cast_id)!=cast:return _reject("unobserved_or_retired_boat")
 if at<float(launches[boat].born_at)-.00001:return _reject("before_launch")
 if kind=="ink_e2_finished":
  if not _matching(event,launches[boat],STABLE) or not _find(event,state.get("e2_finished",[]),STABLE+PUBLIC+["reason","finished_at","settled_at","hit_target_ids"]):return _reject("finish_not_in_snapshot")
  if not branches.has(boat) or event.reason!=branches[boat] or not bool(event.damage_stages_complete) or not bool(event.retired):return _reject("finish_branch")
  finished[boat]=true;return output
 if kind in ["ink_e2_boarded","ink_e2_natural_burst"]:
  if not _matching(event,launches[boat],STABLE) or not _matching(event,state.get("boat",{}),STABLE+PUBLIC) or not _find(event,state.get("e2_lifecycle",[]),STABLE+PUBLIC+["event","source_time","settled_at"]):return _reject("branch_not_in_snapshot")
  if branches.has(boat):return _reject("duplicate_branch")
  var boarded: bool=kind=="ink_e2_boarded"
  if boarded:
   if event.event!="boarded" or not bool(event.boarded) or event.phase!="boarding_settlement" or bool(event.natural_burst_done) or at>=float(event.voyage_until) or event.get("boarding_position")!=event.position or state.get("hero",{}).get("position")!=event.position:return _reject("illegal_board")
  elif event.event!="natural_burst" or bool(event.boarded) or not bool(event.natural_burst_done) or event.phase!="natural_settlement" or absf(at-float(event.voyage_until))>.00001:return _reject("illegal_expiry")
  branches[boat]="boarded" if boarded else "unboarded"
  if not paused and not bool(state.get("paused",false)):output.append(_cue("ink_e2_board" if boarded else "ink_e2_expire",event,state,boat+":branch"))
  return output
 if not _find(event,state.get("e2_receipts",[]),CONTACT):return _reject("contact_not_in_snapshot")
 var segment: String=str(event.segment_id)
 if segment not in ["outward_voyage","teleport_burst","unboarded_end_burst"] or bool(event.hex_generated):return _reject("unsupported_segment")
 if segment=="teleport_burst" and branches.get(boat,"")!="boarded":return _reject("contact_without_board")
 if segment=="unboarded_end_burst" and branches.get(boat,"")!="unboarded":return _reject("contact_without_expiry")
 # Outward receipt can settle after nested boarding: don't forbid that real ordering.
 var receipt: String=str(event.source_event_id)
 var actual: float=float(event.actual_damage)
 if receipt!=boat+":"+segment+":"+str(event.target_id) or event.effect_id!=receipt or contacts.has(receipt):return _reject("contact_identity")
 contacts[receipt]=true
 if not is_finite(actual) or actual<=0.0:return output
 var damage_index: int=-1
 for i: int in range(damage_packets.size()-1,-1,-1):
  var damage: Dictionary=damage_packets[i]
  if int(damage.get("cast_id",-1))==cast and damage.get("target","")==event.target_id and damage.get("room_id","")==room and int(damage.get("generation",-1))==gen and int(damage.sequence)<seq and absf(float(damage.get("amount",-1.0))-actual)<.00001 and absf(float(damage.get("world_time",-1.0))-float(event.world_time))<.00001:
   damage_index=i;break
 if damage_index<0:return _reject("contact_without_damage")
 damage_packets.remove_at(damage_index)
 var mix: String=boat+":"+segment
 if segments.has(mix):coalesced+=1;return output
 segments[mix]=true # Paused identity consumed before any audible command.
 if not paused and not bool(state.get("paused",false)):output.append(_cue("ink_e2_contact",event,state,mix))
 return output
func snapshot() -> Dictionary:
 return {"scope":{"room_id":event_room,"generation":generation},"last_sequence":last_sequence,"paused":paused,"ended":ended,"closed":closed,"counts":counts.duplicate(true),"rejected":rejected.duplicate(true),"coalesced":coalesced,"history":history.duplicate(true),"max_voices":Bank.MAX_VOICES,"hardware_listening":false,"runtime_qualified":false}
