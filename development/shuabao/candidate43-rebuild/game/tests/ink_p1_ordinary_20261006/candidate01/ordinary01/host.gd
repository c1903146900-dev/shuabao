extends "res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/host.gd"
## Same actor, frame loop, Session, wallet, rewards and room authority.
## R1 Router/R HUD/domain view/E-up/frontdoor cleanup remain inherited unchanged.
const P1Sim = preload("res://tests/ink_p1_ordinary_20261006/candidate01/lifesteal01/sim.gd")
const P1Session = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/floor_session.gd")
const P1Growth = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/growth_hud.gd")
const P1Navigation = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/navigation_install.gd")
const P1Binding = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/live_binding.gd")
const P1QHud = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/hud_projection.gd")
const P1Card = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/p_hud.gd")
var p1_selected_projection: Dictionary = {}
func _make_floor_sim() -> Node: return P1Sim.new()
func _make_floor_session() -> RefCounted: return P1Session.new()
func _make_floor_hud() -> Control: return P1Growth.new()
func _install_source_navigation() -> Dictionary: return P1Navigation.apply_to_fresh_ink_sim(sim)
func _create_session_controls() -> void:
 super._create_session_controls()
 if is_instance_valid(initial_hud): P1Growth.apply_p_layout(initial_hud)
func _refresh(delta: float) -> void:
 super._refresh(delta)
 if not is_instance_valid(sim) or not is_instance_valid(hud): return
 # Frozen ancestor Q projections correctly reject this new exact Sim. Rebuild
 # the final Q context; keep the main SkillHud script and inherited R/E cards.
 q2_selected_projection = P1QHud.apply_to(hud,sim)
 composed_q_projection = q2_selected_projection.duplicate(true)
 p1_selected_projection = P1Card.apply_to(hud,sim)
 hud.footer.text = str(hud.footer.text).replace(" · Space暂停","") + " · R→左键 · Space暂停"
func _refresh_session_controls(force: bool) -> void:
 super._refresh_session_controls(force)
 if is_instance_valid(session_header):
  session_header.text = session_header.text.replace("Q1/Q2/Q3＋E1＋R1候选；R1临时功能圈/无音频，组合实机未验","Q1/Q2/Q3＋E1＋P1＋R1候选；P1每阶1SP/最高4阶；临时显示，组合实机未验")
func _session_scope() -> String:
 return "晏归舟 · 普通Lv1 / 0金 / 0XP / 原1SP · 首层12行沿线选择/Boss最后\nQ1/Q2/Q3＋E1/P1/R1和BASIC/Shift；原10hook；P1每阶1SP/4阶，R1英雄6级首学\n临时技能显示；美术/音频、自然升级和全首层原生仍未验"
func _commerce_evidence() -> Dictionary:
 var report: Dictionary = super._commerce_evidence()
 report["parent_r1_runtime_source_binding"] = report.get("runtime_source_binding","")
 report["runtime_source_binding"] = FileAccess.get_sha256(P1Binding.BINDING_PATH)
 report["p1_ordinary_overlay"] = true
 return report
func r1_ordinary_report() -> Dictionary:
 var report: Dictionary = super.r1_ordinary_report()
 report["parent_r1_binding"] = report.binding; report["binding"] = FileAccess.get_sha256(P1Binding.BINDING_PATH)
 report["p1_successor_unverified_composition"] = true
 return report
func e1_ordinary_report() -> Dictionary:
 var report: Dictionary = super.e1_ordinary_report()
 report["parent_r1_binding"] = report.binding; report["binding"] = FileAccess.get_sha256(P1Binding.BINDING_PATH)
 report["p1_successor_unverified_composition"] = true
 return report
func q2_ordinary_report() -> Dictionary:
 var report: Dictionary = super.q2_ordinary_report()
 report["parent_r1_binding"] = report.binding; report["binding"] = FileAccess.get_sha256(P1Binding.BINDING_PATH)
 report["p1_successor_unverified_composition"] = true
 return report
func p1_ordinary_report() -> Dictionary:
 return {"binding":FileAccess.get_sha256(P1Binding.BINDING_PATH),"single_owner_intact":shop_session._owner_intact() if shop_session != null and shop_session.ledger != null else false,"selected_p":p1_selected_projection.duplicate(true),"selected_q":q2_selected_projection.duplicate(true),"R1_router_reused":true,"P2_P3_unconsumed_Hex_offered":false,"native_input_passed":false,"natural_progression_verified":false,"full_floor_passed":false,"temporary_text_card":true}
func _write_json(filename: String, contents: Dictionary) -> void:
 var out: Dictionary = contents.duplicate(true); out["p1_ordinary_integration"] = p1_ordinary_report()
 super._write_json(filename,out)
