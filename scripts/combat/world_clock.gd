extends RefCounted
const T = preload("res://data/combat/tuning.gd")
var world_time: float = 0.0
var presenters: Dictionary = {}
func enter(actor_id: String, duration: float) -> void:
 presenters[actor_id] = maxf(float(presenters.get(actor_id, 0.0)), duration)
func leave(actor_id: String) -> void:
 presenters.erase(actor_id)
func clear() -> void:
 presenters.clear()
func scale_factor() -> float:
 return 1.0 if presenters.is_empty() else T.INITIAL.world_slow
func step(real_delta: float, active: bool) -> float:
 if not active: return 0.0
 # Split at the last presentation ending, so a long frame cannot over-slow the whole frame.
 var last: float = 0.0
 for remaining in presenters.values(): last = maxf(last, remaining)
 var slow_slice: float = minf(real_delta, last)
 var result: float = slow_slice * T.INITIAL.world_slow + real_delta - slow_slice
 for key in presenters.keys():
  presenters[key] -= real_delta
  if presenters[key] <= 0.00000001: presenters.erase(key)
 world_time += result
 return result
