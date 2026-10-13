extends SceneTree
const Host = preload("res://tests/ink_selected_q_hud_20261005/fix01/host.gd")
const SelectedQModel = preload("res://tests/ink_selected_q_hud_20261005/projection.gd")
const Patch = preload("res://tests/ink_selected_q_hud_20261005/fix01/hud_patch.gd")
const Icon = preload("res://tests/ink_selected_q_hud_20261005/icon.gd")
const Gate = preload("res://tests/ink_selected_q_hud_20261005/fix01/projection_gate.gd")
func _initialize() -> void:
 var scripts: Array = [Host,SelectedQModel,Patch,Icon,Gate]
 var failures: Array = []
 for script: GDScript in scripts:
  if not script.can_instantiate(): failures.append(script.resource_path)
 print("INK_SELECTED_Q_PARSE ",JSON.stringify({"suite":"selected_q_parse","scripts":scripts.size(),"failures":failures,"passed":failures.is_empty(),"runtime":false,"native":false}))
 quit(0 if failures.is_empty() else 1)
