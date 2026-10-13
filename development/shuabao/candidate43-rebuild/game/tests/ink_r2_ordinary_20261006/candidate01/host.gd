extends "res://tests/ink_ordinary_composed_20261006/candidate01/host.gd"
## Single composed leaf; the parent's one frame loop, route and Session survive.
const R2OrdinarySim = preload("res://tests/ink_r2_ordinary_20261006/candidate01/sim.gd")
const R2OrdinarySession = preload("res://tests/ink_r2_ordinary_20261006/candidate01/floor_session.gd")
const R2OrdinaryBinding = preload("res://tests/ink_r2_ordinary_20261006/candidate01/live_binding.gd")
const R2OrdinaryNavigation = preload("res://tests/ink_r2_ordinary_20261006/candidate01/navigation_install.gd")
const R2OrdinaryGrowth = preload("res://tests/ink_r2_ordinary_20261006/candidate01/growth_hud.gd")
const R2OrdinaryHud = preload("res://tests/ink_r2_ordinary_20261006/candidate01/hud_projection.gd")
const R2OrdinaryECard = preload("res://tests/ink_r2_ordinary_20261006/candidate01/e_hud.gd")
const R2OrdinaryRCard = preload("res://tests/ink_r2_ordinary_20261006/candidate01/r_hud.gd")
const R2OrdinaryText = preload("res://tests/ink_r2_ordinary_20261006/candidate01/runtime_text.gd")

const R2OrdinaryRouter = preload("res://tests/ink_r2_ordinary_20261006/candidate01/input_adapter.gd")
const R2OrdinaryView = preload("res://tests/ink_r2_ordinary_20261006/candidate01/peaks_view.gd")
var r2_peaks_view: Node3D

func _make_floor_router() -> RefCounted: return R2OrdinaryRouter.new()
func _make_floor_sim() -> Node: return R2OrdinarySim.new()
func _make_floor_session() -> RefCounted: return R2OrdinarySession.new()
func _make_floor_hud() -> Control: return R2OrdinaryGrowth.new()
func _install_source_navigation() -> Dictionary: return R2OrdinaryNavigation.apply_to_fresh_ink_sim(sim)
func _session_scope() -> String: return R2OrdinaryText.scope_text()

func _refresh(delta: float) -> void:
 super._refresh(delta)
 if not is_instance_valid(sim) or not is_instance_valid(hud) or input_router == null: return
 # The frozen parent's exact-Sim projectors deliberately reject this new leaf.
 # Replace their final readback in the same frame, retaining the same renderers.
 q2_selected_projection = R2OrdinaryHud.apply_to(hud,sim)
 composed_q_projection = q2_selected_projection.duplicate(true)
 p1_selected_projection = R2OrdinaryHud.apply_p_to(hud,sim)
 e3_selected_projection = R2OrdinaryECard.apply_to(hud,sim)
 e2_selected_projection = e3_selected_projection.duplicate(true)
 e1_selected_projection = e3_selected_projection.duplicate(true)
 r1_selected_projection = R2OrdinaryRCard.apply_to(hud,sim)
 hud.footer.text = R2OrdinaryHud.input_help(sim)
 R2OrdinaryText.correct_hud(hud)
 var r_preview: Dictionary = input_router.r1_preview_for_view(_current_pointer_ground())
 if is_instance_valid(r1_domain_view): r1_domain_view.present_source(sim.ink_presenter_snapshot(),r_preview if sim.hero.loadout.r == "r1" else {})
 if not is_instance_valid(r2_peaks_view): r2_peaks_view = R2OrdinaryView.new(); add_child(r2_peaks_view)
 r2_peaks_view.present_source(sim.ink_presenter_snapshot(),r_preview if sim.hero.loadout.r == "r2" else {})
 if is_instance_valid(e2_boat_view): e2_boat_view.present_source(sim.ink_presenter_snapshot(),e2_selected_projection)
 if is_instance_valid(e3_frame_view):
  var modal: bool = _mainprep_required or sim.paused or (shop_session != null and shop_session.panel_open)
  modal = modal or (is_instance_valid(initial_hud) and initial_hud.blocks_gameplay_input())
  var preview: Dictionary = {} if modal else input_router.e3_preview_for_view(_current_pointer_ground())
  e3_frame_view.present_source(sim.ink_presenter_snapshot(),preview,e3_selected_projection)

func _refresh_session_controls(force: bool) -> void:
 super._refresh_session_controls(force)
 if is_instance_valid(session_header): session_header.text = session_header.text.replace(E3RuntimeText.skill_line(),R2OrdinaryText.skill_line())

func _commerce_evidence() -> Dictionary:
 var report: Dictionary = super._commerce_evidence()
 report["runtime_source_binding"] = FileAccess.get_sha256(R2OrdinaryBinding.BINDING_PATH)
 report["single_composed_ordinary_leaf"] = true
 return report

func _e3_successor_report(report: Dictionary) -> Dictionary:
 var out: Dictionary = super._e3_successor_report(report)
 out["binding"] = FileAccess.get_sha256(R2OrdinaryBinding.BINDING_PATH)
 out["e1_original_pause_remainder_fixed"] = true
 out["r1_clock_consumer_composed"] = true
 return out

func p2_ordinary_report() -> Dictionary:
 var out: Dictionary = super.p2_ordinary_report()
 out["binding"] = FileAccess.get_sha256(R2OrdinaryBinding.BINDING_PATH)
 out["e1_original_pause_remainder_fixed"] = true
 out["r1_clock_consumer_composed"] = true
 return out

func e3_ordinary_report() -> Dictionary:
 var out: Dictionary = super.e3_ordinary_report()
 out["binding"] = FileAccess.get_sha256(R2OrdinaryBinding.BINDING_PATH)
 out["e1_original_pause_remainder_fixed"] = true
 out["r1_clock_consumer_composed"] = true
 return out

func r2_ordinary_report() -> Dictionary:
 return {"binding":FileAccess.get_sha256(R2OrdinaryBinding.BINDING_PATH),"sim_script":sim.get_script().resource_path if is_instance_valid(sim) else "","single_owner_intact":shop_session._owner_intact() if shop_session != null and shop_session.ledger != null else false,"selected_p":p1_selected_projection.duplicate(true),"selected_e":e3_selected_projection.duplicate(true),"selected_r":r1_selected_projection.duplicate(true),"P1_P2_exclusive":true,"e1_original_remainder_composed":true,"r1_clock_consumer_composed":true,"r2_clock_consumer_composed":true,"R1_R2_exclusive":true,"new_hex_admission":false,"final_presentation_animation":false,"real_multiplayer":false,"native_input":"NOT_RUN","full_floor":"NOT_RUN"}

func _write_json(filename: String, contents: Dictionary) -> void:
 var out: Dictionary = contents.duplicate(true)
 out["r2_ordinary_integration"] = r2_ordinary_report()
 super._write_json(filename,out)

func _create_session_controls() -> void:
 super._create_session_controls()
 if is_instance_valid(initial_hud): R2OrdinaryGrowth.apply_r2_layout(initial_hud)
