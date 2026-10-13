extends Control
## Lightweight source-ledger shop UI. No inventory or currency ownership.
signal close_requested
signal transaction_requested(command_id: String, action: String, arguments: Dictionary)
const Style=preload("res://tests/ink_style_specimen_20261004/style.gd")
const REASONS={"insufficient_gold":"金币不足", "inventory_full":"六个装备槽已满", "regen_time_unit_unresolved":"恢复时间单位未定义，暂不能购买", "outside_base_equipment_slice":"该装备属性或效果尚未接入", "consumable_effect_consumer_not_connected":"真实消耗效果尚未接入", "hp_dependency_changed":"中间生命变化已封存相关交易", "hp_consumption_dependency":"不可逆消费已封存相关交易", "undo_boundary":"本次访问没有可撤回交易", "stale_revision":"状态已变化，请重试新报价", "shop_after_real_battle_only":"战斗中不能进入安全商店", "mandatory_hex_pool_not_ready":"普通入口：初始海克斯候选不足，开战暂停", "ordinary_12_row_content_unconfigured":"正式12行内容待接入", "close_shop_before_room_transition":"请先关闭商店，再进入下一房", "resume_before_room_transition":"请先按空格恢复", "diagnostic_segment_complete":"两战接线段已完成", "body_choice_pending":"先完成锻体选择"}
var _session: RefCounted
var _state: Dictionary={}
var _shown_revision: int=-1
var _category: String="base"
var _selected: String="base:B01"
var _serial: int=0
var _quote: Dictionary={}
var _list: VBoxContainer
var _inventory: VBoxContainer
var _title: Label
var _stats: Label
var _detail: Label
var _receipt: Label
var _buy: Button
var _undo: Button
var _close: Button
var _item_buttons: Dictionary={}
var _sell_buttons: Array=[]
func _ready() -> void:
 theme=Style.ui_theme();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_STOP
 var shade=ColorRect.new();shade.color=Color(0.03,0.06,0.07,0.86);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var panel=PanelContainer.new();add_child(panel);panel.position=Vector2(100,76);panel.size=Vector2(1080,550)
 var background=StyleBoxFlat.new();background.bg_color=Style.SURFACE;background.border_color=Style.EDGE;background.set_border_width_all(1)
 panel.add_theme_stylebox_override("panel",background)
 var content=VBoxContainer.new();content.add_theme_constant_override("separation",9);panel.add_child(content)
 _title=Label.new();content.add_child(_title)
 var tabs=HBoxContainer.new();content.add_child(tabs)
 for entry in [["base","基础12"],["intermediate","合成18"],["final","成装42"],["consumables","消耗品11"]]:
  var button=Button.new();button.text=entry[1];button.pressed.connect(_set_category.bind(str(entry[0])));tabs.add_child(button)
 var columns=HBoxContainer.new();columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;columns.add_theme_constant_override("separation",16);content.add_child(columns)
 var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(340,320);columns.add_child(scroll)
 _list=VBoxContainer.new();_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(_list)
 var right=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(right)
 _detail=Label.new();_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_detail.custom_minimum_size=Vector2(650,66);right.add_child(_detail)
 _buy=Button.new();_buy.text="购买";_buy.pressed.connect(_purchase);right.add_child(_buy)
 _stats=Label.new();_stats.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;right.add_child(_stats)
 var held=Label.new();held.text="当前装备（出售返还实际投入的90%）";right.add_child(held)
 _inventory=VBoxContainer.new();right.add_child(_inventory)
 _receipt=Label.new();_receipt.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_receipt.custom_minimum_size=Vector2(0,42);content.add_child(_receipt)
 var buttons=HBoxContainer.new();content.add_child(buttons)
 _undo=Button.new();_undo.text="撤回上一笔";_undo.pressed.connect(_reverse);buttons.add_child(_undo)
 _close=Button.new();_close.text="关闭 B / Esc（仍保留本次撤回）";_close.pressed.connect(func():close_requested.emit());buttons.add_child(_close)
 var rule=Label.new();rule.text="进入任何下一房后提交。治疗/消费依赖可能封存交易；撤回只恢复该笔造成的生命截断。";rule.add_theme_font_size_override("font_size",13);content.add_child(rule)
 visible=false
func bind_session(session: RefCounted) -> void:
 _session=session;_shown_revision=-1
func _set_category(category: String) -> void:
 _category=category;_shown_revision=-1;refresh(true)
func _select(id: String) -> void:
 _selected=id;_detail_for_selected()
func refresh(force: bool=false) -> void:
 if _session==null:return
 _state=_session.ui_state()
 if not _state.get("ready",false):return
 visible=_state.panel_open
 if not visible:return
 var revision: int=int(_state.state.revision)
 if not force and revision==_shown_revision:return
 _shown_revision=revision
 _title.text="安全商店 · 金币 %d · 装备 %d / 6 · %s"%[_state.state.gold,_state.state.inventory.size(),"真实战斗诊断，非普通入口" if _state.diagnostic else "普通入口（初始海克斯待就绪）"]
 for child in _list.get_children():child.free()
 _item_buttons.clear()
 for id in _state.catalog.items:
  var item: Dictionary=_state.catalog.items[id]
  var category: String=str(id).get_slice(":",0)
  if (_category=="consumables" and category not in ["potion","flask","elixir"]) or (_category!="consumables" and category!=_category):continue
  var status: Dictionary=item.equipment_runtime
  var button=Button.new();button.text="%s  %d金%s"%[item.name,item.price,"" if status.supported else " · 暂未接入"]
  button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.pressed.connect(_select.bind(str(id)))
  button.tooltip_text="点击查看属性与禁用原因";_list.add_child(button);_item_buttons[id]=button
 for child in _inventory.get_children():child.free()
 _sell_buttons.clear()
 for slot in range(6):
  var row=HBoxContainer.new();_inventory.add_child(row)
  var text_label=Label.new();text_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text_label)
  if slot<_state.state.inventory.size():
   var item: Dictionary=_state.state.inventory[slot]
   text_label.text="%d. %s"%[slot+1,_state.catalog.items[item.id].name]
   var button=Button.new();button.text="出售 +%d金"%floori(float(item.invested)*0.9);button.pressed.connect(_sell.bind(int(item.uid)));row.add_child(button);_sell_buttons.append(button)
  else:text_label.text="%d. 空槽"%(slot+1)
 _stats.text="AD %.0f  AP %.0f  生命 %.0f / %.0f  防御 %.0f\n攻速 %.3f  移速 %.2f  暴击 %.0f%%  吸血 %.0f%%"%[_state.stats.ad,_state.stats.ap,_state.hp,_state.stats.max_hp,_state.stats.defence,_state.stats.attack_speed,_state.stats.move_speed,100.0*float(_state.stats.crit_chance),100.0*float(_state.stats.lifesteal)]
 _undo.disabled=_state.state.shop_visit.undo.is_empty()
 _receipt.text=receipt_text(_state.last_receipt)
 _detail_for_selected()
func _detail_for_selected() -> void:
 if not _state.get("ready",false) or not _state.catalog.items.has(_selected):return
 var item: Dictionary=_state.catalog.items[_selected]
 var status: Dictionary=item.equipment_runtime
 _quote=_session.ledger.model.commerce_quote(_selected)
 var detail: String="%s  |  %d金币\n"%[item.name,item.price]
 if status.supported:
  var labels: Dictionary={"AD":"攻击力","AP":"法术强度","attack_speed":"攻速","crit_chance":"暴击率","cooldown_reduction":"冷却缩减","max_hp":"生命上限","defense":"防御","move_speed":"移速","lifesteal":"吸血","tenacity":"韧性","penetration":"穿甲"}
  for stat in status.stats:
   var fraction: bool=stat in ["attack_speed","crit_chance","cooldown_reduction","move_speed","lifesteal","tenacity"]
   detail+="%s +%.2f%s"%[labels.get(stat,stat),float(status.stats[stat])*(100.0 if fraction else 1.0),"%" if fraction else ""]
  if not _quote.accepted:detail+="\n"+reason_text(str(_quote.reason))
 else:detail+=reason_text(str(status.reason))
 _detail.text=detail
 _buy.disabled=not _quote.get("accepted",false)
 _buy.text="购买 %s（%d金币）"%[item.name,item.price] if status.supported else "不可购买："+reason_text(str(status.reason))
func _request(action: String, extra: Dictionary, token: Dictionary) -> void:
 _serial+=1
 var arguments: Dictionary=token.duplicate(true);arguments.merge(extra,true)
 transaction_requested.emit("shop-ui-command:%d"%_serial,action,arguments)
func _purchase() -> void:
 if _buy.disabled or not _quote.get("accepted",false):return
 _request("buy",{"item":_selected},_quote.token)
func _sell(uid: int) -> void:_request("sell",{"uid":uid},_session.ledger.model.commerce_token())
func _reverse() -> void:_request("undo",{},_session.ledger.model.commerce_token())
static func reason_text(reason: String) -> String:
 if reason.begins_with("equipment_runtime_hold:"):return REASONS.get(reason.get_slice(":",3),"此商品实际效果未接入")
 return str(REASONS.get(reason,reason))
static func receipt_text(receipt: Dictionary) -> String:
 if receipt.is_empty():return "同次访问可撤买卖；关闭面板不会提交。"
 if not receipt.get("accepted",false):return "未执行："+reason_text(str(receipt.get("reason","unknown")))
 var hp: Dictionary=receipt.get("health_projection",{})
 if float(hp.get("undo_restored_own_clamp",0.0))>0:return "已撤回；恢复该笔截去的 %.0f 生命（不触发治疗）。"%float(hp.undo_restored_own_clamp)
 return "已完成；金币、物品与属性来自同一本局账本。"
