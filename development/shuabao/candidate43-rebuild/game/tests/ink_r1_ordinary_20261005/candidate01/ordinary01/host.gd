extends "res://tests/ink_e1_ordinary_20261005/candidate01/host.gd"
## Same ordinary actor, frame loop, Session, wallet, rewards and room authority.
const R1Sim = preload("res://tests/ink_r1_ordinary_20261005/candidate01/sim.gd")
const R1Router = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/input_adapter.gd")
const R1Session = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/floor_session.gd")
const R1Growth = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/growth_hud.gd")
const R1Navigation = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/navigation_install.gd")
const R1Binding = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/live_binding.gd")
const R1QHud = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/hud_projection.gd")
const R1Card = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/r_hud.gd")
const R1View = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/domain_view.gd")
var r1_domain_view: Node3D
var r1_selected_projection: Dictionary = {}
func _make_floor_sim() -> Node: return R1Sim.new()
func _make_floor_router() -> RefCounted: return R1Router.new()
func _make_floor_session() -> RefCounted: return R1Session.new()
func _make_floor_hud() -> Control: return R1Growth.new()
func _install_source_navigation() -> Dictionary: return R1Navigation.apply_to_fresh_ink_sim(sim)

func _create_session_controls() -> void:
 super._create_session_controls()
 if is_instance_valid(initial_hud): R1Growth.apply_r_layout(initial_hud)

func _refresh(delta: float) -> void:
 super._refresh(delta)
 if not is_instance_valid(sim) or input_router == null: return
 if not is_instance_valid(r1_domain_view):
  r1_domain_view = R1View.new(); add_child(r1_domain_view)
 r1_domain_view.present_source(sim.ink_presenter_snapshot(),input_router.r1_preview_for_view(_current_pointer_ground()))
 if not is_instance_valid(hud): return
 q2_selected_projection = R1QHud.apply_to(hud,sim)
 composed_q_projection = q2_selected_projection.duplicate(true)
 r1_selected_projection = R1Card.apply_to(hud,sim)
 hud.footer.text = str(hud.footer.text).replace(" · Space暂停","") + " · R→左键 · Space暂停"

func _refresh_session_controls(force: bool) -> void:
 super._refresh_session_controls(force)
 if is_instance_valid(session_header):
  session_header.text = session_header.text.replace("Q1/Q2/Q3＋基础E1候选；E1临时文字/无音频，组合实机未验","Q1/Q2/Q3＋E1＋R1候选；R1临时功能圈/无音频，组合实机未验")

func _session_scope() -> String:
 return "晏归舟 · 普通Lv1 / 0金 / 0XP / 原1SP · 首层12行沿线选择/Boss最后\nQ1/Q2/Q3＋基础E1/R1和BASIC/Shift；原10hook，R1英雄6级首学\nR1临时功能圈；雪景美术/音频、自然Lv6与普通组合实机未验"

func _commerce_evidence() -> Dictionary:
 var report: Dictionary = super._commerce_evidence()
 report["parent_e1_runtime_source_binding"] = report.get("runtime_source_binding","")
 report["runtime_source_binding"] = FileAccess.get_sha256(R1Binding.BINDING_PATH)
 report["r1_ordinary_overlay"] = true
 return report

func e1_ordinary_report() -> Dictionary:
 var report: Dictionary = super.e1_ordinary_report()
 report["parent_e1_binding"] = report.binding
 report["binding"] = FileAccess.get_sha256(R1Binding.BINDING_PATH)
 report["r1_successor_unverified_composition"] = true
 return report

func q2_ordinary_report() -> Dictionary:
 var report: Dictionary = super.q2_ordinary_report()
 report["parent_q2_binding"] = report.binding
 report["binding"] = FileAccess.get_sha256(R1Binding.BINDING_PATH)
 report["r1_successor_unverified_composition"] = true
 return report

func r1_ordinary_report() -> Dictionary:
 return {"binding":FileAccess.get_sha256(R1Binding.BINDING_PATH),"single_owner_intact":shop_session._owner_intact() if shop_session != null and shop_session.ledger != null else false,"selected_r":r1_selected_projection.duplicate(true),"input":input_router.r1_input_snapshot() if input_router != null else {},"temporary_functional_circle":true,"R2_H13_H16_offered":false,"native_input_passed":false,"natural_level6_verified":false,"full_floor_passed":false}

func _write_json(filename: String, contents: Dictionary) -> void:
 var out: Dictionary = contents.duplicate(true)
 out["r1_ordinary_integration"] = r1_ordinary_report()
 super._write_json(filename,out)
