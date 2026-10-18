extends SceneTree
const Test = preload("res://yan_p3_reimplementation_20261018b/test_state.gd")
func _initialize() -> void:
 call_deferred("execute")
func execute() -> void:
 var started := Time.get_ticks_msec()
 var report: Dictionary = Test.new().run()
 var draws: Array = []
 for i in range(3):
  await process_frame
  await RenderingServer.frame_post_draw
  draws.append(Engine.get_frames_drawn())
 report["draw_frames"] = draws
 report["elapsed_ms"] = Time.get_ticks_msec() - started
 report["accepted"] = bool(report.get("accepted", false)) and int(report.get("checks", 0)) == 19 and report.get("failures", []).is_empty() and draws[0] < draws[1] and draws[1] < draws[2] and report.elapsed_ms < 30000
 var args := OS.get_cmdline_user_args()
 if args.size() != 1:
  quit(4)
  return
 var f := FileAccess.open(args[0], FileAccess.WRITE)
 if f == null:
  quit(4)
  return
 f.store_string(JSON.stringify(report, "  "))
 f.flush()
 var good: bool = f.get_error() == OK
 f.close()
 print("P3_CORE_FINAL ", JSON.stringify(report), " IO_OK=", good)
 quit(0 if report.accepted and good else 4)
