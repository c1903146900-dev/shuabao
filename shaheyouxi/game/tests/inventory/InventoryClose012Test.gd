extends GdUnitTestSuite
## Pure schema5 close-contract fixtures. No engine ownership, RPC, disk writes,
## actual durable acknowledgment, or disconnect carry policy is asserted here.
const Close = preload("res://scripts/actor/actor_local_session_close.gd")
const MAXIMUM: int = 9007199254740991
const SESSION := "11111111111111111111111111111111"
const ACTOR_REQUEST_FIELDS := ["client_pid", "peer_id", "player_profile_id", "player_instance_id", "input_generation", "accepted_sequence", "actor_revision", "cutoff_sequence", "pending_count", "intent_count"]

func _manifest() -> Dictionary:
	return {"schema_version": 1, "contract": Close.INVENTORY_OWNED_CONTRACT, "session_id": SESSION, "slot_id": "6".repeat(32), "server_pid": 1234, "owner_pid": 5678, "owner_nonce": "7".repeat(32), "server_epoch": "session_22222222222222222222222222222222", "world_id": "world_33333333333333333333333333333333", "save_schema": 5, "profile_marker_sha256": "a".repeat(64)}

func _actor(sequence: int = 0) -> Dictionary:
	return {"world_id": _manifest()["world_id"], "server_epoch": _manifest()["server_epoch"], "player_profile_id": "player_44444444444444444444444444444444", "player_instance_id": "entity_player_55555555555555555555555555555555", "peer_id": 11, "input_generation": 2, "accepted_sequence": sequence, "actor_revision": 2 + sequence, "authority_revision": 1, "world_seconds": float(sequence) / 16.0}

func _inventory(issued: int = 40, processed: int = 40, accepted: int = 40, revision: int = 7, pending: int = 0) -> Dictionary:
	var result: Dictionary = {}
	var actor := _actor()
	for field in Close.IDENTITY_FIELDS:
		result[field] = actor[field]
	result.merge({"initial_sequence": 40, "issued_sequence": issued, "processed_sequence": processed, "accepted_sequence": accepted, "revision": revision, "pending_count": pending})
	return result

func _configured(bind_inventory: bool = true) -> RefCounted:
	var state := Close.new()
	assert_bool(state.configure_owned_inventory(_manifest(), SESSION, 5678)["ok"]).is_true()
	assert_bool(state.bind_checkpoint(_actor())["ok"]).is_true()
	if bind_inventory:
		assert_bool(state.bind_inventory_checkpoint(_inventory())["ok"]).is_true()
	return state

func _draining() -> RefCounted:
	var state := _configured()
	# One accepted action, then a last issued action awaiting its reply.
	assert_bool(state.bind_inventory_checkpoint(_inventory(41, 40, 40, 7, 1))["ok"]).is_true()
	assert_bool(state.bind_inventory_checkpoint(_inventory(41, 41, 41, 8, 0))["ok"]).is_true()
	assert_bool(state.bind_inventory_checkpoint(_inventory(42, 41, 41, 8, 1))["ok"]).is_true()
	assert_bool(state.begin_stop_inventory(_actor(), 3, true, _inventory(42, 41, 41, 8, 1))["ok"]).is_true()
	return state

func _requested() -> RefCounted:
	var state := _draining()
	# Rejection acknowledges sequence42 without advancing saved Core sequence41.
	assert_bool(state.poll_release_inventory(_actor(3), 0, true, 3, _inventory(42, 42, 41, 8, 0))["ok"]).is_true()
	assert_bool(state.mark_request_written()["ok"]).is_true()
	return state

func _receipt() -> Dictionary:
	var result := _manifest()
	var actor := _actor(3)
	for field in ["peer_id", "player_profile_id", "player_instance_id", "input_generation"]:
		result[field] = actor[field]
	result.merge({"client_pid": 5678, "cutoff_sequence": 3, "accepted_sequence": 3, "server_exit_code": 0, "child_exit_observed": true, "writer_lock_released": true, "main_committed": true, "complete": true, "main_sequence": 4, "main_sha256": "b".repeat(64), "reason": "normal_shutdown", "inventory_initial_sequence": 40, "inventory_cutoff_sequence": 42, "inventory_processed_sequence": 42, "inventory_saved_accepted_sequence": 41, "inventory_saved_revision": 8, "inventory_queue_empty": true})
	return result

func test_manifest5_is_exact_and_binds_canonical_profile_marker() -> void:
	var state := _configured()
	assert_bool(state.manifest_matches(_manifest())).is_true()
	for hash_value in ["A".repeat(64), "a".repeat(63), "z".repeat(64), true, 3, null]:
		var changed := _manifest()
		changed["profile_marker_sha256"] = hash_value
		assert_bool(Close.new().configure_owned_inventory(changed, SESSION, 5678)["ok"]).is_false()
		assert_bool(state.manifest_matches(changed)).is_false()
	for field in Close.INVENTORY_OWNED_MANIFEST_FIELDS:
		var missing := _manifest()
		missing.erase(field)
		assert_bool(Close.new().configure_owned_inventory(missing, SESSION, 5678)["ok"]).is_false()
	var extra := _manifest()
	extra["save_profile"] = 5
	assert_bool(Close.new().configure_owned_inventory(extra, SESSION, 5678)["ok"]).is_false()
	var wrong_contract := _manifest()
	wrong_contract["contract"] = Close.OWNED_CONTRACT
	assert_bool(Close.new().configure_owned_inventory(wrong_contract, SESSION, 5678)["ok"]).is_false()
	assert_bool(Close.new().configure_owned_inventory(_manifest(), "different", 5678)["ok"]).is_false()

func test_manifest5_counts_are_bounded_exact_ints_and_configure_is_one_use() -> void:
	for field in ["schema_version", "server_pid", "owner_pid", "save_schema"]:
		for invalid in [true, 1.0, -1, MAXIMUM + 1, "1"]:
			var changed := _manifest()
			changed[field] = invalid
			assert_bool(Close.new().configure_owned_inventory(changed, SESSION, 5678)["ok"]).is_false()
	for invalid in [true, 5678.0, -1, MAXIMUM + 1, "5678"]:
		assert_bool(Close.new().configure_owned_inventory(_manifest(), SESSION, invalid)["ok"]).is_false()
	var state := _configured()
	assert_bool(state.configure_owned_inventory(_manifest(), SESSION, 5678)["ok"]).is_false()
	assert_bool(state.ready).is_false()

func test_initial_inventory_checkpoint_must_precede_all_issues() -> void:
	assert_bool(_configured(false).bind_inventory_checkpoint(_inventory(41, 40, 40, 7, 1))["ok"]).is_false()
	assert_bool(_configured(false).bind_inventory_checkpoint(_inventory(42, 42, 41, 8, 0))["ok"]).is_false()
	var state := Close.new()
	assert_bool(state.configure_owned_inventory(_manifest(), SESSION, 5678)["ok"]).is_true()
	assert_bool(state.bind_inventory_checkpoint(_inventory())["ok"]).is_false()
	var missing := _inventory()
	missing.erase("processed_sequence")
	assert_bool(_configured().bind_inventory_checkpoint(missing)["ok"]).is_false()
	var extra := _inventory()
	extra["durable"] = true
	assert_bool(_configured().bind_inventory_checkpoint(extra)["ok"]).is_false()

func test_inventory_binds_every_actor_connection_identity_field() -> void:
	for field in Close.IDENTITY_FIELDS:
		var state := _configured()
		var changed := _inventory()
		changed[field] = changed[field] + 1 if changed[field] is int else str(changed[field]).replace("2", "9").replace("3", "9").replace("4", "9").replace("5", "9")
		assert_bool(state.bind_inventory_checkpoint(changed)["ok"]).is_false()
		assert_bool(state.can_close()).is_false()
	for field in ["peer_id", "input_generation"]:
		var changed := _inventory()
		changed[field] = float(changed[field])
		assert_bool(_configured().bind_inventory_checkpoint(changed)["ok"]).is_false()

func test_initial_cursor_cannot_change_even_to_an_older_valid_cursor() -> void:
	var changed := _inventory()
	changed["initial_sequence"] = 39
	assert_bool(_configured().bind_inventory_checkpoint(changed)["ok"]).is_false()
	var draining := _draining()
	changed = _inventory(42, 41, 41, 8, 1)
	changed["initial_sequence"] = 39
	assert_bool(draining.poll_release_inventory(_actor(3), 0, true, 3, changed)["ok"]).is_false()

func test_issue_must_be_exactly_next_and_cannot_skip_the_pending_transition() -> void:
	assert_bool(_configured().bind_inventory_checkpoint(_inventory(42, 41, 40, 7, 1))["ok"]).is_false()
	assert_bool(_configured().bind_inventory_checkpoint(_inventory(41, 41, 41, 8, 0))["ok"]).is_false()
	var state := _configured()
	assert_bool(state.bind_inventory_checkpoint(_inventory(41, 40, 40, 7, 1))["ok"]).is_true()
	assert_bool(state.bind_inventory_checkpoint(_inventory(42, 41, 41, 8, 1))["ok"]).is_false()

func test_inventory_counters_have_strict_types_bounds_and_order() -> void:
	for field in ["initial_sequence", "issued_sequence", "processed_sequence", "accepted_sequence", "revision", "pending_count"]:
		for invalid in [true, 40.0, -1, MAXIMUM + 1, "40", null]:
			var changed := _inventory()
			changed[field] = invalid
			assert_bool(_configured().bind_inventory_checkpoint(changed)["ok"]).is_false()
	for changed in [_inventory(40, 40, 39), _inventory(40, 40, 41), _inventory(40, 41, 40), _inventory(41, 40, 40, 7, 0), _inventory(42, 40, 40, 7, 2)]:
		assert_bool(_configured().bind_inventory_checkpoint(changed)["ok"]).is_false()

func test_inventory_counter_and_revision_regressions_fail_closed() -> void:
	for field in ["issued_sequence", "processed_sequence", "accepted_sequence", "revision"]:
		var state := _configured()
		assert_bool(state.bind_inventory_checkpoint(_inventory(41, 40, 40, 7, 1))["ok"]).is_true()
		assert_bool(state.bind_inventory_checkpoint(_inventory(41, 41, 41, 8, 0))["ok"]).is_true()
		var changed := _inventory(41, 41, 41, 8, 0)
		changed[field] -= 1
		assert_bool(state.bind_inventory_checkpoint(changed)["ok"]).is_false()
		assert_bool(state.ready).is_false()

func test_new_accepted_cursor_requires_strictly_newer_inventory_revision() -> void:
	var state := _configured()
	assert_bool(state.bind_inventory_checkpoint(_inventory(41, 40, 40, 7, 1))["ok"]).is_true()
	assert_bool(state.bind_inventory_checkpoint(_inventory(41, 41, 41, 7, 0))["ok"]).is_false()
	assert_bool(state.can_close()).is_false()
	var larger := _configured()
	assert_bool(larger.bind_inventory_checkpoint(_inventory(41, 40, 40, 7, 1))["ok"]).is_true()
	assert_bool(larger.bind_inventory_checkpoint(_inventory(41, 41, 41, 19, 0))["ok"]).is_true()

func test_global_revision_may_advance_without_exactly_one_per_local_action() -> void:
	var state := _configured()
	assert_bool(state.bind_inventory_checkpoint(_inventory(40, 40, 40, 19, 0))["ok"]).is_true()
	assert_bool(state.bind_inventory_checkpoint(_inventory(41, 40, 40, 19, 1))["ok"]).is_true()
	assert_bool(state.bind_inventory_checkpoint(_inventory(41, 41, 40, 27, 0))["ok"]).is_true()
	assert_bool(state.begin_stop_inventory(_actor(), 0, true, _inventory(41, 41, 40, 31, 0))["ok"]).is_true()
	assert_bool(state.poll_release_inventory(_actor(), 0, true, 0, _inventory(41, 41, 40, 35, 0))["ok"]).is_true()

func test_actor_and_inventory_pending_are_independent_close_barriers() -> void:
	var state := _draining()
	assert_bool(state.poll_release_inventory(_actor(3), 0, true, 3, _inventory(42, 41, 41, 8, 1)).get("pending", false)).is_true()
	assert_bool(state.poll_release_inventory(_actor(3), 1, true, 3, _inventory(42, 42, 41, 8, 0)).get("pending", false)).is_true()
	assert_bool(state.expected_disconnect()).is_false()
	assert_bool(state.statistics()["request_written"]).is_false()
	assert_bool(state.poll_release_inventory(_actor(3), 0, true, 3, _inventory(42, 42, 41, 8, 0))["ok"]).is_true()
	var actor_lag := _draining()
	assert_bool(actor_lag.poll_release_inventory(_actor(2), 0, true, 3, _inventory(42, 42, 41, 8, 0)).get("pending", false)).is_true()
	assert_bool(actor_lag.poll_release_inventory(_actor(3), 0, true, 3, _inventory(42, 42, 41, 8, 0))["ok"]).is_true()

func test_clearing_local_pending_without_processed_reply_is_not_proof() -> void:
	var state := _draining()
	assert_bool(state.poll_release_inventory(_actor(3), 0, true, 3, _inventory(42, 41, 41, 8, 0))["ok"]).is_false()
	assert_bool(state.ready or state.can_close() or state.expected_disconnect()).is_false()

func test_stop_freezes_inventory_cutoff_separately_from_actor_cutoff() -> void:
	var state := _draining()
	assert_int(state.statistics()["cutoff_sequence"]).is_equal(3)
	assert_int(state.inventory_statistics()["cutoff_sequence"]).is_equal(42)
	assert_bool(state.bind_inventory_checkpoint(_inventory(42, 42, 41, 8, 0))["ok"]).is_true()
	assert_bool(state.bind_inventory_checkpoint(_inventory(43, 42, 41, 8, 1))["ok"]).is_false()
	assert_bool(_draining().poll_release_inventory(_actor(4), 0, true, 4, _inventory(42, 42, 41, 8, 0))["ok"]).is_false()

func test_actor_only_methods_and_receipt_cannot_close_schema5() -> void:
	assert_bool(_configured().begin_stop(_actor(), 0, true)["ok"]).is_false()
	assert_bool(_draining().poll_release(_actor(3), 0, true, 3)["ok"]).is_false()
	var actor_only := _receipt()
	for field in Close.INVENTORY_RECEIPT_EXTRA_FIELDS:
		actor_only.erase(field)
	var state := _requested()
	assert_bool(state.accept_receipt(actor_only)["ok"]).is_false()
	assert_bool(state.can_close()).is_false()
	assert_bool(Close.new().configure_owned(_manifest(), SESSION, 5678)["ok"]).is_false()

func test_schema5_stop_counts_and_connected_flag_are_not_coerced() -> void:
	for invalid in [true, 3.0, -1, MAXIMUM + 1, "3"]:
		assert_bool(_configured().begin_stop_inventory(_actor(), invalid, true, _inventory())["ok"]).is_false()
		assert_bool(_draining().poll_release_inventory(_actor(3), invalid, true, 3, _inventory(42, 42, 41, 8, 0))["ok"]).is_false()
		assert_bool(_draining().poll_release_inventory(_actor(3), 0, true, invalid, _inventory(42, 42, 41, 8, 0))["ok"]).is_false()
	for invalid in [1, "true", null, false]:
		assert_bool(_configured().begin_stop_inventory(_actor(), 0, invalid, _inventory())["ok"]).is_false()
		assert_bool(_draining().poll_release_inventory(_actor(3), 0, invalid, 3, _inventory(42, 42, 41, 8, 0))["ok"]).is_false()
	assert_bool(_draining().poll_release_inventory(_actor(3), 0, true, 2, _inventory(42, 42, 41, 8, 0))["ok"]).is_false()

func test_final_rejected_action_builds_exact_detached_dual_cutoff_request() -> void:
	var state := _draining()
	var result: Dictionary = state.poll_release_inventory(_actor(3), 0, true, 3, _inventory(42, 42, 41, 8, 0))
	assert_bool(result["ok"]).is_true()
	var request: Dictionary = result["request"]
	assert_int(request.size()).is_equal((Close.INVENTORY_OWNED_MANIFEST_FIELDS + ACTOR_REQUEST_FIELDS + Close.INVENTORY_REQUEST_EXTRA_FIELDS).size())
	for field in Close.INVENTORY_OWNED_MANIFEST_FIELDS + ACTOR_REQUEST_FIELDS + Close.INVENTORY_REQUEST_EXTRA_FIELDS:
		assert_bool(request.has(field)).is_true()
	assert_bool(request["inventory_accepted_sequence"] == 41 and request["inventory_cutoff_sequence"] == 42 and request["cutoff_sequence"] == 3 and request["inventory_processed_sequence"] == 42 and request["inventory_pending_count"] == 0).is_true()
	request["inventory_accepted_sequence"] = 99
	assert_bool(state.mark_request_written()["ok"]).is_true()
	assert_bool(state.accept_receipt(_receipt())["ok"]).is_true()

func test_rejected_last_action_closes_in_either_receipt_disconnect_order() -> void:
	for receipt_first in [true, false]:
		var state := _requested()
		if receipt_first:
			assert_bool(state.accept_receipt(_receipt())["ok"]).is_true()
			assert_bool(state.can_close()).is_false()
			assert_bool(state.observe_disconnect()["ok"]).is_true()
		else:
			assert_bool(state.observe_disconnect()["ok"]).is_true()
			assert_bool(state.can_close()).is_false()
			assert_bool(state.accept_receipt(_receipt())["ok"]).is_true()
		assert_bool(state.can_close()).is_true()
		assert_bool(state.mark_closed()["ok"]).is_true()
		assert_bool(state.mark_closed()["ok"]).is_false()
		assert_bool(state.can_close()).is_false()

func test_receipt_rejects_wrong_saved_inventory_cutoff_initial_and_revision() -> void:
	for overlay in [{"inventory_initial_sequence": 39}, {"inventory_initial_sequence": 41}, {"inventory_cutoff_sequence": 41}, {"inventory_cutoff_sequence": 43}, {"inventory_processed_sequence": 41}, {"inventory_processed_sequence": 43}, {"inventory_saved_accepted_sequence": 40}, {"inventory_saved_accepted_sequence": 42}, {"inventory_saved_accepted_sequence": 43}, {"inventory_saved_revision": 7}, {"inventory_queue_empty": false}, {"inventory_queue_empty": 1}, {"accepted_sequence": 4}, {"profile_marker_sha256": "c".repeat(64)}, {"server_epoch": "session_99999999999999999999999999999999"}]:
		var receipt := _receipt()
		receipt.merge(overlay, true)
		var state := _requested()
		assert_bool(state.accept_receipt(receipt)["ok"]).is_false()
		assert_bool(state.can_close()).is_false()
	var covering := _receipt()
	covering["inventory_saved_revision"] = 29
	assert_bool(_requested().accept_receipt(covering)["ok"]).is_true()

func test_receipt_inventory_numbers_flags_and_fields_are_exact() -> void:
	for field in ["inventory_initial_sequence", "inventory_cutoff_sequence", "inventory_processed_sequence", "inventory_saved_accepted_sequence", "inventory_saved_revision"]:
		for invalid in [true, 40.0, -1, MAXIMUM + 1, "40"]:
			var receipt := _receipt()
			receipt[field] = invalid
			assert_bool(_requested().accept_receipt(receipt)["ok"]).is_false()
	for field in ["child_exit_observed", "writer_lock_released", "main_committed", "complete", "inventory_queue_empty"]:
		for invalid in [false, 1, "true"]:
			var receipt := _receipt()
			receipt[field] = invalid
			assert_bool(_requested().accept_receipt(receipt)["ok"]).is_false()
	for field in Close.INVENTORY_RECEIPT_EXTRA_FIELDS:
		var receipt := _receipt()
		receipt.erase(field)
		assert_bool(_requested().accept_receipt(receipt)["ok"]).is_false()
	var extra := _receipt()
	extra["durable"] = true
	assert_bool(_requested().accept_receipt(extra)["ok"]).is_false()

func test_repeated_stop_poll_request_and_receipt_are_one_use() -> void:
	assert_bool(_draining().begin_stop_inventory(_actor(), 3, true, _inventory(42, 41, 41, 8, 1))["ok"]).is_false()
	assert_bool(_requested().poll_release_inventory(_actor(3), 0, true, 3, _inventory(42, 42, 41, 8, 0))["ok"]).is_false()
	assert_bool(_requested().mark_request_written()["ok"]).is_false()
	var state := _requested()
	assert_bool(state.accept_receipt(_receipt())["ok"]).is_true()
	assert_bool(state.accept_receipt(_receipt())["ok"]).is_false()
	assert_bool(state.can_close()).is_false()

func test_zero_new_inventory_actions_still_require_separate_inventory_proof() -> void:
	var state := _configured()
	assert_bool(state.begin_stop_inventory(_actor(), 0, true, _inventory())["ok"]).is_true()
	var released: Dictionary = state.poll_release_inventory(_actor(), 0, true, 0, _inventory())
	assert_bool(released["ok"]).is_true()
	assert_bool(released["request"]["inventory_initial_sequence"] == 40 and released["request"]["inventory_cutoff_sequence"] == 40 and released["request"]["cutoff_sequence"] == 0).is_true()
	assert_bool(state.mark_request_written()["ok"]).is_true()
	var receipt := _receipt()
	receipt.merge({"cutoff_sequence": 0, "accepted_sequence": 0, "inventory_cutoff_sequence": 40, "inventory_processed_sequence": 40, "inventory_saved_accepted_sequence": 40, "inventory_saved_revision": 7}, true)
	assert_bool(state.accept_receipt(receipt)["ok"]).is_true()
	assert_bool(state.observe_disconnect()["ok"] and state.can_close()).is_true()

func _legacy_manifest(owned: bool) -> Dictionary:
	var result := _manifest()
	result.erase("profile_marker_sha256")
	result["save_schema"] = 4
	result["contract"] = Close.OWNED_CONTRACT if owned else Close.CONTRACT
	if not owned:
		for field in ["slot_id", "owner_pid", "owner_nonce"]:
			result.erase(field)
		result["server_start_ticks"] = 4567
	return result

func test_legacy4_both_contracts_keep_exact_request_receipt_and_statistics() -> void:
	for owned in [false, true]:
		var manifest := _legacy_manifest(owned)
		var state := Close.new()
		var configured: Dictionary = state.configure_owned(manifest, SESSION, 5678) if owned else state.configure(manifest, "actor011_terrain_play_" + SESSION, 5678)
		assert_bool(configured["ok"]).is_true()
		assert_bool(state.begin_stop(_actor(), 3, true)["ok"]).is_true()
		var released: Dictionary = state.poll_release(_actor(3), 0, true, 3)
		var expected := manifest.duplicate(true)
		for field in ["peer_id", "player_profile_id", "player_instance_id", "input_generation"]:
			expected[field] = _actor(3)[field]
		expected.merge({"client_pid": 5678, "accepted_sequence": 3, "actor_revision": 5, "cutoff_sequence": 3, "pending_count": 0, "intent_count": 3})
		assert_dict(released["request"]).is_equal(expected)
		assert_bool(state.inventory_statistics().is_empty()).is_true()
		assert_bool(state.mark_request_written()["ok"]).is_true()
		var receipt := manifest.duplicate(true)
		for field in ["peer_id", "player_profile_id", "player_instance_id", "input_generation"]:
			receipt[field] = _actor(3)[field]
		receipt.merge({"client_pid": 5678, "cutoff_sequence": 3, "accepted_sequence": 3, "server_exit_code": 0, "writer_lock_released": true, "main_committed": true, "complete": true, "main_sequence": 4, "main_sha256": "b".repeat(64), "reason": "normal_shutdown"})
		if owned:
			receipt["child_exit_observed"] = true
		else:
			receipt.merge({"server_reaped": true, "server_group_empty": true})
		assert_bool(state.accept_receipt(receipt)["ok"]).is_true()
		assert_bool(state.observe_disconnect()["ok"] and state.can_close()).is_true()
		assert_bool(state.mark_closed()["ok"]).is_true()
		assert_dict(state.statistics()).is_equal({"phase": "closed", "cutoff_sequence": 3, "accepted_sequence": 3, "request_written": true, "server_disconnect_observed": true, "save_receipt_verified": true, "main_sequence": 4, "error": ""})
		assert_bool(state.mark_closed()["ok"]).is_false()
