extends RefCounted
## Read-only projection of an already authoritative death settlement.
static func eligible(flow:Dictionary,phase:String,dead:bool,model_phase:String,owner_intact:bool)->bool:
 if not owner_intact or not dead or phase!="true_dead" or model_phase!="safe":return false
 if str(flow.get("status",""))!="defeated":return false
 var settlement:Dictionary=flow.get("settlement",{})
 var run_id:String=str(flow.get("run_id",""))
 return not run_id.is_empty() and str(settlement.get("run_id",""))==run_id and settlement.get("outcome","")=="defeat"

static func header(existing:String)->String:
 return existing.replace(" · defeated · F10退出"," · 本局已结束 · F10退出")

static func hint(existing:String,preflight:Dictionary,preflight_suffix:String,receipt:Dictionary,receipt_suffix:String,pause_suffix:String="")->String:
 # Remove only known source suffixes; never globally replace error text.
 var shown:String=existing
 if not pause_suffix.is_empty():
  if not shown.ends_with(pause_suffix):return existing
  shown=shown.trim_suffix(pause_suffix)
 var receipt_line:String=receipt_suffix
 if not receipt_suffix.is_empty():
  if not shown.ends_with(receipt_suffix):return existing
  shown=shown.trim_suffix(receipt_suffix)
  if receipt.get("accepted",false)==true and str(receipt.get("reason",""))=="defeated":receipt_line="\n本局已结束"
 if not preflight_suffix.is_empty() and preflight.get("accepted",true)==false and str(preflight.get("reason",""))=="not_alive":
  if not shown.ends_with(preflight_suffix):return existing
  shown=shown.trim_suffix(preflight_suffix)+"\n角色已死亡，无法继续进入下一节点。"
 var introduction:String="从下往上沿线选下一行；末行Boss。"
 if shown.begins_with(introduction):shown="角色已死亡，本局已结束。"+shown.trim_prefix(introduction)
 return shown+receipt_line+pause_suffix
