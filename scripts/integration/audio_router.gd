extends Node
## Bounded presentation only. Authoritative events trigger sound; sound never triggers rules.
const Audio = preload("res://scripts/audio/combat_audio.gd")
var sfx: Node
var last_sequence := -1
var ui_seen := {}
var hit_groups := {}
var counts := {}
var history: Array = []
func _ready() -> void:
 sfx = Audio.new()
 add_child(sfx)
func cue(id: String, source: String) -> void:
 var played: bool = sfx.play_event(id)
 counts[id] = int(counts.get(id,0)) + 1
 history.append({"id":id,"source":source,"played":played})
 if history.size() > 64: history.pop_front()
func combat(event: Dictionary) -> void:
 var seq: int = event.get("sequence",-1)
 if seq <= last_sequence: return
 last_sequence = seq
 var kind: String = event.kind
 var id: String = {"attack_started":"sword","dash":"dash","q1":"q_thrust","q2_hit":"q_thrust","q3_wave":"q_thrust","e2_spin":"sword","r2_throw":"sword","overload_started":"e_overload","ultimate_impact":"r_slam","hero_damaged":"hurt","kill":"enemy_die"}.get(kind,"")
 if kind in ["damage","hero_damaged"] and event.get("amount",0) <= 0: return
 if kind == "damage":
  # One transient per cast/world tick across targets and E3 extra packets.
  # R1 already owns a single slam cue at its actual impact event.
  if str(event.get("source","")).begins_with("r1"): return
  var group := "%s:%s:%s" % [event.combat_level_id,event.get("cast_id",-1),event.world_time]
  if hit_groups.has(group): return
  hit_groups[group] = true
  if hit_groups.size() > 128: hit_groups.erase(hit_groups.keys()[0])
  id = "hit_heavy" if event.get("critical",false) else "hit"
 if not id.is_empty(): cue(id,"combat:%s:%d" % [event.combat_level_id,seq])
func ui(request: Dictionary, result: Dictionary) -> void:
 var id: String = request.get("command_id","")
 if id.is_empty() or ui_seen.has(id): return
 ui_seen[id] = true
 if ui_seen.size() > 256: ui_seen.erase(ui_seen.keys()[0])
 cue("ui_confirm" if result.accepted else "ui_reject","ui:"+id)
func snapshot() -> Dictionary:
 return {"player":sfx.snapshot(),"counts":counts.duplicate(),"history":history.duplicate(true),"last_sequence":last_sequence}
