extends GdUnitTestSuite
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Plan = preload("res://scripts/inventory/inventory_drop_plan012.gd")
const WORLD := "world_11111111111111111111111111111111"
const PLAYER := "player_drop_fixture"
var core: RefCounted
func before_test() -> void:
	core = Core.new(WORLD)
	assert_bool(core.trusted_create_player(PLAYER)["ok"]).is_true()
func stack(n: int) -> Dictionary:
	return {"content_id": "mucai", "quantity": n, "item_instance_id": "", "protected_instance_id": "", "state": {}}
func address() -> Dictionary:
	return {"container": "bag", "owner": PLAYER, "slot": 0}
func _seed_fixture(n: int, refill: int = 0) -> void:
	var value: Dictionary = core.snapshot()
	value["players"][PLAYER]["bag"][0] = stack(n)
	assert_bool(core.trusted_restore(value)["ok"]).is_true()
	assert_bool(core.click_slot(PLAYER, address(), core.revision(), 1)["ok"]).is_true()
	if refill > 0:
		value = core.snapshot()
		value["players"][PLAYER]["bag"][0] = stack(refill)
		assert_bool(core.trusted_restore(value)["ok"]).is_true()
func run_plan(kind: String) -> Dictionary:
	return Plan.prepare(core, PLAYER, kind, address(), core.revision(), 2)
func record(id: String, n: int, position: Vector2, scope: String = "surface_body_a") -> Dictionary:
	return {"id": id, "scope": {"world_id": WORLD, "reference_frame": "celestial_local", "body_instance_id": "body_b" if scope == "surface_body_b" else "body_a", "map_kind": "underground" if scope == "underground_body_a" else "surface", "depth": 1 if scope == "underground_body_a" else 0}, "position": position, "stack": stack(n)}
func test_odd_half_returns_ceil_and_keeps_original_untouched() -> void:
	_seed_fixture(7)
	var before: PackedByteArray = var_to_bytes(core.snapshot())
	var result: Dictionary = run_plan("right_half")
	assert_bool(result["ok"]).is_true()
	assert_str(result["action"]).is_equal("half_return")
	assert_int(result["inventory"]["players"][PLAYER]["bag"][0]["quantity"]).is_equal(4)
	assert_int(result["inventory"]["players"][PLAYER]["carry"]["quantity"]).is_equal(3)
	assert_that(result["drop"]).is_null()
	assert_bool(var_to_bytes(core.snapshot()) == before).is_true()
func test_half_cannot_fit_drops_whole_half_no_partial_fill() -> void:
	_seed_fixture(7, 997)
	var result: Dictionary = run_plan("right_half")
	assert_int(result["drop"]["quantity"]).is_equal(4)
	assert_int(result["inventory"]["players"][PLAYER]["bag"][0]["quantity"]).is_equal(997)
	assert_int(result["inventory"]["players"][PLAYER]["carry"]["quantity"]).is_equal(3)
func test_half_exact_capacity_returns_all() -> void:
	_seed_fixture(7, 995)
	var result: Dictionary = run_plan("right_half")
	assert_that(result["drop"]).is_null()
	assert_int(result["inventory"]["players"][PLAYER]["bag"][0]["quantity"]).is_equal(999)
func test_single_carry_half_clears_origin() -> void:
	_seed_fixture(1)
	var result: Dictionary = run_plan("right_half")
	assert_that(result["inventory"]["players"][PLAYER]["carry"]).is_null()
	assert_that(result["inventory"]["players"][PLAYER]["carry_origin"]).is_null()
func test_carry_all_drops_whole_stack() -> void:
	_seed_fixture(7)
	var result: Dictionary = run_plan("carry_all")
	assert_int(result["drop"]["quantity"]).is_equal(7)
	assert_that(result["inventory"]["players"][PLAYER]["carry"]).is_null()
func test_q_drops_one_slot_item_not_carry() -> void:
	_seed_fixture(7, 9)
	var value: Dictionary = core.snapshot()
	value["players"][PLAYER]["hotbar"][0] = stack(9)
	assert_bool(core.trusted_restore(value)["ok"]).is_true()
	var result: Dictionary = Plan.prepare(core, PLAYER, "q_one", {"container": "hotbar", "owner": PLAYER, "slot": 0}, core.revision(), 2)
	assert_int(result["drop"]["quantity"]).is_equal(1)
	assert_int(result["inventory"]["players"][PLAYER]["hotbar"][0]["quantity"]).is_equal(8)
	assert_int(result["inventory"]["players"][PLAYER]["bag"][0]["quantity"]).is_equal(9)
	assert_int(result["inventory"]["players"][PLAYER]["carry"]["quantity"]).is_equal(7)
func test_q_bag_and_authorized_chest_are_rejected_without_mutation() -> void:
	_seed_fixture(7, 9)
	assert_bool(core.trusted_create_chest("chest_fixture")["ok"]).is_true()
	var value: Dictionary = core.snapshot()
	value["chests"]["chest_fixture"]["slots"][0] = stack(5)
	assert_bool(core.trusted_restore(value)["ok"]).is_true()
	assert_bool(core.trusted_set_chest_access(PLAYER, "chest_fixture", true)["ok"]).is_true()
	var before: PackedByteArray = var_to_bytes(core.snapshot())
	for source in [address(), {"container": "chest", "owner": "chest_fixture", "slot": 0}]:
		var result: Dictionary = Plan.prepare(core, PLAYER, "q_one", source, core.revision(), 2)
		assert_bool(result["ok"]).is_false()
		assert_str(result["code"]).is_equal("DROP_Q_HOTBAR_REQUIRED")
		assert_bool(var_to_bytes(core.snapshot()) == before).is_true()
func test_q_foreign_owner_and_invalid_hotbar_slots_keep_original_address_gate() -> void:
	_seed_fixture(7, 9)
	var before: PackedByteArray = var_to_bytes(core.snapshot())
	for source in [{"container": "hotbar", "owner": "player_other", "slot": 0}, {"container": "hotbar", "owner": PLAYER, "slot": -1}, {"container": "hotbar", "owner": PLAYER, "slot": 10}]:
		var result: Dictionary = Plan.prepare(core, PLAYER, "q_one", source, core.revision(), 2)
		assert_bool(result["ok"]).is_false()
		assert_str(result["code"]).is_equal("INVENTORY_ADDRESS_INVALID")
		assert_bool(var_to_bytes(core.snapshot()) == before).is_true()
func test_q_empty_hotbar_does_not_fall_back_to_bag_or_carry() -> void:
	_seed_fixture(7, 9)
	var before: PackedByteArray = var_to_bytes(core.snapshot())
	var result: Dictionary = Plan.prepare(core, PLAYER, "q_one", {"container": "hotbar", "owner": PLAYER, "slot": 0}, core.revision(), 2)
	assert_bool(result["ok"]).is_false()
	assert_str(result["code"]).is_equal("INVENTORY_EMPTY_SLOT")
	assert_bool(var_to_bytes(core.snapshot()) == before).is_true()
func test_stale_revision_or_sequence_rejected() -> void:
	_seed_fixture(7)
	assert_bool(Plan.prepare(core, PLAYER, "carry_all", address(), core.revision() - 1, 2)["ok"]).is_false()
	assert_bool(Plan.prepare(core, PLAYER, "carry_all", address(), core.revision(), 1)["ok"]).is_false()
func test_merge_one_cell_boundary_and_overflow() -> void:
	var incoming: Dictionary = record("drop_z", 10, Vector2.ZERO)
	var existing: Array = [record("drop_a", 995, Vector2(1, 0))]
	var before: PackedByteArray = var_to_bytes([incoming, existing])
	var result: Dictionary = Plan.merge_nearby(core, incoming, existing)
	assert_bool(result["ok"]).is_true()
	assert_int(result["records"][0]["stack"]["quantity"]).is_equal(999)
	assert_int(result["records"][1]["stack"]["quantity"]).is_equal(6)
	assert_bool(var_to_bytes([incoming, existing]) == before).is_true()
func test_different_layer_or_body_and_outside_radius_do_not_merge() -> void:
	var existing: Array = [record("drop_a", 1, Vector2.ZERO, "underground_body_a"), record("drop_b", 1, Vector2(1.001, 0)), record("drop_c", 1, Vector2.ZERO, "surface_body_b")]
	var result: Dictionary = Plan.merge_nearby(core, record("drop_z", 10, Vector2.ZERO), existing)
	assert_int(result["records"].size()).is_equal(4)
func test_stable_id_order_independent_of_input_order() -> void:
	var a: Dictionary = record("drop_a", 995, Vector2.ZERO)
	var b: Dictionary = record("drop_b", 995, Vector2.ZERO)
	var incoming: Dictionary = record("drop_z", 6, Vector2.ZERO)
	var first: Dictionary = Plan.merge_nearby(core, incoming, [b, a])
	var second: Dictionary = Plan.merge_nearby(core, incoming, [a, b])
	assert_bool(var_to_bytes(first) == var_to_bytes(second)).is_true()
func test_duplicate_drop_id_and_nonfinite_position_rejected() -> void:
	assert_bool(Plan.merge_nearby(core, record("drop_a", 1, Vector2.ZERO), [record("drop_a", 1, Vector2.ZERO)])["ok"]).is_false()
	assert_bool(Plan.merge_nearby(core, record("drop_a", 1, Vector2(NAN, 0)), [])["ok"]).is_false()

func test_unique_instances_never_merge_and_duplicate_identity_rejects() -> void:
	var a: Dictionary = record("drop_a", 1, Vector2.ZERO)
	a["stack"] = {"content_id": "wuqi_huoqi_tansuo_01", "quantity": 1, "item_instance_id": "item_a", "protected_instance_id": "protected_a", "state": {"ammo": 3}}
	var b: Dictionary = a.duplicate(true)
	b["id"] = "drop_b"
	assert_bool(Plan.merge_nearby(core, a, [b])["ok"]).is_false()
	b["stack"]["item_instance_id"] = "item_b"
	assert_bool(Plan.merge_nearby(core, a, [b])["ok"]).is_false()
	b["stack"]["protected_instance_id"] = "protected_b"
	assert_int(Plan.merge_nearby(core, a, [b])["records"].size()).is_equal(2)
func test_different_original_item_drops_half_without_swap() -> void:
	_seed_fixture(7, 9)
	var state: Dictionary = core.snapshot()
	state["players"][PLAYER]["bag"][0]["content_id"] = "shitou"
	assert_bool(core.trusted_restore(state)["ok"]).is_true()
	var result: Dictionary = run_plan("right_half")
	assert_int(result["drop"]["quantity"]).is_equal(4)
	assert_str(result["inventory"]["players"][PLAYER]["bag"][0]["content_id"]).is_equal("shitou")
func test_revoked_chest_access_drops_half_does_not_write_chest() -> void:
	assert_bool(core.trusted_create_chest("chest_fixture")["ok"]).is_true()
	var state: Dictionary = core.snapshot()
	state["chests"]["chest_fixture"]["slots"][0] = stack(7)
	assert_bool(core.trusted_restore(state)["ok"]).is_true()
	assert_bool(core.trusted_set_chest_access(PLAYER, "chest_fixture", true)["ok"]).is_true()
	assert_bool(core.click_slot(PLAYER, {"container": "chest", "owner": "chest_fixture", "slot": 0}, core.revision(), 1)["ok"]).is_true()
	core.close_view(PLAYER)
	var result: Dictionary = run_plan("right_half")
	assert_int(result["drop"]["quantity"]).is_equal(4)
	assert_that(result["inventory"]["chests"]["chest_fixture"]["slots"][0]).is_null()
