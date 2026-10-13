extends "res://tests/ink_rest_service_20261006/candidate01/ordinary01/host.gd"
## Ordinary E2 successor: same actor, Session ledger, Q/R menu ownership,
## E1 real-release route, P1 source targets, room flow and rest service.
const E2OrdinarySim = preload("res://tests/ink_e2_boundary_20261006/ordinary01/sim.gd")
const E2OrdinarySession = preload("res://tests/ink_e2_boundary_20261006/ordinary01/floor_session.gd")
const E2OrdinaryBinding = preload("res://tests/ink_e2_boundary_20261006/ordinary01/live_binding.gd")
const E2OrdinaryNavigation = preload("res://tests/ink_e2_boundary_20261006/ordinary01/navigation_install.gd")
const E2OrdinaryGrowth = preload("res://tests/ink_e2_boundary_20261006/ordinary01/growth_hud.gd")
const E2OrdinaryRouter = preload("res://tests/ink_e2_boundary_20261006/ordinary01/input_adapter.gd")
const E2OrdinaryHud = preload("res://tests/ink_e2_boundary_20261006/ordinary01/hud_projection.gd")
const E2OrdinaryCard = preload("res://tests/ink_e2_boundary_20261006/ordinary01/e_hud.gd")
const E2OrdinaryView = preload("res://tests/ink_e2_boundary_20261006/ordinary01/boat_view.gd")
var e2_boat_view: Node3D
var e2_selected_projection: Dictionary = {}

func _make_floor_sim() -> Node: return E2OrdinarySim.new()
func _make_floor_session() -> RefCounted: return E2OrdinarySession.new()
func _make_floor_router() -> RefCounted: return E2OrdinaryRouter.new()
func _make_floor_hud() -> Control: return E2OrdinaryGrowth.new()
func _install_source_navigation() -> Dictionary: return E2OrdinaryNavigation.apply_to_fresh_ink_sim(sim)

func _create_session_controls() -> void:
 super._create_session_controls()
 if is_instance_valid(initial_hud): E2OrdinaryGrowth.apply_e2_layout(initial_hud)

func _input(event: InputEvent) -> void:
 # Menus consume keys before _unhandled_input. Record only blocked E2 downs;
 # the inherited pre-GUI / frontdoor E-up routes drain the real release.
 if input_router != null and is_instance_valid(sim) and event is InputEventKey:
  var modal: bool = _mainprep_required or sim.paused or (shop_session != null and shop_session.panel_open)
  modal = modal or (is_instance_valid(initial_hud) and initial_hud.blocks_gameplay_input())
  if modal: input_router.observe_blocked_e2_down(event)
 super._input(event)

func _refresh(delta: float) -> void:
 super._refresh(delta)
 if not is_instance_valid(sim) or not is_instance_valid(hud): return
 # Frozen P1/Q exact-Sim admission remains intact. These new read-only
 # projections explicitly name this successor, retaining their original views.
 q2_selected_projection = E2OrdinaryHud.apply_to(hud,sim)
 composed_q_projection = q2_selected_projection.duplicate(true)
 p1_selected_projection = E2OrdinaryHud.apply_p_to(hud,sim)
 e2_selected_projection = E2OrdinaryCard.apply_to(hud,sim)
 e1_selected_projection = e2_selected_projection.duplicate(true)
 hud.footer.text = E2OrdinaryHud.input_help(sim)
 if not is_instance_valid(e2_boat_view):
  e2_boat_view = E2OrdinaryView.new(); add_child(e2_boat_view)
 e2_boat_view.present_source(sim.ink_presenter_snapshot(),e2_selected_projection)

func _refresh_session_controls(force: bool) -> void:
 super._refresh_session_controls(force)
 if is_instance_valid(session_header):
  session_header.text = session_header.text.replace("Q1/Q2/Q3＋E1＋P1＋R1候选；P1每阶1SP/最高4阶；临时显示，组合实机未验","Q1/Q2/Q3＋E1/E2＋P1＋R1；孤帆触边停留，仍按原时间消散；临时显示")

func _session_scope() -> String:
 return "晏归舟 · Lv1 / 0金币 / 0经验 / 1技能点 · 首层12行沿线选择，Boss在最后\n可学习Q1/Q2/Q3、E1/E2、P1和R1；普攻与Shift可用\n孤帆触及房间边界停留，仍按原时间消散；可穿过墙体；落点站不下时拒绝登舟，舟保留\n临时功能显示；最终美术与音效未完成"

func _commerce_evidence() -> Dictionary:
 var report: Dictionary = super._commerce_evidence()
 report["parent_rest_runtime_source_binding"] = report.get("runtime_source_binding","")
 report["runtime_source_binding"] = FileAccess.get_sha256(E2OrdinaryBinding.BINDING_PATH)
 report["e2_boundary_ordinary_overlay"] = true
 return report

func _e2_successor_report(report: Dictionary) -> Dictionary:
 report["frozen_parent_binding"] = report.get("binding","")
 report["binding"] = FileAccess.get_sha256(E2OrdinaryBinding.BINDING_PATH)
 report["e2_successor_unverified_composition"] = true
 report["sim_script"] = sim.get_script().resource_path if is_instance_valid(sim) else ""
 return report

func p1_ordinary_report() -> Dictionary: return _e2_successor_report(super.p1_ordinary_report())
func r1_ordinary_report() -> Dictionary: return _e2_successor_report(super.r1_ordinary_report())
func e1_ordinary_report() -> Dictionary: return _e2_successor_report(super.e1_ordinary_report())
func q2_ordinary_report() -> Dictionary: return _e2_successor_report(super.q2_ordinary_report())
func rest_ordinary_report() -> Dictionary: return _e2_successor_report(super.rest_ordinary_report())

func e2_ordinary_report() -> Dictionary:
 return {"binding":FileAccess.get_sha256(E2OrdinaryBinding.BINDING_PATH),"sim_script":sim.get_script().resource_path if is_instance_valid(sim) else "","single_owner_intact":shop_session._owner_intact() if shop_session != null and shop_session.ledger != null else false,"selected_e":e2_selected_projection.duplicate(true),"selected_p":p1_selected_projection.duplicate(true),"input":input_router.e2_input_snapshot() if input_router != null else {},"boat_display":e2_boat_view.boat_sample.duplicate(true) if is_instance_valid(e2_boat_view) else {},"H09_H10_offered":false,"temporary_functional_front":true,"art_audio_complete":false,"native_input_passed":false,"natural_progression_verified":false,"full_floor_passed":false}

func _write_json(filename: String, contents: Dictionary) -> void:
 var output: Dictionary = contents.duplicate(true)
 output["e2_ordinary_integration"] = e2_ordinary_report()
 super._write_json(filename,output)
