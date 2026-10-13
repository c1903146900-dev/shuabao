extends "res://tests/ink_e3_ordinary_20261006/ordinary01/floor_session.gd"
## Same committed rest, health, inventory, reward and route owner.
const P2Binding = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/live_binding.gd")
const P2Bridge = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/bridge.gd")
func _floor_admission(source_sim: Node) -> Dictionary:
 return P2Binding.read_capabilities(source_sim,true)
func _make_reward_bridge() -> RefCounted:
 return P2Bridge.new()
