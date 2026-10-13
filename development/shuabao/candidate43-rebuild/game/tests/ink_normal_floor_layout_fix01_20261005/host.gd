extends "res://tests/ink_normal_floor_host_20261004/host.gd"
## Opt-in layout only. All authority, input, time and live bindings are inherited.
const VisibleGrowthLayout = preload("res://tests/ink_normal_floor_layout_fix01_20261005/growth_hud.gd")
func _create_session_controls() -> void:
 super._create_session_controls()
 if is_instance_valid(initial_hud): VisibleGrowthLayout.apply_layout(initial_hud)

