extends "res://scripts/actor/actor_network_main.gd"
## Explicit 011 technical GUI client. The original server/host owner is unchanged.
## Keyboard intents go through the production client producer, never direct state.
## Geometry/resources remain authoritative; aim/action intent hints are separate.
## Predictive movement/dodge afterimages/art/audio remain pending.
const LocalPresentation = preload("res://scripts/actor/actor_local_presentation.gd")
const PlayView = preload("res://scripts/actor/actor_play_view.gd")
const LocalCommand = preload("res://scripts/actor/actor_command.gd")
const InputSampler = preload("res://scripts/actor/actor_input_sampler.gd")
const PRESENTATION_TRACE_LIMIT := 128
const LOCAL_KEYS := {KEY_W:"move_up", KEY_S:"move_down", KEY_A:"move_left", KEY_D:"move_right", KEY_SHIFT:"dodge", KEY_F:"interact"}
var _local_presentation: RefCounted
var _local_sampler: RefCounted
var _local_input_ready: bool = false
var _local_focused: bool = true
var _local_event_count: int = 0
var _local_intent_count: int = 0
var _local_cleanup_count: int = 0
var _local_last_error: String = ""
var _local_input_stopped: bool = false
var _presentation_trace: Array = []
var _presentation_trace_dropped: int = 0
var _presentation_trace_index: int = 0
var _presentation_trace_checkpoint: Dictionary = {}
var _presentation_trace_authority: Dictionary = {}

func _make_play_view() -> Node2D:
	return PlayView.new()

func _prepare_session() -> bool:
	if _mode != "client":
		_fail("ACTOR_PLAY_CLIENT_ONLY", "技术人物窗口只接入独立服务器客户端")
		return false
	if not super._prepare_session():
		return false
	# Replace only this explicit scene's empty initial overview, before snapshots.
	remove_child(_world_view)
	_world_view.free()
	_world_view = _make_play_view()
	if not _configure_play_camera(_actor_inputs.parameter("camera_ground_multiplier")):
		return false
	_world_view.name = "TechnicalActorWorld"
	add_child(_world_view)
	_local_sampler = InputSampler.new()
	get_window().title = "沙盒011 · 人物技术窗口"
	get_window().min_size = Vector2i(800, 600) # Technical HUD layout, not world units.
	_local_focused = get_window().has_focus()
	return true

func _configure_play_camera(ground_multiplier: float) -> bool:
	var camera_setup: Dictionary = _world_view.configure_camera(ground_multiplier)
	if not camera_setup.get("ok", false):
		_world_view.free()
		_world_view = null
		_fail("ACTOR_PLAY_CAMERA_CONFIG_INVALID", "技术镜头参数无效")
		return false
	return true

func _after_client_snapshot(incoming: Dictionary) -> void:
	super._after_client_snapshot(incoming)
	var profile: String = str(_welcome.get("player_profile_id", ""))
	var shown: Dictionary = _world_view.consume_actor_state(incoming["players"], incoming["actor_public"], profile, _actor_inputs.parameter("actor_diameter_cells"))
	if not shown.get("ok", false):
		_stop_local_input(str(shown.get("code", "ACTOR_PLAY_BINDING_UNAVAILABLE")))
		return
	if not _refresh_local_presentation(incoming):
		return
	if _local_sampler.ready or _closing or _fatal_shutdown or _stop_requested:
		return
	var actor_id: String = str(_welcome.get("player_instance_id", ""))
	var actor: Dictionary = incoming["actor_public"]["actors"][actor_id]
	var initial_aim: Array = _initial_local_aim(actor["aim_position"])
	var pointer: Dictionary = _pointer_world(get_viewport().get_mouse_position())
	if pointer.get("ok", false):
		initial_aim = pointer["world_point"]
	var configured: Dictionary = _local_sampler.configure(initial_aim)
	if not configured.get("ok", false):
		_stop_local_input(str(configured.get("code", "ACTOR_PLAY_INITIAL_AIM_INVALID")))
		return
	_local_input_ready = true
	# Focus may have changed during handshake. No held key is synthesized.
	if not _local_focused:
		_dispatch_local_batch(_local_sampler.set_focused(false), true)

static func _initial_local_aim(public_aim: Array) -> Array:
	# Public aim is a Vector2-derived binary32 pair: the legal command endpoint
	# 2^31-1 rounds to 2^31. Map that one representational boundary back into
	# the existing command domain; no arbitrary invalid values are normalized.
	var aim: Array = public_aim.duplicate()
	for axis in range(2):
		if absf(float(aim[axis])) == 2147483648.0:
			aim[axis] = LocalCommand.MAX_AIM * signf(float(aim[axis]))
	return aim

func _process(delta: float) -> void:
	super._process(delta)
	if not _can_sample():
		return
	# Also resample after viewport geometry changes without requiring mouse motion.
	var pointer: Dictionary = _pointer_world(get_viewport().get_mouse_position())
	if pointer.get("ok", false):
		_dispatch_local_batch(_local_sampler.set_aim(pointer["world_point"]))
	if _can_sample():
		_dispatch_local_batch(_local_sampler.flush())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F10:
		if event.pressed and not event.echo:
			_stop_requested = true
		get_viewport().set_input_as_handled()
		return
	if not _can_sample():
		return
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if LOCAL_KEYS.has(code):
			_local_event_count += 1
			_dispatch_local_batch(_sample_local_key(LOCAL_KEYS[code], event.pressed, event.echo))
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var mapped: Dictionary = _pointer_world(event.position)
		if mapped.get("ok", false):
			_local_event_count += 1
			_dispatch_local_batch(_local_sampler.set_aim(mapped["world_point"]))

func _sample_local_key(key: String, pressed: bool, echo: bool) -> Dictionary:
	if key != "interact":
		return _local_sampler.key_event(key, pressed, echo)
	var pointer: Dictionary = {}
	if pressed and not echo and not _local_sampler.state()["keys"]["interact"]:
		pointer = _current_pointer_world()
	return _local_sampler.interact_pointer_event(pressed, echo, pointer.get("world_point") if pointer.get("ok", false) else null)

func _current_pointer_world() -> Dictionary:
	# Sample at the F edge, after the current view/camera mapping. A pointer which
	# left the view must not interact at the last valid aim retained for movement.
	return _pointer_world(get_viewport().get_mouse_position())

func _pointer_world(viewport_position: Vector2) -> Dictionary:
	var view_point: Vector2 = _world_view.get_global_transform_with_canvas().affine_inverse() * viewport_position
	return _world_view.pointer_to_world(view_point)

func _notification(what: int) -> void:
	# Godot dispatches _notification to every script in the inheritance chain.
	# Calling super here repeats the base close notification.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_set_local_focus(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_set_local_focus(true)

func _set_local_focus(focused: bool) -> void:
	_local_focused = focused
	if _local_sampler == null or not _local_sampler.ready or _closing or _fatal_shutdown or _stop_requested:
		return
	# Send zero/release even though the sampler has become inactive. Merely
	# clearing local keys cannot release the authority's preserved input latches.
	_dispatch_local_batch(_local_sampler.set_focused(focused), not focused)
	if _local_presentation != null and _local_presentation.ready:
		_record_presentation_event("focus_in" if focused else "focus_out")

func _can_sample() -> bool:
	return _local_input_ready and _local_sampler != null and _local_sampler.ready and _local_focused and _startup_ready and not _closing and not _fatal_shutdown and not _stop_requested

func _dispatch_local_batch(batch: Dictionary, cleanup: bool = false) -> void:
	if not batch.get("ok", false):
		_stop_local_input(str(batch.get("code", "ACTOR_PLAY_SAMPLE_FAILED")))
		return
	for intent in batch["intents"]:
		if _closing or _fatal_shutdown or _stop_requested:
			return
		var sent: Dictionary = submit_client_actor_intent(intent["move"], intent["aim"], intent["action"], intent["phase"])
		if not sent.get("ok", false):
			# No retries across generation changes/capacity failures. Failure
			# closes transport so the server disconnect path removes held motion.
			_stop_local_input(str(sent.get("code", "ACTOR_PLAY_SEND_FAILED")))
			return
		var displayed: Dictionary = _record_sent_presentation(sent, intent)
		if not displayed.get("ok", false):
			_stop_local_input(str(displayed.get("code", "ACTOR_PLAY_PRESENTATION_FAILED")))
			return
		_local_intent_count += 1
		if cleanup:
			_local_cleanup_count += 1

func _refresh_local_presentation(incoming: Dictionary) -> bool:
	if _actor_input_pending == null or not _actor_input_pending.ready or _closing or _fatal_shutdown or _stop_requested:
		_stop_local_input("ACTOR_PLAY_PRESENTATION_BINDING_LOST")
		return false
	var checkpoint: Dictionary = _actor_input_pending.cursor()
	var actor: Dictionary = incoming["actor_public"]["actors"][checkpoint["player_instance_id"]]
	var was_provisional: bool = _local_presentation != null and _local_presentation.drawing_state().get("provisional",false)
	var result: Dictionary
	if _local_presentation == null:
		_local_presentation = LocalPresentation.new()
		result = _local_presentation.configure(checkpoint, actor["aim_position"], actor["dodging"])
	else:
		result = _local_presentation.synchronize(checkpoint, actor["aim_position"], actor["dodging"])
	if not result.get("ok", false):
		_stop_local_input(str(result.get("code", "ACTOR_PLAY_PRESENTATION_FAILED")))
		return false
	if not _publish_local_presentation():
		return false
	_presentation_trace_checkpoint = checkpoint.duplicate(true)
	_presentation_trace_authority = {"aim":actor["aim_position"].duplicate(),"dodging":actor["dodging"]}
	# Duplicate snapshots preserve fresh provisional input and are not correction evidence.
	if (_presentation_trace.is_empty() and not was_provisional) or (was_provisional and result.get("corrected", false)):
		_record_presentation_event("snapshot")
	return true

func _record_sent_presentation(sent: Dictionary, intent: Dictionary) -> Dictionary:
	# No await/RPC boundary between production send and this exact cursor read.
	# A changed or retired stream fails closed, never silently loses the hint.
	if _local_presentation == null or not _local_presentation.ready or _actor_input_pending == null or not _actor_input_pending.ready:
		return {"ok":false,"code":"ACTOR_PLAY_PRESENTATION_BINDING_LOST"}
	var checkpoint: Dictionary = _actor_input_pending.cursor()
	if sent.get("input_generation") != checkpoint["input_generation"]:
		return {"ok":false,"code":"ACTOR_PLAY_PRESENTATION_GENERATION_CHANGED"}
	var request := {"kind":"actor_input","sequence":sent.get("sequence"),"move":intent["move"],"aim":intent["aim"],"action":intent["action"],"phase":intent["phase"]}
	var result: Dictionary = _local_presentation.record_sent(checkpoint, request)
	if not result.get("ok", false):
		return result
	if not _publish_local_presentation():
		return {"ok":false,"code":"ACTOR_PLAY_PRESENTATION_VIEW_FAILED"}
	_presentation_trace_checkpoint = checkpoint.duplicate(true)
	_record_presentation_event("sent")
	return result

func _publish_local_presentation() -> bool:
	var result: Dictionary = _world_view.consume_local_presentation(_local_presentation.drawing_state())
	if not result.get("ok", false):
		_stop_local_input(str(result.get("code", "ACTOR_PLAY_PRESENTATION_VIEW_FAILED")))
		return false
	return true

func _clear_local_presentation() -> void:
	var had_display: bool = _local_presentation != null and _local_presentation.ready
	if _local_presentation != null:
		_local_presentation.close()
	if _world_view != null and _world_view.has_method("clear_local_presentation"):
		_world_view.clear_local_presentation()
	if had_display:
		_record_presentation_event("closed")

func _close_actor_input_pending() -> void:
	_clear_local_presentation()
	super._close_actor_input_pending()

func _stop_local_input(code: String) -> void:
	# A failed publish can bubble through dispatch after already stopping here.
	# Keep the first cause and never duplicate transport/report/quit effects.
	if _local_input_stopped:
		return
	_local_input_stopped = true
	_clear_local_presentation()
	_local_last_error = code
	_local_input_ready = false
	if _world_view != null:
		_world_view.clear_actor_state()
	_stop_requested = true
	_fail(code, "技术人物输入停止，连接已关闭，未宣称按键释放成功")

func _cleanup_runtime() -> void:
	_clear_local_presentation()
	_local_input_ready = false
	if _local_sampler != null and _local_sampler.ready:
		_local_sampler.set_enabled(false) # Transport is closing; never send here.
	if _world_view != null and _world_view.has_method("clear_actor_state"):
		_world_view.clear_actor_state()
	_write_closed_presentation_trace()
	super._cleanup_runtime()

func _actor_presentation() -> String:
	return "authoritative_actor_geometry_proxy"

func _write_report(data: Dictionary) -> void:
	var report: Dictionary = data.duplicate(true)
	report["actor_local_gui"] = {"input_ready":_local_input_ready,"focused":_local_focused,"event_count":_local_event_count,"intent_count":_local_intent_count,"cleanup_intent_count":_local_cleanup_count,"last_error":_local_last_error,"prediction":false,"local_aim_action_hints":true,"positional_prediction":false,"formal_world_allowed":false,"presentation":"authoritative_geometry_proxy"}
	report["actor_local_presentation_trace"] = _presentation_trace_report()
	super._write_report(report)

func _record_presentation_event(event: String) -> void:
	# Bounded evidence only. Never enters the network envelope, authority or save.
	if _presentation_trace_checkpoint.is_empty() or _presentation_trace_authority.is_empty():
		return
	_presentation_trace_index += 1
	var held := {"move_up":false,"move_down":false,"move_left":false,"move_right":false,"dodge":false,"interact":false}
	if _local_sampler != null and _local_sampler.ready:
		held = _local_sampler.state()["keys"]
	var hint: Dictionary = _local_presentation.drawing_state() if _local_presentation != null else {}
	_presentation_trace.append({"index":_presentation_trace_index,"ticks_usec":Time.get_ticks_usec(),"event":event,"checkpoint":_presentation_trace_checkpoint.duplicate(true),"authority":_presentation_trace_authority.duplicate(true),"hint":hint,"focused":_local_focused,"held_keys":held.duplicate(true),"cleanup_intent_count":_local_cleanup_count})
	if _presentation_trace.size() > PRESENTATION_TRACE_LIMIT:
		_presentation_trace.pop_front()
		_presentation_trace_dropped += 1

func _presentation_trace_report() -> Dictionary:
	return {"limit":PRESENTATION_TRACE_LIMIT,"dropped":_presentation_trace_dropped,"events":_presentation_trace.duplicate(true)}

func _write_closed_presentation_trace() -> void:
	# A separate final trace retains the close witness without replacing the last
	# client-ready authority report used by the original GUI/save assertions.
	if _report_path.is_empty() or _presentation_trace.is_empty():
		return
	var target: String = _report_path + ".presentation.json"
	var temporary: String = target + ".tmp"
	var output := FileAccess.open(temporary, FileAccess.WRITE)
	if output == null:
		push_error("Could not write local presentation close evidence")
		return
	output.store_string(JSON.stringify(_presentation_trace_report(), "", true, true))
	output.close()
	if DirAccess.rename_absolute(temporary,target) != OK:
		push_error("Could not promote local presentation close evidence")
