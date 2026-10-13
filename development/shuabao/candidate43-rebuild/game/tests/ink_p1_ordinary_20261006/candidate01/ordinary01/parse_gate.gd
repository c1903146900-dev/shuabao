extends SceneTree
## Parse and exact dependency admission only, no finite/native/gameplay claim.
const Room = preload("res://scripts/integration/yanguizhou_first_floor.gd")
const Sim = preload("res://tests/ink_p1_ordinary_20261006/candidate01/lifesteal01/sim.gd")
const Session = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/floor_session.gd")
const Growth = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/growth_hud.gd")
const Passive = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/p_hud.gd")
const Finite = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/finite_gate.gd")
func _initialize() -> void:
 var failures: Array[String] = []
 var scripts: Array[GDScript] = [Room,Sim,Session,Growth,Passive,Finite]
 for script: GDScript in scripts:
  if script == null or not script.can_instantiate(): failures.append(script.resource_path if script != null else "null")
 print("INK_P1_ORDINARY_PARSE ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"runtime_executed":false,"native_input":false}))
 quit(0 if failures.is_empty() else 1)
