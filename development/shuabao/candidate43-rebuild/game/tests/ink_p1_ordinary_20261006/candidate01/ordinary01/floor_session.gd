extends "res://tests/ink_first_floor_user_route_20261005/runtime01/floor_session.gd"
## All lifecycle, route, reward and commerce methods remain the same owner.
const P1Binding = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/live_binding.gd")
const P1RewardBridge = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/bridge.gd")
func _floor_admission(source_sim: Node) -> Dictionary:
 return P1Binding.read_capabilities(source_sim, true)
func _make_reward_bridge() -> RefCounted:
 return P1RewardBridge.new()
