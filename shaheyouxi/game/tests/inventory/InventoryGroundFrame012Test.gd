extends GdUnitTestSuite
## Finite production-owner/Frame/Store integration, with no sockets or UI.
## Tests are separately selectable for approved <=60-second engine batches.
## Items exist only in the isolated technical fixture, never in new-world code.
const Fixture = preload("res://tests/inventory/InventoryWorldSave012Test.gd")
const Owner = preload("res://scripts/actor/actor_terrain_network_main.gd")
const InventoryOwner = preload("res://scripts/inventory/inventory_owner012.gd")
const Profiles = preload("res://scripts/inventory/inventory_save_profiles012.gd")
const Combined = preload("res://scripts/inventory/inventory_world_session012.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const SessionIdentity = preload("res://tests/support/session_identity.gd")
var _fixtures

func before() -> void:
	_fixtures = Fixture.new()

func after_test() -> void:
	_fixtures.after_test()

func after() -> void:
	_fixtures.free()

func _owner(profile: int = 5, path: String = "") -> Node:
	var owner: Node = _fixtures._empty_owner()
	owner._arguments["save_profile"] = str(profile)
	owner._save_settings["automatic_backup_count"] = 2
	owner._save_settings["manual_slot_count"] = 2
	# Retain a genuinely fresh random authority identity until validated restore.
	owner._authority = SandboxServerAuthority.new(int(owner._settings["max_players"]), int(owner._settings["network_protocol_version"]), owner._catalogue.source_sha256, float(owner._save_settings["automatic_interval_seconds"]))
	if not path.is_empty(): owner._save_directory = path
	assert_bool(owner.get_script() == Owner and not owner.is_inside_tree()).is_true()
	owner._save_store = owner._make_save_store()
	assert_object(owner._save_store).is_not_null()
	return owner

func _open(owner: Node) -> Dictionary:
	assert_bool(owner._save_store.acquire()["ok"]).is_true()
	return owner._save_store.load_latest()

func _runtime(owner: Node) -> void:
	assert_bool(await owner._prepare_runtime_before_listen()).is_true()
	assert_bool(owner._bootstrap_frame.status()["save_ready"]).is_true()

func _hello(owner: Node, profile: String = "") -> Dictionary:
	if not _require_test_identity(): return {}
	return {"network_protocol_version": owner._authority.protocol_version, "catalogue_sha256": owner._authority.catalogue_hash, "display_name": "Inventory owner save integration", "resume_profile_id": profile, "resume_secret": resume_secret() if not profile.is_empty() else ""}

func _presence(owner: Node, hello: Dictionary) -> Dictionary:
	var prepared: Dictionary = owner._bootstrap_frame.prepare_bootstrap_presence(11, hello, false)
	assert_bool(prepared.get("ok", false) and prepared.get("prepared", false)).is_true()
	var committed: Dictionary = owner._bootstrap_frame.commit_bootstrap_presence(prepared["ticket"])
	assert_bool(committed.get("pending", false) and committed.get("committed", false)).is_true()
	await get_tree().physics_frame
	var confirmed: Dictionary = owner._bootstrap_frame.confirm_bootstrap_presence(prepared["ticket"])
	assert_bool(confirmed.get("ok", false) and confirmed.get("confirmed", false)).is_true()
	return confirmed

func _fixture_state() -> Dictionary:
	if not _require_test_identity(): return {}
	var fixture: Dictionary = _fixtures._fixture()
	var state: Dictionary = fixture["state"]
	var profile: String = fixture["profile"]
	state["profiles"][profile]["display_name"] = "Inventory owner save integration"
	state["profiles"][profile]["secret_hash"] = resume_secret().sha256_text()
	state["next_auto_due_world_seconds"] = 0.0
	_fixtures._dispose_owner(fixture["owner"])
	return state

func _loaded_fixture() -> Node:
	var state := _fixture_state()
	var owner := _owner()
	assert_bool(_open(owner).get("new_world", false)).is_true()
	assert_str(owner._authority.world_id).is_not_equal(state["world_id"])
	assert_bool(owner._restore_authority_state(state)["ok"]).is_true()
	await _runtime(owner)
	return owner

func _payload(path: String) -> Dictionary:
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("main.json")))
	var decoded: Dictionary = Codec.decode(JSON.parse_string(envelope["payload_json"]))
	assert_bool(decoded["ok"]).is_true()
	assert_int(decoded["value"]["save_schema_version"]).is_equal(5)
	return decoded["value"]["state"]

func _no_inventory(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if key in ["inventory_component", "inventory_contract", "bag", "hotbar", "carry", "carry_origin", "last_sequence", "secret_hash", "resume_secret"] or not _no_inventory(value[key]): return false
	elif value is Array:
		for child in value:
			if not _no_inventory(child): return false
	return true

func _assert_receipt(owner: Node, result: Dictionary) -> void:
	assert_bool(result.get("ok", false) and result.get("main_committed", false)).is_true()
	var state := _payload(owner._save_directory)
	var encoded: Dictionary = Codec.encode(state)
	assert_str(result["save_receipt"]["state_sha256"]).is_equal(JSON.stringify(encoded["value"], "", true, true).sha256_text())
	assert_int(result["save_receipt"]["store_id"]).is_equal(owner._save_store.get_instance_id())
	assert_int(result["save_receipt"]["owner_id"]).is_equal(owner._bootstrap_frame.get_instance_id())
	assert_bool(_no_inventory(result)).is_true()


func test_actual_frame_drop_half_inflight_save_cold_restore_exact() -> void:
	var state := _fixture_state()
	var profile: String = state["inventory_component"]["players"].keys()[0]
	var player: Dictionary = state["inventory_component"]["players"][profile]
	# Explicit isolated refill fixture. No ordinary startup grant is changed.
	player["hotbar"][0] = player["carry"]
	player["bag"][0]["quantity"] = 997
	player["carry"] = player["bag"][0].duplicate(true)
	player["carry"]["quantity"] = 7
	player["carry_origin"] = {"container": "bag", "owner": profile, "slot": 0}
	var owner := _owner()
	assert_bool(_open(owner).get("new_world", false)).is_true()
	assert_bool(owner._restore_authority_state(state)["ok"]).is_true()
	await _runtime(owner)
	await _presence(owner, _hello(owner, profile))
	var before: Dictionary = owner._inventory_owner.snapshot()
	var result: Dictionary = owner._bootstrap_frame.apply_confirmed_inventory_drop(owner, profile, "right_half", {"container": "bag", "owner": profile, "slot": 0}, before["revision"], 20, Vector2.RIGHT)
	assert_bool(result.get("ok", false)).is_true()
	assert_int(owner._inventory_owner.snapshot()["players"][profile]["bag"][0]["quantity"]).is_equal(997)
	assert_int(owner._inventory_owner.snapshot()["players"][profile]["carry"]["quantity"]).is_equal(3)
	assert_int(owner._inventory_owner.snapshot()["ground"].values()[0]["stack"]["quantity"]).is_equal(4)
	assert_bool(not FileAccess.file_exists(owner._save_directory.path_join("main.json"))).is_true()
	var submitted: Dictionary = owner._bootstrap_frame.submit(0.25, [])
	assert_bool(submitted.get("pending", false)).is_true()
	await get_tree().physics_frame
	assert_bool(owner._bootstrap_frame.confirm(submitted["ticket"]).get("confirmed", false)).is_true()
	assert_bool(owner._bootstrap_frame.advance_confirmed_ground(owner)["ok"]).is_true()
	var expected: Dictionary = owner._inventory_owner.snapshot()
	assert_float(expected["ground_clock"]).is_equal(owner._authority.world_seconds)
	assert_float(expected["ground"].values()[0]["trajectory"]["remaining_seconds"]).is_equal(0.25)
	_assert_receipt(owner, owner._commit_confirmed_save("normal_shutdown"))
	var path: String = owner._save_directory
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path.path_join("main.json"))
	_fixtures._dispose_owner(owner)
	var restored := _owner(5, path)
	var loaded := _open(restored)
	assert_bool(loaded["ok"]).is_true()
	assert_bool(restored._restore_authority_state(loaded["state"])["ok"]).is_true()
	assert_bool(var_to_bytes(expected) == var_to_bytes(restored._inventory_owner.snapshot())).is_true()
	assert_bool(FileAccess.get_file_as_bytes(path.path_join("main.json")) == bytes).is_true()
	assert_int(restored._terrain_generation_count).is_equal(0)
	assert_bool(restored._authority.active_peer_ids().is_empty()).is_true()

func test_actual_frame_q_and_whole_carry_preserve_unique_instance_in_ground_save() -> void:
	var owner: Node = await _loaded_fixture()
	var profile: String = owner._inventory_owner.snapshot()["players"].keys()[0]
	await _presence(owner, _hello(owner, profile))
	var frame: RefCounted = owner._bootstrap_frame
	var address := {"container": "bag", "owner": profile, "slot": 0}
	assert_bool(frame.apply_confirmed_inventory_drop(owner, profile, "q_one", address, owner._inventory_owner.revision(), 20, Vector2.RIGHT)["ok"]).is_true()
	assert_int(owner._inventory_owner.snapshot()["players"][profile]["bag"][0]["quantity"]).is_equal(730)
	assert_bool(frame.apply_confirmed_inventory_drop(owner, profile, "carry_all", address, owner._inventory_owner.revision(), 21, Vector2.RIGHT)["ok"]).is_true()
	var value: Dictionary = owner._inventory_owner.snapshot()
	assert_that(value["players"][profile]["carry"]).is_null()
	assert_int(value["ground"].size()).is_equal(2)
	var guns: int = 0
	for record in value["ground"].values():
		if record["stack"]["item_instance_id"] == "item_fixture_gun":
			guns += 1
			assert_str(record["stack"]["protected_instance_id"]).is_equal("protected_fixture_gun")
			assert_bool(var_to_bytes(record["stack"]["state"]["bits"]) == var_to_bytes(-0.0)).is_true()
	assert_int(guns).is_equal(1)
	var before: String = owner._inventory_owner.boundary_token()
	assert_bool(frame.apply_confirmed_inventory_drop(owner, profile, "carry_all", address, owner._inventory_owner.revision(), 21, Vector2.RIGHT)["ok"]).is_false()
	assert_str(owner._inventory_owner.boundary_token()).is_equal(before)
	_assert_receipt(owner, owner._commit_confirmed_save("normal_shutdown"))
	assert_bool(var_to_bytes(_payload(owner._save_directory)["inventory_component"]) == var_to_bytes(value)).is_true()

static func resume_secret() -> String:
	return SessionIdentity.read_resume_secret()

func _require_test_identity() -> bool:
	var available: bool = not resume_secret().is_empty()
	assert_bool(available).is_true()
	return available
