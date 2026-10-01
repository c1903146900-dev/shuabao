extends "res://scripts/integration/room.gd"
## Read-only observer. No fixture HP, enemy, skill, ledger, AI or clock changes.
var qa_inputs := []
func _ready():
 super._ready()
 get_window().title = 'QA_CHECKPOINT_WINDOW'
func _input(event):
 super._input(event)
 if event is InputEventKey:qa_inputs.append({'wall':Time.get_ticks_msec(),'key':event.keycode,'pressed':event.pressed,'echo':event.echo})
 if event is InputEventMouseButton:qa_inputs.append({'wall':Time.get_ticks_msec(),'button':event.button_index,'pressed':event.pressed})
func qa_read():
 var controls := {}
 for pair in [['allocation',live_hud.allocation],['close',live_hud.close_button],['start',start_button],['learn_q',live_hud.rows.Q.buy],['supply_close',live_hud.supply_close],['iron_blade',live_hud.shop_buttons.iron_blade]]:
  var p=pair[1].get_global_rect().get_center();controls[pair[0]]=[p.x,p.y]
 var targets := []
 for enemy in simulation.enemies:
  if not enemy.dead:
   var p=camera.unproject_position(enemy.position)
   targets.append({'id':enemy.actor_id,'screen':[p.x,p.y],'distance':enemy.position.distance_to(simulation.hero.position)})
 return JSON.stringify({'state':integration_snapshot(),'AD':simulation.hero.stats.ad,'controls':controls,'targets':targets,'viewport':[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y],'events':simulation.event_log,'inputs':qa_inputs,'wall':Time.get_ticks_msec()})
