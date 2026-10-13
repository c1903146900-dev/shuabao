extends SceneTree
## Presentation successor parse only; no gameplay replay.
const FILES := ["res://tests/ink_e2_boundary_20261006/ordinary01/text01/bridge.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/text01/finite_gate.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/text01/floor_session.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/text01/growth_hud.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/text01/host.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/text01/live_binding.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/text01/navigation_install.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/text01/runtime_text.gd", "res://scripts/ui/hero_chooser.gd", "res://scripts/integration/yanguizhou_first_floor.gd"]
func _initialize() -> void:
 var failures: Array[String] = []
 for path: String in FILES:
  var source_script: GDScript = load(path)
  if source_script == null or not source_script.can_instantiate(): failures.append(path)
 print("INK_E2_TEXT_PARSE ",JSON.stringify({"passed":failures.is_empty(),"scripts":FILES,"failures":failures,"runtime_pass":false}))
 quit(0 if failures.is_empty() else 1)
