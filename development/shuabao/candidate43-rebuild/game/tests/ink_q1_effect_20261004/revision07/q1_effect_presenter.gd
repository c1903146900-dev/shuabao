extends Node3D
## Original Q1 visual consumer. It owns no simulation reference, input, clock,
## collision, actor movement, damage, release, cooldown or camera authority.
## Call present(sim.ink_presenter_snapshot()) after the simulation advances.
const GEOMETRY_PATH := "res://tests/ink_q1_effect_20261004/revision07/q1_stroke_geometry.json"
const PAINT_PATH := "res://tests/ink_q1_effect_20261004/revision03/q1_original_ink_brush.png"
const STROKE_PATH := "res://tests/ink_q1_effect_20261004/revision06/q1_single_loaded_stroke.png"
const PAINT_SHADER = preload("res://tests/ink_q1_effect_20261004/revision06/ink_paint.gdshader")
const RESIDUE_LIFE := 0.13
const EXPECTED_RULES_SHA := "aef68e35a4becc25fcfa4158cfc2d55ee538a942023f99b7e7cefb07dac7cf53"
const CONTACT_LIFE := 0.075
const EPS := 0.00001

var _layers: Array = []
var _materials: Array[Material] = []
var _paint_texture: Texture2D
var _stroke_texture: Texture2D
var _residue_nodes: Dictionary = {}
var _preview_under_material: StandardMaterial3D
var _preview_material: StandardMaterial3D
var _contact_black: Material
var _contact_wet: Material
var _contact_mineral: StandardMaterial3D
var _wave_nodes: Dictionary = {}
var _free_mesh_pool: Array[MeshInstance3D] = []
var _warmup_complete := false
const MAX_FREE_MESHES := 16
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
	if not parsed is Dictionary or parsed.get("schema", "") != "ink-q1-original-mesh-7":
		_last_error = "invalid_original_geometry"
		return false
	_paint_texture = load(PAINT_PATH) as Texture2D
	if _paint_texture == null:
		_last_error = "original_pigment_texture_missing_or_unimported"
		return false
	_stroke_texture = load(STROKE_PATH) as Texture2D
	if _stroke_texture == null:
		_last_error = "original_single_stroke_missing_or_unimported"
		return false
	_layers = parsed.get("layers", [])
	for layer: Dictionary in _layers:
		_materials.append(_paint_material(layer))
	_preview_material = _material(Color(0.15, 0.24, 0.25, 0.92), true)
	_preview_under_material = _material(Color(0.88, 0.91, 0.85, 0.74), true)
	_contact_black = _paint_material({"dark": [0.035, 0.060, 0.071, 1.0], "mid": [0.26, 0.37, 0.38, 1.0], "opacity": 1.0, "hardness": 0.68, "uv_window": [0.455, 0.08, 0.13, 0.84]})
	_contact_wet = _paint_material({"dark": [0.17, 0.30, 0.30, 1.0], "mid": [0.38, 0.53, 0.46, 1.0], "opacity": 0.28, "hardness": 0.03, "uv_window": [0.425, 0.10, 0.19, 0.80]})
	_contact_mineral = _material(Color("78A9A1"), true)
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

func _paint_material(layer: Dictionary) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = PAINT_SHADER
	result.set_shader_parameter("ink_paint", _stroke_texture if bool(layer.get("stroke_footprint", false)) else _paint_texture)
	result.set_shader_parameter("use_local_footprint", bool(layer.get("stroke_footprint", false)))
	result.set_shader_parameter("pigment_dark", _color(layer.dark))
	result.set_shader_parameter("pigment_mid", _color(layer.mid))
	result.set_shader_parameter("pigment_opacity", float(layer.opacity))
	result.set_shader_parameter("edge_hardness", float(layer.hardness))
	var window: Array = layer.get("uv_window", [0.47, 0.08, 0.10, 0.84])
	result.set_shader_parameter("uv_window", Vector4(float(window[0]), float(window[1]), float(window[2]), float(window[3])))
	return result

func _mesh_node(node_name: String) -> MeshInstance3D:
	if not _free_mesh_pool.is_empty():
		var reused: MeshInstance3D = _free_mesh_pool.pop_back()
		reused.name = node_name
		reused.visible = true
		return reused
	var result := MeshInstance3D.new()
	result.name = node_name
	result.mesh = ArrayMesh.new()
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(result)
	return result

func _retire_mesh_node(node: MeshInstance3D) -> void:
	node.visible = false
	(node.mesh as ArrayMesh).clear_surfaces()
	for key: StringName in node.get_meta_list():
		node.remove_meta(key)
	if _free_mesh_pool.size() < MAX_FREE_MESHES:
		_free_mesh_pool.append(node)
	else:
		node.queue_free()

func _remove_nodes(nodes: Dictionary) -> void:
	for node: MeshInstance3D in nodes.values():
		_retire_mesh_node(node)
	nodes.clear()

func reset_visuals() -> void:
	_remove_nodes(_wave_nodes)
	_remove_nodes(_contact_nodes)
	_remove_nodes(_residue_nodes)
	_seen_contacts.clear()
	if is_instance_valid(_preview_node):
		(_preview_node.mesh as ArrayMesh).clear_surfaces()
	_scope_key = ""
	_last_time = -1.0
	_last_revision = -1

func _fail_closed(reason: String) -> void:
	_remove_nodes(_wave_nodes)
	_remove_nodes(_contact_nodes)
	_remove_nodes(_residue_nodes)
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
		"strong_wave_count": 0, "contact_count": 0, "residue_count": 0, "wave_geometry": [],
		"visual_revision": 7, "original_rgba_texture": PAINT_PATH, "single_stroke_texture": STROKE_PATH,
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
		_render_wave(node.mesh as ArrayMesh, path, front, width, wave_id, 1.0, false, maxf(0.0, source_time - float(wave.released_at)))
	for wave_id: String in _wave_nodes.keys():
		if not live_wave_ids.has(wave_id):
			var node: MeshInstance3D = _wave_nodes[wave_id]
			_retire_mesh_node(node)
			_wave_nodes.erase(wave_id)
	_present_finished(snapshot.get("finished", []), source_time, live_wave_ids)
	_present_contacts(snapshot.get("receipts", []), source_time)
	_stats.strong_wave_count = _wave_nodes.size()
	_stats.contact_count = _contact_nodes.size()
	_stats.residue_count = _residue_nodes.size()

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
	var underneath := PackedVector3Array()
	var under_colors := PackedColorArray()
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
		# A restrained two-tone drafting line. No fill, glow, wave or range ring.
		_append_strip(underneath, under_colors, a, b, side, 0.044, 0.018, Color.WHITE)
		_append_strip(vertices, colors, a, b, side, 0.022, 0.022, Color.WHITE)
		if width > 0.0 and is_finite(width):
			var distance := 0.0
			while distance < length:
				var end := minf(distance + 0.19, length)
				for sign_value in [-1.0, 1.0]:
					var offset: Vector3 = side * (width * 0.5 - 0.008) * float(sign_value)
					_append_strip(vertices, colors, a + tangent * distance + offset,
						a + tangent * end + offset, side, 0.008, 0.019, Color(1, 1, 1, 0.42))
				distance += 0.72
	_add_surface(mesh, underneath, under_colors, _preview_under_material)
	_add_surface(mesh, vertices, colors, _preview_material)

func _render_wave(mesh: ArrayMesh, path: Array[Vector3], front: float,
		width: float, wave_id: String, opacity: float = 1.0, residue: bool = false, source_age: float = 0.0) -> void:
	mesh.clear_surfaces()
	var lower := maxf(0.0, front - 2.2)
	var total_path_length := _path_length(path)
	var upper := minf(front, total_path_length)
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
		if residue and str(layer.name) in ["stroke"]:
			continue
		var uvs := PackedVector2Array()
		var footprint_uvs := PackedVector2Array()
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		for face: Array in layer.triangles:
			var original: Array = []
			for vertex_index: int in face:
				var row: Array = layer.vertices[vertex_index]
				var deformed := _deform_stroke_vertex(row, source_age, maxf(0.0, total_path_length - front), str(layer.name))
				var deformed_point: Vector3 = deformed[0]
				original.append([Vector3(deformed_point.x * width / 1.6, deformed_point.y,
					front + deformed_point.z), deformed[1], deformed[2]])
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
						var pigment: Color = item[1]
						pigment.a *= opacity
						colors.append(pigment)
						# Frozen cumulative arc UV: pigment stays at its original path
						# station, including across corners; no TIME or screen swimming.
						uvs.append(Vector2(clampf(local.x / width + 0.5, 0.0, 1.0),
							clampf(local.z / maxf(EPS, total_path_length), 0.0, 1.0)))
						# UV1 is the frozen real path station; UV2 is the original
						# pigment carried through local deformation and exact clip.
						footprint_uvs.append(item[2])
						min_s = minf(min_s, local.z)
						max_s = maxf(max_s, local.z)
						max_lateral = maxf(max_lateral, absf(local.x))
					triangle_count += 1
		_add_surface(mesh, vertices, colors, _materials[layer_index], uvs, footprint_uvs)
	_stats.triangles += triangle_count
	_stats.wave_geometry.append({"wave_id": wave_id, "triangles": triangle_count,
		"min_arc": min_s if triangle_count > 0 else 0.0,
		"max_arc": max_s if triangle_count > 0 else 0.0,
		"front_arc": front, "max_lateral": max_lateral, "source_half_width": width * 0.5,
		"exact_segment_ids": ids, "height_cap_m": 0.28, "residue_only": residue, "deform_source_age": source_age, "nonperiodic_pressure": true})

func _deform_stroke_vertex(row: Array, source_age: float, remaining_arc: float, layer_name: String) -> Array:
	# A single non-periodic brush-pressure transfer. All arguments come from
	# the current authoritative snapshot; no local clock, integration or noise.
	var origin := Vector3(float(row[0]), float(row[1]), float(row[2]))
	var u := clampf(1.0 + origin.z / 2.2, 0.0, 1.0)
	var wet := layer_name == "wet"
	var age := maxf(0.0, source_age - (0.035 if wet else 0.0))
	var loaded := smoothstep(0.0, 0.070, age)
	var center := lerpf(0.92, 0.18, smoothstep(0.030, 0.300, age))
	var pulse := (1.0 - smoothstep(0.04, 0.24, absf(u - center))) * loaded
	var lift := 1.0 - smoothstep(0.0, 1.3, maxf(0.0, remaining_arc))
	var belly := 4.0 * u * (1.0 - u)
	var pressure := pulse * (1.0 - 0.70 * lift)
	var x := origin.x * (1.0 - 0.14 * (1.0 - loaded) * u)
	x += signf(origin.x) * 0.14 * pressure * belly * (1.0 - absf(origin.x) / 0.8)
	x *= 1.0 - 0.13 * lift * u
	# Exact per-vertex displacement caps and source envelope, not a tolerance.
	x = clampf(x, maxf(-0.8, origin.x - 0.18), minf(0.8, origin.x + 0.18))
	var lag := 1.0 - u
	lag += 0.24 * pressure * lag * (1.0 - lag)
	lag *= 1.0 - 0.24 * lift * u
	var z := clampf(-2.2 * lag, maxf(-2.2, origin.z - 0.16), minf(0.0, origin.z + 0.16))
	var y := 0.018 + 0.004 * pressure if wet else 0.029 + (origin.y - 0.029) * (0.45 + 0.55 * loaded) + 0.074 * pressure * belly
	if not wet:
		y = 0.024 + (y - 0.024) * (1.0 - 0.75 * lift)
	y = clampf(y, 0.014, 0.28)
	var dry_tail := smoothstep(0.070, 0.220, age) * (1.0 - smoothstep(0.22, 0.56, u))
	var withdrawal := smoothstep(0.0, 0.90, lift - 0.30 * u)
	var alpha := float(row[6])
	var value := float(row[3])
	if wet:
		alpha *= (0.55 + 0.45 * loaded) * (1.0 - 0.30 * withdrawal)
		value *= 1.02
	else:
		alpha *= loaded * (1.0 - 0.62 * dry_tail) * (1.0 - 0.74 * withdrawal)
		value *= 1.0 - 0.13 * pressure * belly + 0.12 * dry_tail
	# Carry the original pigment coordinates WITH deformed vertices. Computing
	# these from deformed world coordinates would pin texture while a card moves.
	var footprint := Vector2(u, clampf(0.5 - origin.x / 1.6, 0.0, 1.0))
	return [Vector3(x, y, z), Color(value, value, value, alpha), footprint]

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
			var clipped_point: Array = [point, color_a.lerp(color_b, ratio)]
			if previous.size() > 2 and current.size() > 2:
				var uv_a: Vector2 = previous[2]
				var uv_b: Vector2 = current[2]
				clipped_point.append(uv_a.lerp(uv_b, ratio))
			output.append(clipped_point)
		if current_inside:
			output.append(current)
		previous = current
		previous_position = current_position
		previous_inside = current_inside
	return output

func _present_finished(finished: Array, source_time: float, live_wave_ids: Dictionary) -> void:
	var live: Dictionary = {}
	for item: Dictionary in finished:
		if str(item.get("source", "")) != "q1" or not _item_scope_matches(item):
			continue
		if not item.has("cast_id") or not item.has("released_at"):
			continue
		var wave_id := str(item.get("wave_id", ""))
		var age := source_time - float(item.get("finished_at", -999.0))
		if wave_id.is_empty() or live_wave_ids.has(wave_id) or age < 0.0 or age >= RESIDUE_LIFE:
			continue
		if str(item.get("reason", "")) != "path_end":
			continue
		var path := _path(item.get("path", []))
		var front := float(item.get("front_distance", -1.0))
		var width := float(item.get("width", 0.0))
		if path.size() < 2 or width <= 0.0 or front < 0.0 or front > _path_length(path) + 0.001:
			continue
		if not is_finite(width) or not is_finite(front):
			continue
		if absf(_path_length(path) - float(item.get("path_length", -1.0))) > 0.001:
			continue
		var source_front := _vector(item.get("front_position", null))
		if not source_front.is_finite() or source_front.distance_to(_point_at(path, front)) > 0.002:
			continue
		live[wave_id] = true
		if not _residue_nodes.has(wave_id):
			_residue_nodes[wave_id] = _mesh_node("WeakRetiredInk_" + str(_residue_nodes.size()))
		var node: MeshInstance3D = _residue_nodes[wave_id]
		var fade := 0.23 * pow(1.0 - age / RESIDUE_LIFE, 2.0)
		_render_wave(node.mesh as ArrayMesh, path, front, width, wave_id, fade, true, maxf(0.0, source_time - float(item.released_at)))
	for wave_id: String in _residue_nodes.keys():
		if not live.has(wave_id):
			var node: MeshInstance3D = _residue_nodes[wave_id]
			_retire_mesh_node(node)
			_residue_nodes.erase(wave_id)

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
		var point := _vector(receipt.get("target_contact_position", receipt.get("contact_position", null)))
		var tangent := _vector(receipt.get("direction", null))
		if not point.is_finite() or not tangent.is_finite():
			continue
		tangent.y = 0.0
		if tangent.length_squared() < EPS:
			continue
		tangent = tangent.normalized()
		var node := _mesh_node("Contact_" + str(_seen_contacts.size()))
		node.set_meta("occurred_at", occurred)
		node.set_meta("point", point)
		node.set_meta("tangent", tangent)
		_contact_nodes[key] = node
	for key: String in _contact_nodes.keys():
		var node: MeshInstance3D = _contact_nodes[key]
		var age := source_time - float(node.get_meta("occurred_at"))
		if age >= CONTACT_LIFE:
			_retire_mesh_node(node)
			_contact_nodes.erase(key)
		else:
			var fade := pow(clampf((CONTACT_LIFE - age) / 0.052, 0.0, 1.0), 0.65)
			_render_contact(node.mesh as ArrayMesh, node.get_meta("point"), node.get_meta("tangent"), fade, age)

func _render_contact(mesh: ArrayMesh, point: Vector3, tangent: Vector3, opacity: float, source_age: float) -> void:
	mesh.clear_surfaces()
	var side := Vector3(tangent.z, 0.0, -tangent.x)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	# A short wet ink spread exists ONLY for this accepted damage receipt.
	# It is grounded, irregular and directed, never a circular range marker.
	# Its growth/fade reads the same source age and ends within the same75ms.
	var wet_progress := clampf(source_age / 0.028, 0.0, 1.0)
	var wet_scale := lerpf(0.54, 1.0, wet_progress)
	var wet_alpha := opacity * (0.70 - 0.25 * wet_progress)
	var wet_outline: Array[Vector2] = [Vector2(-0.30, -0.16), Vector2(-0.36, 0.035),
		Vector2(-0.17, 0.21), Vector2(0.035, 0.29), Vector2(0.30, 0.15),
		Vector2(0.34, -0.065), Vector2(0.12, -0.24), Vector2(-0.13, -0.25)]
	for index in range(wet_outline.size()):
		var a: Vector2 = wet_outline[index] * wet_scale
		var b: Vector2 = wet_outline[(index + 1) % wet_outline.size()] * wet_scale
		for local: Vector2 in [Vector2.ZERO, a, b]:
			vertices.append(point + side * local.x + tangent * local.y + Vector3.UP * 0.019)
			colors.append(Color(1, 1, 1, wet_alpha))
			uvs.append(Vector2(clampf((local.x / maxf(0.01, wet_scale) + 0.36) / 0.70, 0.0, 1.0),
				clampf((local.y / maxf(0.01, wet_scale) + 0.25) / 0.54, 0.0, 1.0)))
	_add_surface(mesh, vertices, colors, _contact_wet, uvs)
	vertices = PackedVector3Array()
	colors = PackedColorArray()
	uvs = PackedVector2Array()
	# Three unequal connected ink petals press out from the REAL contact point.
	# The existing .64m by .65m local envelope is kept; no surrounding ring.
	var press := smoothstep(0.0, 0.024, source_age)
	var dry := smoothstep(0.026, CONTACT_LIFE, source_age)
	var spread := lerpf(0.58, 1.0, press)
	var petals: Array = [
		[Vector2(-0.03, -0.18), Vector2(-0.30, -0.02), Vector2(-0.23, 0.16), Vector2(0.03, 0.02)],
		[Vector2(-0.05, -0.08), Vector2(0.04, 0.34), Vector2(0.19, 0.23), Vector2(0.13, -0.02)],
		[Vector2(0.00, -0.11), Vector2(0.19, -0.23), Vector2(0.31, 0.035), Vector2(0.07, 0.07)]]
	for petal_index in range(petals.size()):
		var petal: Array = petals[petal_index]
		for index: int in [0, 1, 2, 0, 2, 3]:
			var authored: Vector2 = petal[index]
			var local: Vector2 = authored * spread
			var tip := index == 1 or index == 2
			var height := 0.027 + (0.12 + 0.025 * float(petal_index)) * press * (1.0 - 0.80 * dry) if tip else 0.034
			vertices.append(point + side * local.x + tangent * local.y + Vector3.UP * height)
			var pigment_alpha := opacity * (1.0 - dry * (0.58 if tip else 0.25))
			colors.append(Color(1, 1, 1, pigment_alpha))
			uvs.append(Vector2(clampf((authored.x + 0.32) / 0.64, 0.0, 1.0), clampf((authored.y + 0.30) / 0.65, 0.0, 1.0)))
	_add_surface(mesh, vertices, colors, _contact_black, uvs)
	vertices = PackedVector3Array()
	colors = PackedColorArray()
	# One small matte mineral-teal center, lower value than white damage text.
	# It is inside the ink press, not a particle, whole-body tint, halo or ring.
	for local: Vector2 in [Vector2(-0.045, -0.018), Vector2(0.105, 0.025), Vector2(0.015, 0.13)]:
		vertices.append(point + side * local.x * spread + tangent * local.y * spread + Vector3.UP * 0.092)
		colors.append(Color(1, 1, 1, opacity * (1.0 - dry) * 0.90))
	_add_surface(mesh, vertices, colors, _contact_mineral)

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
		colors: PackedColorArray, material: Material, uvs: PackedVector2Array = PackedVector2Array(),
		footprint_uvs: PackedVector2Array = PackedVector2Array()) -> void:
	if vertices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	if not footprint_uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV2] = footprint_uvs
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
	result["pooled_mesh_nodes"] = _free_mesh_pool.size()
	result["bounded_warmup_complete"] = _warmup_complete
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

func warm_visual_resources_before_input() -> Dictionary:
	# OPTIONAL and explicit. Main calls this only behind a loading/paused host,
	# before enabling input. No simulation object, snapshot or source clock is
	# touched. This is preparation evidence, never a first-cast performance pass.
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return {"status": "refused_no_active_renderer", "render_frames": 0}
	if _warmup_complete:
		return {"status": "already_warmed", "render_frames": 0}
	if not _initialize():
		return {"status": "unavailable", "reason": _last_error}
	if not _wave_nodes.is_empty() or not _contact_nodes.is_empty() or not _residue_nodes.is_empty():
		return {"status": "refused_visuals_in_use", "render_frames": 0}
	var descriptors: Array = []
	for material: Material in _materials:
		descriptors.append({"material": material, "uv": true, "footprint": true})
	descriptors.append({"material": _contact_black, "uv": true})
	descriptors.append({"material": _contact_wet, "uv": true})
	descriptors.append({"material": _contact_mineral, "uv": false})
	descriptors.append({"material": _preview_material, "uv": false})
	descriptors.append({"material": _preview_under_material, "uv": false})
	var viewport := SubViewport.new()
	viewport.name = "BoundedInkResourceWarmup"
	viewport.size = Vector2i(96, 96)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	camera.position = Vector3(0.0, 4.0, 0.01)
	viewport.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	for index in range(descriptors.size()):
		var descriptor: Dictionary = descriptors[index]
		var instance := MeshInstance3D.new()
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh := ArrayMesh.new()
		var vertices := PackedVector3Array([Vector3(-0.4, 0, -0.4), Vector3(-0.4, 0, 0.4), Vector3(0.4, 0, -0.4),
			Vector3(0.4, 0, -0.4), Vector3(-0.4, 0, 0.4), Vector3(0.4, 0, 0.4)])
		var colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
		var uvs := PackedVector2Array()
		if bool(descriptor.uv):
			uvs = PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)])
		_add_surface(mesh, vertices, colors, descriptor.material, uvs, uvs if bool(descriptor.get("footprint", false)) else PackedVector2Array())
		instance.mesh = mesh
		instance.position = Vector3(float(index % 3) - 1.0, 0, float(floori(float(index) / 3.0)) - 1.0)
		viewport.add_child(instance)
	# Finite visible-to-its-private-viewport draws. Hidden nodes alone are not
	# asserted to warm shaders. No screenshots/PNG writes enter this interval.
	var observed: Dictionary = {"draws": 0}
	var listener: Callable = func(): observed.draws += 1
	RenderingServer.frame_post_draw.connect(listener)
	# At most12 process iterations, even if this renderer emits no draw signal.
	for frame in range(12):
		await get_tree().process_frame
		if int(observed.draws) >= 3:
			break
	RenderingServer.frame_post_draw.disconnect(listener)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.queue_free()
	var reserved: Array[MeshInstance3D] = []
	for index in range(6):
		reserved.append(_mesh_node("ReservedInkMesh_" + str(index)))
	for node: MeshInstance3D in reserved:
		_retire_mesh_node(node)
	_warmup_complete = int(observed.draws) >= 3
	return {"status": "bounded_resource_warmup_drawn" if _warmup_complete else "warmup_inconclusive_no_three_draws", "render_frames": int(observed.draws),
		"private_viewport": Vector2i(96, 96), "material_layouts": descriptors.size(),
		"reserved_mesh_nodes": 6, "simulation_touched": false,
		"caveat": "Different main viewport settings may still compile variants; first actual cast remains separately measured"}
