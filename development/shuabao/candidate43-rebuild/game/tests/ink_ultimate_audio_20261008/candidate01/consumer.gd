extends RefCounted
## Event-only detached R1/R2 consumer. No timers, players, host, commands or RNG.
const Bank=preload("res://tests/ink_benchmark_audio_20261004/bank.gd")
const ROOT="res://tests/ink_ultimate_audio_20261008/candidate01/wav/"
const RULES_HASH="aef68e35a4becc25fcfa4158cfc2d55ee538a942023f99b7e7cefb07dac7cf53"
const STABLE=["domain_id","cast_id","generation","room_id","rank","radius","born_at","expires_at"]
var paused: bool=false
var ended: bool=false
var closed: bool=false
var event_room: String=""
var generation: int=-1
var last_sequence: int=-1
var retired_scopes: Dictionary={}
var launches: Dictionary={}
var stages: Dictionary={}
var identities: Dictionary={}
var ticks: Dictionary={}
var finished: Dictionary={}
var counts: Dictionary={}
var rejected: Dictionary={}
var history: Array=[]
var coalesced: int=0
func _scope(room: String,gen: int)->String:return "%s:%d"%[room,gen]
func clear(reason: String="host_clear")->Array:return [{"action":"stop_all","reason":reason}]
func close(reason: String="exit")->Array:
 closed=true;ended=true
 return clear(reason)
func set_paused(value: bool)->Array:
 if paused==value:return []
 paused=value
 return clear("pause") if value else []
func reset()->Array:
 if not event_room.is_empty():retired_scopes[_scope(event_room,generation)]=true
 event_room="";generation=-1;last_sequence=-1;ended=false;closed=false
 launches.clear();stages.clear();identities.clear();ticks.clear();finished.clear()
 return clear("reset")
func _reject(reason: String)->Array:
 rejected[reason]=int(rejected.get(reason,0))+1
 return []
func _match(a: Dictionary,b: Dictionary,fields: Array)->bool:
 for key in fields:
  if not a.has(key) or not b.has(key) or a[key]!=b[key]:return false
 return true
func _find(a: Dictionary,rows: Array,fields: Array)->bool:
 for row in rows:
  if row is Dictionary and _match(a,row,fields):return true
 return false
func _cue(id: String,event: Dictionary,state: Dictionary,identity: String,position: Vector3)->Array:
 if identities.has(identity):return []
 identities[identity]=true
 if paused or bool(state.get("paused",false)):return []
 var command: Dictionary={"action":"play","id":id,"path":ROOT+id+".wav","variant_index":0,"gain_db":Bank.GAIN_DB,"max_voices":Bank.MAX_VOICES,"loop":false,"pitch_scale":1.0,"cast_key":"%s:%d:%s"%[event_room,generation,str(event.cast_id)],"identity":identity,"room_id":event_room,"generation":generation,"sequence":event.sequence,"source_clock":"world","source_time":event.get("source_time",event.world_time),"world_time":event.world_time,"position":position,"priority":2 if id=="ink_r2_contact" else 1,"candidate":"ink_ultimate_audio_20261008"}
 counts[id]=int(counts.get(id,0))+1;history.append(command.duplicate(true))
 if history.size()>128:history.pop_front()
 return [command]
func consume(event: Dictionary,state: Dictionary)->Array:
 if closed:return []
 if state.get("schema","")!="ink-q1-presenter-1" or state.get("rules_hash","")!=RULES_HASH:return _reject("unbound_snapshot")
 var scope: Dictionary=state.get("scope",{})
 var room: String=str(event.get("room_id",""))
 var gen: int=int(event.get("generation",-1))
 var seq: int=int(event.get("sequence",-1))
 if room.is_empty() or gen<0 or seq<0 or room!=scope.get("room_id","") or gen!=int(scope.get("generation",-1)):return _reject("scope_or_sequence")
 if retired_scopes.has(_scope(room,gen)):return _reject("retired_scope")
 if event_room.is_empty():event_room=room;generation=gen
 elif event_room!=room or generation!=gen:return close("scope_changed_requires_reset")
 if seq<=last_sequence:return _reject("duplicate_or_old_sequence")
 last_sequence=seq
 var kind: String=str(event.get("kind",""))
 if kind in ["encounter_finished","hero_died","hero_death"]:return close(kind)
 var damage: bool=kind=="damage" and event.get("source","")=="r2"
 if not damage and not kind.begins_with("ink_r1_") and not kind.begins_with("ink_r2_"):return []
 if bool(event.get("preview_only",false)):return _reject("preview")
 var r: String="r2" if damage or kind.begins_with("ink_r2_") else "r1"
 if state.get(r+"_schema","")!=("ink-r1-isolated-core-1" if r=="r1" else "ink-r2-ground-peaks-1"):return _reject("family_schema")
 var world: float=float(event.get("world_time",-1.0))
 var now: float=float(state.get("world_time",-1.0))
 if not is_finite(world) or not is_finite(now) or world<0 or absf(world-now)>.00001:return _reject("event_time")
 var domain: Dictionary=state.get("snow" if r=="r1" else "peaks_domain",{})
 var show: Dictionary=state.get("ultimate_presentation",{})
 var cast: int=int(event.get("cast_id",-1))
 var key: String=r+":"+str(cast)
 if kind=="ink_"+r+"_created":
  if cast<0 or launches.has(key) or not _match(event,domain,STABLE+["position"]):return _reject("commit_not_in_snapshot")
  var token: Dictionary=show.get("token",{})
  if not bool(show.get("active",false)) or str(token.get("cast_id",""))!=str(cast) or token.get("ability_id","")!="yanguizhou_"+r:return _reject("commit_without_presentation")
  if not event.position is Vector3 or not event.position.is_finite() or absf(float(event.born_at)-world)>.00001 or float(event.expires_at)<=world:return _reject("commit_geometry_or_time")
  launches[key]=event.duplicate(true)
  launches[key]["presentation_token"]=token.duplicate(true)
  launches[key]["actor_started"]=float(show.get("actor_motion_time",0.0))
  return _cue("ink_"+r+"_create",event,state,key+":create",event.position)
 if not launches.has(key) or finished.has(key):return _reject("unobserved_or_finished_cast")
 var launch: Dictionary=launches[key]
 if kind=="ink_"+r+"_presentation_ended":
  if event.get("token",{})!=launch.presentation_token or not _find(event,show.get("completed",[]),["cast_id","ability_id","token","presentation_end","world_time","generation","room_id"]):return _reject("show_end_not_in_snapshot")
  if float(show.get("actor_motion_time",0.0))-float(launch.actor_started)<(1.0 if r=="r1" else 1.2)-.00001:return _reject("show_end_early")
  return _cue("ink_"+r+"_show_end",event,state,key+":show_end",launch.position)
 if kind=="ink_"+r+"_finished":
  if not _match(event,launch,STABLE+["position"]) or not _find(event,state.get(r+"_finished",[]),STABLE+["position","reason","finished_at"]):return _reject("finish_not_in_snapshot")
  if event.reason!="natural_expiry" or float(event.finished_at)!=float(launch.expires_at) or world<float(event.finished_at)-.00001 or (r=="r2" and not bool(event.get("damage_stages_complete",false))):return _reject("finish_state")
  finished[key]=true
  return _cue("ink_"+r+"_field_end",event,state,key+":field_end",launch.position)
 if r!="r2":return []
 if not _match(domain,launch,STABLE+["position"]):return _reject("domain_no_longer_live")
 if damage:
  var receipt: Dictionary=event.get("r2_receipt",{})
  if not _match(receipt,launch,["domain_id","cast_id","generation","room_id"]):return _reject("receipt_scope")
  var ordinal: int=int(receipt.get("ordinal",-2))
  var segment: String="rollup" if ordinal==-1 else "peak_"+str(ordinal)
  var batch: String=key+":"+segment
  if not stages.has(batch):return _reject("damage_without_started")
  var start: Dictionary=stages[batch]
  var actual: float=float(receipt.get("actual_damage",0.0))
  var effect: String=str(receipt.get("effect_id",""))
  if identities.has(effect):return _reject("duplicate_contact")
  if receipt.get("segment","")!=segment or effect!=str(launch.domain_id)+":"+segment+":"+str(event.get("target","")) or receipt.get("target_id","")!=event.get("target","") or not start.target_ids.has(receipt.target_id):return _reject("receipt_identity")
  if not is_finite(actual) or actual<=0.0 or absf(actual-float(event.get("amount",-1.0)))>.00001:return _reject("nonpositive_or_mismatched_damage")
  if receipt.get("position")!=start.position or event.get("source_position")!=receipt.position or float(receipt.get("source_time",-1.0))!=float(start.source_time) or absf(float(receipt.get("settled_at",-1.0))-world)>.00001:return _reject("receipt_time_or_position")
  identities[effect]=true
  var tick: String="contact:%.9f"%world
  if identities.has(batch+":contact") or ticks.has(tick):identities[batch+":contact"]=true;coalesced+=1;return []
  ticks[tick]=true
  return _cue("ink_r2_contact",event,state,batch+":contact",receipt.position)
 if kind in ["ink_r2_peak_hit_started","ink_r2_rollup_started"]:
  if not _match(event,launch,STABLE):return _reject("stage_scope")
  var ordinal: int=int(event.get("ordinal",-2))
  var segment: String="rollup" if ordinal==-1 else "peak_"+str(ordinal)
  var batch: String=key+":"+segment
  if stages.has(batch):return _reject("duplicate_stage")
  if ordinal==-1:
   if kind!="ink_r2_rollup_started" or float(event.source_time)!=float(launch.expires_at) or event.position!=launch.position:return _reject("rollup_state")
  else:
   if kind!="ink_r2_peak_hit_started":return _reject("peak_stage_kind")
   var found: bool=false
   for peak: Dictionary in state.get("ground_peaks",[]):
    if int(peak.ordinal)==ordinal and peak.phase=="hit" and peak.position==event.position and float(peak.hit_at)==float(event.source_time):found=true
   if not found:return _reject("hit_stage_not_in_snapshot")
  stages[batch]=event.duplicate(true)
  return []
 if kind=="ink_r2_peak_rise":
  if not _match(event,launch,STABLE) or not _find(event,state.get("ground_peaks",[]),STABLE+["ordinal","peak_id","position","phase","rise_at","hit_at","harmless","target_ids"]):return _reject("rise_not_in_snapshot")
  if event.phase!="rise" or float(event.source_time)!=float(event.rise_at) or str(event.peak_id)!=str(launch.domain_id)+":peak:"+str(event.ordinal):return _reject("rise_identity")
  var tick: String="rise:%.9f"%world
  var identity: String=str(event.peak_id)+":rise"
  if ticks.has(tick):identities[identity]=true;coalesced+=1;return []
  ticks[tick]=true
  return _cue("ink_r2_peak_rise",event,state,identity,event.position)
 return []
func snapshot()->Dictionary:
 return {"scope":{"room_id":event_room,"generation":generation},"last_sequence":last_sequence,"paused":paused,"ended":ended,"closed":closed,"counts":counts.duplicate(true),"rejected":rejected.duplicate(true),"coalesced":coalesced,"history":history.duplicate(true),"max_voices":Bank.MAX_VOICES,"hardware_listening":false,"runtime_qualified":false}
