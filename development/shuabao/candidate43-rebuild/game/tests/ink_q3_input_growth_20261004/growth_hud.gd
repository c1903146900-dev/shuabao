extends "res://tests/ink_initial_hex_ui_20261004/hex_hud.gd"
## Candidate-only source Control. Reuses source typography/Hex cards/adapter.
## Two upward learning columns; does not replace the current shop grid or art.
var q_choices: Dictionary = {}
var growth_panel: PanelContainer
var growth_label: Label
var undo_button: Button
var respec_button: Button

func _ready() -> void:
 super._ready()
 growth_panel = PanelContainer.new(); add_child(growth_panel); move_child(growth_panel, 0)
 growth_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 growth_panel.position = Vector2(22, -252); growth_panel.size = Vector2(420, 228)
 var body := VBoxContainer.new(); growth_panel.add_child(body)
 growth_label = Label.new(); body.add_child(growth_label)
 var columns := HBoxContainer.new(); body.add_child(columns)
 for candidate in ["Q1", "Q3"]:
  var column := VBoxContainer.new(); columns.add_child(column)
  var name_label := Label.new(); column.add_child(name_label)
  var upgrade := Button.new(); upgrade.custom_minimum_size = Vector2(196, 46); column.add_child(upgrade)
  upgrade.pressed.connect(func():
   var skill: Dictionary = adapter.state.get("skills", {}).get("Q", {"rank":0})
   adapter.request("learn", {"slot_id":"Q", "candidate_id":candidate, "expected_rank":int(skill.rank)}))
  q_choices[candidate] = {"name":name_label, "upgrade":upgrade}
 undo_button = Button.new(); undo_button.text = "撤销本次投入"; body.add_child(undo_button)
 undo_button.pressed.connect(func(): adapter.request("undo_new_points"))
 respec_button = Button.new(); respec_button.text = "训练节点洗点"; body.add_child(respec_button)
 respec_button.pressed.connect(func(): adapter.request("respec"))

func present_q_growth(state: Dictionary, definitions: Dictionary) -> void:
 if not is_instance_valid(growth_panel): return
 var learned: Dictionary = state.skills.Q
 growth_label.text = "Lv%d · %d SP · Q最高6阶" % [state.level, state.points]
 var locked: bool = bool(state.get("actor_dead", false)) or not state.pending_milestones.is_empty()
 for candidate in q_choices:
  var index: int = int(str(candidate).right(1)) - 1
  q_choices[candidate].name.text = str(definitions.candidate_names.Q[index])
  var rank: int = int(learned.rank) if learned.candidate == candidate else 0
  var same_or_empty: bool = learned.rank == 0 or learned.candidate == candidate
  var button: Button = q_choices[candidate].upgrade
  button.text = "学习 · 1 SP" if rank == 0 else ("%d / 6 → 升阶 · 1 SP" % rank if rank < 6 else "6 / 6 已满阶")
  button.disabled = locked or state.points < 1 or rank >= 6 or not same_or_empty
  button.tooltip_text = "先在训练节点洗点，才能切换同栏候选" if not same_or_empty else str(definitions.get("skill_descriptions", {}).get(candidate, [""])[mini(rank, 5)])
 undo_button.disabled = locked or state.phase != "safe" or state.allocations.is_empty()
 respec_button.disabled = locked or not state.training or state.phase != "safe"
