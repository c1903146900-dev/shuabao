extends "res://tests/ink_first_floor_user_route_20261005/runtime01/host.gd"
## Opt-in first-battle composition. Source, input, clocks and Session are inherited.
const ComposedActor = preload("res://tests/ink_q3_gesture_runtime_20261004/fix01/hero_view.gd")
const ActorSeam = preload("res://tests/ink_q3_gesture_runtime_20261004/fix01/actor_view_seam.gd")
const SelectedQProjection = preload("res://tests/ink_selected_q_hud_20261005/projection.gd")
const SelectedQHUD = preload("res://tests/ink_selected_q_hud_20261005/fix01/hud_patch.gd")
const COMPOSED_ROOT := "res://tests/ink_first_battle_composed_20261005/fix03/"
var composed_actor_replacements: int = 0
var composed_event_deliveries: int = 0
var composed_before_present: int = 0
var composed_constructor_refresh_skips: int = 0
var composed_removed_actor_id: int = 0
var composed_q_projection: Dictionary = {}

func _actor_is_composed() -> bool:
 return is_instance_valid(hero_view) and hero_view.get_script() == ComposedActor

func _start_encounter() -> void:
 # Frozen parent builds its old actor and calls virtual _refresh synchronously.
 # Do not apply the new actor seam to that old object. No frame can render here.
 if shop_session != null:
  super._start_encounter(); return
 super._start_encounter()
 if sim == null or not startup_session_error.is_empty(): return
 if sim.hero_time != 0.0 or composed_actor_replacements != 0:
  floor_error = "composed_actor_requires_fresh_source_zero"; _pause(true,"composition_fail_closed"); return
 var previous: Node3D = hero_view
 composed_removed_actor_id = previous.get_instance_id()
 # Immediate removal/free means there is only one actor at the next frame.
 remove_child(previous); previous.free()
 hero_view = ComposedActor.new(); add_child(hero_view)
 composed_actor_replacements += 1
 # No event connection changes. The parent's one host callback remains bound.
 _refresh(0.0)

func _refresh(delta: float) -> void:
 if sim != null and _actor_is_composed():
  ActorSeam.before_present(hero_view,sim)
  composed_before_present += 1
 elif sim != null:
  composed_constructor_refresh_skips += 1
 super._refresh(delta)
 if sim != null and is_instance_valid(hud):
  composed_q_projection = SelectedQHUD.apply_to(hud,sim.snapshot(),sim.ink_presenter_snapshot(),SelectedQProjection.capture_context(sim))

func _combat_event(event: Dictionary) -> void:
 if not _actor_is_composed():
  super._combat_event(event); return
 if shop_session != null and shop_session.ledger != null:
  var observed: Dictionary = shop_session.observe_event(sim,event)
  if event.get("kind", "") in ["damage","kill"] and not observed.accepted: shop_session.last_receipt = observed
 enemy_layer.observe(sim,event)
 var detached: Dictionary = event.duplicate(true)
 events.append(detached)
 _queue_h02_event(detached)
 if str(event.get("kind", "")).begins_with("ink_q3_"):
  if q3_pending.size() < 128: q3_pending.append(detached)
  else: floor_error = "q3_event_buffer_overflow"
 ActorSeam.receive_event(hero_view,sim,detached)
 composed_event_deliveries += 1
 audio_output.consume(detached,sim.ink_presenter_snapshot())

func composition_report() -> Dictionary:
 var actor_ready: bool = _actor_is_composed()
 var actor_nodes: int = 0
 for child: Node in get_children():
  if child is MotionView: actor_nodes += 1
 var host_callbacks: int = 0
 if sim != null:
  for connection: Dictionary in sim.combat_event.get_connections():
   if connection.callable == Callable(self,"_combat_event"): host_callbacks += 1
 return {"schema":"ink-first-battle-composition-1","warmup_identity":_composed_warmup_identity(),"binding":FileAccess.get_sha256(COMPOSED_ROOT+"source_binding.json"),"floor_binding":FileAccess.get_sha256(REWARD_ROOT+"source_binding.json"),"hud_binding":FileAccess.get_sha256("res://tests/ink_selected_q_hud_20261005/fix01/source_binding.json"),"actor_manifest":FileAccess.get_sha256("res://tests/ink_q3_gesture_runtime_20261004/fix01/manifest.json"),"actor_script":hero_view.get_script().resource_path if is_instance_valid(hero_view) else "","actor_ready":actor_ready,"actor_replacements":composed_actor_replacements,"actor_nodes":actor_nodes,"removed_actor_still_valid":is_instance_id_valid(composed_removed_actor_id),"host_event_subscriptions":host_callbacks,"event_deliveries":composed_event_deliveries,"before_present_calls":composed_before_present,"constructor_refresh_skips":composed_constructor_refresh_skips,"selected_q":composed_q_projection.duplicate(true),"actor":hero_view.q3_runtime_report() if actor_ready else {},"actor_import_status":hero_view.proof.status if actor_ready else "not_composed","source_time":sim.hero_time if sim != null else -1.0,"source_sequence":sim.sequence if sim != null else -1,"source_steps_added_by_composition":0,"full_floor_passed":false,"native_input_passed":false,"art_accepted":false}

func _write_json(filename: String, contents: Dictionary) -> void:
 if evidence_dir.is_empty(): return
 var output: Dictionary = contents.duplicate(true)
 output["scope"] = _session_scope()
 output["first_battle_composition"] = composition_report()
 output["normal_floor"] = {"status":"SOURCE_CANDIDATE","binding":FileAccess.get_sha256(COMPOSED_ROOT+"source_binding.json"),"ancestor_floor_binding":FileAccess.get_sha256(REWARD_ROOT+"source_binding.json"),"flow":shop_session.snapshot() if shop_session != null else {},"enemies":enemy_layer.report if is_instance_valid(enemy_layer) else {},"q3":mountain_view.get_diagnostics() if is_instance_valid(mountain_view) else {},"preview":aim_preview.sample if is_instance_valid(aim_preview) else {},"dropped_history":dropped_history.duplicate(),"reward":_commerce_evidence(),"full_floor_passed":false,"native_art_performance_passed":false,"q3_gesture_imported":_actor_is_composed() and hero_view.q3_bound,"legacy_enemy_metrics_are_empty_anchor":true}
 var file: FileAccess = FileAccess.open(evidence_dir.path_join(filename),FileAccess.WRITE)
 if file != null: file.store_string(JSON.stringify(_json_safe(output),"  ")); file.close()


static func warmup_identity_errors(value: Dictionary) -> Array[String]:
 var errors: Array[String] = []
 var expected: Dictionary = {"q1_script":"res://tests/ink_q1_effect_20261004/revision07/q1_effect_presenter.gd","q1_script_sha":"8f1eb70a62b3c93562c5da963f2e50273a8aee2fdb9fd1f47e85e20740f01453","actor_script":"res://tests/ink_q3_gesture_runtime_20261004/fix01/hero_view.gd","actor_script_sha":"6ce09d2ea50d45f2fb2d8ec8a1dbf9c9759619eb1cf5055963b37e0018a1361c","actor_asset_path":ComposedActor.Q3_MODEL_PATH,"actor_asset_sha":ComposedActor.Q3_MODEL_SHA,"actor_proof_asset_sha":ComposedActor.Q3_MODEL_SHA}
 for field: String in expected:
  if value.get(field,"") != expected[field]: errors.append(field+"_mismatch")
 if value.get("q1_exact_script",false) != true: errors.append("q1_exact_script_required")
 if value.get("actor_exact_script",false) != true: errors.append("actor_exact_script_required")
 if value.get("q3_bound",false) != true: errors.append("q3_import_binding_required")
 if value.get("actor_status","") != "import_structure_checked_not_visual_acceptance": errors.append("actor_import_status_required")
 if not value.get("actor_errors",null) is Array or not value.get("actor_errors",["missing"]).is_empty(): errors.append("actor_import_errors")
 return errors

func _composed_warmup_identity() -> Dictionary:
 var actor_exact: bool = _actor_is_composed()
 var q1_exact: bool = is_instance_valid(q1_view) and q1_view.get_script() == BrushWave
 var actor_path: String = hero_view.get_script().resource_path if is_instance_valid(hero_view) else ""
 var q1_path: String = q1_view.get_script().resource_path if is_instance_valid(q1_view) else ""
 var value: Dictionary = {"q1_exact_script":q1_exact,"q1_script":q1_path,"q1_script_sha":FileAccess.get_sha256(q1_path) if q1_exact else "","actor_exact_script":actor_exact,"actor_script":actor_path,"actor_script_sha":FileAccess.get_sha256(actor_path) if actor_exact else "","actor_asset_path":ComposedActor.Q3_MODEL_PATH,"actor_asset_sha":FileAccess.get_sha256(ComposedActor.Q3_MODEL_PATH),"actor_proof_asset_sha":hero_view.proof.get("asset_sha256","") if actor_exact else "","q3_bound":hero_view.q3_bound if actor_exact else false,"actor_status":hero_view.proof.status if actor_exact else "not_composed","actor_errors":hero_view.proof.errors.duplicate() if actor_exact else ["not_composed"]}
 var errors: Array[String] = warmup_identity_errors(value)
 return {"accepted":errors.is_empty(),"errors":errors,"evidence":value,"source_written":false,"drawn_warmup_accepted":false}

func _prepare_main_viewport() -> void:
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
  _mainprep_fail_startup("current_Q07_composed_Q3fix01_identity_mismatch")
  return
 if not q1_view._initialized or q1_view._materials.size() != 2:
  _mainprep_fail_startup("current_Q07_material_layout_not_ready")
  return
 for resource in [q1_view._materials[0], q1_view._materials[1], q1_view._paint_texture, q1_view._stroke_texture,
   q1_view._preview_material, q1_view._preview_under_material, q1_view._contact_black, q1_view._contact_wet, q1_view._contact_mineral]:
  if not is_instance_valid(resource):
   _mainprep_fail_startup("current_Q07_resource_not_ready")
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
  "actor_candidate": "Q3gesture/fix01/a41f04ec", "effect_candidate": "revision07",
  "explicit_diagnostic_pause": _mainprep_explicit_pause,
  "startup_focus_lost": _mainprep_focus_lost, "normal_run": false,
  "scope": "Preparation seal only: exact current Q07 presenter in main viewport. First-construction pause and post-success resume are separate host lifecycle transitions. No ordinary Lv1, Boss, art or performance acceptance."}
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

