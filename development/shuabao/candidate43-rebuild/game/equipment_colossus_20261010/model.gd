extends "res://equipment_rage_20261010/model.gd"
const ColossusPassive = preload("passive26.gd")
const ColossusInkTuning = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd")
const COLOSSUS_ID := "final:D01"
const COLOSSUS_COMMON := "res://equipment_colossus_20261010/common_bridge.gd"
var _d01_base_hp: float = 0.0
var _d01_original_hero: WeakRef
func bind_health_sim(sim: Node) -> Dictionary:
 if not is_instance_valid(sim) or sim.hero.actor_id!="yanguizhou": return _deny("d01_original_hero_required")
 var original: Dictionary = ColossusInkTuning.hero_stats()
 if not ColossusPassive._number(original.get("max_hp")) or float(original.max_hp)<=0.0 or not ColossusPassive._number(sim.hero.base_stats.get("max_hp")) or float(sim.hero.base_stats.max_hp)!=float(original.max_hp): return _deny("d01_original_base_required")
 var result: Dictionary = super.bind_health_sim(sim)
 if result.get("accepted",false):
  _d01_base_hp=float(original.max_hp)
  _d01_original_hero=weakref(sim.hero)
 return result
func _d01_bound(sim: Node) -> bool:
 if not is_instance_valid(sim) or _health_sim==null or not is_same(_health_sim.get_ref(),sim) or not _e03_bound(sim) or not sim.b02_model_is_bound(self): return false
 if sim.common.get_script().resource_path!=COLOSSUS_COMMON or sim.hero.actor_id!="yanguizhou" or _d01_original_hero==null or not is_same(_d01_original_hero.get_ref(),sim.hero): return false
 return _d01_base_hp>0.0 and is_finite(_d01_base_hp) and ColossusPassive._number(sim.hero.base_stats.get("max_hp")) and float(sim.hero.base_stats.max_hp)==_d01_base_hp
func equipment_runtime_status(id: String) -> Dictionary:
 var out: Dictionary = super.equipment_runtime_status(id)
 if id!=COLOSSUS_ID or not out.get("supported",false): return out
 var sim: Node = _health_sim.get_ref() if _health_sim!=null else null
 if not _d01_bound(sim): return {"supported":false,"reason":"d01_original_consumer_unbound"}
 out.runtime_complete=true;out.shop_admitted=true;out.runtime_status="original_final_health_conversion_bound"
 return out
func d01_conversion(sim: Node, final_max_hp: Variant) -> Dictionary:
 # No effective-stat query: called synchronously from the sole Common projection.
 if not _d01_bound(sim): return ColossusPassive.inspect({},null,null)
 var selected: Dictionary = ColossusPassive.select_unique(state.inventory,runtime_stat_definitions)
 return ColossusPassive.inspect(selected,final_max_hp,_d01_base_hp)
func hunter_elixir_status() -> Dictionary:
 var out: Dictionary=super.hunter_elixir_status();out.equipment_count=45;return out
func war_elixir_status() -> Dictionary:
 var out: Dictionary=super.war_elixir_status();out.equipment_count=45;return out
func snapshot() -> Dictionary:
 var out: Dictionary=super.snapshot()
 out.content_profile="ordinary_equipment45_potions3_formal_training12_elixirs2"
 out.content_warnings=[{"reason":"other27_finals_flasks_other3_elixirs_held"}]
 return out
