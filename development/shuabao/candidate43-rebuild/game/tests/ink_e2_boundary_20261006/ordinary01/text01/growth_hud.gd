extends "res://tests/ink_e2_boundary_20261006/ordinary01/growth_hud.gd"
## Same controls, signals, eligibility and commands; correct displayed text only.
const RuntimeText = preload("res://tests/ink_e2_boundary_20261006/ordinary01/text01/runtime_text.gd")
func present_q_growth(state: Dictionary, definitions: Dictionary) -> void:
 super.present_q_growth(state,definitions)
 RuntimeText.correct_growth(self)
