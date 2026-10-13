extends SceneTree
## Dependency/parse admission only; running this does not run the finite suite.
const Sim = preload("res://tests/ink_r1_ordinary_20261005/candidate01/sim.gd")
const Director = preload("res://tests/ink_r1_ordinary_20261005/candidate01/enemy_director.gd")
const Finite = preload("res://tests/ink_r1_ordinary_20261005/candidate01/finite_gate.gd")

func _initialize() -> void:
 var failures: Array[String] = []
 var scripts: Array[GDScript] = [Sim, Director, Finite]
 for script: GDScript in scripts:
  if script == null or not script.can_instantiate():
   failures.append(script.resource_path if script != null else "null_script")
 var accepted: bool = failures.is_empty()
 print("INK_R1_MINIMAL_CORE_PARSE ", JSON.stringify({"passed":accepted,"failures":failures,"ordinary_R1_opened":false,"ordinary_XP_or_SP_granted":false,"finite_suite_run":false,"native_input":false,"full_floor":false,"art_audio":false}))
 quit(0 if accepted else 1)
