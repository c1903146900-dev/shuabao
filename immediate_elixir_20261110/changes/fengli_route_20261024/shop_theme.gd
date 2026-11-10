extends "res://tests/ink_intermediate_shop_ui_20261004/fix02/shop_panel.gd"
## Fengli-only presentation wrapper. Inherited geometry, font sizes, signals,
## Quotes, commerce tokens and commands still use the inherited ledger path.
var _elixir_drink_buttons: Dictionary = {}
var _elixir_status: Label
func _ready() -> void:
 super._ready()
 _elixir_status=Label.new()
 _elixir_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 _elixir_status.add_theme_font_size_override("font_size",13)
 _stats.get_parent().add_child(_elixir_status)
 _stats.get_parent().move_child(_elixir_status,_stats.get_index()+1)
 # 1. Duplicate the existing theme, changing color properties only.
 theme = theme.duplicate(true)
 theme.set_color("font_color", "Label", Color("e2f5f4"))
 for state:String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
  theme.set_color(state, "Button", Color("e2f5f4"))
 theme.set_color("font_disabled_color", "Button", Color("6e7c92"))
 for state:String in ["normal", "hover", "pressed", "focus", "disabled"]:
  var original:StyleBox = theme.get_stylebox(state, "Button")
  if not original is StyleBoxFlat:continue
  var box:StyleBoxFlat = original.duplicate(true)
  box.bg_color = Color("203247") if state in ["hover", "pressed"] else Color("18223a")
  box.border_color = Color("42e4d1") if state in ["hover", "pressed"] else Color("426678")
  if state == "focus":box.border_color = Color("c7f24a")
  if state == "disabled":
   box.bg_color = Color("141a30")
   box.border_color = Color("303d54")
  theme.set_stylebox(state, "Button", box)
 # Player wording only; retained controls/signals and footer position.
 _close.text="关闭商店（P）"
 var content:Node=_title.get_parent()
 var rule:Label=content.get_child(content.get_child_count()-1) as Label
 if rule!=null:
  rule.text="进入下一房后不能撤回；使用药品或生命变化后，部分交易也不能撤回。"
 # 2. Recolor the original top-level shade/panel, retaining all box metrics.
 for child:Node in get_children():
  if child is ColorRect:child.color = Color(.04,.05,.10,.86)
  elif child is PanelContainer:
   var original:StyleBox = child.get_theme_stylebox("panel")
   if original is StyleBoxFlat:
    var box:StyleBoxFlat = original.duplicate(true)
    box.bg_color = Color("141a30")
    box.border_color = Color("426678")
    child.add_theme_stylebox_override("panel", box)

func _detail_for_selected() -> void:
 super._detail_for_selected()
 # 3. Project existing selection only; never select, toggle or enable a row.
 # This original hook runs after both list rebuild and item selection.
 for id:Variant in _item_buttons:
  var button:Button = _item_buttons[id]
  if str(id) == _selected:
   var original:StyleBox = theme.get_stylebox("normal", "Button")
   if original is StyleBoxFlat:
    var selected:StyleBoxFlat = original.duplicate(true)
    selected.bg_color = Color("203247")
    selected.border_color = Color("c7f24a")
    button.add_theme_stylebox_override("normal", selected)
   button.add_theme_color_override("font_color", Color("c7f24a"))
  else:
   button.remove_theme_stylebox_override("normal")
   button.remove_theme_color_override("font_color")
 # Flask price text uses the existing fresh economic quote, never a second calculator.
 if _state.get("ready",false) and _state.catalog.items.has(_selected):
  var item:Dictionary=_state.catalog.items[_selected]
  if item.get("kind","")=="flask" and item.equipment_runtime.supported:
   _detail.text="%s | 总价%d金币\n%s秒内恢复%s%%最大生命，每场最多2次；与普通血瓶互斥，休息不补充。本试玩不支持出售药壶。"%[item.name,item.price,str(item.recovery.duration_seconds),str(item.recovery.heal_max_health_pct)]
   if _quote.get("accepted",false):
    _buy.text="%s %s（%d金币）"%["升级" if int(_quote.get("credit",0))>0 else "购买",item.name,int(_quote.charge)]
   else:
    _buy.text="不可购买："+_player_reason(str(_quote.reason))
    _detail.text+="\n"+_player_reason(str(_quote.reason))


 # Ordinary recovery values are the same admitted definitions used by the consumer.
 if _state.get("ready",false) and _state.catalog.items.has(_selected):
  var item:Dictionary=_state.catalog.items[_selected]
  if item.get("kind","")=="potion" and item.equipment_runtime.supported:
   var cap:int=int(_session.ledger.model.commerce_definitions.potion_cap)
   _detail.text="%s | %d金币\n%s秒角色战斗时间内恢复%s%%最大生命，受伤不中断；每次消耗1瓶。同档共占1槽，三档合计最多%d瓶；不能与循环药壶同时持有。"%[item.name,item.price,str(item.recovery.duration_seconds),str(item.recovery.heal_max_health_pct),cap]
   if not _quote.get("accepted",false):
    _detail.text+="\n"+_player_reason(str(_quote.reason))
    _buy.text="不可购买："+_player_reason(str(_quote.reason))
  elif item.equipment_runtime.supported and not _quote.get("accepted",false):
   var raw_reason:String=str(_quote.get("reason",""))
   _detail.text=_detail.text.replace(reason_text(raw_reason),_player_reason(raw_reason)).replace(commerce_reason(raw_reason),_player_reason(raw_reason))
   _buy.text="不可购买："+_player_reason(raw_reason)
  elif not item.equipment_runtime.supported:
   _detail.text="%s | %d金币\n本试玩暂不支持此商品。"%[item.name,item.price]
   _buy.text="本试玩暂不可购买"


 # All elixir definitions retain their original full effect text, including
 # unopened items. Availability remains the consumer-backed catalog's decision.
 if _state.get("ready",false) and _state.catalog.items.has(_selected):
  var item:Dictionary=_state.catalog.items[_selected]
  if item.get("kind","")=="elixir":
   _detail.text="%s | %d金币\n%s"%[item.name,item.price,str(item.get("source_effect",""))]
   _detail.text+="\n饮用后立即生效；持续至下一场战斗结束，休息点也会清除。未饮用的库存不受影响。"
   if not item.equipment_runtime.supported:
    _detail.text+="\n此合剂效果暂未开放。"
    _buy.text="本试玩暂不可购买"
   elif _quote.get("accepted",false):
    _detail.text+="\n"+str(_quote.get("outcome_text",""))
    _buy.text="购买并立即饮用（%d金币）"%int(_quote.get("charge",item.price)) if _quote.get("auto_drink",false) else "购买 %s（%d金币）"%[item.name,int(_quote.get("charge",item.price))]
   else:
    _detail.text+="\n"+_player_reason(str(_quote.get("reason","")))
    _buy.text="不可购买："+_player_reason(str(_quote.get("reason","")))

func refresh(force:bool=false)->void:
 # The inherited fix02 retires emitting rows safely. Clear only our references
 # at that same rebuild boundary; never free a pressed button synchronously.
 if _session!=null:
  var next_state:Dictionary=_session.ui_state()
  if next_state.get("ready",false) and next_state.panel_open and (force or int(next_state.state.revision)!=_shown_revision):
   _elixir_drink_buttons.clear()
 super.refresh(force)
 if not _state.get("ready",false) or not visible:return
 _refresh_elixir_controls()
 _title.text="安全商店 · 金币 %d · 装备 %d / 6"%[int(_state.state.gold),_state.state.inventory.size()]
 var receipt:Dictionary=_state.last_receipt
 if receipt.is_empty():_receipt.text="本次商店中的买卖可以撤回；关闭商店不会立即取消撤回机会。"
 elif not receipt.get("accepted",false):_receipt.text="未完成："+_player_reason(str(receipt.get("reason","")))
 else:
  var restored:float=float(receipt.get("health_projection",{}).get("undo_restored_own_clamp",0.0))
  _receipt.text="已撤回，恢复该交易减少的 %.0f 点生命。"%restored if restored>0.0 else "操作完成。"
 if receipt.get("accepted",false):
  for event in receipt.get("events",[]):
   if event.get("type","")=="elixir_activated":
    _receipt.text="装备栏已满，已购买并立即饮用生效；持续至下一场战斗结束或休息清除，该笔已使用交易不能撤回。" if receipt.get("auto_drink",false) else "已饮用并立即生效；持续至下一场战斗结束或休息清除，不同合剂替换旧合剂，该消费不能撤回。"
 for id:Variant in _item_buttons:
  var item:Dictionary=_state.catalog.items[id]
  if not item.equipment_runtime.supported:_item_buttons[id].text="%s · %d金 · 本试玩不可用"%[item.name,item.price]
  elif item.get("kind","")=="flask":_item_buttons[id].text="%s · 总价%d金"%[item.name,item.price]
 for index in range(mini(_sell_buttons.size(),_state.state.inventory.size())):
  var entry:Dictionary=_state.state.inventory[index]
  if _state.catalog.items[entry.id].get("kind","")=="flask":
   _sell_buttons[index].disabled=true
   _sell_buttons[index].text="本试玩不支持出售药壶"
   _sell_buttons[index].tooltip_text="本试玩不支持出售药壶；可按顺序升级。"

func _refresh_elixir_controls()->void:
 var active:Dictionary=_state.state.shop_visit.get("active_elixir",{})
 if active.is_empty():
  _elixir_status.text="战斗合剂：无已生效合剂；饮用后立即生效，持续至下一场战斗结束或休息清除。"
 else:
  var definition:Dictionary=_state.catalog.items.get(str(active.get("item","")),{})
  _elixir_status.text="已生效合剂：%s；持续至下一场战斗结束或休息清除。战前饮用不同合剂会替换旧合剂。"%str(definition.get("name",active.get("item","")))
 for index in range(_state.state.inventory.size()):
  var entry:Dictionary=_state.state.inventory[index]
  var item:Dictionary=_state.catalog.items[entry.id]
  if item.get("kind","")!="elixir" or not item.equipment_runtime.supported:continue
  var uid:int=int(entry.uid)
  if not _elixir_drink_buttons.has(uid):
   var button=Button.new()
   button.text="饮用"
   button.set_meta("elixir_uid",uid)
   # Bind the displayed token, not a freshly minted token after a stale click.
   button.pressed.connect(_drink_elixir.bind(uid,_session.ledger.model.commerce_token().duplicate(true)))
   _inventory.get_child(index).add_child(button)
   _elixir_drink_buttons[uid]=button
  var reason:String=_session.ledger.model.elixir_use_reason(uid)
  var button:Button=_elixir_drink_buttons[uid]
  button.disabled=not reason.is_empty()
  button.tooltip_text=_player_reason(reason) if not reason.is_empty() else "饮用后立即生效，持续至下一场战斗结束或休息清除；不同合剂替换旧合剂，该消费不能撤回。"

func _drink_elixir(uid:int,token:Dictionary)->void:
 if not visible or not _elixir_drink_buttons.has(uid):return
 var button:Button=_elixir_drink_buttons[uid]
 if not is_instance_valid(button) or button.disabled:return
 _request("consume",{"uid":uid},token)

func _player_reason(reason:String)->String:
 var labels:Dictionary={"same_name_elixir_active":"同名合剂已生效，不能再次饮用","elixir_prebattle_only":"合剂只能在战前安全商店饮用","elixir_run_finished":"本局已结束，不能再饮用合剂","elixir_consumer_unbound":"合剂效果尚未接入","elixir_effect_not_supported":"此合剂效果暂未开放","already_used":"合剂已使用，该交易及其依赖不能撤回","missing_item":"这瓶合剂已不在装备栏，请刷新","stale_room":"房间已变化，请重新打开商店","insufficient_gold":"金币不足","inventory_full":"六个装备槽已满","potion_cap":"普通药剂已达携带上限","recovery_mutex":"普通药剂与循环药壶不能同时持有","flask_already_owned":"已持有这档药壶","flask_upgrade_order":"请按顺序升级药壶","unresolved_flask_switch_economics":"本试玩不支持出售药壶","undo_boundary":"本次商店访问没有可撤回的交易","hp_dependency_changed":"生命状态已变化，这笔交易不能撤回","hp_consumption_dependency":"药品已经使用，这笔交易不能撤回","stale_revision":"状态已变化，请重新选择商品","stale_epoch":"商店状态已变化，请重新打开商店","shop_after_real_battle_only":"战斗中不能打开商店","mandatory_hex_pending":"请先完成待选海克斯"}
 return str(labels.get(reason,"当前无法完成此操作。"))
