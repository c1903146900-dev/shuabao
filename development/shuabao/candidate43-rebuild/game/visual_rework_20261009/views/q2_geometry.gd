extends RefCounted
## All three surfaces consume the same sampled shore rows. No collisions.
var rows:Array=[]
var forward:=Vector3.RIGHT
var far_normal:=Vector3.FORWARD
var origin:=Vector3.ZERO
var length:=12.0
var width_scale:=1.0
var data:Dictionary={}
func sample(x:float,stations:Array,values:Array)->float:
 if x<=float(stations[0]):return float(values[0])
 if x>=float(stations[-1]):return float(values[-1])
 for i in range(stations.size()-1):
  if x>float(stations[i+1]):continue
  var t=(x-float(stations[i]))/(float(stations[i+1])-float(stations[i]))
  var a=float(values[maxi(0,i-1)]);var b=float(values[i]);var c=float(values[i+1]);var d=float(values[mini(values.size()-1,i+2)])
  var v=.5*((2.0*b)+(-a+c)*t+(2.0*a-5.0*b+4.0*c-d)*t*t+(-a+3.0*b-3.0*c+d)*t*t*t)
  return clampf(v,minf(b,c),maxf(b,c))
 return float(values[-1])
func point(s:float,n:float,h:float)->Vector3:return origin+forward*s+far_normal*n*width_scale+Vector3.UP*h
func configure(a:Vector3,b:Vector3,camera_position:Vector3,source_width:float=1.5)->void:
 width_scale=maxf(.01,source_width)/1.5
 data=JSON.parse_string(FileAccess.get_file_as_string("res://visual_rework_20261009/views/q2_geometry.json"))
 origin=a;forward=(b-a).normalized();length=a.distance_to(b);far_normal=Vector3(-forward.z,0,forward.x)
 if far_normal.dot(camera_position-(a+b)*.5)>0:far_normal=-far_normal
 var stations:Array=[]
 for i in range(129):stations.append(float(i)*12.0/128.0)
 for v in data.farBank.stations:if not stations.has(float(v)):stations.append(float(v))
 for v in data.waterNear.stations:if not stations.has(float(v)):stations.append(float(v))
 stations.sort();rows.clear()
 for x in stations:
  rows.append({"u":float(x)/12.0,"s":float(x)*length/12.0,"far":sample(x,data.farBank.stations,data.farBank.shoreOffsets),"near":sample(x,data.waterNear.stations,data.waterNear.offsets),"outer":sample(x,data.farBank.stations,data.farBank.outerWidths),"ridge":sample(x,data.farBank.stations,data.farBank.ridgeOffsets),"height":sample(x,data.farBank.stations,data.farBank.ridgeHeights),"near_width":sample(x,data.nearBank.stations,data.nearBank.widths) if x<=7.7 else 0.0,"near_height":sample(x,data.nearBank.stations,data.nearBank.heights) if x<=7.7 else 0.0})
func surface(kind:String,shader:Shader)->MeshInstance3D:
 var chosen:Array=[]
 for row in rows:
  if kind=="near" and row.u>7.7/12.0:continue
  chosen.append(row)
 var columns=17 if kind=="water" else 13
 var vertices=PackedVector3Array();var coords=PackedVector2Array();var coords2=PackedVector2Array();var normals=PackedVector3Array();var indices=PackedInt32Array()
 for row in chosen:
  for j in range(columns):
   var t=float(j)/float(columns-1);var n:float;var height=.046;var ridge_fraction=.5
   if kind=="water":n=lerpf(row.near,row.far,t)
   elif kind in ["far","dust"]:
    n=row.far+row.outer*t*.48
    var ridge=clampf(float(row.ridge)/maxf(.001,row.outer),.08,.94);ridge_fraction=ridge
    var slope=smoothstep(0.0,ridge,t) if t<=ridge else 1.0-smoothstep(ridge,1.0,t)
    height+=row.height*slope*.30
    if kind=="dust":height+=(.06+.08*slope)*sin(t*PI)
   else:
    n=row.near-row.near_width*t*.42;height+=row.near_height*sin(t*PI)*.25
   vertices.append(point(row.s,n,height));coords.append(Vector2(row.u,t));coords2.append(Vector2(n,ridge_fraction))
 for i in range(chosen.size()):
  for j in range(columns):
   var ds=vertices[mini(i+1,chosen.size()-1)*columns+j]-vertices[maxi(i-1,0)*columns+j]
   var dn=vertices[i*columns+mini(j+1,columns-1)]-vertices[i*columns+maxi(j-1,0)]
   var normal=ds.cross(dn).normalized()
   if normal.y<0:normal=-normal
   normals.append(normal if normal.length_squared()>.5 else Vector3.UP)
 for i in range(chosen.size()-1):
  for j in range(columns-1):
   var k=i*columns+j;indices.append_array(PackedInt32Array([k,k+columns,k+columns+1,k,k+columns+1,k+1]))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=coords;arrays[Mesh.ARRAY_TEX_UV2]=coords2;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var node=MeshInstance3D.new();node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("river_length",length);material.set_shader_parameter("layer",1.0 if kind=="near" else 0.0)
 material.render_priority=1 if kind=="water" else 2 if kind=="dust" else 0
 node.material_override=material;return node
func sun_position()->Vector3:
 # B is the sun's ground anchor; the vertical rise is visual only.
 return point(length,0.0,.13)
