extends Control
## Ordinary local entry. User-facing paths/process arguments stay internal.
const Coordinator = preload("res://scripts/actor/actor_local_session_coordinator.gd")
var _coordinator: Node
var _panel: CenterContainer
var _world_name: LineEdit
var _slots: OptionButton
var _new_button: Button
var _inventory_button: Button
var _continue_button: Button
var _exit_button: Button
var _status: Label

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_window().title = "沙盒游戏"
	get_window().min_size = Vector2i(800, 600)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_menu()
	_coordinator = Coordinator.new()
	_coordinator.name = "LocalSession"
	add_child(_coordinator)
	_coordinator.changed.connect(_refresh)
	var configured: Dictionary = _coordinator.configure()
	if not configured.get("ok", false):
		_status.text = "本地存档暂不可用：" + str(configured.get("code", "LOCAL_START_FAILED"))
		_new_button.disabled = true
		_inventory_button.disabled = true
		_continue_button.disabled = true
		return
	_refresh()

func _build_menu() -> void:
	var background := ColorRect.new()
	background.color = Color("17212a")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_panel = CenterContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "沙盒游戏"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var description := Label.new()
	description.text = "地表技术区域\nWASD移动 · Shift闪避 · F交互\n游玩中按F10保存并返回"
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(description)
	_world_name = LineEdit.new()
	_world_name.placeholder_text = "新世界名称（可选）"
	_world_name.max_length = 40
	box.add_child(_world_name)
	_new_button = _button(box, "新建世界", _new_world)
	_inventory_button = _button(box, "新建背包世界（012测试）", _new_inventory_world)
	_slots = OptionButton.new()
	box.add_child(_slots)
	_slots.item_selected.connect(_selection_changed)
	_continue_button = _button(box, "继续世界", _continue_world)
	_exit_button = _button(box, "退出游戏", _exit_game)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(460, 60)
	box.add_child(_status)

func _button(parent: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _refresh() -> void:
	var state: Dictionary = _coordinator.menu_state()
	_panel.visible = not state["playing"]
	_new_button.disabled = not state["can_start"]
	_inventory_button.disabled = not state["can_start"] or not _coordinator.supports_inventory_world()
	_inventory_button.tooltip_text = "新建空背包世界；旧世界按原版本继续" if _coordinator.supports_inventory_world() else "Windows背包世界存储验证尚未完成；旧世界可继续"
	_slots.disabled = not state["can_start"]
	_world_name.editable = state["can_start"]
	_status.text = state["message"]
	if state["phase"] == "idle":
		get_window().title = "沙盒游戏"
		var list: Dictionary = _coordinator.slots()
		_slots.clear()
		if not list.get("ok", false):
			_status.text = "读取存档列表失败：" + str(list.get("code", "LOCAL_SLOTS_FAILED"))
			_continue_button.disabled = true
			return
		for row in list["slots"]:
			var status_text: String = "可继续" if row["status"] == "ready" else "未开始" if row["status"] == "new" else "未完成，需检查"
			if row.has("profile_error"): status_text = "版本标记异常，原档保留"
			elif row.get("profile", 4) == 5: status_text = "背包 · " + status_text
			_slots.add_item(row["label"] + " · " + status_text)
			_slots.set_item_metadata(_slots.item_count - 1, row.duplicate(true))
			if row["slot_id"] == list["last_slot_id"]:
				_slots.select(_slots.item_count - 1)
	_selection_changed(_slots.selected)

func _selection_changed(index: int) -> void:
	var allowed: bool = _coordinator != null and _coordinator.menu_state()["can_start"] and index >= 0 and index < _slots.item_count
	var row: Dictionary = _slots.get_item_metadata(index) if allowed else {}
	_continue_button.disabled = not allowed or row.get("status") not in ["ready", "new"] or row.has("profile_error") or (row.get("profile", 4) == 5 and not _coordinator.supports_inventory_world())

func _new_world() -> void:
	var label: String = _world_name.text.strip_edges()
	var started: Dictionary = _coordinator.new_world(label if not label.is_empty() else "新世界")
	if not started.get("ok", false):
		_status.text = "无法新建世界：" + str(started.get("code", "LOCAL_START_FAILED"))

func _new_inventory_world() -> void:
	var label: String = _world_name.text.strip_edges()
	var started: Dictionary = _coordinator.new_world(label if not label.is_empty() else "背包世界", 5)
	if not started.get("ok", false):
		_status.text = "无法新建背包世界：" + str(started.get("code", "LOCAL_START_FAILED"))

func _continue_world() -> void:
	if _slots.selected < 0:
		return
	var row: Dictionary = _slots.get_item_metadata(_slots.selected)
	var started: Dictionary = _coordinator.continue_world(row["slot_id"])
	if not started.get("ok", false):
		_status.text = "此存档的地形版本不兼容，请使用创建它的技术版本；原存档已保留" if started.get("code") == "TERRAIN_CONTRACT_INCOMPATIBLE" else "无法继续世界：" + str(started.get("code", "LOCAL_START_FAILED"))

func _exit_game() -> void:
	if _coordinator != null and _coordinator.session_ready:
		_coordinator.request_exit()
	else:
		get_tree().quit(1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_exit_game()
