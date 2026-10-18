extends RefCounted
const Mapper = preload("mapper.gd")
const Renderer = preload("renderer.gd")
const Controller = preload("controller.gd")

func _frame() -> Dictionary:
 return {"scope":[1,2,"room",1],"source_time":1.0,"paused":false,"hero":{"dead":false,"stun_left":0.0,"dash_left":0.0,"knockback":[0,0,0]},"snapshot":{"input":{"phase":"idle"}},"ultimate":{"active":false},"events":[]}

func _report(upper: String = "") -> Dictionary:
 return {"source_time":1.0,"upper":upper,"upper_time":0.15,"gait_elapsed_absolute":0.125,"base":"idle","walk_playback_ratio":0.0,"direction_plan":{"aim_direction":Vector3.BACK,"movement_direction":Vector3.BACK}}

func run() -> Dictionary:
 var results: Array = []
 var windows: Dictionary = {"basic_upper":{"first":0.0,"span":0.3},"q1_draw_upper":{"first":0.0,"span":1.0},"q1_hold_upper":{"first":0.0,"span":0.5},"q1_release_upper":{"first":0.0,"span":0.6}}
 var mapper = Mapper.new()
 var frame: Dictionary = _frame()
 var report: Dictionary = _report()
 var plan: Dictionary = mapper.evaluate(frame,report,windows,Vector3.BACK)
 results.append({"name":"idle","passed":plan.get("accepted",false) and plan.phase=="idle"})
 report=_report("basic_upper")
 plan=mapper.evaluate(frame,report,windows,Vector3.BACK)
 results.append({"name":"basic_distinct","passed":plan.get("accepted",false) and plan.phase=="basic" and is_equal_approx(plan.progress,0.5)})
 report.base="walk"; report.walk_playback_ratio=1.0
 plan=mapper.evaluate(frame,report,windows,Vector3.BACK)
 results.append({"name":"moving_basic","passed":plan.get("accepted",false) and plan.moving and is_equal_approx(plan.gait_phase,PI/2.0)})
 frame.snapshot.input={"phase":"frozen","gesture_id":"A","draw_fraction":0.4}
 report=_report("q1_hold_upper")
 plan=mapper.evaluate(frame,report,windows,Vector3.BACK)
 results.append({"name":"hold_uses_draw_fraction","passed":plan.get("accepted",false) and plan.phase=="hold" and is_equal_approx(plan.progress,0.4)})
 frame.snapshot.input={"phase":"idle"}; frame.events=[{"kind":"ink_q1_released","gesture_id":"A"}]
 report=_report("q1_release_upper")
 plan=mapper.evaluate(frame,report,windows,Vector3.BACK)
 results.append({"name":"release_source_clip_and_origin","passed":plan.get("accepted",false) and is_equal_approx(plan.progress,0.25) and is_equal_approx(plan.release_origin_fraction,0.4)})
 frame.events=[]; frame.paused=true
 var paused: Dictionary = mapper.evaluate(frame,report,windows,Vector3.BACK)
 results.append({"name":"pause_same_source_pose","passed":paused==plan})
 results.append({"name":"uncovered_direction","passed":not mapper.evaluate(frame,report,windows,Vector3.RIGHT).get("accepted",false)})
 results.append({"name":"uncovered_alias","passed":not mapper.evaluate(frame,_report("e3_upper"),windows,Vector3.BACK).get("accepted",false)})
 frame.hero.stun_left=0.1
 results.append({"name":"control_fallback","passed":not mapper.evaluate(frame,_report(),windows,Vector3.BACK).get("accepted",false)})
 frame.hero.stun_left=0.0
 results.append({"name":"idle_recovers_without_stop_history","passed":mapper.evaluate(frame,_report(),windows,Vector3.BACK).get("accepted",false)})
 frame.scope=[1,2,"other",2]
 results.append({"name":"scope_reject","passed":mapper.evaluate(frame,_report(),windows,Vector3.BACK).has("fault")})
 frame=_frame(); frame.source_time=0.9
 results.append({"name":"clock_reject","passed":mapper.evaluate(frame,_report(),windows,Vector3.BACK).has("fault")})
 var accepted: bool = true
 for row: Dictionary in results: accepted=accepted and bool(row.passed)
 return {"accepted":accepted,"count":results.size(),"cases":results,"execution":"requires_Godot_call_not_yet_run"}
