extends GdUnitTestSuite
## Actual no-socket host lifecycle, never a manually fabricated live roster.
const Helper = preload("res://tests/harvest/TreeFrameCompletion012Test.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
var helper
func before() -> void:
	helper = Helper.new()
	add_child(helper)
	helper.before()
func after_test() -> void:
	helper.after_test()
func after() -> void:
	helper.after()
	helper.free()
func _active_host() -> Dictionary:
	var c: Dictionary = await helper._opened_alive_frame(1)
	if c.is_empty(): return {}
	var owner: Node = c["owner"]
	# Isolated fixture has no listener. Runtime and presence were actually confirmed.
	owner._startup_ready = true
	var activated: Dictionary = owner.activate_supported_input_phase()
	assert_bool(activated.get("ok", false)).is_true()
	if not activated.get("ok", false): return {}
	assert_bool(owner._live_binding_check().get("ok", false)).is_true()
	assert_bool(owner._bootstrap_last_save_receipt.get("complete", false)).is_true()
	assert_str(owner._last_save_summary["reason"]).is_equal("bootstrap_join")
	return c

func test_owner_stop_during_detachment_preserves_receipt_and_restores_before_progress() -> void:
	var c: Dictionary = await _active_host()
	if c.is_empty(): return
	var owner: Node = c["owner"]
	var frame: RefCounted = c["frame"]
	var service: RefCounted = owner._inventory_owner
	var root: String = service.boundary_token()
	var authority: PackedByteArray = var_to_bytes(owner._authority.persistent_state())
	var receipt: PackedByteArray = var_to_bytes(owner._bootstrap_last_save_receipt)
	var event: String = Ledger.completion_identity(c["fixture"]["tree_id"])
	var prepared: Dictionary = owner._prepare_owner_fixture_tree_completion(1, c["fixture"]["tree_id"], event)
	assert_bool(prepared.get("pending", false) and prepared.get("ok", false)).is_true()
	if not prepared.get("ok", false): return
	var queued: Dictionary = owner._queue_live_actor_input(1, {"kind":"actor_input", "sequence":1, "move":[0,0], "aim":[0.0,-1.0], "action":"none", "phase":"none"})
	assert_bool(queued.get("queued", false)).is_true()
	var queue_bytes: PackedByteArray = var_to_bytes(owner._live_input_queue)
	var consumed: int = owner._live_input_consumed_serial
	owner._request_live_input_stop()
	assert_int(owner._live_input_cutoff).is_equal(owner._live_input_serial)
	var blocked: Dictionary = owner._commit_confirmed_save("normal_shutdown")
	assert_str(blocked.get("code", "")).is_equal("TREE_OWNER_SAVE_PENDING")
	assert_bool(var_to_bytes(owner._bootstrap_last_save_receipt) == receipt).is_true()
	assert_bool(owner._prepare_owner_fixture_tree_completion(1, c["fixture"]["tree_id"], event).get("ok", false)).is_false()
	var pending: Dictionary = owner._advance_live_input_phase(0.125)
	assert_bool(pending.get("tree_pending", false)).is_true()
	assert_bool(pending.get("delta_consumed", true)).is_false()
	assert_bool(var_to_bytes(owner._authority.persistent_state()) == authority).is_true()
	await get_tree().physics_frame
	var restoring: Dictionary = owner._begin_owner_fixture_tree_rollback()
	assert_bool(restoring.get("pending", false)).is_true()
	if not restoring.get("pending", false): return
	assert_str(owner._commit_confirmed_save("normal_shutdown").get("code", "")).is_equal("TREE_OWNER_SAVE_PENDING")
	await get_tree().physics_frame
	var confirmed: Dictionary = owner._advance_live_input_phase(0.125)
	assert_bool(confirmed.get("rollback_confirmed", false)).is_true()
	assert_bool(confirmed.get("delta_consumed", true)).is_false()
	assert_bool(owner._owner_tree_ticket.is_empty() and frame._tree_pending.is_empty()).is_true()
	assert_bool(service.boundary_token() == root and var_to_bytes(owner._authority.persistent_state()) == authority).is_true()
	assert_bool(var_to_bytes(owner._bootstrap_last_save_receipt) == receipt).is_true()
	assert_bool(not owner._live_input_close_ready).is_true()
	assert_int(owner._live_input_consumed_serial).is_equal(consumed)
	assert_bool(var_to_bytes(owner._live_input_queue) == queue_bytes).is_true()
	assert_int(owner._live_input_cutoff).is_greater(consumed)
	assert_bool(frame.public_snapshot().get("ok", false)).is_true()
	print("TREE_OWNER_STOP_ROLLBACK_CONFIRMED normal_shutdown_saved=false delta_consumed=false")
