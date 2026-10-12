extends RefCounted
## Ordinary local process scope. No remote payload selects a slot, path or role.
const Close = preload("res://scripts/actor/actor_local_session_close.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const Generations = preload("res://scripts/save/windows_generation_store.gd")
const InventoryLive = preload("res://scripts/inventory/inventory_live012.gd")
const ProfileMarker = preload("res://scripts/inventory/inventory_profile_marker012.gd")
const ROOT := "user://local_play011"
const CONTROL_BYTES := 16384
const REPORT_BYTES := 4194304
const ARGUMENTS := ["local_slot", "local_session_id", "local_owner_nonce", "local_owner_pid"]
const VALUE_FIELDS := ["startup_timeout_seconds", "close_timeout_seconds", "owner_timeout_seconds", "heartbeat_interval_seconds", "poll_interval_seconds", "kill_grace_seconds"]

static func requested(arguments: Dictionary) -> bool:
	for field in ARGUMENTS:
		if arguments.has(field):
			return true
	return false

static func from_arguments(arguments: Dictionary, role: String) -> Dictionary:
	if role not in ["server", "client"] or not arguments.get("mode") is String or arguments["mode"] != role:
		return {}
	for field in ARGUMENTS:
		if not arguments.get(field) is String:
			return {}
	if not Close._hex(arguments["local_slot"], 32) or not Close._hex(arguments["local_session_id"], 32) or not Close._hex(arguments["local_owner_nonce"], 32) or not arguments["local_owner_pid"].is_valid_int():
		return {}
	var owner_pid: int = int(arguments["local_owner_pid"])
	if owner_pid <= 1 or owner_pid > 2147483647:
		return {}
	var result := paths(arguments["local_slot"], arguments["local_session_id"])
	var required: Dictionary = {"report": result["server_report" if role == "server" else "client_report"], "stop": result["server_stop" if role == "server" else "client_stop"]}
	if role == "server":
		required.merge({"save_dir": result["world_directory"], "seed": "42", "test_entry": "true"})
	else:
		required.merge({"resume": result["identity_path"], "local_session": result["manifest"], "exercise": "false"})
	var inventory_profile: bool = arguments.has("save_profile") or arguments.has("slot_profile_sha256")
	if inventory_profile:
		if not arguments.get("save_profile") is String or arguments["save_profile"] != "5" or not arguments.get("slot_profile_sha256") is String or not Close._hex(arguments["slot_profile_sha256"], 64):
			return {}
		required["save_profile"] = "5"
		required["slot_profile_sha256"] = arguments["slot_profile_sha256"]
	var allowed: Array = ARGUMENTS + ["mode", "port"] + required.keys()
	if role == "client":
		allowed.append("name")
		if not arguments.get("name") is String or arguments["name"].strip_edges().is_empty() or arguments["name"].length() > 64:
			return {}
	for key in arguments:
		if key not in allowed:
			return {}
	for key in required:
		if not arguments.get(key) is String or arguments[key] != required[key]:
			return {} # Being inside the scope does not authorize swapping file roles.
	if not arguments.get("port") is String or not arguments["port"].is_valid_int() or int(arguments["port"]) < 1 or int(arguments["port"]) > 65535:
		return {}
	result.merge({"slot_id": arguments["local_slot"], "session_id": arguments["local_session_id"], "owner_nonce": arguments["local_owner_nonce"], "owner_pid": owner_pid, "role": role})
	if inventory_profile:
		result["save_profile"] = 5
		result["profile_marker_sha256"] = arguments["slot_profile_sha256"]
	if not profile_marker_matches(result): return {}
	return result

static func profile_marker_matches(scope: Dictionary) -> bool:
	# Legacy scope remains unchanged. Explicit5 binds the actual canonical marker
	# to its start-time hash; no Registry/Core preload cycle is introduced here.
	if not scope.get("slot_id") is String or not Close._hex(scope["slot_id"], 32): return false
	var inventory_profile: bool = scope.has("save_profile")
	if not inventory_profile and scope.has("profile_marker_sha256"): return false
	if inventory_profile and (typeof(scope["save_profile"]) != TYPE_INT or scope["save_profile"] != 5 or not scope.get("profile_marker_sha256") is String or not Close._hex(scope["profile_marker_sha256"], 64)): return false
	var root: String = ProjectSettings.globalize_path(ROOT)
	var slot: String = root.path_join("slots").path_join(scope["slot_id"])
	var path: String = slot.path_join(ProfileMarker.FILENAME)
	for checked in [root, root.path_join("slots"), slot, path]:
		if Generations._is_link(checked): return false
	if not inventory_profile: return not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path)
	if DirAccess.dir_exists_absolute(path): return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var size: int = file.get_length()
	if size < 1 or size > ProfileMarker.MAX_BYTES:
		file.close()
		return false
	var bytes: PackedByteArray = file.get_buffer(size)
	var error: int = file.get_error()
	var final_size: int = file.get_length()
	file.close()
	if bytes.size() != size or final_size != size or error not in [OK, ERR_FILE_EOF]: return false
	var text: String = bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes or text.sha256_text() != scope["profile_marker_sha256"]: return false
	return ProfileMarker.decode_text(text, scope["slot_id"]).get("ok", false)

static func paths(slot_id: String, session_id: String) -> Dictionary:
	if not Close._hex(slot_id, 32) or not Close._hex(session_id, 32):
		return {}
	var slot: String = ProjectSettings.globalize_path(ROOT.path_join("slots").path_join(slot_id))
	var session: String = ProjectSettings.globalize_path(ROOT.path_join("sessions").path_join(session_id))
	return {"world_directory": slot.path_join("world"), "identity_path": slot.path_join("identity.json"), "session_directory": session, "server_report": session.path_join("server_owner.json"), "server_stop": session.path_join("server.stop"), "client_report": session.path_join("client_owner.json"), "client_stop": session.path_join("client.stop"), "manifest": session.path_join("local_session.json"), "heartbeat": session.path_join("owner_alive.json"), "heartbeat_directory": session.path_join("owner_alive"), "abort": session.path_join("owner_abort.json")}

static func scoped_path(scope: Dictionary, value: String) -> String:
	if scope.is_empty():
		return ""
	for field in ["world_directory", "identity_path", "server_report", "server_stop", "client_report", "client_stop", "manifest"]:
		if value == scope[field]:
			return value
	return ""

static func settings() -> Dictionary:
	var loaded := read_json("res://data/local_session_settings011.json", CONTROL_BYTES)
	if not loaded.get("ok", false):
		return {}
	var document: Dictionary = loaded["value"]
	for field in ["project", "artifact_kind", "version"]:
		if not document.get(field) is String:
			return {}
	if not exact_integer(document.get("schema_version"), 1):
		return {}
	if document.get("project") != "shaheyouxi_experiment_20261004" or document.get("artifact_kind") != "local_session_technical_settings" or document.get("schema_version") != 1 or document.get("version") != "011.ordinary.1" or not document.get("values") is Dictionary:
		return {}
	var values: Dictionary = document["values"]
	if values.size() != VALUE_FIELDS.size():
		return {}
	for field in VALUE_FIELDS:
		if typeof(values.get(field)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(values[field])) or float(values[field]) <= 0.0:
			return {}
	if values["owner_timeout_seconds"] <= values["heartbeat_interval_seconds"] or values["close_timeout_seconds"] <= values["owner_timeout_seconds"]:
		return {}
	return values.duplicate(true)

static func read_json(path: String, limit: int = CONTROL_BYTES) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var error: int = FileAccess.get_open_error()
		return {"ok": false, "missing": error in [ERR_FILE_NOT_FOUND, ERR_DOES_NOT_EXIST], "code": "LOCAL_FILE_MISSING_OR_UNREADABLE"}
	var size: int = file.get_length()
	if size <= 0 or size > limit:
		file.close()
		return {"ok": false, "code": "LOCAL_FILE_SIZE"}
	var bytes: PackedByteArray = file.get_buffer(size)
	var error: int = file.get_error()
	var final_size: int = file.get_length()
	file.close()
	if bytes.size() != size or final_size != size or error not in [OK, ERR_FILE_EOF]:
		return {"ok": false, "code": "LOCAL_FILE_READ"}
	var text: String = bytes.get_string_from_utf8()
	var parser := JSON.new()
	if text.to_utf8_buffer() != bytes or parser.parse(text) != OK or not parser.data is Dictionary:
		return {"ok": false, "code": "LOCAL_FILE_FORMAT"}
	return {"ok": true, "value": parser.data}

static func write_json(path: String, value: Dictionary) -> bool:
	var text := JSON.stringify(value, "", true, true)
	if text.to_utf8_buffer().size() > CONTROL_BYTES:
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var okay: bool = file.get_error() == OK
	file.close()
	return okay and DirAccess.rename_absolute(path + ".tmp", path) == OK

static func exact_integer(value: Variant, minimum: int = 0) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and floorf(float(value)) == float(value) and float(value) >= minimum and float(value) <= 9007199254740991.0

static func report_root(scope: Dictionary) -> String:
	return scope["session_directory"].path_join("server_reports_v1")

static func next_report_stage(current: String, report: Dictionary, request_result: Dictionary) -> Dictionary:
	if current not in ["", "startup", "close_cursor", "terminal"] or not report.get("status") is String:
		return {"ok": false, "code": "LOCAL_REPORT_STAGE_INVALID"}
	if current == "terminal":
		return {"ok": true, "skip": true}
	if report["status"] in ["normal_shutdown", "failed", "startup_cancelled"]:
		return {"ok": true, "stage": "terminal"}
	if report["status"] != "server_ready":
		return {"ok": false, "code": "LOCAL_REPORT_STATUS_INVALID"}
	if current.is_empty():
		return {"ok": true, "stage": "startup"}
	if current == "close_cursor" or request_result.get("missing", false):
		return {"ok": true, "skip": true}
	if not request_result.get("ok", false):
		return {"ok": false, "code": "LOCAL_REPORT_REQUEST_INVALID"}
	var covered := server_covers_request(report, request_result["request"])
	if covered.get("pending", false):
		return {"ok": true, "skip": true}
	return {"ok": true, "stage": "close_cursor"} if covered.get("ok", false) else covered

static func report_store(scope: Dictionary) -> Dictionary:
	var store := Generations.new()
	var configured := store.configure(report_root(scope), "local_report_v1", ["server"])
	return {"ok": true, "store": store} if configured.get("ok", false) else configured

static func encode_report(report: Dictionary, stage: String, sequence: int, scope: Dictionary, server_pid: int) -> Dictionary:
	var value := {"format": "owned_server_report_v1", "schema_version": 1, "session_id": scope["session_id"], "slot_id": scope["slot_id"], "owner_nonce": scope["owner_nonce"], "server_pid": server_pid, "sequence": sequence, "stage": stage, "report": report}
	var encoded := Codec.encode(value)
	return {"ok": true, "text": JSON.stringify(encoded["value"], "", true, true)} if encoded.get("ok", false) else encoded

static func validate_report(text: String, scope: Dictionary, server_pid: int) -> Dictionary:
	var parser := JSON.new()
	if text.to_utf8_buffer().size() > REPORT_BYTES or parser.parse(text) != OK or JSON.stringify(parser.data, "", true, true) != text:
		return {"ok": false, "code": "LOCAL_REPORT_FORMAT"}
	var decoded := Codec.decode(parser.data)
	if not decoded.get("ok", false) or not Generations._fields(decoded.get("value"), ["format", "schema_version", "session_id", "slot_id", "owner_nonce", "server_pid", "sequence", "stage", "report"]):
		return {"ok": false, "code": "LOCAL_REPORT_FIELDS"}
	var value: Dictionary = decoded["value"]
	for field in ["format", "session_id", "slot_id", "owner_nonce", "stage"]:
		if not value[field] is String:
			return {"ok": false, "code": "LOCAL_REPORT_TYPES"}
	if typeof(value["schema_version"]) != TYPE_INT or value["schema_version"] != 1 or value["format"] != "owned_server_report_v1" or typeof(value["server_pid"]) != TYPE_INT or value["server_pid"] != server_pid or typeof(value["sequence"]) != TYPE_INT or not exact_integer(value["sequence"], 1) or value["stage"] not in ["startup", "close_cursor", "terminal"] or not value["report"] is Dictionary or not value["report"].get("status") is String:
		return {"ok": false, "code": "LOCAL_REPORT_BINDING"}
	for field in ["session_id", "slot_id", "owner_nonce"]:
		if value[field] != scope[field]:
			return {"ok": false, "code": "LOCAL_REPORT_BINDING"}
	var status: String = value["report"]["status"]
	if (value["stage"] == "terminal" and status not in ["normal_shutdown", "failed", "startup_cancelled"]) or (value["stage"] != "terminal" and status != "server_ready"):
		return {"ok": false, "code": "LOCAL_REPORT_STAGE"}
	return {"ok": true, "sequence": value["sequence"], "stage": value["stage"], "report": value["report"]}

static func report_layout_pending(scope: Dictionary) -> bool:
	var root := report_root(scope)
	if Generations._is_link(root) or FileAccess.file_exists(root):
		return false
	if not DirAccess.dir_exists_absolute(root):
		return true
	if Generations._exists(root.path_join("layout.json")):
		return false
	var listed := Generations._directory_entries(root, 1)
	if not listed.get("ok", false):
		return false
	for entry in listed["entries"]:
		if entry["directory"] or entry["name"] != "layout.tmp" or Generations._is_link(root.path_join(entry["name"])):
			return false
	return true

static func read_close_request(scope: Dictionary, server_pid: int, world_id: String, server_epoch: String) -> Dictionary:
	if scope.has("save_profile"):
		if typeof(scope["save_profile"]) != TYPE_INT or scope["save_profile"] != 5: return {"ok": false, "code": "LOCAL_INVENTORY_PROFILE_CHANGED"}
		return read_inventory_close_request(scope, server_pid, world_id, server_epoch)
	var loaded := read_json(scope["session_directory"].path_join("client_close.request.json"))
	if not loaded.get("ok", false):
		return loaded
	var value: Dictionary = loaded["value"]
	var extra := ["client_pid", "peer_id", "player_profile_id", "player_instance_id", "input_generation", "accepted_sequence", "actor_revision", "cutoff_sequence", "pending_count", "intent_count"]
	if not Generations._fields(value, Close.OWNED_MANIFEST_FIELDS + extra):
		return {"ok": false, "code": "LOCAL_CLOSE_REQUEST_FIELDS"}
	for field in ["schema_version", "save_schema", "server_pid", "owner_pid", "client_pid", "peer_id", "input_generation", "accepted_sequence", "actor_revision", "cutoff_sequence", "pending_count", "intent_count"]:
		if not exact_integer(value[field]):
			return {"ok": false, "code": "LOCAL_CLOSE_REQUEST_TYPES"}
		value[field] = int(value[field])
	var manifest: Dictionary = {}
	for field in Close.OWNED_MANIFEST_FIELDS:
		manifest[field] = value[field]
	var state := Close.new()
	if not state.configure_owned(manifest, scope["session_id"], scope["owner_pid"]).get("ok", false):
		return {"ok": false, "code": "LOCAL_CLOSE_REQUEST_SCOPE"}
	for field in ["slot_id", "session_id", "owner_nonce", "owner_pid"]:
		if value[field] != scope[field]:
			return {"ok": false, "code": "LOCAL_CLOSE_REQUEST_SCOPE"}
	if value["server_pid"] != server_pid or value["client_pid"] != scope["owner_pid"] or value["world_id"] != world_id or value["server_epoch"] != server_epoch or not SandboxServerAuthority._valid_id(value["player_profile_id"], "player_") or not SandboxServerAuthority._valid_id(value["player_instance_id"], "entity_player_") or value["peer_id"] <= 1 or value["input_generation"] < 1 or value["pending_count"] != 0 or value["accepted_sequence"] < value["cutoff_sequence"] or value["intent_count"] < value["cutoff_sequence"]:
		return {"ok": false, "code": "LOCAL_CLOSE_REQUEST_UNCONFIRMED"}
	return {"ok": true, "request": value}

static func read_inventory_close_request(scope: Dictionary, server_pid: int, world_id: String, server_epoch: String) -> Dictionary:
	if typeof(scope.get("save_profile")) != TYPE_INT or scope["save_profile"] != 5 or not profile_marker_matches(scope):
		return {"ok": false, "code": "LOCAL_INVENTORY_PROFILE_CHANGED"}
	var loaded := read_json(scope["session_directory"].path_join("client_close.request.json"))
	if not loaded.get("ok", false): return loaded
	var value: Dictionary = loaded["value"]
	var actor_fields := ["client_pid", "peer_id", "player_profile_id", "player_instance_id", "input_generation", "accepted_sequence", "actor_revision", "cutoff_sequence", "pending_count", "intent_count"]
	if not Generations._fields(value, Close.INVENTORY_OWNED_MANIFEST_FIELDS + actor_fields + Close.INVENTORY_REQUEST_EXTRA_FIELDS):
		return {"ok": false, "code": "LOCAL_CLOSE_REQUEST_FIELDS"}
	for field in ["schema_version", "save_schema", "server_pid", "owner_pid", "client_pid", "peer_id", "input_generation", "accepted_sequence", "actor_revision", "cutoff_sequence", "pending_count", "intent_count"] + Close.INVENTORY_REQUEST_EXTRA_FIELDS:
		if not exact_integer(value[field]): return {"ok": false, "code": "LOCAL_CLOSE_REQUEST_TYPES"}
		value[field] = int(value[field])
	var manifest: Dictionary = {}
	for field in Close.INVENTORY_OWNED_MANIFEST_FIELDS: manifest[field] = value[field]
	var state := Close.new()
	if not state.configure_owned_inventory(manifest, scope["session_id"], scope["owner_pid"]).get("ok", false):
		return {"ok": false, "code": "LOCAL_CLOSE_REQUEST_SCOPE"}
	for field in ["slot_id", "session_id", "owner_nonce", "owner_pid", "profile_marker_sha256"]:
		if typeof(value[field]) != typeof(scope[field]) or value[field] != scope[field]: return {"ok": false, "code": "LOCAL_CLOSE_REQUEST_SCOPE"}
	if value["server_pid"] != server_pid or value["client_pid"] != scope["owner_pid"] or value["world_id"] != world_id or value["server_epoch"] != server_epoch or not SandboxServerAuthority._valid_id(value["player_profile_id"], "player_") or not SandboxServerAuthority._valid_id(value["player_instance_id"], "entity_player_") or value["peer_id"] <= 1 or value["input_generation"] < 1 or value["pending_count"] != 0 or value["accepted_sequence"] != value["cutoff_sequence"] or value["intent_count"] < value["cutoff_sequence"]:
		return {"ok": false, "code": "LOCAL_CLOSE_REQUEST_UNCONFIRMED"}
	if value["inventory_pending_count"] != 0 or value["inventory_processed_sequence"] != value["inventory_cutoff_sequence"] or value["inventory_initial_sequence"] > value["inventory_accepted_sequence"] or value["inventory_accepted_sequence"] > value["inventory_processed_sequence"]:
		return {"ok": false, "code": "LOCAL_INVENTORY_REQUEST_UNCONFIRMED"}
	return {"ok": true, "request": value}

static func _counter_name(name: String) -> bool:
	if not name.begins_with("counter_") or not name.ends_with(".json"):
		return false
	var digits := name.trim_prefix("counter_").trim_suffix(".json")
	if digits.length() != 16:
		return false
	for digit in digits:
		if digit not in "0123456789":
			return false
	return int(digits) > 0 and int(digits) <= 9007199254740991

static func _counter_files(directory: String) -> Dictionary:
	# At steady state there are two completed counters. Publication may briefly
	# add a third before pruning; one unfinished temporary is never a heartbeat.
	var access := DirAccess.open(directory)
	if access == null:
		return {"ok": false, "code": "LOCAL_COUNTER_DIRECTORY_UNREADABLE"}
	access.include_hidden = true
	access.include_navigational = false
	if access.list_dir_begin() != OK:
		return {"ok": false, "code": "LOCAL_COUNTER_DIRECTORY_UNREADABLE"}
	var files: Array[String] = []
	var count: int = 0
	while true:
		var entry: String = access.get_next()
		if entry.is_empty():
			break
		count += 1
		if count > 4:
			access.list_dir_end()
			return {"ok": false, "code": "LOCAL_COUNTER_FILE_LIMIT"}
		if access.is_link(entry) or access.current_is_dir():
			access.list_dir_end()
			return {"ok": false, "code": "LOCAL_COUNTER_ENTRY_INVALID"}
		if entry.ends_with(".tmp") and _counter_name(entry.trim_suffix(".tmp")):
			continue
		if not _counter_name(entry):
			access.list_dir_end()
			return {"ok": false, "code": "LOCAL_COUNTER_FILENAME_INVALID"}
		files.append(entry)
	access.list_dir_end()
	files.sort()
	return {"ok": true, "files": files}

static func write_unique_counter(scope: Dictionary, value: Dictionary) -> bool:
	if not exact_integer(value.get("counter"), 1):
		return false
	var directory: String = scope["heartbeat_directory"]
	var parent := DirAccess.open(directory.get_base_dir())
	if parent == null or parent.is_link(directory.get_file()) or DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false
	if not _counter_files(directory).get("ok", false):
		return false
	var target := directory.path_join("counter_%016d.json" % int(value["counter"]))
	if FileAccess.file_exists(target) or FileAccess.file_exists(target + ".tmp"):
		return false # Never replace an existing Windows target.
	if not write_json(target, value):
		return false
	var read := read_json(target)
	if not read.get("ok", false):
		return false
	var actual: Dictionary = read["value"]
	for field in ["schema_version", "owner_pid", "counter"]:
		if not exact_integer(actual.get(field), 1):
			return false
		actual[field] = int(actual[field])
	if actual != value:
		return false
	var listed := _counter_files(directory)
	if not listed.get("ok", false):
		return false
	var files: Array = listed["files"]
	while files.size() > 2:
		if DirAccess.remove_absolute(directory.path_join(files.pop_front())) != OK:
			return false
	return true

static func read_unique_counter(scope: Dictionary) -> Dictionary:
	var directory: String = scope["heartbeat_directory"]
	if not DirAccess.dir_exists_absolute(directory):
		return {"ok": false, "pending": true}
	var parent := DirAccess.open(directory.get_base_dir())
	if parent == null or parent.is_link(directory.get_file()):
		return {"ok": false, "code": "LOCAL_COUNTER_PATH_INVALID"}
	var listed := _counter_files(directory)
	if not listed.get("ok", false):
		return listed
	var files: Array = listed["files"]
	if files.is_empty():
		return {"ok": false, "pending": true}
	var name: String = files.back()
	var loaded := read_json(directory.path_join(name))
	if loaded.get("missing", false):
		return {"ok": false, "pending": true} # A concurrent prune never renews time.
	if not loaded.get("ok", false):
		return loaded
	if not exact_integer(loaded["value"].get("counter"), 1) or int(loaded["value"]["counter"]) != int(name.trim_prefix("counter_").trim_suffix(".json")):
		return {"ok": false, "code": "LOCAL_COUNTER_CONTENT_INVALID"}
	return loaded

static func _fields_typed(value: Dictionary, fields: Dictionary) -> bool:
	for field in fields:
		if typeof(value.get(field)) != fields[field]:
			return false
	return true

static func server_covers_request(report: Dictionary, request: Dictionary) -> Dictionary:
	if request.has("save_schema") and (typeof(request["save_schema"]) != TYPE_INT or request["save_schema"] not in [4, 5]):
		return {"ok": false, "code": "LOCAL_CLOSE_REQUEST_TYPES"}
	if not _fields_typed(request, {"world_id": TYPE_STRING, "server_epoch": TYPE_STRING, "player_profile_id": TYPE_STRING, "player_instance_id": TYPE_STRING, "peer_id": TYPE_INT, "input_generation": TYPE_INT, "accepted_sequence": TYPE_INT, "actor_revision": TYPE_INT}):
		return {"ok": false, "code": "LOCAL_CLOSE_REQUEST_TYPES"}
	if not _fields_typed(report, {"status": TYPE_STRING, "snapshot": TYPE_DICTIONARY, "live_input_runtime": TYPE_DICTIONARY}) or report["status"] != "server_ready":
		return {"ok": false, "code": "LOCAL_SERVER_CLOSE_STATE_INVALID"}
	var snapshot: Dictionary = report["snapshot"]
	if not _fields_typed(snapshot, {"world_id": TYPE_STRING, "server_epoch": TYPE_STRING, "players": TYPE_DICTIONARY, "actor_public": TYPE_DICTIONARY}) or snapshot["world_id"] != request["world_id"] or snapshot["server_epoch"] != request["server_epoch"]:
		return {"ok": false, "code": "LOCAL_SERVER_CLOSE_IDENTITY"}
	var players: Dictionary = snapshot["players"]
	var motion: Dictionary = snapshot["actor_public"]
	var profile: Variant = request.get("player_profile_id")
	var actor: Variant = request.get("player_instance_id")
	if players.size() != 1 or not players.get(profile) is Dictionary or not motion.get("input_cursors") is Dictionary or not motion["input_cursors"].get(actor) is Dictionary:
		return {"ok": false, "code": "LOCAL_SERVER_CLOSE_ROSTER"}
	var player: Dictionary = players[profile]
	var cursor: Dictionary = motion["input_cursors"][actor]
	var live: Dictionary = report["live_input_runtime"]
	if not _fields_typed(player, {"player_instance_id": TYPE_STRING, "role": TYPE_STRING}) or not _fields_typed(live, {"activated": TYPE_BOOL, "enabled": TYPE_BOOL, "failed": TYPE_BOOL}) or player["player_instance_id"] != actor or player["role"] != "MEMBER" or not exact_integer(player.get("peer_id"), 2) or int(player["peer_id"]) != request["peer_id"] or not exact_integer(cursor.get("input_generation"), 1) or int(cursor["input_generation"]) != request["input_generation"] or not live["activated"] or not live["enabled"] or live["failed"]:
		return {"ok": false, "code": "LOCAL_SERVER_CLOSE_BINDING"}
	if not exact_integer(cursor.get("accepted_sequence")) or not exact_integer(motion.get("revision")):
		return {"ok": false, "code": "LOCAL_SERVER_CLOSE_CURSOR"}
	if int(cursor["accepted_sequence"]) < request["accepted_sequence"] or int(motion["revision"]) < request["actor_revision"]: return {"ok": false, "pending": true}
	return inventory_covers_request(report, request, false) if request.get("save_schema", 4) == 5 else {"ok": true}


static func inventory_covers_request(report: Dictionary, request: Dictionary, terminal: bool) -> Dictionary:
	# Only the ordinary single-MEMBER session is admitted by the surrounding actor
	# proof. This reads the corresponding server report, never a client queue flag.
	if typeof(request.get("save_schema")) != TYPE_INT or request["save_schema"] != 5:
		return {"ok": false, "code": "LOCAL_INVENTORY_PROFILE_REQUIRED"}
	if not report.get("status") is String or report["status"] != ("normal_shutdown" if terminal else "server_ready"):
		return {"ok": false, "code": "LOCAL_INVENTORY_REPORT_STAGE"}
	var runtime: Variant = report.get("inventory_live_runtime")
	if not Generations._fields(runtime, ["contract", "queue_empty", "queued_count", "close_proofs"]) or not runtime["contract"] is String or runtime["contract"] != InventoryLive.CONTRACT or typeof(runtime["queue_empty"]) != TYPE_BOOL or not exact_integer(runtime["queued_count"]) or int(runtime["queued_count"]) > InventoryLive.MAX_QUEUE or not runtime["close_proofs"] is Array or runtime["close_proofs"].size() != 1:
		return {"ok": false, "code": "LOCAL_INVENTORY_REPORT_INVALID"}
	if runtime["queue_empty"] != (int(runtime["queued_count"]) == 0):
		return {"ok": false, "code": "LOCAL_INVENTORY_REPORT_INVALID"}
	var normalized: Dictionary = InventoryLive.normalize_close_proof_json(runtime["close_proofs"][0])
	if not normalized.get("ok", false): return normalized
	var proof: Dictionary = normalized["proof"]
	if proof["queue_empty"] != runtime["queue_empty"]:
		return {"ok": false, "code": "LOCAL_INVENTORY_REPORT_INVALID"}
	var checked: Dictionary = InventoryLive.validate_close_proof(proof, request) if terminal else InventoryLive.validate_request_coverage(proof, request)
	if not checked.get("ok", false): return checked
	return {"ok": true, "proof": proof}
