extends "res://integration_checks/d03_source_gate.gd"
const D01 := "final:D01"
const ColossusAdapter = preload("res://equipment_colossus_20261010/adapter.gd")
const ColossusPrior = preload("res://equipment_rage_20261010/adapter.gd")
const ColossusFormula = preload("res://equipment_colossus_20261010/passive26.gd")
var d01_group: String="definitions"
var d01_records: Array=[]
func _initialize()->void:
 output_path="user://d01_source_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--d01-group="):d01_group=arg.trim_prefix("--d01-group=")
 if d01_group not in ["definitions","commerce","projection"]:quit(2);return
 run.call_deferred()
func d01_definitions()->void:
 var numeric: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json"))
 var prior: Dictionary=ColossusPrior.build(numeric)
 var added: Dictionary=ColossusAdapter.build(numeric)
 if not check(prior.accepted and added.accepted,"original44 and D01 source definitions accepted"):return
 for id: String in prior.definitions:check(prior.definitions[id]==added.definitions[id],"prior exact definition "+id)
 check(added.definitions.size()==prior.definitions.size()+1,"one new D01 only")
 var d: Dictionary=added.definitions[D01]
 check(d.stats=={"max_hp":500.0,"AD":30.0,"AP":35.0},"three exact original base stats")
 check(d.recipe.full_price==3150 and d.recipe.component_total==2700 and d.recipe.combine_fee==450,"original exact recipe")
 check(d.passive26=={"health_step":100.0,"health_cap":1200.0,"ad_per_step":2.0,"ap_per_step":3.0},"original four passive parameters")
 var selected: Dictionary=ColossusFormula.select_unique([{"id":D01,"uid":1,"count":2}],added.definitions)
 check(selected.equipped and selected.owned_copies==2,"two copies one selected conversion")
 for row: Array in [[0.0,0.0,0.0],[99.0,1.98,2.97],[100.0,2.0,3.0],[590.0,11.8,17.7],[1199.0,23.98,35.97],[1200.0,24.0,36.0],[1400.0,24.0,36.0]]:
  var effect: Dictionary=ColossusFormula.inspect(selected,360.0+float(row[0]),360.0)
  check(effect.active,"valid proportional fixture "+str(row[0]))
  near_number(effect.AD,float(row[1]),"independent AD formula "+str(row[0]));near_number(effect.AP,float(row[2]),"independent AP formula "+str(row[0]))
 for bad: Array in [[NAN,360.0],[INF,360.0],[360.0,0.0],[true,360.0],[360.0,"360"]]:check(not ColossusFormula.inspect(selected,bad[0],bad[1]).active,"nonfinite or malformed HP rejected")
 for inv: Array in [[{"id":D01,"uid":1,"count":0}],[{"id":D01,"uid":true,"count":1}],[{"id":D01,"uid":1,"count":1},{"id":D01,"uid":1,"count":1}]]:check(not ColossusFormula.select_unique(inv,added.definitions).equipped,"invalid inventory no passive")
 var invalid: Dictionary=numeric.duplicate(true);invalid.parameters["passive:26.health_step"].value=0
 check(not ColossusAdapter.build(invalid).accepted,"zero divisor numeric rejected")
 var f: Dictionary=funded_shop("D01 bound definitions")
 if f.is_empty():return
 check(f.session.ledger.model.equipment_runtime_status(D01).get("runtime_complete",false),"actual original stat consumer bound")
 dispose(f)
func d01_commerce()->void:
 var f: Dictionary=funded_shop("D01 commerce")
 if f.is_empty():return
 var m=f.session.ledger.model
 var hp: float=f.sim.hero.hp
 for id: String in ["intermediate:I17","intermediate:I01","base:B06","base:B01","base:B01","base:B01"]:
  if not buy(f,id):dispose(f);return
 var components: Array=m.state.inventory.duplicate(true);var gold: int=m.state.gold
 check(components.size()==6,"full six slots before component craft")
 var crafted: Dictionary=shop_command(f,"craft",{"item":D01})
 if not check(crafted.accepted,"original fullslot craft D01"):dispose(f);return
 check(m.state.gold==gold-450 and owned_count(f,D01)==1 and m.state.inventory.size()==4,"exact450 fee and component replacement")
 for id: String in ["intermediate:I17","intermediate:I01","base:B06"]:check(owned_count(f,id)==0,"consumed "+id)
 near_number(f.sim.hero.hp,hp,"maximumHP purchase/craft does not heal")
 if not undo(f):dispose(f);return
 check(m.state.inventory==components and m.state.gold==gold,"undo exact component UIDs and wallet")
 if not check(shop_command(f,"craft",{"item":D01}).accepted,"recraft accepted"):dispose(f);return
 var before_sale: int=m.state.gold
 if not sell(f,D01):dispose(f);return
 check(m.state.gold==before_sale+2835 and owned_count(f,D01)==0,"90percent3150 invested sale2835")
 if not undo(f):dispose(f);return
 check(m.state.gold==before_sale and owned_count(f,D01)==1,"sale undo restores effect source")
 if not buy(f,"base:B01") or not buy(f,"base:B01"):dispose(f);return
 var before: Dictionary=m.state.duplicate(true)
 check(not shop_command(f,"buy",{"item":"base:B01"}).accepted,"extra unrelated item rejected at fullslots")
 check(m.state==before,"rejection no Model mutation")
 d01_records.append({"kind":"commerce","inventory":m.state.inventory.duplicate(true),"gold":m.state.gold});dispose(f)
func d01_projection()->void:
 var f: Dictionary=funded_shop("D01 projection")
 if f.is_empty():return
 var m=f.session.ledger.model
 var base: Dictionary=f.sim.hero.base_stats.duplicate(true)
 var initial: Dictionary=f.sim.hero.stats.duplicate(true)
 var plain: bool=int(f.sim.hero.ranks.passive)==0
 for id: String in ["g02","g03","g04","g19","g24","g30"]:plain=plain and not f.sim.common.runtime.active(id)
 d01_records.append({"kind":"initial_projection_context","selected_hex":m.state.selected_hex.duplicate(true),"plain_hp_ad_ap":plain})
 if not check(plain,"actual original choices have no dynamic HP AD AP factor or P2"):dispose(f);return
 var hp: float=f.sim.hero.hp
 for copies in range(1,4):
  if not buy(f,D01):dispose(f);return
  var expected_hp: float=500.0*copies
  near_number(f.sim.hero.stats.max_hp,float(initial.max_hp)+expected_hp,"baseHP per legal copy")
  var counted: float=minf(1200.0,float(f.sim.hero.stats.max_hp)-float(base.max_hp))
  near_number(f.sim.hero.stats.ad,float(initial.ad)+30.0*copies+counted*.02,"AD one unique conversion")
  near_number(f.sim.hero.stats.ap,float(initial.ap)+35.0*copies+counted*.03,"AP one unique conversion")
  var once: Dictionary=f.sim.hero.stats.duplicate(true)
  for _i in range(5):f.sim.common.refresh_stats()
  check(f.sim.hero.stats==once and f.sim.common._last_stats==once,"repeat projection never bakes conversion")
  check(f.sim.hero.base_stats==base,"original base preserved")
 near_number(f.sim.hero.hp,hp,"projection never heals")
 for _i in range(3):
  if not sell(f,D01):dispose(f);return
 near_number(f.sim.hero.stats.ad,float(initial.ad),"last source sale removes AD conversion")
 near_number(f.sim.hero.stats.ap,float(initial.ap),"last source sale removes AP conversion")
 d01_records.append({"kind":"projection","base":base,"initial":initial,"final":f.sim.hero.stats.duplicate(true)});dispose(f)
func run()->void:
 g03_reset_evidence()
 if d01_group=="definitions":d01_definitions()
 elif d01_group=="commerce":d01_commerce()
 else:d01_projection()
 await process_frame
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"group":d01_group,"records":d01_records,"wallet_fixture":true,"natural_play":false,"GUI_verified":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close();quit(0 if report.passed and error==OK else 2)
func check_model_successor(f: Dictionary,label: String)->void:
 var script: Script=f.session.ledger.model.get_script()
 for path: String in ["res://equipment_colossus_20261010/model.gd","res://equipment_rage_20261010/model.gd","res://elixir_war_20261009/model.gd","res://elixir_hunter_20261009/model.gd","res://formal_training_20261009/model.gd","res://equipment_regeneration_20261009/model.gd","res://equipment_blood_trial_20261009/model.gd","res://equipment_lifeline_20261009/model.gd","res://equipment_pursuit_20261009/model.gd","res://equipment_training_20261009/model.gd",B04_MODEL,G06_MODEL,B01_MODEL,DISTANCE_MODEL_PATH,POSTBOSS_MODEL_PATH,POSTBOSS_PRIOR_MODEL_PATH,POSTBOSS_BASE_MODEL_PATH]:
  if not check(script!=null and script.resource_path==path,label+": exact ancestor "+path):return
  script=script.get_base_script()
 check(FileAccess.get_sha256(POSTBOSS_BASE_MODEL_PATH)==POSTBOSS_BASE_MODEL_SHA,label+": original Model retained")
