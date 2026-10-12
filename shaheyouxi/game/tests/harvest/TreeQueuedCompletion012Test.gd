extends GdUnitTestSuite
## Real no-listener HOST lifecycle; queued requests are not completed hits.
const Helper = preload("res://tests/harvest/TreeOwnerCompletion012Test.gd")
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
func _queue_move(server: Node) -> Dictionary:
	return server._queue_live_actor_input(1,{"kind":"actor_input","sequence":1,"move":[0,0],"aim":[0.0,-1.0],"action":"none","phase":"none"})
func _queue_tree(server: Node, fixture: Dictionary) -> Dictionary:
	return server._queue_owner_fixture_tree_completion(1,fixture["tree_id"],Ledger.completion_identity(fixture["tree_id"]))
func test_queue_admits_only_at_boundary_and_preserves_actor_queue_through_rollback() -> void:
	var c: Dictionary = await helper._active_host()
	if c.is_empty(): return
	var server: Node = c["owner"]
	var frame: RefCounted = c["frame"]
	var clock_before: float = server._authority.world_seconds
	var first: Dictionary = server._advance_live_input_phase(0.125)
	assert_bool(first.get("pending",false) and first.get("delta_consumed",false)).is_true()
	if not first.get("pending",false): return
	assert_bool(not server._live_input_ticket.is_empty()).is_true()
	var authority := var_to_bytes(server._authority.persistent_state())
	assert_bool(_queue_move(server).get("queued",false)).is_true()
	var actor_queue := var_to_bytes(server._live_input_queue)
	var consumed: int = server._live_input_consumed_serial
	var request := _queue_tree(server,c["fixture"])
	assert_bool(request.get("queued",false) and request.get("admitted")==false and not request.has("accepted") and not request.has("ticket")).is_true()
	if not request.get("queued",false): return
	var ticket: RefCounted = request["request_ticket"]
	assert_bool(server._owner_tree_ticket.is_empty() and frame._tree_pending.is_empty()).is_true()
	assert_str(server._owner_fixture_tree_request_status(ticket)["phase"]).is_equal("queued")
	assert_str(_queue_tree(server,c["fixture"]).get("code","")).is_equal("TREE_OWNER_REQUEST_BUSY")
	await get_tree().physics_frame
	var admitted: Dictionary = server._advance_live_input_phase(0.125)
	assert_bool(admitted.get("tree_pending",false)).is_true()
	if not admitted.get("tree_pending",false): return
	assert_bool(admitted.get("delta_consumed",true)).is_false()
	assert_str(server._owner_fixture_tree_request_status(ticket)["phase"]).is_equal("admitted")
	assert_bool(server._live_input_ticket.is_empty()).is_true()
	assert_float(server._live_input_pending_delta).is_equal(0.0)
	assert_float(server._authority.world_seconds).is_equal(clock_before + 0.125)
	var before: String = server._inventory_owner.boundary_token()
	assert_bool(var_to_bytes(server._live_input_queue)==actor_queue).is_true()
	assert_int(server._live_input_consumed_serial).is_equal(consumed)
	assert_bool(var_to_bytes(server._authority.persistent_state())==authority).is_true()
	await get_tree().physics_frame
	assert_bool(server._begin_owner_fixture_tree_rollback().get("pending",false)).is_true()
	await get_tree().physics_frame
	var rolled: Dictionary = server._advance_live_input_phase(0.125)
	assert_bool(rolled.get("rollback_confirmed",false)).is_true()
	assert_bool(rolled.get("delta_consumed",true)).is_false()
	var outcome: Dictionary = server._owner_fixture_tree_request_status(ticket)
	assert_str(outcome["phase"]).is_equal("rollback_confirmed")
	assert_bool(server._owner_fixture_tree_request_status(ticket)==outcome).is_true()
	assert_bool(server._owner_fixture_tree_request_status(RefCounted.new()).get("ok",false)).is_false()
	assert_bool(var_to_bytes(server._live_input_queue)==actor_queue).is_true()
	assert_int(server._live_input_consumed_serial).is_equal(consumed)
	assert_str(server._inventory_owner.boundary_token()).is_equal(before)
	assert_bool(var_to_bytes(server._authority.persistent_state())==authority).is_true()
	print("TREE_QUEUED_ADMISSION_ROLLBACK_COMPLETE normal_shutdown_saved=false")
func test_stop_before_admission_rejects_request_then_drains_actor_and_saves_normally() -> void:
	var c: Dictionary = await helper._active_host()
	if c.is_empty(): return
	var server: Node = c["owner"]
	var trees := var_to_bytes(server._inventory_owner.tree_snapshot())
	var sequence: int = server._save_store.last_sequence
	assert_bool(_queue_move(server).get("queued",false)).is_true()
	var request := _queue_tree(server,c["fixture"])
	assert_bool(request.get("queued",false)).is_true()
	if not request.get("queued",false): return
	server._request_live_input_stop()
	assert_str(server._commit_confirmed_save("normal_shutdown").get("code","")).is_equal("TREE_OWNER_SAVE_PENDING")
	var submitted: Dictionary = server._advance_live_input_phase(0.125)
	assert_bool(submitted.get("pending",false) and submitted.get("delta_consumed",false)).is_true()
	if not submitted.get("pending",false): return
	var outcome: Dictionary = server._owner_fixture_tree_request_status(request["request_ticket"])
	assert_str(outcome["phase"]).is_equal("rejected")
	assert_str(outcome["code"]).is_equal("ACTOR_SESSION_STOPPING")
	assert_bool(outcome["admitted"]).is_false()
	assert_bool(server._owner_tree_request.is_empty() and server._owner_tree_ticket.is_empty() and server._bootstrap_frame._tree_pending.is_empty()).is_true()
	assert_bool(server._live_input_queue.is_empty()).is_true()
	assert_int(server._live_input_consumed_serial).is_equal(server._live_input_cutoff)
	await get_tree().physics_frame
	var stopped: Dictionary = server._advance_live_input_phase(0.125)
	assert_bool(stopped.get("close_ready",false) and stopped.get("save_ready",false)).is_true()
	if not stopped.get("close_ready",false): return
	assert_str(server._last_save_summary["reason"]).is_equal("normal_shutdown")
	assert_bool(server._bootstrap_last_save_receipt.get("complete",false)).is_true()
	assert_int(server._save_store.last_sequence).is_equal(sequence+1)
	assert_bool(var_to_bytes(server._inventory_owner.tree_snapshot())==trees).is_true()
	assert_bool(server._owner_fixture_tree_request_status(request["request_ticket"])==outcome).is_true()
	print("TREE_UNADMITTED_STOP_NORMAL_SAVE_COMPLETE listener=false tree_completed=false")
func test_changed_request_result_fails_before_any_actor_or_tree_advance() -> void:
	var c: Dictionary = await helper._active_host()
	if c.is_empty(): return
	var server: Node = c["owner"]
	var authority := var_to_bytes(server._authority.persistent_state())
	var root: String = server._inventory_owner.boundary_token()
	assert_bool(_queue_tree(server,c["fixture"]).get("queued",false)).is_true()
	server._owner_tree_request_result = {"unexpected":true}
	var failed: Dictionary = server._advance_live_input_phase(0.125)
	assert_bool(failed.get("fatal",false)).is_true()
	assert_str(server._live_failure_code).is_equal("TREE_OWNER_REQUEST_RESULT_CHANGED")
	assert_bool(var_to_bytes(server._authority.persistent_state())==authority).is_true()
	assert_str(server._inventory_owner.boundary_token()).is_equal(root)
	assert_bool(server._commit_confirmed_save("normal_shutdown").get("ok",false)).is_false()
