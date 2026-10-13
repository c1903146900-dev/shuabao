extends Node3D
## Source-sized large-area presentation. No automatic impact: runtime calls settle exactly once.
const PAINT:=preload("res://assets/fengli/vfx/forged_wake.gdshader")
var age:=0.0
var radius:=14.0
var height_scale:=1.25
var settled:=false
var impact_age:=0.0
var gather:Array=[]
var burst:Array=[]
func configure(at:Vector3,source_radius:float,visual_scale:float)->void:
 position=at;radius=source_radius;height_scale=visual_scale
 for i in range(5):
  var phase:float=float(i)*2.399
  var points:Array=[]
  for j in range(13):
   var u:float=float(j)/12.0
   points.append(Vector3(cos(phase+u*1.7)*(.60-.40*u),(.48+u*1.10)*height_scale,sin(phase+u*1.7)*(.60-.40*u)))
  var node:=_stroke(points,.075,.018,i,.36);add_child(node);gather.append(node)
func settle(at:Vector3,targets:Array)->void:
 if settled:return
 settled=true;position=at
 for node in gather:node.visible=false
 # Three simultaneous offset cutting planes, never center-to-edge spokes.
 # Each has an asymmetric leading belly and a torn transparent trailing lip.
 for i in range(3):
  var angle:float=[.24,1.80,2.79][i]
  var axis:=Vector3(cos(angle),0,sin(angle));var side:=axis.cross(Vector3.UP)
  var offset:float=[-.34,.12,.48][i]*radius
  var extent:float=sqrt(radius*radius-offset*offset)*.91
  var points:Array=[]
  for j in range(33):
   var u:float=float(j)/32.0
   points.append(axis*lerpf(-extent,extent,u)+side*(offset+sin(u*PI)*radius*(.19+.025*i))+Vector3.UP*(.16+.48*sin(u*PI)))
  var node:=_plane(points,.70+.12*i,i+11,.68);add_child(node);burst.append(node)
 # Sparse perimeter cut fragments carry the source circle, at the same instant.
 for i in range(5):
  var points:Array=[];var start:float=i*TAU/5.0+.13*sin(i*2.1)
  for j in range(15):
   var u:float=float(j)/14.0;var angle:float=start+u*(.30+.07*(i%2))
   points.append(Vector3(cos(angle),0,sin(angle))*radius*.986+Vector3.UP*.07)
  var edge:=_plane(points,.19,i+24,.36);add_child(edge);burst.append(edge)
 for i in targets.size():
  var target:Vector3=targets[i]-at
  var points:Array=[target+Vector3(-.30,.68,.32),target+Vector3(-.12,1.06,.23),target+Vector3(.18,1.42,.15),target+Vector3(.36,1.62,.08)]
  var cut:=_stroke(points,.10,.022,i+41,.91);add_child(cut);burst.append(cut)
func advance(dt:float)->void:
 age+=dt
 if not settled:
  for i in gather.size():
   var mat:ShaderMaterial=gather[i].material_override
   mat.set_shader_parameter("stroke_clock",age)
   gather[i].scale=Vector3.ONE*(.80+.20*clampf(age/.9,0,1))
 else:
  impact_age+=dt
  for node in burst:
   var mat:ShaderMaterial=node.material_override
   mat.set_shader_parameter("stroke_clock",age)
   mat.set_shader_parameter("life_alpha",1.0-clampf(impact_age/.26,0,1))
 if age>=1.78:queue_free()
func _stroke(points:Array,width:float,thickness:float,seed:int,alpha:float)->MeshInstance3D:
 var v:=PackedVector3Array();var uv:=PackedVector2Array();var c:=PackedColorArray();var ix:=PackedInt32Array()
 for i in points.size():
  var u:float=float(i)/float(points.size()-1)
  var tangent:Vector3=Vector3(points[mini(i+1,points.size()-1)])-Vector3(points[maxi(0,i-1)])
  var side:Vector3=tangent.cross(Vector3.UP).normalized()
  if side.length_squared()<.001:side=Vector3.RIGHT
  var profile:float=pow(maxf(.001,sin(u*PI)),.8)
  for j in range(4):
   var a:float=TAU*float(j)/4.0
   v.append(Vector3(points[i])+side*cos(a)*width*profile+Vector3.UP*sin(a)*thickness*profile)
   uv.append(Vector2(u,float(j)/3.0));c.append(Color(1,1,1,alpha))
  if i>0:
   for j in range(4):
    var a: int=(i-1)*4+j;var b: int=(i-1)*4+(j+1)%4;var d: int=i*4+j;var e: int=i*4+(j+1)%4
    ix.append_array(PackedInt32Array([a,d,b,b,d,e]))
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=v;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=c;arrays[Mesh.ARRAY_INDEX]=ix
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var node:=MeshInstance3D.new();node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var mat:=ShaderMaterial.new();mat.shader=PAINT;mat.set_shader_parameter("spin_material",1.0);mat.set_shader_parameter("stroke_seed",seed);node.material_override=mat
 return node

func _plane(points:Array,width:float,seed:int,alpha:float)->MeshInstance3D:
 var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
 for i in points.size():
  var u:float=float(i)/float(points.size()-1)
  var tangent:Vector3=Vector3(points[mini(i+1,points.size()-1)])-Vector3(points[maxi(0,i-1)])
  var side:Vector3=tangent.cross(Vector3.UP).normalized()
  var belly:float=pow(u,1.2)*pow(maxf(.0001,1.0-u),.35)*2.5
  for j in range(4):
   var across:float=[-.30,.10,.72,1.0][j]
   if j==3:across*=.82+.18*sin(i*2.37+seed)
   if j==0:across*=.5+.5*sin(i*1.93+seed)
   var point:Vector3=Vector3(points[i])+side*width*belly*across+Vector3.UP*([0.0,.09,.025,0.0][j]*belly)
   var flat:=Vector2(point.x,point.z)
   if flat.length()>radius:flat=flat.normalized()*radius;point.x=flat.x;point.z=flat.y
   vertices.append(point);uv.append(Vector2(u,float(j)/3.0));colors.append(Color(1,1,1,alpha*(.28 if j==0 else 1.0)))
  if i>0 and not (u<.48 and i%11==3):
   for j in range(3):
    var a:=(i-1)*4+j;var b:=a+1;var c:=i*4+j;var d:=c+1
    indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var node:=MeshInstance3D.new();node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material:=ShaderMaterial.new();material.shader=preload("res://assets/fengli/vfx/r1_cut.gdshader");material.set_shader_parameter("spin_material",1.0);material.set_shader_parameter("stroke_seed",seed);node.material_override=material
 return node
