extends "res://tests/ink_intermediate_shop_ui_20261004/fix02/shop_panel.gd"
## UI-only successor. Requests contain displayed tokens, never trusted commerce
## payloads. Retiring rows/buttons cannot issue another command while emitting.
var _training_box: VBoxContainer
var _training_summary: Label
var _training_pay: Button
var _training_choices: VBoxContainer
var _training_note: Label
var _training_view: Dictionary = {}
var _training_busy: bool = false
var _training_pending_shown: int = -1
var _training_render_key: String = ""

func _ready() -> void:
 super._ready()
 var tabs: HBoxContainer = _title.get_parent().get_child(1)
 var tab := Button.new()
 tab.text = "锻体 · 900金"
 tab.pressed.connect(_set_category.bind("training"))
 tabs.add_child(tab)
 _training_box = VBoxContainer.new()
 _training_box.add_theme_constant_override("separation",12)
 _detail.get_parent().add_child(_training_box)
 _training_box.get_parent().move_child(_training_box,0)
 _training_summary = Label.new()
 _training_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 _training_box.add_child(_training_summary)
 _training_pay = Button.new()
 _training_pay.text = "锻体 · 900金币"
 _training_pay.custom_minimum_size.y = 42
 _training_pay.pressed.connect(_pay_training)
 _training_box.add_child(_training_pay)
 _training_choices = VBoxContainer.new()
 _training_choices.add_theme_constant_override("separation",8)
 _training_box.add_child(_training_choices)
 _training_note = Label.new()
 _training_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 _training_box.add_child(_training_note)
 _training_box.visible = false

func refresh(force: bool = false) -> void:
 if _session != null:
  var next: Dictionary = _session.ui_state()
  var pending: Dictionary = next.get("formal_training",{}).get("pending",{})
  var pending_id: int = int(pending.get("purchase_id",-1))
  if pending_id != -1 and pending_id != _training_pending_shown:
   _category = "training"
   force = true
  _training_pending_shown = pending_id
 super.refresh(force)
 if not _state.get("ready",false) or not visible or not is_instance_valid(_training_box): return
 _training_view = _state.get("formal_training",{}).duplicate(true)
 var key: String = str(_state.state.revision)+":"+_category+":"+str(_training_view.get("can_pay",false))+":"+str(_training_view.get("can_select",false))+":"+str(_training_view.get("reason",""))
 if force or key != _training_render_key:
  _training_render_key = key
  _training_busy = false
  _render_training()
 var showing: bool = _category == "training"
 for child in _training_box.get_parent().get_children():
  if child is Control: child.visible = showing if child == _training_box else not showing
 if not showing: return
 if not _state.last_receipt.is_empty() and not _state.last_receipt.get("accepted",false):
  _receipt.text = "未执行："+_training_reason(str(_state.last_receipt.get("reason","unknown")))

func _render_training() -> void:
 _retire_rows(_training_choices)
 if _category == "training":
  _retire_rows(_list)
  _item_buttons.clear()
  var intro := Label.new()
  intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  intro.custom_minimum_size = Vector2(320,0)
  intro.text = "锻体 · 永久成长\n\n每次固定900金币，无次数上限。\n随机显示3个不同的有效纯属性选项，选1项永久获得。\n\n不占装备格或药品栏。\n付款与选择均不可撤回。\n关闭商店后，待选项仍会保留。"
  _list.add_child(intro)
 _training_summary.text = "本局已完成锻体 %d 次 · 固定 %d 金币/次" % [int(_training_view.get("completed_count",0)),int(_training_view.get("price",900))]
 _training_pay.disabled = not _training_view.get("can_pay",false)
 _training_pay.text = "锻体 · %d金币" % int(_training_view.get("price",900))
 var pending: Dictionary = _training_view.get("pending",{})
 if pending.is_empty():
  var reason: String = str(_training_view.get("reason",""))
  _training_note.text = "达到实际属性上限的选项不会出现；尚有部分提升空间的选项仍可出现。"
  if not reason.is_empty(): _training_note.text += "\n"+_training_reason(reason)
 else:
  _training_pay.disabled = true
  _training_pay.text = "已付款 · 请完成下方三选一"
  _training_note.text = "选择1项立即生效，本局永久保留。关闭后可回来继续选择。"
  for option: Dictionary in _training_view.get("options",[]):
   var button := Button.new()
   button.text = str(option.name)+" · "+str(option.label)
   button.custom_minimum_size.y = 46
   button.alignment = HORIZONTAL_ALIGNMENT_LEFT
   button.tooltip_text = str(option.label)+"；永久获得，不可撤回。"
   if option.runtime_stat == "max_hp": button.tooltip_text += "提高生命上限不会额外治疗。"
   button.disabled = not _training_view.get("can_select",false)
   button.pressed.connect(_choose_training.bind(int(pending.purchase_id),str(option.id),_training_view.token.duplicate(true)))
   _training_choices.add_child(button)

func _pay_training() -> void:
 if _training_busy or _training_pay.disabled or not _training_view.get("can_pay",false): return
 _training_busy = true
 _disable_training_buttons()
 _request("training_pay",{},_training_view.token)
 # Host processes synchronously. A rejection may leave revision unchanged.
 refresh(true)

func _choose_training(purchase_id: int, outcome: String, token: Dictionary) -> void:
 if _training_busy or not _training_view.get("can_select",false): return
 _training_busy = true
 _disable_training_buttons()
 _request("training_select",{"purchase_id":purchase_id,"outcome":outcome},token)
 refresh(true)

func _disable_training_buttons() -> void:
 _training_pay.disabled = true
 _disable_retiring_buttons(_training_choices)

static func _training_reason(reason: String) -> String:
 var reasons: Dictionary = {"body_pool_exhausted":"有效锻体选项不足，暂不能付款", "training_effective_source_unbound":"锻体暂未就绪", "training_effective_stats_unavailable":"锻体暂未就绪", "training_effective_cap_reached":"该属性已达到实际上限", "invalid_body_choice":"该选项不属于本次锻体", "already_selected":"本次锻体已完成", "missing_body_purchase":"本次锻体已失效", "stale_epoch":"商店访问已变化，请重新选择", "stale_room":"所在区域已变化，请重新打开商店", "shop_panel_not_open":"请先打开商店", "mandatory_hex_pending":"请先完成海克斯选择"}
 return str(reasons.get(reason,commerce_reason(reason)))

static func retire_existing(panel: Control) -> void:
 # Called once during the retained host's normal fresh controls construction.
 # Disconnect old outward signals before detach; queue_free after callbacks unwind.
 if not is_instance_valid(panel): return
 _disable_tree(panel)
 for signal_name: String in ["close_requested","transaction_requested"]:
  for connection: Dictionary in panel.get_signal_connection_list(signal_name):
   panel.disconnect(signal_name,connection.callable)
 panel.visible = false
 if panel.get_parent() != null: panel.get_parent().remove_child(panel)
 panel.queue_free()

static func _disable_tree(node: Node) -> void:
 if node is BaseButton: node.disabled = true
 if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
 for child: Node in node.get_children(): _disable_tree(child)
