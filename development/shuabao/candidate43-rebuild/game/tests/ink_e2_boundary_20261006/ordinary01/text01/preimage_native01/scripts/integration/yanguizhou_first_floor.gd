extends "res://tests/ink_e2_boundary_20261006/ordinary01/host.gd"
## Front-door lifecycle adapter only. The frozen ordinary host owns all gameplay.
## Evidence files are diagnostics, never a resumable/global progress save.
const FRONTDOOR_EXTRA_KEYS := [KEY_SPACE, KEY_M, KEY_B, KEY_F1, KEY_F6, KEY_F7, KEY_F9, KEY_F10]
var _frontdoor_suspended := false
var _frontdoor_pause_state: Dictionary = {}
var _frontdoor_auto_accept_quit := true
var _frontdoor_has_window_policy := false
var frontdoor_last_close: Dictionary = {}

func _ready() -> void:
	_frontdoor_auto_accept_quit = get_tree().auto_accept_quit
	_frontdoor_has_window_policy = true
	var prior_connections: Array = get_window().close_requested.get_connections()
	super._ready()
	# The inherited standalone host adds a close lambda. Replace only that newly
	# installed connection with a bound callback that cannot outlive this room.
	for connection: Dictionary in get_window().close_requested.get_connections():
		if not prior_connections.any(func(prior: Dictionary): return prior.callable == connection.callable):
			get_window().close_requested.disconnect(connection.callable)
	get_window().close_requested.connect(_frontdoor_window_close)

func _frontdoor_window_close() -> void:
	close_sample("window_close") # Existing evidence + whole-application exit.

func frontdoor_can_suspend() -> bool:
	# A loading coroutine owns temporary presentation fixtures until it returns.
	# Its existing mask stays authoritative; never pause or bypass that seal.
	return not finished and not _mainprep_pending and (not _mainprep_required or _mainprep_attempted)

func frontdoor_clear_input() -> void:
	if input_router == null or not is_instance_valid(sim): return
	input_router.suspend_input("frontdoor_boundary")
	input_router.clear_q2_frontdoor_latches()
	input_router.clear_r1_frontdoor_latches()
	# The parent fence owns release draining while this room is hidden. Reset the
	# real ink router's physical latches too, or its swallowed mouse-up stays stuck.
	input_router._left_physical = false
	input_router._gesture_consumed = false
	input_router._gesture_id = ""
	input_router._generation = -1
	input_router._suppress_held = true
	input_router._q3_mouse_pair = false
	input_router._retired_q3_intent = ""
	initial_guard.pressed_keys.clear()
	initial_guard.pressed_buttons.clear()
	initial_guard.retired_keys.clear()
	initial_guard.retired_buttons.clear()
	_mainprep_held_keys.clear()
	_mainprep_held_buttons.clear()
	mouse_aim.invalidate("frontdoor_requires_fresh_mouse_event")

func frontdoor_stop_audio() -> void:
	if not is_instance_valid(audio_output): return
	audio_output.set_paused(true)
	audio_output.clear()

func frontdoor_suspend() -> void:
	if _frontdoor_suspended: return
	_frontdoor_pause_state = {"sim_paused":sim.paused, "audio_paused":audio_output.router.paused}
	_frontdoor_suspended = true
	frontdoor_clear_input()
	sim.paused = true
	frontdoor_stop_audio()
	# Global post-draw signals bypass PROCESS_MODE_DISABLED. End bounded captures
	# here; never record the chooser as if it were a gameplay frame.
	if segment_active: _finish_segment("frontdoor_pause", Time.get_ticks_usec())
	if segment_armed:
		segment_armed = false
		segment_control_history.append({"status":"frontdoor_cancelled_armed_capture", "png_saved":false})
	capture_pending.clear()

func frontdoor_resume() -> void:
	if not _frontdoor_suspended: return
	frontdoor_clear_input()
	var now := Time.get_ticks_usec()
	# Drop the first measured process gap; preserve the original hard-wall budget.
	last_process_wall_usec = now
	draw_last_usec = 0
	sim.paused = bool(_frontdoor_pause_state.sim_paused)
	audio_output.set_paused(bool(_frontdoor_pause_state.audio_paused))
	_frontdoor_suspended = false
	_frontdoor_pause_state.clear()

func _drawn() -> void:
	if _frontdoor_suspended: return
	super._drawn()

func _focus_lost() -> void:
	if _frontdoor_suspended:
		_frontdoor_pause_state["sim_paused"] = true
		_frontdoor_pause_state["audio_paused"] = true
	super._focus_lost()

func frontdoor_close_run(reason: String) -> bool:
	if finished: return true
	# Reuse the existing abort-without-settlement boundary. Do not call
	# close_sample here: that standalone host method intentionally quits the app.
	if shop_session != null:
		frontdoor_last_close = shop_session.close_run()
		if not frontdoor_last_close.get("accepted", false): return false
	finished = true
	frontdoor_clear_input()
	frontdoor_stop_audio()
	save_evidence(reason)
	if recording != null:
		recording.close()
		recording = null
	frontdoor_last_close["evidence_only"] = true
	frontdoor_last_close["global_progress_saved"] = false
	frontdoor_last_close["last_diagnostic_write_accepted"] = diagnostic_last.get("accepted", false)
	return true

func _exit_tree() -> void:
	if get_window().close_requested.is_connected(_frontdoor_window_close):
		get_window().close_requested.disconnect(_frontdoor_window_close)
	if RenderingServer.frame_post_draw.is_connected(_drawn):
		RenderingServer.frame_post_draw.disconnect(_drawn)
	if _frontdoor_has_window_policy:
		get_tree().auto_accept_quit = _frontdoor_auto_accept_quit
