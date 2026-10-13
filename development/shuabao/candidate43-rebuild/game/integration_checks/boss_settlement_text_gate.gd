extends SceneTree
const Text=preload("res://visual_rework_20261009/settled_floor_text.gd")
var checks:Array=[]
var output:String=""
func _initialize()->void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
 run.call_deferred()
func check(ok:bool,label:String)->void:checks.append({"passed":ok,"label":label})
func valid()->Dictionary:
 var rows:Array=[]
 for index in range(12):rows.append({"fixture_index":index})
 return {"status":"completed","node_index":12,"run_id":"pure-run","settlement":{"outcome":"victory","run_id":"pure-run"},"row_state":{"status":"all_rows_recorded","completed_rows":rows}}
func run()->void:
 var flow:Dictionary=valid()
 check(Text.eligible(flow,"victory",false,"safe",true),"authoritative-shaped completed victory eligible; pure fixture only")
 for status in ["preparation","combat","between_rooms","service","defeated","faulted","aborted","unbound"]:
  var altered:Dictionary=flow.duplicate(true);altered.status=status
  check(not Text.eligible(altered,"victory",false,"safe",true),"noncompleted status unchanged: "+status)
 for phase in ["preparation","combat","defeat"]:check(not Text.eligible(flow,phase,false,"safe",true),"nonvictory phase unchanged: "+phase)
 check(not Text.eligible(flow,"victory",true,"safe",true),"dead hero cannot present victory")
 check(not Text.eligible(flow,"victory",false,"combat",true),"non-safe Model cannot present victory")
 check(not Text.eligible(flow,"victory",false,"safe",false),"owner mismatch cannot present victory")
 for count in [0,11,13]:
  var altered:Dictionary=flow.duplicate(true);altered.node_index=count
  check(not Text.eligible(altered,"victory",false,"safe",true),"not exactly 12 completed nodes: "+str(count))
 var wrong:Dictionary=flow.duplicate(true);wrong.settlement.run_id="other-run"
 check(not Text.eligible(wrong,"victory",false,"safe",true),"wrong-run settlement rejected")
 wrong=flow.duplicate(true);wrong.settlement.outcome="defeat"
 check(not Text.eligible(wrong,"victory",false,"safe",true),"nonvictory settlement rejected")
 wrong=flow.duplicate(true);wrong.row_state.status="entered"
 check(not Text.eligible(wrong,"victory",false,"safe",true),"unrecorded last room rejected")
 wrong=flow.duplicate(true);wrong.row_state.completed_rows.pop_back()
 check(not Text.eligible(wrong,"victory",false,"safe",true),"missing completion receipt rejected")
 var before:String="已完成 12/12 行 · completed · F10退出\nLv.8 金币1234"
 check(Text.header(before)=="已完成 12/12 行 · 首层已完成 · F10退出\nLv.8 金币1234","header preserves economy and exit instruction")
 check(Text.header("操作失败 · faulted")=="操作失败 · faulted","other headers unchanged")
 var suffix:String="\n操作未完成（first_floor_settled）"
 var original:String="从下往上沿线选下一行；末行Boss。\n请先完成当前战斗或服务节点"+suffix
 var accepted:Dictionary={"accepted":true,"reason":"first_floor_settled"}
 var result:String=Text.hint(original,accepted,suffix)
 check(result=="首层Boss已击败，当前首层已结算。\n首层已完成，没有下一节点。\n首层结算完成","success maps only exact current suffix")
 check(Text.hint(original,{"accepted":false,"reason":"first_floor_settled"},suffix).ends_with(suffix),"same failure reason stays failure")
 check(Text.hint(original,{"accepted":true,"reason":"other"},suffix).ends_with(suffix),"other receipt stays unchanged")
 check(Text.hint(original+"\n暂停：原错误",accepted,suffix,"\n暂停：原错误")==result+"\n暂停：原错误","success receipt maps while appended pause is retained")
 check(Text.hint("请先完成当前海克斯四选一",{},"")=="请先完成当前海克斯四选一","mandatory Hex instruction retained")
 check(Text.hint("当前已暂停；按Space明确继续",{},"")=="当前已暂停；按Space明确继续","original pause instruction retained")
 var identical_failure:String="\n请先完成当前战斗或服务节点"
 var both:String="从下往上沿线选下一行；末行Boss。"+identical_failure+identical_failure
 check(Text.hint(both,{"accepted":false,"reason":"complete_current_node_first"},identical_failure)=="首层Boss已击败，当前首层已结算。\n首层已完成，没有下一节点。"+identical_failure,"only preflight line changes, identical failed receipt stays")
 var matching_pause:String="\n暂停：请先完成当前战斗或服务节点"
 check(Text.hint(both+matching_pause,{"accepted":false,"reason":"complete_current_node_first"},identical_failure,matching_pause).ends_with(identical_failure+matching_pause),"identical failure and pause lines both retained")
 check(Text.hint(original,accepted,"\nunknown suffix")==original,"unknown source line layout fails closed")
 var passed:bool=not output.is_empty()
 for item in checks:passed=passed and bool(item.passed)
 var file=FileAccess.open(output,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify({"passed":passed,"checks":checks,"pure_formatting_fixture":true,"actual_Boss_settlement_verified":false},"  "));file.close()
 quit(0 if passed else 1)
