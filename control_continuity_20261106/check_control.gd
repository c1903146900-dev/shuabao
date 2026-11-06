extends SceneTree
var checks:int=0
class MockSource extends Node:
 var encounter_generation:int=1
 var real_time:float=0
 var phase:String="combat"
 var paused:bool=false
 var hero:Dictionary={"dead":false,"move_intent":Vector3.ZERO,"dash_left":0.0,"lock_time":0.0,"cooldowns":{}}
 var calls:Array=[]
 func request_action(action:String,aim:Vector3,_id:String)->Dictionary:
  calls.append([action,aim])
  if paused or hero.dead:return {"accepted":false,"reason":"encounter_frozen"}
  if hero.lock_time>0:return {"accepted":false,"reason":"action_locked"}
  if hero.dash_left>0:return {"accepted":false,"reason":"dashing"}
  return {"accepted":true}
func check(value:bool)->void:
 assert(value);checks+=1
func _initialize()->void:
 root.add_child(load("res://boot.tscn").instantiate())
 call_deferred("run")
func run()->void:
 var router_script:Script=load("res://fengli_route_20261024/input_router.gd")
 var puppet_script:Script=load("res://fengli_route_20261024/puppet_motion.gd")
 var production:Script=load("res://fengli_route_20261024/presentation.gd")
 check(router_script.can_instantiate());check(puppet_script.can_instantiate());check(production.can_instantiate())
 var source=MockSource.new();root.add_child(source)
 var router=router_script.new();router.bind(source)
 source.hero.lock_time=.08
 check(router._tap("shift",Vector3.INF).get("buffered",false))
 source.hero.lock_time=0;source.real_time=.06
 check(router.update_held_basic(Vector3.ZERO,false).get("accepted",false));check(router.pending.is_empty());check(source.calls.back()[1]==Vector3.INF)
 source.hero.lock_time=.08;router._tap("attack",Vector3(1,0,2));source.real_time=.3;source.hero.lock_time=0
 router.update_held_basic(Vector3.ZERO,false);check(router.pending.is_empty())
 source.hero.lock_time=.3;check(not router._tap("shift",Vector3.INF).get("buffered",false))
 for boundary in ["focus","pause","generation","pointer","death"]:
  source.hero.lock_time=.08;source.paused=false;source.hero.dead=false;router.bind(source);router._tap("shift",Vector3.INF)
  match boundary:
   "focus":router.focus_lost()
   "pause":source.paused=true
   "generation":source.encounter_generation+=1
   "death":source.hero.dead=true
  router.update_held_basic(Vector3.ZERO,boundary=="pointer")
  check(router.pending.is_empty())
 # HUD pointer rejection must preserve held movement, but consume click and
 # queued attacks. A new physical attack is required after leaving the HUD.
 source.paused=false;source.hero.dead=false;source.hero.lock_time=0
 for keycode in [KEY_W,KEY_A,KEY_S,KEY_D]:
  router.bind(source)
  var k:=InputEventKey.new();k.physical_keycode=keycode;k.pressed=true
  router.handle_event(k)
  var held:Vector3=router.movement();check(held.length()>0)
  var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
  var count:int=source.calls.size()
  check(router.handle_event(click,Vector3.ZERO,false,true).reason=="pointer_input_blocked")
  check(router.movement()==held);check(source.hero.move_intent==held);check(source.calls.size()==count)
  router.update_held_basic(Vector3.ZERO,false);check(source.calls.size()==count)
  click.pressed=false;router.handle_event(click);check(router.movement()==held)
  click.pressed=true;check(router.handle_event(click,Vector3.ZERO).accepted)
  router.focus_lost();check(router.movement()==Vector3.ZERO);check(source.hero.move_intent==Vector3.ZERO)
  router.update_held_basic(Vector3.ZERO,false);check(router._held_suppressed)
  click.pressed=false;router.handle_event(click)
  k.pressed=true;router.handle_event(k);check(router.movement()==held)
  router.handle_event(click,Vector3.ZERO,true)
  # A real blocked key-down still clears movement.
  router.handle_event(k,Vector3.ZERO,true);check(router.movement()==Vector3.ZERO)
  router.handle_event(k);k.pressed=false;router.handle_event(k,Vector3.ZERO,false,true);check(router.movement()==Vector3.ZERO)
 var puppet=puppet_script.new();var event:Dictionary={"kind":"attack_started","animation":{"contact_after":.2,"recovery":.3}}
 for i in range(101):check(is_finite(puppet.arm_angle(event,i*.005)))
 print("CONTROL_CONTINUITY_CHECKS_PASS ",checks)
 quit()
