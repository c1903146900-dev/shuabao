extends RefCounted
## Pure world-joint geometry. Returns targets/errors; never writes root, pose or
## gameplay state. Import-rest lengths and actual previous knee must be supplied.
static func solve(hip: Vector3, ankle: Vector3, previous_knee: Vector3, upper_length: float, lower_length: float, margin: float=.0001) -> Dictionary:
	if not hip.is_finite() or not ankle.is_finite() or not previous_knee.is_finite() or not is_finite(upper_length) or not is_finite(lower_length) or not is_finite(margin) or upper_length<=0.0 or lower_length<=0.0 or margin<0.0:
		return {"accepted":false,"reason":"invalid_joint_or_length"}
	var minimum:=absf(upper_length-lower_length)+margin
	var maximum:=upper_length+lower_length-margin
	var offset:=ankle-hip
	var distance:=offset.length()
	if not is_finite(distance) or minimum>=maximum or distance<minimum or distance>maximum:
		return {"accepted":false,"reason":"unreachable_target","distance":distance,"minimum_reach":minimum,"maximum_reach":maximum,"target_was_clamped":false,"bones_were_stretched":false}
	var axis:=offset/distance
	var hint:=previous_knee-hip
	var pole:=hint-axis*hint.dot(axis)
	if not pole.is_finite() or pole.length_squared()<.000000000001:
		return {"accepted":false,"reason":"previous_knee_has_no_bend_plane","target_was_clamped":false}
	pole= pole.normalized()
	var along: float=(upper_length*upper_length+distance*distance-lower_length*lower_length)/(2.0*distance)
	var height:=sqrt(maxf(0.0,upper_length*upper_length-along*along))
	var knee:=hip+axis*along+pole*height
	return {"accepted":true,"hip":hip,"knee":knee,"ankle":ankle,"upper_length":upper_length,"lower_length":lower_length,"upper_residual":absf(hip.distance_to(knee)-upper_length),"lower_residual":absf(knee.distance_to(ankle)-lower_length),"maximum_reach":maximum,"target_was_clamped":false,"bones_were_stretched":false}
static func pelvis_drop_interval(legs: Array, max_drop: float, margin: float=.0001) -> Dictionary:
	# Outer reach-sphere intersection only. The caller must choose an interior
	# drop and call solve for each leg, including its minimum-fold guard.
	if legs.size()!=2 or not is_finite(max_drop) or max_drop<0.0 or not is_finite(margin) or margin<0.0:return {"accepted":false,"reason":"two_legs_and_finite_budget_required"}
	var low:=0.0
	var high:=max_drop
	var evidence: Array=[]
	for row: Dictionary in legs:
		var hip: Vector3=row.get("hip",Vector3.INF)
		var ankle: Vector3=row.get("ankle",Vector3.INF)
		var upper:=float(row.get("upper_length",0.0));var lower:=float(row.get("lower_length",0.0))
		if not hip.is_finite() or not ankle.is_finite() or not is_finite(upper) or not is_finite(lower) or upper<=0.0 or lower<=0.0 or margin<0.0:
			return {"accepted":false,"reason":"invalid_leg"}
		var maximum:=upper+lower-margin
		var dx:=float(ankle.x)-float(hip.x);var dz:=float(ankle.z)-float(hip.z)
		var horizontal_squared:=dx*dx+dz*dz
		if maximum<=0.0 or horizontal_squared>maximum*maximum:return {"accepted":false,"reason":"horizontal_target_unreachable_at_any_pelvis_height","target_was_moved":false}
		var vertical:=sqrt(maxf(0.0,maximum*maximum-horizontal_squared))
		var difference:=float(hip.y)-float(ankle.y)
		var leg_low:=difference-vertical;var leg_high:=difference+vertical
		low=maxf(low,leg_low);high=minf(high,leg_high)
		evidence.append({"horizontal_distance":sqrt(horizontal_squared),"drop_interval":[leg_low,leg_high],"maximum_reach":maximum})
	if low>high:return {"accepted":false,"reason":"no_shared_drop_within_budget","required_minimum_drop":low,"allowed_maximum_drop":high,"legs":evidence}
	return {"accepted":true,"minimum_drop_m":low,"maximum_drop_m":high,"legs":evidence,"scope":"outer reach feasibility interval, not an applied pelvis trajectory or solved pose","final_per_leg_solve_required":true,"root_position_affected":false}
