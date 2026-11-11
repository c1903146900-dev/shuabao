extends RefCounted
## One real fresh Fengli Session; no engine launched by this file's author.
## run("baseline") observes the known gap; run("candidate") requires its filter.
## Fixture-only: reset this isolated model's unselected state/RNG between draws,
## and inject a stale offer to test the existing select/support gate. No funding,
## task completions, equipment or combat results are fabricated. Production RNG
## and persisted runtime files are never changed. Four cards = 3 mixed + 1 hero.
var checks:Array=[]
var failures:Array=[]
var observations:Array=[]
var serial:int=0
const TARGETS=["common_g17","common_g21"]
const FIXTURE_SEEDS=[48,12,1,7]

func check(label:String,ok:bool,detail:Variant=null)->void:
 var row:Dictionary={"check":label,"passed":ok,"detail":detail}
 checks.append(row)
 if not ok:failures.append(row)

func command(model:RefCounted,action:String,args:Dictionary)->Dictionary:
 serial+=1
 return model.command("equipment-hex-probe-"+str(serial),action,args)

func valid_offer(model:RefCounted,offer:Dictionary)->bool:
 var slots:Array=offer.get("slots",[])
 if slots.size()!=4:return false
 var unique:Dictionary={}
 for id in slots:
  if str(id).is_empty() or not model.config.hexes.has(id):return false
  unique[model.config.hexes[id].effect_key]=true
 return unique.size()==4 and model.config.hexes[slots[3]].hero=="fengli"

func run(expectation:String="candidate")->Dictionary:
 checks.clear();failures.clear();observations.clear();serial=0
 var candidate:bool=expectation=="candidate"
 check("explicit_baseline_or_candidate_mode",expectation in ["baseline","candidate"],expectation)
 var sim=load("res://fengli_route_20261024/sim.gd").new()
 var session=load("res://fengli_route_20261024/session.gd").new()
 var path:String="res://__clean_fengli/machine_templates.bin"
 var configured:Dictionary=session.configure_reward_table(path,path,path,true)
 check("real_reward_configuration",configured.get("accepted",false),configured.get("reason",""))
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(session.DEFAULT_DEFINITION))
 var initialized:Dictionary=session.initialize_floor(sim,route,"focused-equipment-hex",true)
 check("real_fresh_Session_bindings",initialized.get("accepted",false),initialized.get("reason",""))
 if initialized.get("accepted",false):
  var model:RefCounted=session.ledger.model
  var pristine:Dictionary=model.state.duplicate(true)
  var pool:Array=model._eligible_hexes(false,[])
  var support_view:Dictionary={}
  check("no_Hex_selected_before_probe",model.state.selected_hex.is_empty() and model.state.offers.is_empty())
  check("bound_task_table_is_empty",model.config.equipment_tasks.is_empty())
  var supported_finals:Array=[]
  for id in model.commerce_definitions.items:
   if str(id).begins_with("final:") and model.equipment_runtime_status(id).supported:supported_finals.append(id)
  check("no_buyable_final_equipment",supported_finals.is_empty(),supported_finals)
  for id in TARGETS:
   support_view[id]=model.support(model.config.hexes[id])
   check(id+"_support_matches_mode",bool(support_view[id].supported)!=candidate,support_view[id])
   check(id+"_pool_matches_mode",(id in pool)!=candidate)
  check("legitimate_advance_choices_remain",("common_g27" in pool) and ("fengli_h19" in pool) and model.state.gold==0 and model.state.inventory.is_empty())
  var ready:Dictionary=model.initial_pool_readiness()
  check("initial_refresh_capacity_ready",ready.accepted,ready)
  var opened:Dictionary=command(model,"hex_open",{"milestone":1})
  var initial:Dictionary=model.state.offers.get("1",{}).duplicate(true)
  check("real_production_seed_initial_four_cards",opened.accepted and valid_offer(model,initial),initial)
  observations.append({"case":"real_initial_state_before_selection","seed":pristine.rng,"pool":pool,"support":support_view,"offer":initial})
  var seen_targets:Dictionary={}
  for seed in FIXTURE_SEEDS:
   model.state=pristine.duplicate(true)
   model.state.rng=seed # Explicit isolated draw fixture, never a production seed.
   var draw:Dictionary=command(model,"hex_open",{"milestone":1})
   var first:Dictionary=model.state.offers.get("1",{}).duplicate(true)
   check("seed_"+str(seed)+"_initial_four_distinct",draw.accepted and valid_offer(model,first),first)
   if not draw.accepted:continue
   var trace:Array=[first.slots.duplicate()]
   for id in first.slots:
    if id in TARGETS:seen_targets[id]=true
   for slot in [0,1,2,3]:
    var refresh:Dictionary=command(model,"hex_refresh",{"milestone":1,"slot":slot})
    var offer:Dictionary=model.state.offers["1"]
    check("seed_"+str(seed)+"_refresh_"+str(slot),refresh.accepted and valid_offer(model,offer),refresh.reason)
    trace.append(offer.slots.duplicate())
    for id in offer.slots:
     if id in TARGETS:seen_targets[id]=true
   var before_repeat:Dictionary=model.state.duplicate(true)
   var exhausted:Dictionary=command(model,"hex_refresh",{"milestone":1,"slot":0})
   check("seed_"+str(seed)+"_refresh_once_only",not exhausted.accepted and exhausted.reason=="refresh_exhausted" and model.state==before_repeat,exhausted.reason)
   var selected:Dictionary=command(model,"hex_select",{"milestone":1,"slot":0})
   check("seed_"+str(seed)+"_normal_selection",selected.accepted and model.state.selected_hex.size()==1,selected.reason)
   observations.append({"case":"isolated_fixture_seed","seed":seed,"offer_and_four_refreshes":trace,"selected":model.state.selected_hex.duplicate()})
  for id in TARGETS:check(id+"_real_draw_matches_mode",seen_targets.has(id)!=candidate,seen_targets)
  # Stale-offer fixture verifies the same support guard protects direct commands,
  # rather than only hiding a card in UI or filtering the initial draw.
  for id in TARGETS:
   model.state=pristine.duplicate(true)
   command(model,"hex_open",{"milestone":1})
   model.state.offers["1"].slots[0]=id
   var before_select:Dictionary=model.state.duplicate(true)
   var stale:Dictionary=command(model,"hex_select",{"milestone":1,"slot":0})
   check(id+"_stale_select_matches_mode",(not stale.accepted and stale.reason=="unsupported_effect" and model.state==before_select) if candidate else (stale.accepted and model.state.points==before_select.points),stale.reason)
   model.state.selected_hex=[id] # Explicit saved-selected-state projection fixture.
   check(id+"_effect_projection_matches_mode",(id in model.aggregate_effects().hexes)!=candidate)
  model.state=pristine
 if is_instance_valid(sim):sim.free()
 var result:Dictionary={"status":"FAIL" if not failures.is_empty() else ("CANDIDATE_FILTER_PASS" if candidate else "BASELINE_GAP_CONFIRMED"),"mode":expectation,"checks":checks,"failures":failures,"observations":observations,"scope":{"fresh_Sessions":1,"real_model_commands":true,"fixture_seeds":FIXTURE_SEEDS,"stale_offer_fixture":true,"saved_selected_projection_fixture":true,"runtime_files_changed":false,"native_UI":"NOT_RUN","natural_gameplay":"NOT_RUN"}}
 print("FOCUSED_EQUIPMENT_HEX ",JSON.stringify(result))
 return result
