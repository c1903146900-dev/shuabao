extends RefCounted
## Read-only world observer. It never edits enemies, HP, inventory or actor stats.
## Center-distance <= radius; spawn telegraphs are not targetable enemies yet.
var _scope: String = ""
var _count: int = 0
func clear() -> void:
 _scope = ""
 _count = 0
func sample(sim: Node, tuning: Dictionary, equipped: bool) -> Dictionary:
 if not equipped or not is_instance_valid(sim) or sim.hero.dead or sim.phase != "combat":
  clear()
  return _result(tuning)
 var scope: String = "%s|%s|%s|%d" % [sim.get_instance_id(), sim.hero.actor_id, sim.room_id, sim.encounter_generation]
 if scope != _scope:
  clear()
  _scope = scope
 # A pause freezes source positions and the last completed sample. Lifecycle and
 # item removal above still invalidate it; a paused new scope starts at zero.
 if sim.paused: return _result(tuning)
 _count = 0
 var seen: Dictionary = {}
 if not sim.hero.position.is_finite(): return _result(tuning)
 for enemy: Dictionary in sim.enemies:
  var id: String = str(enemy.get("actor_id", ""))
  if id.is_empty() or seen.has(id): continue
  if bool(enemy.get("dead", true)) or not is_finite(float(enemy.get("hp", 0.0))) or float(enemy.get("hp", 0.0)) <= 0.0 or enemy.get("state", "spawn") == "spawn": continue
  if enemy.get("room_id", "") != sim.room_id or int(enemy.get("generation", -1)) != sim.encounter_generation: continue
  var position: Variant = enemy.get("position")
  if not position is Vector3 or not position.is_finite(): continue
  if sim.hero.position.distance_to(position) > float(tuning.radius): continue
  seen[id] = true
  _count += 1
  if _count >= int(tuning.enemy_cap): break
 _count = mini(_count, int(tuning.enemy_cap))
 return _result(tuning)
func _result(tuning: Dictionary) -> Dictionary:
 return {"enemy_count":_count,"scope":_scope,"stats":{"defense":_count * float(tuning.get("defense_per_enemy", 0.0)),"tenacity":_count * float(tuning.get("tenacity_per_enemy", 0.0)) / 100.0}}
