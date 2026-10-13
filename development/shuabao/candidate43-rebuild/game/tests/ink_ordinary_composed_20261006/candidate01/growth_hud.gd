extends "res://tests/ink_p2_ordinary_20261006/ordinary01/growth_hud.gd"
## Preserve P1/P2 row, four-rank costs and all E3 controls; add truthful R text.
const CombinedRuntimeText = preload("res://tests/ink_ordinary_composed_20261006/candidate01/runtime_text.gd")
func present_q_growth(state: Dictionary, definitions: Dictionary) -> void:
 super.present_q_growth(state,definitions)
 if is_instance_valid(p2_choice): CombinedRuntimeText.correct_growth(self)
