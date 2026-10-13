extends "res://tests/ink_e2_boundary_20261006/ordinary01/floor_session.gd"
## Preserve the committed rest settlement and all original single-owner state.
const TextBinding = preload("res://tests/ink_e2_boundary_20261006/ordinary01/text01/live_binding.gd")
const TextBridge = preload("res://tests/ink_e2_boundary_20261006/ordinary01/text01/bridge.gd")
func _floor_admission(source_sim: Node) -> Dictionary:
 return TextBinding.read_capabilities(source_sim,true)
func _make_reward_bridge() -> RefCounted:
 return TextBridge.new()
