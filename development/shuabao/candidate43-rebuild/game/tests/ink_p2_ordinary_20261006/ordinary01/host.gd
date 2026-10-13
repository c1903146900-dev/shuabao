extends "res://tests/ink_e2_boundary_20261006/ordinary01/text01/host.gd"
## Same ordinary actor, ledger, world step, room flow and current text layer.
## Exact P2/E3 leaf admission and read-only displays; native validation NOT_RUN.
const E3OrdinarySim = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/sim.gd")
const E3OrdinarySession = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/floor_session.gd")
const E3OrdinaryBinding = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/live_binding.gd")
const E3OrdinaryNavigation = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/navigation_install.gd")
const E3OrdinaryGrowth = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/growth_hud.gd")
const E3OrdinaryRouter = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/input_adapter.gd")
const E3OrdinaryHud = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/hud_projection.gd")
const E3OrdinaryCard = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/e_hud.gd")
const E3OrdinaryView = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/frame_view.gd")
const E3RuntimeText = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/runtime_text.gd")
var e3_frame_view: Node3D
var e3_selected_projection: Dictionary = {}

func _make_floor_sim() -> Node: return E3OrdinarySim.new()
func _make_floor_session() -> RefCounted: return E3OrdinarySession.new()
func _make_floor_router() -> RefCounted: return E3OrdinaryRouter.new()
func _make_floor_hud() -> Control: return E3OrdinaryGrowth.new()
func _install_source_navigation() -> Dictionary: return E3OrdinaryNavigation.apply_to_fresh_ink_sim(sim)
func _session_scope() -> String: return E3RuntimeText.scope_text()

func _create_session_controls() -> void:
 super._create_session_controls()
 if is_instance_valid(initial_hud): E3OrdinaryGrowth.apply_e3_layout(initial_hud)

func _input(event: InputEvent) -> void:
 if input_router != null and is_instance_valid(sim) and event is InputEventKey:
  var modal: bool = _mainprep_required or sim.paused or (shop_session != null and shop_session.panel_open)
  modal = modal or (is_instance_valid(initial_hud) and initial_hud.blocks_gameplay_input())
  if modal: input_router.observe_blocked_e3_down(event)
 # Includes E1's real pre-GUI/frontdoor release and E2's blocked-down latch.
 super._input(event)

func _refresh(delta: float) -> void:
 super._refresh(delta)
 if not is_instance_valid(sim) or not is_instance_valid(hud) or input_router == null: return
 q2_selected_projection = E3OrdinaryHud.apply_to(hud,sim)
 composed_q_projection = q2_selected_projection.duplicate(true)
 p1_selected_projection = E3OrdinaryHud.apply_p_to(hud,sim)
 e3_selected_projection = E3OrdinaryCard.apply_to(hud,sim)
 e2_selected_projection = e3_selected_projection.duplicate(true)
 e1_selected_projection = e3_selected_projection.duplicate(true)
 hud.footer.text = E3OrdinaryHud.input_help(sim)
 _refresh_runtime_text()
 # The ancestor's exact E2 projector rejects this new Sim by design. Supply
 # the new E1/E2/E3 readback to its unchanged boat view after final projection.
 if is_instance_valid(e2_boat_view): e2_boat_view.present_source(sim.ink_presenter_snapshot(),e2_selected_projection)
 if not is_instance_valid(e3_frame_view):
  e3_frame_view = E3OrdinaryView.new(); add_child(e3_frame_view)
 var modal: bool = _mainprep_required or sim.paused or (shop_session != null and shop_session.panel_open)
 modal = modal or (is_instance_valid(initial_hud) and initial_hud.blocks_gameplay_input())
 var preview: Dictionary = {} if modal else input_router.e3_preview_for_view(_current_pointer_ground())
 e3_frame_view.present_source(sim.ink_presenter_snapshot(),preview,e3_selected_projection)

func _refresh_runtime_text() -> void:
 if not is_instance_valid(hud): return
 E3RuntimeText.correct_hud(hud)
 q2_selected_projection = E3RuntimeText.projection(q2_selected_projection)
 composed_q_projection = E3RuntimeText.projection(composed_q_projection)
 p1_selected_projection = E3RuntimeText.projection(p1_selected_projection)
 e3_selected_projection = E3RuntimeText.projection(e3_selected_projection)
 e2_selected_projection = E3RuntimeText.projection(e2_selected_projection)
 e1_selected_projection = E3RuntimeText.projection(e1_selected_projection)
 r1_selected_projection = E3RuntimeText.projection(r1_selected_projection)

func _refresh_session_controls(force: bool) -> void:
 super._refresh_session_controls(force)
 if is_instance_valid(session_header): session_header.text = session_header.text.replace(RuntimeText.skill_line(),E3RuntimeText.skill_line())

func _commerce_evidence() -> Dictionary:
 var report: Dictionary = super._commerce_evidence()
 report["parent_text_runtime_source_binding"] = report.get("runtime_source_binding","")
 report["runtime_source_binding"] = FileAccess.get_sha256(E3OrdinaryBinding.BINDING_PATH)
 report["p2_ordinary_overlay"] = true
 report["e3_ordinary_overlay"] = true
 report["text_only_successor"] = false
 return report

func _e3_successor_report(report: Dictionary) -> Dictionary:
 report["frozen_parent_binding"] = report.get("binding","")
 report["binding"] = FileAccess.get_sha256(E3OrdinaryBinding.BINDING_PATH)
 report["p2_ordinary_candidate"] = true
 report["P2_P3_unconsumed_Hex_offered"] = false
 report["P2_offered"] = true
 report["P3_offered"] = false
 report["e1_original_pause_remainder_fixed"] = false
 report["e3_successor_unverified_composition"] = true
 report["text_only_successor"] = false
 report["sim_script"] = sim.get_script().resource_path if is_instance_valid(sim) else ""
 return report

func p1_ordinary_report() -> Dictionary: return _e3_successor_report(super.p1_ordinary_report())
func r1_ordinary_report() -> Dictionary: return _e3_successor_report(super.r1_ordinary_report())
func e1_ordinary_report() -> Dictionary: return _e3_successor_report(super.e1_ordinary_report())
func e2_ordinary_report() -> Dictionary: return _e3_successor_report(super.e2_ordinary_report())
func q2_ordinary_report() -> Dictionary: return _e3_successor_report(super.q2_ordinary_report())
func rest_ordinary_report() -> Dictionary: return _e3_successor_report(super.rest_ordinary_report())

func e3_ordinary_report() -> Dictionary:
 return {"binding":FileAccess.get_sha256(E3OrdinaryBinding.BINDING_PATH),"sim_script":sim.get_script().resource_path if is_instance_valid(sim) else "","single_owner_intact":shop_session._owner_intact() if shop_session != null and shop_session.ledger != null else false,"selected_e":e3_selected_projection.duplicate(true),"selected_p":p1_selected_projection.duplicate(true),"input":input_router.e3_input_snapshot() if input_router != null else {},"frame_display":e3_frame_view.frame_sample.duplicate(true) if is_instance_valid(e3_frame_view) else {},"H11_H12_offered":false,"temporary_functional_front":true,"art_audio_complete":false,"engine":"NOT_RUN","native_input":"NOT_RUN","natural_progression":"NOT_RUN","full_floor":"NOT_RUN"}

func _write_json(filename: String, contents: Dictionary) -> void:
 var output: Dictionary = contents.duplicate(true)
 output["e3_ordinary_integration"] = e3_ordinary_report()
 output["p2_ordinary_integration"] = p2_ordinary_report()
 super._write_json(filename,output)

func p2_ordinary_report() -> Dictionary:
 return {"binding":FileAccess.get_sha256(E3OrdinaryBinding.BINDING_PATH),"sim_script":sim.get_script().resource_path if is_instance_valid(sim) else "","single_owner_intact":shop_session._owner_intact() if shop_session != null and shop_session.ledger != null else false,"selected_p":p1_selected_projection.duplicate(true),"passive_slot_count":1,"P1_P2_exclusive":true,"closed_hexes_opened":false,"temporary_functional_front":true,"e1_original_pause_remainder_fixed":false,"native_input":"NOT_RUN","natural_progression":"NOT_RUN","full_floor":"NOT_RUN"}
