extends GdUnitTestSuite
## Explicit test-only producer. Never invoked by ordinary startup/new-world.
const Fixture = preload("res://tests/inventory/InventoryWorldSave012Test.gd")
const Paths = preload("res://scripts/network/runtime_paths.gd")
const SessionIdentity = preload("res://tests/support/session_identity.gd")
func test_prepare_explicit_enet_fixture() -> void:
	if not _require_test_identity(): return
	var destination := OS.get_environment("SANDBOX_ENET_FIXTURE_ROOT")
	assert_str(Paths.scoped_path(ProjectSettings.globalize_path("res://"), PackedStringArray(), destination)).is_equal(destination)
	assert_bool(not destination.is_empty() and not DirAccess.dir_exists_absolute(destination)).is_true()
	if destination.is_empty() or DirAccess.dir_exists_absolute(destination): return
	var fixtures := Fixture.new()
	var fixture: Dictionary = fixtures._fixture()
	fixture["state"]["profiles"][fixture["profile"]]["secret_hash"] = resume_secret().sha256_text()
	fixture["state"]["profiles"][fixture["profile"]]["display_name"] = "Inventory ENet disconnect fixture"
	fixture["state"]["next_auto_due_world_seconds"] = 0.0
	var store: RefCounted = fixture["contract"].make_store(destination.path_join("world"), 2, 2)
	assert_bool(store.acquire().get("ok", false)).is_true()
	assert_bool(store.load_latest().get("new_world", false)).is_true()
	var saved: Dictionary = store.save_main(fixture["state"], "explicit_enet_inventory_fixture")
	assert_bool(saved.get("ok", false)).is_true()
	store.close()
	var file := FileAccess.open(destination.path_join("client_private_identity.json"), FileAccess.WRITE)
	assert_object(file).is_not_null()
	file.store_string(JSON.stringify({"player_profile_id":fixture["profile"], "resume_secret":resume_secret()}))
	file.close()
	file = FileAccess.open(destination.path_join("fixture_proof.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind":"explicit_technical_fixture_not_starting_grant", "saved":saved.get("ok", false), "profile":fixture["profile"], "carry_instance":"item_fixture_gun", "bag0_quantity":731, "last_sequence":19}))
	file.close()
	fixtures.after_test()
	fixtures.free()

static func resume_secret() -> String:
	return SessionIdentity.read_resume_secret()

func _require_test_identity() -> bool:
	var available: bool = not resume_secret().is_empty()
	assert_bool(available).is_true()
	return available
