extends RefCounted
## Isolated full-state transaction model, not a network/Frame replacement.
## A later actual Frame adapter must additionally certify authenticated actor,
## settlement completion, hand/range and its immutable-world lease boundary.
const TreeSession = preload("res://scripts/harvest/tree_world_session012.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
const Outputs = preload("res://scripts/harvest/tree_ground012.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
var ready := false
var _session: RefCounted
var _state: Dictionary={}
func _init(session: Variant, state: Variant) -> void:
	if not session is RefCounted or session.get_script()!=TreeSession or not session.ready or not state is Dictionary: return
	if not session.validate_combined_state(state).get("ok",false): return
	if state["inventory_component"]["rules_sha256"]!=Core.TREE_RULES_SHA256: return
	_session=session
	_state=state.duplicate(true)
	ready=true
func snapshot() -> Dictionary:
	return _state.duplicate(true) if ready else {}
func tokens() -> Dictionary:
	if not ready: return {}
	return {"tree":Ledger.exact_token(_state["tree_component"]),"inventory":Core._exact(_state["inventory_component"]),"boundary":Ledger.exact_token(_state)}
func plan_completion(tree_id: String, completion_id: String, profile_id: String, expected: Dictionary) -> Dictionary:
	if not ready or expected!=tokens(): return _bad("TREE_TRANSACTION_STALE_BOUNDARY")
	if not _state["profiles"].has(profile_id): return _bad("TREE_TRANSACTION_PROFILE_UNKNOWN")
	var ledger:=Ledger.new(_state["world_id"],_state["tree_component"]["seed_decimal"])
	var core:=Core.new(_state["world_id"],"v2_tree_seed")
	if not ledger.trusted_restore(_state["tree_component"]).get("ok",false) or not core.trusted_restore(_state["inventory_component"]).get("ok",false): return _bad("TREE_TRANSACTION_COMPONENT_INVALID")
	var tree_plan: Dictionary=ledger.plan_completion(tree_id,completion_id,profile_id,_state["world_seconds"],ledger.token())
	if not tree_plan.get("ok",false): return tree_plan
	var candidate: Dictionary=_state.duplicate(true)
	var drops: Array=[]
	if not tree_plan["replay"]:
		var ground_plan: Dictionary=Outputs.prepare_outputs(core,ledger,tree_plan,_state["world_seconds"])
		if not ground_plan.get("ok",false): return ground_plan
		candidate["inventory_component"]=ground_plan["state"]
		candidate["tree_component"]=tree_plan["state"]
		drops=ground_plan["created_drop_ids"]
	var checked: Dictionary=_session.validate_combined_state(candidate)
	if not checked.get("ok",false): return checked
	return {"ok":true,"state":candidate,"source_tokens":expected.duplicate(),"request":{"tree_id":tree_id,"completion_id":completion_id,"profile_id":profile_id},"replay":tree_plan["replay"],"created_drop_ids":drops,"published":false,"durable":false,"fixture_only":true}
func commit(candidate: Variant) -> Dictionary:
	if not ready or not candidate is Dictionary or not candidate.get("ok",false) or candidate.get("source_tokens")!=tokens() or not candidate.get("request") is Dictionary: return _bad("TREE_TRANSACTION_STALE_BOUNDARY")
	var request: Dictionary=candidate["request"]
	if not Core._fields(request,["tree_id","completion_id","profile_id"]): return _bad("TREE_TRANSACTION_REQUEST_INVALID")
	for key in request:
		if not request[key] is String: return _bad("TREE_TRANSACTION_REQUEST_INVALID")
	# Do not trust a mutable plan merely because its tokens match. Recompute its
	# whole authorised effect from the current root before the synchronous swap.
	var verified:=plan_completion(request["tree_id"],request["completion_id"],request["profile_id"],candidate["source_tokens"])
	if not verified.get("ok",false): return verified
	if Ledger.exact_token(candidate.get("state"))!=Ledger.exact_token(verified["state"]): return _bad("TREE_TRANSACTION_PLAN_CHANGED")
	# No awaits/callbacks or independently-live component restores between the
	# checks above and this one aggregate publication root assignment.
	_state=verified["state"].duplicate(true)
	return {"ok":true,"published":true,"durable":false,"fixture_only":true,"replay":verified["replay"],"created_drop_ids":verified["created_drop_ids"].duplicate(),"source_tokens":tokens()}
static func _bad(code: String) -> Dictionary:
	return {"ok":false,"code":code}
