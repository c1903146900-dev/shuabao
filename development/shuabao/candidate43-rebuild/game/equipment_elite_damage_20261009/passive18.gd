extends RefCounted
## Pure shared-name selection for the two authored final-tier giant hunters.
## The trusted Model owns G06 evolution, actual damage receipts and task state.
const Original = preload("res://equipment_expansion_20261009/passive18.gd")
const PASSIVE_ID := "passive:18"
const ITEM_ID := "final:G06"
const ITEMS := ["final:A05", "final:G06"]
const TUNING_KEYS := ["base_damage_bonus", "damage_bonus_cap", "lost_hp_step", "step_damage_bonus"]

static func valid_tuning(tuning: Dictionary) -> bool:
 if tuning.size() != TUNING_KEYS.size(): return false
 return Original.valid_tuning(tuning)

static func select_unique(inventory: Array, definitions: Dictionary, g06_evolved: bool = false) -> Dictionary:
 var result: Dictionary = _empty()
 var seen: Dictionary = {}
 for value: Variant in inventory:
  if not value is Dictionary or value.get("id", "") not in ITEMS: continue
  var uid: Variant = value.get("uid")
  var count: Variant = value.get("count")
  if not uid is int or int(uid) < 0 or not count is int or int(count) <= 0: continue
  var item_id: String = str(value.id)
  if seen.has(uid):
   if str(seen[uid]) != item_id: return _empty("conflicting_inventory_uid")
   continue
  seen[uid] = item_id
  var definition: Variant = definitions.get(item_id)
  if not definition is Dictionary or definition.get("supported", false) != true: continue
  # Both authoritative suppliers are final-tier. Do not invent a tier mapping
  # for a malformed/foreign definition or infer another source by passive name.
  if definition.get("tier", "") != "final" or definition.get("passives") != [PASSIVE_ID]: continue
  var evolved: bool = item_id == ITEM_ID and g06_evolved
  var tuning: Variant = definition.get("passive18_evolved" if evolved else "passive18")
  if not tuning is Dictionary or not valid_tuning(tuning): continue
  result.owned_copies += int(count)
  if result.equipped:
   var order: int = compare_same_tier(tuning, result.tuning)
   # A future edit that crosses base/cap strengths needs an explicit rule.
   # Returning a reason avoids silently choosing a lexicographic ordering.
   if order == 2: return _empty("ambiguous_same_tier_strength")
   if order <= 0: continue
  result.equipped = true
  result.tuning = tuning.duplicate(true)
  result.item_id = item_id
  result.uid = int(uid)
  result.evolved = evolved
 return result

static func compare_same_tier(candidate: Dictionary, incumbent: Dictionary) -> int:
 # 1 stronger, -1 weaker, 0 equal, 2 not ordered by the authored rule.
 if not valid_tuning(candidate) or not valid_tuning(incumbent): return 2
 if candidate.lost_hp_step != incumbent.lost_hp_step or candidate.step_damage_bonus != incumbent.step_damage_bonus: return 2
 var base: float = float(candidate.base_damage_bonus) - float(incumbent.base_damage_bonus)
 var cap: float = float(candidate.damage_bonus_cap) - float(incumbent.damage_bonus_cap)
 if base == 0.0 and cap == 0.0: return 0
 if base >= 0.0 and cap >= 0.0: return 1
 if base <= 0.0 and cap <= 0.0: return -1
 return 2

static func factor(enemy: Dictionary, tuning: Dictionary) -> float:
 # Delegate the exact original pre-hit floor calculation, including all HP
 # validation, neutral ranks, zero-increment handling and no epsilon rounding.
 if not valid_tuning(tuning): return 1.0
 return Original.factor(enemy, tuning)

static func _empty(reason: String = "") -> Dictionary:
 return {"equipped":false, "tuning":{}, "item_id":"", "uid":-1, "owned_copies":0, "passive_id":PASSIVE_ID, "evolved":false, "reason":reason}
