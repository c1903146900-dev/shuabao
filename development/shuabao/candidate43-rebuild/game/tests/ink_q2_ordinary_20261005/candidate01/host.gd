extends "res://tests/ink_first_floor_user_route_20261005/root_return_native01/follow02/side_carry04/gait06/recovery08_fix01/host.gd"
## Fresh Q2/Session composition under every retained actor and room guard.
const Q2Sim = preload("res://tests/ink_q2_foundation_20261005/fix01/ink_q2_sim.gd")
const Q2Session = preload("res://tests/ink_q2_ordinary_20261005/candidate01/floor_session.gd")
const Q2Router = preload("res://tests/ink_q2_ordinary_20261005/candidate01/input_adapter.gd")
const Q2Growth = preload("res://tests/ink_q2_ordinary_20261005/candidate01/growth_hud.gd")
const Q2RiverView = preload("res://tests/ink_q2_ordinary_20261005/candidate01/river_view.gd")
const Q2HUD = preload("res://tests/ink_q2_ordinary_20261005/candidate01/hud_projection.gd")
const Q2Navigation = preload("res://tests/ink_q2_ordinary_20261005/candidate01/navigation_install.gd")
const Q2Binding = preload("res://tests/ink_q2_ordinary_20261005/candidate01/live_binding.gd")
const NAV_FACTORY_PATH := "res://tests/ink_first_floor_user_route_20261005/native_host01/navigation_host.gd"
const NAV_FACTORY_PREIMAGE := "a6f0b5055712845ce3f0c1e0daadb22002f313de7e1c3644b313b32b31c5ef90"
var q2_river_view: Node3D
var q2_selected_projection: Dictionary = {}

func _make_floor_sim() -> Node:
 return Q2Sim.new()
func _make_floor_router() -> RefCounted:
 return Q2Router.new()
func _make_floor_session() -> RefCounted:
 return Q2Session.new()
func _make_floor_hud() -> Control:
 return Q2Growth.new()
func _install_source_navigation() -> Dictionary:
 return Q2Navigation.apply_to_fresh_ink_sim(sim)

func _return_binding_errors() -> Array[String]:
 var errors: Array[String] = super._return_binding_errors()
 var key: String = "root_return_pin:"+NAV_FACTORY_PATH
 if key not in errors: return errors
 # Only one explicitly preserved host-constructor preimage may be superseded.
 # No actor, clip, material, helper or any other ancestor pin is exempted.
 var overlay: Variant = JSON.parse_string(FileAccess.get_file_as_string(Q2Binding.BINDING_PATH))
 if not overlay is Dictionary: return errors
 var replacement: Dictionary = overlay.get("ancestor_pin_replacements",{}).get(NAV_FACTORY_PATH,{})
 var original: String = str(root_return_contract.get("files",{}).get(NAV_FACTORY_PATH,""))
 var actual: String = FileAccess.get_sha256(NAV_FACTORY_PATH)
 if original == NAV_FACTORY_PREIMAGE and replacement.get("before","") == NAV_FACTORY_PREIMAGE and replacement.get("after","") == actual and overlay.get("runtime_map",{}).get(NAV_FACTORY_PATH,"") == actual:
  errors.erase(key)
 return errors

func _refresh(delta: float) -> void:
 super._refresh(delta)
 if sim == null or input_router == null: return
 if not is_instance_valid(q2_river_view):
  q2_river_view = Q2RiverView.new(); add_child(q2_river_view)
 q2_river_view.present_source(sim.ink_presenter_snapshot(),input_router.q2_preview_for_view(_current_pointer_ground()))
 if is_instance_valid(hud):
  q2_selected_projection = Q2HUD.apply_to(hud,sim)
  composed_q_projection = q2_selected_projection.duplicate(true)

func _refresh_session_controls(force: bool) -> void:
 super._refresh_session_controls(force)
 if is_instance_valid(session_header) and shop_session != null and shop_session.ledger != null:
  session_header.text = session_header.text.replace("Q1/Q3，其他技能未开放","Q1/Q2/Q3候选；Q2临时显示/无音频，实机未验")

func _session_scope() -> String:
 return super._session_scope()+"\nQ1/Q2/Q3接线候选；Q2基础两段/原10hook；H03/H04未开放；Q2临时显示，美术/音频未实现，实机未验"

func _commerce_evidence() -> Dictionary:
 var report: Dictionary = super._commerce_evidence()
 report["prior_runtime_source_binding"] = report.get("runtime_source_binding","")
 report["runtime_source_binding"] = FileAccess.get_sha256(Q2Binding.BINDING_PATH)
 report["q2_overlay"] = true
 return report

func q2_ordinary_report() -> Dictionary:
 return {"binding":FileAccess.get_sha256(Q2Binding.BINDING_PATH),"sim_script":sim.get_script().resource_path if sim != null else "","session_script":shop_session.get_script().resource_path if shop_session != null else "","single_owner_intact":shop_session._owner_intact() if shop_session != null and shop_session.ledger != null else false,"input_script":input_router.get_script().resource_path if input_router != null else "","selected_q":q2_selected_projection.duplicate(true),"river_display":q2_river_view.river_sample.duplicate(true) if is_instance_valid(q2_river_view) else {},"H03_H04_offered":false,"art_audio_implemented":false,"native_input_passed":false,"full_floor_passed":false}

func _write_json(filename: String, contents: Dictionary) -> void:
 var output: Dictionary = contents.duplicate(true)
 output["q2_ordinary_integration"] = q2_ordinary_report()
 super._write_json(filename,output)
