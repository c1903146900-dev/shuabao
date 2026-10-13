extends SceneTree
const Text=preload("res://visual_rework_20261009/defeated_run_text.gd")
const Victory=preload("res://visual_rework_20261009/settled_floor_text.gd")
var checks:Array=[]
var output:String=""
func _initialize()->void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
 run.call_deferred()
func check(ok:bool,label:String)->void:checks.append({"passed":ok,"label":label})
func run()->void:
 var flow:Dictionary={"status":"defeated","run_id":"pure-run","settlement":{"outcome":"defeat","run_id":"pure-run"}}
 check(Text.eligible(flow,"true_dead",true,"safe",true),"pure authoritative-shaped death eligible")
 check(not Victory.eligible(flow,"true_dead",true,"safe",true),"death and victory are mutually exclusive")
 for status in ["preparation","combat","between_rooms","service","completed","faulted","aborted","unbound"]:
  var altered:Dictionary=flow.duplicate(true);altered.status=status
  check(not Text.eligible(altered,"true_dead",true,"safe",true),"nondeath status unchanged: "+status)
 for phase in ["preparation","combat","victory","host_closed"]:
  check(not Text.eligible(flow,phase,true,"safe",true),"nondeath phase unchanged: "+phase)
 check(not Text.eligible(flow,"true_dead",false,"safe",true),"alive rejected")
 check(not Text.eligible(flow,"true_dead",true,"combat",true),"Model unsafe rejected")
 check(not Text.eligible(flow,"true_dead",true,"safe",false),"owner mismatch rejected")
 for field in ["wrong_run","empty_run","victory","missing_settlement"]:
  var altered:Dictionary=flow.duplicate(true)
  if field=="wrong_run":altered.settlement.run_id="other"
  elif field=="empty_run":altered.run_id="";altered.settlement.run_id=""
  elif field=="victory":altered.settlement.outcome="victory"
  else:altered.erase("settlement")
  check(not Text.eligible(altered,"true_dead",true,"safe",true),"invalid settlement: "+field)
 check(Text.header("0/12 · defeated · F10退出\n金币0")=="0/12 · 本局已结束 · F10退出\n金币0","header preserves economy")
 check(Text.header("completed · F10退出")=="completed · F10退出","other header unchanged")
 var intro:String="从下往上沿线选下一行；末行Boss。"
 var pre:String="\n操作未完成（not_alive）"
 var tail:String="\n操作未完成（defeated）"
 var p:Dictionary={"accepted":false,"reason":"not_alive"}
 var r:Dictionary={"accepted":true,"reason":"defeated"}
 var original:String=intro+pre+tail
 var expected:String="角色已死亡，本局已结束。\n角色已死亡，无法继续进入下一节点。\n本局已结束"
 check(Text.hint(original,p,pre,r,tail)==expected,"source-owned death text localized")
 check(Text.hint(intro+pre,p,pre,{},"")=="角色已死亡，本局已结束。\n角色已死亡，无法继续进入下一节点。","no receipt retained")
 check(Text.hint(original,p,pre,{"accepted":false,"reason":"defeated"},tail).ends_with(tail),"same-string failure receipt retained")
 check(Text.hint(intro+pre+pre,p,pre,{"accepted":false,"reason":"not_alive"},pre).ends_with("无法继续进入下一节点。"+pre),"identical failure and preflight distinct")
 check(Text.hint(original,p,pre,{"accepted":true,"reason":"other"},tail).ends_with(tail),"other receipt retained")
 var pause:String="\n暂停：操作未完成（not_alive）"
 check(Text.hint(original+pause,p,pre,r,tail,pause)==expected+pause,"pause retained exactly")
 check(Text.hint(original,p,pre,r,"\nunknown")==original,"unknown receipt layout unchanged")
 check(Text.hint(original+pause,p,pre,r,tail,"\nwrong")==original+pause,"unknown pause layout unchanged")
 check(Text.hint(original,p,"\nwrong",r,tail)==original,"unknown preflight layout unchanged")
 check(Text.hint("当前已暂停；按Space明确继续",{},"",{},"")=="当前已暂停；按Space明确继续","pause-only preserved")
 check(Text.hint("请先完成当前海克斯四选一",{},"",{},"")=="请先完成当前海克斯四选一","modal-only preserved")
 var passed:bool=not output.is_empty() and checks.size()==34
 for row in checks:passed=passed and bool(row.passed)
 var file=FileAccess.open(output,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify({"passed":passed,"checks":checks,"pure_formatting_fixture":true,"reconstructed_test_new_run":true,"actual_UI_verified":false},"  "))
 var error:Error=file.get_error();file.close();quit(0 if passed and error==OK else 1)
