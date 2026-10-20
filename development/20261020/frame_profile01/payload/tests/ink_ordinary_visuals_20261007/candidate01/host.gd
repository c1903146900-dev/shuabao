extends "res://scripts/integration/yanguizhou_first_floor.gd"
const FrameCPU = preload("res://performance_probe_20261020/frame_cpu.gd")
## Single default-entry visual WIP. Artwork is not finally accepted.
## All gameplay, one Session, input, audio, room flow and startup seals inherit.
const OrdinaryVisualActor = preload("res://visual_rework_20261009/runtime_actor.gd")
const OrdinaryParentActor = preload("res://tests/ink_ultimate_presentation_art_20261006/dual_v03/imported_gate01/consumer_candidate.gd")
const VISUAL_PARENT_ACTOR_PATH := "res://tests/ink_ultimate_presentation_art_20261006/dual_v03/imported_gate01/consumer_candidate.gd"
const VISUAL_PARENT_ACTOR_SHA := "0a7fda57ef390040e815c62fbf9637b880e1066d75d53154043549eee0dd6a12"
const OrdinaryAttackFeedback = preload("res://tests/ink_attack_feedback_20261007/candidate02/attack_view.gd")
const OrdinarySnow = preload("res://tests/ink_r1_snow_art_20261008/candidate03/domain_view.gd")
const OrdinaryPeaks = preload("res://tests/ink_r2_scroll_art_20261008/candidate03/peaks_view.gd")
const VISUAL_ACTOR_PATH := "res://visual_rework_20261009/runtime_actor.gd"
const OriginalBrushActor=preload("res://tests/ink_ultimate_brush_art_20261008/candidate01/hero_view.gd")
const OriginalBrushSHA="c42104017bfd3ffb131a9595061964828ba1483c8f80fa3510a070394e0ae36c"
const VISUAL_ACTOR_SHA := "038f6805928d14df25b57444331c15c89a46231834554256ed742da50a05ea15"
const VISUAL_ADAPTER_PATH := "res://tests/ink_ultimate_presentation_art_20261006/dual_v03/presenter_adapter.gd"
const OrdinaryVisualClock = preload("res://tests/ink_ultimate_presentation_art_20261006/dual_v03/presenter_adapter.gd")
const VISUAL_ADAPTER_SHA := "b3fe166685f954575f07ba7cb4786ca34b2e9e0325f3cad6286ec8ed2fdfe133"
const VISUAL_ASSET_SHA := "2134978c8899ce3f94f785870159a1d46f15100ee2fd06dd583db37910bc5c1a"
const VISUAL_BINDING_SHA := "b10cee035d0f81666871e6a3bb1bb6c05255df27e0e13cdbecdccdab08b055c9"
const VISUAL_SIM_PATH := "res://tests/ink_river_hexes_20261006/ordinary01/sim.gd"
const VISUAL_SESSION_PATH := "res://tests/ink_river_hexes_20261006/frontdoor01/floor_session.gd"
const VISUAL_ACTOR_DIFFERENCES := ["actor_script_mismatch", "actor_script_sha_mismatch"]
const OrdinaryBossPresentation = preload("res://tests/ink_first_floor_boss_20261008/presentation01/manager.gd")
var ordinary_boss_presentation: Node3D
var ordinary_visual_actor_installed: bool = false
var ordinary_visual_views_installed: bool = false
var ordinary_visual_installation: Dictionary = {"accepted":false, "reason":"not_attempted"}
var ordinary_visual_asset_binding: Dictionary = {}
var ordinary_visual_clock_binding: Dictionary = {}
var ordinary_attack_feedback: Node3D
var ordinary_visual_event_deliveries: int = 0
var ordinary_visual_refreshes: int = 0

func _actor_is_composed() -> bool:
 if not ordinary_visual_actor_installed: return super._actor_is_composed()
 return is_instance_valid(hero_view) and hero_view.get_script() == OrdinaryVisualActor

func _start_encounter() -> void:
 var fresh: bool = shop_session == null
 super._start_encounter()
 if not fresh or not is_instance_valid(sim) or not startup_session_error.is_empty() or not floor_error.is_empty(): return
 if not release_installed or not release_installation.get("accepted",false):
  _ordinary_visual_fail("recovery08_ancestor_seal_required")
  return
 var ancestor: Dictionary = super._composed_warmup_identity()
 if not ancestor.get("accepted",false):
  _ordinary_visual_fail("recovery08_ancestor_identity_required")
  return
 if sim.get_script().resource_path != VISUAL_SIM_PATH or shop_session.get_script().resource_path != VISUAL_SESSION_PATH or not shop_session._owner_intact():
  _ordinary_visual_fail("exact_inherited_river_source_and_session_required")
  return
 if FileAccess.get_sha256(VISUAL_ACTOR_PATH) != VISUAL_ACTOR_SHA or FileAccess.get_sha256(VISUAL_PARENT_ACTOR_PATH) != VISUAL_PARENT_ACTOR_SHA or FileAccess.get_sha256(VISUAL_ADAPTER_PATH) != VISUAL_ADAPTER_SHA:
  _ordinary_visual_fail("dual_actor_or_adapter_script_changed")
  return
 if sim.hero_time != 0.0 or sim.phase != "preparation" or sim.wave != 0 or not sim.enemies.is_empty() or ordinary_visual_actor_installed:
  _ordinary_visual_fail("fresh_ordinary_preparation_required")
  return
 var before: PackedByteArray = _gesture_gameplay_seal()
 var source_id: int = sim.get_instance_id()
 var session_id: int = shop_session.get_instance_id()
 var director_id: int = sim.enemy_director.get_instance_id()
 var removed_id: int = hero_view.get_instance_id()
 remove_child(hero_view)
 hero_view.free()
 hero_view = OrdinaryVisualActor.new()
 add_child(hero_view)
 ordinary_visual_actor_installed = true
 if not hero_view.recovery_ready or hero_view.proof.get("status", "HOLD") == "HOLD":
  _ordinary_visual_fail("actual_dual_actor_parent_HOLD")
  return
 ordinary_visual_asset_binding = hero_view.bind_ultimate_asset(VISUAL_ASSET_SHA, VISUAL_BINDING_SHA)
 if not ordinary_visual_asset_binding.get("accepted",false):
  _ordinary_visual_fail("actual_dual_asset_binding_HOLD")
  return
 ordinary_visual_clock_binding = hero_view.bind_ultimate_presentation_source(sim)
 if not ordinary_visual_clock_binding.get("accepted",false):
  _ordinary_visual_fail("actual_dual_source_clock_HOLD")
  return
 _ordinary_install_views()
 if not ordinary_visual_views_installed: return
 _refresh(0.0)
 var identity: Dictionary = _composed_warmup_identity()
 var unchanged: bool = before == _gesture_gameplay_seal()
 ordinary_visual_installation = {"accepted":unchanged and identity.get("accepted",false),
  "source_ledger_session_rng_and_director_equal":unchanged,
  "source_instance_unchanged":source_id == sim.get_instance_id(),
  "session_instance_unchanged":session_id == shop_session.get_instance_id(),
  "director_instance_unchanged":director_id == sim.enemy_director.get_instance_id(),
  "prior_actor_freed":not is_instance_id_valid(removed_id),
  "recovery08_ancestor_identity_accepted":ancestor.get("accepted",false),
  "identity_errors":identity.get("errors",[]), "art_accepted":false, "native_input_passed":false}
 if not ordinary_visual_installation.accepted:
  _ordinary_visual_fail("ordinary_visual_install_seal_HOLD")

func _ordinary_install_views() -> void:
 # The original slots keep their original callers and selected-R previews.
 if is_instance_valid(r1_domain_view):
  r1_domain_view.reset_visuals()
  r1_domain_view.free()
 r1_domain_view = OrdinarySnow.new()
 add_child(r1_domain_view)
 if is_instance_valid(r2_peaks_view):
  r2_peaks_view.reset_visuals()
  r2_peaks_view.free()
 r2_peaks_view = OrdinaryPeaks.new()
 add_child(r2_peaks_view)
 ordinary_attack_feedback = OrdinaryAttackFeedback.new()
 add_child(ordinary_attack_feedback)
 if not r1_domain_view._ensure_resources() or not r2_peaks_view._ensure_resources() or not ordinary_attack_feedback._ensure_resources():
  _ordinary_visual_fail("ordinary_visual_standard_resources_HOLD")
  return
 if is_instance_valid(basic_view): basic_view.visible = false
 ordinary_visual_views_installed = true

func _ordinary_visual_fail(reason: String) -> void:
 ordinary_visual_installation["accepted"] = false
 ordinary_visual_installation["reason"] = reason
 floor_error = reason
 _pause(true, "ordinary_visuals_fail_closed")

func _composed_warmup_identity() -> Dictionary:
 if not ordinary_visual_actor_installed: return super._composed_warmup_identity()
 var inherited: Dictionary = super._composed_warmup_identity()
 var value: Dictionary = inherited.get("evidence",{}).duplicate(true)
 var expected: Dictionary = release_contract.get("expected_identity",{}).duplicate(true)
 # Change only the two leaf actor pins; every recovery/carry/gait/Q1 guard stays.
 expected["actor_script"] = VISUAL_ACTOR_PATH
 expected["actor_script_sha"] = VISUAL_ACTOR_SHA
 var errors: Array[String] = release_identity_errors(value, expected)
 var exact_actor: bool = _actor_is_composed() and FileAccess.get_sha256(VISUAL_ACTOR_PATH) == VISUAL_ACTOR_SHA and hero_view.get_script().get_base_script() == OriginalBrushActor and FileAccess.get_sha256("res://tests/ink_ultimate_brush_art_20261008/candidate01/hero_view.gd") == OriginalBrushSHA and hero_view.get_script().get_base_script().get_base_script() == OrdinaryParentActor and hero_view.get_script().get_base_script().get_base_script().get_base_script() == ReleaseActor and FileAccess.get_sha256(VISUAL_PARENT_ACTOR_PATH) == VISUAL_PARENT_ACTOR_SHA
 var differences: Array[String] = []
 for error: String in inherited.get("errors",[]):
  if exact_actor and error in VISUAL_ACTOR_DIFFERENCES: differences.append(error)
  else: errors.append("ancestor_guard:" + error)
 var sorted_differences: Array = differences.duplicate()
 sorted_differences.sort()
 var exact_differences: Array = VISUAL_ACTOR_DIFFERENCES.duplicate()
 exact_differences.sort()
 if sorted_differences != exact_differences: errors.append("exact_two_actor_identity_differences_required")
 if not exact_actor:
  errors.append("exact_dual_actor_required")
 if not hero_view.recovery_ready or not hero_view.ultimate_ready or hero_view.proof.get("status", "HOLD") == "HOLD":
  errors.append("actual_dual_actor_ready_required")
 if not ordinary_visual_asset_binding.get("accepted",false) or not ordinary_visual_clock_binding.get("accepted",false):
  errors.append("dual_asset_and_clock_binding_required")
 if FileAccess.get_sha256(hero_view.Ultimate_ASSET) != VISUAL_ASSET_SHA or FileAccess.get_sha256(hero_view.Ultimate_BINDING) != VISUAL_BINDING_SHA:
  errors.append("dual_asset_or_binding_changed")
 if FileAccess.get_sha256(VISUAL_ADAPTER_PATH) != VISUAL_ADAPTER_SHA or hero_view.ultimate_clock.get_script() != OrdinaryVisualClock or hero_view.ultimate_clock._source == null or hero_view.ultimate_clock._source.get_ref() != sim:
  errors.append("exact_dual_source_clock_required")
 if sim.get_script().resource_path != VISUAL_SIM_PATH or shop_session.get_script().resource_path != VISUAL_SESSION_PATH or not shop_session._owner_intact():
  errors.append("exact_inherited_river_owner_required")
 var result: Dictionary = inherited.duplicate(true)
 result["accepted"] = errors.is_empty()
 result["errors"] = errors
 result["evidence"] = value
 result["ordinary_visual_actor_differences"] = differences
 result["ordinary_visual_raw_ancestor_errors"] = inherited.get("errors",[]).duplicate()
 result["dual_asset_binding"] = ordinary_visual_asset_binding.duplicate(true)
 result["dual_clock_binding"] = ordinary_visual_clock_binding.duplicate(true)
 result["art_accepted"] = false
 return result

func _mainprep_environment() -> Dictionary:
 var result: Dictionary = super._mainprep_environment()
 if ordinary_visual_actor_installed:
  result["ordinary_visual_parent_actor_sha"] = FileAccess.get_sha256(VISUAL_PARENT_ACTOR_PATH)
  result["ordinary_visual_actor_sha"] = FileAccess.get_sha256(VISUAL_ACTOR_PATH)
  result["ordinary_visual_asset_sha"] = FileAccess.get_sha256(hero_view.Ultimate_ASSET)
  result["ordinary_visual_binding_sha"] = FileAccess.get_sha256(hero_view.Ultimate_BINDING)
  result["ordinary_visual_clock_id"] = hero_view.ultimate_clock.get_instance_id()
 return result

func _prepare_main_viewport() -> void:
 # Outside startup, retain the original preparation entry behavior.
 if not _mainprep_required:
  if not ordinary_visual_installation.get("accepted",false):
   _mainprep_fail_startup("ordinary_visuals_not_admitted")
   return
  super._prepare_main_viewport()
  return
 # A deferred third-frame request must still belong to this live startup.
 if not _startup_phase_check_deadline(Time.get_ticks_usec()): return
 if finished or _frontdoor_suspended or not _mainprep_required or _mainprep_attempted or _mainprep_pending: return
 if str(_mainprep_receipt.get("status", "")) == "HOLD": return
 if not ordinary_visual_installation.get("accepted",false):
  _mainprep_fail_startup("ordinary_visuals_not_admitted")
  return
 if not _startup_construction_complete or not _startup_draw_clock_armed or not _startup_phase_admitted():
  _mainprep_fail_startup("startup_phase_admission_required")
  return
 if not _startup_phase_drawable() or _mainprep_stable_draws < 3: return
 super._prepare_main_viewport()

var _ordinary_modal_refresh_queued: bool = false
var ordinary_modal_refreshes: int = 0
func _initial_modal_changed(blocked: bool) -> void:
 super._initial_modal_changed(blocked)
 # The Controller emits command_completed before it clears the mandatory Hex
 # modal. Refresh once after the authority's modal commit, outside that stack.
 if _ordinary_modal_refresh_queued or not is_inside_tree() or finished: return
 _ordinary_modal_refresh_queued = true
 _ordinary_refresh_after_modal.call_deferred()

func _ordinary_refresh_after_modal() -> void:
 _ordinary_modal_refresh_queued = false
 if not is_inside_tree() or finished or not is_instance_valid(session_header) or shop_session == null: return
 _refresh_session_controls(true)
 ordinary_modal_refreshes += 1

func _frame_cpu_body_refresh(delta: float) -> void:
 # Undo last frame's cosmetic transform before the one inherited enemy present.
 if is_instance_valid(ordinary_attack_feedback): ordinary_attack_feedback.clear_enemy_feedback()
 super._refresh(delta)
 if not ordinary_visual_views_installed or not is_instance_valid(sim): return
 if is_instance_valid(basic_view): basic_view.visible = false
 var ink: Dictionary = sim.ink_presenter_snapshot().duplicate(true)
 if finished or sim.hero.dead or sim.phase != "combat":
  ordinary_attack_feedback.reset_visuals()
 else:
  ordinary_attack_feedback.present_source(ink)
  ordinary_attack_feedback.apply_enemy_feedback(enemy_layer.roster.actor_view_map(), sim.snapshot().duplicate(true))
 if finished or sim.hero.dead:
  r1_domain_view.reset_visuals()
  r2_peaks_view.reset_visuals()
 # The River leaf fixes these projections after the frozen R2 parent has drawn
 # its rejected exact-R2 projections. Re-present only E views with final values.
 if is_instance_valid(e2_boat_view): e2_boat_view.present_source(ink, e2_selected_projection)
 if is_instance_valid(e3_frame_view) and input_router != null:
  var modal: bool = _mainprep_required or sim.paused or (shop_session != null and shop_session.panel_open)
  modal = modal or (is_instance_valid(initial_hud) and initial_hud.blocks_gameplay_input())
  var preview: Dictionary = {} if modal else input_router.e3_preview_for_view(_current_pointer_ground())
  e3_frame_view.present_source(ink, preview, e3_selected_projection)
 _ordinary_present_boss()
 ordinary_visual_refreshes += 1

func _combat_event(event: Dictionary) -> void:
 super._combat_event(event)
 _ordinary_live_receipt("combat_event", event)
 if not ordinary_visual_views_installed or not is_instance_valid(sim): return
 ordinary_attack_feedback.consume(event.duplicate(true), sim.ink_presenter_snapshot().duplicate(true))
 r2_peaks_view.receive_source(event.duplicate(true))
 ordinary_visual_event_deliveries += 1

func _request_next_room() -> void:
 if is_instance_valid(ordinary_boss_presentation): ordinary_boss_presentation.clear()
 # The inherited accepted transition destroys the previous enemy roster.
 # Remove cosmetic offsets before that boundary, even on a rejected request.
 if is_instance_valid(ordinary_attack_feedback): ordinary_attack_feedback.clear_enemy_feedback()
 super._request_next_room()

func _ordinary_reset_visuals() -> void:
 if is_instance_valid(ordinary_boss_presentation): ordinary_boss_presentation.clear()
 if is_instance_valid(ordinary_attack_feedback): ordinary_attack_feedback.reset_visuals()
 if ordinary_visual_views_installed:
  if is_instance_valid(r1_domain_view): r1_domain_view.reset_visuals()
  if is_instance_valid(r2_peaks_view): r2_peaks_view.reset_visuals()

func frontdoor_close_run(reason: String) -> bool:
 var accepted: bool = super.frontdoor_close_run(reason)
 if accepted: _ordinary_reset_visuals()
 return accepted

func close_sample(reason: String) -> void:
 _ordinary_reset_visuals()
 super.close_sample(reason)

func _exit_tree() -> void:
 _ordinary_reset_visuals()
 super._exit_tree()

func ordinary_visual_report() -> Dictionary:
 return {"candidate":"ordinary_visuals_candidate01", "revision":"review06_approved_WIP_not_final_art", "actor_path":VISUAL_ACTOR_PATH, "r1_view_path":r1_domain_view.get_script().resource_path if ordinary_visual_views_installed else "", "r2_view_path":r2_peaks_view.get_script().resource_path if ordinary_visual_views_installed else "", "installation":ordinary_visual_installation.duplicate(true),
  "actor_installed":ordinary_visual_actor_installed, "views_installed":ordinary_visual_views_installed,
  "feedback":ordinary_attack_feedback.report.duplicate(true) if is_instance_valid(ordinary_attack_feedback) else {},
  "snow":r1_domain_view.presentation_snapshot() if ordinary_visual_views_installed and is_instance_valid(r1_domain_view) else {},
  "peaks":r2_peaks_view.presentation_snapshot() if ordinary_visual_views_installed and is_instance_valid(r2_peaks_view) else {},
  "event_deliveries":ordinary_visual_event_deliveries, "refreshes":ordinary_visual_refreshes,
  "original_audio_reused":true, "default_changed":true, "art_accepted":false, "native_input_passed":false, "full_floor_passed":false}

# Opt-in test observer only: preserves receipts incrementally if a later exit fails.
# Authority, event order, inputs and source clock remain inherited.
var _ordinary_receipts_enabled: bool = "--ordinary-live-receipts" in OS.get_cmdline_user_args()
var _ordinary_receipt_rows: int = 0
var _ordinary_receipt_bytes: int = 0
var _ordinary_receipt_error: String = ""
func _record_pointer_input(event: InputEvent, ground: Vector3, result: Dictionary, route: String) -> void:
 super._record_pointer_input(event, ground, result, route)
 if not inputs.is_empty(): _ordinary_live_receipt("input", inputs[-1])
func _ordinary_live_receipt(kind: String, payload: Dictionary) -> void:
 if not _ordinary_receipts_enabled or evidence_dir.is_empty() or not is_instance_valid(sim): return
 if _ordinary_receipt_rows >= 128 or not _ordinary_receipt_error.is_empty(): return
 var row: Dictionary = {"kind":kind, "payload":payload.duplicate(true), "source_time":sim.hero_time,
  "wall_usec":Time.get_ticks_usec()-start_ticks, "hero_position":sim.hero.position,
  "hero_hp":sim.hero.hp, "phase":sim.phase, "paused":sim.paused,
  "authority":"observed after original callback; CUA proves device input separately"}
 var line: String = JSON.stringify(row)+"\n"
 var size: int = line.to_utf8_buffer().size()
 if size > 32768 or _ordinary_receipt_bytes+size > 2097152:
  _ordinary_receipt_error="bounded_receipt_limit";return
 var path: String = evidence_dir.path_join("ordinary_live_receipts.jsonl")
 var file = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE_READ)
 if file == null: _ordinary_receipt_error="receipt_open_failed";return
 file.seek_end();file.store_string(line);file.flush()
 if file.get_error()!=OK: _ordinary_receipt_error="receipt_write_failed"
 file.close();_ordinary_receipt_rows+=1;_ordinary_receipt_bytes+=size

func _ordinary_present_boss() -> void:
 if not is_instance_valid(sim) or not is_instance_valid(enemy_layer) or not is_instance_valid(enemy_layer.roster):
  if is_instance_valid(ordinary_boss_presentation): ordinary_boss_presentation.clear()
  return
 if not is_instance_valid(ordinary_boss_presentation):
  ordinary_boss_presentation = OrdinaryBossPresentation.new()
  add_child(ordinary_boss_presentation)
 var frame: Dictionary = {"world_time":sim.hero_time,"paused":sim.paused,"hero_dead":sim.hero.dead,"loading":_mainprep_required,"finished":finished}
 var report: Dictionary = ordinary_boss_presentation.present(sim,enemy_layer.roster.actor_view_map(),frame)
 if report.get("status","") == "HOLD":
  floor_error = str(report.get("reason","boss_presentation_HOLD"))
  _pause(true,"boss_presentation_fail_closed")

# Exact continuation of the unchanged root-return and Q2 constructor source seals.
func _return_binding_errors() -> Array[String]:
 var errors: Array[String] = super._return_binding_errors()
 var flow_path: String = "res://tests/ink_first_floor_user_route_20261005/native_host01/flow_bridge.gd"
 var flow_key: String = "root_return_pin:" + flow_path
 if flow_key in errors and preload("res://performance_probe_20261020/flow_binding.gd").accepts(flow_path, "fccc171979663a6f556bf531c6ce8ba29de06ac24e35464eef45bd3bdec8842f", root_return_contract):
  errors.erase(flow_key)
 var nav_path: String = "res://tests/ink_first_floor_user_route_20261005/native_host01/navigation_host.gd"
 var key: String = "root_return_pin:"+nav_path
 if key not in errors: return errors
 var transition_path: String = "res://visual_rework_20261009/binding/g01_navigation_transition.json"
 if FileAccess.get_sha256(transition_path) != "91ec28957ea7796049ccb2c017f0db84f3eb78d34c8ac84fe4df0d14a88f5a98": return errors
 var t: Variant = JSON.parse_string(FileAccess.get_file_as_string(transition_path))
 if not t is Dictionary or t.get("schema","") != "g01-navigation-exact-successor-1": return errors
 var n: Dictionary = t.get("navigation_host",{})
 var r: Dictionary = t.get("root_return",{})
 var q: Dictionary = t.get("q2_overlay",{})
 var a: Dictionary = t.get("director_authority",{})
 if n.get("path","") != nav_path or str(n.get("before","")).is_empty() or str(n.get("after","")).is_empty(): return errors
 if FileAccess.get_sha256(str(r.get("path",""))) != r.get("sha256","") or FileAccess.get_sha256(str(q.get("path",""))) != q.get("sha256",""): return errors
 var original: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(r.path)))
 var overlay: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(q.path)))
 if not original is Dictionary or not overlay is Dictionary or root_return_contract != original: return errors
 var predecessor: Dictionary = overlay.get("ancestor_pin_replacements",{}).get(nav_path,{})
 if original.get("files",{}).get(nav_path,"") != r.get("navigation_before",""): return errors
 if predecessor.get("before","") != r.get("navigation_before","") or predecessor.get("after","") != n.before or overlay.get("runtime_map",{}).get(nav_path,"") != n.before: return errors
 if FileAccess.get_sha256(str(a.get("plan_path",""))) != a.get("plan_sha256",""): return errors
 var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(a.plan_path)))
 if not plan is Dictionary: return errors
 var matches: int = 0
 for change: Dictionary in plan.get("changed",[]):
  if change.get("path","") == a.get("path",""):
   if change.get("before","") != a.get("before","") or change.get("after","") != a.get("after",""): return errors
   matches += 1
 if matches != 1 or FileAccess.get_sha256(str(a.get("path",""))) != a.get("after",""): return errors
 if FileAccess.get_sha256(nav_path) != n.after: return errors
 errors.erase(key)
 return errors

# Narrow reuse of the existing runtime_host startup phase policy.
var _startup_construction_complete: bool = false
var _startup_draw_clock_armed: bool = false
var _startup_first_draw_usec: int = 0

static func startup_phase_deadline(now_usec:int, origin_usec:int, total_seconds:float,
  armed:bool, first_draw_usec:int, attempted:bool, stable_limit_usec:int)->String:
 if float(now_usec-origin_usec)/1000000.0 >= total_seconds: return "total_wall"
 if armed and not attempted and now_usec-first_draw_usec > stable_limit_usec: return "stable_draws"
 return ""

func _startup_phase_check_deadline(now_usec:int)->bool:
 if finished: return false
 var deadline:String = startup_phase_deadline(now_usec,start_ticks,finite_seconds,
  _startup_draw_clock_armed,_startup_first_draw_usec,_mainprep_attempted,STARTUP_READY_WALL_LIMIT_USEC)
 if deadline == "total_wall":
  close_sample("independent_hard_wall_deadline_during_loading")
  return false
 if deadline == "stable_draws":
  _mainprep_fail_startup("stable_startup_draws_timeout")
  return false
 return true

func _startup_phase_admitted()->bool:
 if not ordinary_visual_installation.get("accepted",false) or not startup_session_error.is_empty() or not floor_error.is_empty(): return false
 if not is_instance_valid(sim) or shop_session == null or not shop_session._owner_intact(): return false
 if sim.get_script().resource_path != VISUAL_SIM_PATH or shop_session.get_script().resource_path != VISUAL_SESSION_PATH: return false
 return is_same(shop_session.sim,sim) and sim.paused and sim.hero_time == 0.0 and not sim.hero.dead

func _startup_phase_drawable()->bool:
 if DisplayServer.get_name() == "headless" or gate_mode: return false
 var viewport:Viewport = get_viewport()
 var window:Window = get_window()
 if not is_instance_valid(viewport) or not is_instance_valid(window) or not window.visible: return false
 var size:Vector2 = viewport.get_visible_rect().size
 return size.is_finite() and size.x > 0.0 and size.y > 0.0

func _drawn()->void:
 if not _mainprep_required:
  super._drawn()
  return
 if not _startup_phase_check_deadline(Time.get_ticks_usec()): return
 if _frontdoor_suspended or str(_mainprep_receipt.get("status", "")) == "HOLD": return
 if not _startup_construction_complete: return
 if not _startup_phase_admitted():
  _mainprep_fail_startup("startup_phase_admission_required")
  return
 if not _startup_phase_drawable(): return
 if not _startup_draw_clock_armed:
  _startup_draw_clock_armed = true
  _startup_first_draw_usec = Time.get_ticks_usec()
  # Only the size reference is set. The real parent callback counts this frame.
  _mainprep_last_size = get_viewport().get_visible_rect().size
 super._drawn()

func _frame_cpu_body_process(delta:float)->void:
 if not _mainprep_required:
  super._process(delta)
  return
 last_process_wall_usec = Time.get_ticks_usec()
 _mainprep_suppressed_process_calls += 1
 _startup_phase_check_deadline(last_process_wall_usec)
 # This is the unchanged runtime01 post-super bounded-history maintenance.
 for entry: Dictionary in [{"name":"inputs","list":inputs},{"name":"events","list":events},{"name":"pauses","list":pauses},{"name":"initial_actions","list":initial_actions},{"name":"process_ms","list":process_intervals_ms},{"name":"draw_ms","list":draw_intervals_ms}]:
  var list: Array = entry.list
  if list.size() > MAX_EVENT_LOG:
   var excess: int = list.size()-MAX_EVENT_LOG
   dropped_history[entry.name] = int(dropped_history.get(entry.name,0))+excess
   for index in range(excess): list.pop_front()


var _startup_construction_complete_usec: int = 0
func _ready() -> void:
 super._ready()
 _startup_construction_complete_usec = Time.get_ticks_usec()
 _startup_construction_complete = true

func startup_phase_diagnostics() -> Dictionary:
 var now_usec: int = Time.get_ticks_usec()
 return {"global_start_usec":start_ticks,"construction_complete_usec":_startup_construction_complete_usec,
  "construction_elapsed_usec":_startup_construction_complete_usec-start_ticks,
  "first_admitted_draw_usec":_startup_first_draw_usec,"draw_clock_armed":_startup_draw_clock_armed,
  "stable_draws":_mainprep_stable_draws,"mainprep_attempted":_mainprep_attempted,
  "global_elapsed_usec":now_usec-start_ticks,"stable_window_elapsed_usec":now_usec-_startup_first_draw_usec if _startup_draw_clock_armed else 0,
  "stable_limit_usec":STARTUP_READY_WALL_LIMIT_USEC,"total_wall_seconds":finite_seconds}

func _process(delta:float)->void:
 if not FrameCPU.active:
  _frame_cpu_body_process(delta)
  return
 var profile_started: int = FrameCPU.begin("host_process")
 _frame_cpu_body_process(delta)
 FrameCPU.end("host_process", profile_started)

func _refresh(delta: float) -> void:
 if not FrameCPU.active:
  _frame_cpu_body_refresh(delta)
  return
 var profile_started: int = FrameCPU.begin("host_refresh")
 _frame_cpu_body_refresh(delta)
 FrameCPU.end("host_refresh", profile_started)

func arm_frame_cpu_profile() -> bool:
 return FrameCPU.arm()
func stop_frame_cpu_profile() -> void:
 FrameCPU.stop()
func frame_cpu_profile_report() -> Dictionary:
 return FrameCPU.report()
