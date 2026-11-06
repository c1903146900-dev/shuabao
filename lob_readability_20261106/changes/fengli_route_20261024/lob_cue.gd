extends RefCounted
# Airborne projectile presentation, not an active floor damage disc.
static func project(source:Dictionary,ground:Vector2,air:Vector2,radius:float)->Dictionary:
 if str(source.get("team",""))!="enemy" or str(source.get("type",""))!="lob":return {"accepted":true,"visible":false}
 var height:Variant=source.get("height",null)
 if not (height is float or height is int) or not is_finite(float(height)) or float(height)<0 or not ground.is_finite() or not air.is_finite() or not is_finite(radius) or radius<=0:return {"accepted":false,"visible":false}
 return {"accepted":true,"visible":true,"ground":ground,"air":air,"radius":radius,"height":float(height),"id":str(source.get("id",""))}
static func draw(canvas:Node2D,cue:Dictionary)->void:
 if not cue.get("visible",false):return
 var at:Vector2=cue.air;var r:float=cue.radius
 # A compact shadow marks current horizontal position, not the landing target.
 canvas.draw_set_transform(cue.ground,0,Vector2(1,.45))
 canvas.draw_circle(Vector2.ZERO,r+1,Color(.04,.03,.08,.55))
 canvas.draw_set_transform(Vector2.ZERO)
 canvas.draw_circle(at,r+1.5,Color("151327"))
 canvas.draw_circle(at,r,Color("ff5277"))
 canvas.draw_circle(at-Vector2(r*.18,r*.2),r*.55,Color("df9cff"))
 canvas.draw_circle(at-Vector2(r*.3,r*.35),maxf(1,r*.18),Color("fff0da"))
