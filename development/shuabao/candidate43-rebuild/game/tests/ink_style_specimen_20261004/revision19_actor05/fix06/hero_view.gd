extends "res://tests/ink_style_specimen_20261004/revision19_actor05/fix05/hero_view.gd"
const VisibleTurnLower6=preload("res://tests/ink_style_specimen_20261004/revision19_actor05/fix06/turn_lower.gd")
func _ready() -> void:
	super._ready()
	if proof.status=="HOLD":return
	lower_motion=VisibleTurnLower6.new()
	proof["motion_revision"]="revision19_actor05_fix06_visible_turn_admission"
	proof.new_presentation_parameters["stationary_turn_start_min_degrees"]=5.0
func present(ink: Dictionary) -> void:
	super.present(ink)
	if not sample_report.is_empty():sample_report["turn_admission_revision"]="fix06_5degree_visible_turn_deadzone"
