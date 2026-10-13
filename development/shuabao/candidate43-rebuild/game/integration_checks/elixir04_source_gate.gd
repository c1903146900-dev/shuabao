extends "res://integration_checks/training12_source_gate.gd"
## Original Host/Session economy fixture. No production state injection except
## declared60000 test wallet. Lifecycle settlement uses inherited source damage.
const HUNTER := "elixir:04"
const HUNTER_GROUPS := ["commerce","full_slots","lifecycle"]
var hunter_groups: Array = HUNTER_GROUPS.duplicate()
var hunter_done: Array = []
var hunter_records: Array = []
func _initialize() -> void:
 output_path="user://hunter_elixir04.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
  if arg.begins_with("--elixir-group="):
   var part: String=arg.trim_prefix("--elixir-group=")
   if part not in HUNTER_GROUPS:push_error("Unknown hunter group");quit(2);return
   hunter_groups=[part]
 run.call_deferred()
func check_model_successor(f: Dictionary,label: String) -> void:
 var script: Script=f.session.ledger.model.get_script()
 for path: String in ["res://elixir_hunter_20261009/model.gd","res://formal_training_20261009/model.gd","res://equipment_regeneration_20261009/model.gd","res://equipment_blood_trial_20261009/model.gd","res://equipment_lifeline_20261009/model.gd","res://equipment_pursuit_20261009/model.gd","res://equipment_training_20261009/model.gd",B04_MODEL,G06_MODEL,B01_MODEL,DISTANCE_MODEL_PATH,POSTBOSS_MODEL_PATH,POSTBOSS_PRIOR_MODEL_PATH,POSTBOSS_BASE_MODEL_PATH]:
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
 if not check(model.equipment_runtime_status(HUNTER).supported,"hunter actual source consumer bound") or not check(f.session.open_panel().accepted,"original safe shop opened"):
  dispose(f);return {}
 return f
func hunter_uid(f: Dictionary) -> int:
 for item: Dictionary in f.session.ledger.model.state.inventory:
  if item.id==HUNTER:return int(item.uid)
 return -1
func hunter_note(f: Dictionary,label: String) -> void:
 hunter_records.append({"label":label,"status":f.session.ledger.model.hunter_elixir_status(),"inventory":f.session.ledger.model.state.inventory.duplicate(true),"gold":f.session.ledger.model.state.gold,"stats":f.sim.hero.stats.duplicate(true),"visit":f.session.ledger.model.state.shop_visit.duplicate(true)})
func hunter_commerce() -> void:
 current_group="commerce"
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 var before: Dictionary=f.sim.hero.stats.duplicate(true)
 if not buy(f,HUNTER):dispose(f);return
 check(model.state.gold==59300 and model.state.inventory.size()==1,"original700 price and one stored slot")
 check(f.sim.hero.stats==before and not model.hunter_elixir_status().active,"stored bottle grants no stats")
 check(undo(f) and model.state.gold==60000 and model.state.inventory.is_empty(),"unused original purchase reversible")
 if not buy(f,HUNTER):dispose(f);return
 serial+=1
 var command_id: String="hunter-consume-"+str(serial)
 var args: Dictionary=model.commerce_token();args.uid=hunter_uid(f)
 var used: Dictionary=f.session.submit(command_id,"consume",args)
 f.session.update_after_source_step()
 check(used.accepted and model.state.inventory.is_empty(),"original safe consumption removes real uid")
 check(model.hunter_elixir_status().pending and not model.hunter_elixir_status().active and f.sim.hero.stats==before,"pending effect has no safe stats")
 check(model.state.shop_visit.undo.back().sealed,"original consumed lineage sealed")
 var state: Dictionary=model.state.duplicate(true)
 var repeated: Dictionary=f.session.submit(command_id,"consume",args)
 check(repeated.accepted and repeated.get("replayed",false) and model.state==state,"same original command replays without spending or effect duplication")
 var conflict: Dictionary=args.duplicate(true);conflict.uid+=1
 check(not f.session.submit(command_id,"consume",conflict).accepted and model.state==state,"same command different uid rejected without mutation")
 if not buy(f,HUNTER):dispose(f);return
 check(model.state.inventory.size()==1,"same name pending still permits one legally stored bottle")
 state=model.state.duplicate(true)
 var refused: Dictionary=shop_command(f,"consume",{"uid":hunter_uid(f)})
 check(not refused.accepted and refused.reason=="same_name_elixir_active" and model.state==state,"same-name repeated drink refuses without dropping or spending")
 for id: String in ["elixir:01","elixir:02","elixir:03","elixir:05"]:check(not model.commerce_quote(id).accepted,"other elixir remains held "+id)
 hunter_note(f,"stored plus pending same-name");dispose(f);hunter_done.append(current_group)
func hunter_full_slots() -> void:
 current_group="full_slots"
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 for i in range(6):
  if not buy(f,"base:B01"):dispose(f);return
 var inventory: Array=model.state.inventory.duplicate(true)
 var gold: int=model.state.gold
 var quote: Dictionary=model.commerce_quote(HUNTER)
 check(quote.accepted and quote.get("auto_drink",false),"full six original slots quote automatic drink")
 if not buy(f,HUNTER):dispose(f);return
 check(model.state.inventory==inventory and model.state.gold==gold-700 and model.hunter_elixir_status().pending,"full slots consume immediately without seventh item")
 check(model.state.shop_visit.undo.back().sealed,"auto-use original purchase sealed")
 var state: Dictionary=model.state.duplicate(true)
 quote=model.commerce_quote(HUNTER)
 check(not quote.accepted and quote.reason=="same_name_elixir_active","same active effect rejects full-slot quote")
 var refused: Dictionary=shop_command(f,"buy",{"item":HUNTER})
 check(not refused.accepted and model.state==state,"failed full-slot repeat never pays or discards")
 hunter_note(f,"full six retained");dispose(f);hunter_done.append(current_group)
func hunter_lifecycle() -> void:
 current_group="lifecycle"
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 var baseline: Dictionary=f.sim.hero.stats.duplicate(true)
 if not buy(f,HUNTER):dispose(f);return
 if not check(shop_command(f,"consume",{"uid":hunter_uid(f)}).accepted,"pending original consume") or not check(f.session.close_panel().accepted,"close original shop") or not enter(f,1):dispose(f);return
 check(model.hunter_elixir_status().active,"real Session entry activates before first external step")
 near_number(float(f.sim.hero.stats.penetration),float(baseline.penetration)+20.0,"original derived penetration adds20 at entry")
 near_number(float(f.sim.hero.stats.crit_chance),minf(1.0,float(baseline.crit_chance)+0.15),"original critical chance adds15percentagepoints")
 var exact: Dictionary=f.sim.hero.stats.duplicate(true)
 for i in range(3):f.session.ledger.refresh_runtime()
 check(f.sim.hero.stats==exact,"repeated projection never bakes elixir stats")
 check(model.hunter_elixir_status().effect.battle_id==model.state.shop_visit.battle_id,"pending effect binds exact original battle receipt")
 check(not shop_command(f,"consume",{"uid":-1}).accepted,"combat request with nonexistent uid is rejected; valid stored uid covered separately")
 if not b04_settle_row(f,1):dispose(f);return
 check(model.state.shop_visit.active_elixir.is_empty() and not model.hunter_elixir_status().active,"actual original victory clears elixir metadata")
 near_number(float(f.sim.hero.stats.penetration),float(baseline.penetration),"victory projection removes temporary penetration")
 near_number(float(f.sim.hero.stats.crit_chance),float(baseline.crit_chance),"victory projection removes temporary critical chance")
 hunter_note(f,"original victory cleared");dispose(f);hunter_done.append(current_group)
func run() -> void:
 g03_reset_evidence()
 if "commerce" in hunter_groups:hunter_commerce()
 if "full_slots" in hunter_groups:hunter_full_slots()
 if "lifecycle" in hunter_groups:hunter_lifecycle()
 await process_frame
 check(hunter_done==hunter_groups,"all requested finite hunter groups complete")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"groups":hunter_done,"records":hunter_records,"wallet_fixture":true,"source_damage_fixture_for_settlement":true,"natural_play":false,"GUI_verified":false,"Windows_verified":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close()
 quit(0 if report.passed and error==OK else 2)
