extends GdUnitTestSuite
## Finite source gate. Run only in a parent-approved Godot resource window.
const Registry = preload("res://scripts/inventory/inventory_save_profiles012.gd")
const Cold = preload("res://scripts/inventory/inventory_cold_validator012.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Combined = preload("res://scripts/inventory/inventory_world_session012.gd")
const BoundedStore = preload("res://scripts/inventory/inventory_world_save_store012.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const Owner = preload("res://scripts/actor/actor_terrain_network_main.gd")
const TerrainStore = preload("res://scripts/terrain/combined_terrain_store.gd")
const TerrainSession = preload("res://scripts/actor/actor_terrain_session_state.gd")
const ActorSession = preload("res://scripts/actor/actor_session_state.gd")
const World = preload("res://scripts/world_session/world_component.gd")
const Inputs = preload("res://scripts/actor/actor_inputs.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const WORLD := "world_11111111111111111111111111111111"
const OTHER := "world_22222222222222222222222222222222"
var _owners: Array = []
var _paths: Array[String] = []
var _stores: Array = []
var _reference_bytes := PackedByteArray()

func _document(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/" + name + ".json"))

func _empty_owner() -> Node:
	var owner := Owner.new()
	_owners.append(owner)
	owner._mode = "server"
	owner._arguments = {"seed": "42", "test_entry": "true"}
	owner._save_directory = ProjectSettings.globalize_path("user://inventory_profiles012/").path_join(Crypto.new().generate_random_bytes(16).hex_encode())
	_paths.append(owner._save_directory)
	owner._settings = _document("network_settings")
	owner._save_settings = _document("save_settings")
	assert_int(owner._catalogue.load_file()).is_equal(OK)
	owner._authority = SandboxServerAuthority.new(int(owner._settings["max_players"]), int(owner._settings["network_protocol_version"]), owner._catalogue.source_sha256, float(owner._save_settings["automatic_interval_seconds"]))
	# Keep the REAL newly allocated random world ID in all cold readers.
	owner._actor_inputs = Inputs.new()
	assert_bool(owner._actor_inputs.load_file()).is_true()
	owner._terrain_documents = [_document("generation_settings"), _document("prefab_settings"), _document("actor_world_bundle011")]
	var docs: Array = owner._terrain_documents
	owner._world = World.new(docs[0], docs[1], docs[2], "011")
	owner._actor_session = ActorSession.new(owner._world, owner._actor_inputs.document())
	owner._terrain_store = TerrainStore.new(docs[0], docs[1], docs[2])
	owner._terrain_session = TerrainSession.new(owner._actor_session, owner._terrain_store)
	assert_bool(owner._terrain_services_ready()).is_true()
	return owner

func _registry(owner: Node, path: String = "") -> RefCounted:
	return Registry.new(owner._terrain_session, owner._authority, owner._save_directory if path.is_empty() else path, int(owner._save_settings["automatic_backup_count"]), int(owner._save_settings["manual_slot_count"]))

func _make(registry: RefCounted, profile: int) -> RefCounted:
	var made: Dictionary = registry.make_store(profile)
	assert_bool(made["ok"]).is_true()
	_stores.append(made["store"])
	return made["store"]

func _reference_state() -> Dictionary:
	if _reference_bytes.is_empty():
		# Single cached generated technical fixture, outside the cold validator.
		var fresh := _empty_owner()
		fresh._authority.world_id = WORLD
		assert_bool(fresh._create_new_world()).is_true()
		var joined: Dictionary = fresh._authority.join(11, {"network_protocol_version": fresh._authority.protocol_version, "catalogue_sha256": fresh._authority.catalogue_hash, "display_name": "Save profile technical fixture", "resume_profile_id": "", "resume_secret": ""})
		assert_bool(joined["ok"]).is_true()
		var spawn: Dictionary = fresh._world.public_component()["layout"]["spawn"]
		var position := Vector2(spawn["cell"][0] + 0.5, spawn["cell"][1] + 0.5)
		assert_bool(fresh._actor_model.create_actor(joined["player_instance_id"], spawn["layer"], position, {"layer": spawn["layer"], "position": [position.x, position.y]})["ok"]).is_true()
		var base: Dictionary = fresh._actor_session.combine(fresh._authority.persistent_state(), fresh._actor_model)
		assert_bool(base["ok"]).is_true()
		var terrain: Dictionary = fresh._terrain_session.combine(base["state"], fresh._terrain_component)
		assert_bool(terrain["ok"]).is_true()
		var core := Core.new(WORLD)
		assert_bool(core.trusted_create_player(joined["player_profile_id"])["ok"]).is_true()
		assert_bool(core.trusted_create_chest("entity_fixture_chest")["ok"]).is_true()
		var snapshot: Dictionary = core.snapshot()
		snapshot["players"][joined["player_profile_id"]]["bag"][0] = {"content_id": "mucai", "quantity": 731, "item_instance_id": "", "protected_instance_id": "", "state": {}}
		assert_bool(core.trusted_restore(snapshot)["ok"]).is_true()
		var combined := Combined.new(fresh._terrain_session, core, fresh._authority)
		var state: Dictionary = combined.combine(terrain["state"], core.snapshot())
		assert_bool(state["ok"]).is_true()
		var encoded: Dictionary = Codec.encode(state["state"])
		assert_bool(encoded["ok"]).is_true()
		_reference_bytes = JSON.stringify(encoded["value"], "", true, true).to_utf8_buffer()
		assert_bool(_reference_bytes.size() <= Combined.MAX_BYTES).is_true()
		_dispose_owner(fresh)
	var decoded: Dictionary = Codec.decode(JSON.parse_string(_reference_bytes.get_string_from_utf8()))
	assert_bool(decoded["ok"]).is_true()
	return decoded["value"]

func _authority_bytes(owner: Node) -> PackedByteArray:
	var authority: RefCounted = owner._authority
	return var_to_bytes([authority.persistent_state(), authority.server_epoch, authority.catalogue_hash, authority.protocol_version, authority.max_players, authority.automatic_interval_seconds, authority._peer_profiles, authority._welcome_cache, authority._command_cache, authority._used_ids, authority._join_generation, authority._prepared_join])

func _assert_cold_owner(owner: Node, authority_before: PackedByteArray, world_before: PackedByteArray) -> void:
	assert_bool(_authority_bytes(owner) == authority_before).is_true()
	assert_bool(var_to_bytes(owner._world.public_component()) == world_before).is_true()
	assert_bool(owner._actor_model == null and owner._actor_space == null and owner._terrain_component.is_empty()).is_true()
	assert_bool(owner._terrain_generation_count == 0 and owner._terrain_stage_creation_count == 0 and owner._terrain_materialization_count == 0 and owner._terrain_restore_count == 0).is_true()
	var statistics: Dictionary = owner._world.statistics()
	assert_bool(statistics["generation_calls"] == 0 and statistics["instantiation_calls"] == 0 and statistics["world_seed_random_calls"] == 0).is_true()

func test_closed_profiles_preserve_original_schema4_store_and_validator() -> void:
	var owner := _empty_owner()
	var registry := _registry(owner)
	assert_bool(registry.ready).is_true()
	var store := _make(registry, 4)
	var original: RefCounted = owner._make_save_store()
	_stores.append(original)
	assert_bool(store.get_script() == SaveStore and store._state_validator == Callable(owner._terrain_session, "validate_combined_state")).is_true()
	for field in ["directory", "automatic_count", "manual_count", "_content_revision", "_network_protocol_version", "_state_validator", "_schema_version", "_maximum_bytes", "_exact_scalars"]:
		assert_bool(store.get(field) == original.get(field)).is_true()
	assert_bool(registry.verify_binding(4, store)["ok"]).is_true()
	for profile in [null, true, 4.0, "4", 0, 3, 7, {}, []]:
		assert_bool(not registry.descriptor(profile)["ok"] and not registry.make_store(profile)["ok"]).is_true()
	assert_bool(not Registry.platform_supported(5, "Windows") and Registry.platform_supported(4, "Windows")).is_true()
	if OS.get_name() == "Windows":
		assert_str(registry.make_store(5)["code"]).is_equal("INVENTORY_SAVE_SCHEMA5_WINDOWS_UNSUPPORTED")
	else:
		var inventory := _make(registry, 5)
		assert_bool(inventory.get_script() == BoundedStore and inventory._state_validator.get_object().get_script() == Cold).is_true()
		assert_bool(registry.verify_binding(5, inventory)["ok"]).is_true()
	assert_bool(not DirAccess.dir_exists_absolute(owner._save_directory)).is_true()

func test_bad_registry_inputs_and_authority_configuration_are_rejected() -> void:
	var owner := _empty_owner()
	for inputs in [[null, owner._authority, "x", 2, 2], [RefCounted.new(), owner._authority, "x", 2, 2], [owner._terrain_session, RefCounted.new(), "x", 2, 2], [owner._terrain_session, owner._authority, "", 2, 2], [owner._terrain_session, owner._authority, 9, 2, 2], [owner._terrain_session, owner._authority, "x", 2.0, 2], [owner._terrain_session, owner._authority, "x", 0, 2], [owner._terrain_session, owner._authority, "x", 65, 2], [owner._terrain_session, owner._authority, "x", 2, 64], [owner._terrain_session, owner._authority, "x", 2, true]]:
		var rejected := Registry.new(inputs[0], inputs[1], inputs[2], inputs[3], inputs[4])
		assert_bool(not rejected.ready and not rejected.make_store(4)["ok"]).is_true()
	for config in [["x".repeat(64), 3], ["a".repeat(63), 3], [[], 3], [owner._authority.catalogue_hash, 0], [owner._authority.catalogue_hash, 3.0], [owner._authority.catalogue_hash, true]]:
		assert_bool(not Cold.valid_configuration(config[0], config[1])).is_true()
	var hash: String = owner._authority.catalogue_hash
	owner._authority.catalogue_hash = "invalid"
	assert_bool(not _registry(owner).ready and not Cold.new(owner._terrain_session, owner._authority).ready).is_true()
	owner._authority.catalogue_hash = hash

func test_store_verification_rejects_wrong_profile_type_callback_config_and_world() -> void:
	var owner := _empty_owner()
	var registry := _registry(owner)
	var store := _make(registry, 4)
	assert_bool(not registry.verify_binding(4, RefCounted.new())["ok"]).is_true()
	assert_bool(not registry.verify_binding(5, store)["ok"]).is_true()
	for mutation in [["directory", "another_path"], ["automatic_count", 3], ["manual_count", 3], ["_content_revision", "b".repeat(64)], ["_network_protocol_version", 12], ["_schema_version", 5], ["_maximum_bytes", 1], ["_exact_scalars", false], ["_state_validator", Callable()]]:
		var original: Variant = store.get(mutation[0])
		store.set(mutation[0], mutation[1])
		assert_bool(not registry.verify_binding(4, store)["ok"]).is_true()
		store.set(mutation[0], original)
		assert_bool(registry.verify_binding(4, store)["ok"]).is_true()
	assert_bool(not registry.verify_binding(4, store, WORLD)["ok"]).is_true()
	store._world_id = WORLD
	assert_bool(registry.verify_binding(4, store, WORLD)["ok"]).is_true()
	assert_bool(not registry.verify_binding(4, store, OTHER)["ok"] and not registry.verify_binding(4, store, 4)["ok"]).is_true()
	if OS.get_name() != "Windows":
		var inventory := _make(registry, 5)
		inventory._generation_init_error = {"ok": false, "code": "fixture_rejected_generation"}
		assert_bool(not registry.verify_binding(5, inventory)["ok"]).is_true()
		inventory._generation_init_error.clear()
		var replacement := Cold.new(owner._terrain_session, owner._authority)
		inventory._state_validator = Callable(replacement, "validate_combined_state")
		assert_bool(not registry.verify_binding(5, inventory)["ok"]).is_true()
	var protocol: int = owner._authority.protocol_version
	owner._authority.protocol_version += 1
	assert_bool(not registry.verify_binding(4, store)["ok"]).is_true()
	assert_str(registry._cold.validate_combined_state({})["code"]).is_equal("INVENTORY_COLD_BINDING_CHANGED")
	owner._authority.protocol_version = protocol
	var legacy: RefCounted = owner._terrain_session._legacy
	owner._terrain_session._legacy = null
	assert_bool(not registry.verify_binding(4, store)["ok"]).is_true()
	owner._terrain_session._legacy = legacy

func test_cold_validation_accepts_saved_world_without_adoption_grants_or_activation() -> void:
	var state := _reference_state()
	var owner := _empty_owner()
	assert_str(owner._authority.world_id).is_not_equal(WORLD)
	var before := _authority_bytes(owner)
	var world_before := var_to_bytes(owner._world.public_component())
	var candidate_before := var_to_bytes(state)
	var live_inventory := Core.new(owner._authority.world_id)
	var inventory_before := var_to_bytes(live_inventory.snapshot())
	var cold := Cold.new(owner._terrain_session, owner._authority)
	assert_bool(cold.validate_combined_state(state)["ok"]).is_true()
	var candidate_inventory := Core.new(WORLD)
	assert_bool(not Combined.new(owner._terrain_session, candidate_inventory, owner._authority).ready).is_true()
	var scoped := Combined.new(owner._terrain_session, candidate_inventory, owner._authority, WORLD)
	assert_bool(scoped.ready).is_true()
	for metadata in [[], {}, true]:
		var malformed: Dictionary = state.duplicate(true)
		malformed["inventory_contract"] = metadata
		assert_bool(not scoped.validate_combined_state(malformed)["ok"]).is_true()
	assert_bool(not Combined.new(owner._terrain_session, candidate_inventory, owner._authority, "world_bad").ready).is_true()
	assert_bool(not Combined.new(owner._terrain_session, candidate_inventory, owner._authority, OTHER).ready).is_true()
	assert_bool(var_to_bytes(state) == candidate_before and var_to_bytes(live_inventory.snapshot()) == inventory_before).is_true()
	_assert_cold_owner(owner, before, world_before)

func test_cold_rejections_cover_contracts_world_profiles_and_bad_field_types() -> void:
	var state := _reference_state()
	var owner := _empty_owner()
	var cold := Cold.new(owner._terrain_session, owner._authority)
	var before := _authority_bytes(owner)
	var world_before := var_to_bytes(owner._world.public_component())
	var profile: String = state["profiles"].keys()[0]
	for mutation in ["old", "unknown", "contract_type", "invalid_world", "world_type", "world_binding", "inventory_world", "profile_set", "profile_type", "inventory_type", "inventory_contract_type", "rules_type", "chest_type", "quantity_type", "schema_type", "actor_type"]:
		var changed: Dictionary = state.duplicate(true)
		match mutation:
			"old": changed.erase("inventory_component")
			"unknown": changed["future"] = true
			"contract_type": changed["inventory_contract"] = []
			"invalid_world": changed["world_id"] = "world_bad"
			"world_type": changed["world_id"] = 17
			"world_binding": changed["world_id"] = OTHER
			"inventory_world": changed["inventory_component"]["world_id"] = OTHER
			"profile_set": changed["inventory_component"]["players"].clear()
			"profile_type": changed["profiles"][profile] = []
			"inventory_type": changed["inventory_component"] = []
			"inventory_contract_type": changed["inventory_component"]["contract"] = {}
			"rules_type": changed["inventory_component"]["rules_sha256"] = []
			"chest_type": changed["inventory_component"]["chests"]["entity_fixture_chest"]["content_id"] = []
			"quantity_type": changed["inventory_component"]["players"][profile]["bag"][0]["quantity"] = 731.0
			"schema_type": changed["inventory_component"]["schema_version"] = true
			"actor_type": changed["actor_component"]["project"] = {}
		var unchanged := var_to_bytes(changed)
		var rejected: Dictionary = cold.validate_combined_state(changed)
		assert_bool(not rejected["ok"] and rejected["recoverable_corruption"] == false).is_true()
		assert_bool(var_to_bytes(changed) == unchanged).is_true()
	for field in ["inventory_contract", "contract", "rules_sha256"]:
		for metadata in [[], {}, true]:
			var changed: Dictionary = state.duplicate(true)
			if field == "inventory_contract": changed[field] = metadata
			else: changed["inventory_component"][field] = metadata
			var unchanged := var_to_bytes(changed)
			var rejected: Dictionary = cold.validate_combined_state(changed)
			assert_bool(not rejected["ok"] and rejected["recoverable_corruption"] == false).is_true()
			assert_bool(var_to_bytes(changed) == unchanged).is_true()
	_assert_cold_owner(owner, before, world_before)

func test_real_store_cold_load_preserves_fresh_authority_and_saved_exact_state() -> void:
	if OS.get_name() == "Windows":
		assert_bool(not Registry.platform_supported(5, OS.get_name())).is_true()
		return
	var state := _reference_state()
	var writer := _empty_owner()
	var registry := _registry(writer)
	var store := _make(registry, 5)
	assert_bool(store.acquire()["ok"] and store.load_latest().get("new_world", false)).is_true()
	assert_bool(store.save_main(state, "profile_fixture")["ok"]).is_true()
	var saved := FileAccess.get_file_as_bytes(writer._save_directory.path_join("main.json"))
	store.close()
	var reader := _empty_owner()
	assert_str(reader._authority.world_id).is_not_equal(WORLD)
	var before := _authority_bytes(reader)
	var world_before := var_to_bytes(reader._world.public_component())
	registry = _registry(reader, writer._save_directory)
	store = _make(registry, 5)
	assert_bool(store.acquire()["ok"]).is_true()
	var loaded: Dictionary = store.load_latest()
	assert_bool(loaded["ok"] and var_to_bytes(loaded["state"]) == var_to_bytes(state)).is_true()
	assert_bool(registry.verify_binding(5, store, WORLD)["ok"]).is_true()
	assert_bool(FileAccess.get_file_as_bytes(writer._save_directory.path_join("main.json")) == saved).is_true()
	_assert_cold_owner(reader, before, world_before)

func test_cross_profile_envelopes_refuse_migration_in_both_directions() -> void:
	if OS.get_name() == "Windows":
		assert_bool(not Registry.platform_supported(5, OS.get_name())).is_true()
		return
	var state := _reference_state()
	var owner := _empty_owner()
	var registry := _registry(owner)
	var old_store := _make(registry, 4)
	var new_store := _make(registry, 5)
	var old_text: String = old_store._encode(Combined.terrain_state(state), 1, "main", "profile_fixture", 0)
	var new_text: String = new_store._encode(state, 1, "main", "profile_fixture", 0)
	assert_bool(old_store._decode_text(old_text)["ok"] and new_store._decode_text(new_text)["ok"]).is_true()
	assert_str(old_store._decode_text(new_text)["code"]).is_equal("UNSUPPORTED_SCHEMA")
	assert_str(new_store._decode_text(old_text)["code"]).is_equal("UNSUPPORTED_SCHEMA")
	assert_bool(not old_store._write_ready and not new_store._write_ready and not DirAccess.dir_exists_absolute(owner._save_directory)).is_true()

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
	if not path.begins_with(ProjectSettings.globalize_path("user://inventory_profiles012/")): return
	var directory := DirAccess.open(path)
	if directory == null: return
	directory.include_hidden = true
	for name in directory.get_files(): DirAccess.remove_absolute(path.path_join(name))
	for name in directory.get_directories(): _remove_fixture(path.path_join(name))
	DirAccess.remove_absolute(path)
