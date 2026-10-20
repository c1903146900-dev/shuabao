extends "res://tests/ink_river_hexes_20261006/frontdoor01/host.gd"
## Front-door lifecycle adapter only. The frozen ordinary host owns all gameplay.
## Evidence files are diagnostics, never a resumable/global progress save.
const FRONTDOOR_EXTRA_KEYS := [KEY_SPACE, KEY_M, KEY_B, KEY_F1, KEY_F6, KEY_F7, KEY_F9, KEY_F10]
var _frontdoor_suspended := false
var _frontdoor_pause_state: Dictionary = {}
var _frontdoor_auto_accept_quit := true
var _frontdoor_has_window_policy := false
var frontdoor_last_close: Dictionary = {}

var _diagnostic_export_requested: bool = false
var diagnostic_output_error: String = ""
var diagnostic_output_attempts: int = 0
var diagnostic_output_suppressed: int = 0
var diagnostic_error_lines: int = 0

func _ready() -> void:
	_diagnostic_export_requested = diagnostic_output_requested(OS.get_cmdline_user_args())
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
	if shop_session != null and shop_session.ledger != null:
		shop_session.ledger.model.potion_consumer.retire()
	frontdoor_clear_input()
	frontdoor_stop_audio()
	_close_skill_audio(reason)
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


const OrdinaryPotions=preload("res://tests/ink_equipment_live_20261008/content01/potion_controls.gd")
const OrdinaryRegenText=preload("res://tests/ink_equipment_regen_20261008/candidate01/regen_ui.gd")
var ordinary_potion_controls: Control
func _create_session_controls() -> void:
	super._create_session_controls()
	if shop_session==null or shop_session.ledger==null: return
	ordinary_potion_controls=OrdinaryPotions.new()
	ordinary_potion_controls.name="OrdinaryPotionControls"
	ordinary_potion_controls.position=OrdinaryPotions.STRIP_RECT.position
	session_canvas.add_child(ordinary_potion_controls)
	ordinary_potion_controls.bind_session(shop_session)
func _refresh_local_text() -> void:
	super._refresh_local_text()
	if is_instance_valid(session_equipment) and shop_session!=null and shop_session.ledger!=null:
		session_equipment.text="装备 %d/6 · 已接32/72\n药水3档·总计最多5瓶\n下一节点提交交易"%shop_session.ledger.model.state.inventory.size()
		session_equipment.add_theme_font_size_override("font_size",12)
		session_equipment.tooltip_text="药水同档共用一槽、混档分别占槽，三档合计最多5瓶，均计入六格装备栏；进入任何下一节点时提交本次商店交易。"
		session_equipment.mouse_filter=Control.MOUSE_FILTER_PASS
	if not is_instance_valid(shop_panel) or not is_instance_valid(shop_panel._title): return
	shop_panel._title.text="当前真实商店 · 装备32/72 · 药水3档"
	if not shop_panel._state.get("ready",false) or not shop_panel._state.catalog.items.has(shop_panel._selected): return
	var item: Dictionary=shop_panel._state.catalog.items[shop_panel._selected]
	var status: Dictionary=item.equipment_runtime
	var extra: String=""
	if status.has("regen_mapping"):
		shop_panel._detail.text=shop_panel._detail.text.replace("hp_regen","战斗生命恢复/秒")
		extra=OrdinaryRegenText.describe(status)
	if status.has("passive23"):
		var tuning: Dictionary=status.passive23
		extra="身陷重围：%s米内每名存活敌人+%s防御、+%s%%韧性，最多%d名；同名被动仅一次，基础属性叠加"%[str(tuning.radius),str(tuning.defense_per_enemy),str(tuning.tenacity_per_enemy),int(tuning.enemy_cap)]
	if str(shop_panel._selected).begins_with("potion:"):
		extra="4秒角色战斗时间内恢复%s%%最大生命；受伤不中断。同档共一槽、总计最多5瓶；关闭商店后点击饮用"%str(item.recovery.heal_max_health_pct)
	if not extra.is_empty() and not shop_panel._detail.text.contains(extra): shop_panel._detail.text+="\n"+extra


const E1SkillAudio = preload("res://tests/ink_first_floor_boss_20261008/audio01/router.gd")
const PriorSkillAudio = preload("res://tests/ink_composed_audio_fix01_20261005/router.gd")
var e1_audio_installed: bool = false

func _start_encounter() -> void:
	var fresh: bool = shop_session == null
	super._start_encounter()
	if not fresh or not is_instance_valid(sim) or not startup_session_error.is_empty() or not floor_error.is_empty(): return
	if not is_instance_valid(audio_output) or audio_output.router.get_script()!=PriorSkillAudio or not audio_output.router.event_room.is_empty():
		floor_error = "e1_audio_requires_fresh_inherited_router"
		_pause(true, "e1_audio_fail_closed")
		return
	var prior_audio_paused: bool = audio_output.router.paused
	audio_output.router = E1SkillAudio.new()
	audio_output.router.set_paused(prior_audio_paused)
	e1_audio_installed = true


func _write_json(filename: String, contents: Dictionary) -> void:
	diagnostic_output_attempts += 1
	if not _diagnostic_output_enabled():
		diagnostic_output_suppressed += 1
		_diagnostic_stderr_failure(filename, contents)
		return
	# Output-only flattening of the ten inherited copying wrappers. Keep every
	# report callback in its original order, before the existing lossless packer.
	# Nested source/proof/event values are read-only; never duplicate or trim them.
	var output: Dictionary = contents.duplicate(false)
	if has_method("ordinary_visual_report"): output["ordinary_visual_candidate"] = call("ordinary_visual_report")
	output["r2_ordinary_integration"] = r2_ordinary_report()
	output["combined_ordinary_integration"] = combined_ordinary_report()
	output["e3_ordinary_integration"] = e3_ordinary_report()
	output["p2_ordinary_integration"] = p2_ordinary_report()
	output["e2_ordinary_integration"] = e2_ordinary_report()
	output["rest_ordinary_integration"] = rest_ordinary_report()
	output["p1_ordinary_integration"] = p1_ordinary_report()
	output["r1_ordinary_integration"] = r1_ordinary_report()
	output["e1_ordinary_integration"] = e1_ordinary_report()
	output["q2_ordinary_integration"] = q2_ordinary_report()
	output["e1_audio_integration"] = {"installed":e1_audio_installed}
	output["skill_audio_integration"] = {"installed":e1_audio_installed,"families":["e1","e2","e3","q2","r1","r2"],"single_output_bus":true,"hearing_accepted":false}
	if evidence_dir.is_empty(): return
	var started: int = Time.get_ticks_usec()
	var heap_before: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var logical: Dictionary = diagnostic_logical_output(output)
	var result: Dictionary = diagnostic_write_logical(filename,logical)
	diagnostic_last = {"filename":filename,"accepted":result.get("accepted",false),"wall_usec":Time.get_ticks_usec()-started,"tracked_heap_before":heap_before,"tracked_heap_after":int(Performance.get_monitor(Performance.MEMORY_STATIC)),"scope":"engine tracked heap at boundaries, not per-call peak or whole-cgroup RSS causality"}



func _close_skill_audio(reason: String) -> void:
	if is_instance_valid(audio_output) and audio_output.router != null and audio_output.router.has_method("close_all"):
		audio_output._apply(audio_output.router.close_all(reason))

func close_sample(reason: String) -> void:
	if finished: return
	_close_skill_audio(reason)
	if shop_session != null and shop_session.ledger != null:
		shop_session.ledger.model.potion_consumer.retire()
	super.close_sample(reason)

# Output policy only; no authority, admission or gameplay lifecycle is conditional on it.
func _diagnostic_stderr_failure(filename: String, contents: Dictionary) -> void:
	if floor_error.is_empty() and startup_session_error.is_empty() and str(contents.get("status", "")) not in ["HOLD", "FAIL", "FAILED"]: return
	if diagnostic_error_lines >= 8: return
	diagnostic_error_lines += 1
	printerr("SHUABAO_DIAGNOSTIC_HOLD file=" + filename.left(128) + " floor=" + floor_error.left(256) + " startup=" + startup_session_error.left(256) + " failures=" + str(contents.get("failures", contents.get("reason", ""))).left(512))

static func diagnostic_output_requested(arguments: PackedStringArray, capture_requested: bool = false) -> bool:
	var requested_evidence: String = ""
	var requested: bool = capture_requested
	for argument: String in arguments:
		if argument in ["--ink-diagnostics", "--ordinary-live-receipts"]:
			requested = true
		elif argument.begins_with("--ink-evidence="):
			requested_evidence = argument.trim_prefix("--ink-evidence=")
	return requested or not requested_evidence.is_empty()

func _diagnostic_output_enabled() -> bool:
	return _diagnostic_export_requested

func _enable_capture_output() -> bool:
	if _diagnostic_export_requested: return true
	if evidence_dir.is_empty():
		evidence_dir = "user://ink_style_specimen_" + str(Time.get_unix_time_from_system()).replace(".", "_")
	var result: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence_dir))
	if result != OK:
		diagnostic_output_error = "capture_evidence_directory_failed:" + str(result)
		push_warning(diagnostic_output_error)
		return false
	_diagnostic_export_requested = diagnostic_output_requested(PackedStringArray(), true)
	return true

func request_frame_capture() -> void:
	if not _enable_capture_output(): return
	super.request_frame_capture()

func request_segment_capture() -> void:
	if not _enable_capture_output(): return
	super.request_segment_capture()
