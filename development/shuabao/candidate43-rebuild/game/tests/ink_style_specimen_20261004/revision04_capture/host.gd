extends "res://tests/ink_style_specimen_20261004/revision03/inputfix02/host.gd"
## Opt-in actual draw capture only. Inherits all source stepping and action input.
const SEGMENT_USEC:=3000000
const ARM_TIMEOUT_USEC:=15000000
const MAX_SEGMENT_FRAMES:=180
const MAX_SEGMENTS:=3
const MAX_PNG_BYTES:=128*1024*1024
const MAX_CAPTURE_PIXELS:=1920*1080
var segment_armed:=false
var segment_active:=false
var segment_serial:=0
var segment_armed_usec:=0
var segment_start_usec:=0
var segment_png_bytes:=0
var segment_last_engine_draw:=-1
var total_png_bytes:=0
var segment_directory:=""
var segment_log: FileAccess
var segment_frames: Array=[]
var segment_callback_usec: Array=[]
var segment_record: Dictionary={}
var segment_history: Array=[]
var segment_control_history: Array=[]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if key==KEY_F8:
			if sim!=null:inputs.append({"wall_usec":Time.get_ticks_usec()-start_ticks,"source_time":sim.hero_time,"category":"host_capture_shortcut","event_class":event.get_class(),"event_text":event.as_text(),"provenance":"received InputEvent; independent OS/CUA proof remains separate"})
			request_segment_capture();get_viewport().set_input_as_handled();return
	super._input(event)

func request_segment_capture() -> void:
	var reason:="armed"
	if finished or sim==null:reason="rejected_closed"
	elif DisplayServer.get_name()=="headless":reason="skipped_headless"
	elif gate_mode:reason="rejected_synthetic_gate"
	elif segment_armed or segment_active:reason="already_armed_or_recording"
	elif segment_serial>=MAX_SEGMENTS:reason="session_segment_limit"
	elif total_png_bytes>=MAX_PNG_BYTES:reason="session_png_byte_limit"
	segment_control_history.append({"status":reason,"monotonic_usec":Time.get_ticks_usec(),"png_saved":false})
	if reason!="armed":return
	segment_serial+=1
	segment_armed=true;segment_armed_usec=Time.get_ticks_usec()
	print("INK_STYLE_F8 armed ",segment_serial,"; starts on next unpaused actual draw")

func _drawn() -> void:
	var draw_usec:=Time.get_ticks_usec()
	var prior_draw_usec:=draw_last_usec
	var f9_before:=capture_history.size()
	super._drawn()
	if finished:return
	if segment_armed:
		if draw_usec-segment_armed_usec>=ARM_TIMEOUT_USEC:
			segment_armed=false
			segment_control_history.append({"status":"arm_timeout_no_unpaused_draw","monotonic_usec":draw_usec,"png_saved":false})
			_write_segment_summary();return
		if sim.paused:return
		if not _begin_segment(draw_usec):return
	if not segment_active:return
	if draw_usec-segment_start_usec>=SEGMENT_USEC:
		_finish_segment("three_second_wall_limit",draw_usec);return
	_capture_segment_frame(draw_usec,prior_draw_usec,capture_history.size()>f9_before)

func _begin_segment(draw_usec: int) -> bool:
	segment_armed=false
	segment_directory=evidence_dir.path_join("F8_%03d"%segment_serial)
	var absolute:=ProjectSettings.globalize_path(segment_directory)
	# Refuse collisions; never replace a prior sequence.
	if DirAccess.dir_exists_absolute(absolute):
		segment_control_history.append({"status":"rejected_existing_segment_directory","path":absolute});_write_segment_summary();return false
	var directory_error:=DirAccess.make_dir_recursive_absolute(absolute)
	if directory_error!=OK:
		segment_control_history.append({"status":"directory_error","error":directory_error});_write_segment_summary();return false
	segment_log=FileAccess.open(segment_directory.path_join("frames.jsonl"),FileAccess.WRITE)
	if segment_log==null:
		segment_control_history.append({"status":"metadata_open_error","error":FileAccess.get_open_error()});_write_segment_summary();return false
	segment_start_usec=draw_usec;segment_png_bytes=0;segment_last_engine_draw=-1
	segment_frames.clear();segment_callback_usec.clear()
	segment_record={"schema":"ink-native-draw-segment-1","serial":segment_serial,"status":"recording","directory":absolute,"armed_monotonic_usec":segment_armed_usec,"first_draw_monotonic_usec":draw_usec,"first_draw_index":draw_count,"source_start_time":last_presented_ink.get("source_time",0.0),"max_wall_usec":SEGMENT_USEC,"max_frames":MAX_SEGMENT_FRAMES,"max_session_png_bytes":MAX_PNG_BYTES,"renderer":RenderingServer.get_video_adapter_name(),"producer_binding_sha256":FileAccess.get_sha256(PRODUCER_BINDING_PATH),"scope":"actual framebuffer samples at real draw timestamps; readback/PNG affected timing is NOT baseline performance, native input proof, audio or art acceptance","simulation_clock_changed":false,"fixed_rate_playback_valid":false,"audio_in_sequence":false,"camera_body_metrics_policy":"existing F9 path only; linked endpoints may be outside segment"}
	segment_active=true
	return true

func _capture_segment_frame(draw_usec: int, prior_draw_usec: int, f9_same_draw: bool) -> void:
	var begin_usec:=Time.get_ticks_usec()
	var engine_draw:=Engine.get_frames_drawn()
	if engine_draw==segment_last_engine_draw:return
	var texture: ViewportTexture=get_viewport().get_texture()
	if texture==null or texture.get_width()<=0 or texture.get_height()<=0 or texture.get_width()*texture.get_height()>MAX_CAPTURE_PIXELS:
		_finish_segment("framebuffer_size_guard",Time.get_ticks_usec());return
	segment_last_engine_draw=engine_draw
	var presented_hash:=_snapshot_digest(last_presented_full,last_presented_ink)
	var before_hash:=_snapshot_digest(sim.snapshot(),sim.ink_presenter_snapshot())
	var image: Image=texture.get_image()
	if image==null or image.is_empty():
		_finish_segment("framebuffer_unavailable",Time.get_ticks_usec());return
	var png: PackedByteArray=image.save_png_to_buffer()
	if png.is_empty():
		_finish_segment("png_encode_failed",Time.get_ticks_usec());return
	if total_png_bytes+png.size()>MAX_PNG_BYTES:
		_finish_segment("session_png_byte_limit_before_write",Time.get_ticks_usec());return
	var index:=segment_frames.size()+1
	var filename:="frame_%04d.png"%index
	var output:=FileAccess.open(segment_directory.path_join(filename),FileAccess.WRITE)
	if output==null:
		_finish_segment("png_open_error_%d"%FileAccess.get_open_error(),Time.get_ticks_usec());return
	# Reserve attempted output bytes too, so a partial write cannot bypass the cap.
	segment_png_bytes+=png.size();total_png_bytes+=png.size()
	output.store_buffer(png);output.flush()
	var save_error:=output.get_error();output.close()
	if save_error!=OK:
		_finish_segment("png_write_error_%d"%save_error,Time.get_ticks_usec());return
	var hash_context:=HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256);hash_context.update(png)
	var png_hash:=hash_context.finish().hex_encode()
	var after_hash:=_snapshot_digest(sim.snapshot(),sim.ink_presenter_snapshot())
	var pair_unchanged:=presented_hash==before_hash and before_hash==after_hash
	var row: Dictionary={"frame_index":index,"filename":filename,"png_sha256":png_hash,"png_bytes":png.size(),"actual_raster_size":[image.get_width(),image.get_height()],"draw_monotonic_usec":draw_usec,"draw_wall_usec":draw_usec-start_ticks,"draw_interval_usec":draw_usec-prior_draw_usec if prior_draw_usec>0 else 0,"frame_post_draw_index":draw_count,"engine_process_frame":Engine.get_process_frames(),"engine_drawn_frame":engine_draw,"source_time":last_presented_ink.get("source_time",0.0),"paused":sim.paused,"presented_snapshot_sha256":presented_hash,"source_before_sha256":before_hash,"source_after_sha256":after_hash,"capture_pair_unchanged":pair_unchanged,"capture_begin_monotonic_usec":begin_usec,"capture_cpu_usec_before_metadata":Time.get_ticks_usec()-begin_usec,"f9_same_draw":f9_same_draw,"source_snapshot":last_presented_ink,"hero_and_enemies":last_presented_full,"actor_sample":hero_view.sample_report}
	segment_log.store_line(JSON.stringify(_json_safe(row)))
	var metadata_error:=segment_log.get_error()
	segment_frames.append({"filename":filename,"draw_monotonic_usec":draw_usec,"frame_post_draw_index":draw_count,"source_time":row.source_time,"draw_interval_usec":row.draw_interval_usec,"capture_pair_unchanged":pair_unchanged})
	segment_callback_usec.append(Time.get_ticks_usec()-begin_usec)
	if metadata_error!=OK:_finish_segment("metadata_write_error_%d"%metadata_error,Time.get_ticks_usec())
	elif not pair_unchanged:_finish_segment("HOLD_source_pair_mismatch",Time.get_ticks_usec())
	elif segment_frames.size()>=MAX_SEGMENT_FRAMES:_finish_segment("frame_limit",Time.get_ticks_usec())
	elif Time.get_ticks_usec()-segment_start_usec>=SEGMENT_USEC:_finish_segment("three_second_wall_limit",Time.get_ticks_usec())

func _finish_segment(reason: String, end_usec: int) -> void:
	if not segment_active:return
	segment_active=false
	if segment_log!=null:segment_log.flush();segment_log.close();segment_log=null
	segment_record.merge({"status":"closed","stop_reason":reason,"end_monotonic_usec":end_usec,"elapsed_wall_usec":end_usec-segment_start_usec,"frames":segment_frames.duplicate(true),"frame_count":segment_frames.size(),"png_bytes":segment_png_bytes,"session_png_bytes":total_png_bytes,"source_end_time":sim.hero_time,"capture_callback_usec_by_frame":segment_callback_usec.duplicate(),"capture_callback_cost_scope":"source digests, readback, PNG encoding/hash/write and metadata line; excludes segment open/close, inherited source_frames logging, F9 and draw callback dispatch","performance_accepted":false,"os_input_accepted":false,"art_accepted":false},true)
	_write_concat(end_usec)
	_link_f9_endpoints(segment_record)
	segment_history.append(segment_record.duplicate(true))
	_write_json("F8_%03d/segment.json"%segment_serial,segment_record)
	_write_segment_summary()
	print("INK_STYLE_F8 ",JSON.stringify({"serial":segment_serial,"stop_reason":reason,"frames":segment_frames.size(),"elapsed_wall_usec":end_usec-segment_start_usec,"directory":segment_record.directory}))

func _write_concat(end_usec: int) -> void:
	# VFR wall durations preserve observed real time. Never assume 30/60 fps.
	var concat:=FileAccess.open(segment_directory.path_join("frames.ffconcat"),FileAccess.WRITE)
	if concat==null:return
	concat.store_line("ffconcat version 1.0")
	for i in range(segment_frames.size()):
		var frame: Dictionary=segment_frames[i]
		var next_usec: int=segment_frames[i+1].draw_monotonic_usec if i+1<segment_frames.size() else end_usec
		concat.store_line("file '%s'"%frame.filename)
		concat.store_line("option framerate 1000000") # PNG demuxer microsecond time base, not playback FPS.
		concat.store_line("duration %.9f"%(float(maxi(1,next_usec-int(frame.draw_monotonic_usec)))/1000000.0))
	if not segment_frames.is_empty():
		concat.store_line("file '%s'"%segment_frames.back().filename)
		concat.store_line("option framerate 1000000")
	concat.close()

func _link_f9_endpoints(record: Dictionary) -> void:
	var before: Dictionary={}
	var after: Dictionary={}
	for capture: Dictionary in capture_history:
		if not capture.get("png_saved",false):continue
		var stamp: int=capture.get("frame_wall_usec",0)+start_ticks
		if stamp<=int(record.first_draw_monotonic_usec):before=capture
		elif stamp>=int(record.end_monotonic_usec) and after.is_empty():after=capture
	record["preceding_f9_endpoint"]=before.duplicate(true)
	record["following_f9_endpoint"]=after.duplicate(true)
	record["f9_endpoints_are_exact_segment_frames"]=false

func _capture_rendered_frame() -> void:
	super._capture_rendered_frame()
	# Reuse the inherited expensive F9 report at endpoints; never recalculate it
	# inside the per-frame recorder. A later F9 completes the adjacent link.
	for record: Dictionary in segment_history:
		_link_f9_endpoints(record)
		_write_json("F8_%03d/segment.json"%int(record.serial),record)
	if not segment_history.is_empty():_write_segment_summary()

func _write_segment_summary() -> void:
	_write_json("frame_segments.json",{"schema":"ink-native-draw-segments-1","default_off":true,"max_segments":MAX_SEGMENTS,"max_frames_per_segment":MAX_SEGMENT_FRAMES,"max_wall_usec_per_segment":SEGMENT_USEC,"max_session_png_bytes":MAX_PNG_BYTES,"session_png_bytes":total_png_bytes,"controls":segment_control_history,"segments":segment_history,"performance_accepted":false})

func save_evidence(reason: String) -> void:
	if segment_active:_finish_segment("host_close_"+reason,Time.get_ticks_usec())
	if segment_armed:
		segment_armed=false
		segment_control_history.append({"status":"host_closed_while_armed","reason":reason,"png_saved":false})
	_write_segment_summary()
	super.save_evidence(reason)
