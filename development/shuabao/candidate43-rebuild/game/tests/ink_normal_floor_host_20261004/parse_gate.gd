extends SceneTree
## Main-owned compile-only gate. No app instance, asset import or source step.
const Host = preload("res://tests/ink_normal_floor_host_20261004/host.gd")
const Session = preload("res://tests/ink_normal_floor_host_20261004/floor_session.gd")
const Model = preload("res://tests/ink_normal_floor_host_20261004/reward_model.gd")
const Bridge = preload("res://tests/ink_normal_floor_host_20261004/bridge.gd")
const Enemy = preload("res://tests/ink_normal_floor_host_20261004/enemy_layer.gd")
const Growth = preload("res://tests/ink_normal_floor_host_20261004/growth_hud.gd")
const Preview = preload("res://tests/ink_normal_floor_host_20261004/preview.gd")
const LifecycleGate = preload("res://tests/ink_normal_floor_host_20261004/lifecycle_gate.gd")
func _initialize() -> void:
 var scripts: Array = [Host,Session,Model,Bridge,Enemy,Growth,Preview,LifecycleGate]
 var failures: Array = []
 for script: GDScript in scripts:
  if not script.can_instantiate(): failures.append(script.resource_path)
 print("INK_NORMAL_FLOOR_PARSE ",JSON.stringify({"suite":"normal_floor_parse","scripts":scripts.size(),"failures":failures,"passed":failures.is_empty(),"engine_runtime":false,"imports":false,"native":false}))
 quit(0 if failures.is_empty() else 1)
