extends RefCounted
## Authored front pose sampled from current original actor presentation metadata.
## No bone retargeting, independent ability timing, or event replay.
var last_time: float = -INF
var last_scope: Array = []
var last_plan: Dictionary = {}
var draw_fraction: float = 0.0
var draw_gesture: String = ""
var release_fraction: float = 1.0

func evaluate(frame: Dictionary, report: Dictionary, windows: Dictionary, camera_forward: Vector3) -> Dictionary:
 if frame.has("fault"): return {"accepted":false,"fault":frame.fault}
 var scope: Array = frame.get("scope",[])
 var now: float = float(frame.get("source_time",NAN))
 if not is_finite(now) or (not last_scope.is_empty() and scope != last_scope) or now < last_time:
  return {"accepted":false,"fault":"source_scope_or_time_changed"}
 if not is_equal_approx(float(report.get("source_time",NAN)),now): return {"accepted":false,"reason":"actor_observation_pending"}
 var input: Dictionary = frame.get("snapshot",{}).get("input",{})
 if str(input.get("phase","")) in ["drawing","frozen"]:
  draw_fraction=clampf(float(input.get("draw_fraction",0.0)),0.0,1.0)
  draw_gesture=str(input.get("gesture_id",""))
 for event: Dictionary in frame.get("events",[]):
  if str(event.get("kind",""))=="ink_q1_released":
   release_fraction=draw_fraction if str(event.get("gesture_id",""))==draw_gesture else 1.0
 var hero: Dictionary = frame.hero
 var upper: String = str(report.get("upper",""))
 last_scope = scope.duplicate()
 last_time = now
 if bool(hero.dead) or float(hero.stun_left)>0.0 or float(hero.dash_left)>0.0 or Vector3(hero.knockback[0],hero.knockback[1],hero.knockback[2]).length()>0.00001:
  return {"accepted":false,"reason":"uncovered_control_or_terminal"}
 if bool(frame.get("ultimate",{}).get("active",false)): return {"accepted":false,"reason":"uncovered_ultimate"}
 if upper not in ["","basic_upper","q1_draw_upper","q1_hold_upper","q1_release_upper"]:
  return {"accepted":false,"reason":"uncovered_action:"+upper}
 var direction: Variant = report.get("direction_plan",{}).get("aim_direction",Vector3.ZERO)
 if upper.is_empty(): direction = report.get("direction_plan",{}).get("movement_direction",Vector3.ZERO)
 if not direction is Vector3 or not direction.is_finite(): return {"accepted":false,"fault":"invalid_direction"}
 direction.y=0.0
 camera_forward.y=0.0
 if direction.length()<0.00001 or camera_forward.length()<0.00001: return {"accepted":false,"reason":"direction_unavailable"}
 if direction.normalized().dot(camera_forward.normalized()) < cos(PI/4.0): return {"accepted":false,"reason":"uncovered_direction"}
 var phase: String = "idle"
 var progress: float = 0.0
 if not upper.is_empty():
  var window: Dictionary = windows.get(upper,{})
  var span: float = float(window.get("span",0.0))
  var first: float = float(window.get("first",NAN))
  var sampled: float = float(report.get("upper_time",NAN))
  if span<=0.0 or not is_finite(span) or not is_finite(first) or not is_finite(sampled): return {"accepted":false,"fault":"invalid_original_clip_window"}
  progress=clampf((sampled-first)/span,0.0,1.0)
  phase={"basic_upper":"basic","q1_draw_upper":"draw","q1_hold_upper":"hold","q1_release_upper":"release"}[upper]
 if upper in ["q1_draw_upper","q1_hold_upper"]: progress=draw_fraction
 var gait: float = float(report.get("gait_elapsed_absolute",NAN))
 if not is_finite(gait): return {"accepted":false,"fault":"invalid_source_gait"}
 var moving: bool = str(report.get("base","")) not in ["idle",""] and float(report.get("walk_playback_ratio",0.0))>0.0
 var plan: Dictionary = {"accepted":true,"phase":phase,"progress":progress,"moving":moving,"gait_phase":fposmod(gait,0.5)/0.5*TAU,"source_time":now,"scope":scope.duplicate(),"original_alias":upper,"release_origin_fraction":release_fraction,"original_event_serial":report.get("received_event_serial",0),"original_event_kind":report.get("received_event_kind",""),"source_started":report.get("upper_source_started",now)}
 last_plan=plan.duplicate(true)
 return plan
