extends Node3D
## Only visual outline of the router's source-backed, read-only preview.
var mesh_view: MeshInstance3D
var sample: Dictionary = {}
func _ready() -> void:
 set_process(false); set_physics_process(false)
 mesh_view = MeshInstance3D.new(); add_child(mesh_view)
 var material := StandardMaterial3D.new()
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.albedo_color = Color("96B9AE")
 material.no_depth_test = true
 mesh_view.material_override = material
 mesh_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func present(value: Dictionary) -> void:
 sample = value.duplicate(true)
 mesh_view.visible = bool(value.get("accepted",false))
 if not mesh_view.visible: return
 var raise: bool = str(value.get("phase","")) == "raise"
 var origin: Vector3 = value.position if raise else value.origin
 var axis: Vector3 = value.axis if raise else value.direction
 var side: Vector3 = Vector3(-axis.z,0,axis.x)
 var length: float = float(value.length)
 var width: float = float(value.width)
 var start: Vector3 = origin - axis*length*.5 if raise else origin
 var corners: Array[Vector3] = [start-side*width*.5,start+side*width*.5,start+axis*length+side*width*.5,start+axis*length-side*width*.5]
 var mesh := ImmediateMesh.new(); mesh.surface_begin(Mesh.PRIMITIVE_LINES)
 for index in range(4):
  mesh.surface_add_vertex(corners[index]+Vector3.UP*.055)
  mesh.surface_add_vertex(corners[(index+1)%4]+Vector3.UP*.055)
 mesh.surface_end(); mesh_view.mesh = mesh
