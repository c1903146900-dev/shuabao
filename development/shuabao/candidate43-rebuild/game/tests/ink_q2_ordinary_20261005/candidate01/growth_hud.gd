extends "res://tests/ink_normal_floor_host_20261004/growth_hud.gd"
## Same Adapter/Controller/Model commands and original safe undo/training buttons.
func _ready() -> void:
 super._ready()
 var columns: HBoxContainer = growth_panel.get_child(0).get_child(1)
 var column := VBoxContainer.new(); columns.add_child(column); columns.move_child(column,1)
 var title := Label.new(); column.add_child(title)
 var upgrade := Button.new(); column.add_child(upgrade)
 upgrade.pressed.connect(func():
  var skill: Dictionary = adapter.state.get("skills",{}).get("Q",{"rank":0})
  adapter.request("learn",{"slot_id":"Q","candidate_id":"Q2","expected_rank":int(skill.rank)}))
 q_choices["Q2"] = {"name":title,"upgrade":upgrade}
 for candidate: String in q_choices:
  q_choices[candidate].upgrade.custom_minimum_size = Vector2(124,46)
  q_choices[candidate].upgrade.add_theme_font_size_override("font_size",12)
  q_choices[candidate].name.add_theme_font_size_override("font_size",13)
  q_choices[candidate].name.custom_minimum_size.x = 124
  q_choices[candidate].name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  q_choices[candidate].name.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func present_q_growth(state: Dictionary, definitions: Dictionary) -> void:
 super.present_q_growth(state,definitions)
 if not q_choices.has("Q2"): return
 q_choices.Q2.name.text = "Q2 · 长河落日"
 q_choices.Q2.name.tooltip_text = "大漠孤烟·长河落日"
 q_choices.Q2.upgrade.tooltip_text += "\nQ → 左键放孤烟；再 Q → 左键放落日。首标窗口5秒，合法二段或超时消标后才起冷却。右键/Esc仅取消瞄准。\nQ2临时功能显示；美术/音频未实现，实机未验；H03/H04未开放"
