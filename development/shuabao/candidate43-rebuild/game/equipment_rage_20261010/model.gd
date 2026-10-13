extends "res://elixir_war_20261009/model.gd"
const RageDistance = preload("distance_selection.gd")
const RageRegeneration = preload("regen_selection.gd")
const OriginalRegeneration = preload("res://equipment_regeneration_20261009/passive24.gd")
const RAGE_ID := "final:D03"

func _rage_bound() -> bool:
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 return _e03_bound(sim) and sim.g03_model_is_bound(self)

func _rage_distance_selection() -> Dictionary:
 if not _rage_bound(): return DistancePassives.select_unique(state.inventory,runtime_stat_definitions)
 return RageDistance.select_unique(state.inventory,runtime_stat_definitions)

func equipment_runtime_status(id: String) -> Dictionary:
 var out: Dictionary = super.equipment_runtime_status(id)
 if id != RAGE_ID or not out.get("supported",false): return out
 if not _rage_bound(): return {"supported":false,"reason":"d03_original_consumers_unbound"}
 out.runtime_complete=true;out.shop_admitted=true
 out.runtime_status="original_distance_and_regeneration_bound"
 return out

func equipment_effects() -> Dictionary:
 var out: Dictionary = super.equipment_effects()
 # The ancestor has already added its named constant once. Change only the
 # difference of selections from this same synchronous inventory snapshot.
 var old: Dictionary = out.get("distance_passives",{}).get("constant_stats",{})
 var selected: Dictionary = _rage_distance_selection()
 var delta: Dictionary = {}
 for key: String in selected.constant_stats: delta[key]=float(selected.constant_stats[key])-float(old.get(key,0.0))
 for key: String in old:
  if not delta.has(key): delta[key]=-float(old[key])
 _add_stats(out.stats,delta)
 out.distance_passives=selected
 for id: String in selected.passives:
  if id not in out.passives: out.passives.append(id)
 var regen: Dictionary = RageRegeneration.select_unique(state.inventory,runtime_stat_definitions)
 if regen.equipped and _rage_bound() and "passive:24" not in out.passives: out.passives.append("passive:24")
 return out

func distance_equipment_multiplier(hero_position: Vector3, enemy: Dictionary) -> float:
 return RageDistance.factor(hero_position,enemy.get("position"),_rage_distance_selection())

func e03_regen_effect(sim: Node, for_tick: bool = false) -> Dictionary:
 var selected: Dictionary = RageRegeneration.select_unique(state.inventory,runtime_stat_definitions)
 if not _e03_bound(sim): return OriginalRegeneration.inspect(selected,{})
 return OriginalRegeneration.inspect(selected,sim.common.e03_clock_context(),sim.common.e03_tick_interval() if for_tick else {})

func hunter_elixir_status() -> Dictionary:
 var out: Dictionary = super.hunter_elixir_status()
 out.equipment_count=44
 return out
func war_elixir_status() -> Dictionary:
 var out: Dictionary = super.war_elixir_status()
 out.equipment_count=44
 return out
func snapshot() -> Dictionary:
 var out: Dictionary = super.snapshot()
 out.content_profile="ordinary_equipment44_potions3_formal_training12_elixirs2"
 out.content_warnings=[{"reason":"other28_finals_flasks_other3_elixirs_held"}]
 return out
