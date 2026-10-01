extends Node3D
## Real progression model integration in a presentation-only scene.
const HUD = preload("res://scripts/ui/progression_hud.gd")
const Controller = preload("res://scripts/ui/progression_controller.gd")
const Fixture = preload("res://scripts/ui/progression_demo_fixture.gd")
var hud: Control
var controller: RefCounted
var model: RefCounted
var fixture: Dictionary
var attack_count := 0
var polled_attack_count := 0
var leaked_keys: Array[int] = []
var elapsed := 0.0
var context_serial := 0

func _ready() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 14, 12)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24
	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-65, -30, 0)
	var floor_node := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(20, 0.2, 16)
	floor_node.mesh = floor_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("243c43")
	floor_node.material_override = material
	add_child(floor_node)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HUD.new()
	layer.add_child(hud)
	var help: Label = hud.label(hud, "成长接线演示\nK 修习  /  P 行装与补给  /  Esc 关闭\nF7 仅切换测试阶段（不会暂停）\n无战斗模拟 · 无金币重置键", 14, Color("a6bac6"))
	help.position = Vector2(24, 178)
	hud.move_child(help, 0)
	build_fixture_for_test()

func build_fixture_for_test() -> void:
	# Explicit setup boundary. Called once on startup or by the test harness, never UI.
	fixture = Fixture.create()
	if fixture.has("error"):
		hud.notice.text = fixture.error
		push_error(fixture.error)
		return
	model = fixture.model
	if controller == null:
		controller = Controller.new()
	controller.combat.clear()
	controller.active_milestone = 0
	controller.receipt_log.clear()
	controller.bind(model, hud, fixture.definitions, fixture.presentation)
	attack_count = 0
	polled_attack_count = 0
	leaked_keys.clear()

func _process(delta: float) -> void:
	elapsed += delta # Presentation heartbeat, NOT a combat/CD clock.
	if controller != null and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not controller.blocks_gameplay_input():
		polled_attack_count += 1 # Verifies the same gate required for arena's held attack.

func set_demo_phase(phase: String, training := false) -> Dictionary:
	context_serial += 1
	var result: Dictionary = model.command("demo-context-%d" % context_serial, "context", {"phase": phase, "training": training})
	controller.refresh()
	return result

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_Q, KEY_E, KEY_R, KEY_SHIFT, KEY_W]:
		leaked_keys.append(event.keycode)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		if model != null:
			var safe: bool = model.snapshot().phase == "safe"
			set_demo_phase("combat" if safe else "safe", not safe)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not controller.blocks_gameplay_input():
			attack_count += 1 # Demonstrates input ownership; never applies damage.

func run_growth_tests() -> String:
	return load("res://tests/ui/progression_integration_test.gd").new().start(self)

func configure_capture(width: int, height: int, view: String) -> Dictionary:
	get_window().size = Vector2i(width, height)
	hud.close_panels()
	if view == "allocation":
		hud.open_allocation()
	elif view == "shop":
		hud.open_supply(0)
	elif view == "inventory":
		hud.open_supply(1)
	elif view == "hex":
		hud.open_supply(2)
	return {"actual_size": get_window().size, "view": view, "gold": model.snapshot().gold}

func evidence_state() -> Dictionary:
	return {"model": model.snapshot(), "combat": controller.combat.duplicate(true), "last_result": controller.last_result,
		"requests": controller.receipt_log.duplicate(true), "attack_count": attack_count, "elapsed": elapsed}
