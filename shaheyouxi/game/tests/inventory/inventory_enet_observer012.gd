extends "res://scripts/actor/actor_terrain_network_main.gd"
## Test observer only. Inherited authority RPC verifies sender and transport.
## Authentication/admission/Frame/save unchanged. Only the test-armed local
## transport close has a single-use expected disconnect callback below.
signal private_reply_seen(value: Variant)
func _receive_inventory_reply012(value: Variant) -> void:
	private_reply_seen.emit(value)

# This technical probe has no ordinary GUI coordinator. Reproduce only the
# already-existing packet startup timeout from actor_terrain_play_client.gd
# _on_connected/_finish_ordinary_startup_timeout/_after_client_snapshot/_process.
# No hello, welcome, snapshot, identity, admission or save result is substituted.
var probe_startup_events: Array = []
var _probe_welcome_seen := false
var _probe_startup_packet: ENetPacketPeer
var _probe_startup_deadline_usec: int = 0
func _on_connected() -> void:
	probe_startup_events.append({"event":"connected", "usec":Time.get_ticks_usec()})
	_probe_startup_packet = _peer.get_peer(1)
	if _probe_startup_packet == null or _probe_startup_packet.get_state() != ENetPacketPeer.STATE_CONNECTED:
		_fail("PROBE_STARTUP_PACKET_INVALID", "Real startup packet unavailable")
		return
	_probe_startup_packet.set_timeout(32, 30000, 30000)
	_probe_startup_deadline_usec = Time.get_ticks_usec() + 30000000
	super._on_connected()

func _finish_probe_startup_timeout(reason: String) -> void:
	if _probe_startup_deadline_usec <= 0: return
	probe_startup_events.append({"event":"restore_timeout", "reason":reason, "usec":Time.get_ticks_usec()})
	if _probe_startup_packet != null and _probe_startup_packet.get_state() == ENetPacketPeer.STATE_CONNECTED:
		_probe_startup_packet.set_timeout(32, 5000, 30000)
	_probe_startup_packet = null
	_probe_startup_deadline_usec = 0

func _after_client_snapshot(incoming: Dictionary) -> void:
	super._after_client_snapshot(incoming)
	if not _closing and not _fatal_shutdown and _actor_client_state != null and _actor_client_state.ready:
		if _probe_startup_deadline_usec > 0: probe_startup_events.append({"event":"first_valid_snapshot", "usec":Time.get_ticks_usec()})
		_finish_probe_startup_timeout("snapshot")

func _process(delta: float) -> void:
	if _probe_startup_deadline_usec > 0 and Time.get_ticks_usec() >= _probe_startup_deadline_usec:
		_finish_probe_startup_timeout("deadline")
	if not _probe_welcome_seen and not _welcome.is_empty():
		_probe_welcome_seen = true
		probe_startup_events.append({"event":"welcome_observed", "usec":Time.get_ticks_usec()})
	super._process(delta)

var _probe_expected_close: Dictionary = {}
var probe_expected_disconnect_seen := false
func arm_probe_expected_close(identity: Dictionary, transport: Dictionary, checkpoint: Dictionary) -> bool:
	if not _probe_expected_close.is_empty() or _closing or _fatal_shutdown: return false
	var context := _client_actor_input_context()
	if not context.get("ok", false): return false
	context["identity"]["input_generation"] = context["input_generation"]
	if context["identity"] != identity or context["transport"] != transport or checkpoint.get("accepted_sequence") != 21 or checkpoint.get("processed_sequence") != 21 or checkpoint.get("issued_sequence") != 21 or checkpoint.get("pending_count") != 0: return false
	for key in identity:
		if checkpoint.get(key) != identity[key]: return false
	_probe_expected_close = {"identity":identity.duplicate(true), "transport":transport.duplicate(true)}
	return true

func _on_server_disconnected() -> void:
	if not _probe_expected_close.is_empty() and _peer != null and _actor_scene_api != null and not _fatal_shutdown:
		var identity: Dictionary = _probe_expected_close["identity"]
		var transport: Dictionary = _probe_expected_close["transport"]
		if _peer.get_instance_id() == transport["peer_instance_id"] and _actor_scene_api.get_instance_id() == transport["api_instance_id"] and _welcome.get("server_epoch") == identity["server_epoch"] and _welcome.get("player_profile_id") == identity["player_profile_id"] and _welcome.get("player_instance_id") == identity["player_instance_id"]:
			_probe_expected_close.clear() # Consume once; later callbacks use original failure.
			probe_expected_disconnect_seen = true
			_actor_client_connection_lost = true
			_close_actor_input_pending()
			probe_startup_events.append({"event":"expected_local_transport_close", "usec":Time.get_ticks_usec()})
			return
	super._on_server_disconnected()
