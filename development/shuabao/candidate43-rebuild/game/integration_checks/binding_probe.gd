extends SceneTree
const Sim=preload("res://tests/ink_river_hexes_20261006/ordinary01/sim.gd")
const Current=preload("res://visual_rework_20261009/binding/live_binding.gd")
const Old=preload("res://tests/ink_first_floor_boss_20261008/live02/live_binding.gd")
func _initialize()->void:
 var sim=Sim.new()
 var accepted=Current.read_capabilities(sim,true)
 var old=Old.read_capabilities(sim,true)
 print("SUCCESSOR_BINDING ",JSON.stringify(accepted))
 print("OLD_BINDING_REJECTS_CHANGED_SOURCE ",JSON.stringify(old))
 sim.free()
 quit(0 if accepted.get("accepted",false) and not old.get("accepted",true) else 1)
