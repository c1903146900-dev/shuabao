extends "res://tests/ink_r2_ordinary_20261006/candidate01/production_adapter.gd"
## One inherited ordinary frame loop, frontdoor and Session. No default cutover.
const RiverSim=preload("res://tests/ink_river_hexes_20261006/ordinary01/sim.gd")
const RiverSession=preload("res://tests/ink_river_hexes_20261006/ordinary01/floor_session.gd")
const RiverRouter=preload("res://tests/ink_river_hexes_20261006/candidate01/input_adapter.gd")
const RiverGrowth=preload("res://tests/ink_river_hexes_20261006/ordinary01/growth_hud.gd")
const RiverNavigation=preload("res://tests/ink_river_hexes_20261006/ordinary01/navigation_install.gd")
const RiverHUD=preload("res://tests/ink_river_hexes_20261006/ordinary01/hud_projection.gd")
const RiverE=preload("res://tests/ink_river_hexes_20261006/ordinary01/e_hud.gd")
const RiverR=preload("res://tests/ink_river_hexes_20261006/ordinary01/r_hud.gd")
const RiverText=preload("res://tests/ink_river_hexes_20261006/ordinary01/runtime_text.gd")
const RiverView=preload("res://tests/ink_river_hexes_20261006/ordinary01/river_view.gd")
const RiverBinding=preload("res://tests/ink_river_hexes_20261006/ordinary01/live_binding.gd")
func _make_floor_sim() -> Node: return RiverSim.new()
func _make_floor_router() -> RefCounted: return RiverRouter.new()
func _make_floor_session() -> RefCounted: return RiverSession.new()
func _make_floor_hud() -> Control: return RiverGrowth.new()
func _install_source_navigation() -> Dictionary: return RiverNavigation.apply_to_fresh_ink_sim(sim)
func _session_scope() -> String: return RiverText.scope_text()
func _ensure_river_view() -> void:
 if is_instance_valid(sim) and not is_instance_valid(q2_river_view):
  q2_river_view=RiverView.new(); add_child(q2_river_view)
func _refresh(delta: float) -> void:
 _ensure_river_view()
 super._refresh(delta)
 if not is_instance_valid(sim) or not is_instance_valid(hud) or input_router==null: return
 q2_selected_projection=RiverHUD.apply_to(hud,sim); composed_q_projection=q2_selected_projection.duplicate(true)
 p1_selected_projection=RiverHUD.apply_p_to(hud,sim)
 e3_selected_projection=RiverE.apply_to(hud,sim); e2_selected_projection=e3_selected_projection.duplicate(true); e1_selected_projection=e3_selected_projection.duplicate(true)
 r1_selected_projection=RiverR.apply_to(hud,sim)
 hud.footer.text=RiverHUD.input_help(sim)
 RiverText.correct_hud(hud)
func q2_ordinary_report() -> Dictionary:
 return {"binding":FileAccess.get_sha256(RiverBinding.BINDING_PATH),"sim_script":sim.get_script().resource_path if is_instance_valid(sim) else "","single_owner_intact":shop_session._owner_intact() if shop_session!=null and shop_session.ledger!=null else false,"selected_q":q2_selected_projection.duplicate(true),"river_display":q2_river_view.river_sample.duplicate(true) if is_instance_valid(q2_river_view) else {},"sunsets":q2_river_view.sunset_samples.duplicate(true) if is_instance_valid(q2_river_view) else [],"H03_H04_offered":true,"other_new_hexes":false,"native_input_passed":false,"full_floor_passed":false,"art_audio_implemented":false}
func _commerce_evidence() -> Dictionary:
 var out: Dictionary=super._commerce_evidence()
 out["runtime_source_binding"]=FileAccess.get_sha256(RiverBinding.BINDING_PATH)
 return out
func r2_ordinary_report() -> Dictionary:
 var out: Dictionary=super.r2_ordinary_report()
 out["binding"]=FileAccess.get_sha256(RiverBinding.BINDING_PATH)
 out["new_hex_admission"]=true;out["new_hex_hooks"]=["H03","H04"]
 return out
