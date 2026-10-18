extends SceneTree
## Diagnostic geometry/cost only: no Sim, gameplay, input authorization or acceptance claim.
const View=preload("res://visual_rework_20261009/views/q1_view.gd")
var failures:Array=[]
var geometry:Array=[]
var costs:Array=[]
var started:int=0
const BUDGET_USEC:int=10000000
func _initialize()->void:run.call_deferred()
func require(ok:bool,label:String)->void:
 if not ok:failures.append(label)
func over_budget()->bool:
 return Time.get_ticks_usec()-started>BUDGET_USEC
func planar(raw:Array)->Array:
 var out:Array=[]
 for p:Vector2 in raw:out.append(Vector3(p.x,0,p.y))
 return out
func cross2(a:Vector2,b:Vector2)->float:return a.x*b.y-a.y*b.x
func in_segment(p:Vector2,a:Vector2,b:Vector2,width:float)->bool:
 var d:Vector2=b-a
 var length:float=d.length()
 if length==0.0:return false
 d/=length
 var side:Vector2=Vector2(-d.y,d.x)
 return (p-a).dot(d)>=-0.00002 and (p-a).dot(d)<=length+0.00002 and absf((p-a).dot(side))<=width*.5+0.00002
func inspect_mesh(mesh:ArrayMesh,path:Array,width:float)->Dictionary:
 var count:int=0;var sum_area:float=0.0;var valid:bool=true
 for surface:int in range(mesh.get_surface_count()):
  var arrays:Array=mesh.surface_get_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
  var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  for i:int in range(0,indices.size(),3):
   var tri:Array[Vector2]=[]
   for j:int in range(3):
    var p:Vector3=vertices[indices[i+j]];var tex:Vector2=uv[indices[i+j]]
    valid=valid and p.is_finite() and tex.is_finite() and tex.x>=-0.00002 and tex.x<=1.00002 and tex.y>=-0.00002 and tex.y<=1.00002
    tri.append(Vector2(p.x,p.z))
   var signed_area:float=cross2(tri[1]-tri[0],tri[2]-tri[0])*.5
   valid=valid and signed_area>0.0
   sum_area+=signed_area;count+=1
   var contained:bool=false
   for k:int in range(1,path.size()):
    var a:Vector2=Vector2(path[k-1].x,path[k-1].z);var b:Vector2=Vector2(path[k].x,path[k].z)
    if in_segment(tri[0],a,b,width) and in_segment(tri[1],a,b,width) and in_segment(tri[2],a,b,width):contained=true;break
   valid=valid and contained
 return {"valid":valid,"triangles":count,"area":sum_area}
func small_cases()->void:
 var cases:Array=[
  {"name":"straight","p":[Vector2(0,0),Vector2(4,0)],"area":[6.4,.4]},
  {"name":"U","p":[Vector2(0,0),Vector2(3,0),Vector2(3,3),Vector2(0,3)],"area":[13.12,.895]},
  {"name":"S","p":[Vector2(0,0),Vector2(2,0),Vector2(3,1),Vector2(2,2),Vector2(3,3),Vector2(5,3)],"area":[11.3780317395533,.817193000900064]},
  {"name":"near180","p":[Vector2(0,0),Vector2(4,0),Vector2(.001,.003)],"area":[6.406237663165664,.4059993848462036]},
  {"name":"reverse","p":[Vector2(0,0),Vector2(4,0),Vector2(0,0)],"area":[6.4,.4]},
  {"name":"duplicate","p":[Vector2(0,0),Vector2(0,0),Vector2(2,0),Vector2(2,0),Vector2(2,2)],"area":[5.76,.3975]},
  {"name":"short","p":[Vector2(0,0),Vector2(.001,0),Vector2(.001,.001),Vector2(.002,.001)],"area":[.004798,.000298]},
  {"name":"run10","p":[Vector2(2.120847702,2.021213531),Vector2(4.649545670,1.936611176),Vector2(6.090635300,4.897480011)],"area":[8.901560729467574,.58068334843429]}
 ]
 for row:Dictionary in cases:
  for index:int in range(2):
   var width:float=1.6 if index==0 else .1
   var view=View.new();root.add_child(view)
   var path:Array=planar(row.p)
   var mesh:ArrayMesh=view._join_geometry(path,width,index==1)
   var result:Dictionary=inspect_mesh(mesh,path,width)
   result["case"]=row.name;result["width"]=width
   result["area_error"]=absf(float(result.area)-float(row.area[index]))
   require(result.valid and result.area_error<.0001,"geometry:"+str(row.name)+":"+str(width))
   geometry.append(result);view.reset_visuals();view.free()
func dense_path(kind:String,count:int)->Array:
 var path:Array=[]
 for i:int in range(count+1):
  var u:float=float(i)/count
  if kind=="U":path.append(Vector3(2*sin(PI*u),0,2*(1-cos(PI*u))))
  elif kind=="S":path.append(Vector3(4*u,0,sin(TAU*u)))
  else:path.append(Vector3(6*u,0,0) if u<=.5 else Vector3(6*(1-u),0,.002*(2*u-1)))
 return path
func cost_case(kind:String,count:int,batch:int)->void:
 var path:Array=dense_path(kind,count)
 var view=View.new();root.add_child(view)
 var samples:Array=[];var total:int=0;var peak:int=0
 var end:int=2
 while true:
  var prefix:Array=path.slice(0,end)
  var at:int=Time.get_ticks_usec()
  var node:MeshInstance3D=view._mesh(prefix,1.6,0,true)
  node.free()
  var elapsed:int=Time.get_ticks_usec()-at
  samples.append(elapsed);total+=elapsed;peak=maxi(peak,elapsed)
  if end==path.size():break
  if over_budget():break
  end=mini(path.size(),end+batch)
 var at:int=Time.get_ticks_usec()
 var nodes:Array=[]
 if end==path.size():
  for layer:int in range(3):nodes.append(view._mesh(path,1.6,layer,false))
 var release_usec:int=Time.get_ticks_usec()-at
 var shared:bool=nodes.size()==3 and nodes[0].mesh==nodes[1].mesh and nodes[0].mesh==nodes[2].mesh
 var triangles:int=0
 if not nodes.is_empty():triangles=nodes[0].mesh.surface_get_array_index_len(0)/3
 costs.append({"shape":kind,"points":count+1,"synthetic_motion_batch":batch,"completed":end==path.size(),"combined_guide_and_actual_width_drag_usec":total,"max_batch_usec":peak,"batch_usec":samples,"release_three_layers_usec":release_usec,"shared_mesh":shared,"triangles":triangles})
 require(end==path.size() and shared,"cost_case_incomplete:"+kind+":"+str(count)+":"+str(batch))
 for node:MeshInstance3D in nodes:node.free()
 view.reset_visuals();view.free()
func run()->void:
 started=Time.get_ticks_usec()
 small_cases()
 for count:int in [256,512]:
  for kind:String in ["U","S","near180"]:
   for batch:int in [1,8,32]:
    if over_budget():break
    cost_case(kind,count,batch)
 require(costs.size()==18,"bounded_cost_coverage_18")
 var report:Dictionary={"diagnostic_only":true,"geometry_cases":geometry,"cost_cases":costs,"failures":failures,"coverage_complete":geometry.size()==16 and costs.size()==18,"passed_checks":failures.is_empty(),"performance_acceptance":false,"native_input_acceptance":false,"physics_or_rules_loaded":false,"elapsed_usec":Time.get_ticks_usec()-started,"budget_usec":BUDGET_USEC}
 var output:String=OS.get_environment("Q1_GEOMETRY_REPORT")
 if not output.is_empty():
  var file=FileAccess.open(output,FileAccess.WRITE)
  if file!=null:file.store_string(JSON.stringify(report,"  "));file.close()
 print("Q1_GEOMETRY_DIAGNOSTIC ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 2)
