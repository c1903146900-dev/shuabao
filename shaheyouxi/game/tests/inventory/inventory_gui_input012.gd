extends SceneTree
## Actual ordinary Coordinator -> production Client -> production Panel.
## Input.parse_input_event feeds real viewport key/mouse dispatch, never request
## functions. This is an automated GUI input test, not a manual user session.
const Coordinator = preload("res://scripts/actor/actor_local_session_coordinator.gd")
const ActorProjection = preload("res://scripts/actor/actor_view_projection.gd")
var coordinator: Node
var output := ""
var failed := false
var finished := false
var records: Array = []
var fixture: Dictionary = {}
var deadline: int = 0
var session_finished := false
var session_success := false
var phase := "startup"
var phase_started_usec: int = 0
var phase_limit_usec: int = 0
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	output = OS.get_environment("SANDBOX_GUI_USER_ROOT")
	if output.is_empty() or output != OS.get_user_data_dir():
		_fail("GUI_USER_SCOPE_INVALID")
		return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("gui_fixture.json")))
	if not value is Dictionary or value.get("kind") != "explicit_offline_gui_inventory_fixture":
		_fail("GUI_FIXTURE_MISSING")
		return
	fixture = value
	deadline = Time.get_ticks_usec() + 95000000
	coordinator = Coordinator.new()
	coordinator.name = "OrdinaryCoordinator"
	root.add_child(coordinator)
	coordinator.session_finished.connect(func(success: bool, _message: String) -> void:
		session_finished = true
		session_success = success)
	if not coordinator.configure().get("ok", false) or not coordinator.continue_world(fixture["slot_id"]).get("ok", false):
		_fail("GUI_COORDINATOR_START_FAILED")
		return
	while not _inventory_ready():
		if not _alive(): return
		await process_frame
	await _key(KEY_I)
	while _panel()._context != "personal" or _client()._inventory_live.client_pending_count() != 0:
		if not _alive(): return
		await process_frame
	await _capture("00_initial")
	var aim := _aim_point()
	if not aim.is_finite():
		_fail("GUI_AIM_UNAVAILABLE")
		return
	# Half of7 cannot fit into original997 (room2): entire4 must drop.
	await _mouse(aim, MOUSE_BUTTON_RIGHT)
	if not await _sequence(20): return
	var player := _player()
	if player["bag"][0]["quantity"] != 997 or player["carry"]["quantity"] != 3:
		_fail("GUI_HALF_FALLBACK_WRONG")
		return
	_record("right_half_full_drop")
	# Real movement input moves the thrower just outside pickup radius3 while
	# keeping later landing points within the existing one-cell merge radius.
	if not await _retreat_from_drop(): return
	# Place/lift through actual Button GUI events, then half-return into empty origin.
	await _mouse(_slot(3), MOUSE_BUTTON_LEFT)
	if not await _sequence(21): return
	if _player()["carry"] != null:
		_fail("GUI_SLOT_PLACE_FAILED")
		return
	await _mouse(_slot(3), MOUSE_BUTTON_LEFT)
	if not await _sequence(22): return
	await _mouse(_aim_point(), MOUSE_BUTTON_RIGHT)
	if not await _sequence(23): return
	player = _player()
	if player["bag"][3]["quantity"] != 2 or player["carry"]["quantity"] != 1:
		_fail("GUI_HALF_RETURN_WRONG")
		return
	_record("right_half_return")
	# The pointer must be outside inventory and hotbar for whole-carry left drop.
	await _key(KEY_I)
	if not await _controls_settled(): return
	await _mouse(_aim_point(), MOUSE_BUTTON_LEFT)
	if not await _sequence(24): return
	if _player()["carry"] != null:
		_fail("GUI_WHOLE_CARRY_DROP_WRONG")
		return
	# Q with world pointer uses selected hotbar0: exactly one of10.
	await _move(_aim_point())
	await _key(KEY_Q)
	if not await _sequence(25): return
	if _player()["hotbar"][0]["quantity"] != 9:
		_fail("GUI_Q_ONE_WRONG")
		return
	_record("q_one_and_whole_carry")
	while not _merged_six():
		if not _alive(): return
		await process_frame
	_record("same_layer_one_cell_merge_six")
	await _capture("01_ground_merged_six")
	# Leave2 on cursor, close panel, then click visible hotbar. Must not mis-drop.
	await _key(KEY_I)
	if not await _controls_settled(): return
	await _mouse(_slot(3), MOUSE_BUTTON_LEFT)
	if not await _sequence(26): return
	await _key(KEY_I)
	if not await _controls_settled(): return
	var cursor: Dictionary = _client()._inventory_live.client_checkpoint()
	await _mouse(_panel()._hotbar_grid.get_child(0).get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await process_frame
	var after_click: Dictionary = _client()._inventory_live.client_checkpoint()
	var unchanged := true
	for key in ["issued_sequence", "processed_sequence", "accepted_sequence", "pending_count"]:
		if after_click[key] != cursor[key]: unchanged = false
	if not unchanged or _player()["carry"]["quantity"] != 2:
		_fail("GUI_CLOSED_HOTBAR_MISDROP")
		return
	_record("closed_hotbar_no_misdrop")
	await _capture("02_carry_before_f10")
	await _key(KEY_F10)
	while not session_finished:
		if not _alive(): return
		await process_frame
	if not session_success or coordinator._forced:
		_fail("GUI_NORMAL_CLOSE_FAILED")
		return
	var saved: Dictionary = coordinator._slots.inspect_save(fixture["slot_id"])
	if not saved.get("ok", false) or saved.get("reason") != "normal_shutdown":
		_fail("GUI_FINAL_SAVE_MISSING")
		return
	var final_player: Dictionary = saved["state"]["inventory_component"]["players"][fixture["profile_id"]]
	if not final_player["carry"] is Dictionary or final_player["carry"].get("quantity") != 2 or final_player["last_sequence"] != 26:
		_fail("GUI_FINAL_CARRY_WRONG")
		return
	var component: Dictionary = saved["state"]["inventory_component"]
	var wood := 0
	for item in final_player["bag"] + final_player["hotbar"] + [final_player["carry"]]:
		if item is Dictionary and item["content_id"] == "mucai": wood += item["quantity"]
	for ground in component.get("ground", {}).values():
		if ground["stack"]["content_id"] == "mucai": wood += ground["stack"]["quantity"]
	var gun: Variant = final_player["bag"][2]
	if wood != 1014 or not gun is Dictionary or gun.get("item_instance_id") != "item_fixture_gun" or gun.get("protected_instance_id") != "protected_fixture_gun" or var_to_bytes(gun.get("state")) != var_to_bytes({"fixture_magazine":3,"bits":-0.0}):
		_fail("GUI_FINAL_CONSERVATION_OR_UNIQUE_STATE")
		return
	finished = true
	_write({"ok":true,"kind":"ordinary_coordinator_gui_input_event_test","manual_input":false,"records":records,"saved_sequence":saved["sequence"],"carry":2,"last_sequence":26,"forced":false})
	coordinator._slots.close()
	quit(0)

func _client() -> Node:
	return coordinator._client
func _panel() -> Control:
	return _client()._inventory_panel
func _inventory_ready() -> bool:
	return is_instance_valid(coordinator._client) and _client()._inventory_live != null and _client()._inventory_live.client_ready() and _client()._inventory_panel != null and _client()._inventory_live.client_pending_count() == 0
func _player() -> Dictionary:
	return _panel().cached_view()["inventory"]
func _slot(index: int) -> Vector2:
	return _panel()._bag_grid.get_child(index).get_global_rect().get_center()
func _aim_point() -> Vector2:
	var drawing: Dictionary = _client()._world_view.drawing_state()
	for actor in drawing.get("actors", []):
		if actor["own"]: return ActorProjection.world_to_screen(drawing, actor["world_position"] + Vector2(0.0,3.0))
	return Vector2(NAN,NAN)
func _own_position() -> Vector2:
	for actor in _client()._world_view.drawing_state().get("actors", []):
		if actor["own"]: return actor["world_position"]
	return Vector2(NAN,NAN)
func _retreat_from_drop() -> bool:
	_begin_phase("retreat_move", 15.0)
	var start := _own_position()
	_set_key(KEY_W, true)
	while start.y - _own_position().y < 0.25:
		if not _alive(): return false
		await process_frame
	var release_sequence: int = _client()._actor_input_pending._next_sequence
	var release_generation: int = _client()._actor_input_pending.cursor()["input_generation"]
	_set_key(KEY_W, false)
	_record("retreat_release_dispatched")
	var release_found := false
	for command in _client()._actor_input_pending.pending():
		if command["sequence"] == release_sequence and command["move"] == [0.0,0.0]: release_found = true
	if not release_found or _client()._actor_input_pending._next_sequence <= release_sequence:
		_fail("GUI_RETREAT_RELEASE_NOT_ISSUED")
		return false
	_begin_phase("retreat_release_authority_cursor", 15.0)
	while _client()._actor_input_pending.cursor()["accepted_sequence"] < release_sequence:
		if not _alive(): return false
		if _client()._actor_input_pending.cursor()["input_generation"] != release_generation:
			_fail("GUI_RETREAT_RELEASE_STREAM_CHANGED")
			return false
		await process_frame
	_record("retreat_release_cursor_covered")
	# Cursor covers admission, not proof every command was executed. Also wait
	# for two distinct authoritative snapshot clocks with stable own position.
	var observed_clock: float = _client()._world_view.statistics()["world_seconds"]
	var observed_position: Vector2 = _own_position()
	var stable_snapshots := 0
	while stable_snapshots < 2:
		if not _alive(): return false
		await process_frame
		if _client()._world_view.statistics()["world_seconds"] <= observed_clock: continue
		var current_position: Vector2 = _own_position()
		stable_snapshots = stable_snapshots + 1 if current_position.distance_to(observed_position) <= 0.0001 else 0
		observed_clock = _client()._world_view.statistics()["world_seconds"]
		observed_position = current_position
	_record("retreat_authoritative_position_stable")
	var distance: float = start.y - _own_position().y
	if distance <= 0.0 or distance > 0.95 or absf(start.x - _own_position().x) > 0.01:
		_fail("GUI_RETREAT_OUTSIDE_TEST_MERGE_GEOMETRY")
		return false
	_begin_phase("ground_visible_outside_pickup_range", 15.0)
	var settle_limit: float = _client()._ground_sync_clock + 1.0
	while true:
		var ground: Array = _client()._world_view._ground_records
		if ground.size() == 1 and ground[0]["quantity"] == 4 and Vector2(ground[0]["position"][0],ground[0]["position"][1]).distance_to(_own_position()) > 3.0: break
		if not _alive(): return false
		if _client()._ground_sync_clock > settle_limit:
			_fail("GUI_FIRST_DROP_NOT_OUTSIDE_PICKUP_RANGE")
			return false
		await process_frame
	_record("real_move_outside_pickup_range")
	_begin_phase("inventory_actions", 0.0)
	return true
func _set_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func _merged_six() -> bool:
	var ground: Array = _client()._world_view._ground_records
	return ground.size() == 1 and ground[0].get("quantity") == 6
func _begin_phase(label: String, seconds: float) -> void:
	phase = label
	phase_started_usec = Time.get_ticks_usec()
	phase_limit_usec = int(seconds * 1000000.0)
	_record("phase_" + label)
func _alive() -> bool:
	if failed: return false
	if phase_limit_usec > 0 and Time.get_ticks_usec() - phase_started_usec >= phase_limit_usec:
		_fail("GUI_STAGE_TIMEOUT_" + phase)
		return false
	if Time.get_ticks_usec() >= deadline or not coordinator._failure.is_empty() or (is_instance_valid(coordinator._client) and coordinator._client._fatal_shutdown):
		_fail("GUI_TIMEOUT_OR_OWNER_FAILURE")
		return false
	return true
func _sequence(expected: int) -> bool:
	# Each caller has already dispatched the real event and awaited frames.
	# The Panel -> Client issue seam is synchronous; no issued request now means
	# a blocked event/bridge failure, not a slow network ACK. Fail visibly early.
	if _client()._inventory_live.client_checkpoint().get("issued_sequence", -1) < expected:
		_fail("GUI_INPUT_NOT_ISSUED_" + str(expected))
		return false
	while _client()._inventory_live.client_checkpoint().get("processed_sequence", -1) < expected or _client()._inventory_live.client_pending_count() != 0:
		if not _alive(): return false
		await process_frame
	if _client()._inventory_live.client_checkpoint().get("accepted_sequence") != expected:
		_fail("GUI_ACTION_REJECTED_" + str(expected))
		return false
	return true
func _controls_settled() -> bool:
	await process_frame
	while _client()._inventory_live.client_pending_count() != 0:
		if not _alive(): return false
		await process_frame
	return true
func _key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
func _move(position: Vector2) -> void:
	Input.warp_mouse(position)
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	await process_frame
func _mouse(position: Vector2, button: MouseButton) -> void:
	await _move(position)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = button
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else (MOUSE_BUTTON_MASK_RIGHT if pressed else 0)
		Input.parse_input_event(event)
		await process_frame
func _record(label: String) -> void:
	var row: Dictionary = {"label":label,"phase":phase,"wall_usec":Time.get_ticks_usec()}
	if is_instance_valid(coordinator) and is_instance_valid(coordinator._client):
		var client: Node = coordinator._client
		row["local_input"] = {"events":client._local_event_count,"intents":client._local_intent_count,"ready":client._local_input_ready,"focused":client._local_focused,"stopped":client._local_input_stopped,"last_error":client._local_last_error}
		if client._local_sampler != null: row["sampler"] = client._local_sampler.state()
		if client._actor_input_pending != null:
			row["actor_cursor"] = client._actor_input_pending.cursor()
			row["actor_pending"] = client._actor_input_pending.pending()
			row["actor_next_sequence"] = client._actor_input_pending._next_sequence
		row["clock"] = client._ground_sync_clock
		if client._inventory_live != null: row["checkpoint"] = client._inventory_live.client_checkpoint()
		if client._inventory_panel != null: row["inventory"] = client._inventory_panel.cached_view().get("inventory", {}).duplicate(true)
		if client._world_view != null and client._world_view.has_method("consume_ground_view"):
			row["ground"] = client._world_view._ground_records.duplicate(true)
			row["ground_layer"] = client._world_view._ground_layer.duplicate(true)
		if client._world_view != null and client._world_view.has_method("drawing_state"):
			for actor in client._world_view.drawing_state().get("actors", []):
				if actor.get("own", false):
					row["actor_position"] = [float(actor["world_position"].x),float(actor["world_position"].y)]
					row["actor_public"] = actor.get("public_state", {}).duplicate(true)
	records.append(row)
	if not output.is_empty():
		var path: String = output.path_join("gui_events.jsonl")
		var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
		if file != null:
			file.seek_end()
			file.store_line(JSON.stringify(row,"",true,true))
			file.flush()
			file.close()
func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	if result != OK: _fail("GUI_CAPTURE_FAILED")
func _write(value: Dictionary) -> void:
	if output.is_empty(): return
	var file := FileAccess.open(output.path_join("gui_result.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value,"",true,true))
		file.close()
func _fail(code: String) -> void:
	if failed: return
	failed = true
	_record("failure_" + code)
	_write({"ok":false,"code":code,"records":records})
	push_error(code)
	quit(1) # Outer guard owns actual descendant cleanup on failure.
