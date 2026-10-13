extends "res://integration_checks/training12_source_gate.gd"
## Original Host/Session economy fixture. No production state injection except
## declared60000 test wallet. Lifecycle settlement uses inherited source damage.
const WAR := "elixir:01"
const WAR_GROUPS := ["commerce","full_slots","lifecycle","replacement"]
var war_groups: Array = WAR_GROUPS.duplicate()
var war_done: Array = []
var war_records: Array = []
func _initialize() -> void:
 output_path="user://war_elixir04.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
  if arg.begins_with("--elixir-group="):
   var part: String=arg.trim_prefix("--elixir-group=")
   if part not in WAR_GROUPS:push_error("Unknown war group");quit(2);return
   war_groups=[part]
 run.call_deferred()
func check_model_successor(f: Dictionary,label: String) -> void:
 var script: Script=f.session.ledger.model.get_script()
 for path: String in ["res://elixir_war_20261009/model.gd","res://elixir_hunter_20261009/model.gd","res://formal_training_20261009/model.gd","res://equipment_regeneration_20261009/model.gd","res://equipment_blood_trial_20261009/model.gd","res://equipment_lifeline_20261009/model.gd","res://equipment_pursuit_20261009/model.gd","res://equipment_training_20261009/model.gd",B04_MODEL,G06_MODEL,B01_MODEL,DISTANCE_MODEL_PATH,POSTBOSS_MODEL_PATH,POSTBOSS_PRIOR_MODEL_PATH,POSTBOSS_BASE_MODEL_PATH]:
  if not check(script!=null and script.resource_path==path,label+": exact model ancestor "+path):return
  script=script.get_base_script()
 check(FileAccess.get_sha256(POSTBOSS_BASE_MODEL_PATH)==POSTBOSS_BASE_MODEL_SHA,label+": original Model retained")
func funded_shop(label: String) -> Dictionary:
 var f: Dictionary=fresh()
 if f.is_empty():return {}
 if not prepare_initial_choices(f):dispose(f);return {}
 var model=f.session.ledger.model
 f.baseline=authority(f)
 for key: String in ["b04_completions","b04_diagnostics","b04_trace","g06_damage","g06_targets","g06_attack_records","live_kills","g02_kills","g03_damage"]:f[key]=[]
 for key: String in ["b04_original_states","b04_release_clocks","g06_attack","g03_before_model"]:f[key]={}
 for key: String in ["b04_synthetic","g02_synthetic","g03_synthetic"]:f[key]=false
 f.b04_observer_action=""
 evidence.wallet_fixtures.append({"case":label,"before":model.state.gold,"after":60000,"test_only":true})
 model.state.gold=60000
 if not check(model.equipment_runtime_status(WAR).supported,"war actual source consumer bound") or not check(f.session.open_panel().accepted,"original safe shop opened"):
  dispose(f);return {}
 return f
func war_uid(f: Dictionary) -> int:
 for item: Dictionary in f.session.ledger.model.state.inventory:
  if item.id==WAR:return int(item.uid)
 return -1
func war_note(f: Dictionary,label: String) -> void:
 war_records.append({"label":label,"status":f.session.ledger.model.war_elixir_status(),"inventory":f.session.ledger.model.state.inventory.duplicate(true),"gold":f.session.ledger.model.state.gold,"stats":f.sim.hero.stats.duplicate(true),"visit":f.session.ledger.model.state.shop_visit.duplicate(true)})
func war_commerce() -> void:
 current_group="commerce"
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 var before: Dictionary=f.sim.hero.stats.duplicate(true)
 if not buy(f,WAR):dispose(f);return
 check(model.state.gold==59350 and model.state.inventory.size()==1,"original650 price and one stored slot")
 check(f.sim.hero.stats==before and not model.war_elixir_status().active,"stored bottle grants no stats")
 check(undo(f) and model.state.gold==60000 and model.state.inventory.is_empty(),"unused original purchase reversible")
 if not buy(f,WAR):dispose(f);return
 serial+=1
 var command_id: String="war-consume-"+str(serial)
 var args: Dictionary=model.commerce_token();args.uid=war_uid(f)
 var used: Dictionary=f.session.submit(command_id,"consume",args)
 f.session.update_after_source_step()
 check(used.accepted and model.state.inventory.is_empty(),"original safe consumption removes real uid")
 check(model.war_elixir_status().pending and not model.war_elixir_status().active and f.sim.hero.stats==before,"pending effect has no safe stats")
 check(model.state.shop_visit.undo.back().sealed,"original consumed lineage sealed")
 var state: Dictionary=model.state.duplicate(true)
 var repeated: Dictionary=f.session.submit(command_id,"consume",args)
 check(repeated.accepted and repeated.get("replayed",false) and model.state==state,"same original command replays without spending or effect duplication")
 var conflict: Dictionary=args.duplicate(true);conflict.uid+=1
 check(not f.session.submit(command_id,"consume",conflict).accepted and model.state==state,"same command different uid rejected without mutation")
 if not buy(f,WAR):dispose(f);return
 check(model.state.inventory.size()==1,"same name pending still permits one legally stored bottle")
 state=model.state.duplicate(true)
 var refused: Dictionary=shop_command(f,"consume",{"uid":war_uid(f)})
 check(not refused.accepted and refused.reason=="same_name_elixir_active" and model.state==state,"same-name repeated drink refuses without dropping or spending")
 for id: String in ["elixir:02","elixir:03","elixir:05"]:check(not model.commerce_quote(id).accepted,"other elixir remains held "+id)
 war_note(f,"stored plus pending same-name");dispose(f);war_done.append(current_group)
func war_full_slots() -> void:
 current_group="full_slots"
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 for i in range(6):
  if not buy(f,"base:B01"):dispose(f);return
 var inventory: Array=model.state.inventory.duplicate(true)
 var gold: int=model.state.gold
 var quote: Dictionary=model.commerce_quote(WAR)
 check(quote.accepted and quote.get("auto_drink",false),"full six original slots quote automatic drink")
 if not buy(f,WAR):dispose(f);return
 check(model.state.inventory==inventory and model.state.gold==gold-650 and model.war_elixir_status().pending,"full slots consume immediately without seventh item")
 check(model.state.shop_visit.undo.back().sealed,"auto-use original purchase sealed")
 var state: Dictionary=model.state.duplicate(true)
 quote=model.commerce_quote(WAR)
 check(not quote.accepted and quote.reason=="same_name_elixir_active","same active effect rejects full-slot quote")
 var refused: Dictionary=shop_command(f,"buy",{"item":WAR})
 check(not refused.accepted and model.state==state,"failed full-slot repeat never pays or discards")
 war_note(f,"full six retained");dispose(f);war_done.append(current_group)
func war_lifecycle() -> void:
 current_group="lifecycle"
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 var baseline: Dictionary=f.sim.hero.stats.duplicate(true)
 if not buy(f,WAR):dispose(f);return
 if not check(shop_command(f,"consume",{"uid":war_uid(f)}).accepted,"pending original consume") or not check(f.session.close_panel().accepted,"close original shop") or not enter(f,1):dispose(f);return
 check(model.war_elixir_status().active,"real Session entry activates before first external step")
 near_number(float(f.sim.hero.stats.ad),float(baseline.ad)+35.0,"original derived AD adds35 at entry")
 near_number(float(f.sim.hero.stats.lifesteal),float(baseline.lifesteal)+0.08,"original lifesteal adds8percentagepoints")
 var exact: Dictionary=f.sim.hero.stats.duplicate(true)
 for i in range(3):f.session.ledger.refresh_runtime()
 check(f.sim.hero.stats==exact,"repeated projection never bakes elixir stats")
 check(model.war_elixir_status().effect.battle_id==model.state.shop_visit.battle_id,"pending effect binds exact original battle receipt")
 check(not shop_command(f,"consume",{"uid":-1}).accepted,"combat request with nonexistent uid is rejected; valid stored uid covered separately")
 if not b04_settle_row(f,1):dispose(f);return
 check(model.state.shop_visit.active_elixir.is_empty() and not model.war_elixir_status().active,"actual original victory clears elixir metadata")
 near_number(float(f.sim.hero.stats.ad),float(baseline.ad),"victory projection removes temporary AD")
 near_number(float(f.sim.hero.stats.lifesteal),float(baseline.lifesteal),"victory projection removes temporary lifesteal")
 check(not f.sim.hero.cast_state.has("elixir_war_on_kill"),"victory removes whole temporary kill buff")
 war_note(f,"original victory cleared");dispose(f);war_done.append(current_group)
func war_replacement() -> void:
 current_group="replacement"
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 var baseline: Dictionary=f.sim.hero.stats.duplicate(true)
 for wanted: String in ["elixir:01","elixir:04","elixir:01"]:
  if not buy(f,wanted):dispose(f);return
  var uid: int=-1
  for item: Dictionary in model.state.inventory:
   if item.id==wanted:uid=int(item.uid);break
  var used: Dictionary=shop_command(f,"consume",{"uid":uid})
  if not check(used.accepted,"original different-kind pending replacement "+wanted):dispose(f);return
  check(model.state.shop_visit.active_elixir.item==wanted and str(model.state.shop_visit.active_elixir.battle_id).is_empty(),"one pending effect equals latest consumed kind")
  check(model.war_elixir_status().pending==(wanted=="elixir:01") and model.hunter_elixir_status().pending==(wanted=="elixir:04"),"only one kind pending at a time")
  check(f.sim.hero.stats==baseline and model.state.inventory.is_empty(),"safe replacement grants no stats and consumes actual bottle")
 check(model.state.gold==58000,"650+700+650 original prices debited exactly")
 war_note(f,"two-way original pending replacement");dispose(f);war_done.append(current_group)
func run() -> void:
 g03_reset_evidence()
 if "commerce" in war_groups:war_commerce()
 if "full_slots" in war_groups:war_full_slots()
 if "lifecycle" in war_groups:war_lifecycle()
 if "replacement" in war_groups:war_replacement()
 await process_frame
 check(war_done==war_groups,"all requested finite war groups complete")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"groups":war_done,"records":war_records,"wallet_fixture":true,"source_damage_fixture_for_settlement":true,"natural_play":false,"GUI_verified":false,"Windows_verified":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close()
 quit(0 if report.passed and error==OK else 2)
