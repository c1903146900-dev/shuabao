extends SceneTree
## Parse/dependency gate only. All reflection is on typed GDScript resources.
const Sim = preload("res://tests/ink_p1_ordinary_20261006/candidate01/sim.gd")
const Finite = preload("res://tests/ink_p1_ordinary_20261006/candidate01/finite_gate.gd")
func _initialize() -> void:
 var failures: Array[String] = []
 var scripts: Array[GDScript] = [Sim,Finite]
 for script: GDScript in scripts:
  if script == null or not script.can_instantiate(): failures.append(script.resource_path if script != null else "null")
 print("INK_P1_CURRENT_CORE_PARSE ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"runtime_executed":false,"ordinary_P1_opened":false}))
 quit(0 if failures.is_empty() else 1)
