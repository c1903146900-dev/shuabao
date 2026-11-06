extends RefCounted
## Visual-only original-art cutout. Timing and displacement remain source-owned.
const SHOULDER=Vector2(685,575)
var body_parts:Array=[]
var moving_body_parts:Array=[]
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
 if str(event.get("kind",""))=="q1_started":return "q1_contact"
 if str(event.get("kind",""))=="attack_started":return "attack_recover"
 if str(event.get("kind",""))=="dash_attack_started":return "dashattack_recover"
 var t:float=progress(event,age)
 return "dashattack_recover" if t<.12 or t>=1.0 else "dash"
func arm_angle(event:Dictionary,age:float)->float:
 var timing:Dictionary=event.get("animation",{})
 var contact:float=maxf(.001,float(timing.get("contact_after",.2)))
 var recovery:float=maxf(.001,float(timing.get("recovery",.3)))
 if age<contact*.6:return lerpf(-.45,-1.45,blend_curve(age/(contact*.6)))
 if age<contact:return lerpf(-1.45,.05,blend_curve((age-contact*.6)/(contact*.4)))
 var t:float=(age-contact)/recovery
 return lerpf(.05,.5,blend_curve(t/.22)) if t<.22 else lerpf(.5,-.45,blend_curve((t-.22)/.78))
func dash_thrust(event:Dictionary,age:float)->float:
 # The source's real-clock contact owns the moment of full extension.
 var timing:Dictionary=event.get("animation",{})
 var contact:float=maxf(.001,float(timing.get("contact_after",0)))
 var recovery:float=maxf(.001,float(timing.get("recovery",0)))
 if age<contact*.45:return -1.0
 if age<contact:return lerpf(-1.0,1.0,blend_curve((age-contact*.45)/(contact*.55)))
 return 1.0-blend_curve((age-contact)/recovery)
func _polygon(canvas:CanvasItem,texture:Texture2D,points:PackedVector2Array,anchor:Vector2,scale:float,angle:float=0)->void:
 var positions:=PackedVector2Array();var uv:=PackedVector2Array()
 for point in points:
  uv.append(point/Vector2(1536,1024))
  var moved:Vector2=SHOULDER+(point-SHOULDER).rotated(angle) if angle!=0 else point
  positions.append((moved-anchor)*scale)
 canvas.draw_polygon(positions,PackedColorArray([Color.WHITE]),uv,texture)
func draw_pose(canvas:CanvasItem,texture:Texture2D,key:String,event:Dictionary,age:float,anchor:Vector2,scale:float,moving_basic:bool=false)->void:
 var kind:String=str(event.get("kind",""));var t:float=progress(event,age)
 receipt={"kind":kind,"source_pose":key,"progress":t,"source_mutations":false}
 if kind=="attack_started":
  if body_parts.is_empty():body_parts=Geometry2D.clip_polygons(PackedVector2Array([Vector2.ZERO,Vector2(1536,0),Vector2(1536,1024),Vector2(0,1024)]),arm)
  var angle:float=arm_angle(event,age)
  _polygon(canvas,texture,arm,anchor,scale,angle)
  if moving_basic:
   if moving_body_parts.is_empty():
    var upper:=PackedVector2Array([Vector2.ZERO,Vector2(1536,0),Vector2(1536,770),Vector2(0,770)])
    for polygon in body_parts:
     moving_body_parts.append_array(Geometry2D.intersect_polygons(polygon,upper))
   for polygon in moving_body_parts:_polygon(canvas,texture,polygon,anchor,scale)
  else:
   for polygon in body_parts:_polygon(canvas,texture,polygon,anchor,scale)
  receipt.moving_basic=moving_basic
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
   elif kind=="q1_started":
    # Existing Q1 art: keep the blade rigid, blend only through shoulder/forearm.
    var thrust:float=dash_thrust(event,age)
    var arm_weight:float=blend_curve((source.x-740)/200)*blend_curve((source.y-390)/80)*(1-blend_curve((source.y-610)/70))
    moved.x+=105*thrust*arm_weight
   elif kind=="dash_attack_started":
    # The existing thrust blade stays rigid; shoulder weight blends translation.
    var thrust:float=dash_thrust(event,age)
    var arm_weight:float=blend_curve((source.x-620)/220)*blend_curve((source.y-570)/65)*(1-blend_curve((source.y-790)/90))
    moved.x+=115*thrust*arm_weight
    var leg_weight:float=blend_curve((source.y-740)/180)
    moved.y-=22*maxf(0,thrust)*leg_weight
    moved.x-=25*maxf(0,thrust)*leg_weight
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

func body_pose(event:Dictionary,age:float)->Dictionary:
 var timing:Dictionary=event.get("animation",{})
 var contact:float=maxf(.001,float(timing.get("contact_after",0)))
 var duration:float=contact+float(timing.get("recovery",0))
 if str(event.get("kind",""))=="q1_started":
  var thrust:float=dash_thrust(event,age)
  return {"lean":.045*thrust,"offset":Vector2(3*thrust,absf(thrust)),"scale":Vector2(1+.025*absf(thrust),1-.025*absf(thrust))}
 if str(event.get("kind",""))=="dash_attack_started":
  var thrust:float=dash_thrust(event,age)
  return {"lean":.10*thrust,"offset":Vector2(4.5*thrust,1.5*absf(thrust)),"scale":Vector2(1+.045*absf(thrust),1-.045*absf(thrust))}
 if str(event.get("kind",""))=="dash":
  if age>=duration:
   var settle:float=1-blend_curve((age-duration)/.10)
   return {"lean":.025*settle,"offset":Vector2(0,2*settle),"scale":Vector2(1+.045*settle,1-.045*settle)}
  var pulse:float=sin(progress(event,age)*PI)
  return {"lean":-.09*pulse,"offset":Vector2.ZERO,"scale":Vector2(1+.09*pulse,1-.09*pulse)}
 var weight:float=0
 if age<contact*.6:weight=-blend_curve(age/(contact*.6))
 elif age<contact:weight=lerpf(-1,1,blend_curve((age-contact*.6)/(contact*.4)))
 else:weight=1-blend_curve((age-contact)/maxf(.001,duration-contact))
 return {"lean":.085*weight,"offset":Vector2(3.5*weight,-1.4*absf(weight)),"scale":Vector2(1+.025*absf(weight),1-.025*absf(weight))}
