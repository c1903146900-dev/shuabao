extends "res://equipment_scholar_20261011/model.gd"
const Prism = preload("passive10.gd")
var _c02_previous: Dictionary={}
var _c02_casts: Dictionary={}
var _c02_scope_saved: Dictionary={}
func c02_model_is_bound(sim: Node)->bool:
 return _g01_bound(sim) and sim.has_method("c02_model_is_bound") and sim.c02_model_is_bound(self)
func equipment_runtime_status(id: String)->Dictionary:
 var out: Dictionary=super.equipment_runtime_status(id)
 if id!=Prism.ITEM_ID or not out.get("supported",false):return out
 var sim: Node=_health_sim.get_ref() if _health_sim!=null else null
 if not c02_model_is_bound(sim):return {"supported":false,"reason":"c02_original_consumer_unbound"}
 out.runtime_complete=true;out.shop_admitted=true;out.runtime_status="original_release_and_packet_bound"
 return out
func c02_record_release(sim: Node,evidence: Dictionary)->Dictionary:
 if not c02_model_is_bound(sim) or not sim.verify_c02_release(self,evidence):return {}
 var scope: Dictionary=_c03_scope(sim)
 if scope.is_empty() or sim.paused:return {}
 if scope!=_c02_scope_saved:
  _c02_scope_saved=scope.duplicate(true);_c02_previous={};_c02_casts={}
 var id: int=int(evidence.cast_id)
 if _c02_casts.has(id):return _c02_casts[id].duplicate(true)
 var selected: Dictionary=Prism.select_unique(state.inventory,runtime_stat_definitions)
 var next: Dictionary=Prism.propose(selected,_c02_previous,scope,str(evidence.family),id,float(sim.hero_time))
 if next.is_empty():return {}
 _c02_previous=next.duplicate(true);_c02_casts[id]=next.duplicate(true)
 return next
func snapshot()->Dictionary:
 var out: Dictionary=super.snapshot()
 out.content_profile="ordinary_equipment48_potions3_formal_training12_elixirs3"
 out.content_warnings=[{"reason":"other24_finals_flasks_other2_elixirs_held"}]
 return out
func swift_elixir_status()->Dictionary:
 var out: Dictionary=super.swift_elixir_status();out.equipment_count=48;return out
