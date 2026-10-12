extends "res://scripts/actor/actor_terrain_network_main.gd"
## Observe real Owner6. A marker only triggers close of an authenticated stream;
## it never supplies hello, welcome, actor input, inventory input or ACK.
const ProbeLedger = preload("res://scripts/harvest/tree_ledger012.gd")
const PROBE_TRIGGER_FIELDS := ["nonce", "phase", "peer_id", "world_id", "server_epoch", "player_profile_id", "player_instance_id", "input_generation", "tree_id", "completion_id"]
signal probe_failure_seen(code: String)

# Same reviewed 30-second startup timeout and first-valid-snapshot restoration
# as inventory_enet_observer012. No replacement handshake or snapshot.
var probe_startup_events: Array = []
var _probe_welcome_seen := false
var _probe_startup_packet: ENetPacketPeer
var _probe_startup_deadline_usec: int = 0
var _probe_expected_close: Dictionary = {}
var probe_expected_disconnect_seen := false
var probe_expected_disconnect_usec: int = 0
var probe_disconnect_callback_count: int = 0

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
	if _probe_startup_deadline_usec <= 0:
		return
	probe_startup_events.append({"event":"restore_timeout", "reason":reason, "usec":Time.get_ticks_usec()})
	if _probe_startup_packet != null and _probe_startup_packet.get_state() == ENetPacketPeer.STATE_CONNECTED:
		_probe_startup_packet.set_timeout(32, 5000, 30000)
	_probe_startup_packet = null
	_probe_startup_deadline_usec = 0

func _after_client_snapshot(incoming: Dictionary) -> void:
	super._after_client_snapshot(incoming)
	if not _closing and not _fatal_shutdown and _actor_client_state != null and _actor_client_state.ready:
		if _probe_startup_deadline_usec > 0:
			probe_startup_events.append({"event":"first_valid_snapshot", "usec":Time.get_ticks_usec()})
		_finish_probe_startup_timeout("snapshot")

func _process(delta: float) -> void:
	if _probe_startup_deadline_usec > 0 and Time.get_ticks_usec() >= _probe_startup_deadline_usec:
		_finish_probe_startup_timeout("deadline")
	if not _probe_welcome_seen and not _welcome.is_empty():
		_probe_welcome_seen = true
		probe_startup_events.append({"event":"welcome_observed", "usec":Time.get_ticks_usec()})
	super._process(delta)

static func probe_nonce_valid(value: String) -> bool:
	if value.length() != 32:
		return false
	for index in range(value.length()):
		if value.substr(index, 1) not in "0123456789abcdef":
			return false
	return true

func arm_tree_expected_close(expected: Dictionary, trigger: Dictionary, nonce: String, mode: String) -> bool:
	if not _probe_expected_close.is_empty() or probe_expected_disconnect_seen or probe_disconnect_callback_count != 0 or _closing or _fatal_shutdown:
		return false
	var current: Dictionary = _client_actor_input_context()
	if not current.get("ok", false) or current != expected or not probe_nonce_valid(nonce):
		return false
	if _actor_client_sent_count != 1 or not _actor_client_sent_intent or _actor_input_binding != current:
		return false
	if mode not in ["baseline", "detached_disconnect"]:
		return false
	if trigger.size() != PROBE_TRIGGER_FIELDS.size():
		return false
	for key in PROBE_TRIGGER_FIELDS:
		if not trigger.has(key):
			return false
	for key in ["peer_id", "input_generation"]:
		var number: Variant = trigger[key]
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or float(number) != floor(float(number)):
			return false
	var expected_phase: String = "published" if mode == "baseline" else "detached"
	if trigger.get("nonce") != nonce or trigger.get("phase") != expected_phase:
		return false
	for key in ["world_id", "server_epoch", "player_profile_id", "player_instance_id", "peer_id"]:
		if trigger.get(key) != current["identity"].get(key):
			return false
	if trigger.get("peer_id") != current["transport"]["peer_id"] or trigger.get("input_generation") != current["input_generation"]:
		return false
	if not SandboxServerAuthority._valid_id(trigger.get("tree_id"), "entity_tree_"):
		return false
	if trigger.get("completion_id") != ProbeLedger.completion_identity(trigger["tree_id"]):
		return false
	# Own original context authenticates the binding; the marker selects only the
	# technical fault point. No marker field is written into the original stream.
	_probe_expected_close = {"context":current.duplicate(true), "trigger":trigger.duplicate(true)}
	return true

func _expected_tree_close_matches() -> bool:
	if _probe_expected_close.is_empty() or probe_expected_disconnect_seen or _closing or _fatal_shutdown or _actor_client_connection_lost:
		return false
	if _peer == null or _actor_scene_api == null or not _owns_scoped_multiplayer():
		return false
	var context: Dictionary = _probe_expected_close["context"]
	var identity: Dictionary = context["identity"]
	var transport: Dictionary = context["transport"]
	if _peer.get_instance_id() != transport["peer_instance_id"] or _actor_scene_api.get_instance_id() != transport["api_instance_id"] or _actor_input_binding != context:
		return false
	if _peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED or _actor_client_sent_count != 1:
		return false
	for key in ["server_epoch", "player_profile_id", "player_instance_id"]:
		if _welcome.get(key) != identity[key]:
			return false
	if _actor_client_state == null or not _actor_client_state.ready or _actor_input_pending == null or not _actor_input_pending.ready:
		return false
	var checkpoint: Dictionary = _actor_client_state.input_checkpoint(identity["player_profile_id"], identity["peer_id"])
	for key in identity:
		if checkpoint.get(key) != identity[key]:
			return false
	return checkpoint.get("input_generation") == context["input_generation"] and _actor_input_pending.cursor().get("input_generation") == context["input_generation"]

func _on_server_disconnected() -> void:
	probe_disconnect_callback_count += 1
	if probe_disconnect_callback_count == 1 and _expected_tree_close_matches():
		_probe_expected_close.clear() # Consume once; duplicates take original failure.
		probe_expected_disconnect_seen = true
		probe_expected_disconnect_usec = Time.get_ticks_usec()
		_actor_client_connection_lost = true
		_close_actor_input_pending()
		probe_startup_events.append({"event":"expected_local_transport_close", "usec":probe_expected_disconnect_usec})
		return
	super._on_server_disconnected()

func _fail(code: String, message: String) -> void:
	probe_failure_seen.emit(code)
	super._fail(code, message) # Preserve original fatal state, cleanup and exit1.

# Diagnostic observation only: same original accept path and return value.
var probe_snapshot_count: int = 0
var probe_snapshot_observations: Array = []
func _client_accept_snapshot(incoming: Dictionary) -> bool:
	probe_snapshot_count += 1
	var started: int = Time.get_ticks_usec()
	var row: Dictionary = {"event":"snapshot_enter", "count":probe_snapshot_count, "usec":started, "has_terrain":incoming.has("terrain_public"), "has_reference":incoming.has("terrain_reference"), "keys":incoming.keys()}
	if probe_snapshot_observations.size()<64:
		probe_snapshot_observations.append(row)
		print("TREE_ENET_CLIENT_TRACE ",JSON.stringify(row,"",true,true))
	var accepted: bool = super._client_accept_snapshot(incoming)
	row={"event":"snapshot_return","count":probe_snapshot_count,"usec":Time.get_ticks_usec(),"elapsed_usec":Time.get_ticks_usec()-started,"accepted":accepted,"fatal":_fatal_shutdown}
	if probe_snapshot_observations.size()<64:
		probe_snapshot_observations.append(row)
		print("TREE_ENET_CLIENT_TRACE ",JSON.stringify(row,"",true,true))
	return accepted
