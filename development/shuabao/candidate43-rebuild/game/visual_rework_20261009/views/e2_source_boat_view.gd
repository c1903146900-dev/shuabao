extends Node3D
## Pure production snapshot view. No demo state, collision or damage ownership.
const Bridge=preload("res://visual_rework_20261009/snapshot_bridge.gd")
const Boat=preload("res://visual_rework_20261009/views/e2_painted_boat.gd")
const Paint=preload("res://visual_rework_20261009/views/paint_factory.gd")
var bridge=Bridge.new()
var mesh:Node3D
var boat_sample:Dictionary={}
var wakes:Dictionary={}
var bursts:Array=[]
var seen:Dictionary={}
var scope:Dictionary={}
var fallback_required=false
var ink_texture:Texture2D
func _ready()->void:
 set_as_top_level(true);transform=Transform3D.IDENTITY
 mesh=Boat.new();add_child(mesh);mesh.visible=false
 ink_texture=load("res://visual_rework_20261009/assets/huamo_bimo_atlas.png") as Texture2D
func reset_visuals()->void:
 boat_sample={};fallback_required=false;seen.clear();scope={}
 if is_instance_valid(mesh):mesh.visible=false
 for row in wakes.values():
  for node in row.nodes:node.queue_free()
 for row in bursts:row.node.queue_free()
 wakes.clear();bursts.clear()
func _sync_scope(snapshot:Dictionary)->void:
 var next:Dictionary=snapshot.get("scope",{})
 if scope!=next:reset_visuals();scope=next.duplicate(true)
func receive_source(event:Dictionary,snapshot:Dictionary)->void:
 _sync_scope(snapshot)
 if not bridge.same_scope(event,scope):return
 var kind=str(event.get("kind",""))
 if kind not in ["ink_e2_boarded","ink_e2_natural_burst"]:return
 if bool(event.get("h09",false)) or bool(event.get("h10",false)):return
 var key=str(event.get("boat_id",""))+":terminal"
 if seen.has(key) or not bridge.finite_point(event.get("position")):return
 var radius=float(event.get("boarding_radius" if kind=="ink_e2_boarded" else "natural_radius",0))
 if radius<=0:return
 seen[key]=true
 var n=Paint.plane(Vector2.ONE*radius*2.0,3,Vector3(.19,.30,.29));n.position=event.position+Vector3.UP*.045;add_child(n)
 bursts.append({"node":n,"born":float(event.get("source_time",snapshot.get("hero_time",0))),"duration":.7})
func _new_wake()->Dictionary:
 var nodes=[]
 for k in range(2):
  var n=MeshInstance3D.new();var mat=ShaderMaterial.new();mat.shader=load("res://visual_rework_20261009/views/e2_painted_ink.gdshader")
  mat.set_shader_parameter("brush",ink_texture);mat.set_shader_parameter("mode",1);mat.set_shader_parameter("seed",float(k));n.material_override=mat;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(n);nodes.append(n)
 return {"nodes":nodes,"retired":-1.0,"route":[],"born":0.0}
func _route_mesh(row:Dictionary,path:Array)->void:
 if path.size()<2:return
 var lengths=[0.0];var total=0.0
 for i in range(1,path.size()):total+=path[i-1].distance_to(path[i]);lengths.append(total)
 if total<.05:return
 for k in range(2):
  var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for i in range(path.size()-1):
   var direction:Vector3=(path[i+1]-path[i]).normalized();var side=Vector3(-direction.z,0,direction.x)
   for pair in [Vector2i(i,0),Vector2i(i+1,0),Vector2i(i+1,1),Vector2i(i,0),Vector2i(i+1,1),Vector2i(i,1)]:
    var behind=total-float(lengths[pair.x]);var width=.67+.13*minf(behind,2.2)
    var branch=(1.0 if k==0 else -1.0)*(.055+.065*minf(behind,2.0))
    st.set_uv(Vector2(float(lengths[pair.x])/total,float(pair.y)))
    st.add_vertex(path[pair.x]+side*(branch+(float(pair.y)-.5)*width)+Vector3.UP*(.035+float(k)*.004))
  row.nodes[k].mesh=st.commit()
func present_source(snapshot:Dictionary,_projection:Dictionary={})->void:
 if not is_instance_valid(mesh):return
 _sync_scope(snapshot)
 var normalized=bridge.normalize(snapshot)
 if not normalized.accepted:reset_visuals();return
 var now=float(normalized.source_time);var active="";mesh.visible=false;boat_sample={};fallback_required=false
 for effect:Dictionary in normalized.effects:
  if effect.kind!="e2":continue
  var source:Dictionary=effect.source
  if bool(source.get("h09",false)) or bool(source.get("h10",false)):
   reset_visuals();scope=snapshot.get("scope",{}).duplicate(true);fallback_required=true;return
  active=str(source.boat_id)
  # Painted bow is +1.275m; production position is physical front.
  mesh.position=effect.front-effect.direction.normalized()*1.275;mesh.rotation.y=atan2(effect.direction.x,effect.direction.z)
  var ground_y=mesh.position.y;mesh.advance(effect.age);mesh.position.y+=ground_y;mesh.visible=true;boat_sample=effect.duplicate(true)
  if not wakes.has(active):wakes[active]=_new_wake()
  var row:Dictionary=wakes[active];row.retired=-1.0;row.born=float(source.born_at)
  var path:Array=[]
  for point in effect.route:
   if bridge.finite_point(point):path.append(point)
  if path.is_empty() or path[-1].distance_to(effect.front)>.001:path.append(effect.front)
  if path!=row.route:row.route=path.duplicate();_route_mesh(row,path)
 for key in wakes.keys():
  var row:Dictionary=wakes[key]
  if key!=active and row.retired<0:row.retired=now
  var fade=1.0 if row.retired<0 else 1.0-smoothstep(row.retired,row.retired+.8,now)
  if fade<=0:
   for n in row.nodes:n.queue_free()
   wakes.erase(key);continue
  for n in row.nodes:n.material_override.set_shader_parameter("age",now-row.born);n.material_override.set_shader_parameter("strength",fade*.85)
 for i in range(bursts.size()-1,-1,-1):
  var row:Dictionary=bursts[i];var age=now-row.born
  if age>=row.duration:row.node.queue_free();bursts.remove_at(i);continue
  row.node.material_override.set_shader_parameter("age",age)
