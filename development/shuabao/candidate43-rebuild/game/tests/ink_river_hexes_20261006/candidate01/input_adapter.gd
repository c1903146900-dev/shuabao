extends "res://tests/ink_r2_ordinary_20261006/candidate01/input_adapter.gd"
## Authored interaction: Ctrl + fresh LMB adds a corner only in Q2 B preview.
## One inherited mouse pair; no extra input clock, source marker or cast owner.

func handle_event(event: InputEvent, point: Vector3 = Vector3.INF) -> Dictionary:
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.ctrl_pressed:
  if _sim != null and is_instance_valid(_sim.get_ref()) and not q2_aim.is_empty() and q2_aim.phase == "second" and r1_aim.is_empty() and q3_aim.is_empty():
   return _commit_q2_corner(point)
 return super.handle_event(event,point)

func _commit_q2_corner(point: Vector3) -> Dictionary:
 if _left_physical: return {"accepted":false,"reason":"duplicate_physical_down","consumed":true}
 # Claim before all checks/callbacks. Even a rejected corner cannot become B
 # or BASIC, and only its actual LMB-up drains this inherited pair.
 _left_physical = true; _gesture_consumed = true; _suppress_held = true; _q2_mouse_pair = true
 var source = _sim.get_ref()
 _generation = source.encounter_generation
 var reason: String = "transaction_in_progress" if source.transaction_active else _q2_scope_reason()
 if not reason.is_empty():
  _retired_q2_intent = reason
  clear_q2_preview(reason)
  return {"accepted":false,"reason":reason,"consumed":true}
 var identity: Dictionary = q2_aim.duplicate(true)
 var result: Dictionary = source.request_q2("corner",point,_command(),int(identity.cast_id),int(identity.generation))
 result["consumed"] = true; result["armed_identity"] = identity
 # The B preview remains armed after a legal/rejected corner. Source events
 # still retire it on expiry, death, room change, rank or loadout change.
 synchronize_preview()
 return result

func q2_preview_for_view(point: Vector3) -> Dictionary:
 var shown: Dictionary = super.q2_preview_for_view(point)
 if not shown.get("accepted",false) or _sim == null or not is_instance_valid(_sim.get_ref()): return shown
 var source = _sim.get_ref()
 shown["corner_input"] = "Ctrl+fresh_LMB"
 shown["corners_used"] = maxi(0,source.ink_q2_pending.get("path",[]).size()-1)
 shown["corner_limit"] = 2
 shown["corner_available"] = shown.get("phase","") == "second" and source.hx("yanguizhou_h03") and int(shown.corners_used)<2
 return shown
