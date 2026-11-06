extends RefCounted
# Foreground hostile projectile cue. Tail is decorative, never a damage region.
static func project(source:Dictionary,at:Vector2,forward:Vector2,radius:float)->Dictionary:
 if str(source.get("team",""))!="enemy":return {"accepted":true,"visible":false}
 if not at.is_finite() or not forward.is_finite() or not is_finite(radius) or radius<=0.0:return {"accepted":false,"visible":false}
 var kind:String=str(source.get("type",""))
 if not kind in ["bolt","hex_bolt","lob"]:return {"accepted":false,"visible":false}
 if kind!="lob" and forward.length_squared()<.000001:return {"accepted":false,"visible":false}
 return {"accepted":true,"visible":true,"at":at,"radius":radius,"direction":forward.normalized(),"kind":kind,"id":str(source.get("id",""))}
static func draw(canvas:Node2D,cue:Dictionary)->void:
 if not cue.get("visible",false):return
 var at:Vector2=cue.at;var radius:float=cue.radius
 # Preserve lob presentation until its distinct airborne contract is evaluated.
 if cue.kind=="lob":canvas.draw_circle(at,maxf(1.0,radius),Color("ff5277"));return
 var color:Color=Color("ffce65") if cue.kind=="bolt" else Color("ee89ff")
 var direction:Vector2=cue.direction
 canvas.draw_line(at-direction*18.0,at-direction*radius,Color("141327"),5.0,true)
 canvas.draw_line(at-direction*18.0,at-direction*radius,color.darkened(.25),2.5,true)
 canvas.draw_circle(at,radius+1.5,Color("141327"))
 canvas.draw_circle(at,radius,Color("ff5277"))
 canvas.draw_circle(at,maxf(1.0,radius*.44),color)
