extends SceneTree
# Pure monotonic-time arithmetic only. No Host instance or render/source step.
const Host = preload("res://visual_rework_20261009/runtime_host.gd")
var checks:Array=[]
var output:String=""
func _initialize()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="): output=arg.trim_prefix("--report=")
 run.call_deferred()
func check(ok:bool,label:String)->void:
 checks.append({"passed":ok,"label":label})
func deadline(now:int,armed:bool=false,first:int=0,attempted:bool=false,total:float=100.0)->String:
 return Host.startup_phase_deadline(now,0,total,armed,first,attempted,10000000)
func run()->void:
 check(deadline(99999999)=="","no first frame stays locked but does not invent a loading deadline")
 check(deadline(100000000)=="total_wall","no first frame reaches existing total software deadline exactly")
 check(deadline(100000001)=="total_wall","no first frame beyond total deadline remains expired")
 check(deadline(20000000,true,15000000)=="","loading time does not consume stable-draw budget")
 check(deadline(25000000,true,15000000)=="","original strict greater-than allows exact ten-second boundary")
 check(deadline(25000001,true,15000000)=="stable_draws","one microsecond beyond original ten seconds rejects")
 check(deadline(100000000,true,15000000)=="total_wall","total deadline wins if both deadlines expire")
 check(deadline(100000000,true,99999999)=="total_wall","late first frame cannot extend total deadline")
 check(deadline(99999999,true,15000000,true)=="","active original preparation is not killed by stable budget")
 check(deadline(100000000,true,15000000,true)=="total_wall","active preparation still has original total wall bound")
 check(deadline(25000001,true,15000000)=="stable_draws","third draw before process cannot bypass expired render budget")
 check(deadline(24999999,true,15000000)=="","third frame may queue before render deadline")
 check(deadline(25000001,true,15000000)=="stable_draws","deferred callback after render deadline must reject same ticket")
 check(deadline(99999999,true,95000000)=="","third frame may queue before total deadline")
 check(deadline(100000000,true,95000000)=="total_wall","deferred callback at total deadline must reject")
 check(deadline(500000000,false,0,false,900.0)=="","unchanged product default is a software wall bound, not test110")
 check(deadline(900000000,false,0,false,900.0)=="total_wall","unchanged default900 deadline exact boundary")
 check(Host.startup_phase_deadline(42000001,17000000,100.0,true,32000000,false,10000000)=="stable_draws","timestamps remain original absolute monotonic values")
 var passed:bool=not output.is_empty()
 for row in checks:passed=passed and bool(row.passed)
 var file=FileAccess.open(output,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify({"passed":passed,"checks":checks,"pure_deadline_arithmetic":true,"real_frames_verified":false,"actual_Host_startup_verified":false,"Boss_verified":false},"  "));file.close()
 quit(0 if passed else 1)
