extends Node3D
## Pure presenter: no process clock, collision, damage, actor writes or hidden Sim.
## Retired wave receipts allow visual-only flowing pigment to fade after impact.
const RIVER_SHADER=preload("res://visual_rework_20261009/views/q1_river.gdshader")
const INK=preload("res://visual_rework_20261009/views/q1_ink.png")
var _scope:Dictionary={}
var _drawn:Dictionary={}
var _preview:MeshInstance3D
var _preview_key:String=""
# Two bounded caches: guide and released-width geometry. Source arrays are copied.
var _join_cache:Dictionary={}
func reset_visuals()->void:
 _join_cache.clear()
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
func _join_geometry(path:Array,draw_width:float,guide:bool)->ArrayMesh:
 var slot:int=1 if guide else 0
 var state:Dictionary=_join_cache.get(slot,{})
 var reusable:bool=not state.is_empty() and float(state.width)==draw_width and state.path.size()<=path.size()
 if reusable:
  for i:int in range(state.path.size()):
   if state.path[i]!=path[i]:reusable=false;break
 if not reusable:
  state={"width":draw_width,"path":[],"processed":1,"rectangles":[],"bounds":[],"vertices":PackedVector3Array(),"uv_meters":PackedVector2Array(),"indices":PackedInt32Array(),"along":0.0,"mesh":null}
 if reusable and state.path.size()==path.size() and state.mesh!=null:return state.mesh
 var vertices:PackedVector3Array=state.vertices
 var uv:PackedVector2Array=state.uv_meters
 var indices:PackedInt32Array=state.indices
 var previous_rectangles:Array=state.rectangles
 var along:float=float(state.along)
 for i:int in range(maxi(1,int(state.processed)),path.size()):
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
  var rectangle_bounds:Rect2=_join_bounds(rectangle)
  for previous_index:int in range(previous_rectangles.size()):
   if not rectangle_bounds.intersects(state.bounds[previous_index]):continue
   var previous:Array[Vector2]=previous_rectangles[previous_index]
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
     vertices.append(Vector3(p.x,0.0,p.y))
     uv.append(Vector2(along+clampf((p-a).dot(direction),0.0,distance),clampf(.5+(p-a).dot(side)/draw_width,0.0,1.0)))
  previous_rectangles.append(rectangle)
  state.bounds.append(rectangle_bounds)
  along+=distance
 state.path=path.duplicate()
 state.processed=path.size()
 state.vertices=vertices;state.uv_meters=uv;state.indices=indices;state.along=along
 var length:float=_length(path)
 var normalized_uv:PackedVector2Array=uv.duplicate()
 for i:int in range(normalized_uv.size()):normalized_uv[i]=Vector2(uv[i].x/maxf(length,.001),uv[i].y)
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=normalized_uv;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new()
 if not vertices.is_empty():mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 state.mesh=mesh;_join_cache[slot]=state
 return mesh
func _mesh(path:Array,width:float,layer:int,guide:bool=false)->MeshInstance3D:
 var length:float=_length(path)
 var shared_mesh:ArrayMesh=_join_geometry(path,.10 if guide else width,guide)
 var n:=MeshInstance3D.new();n.mesh=shared_mesh;n.position.y=.025+layer*.008;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
