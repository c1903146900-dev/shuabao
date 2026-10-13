extends "res://tests/ink_equipment_live_20261008/content01/potion_model.gd"
## Preserve reward, commerce, UID stacking and health observer ownership.
const Passive23Spatial = preload("res://tests/ink_equipment_passive23_20261008/candidate01/spatial_consumer.gd")
const PASSIVE23_ITEMS = ["final:D05", "final:E05"]
var _passive23_spatial = Passive23Spatial.new()
func bind_health_sim(sim: Node) -> Dictionary:
 if not sim.has_method("bind_passive23_model"): return _deny("passive23_sim_consumer_required")
 var result: Dictionary = super.bind_health_sim(sim)
 if result.accepted: sim.bind_passive23_model(self)
 return result
func equipment_runtime_status(id: String) -> Dictionary:
 var result: Dictionary = super.equipment_runtime_status(id)
 if id in PASSIVE23_ITEMS and (_health_sim == null or not is_instance_valid(_health_sim.get_ref())):
  return {"supported":false,"reason":"passive23_world_not_bound"}
 return result
func passive23_effect() -> Dictionary:
 var tuning: Dictionary = {}
 var equipped: bool = false
 for entry: Dictionary in state.inventory:
  if str(entry.id) not in PASSIVE23_ITEMS or int(entry.count) <= 0: continue
  var status: Dictionary = equipment_runtime_status(str(entry.id))
  if not status.get("supported", false): continue
  tuning = status.get("passive23", {})
  equipped = not tuning.is_empty()
  if equipped: break # Unique mechanism across names/UIDs; base stats still sum.
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 return _passive23_spatial.sample(sim, tuning, equipped)
func equipment_effects() -> Dictionary:
 var result: Dictionary = super.equipment_effects()
 var effect: Dictionary = passive23_effect()
 _add_stats(result.stats, effect.stats)
 result["passive23"] = effect
 # Dynamic contribution is added before inherited stat caps and common buffs.
 if effect.enemy_count > 0: result.passives.append("passive:23")
 return result
func snapshot() -> Dictionary:
 var out: Dictionary = super.snapshot()
 out.content_profile = "ordinary_equipment32_potions3"
 out.content_warnings = [{"reason":"other40_finals_flasks_elixirs_held"}]
 return out
