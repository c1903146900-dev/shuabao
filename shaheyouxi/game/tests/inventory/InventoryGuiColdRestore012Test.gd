extends GdUnitTestSuite
## A new engine process restores the actual GUI09 normal-shutdown save. This
## never rewrites the fixture/index or substitutes a synthetic inventory state.
const Integration = preload("res://tests/inventory/InventoryGroundFrame012Test.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
func test_actual_gui_save_fresh_owner_exact_cold_restore() -> void:
	var root: String = OS.get_environment("SANDBOX_GUI_USER_ROOT")
	assert_bool(root.is_absolute_path()).is_true()
	if not root.is_absolute_path(): return
	var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("gui_result.json")))
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("gui_fixture.json")))
	assert_bool(result.get("ok",false) and not result.get("forced",true)).is_true()
	if not result.get("ok",false) or result.get("forced",true): return
	var directory: String = root.path_join("local_play011/slots").path_join(fixture["slot_id"]).path_join("world")
	var path: String = directory.path_join("main.json")
	var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var envelope: Dictionary = JSON.parse_string(original.get_string_from_utf8())
	var decoded: Dictionary = Codec.decode(JSON.parse_string(envelope["payload_json"]))
	assert_bool(decoded.get("ok",false)).is_true()
	if not decoded.get("ok",false): return
	var payload: Dictionary = decoded["value"]
	assert_str(payload["reason"]).is_equal("normal_shutdown")
	assert_int(payload["sequence"]).is_equal(int(result["saved_sequence"]))
	assert_bool(FileAccess.get_sha256(path) != fixture["main_sha256"]).is_true()
	var expected: Dictionary = payload["state"]["inventory_component"]
	var integration := Integration.new()
	integration.before()
	var owner: Node = integration._owner(5,directory)
	var startup_world: String = owner._authority.world_id
	var loaded: Dictionary = integration._open(owner) # acquire + real load_latest
	assert_bool(loaded.get("ok",false)).is_true()
	if loaded.get("ok",false):
		assert_bool(var_to_bytes(loaded["state"]) == var_to_bytes(payload["state"])).is_true()
		assert_bool(owner._restore_authority_state(loaded["state"]).get("ok",false)).is_true()
		assert_str(owner._authority.world_id).is_not_equal(startup_world)
		assert_str(owner._authority.world_id).is_equal(fixture["world_id"])
		assert_bool(owner._authority.active_peer_ids().is_empty()).is_true()
		var inventory: Dictionary = owner._inventory_owner.snapshot()
		assert_bool(var_to_bytes(inventory) == var_to_bytes(expected)).is_true()
		var player: Dictionary = inventory["players"][fixture["profile_id"]]
		assert_int(player["last_sequence"]).is_equal(26)
		assert_int(player["carry"]["quantity"]).is_equal(2)
		assert_int(inventory["ground"].size()).is_equal(1)
		assert_int(inventory["ground"].values()[0]["stack"]["quantity"]).is_equal(6)
		var total := 0
		for stack in player["bag"] + player["hotbar"] + [player["carry"]]:
			if stack != null and stack["content_id"] == "mucai": total += stack["quantity"]
		for record in inventory["ground"].values():
			if record["stack"]["content_id"] == "mucai": total += record["stack"]["quantity"]
		assert_int(total).is_equal(1014)
		assert_str(player["bag"][2]["item_instance_id"]).is_equal("item_fixture_gun")
		assert_str(player["bag"][2]["protected_instance_id"]).is_equal("protected_fixture_gun")
		assert_bool(var_to_bytes(player["bag"][2]["state"]) == var_to_bytes({"fixture_magazine":3,"bits":-0.0})).is_true()
		assert_float(inventory["ground_clock"]).is_equal(owner._authority.world_seconds)
		assert_int(owner._terrain_generation_count).is_equal(0)
		assert_int(owner._terrain_stage_creation_count).is_equal(0)
	assert_bool(FileAccess.get_file_as_bytes(path) == original).is_true()
	integration.after_test()
	integration.after()
	integration.free()
