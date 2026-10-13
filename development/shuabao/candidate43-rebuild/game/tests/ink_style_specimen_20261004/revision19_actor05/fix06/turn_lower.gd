extends "res://tests/ink_style_specimen_20261004/revision19_actor05/fix04/lower_motion.gd"
## Small stationary-turn presentation candidate. These targets approximate the
## displayed stance; they do not reconstruct source physical contact history.
## Three .25/3-second steps and .06 m clearance require native visual review.
const TURN_SECONDS := 0.25
const TURN_RATE := TAU * 2.0
const TURN_CLEARANCE_M := 0.06
const TURN_STANCE_RADIUS_M := 0.35
const TURN_GROUND_TOLERANCE_M := 0.025
const TURN_START_MIN_RADIANS := 5.0 * PI / 180.0 # Visible-turn presentation deadzone, not numeric/key epsilon.
const TURN_RETARGET_TOLERANCE := PI / 180.0

var turn_active := false
var turn_blocked := ""
var turn_start := -1.0
var turn_start_yaw := 0.0
var turn_goal_yaw := 0.0
var turn_delta := 0.0
var turn_capture: Array[Transform3D] = []
var turn_capture_world := Transform3D.IDENTITY
var turn_stages: Array[Dictionary] = []
var turn_last_pose: Array[Transform3D] = []
var turn_last_world := Transform3D.IDENTITY
var turn_last_time := -1.0
var turn_last_report: Dictionary = {}
var turn_stop_capture_time := -1.0


func reset() -> void:
	super.reset()
	_clear_turn()
	turn_stop_capture_time = -1.0


func _clear_turn() -> void:
	turn_active = false
	turn_blocked = ""
	turn_start = -1.0
	turn_capture.clear()
	turn_stages.clear()
	turn_last_pose.clear()
	turn_last_report.clear()
	turn_last_time = -1.0


func apply(actor: Node3D, target: Array[Transform3D], idle: Array[Transform3D], walking: bool,
		now: float, phase: float, next_mode: String, dash_active: bool = false,
		transfer_source_at: float = -1.0) -> Dictionary:
	if walking or dash_active:
		_clear_turn()
		turn_stop_capture_time = -1.0
		return super.apply(actor, target, idle, walking, now, phase, next_mode, dash_active, transfer_source_at)
	var aim_requested: bool = actor.visual_aim_requested
	var desired_yaw: float = actor.desired_visual_yaw
	if turn_active:
		if aim_requested and absf(wrapf(desired_yaw - turn_goal_yaw, -PI, PI)) > TURN_RETARGET_TOLERANCE:
			turn_blocked = "retarget_requires_new_motion_or_reset"
		return _sample_turn(actor, target, now, phase)
	# The first stop sample belongs to fix04's exact previous-lower capture.
	if last_walking:
		turn_stop_capture_time = now
		return super.apply(actor, target, idle, walking, now, phase, next_mode, dash_active, transfer_source_at)
	# A just-completed turn must reproduce its endpoint on every same-time call.
	if turn_last_time == now and not turn_last_pose.is_empty():
		return _cached_turn_result(actor, target, true)
	# Authored idle may contain a small pelvis yaw. Do not repeatedly restart a
	# completed captured request merely because its zero-distance settle adds it.
	var completed_same_request: bool = bool(turn_last_report.get("finished", false)) and absf(wrapf(desired_yaw - turn_goal_yaw, -PI, PI)) <= TURN_RETARGET_TOLERANCE
	var previous: Array[Transform3D] = actor.last_rendered_pose
	if aim_requested and not completed_same_request and is_finite(desired_yaw) and previous.size() == target.size() and not previous.is_empty() and now != turn_stop_capture_time:
		var prior_yaw: float = _logical_yaw(actor, previous, actor.last_skeleton_transform.basis)
		if absf(wrapf(desired_yaw - prior_yaw, -PI, PI)) >= TURN_START_MIN_RADIANS:
			var began: float = minf(now, maxf(float(actor.last_time), transfer_source_at))
			if began < 0.0: began = now
			var admission: Dictionary = _admit_turn(actor, idle, began, desired_yaw)
			if admission.accepted:
				return _sample_turn(actor, target, now, phase)
			var inherited: Dictionary = super.apply(actor, target, idle, walking, now, phase, next_mode, dash_active, transfer_source_at)
			inherited.report["inherited_lower_status"] = inherited.report.get("status", "")
			inherited.report["status"] = "turn_HOLD"
			inherited.report["reason"] = admission.reason
			inherited.report["stationary_turn"] = admission
			return inherited
	return super.apply(actor, target, idle, walking, now, phase, next_mode, dash_active, transfer_source_at)


func _admit_turn(actor: Node3D, idle: Array[Transform3D], now: float, desired_yaw: float) -> Dictionary:
	var previous: Array[Transform3D] = actor.last_rendered_pose
	var previous_world: Transform3D = actor.last_skeleton_transform
	var captured: Dictionary = _foot_data(actor, previous, previous_world)
	var ground_y: float = actor.position.y + 0.14
	var stance: Dictionary = {}
	for side: String in SIDES:
		var point: Vector3 = captured.positions[side]
		var offset: Vector3 = point - actor.position
		offset.y = 0.0
		stance[side] = {"ankle_ground_error_m": absf(point.y - ground_y), "root_radius_m": offset.length()}
		if absf(point.y - ground_y) > TURN_GROUND_TOLERANCE_M or offset.length() > TURN_STANCE_RADIUS_M:
			return {"accepted": false, "status": "turn_HOLD", "reason": "compact_grounded_stance_required", "stance": stance, "radius_limit_m": TURN_STANCE_RADIUS_M, "ground_tolerance_m": TURN_GROUND_TOLERANCE_M}
	_clear_turn()
	turn_active = true
	turn_start = now
	turn_start_yaw = _logical_yaw(actor, previous, previous_world.basis)
	turn_goal_yaw = desired_yaw
	turn_delta = wrapf(desired_yaw - turn_start_yaw, -PI, PI)
	turn_capture = previous.duplicate()
	turn_capture_world = previous_world
	turn_last_pose = previous.duplicate()
	turn_last_world = previous_world
	var half: Dictionary = _idle_feet_at_yaw(actor, idle, turn_start_yaw + turn_delta * 0.5, ground_y)
	var final_feet: Dictionary = _idle_feet_at_yaw(actor, idle, turn_goal_yaw, ground_y)
	var first: String = "L" if turn_delta >= 0.0 else "R"
	var other: String = "R" if first == "L" else "L"
	var points: Dictionary = captured.positions.duplicate(true)
	var bases: Dictionary = captured.orientations.duplicate(true)
	_append_turn_stage(first, points, bases, half.positions[first], half.orientations[first], ground_y)
	_append_turn_stage(other, points, bases, final_feet.positions[other], final_feet.orientations[other], ground_y)
	_append_turn_stage(first, points, bases, final_feet.positions[first], final_feet.orientations[first], ground_y)
	settle.cancel()
	settling = false
	settle_blocked = false
	anchors.clear()
	anchor_orientations.clear()
	releases.clear()
	last_walking = false
	actor.locomotion_mode = "idle"
	return {"accepted": true, "status": "turn_admitted", "stance": stance}


func _idle_feet_at_yaw(actor: Node3D, idle: Array[Transform3D], yaw: float, ground_y: float) -> Dictionary:
	var pose: Array[Transform3D] = idle.duplicate()
	var actual_yaw: float = _logical_yaw(actor, pose, actor.skeleton.global_basis)
	actor._layer_direction(pose, wrapf(yaw - actual_yaw, -PI, PI))
	var feet: Dictionary = _foot_data(actor, pose, actor.skeleton.global_transform)
	for side: String in SIDES:
		var point: Vector3 = feet.positions[side]
		point.y = ground_y
		feet.positions[side] = point
	return feet


func _append_turn_stage(side: String, points: Dictionary, bases: Dictionary, destination: Vector3, orientation: Basis, ground_y: float) -> void:
	var stage: Dictionary = {"moving_side": side, "support_side": "R" if side == "L" else "L", "before": points.duplicate(true), "bases_before": bases.duplicate(true), "ground_y": ground_y}
	points[side] = destination
	bases[side] = orientation
	stage["after"] = points.duplicate(true)
	stage["bases_after"] = bases.duplicate(true)
	turn_stages.append(stage)


func _sample_turn(actor: Node3D, target: Array[Transform3D], now: float, phase: float) -> Dictionary:
	if not turn_blocked.is_empty():
		var held: Dictionary = _cached_turn_result(actor, target, now == turn_last_time)
		held.report["status"] = "turn_HOLD"
		held.report["reason"] = turn_blocked
		held.report["requested_source_age"] = maxf(0.0, now - turn_start)
		return held
	if now == turn_last_time:
		return _cached_turn_result(actor, target, true)
	var age: float = maxf(0.0, now - turn_start)
	var angle: float = signf(turn_delta) * minf(absf(turn_delta), TURN_RATE * age)
	var stage_index: int = mini(2, int(age / (TURN_SECONDS / 3.0)))
	var stage: Dictionary = turn_stages[stage_index]
	var fraction: float = clampf((age - float(stage_index) * TURN_SECONDS / 3.0) / (TURN_SECONDS / 3.0), 0.0, 1.0)
	var smooth: float = fraction * fraction * (3.0 - 2.0 * fraction)
	var finished: bool = age >= TURN_SECONDS
	var targets: Dictionary = stage.before.duplicate(true)
	var orientations: Dictionary = stage.bases_before.duplicate(true)
	var side: String = stage.moving_side
	# Exact endpoints avoid slerp(1) versus raw-basis repeat discrepancies.
	if fraction >= 1.0:
		targets = stage.after.duplicate(true)
		orientations = stage.bases_after.duplicate(true)
	elif fraction > 0.0:
		var first: Vector3 = stage.before[side]
		var last: Vector3 = stage.after[side]
		var point: Vector3 = first.lerp(last, smooth)
		var clearance: float = maxf(0.0, TURN_CLEARANCE_M - maxf(0.0, maxf(first.y, last.y) - float(stage.ground_y)))
		point.y += clearance * 16.0 * fraction * fraction * (1.0 - fraction) * (1.0 - fraction)
		targets[side] = point
		var old_basis: Basis = stage.bases_before[side]
		orientations[side] = old_basis.slerp(stage.bases_after[side], smooth)
	var chest: Basis = actor._global_pose(target, actor.chest_index).basis
	if age == 0.0:
		# Admission is the exact previous applied lower pose, not a new solve of
		# that pose. A fresh reach-margin solve could add a visible pelvis drop.
		var captured_pose: Array[Transform3D] = _reuse_lower(actor, target)
		var capture_report: Dictionary = {"status": "turn_capture_exact", "walking": false, "phase_s": phase, "source_age": 0.0, "duration_s": TURN_SECONDS, "stage": 0, "stage_fraction": 0.0, "moving_foot": side, "support_foot": stage.support_side, "targets": targets, "captured_pelvis_yaw": turn_start_yaw, "target_pelvis_yaw": turn_goal_yaw, "actual_pelvis_yaw": _logical_yaw(actor, captured_pose, actor.skeleton.global_basis), "actual_turn_angle": 0.0, "pelvis_yaw_rate_limit": TURN_RATE, "solver": {"ran": false, "reason": "exact_prior_applied_pose_capture"}, "stepped_turn_implemented": true, "foot_contact_accepted": false, "natural_settle_accepted": false, "native_turn_review_accepted": false, "target_scope": "presentation approximation; no historical physical reconstruction", "retarget_policy": "one captured target; changed aim holds until new motion/reset", "repeated_source_time": false, "finished": false}
		turn_last_pose = captured_pose.duplicate()
		turn_last_world = actor.skeleton.global_transform
		turn_last_time = now
		turn_last_report = capture_report.duplicate(true)
		return _result(captured_pose, capture_report)
	var base: Array[Transform3D] = _copy_lower(actor, target, turn_capture, turn_capture_world.basis, 0.0)
	var captured_pelvis: Basis = turn_capture_world.basis * actor._global_pose(turn_capture, actor.pelvis_index).basis
	actor._set_global_basis(base, actor.pelvis_index, actor.skeleton.global_basis.inverse() * Basis(Vector3.UP, angle) * captured_pelvis)
	_restore_chest(actor, base, chest)
	var solved: Dictionary = FeetPose.apply(actor, base, targets, orientations, actor.leg_lengths, 0.22)
	var report: Dictionary = {"status": "turn_targets_applied" if solved.accepted else "turn_HOLD", "walking": false, "phase_s": phase, "source_age": age, "duration_s": TURN_SECONDS, "stage": stage_index, "stage_fraction": fraction, "moving_foot": "" if finished else side, "support_foot": "both" if finished else stage.support_side, "targets": targets, "captured_pelvis_yaw": turn_start_yaw, "target_pelvis_yaw": turn_goal_yaw, "applied_turn_angle": angle, "pelvis_yaw_rate_limit": TURN_RATE, "solver": _solver_report(solved), "stepped_turn_implemented": true, "foot_contact_accepted": false, "natural_settle_accepted": false, "native_turn_review_accepted": false, "target_scope": "presentation approximation; no historical physical reconstruction", "retarget_policy": "one captured target; changed aim holds until new motion/reset", "repeated_source_time": false, "finished": finished}
	if not solved.accepted:
		turn_blocked = "turn_two_foot_solve_rejected_requires_new_motion_or_reset"
		report["reason"] = turn_blocked
		var held: Array[Transform3D] = _reuse_lower(actor, target)
		report["actual_pelvis_yaw"] = _logical_yaw(actor, held, actor.skeleton.global_basis)
		report["actual_turn_angle"] = wrapf(float(report.actual_pelvis_yaw) - turn_start_yaw, -PI, PI)
		report["requested_turn_angle"] = angle
		report.erase("applied_turn_angle")
		turn_last_report = report.duplicate(true)
		return _result(held, report)
	var pose: Array[Transform3D] = solved.poses
	# Basis only: retain pelvis-drop/chest-origin changes made by the solver.
	_restore_chest(actor, pose, chest)
	report["actual_pelvis_yaw"] = _logical_yaw(actor, pose, actor.skeleton.global_basis)
	report["actual_turn_angle"] = wrapf(float(report.actual_pelvis_yaw) - turn_start_yaw, -PI, PI)
	turn_last_pose = pose.duplicate()
	turn_last_world = actor.skeleton.global_transform
	turn_last_time = now
	turn_last_report = report.duplicate(true)
	last_targets = targets.duplicate(true)
	if finished:
		_complete_turn(actor, pose, now)
	return _result(pose, report)


func _reuse_lower(actor: Node3D, target: Array[Transform3D]) -> Array[Transform3D]:
	if turn_last_world == actor.skeleton.global_transform:
		var result: Array[Transform3D] = target.duplicate()
		var chest: Basis = actor._global_pose(target, actor.chest_index).basis
		for index in range(result.size()):
			if str(actor.skeleton.get_bone_name(index)) in actor.LOWER05:
				result[index] = turn_last_pose[index]
		_restore_chest(actor, result, chest)
		return result
	return _copy_lower(actor, target, turn_last_pose, turn_last_world.basis, 0.0)


func _cached_turn_result(actor: Node3D, target: Array[Transform3D], repeated: bool) -> Dictionary:
	var pose: Array[Transform3D] = _reuse_lower(actor, target)
	var report: Dictionary = turn_last_report.duplicate(true)
	report["repeated_source_time"] = repeated
	report["actual_pelvis_yaw"] = _logical_yaw(actor, pose, actor.skeleton.global_basis)
	return _result(pose, report)


func _complete_turn(actor: Node3D, pose: Array[Transform3D], now: float) -> void:
	var actual: Dictionary = _foot_data(actor, pose, actor.skeleton.global_transform)
	stop_from = pose.duplicate()
	stop_basis = actor.skeleton.global_basis
	stop_yaw = _logical_yaw(actor, pose, stop_basis)
	stop_orientations = actual.orientations.duplicate(true)
	idle_orientations = actual.orientations.duplicate(true)
	stop_neutral = actual.positions.duplicate(true)
	last_targets = actual.positions.duplicate(true)
	var admission: Dictionary = settle.begin(now, actual.positions, actual.positions, "L")
	settling = true
	settle_blocked = not admission.accepted
	last_walking = false
	actor.locomotion_mode = "idle"
	turn_active = false
