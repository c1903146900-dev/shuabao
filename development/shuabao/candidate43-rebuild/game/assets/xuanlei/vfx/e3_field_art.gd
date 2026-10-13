class_name E3FieldArt
extends RefCounted
## Geometry/material resources only. Ownership, range and shield lifetime stay authoritative.
const JADE_SHADER:=preload("res://assets/xuanlei/vfx/e3_jade.gdshader")
const GRAIN:=preload("res://assets/xuanlei/vfx/cuicheng/basalt_grain.png")
const FRACTURE:=preload("res://assets/xuanlei/vfx/cuicheng/erosion.png")

func material(shield: bool = false, ground: bool = false) -> ShaderMaterial:
	var result:=ShaderMaterial.new();result.shader=JADE_SHADER
	result.set_shader_parameter("stone_texture",GRAIN)
	result.set_shader_parameter("fracture_texture",FRACTURE)
	result.set_shader_parameter("tint",Color(0.40,0.69,0.56,0.82) if shield else Color(0.39,0.61,0.48,0.79) if ground else Color(0.40,0.60,0.48,0.96))
	result.set_shader_parameter("edge_light",0.96 if shield else 0.63 if ground else 0.67)
	return result

func _mesh(vertices: PackedVector3Array,normals: PackedVector3Array,uvs: PackedVector2Array,colors: PackedColorArray,indices: PackedInt32Array)->ArrayMesh:
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

func _triangle(v:PackedVector3Array,n:PackedVector3Array,uv:PackedVector2Array,c:PackedColorArray,ix:PackedInt32Array,a:Vector3,b:Vector3,d:Vector3,color:Color)->void:
	var start:=v.size();var normal:Vector3=(b-a).cross(d-a).normalized()
	for p in [a,b,d]:
		v.append(p);n.append(normal);uv.append(Vector2(p.x+p.y*0.36,p.z+p.y*0.29)*2.8);c.append(color)
	ix.append_array(PackedInt32Array([start,start+1,start+2]))

func fractured_plate(width:float,length:float,height:float,variant:int=0)->ArrayMesh:
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uvs:=PackedVector2Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
	# Uneven bevelled slabs. Missing corners and an offset ridge keep the anchors
	# architectural and weighty without repeating tiny gateway silhouettes.
	var outline:=PackedVector2Array([Vector2(-0.48,-0.40),Vector2(-0.17,-0.50),Vector2(0.14,-0.45),Vector2(0.24,-0.36),Vector2(0.48,-0.32),Vector2(0.46,0.18),Vector2(0.25,0.43),Vector2(-0.06,0.50),Vector2(-0.46,0.35),Vector2(-0.40,0.11)])
	var top:Array[Vector3]=[];var rim:Array[Vector3]=[];var bottom:Array[Vector3]=[]
	for i in range(outline.size()):
		var p:=outline[i];p.x+=sin(i*2.13+variant)*0.018
		top.append(Vector3(p.x*width*0.77,height*(0.90+0.10*sin(i*1.31+variant)),p.y*length*0.79))
		rim.append(Vector3(p.x*width,height*0.56,p.y*length))
		bottom.append(Vector3(p.x*width*0.93,0.0,p.y*length*0.94))
	var center:=Vector3(width*0.025,height*0.96,-length*0.025)
	for i in range(outline.size()):
		var j:=(i+1)%outline.size()
		_triangle(vertices,normals,uvs,colors,indices,center,top[j],top[i],Color(0.92,0,0,1))
		_triangle(vertices,normals,uvs,colors,indices,top[i],top[j],rim[i],Color(0.78,0.84,0,1))
		_triangle(vertices,normals,uvs,colors,indices,top[j],rim[j],rim[i],Color(0.76,0.70,0,1))
		_triangle(vertices,normals,uvs,colors,indices,rim[i],rim[j],bottom[i],Color(0.54,0.08,0,1))
		_triangle(vertices,normals,uvs,colors,indices,rim[j],bottom[j],bottom[i],Color(0.50,0,0,1))
	return _mesh(vertices,normals,uvs,colors,indices)

func etched_boundary(radius:float)->ArrayMesh:
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uvs:=PackedVector2Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
	# Only eight short, interrupted ground seams. There is no filled disc,
	# pressure fan, tall perimeter wall or uninterrupted luminous ring.
	for marker in range(8):
		var center_angle:=marker*TAU/8+PI/8
		for j in range(8):
			if j==3 or j==6:continue
			var a:=center_angle+(j-3.5)*0.027
			var b:=center_angle+(j-2.60)*0.027
			var outer_a:=Vector3(sin(a),0,-cos(a))*radius
			var outer_b:=Vector3(sin(b),0,-cos(b))*radius
			var inner_a:=outer_a.normalized()*(radius-0.066-0.025*sin(j*2.1))
			var inner_b:=outer_b.normalized()*(radius-0.066-0.025*sin((j+1)*2.1))
			_triangle(vertices,normals,uvs,colors,indices,inner_a,outer_b,outer_a,Color(0.74,0.70,0,0.79))
			_triangle(vertices,normals,uvs,colors,indices,inner_a,inner_b,outer_b,Color(0.68,0.48,0,0.79))
	return _mesh(vertices,normals,uvs,colors,indices)

func shield_inlay()->ArrayMesh:
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uvs:=PackedVector2Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
	# Three split etched strokes inside each shield-side stone slat. These give a
	# readable real-shield cue without painting the hero white or closing a bubble.
	for side in [-1.0,1.0]:
		for part in range(3):
			var x:float=side*(0.08+part*0.015);var z:float=-0.30+part*0.23
			var a:=Vector3(x,0.073,z);var b:=Vector3(x+0.018,0.073,z+0.16)
			var c:=Vector3(x-0.013,0.073,z+0.16)
			_triangle(vertices,normals,uvs,colors,indices,a,c,b,Color(1,1,0,0.89))
	return _mesh(vertices,normals,uvs,colors,indices)
