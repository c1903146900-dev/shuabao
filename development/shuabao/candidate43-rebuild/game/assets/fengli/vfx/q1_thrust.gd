extends Node3D
## Authored closed pressure-blade volumes. Pure presentation, no collision or damage.
## Q1 is a directional thrust; this node never displaces the hero.
const SHADER := preload("res://assets/fengli/vfx/thrust_volume.gdshader")
const EROSION := preload("res://assets/fengli/vfx/thrust_erosion.png")
var age := 0.0
var life := .32
var layers: Array[ShaderMaterial] = []
var streaks: Array[MeshInstance3D] = []
var source_length := 3.5
var source_width := 1.25
# Art-only vertical alignment; X/Z source reach and width are never multiplied.
var visual_height_scale := 1.25

func configure(origin: Vector3, direction: Vector3, length_m: float, width_m: float, stacks: int = 0) -> void:
	position = origin
	rotation.y = atan2(-direction.x, -direction.z)
	source_length = length_m
	source_width = width_m
	for layer in range(3):
		var node := MeshInstance3D.new()
		node.name = "PressureBladeVolume%d" % layer
		node.mesh = _volume(length_m, width_m, layer)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("erosion_map", EROSION)
		mat.set_shader_parameter("core", 1.0 if layer == 0 else 0.0)
		mat.set_shader_parameter("strength", .75 + .10 * stacks if layer == 0 else .34)
		node.material_override = mat
		layers.append(mat)
		add_child(node)
	# Slender forged shards articulate the forward contact, not a fan or a ring.
	for i in range(7):
		var shard := MeshInstance3D.new()
		shard.mesh = _shard()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color("a7b6c9") if i % 3 != 0 else Color("5b1521")
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = .5
		shard.material_override = mat
		shard.position = Vector3(sin(i * 2.7) * width_m * .30, (1.0 + cos(i * 1.7) * .15) * visual_height_scale, -length_m * (.68 + .04 * i))
		shard.scale = Vector3(.028, .025, .23 + .035 * i)
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		streaks.append(shard)
		add_child(shard)

func advance(dt: float) -> void:
	age += dt
	var t := clampf((age - .06) / .26, 0.0, 1.0)
	for mat in layers: mat.set_shader_parameter("life", clampf(t, 0, 1))
	for i in streaks.size():
		var node := streaks[i]
		node.visible = age >= .1 and t < .90
		node.position.z -= dt * (2.8 + .2 * i)
		node.scale.x = maxf(.001, .028 * (1.0 - t))
		(node.material_override as StandardMaterial3D).albedo_color.a = maxf(0, 1.0 - t)
	if age >= life: queue_free()

func _volume(length_m: float, width_m: float, layer: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	const SIDES := 10
	const ROWS := 22
	for j in range(ROWS + 1):
		var u := float(j) / ROWS
		var profile := pow(maxf(.002, sin(PI * u)), .65)
		var twist := .18 * sin(u * TAU * 1.2 + layer * 2.3)
		for k in range(SIDES + 1):
			var angle := TAU * float(k) / SIDES
			var flank := (-1.0 if layer == 1 else 1.0) * width_m * .34 * sin(u * PI) if layer > 0 else 0.0
			var rx := width_m * (.055 if layer == 0 else .043) * profile
			var ry := (.045 if layer == 0 else .027) * profile
			vertices.append(Vector3(flank + cos(angle + twist) * rx, (1.08 + sin(angle) * ry + .06 * sin(u * TAU + layer)) * visual_height_scale, -.35 - u * (length_m - .35)))
			uv.append(Vector2(u, float(k) / SIDES))
	for j in range(ROWS):
		for k in range(SIDES):
			var a := j * (SIDES + 1) + k
			var b := a + SIDES + 1
			indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _shard() -> ArrayMesh:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0,0,-1), Vector3(-1,0,0), Vector3(0,1,0), Vector3(1,0,0), Vector3(0,-1,0), Vector3(0,0,1)])
	a[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,3,0,3,4,0,4,1,5,2,1,5,3,2,5,4,3,5,1,4])
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	return result
