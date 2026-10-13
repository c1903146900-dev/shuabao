extends "res://equipment_blood_trial_20261009/model.gd"
const Regeneration = preload("passive24.gd")

func _e03_bound(sim: Node) -> bool:
 return _g03_bound(sim,_run_id) and sim.has_method("e03_model_is_bound") and sim.e03_model_is_bound(self)

func equipment_runtime_status(id: String) -> Dictionary:
 var out: Dictionary = super.equipment_runtime_status(id)
 if id != Regeneration.ITEM_ID or not out.get("supported",false): return out
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 if not _e03_bound(sim): return {"supported":false,"reason":"e03_original_regen_clock_not_bound"}
 out.runtime_complete = true;out.shop_admitted = true
 out.runtime_status = "original_continuous_combat_regen_bound"
 return out

func e03_regen_effect(sim: Node, for_tick: bool = false) -> Dictionary:
 var selected: Dictionary = Regeneration.select_unique(state.inventory,runtime_stat_definitions)
 if not _e03_bound(sim): return Regeneration.inspect(selected,{})
 return Regeneration.inspect(selected,sim.common.e03_clock_context(),sim.common.e03_tick_interval() if for_tick else {})

func regeneration_status() -> Dictionary:
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 var out: Dictionary = e03_regen_effect(sim,false)
 out["base_regen"] = float(sim.common.e03_clock_context().base_regen) if _e03_bound(sim) else 0.0
 out["regen_unit"] = "health_points_per_actor_combat_second"
 out["same_combat_generation_resets"] = false
 out["natural_regeneration_only"] = true
 return out

func equipment_effects() -> Dictionary:
 var out: Dictionary = super.equipment_effects()
 var selected: Dictionary = Regeneration.select_unique(state.inventory,runtime_stat_definitions)
 if selected.equipped and equipment_runtime_status(Regeneration.ITEM_ID).get("supported",false) and Regeneration.PASSIVE_ID not in out.passives: out.passives.append(Regeneration.PASSIVE_ID)
 return out

func snapshot() -> Dictionary:
 var out: Dictionary = super.snapshot()
 out.content_profile = "ordinary_equipment43_potions3"
 out.content_warnings = [{"reason":"other29_finals_flasks_elixirs_held"}]
 out["e03_regeneration"] = regeneration_status()
 return out
