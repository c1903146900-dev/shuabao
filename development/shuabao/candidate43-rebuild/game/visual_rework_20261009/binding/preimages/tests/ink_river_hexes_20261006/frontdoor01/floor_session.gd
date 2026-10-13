extends "res://tests/ink_ordinary_composed_20261006/candidate01/floor_session.gd"
## One retained ordinary Session and all original wallet/health/rest authorities.
const R2OrdinaryBinding = preload("res://tests/ink_first_floor_boss_20261008/live02/live_binding.gd")
const R2OrdinaryBridge = preload("res://tests/ink_first_floor_boss_20261008/live02/bridge.gd")
func _floor_admission(source_sim: Node) -> Dictionary:
 return R2OrdinaryBinding.read_capabilities(source_sim,true)
func _make_reward_bridge() -> RefCounted:
 return R2OrdinaryBridge.new()
