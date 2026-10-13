extends SceneTree
const Entry = preload("res://scripts/integration/hero_entry.gd")
const Room = preload("res://scripts/integration/yanguizhou_first_floor.gd")
const Finite = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/finite_gate.gd")
func _initialize() -> void:
 var failures: Array[String]=[]
 var scripts: Array[GDScript]=[Entry,Room,Finite]
 for script: GDScript in scripts:
  if script==null or not script.can_instantiate(): failures.append(script.resource_path if script!=null else "null_script")
 print("INK_R1_ORDINARY_PARSE ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"native_input":false,"natural_level6":false,"art_audio":false}))
 quit(0 if failures.is_empty() else 1)
