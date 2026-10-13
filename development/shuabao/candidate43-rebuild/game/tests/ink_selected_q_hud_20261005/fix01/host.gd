extends "res://tests/ink_normal_floor_layout_fix01_20261005/host.gd"
## Additive post-present seam only. No Sim, input, clock, learning or art replacement.
const SelectedQProjection = preload("res://tests/ink_selected_q_hud_20261005/projection.gd")
const SelectedQHUD = preload("res://tests/ink_selected_q_hud_20261005/fix01/hud_patch.gd")
func _refresh(delta: float) -> void:
 super._refresh(delta)
 if sim != null and is_instance_valid(hud):
  SelectedQHUD.apply_to(hud,sim.snapshot(),sim.ink_presenter_snapshot(),SelectedQProjection.capture_context(sim))
