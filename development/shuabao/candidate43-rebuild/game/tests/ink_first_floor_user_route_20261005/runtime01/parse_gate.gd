extends SceneTree
const Host = preload("res://tests/ink_first_floor_user_route_20261005/runtime01/host.gd")
const Session = preload("res://tests/ink_first_floor_user_route_20261005/runtime01/floor_session.gd")
const Bootstrap = preload("res://tests/ink_first_floor_user_route_20261005/runtime01/bootstrap_session.gd")
const Bridge = preload("res://tests/ink_first_floor_user_route_20261005/runtime01/bridge.gd")
const Model = preload("res://tests/ink_first_floor_user_route_20261005/runtime01/reward_model.gd")
const Adapter = preload("res://tests/ink_first_floor_user_route_20261005/runtime01/reward_adapter.gd")
const Schema = preload("res://tests/ink_first_floor_user_route_20261005/runtime01/route_schema.gd")
const Rows = preload("res://tests/ink_first_floor_user_route_20261005/runtime01/row_state.gd")
const Map = preload("res://tests/ink_first_floor_user_route_20261005/runtime01/route_map.gd")
const Gate = preload("res://tests/ink_first_floor_user_route_20261005/runtime01/engine_gate.gd")
func _initialize() -> void:
 var failures: Array = []
 var scripts: Array = [Host,Session,Bootstrap,Bridge,Model,Adapter,Schema,Rows,Map,Gate]
 for script: GDScript in scripts:
  if not script.can_instantiate(): failures.append(script.resource_path)
 print("INK_USER_ROUTE_PARSE ",JSON.stringify({"suite":"ink_user_route_parse_v1","scripts":scripts.size(),"passed":failures.is_empty(),"failures":failures,"runtime":false,"native":false}))
 quit(0 if failures.is_empty() else 1)
