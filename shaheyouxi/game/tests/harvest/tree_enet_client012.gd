extends SceneTree
## One real resume/welcome/snapshot stream, one original actor_input RPC send,
## then marker-bound local ENet close. No inventory stream or fabricated ACK.
const Observer = preload("res://tests/harvest/tree_enet_observer012.gd")
const Paths = preload("res://scripts/network/runtime_paths.gd")
const TIMEOUT_SECONDS := 65.0
const MAX_TRIGGER_BYTES := 16384
const ALLOWED_ARGUMENTS := ["mode", "port", "resume", "save_profile", "test_entry", "tree_fixture_profile", "exercise", "report", "stop", "name", "expected_players", "probe_report"]
var client: Node
var probe_root := ""
var nonce := ""
var probe_mode := ""
var report := ""
var stop_path := ""
var trigger_path := ""
var started_usec: int = 0
var failed := false
var finished := false
var close_requested := false
var phase := "initializing"
var bound_context: Dictionary = {}
var sent_result: Dictionary = {}
var close_trigger: Dictionary = {}
var history: Array = []
var probe_last_context_usec: int = 0
var probe_last_context_code := ""

func _initialize() -> void:
	started_usec = Time.get_ticks_usec()
	create_timer(TIMEOUT_SECONDS).timeout.connect(func() -> void:
		if not finished and not failed:
			_fail("TIMEOUT"))
	call_deferred("_run")

func _run() -> void:
	var args: Dictionary = {}
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	for argument in user_args:
		if not argument.begins_with("--") or not argument.contains("="):
			_fail("BAD_ARGUMENT")
			return
		var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if pair[0] not in ALLOWED_ARGUMENTS or args.has(pair[0]):
			_fail("UNSUPPORTED_OR_DUPLICATE_ARGUMENT")
			return
		args[pair[0]] = pair[1]
	var requested_root: String = OS.get_environment("TREE_ENET_ROOT")
	probe_root = Paths.scoped_path(ProjectSettings.globalize_path("res://"), user_args, requested_root)
	if probe_root.is_empty() or probe_root != requested_root or not DirAccess.dir_exists_absolute(probe_root):
		_fail("BAD_SCOPE")
		return
	nonce = OS.get_environment("TREE_ENET_NONCE")
	probe_mode = OS.get_environment("TREE_ENET_MODE")
	if not Observer.probe_nonce_valid(nonce) or probe_mode not in ["baseline", "detached_disconnect"]:
		_fail("BAD_TEST_BINDING")
		return
	var required: Dictionary = {"mode":"client", "save_profile":"6", "test_entry":"true", "tree_fixture_profile":"isolated", "exercise":"false", "resume":probe_root.path_join("client_private_identity.json")}
	for key in required:
		if args.get(key) != required[key]:
			_fail("BAD_CLIENT_ARGUMENTS")
			return
	if not FileAccess.file_exists(required["resume"]):
		_fail("FIXTURE_IDENTITY_MISSING")
		return
	var port_text: String = args.get("port", "")
	if not port_text.is_valid_int() or int(port_text) < 1 or int(port_text) > 65535:
		_fail("BAD_PORT")
		return
	var requested_report: String = probe_root.path_join("client_probe.json")
	trigger_path = probe_root.path_join("close_trigger.json")
	stop_path = args.get("stop", "")
	var owner_report: String = args.get("report", "")
	var forbidden_paths: Array = [requested_report, requested_report + ".tmp", trigger_path, required["resume"]]
	for path in [owner_report, stop_path]:
		if Paths.scoped_path(ProjectSettings.globalize_path("res://"), user_args, path) != path or not path.begins_with(probe_root + "/") or path in forbidden_paths:
			_fail("BAD_OWNER_PATH")
			return
	if owner_report == stop_path or owner_report + ".tmp" == stop_path or owner_report + ".tmp" in forbidden_paths or args.get("probe_report", requested_report) != requested_report:
		_fail("CONFLICTING_REPORT_PATH")
		return
	if FileAccess.file_exists(requested_report) or FileAccess.file_exists(requested_report + ".tmp") or FileAccess.file_exists(trigger_path) or FileAccess.file_exists(stop_path):
		_fail("STALE_RUNTIME_FILES")
		return
	report = requested_report # Admit this fresh output only after all path checks.
	_record("driver_started")
	client = Observer.new()
	client.name = "NetworkMain"
	client.probe_failure_seen.connect(_owner_failed)
	process_frame.connect(_observe)
	root.add_child(client) # Original Owner receives unchanged OS command line.

func _observe() -> void:
	if failed or finished:
		return
	if Time.get_ticks_usec() - started_usec >= int(TIMEOUT_SECONDS * 1000000.0):
		_fail("TIMEOUT")
		return
	if not is_instance_valid(client) or client._fatal_shutdown or client._closing:
		_fail("OWNER_STOPPED_OR_FATAL")
		return
	if FileAccess.file_exists(stop_path):
		_fail("UNEXPECTED_STOP_FILE")
		return
	if close_requested:
		return
	var context: Dictionary = client._client_actor_input_context()
	if bound_context.is_empty():
		if not context.get("ok", false):
			var context_code: String=str(context.get("code",""))
			if context_code!=probe_last_context_code or probe_last_context_usec==0:
				probe_last_context_usec=Time.get_ticks_usec()
				probe_last_context_code=context_code
				_record("context_wait",{"code":context_code,"welcome_seen":not client._welcome.is_empty(),"snapshot_count":client.probe_snapshot_count})
			return
		if client._actor_client_sent_count != 0:
			_fail("UNEXPECTED_PREVIOUS_INPUT")
			return
		bound_context = context.duplicate(true)
		_record("context_ready", {"context":bound_context.duplicate(true)})
		# Original method alone allocates sequence/generation and sends RPC to1.
		sent_result = client.submit_client_actor_intent([0, 0], [0, -1])
		if failed:
			return
		if not sent_result.get("ok", false) or not sent_result.get("provisional", false) or typeof(sent_result.get("sequence")) != TYPE_INT or sent_result["sequence"] < 1 or sent_result.get("input_generation") != bound_context["input_generation"] or client._actor_client_sent_count != 1:
			_fail("ORIGINAL_INPUT_SEND_FAILED")
			return
		_record("actor_input_sent", {"sent_result":sent_result.duplicate(true), "move":[0, 0], "aim":[0, -1], "claim":"local_rpc_send_only"})
		return
	if not context.get("ok", false) or context != bound_context or client._actor_client_sent_count != 1:
		_fail("CONTEXT_CHANGED_AFTER_SEND")
		return
	if not FileAccess.file_exists(trigger_path):
		return
	var file := FileAccess.open(trigger_path, FileAccess.READ)
	if file == null:
		_fail("TRIGGER_READ_FAILED")
		return
	var size: int = file.get_length()
	if size < 1 or size > MAX_TRIGGER_BYTES:
		file.close()
		_fail("TRIGGER_SIZE_INVALID")
		return
	var bytes: PackedByteArray = file.get_buffer(size)
	var read_error: int = file.get_error()
	var final_size: int = file.get_length()
	file.close()
	if bytes.size() != size or final_size != size or read_error not in [OK, ERR_FILE_EOF]:
		_fail("TRIGGER_CHANGED_DURING_READ")
		return
	var text: String = bytes.get_string_from_utf8()
	var value: Variant = JSON.parse_string(text)
	if text.to_utf8_buffer() != bytes or not value is Dictionary:
		_fail("TRIGGER_INVALID_JSON")
		return
	if not client.arm_tree_expected_close(bound_context, value, nonce, probe_mode):
		_fail("EXPECTED_CLOSE_BINDING_FAILED")
		return
	close_trigger = value.duplicate(true)
	_record("expected_close_armed", {"trigger":close_trigger.duplicate(true), "context":context.duplicate(true)})
	close_requested = true
	_record("local_transport_close_requested")
	client._peer.close() # Actual ENet transport; no server callback or stop file.
	call_deferred("_finish_close")

func _finish_close() -> void:
	await process_frame
	await process_frame
	if failed:
		return
	if not is_instance_valid(client) or client._fatal_shutdown or client._closing or not client.probe_expected_disconnect_seen or client.probe_disconnect_callback_count != 1 or not client._actor_client_connection_lost or client._actor_client_sent_count != 1 or Time.get_ticks_usec() - started_usec >= int(TIMEOUT_SECONDS * 1000000.0):
		_fail("UNEXPECTED_CLOSE_RESULT")
		return
	_record("expected_disconnect_verified")
	if not _write({"ok":true, "status":"original_actor_input_sent_then_local_transport_close"}):
		_fail("PROBE_REPORT_WRITE_FAILED")
		return
	finished = true
	quit(0)

func _record(event: String, extra: Dictionary = {}) -> void:
	phase = event
	var row: Dictionary = {"event":event, "usec":Time.get_ticks_usec(), "unix_seconds":Time.get_unix_time_from_system()}
	row.merge(extra)
	history.append(row)
	print("TREE_ENET_CLIENT_TRACE ",JSON.stringify(row,"",true,true))

func _write(value: Dictionary) -> bool:
	if report.is_empty():
		return false
	value.merge({"mode":probe_mode, "nonce":nonce, "phase":phase, "started_usec":started_usec, "finished_usec":Time.get_ticks_usec(), "history":history.duplicate(true), "context":bound_context.duplicate(true), "sent_result":sent_result.duplicate(true), "trigger":close_trigger.duplicate(true), "input_claim":"local_rpc_send_only_not_server_acceptance_or_action_success", "last_context_code":probe_last_context_code, "expected_disconnect_seen":false})
	if is_instance_valid(client):
		value["startup_events"] = client.probe_startup_events.duplicate(true)
		value["snapshot_count"] = client.probe_snapshot_count
		value["snapshot_statistics"] = client._actor_client_state.consume_statistics() if client._actor_client_state != null else {}
		value["snapshot_observations"] = client.probe_snapshot_observations.duplicate(true)
		value["sent_count"] = client._actor_client_sent_count
		value["expected_disconnect_seen"] = client.probe_expected_disconnect_seen
		value["expected_disconnect_usec"] = client.probe_expected_disconnect_usec
		value["disconnect_callback_count"] = client.probe_disconnect_callback_count
	var file := FileAccess.open(report + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "", true, true))
	file.flush()
	var write_error: int = file.get_error()
	file.close()
	return write_error == OK and DirAccess.rename_absolute(report + ".tmp", report) == OK

func _owner_failed(code: String) -> void:
	_fail("OWNER_" + code)

func _fail(code: String) -> void:
	if failed:
		return
	failed = true
	_record("failed", {"code":code})
	_write({"ok":false, "code":code})
	push_error(code)
	quit(1)
