extends RefCounted
## Presentation only. No settlement, reward, input or transition operation.
static func eligible(flow:Dictionary,phase:String,dead:bool,model_phase:String,owner_intact:bool)->bool:
 if not owner_intact or dead or phase!="victory" or model_phase!="safe":return false
 if str(flow.get("status",""))!="completed" or int(flow.get("node_index",-1))!=12:return false
 var settlement:Dictionary=flow.get("settlement",{})
 var rows:Dictionary=flow.get("row_state",{})
 if str(flow.get("run_id","")).is_empty() or str(settlement.get("run_id",""))!=str(flow.run_id):return false
 return settlement.get("outcome","")=="victory" and str(rows.get("status",""))=="all_rows_recorded" and rows.get("completed_rows",[]).size()==12

static func header(existing:String)->String:
 return existing.replace(" · completed · F10退出"," · 首层已完成 · F10退出")

static func hint(existing:String,receipt:Dictionary,receipt_suffix:String,pause_suffix:String="")->String:
 # Peel only the known trailing source lines, never replace failure text globally.
 var shown:String=existing
 if not pause_suffix.is_empty():
  if not shown.ends_with(pause_suffix):return existing
  shown=shown.trim_suffix(pause_suffix)
 var receipt_line:String=receipt_suffix
 if not receipt_suffix.is_empty():
  if not shown.ends_with(receipt_suffix):return existing
  shown=shown.trim_suffix(receipt_suffix)
  if receipt.get("accepted",false)==true and str(receipt.get("reason",""))=="first_floor_settled":receipt_line="\n首层结算完成"
 var preflight_line:String="\n请先完成当前战斗或服务节点"
 if shown.ends_with(preflight_line):shown=shown.trim_suffix(preflight_line)+"\n首层已完成，没有下一节点。"
 var introduction:String="从下往上沿线选下一行；末行Boss。"
 if shown.begins_with(introduction):shown="首层Boss已击败，当前首层已结算。"+shown.trim_prefix(introduction)
 return shown+receipt_line+pause_suffix
