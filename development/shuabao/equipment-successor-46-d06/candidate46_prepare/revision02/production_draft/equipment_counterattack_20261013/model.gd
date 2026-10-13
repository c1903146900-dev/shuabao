extends "res://equipment_prism_20261011/model.gd"
const Counterattack=preload("passive27.gd")
const COUNTERATTACK_COMMON := "res://equipment_counterattack_20261013/common_bridge.gd"
var _d06_trusted: Dictionary={}
func _d01_bound(sim: Node)->bool:
 # Exact successor leaf; preserve every inherited actor/base/owner check.
 if not is_instance_valid(sim) or _health_sim==null or not is_same(_health_sim.get_ref(),sim) or not _e03_bound(sim) or not sim.b02_model_is_bound(self):return false
 if sim.common.get_script().resource_path!=COUNTERATTACK_COMMON or sim.hero.actor_id!="yanguizhou" or _d01_original_hero==null or not is_same(_d01_original_hero.get_ref(),sim.hero):return false
 return _d01_base_hp>0.0 and is_finite(_d01_base_hp) and ColossusPassive._number(sim.hero.base_stats.get("max_hp")) and float(sim.hero.base_stats.max_hp)==_d01_base_hp
func _d06_bound(sim: Node)->bool:
 return c02_model_is_bound(sim) and sim.has_method("d06_model_is_bound") and sim.d06_model_is_bound(self) and _swift_original_hero!=null and is_same(_swift_original_hero.get_ref(),sim.hero) and _swift_base_ms>0.0 and is_finite(_swift_base_ms) and Counterattack._number(sim.hero.base_stats.get("move_speed")) and float(sim.hero.base_stats.move_speed)==_swift_base_ms
func equipment_runtime_status(id: String)->Dictionary:
 var out: Dictionary=super.equipment_runtime_status(id)
 if id!=Counterattack.ITEM_ID or not out.get("supported",false):return out
 var sim: Node=_health_sim.get_ref() if _health_sim!=null else null
 if not _d06_bound(sim):return {"supported":false,"reason":"d06_original_control_expiry_unbound"}
 out.runtime_complete=true;out.shop_admitted=true;out.runtime_status="original_tenacity_stun_natural_expiry_bound"
 out["supported_control_sources"]=["core_damage_hero_tenacity_stun"]
 return out
func _d06_selection()->Dictionary:
 return Counterattack.select_unique(state.inventory,runtime_stat_definitions)
func _d06_scope(sim: Node)->Dictionary:
 if not _d06_bound(sim):return {}
 return _c03_scope(sim)
func d06_source_present(sim: Node)->bool:
 return not _d06_scope(sim).is_empty() and bool(_d06_selection().equipped)
func d06_buff_effect(sim: Node)->Dictionary:
 var scope: Dictionary=_d06_scope(sim)
 var saved: Variant=sim.hero.cast_state.get(Counterattack.BUFF_KEY,{}) if is_instance_valid(sim) else {}
 if not saved is Dictionary:return Counterattack.inspect({}, {}, {}, 0.0)
 return Counterattack.inspect(_d06_selection(),saved,scope,float(sim.hero_time) if is_instance_valid(sim) else 0.0)
func d06_final_multiplier(sim: Node)->float:
 return float(d06_buff_effect(sim).final_multiplier)
func d06_move_addition(sim: Node)->float:
 return _swift_base_ms*float(d06_buff_effect(sim).move_fraction) if _d06_bound(sim) else 0.0
func _d06_claims(scope: Dictionary)->Dictionary:
 var saved: Dictionary=state.get("d06_control_claims",{})
 return saved.duplicate(true) if saved.get("scope")==scope and saved.get("serials") is Dictionary else {"scope":scope.duplicate(true),"serials":{}}
func record_d06_control_end(sim: Node,evidence: Dictionary)->Dictionary:
 if not _d06_trusted.is_empty() or not _d06_bound(sim) or not sim.verify_d06_control_end(self,evidence):return _deny("d06_original_natural_control_end_required")
 var scope: Dictionary=_d06_scope(sim)
 if scope.is_empty() or sim.paused:return _deny("d06_original_combat_required")
 var key: String=str(evidence.serial)
 if _d06_claims(scope).serials.has(key):return _deny("d06_control_already_claimed")
 var previous: Variant=sim.hero.cast_state.get(Counterattack.BUFF_KEY,{})
 if not previous is Dictionary:return _deny("d06_invalid_buff")
 var now: float=float(sim.hero_time)
 var proposal: Dictionary=Counterattack.propose(_d06_selection(),scope,now)
 if proposal.is_empty():return _deny("d06_not_equipped_or_invalid_proposal")
 var request: Dictionary={"scope":scope,"evidence":evidence.duplicate(true),"previous":previous.duplicate(true),"now":now,"proposal":proposal}
 var id: String="equipment-d06:"+JSON.stringify([_run_id,state.actor_id,scope.generation,scope.room_id,evidence.serial])
 var existed: bool=receipts.has(id)
 _d06_trusted=request.duplicate(true)
 var result: Dictionary=command(id,"d06_original_control_end",request)
 _d06_trusted={}
 if result.get("accepted",false) and not existed:
  assert(_d06_scope(sim)==scope and sim.verify_d06_control_end(self,evidence))
  sim.hero.cast_state[Counterattack.BUFF_KEY]=proposal.duplicate(true)
  sim.common.refresh_stats()
 return result
func _apply(action: String,args: Dictionary)->String:
 if action!="d06_original_control_end":return super._apply(action,args)
 var sim: Node=_health_sim.get_ref() if _health_sim!=null else null
 if _d06_trusted.is_empty() or args!=_d06_trusted or not _d06_bound(sim) or not sim.verify_d06_control_end(self,args.evidence):return "d06_original_natural_control_end_required"
 if _d06_scope(sim)!=args.scope or float(sim.hero_time)!=float(args.now):return "d06_scope_clock_changed"
 var previous: Variant=sim.hero.cast_state.get(Counterattack.BUFF_KEY,{})
 if not previous is Dictionary or previous!=args.previous:return "d06_buff_changed"
 var proposal: Dictionary=Counterattack.propose(_d06_selection(),args.scope,float(args.now))
 if proposal.is_empty() or proposal!=args.proposal:return "d06_proposal_changed"
 var claims: Dictionary=_d06_claims(args.scope)
 var key: String=str(args.evidence.serial)
 if claims.serials.has(key):return "d06_control_already_claimed"
 claims.serials[key]=args.evidence.kind;state["d06_control_claims"]=claims
 return ""
func equipment_effects()->Dictionary:
 var out: Dictionary=super.equipment_effects()
 if _d06_selection().equipped and equipment_runtime_status(Counterattack.ITEM_ID).get("supported",false) and Counterattack.PASSIVE_ID not in out.passives:out.passives.append(Counterattack.PASSIVE_ID)
 return out
func snapshot()->Dictionary:
 var out: Dictionary=super.snapshot()
 out.content_profile="ordinary_equipment49_potions3_formal_training12_elixirs3"
 out.content_warnings=[{"reason":"other23_finals_flasks_other2_elixirs_held"}]
 var sim: Node=_health_sim.get_ref() if _health_sim!=null else null
 out["d06_counterattack"]=d06_buff_effect(sim)
 return out
func swift_elixir_status()->Dictionary:
 var out: Dictionary=super.swift_elixir_status();out.equipment_count=49;return out
func hunter_elixir_status()->Dictionary:
 var out: Dictionary=super.hunter_elixir_status();out.equipment_count=49;return out
func war_elixir_status()->Dictionary:
 var out: Dictionary=super.war_elixir_status();out.equipment_count=49;return out
