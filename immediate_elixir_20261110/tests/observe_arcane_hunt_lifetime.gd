extends SceneTree
## ISOLATED SOURCE-CONTRACT FIXTURE, not normal UI/economy or full-route acceptance.
## Restored from retained source text; old script hash unavailable.
## Every engine invocation needs the unchanged guard through CUA.
## Normal candidate boot is read-only. All funding/HP seeds belong to fresh test runs.
const ITEMS:Array[String]=["elixir:02","elixir:04"]
const CLOCK_KEYS:Array[String]=["hero_time","world_time","real_time"]
const WALL_LIMIT_MS:int=180000
const COMBAT_LIMIT:float=75.0
const FIXTURE_GOLD:int=100000
const BOOT_SCENE:String="res://boot.tscn"
var output:FileAccess
var output_dir:String="user://observe_arcane_hunt_lifetime"
var boot:Node
var entry:Node
var host:Node
var boot_started:bool=false
var running:bool=false
var finished:bool=false
var started_ms:int=0
var serial:int=0
var passed:int=0
var failed:int=0
var coverage:Dictionary={"normal_ui_full_slot":false,"normal_economy":false,"full_route":false,"rest_settlement":false,"os_native_input":false}
var fixture_sims:Array[Node]=[]

func _initialize()->void:
 started_ms=Time.get_ticks_msec()
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--observer-output="):output_dir=arg.trim_prefix("--observer-output=").simplify_path()
 if not output_dir.begins_with("user://"):
  push_error("user_output_required");quit(9);return
 var path:String=output_dir.path_join("observations.jsonl")
 if FileAccess.file_exists(path):push_error("fresh_observer_output_required");quit(9);return
 if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))!=OK:push_error("output_unwritable");quit(9);return
 output=FileAccess.open(path,FileAccess.WRITE)
 if output==null:push_error("output_unwritable");quit(9);return
 _record("configuration",{"fixture_only":true,"normal_boot_read_only":true,"fixture_gold_seed":FIXTURE_GOLD,"fixture_steel_hp_ratio":0.37,"unmodified_ai":true,"unmodified_damage":true,"engine_validation_before_run":"not_run","coverage_exclusions":coverage})
 var scene:PackedScene=load(BOOT_SCENE)
 if scene==null:_finish("boot_scene_unavailable");return
 boot=scene.instantiate();root.add_child(boot)

func _process(_delta:float)->bool:
 if finished:return false
 if Time.get_ticks_msec()-started_ms>WALL_LIMIT_MS:_check(false,"wall_watchdog",{});_finish("wall_timeout");return false
 if running:return false
 if entry==null:
  for child:Node in boot.get_children():
   if child.get("screen")!=null:entry=child;break
  return false
 if not boot_started:
  boot_started=true
  if not is_instance_valid(entry.get("_start")):_check(false,"frontdoor_start_missing",{});_finish("boot_failed");return false
  entry._start.pressed.emit()
  return false
 host=entry.get("active_room")
 if host==null:return false
 if not str(host.startup_session_error).is_empty() or not str(host.floor_error).is_empty():
  _check(false,"normal_boot_ready",{"startup":host.startup_session_error,"floor":host.floor_error});_finish("boot_failed");return false
 if host.shop_session==null or host.shop_session.ledger==null:return false
 var state:Dictionary=host.shop_session.ledger.model.state
 _check(int(state.gold)==0 and state.inventory.is_empty() and host.sim.phase=="preparation","normal_boot_fresh_zero_resource",{"gold":state.gold,"inventory":state.inventory,"phase":host.sim.phase,"run_id":host.sim.route_run_id})
 _record("normal_boot",{"gold":state.gold,"inventory":state.inventory,"stats":host.sim.hero.stats,"note":"Only existing frontdoor Button signal. No purchase, funding or fixture changes touched this run."})
 host.frontdoor_close_run("immediate_elixir_fixture_boot_complete")
 running=true
 _run_fixtures.call_deferred()
 return false

func _json(value:Variant)->Variant:
 if value is Vector3:return [value.x,value.y,value.z]
 if value is Vector2:return [value.x,value.y]
 if value is Object:return {"object_omitted":value.get_class()}
 if value is Array:
  var result:Array=[]
  for item:Variant in value:result.append(_json(item))
  return result
 if value is Dictionary:
  var result:Dictionary={}
  for key:Variant in value:result[str(key)]=_json(value[key])
  return result
 return value

func _record(kind:String,detail:Dictionary)->void:
 var row:Dictionary=detail.duplicate(true)
 row["record"]=kind;row["wall_ms"]=Time.get_ticks_msec()-started_ms
 var line:String=JSON.stringify(_json(row))
 if output!=null:output.store_line(line);output.flush()
 print("ELIXIR_LIFETIME ",line)

func _check(ok:bool,label:String,detail:Dictionary={})->bool:
 if ok:passed+=1
 else:failed+=1
 _record("check",{"label":label,"passed":ok,"detail":detail})
 return ok

func _near(a:float,b:float)->bool:return absf(a-b)<=0.00001*maxf(1.0,maxf(absf(a),absf(b)))
func _id(prefix:String)->String:serial+=1;return "immediate-fixture:%s:%d"%[prefix,serial]

func _new_fixture(label:String)->Dictionary:
 var sim:Node=load("res://fengli_route_20261024/sim.gd").new()
 root.add_child(sim);fixture_sims.append(sim)
 var session:RefCounted=load("res://fengli_route_20261024/session.gd").new()
 var definition:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(session.DEFAULT_DEFINITION))
 var configured:Dictionary=session.configure_reward_table("res://__clean_fengli/machine_templates.bin","res://__clean_fengli/machine_templates.bin","res://__clean_fengli/machine_templates.bin",true)
 if not _check(configured.get("accepted",false),label+":configure",configured):return {}
 var initialized:Dictionary=session.initialize_floor(sim,definition,_id(label),true)
 if not _check(initialized.get("accepted",false),label+":initialize",{"reason":initialized.get("reason","")}):return {}
 var model:RefCounted=session.ledger.model
 if not _check(int(model.state.gold)==0 and model.state.inventory.is_empty() and sim.hero.hp>0.0,label+":fresh_before_seed"):return {}
 # EXPLICIT INDEPENDENT ECONOMIC FIXTURE. Never use the normal boot host here.
 model.state.gold=FIXTURE_GOLD
 _record("fixture_seed",{"label":label,"run_id":sim.route_run_id,"gold":FIXTURE_GOLD,"normal_run":false,"stock_actor":sim.hero.snapshot()})
 var f:Dictionary={"label":label,"sim":sim,"session":session,"model":model,"ledger":session.ledger,"consumer":model.elixir_consumer}
 var visit:Dictionary=_authority(f,"begin_visit",{"area":"isolated-economic-fixture"})
 if not _check(visit.get("accepted",false),label+":begin_visit",visit):return {}
 return f

func _authority(f:Dictionary,action:String,extra:Dictionary)->Dictionary:
 var args:Dictionary=f.model.commerce_token();args.merge(extra,true)
 return f.ledger.shop_authority(f.session,_id(action),action,args)
func _trade(f:Dictionary,action:String,extra:Dictionary)->Dictionary:
 var args:Dictionary=f.model.commerce_token();args.merge(extra,true)
 return f.ledger.shop_command(_id(action),action,args)

func _fill_equipment(f:Dictionary,count:int)->bool:
 var ids:Array=f.model.commerce_definitions.items.keys();ids.sort()
 var chosen:String=""
 for id:Variant in ids:
  var item:Dictionary=f.model.commerce_definitions.items[id]
  var status:Dictionary=f.model.equipment_runtime_status(str(id))
  if item.get("kind","")=="equipment" and item.get("components",[]).is_empty() and status.get("supported",false):chosen=str(id);break
 if not _check(not chosen.is_empty(),str(f.label)+":supported_filler_found"):return false
 for index:int in range(count):
  var result:Dictionary=_trade(f,"buy",{"item":chosen})
  if not _check(result.get("accepted",false),str(f.label)+":filler_purchase_"+str(index),{"item":chosen,"result":result}):return false
 return true

func _snapshot(f:Dictionary)->Dictionary:
 return {"gold":f.model.state.gold,"inventory":f.model.state.inventory.duplicate(true),"revision":f.model.state.revision,"phase":f.model.state.phase,"sim_phase":f.sim.phase,"shop_visit":f.model.state.shop_visit.duplicate(true),"static":f.consumer.static_stats(),"consumer":f.consumer.snapshot(),"stats":f.sim.hero.stats.duplicate(true),"hp":f.sim.hero.hp,"ad":f.sim.hero.ad(),"speed":f.sim.hero.speed(),"attack_speed":f.sim.hero.attack_speed(),"hero_time":f.sim.hero_time,"world_time":f.sim.clock.world_time,"real_time":f.sim.real_time,"position":f.sim.hero.position}

func _assert_immediate(f:Dictionary,item:String,before:Dictionary,after:Dictionary)->void:
 var label:String=str(f.label)
 _check(f.consumer.active_item()==item and after.phase=="safe" and after.shop_visit.active_elixir.get("battle_id","")=="",label+":immediate_pending_member",after)
 _check(after.shop_visit.active_elixir.get("duration_rule","")=="next_battle_only",label+":no_seconds_lifetime")
 match item:
  "elixir:02":
   _check(_near(float(after.stats.ap)-float(before.stats.ap),60.0),label+":arcane_ap_immediate")
   _check(_near(float(after.stats.cdr)-float(before.stats.cdr),0.10),label+":arcane_cdr_immediate")
  "elixir:04":
   _check(_near(float(after.stats.penetration)-float(before.stats.penetration),20.0),label+":hunt_penetration_immediate")
   _check(_near(float(after.stats.crit_chance)-float(before.stats.crit_chance),0.15),label+":hunt_crit_immediate")
  "elixir:01":
   _check(_near(float(after.ad)-float(before.ad),35.0),label+":war_ad_immediate",{"before":before.ad,"after":after.ad})
   _check(_near(float(after.stats.lifesteal)-float(before.stats.lifesteal),0.08),label+":war_lifesteal_immediate")
  "elixir:03":
   _check(_near(float(after.stats.max_hp),float(before.stats.max_hp)*1.15),label+":steel_maxhp_immediate",{"before":before.stats.max_hp,"after":after.stats.max_hp})
   _check(_near(float(after.hp)/float(after.stats.max_hp),float(before.hp)/float(before.stats.max_hp)),label+":steel_preserves_hp_ratio",{"before_hp":before.hp,"after_hp":after.hp})
   _check(_near(float(after.stats.defence)-float(before.stats.defence),20.0),label+":steel_defense_immediate")
  "elixir:05":
   _check(_near(float(after.speed),float(before.speed)*1.15),label+":swift_source_speed_immediate",{"before":before.speed,"after":after.speed})
   _check(_near(f.consumer.movement_fraction(),0.15),label+":swift_no_unearned_proc")

func _prepare_effect(item:String,manual:bool)->Dictionary:
 var label:String=item.replace(":","_")+("_manual" if manual else "_fullslot")
 var f:Dictionary=_new_fixture(label)
 if f.is_empty():return {}
 if not _fill_equipment(f,5 if manual else 6):return {}
 if item=="elixir:03":
  f.sim.hero.hp=float(f.sim.hero.stats.max_hp)*0.37
  f.sim.observe_pending_health()
  _record("fixture_hp_seed",{"label":label,"ratio":0.37,"hp":f.sim.hero.hp,"max_hp":f.sim.hero.stats.max_hp})
 var before:Dictionary=_snapshot(f)
 var result:Dictionary=_trade(f,"buy",{"item":item})
 if not _check(result.get("accepted",false),label+":purchase",result):return {}
 var price:int=int(f.model.commerce_definitions.items[item].price)
 _check(int(before.gold)-int(f.model.state.gold)==price,label+":exact_purchase_charge",{"price":price,"before":before.gold,"after":f.model.state.gold})
 if manual:
  var reserve:Dictionary=_snapshot(f)
  _check(f.model.state.inventory.size()==6 and f.model.state.shop_visit.active_elixir.is_empty() and reserve.stats==before.stats and _near(reserve.hp,before.hp) and _near(reserve.speed,before.speed),label+":undrunk_reserve_inactive",reserve)
  var uid:int=-1
  for entry_item:Dictionary in f.model.state.inventory:
   if entry_item.id==item:uid=int(entry_item.uid);break
  result=_trade(f,"consume",{"uid":uid})
  if not _check(result.get("accepted",false),label+":manual_consume",result):return {}
  _check(f.model.state.inventory.size()==5 and int(f.model.state.gold)==int(reserve.gold),label+":manual_removes_only_bottle_no_debit")
 else:
  _check(result.get("auto_drink",false) and f.model.state.inventory==before.inventory,label+":auto_drink_no_seventh_item",result)
 var after:Dictionary=_snapshot(f)
 _assert_immediate(f,item,before,after)
 f["before_effect"]=before
 f["active_effect"]=after
 if manual and not _fill_equipment(f,1):return {}
 f["active_effect"]=_snapshot(f) # Full equipment baseline for later removal checks.
 var duplicate_before:Dictionary=f.model.state.duplicate(true)
 var duplicate_stats:Dictionary=_snapshot(f)
 var duplicate:Dictionary=_trade(f,"buy",{"item":item})
 _check(not duplicate.get("accepted",true) and str(duplicate.get("reason",""))=="same_name_elixir_active",label+":duplicate_rejected",duplicate)
 _check(f.model.state==duplicate_before and f.sim.hero.stats==duplicate_stats.stats and _near(f.sim.hero.hp,duplicate_stats.hp),label+":duplicate_atomic_no_mutation")
 return f

func _safe_retention(f:Dictionary)->void:
 var before:Dictionary=_snapshot(f)
 # Source movement is allowed while source combat clocks and proc timers freeze.
 f.sim.free_move(0.2,Vector3.RIGHT)
 for index:int in range(20):f.sim.step(0.5);f.consumer.advance()
 var moved:Dictionary=_snapshot(f)
 _check(moved.position!=before.position,str(f.label)+":safe_movement_allowed")
 for key:String in CLOCK_KEYS:_check(_near(float(moved[key]),float(before[key])),str(f.label)+":safe_frozen_"+key)
 _check(moved.shop_visit.active_elixir==before.shop_visit.active_elixir and moved.static==before.static and moved.stats==before.stats,str(f.label)+":safe_wait_no_bottle_expiry")
 var result:Dictionary=_authority(f,"enter_room",{"next_room":str(f.sim.route_run_id)+"/ordinary-safe-room"})
 var after:Dictionary=_snapshot(f)
 _check(result.get("accepted",false) and after.shop_visit.active_elixir==before.shop_visit.active_elixir and after.static==before.static and after.stats==before.stats,str(f.label)+":ordinary_room_retains_effect",{"result":result,"after":after,"not_rest":true})

func _rest_negative_checks(f:Dictionary)->void:
 var before:Dictionary=f.model.state.duplicate(true)
 var wrong_owner:RefCounted=RefCounted.new()
 var denied:Dictionary=f.model.clear_elixir_for_rest(wrong_owner,{})
 _check(not denied.get("accepted",true) and denied.get("reason","")=="wrong_commerce_authority",str(f.label)+":rest_wrong_owner_rejected",denied)
 denied=f.model.clear_elixir_for_rest(f.session,{})
 _check(not denied.get("accepted",true) and denied.get("reason","")=="committed_rest_entry_required",str(f.label)+":ordinary_room_is_not_rest",denied)
 denied=_trade(f,"clear_rest_elixir",{"entry_id":"fabricated"})
 _check(not denied.get("accepted",true) and denied.get("reason","")=="committed_rest_elixir_authority_required",str(f.label)+":raw_rest_clear_rejected",denied)
 denied=_authority(f,"clear_rest_elixir",{"entry_id":"fabricated"})
 _check(not denied.get("accepted",true) and denied.get("reason","")=="committed_rest_elixir_authority_required",str(f.label)+":trusted_but_uncommitted_rest_rejected",denied)
 _check(f.model.state==before,str(f.label)+":rest_rejections_do_not_mutate_inventory_or_effect")

func _paused_proc_check(f:Dictionary,key:String)->void:
 var before:Dictionary=_snapshot(f)
 var seconds:float=float(before.consumer.get(key,0.0))
 if seconds<=0.0:return
 f.sim.paused=true
 for index:int in range(30):f.sim.step(0.25);f.consumer.advance()
 var after:Dictionary=_snapshot(f)
 _check(_near(float(after.consumer.get(key,0.0)),seconds),str(f.label)+":paused_"+key+"_frozen",{"before":seconds,"after":after.consumer.get(key,0.0)})
 for clock_key:String in CLOCK_KEYS:_check(_near(float(after[clock_key]),float(before[clock_key])),str(f.label)+":paused_"+clock_key)
 f.sim.paused=false

func _source_encounter(f:Dictionary,item:String)->void:
 var room:String=str(f.sim.route_run_id)+"/isolated-stock-source-combat"
 var entered:Dictionary=_authority(f,"enter_room",{"next_room":room})
 if not _check(entered.get("accepted",false),str(f.label)+":combat_room_commit",entered):return
 var level:Dictionary=f.ledger.command("enter_level",{"combat_level_id":room})
 if not _check(level.get("ok",false),str(f.label)+":combat_level_commit",{"reason":level.get("reason","")}):return
 f.sim.auto_finish=true
 # Original stock profiles, HP, damage and AI. No direct damage or forced end.
 var started:Dictionary=f.sim.begin_encounter(room,[{"kind":"minion","position":Vector3(0,0,-3)},{"kind":"minion","position":Vector3(0,0,-7)}])
 var binding:Dictionary=_snapshot(f)
 _check(started.get("accepted",false) and binding.phase=="combat" and binding.sim_phase=="combat" and not str(binding.shop_visit.battle_id).is_empty() and binding.shop_visit.active_elixir.get("battle_id","")==binding.shop_visit.battle_id,str(f.label)+":actual_source_battle_binding",binding)
 var saw_proc:bool=false
 var proc_clock:String="war_seconds" if item=="elixir:01" else "stride_seconds"
 var time_in_combat:float=0.0
 var shift_requested:bool=false
 while f.sim.phase=="combat" and time_in_combat<COMBAT_LIMIT and not finished:
  var live:Array=f.sim.living()
  if live.is_empty():f.sim.step(0.02);time_in_combat+=0.02;continue
  var target:Dictionary=live[0]
  for enemy:Dictionary in live:
   if f.sim.hero.position.distance_to(enemy.position)<f.sim.hero.position.distance_to(target.position):target=enemy
  var distance:float=f.sim.hero.position.distance_to(target.position)
  f.sim.hero.move_intent=(Vector3(target.position)-f.sim.hero.position).normalized() if distance>1.45 else Vector3.ZERO
  if item=="elixir:05" and not shift_requested:
   var shifted:Dictionary=f.sim.request_action("shift",f.sim.hero.position+Vector3.RIGHT*3.0,_id("shift"))
   shift_requested=bool(shifted.get("accepted",false))
  if distance<2.4:f.sim.request_action("attack",target.position,_id("attack"))
  f.sim.step(0.02);time_in_combat+=0.02
  if item in ["elixir:01","elixir:05"] and not saw_proc and float(f.consumer.snapshot().get(proc_clock,0.0))>0.0:
   saw_proc=true
   _record("actual_source_proc",{"label":f.label,"source":proc_clock,"snapshot":_snapshot(f)})
   _paused_proc_check(f,proc_clock)
  if int(time_in_combat*50.0)%100==0:await process_frame
 var after:Dictionary=_snapshot(f)
 _check(f.sim.phase=="victory" and f.sim.living().is_empty() and not f.sim.hero.dead,str(f.label)+":genuine_source_victory",{"seconds":time_in_combat,"phase":f.sim.phase,"living":f.sim.living().size(),"hp":f.sim.hero.hp})
 if item in ["elixir:01","elixir:05"]:_check(saw_proc,str(f.label)+":actual_proc_observed",{"clock":proc_clock})
 _check(f.model.state.phase=="safe" and f.model.state.shop_visit.active_elixir.is_empty() and f.consumer.static_stats().is_empty() and f.consumer.active_item().is_empty(),str(f.label)+":battle_end_removes_bottle",after)
 if item=="elixir:02":
  _check(_near(float(after.stats.ap),float(f.active_effect.stats.ap)-60.0) and _near(float(after.stats.cdr),float(f.active_effect.stats.cdr)-0.10),str(f.label)+":arcane_stats_removed_at_end")
 elif item=="elixir:04":
  _check(_near(float(after.stats.penetration),float(f.active_effect.stats.penetration)-20.0) and _near(float(after.stats.crit_chance),float(f.active_effect.stats.crit_chance)-0.15),str(f.label)+":hunt_stats_removed_at_end")
 elif item=="elixir:03":
  # Active output minus the 15% factor must equal the unchanged equipment base.
  _check(_near(float(after.stats.max_hp),float(f.active_effect.stats.max_hp)/1.15),str(f.label)+":steel_maxhp_removed_at_end")
  var hp_projection:Dictionary=after.consumer.steel.hp_transition
  _check(hp_projection.get("steel_active",true)==false and _near(float(hp_projection.get("before_hp",0.0))/float(hp_projection.get("before_max",1.0)),float(hp_projection.get("after_hp",0.0))/float(hp_projection.get("after_max",1.0))),str(f.label)+":steel_end_removal_preserves_ratio",hp_projection)
 elif item=="elixir:01":
  _check(_near(float(after.stats.ad),float(f.active_effect.stats.ad)-35.0),str(f.label)+":war_ad_removed_at_end")
 elif item=="elixir:05":_check(_near(f.consumer.movement_fraction(),0.0) and _near(float(after.speed),float(after.stats.move_speed)),str(f.label)+":swift_speed_removed_at_end")
 var clock_before:Dictionary=after.duplicate(true)
 f.sim.free_move(0.2,Vector3.LEFT);f.sim.step(5.0);f.consumer.advance()
 var frozen:Dictionary=_snapshot(f)
 for key:String in CLOCK_KEYS:_check(_near(float(frozen[key]),float(clock_before[key])),str(f.label)+":postbattle_frozen_"+key)
 _check(f.consumer.static_stats().is_empty() and f.model.state.shop_visit.active_elixir.is_empty(),str(f.label)+":postbattle_movement_does_not_restore_effect")

func _run_fixtures()->void:
 for item:String in ITEMS:
  for manual:bool in [false,true]:
   var f:Dictionary=_prepare_effect(item,manual)
   if f.is_empty():continue
   _safe_retention(f)
   _rest_negative_checks(f)
   await _source_encounter(f,item)
   _record("fixture_complete",{"label":f.label,"snapshot":_snapshot(f)})
   f.consumer.retire()
   f.sim.queue_free()
   await process_frame
   if finished:return
 _record("uncovered",{"rest_settlement":"Not exercised by this source-contract fixture. Use committed-rest observer; never substitute a plain enter_room result.","normal_ui_full_slot":"Not exercised. Seeded separate fixtures prove source behavior only.","normal_economy":"Not exercised.","native_input":"Button signals and source action requests are not OS input.","combat_procs":"Arcane skill-hit and hunt elite/boss damage not covered; lifecycle and static stats only."})
 _finish("complete")

func _finish(reason:String)->void:
 if finished:return
 finished=true
 _record("final",{"reason":reason,"passed":passed,"failed":failed,"coverage_exclusions":coverage,"runtime_acceptance":"isolated_source_fixture_only"})
 if output!=null:output.close()
 quit(0 if failed==0 and reason=="complete" else 9)
