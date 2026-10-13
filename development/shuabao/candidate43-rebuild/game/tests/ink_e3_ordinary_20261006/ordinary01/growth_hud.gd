extends "res://tests/ink_e2_boundary_20261006/ordinary01/text01/growth_hud.gd"
## Add E3 through the existing Adapter/Controller/Model and original SP ledger.
## Retain every current Q/E1/E2/P1/R1 control and text correction. No Hex row.
const E3RuntimeText = preload("res://tests/ink_e3_ordinary_20261006/ordinary01/runtime_text.gd")
var e3_choice: Button
var e3_rule_hint: Label

func _ready() -> void:
 super._ready()
 var body: VBoxContainer = growth_panel.get_child(0)
 var row := HBoxContainer.new(); body.add_child(row); body.move_child(row,4)
 row.add_theme_constant_override("separation",8)
 var title := Label.new(); title.text = "E3 · 咫尺千里"
 title.custom_minimum_size.x = 190; title.add_theme_font_size_override("font_size",13)
 title.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(title)
 e3_choice = Button.new(); row.add_child(e3_choice)
 e3_choice.custom_minimum_size = Vector2(196,40); e3_choice.add_theme_font_size_override("font_size",12)
 e3_choice.mouse_filter = Control.MOUSE_FILTER_STOP
 e3_choice.pressed.connect(func():
  var skill: Dictionary = adapter.state.get("skills",{}).get("E",{"rank":0})
  adapter.request("learn",{"slot_id":"E","candidate_id":"E3","expected_rank":int(skill.rank)}))
 e3_rule_hint = Label.new(); body.add_child(e3_rule_hint); body.move_child(e3_rule_hint,5)
 e3_rule_hint.add_theme_font_size_override("font_size",12)
 e3_rule_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 e3_rule_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
 e3_rule_hint.text = "E放A，松开后5秒内再E放B。只移动的敌人受伤，近高远低；H11/H12未开放。临时显示"

static func apply_e3_layout(view: Control) -> void:
 # Run after the inherited E2 adjustment so all original controls remain.
 var panel: PanelContainer = view.growth_panel
 panel.custom_minimum_size = Vector2(420,510)
 panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 panel.offset_left = -442; panel.offset_right = -22
 panel.offset_top = -632; panel.offset_bottom = -122

func present_q_growth(state: Dictionary, definitions: Dictionary) -> void:
 super.present_q_growth(state,definitions)
 if not is_instance_valid(e3_choice): return
 var skill: Dictionary = state.skills.E
 var rank: int = int(skill.rank) if skill.candidate == "E3" else 0
 var same_or_empty: bool = int(skill.rank) == 0 or skill.candidate == "E3"
 var locked: bool = bool(state.get("actor_dead",false)) or not state.pending_milestones.is_empty()
 var available: bool = "E3" in definitions.get("runtime_candidates",[])
 e3_choice.text = "学习 · 1 SP" if rank == 0 else ("%d/6 → 升阶 · 1 SP" % rank if rank < 6 else "6/6 已满阶")
 e3_choice.disabled = locked or not available or int(state.points) < 1 or rank >= 6 or not same_or_empty
 var descriptions: Array = definitions.get("skill_descriptions",{}).get("E3",[])
 var detail: String = str(descriptions[mini(rank,5)]) if descriptions.size() == 6 else "原E3六阶描述不可用"
 if not same_or_empty: detail = "先在训练节点洗点，才能切换同栏候选。\n" + detail
 e3_choice.tooltip_text = detail + "\nE在鼠标位置放A；松开后5秒内再E放B，无需左键确认。Q/R预瞄或左键未松开时不能同时确认E3。只移动普通/精英敌人；Boss、自身与队友不交换，只有实际移动的敌人受伤，2米内最高，之后线性降低至最大交换距离最低。\n可隔墙交换；任一实际参与者必需落点非法则整次拒绝，保留A原剩余窗口，不另起CD。A不开始CD；原窗口到期消标或合法完成B时开始CD。暂停冻结，回菜单后先松开E；H11/H12均未开放。临时功能圆与文字；最终美术与音效未完成。"
 E3RuntimeText.correct_growth(self)
 e3_rule_hint.tooltip_text = e3_choice.tooltip_text
