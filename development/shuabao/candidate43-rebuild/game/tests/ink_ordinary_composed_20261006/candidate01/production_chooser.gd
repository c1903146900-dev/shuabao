extends Control
## Front door only. Identity is catalog-owned; availability is explicit runtime readiness.
signal start_requested(hero_id: String)
signal resume_requested
const Design = preload("res://data/final_design/catalog.gd")
const InkRuntimeText = preload("res://tests/ink_ordinary_composed_20261006/candidate01/runtime_text.gd")
const INK := Color("11181d")
const PANEL := Color("1b242b")
const BRONZE := Color("b99b6b")
const SILVER := Color("dbe1e3")
const MUTED := Color("92a0a7")
const HERO_ORDER := ["xuanlei", "fengli", "yanguizhou", "huling", "hezi", "miluo"]
const ROOMS := {
	"xuanlei": "res://scenes/integration/room.tscn",
	"fengli": "res://scenes/integration/fengli_room.tscn",
	"yanguizhou": "res://scenes/integration/yanguizhou_first_floor.tscn",
}
const ROLES := {
	"xuanlei": "重装近战 · 城门与锁链", "fengli": "机动近战 · 连杀与剑气",
	"yanguizhou": "水墨法术 · 绘线与山河", "huling": "远程火力 · 磁轨与六翼",
	"hezi": "编组作战 · 车厢与蒸汽", "miluo": "吞噬巨兽 · 食质与胃界",
}
const READINESS := {
	"xuanlei": "可进入", "fengli": "测试中", "yanguizhou": "首层候选",
	"huling": "未完成", "hezi": "未完成", "miluo": "未完成",
}
const NOTES := {
	"xuanlei": "当前玄垒竞技场。可进入既有成长、装备与试炼流程；本入口不代表全部内容已完成验收。",
	"fengli": "当前风厉测试关。穿墙判定、延迟伤害与部分成长口径仍待确认；动作、音效与实战体验持续测试中。",
}
var selected_id := "xuanlei"
var hero_buttons: Dictionary = {}
var enter_button: Button
var resume_button: Button
var title_label: Label
var role_label: Label
var status_label: Label
var note_label: Label
var skill_label: Label
var portrait: TextureRect
var portrait_notice: Label
var session_label: Label
var count_label: Label
var _busy := false

static func hero_note(hero_id: String) -> String:
	return InkRuntimeText.hero_note() if hero_id == "yanguizhou" else NOTES.get(hero_id, "该英雄尚未完成，暂不可进入。")

static func can_enter(hero_id: String) -> bool:
	return ROOMS.has(hero_id)

static func make_theme() -> Theme:
	var out := Theme.new()
	out.default_font = preload("res://assets/ui/NotoSansCJKsc-Regular.otf")
	out.default_font_size = 16
	out.set_color("font_color", "Label", SILVER)
	out.set_color("font_color", "Button", SILVER)
	out.set_color("font_disabled_color", "Button", MUTED)
	for kind in ["normal", "hover", "pressed", "focus", "disabled"]:
		out.set_stylebox(kind, "Button", panel_style(Color("28343c") if kind == "hover" else PANEL, BRONZE if kind in ["pressed", "focus"] else Color("49545a")))
	return out

static func panel_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

static func text_label(text: String, font_size: int = 16, color: Color = SILVER) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = make_theme()
	var background := ColorRect.new()
	background.color = INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 42)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	header.add_child(text_label("刷宝", 30, BRONZE))
	var heading := text_label("选择英雄", 26)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("outline_size", 0)
	header.add_child(heading)
	header.add_theme_constant_override("separation", 22)
	count_label = text_label("当前可进入  %d / %d" % [ROOMS.size(), HERO_ORDER.size()], 15, MUTED)
	header.add_child(count_label)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	layout.add_child(body)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	for hero_id in HERO_ORDER: _add_hero_card(grid, hero_id)
	var details := PanelContainer.new()
	details.custom_minimum_size.x = 362
	details.add_theme_stylebox_override("panel", panel_style(PANEL, Color("51493c")))
	body.add_child(details)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	details.add_child(column)
	var portrait_holder := Control.new()
	portrait_holder.custom_minimum_size.y = 180
	column.add_child(portrait_holder)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_holder.add_child(portrait)
	portrait_notice = text_label("角色形象制作中", 15, MUTED)
	portrait_notice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_holder.add_child(portrait_notice)
	title_label = text_label("", 26)
	column.add_child(title_label)
	role_label = text_label("", 15, MUTED)
	column.add_child(role_label)
	status_label = text_label("", 15, BRONZE)
	column.add_child(status_label)
	skill_label = text_label("", 14, SILVER)
	skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(skill_label)
	note_label = text_label("", 14, MUTED)
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(note_label)
	enter_button = Button.new()
	enter_button.name = "EnterHero"
	enter_button.custom_minimum_size.y = 48
	enter_button.pressed.connect(func():
		if not _busy and can_enter(selected_id): start_requested.emit(selected_id))
	column.add_child(enter_button)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 20)
	layout.add_child(footer)
	session_label = text_label("每次开始均为独立新对局；局内可打开装备、技能与测试设置。", 14, MUTED)
	session_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	session_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(session_label)
	resume_button = Button.new()
	resume_button.name = "ResumeRun"
	resume_button.text = "继续当前对局"
	resume_button.custom_minimum_size = Vector2(192, 44)
	resume_button.pressed.connect(func():
		if not _busy: resume_requested.emit())
	footer.add_child(resume_button)
	resume_button.hide()
	select_hero(selected_id)

func _add_hero_card(parent: Control, hero_id: String) -> void:
	var hero: Dictionary = Design.hero(hero_id)
	var button := Button.new()
	button.name = "Hero_" + hero_id
	button.custom_minimum_size = Vector2(0, 234)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.disabled = not can_enter(hero_id)
	button.tooltip_text = hero_note(hero_id)
	button.pressed.connect(select_hero.bind(hero_id))
	parent.add_child(button)
	hero_buttons[hero_id] = button
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	button.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var image_space := Control.new()
	image_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image_space.custom_minimum_size.y = 98
	column.add_child(image_space)
	var texture := _portrait_for(hero_id)
	if texture:
		var art := TextureRect.new()
		art.texture = texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image_space.add_child(art)
	else:
		var placeholder := text_label("角色形象制作中", 14, MUTED)
		placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		image_space.add_child(placeholder)
	column.add_child(text_label(str(hero.get("short_name", hero_id)), 23, SILVER if can_enter(hero_id) else MUTED))
	column.add_child(text_label(ROLES[hero_id], 12, MUTED))
	column.add_child(text_label(READINESS[hero_id], 14, BRONZE if can_enter(hero_id) else MUTED))

func _portrait_for(hero_id: String) -> Texture2D:
	var path := "res://assets/ui/portraits/" + hero_id + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

func select_hero(hero_id: String) -> void:
	if _busy or not can_enter(hero_id): return
	selected_id = hero_id
	if not is_instance_valid(title_label): return
	var hero: Dictionary = Design.hero(hero_id)
	title_label.text = hero.get("name", hero_id)
	role_label.text = ROLES[hero_id]
	status_label.text = READINESS[hero_id]
	note_label.text = hero_note(hero_id)
	skill_label.text = "技能方向  ·  %s / %s / %s" % [hero.skills.Q1.name, hero.skills.Q2.name, hero.skills.Q3.name]
	portrait.texture = _portrait_for(hero_id)
	portrait_notice.visible = portrait.texture == null
	if hero_id == "yanguizhou":
		skill_label.text = InkRuntimeText.skill_line()
		enter_button.text = "进入晏归舟首层候选"
	else:
		enter_button.text = "进入风厉测试关" if hero_id == "fengli" else "以玄垒开始"
	for id in hero_buttons:
		hero_buttons[id].add_theme_stylebox_override("normal", panel_style(Color("222c32") if id == selected_id else PANEL, BRONZE if id == selected_id else Color("3a454c")))

func set_session(hero_name: String = "", test_mode: bool = false) -> void:
	resume_button.visible = not hero_name.is_empty()
	session_label.text = "当前 %s%s对局已暂停。继续保留当前进度；选择英雄开始会先询问是否重开。" % [hero_name, " · 自由测试" if test_mode else ""] if not hero_name.is_empty() else "每次开始均为独立新对局；局内可打开装备、技能与测试设置。"

func set_busy(value: bool) -> void:
	_busy = value
	enter_button.disabled = value or not can_enter(selected_id)
	resume_button.disabled = value
	for id in hero_buttons: hero_buttons[id].disabled = value or not can_enter(id)
