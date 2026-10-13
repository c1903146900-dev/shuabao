extends RefCounted
static func plane(size:Vector2,mode:int,pigment:Vector3)->MeshInstance3D:
 var n=MeshInstance3D.new();var m=PlaneMesh.new();m.size=size;n.mesh=m
 var sm=ShaderMaterial.new();sm.shader=load("res://visual_rework_20261009/views/e_paint.gdshader");sm.set_shader_parameter("mode",mode);sm.set_shader_parameter("pigment",pigment);n.material_override=sm
 n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return n
