extends "res://tests/ink_e2_boundary_20261006/ordinary01/e2_boundary.gd"
## Current P1/R1 Sim plus the exact three E2 source layers. Each transplanted
## layer changes only its extends line. This leaf connects E2 to the SAME P1
## collector, final settlement, health authority and original lifesteal path.
var _p1_e2_boats: Dictionary = {}
var _p1_e2_terminal_frames: Array = []

func new_cast(slot: String, stage: String = "", extra: Dictionary = {}) -> Dictionary:
 var owner = hero
 var candidate: String = str(hero.loadout.get(slot,slot))
 var rank: int = int(hero.ranks.passive)
 var eligible: bool = slot == "e" and candidate == "e2" and hero.loadout.passive == "p1" and rank >= 1 and rank <= 4
 var bonus: float = T.fraction("P1-1",rank) if eligible else 0.0
 var refund: float = T.fraction("P1-2",rank) if eligible else 0.0
 var context: Dictionary = super.new_cast(slot,stage,extra)
 if eligible and effect_is_current(context) and is_same(hero,owner) and not hero.dead:
  p1.begin(context,owner,rank,bonus,refund)
 return context

func _e2_event(state: Dictionary, kind: String, at: float) -> void:
 if kind == "launched":
  var id: int = int(state.cast_id)
  if p1.roots.has(id) and _p1_current(p1.roots[id]) and str(p1.roots[id].context.candidate) == "e2":
   if _p1_e2_boats.has(id): p1.cancel(id)
   else: _p1_e2_boats[id] = state
 super._e2_event(state,kind,at)

func _p1_e2_owned(state: Dictionary) -> bool:
 var id: int = int(state.get("cast_id",0))
 return _p1_e2_boats.has(id) and is_same(_p1_e2_boats[id],state) and p1.roots.has(id) and str(p1.roots[id].context.candidate) == "e2" and _p1_current(p1.roots[id])

func _p1_packet_allowed(source: String, id: int, metadata: Dictionary) -> bool:
 if not super._p1_packet_allowed(source,id,metadata): return false
 if source != "e2": return true
 if not _p1_e2_boats.has(id) or not _p1_e2_owned(_p1_e2_boats[id]): return false
 var state: Dictionary = _p1_e2_boats[id]
 var event_id: String = str(metadata.get("effect_id",""))
 var packet: Dictionary = _e2_packets.get(event_id,{})
 return not packet.is_empty() and is_same(packet.state,state) and str(metadata.get("parent_skill","")) == "e2" and str(metadata.get("segment_id","")) in ["outward_voyage","teleport_burst","unboarded_end_burst"] and not bool(metadata.get("hex_generated",false)) and int(metadata.get("generation",-1)) == int(state.generation) and str(metadata.get("room_id","")) == str(state.room_id)

func _e2_complete(state: Dictionary, reason: String, at: float) -> void:
 if not _p1_e2_owned(state):
  super._e2_complete(state,reason,at)
  return
 var id: int = int(state.cast_id)
 var frame: Dictionary = {"state":state,"cast_id":id,"boat_id":str(state.boat_id),"reason":reason,"at":at,"seen":false}
 _p1_e2_terminal_frames.append(frame)
 p1.enter(id)
 super._e2_complete(state,reason,at)
 if not _p1_e2_terminal_frames.is_empty() and is_same(_p1_e2_terminal_frames.back(),frame): _p1_e2_terminal_frames.pop_back()
 if bool(frame.seen) and _p1_e2_boats.has(id) and is_same(_p1_e2_boats[id],state): _p1_e2_boats.erase(id)
 p1.leave(id)
 _p1_flush(id)

func emit_event(kind: String, data: Dictionary = {}) -> void:
 var milestone: int = 0
 if kind == "ink_e2_finished" and not _p1_e2_terminal_frames.is_empty():
  var frame: Dictionary = _p1_e2_terminal_frames.back()
  var state: Dictionary = frame.state
  if not bool(frame.seen) and _p1_e2_owned(state) and bool(state.retired) and bool(state.damage_stages_complete) and int(state.inflight_packets) == 0 and int(data.get("cast_id",0)) == int(frame.cast_id) and str(data.get("boat_id","")) == str(frame.boat_id) and str(data.get("reason","")) == str(frame.reason) and str(frame.reason) in ["boarded","unboarded"] and float(data.get("finished_at",-1.0)) == float(frame.at) and bool(data.get("damage_stages_complete",false)) and int(data.get("generation",-1)) == int(state.generation) and str(data.get("room_id","")) == str(state.room_id):
   frame.seen = true
   milestone = int(frame.cast_id)
   p1.enter(milestone)
   p1.complete(milestone)
 super.emit_event(kind,data)
 if milestone != 0:
  p1.leave(milestone)
  _p1_flush(milestone)

func _p1_lifesteal_source(kind: String, data: Dictionary) -> Dictionary:
 if str(data.get("parent_skill","")) != "e2": return super._p1_lifesteal_source(kind,data)
 if kind != "damage" or str(data.get("source","")) != "yanguizhou_p1" or not bool(data.get("p1_supplement",false)) or str(data.get("damage_type","")) != "final_supplement" or not bool(data.get("final_damage_already_settled",false)): return {}
 var id: int = int(data.get("cast_id",0))
 if not p1.roots.has(id): return {}
 var state: Dictionary = p1.roots[id]
 if not bool(state.settled) or state.targets.size() != 1 or str(state.context.candidate) != "e2": return {}
 var key: String = "%d:%s:%d" % [int(state.context.generation),str(state.context.room_id),id]
 if _p1_lifesteal_claims.has(key): return {}
 var enemy: Dictionary = state.targets[0].enemy
 var amount: float = float(data.get("amount",0.0))
 if not is_finite(amount) or amount <= 0.0 or str(data.get("target","")) != str(enemy.actor_id): return {}
 if not _p1_committed_scope_current(state,enemy) or hero.dead: return {}
 for committed: Dictionary in ink_p1_receipts:
  if int(committed.cast_id) == id and int(committed.generation) == int(state.context.generation) and str(committed.room_id) == str(state.context.room_id) and str(committed.candidate) == "e2" and str(committed.get("target_id","")) == str(enemy.actor_id) and bool(committed.qualified) and int(committed.distinct_targets) == 1 and float(committed.actual_supplement) == amount:
   return state
 return {}

func cancel_cast(id: int) -> void:
 _p1_e2_boats.erase(id)
 _p1_e2_terminal_frames = _p1_e2_terminal_frames.filter(func(frame): return int(frame.cast_id) != id)
 super.cancel_cast(id)

func _hero_clear_transients() -> void:
 _p1_e2_boats.clear()
 _p1_e2_terminal_frames.clear()
 super._hero_clear_transients()
