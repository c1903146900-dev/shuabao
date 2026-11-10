extends SceneTree
## ISOLATED SOURCE-CONTRACT FIXTURE, not normal UI/economy or full-route acceptance.
## V02: fix snapshot-only progression fields; preserve v01 source and evidence.
## Prepared only; no engine/parser run by author.
## Every engine invocation needs the unchanged guard through CUA.
## Normal candidate boot is read-only. All funding/HP seeds belong to fresh test runs.
const ROUTE:Array[String]=["r01b","r02b","r03b","r04b","r05c","r06c","r07b"]
const CLOCK_KEYS:Array[String]=["hero_time","world_time","real_time"]
const WALL_LIMIT_MS:int=180000
const COMBAT_LIMIT:float=100.0
const FIXTURE_GOLD:int=100000
const BOOT_SCENE:String="res://boot.tscn"
var output:FileAccess
var output_dir:String="user://observe_committed_rest02"
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
var coverage:Dictionary={"normal_ui_full_slot":false,"normal_economy":false,"full_route":false,"natural_sustain":false,"rest_settlement":false,"os_native_input":false}
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
 _record("configuration",{"fixture_only":true,"normal_boot_read_only":true,"fixture_gold_seed":FIXTURE_GOLD,"fixture_steel_hp_ratio":0.37,"safe_boundary_full_hp_seeds":true,"combat_hp_writes":false,"route":ROUTE,"unmodified_ai":true,"unmodified_damage":true,"engine_validation_before_run":"not_run","coverage_exclusions":coverage})
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
 host.frontdoor_close_run("committed_rest_fixture_boot_complete")
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
 print("COMMITTED_REST ",line)

func _check(ok:bool,label:String,detail:Dictionary={})->bool:
 if ok:passed+=1
 else:failed+=1
 _record("check",{"label":label,"passed":ok,"detail":detail})
 return ok

func _near(a:float,b:float)->bool:return absf(a-b)<=0.00001*maxf(1.0,maxf(absf(a),absf(b)))
func _id(prefix:String)->String:serial+=1;return "committed-rest-fixture:%s:%d"%[prefix,serial]

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

# Everything after the separate zero-resource boot belongs to an isolated run.
# Only gold and explicitly logged SAFE-stage HP are seeded. No grants of XP,
# kills, offers, route receipts, cooldowns, invulnerability or combat damage.
func _input_release(sim:Node,_reason:String)->void:
 sim.hero.move_intent=Vector3.ZERO

func _bind_route(f:Dictionary)->bool:
 var sim:Node=f.sim
 var session:RefCounted=f.session
 var bound:Dictionary=session.bind_input_suspender(func(reason:String):_input_release(sim,reason))
 sim.combat_event.connect(func(event:Dictionary):
  var result:Dictionary=session.observe_event(sim,event)
  if str(event.get("kind","")) in ["damage","kill"] and not result.get("accepted",false):
   _check(false,"route_event_rejected",{"event":event,"result":result}))
 sim.encounter_finished.connect(func(actual:Dictionary):session.queue_terminal(sim,actual))
 return _check(bound.get("accepted",false),"route_input_binding",bound)

# pending_milestones is a public snapshot projection, not a stored state key.
# Reject a missing/wrong schema rather than silently treating it as no Hex due.
func _growth_snapshot(f:Dictionary)->Dictionary:
 var view:Dictionary=f.model.snapshot()
 if not view.has("pending_milestones") or not view.pending_milestones is Array or not view.has("offers") or not view.offers is Dictionary or not view.has("skills") or not view.skills is Dictionary or not view.has("points"):
  _check(false,"progression_snapshot_schema",{"keys":view.keys()})
  return {}
 for slot:String in ["E","Q","P"]:
  if not view.skills.has(slot) or not view.skills[slot] is Dictionary or not view.skills[slot].has("rank") or not view.skills[slot].has("candidate"):
   _check(false,"progression_skill_schema",{"slot":slot,"skills":view.skills})
   return {}
 return view

func _settle_growth(f:Dictionary)->bool:
 var attempts:int=0
 var view:Dictionary=_growth_snapshot(f)
 if view.is_empty():return false
 _record("real_pending_hex_view",{"pending_milestones":view.pending_milestones,"level":view.level,"points":view.points})
 while not view.pending_milestones.is_empty() and attempts<8:
  attempts+=1
  var milestone:int=int(view.pending_milestones[0])
  var opened:Dictionary=f.model.command(_id("hex-open"),"hex_open",{"milestone":milestone})
  f.session.progression_command_completed({"action":"hex_open"},opened)
  if not _check(opened.get("accepted",false),"real_hex_open",opened):return false
  view=_growth_snapshot(f)
  if view.is_empty():return false
  var key:String=str(milestone)
  if not view.offers.has(key) or not view.offers[key] is Dictionary:
   _check(false,"real_offer_missing_after_acceptance",{"milestone":milestone,"offers":view.offers});return false
  var offer:Dictionary=view.offers[key]
  if not offer.has("slots") or not offer.slots is Array or not offer.has("selected"):
   _check(false,"real_offer_schema",{"milestone":milestone,"offer":offer});return false
  var slots:Array=offer.slots
  if not _check(slots.size()==4 and str(offer.selected).is_empty(),"real_offer_four_unselected_slots",{"milestone":milestone,"slots":slots}):return false
  var selected:Dictionary=f.model.command(_id("hex-select"),"hex_select",{"milestone":milestone,"slot":0})
  f.session.progression_command_completed({"action":"hex_select"},selected)
  if not _check(selected.get("accepted",false),"real_hex_select",{"selected":slots[0],"result":selected}):return false
  view=_growth_snapshot(f)
  if view.is_empty():return false
  if not _check(not milestone in view.pending_milestones and str(view.offers[key].selected)==str(slots[0]) and str(slots[0]) in view.selected_hex,"real_hex_selection_removed_only_settled_milestone",{"milestone":milestone,"pending":view.pending_milestones,"selected_hex":view.selected_hex}):return false
 if not _check(view.pending_milestones.is_empty(),"no_unresolved_hex",{"pending":view.pending_milestones}):return false
 # Invest only earned points through source bridge; no rank/level injection.
 for attempt:int in range(20):
  view=_growth_snapshot(f)
  if view.is_empty():return false
  if int(view.points)<=0:break
  var choices:Array=[]
  for pair:Array in [["E","E1"],["Q","Q3"],["P","P2"]]:
   if int(view.skills[pair[0]].rank)==0:choices.append(pair)
  choices.append_array([["E","E1"],["Q","Q3"],["P","P2"]])
  var learned:bool=false
  for pair:Array in choices:
   var result:Dictionary=f.sim.learn_ability(pair[0],pair[1])
   if result.get("ok",false):
    var after:Dictionary=_growth_snapshot(f)
    if after.is_empty():return false
    _record("source_skill_investment",{"slot":pair[0],"candidate":pair[1],"rank":after.skills[pair[0]].rank})
    learned=true;break
  if not learned:break
 f.session.update_after_source_step()
 return true

func _seed_safe_hp(f:Dictionary,ratio:float,purpose:String)->bool:
 if not _check(f.model.state.phase=="safe" and f.sim.phase in ["preparation","victory"] and not f.sim.transaction_active and not f.sim.hero.dead,"hp_fixture_safe_only",{"purpose":purpose}):return false
 var before:float=f.sim.hero.hp
 f.sim.hero.hp=float(f.sim.hero.stats.max_hp)*ratio
 f.sim.observe_pending_health()
 _record("fixture_hp_seed",{"purpose":purpose,"normal_run":false,"before":before,"after":f.sim.hero.hp,"max_hp":f.sim.hero.stats.max_hp,"ratio":ratio,"not_natural_sustain_evidence":true})
 return true

func _uid(f:Dictionary,item:String)->int:
 for entry_item:Dictionary in f.model.state.inventory:
  if str(entry_item.id)==item:return int(entry_item.uid)
 return -1

func _buy_drink_steel(f:Dictionary)->bool:
 var result:Dictionary=_trade(f,"buy",{"item":"elixir:03"})
 if not _check(result.get("accepted",false),str(f.label)+":buy_held_steel",result):return false
 var uid:int=_uid(f,"elixir:03")
 if not _check(uid>=0,str(f.label)+":steel_not_auto_drunk"):return false
 result=_trade(f,"consume",{"uid":uid})
 return _check(result.get("accepted",false) and f.consumer.active_item()=="elixir:03",str(f.label)+":manual_steel_immediate",result)

func _ordinary_room_control()->bool:
 var f:Dictionary=_new_fixture("ordinary-room-control")
 if f.is_empty():return false
 if not _buy_drink_steel(f):return false
 var before:Dictionary=_snapshot(f)
 var entered:Dictionary=_authority(f,"enter_room",{"next_room":str(f.sim.route_run_id)+"/ordinary-safe-control"})
 var after:Dictionary=_snapshot(f)
 var ok:bool=_check(entered.get("accepted",false) and before.shop_visit.active_elixir==after.shop_visit.active_elixir and before.stats==after.stats and _near(before.hp,after.hp),"ordinary_nonrest_commerce_transition_keeps_effect",{"before":before,"after":after,"result":entered,"route_entry_claimed":false})
 f.consumer.retire();f.sim.queue_free()
 return ok

func _walk_exit(f:Dictionary)->bool:
 var sim:Node=f.sim
 var session:RefCounted=f.session
 # Real safe movement; no teleport or map-permission/route-state assignment.
 for index:int in range(1200):
  session.update_room_exit()
  if session.exit_map_open and session._at_room_exit():return true
  var target:Vector3=session.ROOM_EXIT_POSITION
  var position:Vector3=sim.hero.position
  var direction:Vector3=(target-position).normalized()
  sim.free_move(0.02,direction)
  if index%50==0:await process_frame
  if finished:return false
 return _check(false,"walk_to_authored_upper_exit",{"room":session.active_node_room,"position":sim.hero.position,"exit":session.room_exit_view(),"boundary":session._safe_boundary_reason()})

func _combat_route_node(f:Dictionary)->bool:
 var sim:Node=f.sim
 var session:RefCounted=f.session
 var ticks:int=0
 var observed_start:int=passed
 while sim.phase=="combat" and float(ticks)*0.02<COMBAT_LIMIT and not finished:
  var live:Array=sim.living()
  if not live.is_empty():
   var target:Dictionary=live[0]
   for enemy:Dictionary in live:
    if sim.hero.position.distance_to(enemy.position)<sim.hero.position.distance_to(target.position):target=enemy
   var aim:Vector3=target.position
   var distance:float=sim.hero.position.distance_to(aim)
   var evade:bool=false
   for threat:Dictionary in live:
    if str(threat.state)=="warning" and float(threat.warning_progress)>0.20 and sim.hero.position.distance_to(threat.position)<float(threat.attack_range)+2.0:
     var side:Vector3=Vector3(-float(threat.aim.z),0,float(threat.aim.x))
     sim.hero.move_intent=side.normalized()
     if float(threat.timer)<0.25 and float(sim.hero.cooldowns.shift)<=0.0:sim.request_action("shift",sim.hero.position+side*3.0,_id("evade"))
     evade=true;break
   if not evade:sim.hero.move_intent=(aim-sim.hero.position).normalized() if distance>1.45 else Vector3.ZERO
   if distance<7.0 and float(sim.hero.cooldowns.e)<=0.0:sim.request_action("e",aim,_id("e"))
   if distance<9.0 and float(sim.hero.cooldowns.q)<=0.0:sim.request_action("q",aim,_id("q"))
   if distance<2.4:sim.request_action("attack",aim,_id("attack"))
  sim.step(0.02);ticks+=1
  session.update_after_source_step()
  if ticks%100==0:
   _record("route_combat_progress",{"node":session._active_node.node_id,"seconds":ticks*0.02,"hp":sim.hero.hp,"living":sim.living().size(),"status":session.status})
   await process_frame
 var rows:Dictionary=session.row_state.snapshot()
 return _check(sim.phase=="victory" and not sim.hero.dead and sim.living().is_empty() and session.status=="between_rooms" and rows.status=="awaiting_selection" and session.fault.is_empty(),"authentic_route_combat_completed",{"room":session.active_node_room,"seconds":ticks*0.02,"hp":sim.hero.hp,"status":session.status,"completed_rows":rows.completed_rows.size(),"kills":session.kill_receipts.size(),"expected":session.expected_enemies.size(),"fault":session.fault,"observations_start":observed_start})

func _prepare_training_rest(f:Dictionary)->bool:
 if not _check(f.session._entered_service("training") and int(f.session._active_node.row_number)==6,"real_sixth_row_training"):return false
 if not _check(f.session.open_panel().get("accepted",false),"training_shop_open"):return false
 if not _seed_safe_hp(f,0.37,"partial_health_for_steel_rest_removal"):return false
 var before:Dictionary=_snapshot(f)
 if not _buy_drink_steel(f):return false
 var active:Dictionary=_snapshot(f)
 if not _check(_near(float(active.stats.max_hp),float(before.stats.max_hp)*1.15) and _near(float(active.hp)/float(active.stats.max_hp),0.37),"training_steel_preserves_seed_ratio",{"before":before,"after":active}):return false
 var bought:Dictionary=_trade(f,"buy",{"item":"elixir:01"})
 if not _check(bought.get("accepted",false) and _uid(f,"elixir:01")>=0 and f.consumer.active_item()=="elixir:03","training_war_bottle_held_not_consumed",bought):return false
 if not _check(f.session.close_panel().get("accepted",false),"training_shop_close"):return false
 var completed:Dictionary=f.session.complete_service()
 if not _check(completed.get("accepted",false),"real_training_service_complete",completed):return false
 var after:Dictionary=_snapshot(f)
 _check(after.shop_visit.active_elixir==active.shop_visit.active_elixir and _near(float(after.hp)/float(after.stats.max_hp),0.37),"service_ready_not_rest_and_keeps_active_effect",after)
 f["pre_rest"]=_snapshot(f)
 f["pre_rest_state"]=f.model.state.duplicate(true)
 f["baseline_max"]=float(before.stats.max_hp)
 f["baseline_stats"]=before.stats.duplicate(true)
 return true

func _assert_rest_result(f:Dictionary,entered:Dictionary)->bool:
 var rest:Dictionary=entered.get("rest",{})
 var clear:Dictionary=rest.get("elixir_clear",{})
 var projection:Dictionary=clear.get("health_projection",{})
 var before:Dictionary=f.pre_rest
 var after:Dictionary=_snapshot(f)
 if not _check(rest.get("accepted",false) and str(rest.get("reason",""))=="rest_settled" and clear.get("accepted",false),"committed_rest_settled",entered):return false
 _check(f.session._entered_service("rest") and f.session.row_state.snapshot().status=="entered","rest_real_entry_remains_present",f.session.snapshot())
 _check(after.shop_visit.active_elixir.is_empty() and f.consumer.active_item().is_empty() and f.consumer.static_stats().is_empty(),"rest_clears_consumed_bottle",after)
 _check(_near(float(after.stats.max_hp),float(f.baseline_max)),"rest_removes_steel_max_hp",{"before":before.stats.max_hp,"after":after.stats.max_hp})
 _check(not projection.is_empty() and _near(float(projection.get("pre_hp",-1.0)),float(before.hp)) and _near(float(projection.get("pre_max",-1.0)),float(before.stats.max_hp)) and _near(float(projection.get("post_hp",-1.0)),float(f.baseline_max)*0.37) and _near(float(projection.get("post_max",-1.0)),float(f.baseline_max)) and _near(float(projection.get("transaction_clamp",-1.0)),0.0) and not bool(projection.get("healing_event_emitted",true)),"steel_removal_ratio_before_any_rest_heal",projection)
 _check(_near(float(after.hp),float(after.stats.max_hp)) and _near(float(rest.get("actual_heal",-1.0)),float(f.baseline_max)*0.63),"rest_then_heals_once_to_final_max",rest)
 _check(after.inventory==before.inventory and _uid(f,"elixir:01")>=0,"rest_keeps_undrunk_war_inventory",{"inventory":after.inventory})
 _check(int(after.gold)==int(before.gold),"rest_no_gold_change")
 _check(after.shop_visit.effect_receipts==before.shop_visit.effect_receipts and after.shop_visit.effect_receipts.has(str(before.shop_visit.active_elixir.effect_id)),"rest_consumption_receipts_not_reset")
 _check(int(after.shop_visit.flask_charges)==int(before.shop_visit.flask_charges),"rest_does_not_refill_basic_flask",{"before":before.shop_visit.flask_charges,"after":after.shop_visit.flask_charges,"depleted_flask_scenario_claimed":false})
 _check(after.shop_visit.undo.is_empty(),"real_room_commit_drops_previous_shop_undo")
 _check(f.sim.hero.cooldowns.values().all(func(value:Variant):return float(value)==0.0) and f.sim.hero.shields.is_empty() and f.sim.pending.is_empty() and f.sim.projectiles.is_empty() and f.sim.zones.is_empty(),"rest_live_cleanup",{"cooldowns":f.sim.hero.cooldowns})
 var replay_before:Dictionary=_snapshot(f)
 var replay_state:Dictionary=f.model.state.duplicate(true)
 var replay:Dictionary=f.session.rest_service.settle(f.session,f.session._active_entry.duplicate(true))
 var replay_after:Dictionary=_snapshot(f)
 _check(replay.get("accepted",false) and replay.get("replayed",false),"same_committed_rest_replays",replay)
 _check(f.model.state==replay_state and replay_before==replay_after,"rest_replay_no_live_mutation")
 # Lower only isolated safe HP after settlement: cached replay must not heal again.
 if not _seed_safe_hp(f,0.50,"test_replay_does_not_repeat_heal"):return false
 replay_before=_snapshot(f);replay_state=f.model.state.duplicate(true)
 replay=f.session.rest_service.settle(f.session,f.session._active_entry.duplicate(true))
 _check(replay.get("accepted",false) and replay.get("replayed",false) and f.model.state==replay_state and _snapshot(f)==replay_before,"same_rest_replay_does_not_reheal_after_hp_seed",replay)
 # Return may repeat the cached original receipt. Assert live state, not old after_hp.
 coverage.rest_settlement=true
 return true

func _run_fixtures()->void:
 if not _ordinary_room_control():_finish("ordinary_control_failed");return
 await process_frame
 var f:Dictionary=_new_fixture("committed-rest-route")
 if f.is_empty() or not _bind_route(f):_finish("fixture_setup_failed");return
 if not _settle_growth(f):_finish("initial_progression_failed");return
 for item:String in ["base:B01","base:B01","base:B01","base:B06"]:
  var bought:Dictionary=_trade(f,"buy",{"item":item})
  if not _check(bought.get("accepted",false),"fixture_real_equipment_purchase",{"item":item,"result":bought}):_finish("fixture_gear_failed");return
 for index:int in range(ROUTE.size()):
  if not _settle_growth(f):_finish("progression_blocked");return
  if index<6 and not _seed_safe_hp(f,1.0,"traversal_only_safe_boundary_full_hp"):_finish("unsafe_hp_seed");return
  var reached_exit:bool=await _walk_exit(f)
  if not reached_exit:_finish("route_exit_failed");return
  var selected:Dictionary=f.session.select_node(index+1,ROUTE[index])
  if not _check(selected.get("accepted",false),"real_route_node_selected",{"node":ROUTE[index],"result":selected}):_finish("selection_failed");return
  var entered:Dictionary=f.session.enter_selected_node()
  if not _check(entered.get("accepted",false),"real_route_node_entered",{"node":ROUTE[index],"result":entered}):_finish("entry_failed");return
  _record("route_entry",{"node":ROUTE[index],"state":f.session.snapshot(),"source":_snapshot(f)})
  if index==6:
   if not _assert_rest_result(f,entered):_finish("rest_contract_failed");return
  elif f.session.status=="combat":
   var completed_combat:bool=await _combat_route_node(f)
   if not completed_combat:_finish("route_combat_failed");return
  elif index==5:
   if not _prepare_training_rest(f):_finish("training_preparation_failed");return
  else:
   var completed:Dictionary=f.session.complete_service()
   if not _check(completed.get("accepted",false),"real_early_training_complete",completed):_finish("early_service_failed");return
 f.consumer.retire();f.sim.queue_free()
 _record("uncovered",{"normal_economy":"Fixture funds; actual prices and purchases only.","natural_sustain":"Explicit safe HP seeds between route battles.","full_route":"Stops after first rest at row7.","ui":"Source commands and start Button signal, not OS input or natural UI acceptance.","ordinary_transition":"Separate commerce-only control, not synthetic route receipts.","rest_cleanup":"Cooldown/queue clearing checked; not exhaustive every possible buff."})
 _finish("complete")

func _finish(reason:String)->void:
 if finished:return
 finished=true
 if reason!="complete" and failed==0:_check(false,"observer_did_not_complete",{"reason":reason})
 _record("final",{"reason":reason,"passed":passed,"failed":failed,"coverage_exclusions":coverage,"runtime_acceptance":"isolated_source_fixture_only"})
 if output!=null:output.close()
 quit(0 if failed==0 and reason=="complete" else 9)
