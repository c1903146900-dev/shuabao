extends "res://scripts/integration/room.gd"
# Explicit controlled fixture. Replaces simulation, never presented as natural play.
var rows=[]
func qa_setup(preset):
 set_physics_process(false)
 simulation.free()
 for v in views.values():v.free()
 views.clear();motion.clear();hero_clip.clear()
 simulation=Sim.new();add_child(simulation)
 simulation.ai_enabled=false;simulation.auto_finish=false
 simulation.configure_test_loadout(preset)
 simulation.hero.position=Vector3.ZERO
 simulation.spawn_enemy('minion',Vector3(0,0,-1),10000)
 simulation.spawn_enemy('minion',Vector3(1,0,-1),10000)
 simulation.combat_event.connect(_on_combat_event)
 audio_router.last_sequence=-1;audio_router.hit_groups.clear();audio_router.sfx.stop_all()
 _sync_views(0);_animate(0)
func pose():
 var p=views.fengli.animation_player
 return {'clip':p.current_animation,'position':p.current_animation_position,'length':p.current_animation_length,'motion':motion.fengli.duplicate(),'world':simulation.clock.world_time,'presenters':simulation.clock.presenters.duplicate()}
func qa_animation():
 rows=[]
 for pair in [['e2','e','attack'],['r2','r','ultimate'],['r1','r','ultimate']]:
  qa_setup({'e':pair[0] if pair[1]=='e' else 'e1','r':pair[0] if pair[1]=='r' else 'r1'})
  var result=simulation.request_action(pair[1],Vector3.FORWARD)
  var frames=[]
  for i in (60 if pair[0]=='r1' else 12):
   simulation.step(.015);_sync_views(.015);_animate(.015)
   var first=pose()
   # Repeated view sync must not overwrite manual sampling.
   _sync_views(0)
   frames.append({'before':first,'after':pose()})
  rows.append({'ability':pair[0],'request':result,'frames':frames})
 return JSON.stringify(rows)
func overlays(v):
 var out=[]
 for i in v.flash_meshes.size():out.append({'mesh':str(v.flash_meshes[i].get_path()),'flash':v.flash_meshes[i].material_overlay==v.flash_material,'original':v.flash_meshes[i].material_overlay==v.original_overlays[i]})
 return out
func qa_flash(stage):
 if stage=='start':
  qa_setup({'e':'e2'});camera.size=12
  simulation.damage_enemy(simulation.enemies[0],10,'qa_real_damage',901)
 elif stage=='second':
  _sync_views(.08)
  simulation.damage_enemy(simulation.enemies[1],10,'qa_real_damage',902)
 elif stage=='first_restore':_sync_views(.05)
 elif stage=='all_restore':_sync_views(.08)
 var result={}
 for id in views:result[id]=overlays(views[id])
 return JSON.stringify(result)
func qa_audio():
 qa_setup({'e':'e3'});simulation.request_action('e',Vector3.FORWARD)
 var before=audio_router.counts.duplicate()
 # One actual attack sweeps two real targets with E3 supplementary packets.
 var result=simulation.request_action('attack',Vector3.FORWARD)
 simulation.step(.15);_sync_views(.15);_animate(.15)
 var after=audio_router.counts.duplicate();var log=simulation.event_log.duplicate(true)
 for event in log:audio_router.combat(event)
 var replay=audio_router.counts.duplicate()
 audio_router.sfx.stop_all()
 var accepted=[]
 for i in 100:accepted.append(audio_router.sfx.play_event('sword'))
 var burst=audio_router.sfx.snapshot()
 audio_router.sfx.set_muted(true)
 var muted=audio_router.sfx.snapshot();var denied=audio_router.sfx.play_event('hit')
 audio_router.sfx.set_muted(false)
 var unmuted=audio_router.sfx.play_event('hit')
 audio_router.sfx.stop_all()
 for id in audio_router.sfx.IDS:audio_router.sfx.play_event(id)
 var pool=audio_router.sfx.snapshot()
 audio_router.sfx.set_muted(true)
 return JSON.stringify({'request':result,'before':before,'after':after,'replay':replay,'events':log,'burst_accept':accepted,'burst':burst,'muted':muted,'muted_play':denied,'unmuted_play':unmuted,'pool':pool,'listened':false})

func qa_high_start():
 call_deferred('qa_high_run')
 return 'started controlled high attack speed run'
func qa_high_run():
 qa_setup({'e':'e3'})
 audio_router.sfx.set_muted(false)
 simulation.hero.stats.attack_speed=10.0
 simulation.request_action('e',Vector3.FORWARD)
 var counts_before=audio_router.counts.duplicate()
 var samples=[];var accepted=0
 for i in 240:
  if simulation.request_action('attack',Vector3.FORWARD).accepted:accepted+=1
  simulation.step(1.0/60);_sync_views(1.0/60);_animate(1.0/60)
  samples.append(audio_router.sfx.snapshot())
  await get_tree().create_timer(1.0/60).timeout
 set_meta('high_result',{'attack_speed':simulation.hero.attack_speed(),'accepted':accepted,'before':counts_before,'after':audio_router.counts.duplicate(),'events':simulation.event_log,'players':samples,'listened':false})
 audio_router.sfx.set_muted(true)
func qa_high_report():return JSON.stringify(get_meta('high_result',{}))
