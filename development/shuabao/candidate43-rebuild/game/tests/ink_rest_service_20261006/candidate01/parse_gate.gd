extends SceneTree
const RestHost = preload("res://tests/ink_rest_service_20261006/candidate01/host.gd")
const RestSession = preload("res://tests/ink_rest_service_20261006/candidate01/floor_session.gd")
const RestService = preload("res://tests/ink_rest_service_20261006/candidate01/rest_service.gd")
const Finite = preload("res://tests/ink_rest_service_20261006/candidate01/finite_gate.gd")
func _initialize() -> void:
 var failures: Array[String] = []
 var scripts: Array[GDScript] = [RestHost,RestSession,RestService,Finite]
 for script: GDScript in scripts:
  if script == null or not script.can_instantiate(): failures.append(script.resource_path if script != null else "null")
 print("INK_REST_PARSE ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"runtime_executed":false,"native_input":false}))
 quit(0 if failures.is_empty() else 1)
