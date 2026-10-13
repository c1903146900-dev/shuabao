extends "res://tests/ink_e2_boundary_20261006/ordinary01/input_adapter.gd"
## Ordinary E3 adds fresh physical E edges only. Each down confirms the current
## mouse-ground A/B point; no LMB, key repeat, release or menu resume can commit.
## Existing E1 release ownership, E2 boat latch and Q/R intents stay inherited.
var _e3_release_required: bool = false
var _e3_last_receipt: Dictionary = {}

func bind(source) -> void:
 super.bind(source)
 _e3_release_required = false; _e3_last_receipt = {}

func _e3_selected() -> bool:
 return _sim != null and is_instance_valid(_sim.get_ref()) and _sim.get_ref().hero.loadout.e == "e3"

func observe_blocked_e3_down(event: InputEvent) -> void:
 if not _e3_selected() or not event is InputEventKey: return
 var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
 if code == KEY_E and event.pressed and not event.echo: _e3_release_required = true

func _e3_intent_reason() -> String:
 var source = _sim.get_ref()
 # A held BASIC or started Q drawing keeps its real mouse pair. An armed Q/R
 # keeps its next confirmation click; E cannot silently steal either intent.
 if _left_physical or source._left_held: return "mouse_already_held"
 if not q2_aim.is_empty() or not q3_aim.is_empty() or not r1_aim.is_empty() or source.ink_input.phase != "idle": return "other_skill_preview_active"
 if _q2_mouse_pair or _q3_mouse_pair or _r1_mouse_pair: return "mouse_pair_owned"
 return ""

func handle_event(event: InputEvent, mouse_ground: Vector3 = Vector3.INF) -> Dictionary:
 if event is InputEventKey:
  var released_code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  # A real release also drains an E3 latch retained across a legal loadout
  # change. It still goes through the current E1/E2 owner below.
  if released_code == KEY_E and not event.pressed and not event.echo: _e3_release_required = false
 if _e3_selected() and event is InputEventKey:
  var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  if code == KEY_E:
   if event.echo: return {"accepted":false,"reason":"key_echo","consumed":true}
   if not event.pressed:
    _e_physical = false; _e_cast = {}; _e3_release_required = false
    return {"accepted":false,"reason":"frame_key_up_has_no_effect","consumed":true}
   if _e_physical or _e3_release_required: return {"accepted":false,"reason":"e3_fresh_release_required","consumed":true}
   # Claim even a rejected down before any source callback. A genuine E-up
   # is required before a second placement or a retry at a different point.
   _e_physical = true; _e3_release_required = true
   synchronize_preview()
   var reason: String = _e3_intent_reason()
   var result: Dictionary
   if not reason.is_empty(): result = {"accepted":false,"reason":reason}
   else: result = _sim.get_ref().request_ink_input("e_down",mouse_ground,_command())
   result["consumed"] = true; _e3_last_receipt = result.duplicate(true)
   return result
 return super.handle_event(event,mouse_ground)

func route_event(event: InputEvent, ground_projector: Callable, keyboard_ground: Vector3 = Vector3.INF, gui_blocked: bool = false) -> Dictionary:
 if gui_blocked: observe_blocked_e3_down(event)
 return super.route_event(event,ground_projector,keyboard_ground,gui_blocked)

func suspend_input(reason: String = "pause") -> void:
 if _e3_selected() and _e_physical: _e3_release_required = true
 super.suspend_input(reason)

func e1_release_is_owned() -> bool:
 # The inherited pre-GUI and frontdoor real E-up route drains this latch too.
 if _e3_selected(): return _e_physical or _e3_release_required
 return super.e1_release_is_owned()

func queue_owned_boundary_e_up(event: InputEvent) -> Dictionary:
 if not _e3_selected(): return super.queue_owned_boundary_e_up(event)
 if not event is InputEventKey: return {"accepted":false,"reason":"real_e_key_up_required"}
 var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
 if code != KEY_E or event.pressed or event.echo: return {"accepted":false,"reason":"real_e_key_up_required"}
 return handle_event(event,Vector3.INF)

func e3_preview_for_view(point: Vector3) -> Dictionary:
 if not _e3_selected(): return {"accepted":false,"reason":"e3_not_selected","preview_only":true}
 synchronize_preview()
 var source = _sim.get_ref()
 var reason: String = _e3_intent_reason()
 if not reason.is_empty() or not point.is_finite(): return {"accepted":false,"reason":reason if not reason.is_empty() else "manual_aim_required","preview_only":true}
 if int(source.hero.ranks.e) <= 0: return {"accepted":false,"reason":"unlearned","preview_only":true}
 if source.paused or source.phase != "combat" or source.hero.dead: return {"accepted":false,"reason":"encounter_frozen","preview_only":true}
 if source.hero.lock_time > source.TIME_EPS or source.hero.dash_left > source.TIME_EPS: return {"accepted":false,"reason":"action_locked","preview_only":true}
 if source.ink_frames.is_empty() and source.hero.cooldowns.e > source.TIME_EPS: return {"accepted":false,"reason":"cooldown","preview_only":true}
 var shown: Dictionary = source.e3_preview(point).duplicate(true)
 # These fields are detached display geometry, never an alternate admission.
 shown["position"] = Vector3(point.x,0.0,point.z)
 shown["radius"] = float(source.ink_frames.radius) if not source.ink_frames.is_empty() else source.v("E3-3",int(source.hero.ranks.e))
 shown["generation"] = source.encounter_generation; shown["room_id"] = source.room_id
 shown["source_time"] = source.hero_time
 shown["frame_id"] = str(source.ink_frames.get("frame_id",""))
 shown["frame_phase"] = str(source.ink_frames.get("phase","none"))
 shown["placement_label"] = "B" if shown.frame_phase == "first" else "A"
 shown["displayable"] = shown.frame_phase in ["none","first"]
 return shown

func e3_input_snapshot() -> Dictionary:
 return {"physical_down":_e_physical,"release_required":_e3_release_required,"last_receipt":_e3_last_receipt.duplicate(true),"confirmation":"fresh_E_down_at_current_mouse_ground","source_owns_frames_and_clocks":true}
