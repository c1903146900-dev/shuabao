extends RefCounted
# Screen-space body cue, never a ground footprint or a claim about hit range.
# All timing/facing comes from the current source enemy warning state.
static func project(enemy:Dictionary,foot:Vector2,forward:Vector2)->Dictionary:
 if bool(enemy.get("dead",true)) or str(enemy.get("state",""))!="warning":return {"visible":false,"accepted":true}
 if str(enemy.get("attack_shape",""))=="boss_wave_line":return {"visible":false,"accepted":true}
 if str(enemy.get("telegraph_style",""))!="body_weapon" or bool(enemy.get("ground_warning",false)):return {"visible":false,"accepted":false}
 var raw:Variant=enemy.get("warning_progress",null)
 if not (raw is float or raw is int) or not is_finite(float(raw)) or not foot.is_finite() or not forward.is_finite() or forward.length_squared()<.000001:return {"visible":false,"accepted":false}
 var height:float=46.0 if str(enemy.get("kind",""))=="minion" else 64.0
 return {"visible":true,"accepted":true,"at":foot+Vector2(0,-height-17),"direction":forward.normalized(),"progress":clampf(float(raw),0,1),"actor_id":str(enemy.get("actor_id",""))}
static func draw(canvas:Node2D,cue:Dictionary)->void:
 if not cue.get("visible",false):return
 var at:Vector2=cue.at;var d:Vector2=cue.direction;var side:=d.orthogonal();var amount:float=cue.progress
 var ink:=Color("101426");var color:Color=Color("ffd66e").lerp(Color("ff566b"),amount)
 canvas.draw_circle(at,10.5,ink)
 canvas.draw_arc(at,8.0,-PI*.5,TAU-PI*.5,32,Color("65404d"),2.0,true)
 if amount>.001:canvas.draw_arc(at,8.0,-PI*.5,-PI*.5+TAU*amount,32,color,3.0,true)
 # A short pointer shows committed facing, not attack length or collision width.
 canvas.draw_line(at+d*11,at+d*21,ink,5,true)
 canvas.draw_line(at+d*11,at+d*21,color,2.5,true)
 for sign_side:float in [-1.0,1.0]:
  canvas.draw_line(at+d*21,at+d*16+side*sign_side*4,ink,5,true)
  canvas.draw_line(at+d*21,at+d*16+side*sign_side*4,color,2.5,true)
 canvas.draw_circle(at,2.0,color)
