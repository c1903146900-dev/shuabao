extends Node
## Localhost integration entry for authority and save foundation. No movement or inventory.

const RuntimePaths = preload("res://scripts/network/runtime_paths.gd")

var _mode := ""
var _arguments: Dictionary = {}
var _peer: ENetMultiplayerPeer
var _authority: SandboxServerAuthority
var _catalogue := SandboxContentCatalogue.new()
var _settings: Dictionary = {}
var _save_settings: Dictionary = {}
var _save_store: SandboxSaveStore
var _save_directory := ""
var _load_summary: Dictionary = {}
var _last_save_summary: Dictionary = {}
var _rename_to := ""
var _rename_verified: bool = false
var _stop_requested: bool = false
var _players_root: Node2D
var _report_path := ""
var _stop_path := ""
var _resume_path := ""
var _expected_players: int = 1
var _elapsed: float = 0.0
var _report_elapsed: float = 0.0
var _welcome: Dictionary = {}
var _hello_request: Dictionary = {}
var _snapshot: Dictionary = {}
var _duplicate_verified: bool = false
var _denial_verified: bool = false
var _reported_ready: bool = false
var _exercise: bool = false
var _closing: bool = false
var _startup_ready: bool = false
var _fatal_shutdown: bool = false
var _noncooperative_rejection: String = ""
var _pending_handshakes: Dictionary = {}
var _pending_disconnects: Dictionary = {}
var _forced_disconnect_count: int = 0
const HANDSHAKE_TIMEOUT_SECONDS := 5.0
const REJECTION_FLUSH_SECONDS := 0.25

func _ready() -> void:
	get_tree().auto_accept_quit = false
	for argument in _launch_user_arguments():
		if not argument.begins_with("--") or not argument.contains("="):
			_fail("INVALID_ARGUMENT", "Only --key=value arguments supported")
			return
		var parts := argument.trim_prefix("--").split("=", true, 1)
		_arguments[parts[0]] = parts[1]
	_mode = _arguments.get("mode", "")
	if _mode not in ["server", "host", "client"]:
		_fail("INVALID_MODE", "Mode must be server, host or client")
		return
	var port_text: String = _arguments.get("port", "")
	if not port_text.is_valid_int() or int(port_text) < 1 or int(port_text) > 65535:
		_fail("INVALID_PORT", "Explicit valid localhost test port required")
		return
	_report_path = _runtime_path(_arguments.get("report", ""))
	_stop_path = _runtime_path(_arguments.get("stop", ""))
	_resume_path = _runtime_path(_arguments.get("resume", ""))
	_save_directory = _runtime_path(_arguments.get("save_dir", ""))
	_rename_to = _arguments.get("rename_to", "")
	if _arguments.has("save_dir") and (_save_directory.is_empty() or (_mode == "host" and _resume_path.is_empty())):
		_fail("INVALID_SAVE_PATH", "Persistent Host requires a scoped world directory and private local identity path")
		return
	if _report_path.is_empty() or _stop_path.is_empty():
		_fail("INVALID_PATH", "Integration files must remain in this project runtime directory")
		return
	_expected_players = int(_arguments.get("expected_players", "1"))
	_exercise = _arguments.get("exercise", "false") == "true"
	if _catalogue.load_file() != OK:
		_fail("CATALOGUE_ERROR", _catalogue.last_error)
		return
	var settings: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/network_settings.json"))
	if not settings is Dictionary or settings.get("project") != "shaheyouxi_experiment_20261004" or settings.get("source_sha256") != _catalogue.source_sha256:
		_fail("SETTINGS_ERROR", "Network settings source does not match catalogue")
		return
	_settings = settings
	var save_settings: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/save_settings.json"))
	if not save_settings is Dictionary or save_settings.get("source_sha256") != _catalogue.source_sha256:
		_fail("SAVE_SETTINGS_ERROR", "Save parameters do not match numeric authority")
		return
	_save_settings = save_settings
	if not _prepare_session():
		return
	_players_root = Node2D.new()
	_players_root.name = "Players"
	add_child(_players_root)
	_peer = ENetMultiplayerPeer.new()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if _mode in ["server", "host"]:
		var save_initial := false
		_authority = SandboxServerAuthority.new(int(_settings["max_players"]), int(_settings["network_protocol_version"]), _catalogue.source_sha256, float(_save_settings["automatic_interval_seconds"]))
		if not _save_directory.is_empty():
			_save_store = _make_save_store()
			if _save_store == null:
				_fail("SAVE_FACTORY_FAILED", "存档配置未通过，未读取或写入世界")
				return
			var acquired := _save_store.acquire()
			if not acquired.get("ok", false):
				_fail(acquired.get("code", "SAVE_LOCK_FAILED"), acquired.get("message", "Could not acquire save writer"))
				return
			var loaded := _save_store.load_latest()
			if not loaded.get("ok", false):
				_fail(loaded.get("code", "LOAD_FAILED"), loaded.get("message", "Could not load world"))
				return
			if not loaded.get("new_world", false):
				var restored := _restore_authority_state(loaded["state"])
				if not restored.get("ok", false):
					_fail("RESTORE_FAILED", restored.get("message", "Invalid saved world"))
					return
				var profile_summary: Dictionary = {}
				for profile_id in loaded["state"]["profiles"]:
					var profile: Dictionary = loaded["state"]["profiles"][profile_id]
					profile_summary[profile_id] = {"player_instance_id": profile["player_instance_id"], "display_name": profile["display_name"], "role": profile["role"]}
				_load_summary = {"loaded_from": loaded["loaded_from"], "world_id": _authority.world_id, "world_seconds": _authority.world_seconds, "profiles": profile_summary, "next_auto_due_world_seconds": _authority.next_auto_due_world_seconds, "forced_disconnect_count": _forced_disconnect_count, "transport_peer_count": multiplayer.get_peers().size(), "pending_handshake_count": _pending_handshakes.size(), "pending_disconnect_count": _pending_disconnects.size()}
			else:
				_load_summary = {"loaded_from": "new", "world_id": _authority.world_id}
				if not _create_new_world():
					return
				save_initial = true
		if not await _prepare_authority_runtime(save_initial):
			return
		_peer.set_bind_ip("127.0.0.1")
		var error := _peer.create_server(int(port_text), int(_settings["max_players"]))
		if error != OK:
			_fail("SERVER_START_FAILED", "ENet bind failed: %s" % error_string(error))
			return
		multiplayer.multiplayer_peer = _peer
		if _mode == "host":
			if _save_store != null and _load_summary.get("loaded_from") != "new":
				var stored_profiles: Dictionary = _load_summary.get("profiles", {})
				var existing_host: bool = false
				for profile in stored_profiles.values():
					existing_host = existing_host or profile.get("role") == "HOST"
				if existing_host and not FileAccess.file_exists(_resume_path):
					_fail("HOST_IDENTITY_REQUIRED", "此世界已有房主档案，请恢复本机游戏身份或走授权重绑")
					return
			var host_request := _base_hello("本机房主")
			if not _apply_local_identity(host_request):
				return
			var known_profiles: Dictionary = _load_summary.get("profiles", {})
			if known_profiles.has(host_request["resume_profile_id"]):
				var known: Dictionary = known_profiles[host_request["resume_profile_id"]]
				if known["role"] != "HOST":
					_fail("HOST_ROLE_MISMATCH", "不能将已有普通档案静默提升为房主")
					return
				host_request["display_name"] = known["display_name"]
			var checked_host: Dictionary = _validate_remote_hello(host_request)
			var result: Dictionary = checked_host
			if checked_host.get("ok", false):
				result = await _join_authority_peer_async(1, checked_host["request"], true)
			if _closing:
				return
			if not result.get("ok", false):
				_fail("HOST_JOIN_FAILED", "Host failed shared identity validation")
				return
			if not _write_local_identity(result):
				return
		_sync_server_nodes()
		_write_report(_server_report())
	else:
		var error := _peer.create_client("127.0.0.1", int(port_text))
		if error != OK:
			_fail("CLIENT_START_FAILED", error_string(error))
			return
		multiplayer.multiplayer_peer = _peer

	_startup_ready = true

func _process(delta: float) -> void:
	if _closing:
		return
	_elapsed += delta
	var session_limit: float = _session_time_limit_seconds()
	if session_limit > 0.0 and _elapsed > session_limit:
		_fail("TEST_TIMEOUT", "Integration process exceeded its bounded test window")
		return
	if not _startup_ready:
		if _bootstrap_cancel_requested():
			_cancel_bootstrap()
		return
	if _stop_requested or (not _stop_path.is_empty() and FileAccess.file_exists(_stop_path)):
		_closing = true
		if _save_store != null:
			if not _save_world("normal_shutdown"):
				return
			_write_report(_server_report())
			_save_store.close()
		if _peer != null:
			_peer.close()
		_cleanup_runtime()
		_quit_session(0)
		return
	if _authority != null:
		_reap_unaccepted_connections()
		if not _advance_authority(delta):
			return
		if _save_store != null and _authority.automatic_save_due():
			if not _save_world("automatic", true):
				return
		_report_elapsed += delta
		if _report_elapsed >= 0.1:
			_report_elapsed = 0.0
			_write_report(_server_report())

func _on_connected() -> void:
	if _arguments.get("skip_hello", "false") == "true":
		return
	_hello_request = _base_hello(_arguments.get("name", "同名测试玩家"))
	if _arguments.has("protocol"):
		_hello_request["network_protocol_version"] = int(_arguments["protocol"])
	if not _apply_local_identity(_hello_request):
		return
	hello.rpc_id(1, _hello_request)

func _base_hello(display_name: String) -> Dictionary:
	return {"network_protocol_version": int(_settings["network_protocol_version"]), "catalogue_sha256": _catalogue.source_sha256, "display_name": display_name, "resume_profile_id": "", "resume_secret": ""}

@rpc("any_peer", "call_remote", "reliable")
func hello(request: Dictionary) -> void:
	if _authority == null or not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if _pending_disconnects.has(sender):
		return
	# Capture once before an opt-in owner can suspend. Never rediscover an RPC
	# sender after awaiting a native confirmation or persistence boundary.
	await _handle_remote_hello(sender, request)

func _handle_remote_hello(sender: int, request: Dictionary) -> void:
	var checked: Dictionary = _validate_remote_hello(request)
	var result: Dictionary = checked
	if checked.get("ok", false):
		result = await _join_authority_peer_async(sender, checked["request"], false)
	if _closing:
		return
	_complete_remote_hello(sender, result)

func _complete_remote_hello(sender: int, result: Dictionary) -> void:
	welcome.rpc_id(sender, result)
	_pending_handshakes.erase(sender)
	if not result.get("ok", false):
		_pending_disconnects[sender] = _elapsed + REJECTION_FLUSH_SECONDS
	if result.get("ok", false):
		_sync_server_nodes()
		_broadcast_snapshot()

@rpc("authority", "call_remote", "reliable")
func welcome(result: Dictionary) -> void:
	if _authority != null:
		return
	if not result.get("ok", false):
		_write_report({"status": "rejected", "code": result.get("code"), "message": result.get("message"), "spawned_nodes": _players_root.get_child_count()})
		if _arguments.get("ignore_rejection", "false") == "true":
			_noncooperative_rejection = str(result.get("code", ""))
			return # Test client remains connected; only the server may end this connection.
		_closing = true
		_peer.close()
		get_tree().quit(0 if _arguments.get("expect_rejection", "false") == "true" else 1)
		return
	if not _welcome.is_empty():
		_duplicate_verified = result["player_profile_id"] == _welcome["player_profile_id"] and result["player_instance_id"] == _welcome["player_instance_id"]
		if not _duplicate_verified:
			_fail("DUPLICATE_IDENTITY", "Repeated join changed identity")
			return
	else:
		_welcome = result.duplicate(true)
		if not _write_local_identity(result):
			return
		if _exercise:
			hello.rpc_id(1, _hello_request)
			command.rpc_id(1, {"kind": "set_player", "command_id": 1, "role": "HOST", "player_profile_id": "forged"})
		if not _rename_to.is_empty():
			command.rpc_id(1, {"kind": "set_display_name", "command_id": 2, "display_name": _rename_to})
	_maybe_report_client_ready()

@rpc("any_peer", "call_remote", "reliable")
func command(request: Dictionary) -> void:
	if _authority == null or not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var result := _authority.handle_command(sender, request, _public_snapshot())
	command_result.rpc_id(sender, result)
	if result.get("ok", false) and result.get("kind") == "set_display_name":
		_broadcast_snapshot()

@rpc("authority", "call_remote", "reliable")
func command_result(result: Dictionary) -> void:
	if _authority != null:
		return
	if result.get("code") == "AUTHORITY_REQUIRED":
		_denial_verified = true
	if result.get("ok", false) and result.get("kind") == "set_display_name" and result.get("display_name") == _rename_to:
		_rename_verified = true
	_maybe_report_client_ready()

@rpc("authority", "call_remote", "reliable")
func state_snapshot(snapshot: Dictionary) -> void:
	if _authority != null:
		return
	if not _client_accept_snapshot(snapshot):
		return
	_snapshot = snapshot.duplicate(true)
	_reconcile_nodes(snapshot.get("players", {}))
	_after_client_snapshot(snapshot)
	_maybe_report_client_ready()

func _broadcast_snapshot() -> void:
	var snapshot := _public_snapshot()
	for peer_id in _authority.active_peer_ids():
		if peer_id != 1:
			state_snapshot.rpc_id(peer_id, snapshot)

func _sync_server_nodes() -> void:
	_reconcile_nodes(_public_snapshot()["players"])

func _reconcile_nodes(players: Dictionary) -> void:
	for child in _players_root.get_children():
		if not players.has(str(child.name)):
			_players_root.remove_child(child)
			child.queue_free()
	for profile_id in players:
		if not _players_root.has_node(NodePath(profile_id)):
			var player := Node2D.new()
			player.name = profile_id
			player.set_meta("player_profile_id", profile_id)
			player.set_meta("player_instance_id", players[profile_id]["player_instance_id"])
			player.set_meta("spawn_origin", "server_authoritative_snapshot")
			_players_root.add_child(player)

func _maybe_report_client_ready() -> void:
	if _welcome.is_empty() or _snapshot.is_empty():
		return
	if _exercise and (not _duplicate_verified or not _denial_verified):
		return
	var players: Dictionary = _snapshot.get("players", {})
	if not players.has(_welcome["player_profile_id"]):
		return
	if not _rename_to.is_empty() and (not _rename_verified or players[_welcome["player_profile_id"]]["display_name"] != _rename_to):
		return
	_reported_ready = true
	_write_report({"status": "client_ready" if players.size() >= _expected_players else "client_waiting_for_players", "peer_id": multiplayer.get_unique_id(), "player_profile_id": _welcome["player_profile_id"], "player_instance_id": _welcome["player_instance_id"], "duplicate_join_verified": _duplicate_verified, "authority_rejection_verified": _denial_verified, "snapshot": _snapshot, "spawned_nodes": _players_root.get_child_count()})

func _on_peer_disconnected(peer_id: int) -> void:
	_pending_handshakes.erase(peer_id)
	_pending_disconnects.erase(peer_id)
	if _closing:
		return
	if _authority != null:
		if not _disconnect_authority_peer(peer_id):
			return
		if _save_store != null and _authority.active_peer_ids().is_empty():
			if not _save_world("last_player_left"):
				return
		_sync_server_nodes()
		_broadcast_snapshot()


func _on_peer_connected(peer_id: int) -> void:
	if _authority != null:
		_pending_handshakes[peer_id] = _elapsed + HANDSHAKE_TIMEOUT_SECONDS

func _handshake_deadline_reached(peer_id: int) -> bool:
	return _elapsed >= _pending_handshakes[peer_id]

func _notify_handshake_timeout(peer_id: int) -> void:
	welcome.rpc_id(peer_id, {"ok": false, "code": "HANDSHAKE_TIMEOUT", "message": "联机身份确认超时，请重新连接"})

func _reap_unaccepted_connections() -> void:
	for peer_id in _pending_handshakes.keys():
		if _handshake_deadline_reached(peer_id):
			_notify_handshake_timeout(peer_id)
			_pending_handshakes.erase(peer_id)
			_pending_disconnects[peer_id] = _elapsed + REJECTION_FLUSH_SECONDS
	for peer_id in _pending_disconnects.keys():
		if _elapsed >= _pending_disconnects[peer_id]:
			_pending_disconnects.erase(peer_id)
			_peer.disconnect_peer(peer_id)
			_forced_disconnect_count += 1

func _on_connection_failed() -> void:
	_fail("CONNECTION_FAILED", "Could not connect to localhost server")

func _on_server_disconnected() -> void:
	if _closing:
		return
	if not _noncooperative_rejection.is_empty():
		_write_report({"status": "server_forced_disconnect", "rejection_code": _noncooperative_rejection, "voluntary_rejection_close": false, "spawned_nodes": _players_root.get_child_count()})
		_closing = true
		_quit_session(0)
		return
	if not FileAccess.file_exists(_stop_path):
		_fail("SERVER_DISCONNECTED", "Server disconnected before test shutdown")

func _runtime_path(value: String) -> String:
	return RuntimePaths.scoped_path(ProjectSettings.globalize_path("res://"), _launch_user_arguments(), value, ProjectSettings.get_setting("sandbox/technical_pack", false))

func _launch_user_arguments() -> PackedStringArray:
	return OS.get_cmdline_user_args()

func _session_time_limit_seconds() -> float:
	return 90.0 # Existing bounded technical entries retain their original limit.

func _write_report(data: Dictionary) -> void:
	if _report_path.is_empty():
		return
	if not _persist_report(data):
		_quit_session(1)

func _persist_report(data: Dictionary) -> bool:
	# Default technical report path. Ordinary Windows owner may publish an
	# immutable stage record through the same report call chain instead.
	var temporary := _report_path + ".tmp"
	var handle := FileAccess.open(temporary, FileAccess.WRITE)
	if handle == null:
		push_error("Could not write integration report")
		return false
	handle.store_string(JSON.stringify(data, "", true, true))
	handle.close()
	if DirAccess.rename_absolute(temporary, _report_path) != OK:
		push_error("Could not promote integration report")
		return false
	return true

func _fail(code: String, message: String) -> void:
	_fatal_shutdown = true
	_closing = true
	_write_report({"status": "failed", "code": code, "message": message})
	printerr("SANDBOX_NETWORK_FAILURE ", code, ": ", message)
	if _peer != null:
		_peer.close()
	if _save_store != null:
		_save_store.close()
	_cleanup_runtime()
	_quit_session(1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_user_close()

func _request_user_close() -> void:
	# Default legacy behavior. Owned local sessions may coordinate a server-first
	# close through this virtual hook without bypassing notification dispatch.
	_stop_requested = true

func _read_local_identity(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "missing": FileAccess.get_open_error() in [ERR_FILE_NOT_FOUND, ERR_DOES_NOT_EXIST]}
	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error not in [OK, ERR_FILE_EOF]:
		return {"ok": false, "missing": false}
	var identity: Variant = JSON.parse_string(text)
	if not identity is Dictionary or not SandboxServerAuthority._valid_id(identity.get("player_profile_id"), "player_") or not SandboxServerAuthority._valid_id(identity.get("resume_secret"), "resume_"):
		return {"ok": false, "missing": false}
	return {"ok": true, "identity": identity}

func _apply_local_identity(request: Dictionary) -> bool:
	if _resume_path.is_empty():
		return true
	var loaded := _read_local_identity(_resume_path)
	if loaded.get("missing", false):
		return true
	if not loaded.get("ok", false):
		_fail("IDENTITY_READ_FAILED", "Local test identity is incomplete or unreadable; original preserved")
		return false
	request["resume_profile_id"] = loaded["identity"]["player_profile_id"]
	request["resume_secret"] = loaded["identity"]["resume_secret"]
	return true

func _write_local_identity(result: Dictionary) -> bool:
	if _resume_path.is_empty():
		return true
	var identity := {"player_profile_id": result["player_profile_id"], "resume_secret": result["resume_secret"]}
	if FileAccess.file_exists(_resume_path):
		var loaded := _read_local_identity(_resume_path)
		if loaded.get("ok", false) and loaded["identity"] == identity:
			return true
		_fail("IDENTITY_CONFLICT", "Existing local identity differs; original file preserved")
		return false
	var lock_path := _resume_path + ".write_lock"
	if DirAccess.make_dir_absolute(lock_path) != OK:
		_fail("IDENTITY_WRITE_LOCKED", "Another identity write is in progress or needs recovery")
		return false
	var temporary := _resume_path + ".tmp"
	var handle := FileAccess.open(temporary, FileAccess.WRITE)
	if handle == null:
		DirAccess.remove_absolute(lock_path)
		_fail("IDENTITY_WRITE_FAILED", "Could not write private local game test identity")
		return false
	handle.store_string(JSON.stringify(identity))
	handle.flush()
	var write_error := handle.get_error()
	handle.close()
	var verified := _read_local_identity(temporary)
	if write_error != OK or not verified.get("ok", false) or verified.get("identity") != identity or FileAccess.file_exists(_resume_path):
		DirAccess.remove_absolute(lock_path)
		_fail("IDENTITY_WRITE_FAILED", "Private identity write validation failed; original preserved")
		return false
	var result_code := DirAccess.rename_absolute(temporary, _resume_path)
	DirAccess.remove_absolute(lock_path)
	if result_code != OK:
		_fail("IDENTITY_WRITE_FAILED", "Private identity atomic promotion failed")
		return false
	return true

func _save_world(reason: String, advance_auto: bool = false) -> bool:
	if _fatal_shutdown:
		return false
	var state: Dictionary = _persistent_state_for_save(advance_auto)
	if _fatal_shutdown:
		return false
	var result := _save_store.save_main(state, reason)
	if result.get("ok", false) or result.get("main_committed", false):
		_authority.next_auto_due_world_seconds = state["next_auto_due_world_seconds"]
	_last_save_summary = {"reason": reason, "ok": result.get("ok", false), "sequence": result.get("sequence", -1), "code": result.get("code", "")}
	if not result.get("ok", false):
		_fail(result.get("code", "SAVE_FAILED"), result.get("message", "Saving world failed"))
		return false
	return true

func _server_report() -> Dictionary:
	return {"status": "server_ready", "mode": _mode, "bound_address": "127.0.0.1", "snapshot": _public_snapshot(), "spawned_nodes": _players_root.get_child_count(), "save_enabled": _save_store != null, "load_summary": _load_summary, "last_save": _last_save_summary, "retained_profile_count": _authority.persistent_state()["profiles"].size(), "next_auto_due_world_seconds": _authority.next_auto_due_world_seconds, "forced_disconnect_count": _forced_disconnect_count, "transport_peer_count": multiplayer.get_peers().size(), "pending_handshake_count": _pending_handshakes.size(), "pending_disconnect_count": _pending_disconnects.size()}

# Explicit composition seams; defaults preserve the 003/004 foundation profile.
func _prepare_session() -> bool:
	return true

func _make_save_store() -> SandboxSaveStore:
	return SandboxSaveStore.new(_save_directory, int(_save_settings["automatic_backup_count"]), int(_save_settings["manual_slot_count"]), _catalogue.source_sha256, int(_settings["network_protocol_version"]))

func _restore_authority_state(state: Dictionary) -> Dictionary:
	return _authority.restore_persistent_state(state)

func _create_new_world() -> bool:
	return true

func _persistent_state_for_save(advance_auto: bool) -> Dictionary:
	return _authority.state_for_automatic_save() if advance_auto else _authority.persistent_state()

func _public_snapshot() -> Dictionary:
	return _authority.public_snapshot()

func _validate_remote_hello(request: Dictionary) -> Dictionary:
	return {"ok": true, "request": request}

func _client_accept_snapshot(_incoming: Dictionary) -> bool:
	return true

func _after_client_snapshot(_incoming: Dictionary) -> void:
	pass

# Server-only lifecycle seams. None are RPC methods or client-selected trust flags.
func _prepare_authority_runtime(save_initial: bool) -> bool:
	if _bootstrap_cancel_requested():
		_cancel_bootstrap()
		return false
	var prepared: bool = await _prepare_runtime_before_listen()
	if _bootstrap_cancel_requested():
		_cancel_bootstrap()
		return false
	if not prepared or _closing:
		if not _closing:
			_fail("RUNTIME_PREPARE_FAILED", "Runtime preparation failed before saving or listening")
		return false
	return _save_world("initial_world") if save_initial else true

func _prepare_runtime_before_listen() -> bool:
	return true

func _join_authority_peer_async(peer_id: int, request: Dictionary, local_host: bool = false) -> Dictionary:
	# Existing profiles stay synchronous; only the explicit schema4 owner opts in.
	return _join_authority_peer(peer_id, request, local_host)

func _join_authority_peer(peer_id: int, request: Dictionary, local_host: bool = false) -> Dictionary:
	return _authority.join(peer_id, request, local_host)

func _disconnect_authority_peer(peer_id: int) -> bool:
	_authority.disconnect_peer(peer_id)
	return true

func _advance_authority(delta: float) -> bool:
	_authority.advance(delta)
	return true

func _cleanup_runtime() -> void:
	pass

func _bootstrap_cancel_requested() -> bool:
	return _stop_requested or (not _stop_path.is_empty() and FileAccess.file_exists(_stop_path))

func _cancel_bootstrap() -> void:
	if _closing:
		return
	_closing = true
	_write_report({"status": "startup_cancelled", "saved": false, "listening": false})
	if _peer != null:
		_peer.close()
	if _save_store != null:
		_save_store.close()
	_cleanup_runtime()
	_quit_session(0)

func _quit_session(exit_code: int) -> void:
	get_tree().quit(exit_code)
