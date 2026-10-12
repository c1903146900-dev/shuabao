extends Control
## 009 Chinese visual editor. All state changes go through EditorDocument.
## This UI draws explicit technical proxies, not art, AI, combat or physics.
const EditorDocument = preload("res://scripts/prefab_editor/editor_document.gd")
const EditorCanvas = preload("res://scripts/prefab_editor/editor_canvas.gd")
const DEFAULT_TEMPLATE := "fixture_editor_room"
const TOOLS := [
	["wall", "墙体", "H1 阻挡技术代理"],
	["floor", "地板", "H0 覆盖层技术代理"],
	["container", "容器", "容器代理及同层绑定锚点"],
	["boss", "Boss", "Boss 代理及同层绑定锚点，无 AI 或战斗"],
	["spawn", "出生锚", "设置当前层出生锚点"],
	["entry", "配对入口", "当前层连接到下一层，同 XY；3×3 本体、7×7 安全区"],
	["erase", "擦除", "逐次擦除实体、地板或锚点；入口整对删除，保留基础地面"]
]
var document: RefCounted
var active_depth: int = 0
var active_tool: String = "wall"
var _template_id: LineEdit
var _saved_list: ItemList
var _layer_select: OptionButton
var _tool_buttons: Dictionary = {}
var _toolbar_buttons: Array[Button] = []
var _edit_canvas: Control
var _preview_canvas: Control
var _document_info: Label
var _preview_info: Label
var _edit_hover: Label
var _preview_hover: Label
var _tool_help: Label
var _status: Label
var _diagnostic: Label
var _last_event: Label
var _discard_dialog: ConfirmationDialog
var _pending_action: Dictionary = {}
var _event_sequence: int = 0
var _ui_ready: bool = false

func _ready() -> void:
	get_window().title = "沙盒009预制编辑器"
	get_window().min_size = Vector2i(1152, 720)
	get_window().size = Vector2i(1280, 800)
	get_tree().auto_accept_quit = false
	_build_theme()
	_build_ui()
	var generation: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/generation_settings.json"))
	var prefab: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/prefab_settings.json"))
	if not generation is Dictionary or not prefab is Dictionary:
		_startup_failed("EDITOR_INPUTS_NOT_READY")
		return
	document = EditorDocument.new(generation, prefab)
	if not document.ready:
		_startup_failed(document.last_error)
		return
	var initial: Dictionary
	# Never overwrite or bypass a corrupt saved default on startup.
	if DEFAULT_TEMPLATE in document.saved_template_ids():
		initial = document.open_template(DEFAULT_TEMPLATE)
	else:
		initial = document.new_template(DEFAULT_TEMPLATE)
	if not initial.get("ok", false):
		_startup_failed(str(initial.get("code", "EDITOR_OPERATION_FAILED")))
		return
	_ui_ready = true
	_refresh_saved_list()
	_sync_views()
	_set_status("已准备好。左图绘制房间，保存后可打开；点击“测试实例”查看右图", false)
	_log_event("ready", {"default_template": DEFAULT_TEMPLATE, "loaded_saved": not document.dirty})
	print("PREFAB_EDITOR_READY ", JSON.stringify({"template_id": document.template["template_id"], "formal_world_allowed": false, "window_title": get_window().title}))

func _build_theme() -> void:
	var ui_theme := Theme.new()
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans CJK", "WenQuanYi Micro Hei", "sans-serif"])
	ui_theme.default_font = system_font
	ui_theme.default_font_size = 14
	ui_theme.set_color("font_color", "Label", Color("d8e5ee"))
	ui_theme.set_color("font_color", "Button", Color("dce7ef"))
	ui_theme.set_color("font_pressed_color", "Button", Color("f4e1a8"))
	ui_theme.set_stylebox("normal", "Button", _box(Color("263c4e"), Color("456277"), 5, 9))
	ui_theme.set_stylebox("hover", "Button", _box(Color("35566d"), Color("78a3bb"), 5, 9))
	ui_theme.set_stylebox("pressed", "Button", _box(Color("465440"), Color("c8bc76"), 5, 9))
	ui_theme.set_stylebox("disabled", "Button", _box(Color("22303c"), Color("33424e"), 5, 9))
	ui_theme.set_stylebox("panel", "PanelContainer", _box(Color("192b39"), Color("345065"), 7, 10))
	ui_theme.set_stylebox("normal", "LineEdit", _box(Color("0f1c27"), Color("4e6a7b"), 4, 8))
	ui_theme.set_color("font_color", "LineEdit", Color("e9f0f5"))
	ui_theme.set_stylebox("panel", "ItemList", _box(Color("10212d"), Color("334e62"), 4, 5))
	ui_theme.set_color("font_color", "ItemList", Color("d6e5ef"))
	theme = ui_theme

func _box(fill: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(radius)
	result.content_margin_left = padding
	result.content_margin_right = padding
	result.content_margin_top = 5
	result.content_margin_bottom = 5
	return result

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("0c1721")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 12)
	add_child(margins)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margins.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title: Label = _label("预制房间编辑器", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_label("009  /  F10 退出（不自动保存）", 13, Color("a5b9c7")))
	var boundary: Label = _label("仅技术代理几何  ·  formal_world_allowed=false  ·  非正式美术、AI、战斗或物理碰撞", 14, Color("f0d08a"))
	layout.add_child(boundary)
	_build_toolbar(layout)
	var work := HBoxContainer.new()
	work.size_flags_vertical = Control.SIZE_EXPAND_FILL
	work.add_theme_constant_override("separation", 10)
	layout.add_child(work)
	_build_sidebar(work)
	_build_canvas_panel(work, false)
	_build_canvas_panel(work, true)
	var status_panel := PanelContainer.new()
	layout.add_child(status_panel)
	var status_column := VBoxContainer.new()
	status_panel.add_child(status_column)
	_status = _label("正在核对正式来源…", 15)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 23
	status_column.add_child(_status)
	_diagnostic = _label("", 12, Color("9bb3c4"))
	_diagnostic.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_column.add_child(_diagnostic)
	_last_event = _label("所有按钮、按键、指针点击及绘制操作记录为结构化控制台事件", 11, Color("829aab"))
	_last_event.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_column.add_child(_last_event)
	_discard_dialog = ConfirmationDialog.new()
	_discard_dialog.title = "确认放弃未保存修改"
	_discard_dialog.ok_button_text = "放弃修改并继续"
	_discard_dialog.cancel_button_text = "取消，保留编辑"
	_discard_dialog.min_size = Vector2i(460, 180)
	_discard_dialog.exclusive = true
	_discard_dialog.confirmed.connect(_confirm_discard)
	_discard_dialog.canceled.connect(_cancel_discard)
	_discard_dialog.window_input.connect(_on_dialog_input)
	add_child(_discard_dialog)

func _build_toolbar(parent: VBoxContainer) -> void:
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 7)
	parent.add_child(toolbar)
	toolbar.add_child(_label("模板 ID", 14))
	_template_id = LineEdit.new()
	_template_id.name = "TemplateId"
	_template_id.text = DEFAULT_TEMPLATE
	_template_id.placeholder_text = "fixture_英文小写或数字"
	_template_id.tooltip_text = "此输入框仅用于新建或打开；保存始终写入当前文档 ID"
	_template_id.custom_minimum_size.x = 215
	_template_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_template_id.text_changed.connect(_on_id_changed)
	_template_id.text_submitted.connect(_on_id_submitted)
	toolbar.add_child(_template_id)
	for spec in [["new", "新建"], ["open", "打开"], ["save", "保存"], ["validate", "合法性检查"], ["test", "测试实例"]]:
		var button: Button = _button(spec[1])
		button.name = str(spec[0]).capitalize() + "Button"
		button.pressed.connect(_on_toolbar.bind(str(spec[0])))
		toolbar.add_child(button)
		_toolbar_buttons.append(button)

func _build_sidebar(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 194
	parent.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)
	scroll.add_child(column)
	column.add_child(_label("地图层", 15))
	_layer_select = OptionButton.new()
	_layer_select.name = "DepthSelector"
	_layer_select.add_item("地表 · 深度 0", 0)
	_layer_select.add_item("地下 · 深度 1", 1)
	_layer_select.add_item("深层 · 深度 2", 2)
	_layer_select.item_selected.connect(_on_depth_selected)
	column.add_child(_layer_select)
	column.add_child(_label("绘制工具", 15))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	column.add_child(grid)
	var group := ButtonGroup.new()
	for spec in TOOLS:
		var button: Button = _button(spec[1])
		button.name = str(spec[0]).capitalize() + "Tool"
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = spec[0] == active_tool
		button.tooltip_text = spec[2]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_tool_selected.bind(str(spec[0])))
		_tool_buttons[spec[0]] = button
		grid.add_child(button)
	_tool_help = _label("墙体 · H1 阻挡技术代理", 12, Color("acc0ce"))
	_tool_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tool_help.custom_minimum_size = Vector2(166, 52)
	column.add_child(_tool_help)
	var gestures: Label = _label("左键点击/拖动绘制\n右键擦除 · 基础地面保留\n入口：3格本体 / 7格安全区", 12, Color("91b0c4"))
	column.add_child(gestures)
	var saved_heading := HBoxContainer.new()
	column.add_child(saved_heading)
	var saved_title: Label = _label("已保存模板", 15)
	saved_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saved_heading.add_child(saved_title)
	var refresh: Button = _button("刷新")
	refresh.add_theme_font_size_override("font_size", 12)
	refresh.pressed.connect(_on_refresh_saved)
	saved_heading.add_child(refresh)
	_saved_list = ItemList.new()
	_saved_list.name = "SavedTemplateList"
	_saved_list.custom_minimum_size = Vector2(168, 108)
	_saved_list.item_selected.connect(_on_saved_selected)
	_saved_list.item_activated.connect(_on_saved_activated)
	column.add_child(_saved_list)
	column.add_child(_label("单击选 ID，双击打开", 11, Color("839eaf")))
	var legend: Label = _label("灰：墙  黄：容器  红：Boss\n绿三角：出生  蓝环：入口\n蓝框：入口本体和安全区", 11, Color("a7bdca"))
	column.add_child(legend)

func _build_canvas_panel(parent: HBoxContainer, instance_mode: bool) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	column.add_child(_label("测试世界 · 实际展开实例" if instance_mode else "模板编辑 · 局部坐标", 16, Color("9bd7ec") if instance_mode else Color("e8dcae")))
	var info: Label = _label("尚无实例" if instance_mode else "等待文档", 12, Color("9cb5c6"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.y = 52
	column.add_child(info)
	var canvas: Control = EditorCanvas.new()
	canvas.name = "ActualInstanceCanvas" if instance_mode else "TemplateCanvas"
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.custom_minimum_size = Vector2(270, 230)
	canvas.actual_instance = instance_mode
	canvas.editable = not instance_mode
	canvas.interaction.connect(_on_canvas_interaction)
	canvas.cell_hovered.connect(_on_hover.bind(instance_mode))
	if not instance_mode:
		canvas.paint_requested.connect(_on_paint)
	column.add_child(canvas)
	var hover: Label = _label("指向网格查看格坐标与代理信息", 11, Color("a6bbca"))
	hover.custom_minimum_size.y = 42
	hover.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	hover.clip_text = true
	column.add_child(hover)
	if instance_mode:
		_preview_info = info
		_preview_canvas = canvas
		_preview_hover = hover
	else:
		_document_info = info
		_edit_canvas = canvas
		_edit_hover = hover

func _label(value: String, font_size: int = 14, tint: Color = Color("d8e5ee")) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", tint)
	return result

func _button(value: String) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size.y = 31
	return result

func _on_id_changed(value: String) -> void:
	_log_event("template_id_input", {"value": value})

func _on_id_submitted(value: String) -> void:
	_log_event("template_id_submit", {"value": value})
	_on_toolbar("open")

func _on_toolbar(action: String) -> void:
	_cancel_strokes()
	_log_event("toolbar", {"action": action, "requested_id": _template_id.text.strip_edges()})
	if not _ui_ready:
		_set_status("编辑器尚未就绪，操作未执行", true)
		return
	if action in ["new", "open"]:
		_change_document(action, _template_id.text.strip_edges(), false)
		return
	var result: Dictionary
	match action:
		"save": result = document.save_template()
		"validate": result = document.validate_current()
		"test": result = document.test_instance()
		_: return
	_log_result(action, result)
	if not result.get("ok", false):
		_show_failure(result)
	else:
		match action:
			"save":
				_set_status("已保存当前模板 %s，修订 %d" % [document.template["template_id"], int(document.template["revision"])], false)
				_refresh_saved_list()
			"validate":
				_set_status("合法性检查通过：格式、引用、占用及入口规则有效。仍仅技术代理", false)
			"test":
				_set_status("008 实例化完成：右图读取实际实例坐标和身份，原点 [30,30]；更改模板后须重新测试", false)
	_sync_views()

func _change_document(action: String, identity: String, discard_changes: bool) -> void:
	_cancel_strokes()
	var result: Dictionary = document.new_template(identity, discard_changes) if action == "new" else document.open_template(identity, discard_changes)
	_log_result(action, result)
	if result.get("code", "") == "EDITOR_UNSAVED_CHANGES":
		_pending_action = {"action": action, "template_id": identity}
		_discard_dialog.dialog_text = "当前模板有未保存修改。\n继续%s“%s”会放弃这些修改。\n取消可回到原文档。" % ["新建" if action == "new" else "打开", identity]
		_discard_dialog.popup_centered()
		_log_event("discard_confirmation_shown", _pending_action)
		return
	if not result.get("ok", false):
		_show_failure(result)
		return
	_template_id.text = str(document.template["template_id"])
	_set_status(("已新建" if action == "new" else "已打开") + "模板 " + str(document.template["template_id"]), false)
	_sync_views()
	_refresh_saved_list()

func _confirm_discard() -> void:
	var pending: Dictionary = _pending_action.duplicate()
	_pending_action = {}
	_log_event("discard_confirmed", pending)
	if not pending.is_empty():
		if pending["action"] == "quit":
			_exit_normally("window_close_confirmed")
		else:
			_change_document(pending["action"], pending["template_id"], true)

func _cancel_discard() -> void:
	_log_event("discard_cancelled", _pending_action)
	_pending_action = {}
	_set_status("已取消；原文档及未保存修改均保留", false)

func _on_refresh_saved() -> void:
	_log_event("refresh_saved_templates", {})
	_refresh_saved_list()

func _refresh_saved_list() -> void:
	_saved_list.clear()
	if document == null or not document.ready:
		return
	for identity in document.saved_template_ids():
		_saved_list.add_item(str(identity))
		_saved_list.set_item_tooltip(_saved_list.item_count - 1, str(identity))
		if str(identity) == _template_id.text:
			_saved_list.select(_saved_list.item_count - 1)

func _on_saved_selected(index: int) -> void:
	_template_id.text = _saved_list.get_item_text(index)
	_log_event("saved_template_selected", {"index": index, "template_id": _template_id.text})

func _on_saved_activated(index: int) -> void:
	_on_saved_selected(index)
	_log_event("saved_template_activated", {"index": index, "template_id": _template_id.text})
	if _ui_ready:
		_change_document("open", _template_id.text, false)

func _on_depth_selected(index: int) -> void:
	_cancel_strokes()
	active_depth = _layer_select.get_item_id(index)
	_log_event("depth_selected", {"depth": active_depth})
	_sync_views()

func _on_tool_selected(tool: String) -> void:
	_cancel_strokes()
	active_tool = tool
	_edit_canvas.active_tool = tool
	for spec in TOOLS:
		if spec[0] == tool:
			_tool_help.text = spec[1] + " · " + spec[2]
	_log_event("tool_selected", {"tool": tool})

func _on_canvas_interaction(kind: String, details: Dictionary) -> void:
	_log_event(kind, details)

func _cancel_strokes() -> void:
	if _edit_canvas != null:
		_edit_canvas.cancel_stroke()
	if _preview_canvas != null:
		_preview_canvas.cancel_stroke()

func _on_paint(tool: String, depth: int, cell: Array, source: String) -> void:
	if not _ui_ready or _discard_dialog.visible:
		_log_event("paint_ignored", {"tool": tool, "depth": depth, "cell": cell, "source": source})
		return
	var result: Dictionary = document.erase(depth, cell) if tool == "erase" else document.place(tool, depth, cell)
	_log_result("paint", result, {"tool": tool, "depth": depth, "cell": cell, "source": source})
	if result.get("ok", false):
		var title: String = tool
		for spec in TOOLS:
			if spec[0] == tool:
				title = spec[1]
		_set_status("%s · 深度 %d · 格 [%d,%d]%s" % [title, depth, int(cell[0]), int(cell[1]), "（无变化）" if not result.get("changed", true) else "；未保存，旧预览已清除"], false)
	else:
		_show_failure(result)
	_sync_views()

func _on_hover(cell: Array, details: String, instance_mode: bool) -> void:
	var target: Label = _preview_hover if instance_mode else _edit_hover
	if target == null:
		return
	if cell.is_empty():
		target.text = "指向网格查看格坐标与代理信息"
		target.tooltip_text = ""
	else:
		target.text = ("世界" if instance_mode else "局部") + "格 [%d,%d]" % [int(cell[0]), int(cell[1])] + (" · " + details if not details.is_empty() else "")
		target.tooltip_text = target.text

func _sync_views() -> void:
	if document == null:
		return
	_edit_canvas.active_tool = active_tool
	_edit_canvas.set_document(document.template, active_depth, false)
	_preview_canvas.set_document(document.preview, active_depth, true)
	if not document.template.is_empty():
		_document_info.text = "%s\n修订 %d · %s · 深度 %d · 对象 %d / 锚点 %d" % [document.template["template_id"], int(document.template["revision"]), "未保存修改" if document.dirty else "已保存", active_depth, document.template["objects"].size(), document.template["anchors"].size()]
		_document_info.add_theme_color_override("font_color", Color("efd28d") if document.dirty else Color("9cb5c6"))
	if document.preview.is_empty():
		_preview_info.text = "只读 · 尚无当前文档的测试实例\n修改/保存/切换文档后，旧预览会清除"
		_preview_info.tooltip_text = ""
	else:
		var instance: Dictionary = document.preview
		_preview_info.text = "%s\n原点 %s · 模板修订 %d · 实际对象 %d" % [instance["prefab_instance_id"], str(instance["origin"]), int(instance["template_revision"]), instance["objects"].size()]
		_preview_info.tooltip_text = "world_id=" + str(instance["world_id"]) + "\nbody_instance_id=" + str(instance["body_instance_id"]) + "\ntemplate_sha256=" + str(instance["template_sha256"])

func _set_status(message: String, failure: bool, code: String = "") -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", Color("ff9d9e") if failure else Color("c2e7d4"))
	_diagnostic.text = "错误码：" + code + " · 原文档保留" if failure else "技术验证不等于正式世界、美术、Boss/容器玩法或碰撞验收"
	_diagnostic.tooltip_text = _diagnostic.text

func _show_failure(result: Dictionary) -> void:
	var code: String = str(result.get("code", "EDITOR_OPERATION_FAILED"))
	_set_status(EditorDocument.error_message(code), true, code)

func _startup_failed(code: String) -> void:
	_ui_ready = false
	for button in _toolbar_buttons:
		button.disabled = true
	for button in _tool_buttons.values():
		button.disabled = true
	_layer_select.disabled = true
	_set_status("初始化失败：" + EditorDocument.error_message(code), true, code)
	_log_event("startup_failed", {"code": code})
	push_error("PREFAB_EDITOR_STARTUP_FAILED " + code)

func _log_result(action: String, result: Dictionary, details: Dictionary = {}) -> void:
	var payload: Dictionary = details.duplicate(true)
	payload["action"] = action
	payload["ok"] = result.get("ok", false)
	payload["code"] = result.get("code", "OK")
	payload["changed"] = result.get("changed", false)
	if document != null:
		payload["preview_present"] = not document.preview.is_empty()
		payload["object_count"] = document.template.get("objects", []).size()
		payload["anchor_count"] = document.template.get("anchors", []).size()
		payload["connection_count"] = document.template.get("connections", []).size()
		payload["revision"] = document.template.get("revision", 0)
		if action == "test" and not document.preview.is_empty():
			payload["instance_kind"] = document.preview.get("artifact_kind", "")
			payload["instance_id"] = document.preview.get("prefab_instance_id", "")
			payload["origin"] = document.preview.get("origin", [])
			payload["instance_objects"] = document.preview.get("objects", []).size()
	_log_event("operation_result", payload)

func _log_event(kind: String, details: Dictionary) -> void:
	_event_sequence += 1
	var entry: Dictionary = {"schema_version": 1, "event": kind, "sequence": _event_sequence, "ticks_msec": Time.get_ticks_msec(), "depth": active_depth, "tool": active_tool, "formal_world_allowed": false, "details": details}
	if document != null:
		entry["template_id"] = document.template.get("template_id", "")
		entry["dirty"] = document.dirty
	print("PREFAB_EDITOR_EVENT ", JSON.stringify(entry))
	if _last_event != null:
		_last_event.text = "事件 #%d · %s · 详见 PREFAB_EDITOR_EVENT 控制台记录" % [_event_sequence, kind]

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_log_event("ui_pointer_press", {"viewport_px": [event.position.x, event.position.y], "button": event.button_index, "double_click": event.double_click, "confirmation_visible": _discard_dialog != null and _discard_dialog.visible})
	if event is InputEventKey and event.pressed and not event.echo:
		_log_event("ui_key_press", {"physical_keycode": event.physical_keycode, "keycode": event.keycode, "ctrl": event.ctrl_pressed, "shift": event.shift_pressed})
		if event.physical_keycode == KEY_F10 or event.keycode == KEY_F10:
			_exit_normally("F10")
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if document != null and document.dirty:
			_cancel_strokes()
			_pending_action = {"action": "quit"}
			_discard_dialog.dialog_text = "当前模板有未保存修改。\n关闭窗口将放弃这些修改。\n取消可返回编辑器保存。"
			_discard_dialog.popup_centered()
			_log_event("discard_confirmation_shown", _pending_action)
		else:
			_exit_normally("window_close")

func _on_dialog_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_log_event("dialog_pointer_press", {"dialog_px": [event.position.x, event.position.y], "button": event.button_index})
	if event is InputEventKey and event.pressed and not event.echo:
		_log_event("dialog_key_press", {"physical_keycode": event.physical_keycode, "keycode": event.keycode})
		if event.physical_keycode == KEY_F10 or event.keycode == KEY_F10:
			_exit_normally("F10_confirmation_dialog")

func _exit_normally(reason: String) -> void:
	_log_event("operator_exit", {"reason": reason, "unsaved_discarded": document != null and document.dirty})
	print("PREFAB_EDITOR_OPERATOR_EXIT ", reason)
	get_tree().quit(0)
