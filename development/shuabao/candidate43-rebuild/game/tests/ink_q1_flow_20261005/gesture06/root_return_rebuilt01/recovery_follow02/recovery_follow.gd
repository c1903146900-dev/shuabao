extends RefCounted
## Source-clock yaw branch tracking only. No animation, source or foot ownership.
const START:=.24
const END:=.43
var _key: String=""
var _last_time: float=-1.0
var _error_unwrapped: float=0.0
var _follow_unwrapped: float=0.0
func reset() -> void:
 _key="";_last_time=-1.0;_error_unwrapped=0.0;_follow_unwrapped=0.0
func sample(key: String,now: float,age: float,cast_yaw: float,follow_yaw: float,eligible: bool) -> Dictionary:
 var follow_weight: float=smoothstep(START,END,age) if eligible else 0.0
 if not eligible:
  reset()
  return {"active":false,"source_age":age,"cast_weight":1.0,"follow_weight":0.0,"yaw_correction":0.0,"art_accepted":false}
 var raw_error: float=wrapf(cast_yaw-follow_yaw,-PI,PI)
 var restarted: bool=key!=_key or _last_time<0.0 or now<_last_time
 var repeated: bool=not restarted and now==_last_time
 if restarted:
  _key=key;_error_unwrapped=raw_error;_follow_unwrapped=follow_yaw
 elif not repeated:
  # Unwrap over time BEFORE weighting. Do not pick a new shortest interpolation
  # branch on each frame when the relative angle crosses +PI/-PI.
  _error_unwrapped+=wrapf(raw_error-_error_unwrapped,-PI,PI)
  _follow_unwrapped+=wrapf(follow_yaw-_follow_unwrapped,-PI,PI)
 _last_time=now
 var cast_weight: float=1.0-follow_weight
 var desired: float=_follow_unwrapped+_error_unwrapped*cast_weight
 # This final wrap selects an equivalent rotation matrix, not an interpolation path.
 var correction: float=wrapf(desired-cast_yaw,-PI,PI) if follow_weight>0.0 else 0.0
 return {"active":follow_weight>0.0,"source_age":age,"cast_weight":cast_weight,"follow_weight":follow_weight,"yaw_correction":correction,"cast_yaw":cast_yaw,"follow_yaw":follow_yaw,"raw_relative_yaw":raw_error,"relative_yaw_unwrapped":_error_unwrapped,"follow_yaw_unwrapped":_follow_unwrapped,"desired_world_yaw_unwrapped":desired,"repeated_source":repeated,"branch_restarted":restarted,"reference":"authored chest on actual foot-solved lower frame; yaw authority only","complete_upper_clip":true,"source_direction_written":false,"wave_lifetime_used":false,"art_accepted":false}
