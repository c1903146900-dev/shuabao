extends Control
## Server-view-only technical Control; schema5 leaf owns authenticated RPC.
## Signals are requests only. Future bridge must authenticate, recheck context,
## and call server authority. No local lift/merge/swap/drop/return exists.
signal drop_intent(kind: String, address: Dictionary, expected_revision: int, sequence: int)
signal left_intent(address: Dictionary, expected_revision: int, sequence: int)
signal close_intent(reason: String, expected_revision: int)
signal open_intent()
signal view_rejected(code: String)
const View = preload("res://scripts/inventory/ui012/inventory_view012.gd")
const Slot = preload("res://scripts/inventory/ui012/inventory_slot012.gd")
const MaterialIcons = preload("res://scripts/inventory/ui012/material_icon_textures012.gd")
const CarryVisualClamp = preload("res://scripts/inventory/ui012/carry_visual_clamp012.gd")
const LIMIT := 9007199254740991
var _model: RefCounted
var _context: String = "closed"
var _chest_id: String = ""
var _last_emitted: int = 0
var _context_epoch: int = 0
var _granted_chest: String = ""
var _pending_sequence: int = 0
var _authenticated_open: bool = false
var _personal_open_pending: bool = false
var _requests_enabled: bool = true
var _left_enabled: bool = true
var _mask: ColorRect
var _center: CenterContainer
var _row: HBoxContainer
var _character: VBoxContainer
var _craft: VBoxContainer
var _chest: VBoxContainer
var _bag_grid: GridContainer
var _hotbar_grid: GridContainer
var _chest_grid: GridContainer
var _carry: Label
var _carry_visual_state: Dictionary = {}
var _built: bool = false
var _selected_hotbar: int = 0

func _ready() -> void:
	build_controls()

func bind_identity(world_id: String, profile_id: String) -> bool:
	# Identity cannot silently switch while another player's cache is visible.
	if _model != null: return false
	_model = View.new(world_id, profile_id)
	return true

func apply_server_view(value: Variant) -> Dictionary:
	if _model == null: return {"ok": false, "code": "VIEW_NOT_BOUND"}
	var result: Dictionary = _model.accept(value)
	if not result["ok"]:
		view_rejected.emit(result["code"])
		return result
	var current: Dictionary = _model.snapshot()
	_last_emitted = maxi(_last_emitted, current["inventory"]["last_sequence"])
	if _pending_sequence > 0 and current["inventory"]["last_sequence"] >= _pending_sequence: _pending_sequence = 0
	if _context == "chest" and not current["chests"].has(_chest_id): close_panel("context_lost")
	elif not _granted_chest.is_empty() and not current["chests"].has(_granted_chest):
		_context_epoch += 1
		_granted_chest = ""
	_refresh()
	return result

func cached_view() -> Dictionary:
	return {} if _model == null else _model.snapshot()

func require_authenticated_open() -> void:
	_authenticated_open = true

func set_requests_enabled(enabled: bool) -> void:
	_requests_enabled = enabled
	_refresh()

func set_left_enabled(enabled: bool) -> void:
	_left_enabled = enabled
	_refresh()

func personal_open_pending() -> bool:
	return _personal_open_pending

func complete_personal_open(requested_epoch: int) -> bool:
	# Transport completion is separate from cache acceptance. A delayed first
	# view may refresh the cache, but Escape/toggle/context loss invalidates open.
	if not _requests_enabled or not _personal_open_pending or requested_epoch != _context_epoch or cached_view().is_empty(): return false
	_personal_open_pending = false
	_context = "personal"
	_chest_id = ""
	_refresh()
	return true

func open_personal() -> bool:
	if not _requests_enabled or _personal_open_pending: return false
	if _authenticated_open or cached_view().is_empty():
		if _context == "chest": close_panel("switch_personal")
		_context_epoch += 1
		_personal_open_pending = true
		open_intent.emit()
		return false
	if _context == "chest": close_panel("switch_personal")
	_context = "personal"
	_chest_id = ""
	_refresh()
	return true

func context_epoch() -> int:
	return _context_epoch

func grant_chest_context(chest_id: String, requested_epoch: int) -> bool:
	# Authenticated bridge only: echo the epoch captured when requesting the
	# server range/context grant. A delayed pre-close reply cannot reopen it.
	if requested_epoch != _context_epoch or not cached_view().get("chests", {}).has(chest_id): return false
	if _context == "chest" and chest_id != _chest_id: return false
	_granted_chest = chest_id
	return true

func reject_left_intent(sequence: int) -> bool:
	# Authenticated bridge only, after an explicit server rejection of this
	# request. Never infer rejection from a timer or an unrelated newer view.
	if sequence != _pending_sequence or _pending_sequence == 0: return false
	_pending_sequence = 0
	_refresh()
	return true

func open_chest(chest_id: String) -> bool:
	if chest_id != _granted_chest or not cached_view().get("chests", {}).has(chest_id): return false
	_context = "chest"
	_chest_id = chest_id
	_refresh()
	return true

func close_panel(reason: String = "close") -> void:
	if _context == "closed" and not _personal_open_pending: return
	_personal_open_pending = false
	_context_epoch += 1
	_granted_chest = ""
	_context = "closed"
	_chest_id = ""
	# Only presentation changes. Server-owned carry and slots are untouched.
	_refresh()
	close_intent.emit(reason, cached_view().get("revision", -1))

func context_lost() -> void:
	if _context == "chest" or _personal_open_pending: close_panel("context_lost")
	else:
		_context_epoch += 1
		_granted_chest = ""

func request_left(address: Variant) -> bool:
	var current: Dictionary = cached_view()
	if not _requests_enabled or not _left_enabled or _context == "closed" or current.is_empty() or _pending_sequence != 0 or not _model.address_valid(address): return false
	if address["container"] == "chest" and (_context != "chest" or address["owner"] != _chest_id): return false
	if _last_emitted >= LIMIT or current["revision"] >= LIMIT: return false
	_last_emitted += 1
	_pending_sequence = _last_emitted
	_refresh()
	left_intent.emit(address.duplicate(true), current["revision"], _last_emitted)
	return true

func request_drop(kind: String, address: Dictionary = {}) -> bool:
	var current: Dictionary = cached_view()
	if not _requests_enabled or not _left_enabled or current.is_empty() or _pending_sequence != 0 or kind not in ["q_one", "carry_all", "right_half"]: return false
	if kind != "q_one" and current["inventory"]["carry"] == null: return false
	var selected: Dictionary = {"container": "hotbar", "owner": current["profile_id"], "slot": _selected_hotbar}
	# 137_快捷键 B4/C4: Q uses the selected hotbar slot, never the hovered
	# container. A mismatched explicit request must not silently drop another item.
	if kind == "q_one":
		if not address.is_empty() and (not _model.address_valid(address) or address != selected): return false
	elif not address.is_empty(): selected = address.duplicate(true)
	if not _model.address_valid(selected): return false
	if selected["container"] == "chest" and (_context != "chest" or selected["owner"] != _chest_id): return false
	if _last_emitted >= LIMIT or current["revision"] >= LIMIT: return false
	_last_emitted += 1
	_pending_sequence = _last_emitted
	_refresh()
	drop_intent.emit(kind, selected, current["revision"], _last_emitted)
	return true

func _input(event: InputEvent) -> void:
	if not _requests_enabled or not _built: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9: _selected_hotbar = int(event.keycode - KEY_1)
		elif event.keycode == KEY_0: _selected_hotbar = 9
		elif event.keycode == KEY_Q:
			if request_drop("q_one"): get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _selected_hotbar = (_selected_hotbar + 9) % 10
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _selected_hotbar = (_selected_hotbar + 1) % 10
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if request_drop("right_half"): get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and (not _hotbar_grid.get_global_rect().has_point(event.position) and (_context == "closed" or not _row.get_global_rect().has_point(event.position))):
			if request_drop("carry_all"): get_viewport().set_input_as_handled()

func _hovered_address() -> Dictionary:
	var current: Dictionary = cached_view()
	if current.is_empty(): return {}
	for pair in [["bag", _bag_grid], ["hotbar", _hotbar_grid], ["chest", _chest_grid]]:
		if not pair[1].is_visible_in_tree(): continue
		for index in range(pair[1].get_child_count()):
			if pair[1].get_child(index).get_global_rect().has_point(get_global_mouse_position()):
				return {"container": pair[0], "owner": _chest_id if pair[0] == "chest" else current["profile_id"], "slot": index}
	return {}

func _unhandled_key_input(event: InputEvent) -> void:
	if not _requests_enabled or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_I:
		if _context == "closed" and not _personal_open_pending: open_personal()
		else: close_panel("toggle")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and (_context != "closed" or _personal_open_pending):
		close_panel("escape")
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _built:
		_carry_visual_state = CarryVisualClamp.place(self, _carry, get_local_mouse_position() + Vector2(18, 18))
		if _carry.visible:
			_carry.position = _carry_visual_state["position"]

func carry_visual_state() -> Dictionary:
	# Detached diagnostics only. Never used by input, cache, authority, or RPC.
	return _carry_visual_state.duplicate(true)

func build_controls() -> void:
	if _built: return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask = ColorRect.new()
	_mask.name = "InventoryMask"
	_mask.color = Color(0, 0, 0, 0.65)
	add_child(_mask)
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center = CenterContainer.new()
	_center.name = "CenteredInventoryContext"
	_center.z_index = 10
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 20)
	_center.add_child(_row)
	_character = _column(_row, "CharacterPlaceholder", "人物与穿戴 · 接口未接入")
	var preview_row := HBoxContainer.new()
	_character.add_child(preview_row)
	_label(preview_row, "人物外观\n未接入")
	var armor := VBoxContainer.new()
	preview_row.add_child(armor)
	for part in ["头", "身", "脚"]: _placeholder(armor, part + "：未接入")
	var accessories := HBoxContainer.new()
	_character.add_child(accessories)
	for part in ["饰品 1", "饰品 2"]: _placeholder(accessories, part + "：未接入")
	var bag := _column(_row, "Bag", "背包 40 · 技术 UI")
	_bag_grid = _grid(bag, "BagSlots", 8, 40, "bag")
	var close_button := Button.new()
	close_button.text = "关闭 (Esc / I)"
	close_button.pressed.connect(close_panel.bind("close"))
	bag.add_child(close_button)
	_craft = _column(_row, "PersonalCraftingPlaceholder", "随身制作 · 接口未接入")
	_label(_craft, "配方与材料：未接入")
	_chest = _column(_row, "CurrentChest", "当前箱子 30 · 技术 UI")
	_chest_grid = _grid(_chest, "ChestSlots", 5, 30, "chest")
	var hud := VBoxContainer.new()
	hud.name = "PersistentHotbar"
	hud.z_index = 20 # cehua P134: above the mask.
	add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hud.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label(hud, "生命 / 食物 / 能量：资源条接口未接入（技术占位）")
	_hotbar_grid = _grid(hud, "HotbarSlots", 10, 10, "hotbar")
	_carry = Label.new()
	_carry.name = "ServerCarryTechnicalThumbnail"
	_carry.z_index = 40
	_carry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_carry)
	_add_material_decoration(_carry)
	_refresh()

func _column(parent: Node, node_name: String, title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = node_name
	parent.add_child(column)
	_label(column, title)
	return column

func _placeholder(parent: Node, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = true
	parent.add_child(button)

func _label(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)

func _grid(parent: Node, node_name: String, columns: int, count: int, kind: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = node_name
	grid.columns = columns
	parent.add_child(grid)
	for index in range(count):
		var button := Slot.new()
		button.custom_minimum_size = Vector2(68, 56)
		button.text = str(index + 1)
		button.clip_text = true
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_slot_pressed.bind(kind, index))
		grid.add_child(button)
		_add_material_decoration(button)
	return grid

func _slot_pressed(kind: String, index: int) -> void:
	var current: Dictionary = cached_view()
	if current.is_empty(): return
	request_left({"container": kind, "owner": _chest_id if kind == "chest" else current["profile_id"], "slot": index})

func _refresh() -> void:
	if not _built: return
	_mask.visible = _context != "closed"
	_center.visible = _context != "closed"
	_character.visible = _context == "personal"
	_craft.visible = _context == "personal"
	_chest.visible = _context == "chest"
	var current: Dictionary = cached_view()
	if current.is_empty():
		_carry.hide()
		return
	_paint(_bag_grid, current["inventory"]["bag"])
	_paint(_hotbar_grid, current["inventory"]["hotbar"])
	if _context == "chest": _paint(_chest_grid, current["chests"][_chest_id]["slots"])
	else:
		var empty: Array = []
		empty.resize(30)
		_paint(_chest_grid, empty)
	var carried: Variant = current["inventory"]["carry"]
	_carry.visible = carried != null
	_carry.text = "" if carried == null else "技术携带格\n%s ×%d" % [_name(carried["content_id"]), carried["quantity"]]
	if _paint_material_decoration(_carry, carried):
		_carry.text = ""

func _paint(grid: GridContainer, slots: Array) -> void:
	for index in range(slots.size()):
		var button: Button = grid.get_child(index)
		var entry: Variant = slots[index]
		button.disabled = not _requests_enabled or not _left_enabled or _context == "closed" or _pending_sequence != 0
		button.text = str(index + 1) if entry == null else "%s\n×%d" % [_name(entry["content_id"]), entry["quantity"]]
		button.tooltip_text = "空格 %d" % (index + 1) if entry == null else _tooltip(entry)
		if _paint_material_decoration(button, entry):
			button.text = ""

func _add_material_decoration(parent: Control) -> void:
	# Display-only children never become Grid children or input recipients.
	# The 40 px frame is a technical preview choice, not a formal asset size.
	var icon := TextureRect.new()
	icon.name = "MaterialIcon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.focus_mode = Control.FOCUS_NONE
	icon.position = Vector2(14, 4)
	icon.size = Vector2(40, 40)
	icon.hide()
	parent.add_child(icon)
	var quantity := Label.new()
	quantity.name = "MaterialQuantity"
	quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantity.focus_mode = Control.FOCUS_NONE
	quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	quantity.clip_text = true
	quantity.position = Vector2(4, 32)
	quantity.size = Vector2(60, 24)
	quantity.hide()
	parent.add_child(quantity)

func _paint_material_decoration(parent: Control, entry: Variant) -> bool:
	var icon: TextureRect = parent.get_node("MaterialIcon") as TextureRect
	var quantity: Label = parent.get_node("MaterialQuantity") as Label
	# Always clear first: empty or unmapped content cannot retain a previous icon.
	icon.texture = null
	icon.hide()
	quantity.text = ""
	quantity.hide()
	if entry == null:
		return false
	var texture: Texture2D = MaterialIcons.texture_for_content(entry["content_id"])
	if texture == null:
		return false
	icon.texture = texture
	icon.show()
	quantity.text = "×%d" % entry["quantity"]
	quantity.show()
	return true

static func _name(id: String) -> String:
	return {"mucai": "木材", "shitou": "石头"}.get(id, id)

static func _tooltip(entry: Dictionary) -> String:
	var state: String = JSON.stringify(entry["state"], "  ")
	if state.length() > 1800: state = state.left(1800) + "\n[技术预览已截短]"
	return "%s\nID: %s\n数量: %d\n说明：正式描述接口未接入\n实例: %s\n保护实例: %s\n当前服务器实例状态:\n%s\n技术文字槽；非最终图标" % [_name(entry["content_id"]), entry["content_id"], entry["quantity"], entry["item_instance_id"], entry["protected_instance_id"], state]
