extends "res://tests/ink_e3_ordinary_20261006/ordinary01/growth_hud.gd"
## One existing P row, two mutually exclusive original Model candidates.
const P2RuntimeText = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/runtime_text.gd")
var p2_choice: Button

func _ready() -> void:
 super._ready()
 var row: HBoxContainer = p1_choice.get_parent()
 var title: Label = row.get_child(0)
 title.text = "P · 被动择一"; title.custom_minimum_size.x = 104
 p1_choice.custom_minimum_size.x = 142
 p2_choice = Button.new(); row.add_child(p2_choice)
 p2_choice.custom_minimum_size = Vector2(142,40)
 p2_choice.add_theme_font_size_override("font_size",12)
 p2_choice.mouse_filter = Control.MOUSE_FILTER_STOP
 p2_choice.pressed.connect(func():
  var skill: Dictionary = adapter.state.get("skills",{}).get("P",{"rank":0})
  adapter.request("learn",{"slot_id":"P","candidate_id":"P2","expected_rank":int(skill.rank)}))

func present_q_growth(state: Dictionary, definitions: Dictionary) -> void:
 super.present_q_growth(state,definitions)
 if not is_instance_valid(p2_choice): return
 var skill: Dictionary = state.skills.P
 var rank: int = int(skill.rank) if skill.candidate == "P2" else 0
 var same_or_empty: bool = int(skill.rank) == 0 or skill.candidate == "P2"
 var locked: bool = bool(state.get("actor_dead",false)) or not state.pending_milestones.is_empty()
 var available: bool = "P2" in definitions.get("runtime_candidates",[])
 p1_choice.text = "P1 · "+p1_choice.text
 p2_choice.text = "P2 · 学习 1SP" if rank == 0 else ("P2 %d/4 · 升1SP"%rank if rank < 4 else "P2 4/4 已满阶")
 p2_choice.disabled = locked or not available or int(state.points) < 1 or rank >= 4 or not same_or_empty
 var descriptions: Array = definitions.get("skill_descriptions",{}).get("P2",[])
 var detail: String = "原P2四阶描述不可用"
 if descriptions.size() == 4:
  detail = "当前："+str(descriptions[rank-1]) if rank > 0 else "学习后："+str(descriptions[0])
  if rank > 0 and rank < 4: detail += "\n下一阶："+str(descriptions[rank])
 if not same_or_empty: detail = "先在训练节点洗点，才能切换同栏候选。\n"+detail
 p2_choice.tooltip_text = detail+"\n"+P2RuntimeText.p2_rules()+"\nE3先放A时保留原技能伤害快照，成功B才算一次使用；临时功能显示，最终美术与音效未完成。"
 P2RuntimeText.correct_growth(self)
