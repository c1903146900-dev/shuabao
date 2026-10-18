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
# New 2026-10-18 implementation: exact union of source-segment rectangles.
# First segment owns overlap. No path fitting, width extension or source writes.
func _join_cross(a:Vector2,b:Vector2)->float:
 return a.x*b.y-a.y*b.x
func _join_clean(poly:Array[Vector2])->Array[Vector2]:
 var out:Array[Vector2]=[]
 for p:Vector2 in poly:
  if out.is_empty() or p.distance_squared_to(out.back())>1e-18:out.append(p)
 if out.size()>1 and out[0].distance_squared_to(out.back())<=1e-18:out.pop_back()
 return out
func _join_half(poly:Array[Vector2],a:Vector2,b:Vector2,inside:bool)->Array[Vector2]:
 var out:Array[Vector2]=[]
 if poly.is_empty():return out
 var edge:Vector2=b-a
 var previous:Vector2=poly.back()
 var dp:float=_join_cross(edge,previous-a)
 var previous_in:bool=dp>=0.0 if inside else dp<=0.0
 for current:Vector2 in poly:
  var dc:float=_join_cross(edge,current-a)
  var current_in:bool=dc>=0.0 if inside else dc<=0.0
  if current_in!=previous_in:
   var denominator:float=dp-dc
   if denominator!=0.0:out.append(previous.lerp(current,clampf(dp/denominator,0.0,1.0)))
  if current_in:out.append(current)
  previous=current;dp=dc;previous_in=current_in
 return _join_clean(out)
func _join_bounds(poly:Array[Vector2])->Rect2:
 var bounds:Rect2=Rect2(poly[0],Vector2.ZERO)
 for p:Vector2 in poly:bounds=bounds.expand(p)
 return bounds
func _join_subtract(poly:Array[Vector2],cut:Array[Vector2])->Array:
 if not _join_bounds(poly).intersects(_join_bounds(cut)):return [poly]
 var pieces:Array=[]
 var remaining:Array[Vector2]=poly
 for edge_index:int in range(cut.size()):
  var a:Vector2=cut[edge_index];var b:Vector2=cut[(edge_index+1)%cut.size()]
  var outside:Array[Vector2]=_join_half(remaining,a,b,false)
  if outside.size()>=3:pieces.append(outside)
  remaining=_join_half(remaining,a,b,true)
  if remaining.size()<3:break
 return pieces
func _mesh(path:Array,width:float,layer:int,guide:bool=false)->MeshInstance3D:
 var length:float=_length(path)
 var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
 var previous_rectangles:Array=[]
 var along:float=0.0
 var draw_width:float=.10 if guide else width
 for i:int in range(1,path.size()):
  var world_a:Vector3=path[i-1];var world_b:Vector3=path[i]
  var a:Vector2=Vector2(world_a.x,world_a.z);var b:Vector2=Vector2(world_b.x,world_b.z)
  var distance:float=a.distance_to(b)
  # Duplicate points have no area and no source arc length.
  if distance<=0.0:continue
  var direction:Vector2=(b-a)/distance
  var side:Vector2=Vector2(-direction.y,direction.x)
  var half:Vector2=side*draw_width*.5
  var rectangle:Array[Vector2]=[a-half,b-half,b+half,a+half]
  var pieces:Array=[rectangle]
  for previous:Array[Vector2] in previous_rectangles:
   var next_pieces:Array=[]
   for piece:Array[Vector2] in pieces:next_pieces.append_array(_join_subtract(piece,previous))
   pieces=next_pieces
   if pieces.is_empty():break
  for piece:Array[Vector2] in pieces:
   for fan:int in range(1,piece.size()-1):
    var triangle:Array[Vector2]=[piece[0],piece[fan],piece[fan+1]]
    var area:float=_join_cross(triangle[1]-triangle[0],triangle[2]-triangle[0])
    if area==0.0:continue
    if area<0.0:triangle=[triangle[0],triangle[2],triangle[1]]
    for p:Vector2 in triangle:
     indices.append(vertices.size())
     vertices.append(Vector3(p.x,.025+layer*.008,p.y))
     uv.append(Vector2((along+clampf((p-a).dot(direction),0.0,distance))/maxf(length,.001),clampf(.5+(p-a).dot(side)/draw_width,0.0,1.0)))
  previous_rectangles.append(rectangle)
  along+=distance
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new()
 if not vertices.is_empty():mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
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
