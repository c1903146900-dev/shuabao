extends "res://visual_rework_20261009/postboss_potion_controls.gd"
var route_host:Node
const COMPACT_POTION_GAP:float=6.0
func _ready()->void:
 super._ready()
 # The inherited 372 x 32 minimum and old y=570 strip must not survive.
 # Buttons remain direct children for the inherited inventory/terminal logic.
 custom_minimum_size=Vector2.ZERO
 size=Vector2.ZERO
 position=Vector2.ZERO
func _process(delta:float)->void:
 super._process(delta)
 if route_host==null:return
 _sync_flask_button()
 visible=not route_host.finished and not _session.exit_map_open and not _session.panel_open and not _session.initial_modal_open and not route_host.initial_hud.bottom_popup.visible
 for child in get_children():
  if child is Button and not child.has_meta("fengli_potion_styled"):
   route_host.initial_hud._style_button(child);child.set_meta("fengli_potion_styled",true)
 _layout_compact_buttons()

func _layout_compact_buttons()->void:
 var buttons:Array[Button]=[]
 for child in get_children():
  if child is Button:
   # Top-level Controls are excluded from native HBox child sorting. They stay
   # direct children for source inventory removal and terminal-state disabling.
   child.set_as_top_level(true)
   child.custom_minimum_size=BUTTON_SIZE
   child.size=BUTTON_SIZE
   buttons.append(child)
 var columns:int=mini(2,buttons.size())
 var rows:int=ceili(float(buttons.size())/2.0)
 var dock_size:=Vector2(float(columns)*BUTTON_SIZE.x+maxi(0,columns-1)*COMPACT_POTION_GAP,float(rows)*BUTTON_SIZE.y+maxi(0,rows-1)*COMPACT_POTION_GAP)
 route_host.initial_hud.set_potion_dock_width(dock_size.x if visible else 0.0)
 var bar:PanelContainer=route_host.initial_hud.bottom_bar
 # Bottom-align inside the same 110 px band; all four supported slots fit in
 # two 32 px rows. There is no opaque panel or mouse target between buttons.
 position=bar.position+Vector2(bar.size.x+route_host.initial_hud.POTION_DOCK_GAP,bar.size.y-dock_size.y)
 update_minimum_size()
 size=dock_size
 for index:int in range(buttons.size()):
  var button:Button=buttons[index]
  var offset:=Vector2(float(index%2)*(BUTTON_SIZE.x+COMPACT_POTION_GAP),float(floori(float(index)/2.0))*(BUTTON_SIZE.y+COMPACT_POTION_GAP))
  button.position=get_global_transform().origin+offset
func _use(uid:int)->void:
 if route_host==null or not visible or route_host._blocked():return
 super._use(uid)

func _sync_flask_button()->void:
 if _session==null or _session.ledger==null:return
 var model:RefCounted=_session.ledger.model
 var held:Dictionary={}
 for entry in model.state.inventory:
  if str(entry.id) in ["flask:1","flask:2","flask:3"]:held=entry;break
 var button:Button=get_node_or_null("ReusableFlask")
 if held.is_empty():
  if button!=null:remove_child(button);button.queue_free()
  return
 if button==null:
  button=Button.new();button.name="ReusableFlask"
  button.custom_minimum_size=BUTTON_SIZE
  button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
  button.clip_text=true
  add_child(button)
 # UID changes after upgrade; never retain a stale bound UID.
 if int(button.get_meta("flask_uid",-1))!=int(held.uid):
  for connection in button.pressed.get_connections():button.pressed.disconnect(connection.callable)
  button.pressed.connect(_use.bind(int(held.uid)))
  button.set_meta("flask_uid",int(held.uid))
 var definition:Dictionary=model.commerce_definitions.items[held.id]
 var charges:int=int(model.state.shop_visit.flask_charges)
 button.text="%s ×%d"%[definition.name,charges]
 button.tooltip_text="%s：%s秒角色战斗时间内恢复%s%%最大生命；每场战斗最多2次，休息不补充。非战斗暂停恢复，休息清除剩余恢复。"%[definition.name,str(definition.recovery.duration_seconds),str(definition.recovery.heal_max_health_pct)]
 button.disabled=charges<=0 or _session.panel_open or not model.flask_consumer.preflight(str(held.id)).is_empty()
