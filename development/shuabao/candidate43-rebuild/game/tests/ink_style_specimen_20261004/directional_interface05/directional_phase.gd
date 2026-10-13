extends RefCounted
## Pure target selection only. No actor, simulation, clip resource or clock writes.
const CARDINAL_CLIPS:=["walk","walk_back","strafe_left","strafe_right"]
static func weights(local_direction: Vector3) -> Dictionary:
	if not local_direction.is_finite():return {"accepted":false,"reason":"nonfinite_local_direction"}
	var raw: Array[float]=[maxf(0.0,local_direction.z),maxf(0.0,-local_direction.z),maxf(0.0,-local_direction.x),maxf(0.0,local_direction.x)]
	var total: float=raw[0]+raw[1]+raw[2]+raw[3]
	if total==0.0:return {"accepted":false,"reason":"no_horizontal_motion"}
	var result: Dictionary={}
	var nonzero:=0
	for index in range(4):
		result[CARDINAL_CLIPS[index]]=raw[index]/total
		if raw[index]>0.0:nonzero+=1
	return {"accepted":true,"weights":result,"diagonal":nonzero==2,"requires_target_space_solve_for_exact_stride":nonzero==2,"cardinal_blend_is_not_diagonal_plant_proof":true}
static func sample_time(displacement_phase_s: float, cycle_s: float, proven_window: Dictionary) -> Dictionary:
	var first:=float(proven_window.get("first",INF))
	var last:=float(proven_window.get("last",-INF))
	if not is_finite(displacement_phase_s) or not is_finite(cycle_s) or cycle_s<=0.0 or not is_finite(first) or not is_finite(last) or last<=first:
		return {"accepted":false,"reason":"invalid_phase_or_unproven_window"}
	var phase:=fposmod(displacement_phase_s,cycle_s)
	var requested:=first+phase
	return {"accepted":true,"phase_s":phase,"sample_s":minf(requested,last),"first_key_s":first,"last_key_s":last,"binary_endpoint_clamped":requested>last,"time_reversed":false,"authored_zero_key_preserved":first==0.0}
