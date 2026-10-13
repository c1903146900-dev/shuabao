extends SceneTree
## Parse the exact ordinary successor and finite gate; no gameplay claim.
const Binding = preload("res://tests/ink_e3_ordinary_20261006/ordinary01/live_binding.gd")
const FILES := ["res://tests/ink_e3_ordinary_20261006/ordinary01/sim.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/e3_base.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/q2_jump_seams.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/e3_boundary.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/bridge.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/catalog.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/floor_session.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/growth_hud.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/host.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/input_adapter.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/live_binding.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/navigation_install.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/e_hud.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/frame_view.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/hud_projection.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/runtime_text.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/finite_host.gd", "res://tests/ink_e3_ordinary_20261006/ordinary01/finite_gate.gd", "res://scripts/ui/hero_chooser.gd", "res://scripts/integration/yanguizhou_first_floor.gd"]
func _initialize() -> void:
 var failures: Array[String] = []
 for path: String in FILES:
  var source_script: GDScript = load(path)
  if source_script == null or not source_script.can_instantiate(): failures.append(path)
 print("INK_E3_ORDINARY_PARSE ",JSON.stringify({"passed":failures.is_empty(),"source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH),"scripts":FILES,"failures":failures,"runtime_pass":false}))
 quit(0 if failures.is_empty() else 1)
