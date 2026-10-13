extends "res://tests/ink_river_hexes_20261006/candidate01/sim.gd"
## Same real Q2 root owns every H03 leg and H04 sunset packet. Provenance is
## preserved; the existing P1 collector and P2 use epoch remain sole owners.
var _river_hex_packet_frames: Array = []
var river_hex_terminal_deferrals: Array = []

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
 # H03 changes this exact river's path. H04 reuses this exact Q2 cast/state;
 # neither is another use or permission to cancel the complete Q2 collector.
 _p1_q2_rivers[id] = matched

func _q2_damage(state: Dictionary, enemy: Dictionary, at: float, kind: String, tick: int, position: Vector3, impact: Dictionary) -> void:
 if kind != "sunset":
  super._q2_damage(state,enemy,at,kind,tick,position,impact)
  return
 var frame: Dictionary = {"state":state,"enemy":enemy,"at":at,"tick":tick,"admitted":bool(impact.get("_h04_sample_current",false)) and _q2_target_current(enemy,state)}
 _river_hex_packet_frames.append(frame)
 super._q2_damage(state,enemy,at,kind,tick,position,impact)
 if not _river_hex_packet_frames.is_empty() and is_same(_river_hex_packet_frames.back(),frame): _river_hex_packet_frames.pop_back()

func _river_hex_original_packet(source: String, id: int, metadata: Dictionary) -> bool:
 if source != "hex_yanguizhou_h04" or _river_hex_packet_frames.is_empty(): return false
 if bool(metadata.get("replay",false)) or bool(metadata.get("p1_supplement",false)) or bool(metadata.get("p2_generated",false)) or bool(metadata.get("basic_attack",false)): return false
 if not bool(metadata.get("active_skill",false)) or not bool(metadata.get("hex_generated",false)) or not bool(metadata.get("area",false)): return false
 var frame: Dictionary = _river_hex_packet_frames.back()
 var state: Dictionary = frame.state
 if not bool(frame.admitted) or not _q2_current(state) or not bool(state.h04_at_completion) or int(state.cast_id) != id: return false
 var receipt: Dictionary = metadata.get("q2_receipt",{})
 var target_id: String = str(frame.enemy.actor_id)
 var effect_id: String = "%s:sunset:%d:%s"%[str(state.river_id),int(frame.tick),target_id]
 return str(receipt.get("river_id",""))==str(state.river_id) and int(receipt.get("cast_id",0))==id and int(receipt.get("generation",-1))==int(state.generation) and str(receipt.get("room_id",""))==str(state.room_id) and str(receipt.get("target_id",""))==target_id and str(receipt.get("kind",""))=="sunset" and int(receipt.get("tick",0))==int(frame.tick) and float(receipt.get("source_time",-1.0))==float(frame.at) and str(receipt.get("effect_id",""))==effect_id and str(metadata.get("effect_id",""))==effect_id

func _p1_packet_allowed(source: String, id: int, metadata: Dictionary) -> bool:
 if source != "hex_yanguizhou_h04": return super._p1_packet_allowed(source,id,metadata)
 if not _river_hex_original_packet(source,id,metadata) or not _p1_q2_rivers.has(id): return false
 var state: Dictionary = _p1_q2_rivers[id]
 return _p1_q2_owned_river(state) and not bool(p1.roots[id].settled) and is_same(state,_river_hex_packet_frames.back().state)

func _p2_packet_allowed(source: String, id: int, metadata: Dictionary) -> bool:
 if source != "hex_yanguizhou_h04": return super._p2_packet_allowed(source,id,metadata)
 # Preserve actual source/Hex metadata. Only this verified original packet
 # consults Q2's already-completed use record and ready-epoch entitlement.
 return _river_hex_original_packet(source,id,metadata) and _p2_sync() and cast_is_current(id) and p2.packet_entitled(id,"q2")

func emit_event(kind: String, data: Dictionary = {}) -> void:
 if kind == "damage" and str(data.get("source","")) == "hex_yanguizhou_h04" and not _p2_frames.is_empty():
  var frame: Dictionary = _p2_frames.back()
  var matches: bool = not bool(frame.seen) and str(frame.source)=="hex_yanguizhou_h04" and str(data.get("target",""))==str(frame.enemy.get("actor_id","")) and int(data.get("cast_id",0))==int(frame.cast_id)
  if matches:
   # Reserve the real damage event before callbacks. The inherited P2 emitter
   # sees it as processed; its packet source and P1 capture remain unchanged.
   frame.seen = true
   if bool(frame.eligible) and int(frame.scope_epoch)==_p2_scope_epoch and _ink_scope_current(frame.scope) and _p2_selected() and float(data.get("amount",0.0))>0.0:
    common.refresh_stats()
    var receipt: Dictionary = p2.claim_positive(int(frame.cast_id),"q2",int(frame.packet_serial),float(data.amount),data.position,float(hero.stats.ap),hero_time)
    if receipt.status == "CLAIMED":
     receipt.merge(frame.source_info,true)
     receipt.target_id = str(data.target)
     receipt["original_packet_source"] = "hex_yanguizhou_h04"
     _p2_queue_splash(receipt)
     common.refresh_stats()
 super.emit_event(kind,data)

func _q2_finish(state: Dictionary, reason: String, at: float) -> void:
 if _p1_q2_owned_river(state) and not bool(state.get("retired",false)) and reason == "expired":
  var id: int = int(state.cast_id)
  var finish_at: float = maxf(float(state.expires_at),float(state.sunset_expires_at) if bool(state.h04_at_completion) else float(state.expires_at))
  var pending: bool = paused or not _q2_motion_resume.is_empty() or int(p1.roots[id].depth)>0
  for hit: Dictionary in _q2_deferred_contacts:
   if int(hit.state.cast_id)==id: pending=true
  if bool(state.h04_at_completion):
   var count: int = int(round(T.hex_parameter("H04-1")/T.hex_parameter("H04-4")))
   pending = pending or int(state.next_sunset_tick)<=count
  # Current source river durations are all >= H04's four seconds, so the
  # existing exact expiry terminal is already the whole-root terminal. Keep
  # that original collector/milestone rather than adding a second completion.
  if pending or at!=finish_at or hero_time<finish_at-TIME_EPS:
   river_hex_terminal_deferrals.append({"cast_id":id,"attempted_at":at,"finish_at":finish_at,"pending":pending,"source_time":hero_time})
   if river_hex_terminal_deferrals.size()>32: river_hex_terminal_deferrals.pop_front()
   return
 super._q2_finish(state,reason,at)

func _hero_clear_transients() -> void:
 _river_hex_packet_frames.clear(); river_hex_terminal_deferrals.clear()
 super._hero_clear_transients()

func river_hex_fixture_status() -> Dictionary:
 return {"source_candidate":true,"h04_ordering":"committed_jumps_then_atomic_tick_snapshot","h03_input":"Ctrl+fresh_LMB_in_Q2_B_preview","engine":"NOT_RUN","ordinary_admission":false,"p1_hex_ownership":"same_complete_Q2_root_candidate","p2_h04_eligibility":"same_Q2_use_epoch_candidate","native_input":"NOT_RUN","art_audio_accepted":false,"real_multiplayer":false}
