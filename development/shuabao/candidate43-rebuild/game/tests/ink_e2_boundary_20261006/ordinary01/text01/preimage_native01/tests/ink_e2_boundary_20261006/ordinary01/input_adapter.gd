extends "res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/input_adapter.gd"
## E2 owns only physical E edges. Q/R previews, their mouse pairs, and E1's
## real release forwarding remain inherited. A menu never synthesizes E-up.
var _e2_release_required: bool = false
var _e2_last_receipt: Dictionary = {}

func bind(source) -> void:
 super.bind(source)
 _e2_release_required = false; _e2_last_receipt = {}

func _e2_selected() -> bool:
 return _sim != null and is_instance_valid(_sim.get_ref()) and _sim.get_ref().hero.loadout.e == "e2"

func observe_blocked_e2_down(event: InputEvent) -> void:
 if not _e2_selected() or not event is InputEventKey: return
 var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
 if code == KEY_E and event.pressed and not event.echo:
  _e2_release_required = true

func handle_event(event: InputEvent, mouse_ground: Vector3 = Vector3.INF) -> Dictionary:
 if _e2_selected() and event is InputEventKey:
  var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  if code == KEY_E:
   if event.echo: return {"accepted":false,"reason":"key_echo","consumed":true}
   if not event.pressed:
    _e_physical = false; _e_cast = {}; _e2_release_required = false
    return {"accepted":false,"reason":"boat_key_up_has_no_effect","consumed":true}
   if _e_physical or _e2_release_required:
    return {"accepted":false,"reason":"e2_fresh_release_required","consumed":true}
   # Own the edge before source callbacks. A rejected action still consumes
   # this key pair; repeats cannot launch or board later when admission changes.
   _e_physical = true; _e2_release_required = true
   var result: Dictionary = _sim.get_ref().request_ink_input("e_down",mouse_ground,_command())
   result["consumed"] = true
   _e2_last_receipt = result.duplicate(true)
   return result
 return super.handle_event(event,mouse_ground)

func route_event(event: InputEvent, ground_projector: Callable, keyboard_ground: Vector3 = Vector3.INF, gui_blocked: bool = false) -> Dictionary:
 if gui_blocked: observe_blocked_e2_down(event)
 return super.route_event(event,ground_projector,keyboard_ground,gui_blocked)

func suspend_input(reason: String = "pause") -> void:
 if _e2_selected() and _e_physical: _e2_release_required = true
 super.suspend_input(reason)

func e1_release_is_owned() -> bool:
 # The established host pre-GUI E-up route is also the E2 key-latch drain.
 if _e2_selected(): return _e_physical or _e2_release_required
 return super.e1_release_is_owned()

func queue_owned_boundary_e_up(event: InputEvent) -> Dictionary:
 if not _e2_selected(): return super.queue_owned_boundary_e_up(event)
 if not event is InputEventKey: return {"accepted":false,"reason":"real_e_key_up_required"}
 var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
 if code != KEY_E or event.pressed or event.echo: return {"accepted":false,"reason":"real_e_key_up_required"}
 return handle_event(event,Vector3.INF)

func e2_input_snapshot() -> Dictionary:
 return {"physical_down":_e_physical,"release_required":_e2_release_required,"last_receipt":_e2_last_receipt.duplicate(true),"source_owns_boat_and_clocks":true}
