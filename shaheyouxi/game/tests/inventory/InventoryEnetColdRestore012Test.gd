extends GdUnitTestSuite
## Fresh process and production Store/owner restore after actual ENet disconnect.
const Integration = preload("res://tests/inventory/InventoryGroundFrame012Test.gd")
const Paths = preload("res://scripts/network/runtime_paths.gd")
func test_actual_enet_disconnect_cold_restore() -> void:
	var destination := OS.get_environment("SANDBOX_ENET_FIXTURE_ROOT")
	assert_bool(not destination.is_empty()).is_true()
	assert_str(Paths.scoped_path(ProjectSettings.globalize_path("res://"), PackedStringArray(), destination)).is_equal(destination)
	if destination.is_empty(): return
	var pair: Variant = JSON.parse_string(FileAccess.get_file_as_string(destination.path_join("pair_result.json")))
	assert_bool(pair is Dictionary and pair.get("ok", false)).is_true()
	if not pair is Dictionary or not pair.get("ok", false): return
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(destination.path_join("client_probe.json")))
	var server: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(destination.path_join("server_owner.json")))
	assert_bool(server.get("saved", false) and server.get("disconnect_saved", false)).is_true()
	var integration := Integration.new()
	integration.before()
	var owner: Node = integration._owner(5, destination.path_join("world"))
	var original_world: String = owner._authority.world_id
	var bytes := FileAccess.get_file_as_bytes(destination.path_join("world/main.json"))
	var loaded: Dictionary = integration._open(owner)
	assert_bool(loaded.get("ok", false)).is_true()
	assert_bool(owner._restore_authority_state(loaded["state"])["ok"]).is_true()
	assert_str(owner._authority.world_id).is_not_equal(original_world)
	assert_bool(owner._authority.active_peer_ids().is_empty()).is_true()
	var profile: String = proof["checkpoint"]["player_profile_id"]
	var inventory: Dictionary = owner._inventory_owner.snapshot()["players"][profile]
	assert_bool(var_to_bytes(inventory).hex_encode() == proof["inventory_bytes_hex"]).is_true()
	assert_int(inventory["carry"]["quantity"]).is_equal(731)
	assert_int(inventory["last_sequence"]).is_equal(21)
	assert_str(inventory["bag"][2]["item_instance_id"]).is_equal("item_fixture_gun")
	assert_str(inventory["bag"][2]["protected_instance_id"]).is_equal("protected_fixture_gun")
	assert_bool(FileAccess.get_file_as_bytes(destination.path_join("world/main.json")) == bytes).is_true()
	assert_int(owner._terrain_generation_count).is_equal(0)
	assert_int(owner._terrain_stage_creation_count).is_equal(0)
	integration.after_test()
	integration.after()
	integration.free()
