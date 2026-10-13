extends "res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_input_adapter.gd"
## Q1 is inherited byte-for-byte. Q3 adds a read-only, source-identity-bound aim.
## This object owns only input intent. It never owns terrain, clocks or SP.
var q3_aim: Dictionary = {}
var _q3_mouse_pair: bool = false
var _retired_q3_intent: String = ""
var last_cancel_reason: String = ""

func bind(sim) -> void:
 if _sim != null and is_instance_valid(_sim.get_ref()):
  var previous = _sim.get_ref()
  if previous.combat_event.is_connected(_source_event): previous.combat_event.disconnect(_source_event)
 super.bind(sim)
 q3_aim = {}; _q3_mouse_pair = false; last_cancel_reason = ""; _retired_q3_intent = ""
 sim.combat_event.connect(_source_event)

func route_event(event: InputEvent, ground_projector: Callable, keyboard_ground: Vector3 = Vector3.INF, gui_blocked: bool = false) -> Dictionary:
 # Host calls this after its current viewport/focus/STOP-Control validation.
 # Every mouse event uses THIS event.position, including a down without motion.
 var ground: Vector3 = keyboard_ground
 if event is InputEventMouse:
  if not ground_projector.is_valid() or not event.position.is_finite(): ground = Vector3.INF
  else: ground = ground_projector.call(event.position)
 if gui_blocked:
  suspend_input("ui_blocked")
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
   return handle_event(event, Vector3.INF)
  return {"accepted":false, "reason":"ui_blocked", "consumed":true}
 return handle_event(event, ground)

func _ready_reason() -> String:
 var sim = _sim.get_ref()
 if sim.phase != "combat" or sim.paused: return "encounter_frozen"
 if sim.hero.dead: return "not_alive"
 if sim.hero.loadout.q != "q3" or int(sim.hero.ranks.q) <= 0: return "q3_unlearned"
 if sim._ink_action_controlled("q"): return "controlled"
 if sim.source_rules_hash != sim.EXPECTED_RULES_HASH: return "source_binding_mismatch"
 return ""

func _scope_reason() -> String:
 if q3_aim.is_empty(): return ""
 var sim = _sim.get_ref()
 var reason: String = _ready_reason()
 if not reason.is_empty(): return reason
 if sim.encounter_generation != q3_aim.generation or sim.room_id != q3_aim.room_id: return "stale_preview_room"
 if int(sim.hero.ranks.q) != q3_aim.rank: return "stale_preview_rank"
 if q3_aim.phase == "collapse":
  var mountain: Dictionary = sim.ink_mountain
  if mountain.is_empty(): return "armed_mountain_retired"
  if mountain.terrain_id != q3_aim.terrain_id or mountain.cast_id != q3_aim.cast_id: return "armed_mountain_replaced"
  if not sim.effect_is_current(mountain) or sim.hero_time >= float(mountain.expires_at) - sim.TIME_EPS: return "armed_mountain_expired"
 elif not sim.ink_mountain.is_empty(): return "raise_phase_changed"
 return ""

func clear_q3_preview(reason: String) -> Dictionary:
 var existed: bool = not q3_aim.is_empty()
 q3_aim = {}; last_cancel_reason = reason
 if existed: _suppress_held = true
 return {"accepted":existed, "reason":reason, "consumed":existed, "preview_only":true}

func synchronize_preview() -> Dictionary:
 if _sim == null or not is_instance_valid(_sim.get_ref()):
  return clear_q3_preview("unbound")
 var reason: String = _scope_reason()
 if not reason.is_empty():
  _retired_q3_intent = reason
  return clear_q3_preview(reason)
 return {"accepted":true, "reason":"unchanged", "preview_only":true}

func preview(mouse_ground: Vector3) -> Dictionary:
 synchronize_preview()
 if q3_aim.is_empty(): return {"accepted":false, "reason":"q3_not_armed", "preview_only":true}
 var sim = _sim.get_ref()
 var out: Dictionary = sim.q3_preview(mouse_ground)
 # Never silently change the interpretation shown at arming.
 if out.get("accepted", false) and out.get("phase", "") != q3_aim.phase:
  clear_q3_preview("preview_phase_changed")
  return {"accepted":false, "reason":"preview_phase_changed", "preview_only":true}
 out["armed_identity"] = q3_aim.duplicate(true)
 return out

func _arm_q3(mouse_ground: Vector3) -> Dictionary:
 var sim = _sim.get_ref()
 if sim.transaction_active: return {"accepted":false, "reason":"transaction_in_progress", "consumed":true}
 if _left_physical: return {"accepted":false, "reason":"mouse_already_held", "consumed":true}
 if not q3_aim.is_empty(): return {"accepted":false, "reason":"q3_already_armed", "consumed":true}
 var reason: String = _ready_reason()
 if not reason.is_empty(): return {"accepted":false, "reason":reason, "consumed":true}
 _retired_q3_intent = ""
 if sim.hero.lock_time > sim.TIME_EPS: return {"accepted":false, "reason":"action_locked", "consumed":true}
 if sim.hero.dash_left > sim.TIME_EPS: return {"accepted":false, "reason":"dashing", "consumed":true}
 if sim.ink_mountain.is_empty() and sim.hero.cooldowns.q > sim.TIME_EPS: return {"accepted":false, "reason":"cooldown", "consumed":true}
 # Arming can display an invalid placement while the player moves the pointer.
 # It does not require a chosen point, create a source cast, or spend cooldown.
 var phase: String = "raise" if sim.ink_mountain.is_empty() else "collapse"
 q3_aim = {"phase":phase, "generation":sim.encounter_generation, "room_id":sim.room_id, "rank":int(sim.hero.ranks.q), "cast_id":0, "terrain_id":"", "armed_at":sim.hero_time}
 if phase == "collapse":
  q3_aim.cast_id = sim.ink_mountain.cast_id
  q3_aim.terrain_id = sim.ink_mountain.terrain_id
 var invalid: String = _scope_reason()
 if not invalid.is_empty():
  clear_q3_preview(invalid)
  return {"accepted":false, "reason":invalid, "consumed":true, "preview_only":true}
 return {"accepted":true, "reason":"q3_armed", "consumed":true, "preview_only":true, "preview":preview(mouse_ground)}

func _commit_q3(mouse_ground: Vector3) -> Dictionary:
 var sim = _sim.get_ref()
 if _left_physical: return {"accepted":false, "reason":"duplicate_physical_down", "consumed":true}
 _left_physical = true; _gesture_consumed = true; _suppress_held = true
 _q3_mouse_pair = true; _generation = sim.encounter_generation
 if sim.transaction_active:
  clear_q3_preview("transaction_in_progress")
  return {"accepted":false, "reason":"transaction_in_progress", "consumed":true}
 var reason: String = _scope_reason()
 if not reason.is_empty():
  clear_q3_preview(reason)
  return {"accepted":false, "reason":reason, "consumed":true}
 var shown: Dictionary = preview(mouse_ground)
 if not shown.get("accepted", false):
  clear_q3_preview(str(shown.reason))
  return {"accepted":false, "reason":shown.reason, "consumed":true}
 var identity: Dictionary = q3_aim.duplicate(true)
 # The only Q3 source command is the explicit fresh LMB-down. Clear intent first
 # so reentrant callbacks cannot redispatch it. Persistent terrain is untouched.
 q3_aim = {}
 var result: Dictionary = sim.request_action("q", mouse_ground, _command())
 result["consumed"] = true; result["armed_identity"] = identity
 return result

func handle_event(event: InputEvent, mouse_ground: Vector3 = Vector3.INF) -> Dictionary:
 if _sim == null or not is_instance_valid(_sim.get_ref()): return {"accepted":false, "reason":"unbound"}
 var was_armed: bool = not q3_aim.is_empty()
 var invalid: String = _scope_reason()
 if not invalid.is_empty():
  _retired_q3_intent = invalid
  clear_q3_preview(invalid)
 var sim = _sim.get_ref()
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
  if not event.pressed and _q3_mouse_pair:
   _left_physical = false; _gesture_consumed = false; _suppress_held = false; _q3_mouse_pair = false; _gesture_id = ""
   return {"accepted":false, "reason":"q3_mouse_up_never_fires", "consumed":true}
  if event.pressed and ((was_armed and not invalid.is_empty()) or not _retired_q3_intent.is_empty()):
   _left_physical = true; _gesture_consumed = true; _suppress_held = true; _q3_mouse_pair = true
   var retired: String = _retired_q3_intent
   _retired_q3_intent = ""
   return {"accepted":false, "reason":retired, "consumed":true}
  if event.pressed and not q3_aim.is_empty(): return _commit_q3(mouse_ground)
 if event is InputEventKey:
  var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  if code == KEY_Q and sim.hero.loadout.q == "q3":
   if event.echo: return {"accepted":false, "reason":"key_echo", "consumed":true}
   return _arm_q3(mouse_ground) if event.pressed else {"accepted":false, "reason":"q3_key_up_never_fires", "consumed":not q3_aim.is_empty()}
  if code == KEY_ESCAPE and event.pressed and not q3_aim.is_empty(): return clear_q3_preview("escape")
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not q3_aim.is_empty(): return clear_q3_preview("right_down")
 if event is InputEventMouseMotion and not q3_aim.is_empty(): return preview(mouse_ground)
 # WASD/Shift/basic/Q1 keep their established real source route and cadence.
 return super.handle_event(event, mouse_ground)

func update_held_basic(mouse_ground: Vector3) -> Dictionary:
 synchronize_preview()
 if not q3_aim.is_empty() or _q3_mouse_pair: return {"accepted":false, "reason":"held_basic_suppressed"}
 return super.update_held_basic(mouse_ground)

func suspend_input(reason: String = "pause") -> void:
 if not q3_aim.is_empty(): _retired_q3_intent = reason
 clear_q3_preview(reason)
 super.suspend_input(reason)

func _source_event(event: Dictionary) -> void:
 # Actual source events use `kind`, never fixture-only `type`.
 if event.get("kind", "") in ["encounter_started", "encounter_finished", "true_dead"]:
  if not q3_aim.is_empty(): _retired_q3_intent = str(event.kind)
  clear_q3_preview(str(event.kind)); _suppress_held = true
 else: synchronize_preview()
