extends RefCounted
## Pure source-backed giant-hunter projection. No Sim, clocks, HP or ledger writes.
## The existing damage pipeline owns snapshot/replay and already-final packets.
const PASSIVE_ID := "passive:18"
const ITEM_ID := "final:A05"
const TUNING_KEYS := ["base_damage_bonus", "damage_bonus_cap", "lost_hp_step", "step_damage_bonus"]

static func valid_tuning(tuning: Dictionary) -> bool:
 for key: String in TUNING_KEYS:
  var value: Variant = tuning.get(key)
  if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0: return false
 return float(tuning.lost_hp_step) > 0.0 and float(tuning.damage_bonus_cap) >= float(tuning.base_damage_bonus)

static func select_unique(inventory: Array, definitions: Dictionary) -> Dictionary:
 var result: Dictionary = {"equipped":false, "tuning":{}, "item_id":"", "uid":-1, "owned_copies":0, "passive_id":PASSIVE_ID}
 var definition: Variant = definitions.get(ITEM_ID)
 if not definition is Dictionary or definition.get("supported", false) != true: return result
 if not definition.get("passives") is Array or PASSIVE_ID not in definition.passives: return result
 var tuning: Variant = definition.get("passive18")
 if not tuning is Dictionary or not valid_tuning(tuning): return result
 var seen: Dictionary = {}
 for value: Variant in inventory:
  if not value is Dictionary or value.get("id", "") != ITEM_ID: continue
  var uid: Variant = value.get("uid")
  var count: Variant = value.get("count")
  if not uid is int or int(uid) < 0 or not count is int or int(count) <= 0: continue
  if seen.has(uid): continue
  seen[uid] = true
  result.owned_copies += int(count)
  if result.equipped: continue
  result.equipped = true
  result.tuning = tuning.duplicate(true)
  result.item_id = ITEM_ID
  result.uid = int(uid)
 # Only this admitted A05 item can supply the mechanism. G06's stronger task
 # version remains unavailable; never infer it from a matching passive name.
 return result

static func factor(enemy: Dictionary, tuning: Dictionary) -> float:
 if not valid_tuning(tuning): return 1.0
 if enemy.get("rank_category", "") not in ["elite", "boss"]: return 1.0
 var hp: Variant = enemy.get("hp")
 var maximum: Variant = enemy.get("max_hp")
 if not (hp is int or hp is float) or not (maximum is int or maximum is float): return 1.0
 var health: float = float(hp)
 var max_health: float = float(maximum)
 if not is_finite(health) or not is_finite(max_health) or max_health <= 0.0 or health < 0.0 or health > max_health: return 1.0
 # Read the target's pre-hit HP. The source explicitly requires discrete floor
 # steps; do not add epsilon or round upward near a 25% boundary.
 var lost_percent: float = ((max_health - health) / max_health) * 100.0
 var steps: float = floor(lost_percent / float(tuning.lost_hp_step))
 var bonus: float = float(tuning.base_damage_bonus)
 # Zero increment must stay zero even for an extreme edited step denominator.
 if float(tuning.step_damage_bonus) > 0.0:
  bonus += steps * float(tuning.step_damage_bonus)
 bonus = minf(bonus, float(tuning.damage_bonus_cap))
 var multiplier: float = 1.0 + bonus / 100.0
 return multiplier if is_finite(multiplier) else 1.0
