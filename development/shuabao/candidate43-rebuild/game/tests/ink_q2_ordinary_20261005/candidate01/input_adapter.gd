extends "res://tests/ink_q3_input_growth_20261004/input_adapter.gd"
## Q2 adds only two explicit Q -> fresh LMB placement intents.
## The source owns markers, clocks, cooldowns and damage. Q1/Q3 remain inherited.
var q2_aim: Dictionary = {}
var _q2_mouse_pair := false
var _retired_q2_intent := ""

func bind(sim) -> void:
 super.bind(sim)
 q2_aim = {}; _q2_mouse_pair = false; _retired_q2_intent = ""

func _q2_ready_reason() -> String:
 var sim = _sim.get_ref()
 return sim._q2_input_reason()

func _q2_scope_reason() -> String:
 if q2_aim.is_empty(): return ""
 var sim = _sim.get_ref()
 var reason: String = _q2_ready_reason()
 if not reason.is_empty(): return reason
 if sim.encounter_generation != q2_aim.generation or sim.room_id != q2_aim.room_id: return "stale_preview_room"
 if int(sim.hero.ranks.q) != q2_aim.rank: return "stale_preview_rank"
 var pending: Dictionary = sim.ink_q2_pending
 if q2_aim.phase == "second":
  if pending.is_empty(): return "armed_marker_retired"
  if int(pending.cast_id) != q2_aim.cast_id or not sim.effect_is_current(pending): return "armed_marker_replaced"
  if sim.hero_time >= float(pending.expires_at) - sim.TIME_EPS: return "armed_marker_expired"
 elif not pending.is_empty(): return "marker_phase_changed"
 return ""

func clear_q2_preview(reason: String) -> Dictionary:
 var existed: bool = not q2_aim.is_empty()
 q2_aim = {}; last_cancel_reason = reason
 if existed: _suppress_held = true
 return {"accepted":existed,"reason":reason,"consumed":existed,"preview_only":true}

func synchronize_preview() -> Dictionary:
 var retained: Dictionary = super.synchronize_preview()
 if _sim == null or not is_instance_valid(_sim.get_ref()): return clear_q2_preview("unbound")
 var reason: String = _q2_scope_reason()
 if not reason.is_empty():
  _retired_q2_intent = reason
  return clear_q2_preview(reason)
 return retained

func q2_preview_for_view(point: Vector3) -> Dictionary:
 synchronize_preview()
 if q2_aim.is_empty(): return {"accepted":false,"reason":"q2_not_armed","preview_only":true}
 var shown: Dictionary = _sim.get_ref().q2_preview(point)
 if shown.get("accepted",false) and shown.get("phase","") != q2_aim.phase:
  clear_q2_preview("preview_phase_changed")
  return {"accepted":false,"reason":"preview_phase_changed","preview_only":true}
 shown["armed_identity"] = q2_aim.duplicate(true)
 return shown

func preview(point: Vector3) -> Dictionary:
 # The frozen Q3 rectangle presenter must never interpret a Q2 path as a mountain.
 if not q2_aim.is_empty(): return {"accepted":false,"reason":"q2_uses_source_river_view","preview_only":true}
 return super.preview(point)

func _arm_q2(point: Vector3) -> Dictionary:
 var sim = _sim.get_ref()
 if sim.transaction_active: return {"accepted":false,"reason":"transaction_in_progress","consumed":true}
 if _left_physical: return {"accepted":false,"reason":"mouse_already_held","consumed":true}
 if not q2_aim.is_empty(): return {"accepted":false,"reason":"q2_already_armed","consumed":true}
 var reason: String = _q2_ready_reason()
 if not reason.is_empty(): return {"accepted":false,"reason":reason,"consumed":true}
 if sim.hero.lock_time > sim.TIME_EPS: return {"accepted":false,"reason":"action_locked","consumed":true}
 if sim.ink_q2_pending.is_empty() and sim.hero.cooldowns.q > sim.TIME_EPS: return {"accepted":false,"reason":"cooldown","consumed":true}
 _retired_q2_intent = ""
 q2_aim = {"phase":"first" if sim.ink_q2_pending.is_empty() else "second","generation":sim.encounter_generation,"room_id":sim.room_id,"rank":int(sim.hero.ranks.q),"cast_id":int(sim.ink_q2_pending.get("cast_id",-1))}
 return {"accepted":true,"reason":"q2_armed","consumed":true,"preview_only":true,"preview":q2_preview_for_view(point)}

func _commit_q2(point: Vector3) -> Dictionary:
 if _left_physical: return {"accepted":false,"reason":"duplicate_physical_down","consumed":true}
 _left_physical = true; _gesture_consumed = true; _suppress_held = true; _q2_mouse_pair = true
 var sim = _sim.get_ref()
 _generation = sim.encounter_generation
 var reason: String = _q2_scope_reason()
 if not reason.is_empty():
  clear_q2_preview(reason)
  return {"accepted":false,"reason":reason,"consumed":true}
 var shown: Dictionary = q2_preview_for_view(point)
 if not shown.get("accepted",false):
  clear_q2_preview(str(shown.reason))
  return {"accepted":false,"reason":shown.reason,"consumed":true}
 var intent: Dictionary = q2_aim.duplicate(true)
 q2_aim = {} # Reentrant source callbacks cannot commit this intent twice.
 var result: Dictionary = sim.request_q2(intent.phase,point,_command(),intent.cast_id,intent.generation)
 result["consumed"] = true; result["armed_identity"] = intent
 return result

func handle_event(event: InputEvent, point: Vector3 = Vector3.INF) -> Dictionary:
 if _sim == null or not is_instance_valid(_sim.get_ref()): return {"accepted":false,"reason":"unbound"}
 var was_armed: bool = not q2_aim.is_empty()
 var invalid: String = _q2_scope_reason()
 if not invalid.is_empty():
  _retired_q2_intent = invalid; clear_q2_preview(invalid)
 var sim = _sim.get_ref()
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
  if not event.pressed and _q2_mouse_pair:
   _left_physical = false; _gesture_consumed = false; _suppress_held = false; _q2_mouse_pair = false; _gesture_id = ""
   return {"accepted":false,"reason":"q2_mouse_up_never_fires","consumed":true}
  if event.pressed and ((was_armed and not invalid.is_empty()) or not _retired_q2_intent.is_empty()):
   if _left_physical: return {"accepted":false,"reason":"duplicate_physical_down","consumed":true}
   _left_physical = true; _gesture_consumed = true; _suppress_held = true; _q2_mouse_pair = true
   var retired: String = _retired_q2_intent; _retired_q2_intent = ""
   return {"accepted":false,"reason":retired,"consumed":true}
  if event.pressed and not q2_aim.is_empty(): return _commit_q2(point)
 if event is InputEventKey:
  var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  if code == KEY_Q and sim.hero.loadout.q == "q2":
   if event.echo: return {"accepted":false,"reason":"key_echo","consumed":true}
   return _arm_q2(point) if event.pressed else {"accepted":false,"reason":"q2_key_up_never_fires","consumed":true}
  if code == KEY_ESCAPE and event.pressed and not q2_aim.is_empty(): return clear_q2_preview("escape")
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not q2_aim.is_empty(): return clear_q2_preview("right_down")
 if event is InputEventMouseMotion and not q2_aim.is_empty(): return q2_preview_for_view(point)
 return super.handle_event(event,point)

func update_held_basic(point: Vector3) -> Dictionary:
 synchronize_preview()
 if not q2_aim.is_empty() or _q2_mouse_pair: return {"accepted":false,"reason":"held_basic_suppressed"}
 return super.update_held_basic(point)

func suspend_input(reason: String = "pause") -> void:
 if not q2_aim.is_empty(): _retired_q2_intent = reason
 clear_q2_preview(reason)
 # Keep an outstanding LMB pair until its actual release, like the frozen router.
 super.suspend_input(reason)

func clear_q2_frontdoor_latches() -> void:
 # Only the frontdoor's fresh-event fence may drain physical state wholesale.
 q2_aim = {}; _q2_mouse_pair = false; _retired_q2_intent = ""

func _source_event(event: Dictionary) -> void:
 super._source_event(event)
 if event.get("kind","") in ["encounter_started","encounter_finished","true_dead"]:
  if not q2_aim.is_empty(): _retired_q2_intent = str(event.kind)
  clear_q2_preview(str(event.kind)); _suppress_held = true
 else: synchronize_preview()
