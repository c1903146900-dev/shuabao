extends "res://tests/ink_q2_ordinary_20261005/candidate01/growth_hud.gd"
## One E1 learning button through the same Adapter/Controller/Model ledger.
var e1_choice: Button

func _ready() -> void:
 super._ready()
 var columns: HBoxContainer = growth_panel.get_child(0).get_child(1)
 var column := VBoxContainer.new(); columns.add_child(column)
 var title := Label.new(); title.text = "E1 · 一蓑烟雨"; column.add_child(title)
 title.custom_minimum_size.x = 92; title.add_theme_font_size_override("font_size",13)
 title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 e1_choice = Button.new(); column.add_child(e1_choice)
 e1_choice.custom_minimum_size = Vector2(92,46)
 e1_choice.add_theme_font_size_override("font_size",11)
 e1_choice.mouse_filter = Control.MOUSE_FILTER_STOP
 for candidate: String in q_choices:
  q_choices[candidate].upgrade.custom_minimum_size.x = 92
  q_choices[candidate].upgrade.add_theme_font_size_override("font_size",11)
  q_choices[candidate].name.custom_minimum_size.x = 92
 e1_choice.pressed.connect(func():
  var skill: Dictionary = adapter.state.get("skills",{}).get("E",{"rank":0})
  adapter.request("learn",{"slot_id":"E","candidate_id":"E1","expected_rank":int(skill.rank)}))

func present_q_growth(state: Dictionary, definitions: Dictionary) -> void:
 super.present_q_growth(state,definitions)
 if not is_instance_valid(e1_choice): return
 var skill: Dictionary = state.skills.E
 var rank: int = int(skill.rank) if skill.candidate == "E1" else 0
 var same_or_empty: bool = skill.rank == 0 or skill.candidate == "E1"
 var locked: bool = bool(state.get("actor_dead",false)) or not state.pending_milestones.is_empty()
 growth_label.text = "Lv%d · %d SP · Q/E最高6阶" % [state.level,state.points]
 e1_choice.text = ("学习 1 SP" if rank == 0 else ("%d/6 → 升阶 1 SP" % rank if rank < 6 else "6/6 已满阶"))
 e1_choice.disabled = locked or state.points < 1 or rank >= 6 or not same_or_empty
 e1_choice.tooltip_text = str(definitions.get("skill_descriptions",{}).get("E1",[""])[mini(rank,5)]) + "\n按住E直接入形；松开或到时聚形。成功入形起CD一次为既有实现约定。雨痕追加仅最终圈内，随后全清。H07/H08未开放；临时文字显示，无美术/音频验收"
