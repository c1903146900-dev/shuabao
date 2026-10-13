extends "res://tests/ink_e1_ordinary_20261005/candidate01/input_adapter.gd"
## R1 intent only: fresh R-down aims; fresh LMB-down submits the source command.
## Inherited real E-up/lost-key/frontdoor ownership remains authoritative.
## No R2, R hex, source-domain, terrain, cooldown or progression ownership here.
var r1_aim: Dictionary = {}
var _r1_key_physical: bool = false
var _r1_mouse_pair: bool = false
var _retired_r1_intent: String = ""
var _r1_last_cancel_reason: String = ""

func bind(sim) -> void:
 super.bind(sim)
 clear_r1_frontdoor_latches()

func _r1_ready_reason() -> String:
 if _sim == null or not is_instance_valid(_sim.get_ref()): return "unbound"
 var sim = _sim.get_ref()
 if sim.phase != "combat" or sim.paused: return "encounter_frozen"
 if sim.hero.dead: return "not_alive"
 if sim.source_rules_hash != sim.EXPECTED_RULES_HASH: return "source_binding_mismatch"
 if sim.hero.loadout.r != "r1" or int(sim.hero.ranks.r) <= 0: return "r1_unlearned"
 if sim._e1_form_current(): return "rain_form_forbids_action"
 if sim._ink_action_controlled("r"): return "controlled"
 if sim.hero.lock_time > sim.TIME_EPS: return "action_locked"
 if sim.hero.dash_left > sim.TIME_EPS: return "dashing"
 if not sim.ink_snow.is_empty(): return "snow_domain_already_active"
 if sim.hero.cooldowns.r > sim.TIME_EPS: return "cooldown"
 return ""

func _r1_scope_reason() -> String:
 if r1_aim.is_empty(): return ""
 var reason: String = _r1_ready_reason()
 if not reason.is_empty(): return reason
 var sim = _sim.get_ref()
 if sim.encounter_generation != r1_aim.generation or sim.room_id != r1_aim.room_id: return "stale_preview_room"
 if int(sim.hero.ranks.r) != int(r1_aim.rank): return "stale_preview_rank"
 return ""

func clear_r1_preview(reason: String, retire_click: bool = true) -> Dictionary:
 var existed: bool = not r1_aim.is_empty()
 r1_aim = {}; _r1_last_cancel_reason = reason
 if existed:
  _suppress_held = true
  if retire_click: _retired_r1_intent = reason
 return {"accepted":existed,"reason":reason,"consumed":existed,"preview_only":true}

func synchronize_preview() -> Dictionary:
 var retained: Dictionary = super.synchronize_preview()
 var reason: String = _r1_scope_reason()
 if not reason.is_empty(): return clear_r1_preview(reason)
 return retained

func r1_preview_for_view(point: Vector3) -> Dictionary:
 synchronize_preview()
 if r1_aim.is_empty(): return {"accepted":false,"reason":"r1_not_armed","preview_only":true}
 # The source alone supplies finite-point admission, the 12m limit and radius.
 var shown: Dictionary = _sim.get_ref().r1_preview(point)
 shown["armed_identity"] = r1_aim.duplicate(true)
 return shown

func _arm_r1(point: Vector3) -> Dictionary:
 var sim = _sim.get_ref()
 if sim.transaction_active: return {"accepted":false,"reason":"transaction_in_progress","consumed":true}
 # Neither a BASIC hold nor a started Q1 drawing can be stolen by R.
 if _left_physical or sim._left_held: return {"accepted":false,"reason":"mouse_already_held","consumed":true}
 if not r1_aim.is_empty(): return {"accepted":false,"reason":"r1_already_armed","consumed":true}
 var reason: String = _r1_ready_reason()
 if not reason.is_empty(): return {"accepted":false,"reason":reason,"consumed":true}
 var identity: Dictionary = {"generation":sim.encounter_generation,"room_id":sim.room_id,"rank":int(sim.hero.ranks.r),"armed_at":sim.hero_time}
 # Only an uncommitted Q intent is replaced. Never cancel a cast or terrain.
 if sim.ink_input.phase != "idle": sim.cancel_ink_preview("replaced_by_r1_aim")
 clear_q2_preview("replaced_by_r1_aim")
 clear_q3_preview("replaced_by_r1_aim")
 _retired_q2_intent = ""; _retired_q3_intent = ""
 _gesture_id = ""; _generation = -1
 _retired_r1_intent = ""; _suppress_held = true
 r1_aim = identity
 # Source Q1 cancellation emits callbacks; scope must survive those too.
 reason = _r1_scope_reason()
 if not reason.is_empty():
  clear_r1_preview(reason)
  return {"accepted":false,"reason":reason,"consumed":true,"preview_only":true}
 return {"accepted":true,"reason":"r1_armed","consumed":true,"preview_only":true,"preview":r1_preview_for_view(point)}

func _claim_r1_mouse_pair() -> void:
 _left_physical = true; _gesture_consumed = true; _suppress_held = true
 _r1_mouse_pair = true; _gesture_id = ""
 _generation = _sim.get_ref().encounter_generation

func _commit_r1(point: Vector3) -> Dictionary:
 if _left_physical: return {"accepted":false,"reason":"duplicate_physical_down","consumed":true}
 _claim_r1_mouse_pair()
 var sim = _sim.get_ref()
 var reason: String = "transaction_in_progress" if sim.transaction_active else _r1_scope_reason()
 if not reason.is_empty():
  clear_r1_preview(reason, false)
  return {"accepted":false,"reason":reason,"consumed":true}
 var shown: Dictionary = sim.r1_preview(point)
 if not shown.get("accepted",false):
  clear_r1_preview(str(shown.get("reason","invalid_r1_preview")), false)
  return {"accepted":false,"reason":shown.get("reason","invalid_r1_preview"),"consumed":true}
 var identity: Dictionary = r1_aim.duplicate(true)
 r1_aim = {}; _retired_r1_intent = ""
 # Clear before callbacks: this physical pair can dispatch R only once.
 var result: Dictionary = sim.request_action("r",point,_command())
 result["consumed"] = true; result["armed_identity"] = identity
 return result

func handle_event(event: InputEvent, point: Vector3 = Vector3.INF) -> Dictionary:
 if _sim == null or not is_instance_valid(_sim.get_ref()): return {"accepted":false,"reason":"unbound"}
 synchronize_preview()
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
  if _r1_mouse_pair:
   if event.pressed: return {"accepted":false,"reason":"duplicate_physical_down","consumed":true}
   _left_physical = false; _gesture_consumed = false; _suppress_held = false
   _r1_mouse_pair = false; _gesture_id = ""; _generation = -1
   return {"accepted":false,"reason":"r1_mouse_up_never_fires","consumed":true}
  if event.pressed and not _retired_r1_intent.is_empty():
   if _left_physical: return {"accepted":false,"reason":"duplicate_physical_down","consumed":true}
   _claim_r1_mouse_pair()
   var retired: String = _retired_r1_intent; _retired_r1_intent = ""
   return {"accepted":false,"reason":retired,"consumed":true}
  if event.pressed and not r1_aim.is_empty(): return _commit_r1(point)
  # A stray up while aiming has no authority to commit or retire the preview.
  if not event.pressed and not r1_aim.is_empty(): return {"accepted":false,"reason":"r1_unpaired_mouse_up","consumed":true}
 if event is InputEventKey:
  var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  if code == KEY_R:
   if event.echo: return {"accepted":false,"reason":"key_echo","consumed":true}
   if not event.pressed:
    _r1_key_physical = false
    return {"accepted":false,"reason":"r1_key_up_never_fires","consumed":true}
   if _r1_key_physical: return {"accepted":false,"reason":"duplicate_r_down","consumed":true}
   _r1_key_physical = true
   return _arm_r1(point)
  if code == KEY_Q and event.pressed and not event.echo:
   clear_r1_preview("replaced_by_q_aim")
   var result: Dictionary = super.handle_event(event,point)
   # A successfully armed Q owns the next fresh click. A failed replacement
   # leaves the retired R click fenced, so it cannot become an ordinary shot.
   if result.get("accepted",false): _retired_r1_intent = ""
   return result
  if code == KEY_ESCAPE and event.pressed and not r1_aim.is_empty(): return clear_r1_preview("escape")
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not r1_aim.is_empty(): return clear_r1_preview("right_down")
 if event is InputEventMouseMotion and not r1_aim.is_empty(): return r1_preview_for_view(point)
 return super.handle_event(event,point)

func update_held_basic(point: Vector3) -> Dictionary:
 synchronize_preview()
 if not r1_aim.is_empty() or _r1_mouse_pair or not _retired_r1_intent.is_empty(): return {"accepted":false,"reason":"held_basic_suppressed"}
 return super.update_held_basic(point)

func suspend_input(reason: String = "pause") -> void:
 _r1_key_physical = false
 clear_r1_preview(reason)
 # Preserve an outstanding mouse pair until real up. Super retains E ownership
 # and its real late E-up / chooser release behavior; never synthesize E-up.
 super.suspend_input(reason)

func clear_r1_frontdoor_latches() -> void:
 # Host calls this ONLY after its existing fresh-event fence drained input.
 # This is input state, not permission to cancel a committed snow domain.
 r1_aim = {}; _r1_key_physical = false; _r1_mouse_pair = false
 _retired_r1_intent = ""; _r1_last_cancel_reason = ""

func r1_input_snapshot() -> Dictionary:
 return {"armed":not r1_aim.is_empty(),"aim":r1_aim.duplicate(true),"physical_down":_r1_key_physical,"mouse_pair":_r1_mouse_pair,"retired_intent":_retired_r1_intent,"last_cancel_reason":_r1_last_cancel_reason,"left_physical":_left_physical,"held_suppressed":_suppress_held}

func _source_event(event: Dictionary) -> void:
 super._source_event(event)
 if event.get("kind","") in ["encounter_started","encounter_finished","true_dead"]:
  clear_r1_preview(str(event.kind)); _suppress_held = true
 else: synchronize_preview()
