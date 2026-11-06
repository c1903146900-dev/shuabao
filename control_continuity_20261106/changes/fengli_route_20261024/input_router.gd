extends RefCounted
## Original Fengli request_action remains the sole combat authority.
## No target selection, cast insertion, cooldown or position writes.
var _source: WeakRef
var _keys: Dictionary = {}
var _serial: int = 0
var _left_physical: bool = false
var _held_suppressed: bool = true
var _generation: int = -1
var last_receipt: Dictionary = {}
const BUFFER_SECONDS:float=.12
var pending:Dictionary={}
func bind(source: Node) -> void:
 if _source != null and is_instance_valid(_source.get_ref()):suspend_input("rebind")
 pending.clear()
 _source = weakref(source)
 _keys.clear(); _left_physical = false; _held_suppressed = true
 _generation = source.encounter_generation
func _sim() -> Node:
 return _source.get_ref() if _source != null and is_instance_valid(_source.get_ref()) else null
func _request(action: String, aim: Vector3) -> Dictionary:
 var source: Node = _sim()
 if source == null:return {"accepted":false,"reason":"unbound"}
 _serial += 1
 last_receipt = source.request_action(action,aim,"fengli_route_os:%d" % _serial).duplicate(true)
 return last_receipt.duplicate(true)
func movement() -> Vector3:
 return Vector3(float(_keys.get(KEY_D,false))-float(_keys.get(KEY_A,false)),0.0,float(_keys.get(KEY_S,false))-float(_keys.get(KEY_W,false))).limit_length(1.0)
func handle_event(event: InputEvent, ground: Vector3 = Vector3.INF, blocked: bool = false, pointer_blocked: bool = false) -> Dictionary:
 var source: Node = _sim()
 if source == null:return {"accepted":false,"reason":"unbound"}
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
  _left_physical = false; _held_suppressed = true
  return {"accepted":true,"reason":"physical_left_released"}
 if event is InputEventKey:
  if event.echo:return {"accepted":false,"reason":"key_echo"}
  var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  if key in [KEY_W,KEY_A,KEY_S,KEY_D] and not event.pressed:
   _keys.erase(key); source.hero.move_intent = movement()
   return {"accepted":true,"reason":"movement_released"}
 if blocked:
  suspend_input("host_input_blocked")
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:_left_physical = true
  return {"accepted":false,"reason":"host_input_blocked"}
 # A HUD click suppresses pointer combat only. It must not forget physically
 # held movement keys; modal/focus boundaries above still clear all input.
 if pointer_blocked:
  pending.clear();_held_suppressed=true
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:_left_physical=true
  return {"accepted":false,"reason":"pointer_input_blocked"}
 if event is InputEventKey:
  var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  if key in [KEY_W,KEY_A,KEY_S,KEY_D]:
   _keys[key] = event.pressed; source.hero.move_intent = movement()
   return {"accepted":true,"reason":"movement_intent"}
  if event.pressed:
   if key == KEY_SHIFT:return _tap("shift",Vector3.INF)
   if key in [KEY_Q,KEY_E,KEY_R]:return _request({KEY_Q:"q",KEY_E:"e",KEY_R:"r"}[key],ground)
 elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
  if _left_physical:return {"accepted":false,"reason":"duplicate_physical_down"}
  _left_physical = true; _generation = source.encounter_generation
  _held_suppressed = source.paused or source.phase != "combat" or source.hero.dead
  if _held_suppressed:return {"accepted":false,"reason":"held_basic_suppressed"}
  return _tap("attack",ground)
 return {"accepted":false,"reason":"unmapped_input"}
func update_held_basic(ground: Vector3, pointer_blocked: bool) -> Dictionary:
 var source: Node = _sim()
 if source == null:return {"accepted":false,"reason":"unbound"}
 if source.paused or source.hero.dead or source.phase != "combat" or source.encounter_generation != _generation or pointer_blocked:
  _held_suppressed = true;pending.clear()
 if not pending.is_empty():
  if float(source.real_time)>float(pending.expires):pending.clear()
  else:
   var result:Dictionary=source.request_action(str(pending.action),pending.aim,"")
   if result.get("accepted",false):pending.clear();return result
   if str(result.get("reason","")) not in ["action_locked","dashing","cooldown","dash_attack_used"]:pending.clear()
 if not _left_physical or _held_suppressed or source.hero.dash_left > 0.0:return {"accepted":false,"reason":"held_basic_suppressed"}
 # Match original arena non-notifying held retry: no permanent command-ID growth.
 return source.request_action("attack",ground,"")
func suspend_input(_reason: String = "boundary") -> void:
 pending.clear()
 _keys.clear(); _held_suppressed = true
 var source: Node = _sim()
 if source != null:source.hero.move_intent = Vector3.ZERO
func focus_lost() -> void:
 suspend_input("focus_lost")

func _tap(action:String,aim:Vector3)->Dictionary:
 pending.clear()
 var result:Dictionary=_request(action,aim)
 var source:Node=_sim()
 if source==null or result.get("accepted",false):return result
 var reason:String=str(result.get("reason",""))
 if reason not in ["action_locked","dashing","cooldown","dash_attack_used"]:return result
 var remaining:float=maxf(float(source.hero.lock_time),maxf(float(source.hero.dash_left),float(source.hero.cooldowns.get(action,0))))
 if remaining<=0 or remaining>BUFFER_SECONDS:return result
 pending={"action":action,"aim":aim,"expires":float(source.real_time)+BUFFER_SECONDS}
 _generation=source.encounter_generation
 return result.merged({"buffered":true},true)
