extends GdUnitTestSuite
## Finite isolated source tests; no gameplay installation or network claims.
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const View = preload("res://scripts/inventory/ui012/inventory_view012.gd")
const InventoryPanel = preload("res://scripts/inventory/ui012/inventory_panel012.gd")
const WORLD := "world_11111111111111111111111111111111"
const PROFILE := "player_inventory_panel_fixture"
const CHEST := "entity_inventory_panel_chest"
var _core: RefCounted
var _model: RefCounted
var _panel: Control
var _intents: Array
var _closes: Array

func before_test() -> void:
	_core = Core.new(WORLD)
	_core.trusted_create_player(PROFILE)
	_core.trusted_create_chest(CHEST)
	_core.trusted_set_chest_access(PROFILE, CHEST, true)
	_model = View.new(WORLD, PROFILE)
	_panel = InventoryPanel.new()
	_panel.bind_identity(WORLD, PROFILE)
	_panel.build_controls()
	_intents = []
	_closes = []
	_panel.left_intent.connect(func(address: Dictionary, revision: int, sequence: int) -> void: _intents.append([address, revision, sequence]))
	_panel.close_intent.connect(func(reason: String, revision: int) -> void: _closes.append([reason, revision]))

func after_test() -> void:
	_panel.free()

func _view(sequence: int = 1) -> Dictionary:
	return View.server_view(_core, PROFILE, sequence)

func _stack(count: int = 7) -> Dictionary:
	return {"content_id": "mucai", "quantity": count, "item_instance_id": "", "protected_instance_id": "", "state": {}}

func _address(kind: String = "bag", slot: int = 0, owner: String = PROFILE) -> Dictionary:
	return {"container": kind, "owner": owner, "slot": slot}

func _seed() -> void:
	var state: Dictionary = _core.snapshot()
	state["players"][PROFILE]["bag"][0] = _stack()
	assert_bool(_core.trusted_restore(state)["ok"]).is_true()
	_core.trusted_set_chest_access(PROFILE, CHEST, true)

func test_versioned_valid_whole_view_accepts() -> void:
	assert_bool(_model.accept(_view())["ok"]).is_true()
	assert_str(_model.snapshot()["profile_id"]).is_equal(PROFILE)

func test_unversioned_raw_core_view_refused() -> void:
	assert_bool(_model.accept(_core.view(PROFILE))["ok"]).is_false()

func test_wrong_profile_and_world_refused() -> void:
	for field in ["profile_id", "world_id"]:
		var value: Dictionary = _view()
		value[field] = "other_identity"
		assert_bool(_model.accept(value)["ok"]).is_false()
	assert_bool(_model.snapshot().is_empty()).is_true()

func test_extra_and_missing_fields_refused() -> void:
	for field in View.FIELDS:
		var missing: Dictionary = _view()
		missing.erase(field)
		assert_bool(_model.accept(missing)["ok"]).is_false()
	var extra: Dictionary = _view()
	extra["players"] = {"another_player": {}}
	assert_bool(_model.accept(extra)["ok"]).is_false()

func test_exact_counter_types_and_bounds_refused() -> void:
	for key in ["revision", "view_sequence", "schema_version"]:
		for bad in [-1, 1.0, true, "1", _limit_plus_one()]:
			var value: Dictionary = _view()
			value[key] = bad
			assert_bool(_model.accept(value)["ok"]).is_false()

func _limit_plus_one() -> int:
	return 9007199254740992

func test_all_slot_capacities_are_exact() -> void:
	for kind in ["bag", "hotbar", "chest"]:
		for difference in [-1, 1]:
			var value: Dictionary = _view()
			var slots: Array = value["chests"][CHEST]["slots"] if kind == "chest" else value["inventory"][kind]
			slots.resize(View.CAPACITIES[kind] + difference)
			assert_bool(_model.accept(value)["ok"]).is_false()

func test_quantity_and_unknown_content_rejected_atomically() -> void:
	assert_bool(_model.accept(_view())["ok"]).is_true()
	var before: Dictionary = _model.snapshot()
	for count in [0, -1, 1000, 1.0, true]:
		var value: Dictionary = _view(2)
		value["inventory"]["bag"][0] = _stack()
		value["inventory"]["bag"][0]["quantity"] = count
		assert_bool(_model.accept(value)["ok"]).is_false()
	var unknown: Dictionary = _view(2)
	unknown["inventory"]["bag"][0] = _stack()
	unknown["inventory"]["bag"][0]["content_id"] = "unapproved_item"
	assert_bool(_model.accept(unknown)["ok"]).is_false()
	assert_dict(_model.snapshot()).is_equal(before)

func test_late_invalid_chest_prevents_partial_player_update() -> void:
	_model.accept(_view())
	var before: Dictionary = _model.snapshot()
	var value: Dictionary = _view(2)
	value["revision"] += 1
	value["inventory"]["bag"][0] = _stack()
	value["chests"][CHEST]["slots"][29] = {"broken": true}
	assert_bool(_model.accept(value)["ok"]).is_false()
	assert_dict(_model.snapshot()).is_equal(before)

func test_duplicate_instance_ids_rejected_across_containers() -> void:
	var value: Dictionary = _view()
	var item := {"content_id": "wuqi_huoqi_tansuo_01", "quantity": 1, "item_instance_id": "fixture_instance", "protected_instance_id": "", "state": {"fixture_only": 3}}
	value["inventory"]["bag"][0] = item
	value["chests"][CHEST]["slots"][0] = item.duplicate(true)
	assert_bool(_model.accept(value)["ok"]).is_false()

func test_instance_opaque_state_and_identity_are_preserved() -> void:
	var value: Dictionary = _view()
	value["inventory"]["bag"][0] = {"content_id": "wuqi_huoqi_tansuo_01", "quantity": 1, "item_instance_id": "fixture_instance", "protected_instance_id": "fixture_protected", "state": {"fixture_remaining": 3, "nested": [true, "a"]}}
	assert_bool(_model.accept(value)["ok"]).is_true()
	assert_dict(_model.snapshot()).is_equal(value)

func test_invalid_nested_state_or_stack_fields_refused() -> void:
	var value: Dictionary = _view()
	value["inventory"]["bag"][0] = _stack()
	value["inventory"]["bag"][0]["state"] = {"forbidden_on_material": 1}
	assert_bool(_model.accept(value)["ok"]).is_false()
	value["inventory"]["bag"][0] = _stack()
	value["inventory"]["bag"][0]["extra"] = true
	assert_bool(_model.accept(value)["ok"]).is_false()

func test_cache_and_input_are_detached() -> void:
	var value: Dictionary = _view()
	_model.accept(value)
	value["inventory"]["bag"][0] = _stack()
	var copy: Dictionary = _model.snapshot()
	copy["inventory"]["hotbar"][0] = _stack()
	assert_that(_model.snapshot()["inventory"]["bag"][0]).is_null()
	assert_that(_model.snapshot()["inventory"]["hotbar"][0]).is_null()

func test_stale_view_sequence_and_revision_refused() -> void:
	_model.accept(_view(5))
	assert_bool(_model.accept(_view(4))["ok"]).is_false()
	assert_bool(_model.accept(_view(5))["ok"]).is_false()
	var value: Dictionary = _view(6)
	value["revision"] -= 1
	assert_bool(_model.accept(value)["ok"]).is_false()

func test_same_revision_inventory_mutation_refused() -> void:
	_model.accept(_view())
	var value: Dictionary = _view(2)
	value["inventory"]["bag"][0] = _stack()
	assert_bool(_model.accept(value)["ok"]).is_false()

func test_same_revision_context_revocation_accepts() -> void:
	_model.accept(_view())
	_core.close_view(PROFILE)
	assert_bool(_model.accept(_view(2))["ok"]).is_true()
	assert_bool(_model.snapshot()["chests"].is_empty()).is_true()

func test_carry_from_no_longer_visible_chest_is_valid() -> void:
	var value: Dictionary = _view()
	value["inventory"]["carry"] = _stack()
	value["inventory"]["carry_origin"] = _address("chest", 29, CHEST)
	value["chests"] = {}
	assert_bool(_model.accept(value)["ok"]).is_true()
	assert_bool(_model.address_valid(_address("chest", 29, CHEST))).is_false()

func test_foreign_or_invalid_carry_origin_refused() -> void:
	for origin in [_address("bag", 0, "foreign_player"), _address("hotbar", 10), _address("chest", 30, CHEST), null]:
		var value: Dictionary = _view()
		value["inventory"]["carry"] = _stack()
		value["inventory"]["carry_origin"] = origin
		assert_bool(_model.accept(value)["ok"]).is_false()

func test_left_intents_have_only_address_revision_sequence() -> void:
	_seed()
	_panel.apply_server_view(_view())
	_panel.open_personal()
	var before: Dictionary = _panel.cached_view()
	assert_bool(_panel.request_left(_address())).is_true()
	assert_bool(_panel.request_left(_address("hotbar", 9))).is_false()
	assert_int(_intents.size()).is_equal(1)
	assert_dict(_intents[0][0]).is_equal(_address())
	assert_int(_intents[0][1]).is_equal(_core.revision())
	assert_int(_intents[0][2]).is_equal(1)
	assert_dict(_panel.cached_view()).is_equal(before)

func test_closed_foreign_and_out_of_range_intents_refused() -> void:
	_panel.apply_server_view(_view())
	assert_bool(_panel.request_left(_address())).is_false()
	_panel.open_personal()
	for address in [_address("bag", 40), _address("bag", -1), _address("hotbar", 10), _address("bag", 0, "foreign_player"), _address("chest", 0, CHEST), {"container": "bag"}]:
		assert_bool(_panel.request_left(address)).is_false()
	assert_int(_intents.size()).is_equal(0)

func test_only_active_chest_can_emit_intents() -> void:
	_panel.apply_server_view(_view())
	assert_bool(_panel.grant_chest_context(CHEST, _panel.context_epoch())).is_true()
	assert_bool(_panel.open_chest(CHEST)).is_true()
	assert_bool(_panel.request_left(_address("chest", 29, CHEST))).is_true()
	assert_bool(_panel.request_left(_address("chest", 0, "other_chest"))).is_false()

func test_close_preserves_carry_and_is_idempotent() -> void:
	_seed()
	_core.click_slot(PROFILE, _address(), _core.revision(), 1)
	_panel.apply_server_view(_view())
	_panel.open_personal()
	var before: Dictionary = _panel.cached_view()
	_panel.close_panel()
	_panel.close_panel()
	assert_dict(_panel.cached_view()).is_equal(before)
	assert_int(_closes.size()).is_equal(1)
	assert_int(_panel.cached_view()["inventory"]["carry"]["quantity"]).is_equal(7)
	assert_bool(_panel.get_node("ServerCarryTechnicalThumbnail").visible).is_true()

func test_context_loss_closes_whole_group_and_blocks_cached_reopen() -> void:
	_panel.apply_server_view(_view())
	_panel.grant_chest_context(CHEST, _panel.context_epoch())
	_panel.open_chest(CHEST)
	_panel.context_lost()
	assert_bool(_panel.get_node("InventoryMask").visible).is_false()
	assert_bool(_panel.get_node("CenteredInventoryContext").visible).is_false()
	assert_bool(_panel.open_chest(CHEST)).is_false()
	assert_str(_closes[0][0]).is_equal("context_lost")

func test_new_view_revocation_closes_context_and_clears_chest_slots() -> void:
	_panel.apply_server_view(_view())
	_panel.grant_chest_context(CHEST, _panel.context_epoch())
	_panel.open_chest(CHEST)
	_core.close_view(PROFILE)
	_panel.apply_server_view(_view(2))
	assert_bool(_panel.get_node("InventoryMask").visible).is_false()
	assert_int(_closes.size()).is_equal(1)
	assert_bool(_panel.open_chest(CHEST)).is_false()

func test_layout_capacities_adjacent_chest_and_personal_lifecycle() -> void:
	_panel.apply_server_view(_view())
	_panel.open_personal()
	var row: Node = _panel.get_node("CenteredInventoryContext").get_child(0)
	assert_int(row.get_node("Bag/BagSlots").get_child_count()).is_equal(40)
	assert_int(row.get_node("CurrentChest/ChestSlots").get_child_count()).is_equal(30)
	assert_int(_panel.get_node("PersistentHotbar/HotbarSlots").get_child_count()).is_equal(10)
	assert_bool(row.get_node("CharacterPlaceholder").visible).is_true()
	assert_bool(row.get_node("PersonalCraftingPlaceholder").visible).is_true()
	_panel.grant_chest_context(CHEST, _panel.context_epoch())
	_panel.open_chest(CHEST)
	assert_bool(row.get_node("CharacterPlaceholder").visible).is_false()
	assert_bool(row.get_node("PersonalCraftingPlaceholder").visible).is_false()
	assert_bool(row.get_node("CurrentChest").visible).is_true()
	assert_int(_panel.get_node("PersistentHotbar").z_index).is_greater(_panel.get_node("InventoryMask").z_index)

func test_tooltip_has_padding_min_height_and_current_instance_data() -> void:
	var row: Node = _panel.get_node("CenteredInventoryContext").get_child(0)
	var slot: Button = row.get_node("Bag/BagSlots").get_child(0)
	var tip: Control = slot._make_custom_tooltip("current instance 7")
	assert_float(tip.custom_minimum_size.y).is_greater_equal(120.0)
	assert_int(tip.get_child(0).get_theme_constant("margin_top")).is_greater_equal(20)
	assert_int(tip.get_child(0).get_theme_constant("margin_bottom")).is_greater_equal(20)
	assert_str(tip.get_child(0).get_child(0).text).is_equal("current instance 7")
	tip.free()
	assert_str(InventoryPanel._tooltip({"content_id": "mucai", "quantity": 7, "item_instance_id": "", "protected_instance_id": "", "state": {"fixture_current": 3}})).contains("fixture_current")

func test_identity_binding_cannot_switch_or_leak_other_player() -> void:
	assert_bool(_panel.bind_identity(WORLD, "other_player")).is_false()
	_panel.apply_server_view(_view())
	var before: Dictionary = _panel.cached_view()
	var other: Dictionary = _view(2)
	other["profile_id"] = "other_player"
	assert_bool(_panel.apply_server_view(other)["ok"]).is_false()
	assert_dict(_panel.cached_view()).is_equal(before)

func test_same_revision_changed_visible_chest_refused() -> void:
	_model.accept(_view())
	var value: Dictionary = _view(2)
	value["chests"][CHEST]["slots"][0] = _stack()
	assert_bool(_model.accept(value)["ok"]).is_false()

func test_reordered_dictionary_fields_are_not_state_changes() -> void:
	_model.accept(_view())
	var value: Dictionary = _view(2)
	var player: Dictionary = value["inventory"]
	value["inventory"] = {"last_sequence": player["last_sequence"], "carry_origin": player["carry_origin"], "carry": player["carry"], "hotbar": player["hotbar"], "bag": player["bag"]}
	assert_bool(_model.accept(value)["ok"]).is_true()

func test_sequence_limit_prevents_overflow_intent() -> void:
	var value: Dictionary = _view()
	value["inventory"]["last_sequence"] = 9007199254740991
	_panel.apply_server_view(value)
	_panel.open_personal()
	assert_bool(_panel.request_left(_address())).is_false()
	assert_int(_intents.size()).is_equal(0)

func test_authoritative_ack_releases_single_pending_intent() -> void:
	_seed()
	_panel.apply_server_view(_view())
	_panel.open_personal()
	_panel.request_left(_address())
	assert_bool(_panel.request_left(_address("hotbar", 9))).is_false()
	assert_bool(_core.click_slot(PROFILE, _intents[0][0], _intents[0][1], _intents[0][2])["ok"]).is_true()
	_panel.apply_server_view(_view(2))
	assert_bool(_panel.request_left(_address("hotbar", 9))).is_true()
	assert_int(_intents[1][2]).is_equal(2)
	assert_int(_intents[1][1]).is_equal(_core.revision())

func test_explicit_matching_rejection_releases_gate_without_mutation() -> void:
	_panel.apply_server_view(_view())
	_panel.open_personal()
	_panel.request_left(_address())
	var before: Dictionary = _panel.cached_view()
	assert_bool(_panel.reject_left_intent(99)).is_false()
	assert_bool(_panel.request_left(_address())).is_false()
	assert_bool(_panel.reject_left_intent(1)).is_true()
	assert_bool(_panel.request_left(_address())).is_true()
	assert_int(_intents[1][2]).is_equal(2)
	assert_dict(_panel.cached_view()).is_equal(before)

func test_pre_close_view_and_grant_cannot_reopen_revoked_context() -> void:
	_panel.apply_server_view(_view())
	var old_epoch: int = _panel.context_epoch()
	_panel.grant_chest_context(CHEST, old_epoch)
	_panel.open_chest(CHEST)
	_panel.context_lost()
	_panel.apply_server_view(_view(2))
	assert_bool(_panel.open_chest(CHEST)).is_false()
	assert_bool(_panel.grant_chest_context(CHEST, old_epoch)).is_false()
	assert_bool(_panel.grant_chest_context(CHEST, _panel.context_epoch())).is_true()
	assert_bool(_panel.open_chest(CHEST)).is_true()

func test_regrant_same_revision_changed_chest_is_refused() -> void:
	_model.accept(_view())
	var revoked: Dictionary = _view(2)
	revoked["chests"] = {}
	assert_bool(_model.accept(revoked)["ok"]).is_true()
	var changed: Dictionary = _view(3)
	changed["chests"][CHEST]["slots"][0] = _stack()
	assert_bool(_model.accept(changed)["ok"]).is_false()
	assert_bool(_model.accept(_view(3))["ok"]).is_true()

func test_switch_to_personal_revokes_chest_grant_and_notifies_bridge() -> void:
	_panel.apply_server_view(_view())
	var old_epoch: int = _panel.context_epoch()
	_panel.grant_chest_context(CHEST, old_epoch)
	_panel.open_chest(CHEST)
	_panel.open_personal()
	assert_int(_closes.size()).is_equal(1)
	assert_str(_closes[0][0]).is_equal("switch_personal")
	assert_bool(_panel.open_chest(CHEST)).is_false()
	assert_bool(_panel.grant_chest_context(CHEST, old_epoch)).is_false()

func test_unopened_grant_is_revoked_by_new_view() -> void:
	_panel.apply_server_view(_view())
	var old_epoch: int = _panel.context_epoch()
	_panel.grant_chest_context(CHEST, old_epoch)
	var revoked: Dictionary = _view(2)
	revoked["chests"] = {}
	_panel.apply_server_view(revoked)
	_panel.apply_server_view(_view(3))
	assert_bool(_panel.open_chest(CHEST)).is_false()
	assert_bool(_panel.grant_chest_context(CHEST, old_epoch)).is_false()

func test_pending_gate_disables_slots_until_matching_rejection() -> void:
	_panel.apply_server_view(_view())
	_panel.open_personal()
	var slot: Button = _panel.get_node("PersistentHotbar/HotbarSlots").get_child(0)
	assert_bool(slot.disabled).is_false()
	_panel.request_left(_address())
	assert_bool(slot.disabled).is_true()
	_panel.reject_left_intent(1)
	assert_bool(slot.disabled).is_false()

func test_closed_carry_drop_emits_only_intent_without_local_inventory_mutation() -> void:
	_seed()
	_core.click_slot(PROFILE, _address(), _core.revision(), 1)
	_panel.apply_server_view(_view())
	var drops: Array = []
	_panel.drop_intent.connect(func(kind: String, address: Dictionary, revision: int, sequence: int) -> void: drops.append([kind, address, revision, sequence]))
	var before: PackedByteArray = var_to_bytes(_panel.cached_view())
	assert_bool(_panel.request_drop("carry_all")).is_true()
	assert_str(drops[0][0]).is_equal("carry_all")
	assert_int(drops[0][3]).is_equal(2)
	assert_bool(var_to_bytes(_panel.cached_view()) == before).is_true()
	assert_bool(_panel.request_drop("right_half")).is_false()
func test_drop_and_left_share_pending_and_matching_rejection_gate() -> void:
	_seed()
	_panel.apply_server_view(_view())
	_panel.open_personal()
	assert_bool(_panel.request_drop("q_one", _address())).is_true()
	assert_bool(_panel.request_left(_address())).is_false()
	assert_bool(_panel.reject_left_intent(99)).is_false()
	assert_bool(_panel.reject_left_intent(1)).is_true()
	assert_bool(_panel.request_left(_address())).is_true()
func test_drop_foreign_chest_and_unknown_kind_are_not_emitted() -> void:
	_panel.apply_server_view(_view())
	assert_bool(_panel.request_drop("q_one", _address("chest", 0, CHEST))).is_false()
	assert_bool(_panel.request_drop("q_one", _address("bag", 0, "player_other"))).is_false()
	assert_bool(_panel.request_drop("long_press_whole", _address())).is_false()

func test_closed_panel_hotbar_click_is_not_outside_whole_carry_drop() -> void:
	_seed()
	_core.click_slot(PROFILE, _address(), _core.revision(), 1)
	_panel.apply_server_view(_view())
	add_child(_panel)
	await get_tree().process_frame
	var drops: Array = []
	_panel.drop_intent.connect(func(kind: String, _address: Dictionary, _revision: int, _sequence: int) -> void: drops.append(kind))
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = _panel._hotbar_grid.get_global_rect().get_center()
	_panel._input(event)
	assert_array(drops).is_empty()
	assert_int(_panel._pending_sequence).is_equal(0)
