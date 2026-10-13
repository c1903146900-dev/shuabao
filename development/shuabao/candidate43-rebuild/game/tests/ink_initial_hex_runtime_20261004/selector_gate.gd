extends SceneTree
const Catalog=preload("res://tests/ink_initial_hex_runtime_20261004/ink_initial_catalog.gd")
const Model=preload("res://tests/ink_initial_hex_runtime_20261004/ink_initial_model.gd")
const Design=preload("res://data/final_design/catalog.gd")
const SHOP="res://tests/ink_first_floor_flow_20261004/fixtures/provisional_shop.json"
var checks: int=0
var failures: Array=[]
var serial: int=0
func _initialize()->void:call_deferred("run")
func check(ok: bool,label: String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func call_model(model,action: String,args: Dictionary={})->Dictionary:
 serial+=1;return model.command("initial-selector:%d"%serial,action,args)
func caps()->Dictionary:return {"schema_version":1,"hero_id":"yanguizhou","source_binding_id":"finite-selector-contract-not-runtime-admission","runtime_candidates":["Q1"],"supported_hooks":Catalog.FIRST_SLICE_HEX_HOOKS.duplicate()}
func permutations(left: Array,prefix: Array=[])->Array:
 if left.is_empty():return [prefix]
 var out: Array=[]
 for entry in left:
  var rest: Array=left.duplicate();rest.erase(entry)
  out.append_array(permutations(rest,prefix+[entry]))
 return out
func check_offer(model,seen: Dictionary)->void:
 var offer: Dictionary=model.state.offers["1"]
 var keys: Dictionary={}
 for id in offer.slots:
  check(not id.is_empty() and model.config.hexes.has(id),"four real definition IDs")
  var effect: String=model.config.hexes[id].effect_key
  check(not keys.has(effect),"no duplicate effects");keys[effect]=true
  check(id not in offer.excluded and id not in model.state.selected_hex,"removed and selected never displayed")
  seen[id]=true
 check(model.config.hexes[offer.slots[3]].hero=="yanguizhou","right slot remains personal")
func run()->void:
 var built: Dictionary=Catalog.build(caps(),SHOP,true)
 check(built.accepted,"versioned catalog admits exactly eight candidates")
 var orders: Array=permutations([0,1,2,3])
 check(orders.size()==24,"all refresh permutations")
 var runs: int=0
 for complete in [false,true]:
  for learned in [false,true]:
   for seed_value in [1,7,91]:
    for order in orders:
     var definitions: Dictionary=built.definitions.duplicate(true)
     var hooks: Array=built.hooks.duplicate()
     if complete:
      # Pure allocator fixture only: these extra personal hooks are never a live capability.
      for id in definitions.hexes:
       if definitions.hexes[id].hero=="yanguizhou":hooks.append_array(definitions.hexes[id].required_hooks)
     var model=Model.new(definitions,"selector-only",seed_value);model.set_supported_hooks(hooks)
     if learned:check(call_model(model,"learn",{"slot":"Q","candidate":"Q1","expected_rank":0}).accepted,"real initial SP allocated")
     check(model.initial_pool_readiness().accepted,"pool guarantees four one-time refreshes")
     check(call_model(model,"hex_open",{"milestone":1}).accepted,"open Lv1")
     var seen: Dictionary={};check_offer(model,seen)
     for slot in order:
      var before: Dictionary=model.state.duplicate(true)
      check(call_model(model,"hex_refresh",{"milestone":1,"slot":slot}).accepted,"each order refresh succeeds")
      check(model.state.offers["1"].slots[slot]!=before.offers["1"].slots[slot],"actual replacement")
      check_offer(model,seen)
      before=model.state.duplicate(true)
      check(call_model(model,"hex_refresh",{"milestone":1,"slot":slot}).reason=="refresh_exhausted","second refresh denied")
      check(before==model.state and not model._reserve_personal_refresh,"rejection state and selector context atomic")
     check(seen.size()==8,"eight unique observed effects across four refreshes")
     var points: int=model.state.points
     check(call_model(model,"hex_select",{"milestone":1,"slot":3}).accepted,"one true ledger choice")
     check(model.state.points==points,"Hex never grants SP")
     check(call_model(model,"hex_refresh",{"milestone":1,"slot":0}).reason=="already_selected","chosen offer cannot refresh")
     if not complete:check(not model.initial_pool_readiness().accepted,"remaining partial pool is not Lv4 ready")
     runs+=1
 var small=Model.new(built.definitions,"insufficient",1)
 small.set_supported_hooks(Catalog.FIRST_SLICE_HEX_HOOKS.slice(0,2)+Catalog.FIRST_SLICE_HEX_HOOKS.slice(2,5))
 check(not small.initial_pool_readiness().accepted,"five candidates held before ordinary open")
 var before: Dictionary=small.state.duplicate(true)
 small.set_supported_hooks(Catalog.FIRST_SLICE_HEX_HOOKS.slice(0,1))
 check(call_model(small,"hex_open",{"milestone":1}).reason=="pool_exhausted","insufficient pool fails")
 check(small.state==before and not small._reserve_personal_refresh,"failed open restores RNG/seen/context")
 var result: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"runs":runs,"orders_per_pool":24,"pool_sizes":[8,22],"complete_pool_runtime_claim":false,"source_binding_id":FileAccess.get_sha256("res://tests/ink_initial_hex_runtime_20261004/source_binding.json"),"scope":"real GDScript allocator and ledger contract; expanded personal pool is model-only"}
 var file=FileAccess.open("res://tests/ink_initial_hex_runtime_20261004/selector_result.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
 print("INK_INITIAL_SELECTOR_REPORT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
