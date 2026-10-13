extends SceneTree
## Exact successor syntax/resources only, no gameplay or native acceptance.
const FILES := ["res://tests/ink_e2_boundary_20261006/ordinary01/boat_view.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/bridge.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/catalog.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/e2_base.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/e2_boundary.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/e2_remainder.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/e_hud.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/finite_gate.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/finite_host.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/floor_session.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/growth_hud.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/host.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/hud_projection.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/input_adapter.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/live_binding.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/navigation_install.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/sim.gd"]
func _initialize() -> void:
 var failures: Array[String] = []
 for path: String in FILES:
  var source_script: GDScript = load(path)
  if source_script == null or not source_script.can_instantiate(): failures.append(path)
 print("INK_E2_ORDINARY_PARSE ",JSON.stringify({"passed":failures.is_empty(),"scripts":FILES,"failures":failures,"runtime_pass":false}))
 quit(0 if failures.is_empty() else 1)
