extends MeshInstance3D
## Flat gameplay-ground painting; exact source radius, no collision.
const Paint=preload("res://visual_rework_20261009/views/e3_realm_paint.gdshader")
var paint:ShaderMaterial
var radius=3.0
func setup(texture:Texture2D,source_radius:float,index:float)->void:
 radius=source_radius
 var plane=PlaneMesh.new();plane.size=Vector2(radius*2.,radius*2.);mesh=plane
 paint=ShaderMaterial.new();paint.shader=Paint;paint.set_shader_parameter("landscape_atlas",texture);paint.set_shader_parameter("cell",index)
 material_override=paint;cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func present(source_age:float,strength:float=1.0,fade:float=0.0,exchange_age:float=-1.0)->void:
 if paint==null:return
 paint.set_shader_parameter("age",maxf(source_age,0.0));paint.set_shader_parameter("opacity",.92*strength)
 paint.set_shader_parameter("dissolve",clampf(fade,0.,1.));paint.set_shader_parameter("exchange_progress",exchange_age)
func set_partner(point:Vector3,source_radius:float)->void:
 paint.set_shader_parameter("partner_center",point);paint.set_shader_parameter("partner_radius",source_radius)
