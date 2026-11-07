extends Node
# Fixed Fengli entry. Native Host/Session own all gameplay authority and close results.
const Generation = preload("res://release_generation_20261020/generation.gd")
const HERO := "fengli"
const RENDER_MODE := "fengli_2d_pose_cache_v1"
const ROOM := "res://fengli_route_20261024/room.tscn"
const KEYS := [KEY_W,KEY_A,KEY_S,KEY_D,KEY_Q,KEY_E,KEY_R,KEY_SHIFT,KEY_ENTER,KEY_KP_ENTER,KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_F5,KEY_F8,KEY_K,KEY_P,KEY_ESCAPE,KEY_M,KEY_F10]
enum Screen { MENU, RUN, CONFIRM, TRANSITION, FAULT }
class InputFence extends Node:
 var entry: Node
 func _input(event: InputEvent) -> void:
  entry.filter_session_input(event)
var screen := Screen.MENU
var active_room: Node3D
var _busy := false
var _launch_pending := false
var _layer: CanvasLayer
var _menu: VBoxContainer
var _message: Label
var _start: Button
var _resume: Button
var _pause: Button
var _confirm: Button
var _cancel: Button
var _fence: Node
var _blocked_keys: Dictionary = {}
var _blocked_mouse: Dictionary = {}
var _pause_nodes: Array = []
var _pause_layers: Array = []
var _room_visible := true
var _root_mode := Node.PROCESS_MODE_INHERIT
var _room_focus: WeakRef
func _ready() -> void:
 _layer = CanvasLayer.new(); _layer.layer = 200; add_child(_layer)
 _menu = VBoxContainer.new(); _menu.position = Vector2(40,40); _menu.size = Vector2(530,300); _layer.add_child(_menu)
 var title := Label.new(); title.text = "风厉 · 独立试玩"; _menu.add_child(title)
 _message = Label.new(); _message.text = "新对局从头开始，不继承本局成长。"; _menu.add_child(_message)
 _start = _button("开始新对局",func(): request_start(HERO,ROOM))
 _resume = _button("继续当前对局",resume_run); _resume.disabled = true
 _confirm = _button("结束当前对局并重新开始",confirm_new_run); _confirm.hide()
 _cancel = _button("取消",cancel_new_run); _cancel.hide()
 _pause = Button.new(); _pause.text = "返回菜单"; _pause.position = Vector2(1070,66); _pause.pressed.connect(open_menu); _layer.add_child(_pause); _pause.hide()
 _fence = InputFence.new(); _fence.entry = self; add_child(_fence)
 var admitted: Dictionary = _authorize(HERO,ROOM)
 if not admitted.accepted: _fault(str(admitted.reason))
func _authorize(hero_id: String, room_path: String) -> Dictionary:
 var result: Dictionary = Generation.authorize_entry(self,hero_id,room_path)
 if result.get("accepted",false) and result.get("render_mode","") != RENDER_MODE:
  return Generation.deny("fixed_fengli_render_mode_required")
 return result
func _button(label: String, callback: Callable) -> Button:
 var button := Button.new(); button.text = label; button.pressed.connect(callback); _menu.add_child(button); return button
func request_start(hero_id: String = HERO, room_path: String = ROOM) -> Dictionary:
 if hero_id != HERO or room_path != ROOM: return Generation.deny("fengli_only_entry_required")
 if _busy or screen != Screen.MENU: return Generation.deny("menu_boundary_required")
 var admitted: Dictionary = _authorize(hero_id,room_path)
 if not admitted.accepted: _fault(str(admitted.reason)); return admitted
 if is_instance_valid(active_room):
  screen = Screen.CONFIRM; _confirm.disabled = false; _cancel.disabled = false; _confirm.show(); _cancel.show(); _start.disabled = true; _resume.disabled = true
  _message.text = "结束当前对局？本局成长不会继承，也不会因此结算奖励。"
  _cancel.grab_focus()
 else:
  screen = Screen.TRANSITION; _launch_pending = true; _launch_fresh.call_deferred(hero_id,room_path)
 return {"accepted":true,"reason":"entry_request_only"}
func cancel_new_run() -> void:
 if screen != Screen.CONFIRM: return
 screen = Screen.MENU; _confirm.hide(); _cancel.hide(); _start.disabled = false; _resume.disabled = false; _resume.grab_focus()
 if is_instance_valid(active_room): _message.text = "对局已暂停，可继续当前对局。"
func confirm_new_run() -> void:
 if screen != Screen.CONFIRM or _busy: return
 screen = Screen.TRANSITION; _launch_pending = true; _confirm.disabled = true; _cancel.disabled = true
 _launch_fresh.call_deferred(HERO,ROOM)
func _launch_fresh(hero_id: String, room_path: String = ROOM) -> void:
 # Direct invocation must reject foreign selectors BEFORE all loading/instantiation.
 if hero_id != HERO or room_path != ROOM: return
 if _busy or screen != Screen.TRANSITION or not _launch_pending: return
 _launch_pending = false # Consume this entry operation exactly once, before any yield/load.
 var admitted: Dictionary = _authorize(hero_id,room_path)
 if not admitted.accepted: _fault(str(admitted.reason)); return
 _busy = true; _message.text = "正在载入风厉关卡…"; _start.disabled = true; _resume.disabled = true
 var error := ResourceLoader.load_threaded_request(ROOM,"PackedScene",false)
 if error != OK: _recover("关卡载入请求失败，当前对局仍保留。"); return
 while true:
  var status := ResourceLoader.load_threaded_get_status(ROOM)
  if status == ResourceLoader.THREAD_LOAD_LOADED: break
  if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS: _recover("关卡载入失败，当前对局仍保留。"); return
  await get_tree().process_frame
  if not is_inside_tree(): return
 var packed: Resource = ResourceLoader.load_threaded_get(ROOM)
 if not packed is PackedScene: _recover("关卡资源类型无效。"); return
 # Recheck fixed manifest/readers after asynchronous resource work and before construction.
 admitted = _authorize(HERO,ROOM)
 if not admitted.accepted: _fault(str(admitted.reason)); return
 var candidate: Node = packed.instantiate()
 if not candidate is Node3D or candidate.get_script() != admitted.host_script or candidate.get_script().resource_path != Generation.ROOTS.host:
  candidate.free(); _recover("风厉关卡入口身份不匹配。"); return
 for method: String in ["frontdoor_can_suspend","frontdoor_clear_input","frontdoor_suspend","frontdoor_resume","frontdoor_stop_audio","frontdoor_close_run"]:
  if not candidate.has_method(method): candidate.free(); _recover("风厉关卡生命周期接口缺失。"); return
 # Candidate is not in the tree: its Host _ready/Sim/Session have not run yet.
 _capture_held_inputs()
 if is_instance_valid(active_room):
  if not active_room.frontdoor_close_run("fengli_confirmed_new_run"):
   candidate.free(); _recover("当前动作尚未结束，当前对局仍保留。"); return
  active_room.frontdoor_clear_input(); active_room.frontdoor_stop_audio()
  active_room.free()
 active_room = null; _pause_nodes.clear(); _pause_layers.clear(); _room_focus = null
 await get_tree().process_frame
 if not is_inside_tree(): candidate.free(); return
 admitted = _authorize(HERO,ROOM)
 if not admitted.accepted: candidate.free(); _fault(str(admitted.reason)); return
 # No second gameplay model, save restore, synthetic receipt, or old Yan entry.
 active_room = candidate
 add_child(active_room)
 move_child(_fence,get_child_count()-1)
 if not str(active_room.startup_session_error).is_empty() or not str(active_room.floor_error).is_empty():
  # Hold the actual failed Host. Never guess a close result or free partially bound owners.
  active_room.frontdoor_clear_input(); active_room.frontdoor_stop_audio()
  active_room.process_mode = Node.PROCESS_MODE_DISABLED
  _fault("风厉启动失败："+str(active_room.startup_session_error)+" "+str(active_room.floor_error)); return
 _capture_held_inputs(); active_room.frontdoor_clear_input()
 _confirm.disabled = false; _cancel.disabled = false; _confirm.hide(); _cancel.hide()
 _menu.hide(); _pause.show(); _busy = false; screen = Screen.RUN
 var focus := get_viewport().gui_get_focus_owner()
 if focus != null: focus.release_focus()
func _recover(message: String) -> void:
 _busy = false; _launch_pending = false; screen = Screen.MENU; _message.text = message
 _confirm.hide(); _cancel.hide(); _confirm.disabled = false; _cancel.disabled = false
 _start.disabled = false; _resume.disabled = not is_instance_valid(active_room)
func _fault(message: String) -> void:
 _busy = false; _launch_pending = false; screen = Screen.FAULT; _message.text = message
 _menu.show(); _start.disabled = true; _resume.disabled = true; _confirm.hide(); _cancel.hide(); _pause.hide()
func open_menu() -> void:
 if screen != Screen.RUN or _busy or not is_instance_valid(active_room) or not active_room.frontdoor_can_suspend(): return
 screen = Screen.TRANSITION; _capture_held_inputs(); active_room.frontdoor_clear_input()
 var focus := get_viewport().gui_get_focus_owner()
 _room_focus = weakref(focus) if focus != null and focus != _pause else null
 _root_mode = active_room.process_mode
 active_room.process_mode = Node.PROCESS_MODE_DISABLED; _pause.hide()
 # Drain queued native commands before taking the pause/layer snapshot.
 _finish_open_menu.call_deferred()
func _finish_open_menu() -> void:
 if screen != Screen.TRANSITION or _busy or _launch_pending or not is_instance_valid(active_room): return
 # Queued commands can change the native boundary after open_menu's preflight.
 if not active_room.frontdoor_can_suspend():
  active_room.frontdoor_clear_input()
  active_room.process_mode = _root_mode
  _room_focus = null; screen = Screen.RUN; _pause.show()
  return
 active_room.frontdoor_suspend(); active_room.frontdoor_stop_audio(); active_room.frontdoor_clear_input()
 _room_visible = active_room.visible; active_room.hide(); _pause_nodes.clear(); _pause_layers.clear()
 _suspend_node(active_room); _pause_nodes[0].mode = _root_mode
 screen = Screen.MENU; _menu.show(); _start.disabled = false; _resume.disabled = false; _resume.grab_focus()
 if is_instance_valid(active_room): _message.text = "对局已暂停，可继续当前对局。"
func _suspend_node(node: Node) -> void:
 _pause_nodes.append({"node":node,"mode":node.process_mode}); node.process_mode = Node.PROCESS_MODE_DISABLED
 if node is CanvasLayer: _pause_layers.append({"node":node,"visible":node.visible}); node.hide()
 for child: Node in node.get_children(): _suspend_node(child)
func resume_run() -> void:
 if screen != Screen.MENU or _busy or not is_instance_valid(active_room): return
 var admitted: Dictionary = _authorize(HERO,ROOM)
 if not admitted.accepted: _fault(str(admitted.reason)); return
 screen = Screen.TRANSITION; _capture_held_inputs(); active_room.frontdoor_clear_input()
 for item: Dictionary in _pause_nodes:
  if is_instance_valid(item.node): item.node.process_mode = item.mode
 for item: Dictionary in _pause_layers:
  if is_instance_valid(item.node): item.node.visible = item.visible
 _pause_nodes.clear(); _pause_layers.clear(); active_room.visible = _room_visible
 active_room.frontdoor_resume(); _menu.hide(); _pause.show(); screen = Screen.RUN
 var focus := get_viewport().gui_get_focus_owner()
 if focus != null: focus.release_focus()
 if _room_focus != null:
  var previous: Variant = _room_focus.get_ref()
  if is_instance_valid(previous) and previous.is_visible_in_tree(): previous.grab_focus()
 _room_focus = null
func _capture_held_inputs() -> void:
 for key: int in KEYS:
  if Input.is_physical_key_pressed(key) or Input.is_key_pressed(key): _blocked_keys[key] = true
 for button: int in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
  if Input.is_mouse_button_pressed(button): _blocked_mouse[button] = true
func filter_session_input(event: InputEvent) -> void:
 if event is InputEventKey:
  var key: int = event.physical_keycode if event.physical_keycode else event.keycode
  if screen != Screen.RUN:
   if key in KEYS:
    if event.pressed: _blocked_keys[key] = true
    else: _blocked_keys.erase(key)
   if key == KEY_ESCAPE and event.pressed and not event.echo:
    if screen == Screen.CONFIRM: cancel_new_run()
    elif screen == Screen.MENU: resume_run()
    get_viewport().set_input_as_handled()
  elif _blocked_keys.has(key):
   if not event.pressed: _blocked_keys.erase(key)
   get_viewport().set_input_as_handled()
 elif event is InputEventMouseButton:
  # Forward only real releases, including those consumed by the menu filter.
  if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and is_instance_valid(active_room) and active_room.has_method("frontdoor_observe_pointer_release"):
   active_room.frontdoor_observe_pointer_release(event)
  if screen != Screen.RUN:
   if event.pressed: _blocked_mouse[event.button_index] = true
   else: _blocked_mouse.erase(event.button_index)
  elif _blocked_mouse.has(event.button_index):
   if not event.pressed: _blocked_mouse.erase(event.button_index)
   get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
  if is_instance_valid(active_room): active_room.frontdoor_clear_input()
  _blocked_keys.clear(); _blocked_mouse.clear()

func _process(_delta:float)->void:
 # Visibility only: never invoke admission, snapshot, pause or native close here.
 if is_instance_valid(_pause):
  _pause.visible=screen==Screen.RUN and not _busy and is_instance_valid(active_room) and not active_room.frontdoor_shop_modal_open()
