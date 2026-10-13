extends "res://tests/ink_rest_service_20261006/candidate01/floor_session.gd"
## Retain the proven rest entry and settlement; only select this successor admission.
const RestOrdinaryBinding = preload("res://tests/ink_rest_service_20261006/candidate01/ordinary01/live_binding.gd")
const RestOrdinaryBridge = preload("res://tests/ink_rest_service_20261006/candidate01/ordinary01/bridge.gd")
func _floor_admission(source_sim: Node) -> Dictionary:
 return RestOrdinaryBinding.read_capabilities(source_sim,true)
func _make_reward_bridge() -> RefCounted:
 return RestOrdinaryBridge.new()
