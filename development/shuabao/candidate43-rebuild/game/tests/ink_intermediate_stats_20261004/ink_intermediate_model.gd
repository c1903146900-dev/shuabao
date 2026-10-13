extends "res://tests/ink_initial_hex_runtime_20261004/ink_initial_model.gd"
## Same ledger/kernel, component inverse patches, health journal, and selector.
## The inherited consumer sums ONLY currently held UID entries. Consumed recipe
## components remain audit lineage, never a second source of derived stats.
func equipment_runtime_status(id: String)->Dictionary:
 if not commerce_definitions.items.has(id):return {"supported":false,"reason":"unknown_item"}
 if commerce_definitions.items[id].kind!="equipment":return {"supported":false,"reason":"consumable_effect_consumer_not_connected"}
 if not runtime_stat_definitions.has(id):return {"supported":false,"reason":"outside_base11_intermediate17_slice"}
 return runtime_stat_definitions[id].duplicate(true)
func equipment_effects()->Dictionary:
 var out: Dictionary=super.equipment_effects()
 if not runtime_stat_definitions.is_empty():out.status="base11_intermediate17_runtime_candidate"
 return out
func snapshot()->Dictionary:
 var out: Dictionary=super.snapshot()
 out.content_profile="base11_intermediate17_runtime_candidate"
 out.content_warnings=[{"reason":"source_values_unbalanced_B12_I12_regen_final_and_consumable_effects_hold"}]
 return out
