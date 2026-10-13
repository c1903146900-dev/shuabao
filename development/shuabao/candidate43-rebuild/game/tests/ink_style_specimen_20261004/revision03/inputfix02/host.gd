extends "res://tests/ink_style_specimen_20261004/revision03/fix01/host.gd"
## Narrow host-coordinate repair. Simulation/input-adapter/capture/art remain inherited.
const MouseAim=preload("res://tests/ink_style_specimen_20261004/revision03/inputfix02/mouse_aim_state.gd")
var mouse_aim: RefCounted=MouseAim.new()
func _ready() -> void:
	super._ready()
	# This is the ONLY viewport mouse poll. Later events are the authority.
	mouse_aim.seed_initial(get_viewport().get_mouse_position(),get_viewport().get_visible_rect().size)
	get_window().focus_entered.connect(_pointer_focus_gained)
	get_viewport().size_changed.connect(_pointer_viewport_resized)
	_write_json("inputfix02_contract.json",{"coordinate_source":"InputEventMouse.position; initial viewport seed once only","held_and_keyboard":"last valid received viewport coordinate reprojected through CURRENT camera, never cached ground or target","focus_resize":"invalidate old coordinate; cancel old held/preview input using existing adapter; fresh mouse event required","gui":"observe coordinates before GUI; new GUI presses/motion not routed as gameplay, held BASIC blocked over STOP controls; physical LMB-up still closes admitted gesture","source_sim_and_adapter_changed":false,"native_device_test":"pending; source/synthetic gate cannot replace real CUA"})
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if finished:return
		mouse_aim.observe(event,get_viewport().get_visible_rect().size)
		# Observe every physical up before GUI consumption, with THIS up's point.
		if not gate_mode and sim!=null and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
			var ground: Vector3=_ground_for_event(event,false)
			var result: Dictionary=input_router.handle_event(event,ground)
			_record_pointer_input(event,ground,result,"received LMB-up before GUI")
		return
	super._input(event)
func _unhandled_input(event: InputEvent) -> void:
	if finished or gate_mode or sim==null:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:return
	var ground: Vector3=_ground_for_event(event,true)
	var result: Dictionary=input_router.handle_event(event,ground)
	if result.get("reason","")!="unmapped_input":_record_pointer_input(event,ground,result,"received unhandled event")
func _ground_for_event(event: InputEvent, block_gui: bool=true) -> Vector3:
	if event is InputEventMouse:
		# Root _input/_unhandled_input positions are viewport-local, already
		# translated/scaled by Godot. Do not apply OS offsets or raster scale again.
		if not mouse_aim.accepts(event.position):return Vector3.INF
		if block_gui and _gui_blocks_pointer_at(event.position):return Vector3.INF
		return stage.ground_point(event.position)
	return _current_pointer_ground(block_gui)
func _current_pointer_ground(block_gui: bool=true) -> Vector3:
	if not mouse_aim.valid or not mouse_aim.accepts(mouse_aim.position):return Vector3.INF
	if block_gui and _gui_blocks_pointer_at(mouse_aim.position):return Vector3.INF
	return stage.ground_point(mouse_aim.position)
func _gui_blocks_pointer_at(point: Vector2) -> bool:
	if not is_instance_valid(hud):return false
	return _control_stops_at(hud,point)
func _control_stops_at(control: Control, point: Vector2) -> bool:
	if not control.is_visible_in_tree():return false
	for child in control.get_children():
		if child is Control and _control_stops_at(child,point):return true
	return control.mouse_filter==Control.MOUSE_FILTER_STOP and control.get_global_rect().has_point(point)
func _record_pointer_input(event: InputEvent, ground: Vector3, result: Dictionary, route: String) -> void:
	inputs.append({"wall_usec":Time.get_ticks_usec()-start_ticks,"source_time":sim.hero_time,"event_class":event.get_class(),"event_text":event.as_text(),"event_position":event.position if event is InputEventMouse else null,"pointer":mouse_aim.report(),"camera_position":stage.camera.global_position,"ground":ground,"result":result,"route":route,"provenance":"received InputEvent; independent native-device/CUA proof remains required"})
func _focus_lost() -> void:
	mouse_aim.lose_focus()
	super._focus_lost()
func _pointer_focus_gained() -> void:
	mouse_aim.gain_focus()
	# Existing host requires explicit resume; focus does not restart actions.
func _pointer_viewport_resized() -> void:
	mouse_aim.resize(get_viewport().get_visible_rect().size)
	if input_router!=null:input_router.suspend_input("viewport_resized")
	if sim!=null:inputs.append({"category":"host_lifecycle","kind":"viewport_resized_pointer_invalidated","wall_usec":Time.get_ticks_usec()-start_ticks,"source_time":sim.hero_time,"pointer":mouse_aim.report()})
func _process(delta: float) -> void:
	# Same frozen host clock/budgets. Only the held-aim expression is replaced.
	if finished or sim==null:return
	process_intervals_ms.append(delta*1000.0)
	var process_wall_now:=Time.get_ticks_usec()
	var measured_wall_delta:=float(process_wall_now-last_process_wall_usec)/1000000.0
	last_process_wall_usec=process_wall_now
	if not gate_mode and not sim.paused and sim.phase=="combat" and not sim.hero.dead:active_wall_seconds+=maxf(0.0,measured_wall_delta)
	if not gate_mode:
		input_router.update_held_basic(_current_pointer_ground())
		sim.step(delta)
	_refresh(delta)
	if not gate_mode and active_wall_seconds>=active_budget_seconds:close_sample("finite_active_wall_budget")
	elif not gate_mode and float(Time.get_ticks_usec()-start_ticks)/1000000.0>=finite_seconds:close_sample("independent_hard_wall_deadline")
