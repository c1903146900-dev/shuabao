extends "res://tests/ink_p2_ordinary_20261006/ordinary01/floor_session.gd"
## One retained ordinary Session and all original wallet/health/rest authorities.
const CombinedBinding = preload("res://tests/ink_ordinary_composed_20261006/candidate01/live_binding.gd")
const CombinedBridge = preload("res://tests/ink_ordinary_composed_20261006/candidate01/bridge.gd")
func _floor_admission(source_sim: Node) -> Dictionary:
 return CombinedBinding.read_capabilities(source_sim,true)
func _make_reward_bridge() -> RefCounted:
 return CombinedBridge.new()
