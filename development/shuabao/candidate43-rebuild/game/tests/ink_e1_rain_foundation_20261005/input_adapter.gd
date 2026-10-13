extends "res://tests/ink_q3_input_growth_20261004/input_adapter.gd"
## Isolated physical E-down/up extension, never enabled by the normal host.
var _e_physical: bool = false
var _e_cast: Dictionary = {}
func bind(sim) -> void:
 super.bind(sim)
 _e_physical = false; _e_cast = {}
func _ready_reason() -> String:
 if _sim != null and is_instance_valid(_sim.get_ref()) and _sim.get_ref()._e1_form_current(): return "rain_form_forbids_action"
 return super._ready_reason()
func handle_event(event: InputEvent, mouse_ground: Vector3 = Vector3.INF) -> Dictionary:
 if _sim == null or not is_instance_valid(_sim.get_ref()): return {"accepted":false, "reason":"unbound"}
 var sim = _sim.get_ref()
 if event is InputEventKey:
  var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  if code == KEY_E:
   if event.echo: return {"accepted":false, "reason":"key_echo", "consumed":true}
   if event.pressed:
    if _e_physical: return {"accepted":false, "reason":"duplicate_e_down", "consumed":true}
    _e_physical = true
    var result: Dictionary = sim.request_ink_input("e_down", mouse_ground, _command())
    if result.get("accepted", false) and not sim.ink_rain.is_empty():
     _e_cast = {"cast_id":sim.ink_rain.cast_id, "generation":sim.encounter_generation, "room_id":sim.room_id}
    result["consumed"] = true
    return result
   if not _e_physical: return {"accepted":false, "reason":"unpaired_e_up", "consumed":true}
   _e_physical = false
   var owned: Dictionary = _e_cast; _e_cast = {}
   if owned.is_empty() or sim.ink_rain.is_empty() or owned.cast_id != sim.ink_rain.cast_id or owned.generation != sim.encounter_generation or owned.room_id != sim.room_id: return {"accepted":false, "reason":"retired_e_up", "consumed":true}
   return sim.request_ink_input("e_up", mouse_ground, _command(), "", int(owned.generation))
 return super.handle_event(event, mouse_ground)
func route_event(event: InputEvent, ground_projector: Callable, keyboard_ground: Vector3 = Vector3.INF, gui_blocked: bool = false) -> Dictionary:
 # An actual E-up must be retained even if a modal opened after its paired down.
 if event is InputEventKey:
  var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  if code == KEY_E and not event.pressed: return handle_event(event, keyboard_ground)
 return super.route_event(event, ground_projector, keyboard_ground, gui_blocked)
