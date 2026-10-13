extends "res://scripts/integration/yanguizhou_first_floor.gd"
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
const VISUAL_ACTOR_SHA := "c0ad0a2f51548126a338a9333cfc9b7bc39c0f806f86dec795e031ff86adca66"
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
 if not ordinary_visual_installation.get("accepted",false):
  _mainprep_fail_startup("ordinary_visuals_not_admitted")
  return
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

func _refresh(delta: float) -> void:
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

const TerminalPotionControls=preload("res://visual_rework_20261009/postboss_potion_controls.gd")
func _create_session_controls()->void:
 super._create_session_controls()
 if shop_session==null or shop_session.ledger==null:return
 if is_instance_valid(ordinary_potion_controls):
  var previous=ordinary_potion_controls;previous.get_parent().remove_child(previous);previous.queue_free()
 ordinary_potion_controls=TerminalPotionControls.new()
 ordinary_potion_controls.name="OrdinaryPotionControls"
 session_canvas.add_child(ordinary_potion_controls)
 ordinary_potion_controls.bind_session(shop_session)
