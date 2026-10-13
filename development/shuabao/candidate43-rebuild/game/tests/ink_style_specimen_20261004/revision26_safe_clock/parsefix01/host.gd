extends "res://tests/ink_style_specimen_20261004/revision26_safe_clock/parsefix01/room_host.gd"
## First-construction loading gate only. Preparation never steps or requests the
## source, or emits audio. Existing startup pause/resume transitions are separate.
const FIXTURES := "res://tests/ink_style_specimen_20261004/revision23_loading/presentation_fixtures.json"
const FIXTURES_SHA := "04c040efe991dc0a3ce30daf6ee3546ca9f7078d82d79a744cac8a57620d6166"
const PREPARE_WALL_LIMIT_USEC := 10000000
const STARTUP_READY_WALL_LIMIT_USEC := 10000000
const DRAWS_PER_SAMPLE := 2
const PROCESS_LIMIT_PER_SAMPLE := 30
var _mainprep_required := true
var _mainprep_pending := false
var _mainprep_attempted := false
var _mainprep_stable_draws := 0
var _mainprep_last_size := Vector2.ZERO
var _mainprep_started_usec := 0
var _mainprep_suppressed_process_calls := 0
var _mainprep_layer: CanvasLayer
var _mainprep_mask: ColorRect
var _mainprep_label: Label
var _mainprep_receipt: Dictionary = {"status": "waiting_for_stable_startup_draws", "performance_passed": false}
var _mainprep_explicit_pause := false
var _mainprep_focus_lost := false
var _mainprep_blocked_events := 0
var _mainprep_held_keys: Dictionary = {}
var _mainprep_held_buttons: Dictionary = {}
var _mainprep_startup_transition: Dictionary = {}

static func startup_policy(explicit_start_paused: bool) -> Dictionary:
	return {"initial_pause": true, "auto_prepare": true,
		"resume_after_ready": not explicit_start_paused,
		"diagnostic_pause_after_ready": explicit_start_paused}

static func startup_release_allowed(preparation_succeeded: bool,
		explicit_start_paused: bool, startup_focus_lost: bool) -> bool:
	return preparation_succeeded and not explicit_start_paused and not startup_focus_lost

func _ready() -> void:
	# Configures ONLY this object's first construction. The ancestor performs its
	# existing startup pause after the real idle-zero sample and before processing.
	_mainprep_explicit_pause = "--ink-start-paused" in OS.get_cmdline_user_args()
	start_paused = bool(startup_policy(_mainprep_explicit_pause).initial_pause)
	super._ready()
	_mainprep_layer = CanvasLayer.new()
	_mainprep_layer.name = "FirstInputVisualPreparationMask"
	_mainprep_layer.layer = 1024
	add_child(_mainprep_layer)
	_mainprep_mask = ColorRect.new()
	_mainprep_mask.color = Color(0.025, 0.035, 0.040, 1.0)
	_mainprep_mask.mouse_filter = Control.MOUSE_FILTER_STOP
	_mainprep_layer.add_child(_mainprep_mask)
	_mainprep_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mainprep_label = Label.new()
	_mainprep_label.position = Vector2(32, 36)
	_mainprep_label.text = "首次显示资源准备中，请稍候；F10 退出"
	_mainprep_mask.add_child(_mainprep_label)
	_mainprep_last_size = get_viewport().get_visible_rect().size
	_write_json("main_viewport_warmup.json", _mainprep_receipt)

func _process(delta: float) -> void:
	if _mainprep_required:
		# Keep only the host's wall-budget observation current. Crucially, do NOT
		# call inherited _process: it calls sim.step even when already paused and
		# would overwrite the temporary fixture via its ordinary _refresh.
		last_process_wall_usec = Time.get_ticks_usec()
		_mainprep_suppressed_process_calls += 1
		if not _mainprep_attempted and Time.get_ticks_usec() - start_ticks > STARTUP_READY_WALL_LIMIT_USEC:
			_mainprep_fail_startup("stable_startup_draws_timeout")
		# Retain the ancestor's independent hard wall exit even while fail-closed.
		if not finished and float(Time.get_ticks_usec() - start_ticks) / 1000000.0 >= finite_seconds:
			close_sample("independent_hard_wall_deadline_during_loading")
		return
	super._process(delta)

func _drawn() -> void:
	super._drawn()
	if finished or not _mainprep_required or _mainprep_pending:
		return
	var current_size := get_viewport().get_visible_rect().size
	if current_size == _mainprep_last_size:
		_mainprep_stable_draws += 1
	else:
		_mainprep_last_size = current_size
		_mainprep_stable_draws = 0
	if not _mainprep_attempted and _mainprep_stable_draws >= 3:
		_prepare_main_viewport.call_deferred()

func _input(event: InputEvent) -> void:
	if _mainprep_required:
		if event is InputEventKey and event.pressed and not event.echo:
			var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if key == KEY_F10:
				super._input(event)
				return
		_mainprep_blocked_events += 1
		_mainprep_track_held(event)
		get_viewport().set_input_as_handled()
		return
	# Inputs pressed beneath the mask are not queued for combat. Drain their
	# matching release (and key echo) before admitting a genuinely new press.
	if _mainprep_drain_held(event):
		get_viewport().set_input_as_handled()
		return
	super._input(event)

func _mainprep_track_held(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if event.pressed: _mainprep_held_keys[key] = true
		else: _mainprep_held_keys.erase(key)
	elif event is InputEventMouseButton:
		if event.pressed: _mainprep_held_buttons[event.button_index] = true
		else: _mainprep_held_buttons.erase(event.button_index)

func _mainprep_drain_held(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if _mainprep_held_keys.has(key):
			if not event.pressed: _mainprep_held_keys.erase(key)
			return true
	elif event is InputEventMouseButton and _mainprep_held_buttons.has(event.button_index):
		if not event.pressed: _mainprep_held_buttons.erase(event.button_index)
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if _mainprep_required:
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func _focus_lost() -> void:
	if _mainprep_required: _mainprep_focus_lost = true
	super._focus_lost()

func _mainprep_fail_startup(reason: String) -> void:
	_mainprep_attempted = true
	_mainprep_label.text = "首次显示准备未就绪，玩法保持关闭；F10 退出"
	_mainprep_receipt = {"status": "HOLD", "failures": [reason],
		"input_blocked": true, "explicit_diagnostic_pause": _mainprep_explicit_pause,
		"normal_run": false, "performance_passed": false}
	_write_json("main_viewport_warmup.json", _mainprep_receipt)

func _mainprep_seal() -> Dictionary:
	return {"full": var_to_bytes(sim.snapshot()), "ink": var_to_bytes(sim.ink_presenter_snapshot()),
		"events": var_to_bytes(events), "rng_state": sim.rng.state,
		"audio_commands": var_to_bytes(audio_output.commands),
		"audio_command_count": audio_output.commands.size(),
		"audio_dropped": var_to_bytes(audio_output.dropped),
		"audio_dropped_count": audio_output.dropped.size(), "paused": sim.paused,
		"audio_nonzero_pcm_frames": audio_output.pcm_nonzero_frames,
		"audio_players_playing": audio_output.players.map(func(player: AudioStreamPlayer): return player.playing),
		"input_router_serial": input_router._serial,
		"input_router_keys": var_to_bytes(input_router._keys),
		"input_router_gesture": input_router._gesture_id,
		"input_router_left_physical": input_router._left_physical}

func _mainprep_compare(before: Dictionary, after: Dictionary) -> Array[String]:
	var differences: Array[String] = []
	for key: String in before:
		if before[key] != after[key]:
			differences.append(key)
	return differences

func _mainprep_seal_report(seal: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in seal:
		if seal[key] is PackedByteArray:
			var context := HashingContext.new()
			context.start(HashingContext.HASH_SHA256)
			context.update(seal[key])
			result[key + "_sha256"] = context.finish().hex_encode()
		else:
			result[key] = str(seal[key]) if key == "rng_state" else seal[key]
	return result

func _mainprep_environment() -> Dictionary:
	var world: World3D = get_viewport().find_world_3d()
	return {"viewport_id": get_viewport().get_instance_id(),
		"presenter_viewport_id": q1_view.get_viewport().get_instance_id(),
		"world_id": world.get_instance_id(), "camera_id": stage.camera.get_instance_id(),
		"camera_transform": var_to_str(stage.camera.global_transform), "camera_size": stage.camera.size,
		"environment_id": world.environment.get_instance_id() if world.environment != null else -1,
		"viewport_size": get_viewport().get_visible_rect().size,
		"presenter_id": q1_view.get_instance_id(),
		"presenter_script": q1_view.get_script().resource_path,
		"actor_id": hero_view.get_instance_id(), "actor_script": hero_view.get_script().resource_path,
		"main_material_ids": q1_view._materials.map(func(material: Material): return material.get_instance_id()),
		"preview_material_id": q1_view._preview_material.get_instance_id(),
		"preview_under_material_id": q1_view._preview_under_material.get_instance_id(),
		"contact_black_id": q1_view._contact_black.get_instance_id(),
		"contact_wet_id": q1_view._contact_wet.get_instance_id(),
		"contact_mineral_id": q1_view._contact_mineral.get_instance_id(),
		"paint_texture_id": q1_view._paint_texture.get_instance_id(),
		"stroke_texture_id": q1_view._stroke_texture.get_instance_id()}

func _mainprep_mesh_readback() -> Array:
	var result: Array = []
	for child in q1_view.get_children():
		if not child is MeshInstance3D or not child.visible:
			continue
		var mesh: ArrayMesh = child.mesh
		var surfaces: Array = []
		for surface in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var in_frustum := 0
			for vertex: Vector3 in vertices:
				if stage.camera.is_position_in_frustum(child.to_global(vertex)):
					in_frustum += 1
			surfaces.append({"vertices": vertices.size(), "in_frustum_vertices": in_frustum,
				"uv": arrays[Mesh.ARRAY_TEX_UV].size() if arrays[Mesh.ARRAY_TEX_UV] != null else 0,
				"uv2": arrays[Mesh.ARRAY_TEX_UV2].size() if arrays[Mesh.ARRAY_TEX_UV2] != null else 0,
				"material_id": mesh.surface_get_material(surface).get_instance_id()})
		result.append({"node": str(child.name), "visible_in_tree": child.is_visible_in_tree(),
			"same_main_viewport": child.get_viewport() == get_viewport(), "surfaces": surfaces})
	return result

func _mainprep_wait_draws() -> bool:
	var before_draws := draw_count
	for iteration in range(PROCESS_LIMIT_PER_SAMPLE):
		await get_tree().process_frame
		if finished or Time.get_ticks_usec() - _mainprep_started_usec > PREPARE_WALL_LIMIT_USEC:
			return false
		if draw_count - before_draws >= DRAWS_PER_SAMPLE:
			return true
	return false

func _mainprep_geometry_failures(sample_name: String, geometry: Array) -> Array[String]:
	var errors: Array[String] = []
	var required_prefixes: Array[String] = ["SourcePathPreview"]
	var required_material_ids: Array = [q1_view._preview_under_material.get_instance_id(), q1_view._preview_material.get_instance_id()]
	if sample_name == "wave_contact":
		required_prefixes = ["LowWave_", "Contact_"]
		required_material_ids = q1_view._materials.map(func(material: Material): return material.get_instance_id())
		required_material_ids.append_array([q1_view._contact_black.get_instance_id(), q1_view._contact_wet.get_instance_id(), q1_view._contact_mineral.get_instance_id()])
	elif sample_name == "residue":
		required_prefixes = ["WeakRetiredInk_"]
		required_material_ids = [q1_view._materials[0].get_instance_id()]
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
				if prefix in ["LowWave_", "WeakRetiredInk_"] and (int(surface.vertices) == 0 or int(surface.uv2) != int(surface.vertices)):
					errors.append(prefix + "_missing_Q07_UV2")
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
	if q1_view.get_script() != BrushWave or hero_view.get_script().resource_path != "res://tests/ink_style_specimen_20261004/revision19_actor05/fix07/hero_view.gd":
		_mainprep_fail_startup("current_Q07_actorfix07_identity_mismatch")
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
		"actor_candidate": "candidate05/revision19fix07", "effect_candidate": "revision07",
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

func save_evidence(reason: String) -> void:
	if _mainprep_pending:
		_mainprep_receipt["status"] = "interrupted_during_preparation"
		_mainprep_receipt["close_reason"] = reason
	_mainprep_receipt["blocked_input_events"] = _mainprep_blocked_events
	_write_json("main_viewport_warmup.json", _mainprep_receipt)
	super.save_evidence(reason)
