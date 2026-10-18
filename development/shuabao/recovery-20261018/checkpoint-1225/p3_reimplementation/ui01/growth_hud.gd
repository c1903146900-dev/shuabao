extends "res://tests/ink_r2_ordinary_20261006/candidate01/growth_hud.gd"
const RiverText=preload("res://tests/ink_river_hexes_20261006/ordinary01/runtime_text.gd")
func present_q_growth(state: Dictionary, definitions: Dictionary) -> void:
 super.present_q_growth(state,definitions)
 _present_p3(state,definitions)
 RiverText.correct_growth(self)
 if not q_choices.has("Q2"): return
 var selected: Array=state.get("selected_hex",[])
 if "yanguizhou_h03" in selected: q_choices.Q2.upgrade.tooltip_text += "\n已选河曲：Q2二段预瞄Ctrl+新左键添最多2折点，普通新左键完成B。"
 if "yanguizhou_h04" in selected:
  q_choices.Q2.upgrade.tooltip_text += "\n已选落日熔金：B点4秒内3.5→1米缩圈，每0.5秒一拍，共8拍，归同次Q2。"
  if is_instance_valid(p1_choice): p1_choice.tooltip_text += "\n已选落日熔金的全部原伤计入同次Q2；等整河与落日均结束才补算。"
  if is_instance_valid(p2_choice): p2_choice.tooltip_text += "\n已选落日熔金沿同Q2的新use资格首正伤消费；旧河旧落日和凑满当招不消费。"

# P3 stays inside the original 420px panel: 142+142+104+16 gaps+16 margins.
var p3_choice: Button
func _ready() -> void:
 super._ready()
 var row: HBoxContainer = p1_choice.get_parent()
 var title: Label = row.get_child(0)
 title.hide()
 p3_choice = Button.new()
 row.add_child(p3_choice)
 p3_choice.custom_minimum_size = Vector2(104,40)
 p3_choice.add_theme_font_size_override("font_size",12)
 p3_choice.mouse_filter = Control.MOUSE_FILTER_STOP
 p3_choice.pressed.connect(func():
  var skill: Dictionary = adapter.state.get("skills",{}).get("P",{"rank":0})
  adapter.request("learn",{"slot_id":"P","candidate_id":"P3","expected_rank":int(skill.rank)}))

func _present_p3(state: Dictionary, definitions: Dictionary) -> void:
 if not is_instance_valid(p3_choice): return
 var skill: Dictionary = state.skills.P
 var rank: int = int(skill.rank) if skill.candidate == "P3" else 0
 var same_or_empty: bool = int(skill.rank) == 0 or skill.candidate == "P3"
 p3_choice.text = "P3 学习1SP" if rank == 0 else ("P3 %d/4 升1SP" % rank if rank < 4 else "P3 4/4 满阶")
 p3_choice.disabled = bool(state.get("actor_dead",false)) or not state.pending_milestones.is_empty() or "P3" not in definitions.get("runtime_candidates",[]) or int(state.points) < 1 or rank >= 4 or not same_or_empty
 var descriptions: Array = definitions.get("skill_descriptions",{}).get("P3",[])
 var detail: String = "P3正式描述缺失"
 if descriptions.size() == 4:
  detail = str(descriptions[maxi(0,rank-1)])
  if rank > 0 and rank < 4: detail += "\n下一阶："+str(descriptions[rank])
 p3_choice.tooltip_text = detail+"\n"+RiverText.p3_rules()
 if not same_or_empty: p3_choice.tooltip_text = "先在训练节点洗点，才能切换同栏候选。\n"+p3_choice.tooltip_text
