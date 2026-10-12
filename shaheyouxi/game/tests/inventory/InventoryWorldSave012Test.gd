extends GdUnitTestSuite
## Source-only finite real-file gate; requires an approved engine window.
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Combined = preload("res://scripts/inventory/inventory_world_session012.gd")
const Owner = preload("res://scripts/actor/actor_terrain_network_main.gd")
const CombinedStore = preload("res://scripts/terrain/combined_terrain_store.gd")
const TerrainSession = preload("res://scripts/actor/actor_terrain_session_state.gd")
const ActorSession = preload("res://scripts/actor/actor_session_state.gd")
const World = preload("res://scripts/world_session/world_component.gd")
const Inputs = preload("res://scripts/actor/actor_inputs.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const WORLD := "world_11111111111111111111111111111111"
var _owners: Array = []
var _paths: Array[String] = []
var _reference_bytes := PackedByteArray()
var _reference_statistics: Dictionary = {}
var _stores: Array = []

func _document(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/" + name + ".json"))

func _empty_owner() -> Node:
	var owner := Owner.new()
	_owners.append(owner)
	owner._mode = "server"
	owner._arguments = {"seed": "42", "test_entry": "true"}
	owner._save_directory = ProjectSettings.globalize_path("user://inventory_world012/").path_join(Crypto.new().generate_random_bytes(16).hex_encode())
	_paths.append(owner._save_directory)
	owner._settings = _document("network_settings")
	owner._save_settings = _document("save_settings")
	assert_int(owner._catalogue.load_file()).is_equal(OK)
	owner._authority = SandboxServerAuthority.new(int(owner._settings["max_players"]), int(owner._settings["network_protocol_version"]), owner._catalogue.source_sha256, float(owner._save_settings["automatic_interval_seconds"]))
	owner._authority.world_id = WORLD
	owner._actor_inputs = Inputs.new()
	assert_bool(owner._actor_inputs.load_file()).is_true()
	owner._terrain_documents = [_document("generation_settings"), _document("prefab_settings"), _document("actor_world_bundle011")]
	var docs: Array = owner._terrain_documents
	owner._world = World.new(docs[0], docs[1], docs[2], "011")
	owner._actor_session = ActorSession.new(owner._world, owner._actor_inputs.document())
	owner._terrain_store = CombinedStore.new(docs[0], docs[1], docs[2])
	owner._terrain_session = TerrainSession.new(owner._actor_session, owner._terrain_store)
	assert_bool(owner._terrain_services_ready()).is_true()
	return owner

func _reference_state() -> Dictionary:
	if _reference_bytes.is_empty():
		var fresh := _empty_owner()
		assert_bool(fresh._create_new_world()).is_true()
		var joined: Dictionary = fresh._authority.join(11, {"network_protocol_version": fresh._authority.protocol_version, "catalogue_sha256": fresh._authority.catalogue_hash, "display_name": "Inventory save technical fixture", "resume_profile_id": "", "resume_secret": ""})
		assert_bool(joined["ok"]).is_true()
		var spawn: Dictionary = fresh._world.public_component()["layout"]["spawn"]
		var position := Vector2(spawn["cell"][0] + 0.5, spawn["cell"][1] + 0.5)
		assert_bool(fresh._actor_model.create_actor(joined["player_instance_id"], spawn["layer"], position, {"layer": spawn["layer"], "position": [position.x, position.y]})["ok"]).is_true()
		var base: Dictionary = fresh._actor_session.combine(fresh._authority.persistent_state(), fresh._actor_model)
		assert_bool(base["ok"]).is_true()
		var combined: Dictionary = fresh._terrain_session.combine(base["state"], fresh._terrain_component)
		assert_bool(combined["ok"]).is_true()
		var encoded: Dictionary = Codec.encode(combined["state"])
		assert_bool(encoded["ok"]).is_true()
		_reference_bytes = JSON.stringify(encoded["value"], "", true, true).to_utf8_buffer()
		assert_bool(_reference_bytes.size() <= 4194304).is_true()
		_reference_statistics = fresh.terrain_persistence_statistics()
		_dispose_owner(fresh)
	var parser := JSON.new()
	assert_int(parser.parse(_reference_bytes.get_string_from_utf8())).is_equal(OK)
	var decoded: Dictionary = Codec.decode(parser.data)
	assert_bool(decoded["ok"]).is_true()
	return decoded["value"]

func _fixture() -> Dictionary:
	var base := _reference_state()
	var owner := _empty_owner()
	var core := Core.new(WORLD)
	var profile: String = base["profiles"].keys()[0]
	assert_bool(core.trusted_create_player(profile)["ok"]).is_true()
	assert_bool(core.trusted_create_chest("entity_fixture_chest")["ok"]).is_true()
	var snapshot: Dictionary = core.snapshot()
	snapshot["players"][profile]["bag"][0] = {"content_id": "mucai", "quantity": 731, "item_instance_id": "", "protected_instance_id": "", "state": {}}
	snapshot["players"][profile]["bag"][1] = {"content_id": "wuqi_huoqi_tansuo_01", "quantity": 1, "item_instance_id": "item_fixture_gun", "protected_instance_id": "protected_fixture_gun", "state": {"fixture_magazine": 3, "bits": -0.0}}
	assert_bool(core.trusted_restore(snapshot)["ok"]).is_true()
	assert_bool(core.click_slot(profile, {"container": "bag", "owner": profile, "slot": 1}, core.revision(), 19)["ok"]).is_true()
	var contract := Combined.new(owner._terrain_session, core, owner._authority)
	assert_bool(contract.ready).is_true()
	var combined: Dictionary = contract.combine(base, core.snapshot())
	assert_bool(combined["ok"]).is_true()
	return {"owner": owner, "core": core, "contract": contract, "state": combined["state"], "profile": profile}

func _open(fixture: Dictionary) -> RefCounted:
	var store: RefCounted = fixture["contract"].make_store(fixture["owner"]._save_directory, 2, 2)
	_stores.append(store)
	assert_bool(store.acquire()["ok"]).is_true()
	return store

func test_real_files_roundtrip_actor_667_cells_carry_ids_quantities_and_cursors() -> void:
	var fixture := _fixture()
	var store := _open(fixture)
	assert_bool(store.load_latest().get("new_world", false)).is_true()
	assert_bool(store.save_main(fixture["state"], "inventory_fixture")["ok"]).is_true()
	assert_int(_reference_statistics["cell_count"]).is_equal(667)
	var path: String = fixture["owner"]._save_directory
	var bytes := FileAccess.get_file_as_bytes(path.path_join("main.json"))
	assert_bool(not bytes.is_empty() and bytes.size() <= Combined.MAX_BYTES).is_true()
	store.close()
	store = _open(fixture)
	var loaded: Dictionary = store.load_latest()
	assert_bool(loaded["ok"]).is_true()
	assert_bool(var_to_bytes(loaded["state"]) == var_to_bytes(fixture["state"])).is_true()
	var fresh := Core.new(WORLD)
	assert_bool(fresh.trusted_restore(loaded["state"]["inventory_component"])["ok"]).is_true()
	assert_str(fresh.click_slot(fixture["profile"], {"container": "bag", "owner": fixture["profile"], "slot": 2}, fresh.revision(), 19)["code"]).is_equal("INVENTORY_STALE_SEQUENCE")
	var owner: Node = fixture["owner"]
	assert_bool(owner._restore_authority_state(Combined.terrain_state(loaded["state"]))["ok"]).is_true()
	assert_bool(owner._terrain_generation_count == 0 and owner._terrain_stage_creation_count == 0 and owner._world.statistics()["generation_calls"] == 0 and owner._world.statistics()["instantiation_calls"] == 0 and owner._world.statistics()["world_seed_random_calls"] == 0).is_true()
	assert_bool(FileAccess.get_file_as_bytes(path.path_join("main.json")) == bytes).is_true()

func test_invalid_contracts_are_closed_and_do_not_change_inventory_or_disk() -> void:
	var fixture := _fixture()
	var store := _open(fixture)
	assert_bool(store.load_latest().get("new_world", false)).is_true()
	assert_bool(store.save_main(fixture["state"], "initial_fixture")["ok"]).is_true()
	var before := FileAccess.get_file_as_bytes(fixture["owner"]._save_directory.path_join("main.json"))
	var inventory_before: PackedByteArray = var_to_bytes(fixture["core"].snapshot())
	for mutation in ["old", "unknown", "world", "inventory_world", "profile", "missing_profile", "item", "capacity", "duplicate", "external_duplicate"]:
		var state: Dictionary = fixture["state"].duplicate(true)
		var player: Dictionary = state["inventory_component"]["players"][fixture["profile"]]
		match mutation:
			"old": state.erase("inventory_component")
			"unknown": state["future_component"] = {}
			"world": state["world_id"] = "world_22222222222222222222222222222222"
			"inventory_world": state["inventory_component"]["world_id"] = "world_22222222222222222222222222222222"
			"profile": state["inventory_component"]["players"]["profile_unknown"] = player.duplicate(true)
			"missing_profile": state["inventory_component"]["players"].clear()
			"item": player["bag"][0]["content_id"] = "unknown_item"
			"capacity": player["bag"].append(null)
			"duplicate": player["bag"][2] = player["carry"].duplicate(true)
			"external_duplicate": state["inventory_component"]["external_protected_instance_ids"] = ["protected_fixture_gun"]
		var rejected: Dictionary = fixture["contract"].validate_combined_state(state)
		assert_bool(not rejected["ok"] and rejected["recoverable_corruption"] == false).is_true()
		assert_bool(not store.save_main(state, "invalid_fixture")["ok"]).is_true()
		assert_bool(FileAccess.get_file_as_bytes(fixture["owner"]._save_directory.path_join("main.json")) == before).is_true()
	assert_bool(var_to_bytes(fixture["core"].snapshot()) == inventory_before).is_true()
	assert_int(store.last_sequence).is_equal(1)

func test_schema4_file_is_refused_without_grant_migration_or_fallback() -> void:
	var fixture := _fixture()
	var owner: Node = fixture["owner"]
	var legacy: RefCounted = owner._make_save_store()
	_stores.append(legacy)
	assert_int(legacy._schema_version).is_equal(4)
	assert_bool(legacy.acquire()["ok"] and legacy.load_latest().get("new_world", false)).is_true()
	assert_bool(legacy.save_main(Combined.terrain_state(fixture["state"]), "schema4_fixture")["ok"]).is_true()
	var before := FileAccess.get_file_as_bytes(owner._save_directory.path_join("main.json"))
	legacy.close()
	var store := _open(fixture)
	assert_str(store.load_latest()["code"]).is_equal("UNSUPPORTED_SCHEMA")
	assert_bool(not store._write_ready).is_true()
	assert_bool(FileAccess.get_file_as_bytes(owner._save_directory.path_join("main.json")) == before).is_true()

func test_actual_main_write_failure_keeps_old_file_and_sequence() -> void:
	var fixture := _fixture()
	var store := _open(fixture)
	assert_bool(store.load_latest().get("new_world", false)).is_true()
	assert_bool(store.save_main(fixture["state"], "initial_fixture")["ok"]).is_true()
	var path: String = fixture["owner"]._save_directory
	var before := FileAccess.get_file_as_bytes(path.path_join("main.json"))
	assert_int(DirAccess.make_dir_absolute(path.path_join("main.json.tmp"))).is_equal(OK)
	var changed: Dictionary = fixture["state"].duplicate(true)
	changed["inventory_component"]["revision"] += 1
	var receipt: Dictionary = store.save_main(changed, "failure_fixture")
	assert_bool(not receipt["ok"] and not receipt.get("main_committed", false)).is_true()
	assert_int(store.last_sequence).is_equal(1)
	assert_bool(FileAccess.get_file_as_bytes(path.path_join("main.json")) == before).is_true()

func test_actual_backup_failure_reports_committed_main_without_replay() -> void:
	var fixture := _fixture()
	var store := _open(fixture)
	assert_bool(store.load_latest().get("new_world", false)).is_true()
	assert_bool(store.save_main(fixture["state"], "initial_fixture")["ok"]).is_true()
	var path: String = fixture["owner"]._save_directory
	assert_int(DirAccess.make_dir_absolute(path.path_join("auto/auto_02.json.tmp"))).is_equal(OK)
	var changed: Dictionary = fixture["state"].duplicate(true)
	changed["inventory_component"]["revision"] += 1
	var receipt: Dictionary = store.save_main(changed, "backup_failure_fixture")
	assert_bool(not receipt["ok"] and receipt.get("main_committed", false)).is_true()
	assert_str(receipt["code"]).is_equal("MAIN_SAVED_BACKUP_FAILED")
	assert_int(store.last_sequence).is_equal(2)
	store.close()
	store = _open(fixture)
	var loaded: Dictionary = store.load_latest()
	assert_bool(loaded["ok"] and loaded["sequence"] == 2).is_true()
	assert_bool(var_to_bytes(loaded["state"]) == var_to_bytes(changed)).is_true()

func test_combined_final_envelope_budget_precedes_file_commit() -> void:
	var fixture := _fixture()
	var store := _open(fixture)
	assert_bool(store.load_latest().get("new_world", false)).is_true()
	assert_bool(store.save_main(fixture["state"], "initial_fixture")["ok"]).is_true()
	var before := FileAccess.get_file_as_bytes(fixture["owner"]._save_directory.path_join("main.json"))
	var changed: Dictionary = fixture["state"].duplicate(true)
	# Exact measured growth of plain ASCII, independent of reference-world size.
	var baseline: String = fixture["contract"]._budget_store._encode(changed, Core.MAX_SEQUENCE, "manual", "W".repeat(64), 63)
	var padding: int = Combined.MAX_BYTES - baseline.to_utf8_buffer().size() + 1
	assert_bool(padding > 0).is_true()
	changed["inventory_component"]["players"][fixture["profile"]]["carry"]["state"]["technical_padding"] = "x".repeat(padding)
	assert_bool(fixture["core"].validate_snapshot(changed["inventory_component"])["ok"]).is_true()
	assert_str(fixture["contract"].validate_combined_state(changed)["code"]).is_equal("INVENTORY_WORLD_FINAL_ENVELOPE_TOO_LARGE")
	assert_bool(not store.save_main(changed, "oversize_fixture")["ok"]).is_true()
	assert_bool(not store.save_main(fixture["state"], "\"".repeat(65))["ok"]).is_true()
	assert_bool(FileAccess.get_file_as_bytes(fixture["owner"]._save_directory.path_join("main.json")) == before).is_true()
	assert_int(store.last_sequence).is_equal(1)

func test_invalid_main_inventory_does_not_fall_back_to_older_valid_backup() -> void:
	var fixture := _fixture()
	var store := _open(fixture)
	assert_bool(store.load_latest().get("new_world", false)).is_true()
	assert_bool(store.save_main(fixture["state"], "initial_fixture")["ok"]).is_true()
	var path: String = fixture["owner"]._save_directory.path_join("main.json")
	var changed: Dictionary = fixture["state"].duplicate(true)
	changed["inventory_component"]["players"].clear()
	# Intentional corrupt-contract fixture using the actual unvalidated serializer.
	var text: String = store._encode(changed, 2, "main", "invalid_fixture", 0)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_bool(file != null).is_true()
	file.store_string(text)
	file.close()
	store.close()
	store = _open(fixture)
	var loaded: Dictionary = store.load_latest()
	assert_str(loaded["code"]).is_equal("INVENTORY_WORLD_PROFILE_MISMATCH")
	assert_bool(not loaded["ok"] and not loaded.has("state") and not store._write_ready).is_true()
	assert_str(FileAccess.get_file_as_string(path)).is_equal(text)

func _dispose_owner(owner: Node) -> void:
	if owner._save_store != null: owner._save_store.close()
	if owner._actor_space != null: owner._actor_space.dispose()
	if owner._actor_model != null: owner._actor_model.release_runtime_sessions()
	_owners.erase(owner)
	owner.free()

func after_test() -> void:
	for store in _stores: store.close()
	_stores.clear()
	for owner in _owners.duplicate(): _dispose_owner(owner)
	for path in _paths: _remove_fixture(path)
	_paths.clear()

func _remove_fixture(path: String) -> void:
	if not path.begins_with(ProjectSettings.globalize_path("user://inventory_world012/")): return
	var directory := DirAccess.open(path)
	if directory == null: return
	directory.include_hidden = true
	for name in directory.get_files(): DirAccess.remove_absolute(path.path_join(name))
	for name in directory.get_directories(): _remove_fixture(path.path_join(name))
	DirAccess.remove_absolute(path)
