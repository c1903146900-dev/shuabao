extends SceneTree
func _initialize():call_deferred('run')
func run():
 var room=load('res://scripts/integration/room.gd').new()
 root.add_child(room)
 await process_frame
 room.set_physics_process(false)
 room.start_room()
 room.simulation.damage_enemy(room.simulation.enemies[0],32,'qa_fade',9901)
 var rows=[]
 for dt in [0.0,.325,.26]:
  room._step_effects(dt)
  for effect in room.effects:
   if effect.type=='number':rows.append({'remaining':effect.life,'glyph_alpha':effect.node.modulate.a,'outline_alpha':effect.node.outline_modulate.a,'text':effect.node.text})
 print('QA_LABEL '+JSON.stringify(rows))
 room.queue_free()
 await process_frame
 quit()
