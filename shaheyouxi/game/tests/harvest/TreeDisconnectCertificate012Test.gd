extends GdUnitTestSuite
## Negative certificate gates only, not an ENet/disconnection persistence proof.
const Owner = preload("res://scripts/actor/actor_terrain_network_main.gd")
var server: Node
func before_test() -> void:
	server = Owner.new()
	server._save_profile = 6
func after_test() -> void:
	server.free()
func test_no_certificate_cannot_freeze_transport_or_stop_session() -> void:
	server._live_input_roster[11] = {"profile_id":"player_untrusted", "actor_id":"entity_untrusted", "input_generation":1, "transport":{"peer_id":11,"incarnation":1,"transport":2,"api":3}}
	server._bootstrap_transport_incarnations[11] = 1
	assert_bool(server._freeze_tree_disconnected_transport(11)).is_false()
	assert_bool(server._tree_disconnect_transports.is_empty()).is_true()
	assert_int(server._live_input_cutoff).is_equal(-1)
func test_forged_stopping_cache_does_not_supply_identity() -> void:
	server._live_input_cutoff = 0
	server._tree_disconnect_transports[11] = {"peer_id":11,"incarnation":1,"transport":2,"api":3}
	assert_bool(server._live_peer_context(11).is_empty()).is_true()
	assert_bool(server._tree_live_certificate_matches()).is_false()
func test_capture_requires_actual_frame_owner_and_closes_failed_owner() -> void:
	var result: Dictionary = server._capture_tree_live_certificate()
	assert_bool(result.get("fatal", false)).is_true()
	assert_str(server._live_failure_code).is_equal("TREE_LIVE_CERTIFICATE_UNAVAILABLE")
	assert_bool(server._tree_live_certificate.is_empty()).is_true()
func test_cleanup_removes_certificate_and_transport_cache() -> void:
	server._tree_disconnect_transports[11] = {}
	server._tree_live_certificate = {"untrusted":true}
	server._tree_live_certificate.make_read_only()
	server._cleanup_runtime()
	assert_bool(server._tree_disconnect_transports.is_empty() and server._tree_live_certificate.is_empty()).is_true()
