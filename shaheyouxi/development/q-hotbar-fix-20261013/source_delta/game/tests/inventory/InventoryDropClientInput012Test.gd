extends GdUnitTestSuite
## Real Input.parse_input_event -> original Panel._input/drop_intent -> original
## production Client drop bridge. Only the outgoing RPC seam is captured.
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const View = preload("res://scripts/inventory/ui012/inventory_view012.gd")
const InventoryPanel = preload("res://scripts/inventory/ui012/inventory_panel012.gd")
const Coordinates = preload("res://scripts/actor/actor_view_projection.gd")
const WORLD := "world_11111111111111111111111111111111"
const PROFILE := "player_drop_input_fixture"
const CHEST := "chest_drop_input_fixture"
class DrawingView extends Node2D:
	func drawing_state() -> Dictionary:
		return {"actors":[{"own":true,"world_position":Vector2(1.5,-1.0)}]}
class CapturedClient extends "res://scripts/actor/actor_terrain_play_client.gd":
	var pointer: Dictionary = {}
	var issued: Array = []
	func _current_pointer_world() -> Dictionary:
		return pointer.duplicate(true)
	func _issue_inventory(kind: String, epoch: int, address: Dictionary = {}, revision: int = -1, sequence: int = -1, drop_kind: String = "", aim: Array = []) -> void:
		issued.append({"kind":kind,"epoch":epoch,"address":address.duplicate(true),"revision":revision,"sequence":sequence,"drop_kind":drop_kind,"aim":aim.duplicate()})
var _panel: Control
var _client: CapturedClient
var _drawing: DrawingView
var _before: PackedByteArray
func before_test() -> void:
	var core := Core.new(WORLD)
	core.trusted_create_player(PROFILE)
	core.trusted_create_chest(CHEST)
	var state: Dictionary = core.snapshot()
	var stack := {"content_id":"mucai","quantity":7,"item_instance_id":"","protected_instance_id":"","state":{}}
	state["players"][PROFILE]["carry"] = stack.duplicate(true)
	state["players"][PROFILE]["carry_origin"] = {"container":"bag","owner":PROFILE,"slot":0}
	state["players"][PROFILE]["hotbar"][0] = stack.duplicate(true)
	state["players"][PROFILE]["bag"][0] = stack.duplicate(true)
	state["chests"][CHEST]["slots"][0] = stack.duplicate(true)
	assert_bool(core.trusted_restore(state)["ok"]).is_true()
	assert_bool(core.trusted_set_chest_access(PROFILE, CHEST, true)["ok"]).is_true()
	_panel = InventoryPanel.new()
	_panel.bind_identity(WORLD,PROFILE)
	_panel.build_controls()
	_panel.apply_server_view(View.server_view(core,PROFILE,1))
	_before = var_to_bytes(_panel.cached_view())
	_drawing = DrawingView.new()
	_client = CapturedClient.new() # Not added: no transport/startup replacement.
	_client._world_view = _drawing
	_client._inventory_panel = _panel
	var projection := {"ok":true,"screen_bounds":Rect2(0,0,200,100),"world_bounds":Rect2(-10,-5,20,10),"scale":10.0,"layer":{}}
	_client.pointer = Coordinates.screen_to_world(projection,Vector2(160,20))
	assert_bool(_client.pointer["world_point"] is Array).is_true()
	_panel.drop_intent.connect(_client._request_inventory_drop)
	add_child(_panel)
	await get_tree().process_frame
func after_test() -> void:
	_panel.free()
	_drawing.free()
	_client.free()
func _mouse(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.position = Vector2(-100,-100) # Outside all inventory/hotbar rectangles.
	event.global_position = event.position
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame
func _assert_drop(kind: String, aim: Array) -> void:
	assert_int(_client.issued.size()).is_equal(1)
	if _client.issued.size() != 1: return
	assert_str(_client.issued[0]["kind"]).is_equal("drop")
	assert_str(_client.issued[0]["drop_kind"]).is_equal(kind)
	assert_array(_client.issued[0]["aim"]).is_equal(aim)
	assert_int(typeof(_client.issued[0]["aim"][0])).is_equal(TYPE_FLOAT)
	assert_int(typeof(_client.issued[0]["aim"][1])).is_equal(TYPE_FLOAT)
	assert_bool(var_to_bytes(_panel.cached_view()) == _before).is_true()
func test_real_right_button_projection_array_to_wire_float_direction() -> void:
	await _mouse(MOUSE_BUTTON_RIGHT)
	_assert_drop("right_half",[4.5,-2.0])
func test_real_outside_left_projection_array_to_wire_float_direction() -> void:
	await _mouse(MOUSE_BUTTON_LEFT)
	_assert_drop("carry_all",[4.5,-2.0])
func test_real_q_key_uses_same_projection_conversion() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_Q
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await get_tree().process_frame
	_assert_drop("q_one",[4.5,-2.0])
func test_outside_projection_keeps_zero_aim_right_half_intent() -> void:
	_client.pointer = {"ok":false,"code":"ACTOR_VIEW_POINTER_OUTSIDE"}
	await _mouse(MOUSE_BUTTON_RIGHT)
	_assert_drop("right_half",[0.0,0.0])

func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _hover_slot(grid: GridContainer, slot: int, expected: Dictionary) -> void:
	var event := InputEventMouseMotion.new()
	event.position = grid.get_child(slot).get_global_rect().get_center()
	event.global_position = event.position
	Input.parse_input_event(event)
	await get_tree().process_frame
	# Prove the pointer really resolves to the unwanted source before pressing Q.
	assert_dict(_panel._hovered_address()).is_equal(expected)

func _assert_selected_q(slot: int) -> void:
	_assert_drop("q_one",[4.5,-2.0])
	assert_dict(_client.issued[0]["address"]).is_equal({"container":"hotbar","owner":PROFILE,"slot":slot})

func test_real_q_over_bag_uses_number_selected_hotbar_even_when_empty() -> void:
	assert_bool(_panel.open_personal()).is_true()
	await get_tree().process_frame
	await _key(KEY_2)
	assert_that(_panel.cached_view()["inventory"]["hotbar"][1]).is_null()
	await _hover_slot(_panel._bag_grid, 0, {"container":"bag","owner":PROFILE,"slot":0})
	await _key(KEY_Q)
	_assert_selected_q(1)

func test_real_q_over_other_hotbar_slot_uses_selected_zero_key_slot() -> void:
	await _key(KEY_0)
	await _hover_slot(_panel._hotbar_grid, 0, {"container":"hotbar","owner":PROFILE,"slot":0})
	await _key(KEY_Q)
	_assert_selected_q(9)

func test_real_q_over_authorized_chest_uses_selected_hotbar() -> void:
	assert_bool(_panel.grant_chest_context(CHEST, _panel.context_epoch())).is_true()
	assert_bool(_panel.open_chest(CHEST)).is_true()
	await get_tree().process_frame
	await _key(KEY_2)
	await _hover_slot(_panel._chest_grid, 0, {"container":"chest","owner":CHEST,"slot":0})
	await _key(KEY_Q)
	_assert_selected_q(1)

func test_real_q_uses_wheel_selection_with_both_wrap_directions() -> void:
	await _key(KEY_1)
	await _mouse(MOUSE_BUTTON_WHEEL_UP)
	await _key(KEY_Q)
	_assert_selected_q(9)
	assert_bool(_panel.reject_left_intent(_panel._pending_sequence)).is_true()
	_client.issued.clear()
	await _mouse(MOUSE_BUTTON_WHEEL_DOWN)
	await _key(KEY_Q)
	_assert_selected_q(0)
