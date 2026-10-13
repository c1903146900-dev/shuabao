extends Node3D
var sail:MeshInstance3D
var age=0.0
func mat(c:Color)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=c;m.roughness=.9;return m
func mesh(points:Array,triangles:Array,color:Color)->MeshInstance3D:
 var arr=[];arr.resize(Mesh.ARRAY_MAX);var p=PackedVector3Array();var normals=PackedVector3Array()
 for tri in triangles:
  var normal=(points[tri[1]]-points[tri[0]]).cross(points[tri[2]]-points[tri[0]]).normalized()
  for i in tri:p.append(points[i]);normals.append(normal)
 arr[Mesh.ARRAY_VERTEX]=p;arr[Mesh.ARRAY_NORMAL]=normals
 var m=ArrayMesh.new();m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
 var n=MeshInstance3D.new();n.mesh=m;n.material_override=mat(color);n.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED;add_child(n);return n
func rail(a:Vector3,b:Vector3)->void:
 var n=MeshInstance3D.new();var c=CylinderMesh.new();c.top_radius=.027;c.bottom_radius=.036;c.height=a.distance_to(b);c.radial_segments=6;n.mesh=c;n.position=(a+b)*.5;n.material_override=mat(Color(.33,.33,.27));add_child(n)
 n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
func _ready()->void:
 var v=[Vector3(-.35,.17,-.75),Vector3(.35,.17,-.75),Vector3(.43,.23,.40),Vector3(0,.33,1.05),Vector3(-.43,.23,.40),Vector3(0,-.04,-.40),Vector3(0,.02,.63)]
 mesh(v,[[0,1,5],[1,2,6],[1,6,5],[2,3,6],[3,4,6],[4,0,5],[4,5,6]],Color(.20,.22,.20))
 mesh(v,[[0,2,1],[0,4,2],[4,3,2]],Color(.42,.38,.29))
 for row in [[0,1],[1,2],[2,3],[3,4],[4,0]]:rail(v[row[0]]+Vector3.UP*.045,v[row[1]]+Vector3.UP*.045)
 for z in [-.45,-.12,.20,.48]:
  var board=MeshInstance3D.new();var bm=BoxMesh.new();bm.size=Vector3(.50,.025,.15);board.mesh=bm;board.position=Vector3(0,.26,z);board.material_override=mat(Color(.51,.48,.36));add_child(board)
 var mast=MeshInstance3D.new();var cylinder=CylinderMesh.new();cylinder.top_radius=.026;cylinder.bottom_radius=.04;cylinder.height=1.45;mast.mesh=cylinder;mast.position=Vector3(0,.94,.03);mast.material_override=mat(Color(.19,.17,.14));add_child(mast)
 var cloth=[];var indices=[]
 for j in range(7):
  var vv=float(j)/6.0
  for i in range(6):
   var u=float(i)/5.0
   cloth.append(Vector3(.04+u*(.84-.17*vv),.52+vv*1.13-u*.24*vv,.05+.13*sin(u*PI)*sin(vv*PI)))
 for j in range(6):
  for i in range(5):
   var k=j*6+i;indices.append([k,k+6,k+7]);indices.append([k,k+7,k+1])
 sail=mesh(cloth,indices,Color(.72,.72,.61))
 var sm=ShaderMaterial.new();sm.shader=load("res://visual_rework_20261009/views/e_sail.gdshader");sail.material_override=sm
func advance(t:float)->void:
 age=t;position.y=.065+.020*sin(t*2.0);rotation.z=.015*sin(t*1.8)
 sail.material_override.set_shader_parameter("age",t)
