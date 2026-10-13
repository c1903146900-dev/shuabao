class_name CuichengVFX
extends Node3D
## Presentation-only authored Q1. Call only from the authoritative windup/contact.
## at = hero ground origin; direction = horizontal attack direction.
## All animation, erosion and ballistics obey this node's process state.

const ROOT := "res://assets/xuanlei/vfx/cuicheng/"
const EARTH_SHADER := preload(ROOT + "earth.gdshader")
const ENERGY_SHADER := preload(ROOT + "energy.gdshader")
const STONE_SHADER := preload(ROOT + "stone.gdshader")
const DUST := [preload(ROOT + "dust_0.png"), preload(ROOT + "dust_1.png"), preload(ROOT + "dust_2.png")]
const PRESSURE := preload(ROOT + "pressure_sheet.png")
const CONTACT := preload(ROOT + "contact_spike.png")
const CONTACT_GROUND := preload(ROOT + "contact_ground.png")
const SCAR := preload(ROOT + "ground_scar.png")
const FAULTS := preload(ROOT + "ground_faults.png")
const SPARK := preload(ROOT + "spark.png")
const NOISE := preload(ROOT + "erosion.png")
const BASALT := preload(ROOT + "basalt_grain.png")
const MAX_LIVE := 80

## Shield-side local X, height, and negative local Z forward.
@export var contact_offset := Vector3(-1.0, 0.035, -0.12)
var peak_live := 0
var dropped_oldest := 0
var _live: Array[Dictionary] = []
var _quad: QuadMesh
var _ground: PlaneMesh
var _sheet: ArrayMesh
var _smear: ArrayMesh
var _rocks: Array[ArrayMesh] = []
var _windup_at := Vector3.ZERO
var _following_windup := false

func get_live_count() -> int:
	return _live.size()

func clear_transients() -> void:
	_following_windup=false
	for fx in _live:
		if is_instance_valid(fx.node): fx.node.free()
	_live.clear()

func _frame(direction: Vector3) -> Basis:
	var d := Vector3(direction.x, 0.0, direction.z)
	if d.length_squared() < 0.001: d = Vector3.FORWARD
	return Basis.looking_at(d.normalized(), Vector3.UP)

func _ensure_meshes() -> void:
	if _quad != null: return
	_quad = QuadMesh.new(); _quad.size = Vector2.ONE
	_ground = PlaneMesh.new(); _ground.size = Vector2.ONE
	_sheet = _pressure_mesh()
	_smear = _windup_mesh()
	for i in range(6): _rocks.append(_stone_mesh(i))

func _paint(texture: Texture2D, energy: bool, tint: Color = Color.WHITE, erosion_strength: float = 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ENERGY_SHADER if energy else EARTH_SHADER
	m.set_shader_parameter("art_texture", texture)
	m.set_shader_parameter("erosion_texture", NOISE)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("opacity", 1.0)
	m.set_shader_parameter("erosion", 0.0)
	m.set_shader_parameter("erosion_strength", erosion_strength)
	if texture == SCAR or texture == FAULTS: m.set_shader_parameter("directional_reveal", 1.0)
	return m

func _stone_paint() -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = STONE_SHADER
	m.set_shader_parameter("stone_texture", BASALT)
	return m

func _spawn(mesh: Mesh, material: ShaderMaterial, at: Vector3, frame: Basis, life: float, options: Dictionary = {}) -> void:
	while _live.size() >= MAX_LIVE:
		var old: Dictionary = _live.pop_front()
		if is_instance_valid(old.node): old.node.free()
		dropped_oldest += 1
	var node := MeshInstance3D.new(); node.mesh = mesh; node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 2.0
	add_child(node); node.global_transform = Transform3D(frame, at)
	var scale_from: Vector3 = options.get("scale_from", Vector3.ONE)
	var data: Dictionary = {"node": node, "material": material, "age": -float(options.get("delay", 0.0)), "life": life,
		"origin": at, "frame": frame, "scale_from": scale_from, "scale_to": options.get("scale_to", scale_from),
		"grow_time": life, "velocity": Vector3.ZERO, "gravity": 0.0, "spin": Vector3.ZERO,
		"fade_in": 0.016, "fade_start": 0.35, "erosion_start": 0.36, "erosion_end": 0.99,
		"billboard": false, "roll": 0.0, "stone": false, "ground_y": at.y, "peak_alpha": 1.0, "reveal_time": 0.0}
	data.merge(options, true); _live.append(data)
	if float(data.reveal_time) > 0.0: material.set_shader_parameter("reveal", 0.0)
	node.scale = scale_from
	node.visible = data.age >= 0.0
	peak_live = maxi(peak_live, _live.size())

func windup(at: Vector3, direction: Vector3, duration: float = 0.26) -> void:
	_windup_at=at
	_following_windup=true
	_ensure_meshes()
	var frame := _frame(direction)
	# One thick taper follows the actual raised-shield-to-ground trajectory.
	# It only appears in the final third of anticipation, never as a halo.
	var close := at + frame * Vector3(contact_offset.x, 0.02, contact_offset.z + 0.22)
	_spawn(_smear, _paint(PRESSURE, true, Color(0.88, 0.61, 0.26, 0.52)), close, frame, duration * 0.34,
		{"follows_windup":true,"delay": duration * 0.65, "fade_in": 0.012, "fade_start": 0.28, "erosion_start": 0.53,
		"scale_from": Vector3(0.88, 0.82, 0.88), "scale_to": Vector3(1.0, 1.0, 1.0), "grow_time": duration * 0.23})

func follow_windup(at: Vector3) -> void:
	if not _following_windup:return
	var delta: Vector3=at-_windup_at
	_windup_at=at
	for fx in _live:
		if fx.get("follows_windup",false):
			fx.origin+=delta
			if is_instance_valid(fx.node):fx.node.global_position+=delta
func impact(at: Vector3, direction: Vector3, radius: float = 4.2) -> void:
	follow_windup(at)
	_following_windup=false
	_ensure_meshes()
	var frame := _frame(direction)
	var origin := at + frame * contact_offset
	var size := clampf(radius / 4.2, 0.65, 1.50)
	# Earth footprint first: an irregular directional plate fracture, not a disc.
	var scar_at := origin + frame * Vector3(0.0, 0.012, -0.53 * size)
	_spawn(_ground, _paint(SCAR, false, Color(0.89, 0.94, 1.0, 0.91)), scar_at, frame, 1.02,
		{"scale_from": Vector3(4.10 * size, 1.0, 4.50 * size), "fade_in": 0.008, "reveal_time": 0.16, "fade_start": 0.52, "erosion_start": 0.54})
	_spawn(_ground, _paint(FAULTS, true, Color(1.0, 0.86, 0.66, 0.88)), scar_at + Vector3.UP * 0.012, frame, 0.57,
		{"scale_from": Vector3(4.10 * size, 1.0, 4.50 * size), "fade_in": 0.008, "reveal_time": 0.13, "fade_start": 0.23, "erosion_start": 0.42})
	# A split contact spike, deliberately far smaller than the earth volume.
	var flash_frame := frame.rotated(frame.z, -0.16)
	_spawn(_quad, _paint(CONTACT, true, Color(1.45, 1.29, 0.98, 1.0), 0.0), origin + frame * Vector3(-0.48, 0.40, 0.20), flash_frame, 0.082,
		{"scale_from": Vector3(2.05, 1.21, 1.0) * size, "scale_to": Vector3(2.38, 0.94, 1.0) * size,
		"fade_in": 0.004, "fade_start": 0.10, "erosion_start": 1.0, "billboard": true, "roll": -0.15})
	# Ground-facing splayed contact leaves a sharp footing even from overhead.
	_spawn(_quad, _paint(CONTACT_GROUND, true, Color(1.33, 1.15, 0.81, 0.97), 0.0), origin + frame * Vector3(-0.34, 0.055, 0.17), frame * Basis(Vector3.RIGHT, -PI * 0.5), 0.083,
		{"scale_from": Vector3(2.23, 1.68, 1.0) * size, "scale_to": Vector3(2.73, 2.13, 1.0) * size, "fade_in": 0.003, "fade_start": 0.10, "erosion_start": 1.0})
	# One raised, torn impact sail. Fast expansion throws the mass outward.
	_spawn(_sheet, _paint(PRESSURE, true, Color(1.21, 0.93, 0.56, 0.93)), origin, frame, 0.255,
		{"delay": 0.012, "scale_from": Vector3(0.25, 0.72, 0.25) * size, "scale_to": Vector3(1.08, 0.96, 1.0) * size,
		"grow_time": 0.108, "fade_in": 0.012, "fade_start": 0.45, "erosion_start": 0.39})
	_spawn_earth(origin, frame, size)
	_spawn_stones(origin, frame, size)
	_spawn_sparks(origin, frame, size)

func _spawn_earth(origin: Vector3, frame: Basis, size: float) -> void:
	# Unequal primary lobes; gaps preserve the shield and the pressure-sheet crest.
	var puffs := [
		{"p": Vector3(-0.73, 0.26, -0.74), "v": Vector3(-2.05, 0.18, -1.38), "s": Vector3(1.72, 1.23, 1.0), "g": Vector3(2.79, 1.83, 1.0), "l": 0.49, "d": 0.048, "r": -0.23, "t": 0},
		{"p": Vector3(1.18, 0.29, -1.26), "v": Vector3(2.20, 0.14, -1.83), "s": Vector3(1.37, 1.50, 1.0), "g": Vector3(1.97, 2.15, 1.0), "l": 0.56, "d": 0.073, "r": 0.15, "t": 1},
		{"p": Vector3(0.55, 0.19, -2.12), "v": Vector3(0.12, 0.12, -1.98), "s": Vector3(1.60, 0.71, 1.0), "g": Vector3(2.50, 1.02, 1.0), "l": 0.39, "d": 0.108, "r": -0.08, "t": 2},
		{"p": Vector3(-1.25, 0.19, -0.28), "v": Vector3(-2.20, 0.20, -0.39), "s": Vector3(0.94, 0.64, 1.0), "g": Vector3(1.68, 0.96, 1.0), "l": 0.37, "d": 0.092, "r": -0.33, "t": 2},
		{"p": Vector3(1.24, 0.23, -0.66), "v": Vector3(1.80, 0.26, -0.56), "s": Vector3(0.93, 0.77, 1.0), "g": Vector3(1.64, 1.14, 1.0), "l": 0.43, "d": 0.130, "r": 0.26, "t": 0}
	]
	for i in range(puffs.size()):
		var p: Dictionary = puffs[i]
		var mat := _paint(DUST[int(p.t)], false, Color(0.93, 0.92, 0.85, 0.73 if i < 3 else 0.44))
		mat.set_shader_parameter("erosion_offset", Vector2(i * 0.17, i * -0.24))
		_spawn(_quad, mat, origin + frame * (Vector3(p.p) * size), frame, float(p.l),
			{"delay": p.d, "velocity": frame * (Vector3(p.v) * size), "scale_from": Vector3(p.s) * Vector3(1.05, 0.93, 1.0) * size,
			"scale_to": Vector3(p.g) * Vector3(1.08, 0.95, 1.0) * size, "grow_time": float(p.l) * 0.73, "billboard": true, "roll": p.r,
			"fade_in": 0.052, "fade_start": 0.20, "erosion_start": 0.14, "erosion_end": 0.88})

func _spawn_stones(origin: Vector3, frame: Basis, size: float) -> void:
	# Five substantial thrown plates. Meshes have chipped silhouettes and dark sides.
	var stones := [
		[Vector3(-0.51, 0.16, -0.57), Vector3(-2.73, 4.7, -2.25), Vector3(0.77, 0.38, 0.92), Vector3(1.8, 1.1, 0.6), 0.90],
		[Vector3(0.57, 0.19, -1.08), Vector3(2.45, 5.25, -2.76), Vector3(0.98, 0.41, 0.70), Vector3(-2.1, 0.8, -0.9), 1.00],
		[Vector3(-0.02, 0.11, -1.42), Vector3(-0.55, 3.73, -4.28), Vector3(0.62, 0.29, 0.83), Vector3(2.4, -1.6, 0.9), 0.85],
		[Vector3(-1.07, 0.14, -0.15), Vector3(-3.26, 3.41, -1.16), Vector3(0.61, 0.29, 0.57), Vector3(1.0, 2.3, -1.4), 0.83],
		[Vector3(0.85, 0.14, -0.35), Vector3(3.45, 3.03, -1.07), Vector3(0.53, 0.24, 0.74), Vector3(-1.7, 1.2, 1.8), 0.89]
	]
	for i in range(stones.size()):
		var p: Array = stones[i]
		var rot := frame * Basis.from_euler(Vector3(0.17 + i * 0.11, 0.52 * i, -0.29 + 0.15 * i))
		_spawn(_rocks[i], _stone_paint(), origin + frame * (Vector3(p[0]) * size), rot, float(p[4]),
			{"delay": 0.025 + i * 0.006, "velocity": frame * (Vector3(p[1]) * size), "gravity": 20.0 * size,
			"scale_from": Vector3(p[2]) * size, "spin": p[3], "stone": true, "ground_y": origin.y + 0.10,
			"fade_in": 0.0, "fade_start": 0.74, "erosion_start": 1.0})
	# Three secondary chips support scale without becoming visual confetti.
	for i in range(3):
		var sign_x := -1.0 if i % 2 == 0 else 1.0
		var vel := Vector3(sign_x * (2.8 + i * 0.55), 3.15 + i * 0.4, -1.2 - i * 1.3)
		_spawn(_rocks[(i + 2) % 6], _stone_paint(), origin + frame * Vector3(sign_x * 0.41, 0.17, -0.63), frame, 0.69 + i * 0.07,
			{"delay": 0.055, "velocity": frame * vel * size, "gravity": 19.0 * size,
			"scale_from": Vector3(0.22 + i * 0.025, 0.15, 0.29) * size, "spin": Vector3(3.8, i + 1.5, 2.4),
			"stone": true, "ground_y": origin.y + 0.06, "fade_in": 0.0, "fade_start": 0.61, "erosion_start": 1.0})

func _spawn_sparks(origin: Vector3, frame: Basis, size: float) -> void:
	# Sparse embers only; these are not the shape of the impact.
	for i in range(5):
		var a := -0.91 + i * 0.43
		var vel := Vector3(sin(a) * (3.6 + (i % 2) * 0.7), 2.0 + (i % 3) * 0.64, -cos(a) * (3.3 + i * 0.19)) * size
		_spawn(_quad, _paint(SPARK, true, Color(1.0, 0.89, 0.56, 0.66), 0.0), origin + Vector3.UP * 0.22, frame, 0.24 + i * 0.028,
			{"delay": 0.019 + (i % 2) * 0.017, "velocity": frame * vel, "gravity": 11.0,
			"scale_from": Vector3(0.075, 0.45, 1.0) * size, "scale_to": Vector3(0.032, 0.16, 1.0) * size,
			"billboard": true, "roll": -a, "fade_in": 0.006, "fade_start": 0.16, "erosion_start": 1.0})

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	for i in range(_live.size() - 1, -1, -1):
		var fx: Dictionary = _live[i]
		fx.age = float(fx.age) + maxf(0.0, delta)
		var node: MeshInstance3D = fx.node
		if not is_instance_valid(node): _live.remove_at(i); continue
		var age: float = fx.age
		if age < 0.0: node.visible = false; continue
		if age >= float(fx.life): node.free(); _live.remove_at(i); continue
		node.visible = true
		var t := age / float(fx.life)
		var g := clampf(age / maxf(0.001, float(fx.grow_time)), 0.0, 1.0)
		g = 1.0 - pow(1.0 - g, 2.5)
		var draw_scale: Vector3 = Vector3(fx.scale_from).lerp(Vector3(fx.scale_to), g)
		var velocity: Vector3 = fx.velocity
		var position_now: Vector3 = Vector3(fx.origin) + velocity * age + Vector3.DOWN * 0.5 * float(fx.gravity) * age * age
		var rotation_age := age
		if bool(fx.stone) and position_now.y < float(fx.ground_y):
			var fall := maxf(0.0, float(fx.origin.y) - float(fx.ground_y))
			var gravity := maxf(0.001, float(fx.gravity))
			var landing := (velocity.y + sqrt(velocity.y * velocity.y + 2.0 * gravity * fall)) / gravity
			position_now = Vector3(fx.origin) + velocity * landing
			position_now.y = float(fx.ground_y)
			rotation_age = landing
		var draw_basis: Basis = fx.frame
		if bool(fx.billboard) and camera != null:
			draw_basis = camera.global_basis * Basis(Vector3.BACK, float(fx.roll))
		else:
			draw_basis = draw_basis * Basis.from_euler(Vector3(fx.spin) * rotation_age)
		node.global_transform = Transform3D(draw_basis.scaled_local(draw_scale), position_now)
		var fade_in := 1.0 if float(fx.fade_in) <= 0.0 else clampf(age / float(fx.fade_in), 0.0, 1.0)
		var fade_out := 1.0 - smoothstep(float(fx.fade_start), 1.0, t)
		var material: ShaderMaterial = fx.material
		material.set_shader_parameter("opacity", fade_in * fade_out * float(fx.peak_alpha))
		if not bool(fx.stone):
			if float(fx.reveal_time) > 0.0: material.set_shader_parameter("reveal", clampf(age / float(fx.reveal_time), 0.0, 1.0))
			var erosion := smoothstep(float(fx.erosion_start), maxf(float(fx.erosion_start) + 0.001, float(fx.erosion_end)), t)
			material.set_shader_parameter("erosion", erosion * 0.91)

func _array_mesh(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_COLOR] = colors; arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _pressure_mesh() -> ArrayMesh:
	var v := PackedVector3Array(); var n := PackedVector3Array(); var uv := PackedVector2Array(); var c := PackedColorArray(); var ix := PackedInt32Array()
	const ACROSS := 34
	const DEPTH := 7
	for i in range(ACROSS + 1):
		var u := float(i) / ACROSS
		var angle := lerpf(-1.04, 0.96, u)
		var ridge := 3.62 * (1.0 + 0.071 * sin(u * 23.0) + 0.035 * sin(u * 49.0 + 1.2))
		var span := sin(PI * u)
		for j in range(DEPTH + 1):
			var t := float(j) / DEPTH
			var radius := ridge * lerpf(0.32, 1.0, t)
			var height := 0.06 + sin(t * PI) * (0.68 + 0.23 * sin(u * 15.0)) * pow(span, 0.6) + t * 0.19
			v.append(Vector3(sin(angle) * radius + t * 0.74, height, -cos(angle) * radius))
			n.append(Vector3.UP); uv.append(Vector2(u, 1.0 - t)); c.append(Color(1, 1, 1, pow(span, 0.38)))
			if i < ACROSS and j < DEPTH:
				var a := i * (DEPTH + 1) + j
				ix.append_array(PackedInt32Array([a, a + DEPTH + 1, a + 1, a + 1, a + DEPTH + 1, a + DEPTH + 2]))
	return _array_mesh(v, n, uv, c, ix)

func _windup_mesh() -> ArrayMesh:
	var v := PackedVector3Array(); var n := PackedVector3Array(); var uv := PackedVector2Array(); var c := PackedColorArray(); var ix := PackedInt32Array()
	for i in range(19):
		var t := float(i) / 18.0
		var center := Vector3(-0.10 + t * 0.20, 2.44 * (1.0 - t) + 0.09, 0.46 * (1.0 - t) - sin(t * PI) * 0.52)
		var width := (0.045 + 0.37 * sin(t * PI)) * (0.50 + t * 0.50)
		v.append(center + Vector3(-width, 0, 0)); v.append(center + Vector3(width, 0, -0.07))
		n.append(Vector3.BACK); n.append(Vector3.BACK)
		uv.append(Vector2(t, 0.17)); uv.append(Vector2(t, 0.86))
		var alpha := sin(t * PI)
		c.append(Color(1.0, 0.88, 0.64, alpha)); c.append(Color(0.63, 0.39, 0.17, alpha * 0.25))
		if i < 18:
			var a := i * 2; ix.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	return _array_mesh(v, n, uv, c, ix)

func _stone_mesh(variant: int) -> ArrayMesh:
	var v := PackedVector3Array(); var n := PackedVector3Array(); var uv := PackedVector2Array(); var c := PackedColorArray(); var ix := PackedInt32Array()
	var outline := PackedVector2Array([Vector2(-0.56, -0.31), Vector2(-0.29, -0.51), Vector2(0.17, -0.46), Vector2(0.28, -0.36), Vector2(0.55, -0.29), Vector2(0.47, 0.29), Vector2(0.12, 0.51), Vector2(-0.38, 0.39), Vector2(-0.43, 0.11)])
	var top: Array[Vector3] = []; var rim: Array[Vector3] = []; var bottom: Array[Vector3] = []
	for i in range(outline.size()):
		var p := outline[i].rotated(variant * 0.27)
		var rough := 1.0 + 0.12 * sin(i * 2.47 + variant * 1.73)
		top.append(Vector3(p.x * 0.78 * rough, 0.47 + 0.08 * sin(i * 1.97 + variant), p.y * 0.78 * rough))
		rim.append(Vector3(p.x * rough, 0.12 + 0.04 * sin(i * 2.1), p.y * rough))
		bottom.append(Vector3(p.x * 0.79 * rough + 0.05, -0.47 + 0.05 * sin(i * 2.17), p.y * 0.81 * rough))
	var center := Vector3(0.015, 0.51, -0.035)
	for i in range(outline.size()):
		var j := (i + 1) % outline.size()
		var gray := 0.88 + 0.11 * sin(i * 2.63 + variant)
		_triangle(v, n, uv, c, ix, center, top[j], top[i], Color(0.40, 0.43, 0.42) * Color(gray, gray, gray))
		_triangle(v, n, uv, c, ix, top[i], top[j], rim[i], Color(0.31, 0.32, 0.30))
		_triangle(v, n, uv, c, ix, top[j], rim[j], rim[i], Color(0.36, 0.36, 0.32))
		_triangle(v, n, uv, c, ix, rim[i], rim[j], bottom[i], Color(0.18, 0.20, 0.20))
		_triangle(v, n, uv, c, ix, rim[j], bottom[j], bottom[i], Color(0.22, 0.24, 0.23))
		_triangle(v, n, uv, c, ix, Vector3(0.0, -0.46, 0.0), bottom[i], bottom[j], Color(0.13, 0.145, 0.15))
	return _array_mesh(v, n, uv, c, ix)

func _triangle(v: PackedVector3Array, n: PackedVector3Array, uv: PackedVector2Array, c: PackedColorArray, ix: PackedInt32Array, a: Vector3, b: Vector3, d: Vector3, color: Color) -> void:
	var start := v.size(); var normal := (b - a).cross(d - a).normalized()
	for point in [a, b, d]:
		v.append(point); n.append(normal); uv.append(Vector2(point.x + point.y * 0.32, point.z + point.y * 0.26) * 1.6); c.append(color)
	ix.append_array(PackedInt32Array([start, start + 1, start + 2]))
