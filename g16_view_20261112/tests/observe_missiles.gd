extends RefCounted
## UNRUN. Explicit source-array fixtures; not natural G16 activation or visual acceptance.
var checks:Array=[]
func check(name:String,passed:bool)->void:checks.append({"check":name,"passed":passed})
func run()->Dictionary:
 checks.clear()
 var sim:Node=load("res://fengli_route_20261024/sim.gd").new()
 var session:RefCounted=load("res://fengli_route_20261024/session.gd").new()
 var view:RefCounted=load("res://fengli_route_20261024/missile_view.gd").new()
 var path:String="res://__clean_fengli/machine_templates.bin"
 var config:Dictionary=session.configure_reward_table(path,path,path,true)
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(session.DEFAULT_DEFINITION))
 var bound:Dictionary=session.initialize_floor(sim,route,"g16-view-fixture",true) if config.get("accepted",false) else config
 check("real_session",bound.get("accepted",false))
 if not bound.get("accepted",false):sim.free();return result()
 session.ledger.model.state.selected_hex=["common_g16"]
 session.ledger.refresh_runtime()
 var room:String=session.run_id+"/view"
 session._authority("enter_room",{"next_room":room})
 session.ledger.command("enter_level",{"combat_level_id":room})
 var began:Dictionary=sim.begin_encounter(room,[{"kind":"minion","position":Vector3(5,0,0),"hp":100.0}])
 check("real_encounter",began.get("accepted",false))
 if not began.get("accepted",false):sim.free();return result()
 sim.ai_enabled=false;sim.auto_finish=false;sim.paused=true
 var target:Dictionary=sim.enemies[0]
 var source:Dictionary={"entity_id":"explicit-missile-fixture","kind":"missile","source":"common_g16","position":Vector3.ZERO,"target_id":target.actor_id,"speed":10.0,"left":2.0,"damage":1.0,"cast_id":1}
 sim.common.runtime.projectiles.append(source)
 var before:Array=sim.common.runtime.projectiles.duplicate(true)
 var hp:float=float(target.hp)
 var sampled:Dictionary=view.sample(sim)
 check("visible_source_entity",sampled.live_count==1 and sampled.missiles[0].position==Vector3.ZERO)
 check("no_source_or_damage_write",before==sim.common.runtime.projectiles and float(target.hp)==hp)
 check("paused_resample_stable",sampled==view.sample(sim))
 source.position=Vector3(2,0,0)
 check("reads_actual_source_position",view.sample(sim).missiles[0].position==Vector3(2,0,0))
 target.position=Vector3(6,0,1)
 check("reads_actual_target_no_local_tracking",view.sample(sim).missiles[0].target_position==target.position)
 source.kind="corpse"
 check("excludes_G11",view.sample(sim).live_count==0)
 source.kind="missile";source.source="common_g11"
 check("rejects_wrong_source",view.sample(sim).live_count==0)
 source.source="common_g16";source.left=0.0
 check("rejects_expired_source",view.sample(sim).live_count==0)
 source.left=2.0;target.dead=true
 check("dead_target_hidden",view.sample(sim).live_count==0)
 target.dead=false;sim.hero.dead=true
 check("hero_death_hides",view.sample(sim).live_count==0)
 sim.hero.dead=false;sim.common.runtime.projectiles.clear()
 check("source_removal_no_cached_body",view.sample(sim).live_count==0)
 sim.end_encounter("victory")
 check("end_room_empty",view.sample(sim).live_count==0)
 sim.free()
 return result()
func result()->Dictionary:
 return {"checks":checks,"failures":checks.filter(func(row):return not row.passed),"scope":"UNRUN_UNTIL_AUTHORIZED_GUARDED_INVOCATION; source-array fixtures only, no natural trigger or graphics"}
