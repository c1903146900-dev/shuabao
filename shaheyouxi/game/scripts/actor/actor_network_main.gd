extends "res://scripts/world_session/world_network_main.gd"
## 011 lifecycle, validated client consumption and bounded local intent sending.
## Snapshot admission cursor only; no action receipt, prediction or actor HUD.
## Inherited world rendering remains the read-only technical overview, not actor GUI.
const ActorInputs = preload("res://scripts/actor/actor_inputs.gd")
const ActorMotion = preload("res://scripts/actor/actor_motion.gd")
const ActorSpace = preload("res://scripts/actor/actor_space.gd")
const ActorSession = preload("res://scripts/actor/actor_session_state.gd")
const ActorController = preload("res://scripts/actor/actor_session_controller.gd")
const ActorClientState = preload("res://scripts/actor/actor_client_state.gd")
const ActorInputPending = preload("res://scripts/actor/actor_input_pending.gd")
# Wire-only cursor shape change; persistent schema3/exact save remain unchanged.
const ACTOR_CONTRACT := "sandbox011-actor-lifecycle-v2"
# Combined authority/world/actor contract, distinct from the 010 owner schema2.
# Matches the real exact SaveStore path in ActorSessionStateTest.
const ACTOR_SAVE_SCHEMA := 3
const ACTOR_SAVE_MAXIMUM_BYTES := 4194304
const ACTOR_SNAPSHOT_INTERVAL := 0.1 # Existing technical report cadence, not gameplay time.
var _actor_inputs: RefCounted
var _actor_session: RefCounted
var _actor_model: RefCounted
var _actor_space: RefCounted
var _actor_controller: RefCounted
var _actor_client_state: RefCounted
var _actor_input_pending: RefCounted
var _actor_input_binding: Dictionary = {}
var _actor_client_sent_intent: bool = false
var _actor_client_sent_count: int = 0
var _actor_client_connection_lost: bool = false
var _physics_runtime_ready: bool = false
var _last_actor_physics_frame: int = -1
var _actor_physics_steps: int = 0
var _actor_step_failure: Dictionary = {}
var _actor_snapshot_elapsed: float = 0.0
var _actor_scene_api: SceneMultiplayer
var _actor_scene_tree: WeakRef
var _actor_scene_root: NodePath

func _make_actor_client_state() -> RefCounted:
	return ActorClientState.new()

func _actor_wire_contract() -> String:
	return ACTOR_CONTRACT

func _prepare_session() -> bool:
	if _mode not in ["server", "host", "client"] or (_mode != "client" and _save_directory.is_empty()):
		_fail("ACTOR_SAVE_REQUIRED", "011服务端必须使用独立持久目录")
		return false
	_actor_inputs = ActorInputs.new()
	if not _actor_inputs.load_file():
		_fail("ACTOR_INPUT_INVALID", _actor_inputs.last_error)
		return false
	var documents: Array = []
	for path in ["generation_settings.json", "prefab_settings.json", "actor_world_bundle011.json"]:
		var document: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + path))
		if not document is Dictionary:
			_fail("WORLD_INPUT_INVALID", path)
			return false
		documents.append(document)
	_world = WorldComponent.new(documents[0], documents[1], documents[2], "011")
	if not _world.ready:
		_fail("WORLD_INPUT_INVALID", _world.last_error)
		return false
	_actor_session = ActorSession.new(_world, _actor_inputs.document())
	if not _actor_session.ready:
		_fail("ACTOR_SESSION_INPUT_INVALID", _actor_session.last_error)
		return false
	if _mode == "client":
		_actor_client_state = _make_actor_client_state()
		_actor_input_pending = ActorInputPending.new()
		var configured: Dictionary = _actor_client_state.configure(_world, _actor_inputs, _settings)
		if not configured.get("ok", false):
			_fail(str(configured.get("code", "ACTOR_CLIENT_CONFIGURATION_INVALID")), "人物只读客户端配置无效")
			return false
	if not _prepare_scoped_multiplayer():
		return false
	_world_view = WorldView.new()
	_world_view.name = "TechnicalWorld"
	add_child(_world_view)
	return true

func _prepare_scoped_multiplayer() -> bool:
	if not is_inside_tree() or _actor_scene_api != null:
		_fail("ACTOR_MULTIPLAYER_SCOPE_INVALID", "人物会话必须在独立场景分支中初始化一次")
		return false
	var tree := get_tree()
	var branch := get_path()
	var fallback: MultiplayerAPI = tree.get_multiplayer()
	# An empty path changes the default API. A root-window path shadows all scenes.
	# Reject an existing exact/ancestor mapping before set_multiplayer can replace it
	# or raise the engine's custom-ancestor error. Never modify another session's API.
	if branch.is_empty() or not branch.is_absolute() or branch == tree.root.get_path() or tree.get_multiplayer(branch) != fallback:
		_fail("ACTOR_MULTIPLAYER_SCOPE_CONFLICT", "人物场景分支已有独立联机服务，不能覆盖")
		return false
	# Also reject aliasing the default SceneMultiplayer as a custom ancestor.
	if fallback is SceneMultiplayer and fallback.root_path != tree.root.get_path():
		_fail("ACTOR_MULTIPLAYER_SCOPE_CONFLICT", "默认联机服务已被绑定到其他场景分支")
		return false
	var scene_api := SceneMultiplayer.new()
	scene_api.root_path = branch
	# This protocol is a server-authoritative star: clients never address peers.
	# Set before attaching ENet, on this owner only, including same-tree test owners.
	scene_api.server_relay = false
	_actor_scene_api = scene_api
	_actor_scene_tree = weakref(tree)
	_actor_scene_root = branch
	tree.set_multiplayer(scene_api, branch)
	if not _owns_scoped_multiplayer():
		_fail("ACTOR_MULTIPLAYER_SCOPE_BIND_FAILED", "人物独立联机服务绑定失败")
		return false
	return true

func _owns_scoped_multiplayer() -> bool:
	if _actor_scene_api == null or _actor_scene_tree == null or _actor_scene_root.is_empty():
		return false
	var tree := _actor_scene_tree.get_ref() as SceneTree
	return tree != null and _actor_scene_api.root_path == _actor_scene_root and tree.get_multiplayer(_actor_scene_root) == _actor_scene_api

func _release_scoped_multiplayer() -> void:
	if _actor_scene_api == null:
		return
	# Clear owner references once; the queued callable retains only the API, immutable
	# path and a weak tree reference, so it remains valid if this Node is freed first.
	var release := _scoped_multiplayer_release_task(_actor_scene_tree, _actor_scene_root, _actor_scene_api)
	_actor_scene_api = null
	_actor_scene_tree = null
	_actor_scene_root = NodePath()
	release.call_deferred()

static func _scoped_multiplayer_release_task(tree_ref: WeakRef, branch: NodePath, owned_api: SceneMultiplayer) -> Callable:
	# Static lambda has no owner/self capture. Never mutate SceneTree's custom map
	# synchronously from an ENet/SceneMultiplayer poll callback or _exit_tree.
	return func() -> void:
		var tree: SceneTree = tree_ref.get_ref() as SceneTree if tree_ref != null else null
		if tree == null or branch.is_empty() or not branch.is_absolute():
			return
		# The path may have been replaced while removal was queued. An identity AND
		# root-path check prevents removing a replacement or an inherited/default API.
		if owned_api.root_path != branch or tree.get_multiplayer(branch) != owned_api:
			return
		tree.set_multiplayer(null, branch)

func _exit_tree() -> void:
	# Unexpected scene removal/auto_free must release owned resources too. It never
	# performs a final save; normal shutdown already saves before _cleanup_runtime.
	_closing = true
	if _peer != null:
		_peer.close()
	if _save_store != null:
		_save_store.close()
	_cleanup_runtime()

func _make_save_store() -> SandboxSaveStore:
	return SandboxSaveStore.new(_save_directory, int(_save_settings["automatic_backup_count"]), int(_save_settings["manual_slot_count"]), _catalogue.source_sha256, int(_settings["network_protocol_version"]), _actor_session.validate_combined_state, ACTOR_SAVE_SCHEMA, ACTOR_SAVE_MAXIMUM_BYTES, true)

func _create_new_world() -> bool:
	if not super._create_new_world():
		return false
	_actor_model = ActorMotion.new(_authority.world_id, _actor_inputs.document(), _authority.world_seconds)
	if not _actor_model.ready:
		_fail("ACTOR_MODEL_INITIALIZATION_FAILED", _actor_model.last_error)
		return false
	return true

func _restore_authority_state(state: Dictionary) -> Dictionary:
	# No component is applied before the complete combined contract succeeds.
	var checked: Dictionary = _actor_session.validate_combined_state(state)
	if not checked.get("ok", false):
		return checked
	var restored: Dictionary = _world.restore(state["world_component"], state["world_id"])
	if not restored.get("ok", false):
		return restored
	_actor_model = ActorMotion.new(state["world_id"], _actor_inputs.document(), float(state["world_seconds"]))
	if not _actor_model.ready:
		return {"ok": false, "code": "ACTOR_MODEL_RESTORE_NOT_READY", "recoverable_corruption": false}
	restored = _actor_model.restore_persistent_state(state["actor_component"])
	if not restored.get("ok", false):
		return restored
	# Both restored services remain inactive. Native registration is only by join_peer.
	return _authority.restore_persistent_state(ActorSession.authority_state(state))

func _make_actor_space() -> RefCounted:
	return ActorSpace.new()

func _prepare_runtime_before_listen() -> bool:
	if _closing or _fatal_shutdown or _bootstrap_cancel_requested():
		return false
	if _actor_model == null or not _actor_model.ready or _actor_space != null:
		_fail("ACTOR_RUNTIME_INPUT_INVALID", "人物运行时未正确创建或已重复准备")
		return false
	_actor_space = _make_actor_space()
	if not _actor_space.configure(_world, _actor_inputs):
		_fail("ACTOR_NATIVE_PREPARE_FAILED", _actor_space.last_error)
		return false
	# Existing native suites wait two physics frames after materializing static RIDs.
	# The inherited bootstrap path continues handling cancellation/watchdog meanwhile.
	for frame in range(2):
		await get_tree().physics_frame
		if _closing or _fatal_shutdown or _bootstrap_cancel_requested():
			return false
	for layer_space in _actor_space._spaces.values():
		if PhysicsServer2D.space_get_direct_state(layer_space["rid"]) == null:
			_fail("ACTOR_NATIVE_SPACE_NOT_READY", "物理查询空间尚不可用，未监听或保存")
			return false
	_actor_controller = ActorController.new(_authority, _world, _actor_model, _actor_space, _actor_inputs)
	if not _actor_controller.ready:
		_fail("ACTOR_CONTROLLER_PREPARE_FAILED", _actor_controller.fatal_error)
		return false
	_physics_runtime_ready = true
	return true

func _join_authority_peer(peer_id: int, request: Dictionary, local_host: bool = false) -> Dictionary:
	if _closing or _fatal_shutdown or _bootstrap_cancel_requested():
		return {"ok": false, "code": "ACTOR_SESSION_STOPPING"}
	if not _physics_runtime_ready or _actor_controller == null or not _actor_controller.ready:
		_fail("ACTOR_CONTROLLER_NOT_READY", "人物加入发生于运行时准备完成之前")
		return {"ok": false, "code": "ACTOR_CONTROLLER_NOT_READY", "fatal": true}
	var joined: Dictionary = _actor_controller.join_peer(peer_id, request, local_host)
	if joined.get("fatal", false):
		_fail(str(joined.get("code", "ACTOR_JOIN_FAILED")), "人物加入提交失败，已停止且不会保存或广播")
	return joined

func _disconnect_authority_peer(peer_id: int) -> bool:
	if _fatal_shutdown or _closing:
		return false
	if _actor_controller == null or not _actor_controller.ready:
		_fail("ACTOR_CONTROLLER_NOT_READY", "人物断开时运行时不可用")
		return false
	var removed: Dictionary = _actor_controller.disconnect_peer(peer_id)
	if not removed.get("ok", false):
		_fail(str(removed.get("code", "ACTOR_DISCONNECT_FAILED")), "人物断开失败，已停止且不会保存或广播")
		return false
	return true

func _advance_authority(_delta: float) -> bool:
	# The inherited render/report loop must never advance either gameplay clock.
	if _fatal_shutdown or _closing:
		return false
	if not _physics_runtime_ready or _actor_controller == null or not _actor_controller.ready:
		_fail("ACTOR_CONTROLLER_NOT_READY", "人物运行时已停止")
		return false
	return true

func _physics_process(delta: float) -> void:
	if _mode not in ["server", "host"] or not _startup_ready or _closing or _fatal_shutdown or _bootstrap_cancel_requested():
		return
	if not _physics_runtime_ready or _actor_controller == null or not _actor_controller.ready:
		_fail("ACTOR_CONTROLLER_NOT_READY", "人物物理步缺少已就绪的服务器运行时")
		return
	var frame := Engine.get_physics_frames()
	if frame <= _last_actor_physics_frame:
		return
	_last_actor_physics_frame = frame
	var stepped: Dictionary = _actor_controller.step(delta)
	if not stepped.get("ok", false):
		_actor_step_failure = stepped.get("diagnostic", {}).duplicate(true)
		_actor_step_failure["physics_frame"] = frame
		_fail(str(stepped.get("code", "ACTOR_PHYSICS_STEP_FAILED")), "人物物理步失败，已停止且不会保存或广播")
		return
	if not stepped.get("paused", false):
		_actor_physics_steps += 1
		_actor_snapshot_elapsed += delta
		if _actor_snapshot_elapsed >= ACTOR_SNAPSHOT_INTERVAL:
			_actor_snapshot_elapsed = 0.0
			_broadcast_snapshot()

func _persistent_state_for_save(advance_auto: bool) -> Dictionary:
	if _fatal_shutdown:
		return {}
	if not _physics_runtime_ready or _actor_controller == null or not _actor_controller.ready:
		_fail("ACTOR_CONTROLLER_NOT_SAVE_READY", "人物运行时不可保存")
		return {}
	var combined: Dictionary = _actor_controller.combined_save_state(advance_auto)
	if not combined.get("ok", false):
		_fail(str(combined.get("code", "ACTOR_COMBINED_SAVE_INVALID")), "人物组合保存校验失败，未写入存档")
		return {}
	return combined["state"]

func _public_snapshot() -> Dictionary:
	if _fatal_shutdown or _actor_controller == null or not _actor_controller.ready:
		return {}
	return _actor_controller.public_snapshot()

func _broadcast_snapshot() -> void:
	if _closing or _fatal_shutdown or not _startup_ready or _bootstrap_cancel_requested() or _actor_controller == null or not _actor_controller.ready:
		return
	if _peer == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var authenticated: Array = _authority.active_peer_ids()
	var transport_ids: PackedInt32Array = multiplayer.get_peers()
	var states: Dictionary = {}
	for peer_id in authenticated:
		if not peer_id is int or peer_id <= 1 or not transport_ids.has(peer_id):
			continue
		var packet_peer: ENetPacketPeer = _peer.get_peer(peer_id)
		if packet_peer == null:
			continue
		var state: int = packet_peer.get_state()
		# get_state is safe after disconnect; get_channels needs an active native
		# peer. No await/poll/callback separates this test and the subsequent sends.
		states[peer_id] = {"state": state, "channels": packet_peer.get_channels() if state == ENetPacketPeer.STATE_CONNECTED else 0}
	var snapshot: Dictionary = _broadcast_snapshot_base()
	for peer_id in _select_snapshot_targets(authenticated, transport_ids, states):
		var queue_context: Dictionary = _snapshot_queue_context(peer_id)
		var packet: Dictionary = _wire_snapshot_for_peer(peer_id, snapshot)
		if not packet.is_empty():
			var queued: int = rpc_id(peer_id, "state_snapshot", packet)
			if queued == OK:
				_snapshot_send_succeeded(peer_id, packet, queue_context)

func _broadcast_snapshot_base() -> Dictionary:
	return _public_snapshot()

func _wire_snapshot_for_peer(_peer_id: int, snapshot: Dictionary) -> Dictionary:
	return snapshot

func _snapshot_queue_context(_peer_id: int) -> Dictionary:
	return {}

func _snapshot_send_succeeded(_peer_id: int, _packet: Dictionary, _context: Dictionary) -> void:
	pass

static func _select_snapshot_targets(authenticated: Array, transport_ids: PackedInt32Array, states: Dictionary) -> Array:
	# Inputs come only from this server's authority and transport, never an RPC.
	var targets: Array = []
	for peer_id in authenticated:
		if not peer_id is int or peer_id <= 1 or targets.has(peer_id) or not transport_ids.has(peer_id):
			continue
		var entry: Variant = states.get(peer_id)
		if not entry is Dictionary or not entry.get("state") is int or entry["state"] != ENetPacketPeer.STATE_CONNECTED or not entry.get("channels") is int or entry["channels"] <= 0:
			continue
		targets.append(peer_id)
	return targets

@rpc("any_peer", "call_remote", "reliable")
func actor_input(request: Variant) -> void:
	if _mode not in ["server", "host"] or _peer == null or not _owns_scoped_multiplayer() or not multiplayer.is_server():
		return
	# Capture the actual sender synchronously. Local/direct calls return0 and can
	# never use the authenticated local host identity1 through this RPC surface.
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1:
		return
	_admit_actor_input(sender, request)

func _admit_actor_input(peer_id: int, request: Variant) -> Dictionary:
	# Server-only composition seam. The RPC wrapper supplies the transport sender;
	# local host supplies constant1. No payload field can select a player or actor.
	if _mode not in ["server", "host"] or _authority == null:
		return {"ok": false, "code": "ACTOR_SERVER_REQUIRED"}
	if _closing or _fatal_shutdown or not _startup_ready or _bootstrap_cancel_requested():
		return {"ok": false, "code": "ACTOR_SESSION_STOPPING"}
	if peer_id < 1 or (peer_id == 1 and _mode != "host"):
		return {"ok": false, "code": "ACTOR_PEER_NOT_JOINED"}
	if _pending_disconnects.has(peer_id):
		return {"ok": false, "code": "ACTOR_PEER_DISCONNECTING"}
	if not _physics_runtime_ready or _actor_controller == null or not _actor_controller.ready:
		_fail("ACTOR_CONTROLLER_NOT_READY", "人物输入发生于权威运行时未就绪时")
		return {"ok": false, "code": "ACTOR_CONTROLLER_NOT_READY", "fatal": true}
	var result: Dictionary = _actor_controller.accept_peer_input(peer_id, request)
	if result.get("fatal", false):
		_fail(str(result.get("code", "ACTOR_INPUT_FAILED")), "人物输入权威绑定失败，已停止且不会保存或广播")
	# Preserve admission vs action outcome, including consumed failed dodge edges
	# and duplicate requests. A successful admission is not an action-success ack.
	return result

func submit_local_actor_input(request: Variant) -> Dictionary:
	# This method is deliberately not RPC. Dedicated server/client cannot become
	# host by passing a peer ID or a trusted flag; local identity is always1.
	if _mode != "host":
		return {"ok": false, "code": "ACTOR_LOCAL_HOST_REQUIRED"}
	return _admit_actor_input(1, request)

func submit_client_actor_intent(move: Variant, aim: Variant, action: Variant = "none", phase: Variant = "none") -> Dictionary:
	# Non-RPC local producer. Identity, sequence and generation are never caller data.
	var context: Dictionary = _client_actor_input_context()
	if not context.get("ok", false):
		_close_actor_input_pending()
		return context
	var synchronized: Dictionary = _prepare_client_actor_pending(context)
	if not synchronized.get("ok", false):
		return synchronized
	var pending: RefCounted = _actor_input_pending
	var issued: Dictionary = pending.issue(move, aim, action, phase)
	if not issued.get("ok", false):
		if not pending.ready:
			_close_actor_input_pending()
		return issued
	# A detached send candidate is usable only on the very same owner connection
	# and input stream. Do not queue it for a later connection or replay on failure.
	var current: Dictionary = _client_actor_input_context()
	if not current.get("ok", false) or current != context or _actor_input_pending != pending or not pending.ready or pending.cursor().get("input_generation") != issued["input_generation"] or context["input_generation"] != issued["input_generation"]:
		_close_actor_input_pending()
		return {"ok":false, "code":"ACTOR_CLIENT_INPUT_CONTEXT_CHANGED"}
	var send_error: int = _send_client_actor_input(issued["request"])
	if send_error != OK:
		_close_actor_input_pending()
		_fail("ACTOR_CLIENT_INPUT_SEND_FAILED", "人物意图发送失败，已关闭本次输入流且不会自动重发")
		return {"ok":false, "code":"ACTOR_CLIENT_INPUT_SEND_FAILED", "send_error":send_error}
	_actor_client_sent_intent = true
	_actor_client_sent_count += 1
	# Local send success is provisional; it is neither server acceptance nor action
	# success. Snapshot cursors retire obsolete intents without simulation claims.
	return {"ok":true, "sequence":issued["request"]["sequence"], "input_generation":issued["input_generation"], "provisional":true}

func _actor_client_transport_state() -> Dictionary:
	# Read-only transport seam. Tests can observe a fake connection without opening
	# sockets; production verifies the scoped ENet instance and actual server peer1.
	if _peer == null or not _owns_scoped_multiplayer() or multiplayer.multiplayer_peer != _peer or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or multiplayer.is_server():
		return {"ok":false, "code":"ACTOR_CLIENT_TRANSPORT_UNAVAILABLE"}
	var peer_id: int = multiplayer.get_unique_id()
	if peer_id <= 1 or not multiplayer.get_peers().has(1):
		return {"ok":false, "code":"ACTOR_CLIENT_TRANSPORT_UNAVAILABLE"}
	var server_peer: ENetPacketPeer = _peer.get_peer(1)
	if server_peer == null or server_peer.get_state() != ENetPacketPeer.STATE_CONNECTED or server_peer.get_channels() <= 0:
		return {"ok":false, "code":"ACTOR_CLIENT_TRANSPORT_UNAVAILABLE"}
	return {"ok":true, "peer_id":peer_id, "server_peer_id":1, "peer_instance_id":_peer.get_instance_id(), "api_instance_id":_actor_scene_api.get_instance_id()}

func _send_client_actor_input(request: Dictionary) -> int:
	# Node.rpc_id returns Error; the Callable.rpc_id convenience method returns void.
	return rpc_id(1, &"actor_input", request)

func _client_actor_input_context() -> Dictionary:
	if _mode != "client" or _authority != null:
		return {"ok":false, "code":"ACTOR_CLIENT_REQUIRED"}
	if not _startup_ready or _closing or _fatal_shutdown or _bootstrap_cancel_requested() or _actor_client_connection_lost:
		return {"ok":false, "code":"ACTOR_CLIENT_INPUT_STOPPING"}
	if not _owns_scoped_multiplayer():
		return {"ok":false, "code":"ACTOR_CLIENT_TRANSPORT_UNAVAILABLE"}
	var transport: Dictionary = _actor_client_transport_state()
	if not transport.get("ok", false):
		return transport
	for key in ["peer_id", "server_peer_id", "peer_instance_id", "api_instance_id"]:
		if typeof(transport.get(key)) != TYPE_INT or transport[key] == 0:
			return {"ok":false, "code":"ACTOR_CLIENT_TRANSPORT_UNAVAILABLE"}
	# ObjectIDs are nonzero uint64 handles represented as signed Variant ints;
	# RefCounted IDs may be negative. Only ENet network peer IDs are positive.
	if transport["peer_id"] <= 1 or transport["peer_id"] > 2147483647 or transport["server_peer_id"] != 1 or transport["api_instance_id"] != _actor_scene_api.get_instance_id():
		return {"ok":false, "code":"ACTOR_CLIENT_TRANSPORT_UNAVAILABLE"}
	if _actor_client_state == null or not _actor_client_state.ready or _actor_input_pending == null:
		return {"ok":false, "code":"ACTOR_CLIENT_INPUT_NOT_READY"}
	for item in [["player_profile_id", "player_"], ["player_instance_id", "entity_player_"], ["server_epoch", "session_"]]:
		if not _welcome.get(item[0]) is String or not SandboxServerAuthority._valid_id(_welcome[item[0]], item[1]):
			return {"ok":false, "code":"ACTOR_CLIENT_INPUT_IDENTITY_INVALID"}
	# The small checkpoint comes only from the already-validated cache. No full
	# world/model copy, client-selected actor ID or client-selected epoch is used.
	var checkpoint: Dictionary = _actor_client_state.input_checkpoint(_welcome["player_profile_id"], transport["peer_id"])
	if checkpoint.is_empty():
		return {"ok":false, "code":"INPUT_BINDING_UNAVAILABLE"}
	for key in ["player_profile_id", "player_instance_id", "server_epoch"]:
		if checkpoint.get(key) != _welcome[key]:
			return {"ok":false, "code":"ACTOR_CLIENT_INPUT_IDENTITY_INVALID"}
	var identity: Dictionary = {}
	for key in ActorInputPending.IDENTITY_FIELDS:
		identity[key] = checkpoint[key]
	return {"ok":true, "identity":identity, "transport":transport.duplicate(true), "input_generation":checkpoint["input_generation"]}

func _prepare_client_actor_pending(context: Dictionary) -> Dictionary:
	var result: Dictionary
	if not _actor_input_pending.ready and not _actor_input_binding.is_empty():
		_close_actor_input_pending()
		return {"ok":false, "code":"ACTOR_CLIENT_INPUT_CONTEXT_CHANGED"}
	if _actor_input_pending.ready:
		if _actor_input_binding.get("identity") != context["identity"] or _actor_input_binding.get("transport") != context["transport"]:
			_close_actor_input_pending()
			return {"ok":false, "code":"ACTOR_CLIENT_INPUT_CONTEXT_CHANGED"}
		result = _actor_input_pending.synchronize()
	else:
		result = _actor_input_pending.configure(_actor_client_state, context["identity"])
		if result.get("ok", false):
			_actor_input_binding = context.duplicate(true)
	if not result.get("ok", false):
		_close_actor_input_pending()
	return result

func _synchronize_client_actor_pending() -> Dictionary:
	var context: Dictionary = _client_actor_input_context()
	if not context.get("ok", false):
		_close_actor_input_pending()
		return context
	return _prepare_client_actor_pending(context)

func _close_actor_input_pending() -> void:
	# This owner supports one authenticated input connection. Once it was bound,
	# losing identity, transport or generation cannot reconfigure from a stale
	# welcome/cache on a later submit. A new owner must establish a new connection.
	# A never-bound read-only/no-socket cache does not set this permanent gate.
	if not _actor_input_binding.is_empty():
		_actor_client_connection_lost = true
	if _actor_input_pending != null:
		_actor_input_pending.close()
	_actor_input_binding.clear()

func _fail(code: String, message: String) -> void:
	_close_actor_input_pending()
	super._fail(code, message)

func _on_server_disconnected() -> void:
	# Close even when inherited early-return branches see closing or a stop file.
	_actor_client_connection_lost = true
	_close_actor_input_pending()
	super._on_server_disconnected()

@rpc("any_peer", "call_remote", "reliable")
func command(request: Dictionary) -> void:
	# Guard the inherited identity/read-only command; this adds no actor input RPC.
	if _closing or _fatal_shutdown or not _startup_ready or _bootstrap_cancel_requested() or _actor_controller == null or not _actor_controller.ready:
		return
	super.command(request)

func _base_hello(display_name: String) -> Dictionary:
	var request: Dictionary = super._base_hello(display_name)
	request["actor_contract"] = _actor_wire_contract()
	request["actor_projection_sha256"] = _actor_inputs.source_identity()["projection_sha256"]
	return request

func _validate_remote_hello(request: Dictionary) -> Dictionary:
	if _actor_inputs == null or not _actor_inputs.ready or request.get("actor_contract") != _actor_wire_contract() or request.get("actor_projection_sha256") != _actor_inputs.source_identity()["projection_sha256"]:
		return {"ok": false, "code": "ACTOR_CONTRACT_MISMATCH", "message": "人物生命周期契约或正式参数来源不兼容"}
	var filtered: Dictionary = request.duplicate(true)
	filtered.erase("actor_contract")
	filtered.erase("actor_projection_sha256")
	# World handshake fields are filtered by the inherited world contract. Any other
	# unknown field, including trusted flags/results, remains for original join to reject.
	return super._validate_remote_hello(filtered)

func _client_accept_snapshot(incoming: Dictionary) -> bool:
	if _closing or _fatal_shutdown or _bootstrap_cancel_requested():
		return false
	if _mode != "client" or _actor_client_state == null or not _actor_client_state.ready:
		_fail("ACTOR_CLIENT_NOT_READY", "人物客户端公开状态缓存未就绪")
		return false
	var expected_epoch: Variant = _welcome.get("server_epoch")
	if not expected_epoch is String or not SandboxServerAuthority._valid_id(expected_epoch, "session_"):
		_fail("ACTOR_CLIENT_IDENTITY_NOT_READY", "先取得有效服务器会话身份，才能消费人物快照")
		return false
	var consumed: Dictionary = _actor_client_state.consume(incoming, expected_epoch)
	if not consumed.get("ok", false):
		_fail(str(consumed.get("code", "ACTOR_CLIENT_SNAPSHOT_INVALID")), "人物公开快照校验失败")
		return false
	# A source-only callback test may have no transport. Its validated read-only
	# cache remains usable, but it never becomes a connected input producer.
	_synchronize_client_actor_pending()
	_received_component = _client_world_component()
	_received_hash = JSON.stringify(_received_component, "", true, true).sha256_text()
	return true

func _client_world_component() -> Dictionary:
	return _actor_client_state.snapshot()["world_component"].duplicate(true)

func _cleanup_runtime() -> void:
	_closing = true
	_close_actor_input_pending()
	_physics_runtime_ready = false
	_last_actor_physics_frame = -1
	_actor_snapshot_elapsed = 0.0
	if _actor_controller != null:
		_actor_controller.shutdown_runtime()
	# Constructor failure may precede the controller taking ownership of these.
	# Both cleanup methods are idempotent, including at exhausted generation/revision.
	if _actor_model != null:
		_actor_model.release_runtime_sessions()
	if _actor_space != null:
		_actor_space.dispose()
	if _peer != null:
		_peer.close()
	_release_scoped_multiplayer()
	super._cleanup_runtime()

func _actor_presentation() -> String:
	return "inherited_readonly_world_overview"

func _actor_save_schema_for_report() -> int:
	return ACTOR_SAVE_SCHEMA

func _client_snapshot_matches_report(client_snapshot: Dictionary, reported_snapshot: Variant) -> bool:
	return not client_snapshot.is_empty() and client_snapshot == reported_snapshot

func _write_report(data: Dictionary) -> void:
	var report: Dictionary = data.duplicate(true)
	if not _actor_step_failure.is_empty():
		report["actor_step_failure"] = _actor_step_failure.duplicate(true)
	var scene_api: SceneMultiplayer = multiplayer as SceneMultiplayer if is_inside_tree() else null
	report["actor_transport"] = {"server_relay": scene_api.server_relay if scene_api != null else null, "scoped_api_owned": _owns_scoped_multiplayer()}
	report["actor_contract"] = _actor_wire_contract()
	report["actor_save_schema"] = _actor_save_schema_for_report()
	report["actor_exact_scalars"] = true
	# Preserve the pre-physics restored clock in evidence without another lossy
	# bare-JSON float roundtrip. No private profile or credential is published.
	report["actor_loaded_clock_bits_le"] = ""
	var restored_clock: Variant = _load_summary.get("world_seconds")
	if (restored_clock is int or restored_clock is float) and is_finite(float(restored_clock)):
		var clock_bytes := PackedByteArray()
		clock_bytes.resize(8)
		clock_bytes.encode_double(0, float(restored_clock))
		report["actor_loaded_clock_bits_le"] = clock_bytes.hex_encode()
	report["actor_runtime"] = {"physics_ready": _physics_runtime_ready, "physics_steps": _actor_physics_steps, "last_physics_frame": _last_actor_physics_frame, "client_implemented": true, "client_public_snapshot_implemented": true, "input_rpc_implemented": true, "input_receipt_implemented": false, "input_snapshot_cursor_implemented": true, "client_input_pending_implemented": true, "prediction_implemented": false, "presentation": _actor_presentation(), "formal_world_allowed": false}
	var client_snapshot: Dictionary = _actor_client_state.snapshot() if _actor_client_state != null else {}
	var reported_snapshot: Variant = data.get("snapshot", {})
	var input_online: bool = _actor_input_pending != null and _actor_input_pending.ready and _client_actor_input_context() == _actor_input_binding
	report["actor_input_pending"] = {"ready":input_online, "pending_count":_actor_input_pending.pending().size() if _actor_input_pending != null else 0, "sent_count":_actor_client_sent_count, "cursor":_actor_input_pending.cursor() if _actor_input_pending != null else {}, "admission_only":true}
	report["actor_client"] = {"accepted_snapshot": not client_snapshot.is_empty(), "actor_count": client_snapshot.get("actor_public", {}).get("actors", {}).size(), "read_only": not _actor_client_sent_intent, "cached_authority_revision": client_snapshot.get("revision", -1), "cached_actor_revision": client_snapshot.get("actor_public", {}).get("revision", -1), "matches_reported_snapshot": _client_snapshot_matches_report(client_snapshot, reported_snapshot)}
	# The transport callback also keeps an incoming snapshot. Expose independent
	# cache versions/clock evidence so a stale accepted cache cannot hide behind it.
	for label in ["cached", "reported"]:
		report["actor_client"][label + "_clock_bits_le"] = ""
		var clock_value: Variant = client_snapshot.get("world_seconds") if label == "cached" else (reported_snapshot.get("world_seconds") if reported_snapshot is Dictionary else null)
		if (clock_value is int or clock_value is float) and is_finite(float(clock_value)):
			var exact_clock := PackedByteArray()
			exact_clock.resize(8)
			exact_clock.encode_double(0, float(clock_value))
			report["actor_client"][label + "_clock_bits_le"] = exact_clock.hex_encode()
	super._write_report(report)

# Keep both RPC declarations in this shared ancestor: the terrain server and
# terrain GUI client are different leaves. Default schema3/4 hooks refuse all.
@rpc("any_peer", "call_remote", "reliable")
func inventory_request012(request: Variant) -> void:
	if _mode not in ["server", "host"] or _closing or _fatal_shutdown or _peer == null or not _owns_scoped_multiplayer() or not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender > 1: _receive_inventory_request012(sender, request)

@rpc("authority", "call_remote", "reliable")
func inventory_reply012(reply: Variant) -> void:
	if _mode != "client" or _closing or _fatal_shutdown or _actor_client_connection_lost or not _actor_client_transport_state().get("ok", false): return
	if multiplayer.get_remote_sender_id() == 1: _receive_inventory_reply012(reply)

func _receive_inventory_request012(_sender: int, _request: Variant) -> Dictionary:
	return {"ok": false, "code": "INVENTORY_PROFILE_UNSUPPORTED"}

func _receive_inventory_reply012(_reply: Variant) -> void:
	return

@rpc("authority", "call_remote", "reliable")
func inventory_sync012(_packet: Dictionary) -> void:
	pass # Only schema5 client leaf consumes the authenticated private sync.
