extends RefCounted
## Detached source-event audio. No scheduling, timers, players, bus, Sim or RNG.
const Bank=preload("res://tests/ink_benchmark_audio_20261004/bank.gd")
const ROOT="res://tests/ink_first_floor_boss_20261008/audio01/wav/"
const RULES_HASH="aef68e35a4becc25fcfa4158cfc2d55ee538a942023f99b7e7cefb07dac7cf53"
const STABLE=["boss_cast_id","actor_id","boss_move","run_id","source_instance_id","room_id","generation","phase","target_actor_id","geometry"]
var paused: bool=false
var closed: bool=false
var ended: bool=false
var scope_key: String=""
var last_sequence: int=-1
var retired_scopes: Dictionary={}
var warnings: Dictionary={}
var released: Dictionary={}
var retired_casts: Dictionary={}
var retired_actors: Dictionary={}
var identities: Dictionary={}
var phase_seen: Dictionary={}
var counts: Dictionary={}
var rejected: Dictionary={}
var history: Array=[]
func clear(reason: String="host_clear") -> Array:
 return [{"action":"stop_all","reason":reason}]
func close(reason: String="exit") -> Array:
 closed=true; ended=true
 return clear(reason)
func set_paused(value: bool) -> Array:
 if paused==value: return []
 paused=value
 return clear("pause") if value else []
func reset() -> Array:
 if not scope_key.is_empty(): retired_scopes[scope_key]=true
 scope_key=""; last_sequence=-1; closed=false; ended=false
 warnings.clear(); released.clear(); retired_casts.clear(); retired_actors.clear(); identities.clear(); phase_seen.clear()
 return clear("reset")
func _reject(reason: String) -> Array:
 rejected[reason]=int(rejected.get(reason,0))+1
 return []
func _match(a: Dictionary,b: Dictionary,fields: Array) -> bool:
 for key in fields:
  if not a.has(key) or not b.has(key) or a[key]!=b[key]: return false
 return true
func _cast_matches(event: Dictionary,cast: Dictionary) -> bool:
 if not _match(event,cast,["boss_cast_id","run_id","source_instance_id","room_id","generation","phase","target_actor_id","geometry"]): return false
 return event.get("boss_move","")==cast.get("move","") and event.get("position") == cast.get("origin") and event.get("direction")==cast.get("direction") and event.get("target_point")==cast.get("target_point")
func _cue(id: String,event: Dictionary,frame: Dictionary,identity: String,point: Vector3) -> Array:
 if identities.has(identity): return _reject("duplicate_cue")
 # Consume while paused as well. Resume never replays prior event identities.
 identities[identity]=true
 if paused or bool(frame.paused): return []
 var command: Dictionary={"action":"play","id":id,"path":ROOT+id+".wav","variant_index":0,"gain_db":Bank.GAIN_DB,"max_voices":Bank.MAX_VOICES,"loop":false,"pitch_scale":1.0,"cast_key":scope_key+":"+str(event.get("boss_cast_id",event.actor_id+":phase2")),"identity":scope_key+":"+identity,"run_id":frame.run_id,"source_instance_id":frame.source_instance_id,"room_id":frame.room_id,"generation":frame.generation,"actor_id":event.actor_id,"sequence":event.sequence,"source_clock":"world","source_time":event.source_time,"observed_source_time":frame.source_time,"world_time":event.world_time,"position":point,"priority":1 if id.ends_with("anticipation") else 2,"candidate":"first_floor_boss_audio01","damage_receipt":false}
 counts[id]=int(counts.get(id,0))+1
 history.append(command.duplicate(true))
 if history.size()>128: history.pop_front()
 return [command]
func consume(event: Dictionary,state: Dictionary) -> Array:
 if closed: return []
 if state.get("schema","")!="ink-q1-presenter-1" or state.get("rules_hash","")!=RULES_HASH: return _reject("unbound_presenter")
 var frame: Dictionary=state.get("boss_audio",{})
 if frame.get("schema","")!="first-floor-boss-audio-1": return _reject("unbound_boss_snapshot")
 var room: String=str(frame.get("room_id",""))
 var gen: int=int(frame.get("generation",-1))
 var source: int=int(frame.get("source_instance_id",0))
 var seq: int=int(event.get("sequence",-1))
 var now: float=float(frame.get("source_time",-1.0))
 var world: float=float(frame.get("world_time",-1.0))
 var at: float=float(event.get("world_time",-1.0))
 if room.is_empty() or gen<0 or source<=0 or seq<0 or seq!=int(frame.get("event_sequence",-2)): return _reject("identity_or_current_sequence")
 if room!=event.get("room_id","") or gen!=int(event.get("generation",-1)) or room!=state.get("scope",{}).get("room_id","") or gen!=int(state.get("scope",{}).get("generation",-1)): return _reject("scope_mismatch")
 if not is_finite(now) or not is_finite(world) or not is_finite(at) or now<0.0 or absf(world-at)>.00001: return _reject("source_clock")
 var incoming: String=JSON.stringify([source,str(frame.get("run_id","")),room,gen])
 if retired_scopes.has(incoming): return _reject("retired_scope")
 if scope_key.is_empty(): scope_key=incoming
 elif scope_key!=incoming: return close("scope_changed_requires_reset")
 if seq<=last_sequence: return _reject("duplicate_or_old_sequence")
 last_sequence=seq
 var kind: String=str(event.get("kind",""))
 if kind in ["encounter_finished","hero_died","hero_death"] or bool(frame.get("hero_dead",false)): return close("hero_or_encounter_ended")
 if kind=="kill" and event.get("enemy_kind","")=="boss":
  var dead_actor: String=str(event.get("target",""))
  var dead_row: Dictionary=frame.get("bosses",{}).get(dead_actor,{})
  if dead_actor.is_empty() or dead_row.is_empty() or not _match(frame,dead_row,["run_id","source_instance_id","room_id","generation"]) or not bool(dead_row.get("dead",false)) or dead_row.get("state","")!="dead" or event.get("position")!=dead_row.get("position"): return _reject("death_not_in_snapshot")
  if retired_actors.has(dead_actor): return _reject("duplicate_boss_death")
  retired_actors[dead_actor]=true
  for root_id: String in warnings:
   if warnings[root_id].actor_id==dead_actor: retired_casts[root_id]=true
  # Owner-local retirement must not silence unrelated hero voices. Existing
  # finite one-shots may finish (<= .42s); no future Boss cue can be admitted.
  return []
 if kind!="enemy_warning" and not kind.begins_with("boss_"): return []
 if kind=="enemy_warning" and event.get("enemy_kind","")!="boss": return []
 if bool(event.get("preview_only",false)): return _reject("preview")
 var actor: String=str(event.get("actor_id",""))
 var row: Dictionary=frame.get("bosses",{}).get(actor,{})
 if actor.is_empty() or row.is_empty() or retired_actors.has(actor): return _reject("unknown_or_retired_actor")
 if not _match(frame,row,["run_id","source_instance_id","room_id","generation"]): return _reject("actor_scope")
 # Terminal cancellation can be delivered after the source becomes inactive.
 if kind!="boss_cast_cancelled" and (not bool(row.get("current",false)) or frame.get("phase","")!="combat"): return _reject("inactive_owner")
 if kind in ["boss_front_advanced","boss_hit_receipt","boss_phase_finished"]: return []
 var source_at: float=float(event.get("source_time",-1.0))
 if not is_finite(source_at) or absf(source_at-now)>.00001: return _reject("event_source_time")
 if kind=="boss_phase_started":
  if int(event.get("phase",0))!=2 or int(row.get("phase",0))!=2 or not bool(row.get("transition_done",false)) or row.get("state","")!="boss_transition" or not bool(event.get("vulnerable",false)) or not row.get("cast",{}).is_empty(): return _reject("phase_not_in_snapshot")
  if absf(float(event.get("duration",-1.0))-1.6)>.00001 or absf(float(row.get("timer",-1.0))-1.6)>.00001 or phase_seen.has(actor): return _reject("duplicate_or_invalid_phase")
  phase_seen[actor]=true
  return _cue("boss_phase_crack",event,frame,actor+":phase2",row.position)
 var cast_id: String=str(event.get("boss_cast_id",""))
 var move: String=str(event.get("boss_move",""))
 if cast_id.is_empty() or move not in ["A","B","C"] or not _match(event,frame,["run_id","source_instance_id","room_id","generation"]): return _reject("cast_identity")
 if retired_casts.has(cast_id): return _reject("retired_cast")
 var live: Dictionary=row.get("cast",{})
 if kind=="enemy_warning":
  if warnings.has(cast_id) or row.state!="warning" or bool(live.get("released",true)) or not _cast_matches(event,live) or not bool(event.get("committed",false)): return _reject("warning_not_in_snapshot")
  warnings[cast_id]=event.duplicate(true)
  return _cue("boss_"+move.to_lower()+"_anticipation",event,frame,cast_id+":warning",event.position)
 if not warnings.has(cast_id) or not _match(event,warnings[cast_id],STABLE): return _reject("unobserved_or_mismatched_cast")
 if kind=="boss_cast_cancelled":
  if not live.is_empty(): return _reject("cancel_cast_still_live")
  retired_casts[cast_id]=true
  # No targeted stop exists in the unchanged shared output. Retire only this
  # root; its already-started short tail may finish without silencing heroes.
  return []
 if kind=="boss_cast_finished":
  if not released.has(cast_id) or not live.is_empty() or row.state!="recover": return _reject("finish_not_in_snapshot")
  retired_casts[cast_id]=true
  return []
 if kind=="boss_attack_released":
  if released.has(cast_id) or row.state!="boss_active" or not bool(live.get("released",false)) or not _cast_matches(event,live): return _reject("release_not_in_snapshot")
  released[cast_id]=true
  # C release and stone 0 occur in the same source callback chain. Only the
  # actual landed event owns its impact; release never makes a duplicate.
  if move=="C": return []
  return _cue("boss_"+move.to_lower()+"_impact",event,frame,cast_id+":release",event.position)
 if kind=="boss_rock_landed":
  if move!="C" or not released.has(cast_id) or row.state!="boss_active" or not bool(live.get("released",false)) or not _match(event,live,["boss_cast_id","run_id","source_instance_id","room_id","generation","phase","target_actor_id","geometry"]): return _reject("rock_without_live_release")
  var index: int=int(event.get("stone_index",-1))
  var points: Array=live.get("geometry",{}).get("points",[])
  if index<0 or index>=points.size() or index>1 or int(live.get("rocks_done",0))!=index+1 or event.get("segment_id","")!="rock:%d"%index or event.get("position")!=points[index] or event.get("radius")!=live.geometry.get("radius"): return _reject("rock_not_in_snapshot")
  return _cue("boss_c_impact",event,frame,cast_id+":rock:%d"%index,event.position)
 return []
func snapshot() -> Dictionary:
 return {"scope":scope_key,"last_sequence":last_sequence,"paused":paused,"closed":closed,"ended":ended,"counts":counts.duplicate(true),"rejected":rejected.duplicate(true),"history":history.duplicate(true),"max_voices":Bank.MAX_VOICES,"hardware_listening":false,"runtime_qualified":false,"owns_bus":false}
