extends "res://tests/ink_ordinary_composed_20261006/candidate01/floor_session.gd"
## One retained ordinary Session and all original wallet/health/rest authorities.
const R2OrdinaryBinding = preload("res://visual_rework_20261009/binding/live_binding.gd")
const R2OrdinaryBridge = preload("res://visual_rework_20261009/binding/bridge.gd")
func _floor_admission(source_sim: Node) -> Dictionary:
 return R2OrdinaryBinding.read_capabilities(source_sim,true)
func _make_reward_bridge() -> RefCounted:
 return R2OrdinaryBridge.new()
