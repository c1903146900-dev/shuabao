extends RefCounted
## Source-backed, read-only distance passives. No timers, snapshots or actor writes.
## The caller owns the already-final/replay exclusion and current contact positions.
const ITEMS := {"final:B03":"passive:14", "final:C06":"passive:15", "final:D03":"passive:14"}
const PASSIVE_IDS := ["passive:14", "passive:15"]
const TUNING_SPECS := {
 "passive:14":[["range_threshold", "meters"], ["damage_bonus", "percent_points"], ["lifesteal", "percent_points"]],
 "passive:15":[["range_threshold", "meters"], ["damage_bonus", "percent_points"], ["penetration", "penetration_points"]]
}

static func valid_tuning(passive_id: String, tuning: Dictionary) -> bool:
 if not TUNING_SPECS.has(passive_id): return false
 for spec: Array in TUNING_SPECS[passive_id]:
  var value: Variant = tuning.get(str(spec[0]))
  if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0: return false
 return true

static func select_unique(inventory: Array, definitions: Dictionary) -> Dictionary:
 var result: Dictionary = {"equipped":false, "passives":{}, "constant_stats":{}}
 var seen: Dictionary = {}
 for held: Variant in inventory:
  if not held is Dictionary: continue
  var item_id: Variant = held.get("id")
  if not item_id is String or not ITEMS.has(item_id): continue
  var uid: Variant = held.get("uid")
  var count: Variant = held.get("count")
  if not uid is int or int(uid) < 0 or not count is int or int(count) <= 0: continue
  if seen.has(uid): continue
  var definition: Variant = definitions.get(item_id)
  if not definition is Dictionary or definition.get("supported", false) != true: continue
  var passive_id: String = ITEMS[item_id]
  if not definition.get("passives") is Array or passive_id not in definition.passives: continue
  var tuning: Variant = definition.get("distance_passive")
  if not tuning is Dictionary or not valid_tuning(passive_id, tuning): continue
  seen[uid] = true
  if result.passives.has(passive_id):
   if result.passives[passive_id].tuning != tuning or int(result.passives[passive_id].owned_copies) > 9223372036854775807-int(count): return {"equipped":false,"passives":{},"constant_stats":{}}
   result.passives[passive_id].owned_copies += int(count)
   continue
  result.equipped = true
  result.passives[passive_id] = {"passive_id":passive_id, "item_id":item_id, "uid":int(uid), "owned_copies":int(count), "tuning":tuning.duplicate(true)}
  # User clarified both extra stats are constant. Grant them once per named
  # passive, outside definition.stats, which the ledger multiplies by copies.
  if passive_id == "passive:14": result.constant_stats["lifesteal"] = float(tuning.lifesteal) / 100.0
  if passive_id == "passive:15": result.constant_stats["penetration"] = float(tuning.penetration)
 return result

static func factor(hero_position: Variant, enemy_position: Variant, selection: Dictionary) -> float:
 if not _valid_position(hero_position) or not _valid_position(enemy_position): return 1.0
 if selection.get("equipped", false) != true or not selection.get("passives") is Dictionary: return 1.0
 var origin: Vector3 = hero_position
 var target: Vector3 = enemy_position
 var distance: float = origin.distance_to(target)
 if not is_finite(distance): return 1.0
 var multiplier: float = 1.0
 for passive_id: String in PASSIVE_IDS:
  var entry: Variant = selection.passives.get(passive_id)
  if not _valid_selected(passive_id, entry): continue
  var tuning: Dictionary = entry.tuning
  # The source thresholds are inclusive. Do not widen either side by epsilon.
  var qualifies: bool = distance <= float(tuning.range_threshold) if passive_id == "passive:14" else distance >= float(tuning.range_threshold)
  if qualifies: multiplier *= 1.0 + float(tuning.damage_bonus) / 100.0
 return multiplier if is_finite(multiplier) else 1.0

static func _valid_position(value: Variant) -> bool:
 return value is Vector3 and is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

static func _valid_selected(passive_id: String, entry: Variant) -> bool:
 if not entry is Dictionary or entry.get("passive_id", "") != passive_id: return false
 var item_id: Variant = entry.get("item_id")
 if not item_id is String or not ITEMS.has(item_id) or ITEMS[item_id] != passive_id: return false
 var uid: Variant = entry.get("uid")
 var copies: Variant = entry.get("owned_copies")
 if not uid is int or int(uid) < 0 or not copies is int or int(copies) <= 0: return false
 var tuning: Variant = entry.get("tuning")
 return tuning is Dictionary and valid_tuning(passive_id, tuning)
