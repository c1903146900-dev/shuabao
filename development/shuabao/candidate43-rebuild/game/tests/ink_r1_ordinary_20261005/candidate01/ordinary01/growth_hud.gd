extends "res://tests/ink_e1_ordinary_20261005/candidate01/growth_hud.gd"
## One extra row through the original Controller/Model. No grants or local ranks.
var r1_choice: Button
func _ready() -> void:
 super._ready()
 var body: VBoxContainer = growth_panel.get_child(0)
 var row := HBoxContainer.new(); body.add_child(row); body.move_child(row,2)
 row.add_theme_constant_override("separation",8)
 var title := Label.new(); title.text = "R1 · 独钓寒江雪"; title.custom_minimum_size.x = 190
 title.add_theme_font_size_override("font_size",13); title.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(title)
 r1_choice = Button.new(); r1_choice.custom_minimum_size = Vector2(196,40); r1_choice.add_theme_font_size_override("font_size",12)
 r1_choice.mouse_filter = Control.MOUSE_FILTER_STOP; row.add_child(r1_choice)
 r1_choice.pressed.connect(func():
  var skill: Dictionary = adapter.state.get("skills",{}).get("R",{"rank":0})
  adapter.request("learn",{"slot_id":"R","candidate_id":"R1","expected_rank":int(skill.rank)}))

static func apply_r_layout(view: Control) -> void:
 # The retained host applies its420x228 layout AFTER _ready. Apply this successor
 # only after that call, extending upward without adding a fifth Q/E column.
 var panel: PanelContainer = view.growth_panel
 var wanted: Vector2 = Vector2(420,280)
 panel.custom_minimum_size = wanted
 panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 panel.offset_left = -442; panel.offset_right = -22
 panel.offset_top = -122-wanted.y; panel.offset_bottom = -122

func present_q_growth(state: Dictionary, definitions: Dictionary) -> void:
 super.present_q_growth(state,definitions)
 if not is_instance_valid(r1_choice): return
 var skill: Dictionary = state.skills.R
 var rank: int = int(skill.rank) if skill.candidate == "R1" else 0
 var cost: int = 1 if rank == 0 else 2
 var learned_or_empty: bool = int(skill.rank) == 0 or skill.candidate == "R1"
 var locked: bool = bool(state.get("actor_dead",false)) or not state.pending_milestones.is_empty()
 var available: bool = "R1" in definitions.get("runtime_candidates",[])
 growth_label.text = "Lv%d · %d SP · Q/E最高6阶 · R最高4阶" % [state.level,state.points]
 r1_choice.text = "6级解锁 · 1 SP" if int(state.level) < 6 else ("学习 · 1 SP" if rank == 0 else ("%d/4 → 升阶 · 2 SP" % rank if rank < 4 else "4/4 已满阶"))
 r1_choice.disabled = locked or not available or int(state.level) < 6 or int(state.points) < cost or rank >= 4 or not learned_or_empty
 var descriptions: Array = definitions.get("skill_descriptions",{}).get("R1",[])
 r1_choice.tooltip_text = (str(descriptions[mini(rank,3)]) if descriptions.size() == 4 else "原R1四阶描述不可用") + "\nR预瞄→新左键确认；右键/Esc取消预瞄。首次英雄6级学习1SP，之后每阶2SP且无额外等级门。H13/H14未开放；临时功能圈，雪景美术和音频未完成"
