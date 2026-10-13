extends Node3D
## A single broken transverse material ridge, exact source width, no false nail tips.
## Each real bone body remains separate and count-honest in projectile_art.gd.
var width_m:=2.8
var body:MeshInstance3D
func configure(width:float,visual_scale:float)->void:
 width_m=width
 var v:=PackedVector3Array();var uv:=PackedVector2Array();var colors:=PackedColorArray();var ix:=PackedInt32Array()
 for i in range(29):
  var u:float=float(i)/28.0;var profile:float=pow(maxf(.001,sin(u*PI)),.55)
  var x:float=(u-.5)*width
  for j in range(3):
   var depth:float=[.015,.13,.37][j]*profile
   v.append(Vector3(x,(1.05+(.035 if j==1 else 0.0))*visual_scale,depth+.05*sin(u*PI)))
   uv.append(Vector2(u,float(j)*.5));colors.append(Color(1,1,1,[.26,.32,.09][j]))
  if i>0:
   for j in range(2):
    var a:=(i-1)*3+j;var b:=a+1;var c:=i*3+j;var d:=c+1
    ix.append_array(PackedInt32Array([a,c,b,b,c,d]))
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=v;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=ix
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material:=ShaderMaterial.new();material.shader=preload("res://assets/fengli/vfx/forged_wake.gdshader");material.set_shader_parameter("spin_material",1.0);material.set_shader_parameter("stroke_seed",5.0)
 body=MeshInstance3D.new();body.mesh=mesh;body.material_override=material;body.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(body)
func sync_projectile(data:Dictionary)->void:
 position=data.position
 var direction:Vector3=data.get("direction",Vector3.FORWARD)
 rotation.y=atan2(-direction.x,-direction.z)
