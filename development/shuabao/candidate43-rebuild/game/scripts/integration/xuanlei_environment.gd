extends Node3D
## One bounded test arena. All distances are explicit test values, not final balance.
const EXTENT := 18.0
var camera: Camera3D
var camera_target := Vector3.ZERO
var distance_guides: Array[Node3D] = []
var software_renderer := false

static func material(color: Color, roughness := 0.82, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metal
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

func mesh(shape: Mesh, mat: Material, pos: Vector3, node_name := "") -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.material_override = mat
	n.position = pos
	if not node_name.is_empty(): n.name = node_name
	add_child(n)
	return n

func block(size: Vector3, pos: Vector3, mat: Material, node_name := "") -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(shape,mat,pos,node_name)

func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10151b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("adc7d3")
	env.ambient_light_energy = 0.62
	# Static image-based reflection gives authored metals readable environmental light.
	# Background remains BG_COLOR; no extra dynamic light or per-frame sky update.
	var sky_material:=ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color(0.22,0.30,0.38)
	sky_material.sky_horizon_color=Color(0.42,0.45,0.48)
	sky_material.ground_horizon_color=Color(0.25,0.24,0.23)
	sky_material.ground_bottom_color=Color(0.16,0.14,0.12)
	var reflection_sky:=Sky.new()
	reflection_sky.radiance_size=Sky.RADIANCE_SIZE_128
	reflection_sky.process_mode=Sky.PROCESS_MODE_QUALITY
	reflection_sky.sky_material=sky_material
	env.sky=reflection_sky
	env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-18,0)
	sun.light_color = Color("ffdfb0")
	sun.light_energy = 1.5
	software_renderer = "llvmpipe" in RenderingServer.get_video_adapter_name().to_lower() or "softpipe" in RenderingServer.get_video_adapter_name().to_lower()
	sun.shadow_enabled = not software_renderer
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35,150,0)
	fill.light_color = Color("769fba")
	fill.light_energy = 0.7
	add_child(fill)
	var stone := material(Color("353e42"))
	var dark := material(Color("20292e"))
	var bronze := material(Color("806843"),0.65,0.5)
	var edge := material(Color("ac9569"),0.7,0.3)
	block(Vector3(38,0.5,38),Vector3(0,-0.32,0),dark,"ArenaFoundation")
	var tile_mesh:=BoxMesh.new()
	tile_mesh.size=Vector3(3.99,0.1,3.99)
	var paving:=MultiMesh.new()
	paving.transform_format=MultiMesh.TRANSFORM_3D
	paving.use_colors=true
	paving.mesh=tile_mesh
	paving.instance_count=81
	var index:=0
	for x in range(-4,5):
		for z in range(-4,5):
			paving.set_instance_transform(index,Transform3D(Basis.IDENTITY,Vector3(x*4,-0.08,z*4)))
			paving.set_instance_color(index,Color("303b40") if (x+z)%2==0 else Color("2e393e"))
			index+=1
	var tile_view:=MultiMeshInstance3D.new()
	tile_view.name="BatchedPaving"
	tile_view.multimesh=paving
	var tile_material:=material(Color.WHITE)
	tile_material.vertex_color_use_as_albedo=true
	tile_view.material_override=tile_material
	add_child(tile_view)
	for side in [-1,1]:
		block(Vector3(0.65,0.9,36.6),Vector3(side*18.35,0.35,0),stone,"SideWall_%d" % side)
		block(Vector3(36.6,0.9,0.65),Vector3(0,0.35,side*18.35),stone,"EndWall_%d" % side)
		block(Vector3(0.72,0.12,36.6),Vector3(side*18.35,0.85,0),bronze)
		block(Vector3(36.6,0.12,0.72),Vector3(0,0.85,side*18.35),bronze)
		for p in range(-16,17,4):
			block(Vector3(0.9,1.1,0.9),Vector3(side*18.35,0.55,p),stone)
			block(Vector3(0.9,1.1,0.9),Vector3(p,0.55,side*18.35),stone)
	for radius in [5.0,10.0,15.0]:
		var ring := TorusMesh.new()
		ring.inner_radius = radius-0.025
		ring.outer_radius = radius+0.025
		ring.rings = 96
		ring.ring_segments = 4
		var guide:=mesh(ring,material(Color("465559")),Vector3(0,0.005,0))
		guide.visible=false
		distance_guides.append(guide)
	for p in [Vector3(-16,0,-16),Vector3(16,0,-16),Vector3(-16,0,16),Vector3(16,0,16)]:
		block(Vector3(1.2,0.35,1.2),p+Vector3(0,0.1,0),stone)
		block(Vector3(0.75,1.8,0.75),p+Vector3(0,1,0),bronze)
		var fire := SphereMesh.new()
		fire.radius = 0.28
		fire.height = 0.6
		mesh(fire,material(Color("e69c45"),0.45,0,2),p+Vector3(0,2.1,0))
	# Low-contrast engraved training dais, not debug distance marks.
	var dais:=CylinderMesh.new()
	dais.top_radius=4.7;dais.bottom_radius=4.7;dais.height=0.015
	dais.radial_segments=48
	mesh(dais,material(Color("29353a")),Vector3(0,0.006,0),"TrainingDais")
	var inset:=TorusMesh.new()
	inset.inner_radius=4.42;inset.outer_radius=4.5;inset.rings=48;inset.ring_segments=4
	mesh(inset,material(Color("455255")),Vector3(0,0.022,0),"DaisInlay")
	var inlay:=material(Color("414a49"),0.9)
	for side in [-1,1]:
		block(Vector3(1.2,0.02,0.09),Vector3(side*2.4,0.02,0),inlay)
		block(Vector3(0.09,0.02,1.2),Vector3(0,0.02,side*2.4),inlay)
	camera = Camera3D.new()
	camera.name = "CombatCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 19.0
	add_child(camera)
	camera.current = true
	follow(Vector3.ZERO,1.0)
	_batch_static_boxes()

func follow(target: Vector3, dt: float) -> void:
	camera_target = camera_target.lerp(Vector3(clampf(target.x,-8,8),0,clampf(target.z,-7,7)),minf(1,dt*6))
	camera.position = camera_target+Vector3(0,27,20)
	camera.look_at(camera_target)

func set_distance_guides(enabled: bool) -> void:
	for guide in distance_guides: guide.visible=enabled

func _batch_static_boxes() -> void:
	# Only immutable arena boxes; material/size grouping preserves identical geometry.
	var groups := {}
	for child in get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var key:=str(child.mesh.size)+"/"+str(child.material_override.get_instance_id())
			if not groups.has(key): groups[key]=[]
			groups[key].append(child)
	for group in groups.values():
		if group.size()<2: continue
		var batched:=MultiMesh.new()
		batched.transform_format=MultiMesh.TRANSFORM_3D
		batched.mesh=group[0].mesh
		batched.instance_count=group.size()
		for i in group.size(): batched.set_instance_transform(i,group[i].transform)
		var view:=MultiMeshInstance3D.new()
		view.multimesh=batched
		view.material_override=group[0].material_override
		add_child(view)
		for original in group: original.queue_free()
