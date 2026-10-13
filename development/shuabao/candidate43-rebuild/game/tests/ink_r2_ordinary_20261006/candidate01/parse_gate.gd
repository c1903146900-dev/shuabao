extends SceneTree
const FILES := ["res://tests/ink_r2_ordinary_20261006/candidate01/bridge.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/catalog.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/e_hud.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/finite_gate.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/finite_host.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/floor_session.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/growth_hud.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/host.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/hud_projection.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/input_adapter.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/live_binding.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/navigation_install.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/peaks_view.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/production_adapter.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/production_chooser.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/r_hud.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/runtime_text.gd", "res://tests/ink_r2_ordinary_20261006/candidate01/sim.gd"]
func _initialize() -> void:
 var failures: Array[String] = []
 for path: String in FILES:
  var source_script: GDScript = load(path)
  if source_script == null or not source_script.can_instantiate(): failures.append(path)
 print("INK_R2_ORDINARY_PARSE ",JSON.stringify({"passed":failures.is_empty(),"source_binding_sha256":FileAccess.get_sha256("res://tests/ink_r2_ordinary_20261006/candidate01/source_binding.json"),"scripts":FILES,"failures":failures,"runtime_pass":false}))
 quit(0 if failures.is_empty() else 1)
