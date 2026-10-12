extends GdUnitTestSuite
## Offline technical fixture authoring. Uses real Store+Slots cold inspection.
## Never calls finish_session, fabricates child exits, or labels normal_shutdown.
const Fixture = preload("res://tests/inventory/InventoryWorldSave012Test.gd")
const Slots = preload("res://scripts/actor/actor_local_save_slots.gd")
const SessionIdentity = preload("res://tests/support/session_identity.gd")
var fixtures
var slots: RefCounted
var store: RefCounted
func after_test() -> void:
	if store != null: store.close()
	if slots != null and slots.ready: slots.close()
	if fixtures != null:
		fixtures.after_test()
		fixtures.free()

func test_prepare_explicit_offline_gui_drop_fixture() -> void:
	if not _require_test_identity(): return
	var expected := OS.get_environment("SANDBOX_GUI_USER_ROOT")
	assert_bool(not expected.is_empty()).is_true()
	assert_str(OS.get_user_data_dir()).is_equal(expected)
	if expected.is_empty() or OS.get_user_data_dir() != expected: return
	assert_bool(not DirAccess.dir_exists_absolute(expected.path_join("local_play011"))).is_true()
	if DirAccess.dir_exists_absolute(expected.path_join("local_play011")): return
	slots = Slots.new()
	assert_bool(slots.configure()["ok"]).is_true()
	var created: Dictionary = slots.create_slot("掉落GUI夹具 · 非正常获取", 5)
	assert_bool(created["ok"]).is_true()
	var slot: String = created["slot_id"]
	var paths: Dictionary = slots._paths(slot, slot)
	fixtures = Fixture.new()
	var source: Dictionary = fixtures._fixture()
	var state: Dictionary = source["state"]
	var profile: String = source["profile"]
	var inventory: Dictionary = state["inventory_component"]
	var player: Dictionary = inventory["players"][profile]
	player["bag"][2] = player["carry"] # Unique technical gun, no duplication.
	player["carry"] = player["bag"][0].duplicate(true)
	player["carry"]["quantity"] = 7
	player["carry_origin"] = {"container":"bag", "owner":profile, "slot":0}
	player["bag"][0]["quantity"] = 997
	player["hotbar"][0] = player["carry"].duplicate(true)
	player["hotbar"][0]["quantity"] = 10
	inventory["revision"] += 1
	state["profiles"][profile]["secret_hash"] = resume_secret().sha256_text()
	state["profiles"][profile]["display_name"] = "掉落GUI技术夹具"
	state["next_auto_due_world_seconds"] = 0.0
	store = source["contract"].make_store(paths["world_directory"], 2, 2)
	assert_bool(store.acquire()["ok"]).is_true()
	assert_bool(store.load_latest().get("new_world", false)).is_true()
	var saved: Dictionary = store.save_main(state, "inventory_gui_fixture")
	assert_bool(saved.get("ok", false)).is_true()
	store.close()
	var identity := FileAccess.open(paths["identity_path"], FileAccess.WRITE)
	assert_object(identity).is_not_null()
	identity.store_string(JSON.stringify({"player_profile_id":profile, "resume_secret":resume_secret()}))
	identity.close()
	var inspected: Dictionary = slots.inspect_save(slot)
	assert_bool(inspected.get("ok", false) and inspected.get("reason") == "inventory_gui_fixture").is_true()
	assert_bool(var_to_bytes(inspected["state"]) == var_to_bytes(state)).is_true()
	assert_bool(not DirAccess.dir_exists_absolute(paths["world_directory"].path_join(".writer_lock"))).is_true()
	var changed: Dictionary = Slots.after_verified_save(slots._index, slot, state["world_id"], int(saved["sequence"]))
	assert_bool(changed["ok"]).is_true()
	assert_bool(slots._persist_index(changed["index"])["ok"]).is_true()
	var proof := FileAccess.open(expected.path_join("gui_fixture.json"), FileAccess.WRITE)
	proof.store_string(JSON.stringify({"kind":"explicit_offline_gui_inventory_fixture", "slot_id":slot, "profile_id":profile, "world_id":state["world_id"], "sequence":saved["sequence"], "main_sha256":FileAccess.get_sha256(paths["main_path"]), "save_reason":"inventory_gui_fixture", "normal_shutdown_receipt_created":false, "gui_verified":false, "bag0":997, "carry":7, "hotbar0":10, "last_sequence":19}))
	proof.close()

static func resume_secret() -> String:
	return SessionIdentity.read_resume_secret()

func _require_test_identity() -> bool:
	var available: bool = not resume_secret().is_empty()
	assert_bool(available).is_true()
	return available
