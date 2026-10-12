extends GdUnitTestSuite
## TEST SOURCE ONLY. Requires separately approved Godot resource window.
## Pure geometry and isolated presentation fixtures. No pointer/event injection,
## native-click claim, pixel acceptance, transport, live inventory change or stage.
const CarryVisualClamp = preload("res://scripts/inventory/ui012/carry_visual_clamp012.gd")
const InventoryPanel = preload("res://scripts/inventory/ui012/inventory_panel012.gd")
const InventoryCore = preload("res://scripts/inventory/inventory_core012.gd")
const InventoryView = preload("res://scripts/inventory/ui012/inventory_view012.gd")
const WORLD := "world_11111111111111111111111111111111"
const PROFILE := "player_carry_clamp_fixture"
var _viewport: SubViewport
var _host: Control
var _panel: Control
var _events: Array = []

func before_test() -> void:
	_events = []
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 480)
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_host = Control.new()
	_host.size = Vector2(640, 480)
	_viewport.add_child(_host)
	_panel = InventoryPanel.new()
	assert_bool(_panel.bind_identity(WORLD, PROFILE)).is_true()
	_host.add_child(_panel)
	_panel.set_process(false)
	_panel.set_process_input(false)
	_panel.set_process_unhandled_key_input(false)
	_panel.left_intent.connect(func(_a: Dictionary, _r: int, _s: int) -> void: _events.append("left"))
	_panel.drop_intent.connect(func(_k: String, _a: Dictionary, _r: int, _s: int) -> void: _events.append("drop"))
	_panel.close_intent.connect(func(_r: String, _v: int) -> void: _events.append("close"))
	_panel.open_intent.connect(func() -> void: _events.append("open"))
	_panel.view_rejected.connect(func(_code: String) -> void: _events.append("rejected"))
	var core: RefCounted = InventoryCore.new(WORLD)
	assert_bool(core.trusted_create_player(PROFILE)["ok"]).is_true()
	var view: Dictionary = InventoryView.server_view(core, PROFILE, 1)
	view["inventory"]["carry"] = _material(999)
	view["inventory"]["carry_origin"] = {"container": "bag", "owner": PROFILE, "slot": 0}
	assert_bool(_panel.apply_server_view(view)["ok"]).is_true()
	await get_tree().process_frame

func after_test() -> void:
	_viewport.free()
	_panel = null
	_host = null
	_viewport = null

static func _material(count: int) -> Dictionary:
	return {"content_id": "mucai", "quantity": count, "item_instance_id": "", "protected_instance_id": "", "state": {}}

func _set_carry(entry: Variant) -> void:
	var view: Dictionary = _panel.cached_view()
	view["view_sequence"] += 1
	view["revision"] += 1
	view["inventory"]["carry"] = entry
	view["inventory"]["carry_origin"] = null if entry == null else {"container": "bag", "owner": PROFILE, "slot": 0}
	assert_bool(_panel.apply_server_view(view)["ok"]).is_true()

func _set_unknown() -> void:
	_set_carry({"content_id": "wuqi_huoqi_tansuo_01", "quantity": 1, "item_instance_id": "carry_clamp_unknown", "protected_instance_id": "", "state": {}})

func _state_bytes() -> PackedByteArray:
	return var_to_bytes([_panel.cached_view(), _panel._last_emitted, _panel._pending_sequence, _panel._context, _panel._context_epoch, _panel._granted_chest, _panel._requests_enabled, _panel._left_enabled])

func _assert_inside(viewport_rect: Rect2, measured: Rect2) -> void:
	assert_bool(measured.position.x >= viewport_rect.position.x - 0.001).is_true()
	assert_bool(measured.position.y >= viewport_rect.position.y - 0.001).is_true()
	assert_bool(measured.end.x <= viewport_rect.end.x + 0.001).is_true()
	assert_bool(measured.end.y <= viewport_rect.end.y + 0.001).is_true()

func _assert_material_frames_inside() -> void:
	for decoration_name: String in ["MaterialIcon", "MaterialQuantity"]:
		var decoration: Control = _panel._carry.get_node(decoration_name)
		var transformed: Rect2 = decoration.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, decoration.size)
		_assert_inside(_viewport.get_visible_rect(), transformed)

func test_interior_preserves_exact_local_pointer_plus_18_and_full_child_union() -> void:
	var result: Dictionary = CarryVisualClamp.place(_panel, _panel._carry, Vector2(218, 218))
	assert_bool(result["available"] and result["layout_contained"] and not result["limited"]).is_true()
	assert_bool(result["position"] == Vector2(218, 218)).is_true()
	assert_bool(result["correction_viewport"] == Vector2.ZERO).is_true()
	assert_bool(result["layout_union_viewport"] == Rect2(222, 222, 60, 52)).is_true()
	assert_str(_panel._carry.text).is_equal("")

func test_four_pointer_edges_and_four_corners_keep_both_frames_inside() -> void:
	var points: Array[Vector2] = [Vector2(0, 240), Vector2(639, 240), Vector2(320, 0), Vector2(320, 479), Vector2(0, 0), Vector2(639, 0), Vector2(0, 479), Vector2(639, 479)]
	for pointer: Vector2 in points:
		var requested: Vector2 = pointer + Vector2(18, 18)
		var result: Dictionary = CarryVisualClamp.place(_panel, _panel._carry, requested)
		assert_bool(result["layout_contained"] and not result["limited"]).is_true()
		_panel._carry.position = result["position"] # Fixture visual only; not input.
		_assert_material_frames_inside()
		if pointer.x == 0 and pointer.y <= 240:
			assert_bool(result["position"] == requested).is_true()

func test_minimum_translation_covers_all_four_overflow_sides_and_corners() -> void:
	var viewport_rect := Rect2(10, 20, 100, 80)
	for origin: Vector2 in [Vector2(0, 40), Vector2(100, 40), Vector2(40, 0), Vector2(40, 90), Vector2(0, 0), Vector2(100, 0), Vector2(0, 90), Vector2(100, 90)]:
		var result: Dictionary = CarryVisualClamp.fit_union(Rect2(origin, Vector2(30, 20)), viewport_rect)
		assert_bool(result["layout_contained"]).is_true()
		var expected := Vector2(clampf(origin.x, 10, 80), clampf(origin.y, 20, 80))
		assert_bool(result["layout_union_viewport"] == Rect2(expected, Vector2(30, 20))).is_true()

func test_exact_fit_keeps_zero_correction() -> void:
	var rectangle := Rect2(10, 20, 100, 80)
	var result: Dictionary = CarryVisualClamp.fit_union(rectangle, rectangle)
	assert_bool(result["layout_contained"] and result["correction_viewport"] == Vector2.ZERO).is_true()

func test_small_viewport_deterministically_aligns_each_oversized_axis() -> void:
	for dimensions: Vector2 in [Vector2(20, 80), Vector2(100, 10), Vector2(20, 10)]:
		var rectangle := Rect2(Vector2(10, 20), dimensions)
		var result: Dictionary = CarryVisualClamp.fit_union(Rect2(200, 200, 60, 52), rectangle)
		assert_bool(result["limited"] and not result["layout_contained"]).is_true()
		assert_str(result["status"]).is_equal("limited")
		var union_rect: Rect2 = result["layout_union_viewport"]
		assert_bool(union_rect.size == Vector2(60, 52)).is_true()
		if dimensions.x < 60: assert_float(union_rect.position.x).is_equal(10.0)
		if dimensions.y < 52: assert_float(union_rect.position.y).is_equal(20.0)

func test_small_viewport_place_changes_no_scale_clip_size_or_text() -> void:
	_viewport.size = Vector2i(20, 10)
	var icon: TextureRect = _panel._carry.get_node("MaterialIcon")
	var quantity: Label = _panel._carry.get_node("MaterialQuantity")
	var before: PackedByteArray = var_to_bytes([_panel._carry.size, _panel._carry.scale, _panel._carry.clip_contents, icon.size, icon.scale, quantity.text, quantity.size, quantity.clip_text])
	var result: Dictionary = CarryVisualClamp.place(_panel, _panel._carry, Vector2(218, 218))
	assert_bool(result["limited"] and not result["layout_contained"]).is_true()
	assert_bool(before == var_to_bytes([_panel._carry.size, _panel._carry.scale, _panel._carry.clip_contents, icon.size, icon.scale, quantity.text, quantity.size, quantity.clip_text])).is_true()

func test_invalid_geometry_reports_unavailable() -> void:
	for rectangle: Rect2 in [Rect2(), Rect2(0, 0, -1, 20), Rect2(Vector2(NAN, 0), Vector2(60, 52))]:
		var result: Dictionary = CarryVisualClamp.fit_union(rectangle, Rect2(0, 0, 640, 480))
		assert_bool(not result["available"] and not result["layout_contained"] and result["limited"]).is_true()
	assert_bool(not CarryVisualClamp.fit_union(Rect2(0, 0, 60, 52), Rect2())["available"]).is_true()

func test_unknown_fallback_uses_original_label_layout_and_alignment() -> void:
	_set_unknown()
	await get_tree().process_frame
	var carry: Label = _panel._carry
	carry.size = Vector2(460, 140)
	carry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	carry.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var measured: Dictionary = CarryVisualClamp._label_envelope(carry)
	assert_bool(measured["available"] and measured["has_visual"]).is_true()
	var envelope: Rect2 = measured["rect"]
	var saw_character: bool = false
	for index: int in range(carry.get_total_character_count()):
		var character_rect: Rect2 = carry.get_character_bounds(index)
		if character_rect.has_area():
			saw_character = true
			_assert_inside(envelope, character_rect)
	assert_bool(saw_character and envelope.position.x > 0 and envelope.position.y > 0).is_true()
	var result: Dictionary = CarryVisualClamp.place(_panel, carry, Vector2(630, 470))
	assert_bool(result["layout_contained"]).is_true()
	carry.position = result["position"]
	_assert_inside(_viewport.get_visible_rect(), carry.get_global_transform_with_canvas() * envelope)
	assert_bool(not carry.get_node("MaterialIcon").visible and not carry.get_node("MaterialQuantity").visible).is_true()

func test_current_theme_outline_and_shadow_expand_fallback_layout() -> void:
	_set_unknown()
	await get_tree().process_frame
	var carry: Label = _panel._carry
	carry.add_theme_constant_override("outline_size", 0)
	carry.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	var baseline: Rect2 = CarryVisualClamp._label_envelope(carry)["rect"]
	carry.add_theme_constant_override("outline_size", 3)
	carry.add_theme_color_override("font_outline_color", Color.WHITE)
	carry.add_theme_color_override("font_shadow_color", Color.BLACK)
	carry.add_theme_constant_override("shadow_outline_size", 2)
	carry.add_theme_constant_override("shadow_offset_x", -9)
	carry.add_theme_constant_override("shadow_offset_y", 7)
	var shadow: Rect2 = baseline.grow(2)
	shadow.position += Vector2(-9, 7)
	var expected: Rect2 = baseline.grow(3).merge(shadow)
	assert_bool(CarryVisualClamp._label_envelope(carry)["rect"] == expected).is_true()

func test_empty_and_hidden_carry_have_no_stale_union() -> void:
	_set_carry(null)
	var result: Dictionary = CarryVisualClamp.place(_panel, _panel._carry, Vector2(630, 470))
	assert_bool(result["available"] and not result["has_visual"] and result["layout_contained"]).is_true()
	assert_str(result["status"]).is_equal("empty")
	_set_carry(_material(3))
	_panel._carry.hide()
	assert_str(CarryVisualClamp.place(_panel, _panel._carry, Vector2(630, 470))["status"]).is_equal("empty")

func test_parent_scale_rotation_and_viewport_canvas_transform() -> void:
	_host.position = Vector2(25, -17)
	_host.scale = Vector2(1.3, 0.8)
	_host.rotation = 0.23
	_viewport.canvas_transform = Transform2D(0.11, Vector2(1.2, 0.9), 0.0, Vector2(35, 20))
	_check_transformed_placement()

func test_canvas_layer_transform_and_reflected_parent() -> void:
	var layer := CanvasLayer.new()
	_viewport.add_child(layer)
	_viewport.remove_child(_host)
	layer.add_child(_host)
	layer.transform = Transform2D(-0.14, Vector2(0.8, 1.2), 0.08, Vector2(45, 30))
	_host.scale = Vector2(-1.1, 0.9)
	_host.position = Vector2(550, 20)
	_check_transformed_placement()

func _check_transformed_placement() -> void:
	var conversion: Transform2D = _panel.get_global_transform_with_canvas()
	var interior: Vector2 = conversion.affine_inverse() * Vector2(320, 240) + Vector2(18, 18)
	var result: Dictionary = CarryVisualClamp.place(_panel, _panel._carry, interior)
	assert_bool(result["position"] == interior and result["layout_contained"]).is_true()
	for viewport_pointer: Vector2 in [Vector2(0, 0), Vector2(639, 0), Vector2(0, 479), Vector2(639, 479)]:
		var requested: Vector2 = conversion.affine_inverse() * viewport_pointer + Vector2(18, 18)
		result = CarryVisualClamp.place(_panel, _panel._carry, requested)
		assert_bool(result["layout_contained"]).is_true()
		_panel._carry.position = result["position"]
		_assert_material_frames_inside()

func test_resize_remeasures_visible_viewport_without_cached_bounds() -> void:
	var first: Dictionary = CarryVisualClamp.place(_panel, _panel._carry, Vector2(618, 458))
	_viewport.size = Vector2i(320, 240)
	await get_tree().process_frame
	var second: Dictionary = CarryVisualClamp.place(_panel, _panel._carry, Vector2(618, 458))
	assert_bool(first["position"] != second["position"]).is_true()
	_panel._carry.position = second["position"]
	_assert_material_frames_inside()

func test_near_singular_transform_is_display_unavailable_only() -> void:
	var before: PackedByteArray = _state_bytes()
	_host.scale = Vector2(0.00001, 0.00001)
	var result: Dictionary = CarryVisualClamp.place(_panel, _panel._carry, Vector2(218, 218))
	assert_bool(not result["available"] and result["limited"] and not result["layout_contained"]).is_true()
	assert_bool(result["position"] == Vector2(218, 218)).is_true()
	assert_bool(before == _state_bytes()).is_true()
	assert_array(_events).is_equal([])

func test_unknown_future_label_modes_report_unavailable_without_state_rejection() -> void:
	_set_unknown()
	await get_tree().process_frame
	var before: PackedByteArray = _state_bytes()
	_panel._carry.label_settings = LabelSettings.new()
	var result: Dictionary = CarryVisualClamp.place(_panel, _panel._carry, Vector2(218, 218))
	assert_str(result["reason"]).is_equal("fallback_mode_outside_fixed_scope")
	assert_bool(before == _state_bytes()).is_true()
	assert_array(_events).is_equal([])

func test_unattached_missing_decoration_and_nonfinite_request_are_unavailable() -> void:
	var unattached := Label.new()
	assert_str(CarryVisualClamp.place(_panel, unattached, Vector2.ZERO)["reason"]).is_equal("unattached_carry")
	unattached.free()
	var quantity: Label = _panel._carry.get_node("MaterialQuantity")
	_panel._carry.remove_child(quantity)
	assert_str(CarryVisualClamp.place(_panel, _panel._carry, Vector2.ZERO)["reason"]).is_equal("missing_fixed_decorations")
	_panel._carry.add_child(quantity)
	var result: Dictionary = CarryVisualClamp.place(_panel, _panel._carry, Vector2(NAN, 0))
	assert_str(result["reason"]).is_equal("nonfinite_requested_position")
	assert_bool(result["position"] == _panel._carry.position and result["has_visual"] == null).is_true()

func test_unexpected_icon_and_quantity_modes_do_not_claim_containment() -> void:
	var icon: TextureRect = _panel._carry.get_node("MaterialIcon")
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	assert_str(CarryVisualClamp.place(_panel, _panel._carry, Vector2.ZERO)["reason"]).is_equal("unexpected_icon_layout")
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var quantity: Label = _panel._carry.get_node("MaterialQuantity")
	quantity.clip_text = false
	assert_str(CarryVisualClamp.place(_panel, _panel._carry, Vector2.ZERO)["reason"]).is_equal("unexpected_quantity_layout")

func test_fallback_empty_transparent_clipped_and_unreviewed_effect_paths() -> void:
	assert_bool(not CarryVisualClamp._label_envelope(_panel._carry)["has_visual"]).is_true()
	_set_unknown()
	await get_tree().process_frame
	var carry: Label = _panel._carry
	carry.add_theme_color_override("font_color", Color.TRANSPARENT)
	carry.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	carry.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	assert_bool(not CarryVisualClamp._label_envelope(carry)["has_visual"]).is_true()
	carry.add_theme_color_override("font_color", Color.WHITE)
	carry.clip_text = true
	var measured: Dictionary = CarryVisualClamp._label_envelope(carry)
	assert_bool(measured["available"] and measured["has_visual"]).is_true()
	_assert_inside(Rect2(Vector2.ZERO, carry.size), measured["rect"])
	carry.add_theme_stylebox_override("normal", StyleBoxFlat.new())
	assert_str(CarryVisualClamp._label_envelope(carry)["reason"]).is_equal("fallback_effect_outside_fixed_scope")

func test_helper_is_read_only_and_diagnostics_are_detached() -> void:
	var before: PackedByteArray = _state_bytes()
	var initial_position: Vector2 = _panel._carry.position
	var icon: TextureRect = _panel._carry.get_node("MaterialIcon")
	var texture_id: int = icon.texture.get_instance_id()
	for requested: Vector2 in [Vector2(218, 218), Vector2(639, 479), Vector2(-300, -100)]:
		CarryVisualClamp.place(_panel, _panel._carry, requested)
	assert_bool(_panel._carry.position == initial_position).is_true()
	assert_int(icon.texture.get_instance_id()).is_equal(texture_id)
	_panel._process(0.0) # Original actual mouse read, no input fabrication.
	var state: Dictionary = _panel.carry_visual_state()
	assert_bool(state["requested_position"] == _panel.get_local_mouse_position() + Vector2(18, 18)).is_true()
	state["position"] = Vector2(-9999, -9999)
	assert_bool(_panel.carry_visual_state()["position"] != state["position"]).is_true()
	assert_bool(before == _state_bytes()).is_true()
	assert_array(_events).is_equal([])
	for decoration: Control in [_panel._carry, icon, _panel._carry.get_node("MaterialQuantity")]:
		assert_int(decoration.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	_set_carry(null)
	_panel._process(0.0)
	assert_str(_panel.carry_visual_state()["status"]).is_equal("empty")
