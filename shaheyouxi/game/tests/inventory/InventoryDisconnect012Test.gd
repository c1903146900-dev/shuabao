extends GdUnitTestSuite
## Signal/cutoff and bookkeeping tests only, no ENet or disk proof.
const Server = preload("res://scripts/actor/actor_terrain_network_main.gd")
const Live = preload("res://scripts/inventory/inventory_live012.gd")
const WORLD := "world_11111111111111111111111111111111"
const PROFILE := "player_22222222222222222222222222222222"
var server: Node
var identity: Dictionary
var transport: Dictionary
func before_test() -> void:
	server = Server.new()
	server._save_profile = 5
	server._startup_ready = true
	server._live_input_enabled = true
	server._live_input_activated = true
	server._live_input_serial = 7
	identity = {"world_id": WORLD, "server_epoch": "session_44444444444444444444444444444444", "player_profile_id": PROFILE, "player_instance_id": "entity_player_55555555555555555555555555555555", "peer_id": 11, "input_generation": 1}
	transport = {"peer_id": 11, "incarnation": 7, "transport": 8, "api": 9}
	server._bootstrap_transport_incarnations[11] = 7
	server._live_input_roster[11] = {"profile_id": PROFILE, "actor_id": identity["player_instance_id"], "input_generation": 1, "transport": transport.duplicate(true)}
	server._inventory_live = Live.new()
	assert_bool(server._inventory_live.bind_server(identity, transport, 0, 0)["ok"]).is_true()
func after_test() -> void:
	server.free()
func test_disconnect_freezes_cutoff_and_original_transport() -> void:
	server._on_peer_disconnected(11)
	assert_int(server._live_input_cutoff).is_equal(7)
	assert_bool(server._inventory_live._stopping).is_true()
	assert_bool(server._live_peer_context(11) == transport).is_true()
	assert_bool(server._bootstrap_transport_incarnations.has(11)).is_false()
	assert_bool(server._inventory_disconnect_transports.has(11)).is_true()
func test_recycled_peer_cannot_replace_old_queue_context_or_admit_input() -> void:
	server._on_peer_disconnected(11)
	server._bootstrap_transport_incarnations[11] = 8
	assert_bool(server._live_peer_context(11) == transport).is_true()
	assert_bool(server._receive_inventory_request012(11, {})["ok"]).is_false()
	assert_str(server._queue_live_actor_input(11, {})["code"]).is_equal("ACTOR_SESSION_STOPPING")
func test_cleanup_destroys_frozen_transport_cache() -> void:
	server._on_peer_disconnected(11)
	server._cleanup_runtime()
	assert_bool(server._inventory_disconnect_transports.is_empty()).is_true()
func test_unreceived_request_is_not_fabricated_at_stop() -> void:
	assert_int(server._inventory_live._queue.size()).is_equal(0)
	server._on_peer_disconnected(11)
	assert_int(server._inventory_live._queue.size()).is_equal(0)
	assert_bool(server._inventory_live.server_drained()).is_true()
func test_received_pending_request_retains_original_identity_and_cursor() -> void:
	var request: Dictionary = identity.duplicate(true)
	request.merge({"schema_version": 1, "contract": Live.CONTRACT, "kind": "left", "request_id": 1, "context_epoch": 0, "sequence": 1, "expected_revision": 0, "address": {"container": "bag", "owner": PROFILE, "slot": 0}})
	assert_bool(server._inventory_live.admit_server(11, request, identity, transport)["ok"]).is_true()
	server._on_peer_disconnected(11)
	assert_bool(server._inventory_live.validate_head_server(identity, server._live_peer_context(11))["ok"]).is_true()
	assert_int(server._inventory_live._queue.size()).is_equal(1)
	assert_int(server._inventory_live._streams[11]["accepted"]).is_equal(0)
	assert_int(server._inventory_live._streams[11]["received"]).is_equal(1)
