extends "res://tests/ink_rest_service_20261006/candidate01/ordinary01/floor_session.gd"
## Preserve the committed rest settlement and all original single-owner state.
const BoatOrdinaryBinding = preload("res://tests/ink_e2_boundary_20261006/ordinary01/live_binding.gd")
const BoatOrdinaryBridge = preload("res://tests/ink_e2_boundary_20261006/ordinary01/bridge.gd")
func _floor_admission(source_sim: Node) -> Dictionary:
 return BoatOrdinaryBinding.read_capabilities(source_sim,true)
func _make_reward_bridge() -> RefCounted:
 return BoatOrdinaryBridge.new()
