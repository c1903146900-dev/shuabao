extends RefCounted
## Off-root output preparation only. Caller must atomically publish the new
## tree completion and this inventory candidate through the full TreeSession.
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
const ActorState = preload("res://scripts/actor/actor_state.gd")
static func prepare_outputs(core: Variant, ledger: Variant, tree_plan: Variant, world_seconds: float) -> Dictionary:
	if not core is RefCounted or core.get_script()!=Core or not core.ready or not core._tree_rules or core._rules_identity!=Core.TREE_RULES_SHA256 or not ledger is RefCounted or ledger.get_script()!=Ledger or not ledger.ready: return _bad("TREE_GROUND_CONTEXT")
	if not tree_plan is Dictionary or not tree_plan.get("ok",false) or tree_plan.get("replay",true) or tree_plan.get("must_not_create_drops",true) or tree_plan.get("source_token")!=ledger.token() or not ActorState.valid_clock(world_seconds): return _bad("TREE_GROUND_PLAN_OR_REPLAY")
	var checked: Dictionary=ledger.validate_snapshot(tree_plan.get("state"))
	if not checked.get("ok",false): return checked
	var event: Variant=tree_plan.get("completion_id")
	var next_trees: Dictionary=tree_plan["state"]
	if not event is String or not next_trees["completions"].has(event) or next_trees["world_id"]!=core._world_id: return _bad("TREE_GROUND_EVENT_SCOPE")
	var completion: Dictionary=next_trees["completions"][event]
	if completion["completed_world_seconds"]!=world_seconds or not core.snapshot()["players"].has(completion["profile_id"]): return _bad("TREE_GROUND_CLOCK_OR_PROFILE")
	var recomputed: Dictionary=ledger.plan_completion(completion["tree_id"],event,completion["profile_id"],world_seconds,tree_plan["source_token"])
	if not recomputed.get("ok",false) or recomputed.get("replay",true) or Ledger.exact_token(recomputed["state"])!=Ledger.exact_token(next_trees): return _bad("TREE_GROUND_FORGED_OR_REPLAYED_PLAN")
	var source: Dictionary=core.snapshot()
	var candidate: Dictionary=source.duplicate(true)
	if candidate["revision"]>=Core.MAX_SEQUENCE: return _bad("TREE_GROUND_REVISION_LIMIT")
	if candidate["schema_version"]==1:
		candidate["ground"]={}
		candidate["ground_serial"]=0
		candidate["ground_clock"]=world_seconds
	if candidate["ground_clock"]!=world_seconds: return _bad("TREE_GROUND_CONFIRMED_CLOCK_REQUIRED")
	candidate["schema_version"]=3 # Explicit planned format transition, never load.
	var outputs: Array=completion["outputs"]
	if candidate["ground"].size()+outputs.size()>Core.MAX_GROUND or candidate["ground_serial"]>Core.MAX_SEQUENCE-outputs.size(): return _bad("TREE_GROUND_CAPACITY")
	var tree: Dictionary=next_trees["trees"][completion["tree_id"]]
	var position: Array=[float(tree["cell"][0])+0.5,float(tree["cell"][1])+0.5]
	var created: Array=[]
	var expected: Dictionary=core._totals(source)
	for output in outputs:
		candidate["ground_serial"]+=1
		var id: String="drop_"+core._world_id.trim_prefix("world_")+"_"+str(candidate["ground_serial"])
		if candidate["ground"].has(id): return _bad("TREE_GROUND_ID_REPLAY")
		var stack: Dictionary={"content_id":output["content_id"],"quantity":output["quantity"],"item_instance_id":"","protected_instance_id":"","state":{}}
		Core._count(expected,stack)
		candidate["ground"][id]={"layer":tree["layer"].duplicate(true),"position":position.duplicate(),"stack":stack,"lots":[{"quantity":output["quantity"],"remaining_lifetime":300.0,"remaining_delay":0.5,"thrower":null,"remaining_thrower_protection":null,"source_kind":"natural_harvest","completion_id":event}],"trajectory":{"origin":position.duplicate(),"target":position.duplicate(),"remaining_seconds":0.0}}
		created.append(id)
	candidate["revision"]+=1
	checked=core.validate_snapshot(candidate)
	if not checked.get("ok",false): return checked
	if core._totals(candidate)!=expected: return _bad("TREE_GROUND_OUTPUT_CONSERVATION")
	return {"ok":true,"state":candidate,"inventory_source_token":Core._exact(source),"tree_source_token":tree_plan["source_token"],"completion_id":event,"created_drop_ids":created,"published":false,"durable":false,"fixture_only":true}
static func _bad(code: String) -> Dictionary:
	return {"ok":false,"code":code}
