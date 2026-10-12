extends Control
## 009 proxy geometry only. Instance mode draws the expanded instance records;
## it never falls back to source_template or derives coordinates from a template.
signal paint_requested(tool: String, depth: int, cell: Array, source: String)
signal interaction(kind: String, details: Dictionary)
signal cell_hovered(cell: Array, details: String)

const PLANES := ["H0", "H0_OVERLAY", "H0_DECAL", "H1"]
const COLORS := {
	"ground": Color("263c37"), "floor": Color("a38a57"),
	"wall": Color("b7c3cf"), "container": Color("e9b55c"),
	"boss": Color("ed7585"), "spawn": Color("84e7bd"),
	"entrance": Color("73c9fa"), "decal": Color("e6d785")
}
var active_depth: int = 0
var active_tool: String = "wall"
var actual_instance: bool = false
var editable: bool = true
var _data: Dictionary = {}
var _layer: Dictionary = {}
var _bounds := Rect2i(0, 0, 0, 0)
var _grid_origin := Vector2.ZERO
var _cell_pixels: float = 1.0
var _hover: bool = false
var _hover_cell := Vector2i.ZERO
var _stroke: bool = false
var _stroke_button: int = MOUSE_BUTTON_LEFT
var _previous_cell := Vector2i.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_refresh_layout)
	mouse_exited.connect(_leave_canvas)
	_refresh_layout()

func set_document(value: Dictionary, depth: int, instance_mode: bool = false) -> void:
	_data = value.duplicate(true)
	active_depth = depth
	actual_instance = instance_mode
	editable = not instance_mode
	_layer = {}
	# A stale or wrongly supplied template cannot masquerade as an instance.
	var expected: String = "technical_prefab_instance" if instance_mode else "technical_prefab_template"
	if _data.get("artifact_kind", "") == expected:
		for row in _data.get("layers", []):
			if int(row.get("depth", -1)) == active_depth:
				_layer = row
				break
	_refresh_layout()
	if _hover and not _layer.is_empty() and _bounds.has_point(_hover_cell):
		cell_hovered.emit([_hover_cell.x, _hover_cell.y], _cell_details(_hover_cell))
	else:
		_hover = false
		cell_hovered.emit([], "")

func cancel_stroke() -> void:
	_stroke = false
	_hover = false
	cell_hovered.emit([], "")
	queue_redraw()

func _refresh_layout() -> void:
	_bounds = Rect2i(0, 0, 0, 0)
	if not _layer.is_empty():
		var value: Array = _layer.get("bounds", [])
		if value.size() == 4:
			_bounds = Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))
	if _bounds.size.x > 0 and _bounds.size.y > 0:
		var available := Vector2(maxf(1.0, size.x - 54.0), maxf(1.0, size.y - 60.0))
		_cell_pixels = maxf(1.0, minf(available.x / float(_bounds.size.x), available.y / float(_bounds.size.y)))
		_grid_origin = Vector2(34.0, 30.0) + (available - Vector2(_bounds.size) * _cell_pixels) * 0.5
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_MOUSE_EXIT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_leave_canvas()

func _leave_canvas() -> void:
	_hover = false
	_stroke = false
	cell_hovered.emit([], "")
	queue_redraw()

func _input(event: InputEvent) -> void:
	# A release outside this Control must not leave a latent paint stroke.
	if event is InputEventMouseButton and not event.pressed:
		_stroke = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)
		if _stroke and _hover:
			var required_mask: int = MOUSE_BUTTON_MASK_RIGHT if _stroke_button == MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_LEFT
			if event.button_mask & required_mask:
				_paint_segment(_previous_cell, _hover_cell)
			else:
				_stroke = false
	elif event is InputEventMouseButton:
		_update_hover(event.position)
		interaction.emit("canvas_pointer", {
			"view": "actual_instance" if actual_instance else "template", "pressed": event.pressed,
			"button": event.button_index, "local_px": [event.position.x, event.position.y],
			"viewport_px": _viewport_point(event.position), "inside_grid": _hover,
			"cell": [_hover_cell.x, _hover_cell.y] if _hover else [], "depth": active_depth
		})
		if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			return
		if event.pressed and _hover and editable:
			_stroke = true
			_stroke_button = event.button_index
			_previous_cell = _hover_cell
			_emit_paint(_hover_cell, "pointer_press")
		else:
			_stroke = false
		accept_event()

func _viewport_point(point: Vector2) -> Array:
	var result: Vector2 = get_global_transform_with_canvas() * point
	return [result.x, result.y]

func _update_hover(point: Vector2) -> void:
	var grid_rect := Rect2(_grid_origin, Vector2(_bounds.size) * _cell_pixels)
	_hover = not _layer.is_empty() and grid_rect.has_point(point)
	if _hover:
		_hover_cell = Vector2i(floori((point.x - _grid_origin.x) / _cell_pixels), floori((point.y - _grid_origin.y) / _cell_pixels)) + _bounds.position
		cell_hovered.emit([_hover_cell.x, _hover_cell.y], _cell_details(_hover_cell))
	else:
		cell_hovered.emit([], "")
	queue_redraw()

func _paint_segment(start: Vector2i, finish: Vector2i) -> void:
	var difference := finish - start
	var steps: int = maxi(absi(difference.x), absi(difference.y))
	# Interpolate only this genuine held-button motion; there is no auto paint.
	for index in range(1, steps + 1):
		var fraction: float = float(index) / float(steps)
		var cell := Vector2i(roundi(start.x + difference.x * fraction), roundi(start.y + difference.y * fraction))
		if _bounds.has_point(cell):
			_emit_paint(cell, "pointer_drag")
	_previous_cell = finish

func _emit_paint(cell: Vector2i, source: String) -> void:
	var selected: String = "erase" if _stroke_button == MOUSE_BUTTON_RIGHT else active_tool
	paint_requested.emit(selected, active_depth, [cell.x, cell.y], source)

func _belongs(row: Dictionary) -> bool:
	if actual_instance:
		var address: Dictionary = row.get("layer", {})
		var current: Dictionary = _layer.get("address", {})
		return not address.is_empty() and address == current
	return row.get("layer_id", "") == _layer.get("local_id", "")

func _pixel_rect(value: Array) -> Rect2:
	return Rect2(_grid_origin + (Vector2(float(value[0]), float(value[1])) - Vector2(_bounds.position)) * _cell_pixels, Vector2(float(value[2]), float(value[3])) * _cell_pixels)

func _pixel_cell(value: Array) -> Vector2:
	return _grid_origin + (Vector2(float(value[0]), float(value[1])) - Vector2(_bounds.position) + Vector2(0.5, 0.5)) * _cell_pixels

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("111d27"))
	if _layer.is_empty():
		_draw_centered("尚无实际展开实例" if actual_instance else "没有可编辑模板", size.y * 0.42, Color("b7c5d4"), 18)
		_draw_centered("点击“测试实例”生成只读技术预览" if actual_instance else "请新建或打开模板", size.y * 0.42 + 30.0, Color("8497a9"), 13)
		return
	var grid := Rect2(_grid_origin, Vector2(_bounds.size) * _cell_pixels)
	draw_rect(grid, COLORS["ground"])
	for plane in PLANES:
		for row in _data.get("objects", []):
			if _belongs(row) and row.get("plane", "") == plane:
				_draw_object(row)
	for row in _data.get("protected_areas", []):
		if _belongs(row):
			draw_rect(_pixel_rect(row["rect"]), Color(0.74, 0.61, 0.95, 0.5), false, 1.0)
	_draw_connections()
	for y in range(_bounds.size.y + 1):
		var start := _grid_origin + Vector2(0.0, float(y) * _cell_pixels)
		draw_line(start, start + Vector2(grid.size.x, 0.0), Color(0.8, 0.9, 1.0, 0.15), 1.0)
	for x in range(_bounds.size.x + 1):
		var start := _grid_origin + Vector2(float(x) * _cell_pixels, 0.0)
		draw_line(start, start + Vector2(0.0, grid.size.y), Color(0.8, 0.9, 1.0, 0.15), 1.0)
	for row in _data.get("anchors", []):
		if _belongs(row):
			_draw_anchor(row)
	draw_rect(grid, Color("647d8e"), false, 1.0)
	_draw_axes()
	if _hover:
		var hover_rect := _pixel_rect([_hover_cell.x, _hover_cell.y, 1, 1])
		draw_rect(hover_rect, Color(1.0, 1.0, 1.0, 0.15))
		draw_rect(hover_rect, Color("f3e4b4"), false, 2.0)

func _draw_object(row: Dictionary) -> void:
	var rect: Rect2 = _pixel_rect(row["rect"])
	var kind: String = _object_kind(row)
	var tint: Color = COLORS.get(kind, Color("abb0c4"))
	draw_rect(rect, tint)
	if kind != "ground":
		draw_rect(rect.grow(-1.0), tint.darkened(0.4), false, 2.0)
	if kind == "container" and _cell_pixels >= 12.0:
		draw_line(rect.position + Vector2(3.0, rect.size.y * 0.42), rect.position + Vector2(rect.size.x - 3.0, rect.size.y * 0.42), Color("483c25"), 2.0)
	elif kind == "boss" and _cell_pixels >= 12.0:
		var inset: float = minf(5.0, rect.size.x * 0.2)
		draw_line(rect.position + Vector2(inset, inset), rect.end - Vector2(inset, inset), Color("6c293b"), 2.0)
		draw_line(Vector2(rect.end.x - inset, rect.position.y + inset), Vector2(rect.position.x + inset, rect.end.y - inset), Color("6c293b"), 2.0)

func _object_kind(row: Dictionary) -> String:
	var content: String = str(row.get("content_id", ""))
	if content == "fixture_container" or row.get("content_namespace") == "poi_container":
		return "container"
	if content == "fixture_boss" or content.begins_with("boss_"):
		return "boss"
	match str(row.get("plane", "")):
		"H0": return "ground"
		"H0_OVERLAY": return "floor"
		"H0_DECAL": return "decal"
		_: return "wall"

func _draw_anchor(row: Dictionary) -> void:
	var point: Vector2 = _pixel_cell(row["cell"])
	var kind: String = row.get("kind", "")
	var radius: float = maxf(2.0, _cell_pixels * 0.29)
	var tint: Color = COLORS.get(kind, Color.WHITE)
	draw_circle(point, radius + 1.5, Color("14212a"))
	if kind == "entrance":
		draw_arc(point, radius, 0.0, TAU, 24, tint, 2.0, true)
		draw_line(point - Vector2(radius * 0.55, 0), point + Vector2(radius * 0.55, 0), tint, 2.0)
	elif kind == "spawn":
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius, radius), point + Vector2(-radius, radius)]), tint)
	else:
		draw_circle(point, radius * 0.6, tint)

func _draw_connections() -> void:
	for connection in _data.get("connections", []):
		var endpoints: Array = []
		for anchor in _data.get("anchors", []):
			if anchor.get("local_id", "") in [connection.get("upper_anchor_id", ""), connection.get("lower_anchor_id", "")]:
				endpoints.append(anchor)
		var shown: Dictionary = {}
		for anchor in endpoints:
			if _belongs(anchor):
				shown = anchor
				break
		if shown.is_empty():
			continue
		var safety: Array
		var body: Array
		if actual_instance:
			# These are 008 Instantiator's expanded rectangles, not local geometry.
			safety = connection.get("safety_rect", [])
			body = connection.get("body_rect", [])
		else:
			safety = _centered_rect(shown["cell"], int(connection["safety_side_cells"]))
			body = _centered_rect(shown["cell"], int(connection["body_side_cells"]))
		if safety.size() == 4:
			draw_rect(_pixel_rect(safety), Color(0.3, 0.7, 0.95, 0.10))
			draw_rect(_pixel_rect(safety), Color(0.45, 0.8, 1.0, 0.65), false, 1.0)
		if body.size() == 4:
			draw_rect(_pixel_rect(body), Color("73c9fa"), false, 2.0)

func _centered_rect(cell: Array, side: int) -> Array:
	var half: int = floori(float(side) / 2.0)
	return [int(cell[0]) - half, int(cell[1]) - half, side, side]

func _draw_axes() -> void:
	var font: Font = get_theme_default_font()
	var tint := Color("8fa9b9")
	var stride: int = 1 if _cell_pixels >= 25.0 else 2
	for x in range(0, _bounds.size.x, stride):
		var value: String = str(_bounds.position.x + x)
		var point := _grid_origin + Vector2((float(x) + 0.5) * _cell_pixels - 6.0, -9.0)
		draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, tint)
	for y in range(0, _bounds.size.y, stride):
		var point := _grid_origin + Vector2(-27.0, (float(y) + 0.5) * _cell_pixels + 4.0)
		draw_string(font, point, str(_bounds.position.y + y), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, tint)
	var caption: String = "实例世界 XY（已展开）" if actual_instance else "模板局部 XY（相对原点）"
	_draw_centered(caption, _grid_origin.y + float(_bounds.size.y) * _cell_pixels + 24.0, tint, 12)

func _draw_centered(value: String, baseline: float, tint: Color, font_size: int) -> void:
	var font: Font = get_theme_default_font()
	var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, Vector2(maxf(6.0, (size.x - width) * 0.5), baseline), value, HORIZONTAL_ALIGNMENT_LEFT, maxf(1.0, size.x - 12.0), font_size, tint)

func _cell_details(cell: Vector2i) -> String:
	var parts := PackedStringArray()
	for row in _data.get("objects", []):
		if not _belongs(row):
			continue
		var values: Array = row["rect"]
		var rect := Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
		if rect.has_point(cell) and row.get("plane") != "H0":
			parts.append(str(row.get("content_id", "")))
			if actual_instance:
				parts.append("instance_id=" + str(row.get("instance_id", "")))
	for row in _data.get("anchors", []):
		if _belongs(row) and row.get("cell", []) == [cell.x, cell.y]:
			parts.append("锚点=" + str(row.get("kind", "")))
			if actual_instance:
				parts.append("instance_id=" + str(row.get("instance_id", "")))
	return " · ".join(parts)
