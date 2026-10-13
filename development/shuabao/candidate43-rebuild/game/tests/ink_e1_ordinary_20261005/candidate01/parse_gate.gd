extends SceneTree
const Entry = preload("res://scripts/integration/hero_entry.gd")
const Host = preload("res://scripts/integration/yanguizhou_first_floor.gd")
const Finite = preload("res://tests/ink_e1_ordinary_20261005/candidate01/finite_gate.gd")
func _initialize() -> void:
 var scripts: Array[GDScript] = [Entry,Host,Finite]
 var failures: Array[String] = []
 for script: GDScript in scripts:
  if script == null or not script.can_instantiate(): failures.append(script.resource_path if script != null else "null_script")
 var accepted: bool = failures.is_empty()
 print("INK_E1_ORDINARY_PARSE ",JSON.stringify({"passed":accepted,"failures":failures,"native_input":false,"art_audio":false}))
 quit(0 if accepted else 1)
