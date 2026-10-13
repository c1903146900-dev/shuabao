extends Node3D
## Candidate only. No Sim, colliders, actor writes or independent frame clock.
const Realm=preload("res://visual_rework_20261009/views/e3_painted_realm.gd")
var circles:Dictionary={}
var scope:Dictionary={}
var transient:Dictionary={}
var seen:Dictionary={}
var last_time=-INF
func _ready()->void:
 set_as_top_level(true);transform=Transform3D.IDENTITY
 var texture=load("res://visual_rework_20261009/assets/e3_landscape_atlas01.png") as Texture2D
 if texture==null:return
 for key in ["a","b","preview"]:
  var n=Realm.new();add_child(n);n.setup(texture,3.0,0.0 if key=="a" else 1.0);n.visible=false;circles[key]=n
func reset_visuals()->void:
 for n in circles.values():n.visible=false
 scope={};transient={};seen.clear();last_time=-INF
func _same(row:Dictionary)->bool:
 return row.get("generation",-1)==scope.get("generation",-2) and str(row.get("room_id",""))==str(scope.get("room_id","?"))
func _clock(ink:Dictionary)->float:return float(ink.get("hero_time",ink.get("source_time",NAN)))
func _admit(ink:Dictionary)->bool:
 var next:Dictionary=ink.get("scope",{});var now=_clock(ink)
 if not next.has("generation") or not next.has("room_id") or not is_finite(now):reset_visuals();return false
 if next!=scope or now<last_time:reset_visuals();scope=next.duplicate(true)
 last_time=now;return true
func _show(key:String,point:Variant,radius:float,age:float,strength:float=1.0,fade:float=0.0,exchange:float=-1.0)->void:
 if not point is Vector3 or not point.is_finite() or not is_finite(radius) or radius<=0:return
 var n=circles[key];n.position=point+Vector3.UP*(.036 if key=="a" else .037);n.scale=Vector3(radius/3.0,1.0,radius/3.0)
 n.present(age,strength,fade,exchange);n.visible=true
func receive_source(event:Dictionary,ink_snapshot:Dictionary)->void:
 if not _admit(ink_snapshot) or not _same(event):return
 if str(event.get("kind","")) not in ["ink_e3_exchanged","ink_e3_returned"]:return
 var at=float(event.get("source_time",NAN));var now=_clock(ink_snapshot)
 if not is_finite(at) or at>now or now-at>1.15:return
 if not event.get("a") is Vector3 or not event.get("b") is Vector3:return
 var token="%s:%s:%s"%[str(event.get("frame_id","")),str(event.kind),str(at)]
 if seen.has(token):return
 seen[token]=true;transient=event.duplicate(true)
func present_source(ink_snapshot:Dictionary,preview:Dictionary={},projection:Dictionary={})->void:
 if circles.is_empty() or not _admit(ink_snapshot):return
 for n in circles.values():n.visible=false;n.set_partner(Vector3.ZERO,0.)
 var now=_clock(ink_snapshot)
 var row:Dictionary=ink_snapshot.get("frames",{})
 var projection_valid=_same(projection) and projection.get("candidate","")=="e3" and bool(projection.get("learned",false)) and float(projection.get("source_time",-INF))==now
 if projection_valid and not row.is_empty() and _same(row) and not bool(row.get("retired",true)):
  if str(row.get("frame_id",""))==str(projection.get("frame_id","")) and bool(projection.get("active",false)):
   var age=maxf(0.,now-float(row.get("born_at",now)))
   _show("a",row.get("a"),float(row.get("radius",0)),age)
   if row.has("b"):_show("b",row.b,float(row.radius),age)
 if projection_valid and bool(preview.get("displayable",false)) and _same(preview) and float(preview.get("source_time",-INF))==now:
  if str(preview.get("frame_id",""))==str(row.get("frame_id","")) and str(preview.get("frame_phase","none"))==str(row.get("phase","none")):
   _show("preview",preview.get("position"),float(preview.get("radius",0)),maxf(0.,now-float(row.get("born_at",now))),.65)
 if not transient.is_empty():
  var elapsed=now-float(transient.source_time)
  if elapsed>=1.15 or elapsed<0:transient={}
  else:
   var age=maxf(0.,now-float(transient.get("born_at",now)));var fade=smoothstep(.68,1.15,elapsed)
   _show("a",transient.a,float(transient.radius),age,1.,fade,elapsed)
   _show("b",transient.b,float(transient.radius),age,1.,fade,elapsed)
   circles.preview.visible=false
 var other=circles.b if circles.b.visible else circles.preview
 if circles.a.visible and other.visible:
  circles.a.set_partner(other.position,other.radius*other.scale.x)
  other.set_partner(circles.a.position,circles.a.radius*circles.a.scale.x)
