extends "res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/growth_hud.gd"
## E2 uses the same Adapter/Controller/Model and the original SP ledger.
var e2_choice: Button
var e2_rule_hint: Label

func _ready() -> void:
 super._ready()
 var body: VBoxContainer = growth_panel.get_child(0)
 var row := HBoxContainer.new(); body.add_child(row); body.move_child(row,2)
 row.add_theme_constant_override("separation",8)
 var title := Label.new(); title.text = "E2 · 孤帆远影"
 title.custom_minimum_size.x = 190; title.add_theme_font_size_override("font_size",13)
 title.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(title)
 e2_choice = Button.new(); row.add_child(e2_choice)
 e2_choice.custom_minimum_size = Vector2(196,40); e2_choice.add_theme_font_size_override("font_size",12)
 e2_choice.mouse_filter = Control.MOUSE_FILTER_STOP
 e2_choice.pressed.connect(func():
  var skill: Dictionary = adapter.state.get("skills",{}).get("E",{"rank":0})
  adapter.request("learn",{"slot_id":"E","candidate_id":"E2","expected_rank":int(skill.rank)}))
 e2_rule_hint = Label.new(); body.add_child(e2_rule_hint); body.move_child(e2_rule_hint,3)
 e2_rule_hint.add_theme_font_size_override("font_size",12)
 e2_rule_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 e2_rule_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
 e2_rule_hint.text = "E朝鼠标发舟，松开后再E登舟。触边停留，按原时间消散；落点站不下就保留原船。临时显示"

static func apply_e2_layout(view: Control) -> void:
 # Ancestor hosts apply their own layout after _ready; this final adjustment
 # makes room for the real E2 row without changing any Q/E1/P1/R1 buttons.
 var panel: PanelContainer = view.growth_panel
 panel.custom_minimum_size = Vector2(420,420)
 panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 panel.offset_left = -442; panel.offset_right = -22
 panel.offset_top = -542; panel.offset_bottom = -122

func present_q_growth(state: Dictionary, definitions: Dictionary) -> void:
 super.present_q_growth(state,definitions)
 if not is_instance_valid(e2_choice): return
 var skill: Dictionary = state.skills.E
 var rank: int = int(skill.rank) if skill.candidate == "E2" else 0
 var same_or_empty: bool = int(skill.rank) == 0 or skill.candidate == "E2"
 var locked: bool = bool(state.get("actor_dead",false)) or not state.pending_milestones.is_empty()
 var available: bool = "E2" in definitions.get("runtime_candidates",[])
 e2_choice.text = "学习 · 1 SP" if rank == 0 else ("%d/6 → 升阶 · 1 SP" % rank if rank < 6 else "6/6 已满阶")
 e2_choice.disabled = locked or not available or int(state.points) < 1 or rank >= 6 or not same_or_empty
 var descriptions: Array = definitions.get("skill_descriptions",{}).get("E2",[])
 var detail: String = str(descriptions[mini(rank,5)]) if descriptions.size() == 6 else "原E2六阶描述不可用"
 detail = detail.replace("规则已确认；该技能尚未实现。","基础E2已接入；美术与音效未完成。")
 if not same_or_empty: detail = "先在训练节点洗点，才能切换同栏候选。\n" + detail
 e2_choice.tooltip_text = detail + "\nE朝鼠标方向发舟；松开后再次E登到小舟当前位置，无需左键确认。1.1米宽的船头首次碰到房间边界就原地停留，不沿边滑行，仍按原时间消散，冷却不变；小舟可穿墙。落点在墙内或站不下时，拒绝登舟并保留原船，人物不会被移到别处。暂停时计时冻结；H09/H10均未开放。临时功能显示，最终美术和音效未完成。"
 e2_rule_hint.tooltip_text = e2_choice.tooltip_text
