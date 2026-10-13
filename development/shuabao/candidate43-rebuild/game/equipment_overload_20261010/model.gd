extends "res://equipment_colossus_20261010/model.gd"
const Overload = preload("passive11.gd")
const OVERLOAD_COMMON := "res://equipment_overload_20261010/common_bridge.gd"
var _c03_trusted: Dictionary = {}

func _d01_bound(sim: Node) -> bool:
 # Exact successor of the prior Common; every original identity check retained.
 if not is_instance_valid(sim) or _health_sim==null or not is_same(_health_sim.get_ref(),sim) or not _e03_bound(sim) or not sim.b02_model_is_bound(self): return false
 if sim.common.get_script().resource_path!=OVERLOAD_COMMON or sim.hero.actor_id!="yanguizhou" or _d01_original_hero==null or not is_same(_d01_original_hero.get_ref(),sim.hero): return false
 return _d01_base_hp>0.0 and is_finite(_d01_base_hp) and ColossusPassive._number(sim.hero.base_stats.get("max_hp")) and float(sim.hero.base_stats.max_hp)==_d01_base_hp

func equipment_runtime_status(id: String) -> Dictionary:
 var out: Dictionary = super.equipment_runtime_status(id)
 if id!=Overload.ITEM_ID or not out.get("supported",false): return out
 var sim: Node = _health_sim.get_ref() if _health_sim!=null else null
 if not _d01_bound(sim): return {"supported":false,"reason":"c03_original_consumer_unbound"}
 out.runtime_complete=true;out.shop_admitted=true;out.runtime_status="original_successful_release_stack_bound"
 return out

func _c03_selection() -> Dictionary:
 return Overload.select_unique(state.inventory,runtime_stat_definitions)

func _c03_scope(sim: Node) -> Dictionary:
 if not _d01_bound(sim) or sim.phase!="combat" or sim.hero.dead or state.phase!="combat" or state.get("actor_dead",false) or state.combat_level_id!=sim.combat_level_id: return {}
 return {"run_id":_run_id,"generation":sim.encounter_generation,"room_id":sim.room_id,"combat_level_id":sim.combat_level_id,"hero":str(sim.hero.get_instance_id()),"runtime":str(sim.common.runtime.get_instance_id())}

func c03_buff_effect(sim: Node) -> Dictionary:
 var scope: Dictionary = _c03_scope(sim)
 var selected: Dictionary = _c03_selection()
 var saved: Variant = sim.hero.cast_state.get(Overload.BUFF_KEY,{}) if is_instance_valid(sim) else {}
 if scope.is_empty() or not saved is Dictionary: return {"active":false,"stacks":0,"AP":0.0,"move_fraction":0.0}
 return Overload.inspect(selected,saved,scope,float(sim.common.runtime.actor_time))

func c03_source_present(sim: Node) -> bool:
 return not _c03_scope(sim).is_empty() and bool(_c03_selection().equipped)

func _c03_claims(scope: Dictionary) -> Dictionary:
 var saved: Dictionary = state.get("c03_release_claims",{})
 if saved.get("scope")==scope and saved.get("casts") is Dictionary: return saved.duplicate(true)
 return {"scope":scope.duplicate(true),"casts":{}}

func record_c03_release(sim: Node, evidence: Dictionary) -> Dictionary:
 if not _c03_trusted.is_empty() or not _d01_bound(sim) or not sim.verify_c03_release(self,evidence): return _deny("c03_original_release_required")
 var scope: Dictionary = _c03_scope(sim)
 if scope.is_empty(): return _deny("c03_original_combat_required")
 var selected: Dictionary = _c03_selection()
 if not selected.equipped: return _deny("c03_not_equipped")
 var cast_key: String = str(evidence.cast_id)
 if _c03_claims(scope).casts.has(cast_key): return _deny("c03_release_already_claimed")
 var previous: Variant = sim.hero.cast_state.get(Overload.BUFF_KEY,{})
 if not previous is Dictionary: return _deny("c03_invalid_buff")
 var now: float = float(sim.common.runtime.actor_time)
 var proposal: Dictionary = Overload.propose(selected,previous,scope,now)
 if proposal.is_empty(): return _deny("c03_invalid_proposal")
 var request: Dictionary = {"scope":scope,"evidence":evidence.duplicate(true),"previous":previous.duplicate(true),"now":now,"proposal":proposal}
 var id: String = "equipment-c03:"+JSON.stringify([_run_id,state.actor_id,scope.generation,scope.room_id,evidence.cast_id])
 var existed: bool = receipts.has(id)
 _c03_trusted=request.duplicate(true)
 var result: Dictionary = command(id,"c03_original_release",request)
 _c03_trusted={}
 if result.get("accepted",false) and not existed:
  # Ledger has committed. Do not publish a buff from a rolled-back transaction.
  assert(_c03_scope(sim)==scope and sim.verify_c03_release(self,evidence))
  sim.hero.cast_state[Overload.BUFF_KEY]=proposal.duplicate(true)
  sim.common.refresh_stats()
 return result

func _apply(action: String, args: Dictionary) -> String:
 if action!="c03_original_release": return super._apply(action,args)
 var sim: Node = _health_sim.get_ref() if _health_sim!=null else null
 if _c03_trusted.is_empty() or args!=_c03_trusted or not _d01_bound(sim) or not sim.verify_c03_release(self,args.evidence): return "c03_original_release_required"
 if _c03_scope(sim)!=args.scope or float(sim.common.runtime.actor_time)!=float(args.now): return "c03_scope_clock_changed"
 var previous: Variant = sim.hero.cast_state.get(Overload.BUFF_KEY,{})
 if not previous is Dictionary or previous!=args.previous: return "c03_buff_changed"
 var proposal: Dictionary = Overload.propose(_c03_selection(),previous,args.scope,float(args.now))
 if proposal.is_empty() or proposal!=args.proposal: return "c03_proposal_changed"
 var claims: Dictionary = _c03_claims(args.scope)
 var key: String = str(args.evidence.cast_id)
 if claims.casts.has(key): return "c03_release_already_claimed"
 claims.casts[key]=args.evidence.family
 state["c03_release_claims"]=claims
 return ""

func hunter_elixir_status() -> Dictionary:
 var out: Dictionary=super.hunter_elixir_status();out.equipment_count=46;return out
func war_elixir_status() -> Dictionary:
 var out: Dictionary=super.war_elixir_status();out.equipment_count=46;return out
func snapshot() -> Dictionary:
 var out: Dictionary=super.snapshot()
 out.content_profile="ordinary_equipment46_potions3_formal_training12_elixirs2"
 out.content_warnings=[{"reason":"other26_finals_flasks_other3_elixirs_held"}]
 return out
