# Exact function executed by the native observation harness; not a standalone scene.
func check_layout()->void:
 var script=load("res://fengli_route_20261024/enemy_warning_cue.gd")
 var checks:int=0
 for size in [Vector2(1280,720),Vector2(800,600)]:
  var viewport:=Rect2(Vector2.ZERO,size)
  for foot in [size*.5,Vector2(30,80),Vector2(size.x-30,80),Vector2(30,size.y-30),Vector2(size.x-30,size.y-30)]:
   for offset in [Vector2(0,-40),Vector2(-30,-55),Vector2(30,-55),Vector2(-100,-100)]:
    var cue:Dictionary={"visible":true,"at":foot+offset,"direction":Vector2(0.6,0.8),"progress":0.7,"actor_id":"fixture"}
    var result:Dictionary=script.clear_player(cue,foot,viewport)
    var at:Vector2=result.at
    assert(at.x>=24 and at.x<=size.x-24 and at.y>=24 and at.y<=size.y-24)
    assert(result.direction==Vector2(0.6,0.8) and result.progress==0.7 and result.actor_id=="fixture")
    assert(result.clearance_resolved)
    checks+=1
 print("WARNING_LAYOUT_FIXTURES ",checks)
