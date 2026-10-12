extends Node2D
## Read-only connected technical view. Rows arrive from the authority, never a factory.
const Address = preload("res://scripts/world/spatial_address.gd")
var _component: Dictionary = {}
var _hash: String = ""
var _role: String = ""
var _layers: Dictionary = {}
var _objects: int = 0
var _font: SystemFont

func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Noto Sans CJK SC", "DejaVu Sans"])

func consume(component: Dictionary, role: String) -> void:
	var digest: String = JSON.stringify(component, "", true, true).sha256_text()
	_role = role
	if digest == _hash:
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_layers.clear()
	_objects = 0
	_component = component.duplicate(true)
	_hash = digest
	var plan: Dictionary = component["layout"]
	for depth in range(3):
		var layer := Node2D.new()
		layer.name = "Layer%d" % depth
		var address: Dictionary = Address.layer(plan["world_id"], "body_0001", "surface" if depth == 0 else "underground", depth)
		layer.set_meta("logical_address", address)
		add_child(layer)
		_layers[depth] = layer
	for instance in component["prefab_instances"]:
		for row in instance["objects"]:
			var node := Node2D.new()
			node.name = row["instance_id"]
			node.position = Vector2(row["rect"][0], row["rect"][1])
			node.set_meta("authoritative_record", row.duplicate(true))
			node.set_meta("prefab_instance_id", instance["prefab_instance_id"])
			node.set_meta("spawn_origin", "server_materialized_world")
			_layers[int(row["layer"]["depth"])].add_child(node)
			_objects += 1
	queue_redraw()

func statistics() -> Dictionary:
	return {"layer_nodes": _layers.size(), "materialized_object_nodes": _objects, "component_sha256": _hash, "formal_world_allowed": false, "presentation": "readonly_network_technical_proxy"}

func _draw() -> void:
	if _component.is_empty() or _font == null:
		return
	var plan: Dictionary = _component["layout"]
	draw_rect(Rect2(0, 0, 1180, 812), Color("17202d"))
	_text(Vector2(24, 36), "010 联机技术世界 · %s · F10正常退出" % _role, 23)
	_text(Vector2(24, 68), "服务器世界：" + plan["world_id"], 16)
	_text(Vector2(24, 93), "Seed：%s   只读技术代理 / 人物操作待011 / 正式放行=false" % plan["seed_decimal"], 16)
	for depth in range(3):
		var center := Vector2(195 + 385 * depth, 305)
		_text(center + Vector2(-150, -155), "地表" if depth == 0 else "地下%d层" % depth, 20)
		draw_arc(center, 140, 0, TAU, 96, Color("879bb2"), 2)
		for site in plan["biome_sites"]:
			if int(site["depth"]) == depth:
				draw_circle(center + _cell(site["cell"]) * 0.35, 4, Color("73c997"))
		for connection in plan["connections"]:
			for endpoint in connection["endpoints"]:
				if int(endpoint["layer"]["depth"]) == depth:
					draw_circle(center + _cell(endpoint["cell"]) * 0.35, 4, Color("ffc85c"))
		if depth == 0:
			draw_circle(center + _cell(plan["spawn"]["cell"]) * 0.35, 5, Color("58bbff"))
	var room_rows: Array = room_draw_records(_component)
	_text(Vector2(24, 490), "实际展开房间：共%d对象 / 下图仅地表%d对象局部" % [_objects, room_rows.size()], 19)
	draw_rect(ROOM_VIEWPORT, Color("263445"))
	for row in room_rows:
		var box: Rect2 = row["screen_rect"]
		draw_rect(box, Color("c58d72") if row["plane"] == "H1" else Color("76a56e"))
		draw_rect(box, Color("263445"), false, 1)
	_text(Vector2(420, 550), "三层逻辑地址、生态点与入口代理", 18)
	_text(Vector2(420, 580), "房间含权威展开对象与稳定实例ID", 18)
	_text(Vector2(420, 610), "未绘制完整地形、未实现碰撞/操作/生态", 18)
	_text(Vector2(420, 640), "组件校验：" + _hash.substr(0, 24), 15)

func _text(position: Vector2, value: String, size: int) -> void:
	draw_string(_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("e6edf5"))

static func _cell(value: Array) -> Vector2:
	return Vector2(value[0], value[1])

const ROOM_VIEWPORT := Rect2(24, 520, 340, 250)
const ROOM_PLANE_ORDER := {"H0": 0, "H0_OVERLAY": 1, "H0_DECAL": 2, "H1": 3}

static func room_draw_records(component: Dictionary) -> Array:
	# Screen projection only: consume server-expanded world rectangles, never instantiate.
	var origin: Vector2 = _cell(component["layout"]["spawn"]["cell"])
	var result: Array = []
	for instance in component["prefab_instances"]:
		for row in instance["objects"]:
			if int(row["layer"]["depth"]) != 0:
				continue
			var rect: Array = row["rect"]
			var world_box := Rect2(Vector2(210, 650) + (Vector2(rect[0], rect[1]) - origin) * 28, Vector2(rect[2], rect[3]) * 28)
			var visible: Rect2 = world_box.intersection(ROOM_VIEWPORT)
			if visible.has_area():
				result.append({"screen_rect": visible, "plane": row["plane"], "instance_id": row["instance_id"], "depth": 0})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if ROOM_PLANE_ORDER[a["plane"]] == ROOM_PLANE_ORDER[b["plane"]]:
			return a["instance_id"] < b["instance_id"]
		return ROOM_PLANE_ORDER[a["plane"]] < ROOM_PLANE_ORDER[b["plane"]])
	return result
