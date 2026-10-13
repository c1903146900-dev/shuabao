extends "res://equipment_expansion_20261009/model.gd"
## Original ledger and health ownership; constant passive stats enter the same
## authoritative aggregate as every other equipped stat, once per passive.
const DistancePassives = preload("res://equipment_distance_20261009/passives.gd")
func equipment_effects() -> Dictionary:
 var result: Dictionary = super.equipment_effects()
 var selected: Dictionary = DistancePassives.select_unique(state.inventory, runtime_stat_definitions)
 _add_stats(result.stats, selected.constant_stats)
 for passive_id: String in selected.passives:
  if passive_id not in result.passives: result.passives.append(passive_id)
 result["distance_passives"] = selected
 return result
func distance_equipment_multiplier(hero_position: Vector3, enemy: Dictionary) -> float:
 var selected: Dictionary = DistancePassives.select_unique(state.inventory, runtime_stat_definitions)
 return DistancePassives.factor(hero_position, enemy.get("position"), selected)
func snapshot() -> Dictionary:
 var out: Dictionary = super.snapshot()
 out.content_profile = "ordinary_equipment35_potions3"
 out.content_warnings = [{"reason":"other37_finals_flasks_elixirs_held"}]
 return out
