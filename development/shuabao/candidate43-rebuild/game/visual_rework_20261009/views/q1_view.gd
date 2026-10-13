extends Node3D
## Pure presenter: no process clock, collision, damage, actor writes or hidden Sim.
## Retired wave receipts allow visual-only flowing pigment to fade after impact.
const RIVER_SHADER=preload("res://visual_rework_20261009/views/q1_river.gdshader")
const INK=preload("res://visual_rework_20261009/views/q1_ink.png")
var _scope:Dictionary={}
var _drawn:Dictionary={}
var _preview:MeshInstance3D
var _preview_key:String=""
func reset_visuals()->void:
 for group:Array in _drawn.values():
  for n:MeshInstance3D in group:n.queue_free()
 _drawn.clear()
 if is_instance_valid(_preview):_preview.queue_free()
 _preview=null;_preview_key="";_scope={}
func receive_source(_event:Dictionary,ink_snapshot:Dictionary)->void:
 present_source(ink_snapshot)
func _same_scope(row:Dictionary)->bool:
 return row.get("generation",-1)==_scope.get("generation",-2) and row.get("room_id","")==_scope.get("room_id","?")
func _length(path:Array)->float:
 var result:float=0.0
 for i in range(1,path.size()):result+=Vector3(path[i-1]).distance_to(path[i])
 return result
func _mesh(path:Array,width:float,layer:int,guide:bool=false)->MeshInstance3D:
 var length:float=_length(path)
 var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
 var along:float=0.0
 # Resampling each segment avoids uneven UV speed, without spline overshoot.
 var samples:Array[Vector3]=[]
 for i in range(1,path.size()):
  var a:Vector3=path[i-1];var b:Vector3=path[i]
  var steps:int=maxi(1,ceili(a.distance_to(b)/.10))
  for j in range(steps):samples.append(a.lerp(b,float(j)/steps))
 samples.append(path.back())
 for i in range(samples.size()):
  if i>0:along+=samples[i-1].distance_to(samples[i])
  var forward:Vector3=samples[mini(i+1,samples.size()-1)]-samples[maxi(i-1,0)]
  var side:Vector3=Vector3(-forward.z,0,forward.x).normalized()
  for edge in range(2):
   vertices.append(samples[i]+side*(float(edge)-.5)*(width if not guide else .10)+Vector3.UP*(.025+layer*.008))
   uv.append(Vector2(along/maxf(length,.001),float(edge)))
  if i<samples.size()-1:
   var k:int=i*2;indices.append_array(PackedInt32Array([k,k+2,k+3,k,k+3,k+1]))
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var n:=MeshInstance3D.new();n.mesh=mesh;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material:=ShaderMaterial.new();material.shader=RIVER_SHADER
 material.set_shader_parameter("ink_texture",INK);material.set_shader_parameter("path_length",length)
 material.set_shader_parameter("layer",float(layer));material.set_shader_parameter("guide",guide)
 n.material_override=material;add_child(n);return n
func present_source(ink_snapshot:Dictionary,preview:Dictionary={})->void:
 var scope:Dictionary=ink_snapshot.get("scope",{})
 var now:float=float(ink_snapshot.get("hero_time",ink_snapshot.get("source_time",NAN)))
 if scope.is_empty() or not is_finite(now):reset_visuals();return
 if scope!=_scope:reset_visuals();_scope=scope.duplicate(true)
 var alive:Dictionary={}
 var rows:Array=ink_snapshot.get("waves",[]).duplicate()
 rows.append_array(ink_snapshot.get("finished",[]))
 for row:Dictionary in rows:
  if not _same_scope(row) or str(row.get("source",""))!="q1":continue
  var path:Array=row.get("path",[])
  var age:float=now-float(row.get("released_at",INF))
  if path.size()<2 or age<0.0 or age>=3.45 or _length(path)<=.0001:continue
  var key:String=str(row.get("wave_id",row.get("cast_id","")))
  alive[key]=true
  if not _drawn.has(key):
   var group:Array=[]
   for layer in range(3):group.append(_mesh(path,float(row.get("width",1.6)),layer))
   _drawn[key]=group
  for n:MeshInstance3D in _drawn[key]:
   n.material_override.set_shader_parameter("age",age)
   n.material_override.set_shader_parameter("front_distance",float(row.get("front_distance",0.0)))
 for key in _drawn.keys():
  if not alive.has(key):
   for n:MeshInstance3D in _drawn[key]:n.queue_free()
   _drawn.erase(key)
 var input:Dictionary=preview if not preview.is_empty() else ink_snapshot.get("input",{})
 var path:Array=input.get("path",[])
 var key:String=str(path) if input.get("phase","") in ["drawing","frozen"] and path.size()>1 and _length(path)>.0001 else ""
 if key!=_preview_key:
  if is_instance_valid(_preview):_preview.queue_free()
  _preview=null;_preview_key=key
  if not key.is_empty():_preview=_mesh(path,float(input.get("width",1.6)),0,true)
