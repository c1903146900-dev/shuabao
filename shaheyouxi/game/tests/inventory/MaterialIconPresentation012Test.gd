extends GdUnitTestSuite
## Isolated presentation assertions only. Synthetic views are not gameplay grants.
## No Owner, Store, transport, actual ACK, normal shutdown or playable-slot claim.
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const View = preload("res://scripts/inventory/ui012/inventory_view012.gd")
const InventoryPanel = preload("res://scripts/inventory/ui012/inventory_panel012.gd")
const InventorySlot = preload("res://scripts/inventory/ui012/inventory_slot012.gd")
const MaterialIcons = preload("res://scripts/inventory/ui012/material_icon_textures012.gd")
const WORLD := "world_11111111111111111111111111111111"
const PROFILE := "player_material_icon_fixture"
var _panel: Control
var _events: Array
var _left_intents: Array
const FIXTURE_WINDOW_SIZE := Vector2i(1280, 800)
const FIXTURE_FRAME_LIMIT := 10
const FIXTURE_TIMEOUT_USEC := 1000000
var _fixture_window: Window
var _fixture_saved_size: Vector2i
var _fixture_saved_rect: Rect2
var _fixture_size_owned: bool = false
var _fixture_left_down_owned: bool = false
var _fixture_left_position: Vector2
var _fixture_left_global_position: Vector2

func before_test() -> void:
	# Reject a foreign/previous held button; never release input we do not own.
	assert_bool(not _fixture_left_down_owned).is_true()
	assert_bool(not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)).is_true()
	if _fixture_left_down_owned or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	# Own only this isolated test process's root Window size, per test case.
	assert_bool(not _fixture_size_owned).is_true()
	if _fixture_size_owned:
		return
	_panel = null
	_fixture_window = get_tree().root
	_fixture_saved_size = _fixture_window.size
	_fixture_saved_rect = _fixture_window.get_visible_rect()
	_fixture_size_owned = true
	_fixture_window.size = FIXTURE_WINDOW_SIZE
	_events = []
	_left_intents = []
	_panel = InventoryPanel.new()
	assert_bool(_panel.bind_identity(WORLD, PROFILE)).is_true()
	_panel.build_controls()
	_panel.left_intent.connect(func(address: Dictionary, revision: int, sequence: int) -> void:
		_events.append("left")
		_left_intents.append({"address": address.duplicate(true), "revision": revision, "sequence": sequence}))
	_panel.drop_intent.connect(func(_kind: String, _address: Dictionary, _revision: int, _sequence: int) -> void: _events.append("drop"))
	_panel.close_intent.connect(func(_reason: String, _revision: int) -> void: _events.append("close"))
	_panel.open_intent.connect(func() -> void: _events.append("open"))
	add_child(_panel)
	var core: RefCounted = Core.new(WORLD)
	assert_bool(core.trusted_create_player(PROFILE).get("ok", false)).is_true()
	var view: Dictionary = View.server_view(core, PROFILE, 1)
	view["inventory"]["bag"][0] = _material("mucai", 7)
	view["inventory"]["bag"][1] = _material("shitou", 12)
	view["inventory"]["hotbar"][0] = _material("mucai", 2)
	_apply(view)
	assert_bool(_panel.open_personal()).is_true()
	await get_tree().process_frame
	var fixture_ready: bool = await _wait_fixture_layout()
	assert_bool(fixture_ready).is_true()

func after_test() -> void:
	var input_released: bool = await _release_owned_left_button()
	if is_instance_valid(_panel):
		_panel.free()
	_panel = null
	var restored: bool = await _restore_fixture_window()
	assert_bool(input_released).is_true()
	assert_bool(not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)).is_true()
	assert_bool(restored).is_true()

func after() -> void:
	# Suite-final fallback also covers a setup/teardown failure; it is not a retry.
	var input_released: bool = await _release_owned_left_button()
	if is_instance_valid(_panel):
		_panel.free()
	_panel = null
	var restored: bool = await _restore_fixture_window()
	assert_bool(input_released).is_true()
	assert_bool(not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)).is_true()
	assert_bool(restored).is_true()

static func _material(content_id: String, count: int) -> Dictionary:
	return {"content_id": content_id, "quantity": count, "item_instance_id": "", "protected_instance_id": "", "state": {}}

static func _unmapped(instance_id: String) -> Dictionary:
	return {"content_id": "wuqi_huoqi_tansuo_01", "quantity": 1, "item_instance_id": instance_id, "protected_instance_id": "", "state": {}}

func _apply(view: Dictionary) -> void:
	var current: Dictionary = _panel.cached_view()
	if not current.is_empty():
		view["view_sequence"] = current["view_sequence"] + 1
		view["revision"] = current["revision"] + 1
	assert_bool(_panel.apply_server_view(view).get("ok", false)).is_true()

func _assert_decoration(parent: Control) -> void:
	var icon: TextureRect = parent.get_node("MaterialIcon") as TextureRect
	var quantity: Label = parent.get_node("MaterialQuantity") as Label
	assert_bool(icon != null and quantity != null).is_true()
	if icon == null or quantity == null:
		return
	assert_bool(icon.get_parent() == parent and quantity.get_parent() == parent).is_true()
	assert_int(icon.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(quantity.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(icon.focus_mode).is_equal(Control.FOCUS_NONE)
	assert_int(quantity.focus_mode).is_equal(Control.FOCUS_NONE)
	assert_int(icon.expand_mode).is_equal(TextureRect.EXPAND_IGNORE_SIZE)
	assert_int(icon.stretch_mode).is_equal(TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	assert_int(icon.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_bool(icon.size == Vector2(40, 40)).is_true()

func test_slot_children_and_minimum_geometry_are_unchanged() -> void:
	for pair in [[_panel._bag_grid, 40], [_panel._hotbar_grid, 10], [_panel._chest_grid, 30]]:
		var grid: GridContainer = pair[0]
		assert_int(grid.get_child_count()).is_equal(pair[1])
		for index in range(grid.get_child_count()):
			var button: Button = grid.get_child(index) as Button
			assert_bool(button.get_script() == InventorySlot).is_true()
			assert_int(button.get_child_count()).is_equal(2)
			assert_bool(button.custom_minimum_size == Vector2(68, 56)).is_true()
			assert_bool(button.get_combined_minimum_size() == Vector2(68, 56)).is_true()
			assert_bool(button.icon == null).is_true()
			_assert_decoration(button)

func test_fixed_texture_lookup_keeps_native_sources_and_server_quantities() -> void:
	assert_bool(MaterialIcons.texture_for_content("mucai") == MaterialIcons.WOOD_TEXTURE).is_true()
	assert_bool(MaterialIcons.texture_for_content("shitou") == MaterialIcons.STONE_TEXTURE).is_true()
	assert_bool(MaterialIcons.texture_for_content("unmapped") == null).is_true()
	for texture in [MaterialIcons.WOOD_TEXTURE, MaterialIcons.STONE_TEXTURE]:
		assert_int(texture.get_width()).is_equal(1254)
		assert_int(texture.get_height()).is_equal(1254)
	for pair in [[0, "mucai", "×7"], [1, "shitou", "×12"]]:
		var button: Button = _panel._bag_grid.get_child(pair[0])
		var icon: TextureRect = button.get_node("MaterialIcon")
		var quantity: Label = button.get_node("MaterialQuantity")
		assert_bool(icon.texture == MaterialIcons.texture_for_content(pair[1]) and icon.visible and quantity.visible).is_true()
		assert_str(quantity.text).is_equal(pair[2])
		assert_str(button.text).is_equal("")
		assert_str(button.tooltip_text).is_equal(InventoryPanel._tooltip(_panel.cached_view()["inventory"]["bag"][pair[0]]))
	# Existing material max_stack is 999. Check fit; never shrink or clamp the count.
	var largest: Dictionary = _panel.cached_view()
	largest["inventory"]["bag"][0] = _material("mucai", 999)
	largest["inventory"]["bag"][1] = _material("shitou", 999)
	_apply(largest)
	for index in [0, 1]:
		var quantity: Label = _panel._bag_grid.get_child(index).get_node("MaterialQuantity")
		assert_str(quantity.text).is_equal("×999")
		assert_bool(quantity.size == Vector2(60, 24)).is_true()
		var font: Font = quantity.get_theme_font("font")
		var font_size: int = quantity.get_theme_font_size("font_size")
		var extent: Vector2 = font.get_string_size(quantity.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		assert_bool(extent.x <= 60.0 and extent.y <= 24.0 and font.get_height(font_size) <= 24.0).is_true()

func test_changed_unmapped_and_empty_slots_do_not_retain_an_icon() -> void:
	var button: Button = _panel._bag_grid.get_child(0)
	var icon: TextureRect = button.get_node("MaterialIcon")
	var quantity: Label = button.get_node("MaterialQuantity")
	var view: Dictionary = _panel.cached_view()
	view["inventory"]["bag"][0] = _material("shitou", 9)
	_apply(view)
	assert_bool(icon.texture == MaterialIcons.STONE_TEXTURE).is_true()
	assert_str(quantity.text).is_equal("×9")
	view = _panel.cached_view()
	view["inventory"]["bag"][0] = _unmapped("material_icon_unknown_slot")
	_apply(view)
	assert_bool(icon.texture == null and not icon.visible and not quantity.visible).is_true()
	assert_str(quantity.text).is_equal("")
	assert_str(button.text).is_equal("wuqi_huoqi_tansuo_01\n×1")
	view = _panel.cached_view()
	view["inventory"]["bag"][0] = null
	_apply(view)
	assert_bool(icon.texture == null and not icon.visible and not quantity.visible).is_true()
	assert_str(quantity.text).is_equal("")
	assert_str(button.text).is_equal("1")
	assert_str(button.tooltip_text).is_equal("空格 1")

func test_carry_uses_original_label_following_visibility_and_fallback() -> void:
	var carry: Label = _panel._carry
	assert_bool(carry is Label).is_true()
	assert_str(str(carry.name)).is_equal("ServerCarryTechnicalThumbnail")
	assert_int(carry.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(carry.z_index).is_equal(40)
	_assert_decoration(carry)
	var view: Dictionary = _panel.cached_view()
	view["inventory"]["carry"] = _material("mucai", 3)
	view["inventory"]["carry_origin"] = {"container": "bag", "owner": PROFILE, "slot": 0}
	_apply(view)
	var icon: TextureRect = carry.get_node("MaterialIcon")
	var quantity: Label = carry.get_node("MaterialQuantity")
	var before_pointer: PackedByteArray = var_to_bytes(_panel.cached_view())
	await _move_pointer(Vector2(200, 200))
	assert_bool(var_to_bytes(_panel.cached_view()) == before_pointer).is_true()
	assert_array(_events).is_equal([])
	assert_int(_left_intents.size()).is_equal(0)
	assert_bool(carry.visible and icon.texture == MaterialIcons.WOOD_TEXTURE).is_true()
	assert_str(quantity.text).is_equal("×3")
	assert_str(carry.text).is_equal("")
	assert_bool(not carry.clip_contents).is_true()
	assert_bool(carry.is_visible_in_tree() and icon.is_visible_in_tree() and quantity.is_visible_in_tree()).is_true()
	assert_bool(_panel.get_viewport_rect().intersects(icon.get_global_rect())).is_true()
	_panel._process(0.0)
	assert_bool(carry.position == _panel.get_local_mouse_position() + Vector2(18, 18)).is_true()
	view = _panel.cached_view()
	view["inventory"]["carry"] = _unmapped("material_icon_unknown_carry")
	_apply(view)
	assert_bool(carry.visible and icon.texture == null and not icon.visible and not quantity.visible).is_true()
	assert_str(carry.text).is_equal("技术携带格\nwuqi_huoqi_tansuo_01 ×1")
	view = _panel.cached_view()
	view["inventory"]["carry"] = null
	view["inventory"]["carry_origin"] = null
	_apply(view)
	assert_bool(not carry.visible and icon.texture == null and not icon.visible and not quantity.visible).is_true()
	assert_str(carry.text).is_equal("")

func test_repaint_does_not_mutate_cache_or_emit_requests() -> void:
	var before: PackedByteArray = var_to_bytes(_panel.cached_view())
	var event_count: int = _events.size()
	var revision: int = _panel._last_emitted
	var pending: int = _panel._pending_sequence
	_panel._refresh()
	_panel.set_left_enabled(false)
	assert_bool(_panel._bag_grid.get_child(0).disabled).is_true()
	_panel.set_requests_enabled(false)
	assert_bool(_panel._hotbar_grid.get_child(0).disabled).is_true()
	_panel._refresh()
	assert_bool(var_to_bytes(_panel.cached_view()) == before).is_true()
	assert_int(_events.size()).is_equal(event_count)
	assert_int(_panel._last_emitted).is_equal(revision)
	assert_int(_panel._pending_sequence).is_equal(pending)

func _move_pointer(point: Vector2) -> void:
	assert_bool(_panel.get_viewport_rect().has_point(point)).is_true()
	var started_usec: int = Time.get_ticks_usec()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	# The original first await may resume before Panel._process for that frame.
	# At most nine more natural frame boundaries: ten total, <= one second.
	var arrived: bool = await _wait_pointer_and_natural_carry(point, started_usec)
	assert_bool(arrived).is_true()

func _click_decoration(node_name: String) -> void:
	var button: Button = _panel._bag_grid.get_child(0)
	var decoration: Control = button.get_node(node_name)
	var point: Vector2 = decoration.get_global_rect().get_center()
	assert_bool(_panel.get_viewport_rect().encloses(button.get_global_rect())).is_true()
	assert_bool(_panel.get_viewport_rect().encloses(decoration.get_global_rect())).is_true()
	await _move_pointer(point)
	assert_dict(_panel._hovered_address()).is_equal({"container": "bag", "owner": PROFILE, "slot": 0})
	var before: PackedByteArray = var_to_bytes(_panel.cached_view())
	_events.clear()
	_left_intents.clear()
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	assert_bool(not _fixture_left_down_owned).is_true()
	assert_bool(not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)).is_true()
	if _fixture_left_down_owned or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	_fixture_left_position = event.position
	_fixture_left_global_position = event.global_position
	_fixture_left_down_owned = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_fixture_left_down_owned = false
	assert_bool(not _fixture_left_down_owned).is_true()
	assert_int(_left_intents.size()).is_equal(1)
	assert_array(_events).is_equal(["left"])
	if _left_intents.size() == 1:
		assert_dict(_left_intents[0]["address"]).is_equal({"container": "bag", "owner": PROFILE, "slot": 0})
	assert_bool(var_to_bytes(_panel.cached_view()) == before).is_true()

func test_real_icon_region_click_and_hover_keep_original_slot_intent() -> void:
	await _click_decoration("MaterialIcon")

func test_real_quantity_region_click_and_hover_keep_original_slot_intent() -> void:
	await _click_decoration("MaterialQuantity")

# Test-window setup is a fixture precondition, never a production layout fix.
func _fixture_layout_ready() -> bool:
	if not is_instance_valid(_fixture_window) or not is_instance_valid(_panel):
		return false
	var expected := Rect2(Vector2.ZERO, Vector2(FIXTURE_WINDOW_SIZE))
	if _fixture_window.size != FIXTURE_WINDOW_SIZE or _fixture_window.get_visible_rect() != expected:
		return false
	if _panel.get_viewport() != _fixture_window or _panel.get_global_rect() != expected:
		return false
	for grid: GridContainer in [_panel._bag_grid, _panel._hotbar_grid]:
		if not grid.is_visible_in_tree() or grid.size.x <= 0.0 or grid.size.y <= 0.0 or not expected.encloses(grid.get_global_rect()):
			return false
		for child in grid.get_children():
			var slot: Control = child
			if not slot.is_visible_in_tree() or slot.size != Vector2(68, 56) or not expected.encloses(slot.get_global_rect()):
				return false
	return true

func _wait_fixture_layout() -> bool:
	var started_usec: int = Time.get_ticks_usec()
	for _frame: int in range(FIXTURE_FRAME_LIMIT):
		await get_tree().process_frame
		if Time.get_ticks_usec() - started_usec > FIXTURE_TIMEOUT_USEC:
			return false
		if _fixture_layout_ready():
			return true
	return false

func _restore_fixture_window() -> bool:
	if not _fixture_size_owned:
		return true
	if not is_instance_valid(_fixture_window):
		return false
	_fixture_window.size = _fixture_saved_size
	var started_usec: int = Time.get_ticks_usec()
	for _frame: int in range(FIXTURE_FRAME_LIMIT):
		await get_tree().process_frame
		if Time.get_ticks_usec() - started_usec > FIXTURE_TIMEOUT_USEC:
			return false
		if _fixture_window.size == _fixture_saved_size and _fixture_window.get_visible_rect() == _fixture_saved_rect:
			_fixture_size_owned = false
			return true
	return false

func _wait_pointer_and_natural_carry(point: Vector2, started_usec: int) -> bool:
	for _frame: int in range(FIXTURE_FRAME_LIMIT - 1):
		await get_tree().process_frame
		if Time.get_ticks_usec() - started_usec > FIXTURE_TIMEOUT_USEC:
			return false
		if not _panel.get_viewport().get_mouse_position().is_equal_approx(point):
			continue
		if not _panel.is_processing():
			return false
		if _panel._carry.visible and not _panel._carry.position.is_equal_approx(_panel.get_local_mouse_position() + Vector2(18, 18)):
			continue
		return true
	return false

# Pair only this fixture's injected left-down, while its original Panel lives.
# A cleanup-generated local intent never counts as a successful test assertion.
func _release_owned_left_button() -> bool:
	if not _fixture_left_down_owned:
		return true
	var release := InputEventMouseButton.new()
	release.position = _fixture_left_position
	release.global_position = _fixture_left_global_position
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	var started_usec: int = Time.get_ticks_usec()
	for _frame: int in range(FIXTURE_FRAME_LIMIT):
		await get_tree().process_frame
		if Time.get_ticks_usec() - started_usec > FIXTURE_TIMEOUT_USEC:
			return false
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_fixture_left_down_owned = false
			return true
	# Preserve ownership if release was not observed, so final cleanup may pair it.
	return false
