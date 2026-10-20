extends "res://tests/ink_first_floor_user_route_20261005/native_host01/audio_bridge.gd"
const LegacyFrameCPU = preload("res://performance_probe_20261020/frame_cpu.gd")
## Explicit ordinary-resource WIP Q1 native-input review, not a new hero admission.
const FlowActor=preload("res://tests/ink_q1_flow_20261005/runtime/fix02/parsefix01/hero_view.gd")
const FlowEffect=preload("res://tests/ink_q1_flow_20261005/effect05/q1_effect_presenter.gd")
const FLOW_IDENTITY={"q1_script":"res://tests/ink_q1_flow_20261005/effect05/q1_effect_presenter.gd","q1_script_sha":"c2c7b96c1855c3e9f3959083fc0d05d49b7943f054b0d7ef6c3bf852f3f81673","q1_shader":"res://tests/ink_q1_flow_20261005/effect05/ink_belly.gdshader","q1_shader_sha":"517c94001950db6e257584cc2d0c818e2719eefa4b311a890f5eb3afd826df81","pigment_sha":"95eebee8b0c7019bf2168d804a3dafc07b5dc39d10299e9279e06704f3474590","actor_script":"res://tests/ink_q1_flow_20261005/runtime/fix02/parsefix01/hero_view.gd","actor_script_sha":"d51ffc94edce128039ccf297e8e94fd6b02abc75c4892f2eeebe1abfec26e4ba","visible_asset_sha":"a41f04eca11416a1908caa6afc681afd2d3493b1470b402cd8ac4abd8d941bc2","flow_asset_sha":"b558f0c56aeacb1d6455b85a474e435921f82b281540c4952f3d474d9abad589","flow_binding_sha":"961b39f9fa77cd34ce64b4ebce65bb474cb494e7d7cc90507ad611a9ab06bb4a"}
const FLOW_PIGMENT="res://tests/ink_q1_effect_20261004/revision06/q1_single_loaded_stroke.png"
const FLOW_SHADER="res://tests/ink_q1_flow_20261005/effect05/ink_belly.gdshader"
var flow_actor_replacements: int=0
var flow_effect_replacements: int=0
var flow_removed_actor_id: int=0
var flow_installed: bool=false
var flow_install_source_equal: bool=false

func _session_scope() -> String:
 return "晏归舟 · Q1笔墨原生WIP复看 / 普通Lv1 · 0金0XP原1SP\n真实初始选择和学习；保留原Q3/BASIC/Shift，E族未接；美术未通过"

func _actor_is_composed() -> bool:
 return is_instance_valid(hero_view) and hero_view.get_script()==FlowActor

func _flow_source_seal() -> PackedByteArray:
 return var_to_bytes([sim.snapshot(),sim.ink_presenter_snapshot(),sim.event_log,shop_session.ledger.model.snapshot(),shop_session.snapshot()])

func _start_encounter() -> void:
 var fresh: bool=shop_session==null
 super._start_encounter()
 if not fresh or sim==null or not startup_session_error.is_empty():return
 if sim.hero_time!=0.0 or flow_actor_replacements!=0:
  floor_error="Q1_native_requires_fresh_source_zero";_pause(true,"Q1_composition_fail_closed");return
 var before: PackedByteArray=_flow_source_seal()
 flow_removed_actor_id=hero_view.get_instance_id()
 remove_child(hero_view);hero_view.free()
 hero_view=FlowActor.new();add_child(hero_view)
 flow_actor_replacements+=1
 flow_installed=true
 _refresh(0.0)
 flow_install_source_equal=before==_flow_source_seal()
 if not flow_install_source_equal or not hero_view.flow_ready:
  floor_error="Q1_native_install_source_or_asset_HOLD";_pause(true,"Q1_composition_fail_closed")

func flow_native_report() -> Dictionary:
 return {"status":"Q1_NATIVE_WIP_NOT_ART_ACCEPTED","installed":flow_installed,"actor_replacements_after_original_constructor":flow_actor_replacements,"original_constructor_actor_replacements":composed_actor_replacements,"effect_replacements":flow_effect_replacements,"removed_actor_still_valid":is_instance_id_valid(flow_removed_actor_id),"install_source_equal":flow_install_source_equal,"identity":_composed_warmup_identity() if flow_installed else {},"new_actor_proof":hero_view.proof if flow_installed else {},"new_actor_sample":hero_view.sample_report if flow_installed else {},"ordinary_start_resources":true,"automatic_learning":false,"new_E_family_enabled":false,"art_accepted":false,"native_input_accepted":false}

func _write_json(filename: String,contents: Dictionary) -> void:
 var output: Dictionary=contents.duplicate(true)
 output["q1_native_wip"]=flow_native_report()
 super._write_json(filename,output)

static func flow_identity_errors(value: Dictionary) -> Array[String]:
 var errors: Array[String]=[]
 for field: String in FLOW_IDENTITY:
  if value.get(field,"")!=FLOW_IDENTITY[field]:errors.append(field+"_mismatch")
 for field: String in ["q1_exact_script","actor_exact_script","flow_bound","q3_bound","pigment_exact_resource","flow_material_ready"]:
  if value.get(field,false)!=true:errors.append(field+"_required")
 if value.get("actor_status","")!="import_structure_checked_not_visual_acceptance":errors.append("actor_import_status_required")
 if not value.get("actor_errors",null) is Array or not value.get("actor_errors",["missing"]).is_empty():errors.append("actor_import_errors")
 return errors

func _composed_warmup_identity() -> Dictionary:
 var actor_ok: bool=_actor_is_composed()
 var effect_ok: bool=is_instance_valid(q1_view) and q1_view.get_script()==FlowEffect
 var material_ok: bool=effect_ok and is_instance_valid(q1_view._belly_material) and is_instance_valid(q1_view._belly_material.shader) and q1_view._belly_material.shader.resource_path==FLOW_SHADER
 var value: Dictionary={"q1_exact_script":effect_ok,"actor_exact_script":actor_ok,
  "q1_script":q1_view.get_script().resource_path if effect_ok else "","q1_script_sha":FileAccess.get_sha256(FLOW_IDENTITY.q1_script),
  "q1_shader":q1_view._belly_material.shader.resource_path if material_ok else "","q1_shader_sha":FileAccess.get_sha256(FLOW_SHADER),
  "pigment_sha":FileAccess.get_sha256(FLOW_PIGMENT),"pigment_exact_resource":material_ok and q1_view._belly_material.get_shader_parameter("pigment")==q1_view._stroke_texture,
  "flow_material_ready":material_ok,"actor_script":hero_view.get_script().resource_path if actor_ok else "","actor_script_sha":FileAccess.get_sha256(FLOW_IDENTITY.actor_script),
  "visible_asset_sha":hero_view.proof.get("asset_sha256","") if actor_ok else "","flow_asset_sha":FileAccess.get_sha256(FlowActor.FLOW_ASSET),
  "flow_binding_sha":FileAccess.get_sha256(FlowActor.FLOW_BINDING),"flow_bound":actor_ok and hero_view.flow_ready,
  "q3_bound":actor_ok and hero_view.q3_bound,"actor_status":hero_view.proof.status if actor_ok else "missing","actor_errors":hero_view.proof.errors.duplicate() if actor_ok else ["wrong_actor"]}
 var errors: Array[String]=flow_identity_errors(value)
 return {"accepted":errors.is_empty(),"errors":errors,"evidence":value,"source_written":false,"drawn_warmup_accepted":false}

func _mainprep_environment() -> Dictionary:
 var result: Dictionary=super._mainprep_environment()
 result["flow_material_id"]=q1_view._belly_material.get_instance_id()
 result["flow_shader_id"]=q1_view._belly_material.shader.get_instance_id()
 result["flow_pigment_id"]=q1_view._belly_material.get_shader_parameter("pigment").get_instance_id()
 result["flow_asset_binding"]=FLOW_IDENTITY.flow_binding_sha
 return result

func _refresh(delta: float) -> void:
 if sim!=null and _actor_is_composed():
  ActorSeam.before_present(hero_view,sim);composed_before_present+=1
 elif sim!=null:composed_constructor_refresh_skips+=1
 if sim == null: return
 if shop_session != null and shop_session.ledger != null: shop_session.update_after_source_step()
 input_router.synchronize_preview()
 if initial_started and initial_controller != null: initial_controller.ensure_auto_hex()
 if is_instance_valid(stage) and stage.get_script() != RoomView:
  stage.free(); stage = RoomView.new(); add_child(stage)
 if is_instance_valid(q1_view) and q1_view.get_script() != FlowEffect:
  q1_view.free(); q1_view = FlowEffect.new(); add_child(q1_view); flow_effect_replacements+=1
 if is_instance_valid(hud) and hud.get_script() != SkillHud:
  var parent_canvas: Node = hud.get_parent(); hud.free(); hud = SkillHud.new(); parent_canvas.add_child(hud)
  hud.shop_requested.connect(_shop); hud.exit_requested.connect(func(): close_sample("visible_exit")); hud.diagnostics_requested.connect(_toggle_diagnostics)
 var full: Dictionary = sim.snapshot()
 var ink: Dictionary = sim.ink_presenter_snapshot()
 hero_view.set_received_view_input(ViewInput.capture(input_router,sim.hero.position,str(sim.ink_input.phase),_current_pointer_ground(),not sim.paused and sim.phase == "combat" and not sim.hero.dead))
 hero_view.set_presentation_context(_safe_presentation_context())
 if not sim.paused: hero_view.present(ink)
 var legacy_profile_started: int = -1
 if LegacyFrameCPU.active: legacy_profile_started = LegacyFrameCPU.begin("legacy_effects_present")
 q1_view.present(ink); basic_view.present(ink)
 var fresh: Array = q3_pending; q3_pending = []
 mountain_view.present(ink,fresh)
 aim_preview.present(input_router.preview(_current_pointer_ground()))
 _present_h02(ink)
 if legacy_profile_started >= 0: LegacyFrameCPU.end("legacy_effects_present", legacy_profile_started)
 var enemy_report: Dictionary = enemy_layer.present(sim,full,_safe_presentation_context())
 if enemy_report.get("status", "") != "ready": floor_error = str(enemy_report.get("reason","enemy_presentation_not_ready"))
 if mountain_view.get_diagnostics().get("status", "") == "HOLD": floor_error = "q3_presentation_not_ready"
 if not floor_error.is_empty() and not sim.paused: _pause(true,"presentation_fail_closed")
 stage.follow(full.hero.position,delta)
 stage.present_grounding(full.hero,[])
 stage.enemy_grounding.visible = false # Never misrepresent one enemy shadow as the roster.
 hud.present(full,ink,_brief()); hud.shop_open = shop_session != null and shop_session.panel_open; hud.shop_group.visible = false
 last_presented_full = sim.snapshot(); last_presented_ink = sim.ink_presenter_snapshot()
 if initial_controller != null and not sim.transaction_active:
  initial_controller.present_combat({"hp":sim.hero.hp,"hp_max":sim.hero.stats.max_hp,"stats":sim.hero.stats.duplicate(true),"phase":sim.phase,"room":sim.room_id})
 _refresh_session_controls(false); _refresh_local_text(); _refresh_h02_label()
 if sim!=null and is_instance_valid(hud):
  composed_q_projection=SelectedQHUD.apply_to(hud,sim.snapshot(),sim.ink_presenter_snapshot(),SelectedQProjection.capture_context(sim))

func _mainprep_geometry_failures(sample_name: String, geometry: Array) -> Array[String]:
 var errors: Array[String] = []
 var required_prefixes: Array[String] = ["SourcePathPreview"]
 var required_material_ids: Array = [q1_view._preview_under_material.get_instance_id(), q1_view._preview_material.get_instance_id()]
 if sample_name == "wave_contact":
  required_prefixes = ["LowWave_", "Contact_"]
  required_material_ids = [q1_view._belly_material.get_instance_id()]
  required_material_ids.append_array([q1_view._contact_black.get_instance_id(), q1_view._contact_wet.get_instance_id(), q1_view._contact_mineral.get_instance_id()])
 elif sample_name == "residue":
  required_prefixes = ["WeakRetiredInk_"]
  required_material_ids = [q1_view._belly_material.get_instance_id()]
 var drawn_material_ids: Dictionary = {}
 for prefix: String in required_prefixes:
  var found := false
  for item: Dictionary in geometry:
   if not str(item.node).begins_with(prefix) or item.surfaces.is_empty():
    continue
   found = true
   if not item.visible_in_tree or not item.same_main_viewport:
    errors.append(prefix + "_not_visible_in_main_viewport")
   var in_frustum := 0
   for surface: Dictionary in item.surfaces:
    drawn_material_ids[int(surface.material_id)] = true
    in_frustum += int(surface.in_frustum_vertices)
    if int(surface.vertices) <= 0 or int(surface.in_frustum_vertices) <= 0:
     errors.append(prefix + "_surface_empty_or_outside_camera")
    if prefix in ["LowWave_", "WeakRetiredInk_"] and (int(surface.vertices) == 0 or int(surface.uv) != int(surface.vertices)):
     errors.append(prefix + "_missing_effect05_full_width_UV")
   if in_frustum == 0:
    errors.append(prefix + "_outside_camera_frustum")
  if not found:
   errors.append(prefix + "_missing_surfaces")
 for material_id: int in required_material_ids:
  if not drawn_material_ids.has(material_id): errors.append("current_material_not_drawn_" + str(material_id))
 if drawn_material_ids.size() != required_material_ids.size(): errors.append("unexpected_material_coverage")
 return errors


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
  "actor_candidate": "Q1flow/fix02/parsefix01/b558f0", "effect_candidate": "effect05_native_alpha",
  "explicit_diagnostic_pause": _mainprep_explicit_pause,
  "startup_focus_lost": _mainprep_focus_lost, "normal_run": false,
  "scope": "Preparation seal only: exact Q1 flow actor and effect05 presenter in main viewport. First-construction pause and post-success resume are separate host lifecycle transitions. No ordinary Lv1, Boss, art or performance acceptance."}
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

