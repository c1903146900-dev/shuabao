extends "res://tests/ink_ordinary_composed_20261006/candidate01/growth_hud.gd"
## Both ultimates use the original single R slot and authoritative Controller.
const R2OrdinaryText = preload("res://tests/ink_r2_ordinary_20261006/candidate01/runtime_text.gd")
var r2_choice: Button

func _ready() -> void:
 super._ready()
 var row: HBoxContainer = r1_choice.get_parent()
 var title: Label = row.get_child(0)
 title.text = "R · 大招择一"; title.custom_minimum_size.x = 104
 r1_choice.custom_minimum_size.x = 142
 r2_choice = Button.new(); row.add_child(r2_choice)
 r2_choice.custom_minimum_size = Vector2(142,40)
 r2_choice.add_theme_font_size_override("font_size",12)
 r2_choice.mouse_filter = Control.MOUSE_FILTER_STOP
 r2_choice.pressed.connect(func():
  var skill: Dictionary = adapter.state.get("skills",{}).get("R",{"rank":0})
  adapter.request("learn",{"slot_id":"R","candidate_id":"R2","expected_rank":int(skill.rank)}))

static func apply_r2_layout(view: Control) -> void:
 var panel: PanelContainer = view.growth_panel
 panel.custom_minimum_size.x = maxf(panel.custom_minimum_size.x,420.0)

func present_q_growth(state: Dictionary, definitions: Dictionary) -> void:
 super.present_q_growth(state,definitions)
 if not is_instance_valid(r2_choice): return
 var skill: Dictionary = state.skills.R
 var locked: bool = bool(state.get("actor_dead",false)) or not state.pending_milestones.is_empty()
 for candidate: String in ["R1","R2"]:
  var button: Button = r1_choice if candidate == "R1" else r2_choice
  var rank: int = int(skill.rank) if skill.candidate == candidate else 0
  var same_or_empty: bool = int(skill.rank) == 0 or skill.candidate == candidate
  var cost: int = 1 if rank == 0 else 2
  var level_blocked: bool = rank == 0 and int(state.level) < 6
  button.text = candidate+" · "+("Lv6 / 1SP" if level_blocked else ("学习 1SP" if rank == 0 else ("%d/4 · 升2SP"%rank if rank < 4 else "4/4 已满阶")))
  button.disabled = locked or candidate not in definitions.get("runtime_candidates",[]) or level_blocked or int(state.points) < cost or rank >= 4 or not same_or_empty
  var descriptions: Array = definitions.get("skill_descriptions",{}).get(candidate,[])
  var detail: String = str(descriptions[mini(rank,3)]) if descriptions.size() == 4 else "技能来源不可用"
  if not same_or_empty: detail = "先在训练节点洗点，才能切换同栏候选。\n"+detail
  button.tooltip_text = detail+"\nR预瞄→新左键确认；右键/Esc取消。R1/R2同栏互斥；四阶费用1/2/2/2，只有首学要求英雄6级。"
 R2OrdinaryText.correct_growth(self)
