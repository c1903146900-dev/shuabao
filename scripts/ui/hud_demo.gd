extends Node3D
## Presentation fixture only, NOT a combat/progression implementation.
const HUD = preload("res://scripts/ui/combat_hud.gd")
var hud: Control
var model: Dictionary
var requests: Array[Dictionary] = []
var attack_count := 0
var elapsed := 0.0
var marker: MeshInstance3D
var ended := false
var baseline: Dictionary

func _ready() -> void:
	_world()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HUD.new()
	hud.name = "HUD"
	layer.add_child(hud)
	hud.adapter.request_emitted.connect(_request)
	reset_fixture()
	var help: Label = hud.label(hud, "UI 交互演示  ·  非真实战斗\n左键反馈  /  Q E R Shift  /  K 修习  /  F8 结算  /  F9 重置\nF10 查看初学候选", 14, Color("a6bac6"))
	help.position = Vector2(24, 173)
	var caption: Label = hud.label(hud, "风起荒庭", 34, Color("73908d"))
	caption.position = Vector2(24, 251)
	var sub: Label = hud.label(hud, "P R E S E N T A T I O N   S L I C E", 12, Color("73908d"))
	sub.position = Vector2(26, 298)

func reset_fixture() -> void:
	ended = false
	model = {"actor_id": "demo-fengli", "revision": 1, "level": 18, "points": 13,
		"hp": 760, "hp_max": 1000, "xp": 340, "xp_next": 600, "gold": 1280,
		"room": "荒庭 02 / 05", "wave": "2 / 3", "source_label": "演示数据", "can_undo": false,
		"skills": {
			"Q": {"name": "短矩形突刺", "rank": 2, "candidate_index": 0, "cooldown": 0.0},
			"E": {"name": "超载", "rank": 1, "candidate_index": 2, "cooldown": 8.0},
			"R": {"name": "巨圆乱剑", "rank": 1, "candidate_index": 0, "cooldown": 0.0},
			"Shift": {"name": "冲刺", "rank": 1, "cooldown": 0.0},
			"P": {"name": "击杀成长", "rank": 1, "candidate_index": 2, "reason": "被动生效"}},
		"equipment": [{"name": "长剑", "description": "展示装备，无属性联动"}, {"name": "护甲"}, {"name": "空槽"}, {"name": "空槽"}, {"name": "空槽"}, {"name": "药品", "description": "药品占用第6槽；不假定堆叠与使用规则"}]}
	baseline = model.duplicate(true)
	hud.adapter.present(model)

func _world() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 15, 13)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("14242c")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("80a7b5")
	settings.ambient_light_energy = 0.65
	env.environment = settings
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -25, 0)
	sun.light_energy = 1.2
	add_child(sun)
	_mesh(Vector3(0, -0.4, 0), Vector3(32, 0.5, 24), Color("24383e"))
	for x in range(-5, 6):
		for z in range(-4, 5):
			_mesh(Vector3(x * 2.2, -0.12, z * 2.2), Vector3(2.12, 0.08, 2.12), Color("2a4146") if (x + z) % 2 else Color("2c4449"))
	for x in [-10, 10]:
		for z in [-6, 6]:
			_mesh(Vector3(x, 0.65, z), Vector3(0.8, 1.6, 0.8), Color("486165"))
	marker = _mesh(Vector3(0, 0.9, 0), Vector3(0.5, 1.7, 0.5), Color("8de1d0"))
	_mesh(Vector3(0.55, 0.8, 0), Vector3(0.08, 0.1, 1.6), Color("e7d5a6"))
	for p in [Vector3(-3, 0.5, -3), Vector3(3, 0.5, -2), Vector3(4, 0.5, 2)]:
		_mesh(p, Vector3(0.7, 1, 0.7), Color("976950"))

func _mesh(pos: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	node.material_override = mat
	node.position = pos
	add_child(node)
	return node

func _process(delta: float) -> void:
	elapsed += delta
	marker.position.y = 0.9 + sin(elapsed * 2.0) * 0.08
	if not ended:
		for slot in model.get("skills", {}):
			var skill: Dictionary = model.skills[slot]
			skill.cooldown = maxf(0.0, skill.get("cooldown", 0.0) - delta)
		hud.adapter.present(model)

func _request(command: Dictionary) -> void:
	requests.append(command.duplicate(true))
	var action: String = command.action
	if action == "ability":
		var skill: Dictionary = model.skills[command.slot_id]
		if ended:
			hud.adapter.feedback({"text": "战斗已结束 · 状态冻结"})
		elif float(skill.get("cooldown", 0)) > 0:
			hud.adapter.feedback({"text": "%s尚在冷却" % command.slot_id})
		elif int(skill.get("rank", 0)) == 0:
			hud.adapter.feedback({"text": "尚未学习"})
		else:
			skill.cooldown = 5.0 # Explicitly UI test duration, not an ability balance value.
			hud.adapter.feedback({"text": "%s · 施放反馈演示" % skill.name})
	elif action == "learn":
		var slot: String = command.slot_id
		var skill: Dictionary = model.skills[slot]
		var cost := 2 if slot == "R" and int(skill.rank) > 0 else 1
		if command.expected_rank != skill.rank or skill.rank >= HUD.CAPS[slot] or model.points < cost:
			return
		if slot == "R" and model.level < 6:
			return
		skill.rank += 1
		skill.candidate_index = int(str(command.candidate_id).right(1)) - 1
		skill.name = HUD.CANDIDATES[slot][skill.candidate_index]
		skill.erase("reason")
		if slot == "P":
			skill.reason = "被动生效"
		model.points -= cost
		model.can_undo = ended
		hud.adapter.feedback({"text": "%s提升至%d阶 · 演示分配" % [slot, skill.rank]})
	elif action == "undo_new_points" and ended:
		# Restore only fixture allocation; never HP or CD.
		for slot in ["Q", "E", "R", "P"]:
			for field in ["rank", "candidate_index", "name", "reason"]:
				if baseline.skills[slot].has(field):
					model.skills[slot][field] = baseline.skills[slot][field]
				else:
					model.skills[slot].erase(field)
		model.points = baseline.points
		model.can_undo = false
	else:
		hud.adapter.feedback({"text": "行装请求已发出 · 物品系统未接入"})
	model.revision += 1
	hud.adapter.present(model)

func finish_demo() -> void:
	ended = true
	model.can_undo = model.points < baseline.points
	hud.adapter.present(model)
	hud.show_result({"title": "荒庭 · 波次完成", "kills": 36, "gold": 240, "xp": 180, "source_label": "演示结算 · 非真实战斗奖励"})

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			finish_demo()
		elif event.keycode == KEY_F9:
			hud.close_panels()
			reset_fixture()
		elif event.keycode == KEY_F10:
			clear_demo_loadout()
			hud.open_allocation()
		elif not hud.shade.visible:
			var map := {KEY_Q: "Q", KEY_E: "E", KEY_R: "R", KEY_SHIFT: "Shift"}
			if map.has(event.keycode):
				hud.adapter.request("ability", {"slot_id": map[event.keycode]})
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not hud.shade.visible and not ended:
		attack_count += 1
		hud.adapter.feedback({"kind": "damage", "text": "128", "critical": true, "screen_x": event.position.x, "screen_y": event.position.y})

func run_contract_tests() -> String:
	return load("res://tests/ui/ui_contract_test.gd").new().start(self)

func configure_capture(width: int, height: int, view: String) -> Dictionary:
	get_window().size = Vector2i(width, height)
	hud.close_panels()
	reset_fixture()
	model.skills.E.cooldown = 88.0 # Keep a cooldown visibly present during capture.
	if view == "allocation":
		hud.open_allocation()
	elif view == "result":
		finish_demo()
	elif view == "feedback":
		hud.adapter.feedback({"kind": "damage", "text": "256!", "critical": true})
		hud.adapter.feedback({"text": "Q · 命中反馈演示"})
	return {"requested_size": Vector2i(width, height), "actual_size": get_window().size, "view": view}

func clear_demo_loadout() -> void:
	hud.close_panels()
	reset_fixture()
	model.points = 18
	for slot in ["Q", "E", "R", "P"]:
		model.skills[slot].rank = 0
		model.skills[slot].name = "未学习"
		model.skills[slot].reason = "尚未学习"
		model.skills[slot].cooldown = 0.0
		model.skills[slot].candidate_index = 0
		hud.rows[slot].options.select(0)
	baseline = model.duplicate(true)
	hud.adapter.present(model)
