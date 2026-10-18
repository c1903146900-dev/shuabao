extends SceneTree
var started: int = 0
var output: String = ""
var finished: bool = false
func _initialize() -> void:
 started=Time.get_ticks_msec()
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=1 or not args[0].begins_with("--report=") or DisplayServer.get_name()=="headless":
  quit(4); return
 output=args[0].trim_prefix("--report=")
 if not output.is_absolute_path() or FileAccess.file_exists(output) or DirAccess.dir_exists_absolute(output):
  quit(4); return
 create_timer(15.0,true,false,true).timeout.connect(func(): _finish({"accepted":false,"reason":"internal_deadline"}))
 call_deferred("_run")
func _run() -> void:
 var draws: Array=[]
 for i in range(3):
  await process_frame
  await RenderingServer.frame_post_draw
  draws.append(Engine.get_frames_drawn())
 var test_script: Script=load("res://contract_tests.gd") as Script
 if test_script==null or not test_script.can_instantiate():
  _finish({"accepted":false,"reason":"contract_parse_failed"}); return
 var instance: RefCounted=test_script.new()
 var result: Variant=instance.call("run")
 if not result is Dictionary:
  _finish({"accepted":false,"reason":"invalid_result"}); return
 var report: Dictionary=result
 var cases: Variant=report.get("cases",null)
 var ok: bool=bool(report.get("accepted",false)) and int(report.get("count",0))==19 and cases is Array
 if cases is Array:
  ok=ok and cases.size()==19
  for item: Variant in cases:
   ok=ok and item is Dictionary and bool(item.get("passed",false))
 ok=ok and draws[0]<draws[1] and draws[1]<draws[2]
 report["accepted"]=ok
 report["draw_frames"]=draws
 report["scope"]="detached_19_contracts_only_no_assets_no_live_combat"
 _finish(report)
func _finish(report: Dictionary) -> void:
 if finished: return
 finished=true
 report["elapsed_ms"]=Time.get_ticks_msec()-started
 if report.elapsed_ms>=15000: report["accepted"]=false
 if FileAccess.file_exists(output) or DirAccess.dir_exists_absolute(output): quit(4);return
 var bytes: PackedByteArray=JSON.stringify(report,"  ").to_utf8_buffer()
 var f: FileAccess=FileAccess.open(output,FileAccess.WRITE)
 if f==null: quit(4);return
 var io_ok: bool=f.store_buffer(bytes) and f.get_error()==OK
 f.flush();io_ok=io_ok and f.get_error()==OK;f.close()
 io_ok=io_ok and FileAccess.get_file_as_bytes(output)==bytes
 if Time.get_ticks_msec()-started>=15000: report["accepted"]=false
 print("FRONT_CONTRACT_FINAL ",JSON.stringify(report)," IO_OK=",io_ok)
 quit(0 if bool(report.get("accepted",false)) and io_ok else 4)
