extends GdUnitTestSuite
## Independent fresh actual Owner restoration after a fully green real ENet pair.
const Support = preload("res://tests/harvest/TreeOwnerFrame012Test.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
var support
func before() -> void:
	support=Support.new()
	add_child(support)
	support.before()
func after_test() -> void:
	support.after_test()
func after() -> void:
	support.after()
	support.free()
func test_fresh_owner_restores_real_enet_tree_disconnect_save() -> void:
	var root_path:=OS.get_environment("TREE_ENET_COLD_INPUT")
	assert_bool(root_path.is_absolute_path()).is_true()
	if not root_path.is_absolute_path(): return
	var index: Variant=JSON.parse_string(FileAccess.get_file_as_string(root_path.path_join("cold_index.json")))
	assert_bool(index is Dictionary).is_true()
	if not index is Dictionary: return
	assert_str(index.get("kind","")).is_equal("actual_enet_tree_normal_v1")
	assert_str(index.get("source_stage_sha256","")).is_equal(OS.get_environment("TREE_ENET_SAVED_STAGE_SHA"))
	assert_str(FileAccess.get_sha256(root_path.path_join("server_probe.json"))).is_equal(index["server_probe_sha256"])
	var probe: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root_path.path_join("server_probe.json")))
	assert_bool(probe.get("ok",false) and probe.get("remote_disconnect",false)).is_true()
	var expected_tree: Variant=bytes_to_var(str(probe["published_tree_exact"]).hex_decode())
	var expected_inventory: Variant=bytes_to_var(str(probe["published_inventory_exact"]).hex_decode())
	assert_bool(expected_tree is Dictionary and expected_inventory is Dictionary).is_true()
	if not expected_tree is Dictionary or not expected_inventory is Dictionary: return
	var store_path:=root_path.path_join("store")
	for relative in index["files"]:
		assert_str(FileAccess.get_sha256(store_path.path_join(relative))).is_equal(index["files"][relative])
	var main_before:=FileAccess.get_file_as_bytes(store_path.path_join("main.json"))
	var server: Node=support._owner(store_path)
	if server==null: return
	var loaded: Dictionary=support._open(server)
	assert_bool(loaded.get("ok",false) and loaded.get("loaded_from")=="main").is_true()
	if not loaded.get("ok",false) or not loaded.has("state"): return
	assert_int(loaded["sequence"]).is_equal(int(probe["save_receipt"]["sequence"]))
	var state: Dictionary=loaded["state"]
	var encoded: Dictionary=Support.Codec.encode(state)
	assert_bool(encoded.get("ok",false)).is_true()
	if not encoded.get("ok",false): return
	assert_str(JSON.stringify(encoded["value"],"",true,true).sha256_text()).is_equal(probe["save_receipt"]["state_sha256"])
	assert_bool(var_to_bytes(state["tree_component"])==var_to_bytes(expected_tree)).is_true()
	assert_int(state["tree_component"]["completions"].size()).is_equal(1)
	assert_bool(_item_totals(state["inventory_component"])==_item_totals(expected_inventory)).is_true()
	_assert_protected_inventory_exact(expected_inventory,state["inventory_component"],expected_tree)
	assert_float(state["inventory_component"]["ground_clock"]).is_equal(state["world_seconds"])
	var restored: Dictionary=server._restore_authority_state(state)
	assert_bool(restored.get("ok",false)).is_true()
	if not restored.get("ok",false): return
	assert_bool(var_to_bytes(server._inventory_owner.snapshot())==var_to_bytes(state["inventory_component"])).is_true()
	assert_bool(var_to_bytes(server._inventory_owner.tree_snapshot())==var_to_bytes(state["tree_component"])).is_true()
	assert_bool(server._authority.active_peer_ids().is_empty()).is_true()
	assert_int(server._terrain_generation_count).is_equal(0)
	support.fixture._dispose_owner(server)
	for relative in index["files"]:
		assert_str(FileAccess.get_sha256(store_path.path_join(relative))).is_equal(index["files"][relative])
	assert_bool(FileAccess.get_file_as_bytes(store_path.path_join("main.json"))==main_before).is_true()
	print("TREE_REAL_ENET_FRESH_OWNER_COLD_RESTORED main_sha=",index["files"]["main.json"]," fault_injection=",probe["fault_injection"]," ordinary_harvest_input=false")

func _item_totals(value: Dictionary) -> Dictionary:
	var totals: Dictionary={}
	for player in value["players"].values():
		for kind in ["bag","hotbar"]:
			for stack in player[kind]: _add_stack(totals,stack)
		_add_stack(totals,player["carry"])
	for chest in value["chests"].values():
		for stack in chest["slots"]: _add_stack(totals,stack)
	for record in value["ground"].values(): _add_stack(totals,record["stack"])
	return totals
func _add_stack(totals: Dictionary, stack: Variant) -> void:
	if stack==null: return
	totals[stack["content_id"]]=int(totals.get(stack["content_id"],0))+stack["quantity"]

func _assert_protected_inventory_exact(published_value: Dictionary, saved_value: Dictionary, trees: Dictionary) -> void:
	# This finite fixture closes inside the universal newborn protection window.
	# Exceeding it is a test failure, not permission to disable legitimate pickup.
	assert_int(trees["completions"].size()).is_equal(1)
	if trees["completions"].size()!=1: return
	var event: String=trees["completions"].keys()[0]
	var expected_outputs: Dictionary={}
	for output in trees["completions"][event]["outputs"]:
		expected_outputs[output["content_id"]]=output["quantity"]
	var actual_outputs: Dictionary={}
	var minimum_delay: float=INF
	for record in published_value["ground"].values():
		assert_int(record["lots"].size()).is_equal(1)
		if record["lots"].size()!=1: return
		var lot: Dictionary=record["lots"][0]
		assert_str(lot.get("source_kind","")).is_equal("natural_harvest")
		assert_str(lot.get("completion_id","")).is_equal(event)
		var content: String=record["stack"]["content_id"]
		assert_bool(not actual_outputs.has(content)).is_true()
		actual_outputs[content]=record["stack"]["quantity"]
		assert_int(lot["quantity"]).is_equal(record["stack"]["quantity"])
		minimum_delay=minf(minimum_delay,lot["remaining_delay"])
	assert_bool(actual_outputs==expected_outputs).is_true()
	var elapsed: float=saved_value["ground_clock"]-published_value["ground_clock"]
	assert_bool(is_finite(minimum_delay) and elapsed>=0.0 and elapsed<minimum_delay).is_true()
	if not is_finite(minimum_delay) or elapsed<0.0 or elapsed>=minimum_delay: return
	var normalized: Dictionary=published_value.duplicate(true)
	normalized["ground_clock"]=saved_value["ground_clock"]
	assert_bool(normalized["ground"].keys()==saved_value["ground"].keys()).is_true()
	if normalized["ground"].keys()!=saved_value["ground"].keys(): return
	for id in normalized["ground"]:
		var old_lots: Array=normalized["ground"][id]["lots"]
		var current_lots: Array=saved_value["ground"][id]["lots"]
		assert_int(current_lots.size()).is_equal(old_lots.size())
		if current_lots.size()!=old_lots.size(): return
		for i in range(old_lots.size()):
			assert_str(old_lots[i].get("source_kind","")).is_equal("natural_harvest")
			assert_bool(absf(current_lots[i]["remaining_lifetime"]-maxf(0.0,old_lots[i]["remaining_lifetime"]-elapsed))<=0.000001).is_true()
			assert_bool(absf(current_lots[i]["remaining_delay"]-maxf(0.0,old_lots[i]["remaining_delay"]-elapsed))<=0.000001).is_true()
			old_lots[i]["remaining_lifetime"]=current_lots[i]["remaining_lifetime"]
			old_lots[i]["remaining_delay"]=current_lots[i]["remaining_delay"]
	assert_bool(var_to_bytes(normalized)==var_to_bytes(saved_value)).is_true()
