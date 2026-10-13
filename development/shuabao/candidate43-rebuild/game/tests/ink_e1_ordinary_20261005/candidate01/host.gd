extends "res://tests/ink_q2_ordinary_20261005/candidate01/host.gd"
## New leaf only. Existing actor, room, route, shop and source-step loop remain.
const E1Sim = preload("res://tests/ink_e1_ordinary_20261005/candidate01/sim.gd")
const E1Router = preload("res://tests/ink_e1_ordinary_20261005/candidate01/input_adapter.gd")
const E1Session = preload("res://tests/ink_e1_ordinary_20261005/candidate01/floor_session.gd")
const E1Growth = preload("res://tests/ink_e1_ordinary_20261005/candidate01/growth_hud.gd")
const E1Navigation = preload("res://tests/ink_e1_ordinary_20261005/candidate01/navigation_install.gd")
const E1Binding = preload("res://tests/ink_e1_ordinary_20261005/candidate01/live_binding.gd")
const E1QHud = preload("res://tests/ink_e1_ordinary_20261005/candidate01/hud_projection.gd")
const E1Card = preload("res://tests/ink_e1_ordinary_20261005/candidate01/e1_hud.gd")
var e1_selected_projection: Dictionary = {}
var e1_release_events: Array = []

func _make_floor_sim() -> Node: return E1Sim.new()
func _make_floor_router() -> RefCounted: return E1Router.new()
func _make_floor_session() -> RefCounted: return E1Session.new()
func _make_floor_hud() -> Control: return E1Growth.new()
func _install_source_navigation() -> Dictionary: return E1Navigation.apply_to_fresh_ink_sim(sim)

func _input(event: InputEvent) -> void:
 var observed: bool = false
 if not finished and not _mainprep_required and input_router != null and is_instance_valid(sim) and event is InputEventKey:
  var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  if key == KEY_E and not event.pressed and not event.echo and input_router.e1_release_is_owned():
   var result: Dictionary = input_router.handle_event(event,Vector3.INF)
   _record_e1_release(result,"real_E_up_before_GUI"); observed = true
 # The existing modal guard still sees and drains the delivered key-up.
 super._input(event)
 if observed: get_viewport().set_input_as_handled()

func frontdoor_observe_e1_release(event: InputEvent) -> Dictionary:
 if finished or _mainprep_required or input_router == null or not is_instance_valid(sim): return {"accepted":false,"reason":"e1_room_unavailable"}
 var result: Dictionary = input_router.queue_owned_boundary_e_up(event)
 _record_e1_release(result,"real_E_up_forwarded_by_frontdoor_fence")
 return result

func _record_e1_release(result: Dictionary, origin: String) -> void:
 e1_release_events.append({"origin":origin,"source_time":sim.hero_time,"room_id":sim.room_id,"generation":sim.encounter_generation,"paused":sim.paused,"receipt":result.duplicate(true)})
 if e1_release_events.size() > 32: e1_release_events.pop_front()

func _refresh(delta: float) -> void:
 super._refresh(delta)
 if not is_instance_valid(sim) or not is_instance_valid(hud): return
 # Parent Q2 context is exact-Q2 and therefore intentionally unavailable here.
 # Rebuild the entire selected-Q projection for this exact composed source.
 q2_selected_projection = E1QHud.apply_to(hud,sim)
 composed_q_projection = q2_selected_projection.duplicate(true)
 e1_selected_projection = E1Card.apply_to(hud,sim)

func _refresh_session_controls(force: bool) -> void:
 super._refresh_session_controls(force)
 if is_instance_valid(session_header) and shop_session != null and shop_session.ledger != null:
  session_header.text = session_header.text.replace("Q1/Q2/Q3候选；Q2临时显示/无音频，实机未验","Q1/Q2/Q3＋基础E1候选；E1临时文字/无音频，组合实机未验")

func _session_scope() -> String:
 return "晏归舟 · 普通Lv1 / 0金 / 0XP / 原1SP · 首层12行沿线选择/Boss最后\nQ1/Q2/Q3＋基础E1和BASIC/Shift；原10hook，H07/H08未开放\nE1临时文字显示，美术/音频未完成；类别穿行与组合实机未验"

func _commerce_evidence() -> Dictionary:
 var report: Dictionary = super._commerce_evidence()
 report["q2_parent_runtime_source_binding"] = report.get("runtime_source_binding","")
 report["runtime_source_binding"] = FileAccess.get_sha256(E1Binding.BINDING_PATH)
 report["e1_overlay"] = true
 return report

func e1_ordinary_report() -> Dictionary:
 return {"binding":FileAccess.get_sha256(E1Binding.BINDING_PATH),"sim_script":sim.get_script().resource_path if is_instance_valid(sim) else "","single_owner_intact":shop_session._owner_intact() if shop_session != null and shop_session.ledger != null else false,"selected_q":q2_selected_projection.duplicate(true),"selected_e":e1_selected_projection.duplicate(true),"releases":e1_release_events.duplicate(true),"H07_H08_offered":false,"temporary_text_only":true,"ordinary_class_collision_verified":false,"native_input_passed":false,"full_floor_passed":false,"q2_diagnostic_is_inherited_readback":true}

func _write_json(filename: String, contents: Dictionary) -> void:
 var output: Dictionary = contents.duplicate(true)
 output["e1_ordinary_integration"] = e1_ordinary_report()
 super._write_json(filename,output)
