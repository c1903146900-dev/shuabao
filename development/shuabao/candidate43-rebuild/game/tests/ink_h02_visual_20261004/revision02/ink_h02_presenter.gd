extends Node3D
## Read-only H02 renderer. This object has no simulation, actor or input handle.
## Host: present(sim.ink_presenter_snapshot(), fresh_detached_combat_events).
## The second argument is optional: without actual pulls, draw only water.
const SHAPES_PATH := "res://tests/ink_h02_visual_20261004/revision02/h02_ribbon_shapes.json"
const BRUSH_PATH := "res://tests/ink_q1_effect_20261004/revision06/q1_single_loaded_stroke.png"
const INK_SHADER = preload("res://tests/ink_h02_visual_20261004/revision02/ink_h02.gdshader")
const PULL_SHADER = preload("res://tests/ink_h02_visual_20261004/ink_h02.gdshader")
const RULES_SHA := "aef68e35a4becc25fcfa4158cfc2d55ee538a942023f99b7e7cefb07dac7cf53"
const EPS := 0.00001
const PULL_RECENCY := EPS # Only this exact source sample, no predictive/history tail.
const MAX_PULL_TARGETS := 12 # Bounded cosmetic density; no source limit.
const CURVE_STEPS := 8
var _shapes: Array = []
var _brush_cross_sections: Array = []
var _brush: Texture2D
var _initialized := false
var _ready_ok := false
var _zones: Dictionary = {}
var _pull_receipts: Dictionary = {}
var _pull_node: MeshInstance3D
var _pull_material: ShaderMaterial
var _scope_key := ""
var _last_time := -1.0
var _last_revision := -1
var _requires_reset := false
var _diagnostics: Dictionary = {"status":"not_presented", "art_accepted":false}

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_initialize()

func _initialize() -> bool:
	if _initialized:return _ready_ok
	_initialized = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHAPES_PATH))
	if not parsed is Dictionary or parsed.get("schema", "") != "ink-h02-open-water-ribbons-2":
		_fail_closed("missing_or_invalid_authored_shapes")
		return false
	_shapes = parsed.get("ribbons", [])
	_brush_cross_sections = parsed.get("brush_cross_sections", [])
	_brush = load(BRUSH_PATH) as Texture2D
	if _brush == null or _shapes.size() != 3 or _brush_cross_sections.size() != 65:
		_fail_closed("original_brush_unimported_or_shape_count_changed")
		return false
	_pull_material = _material(0.38, false, 0.0)
	# Real-displacement receipt pigment retains its exact previous shader.
	_pull_material.shader = PULL_SHADER
	_pull_node = _mesh_node("ActualDisplacementWaterLines", self)
	_pull_node.material_override = _pull_material
	_ready_ok = true
	return true

func _material(opacity: float, wet: bool, phase: float) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = INK_SHADER
	result.set_shader_parameter("original_brush", _brush)
	result.set_shader_parameter("opacity", opacity)
	result.set_shader_parameter("quiet_wet_edge", wet)
	result.set_shader_parameter("layer_phase", phase)
	if wet:
		result.set_shader_parameter("deep_ink", Color(0.31, 0.38, 0.36))
		result.set_shader_parameter("dilute_ink", Color(0.47, 0.53, 0.49))
	return result

func _mesh_node(label: String, parent: Node) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = ArrayMesh.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func reset_visuals() -> void:
	for record: Dictionary in _zones.values():
		var node: Node3D = record.node
		node.visible = false
		node.queue_free()
	_zones.clear()
	_pull_receipts.clear()
	if is_instance_valid(_pull_node):(_pull_node.mesh as ArrayMesh).clear_surfaces()
	_scope_key = ""
	_last_time = -1.0
	_last_revision = -1
	_requires_reset = false

func _fail_closed(reason: String) -> void:
	# Preserve watermarks: a rewind must remain blocked until explicit reset.
	var previous_scope := _scope_key
	var previous_time := _last_time
	var previous_revision := _last_revision
	reset_visuals()
	_scope_key = previous_scope
	_last_time = previous_time
	_last_revision = previous_revision
	_requires_reset = reason in ["source_rewind_requires_reset", "active_vortex_identity_changed"]
	_diagnostics = {"status":"HOLD", "reason":reason, "vortices":0, "pull_lines":0, "art_accepted":false}

func _vector(value: Variant) -> Vector3:
	if value is Vector3:return value
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.INF

func _ground(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)

func _scope_matches(item: Dictionary) -> bool:
	return str(item.get("room_id", "")) + ":" + str(item.get("generation", -1)) == _scope_key

func present(snapshot: Dictionary, fresh_events: Array = []) -> void:
	if not _initialize():return
	if snapshot.get("schema", "") != "ink-q1-presenter-1" or snapshot.get("h02_schema", "") != "ink-q1-h02-presenter-1":
		_fail_closed("snapshot_schema_mismatch")
		return
	if str(snapshot.get("rules_hash", "")) != RULES_SHA:
		_fail_closed("rules_identity_mismatch")
		return
	var scope: Dictionary = snapshot.get("scope", {})
	var now := float(snapshot.get("source_time", -1.0))
	var revision := int(snapshot.get("revision", -1))
	if not scope.has("room_id") or not scope.has("generation") or not is_finite(now) or now < 0.0 or revision < 0:
		_fail_closed("missing_scope_or_source_clock")
		return
	var next_scope := str(scope.room_id) + ":" + str(scope.generation)
	if next_scope != _scope_key:
		reset_visuals()
		_scope_key = next_scope
	if _requires_reset:return
	if now < _last_time - EPS or revision < _last_revision:
		_fail_closed("source_rewind_requires_reset")
		return
	_last_time = now
	_last_revision = revision
	var live: Dictionary = {}
	var rejected := 0
	for value: Variant in snapshot.get("vortices", []):
		if not value is Dictionary:continue
		var vortex: Dictionary = value
		if not _valid_vortex(vortex, now):
			rejected += 1
			continue
		var key := str(vortex.vortex_id)
		live[key] = vortex
		if not _zones.has(key):_zones[key] = _create_zone(vortex, snapshot.get("finished", []))
		var record: Dictionary = _zones[key]
		# Stable source identity cannot quietly change center/size/birth in place.
		if _vector(vortex.position) != record.center or float(vortex.radius) != record.radius or float(vortex.born_at) != record.born_at:
			_fail_closed("active_vortex_identity_changed")
			return
		var age := now - float(vortex.born_at)
		var remaining := float(vortex.expires_at) - now
		# Immediate quiet presence, slight loading, then early lift of the bone.
		# Nothing persists once the authoritative snapshot retires the vortex.
		var envelope := (0.32 + 0.68 * smoothstep(0.0, 0.13, age)) * (0.20 + 0.80 * smoothstep(0.0, 0.25, remaining))
		for material: ShaderMaterial in record.materials:
			material.set_shader_parameter("source_age", age)
			material.set_shader_parameter("life_envelope", envelope)
	for key: String in _zones.keys():
		if not live.has(key):
			var node: Node3D = _zones[key].node
			node.visible = false
			node.queue_free()
			_zones.erase(key)
	_ingest_real_pulls(fresh_events, live, now)
	var pull_count := _render_real_pulls(live, now)
	_diagnostics = {"status":"presented_unreviewed_candidate", "scope":_scope_key, "source_time":now,
		"revision":revision, "vortices":_zones.size(), "pull_lines":pull_count, "rejected_vortices":rejected,
		"zone_triangles":_zone_triangle_count(), "source_mutation":false, "art_accepted":false,
		"particles":false, "emission":false, "ground_height_max_m":0.047, "visual_revision":"loaded_hook_02",
		"pull_policy":"actual nonzero source segments only; no extension beyond recorded motion",
		"original_brush":BRUSH_PATH}

func _valid_vortex(vortex: Dictionary, now: float) -> bool:
	for key: String in ["vortex_id", "wave_id", "cast_id", "position", "radius", "duration", "born_at", "expires_at", "source_time"]:
		if not vortex.has(key):return false
	if not _scope_matches(vortex) or str(vortex.get("source", "")) != "yanguizhou_h02":return false
	if str(vortex.vortex_id).is_empty() or not _vector(vortex.position).is_finite():return false
	var radius := float(vortex.radius)
	var birth := float(vortex.born_at)
	var expiry := float(vortex.expires_at)
	var duration := float(vortex.duration)
	return is_finite(radius) and radius > 0.0 and is_finite(birth) and is_finite(expiry) and is_finite(duration) and duration > 0.0 and absf(expiry-birth-duration) <= EPS and absf(float(vortex.source_time)-now) <= EPS and birth <= now + EPS and now < expiry

func _create_zone(vortex: Dictionary, finished: Array) -> Dictionary:
	var root := Node3D.new()
	root.name = "ShallowInkVortex_" + str(_zones.size())
	root.position = _vector(vortex.position)
	add_child(root)
	# Continue the last real Q1 direction if available; never infer target pull.
	for value: Variant in finished:
		if not value is Dictionary:continue
		var wave: Dictionary = value
		if str(wave.get("wave_id", "")) != str(vortex.wave_id) or not _scope_matches(wave):continue
		var direction := _ground(_vector(wave.get("front_direction", Vector3.INF)))
		if direction.is_finite() and direction.length_squared() > EPS:
			root.rotation.y = atan2(-direction.x, -direction.z)
			break
	var materials: Array[ShaderMaterial] = []
	var triangles := 0
	for shape: Dictionary in _shapes:
		if bool(shape.wet_edge):
			var wet := _mesh_node(str(shape.name) + "_local_dilution", root)
			wet.mesh = _ribbon_mesh(shape, float(vortex.radius), 1.12, -0.009)
			var wet_material := _material(0.18, true, float(shape.phase))
			wet.material_override = wet_material
			materials.append(wet_material)
			triangles += int((wet.mesh as ArrayMesh).surface_get_array_len(0) / 3)
		var bone := _mesh_node(str(shape.name), root)
		bone.mesh = _ribbon_mesh(shape, float(vortex.radius), 1.0, 0.0)
		var material := _material(float(shape.opacity), false, float(shape.phase))
		bone.material_override = material
		materials.append(material)
		triangles += int((bone.mesh as ArrayMesh).surface_get_array_len(0) / 3)
	return {"node":root, "materials":materials, "center":_vector(vortex.position), "radius":float(vortex.radius), "born_at":float(vortex.born_at), "triangles":triangles}

func _ribbon_mesh(shape: Dictionary, radius: float, width_scale: float, height_offset: float) -> ArrayMesh:
	var points: Array[Vector3] = []
	var widths: Array[float] = []
	var controls: Array = shape.points
	for index in range(controls.size() - 1):
		var a := Vector3(float(controls[maxi(0,index-1)][0]), 0, float(controls[maxi(0,index-1)][1]))
		var b := Vector3(float(controls[index][0]), 0, float(controls[index][1]))
		var c := Vector3(float(controls[index+1][0]), 0, float(controls[index+1][1]))
		var d := Vector3(float(controls[mini(controls.size()-1,index+2)][0]), 0, float(controls[mini(controls.size()-1,index+2)][1]))
		for step in range(CURVE_STEPS):
			var u := float(step) / float(CURVE_STEPS)
			points.append(b.cubic_interpolate(c, a, d, u) * radius)
			widths.append(lerpf(float(shape.widths[index]), float(shape.widths[index+1]), smoothstep(0.0,1.0,u)) * radius * width_scale)
	points.append(Vector3(float(controls.back()[0]), 0, float(controls.back()[1])) * radius)
	widths.append(float(shape.widths.back()) * radius * width_scale)
	return _make_ribbon(points, widths, float(shape.height) + height_offset, radius, true)

func _brush_uv(flow: float, lateral: float) -> Vector2:
	# Numeric UV fit to the unchanged original bitmap's occupied cross-sections.
	# Preserve the real alpha holes; no rectangular minimum-alpha fill.
	var station := clampf(flow, 0.0, 1.0) * float(_brush_cross_sections.size() - 1)
	var index := mini(int(station), _brush_cross_sections.size() - 2)
	var fraction := station - float(index)
	var a: Array = _brush_cross_sections[index]
	var b: Array = _brush_cross_sections[index + 1]
	return Vector2(lerpf(float(a[0]), float(b[0]), fraction),
		lerpf(lerpf(float(a[1]), float(b[1]), fraction), lerpf(float(a[2]), float(b[2]), fraction), lateral))

func _make_ribbon(points: Array[Vector3], widths: Array[float], height: float, radius_limit: float = -1.0, attached_brush: bool = false) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var flow_uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var lengths: Array[float] = [0.0]
	for i in range(1, points.size()):lengths.append(lengths.back() + points[i].distance_to(points[i-1]))
	var total := maxf(EPS, lengths.back())
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in range(points.size()):
		var tangent := (points[mini(i+1,points.size()-1)] - points[maxi(i-1,0)]).normalized()
		var side := Vector3(tangent.z, 0, -tangent.x)
		for sign_value in [-1.0, 1.0]:
			var point := points[i] + side * widths[i] * 0.5 * float(sign_value)
			if radius_limit > 0.0:point = point.limit_length(radius_limit)
			point.y = height
			if sign_value < 0.0:left.append(point)
			else:right.append(point)
	for i in range(points.size()-1):
		var u0 := lengths[i] / total
		var u1 := lengths[i+1] / total
		var quad := [left[i], right[i], left[i+1], right[i+1]]
		var tex := [Vector2(u0,0), Vector2(u0,1), Vector2(u1,0), Vector2(u1,1)]
		for index in [0,1,2,2,1,3]:
			vertices.append(quad[index])
			flow_uvs.append(tex[index])
			uvs.append(_brush_uv(tex[index].x, tex[index].y) if attached_brush else tex[index])
			colors.append(Color.WHITE)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = flow_uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _ingest_real_pulls(events: Array, live: Dictionary, now: float) -> void:
	for value: Variant in events:
		if not value is Dictionary:continue
		var event: Dictionary = value
		if str(event.get("kind", "")) != "ink_h02_pull" or not _scope_matches(event):continue
		var zone_id := str(event.get("vortex_id", ""))
		if not live.has(zone_id):continue
		var vortex: Dictionary = live[zone_id]
		if int(event.get("cast_id", -1)) != int(vortex.cast_id):continue
		var a := _vector(event.get("from_position", null))
		var b := _vector(event.get("position", null))
		var center := _vector(event.get("center", null))
		var begin := float(event.get("sample_from", -1.0))
		var end := float(event.get("sample_to", -1.0))
		var actual := float(event.get("actual_distance", 0.0))
		var target := str(event.get("target_id", ""))
		if not a.is_finite() or not b.is_finite() or not center.is_finite() or target.is_empty():continue
		if not is_finite(begin) or not is_finite(end) or not is_finite(actual):continue
		if actual <= EPS or a.distance_to(b) <= EPS or absf(a.distance_to(b)-actual) > 0.0001:continue
		if center.distance_to(_vector(vortex.position)) > EPS or b.distance_to(center) >= a.distance_to(center):continue
		if begin < float(vortex.born_at)-EPS or end > float(vortex.expires_at)+EPS or end <= begin or end > now+EPS or now-end > PULL_RECENCY:continue
		var key := zone_id + ":" + target
		var previous: Dictionary = _pull_receipts.get(key, {})
		# Keep only newest actual segment. Duplicate or older events add no ink.
		if not previous.is_empty() and end <= float(previous.sample_to):continue
		_pull_receipts[key] = event.duplicate(true)

func _render_real_pulls(live: Dictionary, now: float) -> int:
	var mesh := _pull_node.mesh as ArrayMesh
	mesh.clear_surfaces()
	var count := 0
	# Stable insertion order; cosmetic limit cannot change source admission.
	for key: String in _pull_receipts.keys():
		var event: Dictionary = _pull_receipts[key]
		if not live.has(str(event.vortex_id)) or now-float(event.sample_to) > PULL_RECENCY:
			_pull_receipts.erase(key)
			continue
		if count >= MAX_PULL_TARGETS:continue
		var a := _ground(_vector(event.from_position))
		var b := _ground(_vector(event.position))
		# End exactly at real destination; never lengthen .06m into a fake .6m pull.
		var points: Array[Vector3] = [a, a.lerp(b,0.5), b]
		var width := minf(0.065, a.distance_to(b)*0.8)
		var widths: Array[float] = [width*0.15, width, width*0.10]
		var segment := _make_ribbon(points, widths, 0.047)
		if segment.get_surface_count() > 0:mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, segment.surface_get_arrays(0))
		count += 1
	_pull_material.set_shader_parameter("source_age", 0.0)
	return count

func _zone_triangle_count() -> int:
	var result := 0
	for record: Dictionary in _zones.values():result += int(record.triangles)
	return result

func get_diagnostics() -> Dictionary:
	return _diagnostics.duplicate(true)
