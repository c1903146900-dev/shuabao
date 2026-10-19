extends Node
## Session boundary only. Never migrates, rewards, or restores a hero ledger.
## Ink disposal delegates to its existing abort/evidence boundary, never a savegame.
## Rooms remain independently runnable. Their existing formal/F8 authority stays intact.
const LoadingStatus = preload("res://scripts/integration/loading_status.gd")
var _loading_status: Node
var _load_in_flight := false
var _launch_click_usec := 0

const Chooser = preload("res://scripts/ui/hero_chooser.gd")
const Design = preload("res://data/final_design/catalog.gd")
const YANGUIZHOU_ADAPTER := "res://scripts/integration/yanguizhou_first_floor.gd"
const YANGUIZHOU_VISUAL_ADAPTER := "res://tests/ink_ordinary_visuals_20261007/candidate01/host.gd"
enum Screen { CHOOSER, RUN, CONFIRM, TRANSITION }
const GAME_KEYS := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E, KEY_R, KEY_SHIFT, KEY_ENTER, KEY_KP_ENTER, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_F5, KEY_F8, KEY_K, KEY_P, KEY_ESCAPE]
class InputFence extends Node:
	var entry: Node
	func _input(event: InputEvent) -> void:
		entry.filter_session_input(event)

var front_layer: CanvasLayer
var screen := Screen.CHOOSER
var chooser: Control
var active_room: Node3D
var active_hero := ""
var pending_hero := ""
var session_serial := 0
var return_button: Button
var confirmation: Control
var confirm_button: Button
var cancel_button: Button
var confirmation_text: Label
var error_label: Label
var input_fence: Node
var _pause_nodes: Array = []
var _pause_layers: Array = []
var _was_visible := true
var _was_simulation_paused := false
var _was_audio_paused := false
var _blocked_keys: Dictionary = {}
var _blocked_mouse: Dictionary = {}
var _room_focus: WeakRef
var _root_mode_before_pause := Node.PROCESS_MODE_INHERIT

func _ready() -> void:
	_loading_status = LoadingStatus.new()
	add_child(_loading_status)
	front_layer = CanvasLayer.new()
	front_layer.name = "HeroSelectionLayer"
	front_layer.layer = 100
	add_child(front_layer)
	chooser = Chooser.new()
	front_layer.add_child(chooser)
	chooser.start_requested.connect(request_start)
	chooser.resume_requested.connect(resume_run)
	return_button = Button.new()
	return_button.name = "ReturnToHeroes"
	return_button.theme = Chooser.make_theme()
	return_button.text = "选择英雄"
	return_button.tooltip_text = "暂停当前对局并查看英雄；开始新对局前会再次确认。"
	return_button.position = Vector2(810, 22)
	return_button.size = Vector2(170, 38)
	return_button.pressed.connect(open_chooser)
	front_layer.add_child(return_button)
	return_button.hide()
	_build_confirmation(front_layer)
	error_label = Chooser.text_label("", 16, Color("edaf8e"))
	error_label.position = Vector2(44, 690)
	front_layer.add_child(error_label)
	input_fence = InputFence.new()
	input_fence.name = "SessionInputFence"
	input_fence.entry = self
	add_child(input_fence)
	chooser.hero_buttons.xuanlei.grab_focus()
	print("SHUABAO_HERO_CHOOSER_READY available=%d catalog=%d" % [Chooser.ROOMS.size(), Chooser.HERO_ORDER.size()])

func _build_confirmation(layer: CanvasLayer) -> void:
	confirmation = Control.new()
	confirmation.name = "NewRunConfirmation"
	confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation.theme = Chooser.make_theme()
	layer.add_child(confirmation)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.04, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-290, -190)
	panel.size = Vector2(580, 380)
	panel.add_theme_stylebox_override("panel", Chooser.panel_style(Chooser.PANEL, Chooser.BRONZE))
	confirmation.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	panel.add_child(column)
	column.add_child(Chooser.text_label("开始全新对局？", 26, Chooser.BRONZE))
	confirmation_text = Chooser.text_label("", 17)
	confirmation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(confirmation_text)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	column.add_child(actions)
	cancel_button = Button.new()
	cancel_button.name = "CancelNewRun"
	cancel_button.text = "取消 · 保留当前对局"
	cancel_button.custom_minimum_size.y = 48
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.pressed.connect(cancel_new_run)
	actions.add_child(cancel_button)
	confirm_button = Button.new()
	confirm_button.name = "ConfirmNewRun"
	confirm_button.text = "确认 · 开始新对局"
	confirm_button.custom_minimum_size.y = 48
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.pressed.connect(confirm_new_run)
	actions.add_child(confirm_button)
	cancel_button.focus_neighbor_left = confirm_button.get_path()
	cancel_button.focus_neighbor_right = confirm_button.get_path()
	confirm_button.focus_neighbor_left = cancel_button.get_path()
	confirm_button.focus_neighbor_right = cancel_button.get_path()
	cancel_button.focus_next = confirm_button.get_path()
	cancel_button.focus_previous = confirm_button.get_path()
	confirm_button.focus_next = cancel_button.get_path()
	confirm_button.focus_previous = cancel_button.get_path()
	confirmation.hide()

func request_start(hero_id: String) -> void:
	if screen != Screen.CHOOSER or not Chooser.can_enter(hero_id): return
	error_label.text = ""
	if not is_instance_valid(active_room):
		_launch_click_usec = Time.get_ticks_usec()
		_launch_fresh.call_deferred(hero_id)
		screen = Screen.TRANSITION
		chooser.set_busy(true)
		return
	pending_hero = hero_id
	screen = Screen.CONFIRM
	chooser.set_busy(true)
	var current_name: String = Design.hero(active_hero).get("short_name", active_hero)
	var next_name: String = Design.hero(hero_id).get("short_name", hero_id)
	confirmation_text.text = "当前%s对局将结束，改以%s从 1 级开始。\n\n本局等级、金币、装备、技能、海克斯、任务与试炼进度都会清空；自由测试及保留的正式进度也会一并结束。\n\n不会结算本局奖励，也不会继承任何成长。" % [current_name, next_name]
	confirmation.show()
	cancel_button.grab_focus()

func cancel_new_run() -> void:
	if screen != Screen.CONFIRM: return
	pending_hero = ""
	confirmation.hide()
	screen = Screen.CHOOSER
	chooser.set_busy(false)
	chooser.resume_button.grab_focus()

func confirm_new_run() -> void:
	if screen != Screen.CONFIRM or not Chooser.can_enter(pending_hero): return
	_launch_click_usec = Time.get_ticks_usec()
	var hero_id := pending_hero
	pending_hero = ""
	screen = Screen.TRANSITION
	confirm_button.disabled = true
	cancel_button.disabled = true
	_launch_fresh.call_deferred(hero_id)

func _launch_fresh(hero_id: String) -> void:
	if _load_in_flight or screen != Screen.TRANSITION: return
	_load_in_flight = true
	_loading_status.begin(self, _launch_click_usec)
	await _loading_status.stage("正在请求关卡资源…", "resource_request")
	if not is_inside_tree(): return
	# Validate/load before destruction. Threaded resource work only; no threaded Nodes.
	var path: String = str(Chooser.ROOMS.get(hero_id, ""))
	_loading_status.mark("resource_request_begin_usec")
	var request_error: Error = ResourceLoader.load_threaded_request(path, "PackedScene", false)
	_loading_status.mark("resource_request_return_usec")
	if request_error != OK:
		_recover_failed_start("关卡暂时无法载入，当前对局仍保留。")
		return
	while true:
		var status: int = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED: break
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_recover_failed_start("关卡暂时无法载入，当前对局仍保留。")
			return
		await get_tree().process_frame
		if not is_inside_tree(): return
	_loading_status.mark("resource_loaded_observed_usec")
	# Never call get before LOADED: it otherwise blocks like synchronous load.
	var packed = ResourceLoader.load_threaded_get(path)
	_loading_status.mark("resource_get_return_usec")
	if not packed is PackedScene:
		_recover_failed_start("关卡暂时无法载入，当前对局仍保留。")
		return
	await _loading_status.stage("正在创建关卡对象…", "instantiate")
	if not is_inside_tree(): return
	_loading_status.mark("instantiate_begin_usec")
	var next_room = packed.instantiate()
	_loading_status.mark("instantiate_return_usec")
	if not next_room is Node3D:
		if is_instance_valid(next_room): next_room.free()
		_recover_failed_start("关卡类型无效，当前对局仍保留。")
		return
	if hero_id == "yanguizhou" and not _has_exact_yanguizhou_adapter(next_room):
		next_room.free()
		_recover_failed_start("首层候选入口不匹配，当前对局仍保留。")
		return
	await _loading_status.stage("正在初始化关卡（此阶段可能短暂停顿）…", "host_ready")
	if not is_inside_tree():
		next_room.free()
		return
	_capture_held_inputs()
	if is_instance_valid(active_room):
		if _is_yanguizhou_room() and not active_room.frontdoor_close_run("frontdoor_confirmed_new_run"):
			next_room.free()
			_recover_failed_start("当前动作尚未结束，请稍后重试；当前对局仍保留。")
			return
		_clear_room_input()
		_stop_room_audio()
		# Immediate free at a deferred boundary removes both formal and test sims,
		# their controllers, callbacks, CanvasLayers, voices and per-room audio bus.
		active_room.free()
	active_room = null
	_pause_nodes.clear()
	_pause_layers.clear()
	_room_focus = null
	confirmation.hide()
	confirm_button.disabled = false
	cancel_button.disabled = false
	# Wait for the current GUI event and queued frees before exposing new input.
	await get_tree().process_frame
	if not is_inside_tree():
		next_room.free()
		return
	active_room = next_room
	active_hero = hero_id
	session_serial += 1
	_loading_status.mark("host_add_child_begin_usec")
	add_child(active_room)
	_loading_status.mark("host_add_child_ready_return_usec")
	# The ink host has its own layers 100/110. Keep its 1024 startup mask above us.
	front_layer.layer = 200 if _is_yanguizhou_room() else 100
	return_button.position = Vector2(1070, 66) if _is_yanguizhou_room() else Vector2(810, 22)
	# Input callbacks run children first in reverse tree order. Keep the fence last.
	move_child(input_fence, get_child_count() - 1)
	_capture_held_inputs()
	_clear_room_input()
	chooser.hide()
	chooser.set_busy(false)
	return_button.show()
	var focus := get_viewport().gui_get_focus_owner()
	if focus: focus.release_focus()
	screen = Screen.RUN
	_load_in_flight = false
	await _loading_status.stage("正在准备首次显示…", "first_display")
	if is_inside_tree() and is_instance_valid(active_room): _loading_status.watch_first_usable(active_room)

func _recover_failed_start(message: String) -> void:
	_load_in_flight = false
	_loading_status.fail()
	pending_hero = ""
	confirmation.hide()
	confirm_button.disabled = false
	cancel_button.disabled = false
	chooser.set_busy(false)
	screen = Screen.CHOOSER
	error_label.text = message

func open_chooser() -> void:
	if screen != Screen.RUN or not is_instance_valid(active_room): return
	if _is_yanguizhou_room() and not active_room.frontdoor_can_suspend(): return
	screen = Screen.TRANSITION
	_capture_held_inputs()
	var focus := get_viewport().gui_get_focus_owner()
	_room_focus = weakref(focus) if focus and focus != return_button else null
	_clear_room_input()
	_root_mode_before_pause = active_room.process_mode
	active_room.process_mode = Node.PROCESS_MODE_DISABLED
	return_button.hide()
	# Drain already-requested room UI transactions before taking the pause snapshot.
	# Deferred calls still execute on process-disabled nodes; this boundary preserves
	# the user's last shop/F8 command and includes any newly created test simulation.
	_finish_open_chooser.call_deferred()

func _finish_open_chooser() -> void:
	if screen != Screen.TRANSITION or not is_instance_valid(active_room): return
	if _is_yanguizhou_room():
		active_room.frontdoor_suspend()
	else:
		_was_simulation_paused = bool(active_room.simulation.paused)
		_was_audio_paused = bool(active_room.audio_router.paused)
		active_room.simulation.paused = true
	_stop_room_audio()
	_clear_room_input()
	_was_visible = active_room.visible
	active_room.hide()
	_pause_nodes.clear()
	_pause_layers.clear()
	_suspend_node(active_room)
	_pause_nodes[0].mode = _root_mode_before_pause
	if _is_yanguizhou_room():
		chooser.set_session("晏归舟 · 首层候选", false)
	else:
		chooser.set_session(Design.hero(active_hero).get("short_name", active_hero), active_room.test_mode)
	chooser.select_hero(active_hero)
	chooser.show()
	screen = Screen.CHOOSER
	chooser.resume_button.grab_focus()

func _suspend_node(node: Node) -> void:
	_pause_nodes.append({"node":node, "mode":node.process_mode})
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CanvasLayer:
		_pause_layers.append({"node":node, "visible":node.visible})
		node.hide()
	for child in node.get_children(): _suspend_node(child)

func resume_run() -> void:
	if screen != Screen.CHOOSER or not is_instance_valid(active_room): return
	screen = Screen.TRANSITION
	_capture_held_inputs()
	_clear_room_input()
	for item in _pause_nodes:
		if is_instance_valid(item.node): item.node.process_mode = item.mode
	for item in _pause_layers:
		if is_instance_valid(item.node): item.node.visible = item.visible
	_pause_nodes.clear()
	_pause_layers.clear()
	active_room.visible = _was_visible
	if _is_yanguizhou_room():
		active_room.frontdoor_resume()
	else:
		active_room.simulation.paused = _was_simulation_paused
		active_room.audio_router.set_paused(_was_audio_paused)
	chooser.hide()
	return_button.show()
	var focus := get_viewport().gui_get_focus_owner()
	if focus: focus.release_focus()
	if _room_focus:
		var previous = _room_focus.get_ref()
		if is_instance_valid(previous) and previous.is_visible_in_tree(): previous.grab_focus()
	_room_focus = null
	screen = Screen.RUN

func _is_yanguizhou_room() -> bool:
	return _has_exact_yanguizhou_adapter(active_room)

func _session_game_keys() -> Array:
	return GAME_KEYS + active_room.FRONTDOOR_EXTRA_KEYS if _is_yanguizhou_room() else GAME_KEYS

func _clear_room_input() -> void:
	if not is_instance_valid(active_room): return
	if _is_yanguizhou_room():
		active_room.frontdoor_clear_input()
		return
	active_room.held_keys.clear()
	active_room.attacking = false
	active_room.action_buffer.clear()
	active_room.enter_latched = false
	if is_instance_valid(active_room.simulation): active_room.simulation.hero.move_intent = Vector3.ZERO

func _stop_room_audio() -> void:
	if not is_instance_valid(active_room): return
	if _is_yanguizhou_room():
		active_room.frontdoor_stop_audio()
		return
	active_room.audio_router.set_paused(true)
	active_room.audio_router.sfx.stop_all()

func _capture_held_inputs() -> void:
	for key in _session_game_keys():
		if Input.is_physical_key_pressed(key) or Input.is_key_pressed(key): _blocked_keys[key] = true
	for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if Input.is_mouse_button_pressed(button): _blocked_mouse[button] = true

func filter_session_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode else event.keycode
		# The disabled Ink room cannot receive a real release while the chooser is up.
		# Forward only this exact room's owned E1 release; retain every fence below.
		if key == KEY_E and not event.pressed and not event.echo and (screen != Screen.RUN or _blocked_keys.has(key)) and _is_yanguizhou_room() and active_room.has_method("frontdoor_observe_e1_release"):
			active_room.frontdoor_observe_e1_release(event)
		if screen != Screen.RUN:
			if key in _session_game_keys():
				if event.pressed: _blocked_keys[key] = true
				else: _blocked_keys.erase(key)
			if key == KEY_ESCAPE and event.pressed and not event.echo:
				if screen == Screen.CONFIRM: cancel_new_run()
				elif screen == Screen.CHOOSER: resume_run()
				get_viewport().set_input_as_handled()
		elif _blocked_keys.has(key):
			if not event.pressed: _blocked_keys.erase(key)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if screen != Screen.RUN:
			if event.pressed: _blocked_mouse[event.button_index] = true
			else: _blocked_mouse.erase(event.button_index)
		elif _blocked_mouse.has(event.button_index):
			if not event.pressed: _blocked_mouse.erase(event.button_index)
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_room_input()
		_blocked_keys.clear()
		_blocked_mouse.clear()

func session_snapshot() -> Dictionary:
	return {"screen":screen, "hero_id":active_hero, "session_serial":session_serial,
		"has_room":is_instance_valid(active_room), "pending_hero":pending_hero,
		"blocked_keys":_blocked_keys.keys(), "blocked_mouse":_blocked_mouse.keys()}

func _has_exact_yanguizhou_adapter(room: Node) -> bool:
	if not is_instance_valid(room) or not room is Node3D: return false
	var adapter: Script = room.get_script()
	return adapter != null and adapter.resource_path in [YANGUIZHOU_ADAPTER, YANGUIZHOU_VISUAL_ADAPTER]
