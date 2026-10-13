extends "res://formal_training_20261009/panel.gd"
## UI-only view of the original current-visit undo journal. No command/receipt
## writes, no new reversal capability, no change to training's irreversible cost.
func _ready() -> void:
 super._ready()
 _close.text = "关闭 P / Esc（保留本次可撤交易）"

static func undo_ui_status(records: Array) -> Dictionary:
 for record: Dictionary in records:
  if not bool(record.get("sealed",false)):
   return {"blocked":false,"reason":""}
 return {"blocked":true,"reason":"undo_boundary" if records.is_empty() else str(records.back().get("seal_reason","already_used"))}

func refresh(force: bool=false) -> void:
 super.refresh(force)
 if not _state.get("ready",false) or not visible or not is_instance_valid(_undo): return
 var journal: Array = _state.state.shop_visit.undo
 var status: Dictionary = undo_ui_status(journal)
 if status.blocked:
  _undo.disabled = true
  var explanations: Dictionary = {
   "already_used":"相关物品已使用，本次交易不可撤回",
   "reward_already_claimed":"相关成长奖励已领取，本次交易不可撤回"
  }
  _undo.tooltip_text = str(explanations.get(status.reason,reason_text(str(status.reason))))
 else:
  # Keep any other disabling decision made by the inherited panel.
  _undo.tooltip_text = ""
