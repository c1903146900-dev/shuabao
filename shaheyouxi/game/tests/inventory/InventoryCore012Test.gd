extends GdUnitTestSuite
## Controlled standalone fixtures, not runtime loot creation or UI/pickup proof.
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const WORLD := "world_11111111111111111111111111111111"
const A := "player_inventory_fixture_a"
const B := "player_inventory_fixture_b"
const CHEST := "entity_inventory_chest_fixture"
const GUN := "wuqi_huoqi_tansuo_01"
var _core: RefCounted

func before_test() -> void:
	_core = Core.new(WORLD)
	assert_bool(_core.ready).is_true()
	assert_bool(_core.trusted_create_player(A)["ok"]).is_true()
	assert_bool(_core.trusted_create_player(B)["ok"]).is_true()
	assert_bool(_core.trusted_create_chest(CHEST)["ok"]).is_true()

func _plain(content: String, count: int) -> Dictionary:
	return {"content_id": content, "quantity": count, "item_instance_id": "", "protected_instance_id": "", "state": {}}

func _gun(id: String, protected: String = "") -> Dictionary:
	# Opaque transport fixture; no claim these invented state field names are the
	# final combat schema, weapon capacity or an actual newly created firearm.
	return {"content_id": GUN, "quantity": 1, "item_instance_id": id, "protected_instance_id": protected, "state": {"fixture_magazine_remaining": 3, "fixture_capacity": 12, "nested": {"bits": -0.0, "label": "keep"}}}

func _address(kind: String, slot: int, owner: String = A) -> Dictionary:
	return {"container": kind, "owner": owner, "slot": slot}

func _seed(bag: Dictionary, hotbar: Dictionary = {}, chest: Dictionary = {}) -> void:
	var state: Dictionary = _core.snapshot()
	for slot in bag: state["players"][A]["bag"][slot] = bag[slot]
	for slot in hotbar: state["players"][A]["hotbar"][slot] = hotbar[slot]
	for slot in chest: state["chests"][CHEST]["slots"][slot] = chest[slot]
	assert_bool(_core.trusted_restore(state)["ok"]).is_true()

func _click(address: Dictionary, sequence: int, profile: String = A) -> Dictionary:
	return _core.click_slot(profile, address, _core.revision(), sequence)

func test_original_base_capacities_are_independent_and_empty() -> void:
	var state: Dictionary = _core.snapshot()
	assert_int(state["players"][A]["bag"].size()).is_equal(40)
	assert_int(state["players"][A]["hotbar"].size()).is_equal(10)
	assert_int(state["chests"][CHEST]["slots"].size()).is_equal(30)
	assert_that(state["players"][A]["carry"]).is_null()
	assert_bool(_click(_address("bag", 0, B), 1)["ok"]).is_false()

func test_lift_is_immediate_server_carry_and_detached() -> void:
	_seed({0: _plain("mucai", 7)})
	assert_str(_click(_address("bag", 0), 1)["action"]).is_equal("lift")
	var state: Dictionary = _core.snapshot()
	assert_that(state["players"][A]["bag"][0]).is_null()
	assert_int(state["players"][A]["carry"]["quantity"]).is_equal(7)
	state["players"][A]["carry"]["quantity"] = 777
	assert_int(_core.snapshot()["players"][A]["carry"]["quantity"]).is_equal(7)

func test_place_into_independent_hotbar_conserves_quantity() -> void:
	_seed({0: _plain("mucai", 7)})
	assert_bool(_click(_address("bag", 0), 1)["ok"]).is_true()
	assert_str(_click(_address("hotbar", 9), 2)["action"]).is_equal("place")
	var state: Dictionary = _core.snapshot()
	assert_int(state["players"][A]["hotbar"][9]["quantity"]).is_equal(7)
	assert_that(state["players"][A]["carry"]).is_null()
	assert_that(state["players"][A]["carry_origin"]).is_null()

func test_partial_merge_respects_999_and_full_rejection_is_atomic() -> void:
	_seed({0: _plain("mucai", 900), 1: _plain("mucai", 200)})
	assert_bool(_click(_address("bag", 0), 1)["ok"]).is_true()
	assert_str(_click(_address("bag", 1), 2)["action"]).is_equal("merge")
	var state: Dictionary = _core.snapshot()
	assert_int(state["players"][A]["bag"][1]["quantity"]).is_equal(999)
	assert_int(state["players"][A]["carry"]["quantity"]).is_equal(101)
	var before: PackedByteArray = var_to_bytes(state)
	assert_str(_click(_address("bag", 1), 3)["code"]).is_equal("INVENTORY_STACK_FULL")
	assert_bool(var_to_bytes(_core.snapshot()) == before).is_true()

func test_swap_preserves_both_items_and_updates_carry_origin() -> void:
	_seed({0: _plain("mucai", 5)}, {0: _plain("shitou", 3)})
	assert_bool(_click(_address("bag", 0), 1)["ok"]).is_true()
	assert_str(_click(_address("hotbar", 0), 2)["action"]).is_equal("swap")
	var player: Dictionary = _core.snapshot()["players"][A]
	assert_str(player["hotbar"][0]["content_id"]).is_equal("mucai")
	assert_str(player["carry"]["content_id"]).is_equal("shitou")
	assert_int(player["carry"]["quantity"]).is_equal(3)
	assert_str(player["carry_origin"]["container"]).is_equal("hotbar")

func test_nonstackable_state_and_protected_identity_survive_transfer() -> void:
	var gun: Dictionary = _gun("item_fixture_one", "protected_fixture_one")
	_seed({0: gun})
	var before: PackedByteArray = var_to_bytes(gun)
	assert_bool(_click(_address("bag", 0), 1)["ok"]).is_true()
	assert_bool(_click(_address("hotbar", 0), 2)["ok"]).is_true()
	assert_bool(var_to_bytes(_core.snapshot()["players"][A]["hotbar"][0]) == before).is_true()

func test_two_instances_of_same_weapon_swap_never_merge() -> void:
	_seed({0: _gun("item_fixture_one"), 1: _gun("item_fixture_two")})
	assert_bool(_click(_address("bag", 0), 1)["ok"]).is_true()
	assert_str(_click(_address("bag", 1), 2)["action"]).is_equal("swap")
	assert_str(_core.snapshot()["players"][A]["carry"]["item_instance_id"]).is_equal("item_fixture_two")
	assert_int(_core.snapshot()["players"][A]["carry"]["quantity"]).is_equal(1)

func test_ui_close_does_not_overwrite_authoritatively_refilled_source() -> void:
	_seed({0: _plain("mucai", 7)})
	assert_bool(_click(_address("bag", 0), 1)["ok"]).is_true()
	# Explicit fixture setup models a later authorized arrival. No automatic
	# pickup implementation or item grant is claimed by this test.
	var refilled: Dictionary = _core.snapshot()
	refilled["players"][A]["bag"][0] = _plain("shitou", 2)
	assert_bool(_core.trusted_restore(refilled)["ok"]).is_true()
	var before: PackedByteArray = var_to_bytes(_core.snapshot())
	assert_bool(_core.close_view(A)["ok"]).is_true()
	assert_bool(var_to_bytes(_core.snapshot()) == before).is_true()
	assert_str(_core.snapshot()["players"][A]["bag"][0]["content_id"]).is_equal("shitou")
	assert_str(_core.snapshot()["players"][A]["carry"]["content_id"]).is_equal("mucai")

func test_competing_chest_takers_and_replay_do_not_duplicate() -> void:
	_seed({}, {}, {0: _plain("mucai", 8)})
	assert_bool(_core.trusted_set_chest_access(A, CHEST, true)["ok"]).is_true()
	assert_bool(_core.trusted_set_chest_access(B, CHEST, true)["ok"]).is_true()
	var before_revision: int = _core.revision()
	var address: Dictionary = _address("chest", 0, CHEST)
	assert_bool(_core.click_slot(A, address, before_revision, 1)["ok"]).is_true()
	var committed: PackedByteArray = var_to_bytes(_core.snapshot())
	assert_str(_core.click_slot(B, address, before_revision, 1)["code"]).is_equal("INVENTORY_STALE_REVISION")
	assert_str(_click(address, 1, B)["code"]).is_equal("INVENTORY_EMPTY_SLOT")
	assert_str(_click(address, 1)["code"]).is_equal("INVENTORY_STALE_SEQUENCE")
	assert_bool(var_to_bytes(_core.snapshot()) == committed).is_true()

func test_exact_snapshot_preserves_carry_and_replay_cursor_after_restore() -> void:
	_seed({0: _gun("item_fixture_one", "protected_fixture_one")})
	assert_bool(_click(_address("bag", 0), 17)["ok"]).is_true()
	var encoded: Dictionary = _core.encode_snapshot()
	assert_bool(encoded["ok"]).is_true()
	var restored := Core.new(WORLD)
	assert_bool(restored.decode_snapshot(encoded["bytes"])["ok"]).is_true()
	assert_bool(var_to_bytes(restored.snapshot()) == var_to_bytes(_core.snapshot())).is_true()
	assert_str(restored.click_slot(A, _address("hotbar", 0), restored.revision(), 17)["code"]).is_equal("INVENTORY_STALE_SEQUENCE")
	assert_bool(restored.click_slot(A, _address("hotbar", 0), restored.revision(), 18)["ok"]).is_true()

func test_duplicate_instance_and_external_protection_are_rejected_atomically() -> void:
	_seed({0: _gun("item_fixture_one", "protected_fixture_one")})
	var before: PackedByteArray = var_to_bytes(_core.snapshot())
	var duplicate: Dictionary = _core.snapshot()
	duplicate["chests"][CHEST]["slots"][0] = _gun("item_fixture_one", "protected_fixture_two")
	assert_bool(_core.trusted_restore(duplicate)["ok"]).is_false()
	duplicate = _core.snapshot()
	duplicate["external_protected_instance_ids"] = ["protected_fixture_one"]
	assert_bool(_core.trusted_restore(duplicate)["ok"]).is_false()
	assert_bool(var_to_bytes(_core.snapshot()) == before).is_true()

func test_malformed_quantities_unknown_content_and_address_refused() -> void:
	var before: PackedByteArray = var_to_bytes(_core.snapshot())
	for quantity in [0, -1, 1000, 1.0, true]:
		var malformed: Dictionary = _core.snapshot()
		var stack: Dictionary = _plain("mucai", 1)
		stack["quantity"] = quantity
		malformed["players"][A]["bag"][0] = stack
		assert_bool(_core.trusted_restore(malformed)["ok"]).is_false()
	var unknown: Dictionary = _core.snapshot()
	unknown["players"][A]["bag"][0] = _plain("unapproved_content", 1)
	assert_bool(_core.trusted_restore(unknown)["ok"]).is_false()
	assert_bool(_core.click_slot(A, {"container": "bag", "owner": A, "slot": 0.0}, _core.revision(), 1)["ok"]).is_false()
	assert_bool(var_to_bytes(_core.snapshot()) == before).is_true()

func test_scopes_are_not_persisted_and_player_views_do_not_leak() -> void:
	assert_bool(_core.trusted_set_chest_access(A, CHEST, true)["ok"]).is_true()
	assert_bool(_core.view(B)["chests"].is_empty()).is_true()
	assert_bool(_core.trusted_restore(_core.snapshot())["ok"]).is_true()
	assert_str(_click(_address("chest", 0, CHEST), 1)["code"]).is_equal("INVENTORY_CHEST_ACCESS_DENIED")
	var view: Dictionary = _core.view(A)
	view["inventory"]["bag"][0] = _plain("mucai", 2)
	assert_that(_core.snapshot()["players"][A]["bag"][0]).is_null()

func test_old_schema_and_corrupted_envelope_cannot_load() -> void:
	var before: PackedByteArray = var_to_bytes(_core.snapshot())
	assert_bool(_core.trusted_restore({"save_schema_version": 4, "terrain_component": {}})["ok"]).is_false()
	var encoded: Dictionary = _core.encode_snapshot()
	var envelope: Array = JSON.parse_string(encoded["bytes"].get_string_from_utf8())
	envelope[2] = "0".repeat(64)
	assert_bool(_core.decode_snapshot(JSON.stringify(envelope).to_utf8_buffer())["ok"]).is_false()
	assert_bool(var_to_bytes(_core.snapshot()) == before).is_true()

func test_wrong_world_cannot_restore_and_final_envelope_budget_is_enforced() -> void:
	var before: PackedByteArray = var_to_bytes(_core.snapshot())
	var wrong: Dictionary = _core.snapshot()
	wrong["world_id"] = "world_22222222222222222222222222222222"
	assert_bool(_core.trusted_restore(wrong)["ok"]).is_false()
	var huge: Dictionary = _core.snapshot()
	var item: Dictionary = _gun("item_fixture_large")
	item["state"]["quote_heavy_fixture"] = '"'.repeat(1100000)
	huge["players"][A]["bag"][0] = item
	var tagged: Dictionary = Core.Codec.encode(huge)
	assert_bool(tagged["ok"]).is_true()
	var payload: String = JSON.stringify(tagged["value"], "", true, true)
	assert_int(payload.to_utf8_buffer().size()).is_less(Core.MAX_BYTES)
	assert_int(Core._snapshot_bytes(payload).size()).is_greater(Core.MAX_BYTES)
	assert_bool(_core.trusted_restore(huge)["ok"]).is_false()
	assert_bool(var_to_bytes(_core.snapshot()) == before).is_true()

func test_complete_merge_consumes_carry_and_clears_origin() -> void:
	_seed({0: _plain("mucai", 7), 1: _plain("mucai", 2)})
	assert_bool(_click(_address("bag", 0), 1)["ok"]).is_true()
	assert_str(_click(_address("bag", 1), 2)["action"]).is_equal("merge")
	var player: Dictionary = _core.snapshot()["players"][A]
	assert_int(player["bag"][1]["quantity"]).is_equal(9)
	assert_that(player["carry"]).is_null()
	assert_that(player["carry_origin"]).is_null()

func test_internal_protected_collision_external_item_collision_and_unsupported_protected_stack() -> void:
	_seed({0: _gun("item_fixture_one", "protected_fixture_one")})
	var before: PackedByteArray = var_to_bytes(_core.snapshot())
	var conflicting: Dictionary = _core.snapshot()
	conflicting["players"][A]["bag"][1] = _gun("item_fixture_two", "protected_fixture_one")
	assert_bool(_core.trusted_restore(conflicting)["ok"]).is_false()
	conflicting = _core.snapshot()
	conflicting["external_item_instance_ids"] = ["item_fixture_one"]
	assert_bool(_core.trusted_restore(conflicting)["ok"]).is_false()
	conflicting = _core.snapshot()
	var unsupported: Dictionary = _plain("mucai", 2)
	unsupported["protected_instance_id"] = "protected_material_fixture"
	conflicting["players"][A]["bag"][1] = unsupported
	assert_bool(_core.trusted_restore(conflicting)["ok"]).is_false()
	assert_bool(var_to_bytes(_core.snapshot()) == before).is_true()

func test_malformed_contract_metadata_rejects_without_runtime_or_mutation() -> void:
	var before: PackedByteArray = var_to_bytes(_core.snapshot())
	for field in ["contract", "rules_sha256"]:
		for value in [null, [], {}, true, 7, 1.0]:
			var bad: Dictionary = _core.snapshot()
			bad[field] = value
			assert_bool(_core.trusted_restore(bad)["ok"]).is_false()
			assert_bool(var_to_bytes(_core.snapshot()) == before).is_true()
	for value in [null, [], {}, true, 7, 1.0]:
		var bad: Dictionary = _core.snapshot()
		for chest in bad["chests"]: bad["chests"][chest]["content_id"] = value
		assert_bool(_core.trusted_restore(bad)["ok"]).is_false()
		assert_bool(var_to_bytes(_core.snapshot()) == before).is_true()
