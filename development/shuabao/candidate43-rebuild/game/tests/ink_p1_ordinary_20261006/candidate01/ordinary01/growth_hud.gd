extends "res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/growth_hud.gd"
## One passive row through the SAME Adapter/Controller/Model and original SP.
var p1_choice: Button
func _ready() -> void:
 super._ready()
 var body: VBoxContainer = growth_panel.get_child(0)
 var row := HBoxContainer.new(); body.add_child(row); body.move_child(row,2)
 row.add_theme_constant_override("separation",8)
 var title := Label.new(); title.text = "P1 · 计白当黑"; title.custom_minimum_size.x = 190
 title.add_theme_font_size_override("font_size",13); title.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(title)
 p1_choice = Button.new(); p1_choice.custom_minimum_size = Vector2(196,40); p1_choice.add_theme_font_size_override("font_size",12)
 p1_choice.mouse_filter = Control.MOUSE_FILTER_STOP; row.add_child(p1_choice)
 p1_choice.pressed.connect(func():
  var skill: Dictionary = adapter.state.get("skills",{}).get("P",{"rank":0})
  adapter.request("learn",{"slot_id":"P","candidate_id":"P1","expected_rank":int(skill.rank)}))

static func apply_p_layout(view: Control) -> void:
 # All ancestors apply their own layout after _ready. Add one upward row only
 # after their existing session-control construction, keeping bottom clearance.
 var panel: PanelContainer = view.growth_panel
 var wanted: Vector2 = Vector2(420,328)
 panel.custom_minimum_size = wanted
 panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 panel.offset_left = -442; panel.offset_right = -22
 panel.offset_top = -122-wanted.y; panel.offset_bottom = -122

func present_q_growth(state: Dictionary, definitions: Dictionary) -> void:
 super.present_q_growth(state,definitions)
 if not is_instance_valid(p1_choice): return
 var skill: Dictionary = state.skills.P
 var rank: int = int(skill.rank) if skill.candidate == "P1" else 0
 var same_or_empty: bool = int(skill.rank) == 0 or skill.candidate == "P1"
 var locked: bool = bool(state.get("actor_dead",false)) or not state.pending_milestones.is_empty()
 var available: bool = "P1" in definitions.get("runtime_candidates",[])
 growth_label.text = "Lv%d · %d SP · Q/E最高6阶 · P/R最高4阶" % [state.level,state.points]
 p1_choice.text = "学习 · 1 SP" if rank == 0 else ("%d/4 → 升阶 · 1 SP" % rank if rank < 4 else "4/4 已满阶")
 p1_choice.disabled = locked or not available or int(state.points) < 1 or rank >= 4 or not same_or_empty
 var descriptions: Array = definitions.get("skill_descriptions",{}).get("P1",[])
 var detail: String = "原P1四阶描述不可用"
 if descriptions.size() == 4:
  detail = "当前："+str(descriptions[rank-1]) if rank > 0 else "学习后："+str(descriptions[0])
  if rank > 0 and rank < 4: detail += "\n下一阶："+str(descriptions[rank])
 p1_choice.tooltip_text = detail + "\n每阶1SP，上限4阶。整次Q/E伤害阶段结束后判定一次；不提前击杀，不计R1/BASIC。补算实际伤害按原Q/E面积系数参与已有吸血。P2/P3及未接强化未开放。"
