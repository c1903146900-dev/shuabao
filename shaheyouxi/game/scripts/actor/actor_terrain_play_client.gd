extends "res://scripts/actor/actor_play_client.gd"
## Explicit schema4/new4 local-session GUI with public terrain rendering.
## No save writer; camera, input and close semantics remain shared.
## Only the launcher owning this exact local server may coordinate its shutdown.
const TerrainClient = preload("res://scripts/actor/actor_terrain_client_state.gd")
const TerrainPlayView = preload("res://scripts/actor/actor_terrain_play_view.gd")
const SessionClose = preload("res://scripts/actor/actor_local_session_close.gd")
const LocalScope = preload("res://scripts/actor/actor_local_session_scope.gd")
const GroundView = preload("res://scripts/inventory/inventory_ground_view012.gd")
const InventoryActorState = preload("res://scripts/actor/actor_state.gd")
const InventoryLive = preload("res://scripts/inventory/inventory_live012.gd")
const InventoryPanel = preload("res://scripts/inventory/ui012/inventory_panel012.gd")
const CONTROL_LIMIT_BYTES := 16384
const CLOSE_TIMEOUT_USEC := 15000000
const CONTROL_INTEGER_FIELDS := ["schema_version", "save_schema", "server_pid", "server_start_ticks", "owner_pid", "client_pid", "peer_id", "input_generation", "cutoff_sequence", "accepted_sequence", "actor_revision", "pending_count", "intent_count", "server_exit_code", "main_sequence", "inventory_initial_sequence", "inventory_cutoff_sequence", "inventory_processed_sequence", "inventory_accepted_sequence", "inventory_revision", "inventory_pending_count", "inventory_saved_accepted_sequence", "inventory_saved_revision"]
var _inventory_client_closed: bool = false
var _ground_sync_clock: float = -1.0
var _inventory_close_waiting: bool = false
var _inventory_close_wait_started_usec: int = 0
var _inventory_close_notice: String = ""
var _inventory_notice_label: Label
var _inventory_schema: int = 4
var _inventory_live: RefCounted
var _inventory_panel: Control
var _inventory_layer: CanvasLayer
var _session_close: RefCounted
var _local_session_root: String = ""
var _local_session_manifest: String = ""
var _gui_close_started: bool = false
var _gui_close_started_usec: int = 0
var _last_close_status: Dictionary = {}
var _schema4_initial_checkpoint: Dictionary = {}
var _ordinary_coordinator: WeakRef
var _ordinary_coordinator_script: Script
var _ordinary_arguments: PackedStringArray = []
var _ordinary_scope: Dictionary = {}
var _ordinary_settings: Dictionary = {}
var _ordinary_startup_peer: ENetPacketPeer
var _ordinary_startup_deadline_usec: int = 0
var _ordinary_startup_armed: bool = false

func _on_connected() -> void:
	if not _ordinary_scope.is_empty() and _ordinary_owner() != null and not _ordinary_startup_armed:
		# The exact owned manifest was verified before this transport was created.
		_ordinary_startup_peer = _peer.get_peer(1)
		if _ordinary_startup_peer == null or _ordinary_startup_peer.get_state() != ENetPacketPeer.STATE_CONNECTED:
			_fail("LOCAL_STARTUP_PEER_INVALID", "本机启动连接不可用")
			return
		_ordinary_startup_armed = true
		_ordinary_startup_deadline_usec = Time.get_ticks_usec() + 30000000
		_ordinary_startup_peer.set_timeout(32, 30000, 30000)
	super._on_connected()

func _finish_ordinary_startup_timeout() -> void:
	if _ordinary_startup_peer != null and _ordinary_startup_peer.get_state() == ENetPacketPeer.STATE_CONNECTED:
		_ordinary_startup_peer.set_timeout(32, 5000, 30000)
	_ordinary_startup_peer = null
	_ordinary_startup_deadline_usec = 0

func _client_snapshot_matches_report(_client_snapshot: Dictionary, reported_snapshot: Variant) -> bool:
	return _actor_client_state != null and _actor_client_state.matches_wire_snapshot(reported_snapshot)

func _client_world_component() -> Dictionary:
	return _actor_client_state.world_component_snapshot()

func _actor_wire_contract() -> String:
	return TerrainClient.WIRE_CONTRACT

func _make_actor_client_state() -> RefCounted:
	return TerrainClient.new()

func _make_play_view() -> Node2D:
	return TerrainPlayView.new()

func bind_owned_session(coordinator: Node, arguments: PackedStringArray) -> Dictionary:
	if is_inside_tree() or _ordinary_coordinator != null or _session_close != null or coordinator == null:
		return {"ok": false, "code": "LOCAL_CLIENT_BINDING_ORDER"}
	var script: Variant = coordinator.get_script()
	if not script is Script or script.resource_path != "res://scripts/actor/actor_local_session_coordinator.gd" or not coordinator.permits_client_binding(self, arguments):
		return {"ok": false, "code": "LOCAL_CLIENT_OWNER_INVALID"}
	_ordinary_coordinator = weakref(coordinator)
	_ordinary_coordinator_script = script
	_ordinary_arguments = arguments.duplicate()
	_ordinary_settings = LocalScope.settings()
	if _ordinary_settings.is_empty():
		return {"ok": false, "code": "LOCAL_CLIENT_SETTINGS_INVALID"}
	_ordinary_settings.make_read_only()
	return {"ok": true}

func _ordinary_owner() -> Node:
	var owner: Node = _ordinary_coordinator.get_ref() as Node if _ordinary_coordinator != null else null
	return owner if owner != null and owner.get_script() == _ordinary_coordinator_script and owner.owns_client(self) else null

func _launch_user_arguments() -> PackedStringArray:
	return _ordinary_arguments.duplicate() if _ordinary_coordinator != null else super._launch_user_arguments()

func _runtime_path(value: String) -> String:
	if _ordinary_coordinator != null:
		return LocalScope.scoped_path(LocalScope.from_arguments(_arguments, "client"), value) if _ordinary_owner() != null else ""
	return super._runtime_path(value)

func _session_time_limit_seconds() -> float:
	return 0.0 if _ordinary_coordinator != null and _ordinary_owner() != null else super._session_time_limit_seconds()

func _quit_session(code: int) -> void:
	if _ordinary_coordinator != null:
		var owner := _ordinary_owner()
		if owner != null:
			owner.client_finished(self, code)
			return
	super._quit_session(code)

func _prepare_session() -> bool:
	if _ordinary_coordinator != null:
		_ordinary_scope = LocalScope.from_arguments(_arguments, "client")
		if _ordinary_owner() == null or _ordinary_scope.is_empty() or _ordinary_scope["owner_pid"] != OS.get_process_id():
			_fail("LOCAL_CLIENT_OWNER_INVALID", "本机会话所有者不可用")
			return false
		_ordinary_scope.make_read_only()
	_local_session_root = _report_path.get_base_dir()
	_local_session_manifest = _runtime_path(_arguments.get("local_session", ""))
	if _mode != "client" or _report_path != _local_session_root.path_join("client_owner.json") or _stop_path != _local_session_root.path_join("client.stop") or _local_session_manifest != _local_session_root.path_join("local_session.json"):
		_fail("LOCAL_SESSION_PATH_INVALID", "new4技术窗口须由本机会话入口启动")
		return false
	var loaded := _read_local_control(_local_session_manifest)
	if not loaded.get("ok", false):
		_fail(str(loaded.get("code", "LOCAL_SESSION_MANIFEST_INVALID")), "本机会话信息不可用")
		return false
	_session_close = SessionClose.new()
	var selected: Variant = _arguments.get("save_profile", "4")
	if not selected is String or selected not in ["4", "5"]:
		_fail("INVENTORY_CLIENT_PROFILE_INVALID", "存档配置不受支持")
		return false
	_inventory_schema = int(selected)
	if _inventory_schema == 5 and (OS.get_name() == "Windows" or _ordinary_scope.is_empty() or _ordinary_scope.get("save_profile") != 5):
		_fail("INVENTORY_CLIENT_PROFILE_UNSUPPORTED", "背包会话需要已验证的本地存档配置")
		return false
	var configured: Dictionary
	if _inventory_schema == 5: configured = _session_close.configure_owned_inventory(loaded["value"], _local_session_root.get_file(), OS.get_process_id())
	else: configured = _session_close.configure_owned(loaded["value"], _local_session_root.get_file(), OS.get_process_id()) if not _ordinary_scope.is_empty() else _session_close.configure(loaded["value"], _local_session_root.get_file(), OS.get_process_id())
	if not configured.get("ok", false):
		_fail(str(configured.get("code", "LOCAL_SESSION_MANIFEST_INVALID")), "本机会话信息不匹配")
		return false
	if not super._prepare_session():
		return false
	get_window().title = "沙盒游戏 · 地表技术区域 · F10保存返回" if not _ordinary_scope.is_empty() else "沙盒011 new4 · 地表技术窗口 · F10保存退出"
	return true

func _actor_save_schema_for_report() -> int:
	# Expected locally owned server schema, established by the launcher manifest;
	# this client neither opens a SaveStore nor loads/writes a schema3 save.
	return _inventory_schema

func _after_client_snapshot(incoming: Dictionary) -> void:
	if _session_close == null or _actor_input_pending == null or not _actor_input_pending.ready:
		_stop_local_input("LOCAL_SESSION_CHECKPOINT_UNAVAILABLE")
		return
	var cursor: Dictionary = _actor_input_pending.cursor()
	var bound: Dictionary = _session_close.bind_checkpoint(cursor)
	if not bound.get("ok", false):
		_stop_local_input(str(bound.get("code", "LOCAL_SESSION_CHECKPOINT_INVALID")))
		return
	if _schema4_initial_checkpoint.is_empty():
		# state_snapshot already validated this RPC and synchronized the pending
		# cursor. Capture before the shared view/sampler receives its first state.
		# This is public evidence only; no input, clock or actor state is changed.
		var actor: Dictionary = incoming["actor_public"]["actors"][cursor["player_instance_id"]]
		_schema4_initial_checkpoint = cursor.duplicate(true)
		_schema4_initial_checkpoint.erase("world_seconds")
		_schema4_initial_checkpoint["layer"] = actor["layer"].duplicate(true)
		_schema4_initial_checkpoint["layer"].make_read_only()
		_schema4_initial_checkpoint["position_bits_le"] = [_checkpoint_scalar_bits(actor["position"][0]), _checkpoint_scalar_bits(actor["position"][1])]
		_schema4_initial_checkpoint["position_bits_le"].make_read_only()
		_schema4_initial_checkpoint["clock_bits_le"] = _checkpoint_scalar_bits(cursor["world_seconds"])
		_schema4_initial_checkpoint.make_read_only()
	if not _world_view.terrain_ready():
		var terrain_shown: Dictionary = _world_view.consume_validated_terrain(_actor_client_state.terrain_snapshot())
		if not terrain_shown.get("ok", false):
			_stop_local_input(str(terrain_shown.get("code", "TERRAIN_PLAY_PUBLIC_INVALID")))
			return
	super._after_client_snapshot(incoming)
	if _inventory_schema == 5 and not _closing and not _fatal_shutdown: _prepare_inventory_client()
	if not _closing and not _fatal_shutdown:
		_finish_ordinary_startup_timeout()

func _initial_checkpoint_report() -> Dictionary:
	return _schema4_initial_checkpoint.duplicate(true)

static func _checkpoint_scalar_bits(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()

func _client_accept_snapshot(incoming: Dictionary) -> bool:
	if _session_close != null and _session_close.statistics()["server_disconnect_observed"]:
		return false
	return super._client_accept_snapshot(incoming)

func _can_sample() -> bool:
	return not _gui_close_started and _session_close != null and _session_close.ready and super._can_sample()

func _set_local_focus(focused: bool) -> void:
	if _gui_close_started:
		_local_focused = focused
		return # Focus re-entry cannot create intents after the fixed close cutoff.
	super._set_local_focus(focused)

func _unhandled_key_input(event: InputEvent) -> void:
	# This engine phase precedes _unhandled_input. The inherited world callback
	# would otherwise set the legacy stop flag before the local drain begins.
	if event is InputEventKey and event.keycode == KEY_F10:
		if event.pressed and not event.echo:
			_request_user_close()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F10:
		if event.pressed and not event.echo:
			_request_user_close()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func _request_user_close() -> void:
	_request_local_session_stop()

func _request_local_session_stop() -> void:
	if _gui_close_started or _closing or _fatal_shutdown:
		return
	if _inventory_schema == 5 and not _inventory_preclose_ready(): return
	_gui_close_started = true
	if _inventory_schema == 5:
		if _inventory_live != null: _inventory_live.stop_client()
		if _inventory_panel != null:
			_inventory_panel.set_requests_enabled(false)
			_inventory_panel.close_panel("session_stop")
	_gui_close_started_usec = Time.get_ticks_usec()
	if _session_close == null or not _session_close.ready or not _startup_ready or not _reported_ready or _local_sampler == null or not _local_sampler.ready or _actor_input_pending == null or not _actor_input_pending.ready:
		_stop_local_input("LOCAL_SESSION_STOP_BEFORE_READY")
		return # Explicit startup failure, never a claimed successful normal save.
	_local_input_ready = false
	# Existing sampler emits zero movement and releases every actually held action.
	# Existing dispatch calls the real producer/RPC synchronously before capture.
	_dispatch_local_batch(_local_sampler.set_enabled(false), true)
	if _closing or _fatal_shutdown or not _actor_input_pending.ready:
		return
	var cutoff: int = _actor_input_pending._next_sequence - 1
	var started: Dictionary
	if _inventory_schema == 5:
		if _inventory_live == null or not _inventory_live.client_ready():
			_stop_local_input("INVENTORY_STOP_BEFORE_READY")
			return
		started = _session_close.begin_stop_inventory(_actor_input_pending.cursor(), cutoff, _actor_client_transport_state().get("ok", false), _inventory_live.client_checkpoint())
	else: started = _session_close.begin_stop(_actor_input_pending.cursor(), cutoff, _actor_client_transport_state().get("ok", false))
	if not started.get("ok", false):
		_stop_local_input(str(started.get("code", "LOCAL_SESSION_STOP_NOT_READY")))
		return
	_write_local_close_status()

func _process(delta: float) -> void:
	if _ordinary_startup_deadline_usec > 0 and Time.get_ticks_usec() >= _ordinary_startup_deadline_usec:
		_finish_ordinary_startup_timeout()
	if _ordinary_coordinator != null and _ordinary_owner() == null and not _closing and not _fatal_shutdown:
		_stop_local_input("LOCAL_CLIENT_OWNER_LOST")
		return
	super._process(delta)
	if not _closing and not _fatal_shutdown and _inventory_preclose_timed_out(Time.get_ticks_usec()):
		_stop_local_input("INVENTORY_PRECLOSE_TIMEOUT")
		return
	if _closing or _fatal_shutdown or not _gui_close_started:
		return
	var close_limit: int = int(_ordinary_settings["close_timeout_seconds"] * 1000000.0) if not _ordinary_scope.is_empty() else CLOSE_TIMEOUT_USEC
	if Time.get_ticks_usec() - _gui_close_started_usec > close_limit:
		_stop_local_input("LOCAL_SESSION_CLOSE_TIMEOUT")
		return
	_poll_local_session_close()

func _poll_local_session_close() -> void:
	var statistics: Dictionary = _session_close.statistics()
	if statistics["phase"] == "draining":
		if _actor_input_pending == null or not _actor_input_pending.ready:
			_stop_local_input("LOCAL_SESSION_RELEASE_UNCONFIRMED")
			return
		var released: Dictionary
		if _inventory_schema == 5:
			# View/close control replies never consume a left sequence, yet must
			# also finish before the launcher can publish a server stop request.
			if _inventory_live == null or not _inventory_live.client_ready():
				_stop_local_input("INVENTORY_RELEASE_UNCONFIRMED")
				return
			if _inventory_live.client_pending_count() != 0: return
			released = _session_close.poll_release_inventory(_actor_input_pending.cursor(), _actor_input_pending.pending().size(), _actor_client_transport_state().get("ok", false), _actor_client_sent_count, _inventory_live.client_checkpoint())
		else: released = _session_close.poll_release(_actor_input_pending.cursor(), _actor_input_pending.pending().size(), _actor_client_transport_state().get("ok", false), _actor_client_sent_count)
		if released.get("pending", false):
			return
		if not released.get("ok", false) or not _manifest_still_matches():
			_stop_local_input(str(released.get("code", "LOCAL_SESSION_MANIFEST_CHANGED")))
			return
		if not _write_local_control("client_close.request.json", released["request"]):
			_stop_local_input("LOCAL_SESSION_REQUEST_WRITE_FAILED")
			return
		var recorded: Dictionary = _session_close.mark_request_written()
		if not recorded.get("ok", false):
			_stop_local_input(str(recorded["code"]))
			return
	statistics = _session_close.statistics()
	if statistics["phase"] == "waiting_server" and not statistics["save_receipt_verified"] and FileAccess.file_exists(_local_session_root.path_join("server_close.result.json")):
		var loaded := _read_local_control(_local_session_root.path_join("server_close.result.json"))
		if not loaded.get("ok", false) or not _manifest_still_matches():
			_stop_local_input("LOCAL_SESSION_RECEIPT_READ_FAILED")
			return
		var accepted: Dictionary = _session_close.accept_receipt(loaded["value"])
		if not accepted.get("ok", false):
			_stop_local_input(str(accepted.get("code", "LOCAL_SESSION_RECEIPT_INVALID")))
			return
	_write_local_close_status()
	if _session_close.can_close():
		_stop_requested = true # The next inherited client process performs normal exit.

func _on_server_disconnected() -> void:
	_ordinary_startup_armed = false
	_ordinary_startup_peer = null
	_ordinary_startup_deadline_usec = 0
	_close_inventory_client()
	if _session_close != null and _session_close.expected_disconnect():
		_actor_client_connection_lost = true
		_close_actor_input_pending()
		_local_input_ready = false
		var observed: Dictionary = _session_close.observe_disconnect()
		if not observed.get("ok", false):
			_stop_local_input(str(observed["code"]))
			return
		_write_local_close_status()
		return # Save/exit success still requires the owned launcher's exact receipt.
	super._on_server_disconnected()

func _cleanup_runtime() -> void:
	_ordinary_startup_armed = false
	_ordinary_startup_peer = null
	_ordinary_startup_deadline_usec = 0
	_close_inventory_client()
	if _session_close != null and _session_close.can_close() and not _fatal_shutdown:
		_session_close.mark_closed()
		_write_local_close_status()
	super._cleanup_runtime()

func _write_report(data: Dictionary) -> void:
	if _ordinary_coordinator != null:
		return # The ordinary coordinator reads this client's validated objects.
	var report: Dictionary = data.duplicate(true)
	report["actor_schema4_initial_checkpoint"] = _initial_checkpoint_report()
	report["actor_schema4_local_session"] = _local_close_statistics()
	report["actor_schema4_local_session"]["client_writes_save"] = false
	super._write_report(report)

func _write_closed_presentation_trace() -> void:
	if _ordinary_coordinator == null:
		super._write_closed_presentation_trace()

func _local_close_statistics() -> Dictionary:
	var statistics: Dictionary = _session_close.statistics() if _session_close != null else {"phase": "unconfigured"}
	statistics["inputs_stopped"] = _gui_close_started and _local_sampler != null and _local_sampler.ready and not _local_sampler.state()["enabled"]
	statistics["pending_count"] = _actor_input_pending.pending().size() if _actor_input_pending != null else -1
	return statistics

func _manifest_still_matches() -> bool:
	var loaded := _read_local_control(_local_session_manifest)
	return loaded.get("ok", false) and _session_close.manifest_matches(loaded["value"])

func _write_local_close_status() -> void:
	var statistics := _local_close_statistics()
	if statistics != _last_close_status:
		_last_close_status = statistics.duplicate(true)
		if not _write_local_control("client_close.status.json", statistics):
			_stop_local_input("LOCAL_SESSION_STATUS_WRITE_FAILED")

func _write_local_control(filename: String, value: Dictionary) -> bool:
	if _ordinary_coordinator != null and filename == "client_close.status.json":
		return true # Diagnostic status stays in _last_close_status for this mode.
	if filename not in ["client_close.request.json", "client_close.status.json"] or _local_session_root.is_empty():
		return false
	var text := JSON.stringify(value, "", true, true)
	if text.to_utf8_buffer().size() > CONTROL_LIMIT_BYTES:
		return false
	var target := _local_session_root.path_join(filename)
	var file := FileAccess.open(target + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var written: bool = file.get_error() == OK
	file.close()
	return written and DirAccess.rename_absolute(target + ".tmp", target) == OK

static func _read_local_control(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 1 or file.get_length() > CONTROL_LIMIT_BYTES:
		if file != null:
			file.close()
		return {"ok": false, "code": "LOCAL_SESSION_CONTROL_SIZE_OR_PATH"}
	var parser := JSON.new()
	var length: int = file.get_length()
	var bytes: PackedByteArray = file.get_buffer(length)
	var read_error: int = file.get_error()
	var final_length: int = file.get_length()
	file.close()
	if bytes.size() != length or final_length != length or read_error not in [OK, ERR_FILE_EOF]:
		return {"ok": false, "code": "LOCAL_SESSION_CONTROL_READ_FAILED"}
	var text: String = bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return {"ok": false, "code": "LOCAL_SESSION_CONTROL_JSON"}
	var parse_error: int = parser.parse(text)
	if parse_error != OK:
		return {"ok": false, "code": "LOCAL_SESSION_CONTROL_JSON"}
	return _canonical_local_control(parser.data)

static func _canonical_local_control(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false, "code": "LOCAL_SESSION_CONTROL_FIELDS"}
	# JSON numeric tokens become floats in Godot. Restore only declared integer
	# slots, rejecting bools, fractions, infinities and out-of-domain values.
	var result: Dictionary = value.duplicate(true)
	for field in CONTROL_INTEGER_FIELDS:
		if result.has(field):
			var number: Variant = result[field]
			if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or absf(float(number)) > 9007199254740991.0 or floorf(float(number)) != float(number):
				return {"ok": false, "code": "LOCAL_SESSION_CONTROL_INTEGER"}
			result[field] = int(number)
	return {"ok": true, "value": result}

func _prepare_inventory_client() -> void:
	if _inventory_client_closed: return
	var context := _inventory_client_context()
	if not context.get("ok", false):
		_stop_local_input("INVENTORY_CLIENT_CONTEXT_UNAVAILABLE")
		return
	if _inventory_live != null:
		if not _inventory_live.client_matches(context["identity"], context["transport"]): _stop_local_input("INVENTORY_CLIENT_CONTEXT_CHANGED")
		return
	_inventory_live = InventoryLive.new()
	if not _inventory_live.configure_client(context["identity"], context["transport"])["ok"]:
		_stop_local_input("INVENTORY_CLIENT_BINDING")
		return
	_inventory_layer = CanvasLayer.new()
	_inventory_layer.name = "Inventory012"
	_inventory_layer.layer = 10
	add_child(_inventory_layer)
	_inventory_panel = InventoryPanel.new()
	_inventory_panel.bind_identity(context["identity"]["world_id"], context["identity"]["player_profile_id"])
	_inventory_panel.require_authenticated_open()
	_inventory_panel.set_left_enabled(false)
	_inventory_panel.open_intent.connect(_request_inventory_open)
	_inventory_panel.close_intent.connect(_request_inventory_close)
	_inventory_panel.left_intent.connect(_request_inventory_left)
	_inventory_panel.drop_intent.connect(_request_inventory_drop)
	_inventory_layer.add_child(_inventory_panel)
	_inventory_notice_label = Label.new()
	_inventory_notice_label.position = Vector2(24, 90)
	_inventory_notice_label.z_index = 30
	_inventory_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory_layer.add_child(_inventory_notice_label)
	# Initial private checkpoint is obtained without opening the panel.
	_issue_inventory("view", _inventory_panel.context_epoch())

func _issue_inventory(kind: String, epoch: int, address: Dictionary = {}, revision: int = -1, sequence: int = -1, drop_kind: String = "", aim: Array = []) -> void:
	if _inventory_client_closed or _inventory_schema != 5 or _inventory_live == null or _inventory_close_waiting or _gui_close_started or _closing or _fatal_shutdown: return
	var context := _inventory_client_context()
	if not context.get("ok", false) or not _inventory_live.client_matches(context.get("identity", {}), context.get("transport", {})):
		_stop_local_input("INVENTORY_CLIENT_CONTEXT_CHANGED")
		return
	var issued: Dictionary = _inventory_live.issue_client(kind, epoch, address, revision, sequence, drop_kind, aim)
	if not issued["ok"]:
		_stop_local_input(str(issued["code"]))
		return
	if not _bind_inventory_checkpoint(): return
	_inventory_panel.set_left_enabled(false)
	if rpc_id(1, &"inventory_request012", issued["request"]) != OK:
		_close_inventory_client()
		_stop_local_input("INVENTORY_CLIENT_SEND_FAILED") # No automatic resend.

func _request_inventory_drop(kind: String, address: Dictionary, revision: int, sequence: int) -> void:
	var pointer: Dictionary = _current_pointer_world()
	var direction := Vector2.ZERO
	if pointer.get("ok", false):
		var drawing: Dictionary = _world_view.drawing_state()
		for actor in drawing.get("actors", []):
			if actor.get("own", false): direction = InventoryActorState.vector(pointer["world_point"]) - actor["world_position"]
	_issue_inventory("drop", _inventory_panel.context_epoch(), address, revision, sequence, kind, [float(direction.x), float(direction.y)])

func _request_inventory_open() -> void:
	_issue_inventory("view", _inventory_panel.context_epoch())

func _request_inventory_close(_reason: String, _revision: int) -> void:
	_issue_inventory("close", _inventory_panel.context_epoch())

func _request_inventory_left(address: Dictionary, revision: int, sequence: int) -> void:
	_issue_inventory("left", _inventory_panel.context_epoch(), address, revision, sequence)

func _bind_inventory_checkpoint() -> bool:
	if not _inventory_live.client_ready(): return true
	var bound: Dictionary = _session_close.bind_inventory_checkpoint(_inventory_live.client_checkpoint())
	if not bound["ok"]:
		_stop_local_input(str(bound["code"]))
		return false
	return true

func _receive_inventory_reply012(reply: Variant) -> void:
	if _inventory_client_closed or _inventory_schema != 5 or _inventory_live == null or _inventory_panel == null: return
	var context := _inventory_client_context()
	if not context.get("ok", false) or not _inventory_live.client_matches(context.get("identity", {}), context.get("transport", {})):
		_stop_local_input("INVENTORY_CLIENT_CONTEXT_CHANGED")
		return
	if not reply is Dictionary or not _inventory_panel._model.validate(reply.get("view")).get("ok", false):
		_stop_local_input("INVENTORY_PRIVATE_VIEW_INVALID")
		return
	var accepted: Dictionary = _inventory_live.accept_client(reply)
	if not accepted["ok"]:
		_stop_local_input(str(accepted["code"]))
		return
	var shown: Dictionary = _inventory_panel.apply_server_view(accepted["view"])
	if not shown["ok"]:
		_stop_local_input(str(shown["code"]))
		return
	if _inventory_client_closed or _closing or _fatal_shutdown: return
	if not _bind_inventory_checkpoint(): return
	if accepted["kind"] in ["left", "drop"] and not accepted["action_ok"]: _inventory_panel.reject_left_intent(accepted["sequence"])
	if accepted["kind"] == "view" and accepted["action_ok"] and not _gui_close_started: _inventory_panel.complete_personal_open(accepted["context_epoch"])
	_inventory_panel.set_left_enabled(not _gui_close_started and not _inventory_close_waiting and _inventory_live.client_pending_count() == 0)
	if _inventory_close_waiting and _inventory_live.client_pending_count() == 0: _request_local_session_stop()

func _close_inventory_client() -> void:
	_inventory_client_closed = true # Before context_lost can emit close_intent.
	if _inventory_live != null: _inventory_live.close()
	if _inventory_panel != null:
		_inventory_panel.set_requests_enabled(false)
		_inventory_panel.context_lost()

func _inventory_client_context() -> Dictionary:
	var context := _client_actor_input_context()
	if context.get("ok", false): context["identity"]["input_generation"] = context["input_generation"]
	return context

func _inventory_preclose_ready() -> bool:
	# User-confirmed carry persistence: wait for the authoritative response,
	# then save the complete inventory including carry. Never return or drop here.
	if _inventory_live == null or not _inventory_live.client_ready() or _inventory_panel == null:
		return true # Existing startup/close checks fail this unavailable session.
	if _inventory_live.client_pending_count() != 0:
		if not _inventory_close_waiting: _inventory_close_wait_started_usec = Time.get_ticks_usec()
		_inventory_close_waiting = true
		_inventory_panel.set_requests_enabled(false)
		_inventory_panel.set_left_enabled(false)
		_inventory_close_message("正在等待背包操作确认…")
		return false
	_inventory_close_waiting = false
	_inventory_close_wait_started_usec = 0
	var view: Dictionary = _inventory_panel.cached_view()
	if view.is_empty():
		_inventory_close_message("背包状态尚未确认，请稍后保存退出")
		return false
	_inventory_close_message("")
	return true

func _inventory_close_message(message: String) -> void:
	_inventory_close_notice = message
	if _inventory_notice_label != null: _inventory_notice_label.text = message

func _inventory_preclose_timed_out(now_usec: int) -> bool:
	var limit: int = int(_ordinary_settings["close_timeout_seconds"] * 1000000.0) if not _ordinary_scope.is_empty() else CLOSE_TIMEOUT_USEC
	return _inventory_close_waiting and now_usec - _inventory_close_wait_started_usec > limit

@rpc("authority", "call_remote", "reliable")
func inventory_sync012(packet: Dictionary) -> void:
	if _inventory_client_closed or _inventory_schema != 5 or _inventory_live == null or _inventory_panel == null or _closing or _fatal_shutdown: return
	if multiplayer.get_remote_sender_id() != 1: return
	var context := _inventory_client_context()
	if not context.get("ok", false) or not _inventory_live.client_matches(context.get("identity", {}), context.get("transport", {})): return
	if not GroundView.validate(packet, context["identity"], _inventory_panel._model._rules) or not _inventory_panel._model.validate(packet["view"]).get("ok", false) or packet["world_seconds"] < _ground_sync_clock:
		_stop_local_input("INVENTORY_SYNC_INVALID")
		return
	var accepted: Dictionary = _inventory_live.accept_sync_client(packet["identity"], packet["view"])
	if not accepted.get("ok", false):
		_stop_local_input(str(accepted.get("code", "INVENTORY_SYNC_INVALID")))
		return
	if accepted.get("skipped", false): return
	var shown: Dictionary = _inventory_panel.apply_server_view(packet["view"])
	if not shown.get("ok", false):
		_stop_local_input(str(shown.get("code", "INVENTORY_SYNC_INVALID")))
		return
	_ground_sync_clock = packet["world_seconds"]
	_world_view.consume_ground_view(packet["layer"], packet["ground"])
	_bind_inventory_checkpoint()
