extends "res://scripts/combat/hero_combat_core.gd"
## Narrow isolated guard around the unchanged shared damage pipeline.
## No clock/AI/rank/crit/cooldown rewrite and no new callback prohibition.
func _ink_scope()->Dictionary:
 return {"hero_instance":hero,"room_id":room_id,"generation":encounter_generation}
func _ink_scope_current(scope:Dictionary)->bool:
 return phase=="combat" and is_same(hero,scope.hero_instance) and room_id==str(scope.room_id) and encounter_generation==int(scope.generation)
func _retire_old_hit(original_bridge:RefCounted,original_scope:Dictionary,entry_depth:int)->void:
 # Only unwind the exact original bridge/epoch depth. A new room owns its new
 # nesting counter; InkBridge.begin_room reset it before any new-room events.
 if original_bridge.runtime.generation==int(original_scope.generation) and original_bridge.runtime.room_id==str(original_scope.room_id):
  if original_bridge._inside_hit==entry_depth+1:original_bridge._inside_hit=entry_depth
func damage_enemy(enemy: Dictionary, amount: float, source: String, cast_id: int=0, is_true: bool=false, critical: bool=false, metadata: Dictionary={}) -> bool:
 var original_scope:Dictionary=_ink_scope()
 var original_bridge:RefCounted=common
 var entry_depth:int=common._inside_hit
 if phase!="combat" or paused or hero.dead or enemy.is_empty() or enemy.dead or enemy.state=="spawn" or not cast_is_current(cast_id): return false
 if not is_same(enemy,enemy_by_id(str(enemy.actor_id))): return false
 if metadata.has("generation") and int(metadata.generation)!=encounter_generation: return false
 if metadata.has("room_id") and str(metadata.room_id)!=room_id: return false
 if metadata.has("effect_id"):
  var key="damage:%s:%s"%[metadata.effect_id,enemy.actor_id]
  if _effect_claims.has(key): return false
  _effect_claims[key]=true
 common._inside_hit+=1
 # Replays already contain their original nominal amount and suppress reactions.
 var adjusted: float=amount if metadata.get("replay",false) or metadata.get("no_reactions",false) else _hero_outgoing_damage(enemy,amount,source,cast_id,is_true,metadata)
 var event: Dictionary=common.before_hit(enemy,adjusted,source,cast_id,is_true,critical,metadata)
 # Hero final multipliers follow common final multipliers and precede mitigation.
 # Already-snapshotted packets (G18, proportional true riders) must not apply twice.
 var hero_final: float=1.0 if event.get("snapshot_final",false) or event.get("replay",false) else _hero_final_outgoing_multiplier(enemy,event)
 event.amount*=hero_final
 event.hero_final_multiplier=hero_final
 if event.has("cast_bonus_final"): event.cast_bonus_final*=hero_final
 var source_position: Vector3=event.get("position",hero.position)
 var guard_factor: float=enemy_director.guard_multiplier(enemy,source_position,source,is_true)
 var packet: float=maxf(0,float(event.amount))*guard_factor
 var penetration: float=float(event.get("saved_stats",{}).get("penetration",hero.stats.penetration)) if event.get("replay",false) else float(event.get("impact_penetration",hero.stats.penetration))
 if not is_true: packet*=100.0/(100.0+maxf(0,float(enemy.defence)-penetration))
 var actual: float=minf(float(enemy.hp),packet)
 enemy.hp=maxf(0,float(enemy.hp)-packet)
 emit_event("damage",{"target":enemy.actor_id,"position":enemy.position,"source_position":source_position,"amount":actual,"source":source,"cast_id":cast_id,"critical":event.get("critical",critical),"damage_type":"true" if is_true else "ordinary","hex_generated":event.get("hex_generated",false),"replay":event.get("replay",false),"saved_aim":event.get("saved_aim",hero.facing),"occurrence":event.get("occurrence",event.get("replay_segment",{}).get("occurrence",0)),"strike":event.get("strike",0),"round":event.get("round",0),"combo":event.get("combo",0),"direction":event.get("direction",hero.facing),"enemy_kind":enemy.kind,"target_radius":enemy.radius,"guard_factor":guard_factor,"guarded":guard_factor<1.0,"absorbed":0.0,"basic_attack":event.get("basic_attack",false)})
 if not _ink_scope_current(original_scope):
  _retire_old_hit(original_bridge,original_scope,entry_depth)
  return false
 if not is_true and not event.get("no_reactions",false): heal(actual*float(event.get("impact_lifesteal_rate",_hero_lifesteal_rate(event)))*_hero_lifesteal_factor(event),true,{"source":"lifesteal"})
 if not _ink_scope_current(original_scope):
  _retire_old_hit(original_bridge,original_scope,entry_depth)
  return false
 if event.has("replay_segment"):
  var segment: Dictionary=event.replay_segment
  var extra: Dictionary={"critical":event.get("critical",false),"occurrence":segment.get("occurrence",0)}
  for field in ["replay_hit_group","replay_hit_limit","relative_time","saved_aim"]:
   if segment.has(field): extra[field]=segment[field]
  if segment.get("target_mode","")=="bound": common.record_bound(cast_id,segment.segment_id,enemy,event.amount,source_position,extra)
  else:
   extra.merge({"original_target_id":enemy.actor_id,"cast_bonus_final":event.get("cast_bonus_final",0.0),"hero_final_multiplier":event.get("hero_final_multiplier",1.0)},true)
   common.record_spatial(cast_id,segment.segment_id,event.amount,source_position,segment.shape,extra)
 if enemy.hp<=0: _kill_enemy(enemy,source,cast_id)
 if not _ink_scope_current(original_scope):
  _retire_old_hit(original_bridge,original_scope,entry_depth)
  return false
 if not event.get("no_reactions",false): _hero_after_damage(enemy,event,actual)
 if not _ink_scope_current(original_scope):
  _retire_old_hit(original_bridge,original_scope,entry_depth)
  return false
 common.after_hit(event,actual)
 common._inside_hit-=1
 common.drain()
 return enemy.dead
