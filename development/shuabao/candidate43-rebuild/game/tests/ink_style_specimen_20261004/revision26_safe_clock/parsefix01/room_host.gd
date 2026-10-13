extends "res://tests/ink_style_specimen_20261004/revision19_actor05/fix07/parsefix01/capture_host.gd"
## Independent room preview; inherited source, actor, input and capture semantics.
## It deliberately retains the diagnostic learned Q1. It is not a normal run.
const RoomView = preload("res://tests/ink_first_floor_room_art_20261004/stage.gd")
const RoomLayout = preload("res://tests/ink_first_floor_room_art_20261004/room_layout.gd")
const BrushWave = preload("res://tests/ink_q1_effect_20261004/revision07/q1_effect_presenter.gd")
const SkillHud = preload("res://tests/ink_style_specimen_20261004/revision10_hud/hud.gd")
var bound_room_sim_id := -1
var room_binding_report: Dictionary = {}
func _refresh(delta: float) -> void:
	if is_instance_valid(stage) and stage.get_script()!=RoomView:
		stage.free()
		stage = RoomView.new()
		add_child(stage)
	if sim!=null and bound_room_sim_id!=sim.get_instance_id():
		room_binding_report = RoomLayout.bind_to_sim(sim)
		bound_room_sim_id = sim.get_instance_id()
	if is_instance_valid(q1_view) and q1_view.get_script()!=BrushWave:
		q1_view.free()
		q1_view = BrushWave.new()
		add_child(q1_view)
	if is_instance_valid(hud) and hud.get_script()!=SkillHud:
		var canvas: Node = hud.get_parent()
		var shop_was_open: bool = hud.shop_open
		var diagnostic_was_visible: bool = hud.diagnostics_visible
		hud.free()
		hud = SkillHud.new()
		canvas.add_child(hud)
		hud.shop_requested.connect(_shop)
		hud.exit_requested.connect(func():close_sample("visible_exit"))
		hud.diagnostics_requested.connect(_toggle_diagnostics)
		hud.set_shop(shop_was_open)
		hud.set_diagnostics(diagnostic_was_visible)
	super._refresh(delta)
func _ready() -> void:
	super._ready()
	_write_json("room_binding.json",room_binding_report)
	_write_json("integrated_scope.json",{"room":"forecourt01 explicit 26m layout / six boundary-attached solids","actor":"candidate05/revision19fix07 bounded turn and cast-bridge candidate; native turn/foot review remains open","q1_effect":"revision07 source-driven local pressure, dynamic and contact unaccepted","hud":"revision10 diagnostic only","camera":"18m / 40deg unchanged","normal_run":false,"entire_floor":false,"art_passed":false,"collision_engine_gate_passed":false,"shadow_pixels_verified":false,"performance_passed":false})
func _input(event: InputEvent) -> void:
	super._input(event)
	if finished or sim==null or not event is InputEventKey or event.echo or not event.pressed:return
	var key: int = event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if key!=KEY_F7:return
	get_viewport().set_input_as_handled()
	if not sim.paused:
		print("FORECOURT F7 rejected: pause first for same-state shadow A/B")
		return
	var before: String = _snapshot_digest(sim.snapshot(),sim.ink_presenter_snapshot())
	stage.set_shadow_mode("none" if stage.shadow_mode=="static" else "static")
	var after: String = _snapshot_digest(sim.snapshot(),sim.ink_presenter_snapshot())
	inputs.append({"category":"paused_room_shadow_AB","mode":stage.shadow_mode,"source_before_sha256":before,"source_after_sha256":after,"source_unchanged":before==after,"wall_usec":Time.get_ticks_usec()-start_ticks,"provenance":"received F7 InputEvent; visual layer toggle only"})
	print("FORECOURT shadow mode ",stage.shadow_mode,"; F9 captures same paused source state")
