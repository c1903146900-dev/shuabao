extends GdUnitTestSuite
## Negative capability/early-reentry syntax tests only. Synthetic pending state
## is never a legal ticket, and no real Owner/native/world is instantiated here.
const Frame = preload("res://scripts/actor/actor_frame_transaction.gd")
const Hot = preload("res://scripts/harvest/tree_ground_hot012.gd")

func test_absent_unknown_and_retired_ticket_are_not_authority() -> void:
	var frame := Frame.new(null, null, null, null, null)
	for ticket in [null, {}, RefCounted.new()]:
		assert_bool(frame._ground_ticket_state(ticket, "issued").get("ok", false)).is_false()
		assert_bool(frame._validate_tree_ground_candidate(null, {}, null, ticket, 0.0, 3.0, 8.0).get("ok", false)).is_false()
	assert_bool(frame._ground_pending.is_empty()).is_true()
	assert_bool(frame._ground_certificate.is_empty()).is_true()
	assert_bool(frame._ground_invalidated).is_false()
	assert_bool(frame.has_method("_open_ground_ticket")).is_false()

func test_synthetic_pending_blocks_every_external_frame_entry_before_source_reads() -> void:
	var frame := Frame.new(null, null, null, null, null)
	var pending: Dictionary = {"synthetic_only": true}
	pending.make_read_only()
	frame._ground_pending = pending
	var calls: Array = [
		["prepare_frozen_sources", [null]], ["prepare_initial_boundary", [null]],
		["confirm_initial_boundary", [null]], ["cancel_initial_boundary", [null]],
		["capture_envelope", [11, {}]], ["prepare_bootstrap_presence", [11, {}, false]],
		["commit_bootstrap_presence", [null]], ["confirm_bootstrap_presence", [null]],
		["cancel_bootstrap_presence", [null]], ["submit", [0.125, []]],
		["confirm", [null]], ["confirm_fixture_tree_completion", [null]],
		["begin_fixture_tree_rollback", [null]], ["confirm_fixture_tree_rollback", [null]],
		["public_snapshot", []], ["combined_save_state", [false]],
		["save_confirmed_owner", ["normal_shutdown", false]],
		["advance_confirmed_ground", [null]],
		["apply_confirmed_inventory_left", [null, "", {}, 0, 1]],
		["apply_confirmed_inventory_drop", [null, "", "q_one", {}, 0, 1, Vector2.ZERO]],
		["prepare_fixture_tree_completion", [null, 11, "", ""]],
	]
	for row in calls:
		var result: Dictionary = frame.callv(row[0], row[1])
		assert_str(result.get("code", "")).is_equal("TREE_GROUND_SYNCHRONOUS_PENDING")
		assert_bool(result.get("ok", false)).is_false()
		assert_bool(is_same(frame._ground_pending, pending)).is_true()
		assert_str(frame.fatal_error).is_empty()
	assert_bool(frame.last_confirmed_snapshot().is_empty()).is_true()
	frame._clear_ground_transaction()
	assert_bool(frame._ground_pending.is_empty()).is_true()

func test_foreign_frame_cannot_install_measurements_as_certificate() -> void:
	var helper := Hot.new()
	var proof: Dictionary = {"metrics": {"bytes_delta": 0}}
	proof.make_read_only()
	assert_bool(helper.bind_certificate(RefCounted.new(), proof)).is_false()
	assert_bool(helper.certificate_matches(RefCounted.new(), proof)).is_false()
	assert_bool(helper._bound_certificate.is_empty()).is_true()
