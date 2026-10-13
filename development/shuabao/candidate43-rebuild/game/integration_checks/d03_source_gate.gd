extends "res://integration_checks/war_elixir_source_gate.gd"
const D03 := "final:D03"
const D03Adapter = preload("res://equipment_rage_20261010/adapter.gd")
const D03Prior = preload("res://equipment_regeneration_20261009/adapter.gd")
var d03_group: String = "definitions"
var d03_records: Array = []
func _initialize() -> void:
 output_path="user://d03_source_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="): output_path=arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--d03-group="): d03_group=arg.trim_prefix("--d03-group=")
 if d03_group not in ["definitions","commerce","unique"]: push_error("Unknown D03 group");quit(2);return
 run.call_deferred()

func d03_note(f: Dictionary,label: String) -> void:
 var m=f.session.ledger.model
 d03_records.append({"label":label,"inventory":m.state.inventory.duplicate(true),"gold":m.state.gold,"equipment":m.equipment_effects().duplicate(true),"stats":f.sim.hero.stats.duplicate(true),"regen":m.regeneration_status().duplicate(true)})

func d03_definitions() -> void:
 var numeric: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json"))
 var old: Dictionary=D03Prior.build(numeric)
 var current: Dictionary=D03Adapter.build(numeric)
 if not check(old.accepted and current.accepted,"both original43 and D03 successor source adapters accepted"):return
 for id: String in old.definitions:check(current.definitions[id]==old.definitions[id],"old definition exact "+id)
 check(current.definitions.size()==old.definitions.size()+1,"exactly one new definition")
 var d: Dictionary=current.definitions[D03]
 check(d.stats=={"max_hp":420.0,"AD":20.0,"cooldown_reduction":0.12,"lifesteal":0.06},"D03 original four stats")
 check(d.recipe.full_price==3200 and d.recipe.component_total==2800 and d.recipe.combine_fee==400,"original D03 recipe prices")
 check(d.distance_passive==old.definitions["final:B03"].distance_passive and d.passive24==old.definitions["final:E03"].passive24,"same named tuning reused exactly")
 var f: Dictionary=funded_shop("D03 definitions")
 if f.is_empty():return
 check(f.session.ledger.model.equipment_runtime_status(D03).get("runtime_complete",false),"D03 actual original consumers bound")
 d03_note(f,"bound definition");dispose(f)

func d03_commerce() -> void:
 var f: Dictionary=funded_shop("D03 commerce")
 if f.is_empty():return
 var m=f.session.ledger.model
 var hp: float=f.sim.hero.hp
 for id: String in ["intermediate:I07","intermediate:I13","base:B09","base:B01","base:B01","base:B01"]:
  if not buy(f,id):dispose(f);return
 var components: Array=m.state.inventory.duplicate(true)
 var gold: int=m.state.gold
 check(components.size()==6,"six actual slots before valid component synthesis")
 var crafted: Dictionary=shop_command(f,"craft",{"item":D03})
 if not check(crafted.get("accepted",false),"original six-slot D03 component craft accepted"):dispose(f);return
 check(m.state.gold==gold-400 and owned_count(f,D03)==1 and m.state.inventory.size()==4,"three components replaced with one; exact400 fee")
 for id: String in ["intermediate:I07","intermediate:I13","base:B09"]:check(owned_count(f,id)==0,"consumed original component "+id)
 near_number(f.sim.hero.hp,hp,"synthesis maxHP increase does not heal")
 if not undo(f):dispose(f);return
 check(m.state.inventory==components and m.state.gold==gold,"craft undo restores exact component UIDs and gold")
 if not check(shop_command(f,"craft",{"item":D03}).accepted,"recraft valid after undo"):dispose(f);return
 var before_sale: int=m.state.gold
 if not sell(f,D03):dispose(f);return
 check(m.state.gold==before_sale+2880 and owned_count(f,D03)==0,"original90percent actual3200 investment sale")
 if not undo(f):dispose(f);return
 check(m.state.gold==before_sale and owned_count(f,D03)==1,"sale undo restores current D03 selection")
 if not buy(f,"base:B01") or not buy(f,"base:B01"):dispose(f);return
 var before: Dictionary=m.state.duplicate(true)
 var rejected: Dictionary=shop_command(f,"buy",{"item":"base:B01"})
 check(not rejected.accepted,"six actual slots reject unrelated extra item")
 check(m.state==before,"rejected full-slot purchase leaves Model state unchanged")
 d03_note(f,"craft sell undo full slots");dispose(f)

func d03_unique() -> void:
 var f: Dictionary=funded_shop("D03 unique")
 if f.is_empty():return
 var m=f.session.ledger.model
 var baseline: Dictionary=m.equipment_effects().stats.duplicate(true)
 for id: String in [D03,D03,"final:B03","final:E03"]:
  if not buy(f,id):dispose(f);return
 var stats: Dictionary=m.equipment_effects().stats
 near_number(float(stats.get("lifesteal",0.0))-float(baseline.get("lifesteal",0.0)),0.17,"two D03 .12 base plus one shared .05")
 near_number(float(stats.get("max_hp",0.0))-float(baseline.get("max_hp",0.0)),1580.0,"two D03 plus B03 and E03 baseHP per copy")
 near_number(m.distance_equipment_multiplier(Vector3.ZERO,{"position":Vector3(4.5,0,0)}),1.12,"named distance factor once at inclusive4.5")
 near_number(m.distance_equipment_multiplier(Vector3.ZERO,{"position":Vector3(4.5001,0,0)}),1.0,"distance condition only damage")
 check(m.regeneration_status().owned_copies==3,"two D03 and one E03 select same single regen tuning")
 if not sell(f,D03) or not sell(f,D03):dispose(f);return
 stats=m.equipment_effects().stats
 near_number(float(stats.get("lifesteal",0.0))-float(baseline.get("lifesteal",0.0)),0.05,"B03 retains unique constant after last D03 sold")
 check(m.regeneration_status().owned_copies==1,"E03 retains regen after last D03 sold")
 if not sell(f,"final:B03") or not sell(f,"final:E03"):dispose(f);return
 near_number(float(m.equipment_effects().stats.get("lifesteal",0.0)),float(baseline.get("lifesteal",0.0)),"last named source removes constant")
 check(not m.regeneration_status().equipped,"last regen source removes selection")
 d03_note(f,"unique sources removed");dispose(f)

func run() -> void:
 g03_reset_evidence()
 if d03_group=="definitions":d03_definitions()
 elif d03_group=="commerce":d03_commerce()
 elif d03_group=="unique":d03_unique()
 await process_frame
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"group":d03_group,"records":d03_records,"wallet_fixture":true,"natural_play":false,"GUI_verified":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close()
 quit(0 if report.passed and error==OK else 2)
func check_model_successor(f: Dictionary,label: String) -> void:
 var script: Script=f.session.ledger.model.get_script()
 for path: String in ["res://equipment_rage_20261010/model.gd","res://elixir_war_20261009/model.gd","res://elixir_hunter_20261009/model.gd","res://formal_training_20261009/model.gd","res://equipment_regeneration_20261009/model.gd","res://equipment_blood_trial_20261009/model.gd","res://equipment_lifeline_20261009/model.gd","res://equipment_pursuit_20261009/model.gd","res://equipment_training_20261009/model.gd",B04_MODEL,G06_MODEL,B01_MODEL,DISTANCE_MODEL_PATH,POSTBOSS_MODEL_PATH,POSTBOSS_PRIOR_MODEL_PATH,POSTBOSS_BASE_MODEL_PATH]:
  if not check(script!=null and script.resource_path==path,label+": exact model ancestor "+path):return
  script=script.get_base_script()
 check(FileAccess.get_sha256(POSTBOSS_BASE_MODEL_PATH)==POSTBOSS_BASE_MODEL_SHA,label+": original Model retained")
