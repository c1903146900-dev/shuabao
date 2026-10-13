extends "res://tests/ink_e2_boundary_20261006/ordinary01/host.gd"
## Same exact tested Sim/router, normal input lifecycle and all source mechanics.
const TextSession = preload("res://tests/ink_e2_boundary_20261006/ordinary01/text01/floor_session.gd")
const TextGrowth = preload("res://tests/ink_e2_boundary_20261006/ordinary01/text01/growth_hud.gd")
const TextNavigation = preload("res://tests/ink_e2_boundary_20261006/ordinary01/text01/navigation_install.gd")
const TextBinding = preload("res://tests/ink_e2_boundary_20261006/ordinary01/text01/live_binding.gd")
const RuntimeText = preload("res://tests/ink_e2_boundary_20261006/ordinary01/text01/runtime_text.gd")

func _make_floor_session() -> RefCounted: return TextSession.new()
func _make_floor_hud() -> Control: return TextGrowth.new()
func _install_source_navigation() -> Dictionary: return TextNavigation.apply_to_fresh_ink_sim(sim)
func _session_scope() -> String: return RuntimeText.scope_text()

func _refresh(delta: float) -> void:
 super._refresh(delta)
 _refresh_runtime_text()

func _refresh_runtime_text() -> void:
 if not is_instance_valid(hud): return
 RuntimeText.correct_hud(hud)
 q2_selected_projection = RuntimeText.projection(q2_selected_projection)
 composed_q_projection = RuntimeText.projection(composed_q_projection)
 p1_selected_projection = RuntimeText.projection(p1_selected_projection)
 e2_selected_projection = RuntimeText.projection(e2_selected_projection)
 e1_selected_projection = RuntimeText.projection(e1_selected_projection)
 r1_selected_projection = RuntimeText.projection(r1_selected_projection)

func _refresh_session_controls(force: bool) -> void:
 super._refresh_session_controls(force)
 if is_instance_valid(session_header):
  session_header.text = session_header.text.replace("Q1/Q2/Q3＋E1/E2＋P1＋R1；孤帆触边停留，仍按原时间消散；临时显示",RuntimeText.skill_line())

func _commerce_evidence() -> Dictionary:
 var report: Dictionary = super._commerce_evidence()
 report["parent_e2_runtime_source_binding"] = report.get("runtime_source_binding","")
 report["runtime_source_binding"] = FileAccess.get_sha256(TextBinding.BINDING_PATH)
 report["text_only_successor"] = true
 return report

func e2_ordinary_report() -> Dictionary:
 var report: Dictionary = super.e2_ordinary_report()
 report["parent_e2_binding"] = report.binding
 report["binding"] = FileAccess.get_sha256(TextBinding.BINDING_PATH)
 report["text_only_successor"] = true
 return report
