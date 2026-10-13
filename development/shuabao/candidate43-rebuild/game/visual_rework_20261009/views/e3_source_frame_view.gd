extends Node3D
const Bridge=preload("res://visual_rework_20261009/snapshot_bridge.gd")
const Paint=preload("res://visual_rework_20261009/views/paint_factory.gd")
var bridge=Bridge.new()
var rings:Dictionary={}
var frame_sample:Dictionary={}
var preview_sample:Dictionary={}
func _ready()->void:
 set_as_top_level(true);transform=Transform3D.IDENTITY
 for key in ["a","b","preview"]:
  var n=Paint.plane(Vector2(1,1),1,Vector3(.13,.22,.23));add_child(n);n.visible=false;rings[key]=n
func reset_visuals()->void:
 frame_sample={};preview_sample={}
 for n in rings.values():n.visible=false
func _show(key:String,point:Variant,radius:float,age:float)->void:
 if not point is Vector3 or not point.is_finite() or radius<=0:return
 var n:MeshInstance3D=rings[key];n.position=point+Vector3.UP*.045;n.scale=Vector3(radius*2/.67,1,radius*2/.67);n.visible=true;n.material_override.set_shader_parameter("age",age)
func present_source(snapshot:Dictionary,preview:Dictionary={},projection:Dictionary={})->void:
 if rings.is_empty():return
 reset_visuals()
 var data=bridge.normalize(snapshot)
 if not data.accepted:return
 if not bridge.same_scope(projection,data.scope) or projection.get("candidate","")!="e3" or not bool(projection.get("learned",false)) or float(projection.get("source_time",-INF))!=data.source_time:return
 for row:Dictionary in data.effects:
  if row.kind!="e3":continue
  var f:Dictionary=row.source
  if str(f.get("frame_id",""))!=str(projection.get("frame_id","")) or not bool(projection.get("active",false)):continue
  frame_sample=f.duplicate(true);_show("a",f.get("a"),float(f.get("radius",0)),row.age)
  if f.has("b"):_show("b",f.b,float(f.radius),row.age)
 # Exact caller-supplied preview remains functional guidance, not committed art.
 if bool(preview.get("displayable",false)) and bridge.same_scope(preview,data.scope) and float(preview.get("source_time",-INF))==data.source_time:
  if str(preview.get("frame_id",""))!=str(snapshot.get("frames",{}).get("frame_id","")) or str(preview.get("frame_phase","none"))!=str(snapshot.get("frames",{}).get("phase","none")):return
  preview_sample=preview.duplicate(true);_show("preview",preview.get("position"),float(preview.get("radius",0)),0.0)
