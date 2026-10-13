extends "res://tests/ink_equipment_live_20261008/content01/potion_controls.gd"
var _last_terminal_reason=""
func _terminal_reason()->String:
 if _session==null or _session.ledger==null:return ""
 return _session.ledger.model.potion_terminal_reason(_session)
func _process(delta:float)->void:
 var reason=_terminal_reason()
 if reason!=_last_terminal_reason:
  _signature="";_last_terminal_reason=reason
 super._process(delta)
 if reason.is_empty():return
 for child in get_children():
  if child is Button:
   child.disabled=true
   if not child.has_meta("original_potion_tooltip"):child.set_meta("original_potion_tooltip",child.tooltip_text)
   child.tooltip_text=str(child.get_meta("original_potion_tooltip"))+"\n本局已结束，无法使用药水；保留现有药瓶。"
func _use(uid:int)->void:
 var reason=_terminal_reason()
 if not reason.is_empty():
  if _session!=null:_session._record({"accepted":false,"reason":reason,"changed":false})
  return
 super._use(uid)
