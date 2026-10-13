extends "res://tests/ink_e3_ordinary_20261006/ordinary01/e3_boundary.gd"
## E3 binds into the existing sole P1 collector and committed B09 supplement
## path. No new health, wallet, cooldown, common or world-step authority.
var _p1_e3_frames: Dictionary = {}
var _p1_e3_terminal_frames: Array = []
var _p1_e3_packet_frames: Array = []

func new_cast(slot: String, stage: String = "", extra: Dictionary = {}) -> Dictionary:
 var owner = hero
 var rank: int = int(hero.ranks.passive)
 var eligible: bool = slot == "e" and hero.loadout.e == "e3" and hero.loadout.passive == "p1" and rank >= 1 and rank <= 4
 var bonus: float = T.fraction("P1-1",rank) if eligible else 0.0
 var refund: float = T.fraction("P1-2",rank) if eligible else 0.0
 var context: Dictionary = super.new_cast(slot,stage,extra)
 if eligible and effect_is_current(context) and is_same(hero,owner) and not hero.dead:
  p1.begin(context,owner,rank,bonus,refund)
 return context

func _e3_event(state: Dictionary, kind: String, at: float) -> void:
 var id: int = int(state.cast_id)
 if kind == "first_placed" and _e3_live(state) and state.phase == "first" and p1.roots.has(id) and _p1_current(p1.roots[id]) and str(p1.roots[id].context.candidate) == "e3":
  if _p1_e3_frames.has(id): p1.cancel(id)
  else: _p1_e3_frames[id] = state
 if kind == "placement_expired":
  p1.cancel(id); _p1_e3_frames.erase(id)
 super._e3_event(state,kind,at)

func _p1_e3_owned(state: Dictionary) -> bool:
 var id: int = int(state.get("cast_id",0))
 return _p1_e3_frames.has(id) and is_same(_p1_e3_frames[id],state) and p1.roots.has(id) and str(p1.roots[id].context.candidate) == "e3" and _p1_current(p1.roots[id]) and _e3_context_current(state)

func damage_enemy(enemy: Dictionary, amount: float, source: String, cast_id: int = 0, is_true: bool = false, critical: bool = false, metadata: Dictionary = {}) -> bool:
 if source != "e3": return super.damage_enemy(enemy,amount,source,cast_id,is_true,critical,metadata)
 var event_id: String = str(metadata.get("effect_id",""))
 var packet: Dictionary = _e3_packets.get(event_id,{})
 var admitted: bool = not packet.is_empty() and is_same(packet.enemy,enemy) and not bool(packet.actual_seen) and _p1_e3_owned(packet.state) and _e3_live(packet.state) and packet.state.phase == "settling" and int(packet.state.cast_id) == cast_id and str(event_id) == str(packet.state.frame_id)+":swap_damage:"+str(enemy.actor_id)
 var frame: Dictionary = {"packet":packet,"effect_id":event_id,"cast_id":cast_id,"admitted":admitted}
 _p1_e3_packet_frames.append(frame)
 var result: bool = super.damage_enemy(enemy,amount,source,cast_id,is_true,critical,metadata)
 if not _p1_e3_packet_frames.is_empty() and is_same(_p1_e3_packet_frames.back(),frame): _p1_e3_packet_frames.pop_back()
 return result

func _p1_packet_allowed(source: String, id: int, metadata: Dictionary) -> bool:
 if not super._p1_packet_allowed(source,id,metadata): return false
 if source != "e3": return true
 if _p1_e3_packet_frames.is_empty(): return false
 var frame: Dictionary = _p1_e3_packet_frames.back()
 if not bool(frame.admitted) or int(frame.cast_id) != id or str(frame.effect_id) != str(metadata.get("effect_id","")): return false
 var state: Dictionary = frame.packet.state
 return _p1_e3_owned(state) and str(metadata.get("parent_skill","")) == "e3" and str(metadata.get("segment_id","")) == "swap_damage" and not bool(metadata.get("hex_generated",false)) and bool(metadata.get("active_skill",false)) and int(metadata.get("generation",-1)) == int(state.generation) and str(metadata.get("room_id","")) == str(state.room_id)

func _e3_dispatch_damage(state: Dictionary) -> void:
 var id: int = int(state.cast_id)
 p1.enter(id)
 super._e3_dispatch_damage(state)
 p1.leave(id)
 _p1_flush(id)

func _e3_finish_damage(state: Dictionary) -> void:
 # A terminal is genuine only after the current real packet batch is drained.
 if not _e3_live(state) or state.phase != "settling" or bool(state.damage_stages_complete) or bool(state.get("dispatching",false)) or int(state.damage_cursor) < state.pending_damage.size(): return
 if not _p1_e3_owned(state):
  super._e3_finish_damage(state)
  return
 var id: int = int(state.cast_id)
 var frame: Dictionary = {"state":state,"cast_id":id,"frame_id":str(state.frame_id),"at":hero_time,"seen":false}
 _p1_e3_terminal_frames.append(frame)
 p1.enter(id)
 super._e3_finish_damage(state)
 if not _p1_e3_terminal_frames.is_empty() and is_same(_p1_e3_terminal_frames.back(),frame): _p1_e3_terminal_frames.pop_back()
 if bool(frame.seen) and _p1_e3_frames.has(id) and is_same(_p1_e3_frames[id],state): _p1_e3_frames.erase(id)
 p1.leave(id)
 _p1_flush(id)

func emit_event(kind: String, data: Dictionary = {}) -> void:
 var milestone: int = 0
 if kind == "ink_e3_damage_finished" and not _p1_e3_terminal_frames.is_empty():
  var frame: Dictionary = _p1_e3_terminal_frames.back()
  var state: Dictionary = frame.state
  var original_receipt: bool = not ink_e3_finished.is_empty() and is_same(ink_e3_finished.back(),data)
  if original_receipt and not bool(frame.seen) and _p1_e3_owned(state) and bool(state.damage_stages_complete) and bool(state.release_completed) and state.phase in ["complete","return_window"] and int(state.damage_cursor) == state.pending_damage.size() and int(data.get("cast_id",0)) == int(frame.cast_id) and str(data.get("frame_id","")) == str(frame.frame_id) and float(data.get("finished_at",-1.0)) == float(frame.at) and bool(data.get("damage_stages_complete",false)) and int(data.get("generation",-1)) == int(state.generation) and str(data.get("room_id","")) == str(state.room_id):
   frame.seen = true; milestone = int(frame.cast_id)
   p1.enter(milestone); p1.complete(milestone)
 super.emit_event(kind,data)
 if milestone != 0:
  p1.leave(milestone); _p1_flush(milestone)

func _p1_lifesteal_source(kind: String, data: Dictionary) -> Dictionary:
 if str(data.get("parent_skill","")) != "e3": return super._p1_lifesteal_source(kind,data)
 if kind != "damage" or str(data.get("source","")) != "yanguizhou_p1" or not bool(data.get("p1_supplement",false)) or str(data.get("damage_type","")) != "final_supplement" or not bool(data.get("final_damage_already_settled",false)): return {}
 var id: int = int(data.get("cast_id",0))
 if not p1.roots.has(id): return {}
 var state: Dictionary = p1.roots[id]
 if not bool(state.settled) or state.targets.size() != 1 or str(state.context.candidate) != "e3": return {}
 var key: String = "%d:%s:%d" % [int(state.context.generation),str(state.context.room_id),id]
 if _p1_lifesteal_claims.has(key): return {}
 var enemy: Dictionary = state.targets[0].enemy
 var amount: float = float(data.get("amount",0.0))
 if not is_finite(amount) or amount <= 0.0 or str(data.get("target","")) != str(enemy.actor_id): return {}
 if not _p1_committed_scope_current(state,enemy) or hero.dead: return {}
 for committed: Dictionary in ink_p1_receipts:
  if int(committed.cast_id) == id and int(committed.generation) == int(state.context.generation) and str(committed.room_id) == str(state.context.room_id) and str(committed.candidate) == "e3" and str(committed.get("target_id","")) == str(enemy.actor_id) and bool(committed.qualified) and int(committed.distinct_targets) == 1 and float(committed.actual_supplement) == amount:
   return state
 return {}

func cancel_cast(id: int) -> void:
 _p1_e3_frames.erase(id)
 _p1_e3_terminal_frames = _p1_e3_terminal_frames.filter(func(frame): return int(frame.cast_id) != id)
 super.cancel_cast(id)

func _hero_clear_transients() -> void:
 _p1_e3_frames.clear(); _p1_e3_terminal_frames.clear(); _p1_e3_packet_frames.clear()
 super._hero_clear_transients()
