extends "res://scripts/integration/room.gd"
var qa_inputs=[]
var qa_events=[]
var qa_frames=[]
var qa_timer=0.0
func _ready():
 super._ready();get_window().title='QA_CHECKPOINT_WINDOW'
func _input(event):
 super._input(event)
 if event is InputEventKey:qa_inputs.append({'wall':Time.get_ticks_msec(),'key':event.keycode,'pressed':event.pressed,'echo':event.echo})
 if event is InputEventMouseButton:qa_inputs.append({'wall':Time.get_ticks_msec(),'button':event.button_index,'pressed':event.pressed})
func _on_combat_event(event):
 super._on_combat_event(event)
 qa_events.append({'event':event.duplicate(true),'hero':{'hp':simulation.hero.hp,'state':simulation.hero.cast_state.duplicate(true),'e3':simulation.hero.overload_left,'cd':simulation.hero.cooldowns.duplicate(true),'untargetable':simulation.hero.untargetable,'immune':simulation.extensions.is_immune()},'scale':simulation.clock.scale_factor()})
 if qa_events.size()>20:qa_events.pop_front()
func _physics_process(dt):
 super._physics_process(dt);qa_timer+=dt
 if qa_timer>=.025:
  qa_timer=0
  qa_frames.append({'time':simulation.clock.world_time,'phase':simulation.phase,'hp':simulation.hero.hp,'q2':simulation.hero.cast_state.has('q2'),'immune':simulation.extensions.is_immune(),'untargetable':simulation.hero.untargetable,'e3':simulation.hero.overload_left,'state':simulation.hero.cast_state.duplicate(true),'cooldowns':simulation.hero.cooldowns.duplicate(true)})
  if qa_frames.size()>12:qa_frames.pop_front()
func qa_read():
 var controls={};var buttons={'start':start_button,'allocation':live_hud.allocation,'mute':mute_button}
 for slot in ['Q','E','R','P']:
  buttons['learn_'+slot]=live_hud.rows[slot].buy;buttons['options_'+slot]=live_hud.rows[slot].options
 for id in buttons:
  var p=buttons[id].get_global_rect().get_center();controls[id]={'point':[p.x,p.y],'disabled':buttons[id].disabled}
 var choices={}
 for slot in ['Q','E','R','P']:
  var opt=live_hud.rows[slot].options;var pop=opt.get_popup()
  choices[slot]={'selected':opt.selected,'visible':pop.visible,'embedded':pop.is_embedded(),'position':[pop.position.x,pop.position.y],'size':[pop.size.x,pop.size.y],'count':pop.get_item_count()}
 var targets=[]
 for enemy in simulation.enemies:
  if not enemy.dead:
   var p=camera.unproject_position(enemy.position);targets.append({'id':enemy.actor_id,'screen':[p.x,p.y],'distance':enemy.position.distance_to(simulation.hero.position),'hp':enemy.hp,'timer':enemy.timer,'state':enemy.state})
 var aim=camera.unproject_position(Vector3(10,0,10))
 return JSON.stringify({'choices':choices,'state':integration_snapshot(),'controls':controls,'targets':targets,'empty_aim':[aim.x,aim.y],'viewport':[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y],'events':qa_events,'frames':qa_frames,'inputs':qa_inputs.slice(-60),'wall':Time.get_ticks_msec()})
