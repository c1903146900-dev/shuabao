extends SceneTree
const Text = preload("res://visual_rework_20261009/initial_status_text.gd")
var checks: Array=[]
var failures: Array=[]
func check(value: bool,label: String) -> void:
 checks.append({"passed":value,"label":label})
 if not value:failures.append(label)
func _initialize() -> void:
 var suffix="\n操作未完成（developer_first_floor_bound）"
 var before="请先点击当前行的一个节点"+suffix
 var ok={"accepted":true,"reason":"developer_first_floor_bound"}
 for phase in ["preparation","combat","victory","defeat"]:
  for session in ["preparation","combat","between_rooms","completed"]:
   for dead in [false,true]:
    var eligible=phase=="preparation" and session=="preparation" and not dead
    check(Text.status("状态：遭遇结束",phase,session,dead)==("状态：开局准备" if eligible else "状态：遭遇结束"),"phase/session/death status: %s/%s/%s"%[phase,session,dead])
    check(Text.hint(before,ok,suffix,phase,session,dead)==("请先点击当前行的一个节点\n初始准备完成" if eligible else before),"phase/session/death receipt: %s/%s/%s"%[phase,session,dead])
 for existing in ["状态：暂停","状态：已倒下","状态：闪避免疫","状态：免疫","状态：无"]:
  check(Text.status(existing,"preparation","preparation",false)==existing,"preserve original status: "+existing)
 for receipt in [{"accepted":false,"reason":"developer_first_floor_bound"},{"reason":"developer_first_floor_bound"},{"accepted":true,"reason":"no_live_run"},{}]:
  check(Text.hint(before,receipt,suffix,"preparation","preparation",false)==before,"non-success or other reason kept: "+JSON.stringify(receipt))
 check(Text.hint("另一个错误",ok,suffix,"preparation","preparation",false)=="另一个错误","does not replace unmatched current text")
 check(Text.hint(suffix+before,ok,suffix,"preparation","preparation",false)==suffix+"请先点击当前行的一个节点\n初始准备完成","only final receipt suffix changes, prior content retained")
 check(Text.status("状态：遭遇结束","preparation","preparation",false,true)=="状态：开局准备 · 暂停","original preparation pause wording retained")
 var out=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--result="):out=arg.trim_prefix("--result=")
 var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"pure read-only UI formatter cases, not gameplay or native GUI"}
 if not out.is_empty():
  var f=FileAccess.open(out,FileAccess.WRITE)
  if f==null:quit(3);return
  f.store_string(JSON.stringify(result,"  "));f.close()
 print("INITIAL_STATUS_GATE ",JSON.stringify({"passed":failures.is_empty(),"checks":checks.size(),"failures":failures}))
 quit(0 if failures.is_empty() else 2)
