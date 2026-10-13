extends "res://integration_checks/d01_source_gate.gd"
const C03 := "final:C03"
const OverloadAdapter = preload("res://equipment_overload_20261010/adapter.gd")
const OverloadPrior = preload("res://equipment_colossus_20261010/adapter.gd")
const OverloadFormula = preload("res://equipment_overload_20261010/passive11.gd")
var c03_group: String = "definitions"
var c03_records: Array = []
var c03_completed: Array = []
func _initialize() -> void:
 output_path="user://c03_source_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="): output_path=arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--c03-group="): c03_group=arg.trim_prefix("--c03-group=")
 if c03_group not in ["definitions","commerce","arithmetic"]: quit(2);return
 run.call_deferred()
func c03_definitions() -> void:
 var numeric: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json"))
 var prior: Dictionary=OverloadPrior.build(numeric)
 var added: Dictionary=OverloadAdapter.build(numeric)
 if not check(prior.accepted and added.accepted,"prior45 and C03 formal adapter accepted"):return
 for id: String in prior.definitions:check(prior.definitions[id]==added.definitions[id],"prior exact definition "+id)
 check(added.definitions.size()==prior.definitions.size()+1,"one new C03 only")
 var d: Dictionary=added.definitions[C03]
 check(d.stats.size()==2,"closed two base stats")
 near_number(d.stats.AP,90.0,"original AP90");near_number(d.stats.cooldown_reduction,.25,"original CDR25percent")
 check(d.recipe.full_price==3200 and d.recipe.component_total==2800 and d.recipe.combine_fee==400,"formal recipe3200 with400 combination")
 check(d.passive11.size()==4,"closed four passive parameters")
 for key: String in {"ap_per_stack":10.0,"ms_per_stack":2.0,"duration":4.0,"max_stacks":6.0}:
  near_number(d.passive11[key],{"ap_per_stack":10.0,"ms_per_stack":2.0,"duration":4.0,"max_stacks":6.0}[key],"formal passive "+key)
 var f: Dictionary=funded_shop("C03 definitions actual bound")
 if f.is_empty():return
 check(f.session.ledger.model.equipment_runtime_status(C03).get("runtime_complete",false),"new original release consumer bound")
 check(f.session.ledger.model.equipment_runtime_status(D01).get("runtime_complete",false),"D01 exact successor remains bound")
 var changed: Dictionary=numeric.duplicate(true);changed.parameters["passive:11.duration"].value=0
 check(not OverloadAdapter.build(changed).accepted,"zero duration rejected")
 changed=numeric.duplicate(true);changed.parameters["passive:11.max_stacks"].value=6.5
 check(not OverloadAdapter.build(changed).accepted,"fractional stack maximum rejected")
 c03_completed.append("definitions");dispose(f)
func c03_commerce() -> void:
 var f: Dictionary=funded_shop("C03 commerce")
 if f.is_empty():return
 var m=f.session.ledger.model
 var hp: float=f.sim.hero.hp
 for id: String in ["intermediate:I05","intermediate:I02","base:B05","base:B01","base:B01","base:B01"]:
  if not buy(f,id):dispose(f);return
 var original: Array=m.state.inventory.duplicate(true);var gold: int=m.state.gold
 check(original.size()==6,"six real slots before craft")
 if not check(shop_command(f,"craft",{"item":C03}).accepted,"original fullslot craft"):dispose(f);return
 check(m.state.gold==gold-400 and owned_count(f,C03)==1 and m.state.inventory.size()==4,"only400 charged and three components replaced")
 for id: String in ["intermediate:I05","intermediate:I02","base:B05"]:check(owned_count(f,id)==0,"component consumed "+id)
 near_number(f.sim.hero.hp,hp,"craft does not heal")
 if not undo(f):dispose(f);return
 check(m.state.inventory==original and m.state.gold==gold,"undo original component UIDs and exact400")
 if not check(shop_command(f,"craft",{"item":C03}).accepted,"recraft"):dispose(f);return
 var before_sale: int=m.state.gold
 if not sell(f,C03):dispose(f);return
 check(m.state.gold==before_sale+2880 and owned_count(f,C03)==0,"original90percent sale2880")
 if not undo(f):dispose(f);return
 check(m.state.gold==before_sale and owned_count(f,C03)==1,"sale undo restores original item")
 if not buy(f,C03):dispose(f);return
 var selected: Dictionary=OverloadFormula.select_unique(m.state.inventory,m.runtime_stat_definitions)
 check(selected.equipped and selected.owned_copies==2,"two legal C03 copies one passive selection")
 c03_records.append({"kind":"commerce","gold":m.state.gold,"inventory":m.state.inventory.duplicate(true)})
 c03_completed.append("commerce");dispose(f)
func c03_arithmetic() -> void:
 var selected: Dictionary={"equipped":true,"owned_copies":2,"tuning":{"ap_per_stack":10.0,"ms_per_stack":2.0,"duration":4.0,"max_stacks":6.0}}
 var scope: Dictionary={"run_id":"isolated arithmetic","generation":1,"room_id":"r01","combat_level_id":"c1","hero":"one","runtime":"one"}
 var buff: Dictionary={}
 for count in range(1,8):
  var now: float=count*.25
  buff=OverloadFormula.propose(selected,buff,scope,now)
  var effect: Dictionary=OverloadFormula.inspect(selected,buff,scope,now)
  check(effect.active and effect.stacks==mini(count,6),"one effect stacks capped6 "+str(count))
  near_number(effect.AP,10.0*mini(count,6),"independent AP "+str(count))
  near_number(effect.move_fraction,.02*mini(count,6),"independent MS "+str(count))
  near_number(buff.expires_at,now+4.0,"all stack duration refresh "+str(count))
 var before: Dictionary=buff.duplicate(true)
 for _i in range(4):check(OverloadFormula.inspect(selected,buff,scope,1.75).stacks==6,"read projection stable")
 check(buff==before,"read projection no mutation")
 check(OverloadFormula.inspect(selected,buff,scope,5.749).active,"before4seconds active")
 check(not OverloadFormula.inspect(selected,buff,scope,5.75).active,"exact4seconds expired")
 check(OverloadFormula.propose(selected,buff,scope,5.75).stacks==1,"expired stack restarts at1")
 var wrong: Dictionary=scope.duplicate(true);wrong.generation=2
 check(not OverloadFormula.inspect(selected,buff,wrong,2.0).active,"other generation denied")
 check(not OverloadFormula.inspect({"equipped":false},buff,scope,2.0).active,"no source no effect")
 for bad: Variant in [NAN,INF,-1.0]:check(OverloadFormula.propose(selected,buff,scope,float(bad)).is_empty(),"invalid clock rejected")
 c03_completed.append("arithmetic")
func run() -> void:
 g03_reset_evidence()
 if c03_group=="definitions":c03_definitions()
 elif c03_group=="commerce":c03_commerce()
 else:c03_arithmetic()
 check(c03_completed==[c03_group],"requested complete group reached")
 await process_frame
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"group":c03_group,"completed":c03_completed,"records":c03_records,"wallet_fixture":c03_group!="arithmetic","pure_arithmetic":c03_group=="arithmetic","real_release_verified":false,"natural_play":false,"GUI_verified":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close();quit(0 if report.passed and error==OK else 2)
func check_model_successor(f: Dictionary,label: String)->void:
 var script: Script=f.session.ledger.model.get_script()
 for path: String in ["res://equipment_overload_20261010/model.gd","res://equipment_colossus_20261010/model.gd","res://equipment_rage_20261010/model.gd","res://elixir_war_20261009/model.gd","res://elixir_hunter_20261009/model.gd","res://formal_training_20261009/model.gd","res://equipment_regeneration_20261009/model.gd","res://equipment_blood_trial_20261009/model.gd","res://equipment_lifeline_20261009/model.gd","res://equipment_pursuit_20261009/model.gd","res://equipment_training_20261009/model.gd",B04_MODEL,G06_MODEL,B01_MODEL,DISTANCE_MODEL_PATH,POSTBOSS_MODEL_PATH,POSTBOSS_PRIOR_MODEL_PATH,POSTBOSS_BASE_MODEL_PATH]:
  if not check(script!=null and script.resource_path==path,label+": exact ancestor "+path):return
  script=script.get_base_script()
 check(FileAccess.get_sha256(POSTBOSS_BASE_MODEL_PATH)==POSTBOSS_BASE_MODEL_SHA,label+": original Model retained")
