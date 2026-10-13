extends RefCounted
## Transactional presentation-pose IK. Inputs are actual imported LOCAL poses;
## targets, orientation bases and the previous-knee pole are in WORLD space.
## Nothing writes the actor/root, Skeleton3D, simulation, or the caller's array.
## Only an accepted result contains `poses`; the caller decides when to commit.

const Leg = preload("res://tests/ink_style_specimen_20261004/directional_interface05/world_leg_targets.gd")
const SIDES := ["L", "R"]
const REACH_MARGIN_M := 0.0001
const DROP_INTERIOR_M := 0.001
const POSITION_TOLERANCE_M := 0.0001
const LENGTH_TOLERANCE_M := 0.00002
const BASIS_TOLERANCE := 0.0001


static func apply(actor: Node3D, poses: Array[Transform3D], targets: Dictionary,
		orientations: Dictionary, lengths: Dictionary, max_pelvis_drop: float) -> Dictionary:
	var per_leg: Dictionary = {}
	if not is_instance_valid(actor) or not actor.has_method("_global_pose") or not actor.has_method("_set_global_basis"):
		return _reject("actor_pose_interface_required", per_leg)
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if not is_instance_valid(skeleton) or poses.size() != skeleton.get_bone_count():
		return _reject("complete_actual_local_pose_array_required", per_leg)
	if not is_finite(max_pelvis_drop) or max_pelvis_drop < 0.0:
		return _reject("finite_nonnegative_pelvis_drop_budget_required", per_leg)
	var skeleton_world: Transform3D = skeleton.global_transform
	if not _valid_transform(skeleton_world):
		return _reject("invalid_skeleton_world_transform", per_leg)
	for pose: Transform3D in poses:
		if not _valid_transform(pose):
			return _reject("invalid_local_pose", per_leg)
	var pelvis: int = skeleton.find_bone("pelvis")
	if pelvis < 0:
		return _reject("missing_pelvis", per_leg)
	var rows: Array = []
	var indices: Dictionary = {}
	for side: String in SIDES:
		if not targets.has(side) or typeof(targets[side]) != TYPE_VECTOR3:
			return _reject("two_world_Vector3_targets_required", per_leg)
		var target: Vector3 = targets[side]
		if not target.is_finite():
			return _reject("nonfinite_target_" + side, per_leg)
		if orientations.has(side):
			if typeof(orientations[side]) != TYPE_BASIS or not _valid_basis(orientations[side]):
				return _reject("invalid_world_orientation_" + side, per_leg)
		if not lengths.has(side) or typeof(lengths[side]) != TYPE_DICTIONARY:
			return _reject("actual_import_lengths_required_" + side, per_leg)
		var supplied: Dictionary = lengths[side]
		if not _positive_number(supplied.get("upper_m")) or not _positive_number(supplied.get("lower_m")):
			return _reject("invalid_import_lengths_" + side, per_leg)
		var upper: float = supplied["upper_m"]
		var lower: float = supplied["lower_m"]
		var thigh: int = skeleton.find_bone("thigh_" + side)
		var shin: int = skeleton.find_bone("shin_" + side)
		var foot: int = skeleton.find_bone("foot_" + side)
		if thigh < 0 or shin < 0 or foot < 0:
			return _reject("missing_leg_bones_" + side, per_leg)
		if skeleton.get_bone_parent(shin) != thigh or skeleton.get_bone_parent(foot) != shin or not _descends_from(skeleton, thigh, pelvis):
			return _reject("unsupported_leg_hierarchy_" + side, per_leg)
		indices[side] = {"thigh": thigh, "shin": shin, "foot": foot}
		var hip: Vector3 = _world_pose(actor, poses, thigh, skeleton_world).origin
		var knee: Vector3 = _world_pose(actor, poses, shin, skeleton_world).origin
		var ankle: Vector3 = _world_pose(actor, poses, foot, skeleton_world).origin
		var measured_upper: float = hip.distance_to(knee)
		var measured_lower: float = knee.distance_to(ankle)
		per_leg[side] = {"target_world": target, "previous_knee_world": knee,
			"input_hip_world": hip, "input_ankle_world": ankle,
			"upper_m": upper, "lower_m": lower,
			"input_upper_m": measured_upper, "input_lower_m": measured_lower}
		if not hip.is_finite() or not knee.is_finite() or not ankle.is_finite():
			return _reject("nonfinite_world_joints_" + side, per_leg)
		if absf(measured_upper - upper) > LENGTH_TOLERANCE_M or absf(measured_lower - lower) > LENGTH_TOLERANCE_M:
			return _reject("input_world_lengths_do_not_match_import_" + side, per_leg)
		rows.append({"hip": hip, "ankle": target, "previous_knee": knee,
			"upper_length": upper, "lower_length": lower})

	# Establish the shared reach envelope before touching even the working copy.
	var interval: Dictionary = Leg.pelvis_drop_interval(rows, max_pelvis_drop, REACH_MARGIN_M)
	if not interval.get("accepted", false):
		return _reject(str(interval.get("reason", "no_shared_drop")), per_leg, 0.0, interval)
	var drop: float = 0.0
	var admission: Dictionary = _solve_both(rows, drop)
	if not admission["accepted"]:
		# For a required drop, stay 1 mm inside BOTH ends of the shared outer
		# interval, including the explicit budget. No target/length is adjusted.
		# A too-narrow envelope or failed minimum-fold/pole guard is a visible hold.
		var safe_low: float = float(interval["minimum_drop_m"]) + DROP_INTERIOR_M
		var safe_high: float = float(interval["maximum_drop_m"]) - DROP_INTERIOR_M
		if safe_low > safe_high:
			return _reject("no_safe_interior_drop_interval", per_leg, 0.0, interval)
		drop = safe_low
		admission = _solve_both(rows, drop)
	for side: String in SIDES:
		per_leg[side]["solve"] = admission["per_leg"][side]
	if not admission["accepted"]:
		return _reject("two_leg_solve_rejected", per_leg, drop, interval)

	var working: Array[Transform3D] = poses.duplicate()
	var skeleton_inverse_basis: Basis = skeleton_world.basis.inverse()
	var pelvis_parent: int = skeleton.get_bone_parent(pelvis)
	var parent_basis: Basis = Basis.IDENTITY
	if pelvis_parent >= 0:
		var parent_pose: Transform3D = actor.call("_global_pose", working, pelvis_parent)
		parent_basis = parent_pose.basis
	if not _valid_basis(parent_basis):
		return _reject("invalid_pelvis_parent_basis", per_leg, drop, interval)
	var pelvis_pose: Transform3D = working[pelvis]
	# A world-vertical offset becomes a pelvis-local offset through BOTH bases.
	pelvis_pose.origin += parent_basis.inverse() * (skeleton_inverse_basis * (Vector3.DOWN * drop))
	working[pelvis] = pelvis_pose
	for side: String in SIDES:
		var ids: Dictionary = indices[side]
		var solved: Dictionary = admission["per_leg"][side]
		var hip_pose: Transform3D = _world_pose(actor, working, ids["thigh"], skeleton_world)
		var knee_pose: Transform3D = _world_pose(actor, working, ids["shin"], skeleton_world)
		var expected_hip: Vector3 = solved["hip"]
		if hip_pose.origin.distance_to(expected_hip) > POSITION_TOLERANCE_M:
			return _reject("pelvis_world_translation_mismatch_" + side, per_leg, drop, interval)
		var wanted_knee: Vector3 = solved["knee"]
		if not _align_segment(actor, working, ids["thigh"], knee_pose.origin - hip_pose.origin,
				wanted_knee - hip_pose.origin, hip_pose.basis, skeleton_inverse_basis, poses[ids["thigh"]].basis):
			return _reject("thigh_rotation_failed_" + side, per_leg, drop, interval)
		knee_pose = _world_pose(actor, working, ids["shin"], skeleton_world)
		var ankle_pose: Transform3D = _world_pose(actor, working, ids["foot"], skeleton_world)
		var target: Vector3 = targets[side]
		if not _align_segment(actor, working, ids["shin"], ankle_pose.origin - knee_pose.origin,
				target - knee_pose.origin, knee_pose.basis, skeleton_inverse_basis, poses[ids["shin"]].basis):
			return _reject("shin_rotation_failed_" + side, per_leg, drop, interval)
		if orientations.has(side):
			var desired: Basis = orientations[side]
			# Orient only: the imported foot's local scale is restored below.
			if not _set_world_basis(actor, working, ids["foot"], desired.orthonormalized(),
					skeleton_inverse_basis, poses[ids["foot"]].basis):
				return _reject("foot_orientation_failed_" + side, per_leg, drop, interval)

	# Verify the actual result, not just the ideal analytic construction.
	for side: String in SIDES:
		var ids: Dictionary = indices[side]
		var hip: Vector3 = _world_pose(actor, working, ids["thigh"], skeleton_world).origin
		var knee: Vector3 = _world_pose(actor, working, ids["shin"], skeleton_world).origin
		var foot_pose: Transform3D = _world_pose(actor, working, ids["foot"], skeleton_world)
		var target: Vector3 = targets[side]
		var upper: float = hip.distance_to(knee)
		var lower: float = knee.distance_to(foot_pose.origin)
		var residual: float = foot_pose.origin.distance_to(target)
		var row: Dictionary = per_leg[side]
		row.merge({"result_hip_world": hip, "result_knee_world": knee,
			"result_ankle_world": foot_pose.origin, "ankle_residual_m": residual,
			"result_upper_m": upper, "result_lower_m": lower,
			"upper_length_residual_m": absf(upper - float(row["upper_m"])),
			"lower_length_residual_m": absf(lower - float(row["lower_m"]))}, true)
		if not _valid_transform(foot_pose) or not is_finite(residual) or residual > POSITION_TOLERANCE_M:
			return _reject("actual_ankle_residual_exceeded_" + side, per_leg, drop, interval)
		if row["upper_length_residual_m"] > LENGTH_TOLERANCE_M or row["lower_length_residual_m"] > LENGTH_TOLERANCE_M:
			return _reject("actual_bone_length_residual_exceeded_" + side, per_leg, drop, interval)
		if orientations.has(side):
			var desired: Basis = orientations[side]
			var error: float = _basis_error(foot_pose.basis.orthonormalized(), desired.orthonormalized())
			row["orientation_basis_residual"] = error
			if error > BASIS_TOLERANCE:
				return _reject("actual_foot_orientation_residual_exceeded_" + side, per_leg, drop, interval)
	for index: int in range(poses.size()):
		if not _valid_transform(working[index]):
			return _reject("invalid_result_pose", per_leg, drop, interval)
		if index != pelvis and working[index].origin != poses[index].origin:
			return _reject("non_pelvis_local_origin_changed", per_leg, drop, interval)
		if working[index].basis.get_scale().distance_to(poses[index].basis.get_scale()) > 0.000001:
			return _reject("local_scale_changed", per_leg, drop, interval)
	return {"accepted": true, "poses": working, "pelvis_drop": drop, "per_leg": per_leg,
		"reason": "two_world_feet_solved", "drop_interval": interval,
		"drop_interior_safety_m": DROP_INTERIOR_M if drop > 0.0 else 0.0,
		"target_was_moved": false, "bones_were_stretched": false,
		"root_position_affected": false, "scope": "uncommitted_visual_pose_only"}


static func _solve_both(rows: Array, drop: float) -> Dictionary:
	var result: Dictionary = {"accepted": true, "per_leg": {}}
	for index: int in range(SIDES.size()):
		var row: Dictionary = rows[index]
		var hip: Vector3 = row["hip"]
		var solved: Dictionary = Leg.solve(hip + Vector3.DOWN * drop, row["ankle"],
			row["previous_knee"], row["upper_length"], row["lower_length"], REACH_MARGIN_M)
		result["per_leg"][SIDES[index]] = solved
		result["accepted"] = result["accepted"] and solved.get("accepted", false)
	return result


static func rotation_between(current: Vector3, desired: Vector3) -> Basis:
	# atan2 retains the observed 0.020-degree correction even when float32 dot
	# rounds to 1. No residual tolerance, local scale, or reach budget is widened.
	var source: Vector3 = current.normalized()
	var target: Vector3 = desired.normalized()
	var cross: Vector3 = source.cross(target)
	var sine: float = cross.length()
	var cosine: float = clampf(source.dot(target), -1.0, 1.0)
	if sine > 0.0:
		return Basis(cross / sine, atan2(sine, cosine))
	if cosine >= 0.0:
		return Basis.IDENTITY
	var helper_axis: Vector3 = Vector3.RIGHT if absf(source.x) < absf(source.y) else Vector3.UP
	if absf(source.z) < minf(absf(source.x), absf(source.y)):
		helper_axis = Vector3.BACK
	return Basis(source.cross(helper_axis).normalized(), PI)


static func _align_segment(actor: Node3D, poses: Array[Transform3D], index: int,
		current: Vector3, desired: Vector3, current_world_basis: Basis,
		skeleton_inverse_basis: Basis, original_local_basis: Basis) -> bool:
	if not current.is_finite() or not desired.is_finite() or current.length_squared() < 0.000000000001 or desired.length_squared() < 0.000000000001:
		return false
	var rotation: Basis = rotation_between(current, desired)
	return _set_world_basis(actor, poses, index, rotation * current_world_basis,
		skeleton_inverse_basis, original_local_basis)


static func _set_world_basis(actor: Node3D, poses: Array[Transform3D], index: int,
		world_basis: Basis, skeleton_inverse_basis: Basis, original_local_basis: Basis) -> bool:
	actor.call("_set_global_basis", poses, index, skeleton_inverse_basis * world_basis)
	var local: Transform3D = poses[index]
	if not _valid_basis(local.basis):
		return false
	# Preserve each imported local-axis magnitude without assuming Euler axes,
	# positive determinant, uniform scale, or a particular bone-forward axis.
	local.basis.x *= original_local_basis.x.length() / local.basis.x.length()
	local.basis.y *= original_local_basis.y.length() / local.basis.y.length()
	local.basis.z *= original_local_basis.z.length() / local.basis.z.length()
	poses[index] = local
	return _valid_transform(local)


static func _world_pose(actor: Node3D, poses: Array[Transform3D], index: int,
		skeleton_world: Transform3D) -> Transform3D:
	var in_skeleton: Transform3D = actor.call("_global_pose", poses, index)
	return skeleton_world * in_skeleton


static func _descends_from(skeleton: Skeleton3D, index: int, ancestor: int) -> bool:
	for _step: int in range(skeleton.get_bone_count()):
		index = skeleton.get_bone_parent(index)
		if index == ancestor:
			return true
		if index < 0:
			return false
	return false


static func _positive_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value)) and float(value) > 0.0


static func _valid_basis(value: Basis) -> bool:
	return value.is_finite() and absf(value.determinant()) > 0.000000000001


static func _valid_transform(value: Transform3D) -> bool:
	return value.origin.is_finite() and _valid_basis(value.basis)


static func _basis_error(first: Basis, second: Basis) -> float:
	return maxf(first.x.distance_to(second.x), maxf(first.y.distance_to(second.y), first.z.distance_to(second.z)))


static func _reject(reason: String, per_leg: Dictionary, drop: float = 0.0, interval: Dictionary = {}) -> Dictionary:
	# Deliberately omit `poses`: neither partial leg writes nor a fallback pose is
	# usable. The caller must explicitly hold/release its existing anchor on fail.
	return {"accepted": false, "reason": reason, "pelvis_drop": drop,
		"per_leg": per_leg, "drop_interval": interval, "target_was_moved": false,
		"bones_were_stretched": false, "root_position_affected": false,
		"scope": "rejected_uncommitted_visual_pose"}
