extends SceneTree
const FILES := ["res://tests/ink_e2_boundary_20261006/candidate01/boat_boundary.gd","res://tests/ink_e2_boundary_20261006/candidate01/sim.gd","res://tests/ink_e2_boundary_20261006/candidate01/finite_gate.gd"]
func _initialize() -> void:
 var failures: Array[String] = []
 for path: String in FILES:
  var script: GDScript = load(path)
  if script == null or not script.can_instantiate(): failures.append(path)
 print("INK_E2_BOUNDARY_PARSE ",JSON.stringify({"passed":failures.is_empty(),"scripts":FILES,"failures":failures,"runtime_pass":false}))
 quit(0 if failures.is_empty() else 1)
