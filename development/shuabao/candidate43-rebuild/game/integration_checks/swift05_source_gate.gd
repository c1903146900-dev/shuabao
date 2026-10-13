extends "res://integration_checks/c03_source_gate.gd"
const SWIFT := "elixir:05"
var swift_group: String="definitions"
var swift_completed: Array=[]
var swift_records: Array=[]
func _initialize()->void:
 output_path="user://swift_source.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--swift-group="):swift_group=arg.trim_prefix("--swift-group=")
 if swift_group not in ["definitions","commerce","full_slots","replacement"]:quit(2);return
 run.call_deferred()
func swift_uid(f: Dictionary)->int:
 for item: Dictionary in f.session.ledger.model.state.inventory:
  if item.id==SWIFT:return int(item.uid)
 return -1
func swift_note(f: Dictionary,label: String)->void:
 swift_records.append({"label":label,"status":f.session.ledger.model.swift_elixir_status(),"gold":f.session.ledger.model.state.gold,"inventory":f.session.ledger.model.state.inventory.duplicate(true),"hero":f.sim.hero.snapshot().duplicate(true)})
func swift_definitions()->void:
 var f: Dictionary=funded_shop("Swift formal definition")
 if f.is_empty():return
 var model=f.session.ledger.model
 var status: Dictionary=model.swift_elixir_status()
 check(status.supported and not status.active and not status.pending,"exact fresh Swift consumer bound and inactive")
 check(status.tuning.size()==6,"closed six original parameters")
 for key: String in {"price":650.0,"move":15.0,"attack_speed":15.0,"cdr":8.0,"after_shift_move":15.0,"after_shift_duration":1.5}:
  near_number(status.tuning.get(key,-1),{"price":650.0,"move":15.0,"attack_speed":15.0,"cdr":8.0,"after_shift_move":15.0,"after_shift_duration":1.5}[key],"original formal05 "+key)
 for id: String in ["elixir:01","elixir:04",SWIFT,C03,D01]:check(model.equipment_runtime_status(id).supported,"existing exact consumer preserved "+id)
 for id: String in ["elixir:02","elixir:03"]:check(not model.equipment_runtime_status(id).supported,"unimplemented elixir remains held "+id)
 swift_note(f,"formal definition");swift_completed.append("definitions");dispose(f)
func swift_commerce()->void:
 var f: Dictionary=funded_shop("Swift storage and use")
 if f.is_empty():return
 var model=f.session.ledger.model
 var before: Dictionary=f.sim.hero.snapshot().duplicate(true)
 var gold: int=model.state.gold
 if not buy(f,SWIFT):dispose(f);return
 check(model.state.gold==gold-650 and swift_uid(f)>=0,"stored original bottle costs650")
 check(f.sim.hero.snapshot()==before and not model.swift_elixir_status().active and not model.swift_elixir_status().pending,"stored bottle has no stats or battle effect")
 if not check(shop_command(f,"consume",{"uid":swift_uid(f)}).get("accepted",false),"original Session consumes real Swift UID"):dispose(f);return
 var pending: Dictionary=model.state.shop_visit.active_elixir.duplicate(true)
 check(model.swift_elixir_status().pending and not model.swift_elixir_status().active and swift_uid(f)<0,"consumption creates only next-battle pending effect")
 check(f.sim.hero.snapshot()==before,"pending effect gives no safe-phase stat or HP benefit")
 check(not shop_command(f,"undo",{}).get("accepted",false),"consumed bottle transaction cannot undo")
 if not buy(f,SWIFT):dispose(f);return
 check(model.state.shop_visit.active_elixir==pending and swift_uid(f)>=0,"same-name bottle may be stored without refreshing effect")
 var denied: Dictionary=shop_command(f,"consume",{"uid":swift_uid(f)})
 check(not denied.get("accepted",false) and str(denied.get("reason","")).contains("same_name"),"same-name pending effect cannot drink again")
 check(model.state.shop_visit.active_elixir==pending,"failed repeated drink leaves pending effect exact")
 swift_note(f,"stored pending and rejected same-name drink");swift_completed.append("commerce");dispose(f)
func swift_full_slots()->void:
 var f: Dictionary=funded_shop("Swift full six slots")
 if f.is_empty():return
 var model=f.session.ledger.model
 for _i in range(6):
  if not buy(f,"base:B01"):dispose(f);return
 var before: Array=model.state.inventory.duplicate(true)
 var gold: int=model.state.gold
 var quoted: Dictionary=model.commerce_quote(SWIFT)
 if not check(quoted.get("accepted",false) and quoted.get("auto_drink",false),"original full inventory quotes automatic drink"):dispose(f);return
 if not buy(f,SWIFT):dispose(f);return
 check(model.state.gold==gold-650 and model.state.inventory==before and model.swift_elixir_status().pending,"full-slot purchase consumes without extra equipment slot")
 check(not model.swift_elixir_status().active,"full-slot safe auto drink still pending only")
 swift_note(f,"original full-slot automatic drink");swift_completed.append("full_slots");dispose(f)
func swift_replacement()->void:
 var f: Dictionary=funded_shop("Swift original different-kind replacement")
 if f.is_empty():return
 var model=f.session.ledger.model
 for id: String in [SWIFT,"elixir:01",SWIFT,"elixir:04"]:
  if not buy(f,id):dispose(f);return
  var uid: int=-1
  for item: Dictionary in model.state.inventory:
   if item.id==id:uid=int(item.uid);break
  if not check(uid>=0,"real replacement bottle stored "+id) or not check(shop_command(f,"consume",{"uid":uid}).get("accepted",false),"original different-kind consumption "+id):dispose(f);return
  check(model.state.shop_visit.active_elixir.item==id and str(model.state.shop_visit.active_elixir.get("battle_id","")).is_empty(),"one original pending kind replaces previous "+id)
  swift_note(f,"replacement "+id)
 swift_completed.append("replacement");dispose(f)
func run()->void:
 g03_reset_evidence()
 if swift_group=="definitions":swift_definitions()
 elif swift_group=="commerce":swift_commerce()
 elif swift_group=="full_slots":swift_full_slots()
 else:swift_replacement()
 check(swift_completed==[swift_group],"entire requested Swift source group completed")
 await process_frame
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"group":swift_group,"completed":swift_completed,"records":swift_records,"wallet_fixture":60000,"natural_play":false,"real_shift_verified":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var f: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if f==null:quit(2);return
 f.store_string(JSON.stringify(report,"  "));var error: Error=f.get_error();f.close();quit(0 if report.passed and error==OK else 2)
func check_model_successor(f: Dictionary,label: String)->void:
 var script: Script=f.session.ledger.model.get_script()
 for path: String in ["res://elixir_swift_20261010/model.gd","res://equipment_overload_20261010/model.gd","res://equipment_colossus_20261010/model.gd","res://equipment_rage_20261010/model.gd","res://elixir_war_20261009/model.gd","res://elixir_hunter_20261009/model.gd","res://formal_training_20261009/model.gd","res://equipment_regeneration_20261009/model.gd","res://equipment_blood_trial_20261009/model.gd","res://equipment_lifeline_20261009/model.gd","res://equipment_pursuit_20261009/model.gd","res://equipment_training_20261009/model.gd",B04_MODEL,G06_MODEL,B01_MODEL,DISTANCE_MODEL_PATH,POSTBOSS_MODEL_PATH,POSTBOSS_PRIOR_MODEL_PATH,POSTBOSS_BASE_MODEL_PATH]:
  if not check(script!=null and script.resource_path==path,label+": exact ancestor "+path):return
  script=script.get_base_script()
 check(FileAccess.get_sha256(POSTBOSS_BASE_MODEL_PATH)==POSTBOSS_BASE_MODEL_SHA,label+": original Model retained")
