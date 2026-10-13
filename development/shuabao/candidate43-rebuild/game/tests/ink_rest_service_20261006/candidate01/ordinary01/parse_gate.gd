extends SceneTree
const Production = preload("res://scripts/integration/yanguizhou_first_floor.gd")
const RestSession = preload("res://tests/ink_rest_service_20261006/candidate01/ordinary01/floor_session.gd")
const RestBridge = preload("res://tests/ink_rest_service_20261006/candidate01/ordinary01/bridge.gd")
const RestNavigation = preload("res://tests/ink_rest_service_20261006/candidate01/ordinary01/navigation_install.gd")
const RestBinding = preload("res://tests/ink_rest_service_20261006/candidate01/ordinary01/live_binding.gd")
const Finite = preload("res://tests/ink_rest_service_20261006/candidate01/ordinary01/finite_gate.gd")
func _initialize() -> void:
 var failures: Array[String] = []
 var scripts: Array[GDScript] = [Production,RestSession,RestBridge,RestNavigation,RestBinding,Finite]
 for script: GDScript in scripts:
  if script == null or not script.can_instantiate(): failures.append(script.resource_path if script != null else "null")
 print("INK_REST_ORDINARY_PARSE ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"runtime_executed":false,"native_input":false}))
 quit(0 if failures.is_empty() else 1)
