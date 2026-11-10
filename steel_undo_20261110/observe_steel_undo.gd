extends SceneTree
## Isolated source-contract regression probe. Never funds or edits the normal run.
## One case per process: an original full-HP assertion may interrupt undo.
## Every engine invocation MUST use the unchanged owned guard through CUA.
const CASES:Array[String]=["control_half","control_full","steel_half","steel_full"]
const WALL_LIMIT_MS:int=20000
const FIXTURE_GOLD:int=100000
var case_name:String=""
var output:FileAccess
var started_ms:int=0
var undo_started_ms:int=-1
var boot:Node
var entry:Node
var host:Node
var fixture_sim:Node
var boot_started:bool=false
var running:bool=false
var finished:bool=false
var passed:int=0
var failed:int=0
var serial:int=0

func _initialize()->void:
 started_ms=Time.get_ticks_msec()
 var output_dir:String="user://steel_undo_probe"
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--case="):case_name=arg.trim_prefix("--case=")
  if arg.begins_with("--observer-output="):output_dir=arg.trim_prefix("--observer-output=").simplify_path()
 if case_name not in CASES or not output_dir.begins_with("user://"):
  push_error("valid_case_and_user_output_required");quit(9);return
 var path:String=output_dir.path_join("observations.jsonl")
 if FileAccess.file_exists(path):push_error("fresh_output_required");quit(9);return
 if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))!=OK:push_error("output_unwritable");quit(9);return
 output=FileAccess.open(path,FileAccess.WRITE)
 if output==null:push_error("output_unwritable");quit(9);return
 _record("configuration",{"fixture_only":true,"normal_boot_read_only":true,"fixture_gold":FIXTURE_GOLD,"fixture_health_seed":true,"production_patched":false,"expected_regression":"Steel sale undo must return to pre-sale HP, not add the ratio shrink a second time.","runtime_acceptance":false})
 var scene:PackedScene=load("res://boot.tscn")
 if scene==null:_check(false,"boot_scene_available");_finish("boot_failed");return
 boot=scene.instantiate();root.add_child(boot)

func _process(_delta:float)->bool:
 if finished:return false
 if Time.get_ticks_msec()-started_ms>WALL_LIMIT_MS:
  _check(false,"wall_watchdog");_finish("wall_timeout");return false
 if running:
  if undo_started_ms>=0 and Time.get_ticks_msec()-undo_started_ms>2000:
   _check(false,"undo_did_not_return",{"note":"Inspect the guard-owned engine log. A missing final result is never a pass."})
   _finish("undo_interrupted")
  return false
 if entry==null:
  for child:Node in boot.get_children():
   if child.get("screen")!=null:entry=child;break
  return false
 if not boot_started:
  boot_started=true
  if not is_instance_valid(entry.get("_start")):_check(false,"frontdoor_start_available");_finish("boot_failed");return false
  entry._start.pressed.emit()
  return false
 host=entry.get("active_room")
 if host==null:return false
 if not str(host.startup_session_error).is_empty() or not str(host.floor_error).is_empty():
  _check(false,"normal_boot_ready",{"startup":host.startup_session_error,"floor":host.floor_error});_finish("boot_failed");return false
 if host.shop_session==null or host.shop_session.ledger==null:return false
 var state:Dictionary=host.shop_session.ledger.model.state
 if not _check(int(state.gold)==0 and state.inventory.is_empty() and host.sim.phase=="preparation","normal_run_untouched",{"gold":state.gold,"slots":state.inventory.size(),"phase":host.sim.phase}):
  _finish("boot_failed");return false
 host.frontdoor_close_run("steel_undo_probe_normal_boot_complete")
 running=true
 _run_case.call_deferred()
 return false

func _record(kind:String,detail:Dictionary={})->void:
 var row:Dictionary=detail.duplicate(true)
 row["record"]=kind;row["case"]=case_name;row["wall_ms"]=Time.get_ticks_msec()-started_ms
 var line:String=JSON.stringify(row)
 if output!=null:output.store_line(line);output.flush()
 print("STEEL_UNDO ",line)

func _check(ok:bool,label:String,detail:Dictionary={})->bool:
 if ok:passed+=1
 else:failed+=1
 _record("check",{"label":label,"passed":ok,"detail":detail})
 return ok

func _near(a:float,b:float)->bool:return absf(a-b)<=0.00001*maxf(1.0,maxf(absf(a),absf(b)))
func _id(operation:String)->String:serial+=1;return "steel-undo:%s:%s:%d"%[case_name,operation,serial]

func _trade(f:Dictionary,operation:String,extra:Dictionary={})->Dictionary:
 var args:Dictionary=f.model.commerce_token();args.merge(extra,true)
 return f.ledger.shop_command(_id(operation),operation,args)

func _uid(f:Dictionary,item:String)->int:
 for entry_item:Dictionary in f.model.state.inventory:
  if str(entry_item.id)==item:return int(entry_item.uid)
 return -1

func _snapshot(f:Dictionary)->Dictionary:
 return {"hp":f.sim.hero.hp,"max_hp":f.sim.hero.stats.max_hp,"stats":f.sim.hero.stats.duplicate(true),"gold":f.model.state.gold,"inventory":f.model.state.inventory.duplicate(true),"revision":f.model.state.revision,"health_revision":f.sim.equipment_health_revision,"undo":f.model.state.shop_visit.undo.duplicate(true),"active_elixir":f.model.state.shop_visit.active_elixir.duplicate(true),"effect_receipts":f.model.state.shop_visit.effect_receipts.duplicate(true),"steel_transition":f.model.elixir_consumer.steel.snapshot().hp_transition}

func _run_case()->void:
 fixture_sim=load("res://fengli_route_20261024/sim.gd").new()
 root.add_child(fixture_sim)
 var session:RefCounted=load("res://fengli_route_20261024/session.gd").new()
 var definition:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(session.DEFAULT_DEFINITION))
 var configured:Dictionary=session.configure_reward_table("res://__clean_fengli/machine_templates.bin","res://__clean_fengli/machine_templates.bin","res://__clean_fengli/machine_templates.bin",true)
 if not _check(configured.get("accepted",false),"fixture_configuration",{"reason":configured.get("reason","")}):_finish("fixture_failed");return
 var initialized:Dictionary=session.initialize_floor(fixture_sim,definition,_id("run"),true)
 if not _check(initialized.get("accepted",false),"fixture_initialization",{"reason":initialized.get("reason","")}):_finish("fixture_failed");return
 var model:RefCounted=session.ledger.model
 if not _check(int(model.state.gold)==0 and model.state.inventory.is_empty(),"fixture_fresh_before_seed"):_finish("fixture_failed");return
 # Funding is confined to this newly initialized independent test model.
 model.state.gold=FIXTURE_GOLD
 var f:Dictionary={"sim":fixture_sim,"session":session,"model":model,"ledger":session.ledger}
 var args:Dictionary=model.commerce_token();args["area"]="isolated-steel-undo-fixture"
 var visit:Dictionary=f.ledger.shop_authority(session,_id("begin_visit"),"begin_visit",args)
 if not _check(visit.get("accepted",false),"fixture_shop_visit",visit):_finish("fixture_failed");return
 var source_max:float=fixture_sim.hero.stats.max_hp
 var bought:Dictionary=_trade(f,"buy",{"item":"base:B06"})
 if not _check(bought.get("accepted",false),"buy_real_hp_equipment",bought):_finish("fixture_failed");return
 var equipment_uid:int=_uid(f,"base:B06")
 var unscaled_max:float=fixture_sim.hero.stats.max_hp
 if not _check(equipment_uid>0 and _near(unscaled_max-source_max,140.0),"source_hp_equipment_adds_140",{"before":source_max,"after":unscaled_max,"uid":equipment_uid}):_finish("fixture_failed");return
 var steel:bool=case_name.begins_with("steel_")
 if steel:
  var held:Dictionary=_trade(f,"buy",{"item":"elixir:03"})
  if not _check(held.get("accepted",false) and not held.get("auto_drink",true),"buy_held_steel",held):_finish("fixture_failed");return
  var drunk:Dictionary=_trade(f,"consume",{"uid":_uid(f,"elixir:03")})
  if not _check(drunk.get("accepted",false),"manual_steel_drink",drunk):_finish("fixture_failed");return
  if not _check(model.elixir_consumer.active_item()=="elixir:03" and _near(fixture_sim.hero.stats.max_hp,unscaled_max*1.15),"immediate_steel_active",_snapshot(f)):_finish("fixture_failed");return
 else:
  if not _check(model.state.shop_visit.active_elixir.is_empty() and _near(fixture_sim.hero.stats.max_hp,unscaled_max),"control_without_steel"):_finish("fixture_failed");return
 # A deliberate fixture seed before the observed sale. No combat/healing hook.
 var ratio:float=0.5 if case_name.ends_with("_half") else 1.0
 fixture_sim.hero.hp=float(fixture_sim.hero.stats.max_hp)*ratio
 fixture_sim.observe_pending_health()
 var before:Dictionary=_snapshot(f)
 _record("before_sale",{"snapshot":before,"seed_ratio":ratio,"normal_run":false})
 var sold:Dictionary=_trade(f,"sell",{"uid":equipment_uid})
 if not _check(sold.get("accepted",false),"sell_hp_equipment",sold):_finish("sale_failed");return
 var after_sale:Dictionary=_snapshot(f)
 var expected_max:float=source_max*(1.15 if steel else 1.0)
 var expected_hp:float=expected_max*ratio if steel else minf(float(before.hp),expected_max)
 _check(_near(after_sale.max_hp,expected_max) and _near(after_sale.hp,expected_hp),"sale_projection",{"actual":after_sale,"expected_hp":expected_hp,"expected_max":expected_max})
 if not _check(not model.state.shop_visit.undo.is_empty(),"sale_undo_record_exists"):_finish("sale_failed");return
 var sale_record:Dictionary=model.state.shop_visit.undo.back().duplicate(true)
 if not _check(sale_record.get("action","")=="sell" and not sale_record.get("sealed",true) and sale_record.get("hp_sensitive",false),"sale_is_current_unsealed_hp_transaction",sale_record):_finish("sale_failed");return
 # Flush BEFORE the unmodified production undo. Original full-steel code may
 # assert here; use the separate process/owned guard, never disable assertions.
 _record("before_undo",{"snapshot":after_sale,"expected_return_hp":before.hp,"expected_return_max":before.max_hp,"source_risk_additional_restore":sale_record.get("hp_clamp",{}).get("clamp_delta",0.0)})
 undo_started_ms=Time.get_ticks_msec()
 var undone:Dictionary=_trade(f,"undo")
 undo_started_ms=-1
 _record("undo_returned",{"result":undone,"snapshot":_snapshot(f)})
 if not _check(undone.get("accepted",false),"undo_accepted",undone):_finish("undo_rejected");return
 var after:Dictionary=_snapshot(f)
 _check(_near(after.max_hp,before.max_hp),"undo_restores_maximum",{"before":before.max_hp,"after":after.max_hp})
 _check(_near(after.hp,before.hp),"undo_restores_only_own_hp_change",{"before":before.hp,"after":after.hp,"excess":float(after.hp)-float(before.hp)})
 _check(float(after.hp)<=float(after.max_hp) and float(after.hp)>0.0,"undo_hp_within_live_bounds",{"hp":after.hp,"max_hp":after.max_hp})
 _check(after.inventory==before.inventory and int(after.gold)==int(before.gold),"undo_restores_only_item_and_money",{"before_gold":before.gold,"after_gold":after.gold})
 _check(after.active_elixir==before.active_elixir and after.effect_receipts==before.effect_receipts,"undo_preserves_consumed_effect_receipts")
 _finish("complete")

func _finish(reason:String)->void:
 if finished:return
 finished=true
 _record("final",{"reason":reason,"passed":passed,"failed":failed,"runtime_acceptance":"isolated_single_case_only","normal_ui_or_economy":false})
 if output!=null:output.close()
 if is_instance_valid(fixture_sim):fixture_sim.queue_free()
 quit(0 if failed==0 and reason=="complete" else 9)
