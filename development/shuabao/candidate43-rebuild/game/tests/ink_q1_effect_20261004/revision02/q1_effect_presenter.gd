extends Node3D
## Original Q1 visual consumer. It owns no simulation reference, input, clock,
## collision, actor movement, damage, release, cooldown or camera authority.
## Call present(sim.ink_presenter_snapshot()) after the simulation advances.
const GEOMETRY_PATH := "res://tests/ink_q1_effect_20261004/q1_stroke_geometry.json"
const EXPECTED_RULES_SHA := "aef68e35a4becc25fcfa4158cfc2d55ee538a942023f99b7e7cefb07dac7cf53"
const CONTACT_LIFE := 0.075
const EPS := 0.00001

var _layers: Array = []
var _materials: Array[StandardMaterial3D] = []
var _preview_material: StandardMaterial3D
var _contact_black: StandardMaterial3D
var _contact_white: StandardMaterial3D
var _wave_nodes: Dictionary = {}
var _contact_nodes: Dictionary = {}
var _seen_contacts: Dictionary = {}
var _preview_node: MeshInstance3D
var _scope_key := ""
var _last_time := -1.0
var _last_revision := -1
var _last_error := "not_presented"
var _stats: Dictionary = {}
var _initialized := false

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_initialize()

func _initialize() -> bool:
	if _initialized:
		return not _layers.is_empty()
	_initialized = true
	if not FileAccess.file_exists(GEOMETRY_PATH):
		_last_error = "missing_original_geometry"
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY_PATH))
	if not parsed is Dictionary or parsed.get("schema", "") != "ink-q1-original-mesh-1":
		_last_error = "invalid_original_geometry"
		return false
	_layers = parsed.get("layers", [])
	for layer: Dictionary in _layers:
		_materials.append(_material(_color(layer.color), bool(layer.transparent)))
	_preview_material = _material(Color(0.34, 0.43, 0.43, 0.46), true)
	_contact_black = _material(Color("182326"), false)
	_contact_white = _material(Color("E5ECE7"), false)
	_preview_node = _mesh_node("SourcePathPreview")
	return true

func _material(tint: Color, alpha: bool) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = tint
	result.vertex_color_use_as_albedo = true
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	result.roughness = 1.0
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.emission_enabled = false
	if alpha:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return result

func _mesh_node(node_name: String) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = node_name
	result.mesh = ArrayMesh.new()
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(result)
	return result

func _remove_nodes(nodes: Dictionary) -> void:
	for node: MeshInstance3D in nodes.values():
		node.visible = false
		node.queue_free()
	nodes.clear()

func reset_visuals() -> void:
	_remove_nodes(_wave_nodes)
	_remove_nodes(_contact_nodes)
	_seen_contacts.clear()
	if is_instance_valid(_preview_node):
		(_preview_node.mesh as ArrayMesh).clear_surfaces()
	_scope_key = ""
	_last_time = -1.0
	_last_revision = -1

func _fail_closed(reason: String) -> void:
	_remove_nodes(_wave_nodes)
	_remove_nodes(_contact_nodes)
	if is_instance_valid(_preview_node):
		(_preview_node.mesh as ArrayMesh).clear_surfaces()
	_last_error = reason
	_stats = {"status": "HOLD", "reason": reason, "strong_wave_count": 0}

func present(snapshot: Dictionary) -> void:
	if not _initialize():
		return
	if snapshot.get("schema", "") != "ink-q1-presenter-1":
		_fail_closed("snapshot_schema_mismatch")
		return
	var scope: Dictionary = snapshot.get("scope", {})
	if not scope.has("room_id") or not scope.has("generation"):
		_fail_closed("missing_scope")
		return
	var new_scope := str(scope.room_id) + ":" + str(scope.generation)
	if new_scope != _scope_key:
		reset_visuals()
		_scope_key = new_scope
	var source_time := float(snapshot.get("source_time", -1.0))
	var revision := int(snapshot.get("revision", -1))
	if not is_finite(source_time) or source_time < 0.0 or revision < 0:
		_fail_closed("missing_source_time_or_revision")
		return
	if source_time < _last_time - EPS or revision < _last_revision:
		_fail_closed("source_rewind_requires_explicit_reset")
		return
	if str(snapshot.get("rules_hash", "")) != EXPECTED_RULES_SHA:
		_fail_closed("rules13_identity_mismatch")
		return
	if revision == _last_revision and is_equal_approx(source_time, _last_time) and _last_error.is_empty():
		return
	_last_time = source_time
	_last_revision = revision
	_last_error = ""
	_stats = {"status": "presented_not_visually_accepted", "scope": _scope_key,
		"source_time": source_time, "revision": revision, "triangles": 0,
		"strong_wave_count": 0, "contact_count": 0, "wave_geometry": [],
		"emission": false, "particles": false, "source_mutation": false}
	_present_preview(snapshot.get("input", {}))
	var live_wave_ids: Dictionary = {}
	for wave: Dictionary in snapshot.get("waves", []):
		if str(wave.get("source", "")) != "q1" or not _item_scope_matches(wave):
			continue
		var wave_id := str(wave.get("wave_id", ""))
		if wave_id.is_empty() or not wave.has("cast_id") or not wave.has("released_at"):
			continue
		if float(wave.released_at) > source_time + EPS:
			continue
		var path: Array[Vector3] = _path(wave.get("path", []))
		var width := float(wave.get("width", 0.0))
		var front := float(wave.get("front_distance", -1.0))
		var total := _path_length(path)
		if path.size() < 2 or width <= 0.0 or not is_finite(width) or not is_finite(front):
			continue
		if front < 0.0 or front > total + 0.001:
			continue
		if absf(total - float(wave.get("path_length", -1.0))) > 0.001:
			continue
		var supplied_front := _vector(wave.get("front_position", null))
		if not supplied_front.is_finite() or supplied_front.distance_to(_point_at(path, front)) > 0.002:
			continue
		live_wave_ids[wave_id] = true
		if not _wave_nodes.has(wave_id):
			_wave_nodes[wave_id] = _mesh_node("LowWave_" + str(_wave_nodes.size()))
		var node: MeshInstance3D = _wave_nodes[wave_id]
		node.visible = true
		_render_wave(node.mesh as ArrayMesh, path, front, width, wave_id)
	for wave_id: String in _wave_nodes.keys():
		if not live_wave_ids.has(wave_id):
			var node: MeshInstance3D = _wave_nodes[wave_id]
			node.visible = false
			node.queue_free()
			_wave_nodes.erase(wave_id)
	_present_contacts(snapshot.get("receipts", []), source_time)
	_stats.strong_wave_count = _wave_nodes.size()
	_stats.contact_count = _contact_nodes.size()

func _present_preview(input: Dictionary) -> void:
	var mesh := _preview_node.mesh as ArrayMesh
	mesh.clear_surfaces()
	if str(input.get("phase", "idle")) not in ["drawing", "frozen"]:
		return
	var path := _path(input.get("path", []))
	if path.size() < 2:
		return
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var width := float(input.get("width", 0.0))
	for i in range(path.size() - 1):
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var delta := b - a
		delta.y = 0.0
		var length := delta.length()
		if length < EPS:
			continue
		var tangent := delta / length
		var side := Vector3(tangent.z, 0.0, -tangent.x)
		_append_strip(vertices, colors, a, b, side, 0.012, 0.021, Color(1, 1, 1, 0.84))
		# Broken width edges never read as an active filled river. The width is
		# read from the producer; missing source width means no boundary guide.
		if width > 0.0 and is_finite(width):
			var distance := 0.0
			while distance < length:
				var end := minf(distance + 0.24, length)
				for sign_value in [-1.0, 1.0]:
					var offset: Vector3 = side * (width * 0.5 - 0.006) * float(sign_value)
					_append_strip(vertices, colors, a + tangent * distance + offset,
						a + tangent * end + offset, side, 0.005, 0.018, Color(1, 1, 1, 0.60))
				distance += 0.66
	_add_surface(mesh, vertices, colors, _preview_material)

func _render_wave(mesh: ArrayMesh, path: Array[Vector3], front: float,
		width: float, wave_id: String) -> void:
	mesh.clear_surfaces()
	var lower := maxf(0.0, front - 1.65)
	var upper := minf(front, _path_length(path))
	var segments: Array = []
	var arc := 0.0
	for index in range(path.size() - 1):
		var delta: Vector3 = path[index + 1] - path[index]
		delta.y = 0.0
		var length := delta.length()
		if length < EPS:
			continue
		if arc + length > lower and arc < upper:
			segments.append({"id": wave_id + ":segment:" + str(index),
				"start": path[index], "tangent": delta / length,
				"lo": maxf(arc, lower), "hi": minf(arc + length, upper), "arc": arc})
		arc += length
	var triangle_count := 0
	var min_s := INF
	var max_s := -INF
	var max_lateral := 0.0
	var ids: Array[String] = []
	for segment: Dictionary in segments:
		ids.append(segment.id)
	for layer_index in range(_layers.size()):
		var layer: Dictionary = _layers[layer_index]
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		for face: Array in layer.triangles:
			var original: Array = []
			for vertex_index: int in face:
				var row: Array = layer.vertices[vertex_index]
				original.append([Vector3(float(row[0]) * width / 1.6, float(row[1]),
					front + float(row[2])), Color(float(row[3]), float(row[4]), float(row[5]), float(row[6]))])
			for segment: Dictionary in segments:
				# Clip the original triangle in arc space BEFORE world mapping.
				# No clamping of whole vertices into a pile, spline or corner bridge.
				var clipped := _clip_arc(original, float(segment.lo), true)
				clipped = _clip_arc(clipped, float(segment.hi), false)
				if clipped.size() < 3:
					continue
				for k in range(1, clipped.size() - 1):
					var tri: Array = [clipped[0], clipped[k], clipped[k + 1]]
					var p0: Vector3 = tri[0][0]
					var p1: Vector3 = tri[1][0]
					var p2: Vector3 = tri[2][0]
					if (p1 - p0).cross(p2 - p0).length_squared() < 0.00000000001:
						continue
					for item: Array in tri:
						var local: Vector3 = item[0]
						var tangent: Vector3 = segment.tangent
						var lateral := Vector3(tangent.z, 0.0, -tangent.x)
						var world: Vector3 = segment.start + tangent * (local.z - float(segment.arc))
						world += lateral * local.x + Vector3.UP * local.y
						vertices.append(world)
						colors.append(item[1])
						min_s = minf(min_s, local.z)
						max_s = maxf(max_s, local.z)
						max_lateral = maxf(max_lateral, absf(local.x))
					triangle_count += 1
		_add_surface(mesh, vertices, colors, _materials[layer_index])
	_stats.triangles += triangle_count
	_stats.wave_geometry.append({"wave_id": wave_id, "triangles": triangle_count,
		"min_arc": min_s if triangle_count > 0 else 0.0,
		"max_arc": max_s if triangle_count > 0 else 0.0,
		"front_arc": front, "max_lateral": max_lateral, "source_half_width": width * 0.5,
		"exact_segment_ids": ids, "height_cap_m": 0.35})

func _clip_arc(polygon: Array, boundary: float, keep_above: bool) -> Array:
	var output: Array = []
	if polygon.is_empty():
		return output
	var previous: Array = polygon[-1]
	var previous_position: Vector3 = previous[0]
	var previous_inside := previous_position.z >= boundary if keep_above else previous_position.z <= boundary
	for current: Array in polygon:
		var current_position: Vector3 = current[0]
		var current_inside := current_position.z >= boundary if keep_above else current_position.z <= boundary
		if current_inside != previous_inside:
			var ratio := (boundary - previous_position.z) / (current_position.z - previous_position.z)
			var point := previous_position.lerp(current_position, ratio)
			point.z = boundary
			var color_a: Color = previous[1]
			var color_b: Color = current[1]
			output.append([point, color_a.lerp(color_b, ratio)])
		if current_inside:
			output.append(current)
		previous = current
		previous_position = current_position
		previous_inside = current_inside
	return output

func _present_contacts(receipts: Array, source_time: float) -> void:
	for receipt: Dictionary in receipts:
		if str(receipt.get("source", "")) != "q1" or not _item_scope_matches(receipt):
			continue
		var receipt_id := str(receipt.get("receipt_id", ""))
		if receipt_id.is_empty() or not receipt.has("wave_id") or not receipt.has("cast_id"):
			continue
		var key := _scope_key + ":" + str(receipt.wave_id) + ":" + receipt_id
		if _seen_contacts.has(key):
			continue
		var occurred := float(receipt.get("contact_time", -1.0))
		var age := source_time - occurred
		if occurred < 0.0 or age < -EPS or age >= CONTACT_LIFE:
			continue
		_seen_contacts[key] = true
		if float(receipt.get("actual_damage", 0.0)) <= 0.0:
			continue
		var point := _vector(receipt.get("contact_position", null))
		var tangent := _vector(receipt.get("direction", null))
		if not point.is_finite() or not tangent.is_finite():
			continue
		tangent.y = 0.0
		if tangent.length_squared() < EPS:
			continue
		tangent = tangent.normalized()
		var node := _mesh_node("Contact_" + str(_seen_contacts.size()))
		node.set_meta("occurred_at", occurred)
		_contact_nodes[key] = node
		_render_contact(node.mesh as ArrayMesh, point, tangent)
	for key: String in _contact_nodes.keys():
		var node: MeshInstance3D = _contact_nodes[key]
		var age := source_time - float(node.get_meta("occurred_at"))
		if age >= CONTACT_LIFE:
			node.visible = false
			node.queue_free()
			_contact_nodes.erase(key)

func _render_contact(mesh: ArrayMesh, point: Vector3, tangent: Vector3) -> void:
	var side := Vector3(tangent.z, 0.0, -tangent.x)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	# One pressed black wedge, fixed at the actual receipt position. No target
	# transform, radial explosion, beam, screen flash, hitstop or push animation.
	var local := [Vector3(-0.17, 0.030, -0.29), Vector3(0.13, 0.030, -0.17),
		Vector3(0.075, 0.19, 0.18), Vector3(-0.13, 0.12, 0.11)]
	for index in [0, 2, 1, 0, 3, 2]:
		var v: Vector3 = local[index]
		vertices.append(point + side * v.x + tangent * v.z + Vector3.UP * v.y)
		colors.append(Color.WHITE)
	_add_surface(mesh, vertices, colors, _contact_black)
	vertices = PackedVector3Array()
	colors = PackedColorArray()
	_append_strip(vertices, colors, point - side * 0.14 - tangent * 0.015,
		point + side * 0.10 + tangent * 0.04, tangent, 0.021, 0.205, Color.WHITE)
	_add_surface(mesh, vertices, colors, _contact_white)

func _append_strip(vertices: PackedVector3Array, colors: PackedColorArray,
		a: Vector3, b: Vector3, side: Vector3, half_width: float, height: float, tint: Color) -> void:
	var points := [a - side * half_width + Vector3.UP * height,
		a + side * half_width + Vector3.UP * height,
		b - side * half_width + Vector3.UP * height,
		b + side * half_width + Vector3.UP * height]
	for index in [0, 2, 1, 1, 2, 3]:
		vertices.append(points[index])
		colors.append(tint)

func _add_surface(mesh: ArrayMesh, vertices: PackedVector3Array,
		colors: PackedColorArray, material: Material) -> void:
	if vertices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)

func _vector(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary and value.has("x") and value.has("y") and value.has("z"):
		return Vector3(float(value.x), float(value.y), float(value.z))
	return Vector3(INF, INF, INF)

func _path(raw: Variant) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not raw is Array and not raw is PackedVector3Array:
		return result
	if raw.size() > 4:
		return result
	for value: Variant in raw:
		var point := _vector(value)
		if not point.is_finite():
			return []
		result.append(point)
	return result

func _path_length(path: Array[Vector3]) -> float:
	var total := 0.0
	for i in range(path.size() - 1):
		var delta: Vector3 = path[i + 1] - path[i]
		delta.y = 0.0
		total += delta.length()
	return total

func _color(values: Array) -> Color:
	return Color(float(values[0]), float(values[1]), float(values[2]), float(values[3]))

func get_diagnostics() -> Dictionary:
	var result := _stats.duplicate(true)
	result["last_error"] = _last_error
	return result

func _item_scope_matches(item: Dictionary) -> bool:
	return str(item.get("room_id", "")) + ":" + str(item.get("generation", "")) == _scope_key

func _point_at(path: Array[Vector3], distance: float) -> Vector3:
	var left := distance
	for i in range(path.size() - 1):
		var delta: Vector3 = path[i + 1] - path[i]
		delta.y = 0.0
		var length := delta.length()
		if length < EPS:
			continue
		if left <= length or i == path.size() - 2:
			return path[i] + delta / length * minf(left, length)
		left -= length
	return Vector3(INF, INF, INF)
