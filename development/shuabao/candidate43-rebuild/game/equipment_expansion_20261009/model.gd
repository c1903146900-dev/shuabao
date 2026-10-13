extends "res://visual_rework_20261009/binding/postboss_model.gd"
## Same commerce, health and terminal boundaries; one authored final item admitted.
const EquipmentPassive18 = preload("res://equipment_expansion_20261009/passive18.gd")
func passive18_multiplier(enemy: Dictionary, _event: Dictionary) -> float:
 var selected: Dictionary = EquipmentPassive18.select_unique(state.inventory, runtime_stat_definitions)
 return EquipmentPassive18.factor(enemy, selected.tuning)
func snapshot() -> Dictionary:
 var out: Dictionary = super.snapshot()
 out.content_profile = "ordinary_equipment33_potions3"
 out.content_warnings = [{"reason":"other39_finals_flasks_elixirs_held"}]
 out["passive18_equipment"] = EquipmentPassive18.select_unique(state.inventory, runtime_stat_definitions)
 return out
