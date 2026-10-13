extends "res://tests/ink_first_floor_user_route_20261005/native_host01/navigation_host.gd"
## Independent opt-in presentation leaf. Underlying30/300 route/nav/Q1/effect05
## constructors remain intact. Final author identity is required before admission.
const GestureActor = preload("res://tests/ink_q1_flow_20261005/gesture06/runtime/hero_view.gd")
const IntentReporter = preload("res://tests/ink_q1_flow_20261005/gesture06/runtime/intent_report.gd")
const INTENT_REPORT_PATH := "res://tests/ink_q1_flow_20261005/gesture06/runtime/intent_report.gd"
const GESTURE_ROOT := "res://tests/ink_first_floor_user_route_20261005/gesture06_host01/parsefix01/"
const GESTURE_ACTOR_PATH := "res://tests/ink_q1_flow_20261005/gesture06/runtime/hero_view.gd"
var gesture_contract: Dictionary = {}
var gesture_installed := false
var gesture_installation: Dictionary = {"accepted":false,"reason":"not_attempted"}
var gesture_actor_replacements := 0
var gesture_removed_actor_id := 0

func _actor_is_composed() -> bool:
 if not gesture_installed: return super._actor_is_composed()
 return is_instance_valid(hero_view) and hero_view.get_script() == GestureActor

func _gesture_gameplay_seal() -> PackedByteArray:
 return var_to_bytes([sim.snapshot(),sim.ink_presenter_snapshot(),sim.event_log,shop_session.ledger.model.save(),shop_session.snapshot(),sim.rng.state,sim.enemy_director.get_instance_id(),sim.enemy_director.get_script().resource_path])

func _start_encounter() -> void:
 var fresh: bool = shop_session == null
 super._start_encounter()
 if not fresh: return
 if sim == null or not startup_session_error.is_empty() or not floor_error.is_empty(): return
 if not flow_installed or not flow_install_source_equal or not navigation_installation.get("accepted",false):
  _gesture_fail("original_Q1_and_navigation_seals_required"); return
 var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(GESTURE_ROOT+"gesture_contract.json"))
 if not loaded is Dictionary or loaded.get("schema","") != "ink-new-route-gesture06-contract-1" or loaded.get("ready",false) != true or loaded.get("status","") != "FROZEN_AUTHOR_RUNTIME_PINS":
  _gesture_fail("final_gesture_author_identity_pending"); return
 gesture_contract = loaded.duplicate(true)
 var expected: Dictionary = gesture_contract.get("expected_identity",{})
 if expected.get("actor_script","") != GESTURE_ACTOR_PATH or expected.get("actor_script_sha","") != FileAccess.get_sha256(GESTURE_ACTOR_PATH):
  _gesture_fail("gesture_actor_source_mismatch"); return
 if sim.hero_time != 0.0 or sim.phase != "preparation" or sim.wave != 0 or not sim.enemies.is_empty():
  _gesture_fail("fresh_preparation_before_first_input_required"); return
 var before: PackedByteArray = _gesture_gameplay_seal()
 var director_before: int = sim.enemy_director.get_instance_id()
 gesture_removed_actor_id = hero_view.get_instance_id()
 remove_child(hero_view); hero_view.free()
 hero_view = GestureActor.new(); add_child(hero_view)
 gesture_actor_replacements += 1
 gesture_installed = true
 _refresh(0.0)
 var data_equal: bool = before == _gesture_gameplay_seal()
 var identity: Dictionary = _composed_warmup_identity()
 gesture_installation = {"accepted":data_equal and identity.accepted,"source_ledger_session_rng_and_director_equal":data_equal,"director_instance_unchanged":director_before == sim.enemy_director.get_instance_id(),"new_actor_replacements":gesture_actor_replacements,"prior_Flow_actor_freed":not is_instance_id_valid(gesture_removed_actor_id),"identity":identity,"presentation_only":true,"native_input_passed":false,"art_accepted":false}
 if not gesture_installation.accepted: _gesture_fail("gesture_install_data_or_identity_HOLD")

func _gesture_fail(reason: String) -> void:
 gesture_installation["accepted"] = false; gesture_installation["reason"] = reason
 floor_error = reason
 _pause(true,"gesture06_fail_closed")

static func gesture_identity_errors(value: Dictionary, expected: Dictionary) -> Array[String]:
 var errors: Array[String] = []
 if expected.is_empty(): errors.append("frozen_expected_identity_required"); return errors
 for field: String in expected:
  if value.get(field,null) != expected[field]: errors.append(field+"_mismatch")
 for field: String in ["q1_exact_script","actor_exact_script","flow_bound","q3_bound","pigment_exact_resource","flow_material_ready","intent_ready","intent_report_exact","intent_consumer_accepted"]:
  if value.get(field,false) != true: errors.append(field+"_required")
 if value.get("actor_status","") != "import_structure_checked_not_visual_acceptance": errors.append("actor_import_status_required")
 if not value.get("actor_errors",null) is Array or not value.get("actor_errors",["missing"]).is_empty(): errors.append("actor_import_errors")
 return errors

func _composed_warmup_identity() -> Dictionary:
 if not gesture_installed: return super._composed_warmup_identity()
 # The old Flow/Q3 asset bindings are retained dependencies, while actor identity
 # is genuinely the new intent script. Never label the new actor as the old one.
 var inherited: Dictionary = super._composed_warmup_identity()
 var value: Dictionary = inherited.get("evidence",{}).duplicate(true)
 value["actor_script"] = hero_view.get_script().resource_path
 value["actor_script_sha"] = FileAccess.get_sha256(GESTURE_ACTOR_PATH)
 value["intent_asset"] = GestureActor.INTENT_ASSET
 value["intent_asset_sha"] = FileAccess.get_sha256(GestureActor.INTENT_ASSET)
 value["intent_binding_sha"] = FileAccess.get_sha256(GestureActor.INTENT_BINDING)
 value["intent_boundaries_sha"] = FileAccess.get_sha256(GestureActor.INTENT_ROOT+"source_boundaries.json")
 value["intent_ready"] = hero_view.intent_ready
 value["intent_report_script"] = INTENT_REPORT_PATH
 value["intent_report_sha"] = FileAccess.get_sha256(INTENT_REPORT_PATH)
 var reporter_script: Script = load(INTENT_REPORT_PATH)
 value["intent_report_exact"] = reporter_script != null and reporter_script == IntentReporter and reporter_script.resource_path == INTENT_REPORT_PATH
 var consumer: Dictionary = IntentReporter.capture(hero_view)
 value["intent_consumer_accepted"] = consumer.get("accepted",false)
 var errors: Array[String] = gesture_identity_errors(value,gesture_contract.get("expected_identity",{}))
 return {"accepted":errors.is_empty(),"errors":errors,"evidence":value,"source_written":false,"drawn_warmup_accepted":false,"intent_consumer_readback":consumer,"intent_consumption_scope":"actual private AnimationPlayer alias and window readback; final native appearance still separate"}

func _mainprep_environment() -> Dictionary:
 var result: Dictionary = super._mainprep_environment()
 if gesture_installed:
  result["gesture_intent_binding"] = FileAccess.get_sha256(GestureActor.INTENT_BINDING)
 return result

func _session_scope() -> String:
 return super._session_scope()+"\n独立gesture06动作候选，保留effect05；真实intent消费与美术验收单列"

func gesture_host_report() -> Dictionary:
 return {"scope":"new_user_route_navigation_and_actor_only_gesture06_leaf","installed":gesture_installed,"installation":gesture_installation.duplicate(true),"actor_script":hero_view.get_script().resource_path if is_instance_valid(hero_view) else "","intent_state":hero_view.sample_report.get("q1_intent",{}).duplicate(true) if gesture_installed else {},"intent_consumer":IntentReporter.capture(hero_view) if gesture_installed else {},"actual_actor_sample_upper":hero_view.sample_report.get("upper","") if gesture_installed else "","handoff_instantiated":false,"new_effects_added":false,"effect_retained":"effect05","binding_sha256":FileAccess.get_sha256(GESTURE_ROOT+"source_binding.json") if FileAccess.file_exists(GESTURE_ROOT+"source_binding.json") else "PENDING","art_accepted":false,"native_input_passed":false,"full_floor_passed":false}

func _write_json(filename: String,contents: Dictionary) -> void:
 var output: Dictionary = contents.duplicate(true)
 output["gesture06_host"] = gesture_host_report()
 super._write_json(filename,output)

func _prepare_main_viewport() -> void:
 if not gesture_installed or not gesture_installation.get("accepted",false):
  _mainprep_fail_startup("gesture06_final_identity_not_admitted"); return
 if finished or _mainprep_attempted or _mainprep_pending: return
 if DisplayServer.get_name() == "headless" or gate_mode:
  _mainprep_fail_startup("native_main_viewport_required")
  return
 if not sim.paused or sim.hero_time != 0.0 or restart_count != 0:
  _mainprep_fail_startup("not_first_paused_idle_zero_construction")
  return
 if _mainprep_stable_draws < 3: return
 if segment_armed or segment_active or not capture_pending.is_empty():
  _mainprep_fail_startup("capture_already_armed")
  return
 if sim.ink_input.phase != "idle" or not sim.ink_waves.is_empty() or not sim.ink_receipts.is_empty():
  _mainprep_fail_startup("not_first_input_idle_source")
  return
 if not _composed_warmup_identity().accepted:
  _mainprep_fail_startup("exact_Q1_flow_effect05_identity_mismatch")
  return
 if not q1_view._initialized or q1_view._materials.size() != 2:
  _mainprep_fail_startup("original_contact_preview_material_layout_not_ready")
  return
 for resource in [q1_view._materials[0], q1_view._materials[1], q1_view._paint_texture, q1_view._stroke_texture,
   q1_view._preview_material, q1_view._preview_under_material, q1_view._contact_black, q1_view._contact_wet, q1_view._contact_mineral]:
  if not is_instance_valid(resource):
   _mainprep_fail_startup("contact_preview_resource_not_ready")
   return
 if audio_output.pcm_nonzero_frames != 0 or audio_output.players.any(func(player: AudioStreamPlayer): return player.playing):
  _mainprep_fail_startup("startup_audio_not_silent")
  return
 _mainprep_attempted = true
 _mainprep_pending = true
 _mainprep_started_usec = Time.get_ticks_usec()
 _mainprep_label.text = "正在准备首次显示资源；F10 退出"
 var before: Dictionary = _mainprep_seal()
 var environment_before: Dictionary = _mainprep_environment()
 var source_snapshot: Dictionary = sim.ink_presenter_snapshot()
 var process_before := _mainprep_suppressed_process_calls
 var rows: Array = []
 var failures: Array[String] = []
 _mainprep_receipt = {"status": "preparation_in_progress", "trigger": "automatic first-construction stable paused viewport",
  "first_actual_input_pending": true, "performance_passed": false}
 _write_json("main_viewport_warmup.json", _mainprep_receipt)
 if FileAccess.get_sha256(FIXTURES) != FIXTURES_SHA:
  failures.append("fixture_file_identity_mismatch")
 var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES))
 if not fixture is Dictionary or fixture.get("schema", "") != "ink-main-viewport-presentation-fixtures-1":
  failures.append("fixture_schema_mismatch")
 if failures.is_empty():
  q1_view.reset_visuals()
  for sample: Dictionary in fixture.samples:
   var sample_bytes := var_to_bytes(sample.snapshot)
   var drawn_before := draw_count
   q1_view.present(sample.snapshot)
   var geometry: Array = _mainprep_mesh_readback()
   var geometry_errors: Array[String] = _mainprep_geometry_failures(str(sample.name), geometry)
   var actual_draws: bool = await _mainprep_wait_draws()
   if finished:
    return
   var unchanged: Array[String] = _mainprep_compare(before, _mainprep_seal())
   var environment_unchanged: bool = environment_before == _mainprep_environment()
   rows.append({"fixture": sample.name, "original_source_line": sample.source_line,
    "fixture_source_time": sample.snapshot.source_time, "actual_main_viewport_draws": draw_count - drawn_before,
    "mesh_before_draws": geometry, "geometry_errors": geometry_errors, "source_differences": unchanged,
    "main_viewport_draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
    "environment_and_resources_unchanged": environment_unchanged,
    "fixture_argument_unchanged": sample_bytes == var_to_bytes(sample.snapshot),
    "diagnostics": q1_view.get_diagnostics()})
   if not actual_draws or not unchanged.is_empty() or not environment_unchanged or not geometry_errors.is_empty() or sample_bytes != var_to_bytes(sample.snapshot):
    failures.append("sample_" + str(sample.name) + "_guard_or_draw_failed")
    break
 # Clear all sampled waves, receipt dedup and retirement state, while retaining
 # the presenter's texture/material resources and bounded reusable node pool.
 q1_view.reset_visuals()
 q1_view.present(sim.ink_presenter_snapshot())
 var restore_draws: bool = await _mainprep_wait_draws()
 if finished:
  return
 var after: Dictionary = _mainprep_seal()
 var differences: Array[String] = _mainprep_compare(before, after)
 var clean: bool = q1_view._wave_nodes.is_empty() and q1_view._contact_nodes.is_empty() and q1_view._residue_nodes.is_empty() and q1_view._seen_contacts.is_empty()
 for child in q1_view.get_children():
  if child is MeshInstance3D and child.mesh != null and child.mesh.get_surface_count() > 0:
   clean = false
 var restored: bool = var_to_bytes(source_snapshot) == var_to_bytes(sim.ink_presenter_snapshot())
 if not restore_draws or not differences.is_empty() or not clean or not restored or environment_before != _mainprep_environment():
  failures.append("restore_guard_failed")
 _mainprep_receipt = {"status": "main_viewport_preparation_drawn_source_unchanged" if failures.is_empty() else "HOLD",
  "failures": failures, "before": _mainprep_seal_report(before), "after": _mainprep_seal_report(after),
  "source_differences": differences, "source_snapshot_restored": restored, "transients_and_dedup_empty": clean,
  "environment_before": environment_before, "environment_after": _mainprep_environment(), "samples": rows,
  "elapsed_wall_usec": Time.get_ticks_usec() - _mainprep_started_usec,
  "suppressed_inherited_process_calls": _mainprep_suppressed_process_calls - process_before,
  "fixture_sha256": FIXTURES_SHA, "input_blocked_during_preparation": true,
  "first_actual_input_pending": true, "performance_passed": false, "private_viewport_created": false,
  "source_steps_or_requests_by_preparation": 0, "audio_commands_by_preparation": 0,
  "blocked_input_events": _mainprep_blocked_events,
  "actor_candidate": "gesture06_exact_intent_rotation_leaf", "effect_candidate": "effect05_native_alpha",
  "explicit_diagnostic_pause": _mainprep_explicit_pause,
  "startup_focus_lost": _mainprep_focus_lost, "normal_run": false,
  "scope": "Preparation seal only: exact gesture06 intent actor and unchanged effect05 presenter in main viewport; actor-only revision, no new handoff effect. First-construction pause and post-success resume are separate host lifecycle transitions. No ordinary Lv1, Boss, art or performance acceptance."}
 _write_json("main_viewport_warmup.json", _mainprep_receipt)
 _mainprep_pending = false
 if failures.is_empty():
  _mainprep_required = false
  _mainprep_layer.queue_free()
  # Separate from, and strictly AFTER, the unchanged-source preparation seal.
  # This is the existing host lifecycle transition, not a source clock edit.
  var resume_allowed := startup_release_allowed(true, _mainprep_explicit_pause, _mainprep_focus_lost)
  var source_before_resume: Dictionary = _mainprep_seal_report(_mainprep_seal())
  if resume_allowed: _pause(false, "first_construction_loading_ready")
  _mainprep_startup_transition = {"status": "resumed_after_loading" if resume_allowed else "diagnostic_or_focus_pause_retained",
   "policy": startup_policy(_mainprep_explicit_pause), "focus_lost": _mainprep_focus_lost,
   "preparation_seal_unchanged_claim_excludes_this_transition": true,
   "before_resume": source_before_resume, "after_resume": _mainprep_seal_report(_mainprep_seal()),
   "source_time_after_resume": sim.hero_time, "source_steps_by_transition": 0,
   "host_resume_may_change_pause_input_audio_lifecycle": true}
  _write_json("startup_transition.json", _mainprep_startup_transition)
 else:
  _mainprep_label.text = "准备检查未通过，保持阻止玩法；查看凭证，F10 退出"

