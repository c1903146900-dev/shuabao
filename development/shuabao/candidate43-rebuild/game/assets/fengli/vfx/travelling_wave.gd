extends Node3D
## Curved, closed pressure-blade volume. Position comes only from the live runtime projectile.
## Source width is X span; source travel is runtime-owned. Model scale affects height only.
var width_m:=1.8
var visual_height_scale:=1.25
var body:MeshInstance3D
var rib:MeshInstance3D
var material:ShaderMaterial
const SHADER:=preload("res://assets/fengli/vfx/wave_pressure.gdshader")
func configure(width:float,height_scale:float)->void:
 width_m=width;visual_height_scale=height_scale
 body=MeshInstance3D.new();body.mesh=_volume(width_m,.13,.24);body.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(body)
 material=ShaderMaterial.new();material.shader=SHADER;body.material_override=material
 rib=MeshInstance3D.new();rib.mesh=_volume(width_m*.93,.032,.055);rib.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(rib)
 var edge:=StandardMaterial3D.new();edge.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;edge.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;edge.albedo_color=Color(.64,.77,.85,.78);rib.material_override=edge
func sync_projectile(data:Dictionary)->void:
 position=data.position
 var direction:Vector3=data.get("direction",Vector3.FORWARD)
 rotation.y=atan2(-direction.x,-direction.z)
 var remaining:float=float(data.get("remaining",1.0));material.set_shader_parameter("edge_fade",clampf(remaining/.45,0.,1.))
func _volume(width:float,thickness:float,depth:float)->ArrayMesh:
 var points:=PackedVector3Array();var uv:=PackedVector2Array();var ids:=PackedInt32Array()
 const SEGMENTS:=24
 const SIDES:=8
 for i in range(SEGMENTS+1):
  var u:float=float(i)/SEGMENTS;var x:float=(u-.5)*width
  var curve:float=pow(abs(2.*u-1.),1.65)*.40
  var tip:float=pow(maxf(.001,sin(u*PI)),.65)
  for j in range(SIDES):
   var angle:float=TAU*float(j)/SIDES
   points.append(Vector3(x,(1.02+cos(angle)*thickness*tip)*visual_height_scale,curve+sin(angle)*depth*tip))
   uv.append(Vector2(u,float(j)/SIDES))
 for i in range(SEGMENTS):
  for j in range(SIDES):
   var a:=i*SIDES+j;var b:=i*SIDES+(j+1)%SIDES;var c:=(i+1)*SIDES+j;var d:=(i+1)*SIDES+(j+1)%SIDES
   ids.append_array(PackedInt32Array([a,c,b,b,c,d]))
 for j in range(1,SIDES-1):ids.append_array(PackedInt32Array([0,j+1,j,SEGMENTS*SIDES,SEGMENTS*SIDES+j,SEGMENTS*SIDES+j+1]))
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=ids
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
