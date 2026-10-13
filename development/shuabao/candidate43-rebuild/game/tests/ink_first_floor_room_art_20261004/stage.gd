extends Node3D
## Independent representative room; same camera, new explicit physical layout.
## Meshes/paint/soft shadows are authored offline. No runtime geometry noise.
const Style = preload("res://tests/ink_style_specimen_20261004/style.gd")
const Layout = preload("res://tests/ink_first_floor_room_art_20261004/room_layout.gd")
const GEOMETRY_PATH := "res://tests/ink_first_floor_room_art_20261004/room_geometry.json"
const LIGHTING_PATH := "res://tests/ink_first_floor_room_art_20261004/lighting_contract.json"
const CAMERA_SIZE := 18.0
const CAMERA_ELEVATION_DEG := 40.0
const CAMERA_GROUND_DISTANCE := 24.0
var camera: Camera3D
var target := Vector3.ZERO
var software_renderer := false
var shadow_enabled := false
var shadow_mode := "static"
var room_mesh_stats: Dictionary = {}
var lighting_contract: Dictionary = {}
var sun: DirectionalLight3D
var static_shadow_layer: Node3D
var hero_grounding: MeshInstance3D
var enemy_grounding: MeshInstance3D
var contact_mesh: ArrayMesh
var contact_material: StandardMaterial3D
var floor_winding_failures := 0
var floor_triangle_count := 0

func _ready() -> void:
	lighting_contract = JSON.parse_string(FileAccess.get_file_as_string(LIGHTING_PATH))
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(lighting_contract.background_color)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(lighting_contract.ambient_color)
	env.ambient_light_energy = float(lighting_contract.ambient_energy)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.fog_enabled = false
	environment.environment = env
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.name = "SharedWarmKey"
	sun.rotation_degrees = Vector3(-52,-25,0)
	sun.light_color = Color(lighting_contract.key_color)
	sun.light_energy = float(lighting_contract.key_energy)
	sun.light_angular_distance = 12.0
	add_child(sun)
	software_renderer = "llvmpipe" in RenderingServer.get_video_adapter_name().to_lower() or "softpipe" in RenderingServer.get_video_adapter_name().to_lower()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY_PATH))
	room_mesh_stats = data.stats.duplicate(true)
	floor_triangle_count = int(room_mesh_stats.floor_triangles)
	var opaque := MeshInstance3D.new()
	opaque.name = "PaintedForecourtOpaque"
	opaque.mesh = _mesh(data.opaque)
	opaque.material_override = _paint_material(false)
	add_child(opaque)
	static_shadow_layer = Node3D.new()
	static_shadow_layer.name = "StaticSoftShadowLayer"
	add_child(static_shadow_layer)
	var ground_cast := MeshInstance3D.new()
	ground_cast.name = "BakedVolumeCastAndContact"
	ground_cast.mesh = _mesh(data.static_soft_shadow)
	ground_cast.material_override = _paint_material(true)
	ground_cast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	static_shadow_layer.add_child(ground_cast)
	contact_mesh = _mesh(data.actor_contact)
	contact_material = _paint_material(true)
	hero_grounding = _ground_shadow(Vector2(1.12,.80))
	enemy_grounding = _ground_shadow(Vector2(.94,.74))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--room-shadow="):
			shadow_mode = argument.trim_prefix("--room-shadow=")
	set_shadow_mode(shadow_mode)
	camera = Camera3D.new()
	camera.name = "Forecourt_18m_40degCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	camera.near = .1
	camera.far = 70.0
	add_child(camera)
	camera.current = true
	follow(Vector3.ZERO,1.0)

func _mesh(data: Dictionary) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for point: Array in data.vertices:
		vertices.append(Vector3(float(point[0]),float(point[1]),float(point[2])))
	for normal_value: Array in data.normals:
		normals.append(Vector3(float(normal_value[0]),float(normal_value[1]),float(normal_value[2])))
	for pigment: Array in data.colors:
		colors.append(Color(float(pigment[0]),float(pigment[1]),float(pigment[2]),float(pigment[3])))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _paint_material(alpha: bool) -> StandardMaterial3D:
	var material := Style.matte(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	if alpha:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.render_priority = -1
	return material

func _ground_shadow(size: Vector2) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = contact_mesh
	view.material_override = contact_material
	view.scale = Vector3(size.x,1.0,size.y)
	view.position.y = .013
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	static_shadow_layer.add_child(view)
	return view

func set_shadow_mode(mode: String) -> void:
	assert(mode in ["none","static","dynamic","both"],"Unknown forecourt shadow mode")
	shadow_mode = mode
	# This exact same layer is enabled/disabled; no mesh/color/light substitutions.
	static_shadow_layer.visible = mode in ["static","both"]
	shadow_enabled = mode in ["dynamic","both"]
	sun.shadow_enabled = shadow_enabled

func follow(at: Vector3, delta: float) -> void:
	# Exact old camera constants, elevation, smoothing and clamp. No zoom workaround.
	target = target.lerp(Vector3(clampf(at.x,-8,8),0,clampf(at.z,-7,7)),minf(1.0,delta*6.0))
	camera.position = target + Vector3(0,CAMERA_GROUND_DISTANCE*tan(deg_to_rad(CAMERA_ELEVATION_DEG)),CAMERA_GROUND_DISTANCE)
	camera.look_at(target)

func ground_point(mouse: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	if absf(direction.y)<.00001:return Vector3.INF
	var distance := -origin.y/direction.y
	return origin+direction*distance if distance>=0 else Vector3.INF

func present_grounding(hero: Dictionary, enemies: Array) -> void:
	hero_grounding.position = Vector3(hero.get("position",Vector3.ZERO))+Vector3(0,.013,0)
	if not enemies.is_empty():enemy_grounding.position = Vector3(enemies[0].position)+Vector3(0,.013,0)
	enemy_grounding.visible = not enemies.is_empty()

func shadow_review_probes() -> Array:
	var result: Array = []
	for row: Array in [["west_visible_shadow",Vector3(-7.5,.009,0)],["west_soft_penumbra",Vector3(-7.5,.009,-4)],["quiet_floor_control",Vector3(-6.5,.009,0)]]:
		result.append({"id":row[0],"world":row[1],"logical_screen":camera.unproject_position(row[1]),"pixel_verified":false})
	return result

func camera_contract() -> Dictionary:
	return {"revision":"forecourt01_independent_layout_source_candidate","size":camera.size,"elevation_degrees":rad_to_deg(atan2(camera.position.y-target.y,Vector2(camera.position.x-target.x,camera.position.z-target.z).length())),"camera_position":camera.global_position,"look_target":target,"ground_distance":CAMERA_GROUND_DISTANCE,"room_layout_sha256":FileAccess.get_sha256(Layout.PATH),"room_geometry_sha256":FileAccess.get_sha256(GEOMETRY_PATH),"lighting_sha256":FileAccess.get_sha256(LIGHTING_PATH),"shared_lighting_contract":lighting_contract.duplicate(true),"static_room_mesh":room_mesh_stats.duplicate(true),"shadow_mode":shadow_mode,"shadow_review_probes":shadow_review_probes(),"static_shadow_layer_visible":static_shadow_layer.visible,"dynamic_shadow_setting":sun.shadow_enabled,"real_dynamic_shadows":shadow_enabled,"dynamic_shadow_pixels_verified":false,"static_shadow_pixels_verified":false,"software_renderer":software_renderer,"floor_triangles":floor_triangle_count,"floor_winding_failures":floor_winding_failures,"baked_contact_grounding":static_shadow_layer.visible,"art_review_pending":true,"source_footprints_unchanged":false,"old_diagnostic_room_unchanged":true,"scope":"single representative room candidate, not full first floor; real_dynamic_shadows means node enabled, never verified pixel softness"}
