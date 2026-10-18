extends "res://tests/ink_r2_ordinary_20261006/candidate01/growth_hud.gd"
const RiverText=preload("res://tests/ink_river_hexes_20261006/ordinary01/runtime_text.gd")
func present_q_growth(state: Dictionary, definitions: Dictionary) -> void:
 super.present_q_growth(state,definitions)
 RiverText.correct_growth(self)
 if not q_choices.has("Q2"): return
 var selected: Array=state.get("selected_hex",[])
 if "yanguizhou_h03" in selected: q_choices.Q2.upgrade.tooltip_text += "\n已选河曲：Q2二段预瞄Ctrl+新左键添最多2折点，普通新左键完成B。"
 if "yanguizhou_h04" in selected:
  q_choices.Q2.upgrade.tooltip_text += "\n已选落日熔金：B点4秒内3.5→1米缩圈，每0.5秒一拍，共8拍，归同次Q2。"
  if is_instance_valid(p1_choice): p1_choice.tooltip_text += "\n已选落日熔金的全部原伤计入同次Q2；等整河与落日均结束才补算。"
  if is_instance_valid(p2_choice): p2_choice.tooltip_text += "\n已选落日熔金沿同Q2的新use资格首正伤消费；旧河旧落日和凑满当招不消费。"
