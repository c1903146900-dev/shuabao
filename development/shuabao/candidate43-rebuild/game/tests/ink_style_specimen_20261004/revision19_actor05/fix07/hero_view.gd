extends "res://tests/ink_style_specimen_20261004/revision19_actor05/fix06/hero_view.gd"
## Combat delegates to frozen fix06. Safe movement has its own explicit clock.
var presentation_context: Dictionary = {}
var _safe_active7 := false
var _safe_signature7: Dictionary = {}
var _safe_instance7 := -1
var _safe_source_anchor7 := 0.0
var _safe_elapsed_origin7 := 0.0
var _safe_last_source7 := -1.0
var _safe_last_pose_time7 := -1.0
var _safe_entry_pose7: Array[Transform3D] = []
var _safe_entry_chest7 := Basis.IDENTITY
var _safe_entry_time7 := 0.0
var _context_scope7: Dictionary = {}
var _context_instance7 := -1
var _context_last_elapsed7 := 0.0
var _context_previous_elapsed7 := 0.0

func set_presentation_context(context: Dictionary) -> void:
	presentation_context = context.duplicate(true)

func _reset_instance_view7() -> void:
	# All fields below belong to this presentation object; imported resources stay.
	lower_motion.reset(); gait_time = 0.0; gait_cursor = 0.0
	last_position = Vector3.INF; last_time = -1.0; previous_source_walking = false
	last_move_intent = Vector3.ZERO; last_dash_left = 0.0
	last_rendered_pose.clear(); blend_from_pose.clear(); previous_upper_pose.clear()
	event_action = ""; event_at = -1.0; event_identity = ""
	transition_key = ""; transition_source_at = 0.0; last_upper_end = -1.0; cancel_at = -1.0
	last_signature5.clear(); stop_chest_started5 = -1.0; upper_from_world_valid5 = false
	_safe_active7 = false; _safe_signature7.clear(); _safe_last_pose_time7 = -1.0
	has_motion_scope = false

func present(ink: Dictionary) -> void:
	var mode: String = str(presentation_context.get("phase", ""))
	var matching: bool = presentation_context.get("schema", "") == "safe-locomotion-presentation-1" and presentation_context.get("scope", {}) == ink.get("scope", {})
	var next_instance: int = int(presentation_context.get("instance_id", -1))
	if matching and _safe_instance7 >= 0 and next_instance != _safe_instance7:
		_reset_instance_view7()
	if matching:
		var context_elapsed: float = float(presentation_context.get("safe_elapsed", 0.0))
		_context_previous_elapsed7 = _context_last_elapsed7 if _context_instance7 == next_instance and _context_scope7 == ink.get("scope", {}) else context_elapsed
		_context_instance7 = next_instance; _context_scope7 = ink.get("scope", {}).duplicate(true)
		_context_last_elapsed7 = context_elapsed; _safe_instance7 = next_instance
	if matching and mode in ["preparation", "victory"]:
		_present_safe7(ink)
		return
	if _safe_active7:
		# Do not subtract safe presentation seconds from a combat source timestamp.
		last_time = _safe_last_source7
		lower_motion.reset(); stop_chest_started5 = -1.0; last_signature5.clear()
		_safe_active7 = false; _safe_signature7.clear()
	super.present(ink)

func _presentation_names7(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		var names: Dictionary = {"source_time": "locomotion_time", "source_delta": "locomotion_delta", "source_age": "locomotion_age", "repeated_source_time": "repeated_locomotion_time"}
		for key: Variant in value: out[names.get(key, key)] = _presentation_names7(value[key])
		return out
	if value is Array:
		var out: Array = []
		for entry: Variant in value: out.append(_presentation_names7(entry))
		return out
	return value

func _present_safe7(ink: Dictionary) -> void:
	if proof.status == "HOLD" or player == null or skeleton == null: return
	var source_now: float = float(ink.get("source_time", 0.0))
	var elapsed: float = float(presentation_context.get("safe_elapsed", -1.0))
	if not is_finite(elapsed) or elapsed < 0.0:
		push_error("invalid safe presentation clock"); return
	if not bool(presentation_context.get("eligible", false)):
		# A first static source sample is still required before loading/first pause.
		if sample_report.is_empty(): super.present(ink)
		if not sample_report.is_empty():
			sample_report = sample_report.duplicate(true)
			sample_report["presentation_clock"] = presentation_context.merged({"frozen": true, "locomotion_delta": 0.0})
		return
	var old_diagnostics: int = clock_diagnostics.size()
	# The inherited rollback guard always sees raw source time, never pose time.
	if _safe_active7: last_time = _safe_last_source7
	_prepare_source_clock(ink)
	if old_diagnostics != clock_diagnostics.size():
		_safe_active7 = false; _safe_signature7.clear(); _safe_last_pose_time7 = -1.0
	if not _safe_active7:
		_safe_active7 = true; _safe_source_anchor7 = source_now; _safe_elapsed_origin7 = _context_previous_elapsed7
		_safe_last_source7 = last_time
		_safe_last_pose_time7 = last_time
		_safe_entry_time7 = source_now
		_safe_entry_pose7 = last_rendered_pose.duplicate()
		if not _safe_entry_pose7.is_empty():
			_safe_entry_chest7 = last_skeleton_transform.basis * _global_pose(_safe_entry_pose7, chest_index).basis
		# Encounter-end retirement is visual only; no action ages are advanced.
		event_action = ""; event_at = -1.0; event_identity = ""; active_upper = ""
		transition_key = ""; blend_from_pose.clear(); previous_upper_weight = 0.0
		last_signature5.clear()
	var now: float = _safe_source_anchor7 + elapsed - _safe_elapsed_origin7
	if _safe_last_pose_time7 >= 0.0 and now < _safe_last_pose_time7:
		push_error("safe presentation clock regressed without scope reset"); return
	last_time = _safe_last_pose_time7
	var signature: Dictionary = {"clock": presentation_context, "source": ink, "event_serial": received_event_serial}
	if signature == _safe_signature7 and not last_rendered_pose.is_empty():
		sample_report = sample_report.duplicate(true)
		sample_report["pose_cache_reused"] = true; sample_report["source_delta"] = 0.0
		sample_report["actual_displacement"] = 0.0; sample_report["repeated_source_time"] = true
		sample_report["presentation_clock"] = presentation_context.merged({"locomotion_time": now, "locomotion_delta": 0.0, "repeated_locomotion_time": true, "frozen": false})
		sample_report.direction_plan.root_turn.applied_radians = 0.0
		sample_report.direction_plan.root_turn.locomotion_delta = 0.0
		sample_report.direction_layer.chest_constraints.locomotion_delta = 0.0
		sample_report.direction_layer.chest_constraints.yaw_rate.applied_radians = 0.0
		sample_report.direction_layer.chest_constraints.yaw_rate.locomotion_delta = 0.0
		return
	var hero: Dictionary = ink.get("hero", {})
	var at: Vector3 = hero.get("position", Vector3.ZERO)
	var displacement: Vector3 = at - last_position if last_position.is_finite() else Vector3.ZERO
	displacement.y = 0.0
	var distance: float = displacement.length()
	var dt: float = maxf(0.0, now - last_time) if last_time >= 0.0 else 0.0
	var repeated: bool = last_time >= 0.0 and now == last_time
	var intent: Vector3 = hero.get("move_intent", Vector3.ZERO)
	var stop_input: bool = repeated and last_move_intent != Vector3.ZERO and intent == Vector3.ZERO
	var was_walking: bool = previous_source_walking
	var walking: bool = previous_source_walking if repeated else distance > .0001 and dt > 0.0
	if stop_input: walking = false
	if not repeated or stop_input: previous_source_walking = walking
	if walking and dt > 0.0: move_heading = displacement.normalized()
	elif last_time < 0.0: move_heading = hero.get("facing", Vector3.BACK)
	var has_previous: bool = not last_rendered_pose.is_empty()
	var previous_chest: Basis = last_skeleton_transform.basis * _global_pose(last_rendered_pose, chest_index).basis if has_previous else Basis.IDENTITY
	position = at
	desired_visual_yaw = atan2(move_heading.x, move_heading.z) if walking or last_time < 0.0 else last_visual_yaw
	visual_aim_requested = false
	var turn: Dictionary = Heading5.advance(last_visual_yaw, desired_visual_yaw, dt) if last_time >= 0.0 else {"yaw": desired_visual_yaw, "target_yaw": desired_visual_yaw, "applied_radians": 0.0, "source_delta": 0.0, "rate_limited": false}
	rotation.y = float(turn.yaw)
	var choice: Dictionary = Phase.weights(Basis(Vector3.UP, -rotation.y) * move_heading)
	var weights: Dictionary = choice.get("weights", {"walk": 1.0})
	var dominant: String = "walk"; var greatest: float = -1.0
	for clip: String in weights:
		if float(weights[clip]) > greatest: dominant = clip; greatest = float(weights[clip])
	if walking: stop_chest_started5 = -1.0
	elif was_walking and has_previous: stop_chest_started5 = now; stop_chest_from_world5 = previous_chest
	if walking and dt > 0.0:
		gait_time += distance / AUTHORED_GAIT_REFERENCE_MPS
		gait_cursor += distance / AUTHORED_GAIT_REFERENCE_MPS
	var phase: float = fposmod(gait_time, float(directional_contract.cycle_seconds))
	var base: String = "walk" if walking else "idle"
	var window: Dictionary = key_windows[base]
	var base_time: float = float(window.first) + (phase if walking else fposmod(now, float(window.span)))
	var pose: Array[Transform3D] = _sample_directional_base(phase, weights) if walking else _sample("idle", base_time)
	if not walking: consumed_direction_samples.clear()
	var retire_alpha: float = clampf((now - _safe_entry_time7) / .08, 0.0, 1.0)
	if _safe_entry_pose7.size() == pose.size() and retire_alpha < 1.0:
		var prior: Array[Transform3D] = pose.duplicate()
		for index in range(pose.size()):
			if str(skeleton.get_bone_name(index)) in UPPER: prior[index] = _safe_entry_pose7[index]
		_set_global_basis(prior, chest_index, skeleton.global_basis.inverse() * _safe_entry_chest7)
		for index in range(pose.size()):
			if str(skeleton.get_bone_name(index)) in UPPER: pose[index] = prior[index].interpolate_with(pose[index], retire_alpha)
	var idle: Array[Transform3D] = _sample("idle", float(key_windows.idle.first))
	var lower: Dictionary = lower_motion.apply(self, pose, idle, walking, now, phase, "move:" + dominant, false, last_time)
	pose = lower.poses
	var chest: Dictionary = _chest_finish5(pose, previous_chest, has_previous, now, dt, walking, false, move_heading)
	pose = chest.poses
	for index in range(pose.size()): skeleton.set_bone_pose(index, pose[index])
	last_rendered_pose = pose.duplicate(); last_skeleton_basis = skeleton.global_basis; last_skeleton_transform = skeleton.global_transform
	var source_dt: float = maxf(0.0, source_now - _safe_last_source7) if _safe_last_source7 >= 0.0 else 0.0
	_safe_last_source7 = source_now; _safe_last_pose_time7 = now; last_time = now
	last_position = at; last_visual_yaw = rotation.y; last_move_intent = intent; last_dash_left = 0.0
	presented_event_serial = received_event_serial; _safe_signature7 = signature.duplicate(true)
	sample_report = {"motion_revision": "revision19_actor05_fix07_safe_clock", "base": base, "base_time": base_time,
		"base_key_first": window.first, "base_key_span": window.span, "gait_elapsed_absolute": gait_time, "gait_cursor_signed": gait_cursor,
		"source_time": source_now, "source_delta": source_dt, "repeated_source_time": source_dt == 0.0,
		"actual_displacement": distance, "upper": "", "upper_source_age": 0.0, "weight": 0.0,
		"safe_upper_retirement_alpha": retire_alpha, "upper_retirement_is_source_action_progress": false,
		"presentation_clock": presentation_context.merged({"locomotion_time": now, "locomotion_delta": dt, "repeated_locomotion_time": repeated, "frozen": false}),
		"direction_plan": {"root_yaw": desired_visual_yaw, "visual_root_yaw": rotation.y, "movement_direction": move_heading, "aim_direction": move_heading,
			"direction_weights": weights, "dominant_clip": dominant, "diagonal_unverified": choice.get("diagonal", false), "root_turn": _presentation_names7(turn)},
		"direction_layer": {"chest_constraints": _presentation_names7(chest.report)},
		"lower_transition": _presentation_names7(lower.report), "pose_cache_reused": false,
		"same_time_stop_input": stop_input, "source_motion_modified": false, "sampled_bones": bone_sample_evidence(),
		"received_view_input": received_view_input.duplicate(true), "received_event_serial": received_event_serial,
		"actor_asset_sha256": MODEL_SHA, "boundary_authority_sha256": BOUNDARIES05_SHA,
		"scope": "safe movement presentation; no new source action, diagonal or native art acceptance"}
