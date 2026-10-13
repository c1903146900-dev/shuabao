extends "res://elixir_war_20261009/panel.gd"
## UI-only next-battle use affordance. Original Model/Session command owns debit,
## source UID, tokens, replay, consumed-lineage sealing and pending replacement.
func refresh(force: bool = false) -> void:
 super.refresh(force)
 if not _state.get("ready",false) or not visible: return
 for index in range(_state.state.inventory.size()):
  var item: Dictionary = _state.state.inventory[index]
  if item.id!="elixir:05" or index>=_inventory.get_child_count(): continue
  var row: Node = _inventory.get_child(index)
  var button: Button = null
  for child: Node in row.get_children():
   if child is Button and child.has_meta("swift_elixir_use"): button=child;break
  if button==null:
   button=Button.new();button.text="饮用 · 下一战";button.set_meta("swift_elixir_use",true)
   button.pressed.connect(_drink_swift.bind(int(item.uid),button));row.add_child(button)
  var status: Dictionary = _session.ledger.model.swift_elixir_use_status(int(item.uid))
  button.disabled=not status.accepted
  button.tooltip_text="仅下一场战斗生效；饮用后此笔不可撤回" if status.accepted else _hunter_reason(str(status.reason))
func _drink_swift(uid: int, button: Button) -> void:
 if not is_instance_valid(button) or button.disabled: return
 button.disabled=true
 _request("consume",{"uid":uid},_session.ledger.model.commerce_token())
func _detail_for_selected() -> void:
 super._detail_for_selected()
 if _selected!="elixir:05" or not _state.get("ready",false): return
 var status: Dictionary = _session.ledger.model.swift_elixir_status()
 if not status.supported: return
 var tuning: Dictionary = status.tuning
 _detail.text="疾行合剂 | %d金币\n下一战：移动速度+%s%%、攻击速度+%s%%、冷却缩减+%s%%；Shift结束后额外移动速度+%s%%，持续%s战斗秒，重复只刷新不叠层。两项移动速度加算，短效期间合计%s%%。战后整体清除。存放占1格；满格购买会立即饮用。\n%s" % [int(tuning.price),str(tuning.move),str(tuning.attack_speed),str(tuning.cdr),str(tuning.after_shift_move),str(tuning.after_shift_duration),str(float(tuning.move)+float(tuning.after_shift_move)),"已饮用，等待下一战；同名效果不能再次饮用。" if status.pending else "当前战斗已生效。" if status.active else "购买后可在本页装备栏饮用。"]
 if not _quote.get("accepted",false): _detail.text+="\n"+_hunter_reason(str(_quote.get("reason","")))
