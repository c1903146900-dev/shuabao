extends RefCounted
## Stateless presentation heading only. source_dt is zero on repeated source
## timestamps; no game actor, input, clock, animation time or distance is written.
const ROOT_RADIANS_PER_SECOND:=TAU*2.0 # 720 degrees/s; 90 degrees takes .125 s.
const CHEST_RADIANS_PER_SECOND:=TAU*3.0 # 1080 degrees/s for observable body yaw.
const TORSO_LIMIT_RADIANS:=65.0*PI/180.0
static func advance(previous: float, desired: float, source_dt: float, maximum_rate: float=ROOT_RADIANS_PER_SECOND) -> Dictionary:
	if not is_finite(previous) or not is_finite(desired) or not is_finite(source_dt) or source_dt<0.0 or not is_finite(maximum_rate) or maximum_rate<0.0:
		return {"accepted":false,"reason":"invalid_presentation_heading_input"}
	var error:=wrapf(desired-previous,-PI,PI)
	var budget:=maximum_rate*source_dt
	var applied:=clampf(error,-budget,budget)
	var result:=previous+applied
	return {"accepted":true,"yaw":result,"target_yaw":desired,"applied_radians":applied,"source_delta":source_dt,"maximum_rate":maximum_rate,"rate_limited":absf(error)>budget,"remaining_radians":wrapf(desired-result,-PI,PI),"source_motion_changed":false}
static func logical_yaw(world_basis: Basis, rest_global_basis: Basis) -> float:
	var direction: Vector3=world_basis*rest_global_basis.inverse()*Vector3.BACK
	return atan2(direction.x,direction.z)
