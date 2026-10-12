extends Node2D
## Batch 006 technical acceptance fixture. Not the game's character/HUD/art scene.
const Address = preload("res://scripts/world/spatial_address.gd")
const Inputs = preload("res://scripts/world/spatial_inputs.gd")
const Model = preload("res://scripts/world/spatial_model.gd")
const Physics = preload("res://scripts/world/spatial_physics.gd")
const Decals = preload("res://scripts/world/visual_decal_cache.gd")
const Pointer = preload("res://scripts/world/spatial_pointer.gd")
const WORLD := "world_00600600600600600600600600600600"
const CELL_PIXELS := 36.0 # Fixture display scale, not gameplay data.
const ORIGIN := Vector2(60, 130)
const ENTRY := Vector2i(2, 2) # Explicit paired entrance fixture, not random generation.
var model: RefCounted
var physics: RefCounted
var inputs: RefCounted
var decals: RefCounted
var identities: Array[Dictionary] = []
var active_layer: int = 0
var running: bool = false
var message: String = "空间试验场初始化"
var status: Label
var _pointer := Pointer.new()
var _last_pointer_event_position := Vector2(-1, -1)
var _last_pointer_event_type: String = "none"

func _ready() -> void:
	status = Label.new()
	status.position = Vector2(30, 20)
	status.add_theme_font_size_override("font_size", 20)
	add_child(status)
	inputs = Inputs.new()
	if not inputs.load_file():
		_fail(inputs.last_error)
		return
	model = Model.new(WORLD, inputs.data)
	if not model.create_starting_body()["ok"]:
		_fail("首母星身份创建失败")
		return
	identities = [Address.layer(WORLD, "body_0001", "surface", 0), Address.layer(WORLD, "body_0001", "underground", 1)]
	for identity in identities:
		if not model.add_layer(identity, Rect2i(0, 0, 20, 13))["ok"]:
			_fail("地图层创建失败")
			return
	var placements := [
		[0, "H1", "entity_00000000000000000000000000000001", "jianzhu_qiang_00", Vector2i(7, 4)],
		[0, "H1", "entity_00000000000000000000000000000002", "gongzuotai_jichu", Vector2i(10, 7)],
		[0, "H0_OVERLAY", "entity_00000000000000000000000000000003", "jianzhu_diban_00", Vector2i(7, 4)],
		[1, "H1", "entity_00000000000000000000000000000004", "jianzhu_qiang_00", Vector2i(5, 8)]
	]
	for placement in placements:
		if not model.place_object(identities[placement[0]], placement[1], placement[2], placement[3], placement[4])["ok"]:
			_fail("试验对象放置失败")
			return
	decals = Decals.new(2)
	decals.add(identities[0], Vector2i(4, 3), "fixture_grass")
	physics = Physics.new()
	for identity in identities:
		if not physics.add_layer(model, identity):
			_fail("独立物理空间创建失败")
			return
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not physics.add_actor("fixture_player", identities[0], Address.cell_center(ENTRY), inputs.parameter("actor_diameter_cells") / 2.0):
		_fail("试验人物安全落点失败")
		return
	running = true
	message = "WASD 移动；鼠标指向蓝色入口格后 F 切层；F10 退出试验"
	print("SPATIAL_LAB_READY surface/body_0001 2.5,2.5; technical proxies only")
	_update_status()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not running:
		return
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if direction.length_squared() > 0:
		physics.move_actor("fixture_player", direction.normalized() * inputs.parameter("movement_speed_cells_per_second") * delta)
	_update_status()
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_MOUSE_EXIT, NOTIFICATION_APPLICATION_FOCUS_OUT] and _pointer != null:
		_pointer.invalidate()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_pointer.consume(event, get_viewport_rect().size)
		_last_pointer_event_position = event.position
		_last_pointer_event_type = event.get_class()
		if event is InputEventMouseButton and event.pressed:
			_trace_pointer("mouse_button")

func _trace_pointer(reason: String) -> void:
	print("SPATIAL_LAB_POINTER reason=", reason, " event_type=", _last_pointer_event_type, " event_px=", _last_pointer_event_position, " viewport_px=", get_viewport().get_mouse_position(), " global_px=", get_global_mouse_position(), " viewport_size=", get_viewport_rect().size, " canvas=", get_global_transform_with_canvas(), " event_cell=", _pointer.cell(ORIGIN, CELL_PIXELS))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F10:
		print("SPATIAL_LAB_OPERATOR_EXIT")
		get_tree().quit(0)
		return
	if not running or not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode != KEY_F:
		return
	_trace_pointer("F_attempt_event_coordinates")
	var cell: Dictionary = _pointer.cell(ORIGIN, CELL_PIXELS)
	var actor: Dictionary = physics.actor_view("fixture_player")
	if not cell["ok"] or cell["cell"] != ENTRY:
		message = "请将鼠标指向蓝色入口格，再按 F"
	elif actor["position"].distance_to(Address.cell_center(ENTRY)) > inputs.parameter("interaction_range_cells"):
		message = "距离入口超过表内 1.5 格"
	else:
		var target := 1 - active_layer
		var result: Dictionary = physics.transfer_actor("fixture_player", identities[target])
		if result["ok"]:
			active_layer = target
			message = "已主动切层，人物相对 XY 保持不变"
			print("SPATIAL_LAB_TRANSFER ", Address.key(identities[active_layer]), " position=", actor["position"])
		else:
			message = "入口目标被阻挡：" + result["code"]
	_update_status()
	queue_redraw()

func _draw() -> void:
	if not running:
		return
	var identity: Dictionary = identities[active_layer]
	var view: Dictionary = model.layer_view(identity)
	var ground := Color("294c37") if active_layer == 0 else Color("403c47")
	draw_rect(Rect2(ORIGIN, Vector2(20, 13) * CELL_PIXELS), ground)
	for y in range(14):
		draw_line(ORIGIN + Vector2(0, y) * CELL_PIXELS, ORIGIN + Vector2(20, y) * CELL_PIXELS, Color(1, 1, 1, 0.12))
	for x in range(21):
		draw_line(ORIGIN + Vector2(x, 0) * CELL_PIXELS, ORIGIN + Vector2(x, 13) * CELL_PIXELS, Color(1, 1, 1, 0.12))
	# Plane rendering order is explicit, independent of dictionary insertion order.
	for plane in ["H0_OVERLAY", "H1"]:
		for object in view["objects"].values():
			if object["plane"] != plane:
				continue
			var definition: Dictionary = model.definition(object["content_id"])
			var size: Array = definition["footprint_cells"]
			var rect := Rect2(ORIGIN + Vector2(object["anchor"]) * CELL_PIXELS, Vector2(size[0], size[1]) * CELL_PIXELS)
			draw_rect(rect, Color("98733f") if plane == "H0_OVERLAY" else Color("beb7a4"))
			draw_rect(rect, Color("282522"), false, 2)
	if not decals.at(identity, Vector2i(4, 3)).is_empty():
		draw_circle(ORIGIN + Vector2(4.5, 3.5) * CELL_PIXELS, 4.0, Color("e6cf71"))
	draw_rect(Rect2(ORIGIN + Vector2(ENTRY) * CELL_PIXELS, Vector2.ONE * CELL_PIXELS), Color("53c7ec"), false, 3)
	var actor: Dictionary = physics.actor_view("fixture_player")
	draw_circle(ORIGIN + actor["position"] * CELL_PIXELS, actor["radius"] * CELL_PIXELS, Color("f4dc92"))

func _update_status() -> void:
	if not running:
		return
	var actor: Dictionary = physics.actor_view("fixture_player")
	status.text = "006 技术代理试验场（非正式美术/完整人物）\n%s depth=%d | body_0001 | XY %.2f, %.2f\n%s" % [identities[active_layer]["map_kind"], identities[active_layer]["depth"], actor["position"].x, actor["position"].y, message]

func _fail(reason: String) -> void:
	message = "006 初始化失败：" + reason
	status.text = message
	push_error(message)

func _exit_tree() -> void:
	if physics != null:
		physics.dispose()
