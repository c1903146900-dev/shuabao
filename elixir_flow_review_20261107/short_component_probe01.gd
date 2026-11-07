extends SceneTree
## PREPARED, NOT ENGINE-PARSED OR RUN. COMPONENT FIXTURES, NOT GAMEPLAY EVIDENCE.
## Run only with the unchanged originalguard normal-window launcher/backstop.
## Finite workload and 12s cooperative checks, NOT a hard 15s guarantee.
## No source preloads before the authentic boot mount.
const LIMIT_MS:int=12000
var started:int=0
var run_started:bool=false
var finished:bool=false
var failures:Array=[]
var checks:int=0

class FixtureHost extends Node:
 var hero:RefCounted
 var allies:Array=[]
 var paused:bool=false
 var transaction_active:bool=false
 var clock:RefCounted
 var hero_time:float=0.0
 var encounter_generation:int=1
 var room_id:String="COMPONENT_FIXTURE_ONLY"
 var enemies:Dictionary={}
 var _casts:Dictionary={1:{"slot":"q"},2:{"slot":"e"},3:{"slot":"q"}}
 var packets:Array=[]
 func enemy_by_id(id:String)->Dictionary:return enemies.get(id,{})
 func cast_is_current(id:int)->bool:return _casts.has(id)
 # Packet spy only: DOES NOT run combat damage, mitigation, lifesteal, or kills.
 func damage_enemy(enemy:Dictionary,amount:float,source:String,cast_id:int,is_true:bool,critical:bool,metadata:Dictionary)->bool:
  packets.append({"target":enemy.actor_id,"amount":amount,"source":source,"cast_id":cast_id,"is_true":is_true,"critical":critical,"metadata":metadata.duplicate(true)})
  return false

class FixtureModel extends RefCounted:
 # Used only for observation labels, never passed to bind or a ledger.
 var state:Dictionary={"shop_visit":{"battle_id":"COMPONENT_FIXTURE_ONLY"}}

func _initialize()->void:
 started=Time.get_ticks_msec()
 print("SHORT_COMPONENT_CONFIGURATION ",JSON.stringify({"fixture":true,"natural_flow":false,"route_admission_test":false,"cooperative_limit_ms":LIMIT_MS,"hard_15s_guarantee":false,"external_backstop":"unchanged_originalguard_595_600s","engine_max_fps":Engine.max_fps,"observed_fps":Engine.get_frames_per_second()}))
 var boot=load("res://boot.tscn")
 if boot==null:_finish("boot_missing",9);return
 root.add_child(boot.instantiate())

func _process(_dt:float)->bool:
 if finished:return false
 if Time.get_ticks_msec()-started>=LIMIT_MS:_finish("component_timeout",9);return false
 # A runtime error can abort _run_components without reaching _finish. Keep the
 # frame watchdog alive, but never retry the partially executed fixture batch.
 if run_started:return false
 if root.get_node_or_null("Boot/FengliEntry")==null:return false
 # Do not start a route. The authenticated mount has completed; all test objects
 # below are local and never installed into the real entry/host/ledger.
 run_started=true
 _run_components()
 return false

func _check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)

func _near(actual:float,expected:float,label:String)->void:
 _check(is_equal_approx(actual,expected),label+" actual="+str(actual)+" expected="+str(expected))

func _deadline(stage:String,fixture:Node=null)->bool:
 # Cooperative only: blocked native calls remain originalguard's responsibility.
 if Time.get_ticks_msec()-started<LIMIT_MS:return true
 if is_instance_valid(fixture):fixture.queue_free()
 _finish("component_deadline_before_"+stage,9)
 return false

func _finish(reason:String,code:int)->void:
 print("SHORT_COMPONENT_RESULT ",JSON.stringify({"reason":reason,"checks":checks,"failures":failures,"fixture":true,"natural_flow":false,"real_damage_pipeline":false,"elapsed_ms":Time.get_ticks_msec()-started,"engine_max_fps":Engine.max_fps,"observed_fps":Engine.get_frames_per_second()}))
 quit(code)
 finished=true

func _run_components()->void:
 if not _deadline("source_load"):return
 var actor_script=load("res://scripts/actors/hero_model_core.gd")
 var clock_script=load("res://scripts/combat/world_clock.gd")
 var steel_script=load("res://fengli_route_20261024/steel_runtime.gd")
 if actor_script==null or clock_script==null or steel_script==null:_finish("source_load_failed",9);return
 if not _deadline("fixture_compile"):return
 # Explicit pure-component seam. Only scope/liveness is substituted. Do not call
 # bind(), ready(), Machine.readiness(), ledger mutation, or mint any capability.
 # Inherited effect methods are unchanged. Fixture model is never an owner.
 var seam=GDScript.new()
 seam.source_code='extends "res://fengli_route_20261024/elixir_consumer.gd"\nvar fixture_item:String="elixir:03"\nfunc active_item()->String:return fixture_item\nfunc _live_item()->String:return fixture_item\nfunc _current_scope()->Array:return ["COMPONENT_FIXTURE_ONLY",1,"NO_AUTHORITY",fixture_item]\n'
 if seam.reload()!=OK:_finish("fixture_seam_parse_failed",9);return
 var effect=seam.new()
 var sim=FixtureHost.new()
 sim.hero=actor_script.new();sim.clock=clock_script.new()
 root.add_child(sim)
 var model=FixtureModel.new()
 effect._sim=weakref(sim);effect._model=weakref(model)
 if not _deadline("numeric_validation",sim):return
 # Validate immutable numeric file identity, rather than silently using constants.
 var values_path:String="res://fengli_route_20261024/elixir_values.json"
 if FileAccess.get_sha256(values_path)!="e9c8939564c6f39f9b101086cea66dda1804d26412e9f0324c243af6e68e7512":
  sim.queue_free();_finish("numeric_identity_failed",9);return
 var values:Variant=JSON.parse_string(FileAccess.get_file_as_string(values_path))
 if not values is Dictionary or values.get("format","")!="fengli-elixir-values-1":
  sim.queue_free();_finish("numeric_format_failed",9);return
 effect._values=values.parameters.duplicate(true)
 var steel=effect.steel
 var bound:Dictionary=steel.bind(sim,effect)
 if not bound.get("accepted",false):sim.queue_free();_finish("steel_values_or_bind_rejected",9);return
 if not _deadline("steel_hp",sim):return
 _near(steel.value("elixir:03.max_health"),15.0,"source steel HP percent")
 _near(steel.value("elixir:03.path_duration"),1.5,"source path lifetime")
 _near(steel.value("path_width"),0.8,"source path width")
 sim.hero.initialize_stats({"max_hp":100.0,"move_speed":10.0});sim.hero.hp=50.0
 var projection:Dictionary=sim.hero.stats.duplicate(true)
 steel.commit_final_projection(sim.hero,projection)
 _near(sim.hero.stats.max_hp,115.0,"steel max HP entry")
 _near(sim.hero.hp,57.5,"steel entry ratio")
 steel.commit_final_projection(sim.hero,projection)
 _near(sim.hero.hp,57.5,"steel repeated final projection idempotent")
 projection.max_hp=200.0;steel.commit_final_projection(sim.hero,projection)
 _near(sim.hero.hp,115.0,"active max change ratio")
 _near(sim.hero.stats.max_hp,230.0,"active max change boost")
 effect.fixture_item="";steel.commit_final_projection(sim.hero,projection)
 _near(sim.hero.hp,100.0,"steel removal ratio")
 _near(sim.hero.stats.max_hp,200.0,"steel removal max")
 if not _deadline("steel_paths",sim):return
 effect.fixture_item="elixir:03"
 var ally=actor_script.new();ally.initialize_stats({"max_hp":100.0,"move_speed":10.0});ally.position=Vector3(0.5,0,0)
 sim.allies.append(ally);steel.track_ally(ally)
 steel.record_movement(Vector3.ZERO,Vector3(1,0,0))
 _check(steel.snapshot().paths.size()==1,"real path segment creation")
 _near(ally.speed(),11.0,"ally on path")
 _near(sim.hero.speed(),10.0,"hero excluded")
 ally.position.z=0.41;_near(ally.speed(),10.0,"outside half width")
 ally.position.z=0.0;ally.stats.move_speed=20.0
 _near(ally.speed(),22.0,"dynamic projected ally speed")
 sim.allies.clear();_near(ally.speed(),20.0,"removed ally excluded immediately")
 sim.allies.append(ally);sim.clock.world_time=1.5
 _near(ally.speed(),20.0,"expiry exact boundary before pruning")
 steel.advance();_check(steel.snapshot().paths.is_empty(),"expired paths pruned")
 sim.paused=true;steel.record_movement(Vector3.ZERO,Vector3(1,0,0))
 _check(steel.snapshot().paths.is_empty(),"paused movement ignored")
 sim.paused=false;steel.record_movement(Vector3.ZERO,Vector3(1,0,0))
 steel.clear_paths();_check(ally._movement_sources.is_empty(),"path cleanup unbinds ally")
 if not _deadline("war",sim):return
 effect.fixture_item="elixir:01";effect.clear_battle()
 _near(effect.value("elixir:01.on_kill_duration"),3.0,"source war duration")
 _near(effect.value("elixir:01.on_kill_as"),10.0,"source war percent")
 var first:Dictionary={"actor_id":"fixture_dead_1","dead":true}
 var second:Dictionary={"actor_id":"fixture_dead_2","dead":true}
 sim.enemies={first.actor_id:first,second.actor_id:second}
 effect.killed(first,1);_near(effect.war_fraction(),0.1,"war first kill")
 sim.hero_time=1.0;effect.killed(first,1)
 _near(effect._war_until,3.0,"duplicate kill does not refresh")
 effect.killed(second,1);_near(effect._war_until,4.0,"new kill refreshes")
 _near(effect.war_fraction(),0.1,"refresh does not stack")
 sim.hero_time=4.0;_near(effect.war_fraction(),0.0,"war exact expiry")
 effect.advance();_near(effect._war_until,0.0,"war expiry clears timer")
 if not _deadline("arcane",sim):return
 effect.fixture_item="elixir:02";effect.clear_battle()
 sim.hero.stats.ap=160.0
 var target:Dictionary={"actor_id":"fixture_target","hp":1000.0,"dead":false}
 sim.enemies[target.actor_id]=target
 var event:Dictionary={"source":"q1","cast_id":1,"hero_final_multiplier":1.0,"generation":1,"room_id":sim.room_id}
 effect._record_arcane_damage(target,event,10.0)
 _check(sim.packets.size()==1,"arcane first effective hit packet")
 if sim.packets.size()==1:
  var packet:Dictionary=sim.packets[0]
  _near(packet.amount,56.0,"arcane 40 plus trigger AP times 10 percent")
  _check(packet.is_true and packet.source=="elixir_arcane","arcane true source packet")
  _check(packet.metadata.hex_generated and not packet.metadata.active_skill and not packet.metadata.basic_attack,"arcane generated non-skill packet")
  _check(not packet.metadata.get("snapshot_final",false) and not packet.metadata.get("no_reactions",false),"arcane fresh final-modifier eligibility")
 effect._record_arcane_damage(target,event,10.0)
 _check(sim.packets.size()==1,"arcane once per cast")
 event.cast_id=2;event.source="e1_dagger";event.replay=true
 effect._record_arcane_damage(target,event,10.0)
 _check(sim.packets.size()==1,"arcane replay excluded")
 event.erase("replay");effect._record_arcane_damage(target,event,0.0)
 _check(sim.packets.size()==1,"arcane zero damage excluded")
 sim.hero.stats.ap=260.0;effect._record_arcane_damage(target,event,1.0)
 _check(sim.packets.size()==2,"arcane separate E cast")
 if sim.packets.size()==2:_near(sim.packets[1].amount,66.0,"arcane current trigger AP")
 event.cast_id=3;event.source="q1";target.dead=true;target.hp=0.0
 effect._record_arcane_damage(target,event,1.0)
 _check(effect._arcane_casts.has(3) and sim.packets.size()==2,"lethal hit consumes without transfer")
 effect.clear_battle();_check(effect._arcane_casts.is_empty(),"arcane cleanup")
 if not _deadline("completion",sim):return
 sim.queue_free()
 _finish("component_checks_pass" if failures.is_empty() else "component_checks_failed",0 if failures.is_empty() else 1)
