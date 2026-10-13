extends "res://tests/ink_e1_ordinary_20261005/candidate01/input_base.gd"
## Lost-key recovery only. Suspension never synthesizes E-up or ends the form.
func _owned_e_current() -> bool:
 if _sim == null or not is_instance_valid(_sim.get_ref()) or _e_cast.is_empty(): return false
 var sim = _sim.get_ref()
 return sim._e1_form_current() and int(_e_cast.cast_id) == int(sim.ink_rain.cast_id) and int(_e_cast.generation) == sim.encounter_generation and str(_e_cast.room_id) == sim.room_id

func suspend_input(reason: String = "pause") -> void:
 _e_physical = false
 # Preserve exact surviving ownership so a genuinely delivered late E-up can
 # still release it. A stale/dead/expired form is never substituted by a new one.
 if not _owned_e_current(): _e_cast = {}
 super.suspend_input(reason)

func handle_event(event: InputEvent, mouse_ground: Vector3 = Vector3.INF) -> Dictionary:
 if event is InputEventKey:
  var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  if code == KEY_E and not event.pressed and not event.echo and not _e_physical and not _e_cast.is_empty():
   var owned: Dictionary = _e_cast
   var valid: bool = _owned_e_current()
   _e_cast = {}
   if not valid: return {"accepted":false, "reason":"retired_e_up", "consumed":true}
   return _sim.get_ref().request_ink_input("e_up", mouse_ground, _command(), "", int(owned.generation))
 return super.handle_event(event, mouse_ground)

func e1_release_is_owned() -> bool:
 return _e_physical or _owned_e_current()

func e1_input_snapshot() -> Dictionary:
 return {"physical_down":_e_physical,"owns_current_form":_owned_e_current(),"cast":_e_cast.duplicate(true)}

func queue_owned_boundary_e_up(event: InputEvent) -> Dictionary:
 if not event is InputEventKey: return {"accepted":false,"reason":"real_e_key_up_required"}
 var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
 if code != KEY_E or event.pressed or event.echo: return {"accepted":false,"reason":"real_e_key_up_required"}
 if not _owned_e_current():
  _e_physical = false; _e_cast = {}
  return {"accepted":false,"reason":"retired_boundary_e_up"}
 var owned: Dictionary = _e_cast.duplicate(true)
 var result: Dictionary = _sim.get_ref().request_e1_boundary_release(owned,_command())
 if result.get("accepted",false):
  _e_physical = false; _e_cast = {}
 return result
