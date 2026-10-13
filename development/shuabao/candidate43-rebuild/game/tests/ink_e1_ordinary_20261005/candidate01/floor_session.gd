extends "res://tests/ink_first_floor_user_route_20261005/runtime01/floor_session.gd"
## All lifecycle, route, reward and commerce methods remain the same owner.
const Q2Binding = preload("res://tests/ink_e1_ordinary_20261005/candidate01/live_binding.gd")
const Q2RewardBridge = preload("res://tests/ink_e1_ordinary_20261005/candidate01/bridge.gd")
func _floor_admission(source_sim: Node) -> Dictionary:
 return Q2Binding.read_capabilities(source_sim, true)
func _make_reward_bridge() -> RefCounted:
 return Q2RewardBridge.new()
