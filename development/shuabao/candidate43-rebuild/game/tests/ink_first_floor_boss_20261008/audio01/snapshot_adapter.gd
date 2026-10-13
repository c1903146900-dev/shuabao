extends RefCounted
## Read-only synchronous adapter. It never initializes a Boss runtime or owns dt.
## Call at the actual combat_event delivery, not against event-log history.
static func capture(sim, base: Dictionary = {}) -> Dictionary:
 var out: Dictionary=(sim.ink_presenter_snapshot() if base.is_empty() else base).duplicate(true)
 var run_id: String=""
 if sim.progression!=null:
  var model=sim.progression.get("model")
  if model!=null: run_id=str(model.get("_run_id"))
 var bosses: Dictionary={}
 for enemy: Dictionary in sim.enemies:
  if enemy.kind!="boss" or not enemy.has("boss_runtime"): continue
  var row: Dictionary=enemy.boss_runtime.duplicate(true)
  row.merge({"actor_id":enemy.actor_id,"position":enemy.position,"state":enemy.state,"timer":enemy.timer,"dead":enemy.dead},true)
  row["current"]=str(row.run_id)==run_id and int(row.source_instance_id)==sim.get_instance_id() and str(row.room_id)==sim.room_id and int(row.generation)==sim.encounter_generation and sim.hero.get_instance_id()==int(row.hero_instance_id) and not sim.hero.dead and not enemy.dead and sim.phase=="combat"
  bosses[str(enemy.actor_id)]=row
 out["boss_audio"]={"schema":"first-floor-boss-audio-1","source_instance_id":sim.get_instance_id(),"run_id":run_id,"room_id":sim.room_id,"generation":sim.encounter_generation,"event_sequence":sim.sequence,"source_time":sim.hero_time,"world_time":sim.clock.world_time,"paused":sim.paused,"hero_dead":sim.hero.dead,"phase":sim.phase,"bosses":bosses}
 return out
