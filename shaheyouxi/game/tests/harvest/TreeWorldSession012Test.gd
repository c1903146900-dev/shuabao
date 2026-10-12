extends "res://tests/inventory/InventoryWorldSave012Test.gd"
## Reuses the original real-world fixture and teardown; inherited old-schema
## persistence checks remain present. No generation density or natural spawn.
const TreeSession = preload("res://scripts/harvest/tree_world_session012.gd")
const TreeLedger = preload("res://scripts/harvest/tree_ledger012.gd")
func _tree_fixture() -> Dictionary:
	var f:=_fixture()
	var seed: String=f["state"]["world_component"]["layout"]["seed_decimal"]
	f["trees"]=TreeLedger.new(WORLD,seed)
	f["tree_session"]=TreeSession.new(f["contract"],f["owner"]._authority,seed)
	assert_bool(f["tree_session"].ready).is_true()
	return f
func _add_at(f: Dictionary, cell: Array) -> Dictionary:
	var layer: Dictionary=f["state"]["world_component"]["layout"]["spawn"]["layer"]
	return f["trees"].plan_fixture_tree(layer,cell,[],[],f["trees"].token())
func test_tree6_empty_component_full_wrapper_old5_unchanged() -> void:
	var f:=_tree_fixture()
	var before:=var_to_bytes(f["state"])
	var result: Dictionary=f["tree_session"].combine(f["state"],f["trees"].snapshot())
	assert_bool(result["ok"]).is_true()
	assert_bool(var_to_bytes(f["state"])==before).is_true()
	assert_bool(f["contract"].validate_combined_state(result["state"])["ok"]).is_false()
	assert_bool(f["tree_session"].validate_combined_state(f["state"])["ok"]).is_false()
	assert_bool(f["contract"].validate_combined_state(TreeSession.inventory_state(result["state"]))["ok"]).is_true()
func test_tree6_saved_seed_must_match_actual_world_not_just_ledger() -> void:
	var f:=_tree_fixture()
	var foreign:=TreeLedger.new(WORLD,"123456")
	var scope:=TreeSession.new(f["contract"],f["owner"]._authority,"123456")
	assert_str(scope.combine(f["state"],foreign.snapshot())["code"]).is_equal("TREE_WORLD_SEED_BINDING")
func test_tree6_actual_entry_and_prefab_reserved_cells_reject_on_cold_admission() -> void:
	var f:=_tree_fixture()
	var world: Dictionary=f["state"]["world_component"]
	var layer: Dictionary=world["layout"]["spawn"]["layer"]
	var regions: Dictionary=TreeSession.regions_for_layer(world,layer)
	assert_bool(regions["entries"].is_empty()).is_false()
	assert_bool(regions["protected"].is_empty()).is_false()
	for region in [regions["entries"][0],regions["protected"][0]]:
		var plan:=_add_at(f,region["origin"])
		assert_bool(plan["ok"]).is_true() # Detached caller did not supply reservations.
		assert_str(f["tree_session"].combine(f["state"],plan["state"])["code"]).is_equal("TREE_FIXTURE_PROTECTED_CELL")
func test_tree6_unknown_profile_and_future_completion_rejected() -> void:
	var f:=_tree_fixture()
	# Find a fixture cell admitted by the ACTUAL world reservations. This is a
	# bounded test setup, not a gameplay tree-placement algorithm.
	var added: Dictionary={}
	for x in range(-30,31):
		var candidate:=_add_at(f,[x,30])
		if candidate.get("ok",false) and f["tree_session"].combine(f["state"],candidate["state"])["ok"]:
			added=candidate
			break
	assert_bool(added.is_empty()).is_false()
	if added.is_empty(): return
	assert_bool(f["trees"].trusted_restore(added["state"])["ok"]).is_true()
	var event:=TreeLedger.completion_identity(added["tree_id"])
	var done: Dictionary=f["trees"].plan_completion(added["tree_id"],event,"player_22222222222222222222222222222222",0.0,f["trees"].token())
	assert_str(f["tree_session"].combine(f["state"],done["state"])["code"]).is_equal("TREE_COMPLETION_AUTHORITY_CONTEXT")
	done=f["trees"].plan_completion(added["tree_id"],event,f["profile"],f["state"]["world_seconds"]+1.0,f["trees"].token())
	assert_str(f["tree_session"].combine(f["state"],done["state"])["code"]).is_equal("TREE_COMPLETION_AUTHORITY_CONTEXT")
func test_tree6_budget_encoder_configuration_replacement_rejects() -> void:
	var f:=_tree_fixture()
	f["tree_session"]._budget_store._exact_scalars=false
	assert_str(f["tree_session"].combine(f["state"],f["trees"].snapshot())["code"]).is_equal("TREE_SESSION_BINDING_CHANGED")
func test_tree6_real_store_empty_ledger_cold_roundtrip_and_file_identity() -> void:
	var f:=_tree_fixture()
	var result: Dictionary=f["tree_session"].combine(f["state"],f["trees"].snapshot())
	assert_bool(result["ok"]).is_true()
	var store: RefCounted=f["tree_session"].make_store(f["owner"]._save_directory,2,2)
	_stores.append(store)
	assert_bool(store.acquire()["ok"]).is_true()
	assert_bool(store.load_latest().get("new_world",false)).is_true()
	assert_bool(store.save_main(result["state"],"tree_fixture")["ok"]).is_true()
	var path: String=f["owner"]._save_directory.path_join("main.json")
	var original:=FileAccess.get_file_as_bytes(path)
	store.close()
	store=f["tree_session"].make_store(f["owner"]._save_directory,2,2)
	_stores.append(store)
	assert_bool(store.acquire()["ok"]).is_true()
	var loaded: Dictionary=store.load_latest()
	assert_bool(loaded["ok"]).is_true()
	assert_bool(var_to_bytes(loaded["state"])==var_to_bytes(result["state"])).is_true()
	assert_bool(FileAccess.get_file_as_bytes(path)==original).is_true()
func test_tree6_inventory_rule_mutation_invalidates_bound_contract() -> void:
	var f:=_tree_fixture()
	f["core"]._rules["item_rules"]["mucai"]["max_stack"]=1000
	assert_str(f["tree_session"].combine(f["state"],f["trees"].snapshot())["code"]).is_equal("TREE_SESSION_BINDING_CHANGED")
