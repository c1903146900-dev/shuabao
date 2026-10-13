extends RefCounted
## Thin OS-event router. Host supplies live camera-ground aim to update_held_basic
## every host input update. Never choose a target or re-release a Q1 gesture.
var _sim:WeakRef
var _keys:Dictionary={}
var _serial:int=0
var _gesture_id:String=""
var _generation:int=-1
var _left_physical:bool=false
var _gesture_consumed:bool=false
var _suppress_held:bool=false
func bind(sim)->void:
 if _sim!=null and _sim.get_ref()!=null:focus_lost()
 _sim=weakref(sim);_keys.clear();_gesture_id="";_generation=-1
 _left_physical=false;_gesture_consumed=false;_suppress_held=false
func _command()->String:
 _serial+=1
 return "ink_os_input:%d"%_serial
func _cancel(kind:String,mouse_ground:Vector3)->Dictionary:
 var sim=_sim.get_ref()
 if sim.ink_input.phase=="idle":return {"accepted":false,"reason":"no_preview_to_cancel","consumed":false}
 _suppress_held=true
 return sim.request_ink_input(kind,mouse_ground,_command())
func handle_event(event:InputEvent,mouse_ground:Vector3=Vector3.INF)->Dictionary:
 if _sim==null or _sim.get_ref()==null:return {"accepted":false,"reason":"unbound"}
 var sim=_sim.get_ref()
 if event is InputEventKey:
  if event.echo:return {"accepted":false,"reason":"key_echo"}
  var key:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
  if key in [KEY_W,KEY_A,KEY_S,KEY_D]:
   _keys[key]=event.pressed
   sim.hero.move_intent=Vector3(float(_keys.get(KEY_D,false))-float(_keys.get(KEY_A,false)),0.0,float(_keys.get(KEY_S,false))-float(_keys.get(KEY_W,false))).limit_length(1.0)
   return {"accepted":true,"reason":"movement_intent"}
  if key==KEY_Q:
   if event.pressed and _left_physical:return {"accepted":false,"reason":"mouse_already_held"}
   var result:Dictionary=sim.request_ink_input("q_down" if event.pressed else "q_up",mouse_ground,_command())
   if result.get("accepted",false):_gesture_id=str(result.get("gesture_id",_gesture_id));_generation=sim.encounter_generation
   return result
  if key==KEY_ESCAPE and event.pressed:return _cancel("escape",mouse_ground)
  if key==KEY_SHIFT and event.pressed:return sim.request_action("shift",mouse_ground,_command())
 elif event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:return _cancel("right_down",mouse_ground)
  if event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed:
    if _left_physical:return {"accepted":false,"reason":"duplicate_physical_down"}
    _left_physical=true;_suppress_held=false;_generation=sim.encounter_generation
    _gesture_consumed=sim.ink_input.phase!="idle"
    if sim.paused or sim.phase!="combat" or sim.hero.dead:_suppress_held=true
   var result:Dictionary=sim.request_ink_input("left_down" if event.pressed else "left_up",mouse_ground,_command(),_gesture_id,_generation)
   if result.has("gesture_id"):_gesture_id=str(result.gesture_id)
   if not event.pressed:
    _gesture_id="";_left_physical=false;_gesture_consumed=false;_suppress_held=false
   return result
 elif event is InputEventMouseMotion:
  return sim.request_ink_input("motion",mouse_ground,_command(),_gesture_id,_generation)
 return {"accepted":false,"reason":"unmapped_input"}
func update_held_basic(mouse_ground:Vector3)->Dictionary:
 if _sim==null or _sim.get_ref()==null:return {"accepted":false,"reason":"unbound"}
 var sim=_sim.get_ref()
 if sim.paused or sim.phase!="combat" or sim.hero.dead or sim.encounter_generation!=_generation:
  _suppress_held=true
 if not _left_physical or _gesture_consumed or _suppress_held:return {"accepted":false,"reason":"held_basic_suppressed"}
 # Read current aim anew for every submitted shot; shared source cadence gates it.
 return sim.request_action("attack",mouse_ground,_command())
func suspend_input(reason:String="pause")->void:
 if _sim==null or _sim.get_ref()==null:return
 _keys.clear();_suppress_held=true
 _sim.get_ref().hero.move_intent=Vector3.ZERO
 _sim.get_ref().request_ink_input("focus_lost",Vector3.INF,_command())
func focus_lost()->void:
 # Keep physical-held/consumed latch until mouse-up, even though the simulator
 # cleared its preview. Only a new down after release can start ordinary fire.
 suspend_input("focus_lost")
