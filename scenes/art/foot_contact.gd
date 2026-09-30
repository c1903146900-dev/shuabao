extends Node3D
## Optional art-only contact pass for a known flat floor. No gameplay state or damage writes.
var target: Node3D
var skeleton: Skeleton3D
var ankle_height := .17
var floor_y := .01
var patches: Array[MeshInstance3D] = []
var indices: Array[int] = []
func setup(model: Node3D, ankle: float=.17, radius: float=.18, ground_y: float=.01) -> void:
 target=model
 ankle_height=ankle
 floor_y=ground_y
 skeleton=model.find_child("Skeleton3D",true,false) as Skeleton3D
 if skeleton==null:return
 var shader := Shader.new()
 shader.code="shader_type spatial; render_mode unshaded, cull_disabled, depth_draw_never; uniform float opacity=0.3; void fragment(){float r=length((UV-vec2(0.5))*2.0); ALBEDO=vec3(0.025,0.032,0.036); ALPHA=opacity*(1.0-smoothstep(0.35,1.0,r));}"
 for bone in ["foot1","foot-1"]:
  var index:=skeleton.find_bone(bone)
  if index<0:continue
  indices.append(index)
  var patch:=MeshInstance3D.new()
  var plane:=PlaneMesh.new()
  plane.size=Vector2(radius*2,radius*3.0)
  patch.mesh=plane
  var material:=ShaderMaterial.new()
  material.shader=shader
  patch.material_override=material
  patch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(patch)
  patches.append(patch)
 _process(0)
func _process(_dt: float) -> void:
 if skeleton==null or not is_instance_valid(target):return
 for i in range(patches.size()):
  var pose:=skeleton.global_transform*skeleton.get_bone_global_pose(indices[i])
  var center:=pose.origin+pose.basis.y*.06
  patches[i].global_position=Vector3(center.x,floor_y+.006,center.z)
  var rise:=maxf(0.0,pose.origin.y-ankle_height)
  var alpha:=.65*(1.0-smoothstep(.015,.18,rise))
  patches[i].visible=target.is_visible_in_tree() and alpha>.001
  patches[i].material_override.set_shader_parameter("opacity",alpha)
