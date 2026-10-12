extends GdUnitTestSuite
## Independent actual Owner cold restoration of the real Frame-normal-save file.
const Support = preload("res://tests/harvest/TreeOwnerFrame012Test.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
var support
func before() -> void:
	support = Support.new()
	add_child(support)
	support.before()
func after_test() -> void:
	support.after_test()
func after() -> void:
	support.after()
	support.free()
func test_fresh_owner_restores_actual_normal_tree_save_exactly() -> void:
	var root := OS.get_environment("TREE_OWNER_NORMAL_COLD_INPUT")
	assert_bool(root.is_absolute_path()).is_true()
	if not root.is_absolute_path(): return
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("normal_save_index.json")))
	assert_bool(index is Dictionary).is_true()
	if not index is Dictionary: return
	assert_str(index.get("kind", "")).is_equal("actual_frame_normal_tree_save_v1")
	assert_bool(index.get("normal_frame_save") == true and index.get("ordinary_live_stop") == false).is_true()
	assert_str(index.get("runtime_stage_sha256", "")).is_equal(OS.get_environment("TREE_OWNER_SAVED_SOURCE_STAGE_SHA"))
	var path := root.path_join("store")
	for relative in index["files"]:
		assert_str(FileAccess.get_sha256(path.path_join(relative))).is_equal(index["files"][relative])
	var original := FileAccess.get_file_as_bytes(path.path_join("main.json"))
	var owner: Node = support._owner(path)
	if owner == null: return
	var loaded: Dictionary = support._open(owner)
	assert_bool(loaded.get("ok", false) and loaded.get("loaded_from") == "main").is_true()
	if not loaded.get("ok", false) or not loaded.has("state"): return
	assert_int(loaded["sequence"]).is_equal(2)
	var state: Dictionary = loaded["state"]
	assert_str(Ledger.exact_token(state)).is_equal(index["state_token"])
	var encoded: Dictionary = Support.Codec.encode(state)
	assert_bool(encoded.get("ok", false)).is_true()
	if not encoded.get("ok", false): return
	assert_str(JSON.stringify(encoded["value"], "", true, true).sha256_text()).is_equal(index["receipt"]["state_sha256"])
	var restored: Dictionary = owner._restore_authority_state(state)
	assert_bool(restored.get("ok", false)).is_true()
	if not restored.get("ok", false): return
	assert_bool(var_to_bytes(owner._inventory_owner.snapshot()) == var_to_bytes(state["inventory_component"])).is_true()
	assert_bool(var_to_bytes(owner._inventory_owner.tree_snapshot()) == var_to_bytes(state["tree_component"])).is_true()
	assert_str(state["tree_component"]["trees"][index["tree_id"]]["status"]).is_equal("felled")
	assert_bool(state["tree_component"]["completions"].has(index["completion_id"])).is_true()
	assert_bool(owner._authority.active_peer_ids().is_empty()).is_true()
	assert_int(owner._terrain_generation_count).is_equal(0)
	support.fixture._dispose_owner(owner)
	for relative in index["files"]:
		assert_str(FileAccess.get_sha256(path.path_join(relative))).is_equal(index["files"][relative])
	assert_bool(FileAccess.get_file_as_bytes(path.path_join("main.json")) == original).is_true()
	print("TREE_ACTUAL_FRAME_NORMAL_COLD_RESTORED main_sha=",index["files"]["main.json"]," ordinary_live_stop=false")
