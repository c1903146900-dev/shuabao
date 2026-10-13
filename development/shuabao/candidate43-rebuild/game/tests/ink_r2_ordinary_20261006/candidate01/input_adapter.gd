extends "res://tests/ink_e3_ordinary_20261006/ordinary01/input_adapter.gd"
## Reuse the same R physical pair and Q/E arbitration; selected R owns intent.
func _r1_ready_reason() -> String:
 if _sim == null or not is_instance_valid(_sim.get_ref()): return "unbound"
 var source = _sim.get_ref()
 if source.hero.loadout.r != "r2": return super._r1_ready_reason()
 if source.phase != "combat" or source.paused: return "encounter_frozen"
 if source.hero.dead: return "not_alive"
 if source.source_rules_hash != source.EXPECTED_RULES_HASH: return "source_binding_mismatch"
 if int(source.hero.ranks.r) <= 0: return "r2_unlearned"
 if source._e1_form_current(): return "rain_form_forbids_action"
 if source._ink_action_controlled("r"): return "controlled"
 if source.hero.lock_time > source.TIME_EPS: return "action_locked"
 if source.hero.dash_left > source.TIME_EPS: return "dashing"
 if not source.ink_peaks.is_empty(): return "peak_domain_already_active"
 if source.hero.cooldowns.r > source.TIME_EPS: return "cooldown"
 return ""

func _r1_scope_reason() -> String:
 var reason: String = super._r1_scope_reason()
 if not reason.is_empty() or r1_aim.is_empty(): return reason
 if str(r1_aim.get("candidate","")) != str(_sim.get_ref().hero.loadout.r): return "stale_preview_candidate"
 return ""

func _selected_r_preview(point: Vector3) -> Dictionary:
 var source = _sim.get_ref()
 return source.r2_preview(point) if source.hero.loadout.r == "r2" else source.r1_preview(point)

func r1_preview_for_view(point: Vector3) -> Dictionary:
 synchronize_preview()
 if r1_aim.is_empty(): return {"accepted":false,"reason":"r_not_armed","preview_only":true}
 var shown: Dictionary = _selected_r_preview(point)
 shown["armed_identity"] = r1_aim.duplicate(true)
 shown["candidate"] = str(r1_aim.candidate)
 return shown

func _arm_r1(point: Vector3) -> Dictionary:
 var source = _sim.get_ref()
 if source.transaction_active: return {"accepted":false,"reason":"transaction_in_progress","consumed":true}
 if _left_physical or source._left_held: return {"accepted":false,"reason":"mouse_already_held","consumed":true}
 if not r1_aim.is_empty(): return {"accepted":false,"reason":"r_already_armed","consumed":true}
 var reason: String = _r1_ready_reason()
 if not reason.is_empty(): return {"accepted":false,"reason":reason,"consumed":true}
 var identity: Dictionary = {"generation":source.encounter_generation,"room_id":source.room_id,"rank":int(source.hero.ranks.r),"candidate":str(source.hero.loadout.r),"armed_at":source.hero_time}
 if source.ink_input.phase != "idle": source.cancel_ink_preview("replaced_by_r_aim")
 clear_q2_preview("replaced_by_r_aim"); clear_q3_preview("replaced_by_r_aim")
 _retired_q2_intent = ""; _retired_q3_intent = ""
 _gesture_id = ""; _generation = -1
 _retired_r1_intent = ""; _suppress_held = true; r1_aim = identity
 reason = _r1_scope_reason()
 if not reason.is_empty():
  clear_r1_preview(reason)
  return {"accepted":false,"reason":reason,"consumed":true,"preview_only":true}
 return {"accepted":true,"reason":"r_armed","consumed":true,"preview_only":true,"preview":r1_preview_for_view(point)}

func _commit_r1(point: Vector3) -> Dictionary:
 if _left_physical: return {"accepted":false,"reason":"duplicate_physical_down","consumed":true}
 _claim_r1_mouse_pair()
 var source = _sim.get_ref()
 var reason: String = "transaction_in_progress" if source.transaction_active else _r1_scope_reason()
 if not reason.is_empty():
  clear_r1_preview(reason,false)
  return {"accepted":false,"reason":reason,"consumed":true}
 var shown: Dictionary = _selected_r_preview(point)
 if not shown.get("accepted",false):
  clear_r1_preview(str(shown.get("reason","invalid_r_preview")),false)
  return {"accepted":false,"reason":shown.get("reason","invalid_r_preview"),"consumed":true}
 var identity: Dictionary = r1_aim.duplicate(true)
 r1_aim = {}; _retired_r1_intent = ""
 var result: Dictionary = source.request_action("r",point,_command())
 result["consumed"] = true; result["armed_identity"] = identity
 return result
