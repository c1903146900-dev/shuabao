extends SceneTree
const FILES := ["res://tests/ink_p2_ordinary_20261006/mechanism01/p2_state.gd", "res://tests/ink_p2_ordinary_20261006/mechanism01/p2_common_bridge.gd", "res://tests/ink_p2_ordinary_20261006/mechanism01/sim.gd", "res://tests/ink_p2_ordinary_20261006/mechanism01/finite_gate.gd"]
func _initialize() -> void:
 var failures: Array[String] = []
 for path: String in FILES:
  var source_script: GDScript = load(path)
  if source_script == null or not source_script.can_instantiate(): failures.append(path)
 print("INK_P2_MECHANISM_PARSE ",JSON.stringify({"passed":failures.is_empty(),"source_binding_sha256":FileAccess.get_sha256("res://tests/ink_p2_ordinary_20261006/mechanism01/source_binding.json"),"scripts":FILES,"failures":failures,"runtime_pass":false}))
 quit(0 if failures.is_empty() else 1)
