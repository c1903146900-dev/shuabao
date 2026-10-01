extends Control
## Standalone HUD. No HP, cooldown, XP or point simulation happens here.
const Adapter = preload("res://scripts/ui/hud_adapter.gd")
const INK := Color("101c27")
const TEAL := Color("81ead8")
const GOLD := Color("ebcb87")
const MUTED := Color("a6bac6")
const CANDIDATES := {
	"Q": ["短矩形突刺", "连续锁敌突袭", "长矩形剑气"],
	"E": ["追踪匕首", "旋斩与瞬移", "超载"],
	"R": ["巨圆乱剑", "累计普攻骨钉"],
	"P": ["普攻吸血", "残血反打", "击杀成长"]}
const CAPS := {"Q": 5, "E": 5, "R": 3, "P": 3}
var adapter = Adapter.new()
var state: Dictionary = {}
var hp: ProgressBar
var xp: ProgressBar
var health_text: Label
var identity: Label
var progress_text: Label
var gold_text: Label
var provenance: Label
var notice: Label
var slots: Dictionary = {}
var equipment: Array[Button] = []
var allocation: Button
var shade: ColorRect
var panel: PanelContainer
var rows: Dictionary = {}
var point_label: Label
var undo_button: Button
var result_box: PanelContainer
var result_text: Label
var close_button: Button
var old_focus: Control
var focus_chain: Array[Control] = []
var feedback_layer: Control
var notice_tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := Theme.new()
	t.default_font = preload("res://assets/ui/NotoSansCJKsc-Regular.otf")
	t.default_font_size = 16
	t.set_color("font_color", "Label", Color("eaf4f5"))
	for kind in ["normal", "hover", "pressed", "focus", "disabled"]:
		var color := INK if kind != "hover" else Color("234653")
		var edge := TEAL if kind == "focus" else Color("3c5c6c")
		t.set_stylebox(kind, "Button", box(color, edge))
		t.set_stylebox(kind, "OptionButton", box(color, edge))
	t.set_color("font_color", "Button", Color("ecf4ef"))
	t.set_color("font_disabled_color", "Button", MUTED)
	theme = t
	var stats := card(Vector2(24, 24), Vector2(310, 130))
	var v := column(stats)
	identity = label(v, "风厉  /  LV. 01", 23, TEAL)
	health_text = label(v, "生命", 16)
	hp = bar(v, Color("4fcab5"), 13)
	xp = bar(v, GOLD, 4)
	provenance = label(v, "等待战斗状态", 12, MUTED)
	var route := card(Vector2(-280, 24), Vector2(256, 100), Vector2(1, 0))
	var rv := column(route)
	progress_text = label(rv, "房间 / 波次", 18)
	gold_text = label(rv, "金币  0", 21, GOLD)
	var skill_row := HBoxContainer.new()
	add_child(skill_row)
	skill_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	skill_row.offset_left = -303
	skill_row.offset_top = -133
	skill_row.offset_right = 303
	skill_row.offset_bottom = -25
	skill_row.add_theme_constant_override("separation", 8)
	for slot in ["Q", "E", "R", "Shift", "P"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(114, 108)
		b.pressed.connect(_slot_request.bind(slot))
		skill_row.add_child(b)
		slots[slot] = b
	allocation = Button.new()
	add_child(allocation)
	allocation.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	allocation.offset_left = 24
	allocation.offset_top = -83
	allocation.offset_right = 284
	allocation.offset_bottom = -25
	allocation.pressed.connect(open_allocation)
	var pack := card(Vector2(-264, -145), Vector2(240, 120), Vector2(1, 1))
	var pv := column(pack)
	label(pv, "行装  /  6 槽含药品", 14, MUTED)
	var grid := GridContainer.new()
	grid.columns = 3
	pv.add_child(grid)
	for i in range(6):
		var b := Button.new()
		b.custom_minimum_size = Vector2(68, 34)
		b.pressed.connect(func(): adapter.request("item", {"slot_index": i}))
		grid.add_child(b)
		equipment.append(b)
	notice = label(self, "", 19, GOLD)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left = -285
	notice.offset_top = 42
	notice.offset_right = 285
	notice.offset_bottom = 78
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_layer = Control.new()
	add_child(feedback_layer)
	feedback_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	feedback_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_panels()
	adapter.snapshot_changed.connect(render)
	adapter.feedback_emitted.connect(show_feedback)

func box(fill: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	return s

func card(pos: Vector2, dimensions: Vector2, anchor := Vector2.ZERO) -> PanelContainer:
	var c := PanelContainer.new()
	add_child(c)
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + dimensions.x
	c.offset_bottom = pos.y + dimensions.y
	c.add_theme_stylebox_override("panel", box(INK, Color("365361")))
	return c

func column(parent: Node) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	parent.add_child(v)
	return v

func label(parent: Node, text: String, font_size := 16, color := Color("eaf4f5")) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func bar(parent: Node, color: Color, height: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size.y = height
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := box(Color("293c49"), Color.TRANSPARENT)
	background.content_margin_top = 0
	background.content_margin_bottom = 0
	b.add_theme_stylebox_override("background", background)
	var fill := box(color, Color.TRANSPARENT)
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	b.add_theme_stylebox_override("fill", fill)
	parent.add_child(b)
	return b

func _build_panels() -> void:
	shade = ColorRect.new()
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.025, 0.04, 0.66)
	shade.hide()
	panel = card(Vector2(-617, 154), Vector2(593, 415), Vector2(1, 0))
	var v := column(panel)
	var heading := HBoxContainer.new()
	v.add_child(heading)
	var title := label(heading, "剑技修习", 26, TEAL)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = Button.new()
	close_button.text = "关闭  Esc"
	heading.add_child(close_button)
	close_button.pressed.connect(close_panels)
	point_label = label(v, "", 18, GOLD)
	label(v, "学习时选一项 · 升级仅数值成长 · 战斗不会暂停", 14, MUTED)
	for slot in ["Q", "E", "R", "P"]:
		var row := HBoxContainer.new()
		v.add_child(row)
		var key := label(row, slot if slot != "P" else "被动", 18, TEAL)
		key.custom_minimum_size.x = 42
		var options := OptionButton.new()
		options.custom_minimum_size.x = 192
		for candidate in CANDIDATES[slot]:
			options.add_item(candidate)
		row.add_child(options)
		var rank := label(row, "0 / 5", 16)
		rank.custom_minimum_size.x = 55
		var buy := Button.new()
		buy.custom_minimum_size.x = 125
		row.add_child(buy)
		buy.pressed.connect(func():
			adapter.request("learn", {"slot_id": slot, "candidate_id": "%s%d" % [slot, options.selected + 1], "expected_rank": int(state.get("skills", {}).get(slot, {}).get("rank", 0))}))
		var reason := label(v, "", 14, MUTED)
		rows[slot] = {"options": options, "rank": rank, "buy": buy, "reason": reason}
	undo_button = Button.new()
	undo_button.text = "撤销本场新点数（由成长系统校验）"
	undo_button.pressed.connect(func(): adapter.request("undo_new_points"))
	v.add_child(undo_button)
	label(v, "旧技能仅训练节点重配；撤销不恢复生命或冷却。", 14, MUTED)
	panel.hide()
	result_box = card(Vector2(-230, -175), Vector2(460, 350), Vector2(0.5, 0.5))
	var end := column(result_box)
	label(end, "战斗结算", 30, TEAL)
	result_text = label(end, "", 20)
	var done := Button.new()
	done.text = "返回战场视图  /  Esc"
	done.pressed.connect(close_panels)
	end.add_child(done)
	done.focus_next = NodePath(".")
	done.focus_previous = NodePath(".")
	result_box.hide()

func render(snapshot: Dictionary) -> void:
	state = snapshot.duplicate(true)
	identity.text = "风厉  /  LV. %02d" % int(state.get("level", 1))
	health_text.text = "生命  %d / %d" % [state.get("hp", 0), state.get("hp_max", 1)]
	hp.max_value = maxf(1, state.get("hp_max", 1))
	hp.value = state.get("hp", 0)
	xp.max_value = maxf(1, state.get("xp_next", 1))
	xp.value = state.get("xp", 0)
	provenance.text = "%s · 经验 %d / %d" % [state.get("source_label", "状态未接入"), state.get("xp", 0), state.get("xp_next", 1)]
	progress_text.text = "%s  ·  波次 %s" % [state.get("room", "—"), state.get("wave", "—")]
	gold_text.text = "金币  %s" % state.get("gold", 0)
	allocation.text = "修习  [ K ]   ·   剩余 %d 点" % state.get("points", 0)
	for slot in slots:
		var skill: Dictionary = state.get("skills", {}).get(slot, {})
		var cd := float(skill.get("cooldown", 0.0))
		var status := str(skill.get("reason", "就绪"))
		if cd > 0:
			status = (status + "\n" if status != "就绪" else "") + "冷却 %.1fs" % cd
		var rank_text := "固定" if slot == "Shift" else "Lv.%d" % skill.get("rank", 0)
		slots[slot].text = "%s   %s\n%s\n%s" % [slot if slot != "P" else "被动", rank_text, skill.get("name", "未学习"), status]
		slots[slot].tooltip_text = str(skill.get("description", status))
	for i in range(6):
		var items: Array = state.get("equipment", [])
		var item: Dictionary = items[i] if i < items.size() else {}
		equipment[i].text = str(item.get("name", "空槽"))
		equipment[i].tooltip_text = str(item.get("description", "未装备"))
	if panel.visible:
		_render_allocation()

func _render_allocation() -> void:
	point_label.text = "本局授点 %d / 18   ·   剩余 %d 点" % [state.get("level", 1), state.get("points", 0)]
	for slot in rows:
		var row: Dictionary = rows[slot]
		var skill: Dictionary = state.get("skills", {}).get(slot, {})
		var rank := int(skill.get("rank", 0))
		var cost := 2 if slot == "R" and rank > 0 else 1
		row.rank.text = "%d / %d" % [rank, CAPS[slot]]
		row.options.disabled = rank > 0
		if rank > 0:
			row.options.selected = clampi(int(skill.get("candidate_index", 0)), 0, CANDIDATES[slot].size() - 1)
		var reason := str(skill.get("upgrade_reason", ""))
		if rank >= CAPS[slot]:
			reason = "已满阶"
		elif slot == "R" and int(state.get("level", 1)) < 6:
			reason = "6级可学习"
		elif int(state.get("points", 0)) < cost:
			reason = "点数不足"
		row.buy.text = ("学习" if rank == 0 else "升级") + "  ·  %d点" % cost
		row.buy.disabled = not reason.is_empty()
		row.reason.text = reason if not reason.is_empty() else ("R耗点 1 / 2 / 2 · 后两阶门槛由系统校验" if slot == "R" else "每阶1点 · 升级仅成长数值")
	undo_button.disabled = not state.get("can_undo", false)
	focus_chain = [close_button]
	for slot in rows:
		for field in ["options", "buy"]:
			var control: Control = rows[slot][field]
			if not control.disabled:
				focus_chain.append(control)
	if not undo_button.disabled:
		focus_chain.append(undo_button)
	for i in range(focus_chain.size()):
		var control := focus_chain[i]
		control.focus_next = control.get_path_to(focus_chain[(i + 1) % focus_chain.size()])
		control.focus_previous = control.get_path_to(focus_chain[(i - 1 + focus_chain.size()) % focus_chain.size()])

func _slot_request(slot: String) -> void:
	if slot == "P":
		open_allocation()
	else:
		adapter.request("ability", {"slot_id": slot})

func open_allocation() -> void:
	if panel.visible:
		close_panels()
		return
	old_focus = get_viewport().gui_get_focus_owner()
	result_box.hide()
	shade.show()
	panel.show()
	_render_allocation()
	close_button.grab_focus()

func close_panels() -> void:
	panel.hide()
	result_box.hide()
	shade.hide()
	if is_instance_valid(old_focus) and old_focus.is_visible_in_tree():
		old_focus.grab_focus()
	else:
		allocation.grab_focus()

func show_result(summary: Dictionary) -> void:
	old_focus = get_viewport().gui_get_focus_owner()
	panel.hide()
	shade.show()
	result_box.show()
	result_text.text = "%s\n\n击败敌人   %d\n本场金币   +%d\n本场经验   +%d\n\n%s" % [summary.get("title", "战斗结束"), summary.get("kills", 0), summary.get("gold", 0), summary.get("xp", 0), summary.get("source_label", "")]
	result_box.get_child(0).get_child(2).grab_focus()

func show_feedback(event: Dictionary) -> void:
	if event.get("kind", "") == "damage":
		var l := label(feedback_layer, str(event.get("text", "0")), 30, GOLD if event.get("critical", false) else Color.WHITE)
		l.position = Vector2(event.get("screen_x", size.x * 0.5), event.get("screen_y", size.y * 0.43))
		var tw := create_tween().set_parallel()
		tw.tween_property(l, "position:y", l.position.y - 60, 0.7)
		tw.tween_property(l, "modulate:a", 0.0, 0.7)
		tw.chain().tween_callback(l.queue_free)
	else:
		notice.text = str(event.get("text", ""))
		notice.modulate.a = 1.0
		if notice_tween and notice_tween.is_valid():
			notice_tween.kill()
		notice_tween = create_tween()
		notice_tween.tween_interval(1.5)
		notice_tween.tween_property(notice, "modulate:a", 0.0, 0.4)

func blocks_gameplay_input() -> bool:
	return shade.visible or get_viewport().gui_get_hovered_control() != null

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and shade.visible:
			close_panels()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_K:
			open_allocation()
			get_viewport().set_input_as_handled()
