extends Node3D
## Short original solid brush slugs at actual BASIC fronts. No simulated hits.
const Style=preload("res://tests/ink_style_specimen_20261004/style.gd")
var views: Dictionary={}
var material: StandardMaterial3D
func _ready() -> void:
	set_process(false)
	material=Style.matte(Color("233537"))
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
func present(snapshot: Dictionary) -> void:
	var seen: Dictionary={}
	for shot: Dictionary in snapshot.get("basics",[]):
		var id:=str(shot.get("wave_id",""))
		if id.is_empty():continue
		seen[id]=true
		if not views.has(id):
			var node:=MeshInstance3D.new()
			node.mesh=ArrayMesh.new();node.material_override=material
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node);views[id]=node
		var view: MeshInstance3D=views[id]
		var front: Vector3=shot.get("front_position",Vector3.ZERO)
		var direction: Vector3=shot.get("front_direction",Vector3.FORWARD)
		var side:=Vector3(direction.z,0,-direction.x)
		var length:=minf(.52,float(shot.get("front_distance",0.0)))
		var width:=float(shot.get("width",.55))*.40
		var center:=front+Vector3(0,.11,0)
		var a:=center
		var b:=center-direction*length+side*width
		var c:=center-direction*length*.78-side*width
		var vertices:=PackedVector3Array([a,b,c,a,c,b])
		var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices
		var mesh: ArrayMesh=view.mesh
		mesh.clear_surfaces();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	for id in views.keys():
		if not seen.has(id):views[id].queue_free();views.erase(id)
