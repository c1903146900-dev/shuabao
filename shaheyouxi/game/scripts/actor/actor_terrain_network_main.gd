extends "res://scripts/actor/actor_network_main.gd"
## Schema4 remains the default; explicit schema5 adds private inventory saves.
## An explicit server-only activation can
## run a fixed supported roster through the same confirmed Frame and bounded FIFO.
const TerrainPublic = preload("res://scripts/actor/actor_terrain_public_projection.gd")
const TerrainClient = preload("res://scripts/actor/actor_terrain_client_state.gd")
const TerrainSession = preload("res://scripts/actor/actor_terrain_session_state.gd")
const TerrainStore = preload("res://scripts/terrain/combined_terrain_store.gd")
const TerrainValues = preload("res://scripts/terrain/required_entry_terrain_store.gd") # Existing exact Variant comparison semantics.
const TerrainStage = preload("res://scripts/terrain/combined_terrain_stage.gd")
const ActorTerrainSpace = preload("res://scripts/actor/actor_terrain_space.gd")
const BootstrapFrame = preload("res://scripts/actor/actor_frame_transaction.gd")
const ActorState = preload("res://scripts/actor/actor_state.gd")
const LocalScope = preload("res://scripts/actor/actor_local_session_scope.gd")
const InventoryProfiles = preload("res://scripts/inventory/inventory_save_profiles012.gd")
const InventoryLive = preload("res://scripts/inventory/inventory_live012.gd")
const InventoryOwner = preload("res://scripts/inventory/inventory_owner012.gd")
const TreeInventoryOwner = preload("res://scripts/harvest/tree_inventory_owner012.gd")
const TreeTerrainSpace = preload("res://scripts/harvest/tree_terrain_space012.gd")
const TreeSession = preload("res://scripts/harvest/tree_world_session012.gd")
const InventoryCombined = preload("res://scripts/inventory/inventory_world_session012.gd")
const ACTOR_SAVE_SCHEMA4 := 4
const BOOTSTRAP_HELLO_FIELDS := ["network_protocol_version", "catalogue_sha256", "display_name", "resume_profile_id", "resume_secret", "world_contract", "world_bundle_sha256", "actor_contract", "actor_projection_sha256"]
const BOOTSTRAP_MAX_HELLOS := 64
const BOOTSTRAP_MAX_HELLO_BYTES := 4096
const BOOTSTRAP_MAX_QUEUED_BYTES := 65536
var _tree_live_certificate: Dictionary = {}
var _tree_disconnect_transports: Dictionary = {}
var _owner_tree_request: Dictionary = {}
var _owner_tree_request_result: Dictionary = {}
var _owner_tree_ticket: Dictionary = {}
var _save_profile: int = ACTOR_SAVE_SCHEMA4
var _save_profile_binding: Dictionary = {}
var _inventory_registry: RefCounted
var _inventory_owner: RefCounted
var _inventory_runtime_binding: Dictionary = {}
var _inventory_live: RefCounted
var _terrain_session: RefCounted
var _terrain_store: RefCounted
var _terrain_documents: Array = []
var _terrain_component: Dictionary = {}
var _terrain_public: Dictionary = {}
var _terrain_baseline_queued: Dictionary = {}
var _terrain_wire_statistics: Dictionary = {"full_packets_queued": 0, "reference_packets_queued": 0}
var _terrain_creation_attempted: bool = false
var _terrain_stage_creation_count: int = 0
var _terrain_materialization_count: int = 0
var _terrain_generation_count: int = 0
var _terrain_restore_count: int = 0
var _bootstrap_frame: RefCounted
var _bootstrap_runtime_attempted: bool = false
var _bootstrap_presence_busy: bool = false
var _bootstrap_presence_peer: int = 0
var _bootstrap_public_snapshot: Dictionary = {}
var _bootstrap_last_save_receipt: Dictionary = {}
var _bootstrap_welcome_return_count: int = 0
var _bootstrap_hello_queue: Array = []
var _bootstrap_hello_connections: Dictionary = {}
var _bootstrap_hello_bytes: int = 0
var _bootstrap_hello_draining: bool = false
var _bootstrap_transport_serial: int = 0
var _bootstrap_transport_incarnations: Dictionary = {}
var _bootstrap_activation: Dictionary = {}
var _live_input_enabled: bool = false
var _live_input_activated: bool = false
var _live_input_context: Dictionary = {}
var _live_input_roster: Dictionary = {}
var _live_input_queue: Array = []
var _live_input_bytes: int = 0
var _live_input_serial: int = 0
var _live_input_consumed_serial: int = 0
var _live_input_cutoff: int = -1
var _live_input_ticket: Dictionary = {}
var _live_input_pending_delta: float = 0.0
var _live_input_close_ready: bool = false
var _live_failure_code: String = ""
var _inventory_disconnect_transports: Dictionary = {} # Frozen old incarnations; stop-only.
var _ordinary_scope: Dictionary = {}
var _ordinary_settings: Dictionary = {}
var _ordinary_counter: int = -1
var _ordinary_seen_usec: int = 0
var _ordinary_poll_usec: int = -1
var _ordinary_report_store: RefCounted
var _ordinary_report_sequence: int = 0
var _ordinary_report_stage: String = ""
var _ordinary_startup_peers: Dictionary = {}
var _ordinary_handshake_deadlines: Dictionary = {}

static func _ordinary_admitted_join_expired(deadline_usec: int) -> bool:
	return deadline_usec > 0 and Time.get_ticks_usec() >= deadline_usec

func _arm_ordinary_startup_peer(peer_id: int, transport: Dictionary, owner: Dictionary) -> void:
	if _ordinary_scope.is_empty() or transport.is_empty() or _ordinary_startup_peers.has(peer_id):
		return
	var peer: ENetPacketPeer = _peer.get_peer(peer_id)
	if peer == null or peer.get_state() != ENetPacketPeer.STATE_CONNECTED:
		return
	peer.set_timeout(32, 30000, 30000)
	var deadline_usec: int = Time.get_ticks_usec() + 30000000
	_ordinary_startup_peers[peer_id] = {"peer": peer, "transport": transport.duplicate(true), "owner": owner.duplicate(true), "deadline_usec": deadline_usec}
	_ordinary_handshake_deadlines[peer_id] = {"transport": transport.duplicate(true), "owner": owner.duplicate(true), "deadline_usec": deadline_usec}

func _handshake_deadline_reached(peer_id: int) -> bool:
	if _ordinary_handshake_deadlines.has(peer_id):
		var row: Dictionary = _ordinary_handshake_deadlines[peer_id]
		if not _ordinary_scope.is_empty() and row["transport"] == _bootstrap_transport_context(peer_id) and row["owner"] == _bootstrap_owner_context():
			return Time.get_ticks_usec() >= row["deadline_usec"]
		_ordinary_handshake_deadlines.erase(peer_id)
	return super._handshake_deadline_reached(peer_id)

func _poll_ordinary_startup_peers() -> void:
	for peer_id in _ordinary_handshake_deadlines.keys():
		if not _pending_handshakes.has(peer_id):
			_ordinary_handshake_deadlines.erase(peer_id)
	for peer_id in _ordinary_startup_peers.keys():
		var row: Dictionary = _ordinary_startup_peers[peer_id]
		if row["transport"] != _bootstrap_transport_context(peer_id) or row["owner"] != _bootstrap_owner_context():
			# Restore only the captured old packet object, never look up a replacement.
			var old_peer: ENetPacketPeer = row["peer"]
			if old_peer.get_state() == ENetPacketPeer.STATE_CONNECTED:
				old_peer.set_timeout(32, 5000, 30000)
			_ordinary_startup_peers.erase(peer_id)
			_ordinary_handshake_deadlines.erase(peer_id)
			continue
		var accepted := false
		if _live_input_roster.has(peer_id) and _terrain_baseline_queued.has(peer_id):
			var binding: Dictionary = _live_input_roster[peer_id]
			var cursor: Dictionary = _bootstrap_public_snapshot.get("actor_public", {}).get("input_cursors", {}).get(binding["actor_id"], {})
			accepted = cursor.get("input_generation", -1) == binding["input_generation"] and cursor.get("accepted_sequence", 0) > 0
		if accepted or Time.get_ticks_usec() >= row["deadline_usec"]:
			var peer: ENetPacketPeer = row["peer"]
			if peer.get_state() == ENetPacketPeer.STATE_CONNECTED:
				peer.set_timeout(32, 5000, 30000)
			_ordinary_startup_peers.erase(peer_id)

func _client_snapshot_matches_report(_client_snapshot: Dictionary, reported_snapshot: Variant) -> bool:
	return _actor_client_state != null and _actor_client_state.matches_wire_snapshot(reported_snapshot)

func _broadcast_snapshot_base() -> Dictionary:
	return {} if _fatal_shutdown or not _live_failure_code.is_empty() or _terrain_public.is_empty() else _bootstrap_public_snapshot.duplicate(true)

func _snapshot_queue_context(peer_id: int) -> Dictionary:
	var transport: Dictionary = _bootstrap_transport_context(peer_id)
	if transport.is_empty() or _terrain_public.is_empty():
		return {}
	return {"transport": transport, "server_epoch": _authority.server_epoch, "world_id": _authority.world_id, "projection_sha256": _terrain_public["projection_sha256"]}

func _wire_snapshot_for_peer(peer_id: int, snapshot: Dictionary) -> Dictionary:
	var context: Dictionary = _snapshot_queue_context(peer_id)
	if context.is_empty() or snapshot.is_empty():
		return {}
	var packet: Dictionary = snapshot.duplicate(false)
	if _terrain_baseline_queued.get(peer_id) == context:
		packet["terrain_reference"] = TerrainClient.reference_for(_terrain_public)
	else:
		packet["terrain_public"] = _terrain_public.duplicate(true)
	return packet

func _snapshot_send_succeeded(peer_id: int, packet: Dictionary, context: Dictionary) -> void:
	# Same reliable ordered RPC/channel for baseline and references. Mark only
	# after successful queueing on the same connection incarnation, never merely
	# after constructing a packet. Delivery still belongs to the transport.
	if context.is_empty() or context != _snapshot_queue_context(peer_id) or packet.get("server_epoch") != context["server_epoch"] or packet.get("world_id") != context["world_id"]:
		return
	if packet.has("terrain_public"):
		if not packet["terrain_public"] is Dictionary or packet["terrain_public"].get("projection_sha256") != context["projection_sha256"]:
			return
		_terrain_baseline_queued[peer_id] = context.duplicate(true)
		_terrain_wire_statistics["full_packets_queued"] += 1
	else:
		_terrain_wire_statistics["reference_packets_queued"] += 1

func _client_world_component() -> Dictionary:
	return _actor_client_state.world_component_snapshot()

func _actor_wire_contract() -> String:
	return TerrainClient.WIRE_CONTRACT

func _make_actor_client_state() -> RefCounted:
	return TerrainClient.new()

func _runtime_path(value: String) -> String:
	if LocalScope.requested(_arguments):
		return LocalScope.scoped_path(LocalScope.from_arguments(_arguments, "server"), value)
	return super._runtime_path(value)

func _session_time_limit_seconds() -> float:
	return 0.0 if not _ordinary_scope.is_empty() else super._session_time_limit_seconds()

func _ordinary_owner_check(force_read: bool = false) -> Dictionary:
	if _ordinary_scope.is_empty():
		return {"ok": true}
	if not _freeze_save_profile().get("ok", false) or _ordinary_scope.get("save_profile", 4) != _save_profile:
		return _live_failure("LOCAL_OWNER_SAVE_PROFILE_CHANGED")
	if not _live_failure_code.is_empty():
		return _live_failure(_live_failure_code)
	if FileAccess.file_exists(_ordinary_scope["abort"]):
		return _live_failure("LOCAL_OWNER_ABORTED")
	var now: int = Time.get_ticks_usec()
	var timeout_usec: int = int(_ordinary_settings["owner_timeout_seconds"] * 1000000.0)
	if not force_read and _ordinary_counter >= 1 and _ordinary_poll_usec >= 0 and now - _ordinary_poll_usec < int(_ordinary_settings["heartbeat_interval_seconds"] * 1000000.0):
		return _live_failure("LOCAL_OWNER_LOST") if now - _ordinary_seen_usec > timeout_usec else {"ok": true}
	_ordinary_poll_usec = now
	if not LocalScope.profile_marker_matches(_ordinary_scope):
		return _live_failure("LOCAL_OWNER_SAVE_PROFILE_CHANGED")
	var loaded := LocalScope.read_unique_counter(_ordinary_scope) if OS.get_name() == "Windows" else LocalScope.read_json(_ordinary_scope["heartbeat"])
	if not loaded.get("ok", false):
		if loaded.get("pending", false) and _ordinary_counter >= 1 and now - _ordinary_seen_usec <= int(_ordinary_settings["owner_timeout_seconds"] * 1000000.0):
			return {"ok": true} # Missing new publication never extends this deadline.
		return _live_failure("LOCAL_OWNER_HEARTBEAT_UNREADABLE")
	var value: Dictionary = loaded["value"]
	if not ActorState.exact_fields(value, ["schema_version", "session_id", "slot_id", "owner_nonce", "owner_pid", "counter"]):
		return _live_failure("LOCAL_OWNER_HEARTBEAT_INVALID")
	for field in ["session_id", "slot_id", "owner_nonce"]:
		if not value[field] is String or value[field] != _ordinary_scope[field]:
			return _live_failure("LOCAL_OWNER_HEARTBEAT_BINDING")
	if not LocalScope.exact_integer(value["schema_version"], 1) or value["schema_version"] != 1 or not LocalScope.exact_integer(value["owner_pid"], 2) or int(value["owner_pid"]) != _ordinary_scope["owner_pid"] or not LocalScope.exact_integer(value["counter"], 1):
		return _live_failure("LOCAL_OWNER_HEARTBEAT_INVALID")
	var counter: int = int(value["counter"])
	if counter < _ordinary_counter:
		return _live_failure("LOCAL_OWNER_HEARTBEAT_REGRESSED")
	if counter > _ordinary_counter:
		_ordinary_counter = counter
		_ordinary_seen_usec = now
	# A repeated counter or changed mtime does not renew this local deadline.
	if now - _ordinary_seen_usec > int(_ordinary_settings["owner_timeout_seconds"] * 1000000.0):
		return _live_failure("LOCAL_OWNER_LOST")
	return {"ok": true}

func _freeze_save_profile() -> Dictionary:
	# Startup argument is a closed selector, never a script or validator path.
	# Detached exact-owner fixtures also enter this same one-time selection seam.
	if not _save_profile_binding.is_empty():
		return {"ok": true} if _save_profile_valid() else {"ok": false, "code": "INVENTORY_SAVE_PROFILE_CHANGED"}
	var selected: Variant = _arguments.get("save_profile", "4")
	if not selected is String or selected not in ["4", "5", "6"]:
		return {"ok": false, "code": "INVENTORY_SAVE_PROFILE_UNSUPPORTED"}
	if selected == "6" and (_arguments.get("tree_fixture_profile") != "isolated" or _arguments.get("test_entry") != "true"):
		return {"ok":false,"code":"TREE_RUNTIME_FIXTURE_OPT_IN_REQUIRED"}
	var profile: int = int(selected)
	if not InventoryProfiles.platform_supported(profile, OS.get_name()):
		return {"ok": false, "code": "INVENTORY_SAVE_SCHEMA5_WINDOWS_UNSUPPORTED"}
	_save_profile = profile
	_save_profile_binding = {"profile": profile}
	_save_profile_binding.make_read_only()
	return {"ok": true}

func _save_profile_valid() -> bool:
	return not _save_profile_binding.is_empty() and _save_profile == _save_profile_binding["profile"] and _save_profile in [4, 5,6] and InventoryProfiles.platform_supported(_save_profile, OS.get_name())

func _inventory_registry_ready() -> bool:
	return _save_profile_valid() and _save_profile in [5,6] and _inventory_registry != null and _inventory_registry.get_script() == InventoryProfiles and _inventory_registry._binding_valid() and _inventory_registry._terrain == _terrain_session and _inventory_registry._authority == _authority and _inventory_registry.descriptor(_save_profile).get("ok",false)

func _inventory_service_ready() -> bool:
	return _inventory_registry_ready() and not _inventory_runtime_binding.is_empty() and _inventory_runtime_binding["registry"] == _inventory_registry and _inventory_runtime_binding["owner"] == _inventory_owner and _inventory_owner != null and _inventory_owner.get_script() == (TreeInventoryOwner if _save_profile == 6 else InventoryOwner) and _inventory_owner._binding_valid() and _inventory_owner._initialized and not _inventory_owner._busy and _inventory_owner._authority == _authority and _inventory_owner._contract._terrain == _terrain_session

func _initialize_inventory(state: Dictionary, loaded: bool) -> Dictionary:
	if not _inventory_registry_ready() or _inventory_owner != null or not _inventory_runtime_binding.is_empty():
		return {"ok": false, "code": "INVENTORY_OWNER_INITIALIZATION_ORDER", "recoverable_corruption": false}
	var candidate: RefCounted = TreeInventoryOwner.new(_terrain_session,_authority) if _save_profile == 6 else InventoryOwner.new(_terrain_session, _authority)
	var checked: Dictionary = candidate.initialize_loaded(state) if loaded else candidate.initialize_empty(state)
	if not checked.get("ok", false):
		return checked
	_inventory_owner = candidate
	_inventory_runtime_binding = {"registry": _inventory_registry, "owner": candidate}
	_inventory_runtime_binding.make_read_only()
	return {"ok": true}

func _inventory_apply_confirmed_left(authenticated_profile: String, address: Variant, expected_revision: Variant, sequence: Variant) -> Dictionary:
	# Internal server seam only. The later bounded queue authenticates profile,
	# epoch and connection; this hook never accepts an RPC or writes a save.
	if _mode not in ["server", "host"] or _closing or _fatal_shutdown or not _live_failure_code.is_empty() or not _physics_runtime_ready or not _inventory_service_ready() or _bootstrap_frame == null or _bootstrap_frame.get_script() != BootstrapFrame:
		return {"ok": false, "code": "INVENTORY_CONFIRMED_OWNER_NOT_READY"}
	return _bootstrap_frame.apply_confirmed_inventory_left(self, authenticated_profile, address, expected_revision, sequence)

func _prepare_session() -> bool:
	var profile := _freeze_save_profile()
	if not profile.get("ok", false):
		_fail(profile["code"], "存档配置不受支持，未启动世界")
		return false
	if LocalScope.requested(_arguments):
		_ordinary_scope = LocalScope.from_arguments(_arguments, "server")
		_ordinary_settings = LocalScope.settings()
		if _ordinary_scope.is_empty() or _ordinary_settings.is_empty() or _ordinary_scope["owner_pid"] == OS.get_process_id():
			_fail("LOCAL_OWNER_SCOPE_INVALID", "本机会话启动信息无效")
			return false
		_ordinary_scope.make_read_only()
		_ordinary_settings.make_read_only()
		_ordinary_seen_usec = Time.get_ticks_usec()
		if not _ordinary_owner_check().get("ok", false):
			_fail(_live_failure_code, "本机会话所有者不可用，未继续启动")
			return false
	if not super._prepare_session():
		return false
	# Setup is validation-only, including on a restore. Stage is fresh-world only.
	for path in ["generation_settings.json", "prefab_settings.json", "actor_world_bundle011.json"]:
		var document: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + path))
		if not document is Dictionary:
			_fail("ACTOR_TERRAIN_INPUT_INVALID", path)
			return false
		_terrain_documents.append(document)
	_terrain_store = TerrainStore.new(_terrain_documents[0], _terrain_documents[1], _terrain_documents[2])
	_terrain_session = TerrainSession.new(_actor_session, _terrain_store)
	if not _terrain_session.ready:
		_fail("ACTOR_TERRAIN_SESSION_INPUT_INVALID", _terrain_store.last_error if not _terrain_store.ready else _terrain_session.last_error)
		return false
	return true

func _make_save_store() -> SandboxSaveStore:
	var profile := _freeze_save_profile()
	if not profile.get("ok", false):
		return null
	if _save_profile in [5,6]:
		if _inventory_registry != null:
			return null
		_inventory_registry = InventoryProfiles.new(_terrain_session, _authority, _save_directory, int(_save_settings["automatic_backup_count"]), int(_save_settings["manual_slot_count"]))
		var made: Dictionary = _inventory_registry.make_store(_save_profile)
		return made["store"] if made.get("ok", false) else null
	# The existing exact codec covers the entire typed combined snapshot once.
	# TerrainStore's detached byte envelope is never nested inside this SaveStore.
	var store := SandboxSaveStore.new(_save_directory, int(_save_settings["automatic_backup_count"]), int(_save_settings["manual_slot_count"]), _catalogue.source_sha256, int(_settings["network_protocol_version"]), _terrain_session.validate_combined_state, ACTOR_SAVE_SCHEMA4, ACTOR_SAVE_MAXIMUM_BYTES, true)
	if not _ordinary_scope.is_empty() and OS.get_name() == "Windows":
		# A rejected opt-in is sticky in the actual Store; acquire then refuses it.
		# Never silently fall back to replacing old Windows main/index files.
		store.configure_windows_generation_storage()
	return store

func _validate_ordinary_report(text: String) -> Dictionary:
	return LocalScope.validate_report(text, _ordinary_scope, OS.get_process_id())

func _persist_report(data: Dictionary) -> bool:
	if _ordinary_scope.is_empty() or OS.get_name() != "Windows":
		return super._persist_report(data)
	var request: Dictionary = {"ok": false, "missing": true}
	if _ordinary_report_stage == "startup" and data.get("status") is String and data["status"] == "server_ready" and _authority != null:
		request = LocalScope.read_close_request(_ordinary_scope, OS.get_process_id(), _authority.world_id, _authority.server_epoch)
	var next := LocalScope.next_report_stage(_ordinary_report_stage, data, request)
	if not next.get("ok", false):
		_live_failure(str(next.get("code", "LOCAL_REPORT_FAILED")))
		return false
	if next.get("skip", false):
		return true
	if _ordinary_report_store == null:
		var configured := LocalScope.report_store(_ordinary_scope)
		if not configured.get("ok", false):
			_live_failure("LOCAL_REPORT_LAYOUT_INVALID")
			return false
		_ordinary_report_store = configured["store"]
	if _ordinary_report_sequence >= 9007199254740991:
		_live_failure("LOCAL_REPORT_SEQUENCE_EXHAUSTED")
		return false
	var sequence: int = _ordinary_report_sequence + 1
	var encoded := LocalScope.encode_report(data, next["stage"], sequence, _ordinary_scope, OS.get_process_id())
	if not encoded.get("ok", false):
		_live_failure("LOCAL_REPORT_ENCODING_FAILED")
		return false
	var written: Dictionary = _ordinary_report_store.write_generation("server", encoded["text"], sequence, _validate_ordinary_report)
	if not written.get("ok", false):
		_live_failure(str(written.get("code", "LOCAL_REPORT_WRITE_FAILED")))
		return false
	_ordinary_report_sequence = sequence
	_ordinary_report_stage = next["stage"]
	return true

func _create_new_world() -> bool:
	var profile := _freeze_save_profile()
	if not profile.get("ok", false) or (_save_profile in [5,6] and not _inventory_registry_ready()):
		_fail(str(profile.get("code", "INVENTORY_SAVE_REGISTRY_NOT_READY")), "存档配置尚未绑定，未创建世界")
		return false
	if _terrain_creation_attempted or not _terrain_component.is_empty() or not _terrain_services_ready():
		_fail("ACTOR_TERRAIN_CREATION_NOT_ALLOWED", "地形新建只能在已准备的新世界入口执行一次")
		return false
	_terrain_creation_attempted = true
	if not super._create_new_world():
		return false
	_terrain_stage_creation_count += 1
	var stage := TerrainStage.new(_terrain_documents[0], _terrain_documents[1], _terrain_documents[2])
	if not stage.ready:
		_fail("ACTOR_TERRAIN_STAGE_NOT_READY", stage.last_error)
		return false
	_terrain_materialization_count += 1
	var made: Dictionary = stage.materialize(_world.public_component(), _authority.world_id)
	if not made.get("ok", false):
		_fail(str(made.get("code", "ACTOR_TERRAIN_GENERATION_FAILED")), "入口地形生成失败，未保存或监听")
		return false
	var base: Dictionary = _actor_session.combine(_authority.persistent_state(), _actor_model)
	var checked: Dictionary = _terrain_session.combine(base["state"], made["artifact"]) if base.get("ok", false) else base
	if not checked.get("ok", false):
		_fail(str(checked.get("code", "ACTOR_TERRAIN_GENERATION_INVALID")), "新建完整世界合同校验失败，未保存或监听")
		return false
	var public: Dictionary = TerrainPublic.build(_terrain_store, checked["state"]["terrain_component"], _world.public_component(), _authority.world_id)
	if not public.get("ok", false):
		_fail(str(public.get("code", "TERRAIN_PUBLIC_INVALID")), "地形公开显示数据校验失败，未保存或监听")
		return false
	_terrain_public = public["projection"]
	_terrain_component = checked["state"]["terrain_component"].duplicate(true)
	_terrain_generation_count += 1
	if _save_profile in [5,6]:
		var initialized := _initialize_inventory(checked["state"], false)
		if not initialized.get("ok", false):
			_fail(initialized.get("code", "INVENTORY_OWNER_INITIALIZATION_FAILED"), "空物品栏初始化失败，未保存或监听")
			return false
	return true

func _restore_authority_state(state: Dictionary) -> Dictionary:
	# Whole schema5 cold validation precedes ALL world/authority/inventory writes.
	var profile := _freeze_save_profile()
	if not profile.get("ok", false):
		return TerrainSession._bad(profile["code"])
	if not _terrain_services_ready():
		return TerrainSession._bad("ACTOR_TERRAIN_SESSION_NOT_READY")
	var base: Dictionary = state
	if _save_profile in [5,6]:
		if not _inventory_registry_ready() or _inventory_owner != null or not _inventory_runtime_binding.is_empty():
			return TerrainSession._bad("INVENTORY_OWNER_INITIALIZATION_ORDER")
		var cold: Dictionary = _inventory_registry._tree_cold.validate_combined_state(state) if _save_profile == 6 else _inventory_registry._cold.validate_combined_state(state)
		if not cold.get("ok", false):
			return cold
		base = InventoryCombined.terrain_state(TreeSession.inventory_state(state) if _save_profile == 6 else state)
	var checked: Dictionary = _terrain_session.validate_combined_state(base)
	if not checked.get("ok", false):
		return checked
	var stored: Dictionary = _terrain_store.restore(base["terrain_component"], base["world_component"], base["world_id"])
	if not stored.get("ok", false):
		return TerrainSession._closed(stored)
	var public: Dictionary = TerrainPublic.build(_terrain_store, stored["artifact"], base["world_component"], base["world_id"])
	if not public.get("ok", false):
		return TerrainSession._closed(public)
	var restored: Dictionary = super._restore_authority_state(TerrainSession.legacy_state(base))
	if not restored.get("ok", false):
		return TerrainSession._closed(restored)
	_terrain_public = public["projection"]
	_terrain_component = stored["artifact"].duplicate(true)
	_terrain_restore_count += 1
	if _save_profile in [5,6]:
		return _initialize_inventory(state, true)
	return {"ok": true}

func _terrain_services_ready() -> bool:
	return _terrain_store != null and _terrain_store.get_script() == TerrainStore and _terrain_store.ready and _terrain_session != null and _terrain_session.get_script() == TerrainSession and _terrain_session.ready and _terrain_session._terrain_store == _terrain_store and _terrain_session._legacy == _actor_session

func _persistent_state_for_save(advance_auto: bool) -> Dictionary:
	# Read-only confirmed preview; actual writes must go through the Frame receipt.
	if _fatal_shutdown or not _live_failure_code.is_empty() or _bootstrap_frame == null or _bootstrap_frame.get_script() != BootstrapFrame or _terrain_session == null:
		return {}
	var base: Dictionary = _bootstrap_frame.combined_save_state(advance_auto)
	if not base.get("ok", false):
		return {}
	var combined: Dictionary = _terrain_session.combine(base["state"], _terrain_component)
	if not combined.get("ok", false):
		return {}
	if _save_profile in [5,6]:
		if not _inventory_service_ready():
			return {}
		combined = _inventory_owner.combine_for_save(combined["state"])
	return combined["state"] if combined.get("ok", false) else {}

func _make_actor_space() -> RefCounted:
	if _save_profile == 6: return TreeTerrainSpace.new(_terrain_component,_terrain_store,self)
	return ActorTerrainSpace.new(_terrain_component, _terrain_store)

func terrain_runtime_evidence() -> Dictionary:
	var evidence: Dictionary = _actor_space.runtime_evidence() if _actor_space != null and _actor_space.has_method("runtime_evidence") else {}
	evidence["owner_runtime_ready"] = _physics_runtime_ready
	return evidence

func _actor_save_schema_for_report() -> int:
	return _save_profile

func terrain_persistence_statistics() -> Dictionary:
	return {"save_schema": _save_profile, "stage_creation_count": _terrain_stage_creation_count, "materialization_count": _terrain_materialization_count, "generation_count": _terrain_generation_count, "restore_count": _terrain_restore_count, "artifact_sha256": _terrain_component.get("artifact_sha256", ""), "cell_count": _terrain_component.get("counts", {}).get("total_cells", 0), "terrain_contract": _terrain_component.get("contract", ""), "formal_world_allowed": false, "native_clear_allowed": false, "transfer_allowed": false}

func _write_report(data: Dictionary) -> void:
	var report: Dictionary = data.duplicate(true)
	report["terrain_persistence"] = terrain_persistence_statistics()
	report["terrain_wire"] = _terrain_wire_statistics.duplicate(true)
	report["terrain_runtime"] = terrain_runtime_evidence()
	report["bootstrap_runtime"] = {"startup_only": not _live_input_activated, "paused": not _live_input_enabled, "bootstrap_welcome_return_count": _bootstrap_welcome_return_count, "input_admission_implemented": _live_input_activated, "command_implemented": false, "live_f_implemented": _live_input_activated, "presence_pending": _bootstrap_presence_busy, "queued_hellos": _bootstrap_hello_connections.size(), "queued_bytes": _bootstrap_hello_bytes, "last_save_receipt": _bootstrap_save_receipt_summary()}
	report["live_input_runtime"] = live_input_statistics()
	if _save_profile == 5: report["inventory_live_runtime"] = inventory_live_statistics()
	if _authority != null and report.has("snapshot"):
		report["snapshot"] = _public_snapshot()
	super._write_report(report)

func _prepare_runtime_before_listen() -> bool:
	if _closing or _fatal_shutdown or _bootstrap_cancel_requested() or _bootstrap_runtime_attempted:
		return false
	_bootstrap_runtime_attempted = true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or _mode not in ["server", "host"] or _actor_model == null or not _actor_model.ready or _actor_space != null:
		_fail("BOOTSTRAP_RUNTIME_INPUT_INVALID", "启动边界缺少未激活的真实服务，未监听或保存")
		return false
	_actor_space = _make_actor_space()
	if not _actor_space.configure(_world, _actor_inputs):
		_fail("ACTOR_NATIVE_PREPARE_FAILED", _actor_space.last_error)
		return false
	for frame in range(2):
		await tree.physics_frame
		if _closing or _fatal_shutdown or _bootstrap_cancel_requested():
			return false
	for layer_space in _actor_space._spaces.values():
		if PhysicsServer2D.space_get_direct_state(layer_space["rid"]) == null:
			_fail("ACTOR_NATIVE_SPACE_NOT_READY", "启动边界的物理空间尚不可查询")
			return false
	if _save_profile == 6:
		if _actor_space.get_script()!=TreeTerrainSpace:
			_fail("TREE_NATIVE_ADAPTER_IDENTITY","树木原生适配器身份不匹配，未监听或保存")
			return false
		var prepared_trees: Dictionary=_actor_space.prepare_tree_boundary()
		if not prepared_trees.get("ok",false):
			_fail(str(prepared_trees.get("code","TREE_NATIVE_PREPARE_FAILED")),"树木碰撞准备失败，未监听或保存")
			return false
		var tree_context: Dictionary=prepared_trees["context"]
		for tree_frame in range(2):
			await tree.physics_frame
			if _closing or _fatal_shutdown or _bootstrap_cancel_requested(): return false
			if _actor_space==null or _actor_space.get_script()!=TreeTerrainSpace or _actor_space.preparation_context()!=tree_context:
				_fail("TREE_NATIVE_STARTUP_CONTEXT_CHANGED","树木碰撞等待期间身份改变，未监听或保存")
				return false
		var confirmed_trees: Dictionary=_actor_space.confirm_tree_boundary(tree_context)
		if not confirmed_trees.get("ok",false):
			_fail(str(confirmed_trees.get("code","TREE_NATIVE_CONFIRM_FAILED")),"树木碰撞未确认，未监听或保存")
			return false
	# Retained solely for the existing read-only/lifecycle ownership interfaces.
	# This owner never invokes Controller.step/join/disconnect or legacy saves.
	_actor_controller = ActorController.new(_authority, _world, _actor_model, _actor_space, _actor_inputs)
	if not _actor_controller.ready:
		_fail("ACTOR_CONTROLLER_PREPARE_FAILED", _actor_controller.fatal_error)
		return false
	_bootstrap_frame = BootstrapFrame.new(_authority, _world, _actor_model, _actor_space, _actor_inputs)
	var prepared: Dictionary = _bootstrap_frame.prepare_initial_boundary(self)
	if not prepared.get("prepared", false) or not prepared.get("pending", false) or not prepared.get("ticket") is Dictionary:
		_fail(str(prepared.get("code", "BOOTSTRAP_INITIAL_PREPARE_FAILED")), "初始确认边界准备失败")
		return false
	var context := _bootstrap_owner_context()
	await tree.physics_frame
	if _closing or _fatal_shutdown or _bootstrap_cancel_requested():
		return false
	if context != _bootstrap_owner_context():
		_fail("BOOTSTRAP_INITIAL_OWNER_CHANGED", "初始确认等待期间服务身份已改变")
		return false
	var confirmed: Dictionary = _bootstrap_frame.confirm_initial_boundary(prepared["ticket"])
	if not confirmed.get("ok", false) or not confirmed.get("confirmed", false):
		_fail(str(confirmed.get("code", "BOOTSTRAP_INITIAL_CONFIRM_FAILED")), "初始边界未确认，未监听或保存")
		return false
	_bootstrap_public_snapshot = _bootstrap_frame.last_confirmed_snapshot()
	_physics_runtime_ready = true
	return true

func _bootstrap_owner_context() -> Dictionary:
	if _authority == null or _world == null or _actor_model == null or _actor_space == null or _actor_inputs == null or _terrain_store == null or _save_store == null or _bootstrap_frame == null or _bootstrap_frame.get_script() != BootstrapFrame:
		return {}
	return {"mode": _mode, "epoch": _authority.server_epoch, "world_id": _authority.world_id, "authority": _authority.get_instance_id(), "world": _world.get_instance_id(), "model": _actor_model.get_instance_id(), "space": _actor_space.get_instance_id(), "inputs": _actor_inputs.get_instance_id(), "terrain": _terrain_store.get_instance_id(), "save_store": _save_store.get_instance_id(), "frame": _bootstrap_frame.get_instance_id(), "save_profile": _save_profile, "inventory_owner": _inventory_owner.get_instance_id() if _inventory_owner != null else 0, "inventory_registry": _inventory_registry.get_instance_id() if _inventory_registry != null else 0}

func _bootstrap_transport_context(peer_id: int) -> Dictionary:
	if peer_id <= 1 or _pending_disconnects.has(peer_id) or not is_inside_tree() or _peer == null or not _owns_scoped_multiplayer() or not multiplayer.is_server() or multiplayer.multiplayer_peer != _peer or not multiplayer.get_peers().has(peer_id) or not _bootstrap_transport_incarnations.has(peer_id):
		return {}
	var packet_peer: ENetPacketPeer = _peer.get_peer(peer_id)
	if packet_peer == null or packet_peer.get_state() != ENetPacketPeer.STATE_CONNECTED or packet_peer.get_channels() <= 0:
		return {}
	return {"peer_id": peer_id, "incarnation": _bootstrap_transport_incarnations[peer_id], "transport": _peer.get_instance_id(), "api": _actor_scene_api.get_instance_id()}

func _join_authority_peer(_peer_id: int, _request: Dictionary, _local_host: bool = false) -> Dictionary:
	# Prevent callers from accidentally selecting the synchronous schema3 bypass.
	return {"ok": false, "code": "BOOTSTRAP_ASYNC_JOIN_REQUIRED"}

func _trace_bootstrap_phase(stage: String) -> void:
	# Bounded diagnostic markers only for the ordinary local owner. No identities,
	# hello fields, credentials, state snapshots, or artificial time advancement.
	if not _ordinary_scope.is_empty():
		print("NEW4_BOOTSTRAP_PHASE " + JSON.stringify({"stage": stage, "uptime_usec": Time.get_ticks_usec(), "physics_frame": Engine.get_physics_frames(), "pending_handshakes": _pending_handshakes.size(), "pending_disconnects": _pending_disconnects.size()}))

func _join_authority_peer_async(peer_id: int, request: Dictionary, local_host: bool = false) -> Dictionary:
	if _live_input_activated:
		return {"ok": false, "code": "LIVE_INPUT_ROSTER_CLOSED"}
	if _closing or _fatal_shutdown or _bootstrap_cancel_requested():
		return {"ok": false, "code": "ACTOR_SESSION_STOPPING"}
	if not _physics_runtime_ready or _bootstrap_frame == null or _bootstrap_presence_busy:
		return {"ok": false, "code": "BOOTSTRAP_BOUNDARY_UNAVAILABLE"}
	var tree := Engine.get_main_loop() as SceneTree
	var context := _bootstrap_owner_context()
	var transport := {} if local_host else _bootstrap_transport_context(peer_id)
	if tree == null or context.is_empty() or (local_host and (peer_id != 1 or _mode != "host")) or (not local_host and transport.is_empty()):
		return {"ok": false, "code": "BOOTSTRAP_PEER_BINDING_INVALID"}
	_bootstrap_presence_busy = true
	_bootstrap_presence_peer = peer_id
	_trace_bootstrap_phase("presence_prepare_begin")
	var prepared: Dictionary = _bootstrap_frame.prepare_bootstrap_presence(peer_id, request, local_host)
	_trace_bootstrap_phase("presence_prepare_end")
	if not prepared.get("ok", false):
		_bootstrap_presence_busy = false
		_bootstrap_presence_peer = 0
		if prepared.get("fatal", false):
			_fail(str(prepared.get("code", "BOOTSTRAP_PRESENCE_PREPARE_FAILED")), "恢复加入准备失败，未保存或发布")
		return prepared
	if not local_host:
		_arm_ordinary_startup_peer(peer_id, transport, context)
	var startup_deadline_usec: int = _ordinary_handshake_deadlines.get(peer_id, {}).get("deadline_usec", 0)
	_trace_bootstrap_phase("presence_commit_begin")
	var committed: Dictionary = _bootstrap_frame.commit_bootstrap_presence(prepared["ticket"])
	_trace_bootstrap_phase("presence_commit_end")
	if not committed.get("pending", false) or not committed.get("committed", false):
		_fail(str(committed.get("code", "BOOTSTRAP_PRESENCE_COMMIT_FAILED")), "恢复加入提交失败，未保存或发布")
		return {"ok": false, "fatal": true, "code": committed.get("code", "BOOTSTRAP_PRESENCE_COMMIT_FAILED")}
	# A normal stop now waits for this exact confirmation and save. A transport or
	# ownership change is fatal: never welcome a replacement connection/owner.
	_trace_bootstrap_phase("presence_frame_wait_begin")
	await tree.physics_frame
	_trace_bootstrap_phase("presence_frame_wait_end")
	if _closing or _fatal_shutdown:
		return {"ok": false, "code": "ACTOR_SESSION_STOPPING", "fatal": true}
	if context != _bootstrap_owner_context() or (not local_host and transport != _bootstrap_transport_context(peer_id)):
		_fail("BOOTSTRAP_PRESENCE_OWNER_CHANGED", "恢复加入等待期间身份或连接已改变，未保存或发布")
		return {"ok": false, "fatal": true, "code": "BOOTSTRAP_PRESENCE_OWNER_CHANGED"}
	if _ordinary_admitted_join_expired(startup_deadline_usec):
		_fail("LOCAL_JOIN_TIMEOUT", "角色加入确认已超时，未发布成功")
		return {"ok": false, "fatal": true, "code": "LOCAL_JOIN_TIMEOUT"}
	_trace_bootstrap_phase("presence_confirm_begin")
	var confirmed: Dictionary = _bootstrap_frame.confirm_bootstrap_presence(prepared["ticket"])
	_trace_bootstrap_phase("presence_confirm_end")
	if not confirmed.get("ok", false) or not confirmed.get("confirmed", false):
		_fail(str(confirmed.get("code", "BOOTSTRAP_PRESENCE_CONFIRM_FAILED")), "恢复加入未确认，未保存或发布")
		return {"ok": false, "fatal": true, "code": confirmed.get("code", "BOOTSTRAP_PRESENCE_CONFIRM_FAILED")}
	if _ordinary_admitted_join_expired(startup_deadline_usec):
		_fail("LOCAL_JOIN_TIMEOUT", "角色加入确认已超时，未开始保存或发布成功")
		return {"ok": false, "fatal": true, "code": "LOCAL_JOIN_TIMEOUT"}
	_trace_bootstrap_phase("presence_save_begin")
	if not _save_world("bootstrap_join"):
		return {"ok": false, "fatal": true, "code": _last_save_summary.get("code", "BOOTSTRAP_SAVE_FAILED")}
	_trace_bootstrap_phase("presence_save_end")
	if context != _bootstrap_owner_context() or (not local_host and transport != _bootstrap_transport_context(peer_id)):
		_fail("BOOTSTRAP_PRESENCE_OWNER_CHANGED", "存档已完成但加入身份已改变，未发布成功")
		return {"ok": false, "fatal": true, "code": "BOOTSTRAP_PRESENCE_OWNER_CHANGED", "main_committed": _last_save_summary.get("main_committed", false)}
	if _ordinary_admitted_join_expired(startup_deadline_usec):
		_fail("LOCAL_JOIN_TIMEOUT", "角色加入已超时，保留刚完成的存档，未发布成功")
		return {"ok": false, "fatal": true, "code": "LOCAL_JOIN_TIMEOUT", "main_committed": _last_save_summary.get("main_committed", false)}
	if _bootstrap_cancel_requested():
		_bootstrap_presence_busy = false
		_bootstrap_presence_peer = 0
		# The durable save is real, but shutdown supersedes private welcome/identity
		# publication. Base _ready observes closing before writing a local identity.
		_close_confirmed_bootstrap()
		return {"ok": false, "stopped": true, "code": "BOOTSTRAP_STOPPED_AFTER_CONFIRMED_SAVE"}
	if confirmed.get("surface_bootstrap", false):
		# This one-use proof exists only inside the actual confirmed + saved join.
		# It is not a caller option on the public activation method or an RPC field.
		_bootstrap_activation = {"ticket": prepared["ticket"].duplicate(true), "context": context, "peer_id": peer_id, "actor_id": confirmed["welcome"]["player_instance_id"], "sequence": _save_store.last_sequence, "save_serial": _bootstrap_frame._save_serial, "saved_boundary": _bootstrap_frame._lineage.duplicate(true), "save_receipt": _bootstrap_last_save_receipt.duplicate(true)}
		_trace_bootstrap_phase("presence_activate_begin")
		var enabled := _activate_confirmed_surface_bootstrap(startup_deadline_usec)
		_trace_bootstrap_phase("presence_activate_end")
		if not enabled.get("ok", false):
			if not _closing:
				_fail(str(enabled.get("code", "SURFACE_BOOTSTRAP_ACTIVATION_FAILED")), "地表加入的确认输入阶段未启用，未发送欢迎")
			return {"ok": false, "fatal": true, "code": enabled.get("code", "SURFACE_BOOTSTRAP_ACTIVATION_FAILED")}
	if _ordinary_admitted_join_expired(startup_deadline_usec):
		_live_input_enabled = false
		_fail("LOCAL_JOIN_TIMEOUT", "加入发布已超时，保留完整存档，未发送欢迎")
		return {"ok": false, "fatal": true, "code": "LOCAL_JOIN_TIMEOUT", "main_committed": _last_save_summary.get("main_committed", false)}
	_bootstrap_presence_busy = false
	_bootstrap_presence_peer = 0
	_bootstrap_welcome_return_count += 1
	_trace_bootstrap_phase("presence_welcome_ready")
	return confirmed["welcome"].duplicate(true)

func _bounded_bootstrap_hello(request: Dictionary) -> Dictionary:
	# Reject nested/object/oversized values before either recursive copy or codec.
	if request.size() != BOOTSTRAP_HELLO_FIELDS.size():
		return {"ok": false, "code": "BOOTSTRAP_HELLO_SHAPE_INVALID"}
	for field in BOOTSTRAP_HELLO_FIELDS:
		if not request.has(field):
			return {"ok": false, "code": "BOOTSTRAP_HELLO_SHAPE_INVALID"}
		if field == "network_protocol_version":
			if typeof(request[field]) != TYPE_INT:
				return {"ok": false, "code": "BOOTSTRAP_HELLO_SHAPE_INVALID"}
		elif not request[field] is String or request[field].length() > 128:
			return {"ok": false, "code": "BOOTSTRAP_HELLO_SHAPE_INVALID"}
	var size := var_to_bytes(request).size()
	if size > BOOTSTRAP_MAX_HELLO_BYTES:
		return {"ok": false, "code": "BOOTSTRAP_HELLO_TOO_LARGE"}
	var checked: Dictionary = _validate_remote_hello(request)
	if checked.get("ok", false):
		checked["bytes"] = size
	return checked

func _handle_remote_hello(sender: int, request: Dictionary) -> void:
	if not _owner_tree_ticket.is_empty(): return
	if _closing or _fatal_shutdown or _bootstrap_cancel_requested():
		return
	if _live_input_activated:
		# An authenticated duplicate must not reach the old failure completion,
		# which schedules a disconnect. No new welcome or presence is admitted.
		if _authority != null and _authority.active_peer_ids().has(sender):
			if not _bootstrap_transport_context(sender).is_empty():
				command_result.rpc_id(sender, {"ok": false, "code": "LIVE_INPUT_ROSTER_CLOSED"})
		elif not _bootstrap_transport_context(sender).is_empty():
			_complete_remote_hello(sender, {"ok": false, "code": "LIVE_INPUT_ROSTER_CLOSED"})
		return
	var transport := _bootstrap_transport_context(sender)
	if transport.is_empty() or _bootstrap_hello_connections.has(sender):
		return # At most one pending hello per connection; no duplicate replay.
	var checked := _bounded_bootstrap_hello(request)
	if not checked.get("ok", false):
		_complete_remote_hello(sender, checked)
		return
	var context := _bootstrap_owner_context()
	if context.is_empty():
		_complete_remote_hello(sender, {"ok": false, "code": "BOOTSTRAP_BOUNDARY_UNAVAILABLE"})
		return
	var event := {"sender": sender, "transport": transport, "owner": context, "request": checked["request"].duplicate(true), "bytes": 0}
	# Bound the stored event including trusted identity metadata, not just the
	# smaller filtered hello. Replacing the integer byte counter keeps its width.
	var event_bytes := var_to_bytes(event).size()
	if event_bytes > BOOTSTRAP_MAX_HELLO_BYTES or _bootstrap_hello_connections.size() >= BOOTSTRAP_MAX_HELLOS or _bootstrap_hello_bytes + event_bytes > BOOTSTRAP_MAX_QUEUED_BYTES:
		_complete_remote_hello(sender, {"ok": false, "code": "BOOTSTRAP_HELLO_QUEUE_FULL"})
		return
	event["bytes"] = event_bytes
	_bootstrap_hello_connections[sender] = transport["incarnation"]
	_bootstrap_hello_bytes += event_bytes
	_bootstrap_hello_queue.append(event)

func _drain_bootstrap_hello() -> void:
	if not _owner_tree_ticket.is_empty(): return
	if _bootstrap_hello_draining or _bootstrap_presence_busy or _bootstrap_hello_queue.is_empty() or not _startup_ready or _closing or _fatal_shutdown or _bootstrap_cancel_requested():
		return
	_bootstrap_hello_draining = true
	var event: Dictionary = _bootstrap_hello_queue.pop_front()
	var sender: int = event["sender"]
	if event["transport"] == _bootstrap_transport_context(sender) and event["owner"] == _bootstrap_owner_context():
		if _live_input_activated:
			# Previously queued hellos now receive the same fixed-roster rejection as
			# newly arriving ones. Keep the in-flight accounting until the common tail.
			_handle_remote_hello(sender, event["request"])
		else:
			var result: Dictionary = await _join_authority_peer_async(sender, event["request"], false)
			if not _closing and not _fatal_shutdown and not _bootstrap_cancel_requested() and event["transport"] == _bootstrap_transport_context(sender) and event["owner"] == _bootstrap_owner_context():
				_complete_remote_hello(sender, result)
	# Accounting includes the in-flight item until its await has finished. Never
	# erase an incarnation admitted later under the same recycled peer number.
	if _bootstrap_hello_connections.get(sender) == event["transport"]["incarnation"]:
		_bootstrap_hello_connections.erase(sender)
		_bootstrap_hello_bytes -= event["bytes"]
	_bootstrap_hello_draining = false

func _on_peer_connected(peer_id: int) -> void:
	_terrain_baseline_queued.erase(peer_id)
	if _bootstrap_transport_serial >= ActorMotion.MAX_REVISION:
		_fail("BOOTSTRAP_CONNECTION_GENERATION_EXHAUSTED", "连接世代已耗尽")
		return
	_bootstrap_transport_serial += 1
	_bootstrap_transport_incarnations[peer_id] = _bootstrap_transport_serial
	super._on_peer_connected(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if _save_profile == 6 and _live_input_activated and _live_input_enabled and _startup_ready and not _closing and not _fatal_shutdown and _live_input_roster.has(peer_id):
		_freeze_tree_disconnected_transport(peer_id)
	# A loss after schema5 activation requests a bounded complete-state shutdown.
	# Keep the logical roster until Frame confirms and saves it, not half-remove
	# the actor and inventory. This first slice closes the fixed-roster server.
	if _save_profile == 5 and _live_input_activated and _live_input_enabled and _startup_ready and not _closing and not _fatal_shutdown and _live_input_roster.has(peer_id):
		var frozen: Dictionary = _live_input_roster[peer_id]["transport"]
		if peer_id > 1 and frozen.get("incarnation") == _bootstrap_transport_incarnations.get(peer_id) and _inventory_live != null and _inventory_live._streams.has(peer_id) and _inventory_live._streams[peer_id]["transport"] == frozen:
			_inventory_disconnect_transports[peer_id] = frozen.duplicate(true)
			_request_live_input_stop()
	_ordinary_handshake_deadlines.erase(peer_id)
	_ordinary_startup_peers.erase(peer_id)
	_terrain_baseline_queued.erase(peer_id)
	_bootstrap_transport_incarnations.erase(peer_id)
	_pending_handshakes.erase(peer_id)
	_pending_disconnects.erase(peer_id)
	if _closing or _fatal_shutdown:
		return
	if not _disconnect_authority_peer(peer_id):
		return
	# Unauthenticated transport loss only removes its bounded hello bookkeeping.
	for index in range(_bootstrap_hello_queue.size() - 1, -1, -1):
		var event: Dictionary = _bootstrap_hello_queue[index]
		if event["sender"] == peer_id:
			_bootstrap_hello_bytes -= event["bytes"]
			_bootstrap_hello_queue.remove_at(index)
	_bootstrap_hello_connections.erase(peer_id)

func _disconnect_authority_peer(peer_id: int) -> bool:
	if _closing or _fatal_shutdown:
		return false
	if _save_profile == 6 and _live_input_cutoff >= 0 and _tree_disconnect_transports.has(peer_id) and _tree_live_certificate_matches():
		return true # Original authenticated roster persists until confirmed save.
	if _save_profile == 5 and _live_input_cutoff >= 0 and _inventory_disconnect_transports.has(peer_id):
		return true # Frozen accepted queues are drained by the normal Frame path.
	if peer_id == _bootstrap_presence_peer or (_authority != null and _authority.active_peer_ids().has(peer_id)):
		_fail("BOOTSTRAP_AUTHENTICATED_DISCONNECT_UNSUPPORTED", "此固定名单入口不提交断开生命周期，已停止且不保存")
		return false
	return true

func activate_supported_input_phase() -> Dictionary:
	# Explicit activation keeps the original public gates. Surface joins use only
	# their private, one-use proof after actual confirmation/save, before welcome.
	return _activate_supported_input(false)

func _activate_confirmed_surface_bootstrap(startup_deadline_usec: int = 0) -> Dictionary:
	return _activate_supported_input(true, startup_deadline_usec)

func _activate_supported_input(confirmed_bootstrap: bool, startup_deadline_usec: int = 0) -> Dictionary:
	# The final implementation consumes the proof itself; calling this helper with
	# true cannot skip validation by bypassing its ordinary wrapper.
	var proof: Dictionary = {}
	if confirmed_bootstrap:
		proof = _bootstrap_activation
		_bootstrap_activation = {}
		if not _surface_activation_proof_valid(proof):
			return {"ok": false, "code": "SURFACE_BOOTSTRAP_PROOF_REQUIRED"}
	if _live_input_activated:
		return {"ok": false, "code": "LIVE_INPUT_ALREADY_ACTIVATED"}
	if _mode not in ["server", "host"] or _closing or _fatal_shutdown or _bootstrap_cancel_requested() or not _physics_runtime_ready or _bootstrap_frame == null or _bootstrap_frame.get_script() != BootstrapFrame:
		return {"ok": false, "code": "LIVE_INPUT_ACTIVATION_UNAVAILABLE"}
	if not confirmed_bootstrap and (not _startup_ready or _bootstrap_presence_busy or _bootstrap_hello_draining or not _bootstrap_hello_queue.is_empty() or not _bootstrap_hello_connections.is_empty()):
		return {"ok": false, "code": "LIVE_INPUT_ACTIVATION_UNAVAILABLE"}
	var checked: Dictionary = _bootstrap_frame.public_snapshot()
	if not checked.get("ok", false):
		if checked.get("fatal", false):
			return _live_failure(str(checked.get("code", "LIVE_INPUT_INITIAL_BOUNDARY_INVALID")))
		return {"ok": false, "code": "LIVE_INPUT_CONFIRMED_BASELINE_REQUIRED"}
	var snapshot: Dictionary = checked["snapshot"]
	if confirmed_bootstrap:
		if _bootstrap_frame._actor_for_peer(proof["peer_id"]) != proof["actor_id"] or not snapshot["actor_public"]["actors"].has(proof["actor_id"]) or snapshot["actor_public"]["actors"][proof["actor_id"]]["layer"]["map_kind"] != "surface":
			return {"ok": false, "code": "SURFACE_BOOTSTRAP_PROOF_REQUIRED"}
	if snapshot["players"].is_empty() or _bootstrap_owner_context().is_empty():
		return {"ok": false, "code": "LIVE_INPUT_NONEMPTY_ROSTER_REQUIRED"}
	var roster: Dictionary = {}
	for profile_id in snapshot["players"]:
		var player: Dictionary = snapshot["players"][profile_id]
		var actor_id: String = player["player_instance_id"]
		var peer_id: int = player["peer_id"]
		var actor: Dictionary = snapshot["actor_public"]["actors"][actor_id]
		# The preceding Frame gate proves actual two-RID space/transform/shape
		# bindings. This queries the complete configured circle at its real target,
		# including map circle, materialized_bounds and native environmental overlap.
		if not _actor_space.environment_clear(actor["layer"], ActorState.vector(actor["position"])):
			return {"ok": false, "code": "LIVE_INPUT_COMPLETE_BODY_NOT_SUPPORTED"}
		var transport := _live_peer_context(peer_id)
		if transport.is_empty():
			return {"ok": false, "code": "LIVE_INPUT_PEER_BINDING_INVALID"}
		roster[peer_id] = {"profile_id": profile_id, "actor_id": actor_id, "input_generation": snapshot["actor_public"]["input_cursors"][actor_id]["input_generation"], "transport": transport}
	if confirmed_bootstrap:
		# The same synchronous join already durably saved this exact confirmed
		# boundary. No await, tick or mutation occurs between minting/consuming
		# its private one-use proof. Recheck after native/roster queries; receipt
		# fields alone cannot substitute for that unchanged actual Frame lineage.
		if not _surface_activation_proof_valid(proof):
			return {"ok": false, "code": "SURFACE_BOOTSTRAP_SAVED_BOUNDARY_CHANGED"}
		_trace_bootstrap_phase("activation_reuse_confirmed_save")
	else:
		# The separately requested activation keeps its original fresh-save gate.
		if not _save_world("bootstrap_join"):
			return {"ok": false, "fatal": true, "code": "LIVE_INPUT_ACTIVATION_SAVE_FAILED", "retry_allowed": false}
	_live_input_context = _bootstrap_owner_context()
	_live_input_roster = roster
	if _ordinary_admitted_join_expired(startup_deadline_usec):
		return {"ok": false, "code": "LOCAL_JOIN_TIMEOUT"}
	if _save_profile == 6:
		var certified := _capture_tree_live_certificate()
		if not certified.get("ok", false): return certified
	_live_input_activated = true
	_live_input_enabled = true
	if _save_profile == 5:
		var inventory_ready := _bind_inventory_live_roster()
		if not inventory_ready.get("ok", false): return _live_failure(str(inventory_ready.get("code", "INVENTORY_LIVE_BINDING")))
	return {"ok": true, "enabled": true, "fixed_roster_count": roster.size()}

func _surface_activation_proof_valid(proof: Variant) -> bool:
	if not ActorState.exact_fields(proof, ["ticket", "context", "peer_id", "actor_id", "sequence", "save_serial", "saved_boundary", "save_receipt"]) or not proof["actor_id"] is String or not proof["context"] is Dictionary:
		return false
	if not SandboxServerAuthority._valid_id(proof["actor_id"], "entity_player_"):
		return false
	for field in ["peer_id", "sequence", "save_serial"]:
		if typeof(proof[field]) != TYPE_INT or proof[field] < 1:
			return false
	var ticket: Variant = proof["ticket"]
	if not ActorState.exact_fields(ticket, ["owner_id", "generation", "kind"]) or typeof(ticket["owner_id"]) != TYPE_INT or typeof(ticket["generation"]) != TYPE_INT or not ticket["kind"] is String or ticket["kind"] != "bootstrap_presence":
		return false
	if _bootstrap_frame == null or _bootstrap_frame.get_script() != BootstrapFrame or _bootstrap_frame._source_lease == null or _save_store == null or not _bootstrap_presence_busy or _bootstrap_presence_peer != proof["peer_id"] or (not _startup_ready and (_mode != "host" or proof["peer_id"] != 1)):
		return false
	if not _bootstrap_frame._source_lease.guard().get("ok", false):
		return false
	if not proof["saved_boundary"] is Dictionary or proof["saved_boundary"] != _bootstrap_frame._lineage:
		return false
	var receipt: Variant = proof["save_receipt"]
	if not ActorState.exact_fields(receipt, ["owner_id", "generation", "store_id", "sequence", "state_sha256", "main_committed", "complete"]) or receipt != _bootstrap_last_save_receipt or not TerrainValues._same(receipt.get("complete"), true) or not TerrainValues._same(receipt.get("main_committed"), true):
		return false
	if typeof(receipt["owner_id"]) != TYPE_INT or typeof(receipt["generation"]) != TYPE_INT or typeof(receipt["store_id"]) != TYPE_INT or typeof(receipt["sequence"]) != TYPE_INT or not TerrainValues._hash(receipt["state_sha256"]):
		return false
	if receipt["owner_id"] != _bootstrap_frame.get_instance_id() or receipt["generation"] != proof["save_serial"] or receipt["store_id"] != _save_store.get_instance_id() or receipt["sequence"] != proof["sequence"]:
		return false
	if _last_save_summary.get("reason") != "bootstrap_join" or _last_save_summary.get("ok") != true or _last_save_summary.get("sequence") != proof["sequence"]:
		return false
	return TerrainValues._same(proof["context"], _bootstrap_owner_context()) and proof["sequence"] == _save_store.last_sequence and proof["save_serial"] == _bootstrap_frame._save_serial and ticket["owner_id"] == _bootstrap_frame.get_instance_id() and ticket["generation"] == _bootstrap_frame._generation

func _capture_tree_live_certificate() -> Dictionary:
	if _save_profile != 6 or not _tree_live_certificate.is_empty() or _bootstrap_frame == null or _bootstrap_frame._source_lease == null or _bootstrap_frame._source_lease.bound_save_owner() != self or _live_input_context != _bootstrap_owner_context() or _live_input_roster.is_empty():
		return _live_failure("TREE_LIVE_CERTIFICATE_UNAVAILABLE")
	var roster: Dictionary = _live_input_roster.duplicate(true)
	for peer_id in roster:
		var binding: Dictionary = roster[peer_id]
		if not ActorState.exact_fields(binding, ["profile_id", "actor_id", "input_generation", "transport"]) or not binding["transport"] is Dictionary: return _live_failure("TREE_LIVE_ROSTER_INVALID")
		binding["transport"].make_read_only()
		binding.make_read_only()
	roster.make_read_only()
	var context: Dictionary = _live_input_context.duplicate(true)
	context.make_read_only()
	_tree_live_certificate = {"owner":weakref(self), "frame":_bootstrap_frame, "lease":_bootstrap_frame._source_lease, "peer":_peer, "api":_actor_scene_api, "context":context, "roster":roster}
	_tree_live_certificate.make_read_only()
	return {"ok":true} if _tree_live_certificate_matches() else _live_failure("TREE_LIVE_CERTIFICATE_BINDING")

func _tree_live_certificate_matches() -> bool:
	var certificate: Dictionary = _tree_live_certificate
	if _save_profile != 6 or not ActorState.exact_fields(certificate, ["owner","frame","lease","peer","api","context","roster"]) or not certificate.is_read_only() or not certificate["owner"] is WeakRef or certificate["owner"].get_ref() != self or _bootstrap_frame == null or _bootstrap_frame.get_script() != BootstrapFrame or not is_same(certificate["frame"], _bootstrap_frame) or not is_same(certificate["lease"], _bootstrap_frame._source_lease) or _bootstrap_frame._source_lease == null or _bootstrap_frame._source_lease.bound_save_owner() != self:
		return false
	if not certificate["context"] is Dictionary or not certificate["context"].is_read_only() or not certificate["roster"] is Dictionary or not certificate["roster"].is_read_only() or certificate["context"] != _live_input_context or certificate["context"] != _bootstrap_owner_context() or certificate["roster"] != _live_input_roster or not is_same(certificate["peer"], _peer) or not is_same(certificate["api"], _actor_scene_api): return false
	for binding in certificate["roster"].values():
		if not binding is Dictionary or not binding.is_read_only() or not binding.get("transport") is Dictionary or not binding["transport"].is_read_only(): return false
	if _peer == null or _actor_scene_api == null:
		# Existing no-listener host fixtures have no remote identities to preserve.
		return _peer == null and _actor_scene_api == null and _mode == "host" and _arguments.get("test_entry") == "true" and _arguments.get("tree_fixture_profile") == "isolated" and certificate["roster"].keys() == [1]
	return is_inside_tree() and _owns_scoped_multiplayer() and multiplayer == _actor_scene_api and multiplayer.is_server() and multiplayer.multiplayer_peer == _peer

func _freeze_tree_disconnected_transport(peer_id: int) -> bool:
	if peer_id <= 1 or _tree_disconnect_transports.has(peer_id) or not _tree_live_certificate_matches() or not _live_input_roster.has(peer_id): return false
	if not _bootstrap_frame._source_lease.guard().get("ok", false): return false
	var binding: Dictionary = _tree_live_certificate["roster"][peer_id]
	var frozen: Dictionary = binding["transport"]
	if not ActorState.exact_fields(frozen, ["peer_id","incarnation","transport","api"]) or frozen["peer_id"] != peer_id or frozen["incarnation"] != _bootstrap_transport_incarnations.get(peer_id) or _peer == null or _actor_scene_api == null or frozen["transport"] != _peer.get_instance_id() or frozen["api"] != _actor_scene_api.get_instance_id(): return false
	var profile: Variant = _authority._profiles.get(binding["profile_id"])
	if _authority._peer_profiles.get(peer_id) != binding["profile_id"] or not profile is Dictionary or profile.get("player_instance_id") != binding["actor_id"] or not _actor_model._active.has(binding["actor_id"]) or _actor_model._input_generations.get(binding["actor_id"]) != binding["input_generation"]: return false
	_tree_disconnect_transports[peer_id] = frozen
	_request_live_input_stop()
	return true

func _live_peer_context(peer_id: int) -> Dictionary:
	if _save_profile == 6 and _live_input_cutoff >= 0 and _tree_disconnect_transports.has(peer_id):
		if not _tree_live_certificate_matches() or not _tree_live_certificate["roster"].has(peer_id) or _tree_disconnect_transports[peer_id] != _tree_live_certificate["roster"][peer_id]["transport"]: return {}
		return _tree_disconnect_transports[peer_id].duplicate(true)
	if _save_profile == 5 and _live_input_cutoff >= 0 and _inventory_disconnect_transports.has(peer_id):
		return _inventory_disconnect_transports[peer_id].duplicate(true)
	if peer_id == 1:
		return {"peer_id": 1, "local_host": true} if _mode == "host" else {}
	return _bootstrap_transport_context(peer_id)

func _live_binding_check() -> Dictionary:
	if _save_profile == 6 and not _tree_live_certificate_matches(): return _live_failure("TREE_LIVE_CERTIFICATE_CHANGED")
	if _live_input_context.is_empty() or _bootstrap_frame == null or _bootstrap_frame.get_script() != BootstrapFrame or _bootstrap_frame.get_instance_id() != _live_input_context.get("frame") or _bootstrap_frame._source_lease == null:
		return _live_failure("LIVE_INPUT_OWNER_CHANGED")
	var sources: Dictionary = _bootstrap_frame._source_lease.guard()
	if not sources.get("ok", false) or _live_input_context != _bootstrap_owner_context() or not _physics_runtime_ready:
		return _live_failure("LIVE_INPUT_OWNER_CHANGED")
	# Do not project tentative actor records just to queue an envelope. The Frame
	# performs complete dynamic validation before confirmation or mutation.
	var peers: Dictionary = _authority._peer_profiles
	var active: Dictionary = _actor_model._active
	var generations: Dictionary = _actor_model._input_generations
	if peers.size() != _live_input_roster.size() or active.size() != _live_input_roster.size() or generations.size() != _live_input_roster.size():
		return _live_failure("LIVE_INPUT_ROSTER_CHANGED")
	for peer_id in _live_input_roster:
		var binding: Dictionary = _live_input_roster[peer_id]
		var profile: Variant = _authority._profiles.get(binding["profile_id"])
		var generation: Variant = generations.get(binding["actor_id"])
		if not peers.get(peer_id) is String or peers[peer_id] != binding["profile_id"] or not profile is Dictionary or not profile.get("player_instance_id") is String or profile["player_instance_id"] != binding["actor_id"] or not active.has(binding["actor_id"]) or typeof(generation) != TYPE_INT or generation != binding["input_generation"] or binding["transport"] != _live_peer_context(peer_id):
			return _live_failure("LIVE_INPUT_PEER_BINDING_CHANGED")
	return {"ok": true}

func _queue_live_actor_input(peer_id: int, request: Variant) -> Dictionary:
	if not _live_failure_code.is_empty():
		return _live_failure(_live_failure_code)
	if not _live_input_enabled:
		return {"ok": false, "code": "BOOTSTRAP_INPUT_UNSUPPORTED", "startup_only": true}
	if _closing or _fatal_shutdown or not _startup_ready or _live_input_cutoff >= 0 or _bootstrap_cancel_requested():
		if _bootstrap_cancel_requested():
			_request_live_input_stop()
		return {"ok": false, "queued": false, "code": "ACTOR_SESSION_STOPPING"}
	if not _live_input_roster.has(peer_id):
		return {"ok": false, "queued": false, "code": "ACTOR_PEER_NOT_JOINED"}
	var binding := _live_binding_check()
	if not binding.get("ok", false):
		return binding
	var command_check: Dictionary = _bootstrap_frame._command_check(request)
	if not command_check.get("ok", false):
		return command_check
	var captured := {"peer_id": peer_id, "actor_id": _live_input_roster[peer_id]["actor_id"], "input_generation": _live_input_roster[peer_id]["input_generation"], "server_epoch": _live_input_context["epoch"], "world_id": _live_input_context["world_id"], "request": request.duplicate(true)}
	var bounded: Dictionary = _bootstrap_frame._envelope_check(captured)
	if not bounded.get("ok", false):
		return bounded
	if _live_input_serial >= ActorMotion.MAX_REVISION:
		return _live_failure("LIVE_INPUT_QUEUE_SERIAL_EXHAUSTED")
	var event := {"serial": _live_input_serial + 1, "owner": _live_input_context.duplicate(true), "transport": _live_input_roster[peer_id]["transport"].duplicate(true), "envelope": captured, "bytes": 0}
	var event_bytes := var_to_bytes(event).size()
	if event_bytes > BootstrapFrame.MAX_ENVELOPE_BYTES or _live_input_queue.size() >= BootstrapFrame.MAX_ENVELOPES or _live_input_bytes + event_bytes > BootstrapFrame.MAX_BATCH_BYTES:
		# RPC has no receipt channel: silently dropping a release would leave held
		# intent active. Exhaustion therefore stops this bounded technical session.
		return _live_failure("LIVE_INPUT_QUEUE_FULL")
	event["bytes"] = event_bytes
	_live_input_serial += 1
	_live_input_bytes += event_bytes
	_live_input_queue.append(event)
	return {"ok": false, "queued": true, "accepted": false, "confirmed": false, "code": "LIVE_INPUT_QUEUED"}

func _admit_actor_input(peer_id: int, request: Variant) -> Dictionary:
	var result := _queue_live_actor_input(peer_id, request)
	if result.get("fatal", false):
		_fail(str(result["code"]), "输入队列边界失败，已停止且不保存未确认状态")
	return result

func _request_live_input_stop() -> void:
	if _live_input_enabled and _live_input_cutoff < 0:
		_live_input_cutoff = _live_input_serial
		if _save_profile == 5 and _inventory_live != null: _inventory_live.stop_server()

func _live_failure(code: String, source: Dictionary = {}) -> Dictionary:
	if _live_failure_code.is_empty():
		_live_failure_code = code
	var result := {"ok": false, "fatal": true, "code": _live_failure_code, "retry_allowed": false, "save_ready": false, "delta_disposition": "failed_no_retry"}
	for field in ["main_committed", "save_receipt", "sequence"]:
		if source.has(field):
			result[field] = source[field]
	return result

func live_input_statistics() -> Dictionary:
	return {"enabled": _live_input_enabled, "activated": _live_input_activated, "fixed_roster_count": _live_input_roster.size(), "queued_count": _live_input_queue.size(), "queued_bytes": _live_input_bytes, "pending": not _live_input_ticket.is_empty(), "stopping": _live_input_cutoff >= 0, "close_ready": _live_input_close_ready, "failed": not _live_failure_code.is_empty()}

func _live_ordered_batch() -> Dictionary:
	if _live_input_queue.size() > BootstrapFrame.MAX_ENVELOPES:
		return _live_failure("LIVE_INPUT_QUEUE_ACCOUNTING_CHANGED")
	var batch: Array = []
	var expected_serial: int = _live_input_consumed_serial
	var checked_bytes: int = 0
	for event in _live_input_queue:
		if not event is Dictionary or event.size() != 5 or typeof(event.get("serial")) != TYPE_INT or typeof(event.get("bytes")) != TYPE_INT:
			return _live_failure("LIVE_INPUT_QUEUE_ACCOUNTING_CHANGED")
		var checked: Dictionary = _bootstrap_frame._envelope_check(event.get("envelope"))
		if not checked.get("ok", false):
			return _live_failure("LIVE_INPUT_QUEUED_ENVELOPE_CHANGED")
		var envelope: Dictionary = event["envelope"]
		var peer_id: int = envelope["peer_id"]
		expected_serial += 1
		if event["serial"] != expected_serial or (_live_input_cutoff >= 0 and event["serial"] > _live_input_cutoff) or not TerrainValues._same(event.get("owner"), _live_input_context) or not _live_input_roster.has(peer_id) or not TerrainValues._same(event.get("transport"), _live_peer_context(peer_id)) or envelope["actor_id"] != _live_input_roster[peer_id]["actor_id"] or envelope["input_generation"] != _live_input_roster[peer_id]["input_generation"] or envelope["world_id"] != _live_input_context["world_id"] or envelope["server_epoch"] != _live_input_context["epoch"]:
			return _live_failure("LIVE_INPUT_QUEUED_BINDING_CHANGED")
		var event_bytes := var_to_bytes(event).size()
		if event["bytes"] != event_bytes or event_bytes > BootstrapFrame.MAX_ENVELOPE_BYTES:
			return _live_failure("LIVE_INPUT_QUEUE_ACCOUNTING_CHANGED")
		checked_bytes += event_bytes
		batch.append(envelope)
	if expected_serial != _live_input_serial or checked_bytes != _live_input_bytes or checked_bytes > BootstrapFrame.MAX_BATCH_BYTES:
		return _live_failure("LIVE_INPUT_QUEUE_ACCOUNTING_CHANGED")
	return {"ok": true, "batch": batch, "last_serial": expected_serial}

@rpc("any_peer", "call_remote", "reliable")
func command(_request: Dictionary) -> void:
	if _closing or _fatal_shutdown or _authority == null or not is_inside_tree() or _peer == null or not _owns_scoped_multiplayer() or not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender > 1 and not _bootstrap_transport_context(sender).is_empty():
		command_result.rpc_id(sender, {"ok": false, "code": "BOOTSTRAP_COMMAND_UNSUPPORTED", "startup_only": not _live_input_activated})

func _physics_process(delta: float) -> void:
	if not _live_input_enabled or _closing or _fatal_shutdown:
		return
	var result := _advance_live_input_phase(delta)
	if result.get("fatal", false):
		_fail(str(result["code"]), "人物确认帧失败，已停止且不重跑此步或保存半帧")
	elif result.get("close_ready", false):
		_close_confirmed_bootstrap()

func _queue_owner_fixture_tree_completion(peer_id: int, tree_id: String, event_id: String) -> Dictionary:
	if _save_profile != 6 or _arguments.get("test_entry") != "true" or _arguments.get("tree_fixture_profile") != "isolated" or not _live_input_activated or not _live_input_enabled or not _startup_ready or _closing or _fatal_shutdown or not _live_failure_code.is_empty() or _live_input_cutoff >= 0 or _bootstrap_cancel_requested():
		return {"ok":false, "code":"TREE_OWNER_REQUEST_UNAVAILABLE"}
	if not _owner_tree_request_result_valid(): return _live_failure("TREE_OWNER_REQUEST_RESULT_CHANGED")
	if not _owner_tree_request.is_empty() or not _owner_tree_ticket.is_empty() or _owner_tree_request_result.get("phase") == "admitted": return {"ok":false, "code":"TREE_OWNER_REQUEST_BUSY"}
	var binding := _live_binding_check()
	if not binding.get("ok",false): return binding
	if not _live_input_roster.has(peer_id) or var_to_bytes([tree_id,event_id]).size() > BootstrapFrame.MAX_ENVELOPE_BYTES: return {"ok":false, "code":"TREE_OWNER_REQUEST_INVALID"}
	var context: Dictionary = _live_input_context.duplicate(true)
	context.make_read_only()
	var actor: Dictionary = _live_input_roster[peer_id].duplicate(true)
	actor["transport"].make_read_only()
	actor.make_read_only()
	var request_ticket := RefCounted.new()
	_owner_tree_request = {"ticket":request_ticket, "peer_id":peer_id, "tree_id":tree_id, "event_id":event_id, "context":context, "actor":actor}
	_owner_tree_request.make_read_only()
	_owner_tree_request_result = {}
	return {"ok":false, "queued":true, "admitted":false, "request_ticket":request_ticket, "code":"TREE_OWNER_REQUEST_QUEUED"}

func _owner_tree_request_result_valid() -> bool:
	var result: Dictionary = _owner_tree_request_result
	if result.is_empty(): return true
	if not ActorState.exact_fields(result,["ticket","phase","code","completion_ticket"]) or not result.is_read_only() or not result["ticket"] is RefCounted or not result["phase"] is String or result["phase"] not in ["rejected","admitted","published","rollback_confirmed","replayed"] or not result["code"] is String: return false
	return result["completion_ticket"] is RefCounted if result["phase"] == "admitted" else result["completion_ticket"] == null

func _owner_fixture_tree_request_status(request_ticket: Variant) -> Dictionary:
	if not _owner_tree_request_result_valid(): return _live_failure("TREE_OWNER_REQUEST_RESULT_CHANGED")
	if not request_ticket is RefCounted: return {"ok":false, "code":"TREE_OWNER_REQUEST_UNKNOWN"}
	if not _owner_tree_request.is_empty() and is_same(_owner_tree_request.get("ticket"),request_ticket): return {"ok":true, "queued":true, "admitted":false, "phase":"queued"}
	var result: Dictionary = _owner_tree_request_result
	if result.is_empty() or not is_same(result.get("ticket"),request_ticket): return {"ok":false, "code":"TREE_OWNER_REQUEST_UNKNOWN"}
	return {"ok":true, "queued":false, "admitted":result["phase"] in ["admitted","published","rollback_confirmed","replayed"], "phase":result["phase"], "code":result["code"]}

func _record_owner_tree_request(request_ticket: RefCounted, phase: String, code: String = "", completion_ticket: Variant = null) -> void:
	# Exactly one recent request result, never a persistent or unbounded receipt log.
	_owner_tree_request_result = {"ticket":request_ticket, "phase":phase, "code":code, "completion_ticket":completion_ticket}
	_owner_tree_request_result.make_read_only()

func _admit_owner_tree_request() -> Dictionary:
	if _owner_tree_request.is_empty(): return {"ok":true, "tree_request_idle":true}
	var request: Dictionary = _owner_tree_request
	if not ActorState.exact_fields(request,["ticket","peer_id","tree_id","event_id","context","actor"]) or not request.is_read_only() or not request["ticket"] is RefCounted or typeof(request["peer_id"]) != TYPE_INT or not request["tree_id"] is String or not request["event_id"] is String or not request["context"] is Dictionary or not request["context"].is_read_only() or not request["actor"] is Dictionary or not request["actor"].is_read_only() or request["context"] != _live_input_context or not _live_input_roster.has(request["peer_id"]) or request["actor"] != _live_input_roster[request["peer_id"]]: return _live_failure("TREE_OWNER_REQUEST_CHANGED")
	if not ActorState.exact_fields(request["actor"],["profile_id","actor_id","input_generation","transport"]) or not request["actor"]["transport"] is Dictionary or not request["actor"]["transport"].is_read_only() or not _owner_tree_request_result.is_empty(): return _live_failure("TREE_OWNER_REQUEST_CHANGED")
	if _live_input_cutoff >= 0 or _bootstrap_cancel_requested():
		_record_owner_tree_request(request["ticket"],"rejected","ACTOR_SESSION_STOPPING")
		_owner_tree_request = {}
		return {"ok":true, "tree_request_idle":true, "request_rejected":true}
	var prepared := _prepare_owner_fixture_tree_completion(request["peer_id"],request["tree_id"],request["event_id"])
	if prepared.get("fatal",false): return prepared
	if prepared.get("replay",false):
		_record_owner_tree_request(request["ticket"],"replayed")
	elif prepared.get("ok",false) and prepared.get("pending",false):
		_record_owner_tree_request(request["ticket"],"admitted","",prepared["ticket"])
	else:
		_record_owner_tree_request(request["ticket"],"rejected",str(prepared.get("code","TREE_OWNER_REQUEST_REJECTED")))
	_owner_tree_request = {}
	return {"ok":prepared.get("ok",false), "tree_request_handled":true, "tree_pending":prepared.get("pending",false), "delta_consumed":false, "save_ready":not prepared.get("pending",false)}

func _prepare_owner_fixture_tree_completion(peer_id: int, tree_id: String, event_id: String) -> Dictionary:
	# Internal isolated-fixture seam; no RPC/ordinary input can mint a completion.
	if _save_profile != 6 or _arguments.get("test_entry") != "true" or _arguments.get("tree_fixture_profile") != "isolated" or not _live_input_activated or not _live_input_enabled or not _startup_ready or _closing or _fatal_shutdown or not _live_failure_code.is_empty() or _live_input_cutoff >= 0 or _bootstrap_cancel_requested():
		return {"ok": false, "code": "TREE_OWNER_COMPLETION_UNAVAILABLE"}
	if not _owner_tree_ticket.is_empty() or not _live_input_ticket.is_empty() or _bootstrap_presence_busy:
		return {"ok": false, "pending": true, "code": "TREE_OWNER_CONFIRMED_BOUNDARY_REQUIRED", "delta_consumed": false}
	var binding := _live_binding_check()
	if not binding.get("ok", false): return binding
	if not _live_input_roster.has(peer_id): return {"ok": false, "code": "TREE_OWNER_PEER_NOT_JOINED"}
	var prepared: Dictionary = _bootstrap_frame.prepare_fixture_tree_completion(self, peer_id, tree_id, event_id)
	if prepared.get("fatal", false): return _live_failure(str(prepared.get("code", "TREE_OWNER_PREPARE_FAILED")), prepared)
	if prepared.get("replay", false): return prepared
	if not prepared.get("ok", false): return prepared
	if not prepared.get("ticket") is RefCounted or not prepared.get("pending", false): return _live_failure("TREE_OWNER_PREPARATION_INVALID")
	_owner_tree_ticket = {"frame": _bootstrap_frame, "ticket": prepared["ticket"], "context": _live_input_context.duplicate(true)}
	_owner_tree_ticket.make_read_only()
	return prepared

func _begin_owner_fixture_tree_rollback() -> Dictionary:
	if _owner_tree_ticket.is_empty() or _save_profile != 6 or _bootstrap_frame == null or not is_same(_owner_tree_ticket.get("frame"), _bootstrap_frame):
		return {"ok": false, "code": "TREE_OWNER_NO_PENDING_COMPLETION"}
	var binding := _live_binding_check()
	if not binding.get("ok", false): return binding
	var result: Dictionary = _bootstrap_frame.begin_fixture_tree_rollback(_owner_tree_ticket["ticket"])
	return _live_failure(str(result.get("code", "TREE_OWNER_ROLLBACK_FAILED")), result) if result.get("fatal", false) else result

func _advance_owner_tree_completion() -> Dictionary:
	if not _owner_tree_request_result_valid(): return _live_failure("TREE_OWNER_REQUEST_RESULT_CHANGED")
	if _owner_tree_request_result.get("phase") == "admitted" and (_owner_tree_ticket.is_empty() or not is_same(_owner_tree_request_result["completion_ticket"],_owner_tree_ticket.get("ticket"))): return _live_failure("TREE_OWNER_REQUEST_RESULT_CHANGED")
	if _owner_tree_ticket.is_empty():
		if _save_profile == 6 and _bootstrap_frame != null and not _bootstrap_frame._tree_pending.is_empty(): return _live_failure("TREE_OWNER_TICKET_LOST")
		return {"ok": true, "tree_idle": true}
	if not ActorState.exact_fields(_owner_tree_ticket, ["frame", "ticket", "context"]) or not _owner_tree_ticket.is_read_only() or _save_profile != 6 or _bootstrap_frame == null or _bootstrap_frame.get_script() != BootstrapFrame or not is_same(_owner_tree_ticket["frame"], _bootstrap_frame) or not _owner_tree_ticket["ticket"] is RefCounted or _owner_tree_ticket["context"] != _live_input_context or not _live_input_ticket.is_empty():
		return _live_failure("TREE_OWNER_TICKET_CHANGED")
	var pending: Dictionary = _bootstrap_frame._tree_pending
	if pending.is_empty() or not is_same(pending.get("ticket"), _owner_tree_ticket["ticket"]): return _live_failure("TREE_OWNER_FRAME_TICKET_LOST")
	var result: Dictionary
	if pending.get("phase") == "detached":
		result = _bootstrap_frame.confirm_fixture_tree_completion(_owner_tree_ticket["ticket"])
	elif pending.get("phase") == "restoring":
		result = _bootstrap_frame.confirm_fixture_tree_rollback(_owner_tree_ticket["ticket"])
	else:
		return _live_failure("TREE_OWNER_PHASE_INVALID")
	if result.get("pending", false) and result.get("code") == "TREE_COMPLETION_AWAIT_PHYSICS":
		return {"ok": false, "pending": true, "tree_pending": true, "delta_consumed": false, "save_ready": false}
	if not result.get("ok", false) or not (result.get("published", false) or result.get("rollback_confirmed", false)):
		return _live_failure(str(result.get("code", "TREE_OWNER_CONFIRM_FAILED")), result)
	if _owner_tree_request_result.get("phase") == "admitted":
		if not is_same(_owner_tree_request_result.get("completion_ticket"),_owner_tree_ticket["ticket"]): return _live_failure("TREE_OWNER_REQUEST_RESULT_CHANGED")
		_record_owner_tree_request(_owner_tree_request_result["ticket"],"published" if result.get("published",false) else "rollback_confirmed")
	_owner_tree_ticket = {}
	_bootstrap_public_snapshot = _bootstrap_frame.last_confirmed_snapshot()
	_sync_server_nodes()
	# Do not charge this physics delta or submit another operation in this call.
	# Queued actor envelopes and the frozen cutoff survive until the next frame.
	return {"ok": true, "tree_completed": true, "published": result.get("published", false), "rollback_confirmed": result.get("rollback_confirmed", false), "delta_consumed": false, "save_ready": true}

func _advance_live_input_phase(delta: float) -> Dictionary:
	# Internal synchronous composition seam. Its caller must terminate on fatal;
	# the sticky failure closes every input/public/save gate even before dispatch.
	if not _live_failure_code.is_empty():
		return _live_failure(_live_failure_code)
	var owner_check := _ordinary_owner_check()
	if not owner_check.get("ok", false):
		return owner_check
	if not _live_input_enabled or _closing or _fatal_shutdown or not _startup_ready:
		return {"ok": false, "code": "LIVE_INPUT_NOT_ACTIVE", "delta_consumed": false}
	if _live_input_close_ready:
		return {"ok": false, "code": "LIVE_INPUT_CLOSE_ALREADY_PREPARED", "delta_consumed": false}
	var frame := Engine.get_physics_frames()
	if frame <= _last_actor_physics_frame:
		return {"ok": false, "code": "LIVE_INPUT_ALREADY_ADVANCED", "delta_consumed": false}
	_last_actor_physics_frame = frame
	if _bootstrap_cancel_requested():
		_request_live_input_stop()
	var binding := _live_binding_check()
	if not binding.get("ok", false):
		return binding
	var tree_phase := _advance_owner_tree_completion()
	if not tree_phase.get("tree_idle", false): return tree_phase
	var ordered := _live_ordered_batch()
	if not ordered.get("ok", false):
		return ordered
	var confirmed_previous: bool = false
	var confirmed_interactions: Array = []
	if not _live_input_ticket.is_empty():
		var confirmed: Dictionary = _bootstrap_frame.confirm(_live_input_ticket)
		if not confirmed.get("ok", false) or not confirmed.get("confirmed", false):
			return _live_failure(str(confirmed.get("code", "LIVE_INPUT_CONFIRMATION_FAILED")))
		_live_input_ticket.clear()
		confirmed_previous = true
		confirmed_interactions = confirmed.get("interactions", []).duplicate(true)
		_actor_snapshot_elapsed += _live_input_pending_delta
		_live_input_pending_delta = 0.0
	# Inventory is synchronous at the same confirmed boundary, after Actor
	# confirmation and before any save or new Actor submission.
	if _save_profile in [5,6]:
		if _inventory_owner.has_ground_component():
			var ground_advanced: Dictionary = _bootstrap_frame.advance_confirmed_ground(self)
			if not ground_advanced.get("ok", false): return _live_failure(str(ground_advanced.get("code", "GROUND_ADVANCE_FAILED")))
		if _save_profile == 5:
			var drained := _drain_inventory_confirmed()
			if not drained.get("ok", false): return _live_failure(str(drained.get("code", "INVENTORY_DRAIN_FAILED")))
	var requested := _admit_owner_tree_request()
	if not requested.get("tree_request_idle",false): return requested
	# Both stop and automatic saves occur only here, before any new submission.
	if _live_input_cutoff >= 0 and _live_input_queue.is_empty():
		if _live_input_consumed_serial != _live_input_cutoff:
			return _live_failure("LIVE_INPUT_STOP_CUTOFF_MISMATCH")
		var saved := _commit_confirmed_save("normal_shutdown")
		if not saved.get("ok", false):
			return _live_failure(str(saved.get("code", "LIVE_INPUT_STOP_SAVE_FAILED")), saved)
		_live_input_close_ready = true
		return {"ok": true, "close_ready": true, "pending": false, "save_ready": true, "confirmed_previous": confirmed_previous, "confirmed_interactions": confirmed_interactions, "delta_consumed": false}
	if _authority.automatic_save_due():
		var saved := _commit_confirmed_save("automatic", true)
		if not saved.get("ok", false):
			return _live_failure(str(saved.get("code", "LIVE_INPUT_AUTOMATIC_SAVE_FAILED")), saved)
	if confirmed_previous:
		_bootstrap_public_snapshot = _bootstrap_frame.last_confirmed_snapshot()
		_sync_server_nodes()
		if _actor_snapshot_elapsed >= ACTOR_SNAPSHOT_INTERVAL:
			_actor_snapshot_elapsed = 0.0
			_broadcast_snapshot()
	var submitted: Dictionary = _bootstrap_frame.submit(delta, ordered["batch"])
	if not submitted.get("pending", false) or not submitted.get("sealed", false) or not submitted.get("delta_consumed", false) or not submitted.get("ticket") is Dictionary:
		return _live_failure(str(submitted.get("code", "LIVE_INPUT_SUBMIT_FAILED")))
	_live_input_ticket = submitted["ticket"].duplicate(true)
	_live_input_pending_delta = delta
	_live_input_consumed_serial = ordered["last_serial"]
	_live_input_queue.clear()
	_live_input_bytes = 0
	_actor_physics_steps += 1
	return {"ok": false, "pending": true, "sealed": true, "delta_consumed": true, "confirmed_previous": confirmed_previous, "confirmed_interactions": confirmed_interactions}

func _advance_authority(_delta: float) -> bool:
	return not _closing and not _fatal_shutdown and _physics_runtime_ready

func _process(delta: float) -> void:
	if _mode == "client" and _authority == null:
		super._process(delta)
		return
	if _closing or _fatal_shutdown:
		return
	if not _ordinary_owner_check().get("ok", false):
		_fail(_live_failure_code, "本机会话所有者已失联，保留最近完整存档")
		return
	_poll_ordinary_startup_peers()
	_elapsed += delta
	var session_limit: float = _session_time_limit_seconds()
	if session_limit > 0.0 and _elapsed > session_limit:
		_fail("TEST_TIMEOUT", "技术运行入口超过限定窗口")
		return
	if _authority != null:
		_reap_unaccepted_connections()
	if _closing or _fatal_shutdown:
		return
	if _bootstrap_cancel_requested():
		if _live_input_enabled:
			_request_live_input_stop()
			return # The physics owner drains the cutoff and confirms before save.
		if _bootstrap_presence_busy:
			return # Confirm + exact save is still owned by the suspended join.
		if not _startup_ready:
			_cancel_bootstrap()
			return
		if not _save_world("normal_shutdown"):
			return
		_close_confirmed_bootstrap()
		return
	if not _startup_ready:
		return
	await _drain_bootstrap_hello()
	if _closing or _fatal_shutdown:
		return
	_report_elapsed += delta
	if _report_elapsed >= 0.1:
		_report_elapsed = 0.0
		_write_report(_server_report())

func _close_confirmed_bootstrap() -> void:
	_closing = true
	_write_report({"status": "normal_shutdown", "saved": true, "mode": _mode, "last_save": _last_save_summary.duplicate(true), "disconnect_saved": not _inventory_disconnect_transports.is_empty() or not _tree_disconnect_transports.is_empty()})
	if _save_store != null:
		_save_store.close()
	if _peer != null:
		_peer.close()
	_cleanup_runtime()
	_quit_session(0)

func _bootstrap_save_receipt_summary() -> Dictionary:
	var summary := {"sequence": _bootstrap_last_save_receipt.get("sequence", -1), "main_committed": _bootstrap_last_save_receipt.get("main_committed", false), "complete": _bootstrap_last_save_receipt.get("complete", false)}
	# Preserve the actual Frame receipt hash for schema5 disk inspection.
	# Legacy4 keeps its exact three-field report shape.
	if _save_profile == 5: summary["state_sha256"] = _bootstrap_last_save_receipt.get("state_sha256", "")
	return summary

func _save_world(reason: String, advance_auto: bool = false) -> bool:
	if _fatal_shutdown or not _live_failure_code.is_empty():
		return false
	var result := _commit_confirmed_save(reason, advance_auto)
	if not result.get("ok", false):
		_fail(str(result.get("code", "BOOTSTRAP_SAVE_FAILED")), "真实确认存档未完成，已停止；保留实际主存档提交事实")
		return false
	return true

func _commit_confirmed_save(reason: String, advance_auto: bool = false) -> Dictionary:
	# Shared actual save, not an externally supplied acknowledgment. The caller
	# dispatches any failed result to the existing terminal owner lifecycle.
	if _fatal_shutdown or not _live_failure_code.is_empty():
		return {"ok": false, "fatal": true, "code": "LIVE_INPUT_SAVE_CLOSED"}
	var owner_check := _ordinary_owner_check(true)
	if not owner_check.get("ok", false):
		return owner_check
	if not _owner_tree_request.is_empty() or not _owner_tree_ticket.is_empty() or (_save_profile == 6 and _bootstrap_frame != null and _bootstrap_frame.get_script() == BootstrapFrame and not _bootstrap_frame._tree_pending.is_empty()):
		return {"ok": false, "pending": true, "code": "TREE_OWNER_SAVE_PENDING", "save_ready": false}
	if _live_input_activated and reason == "normal_shutdown" and (_live_input_cutoff < 0 or not _live_input_queue.is_empty() or not _live_input_ticket.is_empty() or _live_input_consumed_serial != _live_input_cutoff):
		return {"ok": false, "code": "LIVE_INPUT_STOP_NOT_DRAINED", "save_ready": false}
	if _bootstrap_frame == null or _bootstrap_frame.get_script() != BootstrapFrame:
		return {"ok": false, "fatal": true, "code": "BOOTSTRAP_CONFIRMED_FRAME_REQUIRED"}
	if _save_profile == 5 and _live_input_activated:
		if _inventory_live == null or not _inventory_live.server_drained():
			return {"ok": false, "code": "INVENTORY_SAVE_NOT_DRAINED", "save_ready": false}
		if reason == "normal_shutdown" and not _inventory_live._stopping:
			return {"ok": false, "code": "INVENTORY_STOP_NOT_FROZEN", "save_ready": false}
	var result: Dictionary = _bootstrap_frame.save_confirmed_owner(reason, advance_auto)
	_bootstrap_last_save_receipt = result.get("save_receipt", {}).duplicate(true)
	_last_save_summary = {"reason": reason, "ok": result.get("ok", false), "sequence": result.get("sequence", _bootstrap_last_save_receipt.get("sequence", -1)), "code": result.get("code", ""), "main_committed": result.get("main_committed", false), "save_receipt": _bootstrap_save_receipt_summary()}
	if result.get("ok", false):
		_bootstrap_public_snapshot = _bootstrap_frame.last_confirmed_snapshot()
	return result

func _public_snapshot() -> Dictionary:
	if _fatal_shutdown or not _live_failure_code.is_empty() or _bootstrap_public_snapshot.is_empty() or _terrain_public.is_empty():
		return {}
	var result: Dictionary = _bootstrap_public_snapshot.duplicate(true)
	result["terrain_public"] = _terrain_public.duplicate(true)
	return result

func _sync_server_nodes() -> void:
	if _closing or _fatal_shutdown or not _live_failure_code.is_empty() or _bootstrap_public_snapshot.is_empty():
		return
	if _players_root != null:
		_reconcile_nodes(_bootstrap_public_snapshot.get("players", {}))
	if _world_view != null:
		_world_view.consume(_bootstrap_public_snapshot["world_component"], _mode)

func _broadcast_snapshot() -> void:
	if not _tree_disconnect_transports.is_empty(): return
	if not _owner_tree_ticket.is_empty(): return
	if not _inventory_disconnect_transports.is_empty(): return # No old-roster data to a recycled transport.
	if _bootstrap_presence_busy or not _live_failure_code.is_empty() or not _live_input_ticket.is_empty() or _bootstrap_public_snapshot.is_empty():
		return
	super._broadcast_snapshot()
	_broadcast_inventory_sync012()

func _cleanup_runtime() -> void:
	_owner_tree_request = {}
	_owner_tree_request_result = {}
	_tree_disconnect_transports.clear()
	_tree_live_certificate = {}
	_owner_tree_ticket = {}
	_inventory_disconnect_transports.clear()
	_ordinary_handshake_deadlines.clear()
	_ordinary_startup_peers.clear()
	if _inventory_live != null: _inventory_live.close()
	_terrain_baseline_queued.clear()
	_terrain_public.clear()
	_bootstrap_activation = {}
	_live_input_enabled = false
	_live_input_queue.clear()
	_live_input_bytes = 0
	_live_input_ticket.clear()
	_live_input_context.clear()
	_live_input_roster.clear()
	_bootstrap_hello_queue.clear()
	_bootstrap_hello_connections.clear()
	_bootstrap_transport_incarnations.clear()
	_bootstrap_hello_bytes = 0
	_bootstrap_hello_draining = false
	_bootstrap_presence_busy = false
	_bootstrap_presence_peer = 0
	if _bootstrap_frame != null and _bootstrap_frame.get_script() == BootstrapFrame and _bootstrap_frame._source_lease != null:
		_bootstrap_frame._source_lease.release()
	_bootstrap_frame = null
	super._cleanup_runtime()

func _inventory_identity_for(peer_id: int) -> Dictionary:
	# The packet never chooses a profile or actor. Resolve the authenticated peer
	# through the fixed confirmed roster and cross-check actual active authority.
	if not _inventory_service_ready() or not _live_input_roster.has(peer_id): return {}
	var row: Dictionary = _live_input_roster[peer_id]
	if _authority._peer_profiles.get(peer_id) != row["profile_id"] or _authority._profiles.get(row["profile_id"], {}).get("player_instance_id") != row["actor_id"] or not _actor_model._active.has(row["actor_id"]) or _actor_model._input_generations.get(row["actor_id"]) != row["input_generation"]: return {}
	return {"world_id": _authority.world_id, "server_epoch": _authority.server_epoch, "player_profile_id": row["profile_id"], "player_instance_id": row["actor_id"], "peer_id": peer_id, "input_generation": row["input_generation"]}

func _bind_inventory_live_roster() -> Dictionary:
	if _inventory_live != null or not _inventory_service_ready(): return InventoryLive.bad("INVENTORY_LIVE_BINDING")
	_inventory_live = InventoryLive.new()
	for peer_id in _live_input_roster:
		var identity := _inventory_identity_for(peer_id)
		if identity.is_empty(): return InventoryLive.bad("INVENTORY_LIVE_IDENTITY")
		var view: Dictionary = _inventory_owner.view_for(identity["player_profile_id"], 0)
		if view.is_empty(): return InventoryLive.bad("INVENTORY_LIVE_PRIVATE_VIEW")
		var bound: Dictionary = _inventory_live.bind_server(identity, _live_peer_context(peer_id), view["inventory"]["last_sequence"], view["revision"])
		if not bound["ok"]: return bound
	return {"ok": true}

func _receive_inventory_request012(sender: int, request: Variant) -> Dictionary:
	if _save_profile != 5 or _inventory_live == null or not _live_input_enabled or not _startup_ready or _closing or _fatal_shutdown or _live_input_cutoff >= 0 or _bootstrap_cancel_requested(): return InventoryLive.bad("INVENTORY_STREAM_CLOSED")
	var checked := _live_binding_check()
	if checked.get("ok", false):
		checked = _inventory_live.admit_server(sender, request, _inventory_identity_for(sender), _live_peer_context(sender))
	if checked.get("fatal", false) or checked.get("code") in ["INVENTORY_QUEUE_BUDGET", "INVENTORY_CONTROL_BUDGET"]:
		_fail(str(checked.get("code", "INVENTORY_ADMISSION_FAILED")), "背包请求队列失败，已停止且不重试")
	return checked

func _drain_inventory_confirmed() -> Dictionary:
	if not _inventory_service_ready() or _inventory_live == null or not _live_input_ticket.is_empty() or _bootstrap_frame == null: return InventoryLive.bad("INVENTORY_CONFIRMED_BOUNDARY_REQUIRED")
	if _inventory_live.head_server().is_empty(): return {"ok": _inventory_live.server_drained(), "code": "INVENTORY_QUEUE_ACCOUNTING"}
	if not _bootstrap_frame.status().get("save_ready", false): return InventoryLive.bad("INVENTORY_CONFIRMED_BOUNDARY_REQUIRED")
	for _index in range(InventoryLive.MAX_QUEUE):
		var event: Dictionary = _inventory_live.head_server()
		if event.is_empty(): return {"ok": _inventory_live.server_drained(), "code": "INVENTORY_QUEUE_ACCOUNTING"}
		var peer_id: int = event["peer"]
		var checked: Dictionary = _inventory_live.validate_head_server(_inventory_identity_for(peer_id), _live_peer_context(peer_id))
		if not checked["ok"]: return checked
		var request: Dictionary = event["request"]
		var profile: String = _inventory_identity_for(peer_id)["player_profile_id"]
		var result := {"ok": true}
		if request["kind"] == "left": result = _inventory_apply_confirmed_left(profile, request["address"], request["expected_revision"], request["sequence"])
		elif request["kind"] == "drop": result = _bootstrap_frame.apply_confirmed_inventory_drop(self, profile, request["drop_kind"], request["address"], request["expected_revision"], request["sequence"], ActorState.vector(request["aim"]))
		elif request["kind"] == "close": result = _inventory_owner.close_view(profile)
		if result.get("fatal", false): return result
		var view: Dictionary = _inventory_owner.view_for(profile, _inventory_live.next_view_sequence(peer_id))
		var completed: Dictionary = _inventory_live.complete_server(result, view)
		if not completed["ok"]: return completed
		# Never broadcast an inventory component or another player's projection.
		if not _inventory_disconnect_transports.has(peer_id):
			if rpc_id(peer_id, &"inventory_reply012", completed["reply"]) != OK: return InventoryLive.bad("INVENTORY_PRIVATE_SEND_FAILED")
	return {"ok": _inventory_live.server_drained(), "code": "INVENTORY_QUEUE_ACCOUNTING"}

func inventory_close_proof(peer_id: int) -> Dictionary:
	if _save_profile != 5 or _inventory_live == null or not _inventory_service_ready(): return {}
	var identity := _inventory_identity_for(peer_id)
	if identity.is_empty() or not _inventory_live._streams.has(peer_id) or identity != _inventory_live._streams[peer_id]["identity"] or _live_peer_context(peer_id) != _inventory_live._streams[peer_id]["transport"]: return {}
	return _inventory_live.server_proof(peer_id, _inventory_owner.view_for(identity["player_profile_id"], 0))

func inventory_live_statistics() -> Dictionary:
	var proofs: Array = []
	if _save_profile == 5 and _inventory_live != null:
		for peer_id in _live_input_roster: proofs.append(inventory_close_proof(peer_id))
	return {"contract": InventoryLive.CONTRACT, "queue_empty": _inventory_live != null and _inventory_live.server_drained(), "queued_count": _inventory_live._queue.size() if _inventory_live != null else 0, "close_proofs": proofs}

func _broadcast_inventory_sync012() -> void:
	if _save_profile != 5 or _inventory_live == null or _inventory_live._stopping or not _inventory_disconnect_transports.is_empty() or not _live_failure_code.is_empty(): return
	var component: Dictionary = _inventory_owner.snapshot()
	for peer_id in _live_input_roster:
		if peer_id == 1: continue
		var identity: Dictionary = _inventory_identity_for(peer_id)
		if identity.is_empty() or _live_peer_context(peer_id) != _live_input_roster[peer_id]["transport"]: continue
		var profile: String = identity["player_profile_id"]
		var actor_id: String = identity["player_instance_id"]
		var actor: Dictionary = _actor_model.persistent_state()["actors"][actor_id]
		var records: Array = []
		for id in component.get("ground", {}):
			var record: Dictionary = component["ground"][id]
			if record["layer"] == actor["layer"]:
				records.append({"id": id, "position": record["position"].duplicate(), "content_id": record["stack"]["content_id"], "quantity": record["stack"]["quantity"]})
		var sync: Dictionary = _inventory_live.sync_server(peer_id, _inventory_owner.view_for(profile, _inventory_live.next_view_sequence(peer_id)))
		if not sync.get("ok", false): continue
		var packet: Dictionary = {"schema_version": 1, "contract": "inventory012-private-ground-sync-v1", "identity": identity, "view": sync["view"], "layer": actor["layer"].duplicate(true), "world_seconds": _authority.world_seconds, "ground": records}
		if rpc_id(peer_id, &"inventory_sync012", packet) != OK:
			_fail("INVENTORY_SYNC_SEND_FAILED", "背包同步传输失败，保留最近完整存档")
			return
