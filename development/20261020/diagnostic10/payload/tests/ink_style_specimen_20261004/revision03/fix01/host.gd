extends Node3D
## Isolated real producer host. Diagnostic learned Q1; never normal-entry or art acceptance.
const Sim=preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_sim.gd")
const InputRouter=preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_input_adapter.gd")
const Stage=preload("res://tests/ink_style_specimen_20261004/revision03/fix01/stage.gd")
const HeroView=preload("res://tests/ink_style_specimen_20261004/revision03/hero_view.gd")
const MinionView=preload("res://tests/ink_style_specimen_20261004/minion_view.gd")
const Q1View=preload("res://tests/ink_q1_effect_20261004/revision02/q1_effect_presenter.gd")
const BasicView=preload("res://tests/ink_style_specimen_20261004/basic_presenter.gd")
const HUD=preload("res://tests/ink_style_specimen_20261004/revision03/hud.gd")
const BodyMetrics=preload("res://tests/ink_style_specimen_20261004/revision03/body_metrics.gd")
const AudioOutput=preload("res://tests/ink_style_specimen_20261004/audio_output.gd")
var sim: Node
var input_router: RefCounted
var stage: Node3D
var hero_view: Node3D
var enemy_view: Node3D
var q1_view: Node3D
var basic_view: Node3D
var audio_output: Node
var hud: Control
var start_ticks:=0
var draw_count:=0
var draw_last_usec:=0
var draw_intervals_ms: Array=[]
var process_intervals_ms: Array=[]
var inputs: Array=[]
var events: Array=[]
var pauses: Array=[]
var seen_receipts: Dictionary={}
var evidence_dir:=""
var recording: FileAccess
var finite_seconds:=900.0 # independent hard wall budget
var active_budget_seconds:=90.0
var active_wall_seconds:=0.0
var last_process_wall_usec:=0
var start_paused:=false
var gate_mode:=false
var finished:=false
var shop_prior_pause:=false
var diagnostic:=false
var restart_count:=0
const PRODUCER_BINDING_PATH:="res://tests/ink_q1_foundation_20261004/revision02/source_binding.json"
const PRODUCER_BINDING_SHA:="f927e5d7c75cb6b2e660310a85dbc1c5dad0a68ad724faa0c4cf7a081085bf1a"
var capture_pending: Dictionary={}
var capture_history: Array=[]
var capture_serial:=0
var last_presented_ink: Dictionary={}
var last_presented_full: Dictionary={}

func _ready() -> void:
	start_ticks=Time.get_ticks_usec()
	last_process_wall_usec=start_ticks
	for argument: String in OS.get_cmdline_user_args():
		if argument=="--ink-start-paused":start_paused=true
		elif argument.begins_with("--ink-active-seconds="):active_budget_seconds=clampf(float(argument.trim_prefix("--ink-active-seconds=")),3.0,1800.0)
		elif argument.begins_with("--ink-wall-seconds="):finite_seconds=clampf(float(argument.trim_prefix("--ink-wall-seconds=")),3.0,1800.0)
		elif argument.begins_with("--ink-seconds="):finite_seconds=clampf(float(argument.trim_prefix("--ink-seconds=")),3.0,600.0)
		elif argument.begins_with("--ink-evidence="):evidence_dir=argument.trim_prefix("--ink-evidence=")
		elif argument=="--ink-gate":gate_mode=true
	if evidence_dir.is_empty():evidence_dir="user://ink_style_specimen_"+str(Time.get_unix_time_from_system()).replace(".","_")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence_dir))
	recording=FileAccess.open(evidence_dir.path_join("source_frames.jsonl"),FileAccess.WRITE)
	var _startup_probe_base_stage_effect_audio_hud: int = _startup_probe_begin()
	stage=Stage.new();add_child(stage)
	q1_view=Q1View.new();add_child(q1_view)
	basic_view=BasicView.new();add_child(basic_view)
	audio_output=AudioOutput.new();add_child(audio_output)
	var canvas:=CanvasLayer.new();add_child(canvas)
	hud=HUD.new();canvas.add_child(hud)
	hud.shop_requested.connect(_shop)
	hud.exit_requested.connect(func():close_sample("visible_exit"))
	hud.diagnostics_requested.connect(_toggle_diagnostics)
	get_tree().auto_accept_quit=false
	get_window().close_requested.connect(func():close_sample("window_close"))
	get_window().focus_exited.connect(_focus_lost)
	RenderingServer.frame_post_draw.connect(_drawn)
	_startup_probe_end("base_stage_effect_audio_hud", _startup_probe_base_stage_effect_audio_hud)
	_start_encounter()
	stage.follow(sim.hero.position,1.0)
	if start_paused and not gate_mode:_pause(true,"start_paused_after_real_idle0_sample")
	var _startup_probe_base_startup_report: int = _startup_probe_begin()
	_write_json("session_start.json",{"scope":"diagnostic learned Q1, real one-minion director; not normal Lv1, final art, Boss, performance or OS-input acceptance","renderer":RenderingServer.get_video_adapter_name(),"rendering_method":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"resolution":get_viewport().get_visible_rect().size,"camera_size":stage.camera.size,"camera_contract":stage.camera_contract(),"logical_viewport_not_raster":true,"shadow_enabled":stage.shadow_enabled,"audio":audio_output.report(),"hero_import":hero_view.proof,"enemy_import":enemy_view.proof,"gate_mode":gate_mode,"start_paused":start_paused,"active_budget_seconds":active_budget_seconds,"hard_wall_budget_seconds":finite_seconds,"rules_sha256":sim.source_rules_hash,"auto_finish":sim.auto_finish,"producer_revision":"control02","producer_binding_sha256":FileAccess.get_sha256(PRODUCER_BINDING_PATH)})
	_startup_probe_end("base_startup_report", _startup_probe_base_startup_report)
func _start_encounter() -> void:
	if is_instance_valid(sim):sim.queue_free()
	if is_instance_valid(hero_view):hero_view.queue_free()
	if is_instance_valid(enemy_view):enemy_view.queue_free()
	sim=Sim.new();add_child(sim)
	# Explicit diagnostic learned profile only. No fake level or HP overwrite.
	sim.hero.loadout.q="q1";sim.hero.ranks.q=1
	sim.hero.position=Vector3(0,0,4)
	sim.arena_half_extent=Stage.EXTENT
	sim.obstacles=Stage.OBSTACLES.duplicate(true)
	sim.auto_finish=false # Keep specimen open after a genuine kill; no victory reward.
	sim.ai_enabled=true
	input_router=InputRouter.new();input_router.bind(sim)
	hero_view=HeroView.new();add_child(hero_view)
	enemy_view=MinionView.new();add_child(enemy_view)
	audio_output.restart_scope()
	sim.combat_event.connect(_combat_event)
	sim.begin_encounter("ink-style-specimen-%d"%restart_count,[{"kind":"minion","position":Vector3(0,0,-5)}])
	seen_receipts.clear()
	q1_view.reset_visuals()
	audio_output.clear()
	_refresh(0.0)
func _unhandled_input(event: InputEvent) -> void:
	if finished or gate_mode or sim==null:return
	# LMB-up is observed in _input even if a GUI control consumes it.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:return
	var ground: Vector3=stage.ground_point(get_viewport().get_mouse_position())
	var result: Dictionary=input_router.handle_event(event,ground)
	if result.get("reason","")!="unmapped_input":
		inputs.append({"wall_usec":Time.get_ticks_usec()-start_ticks,"source_time":sim.hero_time,"event_class":event.get_class(),"event_text":event.as_text(),"ground":ground,"result":result,"provenance":"received_InputEvent; native_device_proof_requires_separate_CUA_record"})
func _input(event: InputEvent) -> void:
	if not finished and not gate_mode and sim!=null and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		var release_ground: Vector3=stage.ground_point(get_viewport().get_mouse_position())
		var release_result: Dictionary=input_router.handle_event(event,release_ground)
		inputs.append({"wall_usec":Time.get_ticks_usec()-start_ticks,"source_time":sim.hero_time,"event_class":event.get_class(),"event_text":event.as_text(),"ground":release_ground,"result":release_result,"provenance":"received_InputEvent before GUI; not independent device proof"})
	if not event is InputEventKey or event.echo or not event.pressed:return
	var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if sim!=null and key in [KEY_F1,KEY_F6,KEY_F9,KEY_F10,KEY_B,KEY_SPACE,KEY_ESCAPE]:
		inputs.append({"wall_usec":Time.get_ticks_usec()-start_ticks,"source_time":sim.hero_time,"category":"host_shortcut","event_class":event.get_class(),"event_text":event.as_text(),"provenance":"received InputEvent; independent OS/CUA proof remains separate"})
	match key:
		KEY_F9:request_frame_capture();get_viewport().set_input_as_handled()
		KEY_F10:close_sample("F10");get_viewport().set_input_as_handled()
		KEY_F1:_toggle_diagnostics();get_viewport().set_input_as_handled()
		KEY_B:_shop(not hud.shop_open);get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if hud.shop_open:_shop(false);get_viewport().set_input_as_handled()
		KEY_SPACE:
			if not hud.shop_open:_pause(not sim.paused,"manual_space")
			get_viewport().set_input_as_handled()
		KEY_F6:
			if not hud.shop_open:
				pauses.append({"kind":"explicit_fresh_diagnostic_restart","wall_usec":Time.get_ticks_usec()-start_ticks,"source_time":sim.hero_time})
				restart_count+=1;_start_encounter()
			get_viewport().set_input_as_handled()
func _pause(value: bool, reason: String) -> void:
	input_router.suspend_input(reason)
	sim.paused=value
	audio_output.set_paused(value)
	pauses.append({"paused":value,"reason":reason,"wall_usec":Time.get_ticks_usec()-start_ticks,"source_time":sim.hero_time})
func _shop(open: bool) -> void:
	if hud.shop_open==open:return
	if open:
		shop_prior_pause=sim.paused
		_pause(true,"shop_open")
	else:_pause(shop_prior_pause,"shop_close")
	hud.set_shop(open)
func _focus_lost() -> void:
	if sim==null or finished:return
	input_router.focus_lost()
	_pause(true,"window_focus_lost_requires_explicit_resume")
	if hud.shop_open:shop_prior_pause=true
func _toggle_diagnostics() -> void:
	diagnostic=not diagnostic;hud.set_diagnostics(diagnostic)
func _combat_event(event: Dictionary) -> void:
	var detached: Dictionary=event.duplicate(true)
	events.append(detached)
	hero_view.receive(detached,sim.hero_time)
	audio_output.consume(detached,sim.ink_presenter_snapshot())
func _process(delta: float) -> void:
	if finished or sim==null:return
	process_intervals_ms.append(delta*1000.0)
	var process_wall_now:=Time.get_ticks_usec()
	var measured_wall_delta:=float(process_wall_now-last_process_wall_usec)/1000000.0
	last_process_wall_usec=process_wall_now
	if not gate_mode and not sim.paused and sim.phase=="combat" and not sim.hero.dead:active_wall_seconds+=maxf(0.0,measured_wall_delta)
	if not gate_mode:
		input_router.update_held_basic(stage.ground_point(get_viewport().get_mouse_position()))
		sim.step(delta) # No time clamp, tick subdivision, actor teleport or fake damage.
	_refresh(delta)
	if not gate_mode and active_wall_seconds>=active_budget_seconds:close_sample("finite_active_wall_budget")
	elif not gate_mode and float(Time.get_ticks_usec()-start_ticks)/1000000.0>=finite_seconds:close_sample("independent_hard_wall_deadline")
func _refresh(delta: float) -> void:
	var full: Dictionary=sim.snapshot()
	var ink: Dictionary=sim.ink_presenter_snapshot()
	if not sim.paused:hero_view.present(ink)
	q1_view.present(ink)
	basic_view.present(ink)
	if not sim.paused and not full.enemies.is_empty():enemy_view.present(full.enemies[0],float(ink.source_time))
	for receipt: Dictionary in ink.receipts:
		var id:=str(receipt.receipt_id)
		if not seen_receipts.has(id):
			seen_receipts[id]=true
			enemy_view.contact(receipt)
	stage.follow(full.hero.position,delta)
	stage.present_grounding(full.hero,full.enemies)
	hud.present(full,ink,_brief())
	last_presented_full=full.duplicate(true)
	last_presented_ink=ink.duplicate(true)
	if recording!=null:
		recording.store_line(JSON.stringify(_json_safe({"wall_usec":Time.get_ticks_usec()-start_ticks,"draw_index":draw_count,"snapshot":ink,"hero":full.hero,"enemies":full.enemies,"paused":sim.paused,"actor_sample":hero_view.sample_report})))
func _drawn() -> void:
	if finished:return
	var now:=Time.get_ticks_usec()
	if draw_last_usec>0:draw_intervals_ms.append(float(now-draw_last_usec)/1000.0)
	draw_last_usec=now;draw_count+=1
	if not capture_pending.is_empty() and draw_count>int(capture_pending.request_draw_index):_capture_rendered_frame()
func _brief() -> Dictionary:
	return {"renderer":RenderingServer.get_video_adapter_name(),"wall_seconds":float(Time.get_ticks_usec()-start_ticks)/1000000.0,"active_wall_seconds":active_wall_seconds,"active_budget_seconds":active_budget_seconds,"hard_wall_budget_seconds":finite_seconds,"draw_frames":draw_count,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"receipt_count":seen_receipts.size(),"input_count":inputs.size(),"shadows":stage.shadow_enabled,"audio_status":audio_output.status_text(),"hero_status":hero_view.proof.status}
func _stats(values: Array) -> Dictionary:
	if values.is_empty():return {"samples":0,"status":"not_measured"}
	var sorted:=values.duplicate();sorted.sort()
	var sum:=0.0
	for value in sorted:sum+=float(value)
	return {"samples":sorted.size(),"mean_ms":sum/sorted.size(),"p50_ms":sorted[floori((sorted.size()-1)*.50)],"p95_ms":sorted[floori((sorted.size()-1)*.95)],"max_ms":sorted.back()}
func _json_safe(value: Variant) -> Variant:
	if value is Vector3:return [value.x,value.y,value.z] if value.is_finite() else "nonfinite_Vector3"
	if value is Vector2:return [value.x,value.y]
	if value is Dictionary:
		var result: Dictionary={}
		for key in value:result[str(key)]=_json_safe(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item in value:result.append(_json_safe(item))
		return result
	return value
func _write_json(filename: String, contents: Dictionary) -> void:
	var output:=FileAccess.open(evidence_dir.path_join(filename),FileAccess.WRITE)
	if output!=null:output.store_string(JSON.stringify(_json_safe(contents),"  "))
func save_evidence(reason: String) -> void:
	if recording!=null:recording.flush()
	_write_json("session_result.json",{"reason":reason,"diagnostic_guard":{"active_wall_seconds":active_wall_seconds,"active_budget_seconds":active_budget_seconds,"hard_wall_budget_seconds":finite_seconds,"start_paused":start_paused,"basis":"observed unpaused alive combat state; monotonic wall deltas, not source time"},"scope":"actual sampled host; no automatic art, device-input, hearing, balance, Boss or target-hardware pass","status":_brief(),"hero_import":hero_view.proof,"enemy_import":enemy_view.proof,"draw_frame_intervals":_stats(draw_intervals_ms),"process_intervals":_stats(process_intervals_ms),"source_time":sim.hero_time,"actual_frames_drawn_engine":Engine.get_frames_drawn(),"input_events":inputs,"combat_events":events,"pauses":pauses,"audio":audio_output.report(),"q1_presenter":q1_view.get_diagnostics(),"restart_count":restart_count,"captures":capture_history,"producer_revision":"control02","producer_binding_sha256":FileAccess.get_sha256(PRODUCER_BINDING_PATH),"viewport":get_viewport().get_visible_rect().size,"camera_size":stage.camera.size,"camera_contract":stage.camera_contract(),"os_input_accepted":false,"art_accepted":false,"audio_accepted":false,"performance_accepted":false})
func close_sample(reason: String) -> void:
	if finished:return
	finished=true
	input_router.suspend_input("exit")
	audio_output.set_paused(true)
	save_evidence(reason)
	if recording!=null:recording.close()
	get_tree().quit()

func _snapshot_digest(full: Dictionary, ink: Dictionary) -> String:
	return JSON.stringify(_json_safe({"full":full,"ink":ink}),"",true,true).sha256_text()
func request_frame_capture() -> void:
	if finished or sim==null:return
	if DisplayServer.get_name()=="headless":
		capture_history.append({"status":"skipped_headless","png_saved":false,"source_time":sim.hero_time});return
	if not capture_pending.is_empty():return
	capture_serial+=1
	var full: Dictionary=sim.snapshot()
	var ink: Dictionary=sim.ink_presenter_snapshot()
	capture_pending={"serial":capture_serial,"request_draw_index":draw_count,"request_wall_usec":Time.get_ticks_usec()-start_ticks,"request_source_time":sim.hero_time,"request_paused":sim.paused,"request_snapshot_sha256":_snapshot_digest(full,ink)}
func _capture_rendered_frame() -> void:
	# Called only by a NEW frame_post_draw. No input generation, replay, resampling,
	# source mutation or pretend capture in headless mode.
	var capture_cpu_begin:=Time.get_ticks_usec()
	var record: Dictionary=capture_pending.duplicate(true)
	capture_pending.clear()
	var before_full: Dictionary=sim.snapshot()
	var before_ink: Dictionary=sim.ink_presenter_snapshot()
	var before_hash:=_snapshot_digest(before_full,before_ink)
	var presented_hash:=_snapshot_digest(last_presented_full,last_presented_ink)
	var image: Image=get_viewport().get_texture().get_image()
	var filename:="F9_%03d_frame_%06d.png"%[int(record.serial),draw_count]
	var path:=evidence_dir.path_join(filename)
	var saved: Error=image.save_png(path)
	var actual_raster:=Vector2i(image.get_width(),image.get_height())
	var body_metrics: Dictionary=BodyMetrics.collect(hero_view,stage.camera,actual_raster)
	var enemy_metrics: Dictionary=BodyMetrics.collect(enemy_view,stage.camera,actual_raster)
	var after_full: Dictionary=sim.snapshot()
	var after_ink: Dictionary=sim.ink_presenter_snapshot()
	var after_hash:=_snapshot_digest(after_full,after_ink)
	var pause_expected: bool=bool(record.request_paused) and sim.paused
	var paused_unchanged: bool=pause_expected and record.request_snapshot_sha256==before_hash and before_hash==after_hash
	var pair_unchanged:=before_hash==after_hash and presented_hash==before_hash
	record.merge({"status":"saved_actual_frame" if saved==OK and pair_unchanged and (not pause_expected or paused_unchanged) else "HOLD_capture_or_source_pair_mismatch","capture_cpu_wall_ms":float(Time.get_ticks_usec()-capture_cpu_begin)/1000.0,"png_saved":saved==OK,"png_path":ProjectSettings.globalize_path(path),"png_sha256":FileAccess.get_sha256(path) if saved==OK else "","save_error":saved,"frame_post_draw_index":draw_count,"frame_wall_usec":Time.get_ticks_usec()-start_ticks,"frame_source_time":sim.hero_time,"frame_paused":sim.paused,"frame_before_sha256":before_hash,"frame_after_sha256":after_hash,"presented_snapshot_sha256":presented_hash,"capture_pair_unchanged":pair_unchanged,"paused_source_expected":pause_expected,"paused_source_unchanged":paused_unchanged,"running_capture_is_freeze_proof":false,"source_snapshot":before_ink,"hero_and_enemies":before_full,"renderer":RenderingServer.get_video_adapter_name(),"viewport":get_viewport().get_visible_rect().size,"camera_size":stage.camera.size,"camera_contract":stage.camera_contract(),"actual_raster_size":[actual_raster.x,actual_raster.y],"logical_viewport_not_raster":true,"hero_geometry_metrics":body_metrics,"enemy_geometry_metrics":enemy_metrics,"art_accepted":false},true)
	capture_history.append(record)
	_write_json(filename.trim_suffix(".png")+".json",record)
	print("INK_STYLE_F9 ",JSON.stringify({"status":record.status,"png_path":record.png_path,"capture_pair_unchanged":pair_unchanged,"paused_source_unchanged":paused_unchanged}))

# Opt-in bounded startup observation only. No world data, frame logger or file output.
var _startup_probe_enabled: bool = "--trial-startup-profile" in OS.get_cmdline_user_args()
var _startup_probe_open: bool = true
var _startup_probe_rows: Array = []
var _startup_probe_dropped: int = 0
func _startup_probe_begin() -> int:
	return Time.get_ticks_usec() if _startup_probe_enabled and _startup_probe_open else 0
func _startup_probe_end(label: String, began: int) -> void:
	if began == 0 or not _startup_probe_enabled or not _startup_probe_open: return
	var ended: int = Time.get_ticks_usec()
	if _startup_probe_rows.size() >= 64:
		_startup_probe_dropped += 1
		return
	_startup_probe_rows.append({"label":label,"begin_usec":began,"end_usec":ended,"elapsed_usec":ended-began})
func startup_construction_profile() -> Dictionary:
	return {"enabled":_startup_probe_enabled,"closed":not _startup_probe_open,"rows":_startup_probe_rows.duplicate(true),"dropped":_startup_probe_dropped,"scope":"startup_wall_intervals_nested_do_not_sum","deferred_warmup_included":false}
