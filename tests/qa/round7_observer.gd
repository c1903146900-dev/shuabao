extends "res://scripts/integration/room.gd"
## Only records observations and changes the window title; no fixture game mutations.
var qa_inputs=[]
func _ready():
 super._ready()
 get_window().title='QA_CHECKPOINT_WINDOW'
func _input(event):
 super._input(event)
 if event is InputEventKey:qa_inputs.append({'wall':Time.get_ticks_msec(),'key':event.keycode,'pressed':event.pressed,'echo':event.echo})
 if event is InputEventMouseButton:qa_inputs.append({'wall':Time.get_ticks_msec(),'button':event.button_index,'pressed':event.pressed})
func qa_read():
 var controls={}
 var buttons={'allocation':live_hud.allocation,'start':start_button,'learn_q':live_hud.rows.Q.buy,'hex_open':live_hud.hex_open,'undo_shop':live_hud.undo_shop}
 for id in live_hud.shop_buttons:buttons['buy_'+id]=live_hud.shop_buttons[id]
 for i in range(6):
  buttons['use_'+str(i)]=live_hud.use_buttons[i];buttons['sell_'+str(i)]=live_hud.sell_buttons[i];buttons['equip_'+str(i)]=live_hud.equipment[i]
 for i in range(4):buttons['hex_'+str(i)]=live_hud.hex_cards[i].select
 for id in buttons:
  var b=buttons[id];var p=b.get_global_rect().get_center()
  controls[id]={'point':[p.x,p.y],'disabled':b.disabled,'visible':b.is_visible_in_tree()}
 var tabbar=live_hud.tabs.get_tab_bar()
 for i in range(3):
  var p=tabbar.get_global_position()+tabbar.get_tab_rect(i).get_center();controls['tab_'+str(i)]={'point':[p.x,p.y],'disabled':false,'visible':tabbar.is_visible_in_tree()}
 var scroll=live_hud.shop_grid.get_parent();var rect=scroll.get_global_rect()
 var targets=[]
 for enemy in simulation.enemies:
  if not enemy.dead:
   var p=camera.unproject_position(enemy.position);targets.append({'id':enemy.actor_id,'screen':[p.x,p.y],'distance':enemy.position.distance_to(simulation.hero.position)})
 var focus=get_viewport().gui_get_focus_owner()
 return JSON.stringify({'state':integration_snapshot(),'stats':simulation.hero.stats,'controls':controls,'targets':targets,'viewport':[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y],'scroll':[rect.position.x,rect.position.y,rect.size.x,rect.size.y],'scroll_y':scroll.scroll_vertical,'events':simulation.event_log,'inputs':qa_inputs,'wall':Time.get_ticks_msec(),'focus':str(focus.get_path()) if focus else '', 'last_result':controller.last_result,'receipts':controller.receipt_log,'effects':ledger.model.aggregate_effects()})
