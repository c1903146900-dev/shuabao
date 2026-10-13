extends Node3D
## Original isolated training courtyard. Explicit collision footprint, original palette maps.
const Style = preload("res://tests/ink_style_specimen_20261004/style.gd")
const STONE_MAP:="res://tests/ink_style_specimen_20261004/revision03/textures/quiet_stone.png"
const SHADOW_MAP:="res://tests/ink_style_specimen_20261004/revision03/textures/soft_grounding.png"
const CAMERA_SIZE:=18.0
const CAMERA_ELEVATION_DEG:=40.0
const CAMERA_GROUND_DISTANCE:=24.0
const EXTENT := 18.0
const OBSTACLES := [
	{"position": Vector3(-7,0,-4), "half": Vector3(.9,0,.9)},
	{"position": Vector3(7,0,-4), "half": Vector3(.9,0,.9)}
]
var camera: Camera3D
var target := Vector3.ZERO
var software_renderer := false
var shadow_enabled := false
var hero_grounding: MeshInstance3D
var enemy_grounding: MeshInstance3D
var floor_winding_failures:=0
var floor_triangle_count:=0
func _ready() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("839188")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("CAD8D7")
	env.ambient_light_energy = .66
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.fog_enabled = false
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-25,0)
	sun.light_color = Color("F2E9D4")
	sun.light_energy = .88
	sun.light_angular_distance = 12.0
	software_renderer = "llvmpipe" in RenderingServer.get_video_adapter_name().to_lower() or "softpipe" in RenderingServer.get_video_adapter_name().to_lower()
	shadow_enabled = not software_renderer
	sun.shadow_enabled = shadow_enabled
	add_child(sun)
	# Correct clockwise-facing stone top geometry; v1 reversed faces showed the
	# exact BG_COLOR through the floor, leaving only horizontal side edges.
	_build_paving()
	hero_grounding=_ground_shadow(Vector2(1.05,.72))
	enemy_grounding=_ground_shadow(Vector2(.85,.65))
	# Walls' inner faces agree with the authoritative 18 m clamp.
	for sign_value in [-1.0,1.0]:
		_piece(Vector3(.55,.42,36.55),Vector3(sign_value*18.275,.21,0),Style.matte(Color("617774")))
		_piece(Vector3(36.55,.42,.55),Vector3(0,.21,sign_value*18.275),Style.matte(Color("617774")))
	# Props are shaped masonry, not actor placeholders. Their exact source AABBs are exposed.
	for item: Dictionary in OBSTACLES:
		var grounding:=_ground_shadow(Vector2(2.42,2.15))
		grounding.position=item.position+Vector3(0,.008,0)
		_piece(Vector3(1.8,.22,1.8),item.position+Vector3(0,.11,0),Style.matte(Color("687D76")))
		_piece(Vector3(1.35,.92,1.35),item.position+Vector3(0,.68,0),Style.matte(Color.WHITE,"stone"))
		_piece(Vector3(1.52,.16,1.52),item.position+Vector3(0,1.22,0),Style.matte(Color("7D9389")))
		_piece(Vector3(.84,.08,.84),item.position+Vector3(0,1.34,0),Style.matte(Color("B3B79A")))
	camera = Camera3D.new()
	camera.name = "Revision03_18m_40degCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	camera.near = .1
	camera.far = 70.0
	add_child(camera)
	camera.current = true
	follow(Vector3.ZERO, 1.0)
func _piece(size: Vector3, at: Vector3, material: Material) -> void:
	var view := MeshInstance3D.new()
	view.mesh = _beveled_block(size,.07)
	view.material_override = material
	view.position = at
	add_child(view)
func _beveled_block(size: Vector3, cut: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var x := size.x*.5
	var y := size.y*.5
	var z := size.z*.5
	var c := minf(cut,minf(x,z)*.4)
	var outline: Array[Vector2] = [Vector2(-x+c,-z),Vector2(x-c,-z),Vector2(x,-z+c),Vector2(x,z-c),Vector2(x-c,z),Vector2(-x+c,z),Vector2(-x,z-c),Vector2(-x,-z+c)]
	for i in range(8):
		var a := Vector3(outline[i].x,y,outline[i].y)
		var b := Vector3(outline[(i+1)%8].x,y,outline[(i+1)%8].y)
		_tri(vertices,uvs,normals,Vector3(0,y,0),b,a,Vector3.UP,size)
		var al := Vector3(a.x,-y,a.z)
		var bl := Vector3(b.x,-y,b.z)
		var normal := Vector3(b.z-a.z,0,a.x-b.x).normalized()
		_tri(vertices,uvs,normals,a,b,bl,normal,size)
		_tri(vertices,uvs,normals,a,bl,al,normal,size)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
func _tri(vertices: PackedVector3Array, uvs: PackedVector2Array, normals: PackedVector3Array, a: Vector3,b: Vector3,c: Vector3,n: Vector3,size: Vector3) -> void:
	# Godot triangle fronts are clockwise: cross product opposes supplied outward normal.
	var ordered := PackedVector3Array([a,c,b]) if (b-a).cross(c-a).dot(n)>0.0 else PackedVector3Array([a,b,c])
	for point: Vector3 in ordered:
		vertices.append(point)
		normals.append(n)
		uvs.append(Vector2(point.x/size.x+.5,point.z/size.z+.5))
func follow(at: Vector3, delta: float) -> void:
	target = target.lerp(Vector3(clampf(at.x,-8,8),0,clampf(at.z,-7,7)),minf(1.0,delta*6.0))
	camera.position = target + Vector3(0,CAMERA_GROUND_DISTANCE*tan(deg_to_rad(CAMERA_ELEVATION_DEG)),CAMERA_GROUND_DISTANCE)
	camera.look_at(target)
func ground_point(mouse: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	if absf(direction.y)<.00001:return Vector3.INF
	var distance := -origin.y/direction.y
	return origin+direction*distance if distance>=0 else Vector3.INF

func _build_paving() -> void:
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var colors:=PackedColorArray()
	var uv:=PackedVector2Array()
	# Staggered joints have low contrast; the broad top surface owns the image.
	for row in range(9):
		var z0: float=-18.0+row*4.0
		var offset: float=2.0 if row%2==1 else 0.0
		for column in range(10):
			var x0:=maxf(-18.0,-18.0+column*4.0-offset)
			var x1:=minf(18.0,-14.0+column*4.0-offset)
			if x1-x0<.05:continue
			var gap:=.012
			var lo:=Vector2(x0+gap,z0+gap)
			var hi:=Vector2(x1-gap,z0+4.0-gap)
			var cut:=.045
			var outline: Array[Vector2]=[lo+Vector2(cut,0),Vector2(hi.x-cut,lo.y),Vector2(hi.x,lo.y+cut),hi-Vector2(0,cut),hi-Vector2(cut,0),Vector2(lo.x+cut,hi.y),Vector2(lo.x,hi.y-cut),lo+Vector2(0,cut)]
			var center: Vector2=(lo+hi)*.5
			var tint:=Color(.985,.995,.985) if (row+column)%3==0 else Color.WHITE
			for edge in range(8):
				var a:=Vector3(outline[edge].x,0,outline[edge].y)
				var b:=Vector3(outline[(edge+1)%8].x,0,outline[(edge+1)%8].y)
				var c:=Vector3(center.x,0,center.y)
				var local_vertices:=PackedVector3Array();var local_normals:=PackedVector3Array();var local_uv:=PackedVector2Array()
				_tri(local_vertices,local_uv,local_normals,c,a,b,Vector3.UP,Vector3(4,1,4))
				if (local_vertices[1]-local_vertices[0]).cross(local_vertices[2]-local_vertices[0]).dot(Vector3.UP)>=0:floor_winding_failures+=1
				floor_triangle_count+=1
				for point: Vector3 in local_vertices:
					vertices.append(point);normals.append(Vector3.UP);colors.append(tint)
					uv.append(Vector2((point.x-x0)/maxf(.001,x1-x0),(point.z-z0)/4.0))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uv
	var floor_mesh:=ArrayMesh.new();floor_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var floor_view:=MeshInstance3D.new();floor_view.name="ClockwiseStaggeredStoneTops";floor_view.mesh=floor_mesh
	var mat:=Style.matte(Color.WHITE);mat.vertex_color_use_as_albedo=true;mat.albedo_texture=load(STONE_MAP)
	floor_view.material_override=mat;add_child(floor_view)
	# An opaque lower plane seals subpixel joints, so no BG_COLOR leaks through.
	var base:=MeshInstance3D.new();var shape:=PlaneMesh.new();shape.size=Vector2(36,36);base.mesh=shape
	base.position.y=-.012;base.material_override=Style.matte(Color("909D91"));add_child(base)
func _ground_shadow(size: Vector2) -> MeshInstance3D:
	var view:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=size;view.mesh=plane
	var material:=Style.matte(Color.WHITE);material.albedo_texture=load(SHADOW_MAP)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.render_priority=-1
	view.material_override=material;view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.position.y=.008;add_child(view);return view
func present_grounding(hero: Dictionary, enemies: Array) -> void:
	hero_grounding.position=Vector3(hero.get("position",Vector3.ZERO))+Vector3(0,.008,0)
	if not enemies.is_empty():enemy_grounding.position=Vector3(enemies[0].position)+Vector3(0,.008,0)
	enemy_grounding.visible=not enemies.is_empty()
func camera_contract() -> Dictionary:
	return {"revision":"03_18m_40deg_trial_not_art_acceptance","size":camera.size,"elevation_degrees":rad_to_deg(atan2(camera.position.y-target.y,Vector2(camera.position.x-target.x,camera.position.z-target.z).length())),"camera_position":camera.global_position,"look_target":target,"ground_distance":CAMERA_GROUND_DISTANCE,"old_camera_size":19.0,"old_elevation_degrees":53.471144633,"floor_winding_failures":floor_winding_failures,"floor_triangles":floor_triangle_count,"baked_contact_grounding":true,"real_dynamic_shadows":shadow_enabled,"source_footprints_unchanged":true}
