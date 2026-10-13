extends GdUnitTestSuite
## Finite production transport bookkeeping + real Core/View/Panel. No ENet,
## native-world/Frame, GUI input delivery, disk receipts or runtime claims here.
const Live = preload("res://scripts/inventory/inventory_live012.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const View = preload("res://scripts/inventory/ui012/inventory_view012.gd")
const InventoryPanel = preload("res://scripts/inventory/ui012/inventory_panel012.gd")
const BaseOwner = preload("res://scripts/actor/actor_network_main.gd")
const Client = preload("res://scripts/actor/actor_terrain_play_client.gd")
const Server = preload("res://scripts/actor/actor_terrain_network_main.gd")
const Ground = preload("res://scripts/inventory/inventory_ground012.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const WORLD := "world_11111111111111111111111111111111"
const PROFILE := "player_22222222222222222222222222222222"
const OTHER := "player_33333333333333333333333333333333"
var _server: RefCounted
var _client: RefCounted
var _core: RefCounted
var _model: RefCounted
var _identity: Dictionary
var _transport: Dictionary
var _panel: Control

func before_test() -> void:
	_identity = {"world_id": WORLD, "server_epoch": "session_44444444444444444444444444444444", "player_profile_id": PROFILE, "player_instance_id": "entity_player_55555555555555555555555555555555", "peer_id": 11, "input_generation": 1}
	_transport = {"peer_id": 11, "incarnation": 7, "transport": 8, "api": 9}
	_core = Core.new(WORLD)
	assert_bool(_core.trusted_create_player(PROFILE)["ok"]).is_true()
	_server = Live.new()
	_client = Live.new()
	_model = View.new(WORLD, PROFILE)
	assert_bool(_server.bind_server(_identity, _transport, 0, _core.revision())["ok"]).is_true()
	assert_bool(_client.configure_client(_identity, _transport)["ok"]).is_true()

func after_test() -> void:
	if _panel != null:
		_panel.free()
		_panel = null

func _address() -> Dictionary:
	return {"container": "bag", "owner": PROFILE, "slot": 0}

func _seed(sequence: int = 0) -> void:
	# Isolated test-state preparation only; no runtime grant path exists.
	var state: Dictionary = _core.snapshot()
	state["players"][PROFILE]["bag"][0] = {"content_id": "mucai", "quantity": 7, "item_instance_id": "", "protected_instance_id": "", "state": {}}
	state["players"][PROFILE]["last_sequence"] = sequence
	assert_bool(_core.trusted_restore(state)["ok"]).is_true()

func _issue(kind: String = "view", revision: int = -1, sequence: int = -1, epoch: int = 0) -> Dictionary:
	var issued: Dictionary = _client.issue_client(kind, epoch, _address(), revision, sequence)
	assert_bool(issued["ok"]).is_true()
	assert_bool(_server.admit_server(11, issued["request"], _identity, _transport)["ok"]).is_true()
	return issued["request"]

func _complete() -> Dictionary:
	var event: Dictionary = _server.head_server()
	assert_bool(_server.validate_head_server(_identity, _transport)["ok"]).is_true()
	var request: Dictionary = event["request"]
	var result := {"ok": true}
	if request["kind"] == "left": result = _core.click_slot(PROFILE, request["address"], request["expected_revision"], request["sequence"])
	elif request["kind"] == "drop":
		# Pure Ground is the business oracle here; this does not claim native H1/Frame.
		result = Ground.prepare_drop(_core, PROFILE, request["drop_kind"], request["address"], request["expected_revision"], request["sequence"], Address.layer(WORLD, "body_live_fixture", "surface", 0), Vector2.ZERO, Vector2(3, 0), 0.0)
		if result["ok"]: assert_bool(_core.trusted_restore(result["state"])["ok"]).is_true()
	var completed: Dictionary = _server.complete_server(result, View.server_view(_core, PROFILE, _server.next_view_sequence(11)))
	assert_bool(completed["ok"]).is_true()
	assert_bool(_model.accept(completed["reply"]["view"])["ok"]).is_true()
	assert_bool(_client.accept_client(completed["reply"])["ok"]).is_true()
	return completed["reply"]

func _bootstrap() -> void:
	_issue()
	_complete()

func _close_request() -> Dictionary:
	var cursor: Dictionary = _client.client_checkpoint()
	var result: Dictionary = _identity.duplicate(true)
	result.merge({"inventory_initial_sequence": cursor["initial_sequence"], "inventory_cutoff_sequence": cursor["issued_sequence"], "inventory_processed_sequence": cursor["processed_sequence"], "inventory_accepted_sequence": cursor["accepted_sequence"], "inventory_revision": cursor["revision"], "inventory_pending_count": cursor["pending_count"]})
	return result

func _new_panel() -> void:
	_panel = InventoryPanel.new()
	_panel.bind_identity(WORLD, PROFILE)
	_panel.require_authenticated_open()
	_panel.build_controls()

func test_shared_base_and_old4_refuse_inventory() -> void:
	var base := BaseOwner.new()
	assert_bool(base._receive_inventory_request012(11, {})["ok"]).is_false()
	base.free()
	var server := Server.new()
	assert_bool(server._receive_inventory_request012(11, {})["ok"]).is_false()
	assert_bool(server.inventory_close_proof(11).is_empty()).is_true()
	server.free()

func test_empty_bootstrap_private_checkpoint_does_not_issue_left() -> void:
	_bootstrap()
	assert_int(_client.client_checkpoint()["initial_sequence"]).is_equal(0)
	assert_int(_client.client_checkpoint()["issued_sequence"]).is_equal(0)
	assert_int(_client.client_checkpoint()["pending_count"]).is_equal(0)
	assert_bool(_model.snapshot()["inventory"]["carry"] == null).is_true()
	assert_bool(_server.server_drained()).is_true()

func test_rejection_consumes_processed_only_then_contiguous_success() -> void:
	_seed()
	_bootstrap()
	var revision: int = _core.revision()
	_issue("left", revision - 1, 1)
	var rejected := _complete()
	assert_bool(rejected["ok"]).is_false()
	assert_int(rejected["processed_sequence"]).is_equal(1)
	assert_int(rejected["accepted_sequence"]).is_equal(0)
	assert_int(_core.revision()).is_equal(revision)
	_issue("left", revision, 2)
	var accepted := _complete()
	assert_bool(accepted["ok"]).is_true()
	assert_bool(accepted["authoritative"] and not accepted["durable"]).is_true()
	assert_int(accepted["accepted_sequence"]).is_equal(2)
	assert_int(accepted["revision"]).is_equal(revision + 1)

func test_resumed_cursor_starts_from_persisted_last_sequence() -> void:
	_seed(17)
	_server = Live.new()
	assert_bool(_server.bind_server(_identity, _transport, 17, _core.revision())["ok"]).is_true()
	_bootstrap()
	assert_int(_client.client_checkpoint()["initial_sequence"]).is_equal(17)
	assert_bool(_client.issue_client("left", 0, _address(), _core.revision(), 1)["ok"]).is_false()
	_issue("left", _core.revision(), 18)
	assert_int(_complete()["accepted_sequence"]).is_equal(18)

func test_duplicate_jump_and_unknown_request_fields_never_admit() -> void:
	_bootstrap()
	var issued: Dictionary = _client.issue_client("left", 0, _address(), _core.revision(), 1)
	var request: Dictionary = issued["request"]
	for bad_sequence in [0, 2, 1.0, true]:
		var bad: Dictionary = request.duplicate(true)
		bad["sequence"] = bad_sequence
		assert_bool(_server.admit_server(11, bad, _identity, _transport)["ok"]).is_false()
	var extra: Dictionary = request.duplicate(true)
	extra["grant"] = {"quantity": 999}
	assert_bool(_server.admit_server(11, extra, _identity, _transport)["ok"]).is_false()
	assert_bool(_server.admit_server(11, request, _identity, _transport)["ok"]).is_true()
	assert_bool(_server.admit_server(11, request, _identity, _transport)["ok"]).is_false()
	_complete()
	assert_int(_client.client_checkpoint()["processed_sequence"]).is_equal(1)

func test_foreign_profile_epoch_generation_and_connection_refuse() -> void:
	var request: Dictionary = _client.issue_client("view", 0)["request"]
	for pair in [["player_profile_id", OTHER], ["server_epoch", "session_66666666666666666666666666666666"], ["input_generation", 2], ["peer_id", 12]]:
		var bad: Dictionary = request.duplicate(true)
		bad[pair[0]] = pair[1]
		assert_bool(_server.admit_server(11, bad, _identity, _transport)["ok"]).is_false()
	var changed: Dictionary = _transport.duplicate(true)
	changed["incarnation"] += 1
	assert_bool(_server.admit_server(11, request, _identity, changed)["ok"]).is_false()
	assert_bool(_server.server_drained()).is_true()

func test_dequeue_rechecks_connection_and_confirmed_identity() -> void:
	_issue()
	var changed: Dictionary = _transport.duplicate(true)
	changed["incarnation"] += 1
	assert_bool(_server.validate_head_server(_identity, changed)["ok"]).is_false()
	var identity: Dictionary = _identity.duplicate(true)
	identity["input_generation"] += 1
	assert_bool(_server.validate_head_server(identity, _transport)["ok"]).is_false()
	assert_bool(_server.server_drained()).is_false()

func test_requests_have_strict_types_and_address_bounds() -> void:
	_bootstrap()
	var request: Dictionary = _client.issue_client("left", 0, _address(), _core.revision(), 1)["request"]
	for field in ["schema_version", "peer_id", "input_generation", "request_id", "context_epoch", "expected_revision", "sequence"]:
		for number in [true, 1.0, -1, Live.MAX_SEQUENCE + 1]:
			var bad: Dictionary = request.duplicate(true)
			bad[field] = number
			assert_bool(Live.validate_request(bad)["ok"]).is_false()
	for slot in [-1, 40, 1.0, true]:
		var bad: Dictionary = request.duplicate(true)
		bad["address"]["slot"] = slot
		assert_bool(Live.validate_request(bad)["ok"]).is_false()
	var oversized: Dictionary = request.duplicate(true)
	oversized["address"]["owner"] = "a".repeat(4096)
	assert_bool(Live.validate_request(oversized)["ok"]).is_false()

func test_control_queue_bound_and_left_singleflight() -> void:
	_bootstrap()
	for index in range(Live.MAX_CONTROLS): _issue("view", -1, -1, index)
	assert_bool(_client.issue_client("view", 99)["ok"]).is_false()
	assert_bool(_client.issue_client("left", 0, _address(), _core.revision(), 1)["ok"]).is_false()
	for _index in range(Live.MAX_CONTROLS): _complete()
	_issue("left", _core.revision(), 1)
	assert_bool(_client.issue_client("left", 0, _address(), _core.revision(), 2)["ok"]).is_false()

func test_reply_is_private_and_has_independent_transport_and_view_cursors() -> void:
	assert_bool(_core.trusted_create_player(OTHER)["ok"]).is_true()
	_issue()
	var reply := _complete()
	assert_str(reply["view"]["profile_id"]).is_equal(PROFILE)
	assert_bool(reply.has("inventory_component") or reply["view"].has("players")).is_false()
	assert_bool(reply["view"]["chests"].is_empty()).is_true()
	assert_int(reply["view"]["view_sequence"]).is_equal(1)
	assert_int(reply["processed_sequence"]).is_equal(0)

func test_reply_wrong_identity_float_and_false_durable_refuse() -> void:
	_issue()
	var completed: Dictionary = _server.complete_server({"ok": true}, View.server_view(_core, PROFILE, 1))
	for pair in [["peer_id", 11.0], ["input_generation", true], ["durable", true], ["authoritative", false], ["processed_sequence", 0.0], ["player_profile_id", OTHER]]:
		var bad: Dictionary = completed["reply"].duplicate(true)
		bad[pair[0]] = pair[1]
		assert_bool(_client.accept_client(bad)["ok"]).is_false()
	assert_bool(_client.accept_client(completed["reply"])["ok"]).is_true()
	assert_bool(_client.accept_client(completed["reply"])["ok"]).is_false()

func test_close_freezes_cutoff_and_controls_must_also_drain() -> void:
	_bootstrap()
	_issue("left", _core.revision(), 1)
	_issue("close", -1, -1, 1)
	_client.stop_client()
	_server.stop_server()
	assert_bool(_client.issue_client("view", 1)["ok"]).is_false()
	_complete()
	assert_int(_client.client_checkpoint()["pending_count"]).is_equal(0)
	assert_int(_client.client_pending_count()).is_equal(1)
	assert_bool(_server.server_drained()).is_false()
	_complete()
	var proof: Dictionary = _server.server_proof(11, View.server_view(_core, PROFILE, 0))
	assert_bool(Live.validate_close_proof(proof, _close_request())["ok"]).is_true()
	var future: Dictionary = _close_request()
	future["inventory_cutoff_sequence"] = 0
	assert_bool(Live.validate_close_proof(proof, future)["ok"]).is_false()
	assert_bool(_server.admit_server(11, {}, _identity, _transport)["ok"]).is_false()

func test_pre_stop_coverage_and_final_proof_are_separate_exact_modes() -> void:
	_bootstrap()
	var running: Dictionary = _server.server_proof(11, View.server_view(_core, PROFILE, 0))
	assert_bool(Live.validate_request_coverage(running, _close_request())["ok"]).is_true()
	assert_bool(Live.validate_close_proof(running, _close_request())["ok"]).is_false()
	_server.stop_server()
	var stopped: Dictionary = _server.server_proof(11, View.server_view(_core, PROFILE, 0))
	assert_bool(Live.validate_close_proof(stopped, _close_request())["ok"]).is_true()
	assert_bool(Live.validate_request_coverage(stopped, _close_request())["ok"]).is_false()
	var future: Dictionary = _close_request()
	future["inventory_processed_sequence"] = 1
	assert_bool(Live.validate_close_proof(stopped, future)["ok"]).is_false()

func test_json_proof_normalization_does_not_relax_network() -> void:
	_bootstrap()
	var proof: Dictionary = _server.server_proof(11, View.server_view(_core, PROFILE, 0))
	var json_value: Variant = JSON.parse_string(JSON.stringify(proof))
	var normalized: Dictionary = Live.normalize_close_proof_json(json_value)
	assert_bool(normalized["ok"]).is_true()
	assert_bool(Live.validate_request_coverage(normalized["proof"], _close_request())["ok"]).is_true()
	for number in [true, 0.5, INF, NAN]:
		var bad: Dictionary = json_value.duplicate(true)
		bad["processed_sequence"] = number
		assert_bool(Live.normalize_close_proof_json(bad)["ok"]).is_false()
	json_value["extra"] = false
	assert_bool(Live.normalize_close_proof_json(json_value)["ok"]).is_false()

func test_reconnect_cannot_reconfigure_or_retry_pending_client() -> void:
	_bootstrap()
	_issue("left", _core.revision(), 1)
	_client.close()
	var replacement: Dictionary = _transport.duplicate(true)
	replacement["incarnation"] += 1
	assert_bool(_client.configure_client(_identity, replacement)["ok"]).is_false()
	assert_bool(_client.issue_client("left", 0, _address(), _core.revision(), 1)["ok"]).is_false()
	assert_bool(_client.client_matches(_identity, replacement)).is_false()

func test_async_first_open_cancelled_by_escape_toggle_or_context_loss() -> void:
	_new_panel()
	for reason in ["escape", "toggle", "context_lost"]:
		_panel.open_personal()
		var epoch: int = _panel.context_epoch()
		assert_bool(_panel.personal_open_pending()).is_true()
		if reason == "context_lost": _panel.context_lost()
		else: _panel.close_panel(reason)
		assert_bool(_panel.apply_server_view(View.server_view(_core, PROFILE, epoch))["ok"]).is_true()
		assert_bool(_panel.complete_personal_open(epoch)).is_false()
		assert_bool(_panel.get_node("InventoryMask").visible).is_false()

func test_newer_open_ignores_late_old_completion_and_stopped_open() -> void:
	_new_panel()
	_panel.open_personal()
	var old: int = _panel.context_epoch()
	_panel.close_panel("toggle")
	_panel.open_personal()
	var current: int = _panel.context_epoch()
	_panel.apply_server_view(View.server_view(_core, PROFILE, 1))
	assert_bool(_panel.complete_personal_open(old)).is_false()
	assert_bool(_panel.complete_personal_open(current)).is_true()
	_panel.close_panel()
	_panel.open_personal()
	_panel.set_requests_enabled(false)
	assert_bool(_panel.complete_personal_open(_panel.context_epoch())).is_false()
	assert_bool(_panel.request_left(_address())).is_false()

func test_panel_control_gate_does_not_consume_unsent_left_sequence() -> void:
	_new_panel()
	_panel.apply_server_view(View.server_view(_core, PROFILE, 1))
	_panel.open_personal()
	_panel.complete_personal_open(_panel.context_epoch())
	_panel.set_left_enabled(false)
	assert_bool(_panel.request_left(_address())).is_false()
	assert_int(_panel._last_emitted).is_equal(0)
	_panel.set_left_enabled(true)
	assert_bool(_panel.request_left(_address())).is_true()
	assert_int(_panel._last_emitted).is_equal(1)

func test_panel_unknown_item_and_overflow_stay_closed() -> void:
	_new_panel()
	_panel.open_personal()
	var value: Dictionary = View.server_view(_core, PROFILE, 1)
	value["inventory"]["bag"][0] = {"content_id": "unregistered", "quantity": 1, "item_instance_id": "", "protected_instance_id": "", "state": {}}
	assert_bool(_panel.apply_server_view(value)["ok"]).is_false()
	assert_bool(_panel.complete_personal_open(_panel.context_epoch())).is_false()
	value["inventory"]["bag"][0]["content_id"] = "mucai"
	value["inventory"]["bag"][0]["quantity"] = Live.MAX_SEQUENCE
	assert_bool(_panel.apply_server_view(value)["ok"]).is_false()
	assert_bool(_panel.get_node("InventoryMask").visible).is_false()

func test_stale_running_report_waits_but_future_cursor_and_identity_refuse() -> void:
	_seed()
	_bootstrap()
	var old: Dictionary = _server.server_proof(11, View.server_view(_core, PROFILE, 0))
	_issue("left", _core.revision(), 1)
	_complete()
	assert_bool(Live.validate_request_coverage(old, _close_request()).get("pending", false)).is_true()
	var future: Dictionary = old.duplicate(true)
	future["processed_sequence"] = 2
	assert_bool(Live.validate_request_coverage(future, _close_request()).get("pending", false)).is_false()
	old["player_profile_id"] = OTHER
	assert_bool(Live.validate_request_coverage(old, _close_request()).get("pending", false)).is_false()

func test_client_teardown_suppresses_pending_open_close_callback() -> void:
	_new_panel()
	var client := Client.new()
	client._inventory_schema = 5
	client._inventory_live = _client
	client._inventory_panel = _panel
	_panel.open_personal()
	_panel.close_intent.connect(client._request_inventory_close)
	client._close_inventory_client()
	assert_bool(client._inventory_client_closed).is_true()
	assert_str(client._local_last_error).is_equal("")
	assert_bool(_panel.personal_open_pending()).is_false()
	client._inventory_panel = null
	client.free()

func test_client_teardown_suppresses_chest_close_callback() -> void:
	_new_panel()
	var chest := "entity_inventory_live_chest"
	_core.trusted_create_chest(chest)
	_core.trusted_set_chest_access(PROFILE, chest, true)
	_panel.apply_server_view(View.server_view(_core, PROFILE, 1))
	_panel.grant_chest_context(chest, _panel.context_epoch())
	assert_bool(_panel.open_chest(chest)).is_true()
	var client := Client.new()
	client._inventory_schema = 5
	client._inventory_live = _client
	client._inventory_panel = _panel
	_panel.close_intent.connect(client._request_inventory_close)
	client._close_inventory_client()
	assert_str(client._local_last_error).is_equal("")
	assert_str(_panel._context).is_equal("closed")
	client._inventory_panel = null
	client.free()

func test_global_queue_budget_refuses_without_advancing_new_request() -> void:
	var server := Live.new()
	for index in range(Live.MAX_QUEUE):
		var identity: Dictionary = _identity.duplicate(true)
		identity["peer_id"] = 100 + index
		identity["player_profile_id"] = "player_" + ("%032x" % (100 + index))
		identity["player_instance_id"] = "entity_player_" + ("%032x" % (100 + index))
		var transport: Dictionary = _transport.duplicate(true)
		transport["peer_id"] = identity["peer_id"]
		assert_bool(server.bind_server(identity, transport, 0, 0)["ok"]).is_true()
		var request: Dictionary = identity.duplicate(true)
		request.merge({"schema_version": 1, "contract": Live.CONTRACT, "kind": "view", "request_id": 1, "context_epoch": 0})
		assert_bool(server.admit_server(identity["peer_id"], request, identity, transport)["ok"]).is_true()
	var stream: Dictionary = server._streams[100]
	var extra: Dictionary = stream["identity"].duplicate(true)
	extra.merge({"schema_version": 1, "contract": Live.CONTRACT, "kind": "view", "request_id": 2, "context_epoch": 0})
	assert_str(server.admit_server(100, extra, stream["identity"], stream["transport"])["code"]).is_equal("INVENTORY_QUEUE_BUDGET")
	assert_int(server._streams[100]["request_id"]).is_equal(1)
	assert_int(server._queue.size()).is_equal(Live.MAX_QUEUE)

func test_closed_chest_left_is_processed_rejection_without_grant() -> void:
	var chest := "entity_inventory_live_unopened"
	_core.trusted_create_chest(chest)
	_bootstrap()
	var address := {"container": "chest", "owner": chest, "slot": 0}
	var issued: Dictionary = _client.issue_client("left", 0, address, _core.revision(), 1)
	assert_bool(_server.admit_server(11, issued["request"], _identity, _transport)["ok"]).is_true()
	var reply := _complete()
	assert_bool(reply["ok"]).is_false()
	assert_int(reply["processed_sequence"]).is_equal(1)
	assert_int(reply["accepted_sequence"]).is_equal(0)
	assert_bool(reply["view"]["chests"].is_empty()).is_true()

func test_actual_frame_receipt_hash_summary_is_schema5_only() -> void:
	var server := Server.new()
	server._bootstrap_last_save_receipt = {"sequence": 7, "main_committed": true, "complete": true, "state_sha256": "a".repeat(64)}
	assert_dict(server._bootstrap_save_receipt_summary()).is_equal({"sequence": 7, "main_committed": true, "complete": true})
	server._save_profile = 5
	assert_dict(server._bootstrap_save_receipt_summary()).is_equal(server._bootstrap_last_save_receipt)
	server._bootstrap_last_save_receipt.erase("state_sha256")
	assert_str(server._bootstrap_save_receipt_summary()["state_sha256"]).is_empty()
	server.free()

func test_confirmed_carry_save_waits_for_actual_reply_without_return_or_drop() -> void:
	_seed()
	_bootstrap()
	_new_panel()
	_panel.apply_server_view(View.server_view(_core, PROFILE, 1))
	var client := Client.new()
	client._inventory_schema = 5
	client._inventory_live = _client
	client._inventory_panel = _panel
	_issue("left", _core.revision(), 1)
	assert_bool(client._inventory_preclose_ready()).is_false()
	assert_bool(client._inventory_close_waiting).is_true()
	assert_bool(_client._stopping).is_false()
	var reply := _complete()
	_panel.apply_server_view(reply["view"])
	var before: Dictionary = _core.snapshot()
	assert_bool(before["players"][PROFILE]["carry"] != null).is_true()
	assert_bool(client._inventory_preclose_ready()).is_true()
	assert_bool(client._inventory_close_waiting).is_false()
	assert_str(client._inventory_close_notice).is_empty()
	assert_dict(_core.snapshot()).is_equal(before)
	assert_bool(_panel._requests_enabled).is_false()
	_issue("left", _core.revision(), 2)
	reply = _complete()
	_panel.apply_server_view(reply["view"])
	assert_bool(client._inventory_preclose_ready()).is_true()
	assert_str(client._inventory_close_notice).is_empty()
	client._inventory_panel = null
	client.free()

func test_preclose_missing_reply_uses_bounded_deadline_without_retry_or_extension() -> void:
	_bootstrap()
	_new_panel()
	_panel.apply_server_view(View.server_view(_core, PROFILE, 1))
	var client := Client.new()
	client._inventory_schema = 5
	client._inventory_live = _client
	client._inventory_panel = _panel
	_issue("view")
	assert_bool(client._inventory_preclose_ready()).is_false()
	var started: int = client._inventory_close_wait_started_usec
	assert_bool(client._inventory_preclose_ready()).is_false()
	assert_int(client._inventory_close_wait_started_usec).is_equal(started)
	assert_bool(client._inventory_preclose_timed_out(started + Client.CLOSE_TIMEOUT_USEC)).is_false()
	assert_bool(client._inventory_preclose_timed_out(started + Client.CLOSE_TIMEOUT_USEC + 1)).is_true()
	assert_int(_client.client_pending_count()).is_equal(1)
	var reply := _complete()
	_panel.apply_server_view(reply["view"])
	assert_bool(client._inventory_preclose_ready()).is_true()
	assert_int(client._inventory_close_wait_started_usec).is_equal(0)
	assert_bool(client._inventory_preclose_timed_out(started + Client.CLOSE_TIMEOUT_USEC + 1)).is_false()
	client._inventory_panel = null
	client.free()

func test_drop_rejection_retires_sequence_then_left_continues() -> void:
	_seed()
	_bootstrap()
	var issued: Dictionary = _client.issue_client("drop", 0, _address(), _core.revision(), 1, "carry_all", [1.0, 0.0])
	assert_bool(issued["ok"]).is_true()
	assert_bool(_server.admit_server(11, issued["request"], _identity, _transport)["ok"]).is_true()
	var done: Dictionary = _server.complete_server({"ok": false, "code": "INVENTORY_EMPTY_SLOT"}, View.server_view(_core, PROFILE, _server.next_view_sequence(11)))
	assert_bool(done["ok"]).is_true()
	assert_bool(_client.accept_client(done["reply"])["ok"]).is_true()
	assert_int(done["reply"]["processed_sequence"]).is_equal(1)
	assert_int(done["reply"]["accepted_sequence"]).is_equal(0)
	_issue("left", _core.revision(), 2)
	assert_bool(_complete()["ok"]).is_true()
func test_drop_obeys_cutoff_and_rejects_bad_direction_or_action() -> void:
	_bootstrap()
	assert_bool(_client.issue_client("drop", 0, _address(), _core.revision(), 1, "unknown", [1.0, 0.0])["ok"]).is_false()
	var hotbar := {"container": "hotbar", "owner": PROFILE, "slot": 0}
	assert_bool(_client.issue_client("drop", 0, hotbar, _core.revision(), 1, "q_one", [NAN, 0.0])["ok"]).is_false()
	var issued: Dictionary = _client.issue_client("drop", 0, hotbar, _core.revision(), 1, "q_one", [1.0, 0.0])
	_server.stop_server()
	assert_bool(_server.admit_server(11, issued["request"], _identity, _transport)["ok"]).is_false()
func test_q_nonhotbar_business_rejections_ack_then_selected_hotbar_succeeds() -> void:
	_seed()
	assert_bool(_core.trusted_create_chest("chest_live_fixture")["ok"]).is_true()
	var state: Dictionary = _core.snapshot()
	state["players"][PROFILE]["hotbar"][0] = state["players"][PROFILE]["bag"][0].duplicate(true)
	state["chests"]["chest_live_fixture"]["slots"][0] = state["players"][PROFILE]["bag"][0].duplicate(true)
	assert_bool(_core.trusted_restore(state)["ok"]).is_true()
	assert_bool(_core.trusted_set_chest_access(PROFILE, "chest_live_fixture", true)["ok"]).is_true()
	_bootstrap()
	var before: PackedByteArray = var_to_bytes(_core.snapshot())
	var sequence: int = 0
	for source in [_address(), {"container": "chest", "owner": "chest_live_fixture", "slot": 0}]:
		sequence += 1
		var issued: Dictionary = _client.issue_client("drop", 0, source, _core.revision(), sequence, "q_one", [1.0, 0.0])
		assert_bool(issued["ok"]).is_true()
		assert_bool(_server.admit_server(11, issued["request"], _identity, _transport)["ok"]).is_true()
		var reply: Dictionary = _complete()
		assert_bool(reply["ok"]).is_false()
		assert_str(reply["code"]).is_equal("DROP_Q_HOTBAR_REQUIRED")
		assert_int(reply["processed_sequence"]).is_equal(sequence)
		assert_int(reply["accepted_sequence"]).is_equal(0)
		assert_int(_client.client_pending_count()).is_equal(0)
		assert_bool(_server.server_drained()).is_true()
		assert_bool(var_to_bytes(_core.snapshot()) == before).is_true()
	var issued: Dictionary = _client.issue_client("drop", 0, {"container": "hotbar", "owner": PROFILE, "slot": 0}, _core.revision(), 3, "q_one", [1.0, 0.0])
	assert_bool(issued["ok"]).is_true()
	assert_bool(_server.admit_server(11, issued["request"], _identity, _transport)["ok"]).is_true()
	var reply: Dictionary = _complete()
	assert_bool(reply["ok"]).is_true()
	assert_int(reply["processed_sequence"]).is_equal(3)
	assert_int(reply["accepted_sequence"]).is_equal(3)
	assert_int(_core.snapshot()["players"][PROFILE]["hotbar"][0]["quantity"]).is_equal(6)
	assert_int(_core.snapshot()["players"][PROFILE]["bag"][0]["quantity"]).is_equal(7)
	assert_int(_core.snapshot()["ground"].values()[0]["stack"]["quantity"]).is_equal(1)
	assert_int(_client.client_pending_count()).is_equal(0)
	assert_bool(_server.server_drained()).is_true()
func test_unsolicited_sync_advances_view_not_action_cursor() -> void:
	_bootstrap()
	var view: Dictionary = View.server_view(_core, PROFILE, _server.next_view_sequence(11))
	var sync: Dictionary = _server.sync_server(11, view)
	assert_bool(sync["ok"]).is_true()
	assert_bool(_client.accept_sync_client(_identity, sync["view"])["ok"]).is_true()
	assert_int(_client.client_checkpoint()["accepted_sequence"]).is_equal(0)
	assert_int(_client.client_checkpoint()["processed_sequence"]).is_equal(0)
func test_sync_during_pending_request_does_not_retire_it() -> void:
	_seed()
	_bootstrap()
	var sync: Dictionary = _server.sync_server(11, View.server_view(_core, PROFILE, _server.next_view_sequence(11)))
	_issue("left", _core.revision(), 1)
	var skipped: Dictionary = _client.accept_sync_client(_identity, sync["view"])
	assert_bool(skipped["skipped"]).is_true()
	assert_int(_client.client_pending_count()).is_equal(1)
	assert_bool(_complete()["ok"]).is_true()

func test_initial_sync_before_first_private_reply_is_skipped_then_converges() -> void:
	var early: Dictionary = _server.sync_server(11, View.server_view(_core, PROFILE, _server.next_view_sequence(11)))
	_issue("view")
	assert_bool(_client.client_ready()).is_false()
	assert_bool(_client.accept_sync_client(_identity, early["view"])["skipped"]).is_true()
	assert_int(_client.client_pending_count()).is_equal(1)
	assert_dict(_client.client_checkpoint()).is_empty()
	assert_bool(_complete()["ok"]).is_true()
	var next: Dictionary = _server.sync_server(11, View.server_view(_core, PROFILE, _server.next_view_sequence(11)))
	var synced: Dictionary = _client.accept_sync_client(_identity, next["view"])
	assert_bool(synced["ok"] and not synced["skipped"]).is_true()
	assert_int(_client.client_pending_count()).is_equal(0)

func test_sync_after_stop_is_skipped_without_changing_frozen_checkpoint() -> void:
	_bootstrap()
	var pending: Dictionary = _server.sync_server(11, View.server_view(_core, PROFILE, _server.next_view_sequence(11)))
	var before: Dictionary = _client.client_checkpoint()
	_client.stop_client()
	assert_bool(_client.accept_sync_client(_identity, pending["view"])["skipped"]).is_true()
	assert_dict(_client.client_checkpoint()).is_equal(before)
	assert_int(_client.client_pending_count()).is_equal(0)

func test_initial_and_stopping_sync_still_reject_foreign_identity() -> void:
	var foreign: Dictionary = _identity.duplicate(true)
	foreign["server_epoch"] = "session_99999999999999999999999999999999"
	var view: Dictionary = View.server_view(_core, PROFILE, 1)
	assert_bool(_client.accept_sync_client(foreign, view)["ok"]).is_false()
	_bootstrap()
	_client.stop_client()
	assert_bool(_client.accept_sync_client(foreign, view)["ok"]).is_false()
