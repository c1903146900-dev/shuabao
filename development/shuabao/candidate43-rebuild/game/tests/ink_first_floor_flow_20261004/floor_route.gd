extends RefCounted
## Linear technical coordinator schema; no room count, map theme or enemy balance implied.
const ENEMY_KINDS = ["minion", "pouncer", "armored", "ranged", "pitcher", "support", "elite", "boss"]

static func validate(route: Dictionary, allow_fixture: bool = false) -> Dictionary:
 if route.get("schema_version", 0) != 1: return _deny("floor_schema_mismatch")
 if route.get("hero_id", "") != "yanguizhou": return _deny("floor_hero_mismatch")
 if str(route.get("floor_id", "")).is_empty() or str(route.get("version", "")).is_empty(): return _deny("floor_identity_missing")
 if route.get("completion_rule", "") != "boss_defeated_and_coordinator_completed": return _deny("floor_completion_rule_missing")
 if route.get("content_status", "") == "technical_fixture":
  if not allow_fixture: return _deny("fixture_route_not_release_content")
 elif route.get("content_status", "") != "authored_candidate":
  return _deny("floor_content_unconfigured")
 var nodes = route.get("nodes")
 if not nodes is Array or nodes.is_empty(): return _deny("floor_nodes_missing")
 var ids: Dictionary = {}
 var boss_rooms := 0
 for index in range(nodes.size()):
  if not nodes[index] is Dictionary: return _deny("floor_node_invalid")
  var node: Dictionary = nodes[index]
  var id: String = str(node.get("id", ""))
  if id.is_empty() or id.contains("/") or id.contains("|") or ids.has(id): return _deny("floor_node_id_invalid")
  ids[id] = true
  if node.get("kind", "") not in ["ordinary", "elite", "boss"]: return _deny("floor_node_kind_invalid")
  if not node.get("training_after", false) is bool: return _deny("floor_training_flag_invalid")
  var roster = node.get("roster")
  if not roster is Array or roster.is_empty(): return _deny("floor_roster_missing")
  var bosses := 0
  for entry in roster:
   if not entry is Dictionary: return _deny("floor_roster_entry_invalid")
   if entry.get("kind", "") not in ENEMY_KINDS: return _deny("floor_enemy_kind_unknown")
   if entry.has("hp") or entry.has("reward") or entry.has("level"): return _deny("floor_roster_cannot_override_balance")
   var position = entry.get("position")
   if not position is Array or position.size() != 3: return _deny("floor_position_invalid")
   for value in position:
    if not (value is int or value is float) or not is_finite(float(value)): return _deny("floor_position_invalid")
   if entry.kind == "boss": bosses += 1
  if node.kind == "boss":
   boss_rooms += 1
   if bosses != 1 or index != nodes.size() - 1: return _deny("floor_final_boss_invalid")
  elif bosses != 0: return _deny("floor_unregistered_boss")
 if boss_rooms != 1: return _deny("floor_final_boss_missing")
 return {"accepted":true, "reason":""}

static func roster(node: Dictionary) -> Array:
 var result: Array = []
 for entry in node.roster:
  result.append({"kind":entry.kind, "position":Vector3(entry.position[0], entry.position[1], entry.position[2])})
 return result

static func _deny(reason: String) -> Dictionary:
 return {"accepted":false, "reason":reason}
