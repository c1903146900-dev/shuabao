extends "res://scripts/integration/room.gd"
var qa_tag=""
var qa_hits=[]
var qa_frames=[]
var qa_inputs=[]
var qa_timer=0.0
var qa_t=0.0
var qa_panels=0
var qa_last_panel=false
func qa_prepare(tag):
 new_run();get_window().title="QA_CHECKPOINT_WINDOW";get_window().size=Vector2i(1280,720)
 qa_tag=tag;qa_hits.clear();qa_frames.clear();qa_inputs.clear();qa_timer=0;qa_t=0;qa_panels=0;qa_last_panel=false
 if tag in ['e3','e2','r2','q2','e1']:
  ledger.model.state.level=6;ledger.model.state.points=6;ledger.model.state.granted_level_ids=[1,2,3,4,5,6]
  var slot=str(tag).left(1).to_upper()
  ledger.model.command('qa-learn','learn',{'slot':slot,'candidate':str(tag).to_upper(),'expected_rank':0});simulation._sync_loadout_from_ledger()
 start_room();simulation.enemies.clear();simulation.hero.position=Vector3.ZERO;simulation.hero.stats.regen=0
 simulation.ai_enabled=tag in ['death','true_death','hit'];simulation.auto_finish=tag in ['victory','death','true_death']
 var enemy=simulation.spawn_enemy('minion',Vector3(0,0,-2),64 if tag=='victory' else 10000)
 if tag in ['death','true_death','hit']:
  simulation.hero.hp=240 if tag=='hit' else 1;simulation.hero.self_rescue_used=tag=='true_death';enemy.position=Vector3(0,0,-1);enemy.timer=0
 mouse_at=camera.unproject_position(enemy.position)
 _sync_views(0);_present()
 return qa_read()
func _input(event):
 super._input(event)
 if event is InputEventKey:qa_inputs.append({'time':qa_t,'key':event.keycode,'pressed':event.pressed,'echo':event.echo})
 if event is InputEventMouseButton:qa_inputs.append({'time':qa_t,'button':event.button_index,'pressed':event.pressed})
func _physics_process(dt):
 super._physics_process(dt)
 qa_t+=dt;qa_timer+=dt
 if is_instance_valid(live_hud):
  if live_hud.shade.visible and not qa_last_panel:qa_panels+=1
  qa_last_panel=live_hud.shade.visible
 if qa_timer>=.05 and is_instance_valid(live_hud):
  qa_timer=0
  qa_frames.append({'t':qa_t,'phase':simulation.phase,'position':str(simulation.hero.position),'hp':simulation.hero.hp,'panel':live_hud.shade.visible,'held':held_keys.duplicate(),'physical_w':Input.is_physical_key_pressed(KEY_W),'attacking':attacking,'q':simulation.hero.cast_state.duplicate(true),'e3':simulation.hero.overload_left,'clip':str(views.fengli.animation_player.current_animation) if views.has('fengli') else '', 'hero_clip':hero_clip.duplicate(true),'hud_e':live_hud.slots.E.text,'hud_r':live_hud.slots.R.text})
func qa_material_bindings():
 var result=[]
 for id in views:
  var v=views[id];var count=0;var matches=0
  for mesh in v.visual.find_children('*','MeshInstance3D',true,false):
   if not mesh.is_visible_in_tree():continue
   count+=1
   if mesh.material_override==v.material:matches+=1
   for surface in range(mesh.mesh.get_surface_count()):
    if mesh.get_active_material(surface)==v.material:matches+=1
  result.append({'id':id,'imported':v.imported_art,'visible_meshes':count,'flash_material_bindings':matches,'flash_left':v.flash_left,'flash_color':str(v.material.albedo_color)})
 return result
func qa_read():
 var controls={}
 for pair in [['allocation',live_hud.allocation],['close',live_hud.close_button],['start',start_button]]:
  var p=pair[1].get_global_rect().get_center();controls[pair[0]]=[p.x,p.y]
 var aim=camera.unproject_position(Vector3(0,0,-2));controls.aim=[aim.x,aim.y]
 var focus=get_viewport().gui_get_focus_owner()
 return JSON.stringify({'tag':qa_tag,'state':integration_snapshot(),'frames':qa_frames,'inputs':qa_inputs,'panel_opens':qa_panels,'controls':controls,'viewport':[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y],'focus':str(focus.get_path()) if focus else '', 'hits':qa_hits,'materials':qa_material_bindings(),'events':simulation.event_log})

func _on_combat_event(event):
 super._on_combat_event(event)
 if event.kind in ['damage','hero_damaged']:
  qa_hits.append({'event':event.duplicate(true),'bindings_at_hit':qa_material_bindings()})
