extends "res://visual_rework_20261009/transaction_panel.gd"
## UI-only next-battle use affordance. Original Model/Session command owns debit,
## source UID, tokens, replay, consumed-lineage sealing and pending replacement.
func refresh(force: bool = false) -> void:
 super.refresh(force)
 if not _state.get("ready",false) or not visible: return
 for index in range(_state.state.inventory.size()):
  var item: Dictionary = _state.state.inventory[index]
  if item.id!="elixir:04" or index>=_inventory.get_child_count(): continue
  var row: Node = _inventory.get_child(index)
  var button: Button = null
  for child: Node in row.get_children():
   if child is Button and child.has_meta("hunter_elixir_use"): button=child;break
  if button==null:
   button=Button.new();button.text="饮用 · 下一战";button.set_meta("hunter_elixir_use",true)
   button.pressed.connect(_drink_hunter.bind(int(item.uid),button));row.add_child(button)
  var status: Dictionary = _session.ledger.model.hunter_elixir_use_status(int(item.uid))
  button.disabled=not status.accepted
  button.tooltip_text="仅下一场战斗生效；饮用后此笔不可撤回" if status.accepted else _hunter_reason(str(status.reason))
func _drink_hunter(uid: int, button: Button) -> void:
 if not is_instance_valid(button) or button.disabled: return
 button.disabled=true
 _request("consume",{"uid":uid},_session.ledger.model.commerce_token())
func _detail_for_selected() -> void:
 super._detail_for_selected()
 if _selected!="elixir:04" or not _state.get("ready",false): return
 var status: Dictionary = _session.ledger.model.hunter_elixir_status()
 if not status.supported: return
 var tuning: Dictionary = status.tuning
 _detail.text="猎杀号剂 | %d金币\n下一战：穿甲+%s、暴击率+%s%%；对精英/Boss最终伤害+%s%%。战后清除。存放占1格；满格购买会立即饮用。\n%s" % [int(tuning.price),str(tuning.penetration),str(tuning.crit),str(tuning.boss_damage_bonus),"已饮用，等待下一战；同名效果不能再次饮用。" if status.pending else "当前战斗已生效。" if status.active else "购买后可在本页装备栏饮用。"]
 if not _quote.get("accepted",false): _detail.text+="\n"+_hunter_reason(str(_quote.get("reason","")))
func _hunter_reason(reason: String) -> String:
 return str({"elixir_run_finished":"本局已结束，没有下一场战斗，无法饮用。","same_name_elixir_active":"同名合剂已饮用，不能再次使用。","elixir_prebattle_only":"仅能在非战斗阶段饮用。","not_alive":"角色已死亡，无法饮用。"}.get(reason,reason_text(reason)))
