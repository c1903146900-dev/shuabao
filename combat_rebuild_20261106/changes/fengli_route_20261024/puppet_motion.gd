extends RefCounted
## Visual-only original-art cutout. Timing and displacement remain source-owned.
const SHOULDER=Vector2(685,575)
var body_parts:Array=[]
var arm:=PackedVector2Array([Vector2(700,520),Vector2(880,555),Vector2(1020,665),Vector2(1600,665),Vector2(1600,1030),Vector2(1240,1030),Vector2(1240,895),Vector2(900,770),Vector2(705,680)])
var mesh:=ArrayMesh.new()
var receipt:Dictionary={}
func blend_curve(t:float)->float:
 t=clampf(t,0.0,1.0)
 return t*t*(3.0-2.0*t)
func progress(event:Dictionary,age:float)->float:
 var timing:Dictionary=event.get("animation",{})
 return clampf(age/maxf(.001,float(timing.get("contact_after",0))+float(timing.get("recovery",0))),0,1)
func pose_key(event:Dictionary,age:float)->String:
 if str(event.get("kind",""))=="attack_started":return "attack_recover"
 var t:float=progress(event,age)
 return "dashattack_recover" if t<.14 or t>.78 else "dash"
func arm_angle(event:Dictionary,age:float)->float:
 var timing:Dictionary=event.get("animation",{})
 var contact:float=maxf(.001,float(timing.get("contact_after",.2)))
 var recovery:float=maxf(.001,float(timing.get("recovery",.3)))
 if age<contact*.6:return lerpf(0,-1.35,blend_curve(age/(contact*.6)))
 if age<contact:return lerpf(-1.35,-.4,blend_curve((age-contact*.6)/(contact*.4)))
 var t:float=(age-contact)/recovery
 return lerpf(-.4,.2,blend_curve(t/.3)) if t<.3 else lerpf(.2,0,blend_curve((t-.3)/.7))
func _polygon(canvas:CanvasItem,texture:Texture2D,points:PackedVector2Array,anchor:Vector2,scale:float,angle:float=0)->void:
 var positions:=PackedVector2Array();var uv:=PackedVector2Array()
 for point in points:
  uv.append(point/Vector2(1536,1024))
  var moved:Vector2=SHOULDER+(point-SHOULDER).rotated(angle) if angle!=0 else point
  positions.append((moved-anchor)*scale)
 canvas.draw_polygon(positions,PackedColorArray([Color.WHITE]),uv,texture)
func draw_pose(canvas:CanvasItem,texture:Texture2D,key:String,event:Dictionary,age:float,anchor:Vector2,scale:float)->void:
 var kind:String=str(event.get("kind",""));var t:float=progress(event,age)
 receipt={"kind":kind,"source_pose":key,"progress":t,"source_mutations":false}
 if kind=="attack_started":
  if body_parts.is_empty():body_parts=Geometry2D.clip_polygons(PackedVector2Array([Vector2.ZERO,Vector2(1536,0),Vector2(1536,1024),Vector2(0,1024)]),arm)
  var angle:float=arm_angle(event,age)
  _polygon(canvas,texture,arm,anchor,scale,angle)
  for polygon in body_parts:_polygon(canvas,texture,polygon,anchor,scale)
  receipt.arm_radians=angle
  return
 var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
 for y in range(19):
  for x in range(25):
   var source:=Vector2(float(x)/24*1536,float(y)/18*1024)
   var moved:Vector2=source
   if key=="dash":
    var pulse:float=sin(t*PI)
    var leg:float=blend_curve((source.y-610)/300)
    moved.x=lerpf(source.x,596+(source.x-596)*.72,leg*pulse)
    moved.y-=42*leg*pulse
    moved.x+=65*pulse*(1-leg)
    moved.x+=23*sin(t*TAU)*blend_curve((450-source.x)/400)
   var at:Vector2=(moved-anchor)*scale
   vertices.append(Vector3(at.x,at.y,0));uv.append(source/Vector2(1536,1024))
 for y in range(18):
  for x in range(24):
   var i:int=y*25+x
   indices.append_array(PackedInt32Array([i,i+1,i+25,i+1,i+26,i+25]))
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
 mesh.clear_surfaces();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 canvas.draw_mesh(mesh,texture)
 receipt.vertices=vertices.size()
