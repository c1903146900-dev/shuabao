extends RefCounted
## Pure, one-use close coordination for explicit local schema4/schema5 pairs.
## No filesystem, RPC, input generation, process termination or save writes.
const Authority = preload("res://scripts/network/server_authority.gd")
const Inputs = preload("res://scripts/actor/actor_inputs.gd")
const State = preload("res://scripts/actor/actor_state.gd")
const ClientState = preload("res://scripts/actor/actor_client_state.gd")
const CONTRACT := "schema4_local_gui_session_v1"
const MANIFEST_FIELDS := ["schema_version", "contract", "session_id", "server_pid", "server_start_ticks", "server_epoch", "world_id", "save_schema"]
const OWNED_CONTRACT := "schema4_owned_local_session_v1"
const OWNED_MANIFEST_FIELDS := ["schema_version", "contract", "session_id", "slot_id", "server_pid", "owner_pid", "owner_nonce", "server_epoch", "world_id", "save_schema"]
const IDENTITY_FIELDS := ["world_id", "server_epoch", "player_profile_id", "player_instance_id", "peer_id", "input_generation"]
const RECEIPT_EXTRA_FIELDS := ["client_pid", "peer_id", "player_profile_id", "player_instance_id", "input_generation", "cutoff_sequence", "accepted_sequence", "server_exit_code", "server_reaped", "server_group_empty", "writer_lock_released", "main_committed", "complete", "main_sequence", "main_sha256", "reason"]
# Schema5 is explicit. These additions never appear in either legacy contract.
const INVENTORY_OWNED_CONTRACT := "schema5_owned_local_session_v1"
const INVENTORY_OWNED_MANIFEST_FIELDS: Array = ["schema_version", "contract", "session_id", "slot_id", "server_pid", "owner_pid", "owner_nonce", "server_epoch", "world_id", "save_schema", "profile_marker_sha256"]
const INVENTORY_CHECKPOINT_FIELDS: Array = ["world_id", "server_epoch", "player_profile_id", "player_instance_id", "peer_id", "input_generation", "initial_sequence", "issued_sequence", "processed_sequence", "accepted_sequence", "revision", "pending_count"]
const INVENTORY_REQUEST_EXTRA_FIELDS := ["inventory_initial_sequence", "inventory_cutoff_sequence", "inventory_processed_sequence", "inventory_accepted_sequence", "inventory_revision", "inventory_pending_count"]
const INVENTORY_RECEIPT_EXTRA_FIELDS := ["inventory_initial_sequence", "inventory_cutoff_sequence", "inventory_processed_sequence", "inventory_saved_accepted_sequence", "inventory_saved_revision", "inventory_queue_empty"]
var _inventory_required: bool = false
var _inventory_checkpoint: Dictionary = {}
var _inventory_cutoff: int = -1
var ready: bool = false
var _attempted: bool = false
var _phase: String = "unconfigured"
var _manifest: Dictionary = {}
var _client_pid: int = 0
var _identity: Dictionary = {}
var _checkpoint: Dictionary = {}
var _cutoff: int = -1
var _request: Dictionary = {}
var _disconnected: bool = false
var _receipt: Dictionary = {}
var _error: String = ""
var _manifest_fields: Array = MANIFEST_FIELDS.duplicate()
var _receipt_fields: Array = RECEIPT_EXTRA_FIELDS.duplicate()
var _exit_proof_fields: Array = ["server_reaped", "server_group_empty"]

func configure(manifest: Variant, directory_name: String, client_pid: int) -> Dictionary:
	if _attempted:
		return _fail("LOCAL_SESSION_ALREADY_CONFIGURED")
	_attempted = true
	if not State.exact_fields(manifest, MANIFEST_FIELDS):
		return _fail("LOCAL_SESSION_MANIFEST_FIELDS")
	for field in ["schema_version", "server_pid", "server_start_ticks", "save_schema"]:
		if typeof(manifest[field]) != TYPE_INT:
			return _fail("LOCAL_SESSION_MANIFEST_TYPES")
	for field in ["contract", "session_id", "server_epoch", "world_id"]:
		if not manifest[field] is String:
			return _fail("LOCAL_SESSION_MANIFEST_TYPES")
	if manifest["schema_version"] != 1 or manifest["save_schema"] != 4 or manifest["contract"] != CONTRACT or not _hex(manifest["session_id"], 32) or directory_name != "actor011_terrain_play_" + manifest["session_id"] or client_pid <= 1 or manifest["server_pid"] <= 1 or manifest["server_pid"] == client_pid or manifest["server_start_ticks"] <= 0 or not Authority._valid_id(manifest["server_epoch"], "session_") or not Authority._valid_id(manifest["world_id"], "world_"):
		return _fail("LOCAL_SESSION_MANIFEST_BINDING")
	_manifest = manifest.duplicate(true)
	_client_pid = client_pid
	_phase = "running"
	ready = true
	return {"ok": true}

func configure_owned(manifest: Variant, directory_name: String, client_pid: int) -> Dictionary:
	# The ordinary GUI owns one child through Godot's process API. It does not
	# claim Linux process-birth ticks, a PID namespace, or process-group reaping.
	if _attempted:
		return _fail("LOCAL_SESSION_ALREADY_CONFIGURED")
	_attempted = true
	if not State.exact_fields(manifest, OWNED_MANIFEST_FIELDS):
		return _fail("LOCAL_SESSION_MANIFEST_FIELDS")
	for field in ["schema_version", "server_pid", "owner_pid", "save_schema"]:
		if typeof(manifest[field]) != TYPE_INT:
			return _fail("LOCAL_SESSION_MANIFEST_TYPES")
	for field in ["contract", "session_id", "slot_id", "owner_nonce", "server_epoch", "world_id"]:
		if not manifest[field] is String:
			return _fail("LOCAL_SESSION_MANIFEST_TYPES")
	if manifest["schema_version"] != 1 or manifest["contract"] != OWNED_CONTRACT or manifest["save_schema"] != 4 or directory_name != manifest["session_id"] or client_pid <= 1 or manifest["owner_pid"] != client_pid or manifest["server_pid"] <= 1 or manifest["server_pid"] == client_pid or not _hex(manifest["session_id"], 32) or not _hex(manifest["slot_id"], 32) or not _hex(manifest["owner_nonce"], 32) or not Authority._valid_id(manifest["server_epoch"], "session_") or not Authority._valid_id(manifest["world_id"], "world_"):
		return _fail("LOCAL_SESSION_MANIFEST_BINDING")
	_manifest_fields = OWNED_MANIFEST_FIELDS.duplicate()
	_receipt_fields.erase("server_reaped")
	_receipt_fields.erase("server_group_empty")
	_receipt_fields.append("child_exit_observed")
	_exit_proof_fields = ["child_exit_observed"]
	_manifest = manifest.duplicate(true)
	_client_pid = client_pid
	_phase = "running"
	ready = true
	return {"ok": true}

func configure_owned_inventory(manifest: Variant, directory_name: String, client_pid: Variant) -> Dictionary:
	# The canonical marker bytes are checked by the caller's read-only scope.
	# Here their lowercase SHA256 is bound into every request and receipt.
	if _attempted:
		return _fail("LOCAL_SESSION_ALREADY_CONFIGURED")
	_attempted = true
	if not State.exact_fields(manifest, INVENTORY_OWNED_MANIFEST_FIELDS):
		return _fail("LOCAL_SESSION_MANIFEST_FIELDS")
	for field in ["schema_version", "server_pid", "owner_pid", "save_schema"]:
		if not _inventory_integer(manifest[field]):
			return _fail("LOCAL_SESSION_MANIFEST_TYPES")
	for field in ["contract", "session_id", "slot_id", "owner_nonce", "server_epoch", "world_id", "profile_marker_sha256"]:
		if not manifest[field] is String:
			return _fail("LOCAL_SESSION_MANIFEST_TYPES")
	if not _inventory_integer(client_pid):
		return _fail("LOCAL_SESSION_MANIFEST_TYPES")
	if manifest["schema_version"] != 1 or manifest["contract"] != INVENTORY_OWNED_CONTRACT or manifest["save_schema"] != 5 or directory_name != manifest["session_id"] or client_pid <= 1 or manifest["owner_pid"] != client_pid or manifest["server_pid"] <= 1 or manifest["server_pid"] == client_pid or not _hex(manifest["session_id"], 32) or not _hex(manifest["slot_id"], 32) or not _hex(manifest["owner_nonce"], 32) or not _hex(manifest["profile_marker_sha256"], 64) or not Authority._valid_id(manifest["server_epoch"], "session_") or not Authority._valid_id(manifest["world_id"], "world_"):
		return _fail("LOCAL_SESSION_MANIFEST_BINDING")
	_inventory_required = true
	_manifest_fields = INVENTORY_OWNED_MANIFEST_FIELDS.duplicate()
	_receipt_fields.erase("server_reaped")
	_receipt_fields.erase("server_group_empty")
	_receipt_fields.append("child_exit_observed")
	_receipt_fields.append_array(INVENTORY_RECEIPT_EXTRA_FIELDS)
	_exit_proof_fields = ["child_exit_observed"]
	_manifest = manifest.duplicate(true)
	_client_pid = client_pid
	_phase = "running"
	ready = true
	return {"ok": true}

func manifest_matches(value: Variant) -> bool:
	if not ready or not State.exact_fields(value, _manifest_fields):
		return false
	for field in _manifest_fields:
		if typeof(value[field]) != typeof(_manifest[field]) or value[field] != _manifest[field]:
			return false
	return true

func bind_checkpoint(cursor: Variant) -> Dictionary:
	if not ready or _phase in ["failed", "closed"] or not State.exact_fields(cursor, ClientState.INPUT_CHECKPOINT_FIELDS):
		return _fail("LOCAL_SESSION_CHECKPOINT_INVALID")
	for pair in [["world_id", "world_"], ["server_epoch", "session_"], ["player_profile_id", "player_"], ["player_instance_id", "entity_player_"]]:
		if not Authority._valid_id(cursor[pair[0]], pair[1]):
			return _fail("LOCAL_SESSION_CHECKPOINT_INVALID")
	for field in ["peer_id", "input_generation", "accepted_sequence", "actor_revision", "authority_revision"]:
		if typeof(cursor[field]) != TYPE_INT or cursor[field] < 0 or cursor[field] > Inputs.MAX_EXACT_INTEGER:
			return _fail("LOCAL_SESSION_CHECKPOINT_INVALID")
	if cursor["peer_id"] <= 1 or cursor["input_generation"] < 1 or cursor["input_generation"] > cursor["actor_revision"] or not State.valid_clock(cursor["world_seconds"]) or cursor["world_id"] != _manifest["world_id"] or cursor["server_epoch"] != _manifest["server_epoch"]:
		return _fail("LOCAL_SESSION_CHECKPOINT_BINDING")
	var identity: Dictionary = {}
	for field in IDENTITY_FIELDS:
		identity[field] = cursor[field]
	if not _identity.is_empty() and identity != _identity:
		return _fail("LOCAL_SESSION_INPUT_STREAM_CHANGED")
	if not _checkpoint.is_empty() and (cursor["accepted_sequence"] < _checkpoint["accepted_sequence"] or cursor["actor_revision"] < _checkpoint["actor_revision"] or cursor["authority_revision"] < _checkpoint["authority_revision"] or cursor["world_seconds"] < _checkpoint["world_seconds"]):
		return _fail("LOCAL_SESSION_CHECKPOINT_REGRESSION")
	if _inventory_required and _cutoff >= 0 and cursor["accepted_sequence"] > _cutoff:
		return _fail("LOCAL_SESSION_ACTOR_AFTER_CUTOFF")
	_identity = identity
	_checkpoint = cursor.duplicate(true)
	return {"ok": true}

func begin_stop(cursor: Variant, issued_cutoff: int, connected: bool) -> Dictionary:
	if _inventory_required:
		return _fail("LOCAL_SESSION_INVENTORY_PROOF_REQUIRED")
	if not ready or _phase != "running" or not connected:
		return _fail("LOCAL_SESSION_STOP_NOT_READY")
	var checked := bind_checkpoint(cursor)
	if not checked["ok"]:
		return checked
	if issued_cutoff < cursor["accepted_sequence"] or issued_cutoff > Inputs.MAX_EXACT_INTEGER:
		return _fail("LOCAL_SESSION_CUTOFF_INVALID")
	_cutoff = issued_cutoff
	_phase = "draining"
	return {"ok": true, "pending": true}

func poll_release(cursor: Variant, pending_count: int, connected: bool, intent_count: int) -> Dictionary:
	if _inventory_required:
		return _fail("LOCAL_SESSION_INVENTORY_PROOF_REQUIRED")
	if not ready or _phase != "draining" or not connected or _disconnected or pending_count < 0 or intent_count < 0:
		return _fail("LOCAL_SESSION_RELEASE_UNCONFIRMED")
	var checked := bind_checkpoint(cursor)
	if not checked["ok"]:
		return checked
	if pending_count != 0 or cursor["accepted_sequence"] < _cutoff:
		return {"ok": false, "pending": true}
	_request = _manifest.duplicate(true)
	_request.merge(_identity, true)
	_request.merge({"client_pid": _client_pid, "accepted_sequence": cursor["accepted_sequence"], "actor_revision": cursor["actor_revision"], "cutoff_sequence": _cutoff, "pending_count": 0, "intent_count": intent_count}, true)
	_phase = "request_ready"
	return {"ok": true, "request": _request.duplicate(true)}

func bind_inventory_checkpoint(cursor: Variant) -> Dictionary:
	# Call at connection start, then on EVERY issue and authoritative reply.
	# The single-flight panel cannot skip its issue transition and bind only at F10.
	if not ready or not _inventory_required or _phase not in ["running", "draining"] or _identity.is_empty() or not State.exact_fields(cursor, INVENTORY_CHECKPOINT_FIELDS):
		return _fail("LOCAL_SESSION_INVENTORY_CHECKPOINT_INVALID")
	for field in IDENTITY_FIELDS:
		if typeof(cursor[field]) != typeof(_identity[field]) or cursor[field] != _identity[field]:
			return _fail("LOCAL_SESSION_INVENTORY_STREAM_CHANGED")
	for field in ["initial_sequence", "issued_sequence", "processed_sequence", "accepted_sequence", "revision", "pending_count"]:
		if not _inventory_integer(cursor[field]):
			return _fail("LOCAL_SESSION_INVENTORY_CHECKPOINT_INVALID")
	if cursor["initial_sequence"] > cursor["accepted_sequence"] or cursor["accepted_sequence"] > cursor["processed_sequence"] or cursor["processed_sequence"] > cursor["issued_sequence"] or cursor["pending_count"] > 1 or cursor["issued_sequence"] - cursor["processed_sequence"] != cursor["pending_count"]:
		return _fail("LOCAL_SESSION_INVENTORY_COUNTER_ORDER")
	if _inventory_checkpoint.is_empty():
		if cursor["initial_sequence"] != cursor["issued_sequence"] or cursor["pending_count"] != 0:
			return _fail("LOCAL_SESSION_INVENTORY_INITIAL_CHECKPOINT_REQUIRED")
	else:
		if cursor["initial_sequence"] != _inventory_checkpoint["initial_sequence"]:
			return _fail("LOCAL_SESSION_INVENTORY_INITIAL_CHANGED")
		for field in ["issued_sequence", "processed_sequence", "accepted_sequence", "revision"]:
			if cursor[field] < _inventory_checkpoint[field]:
				return _fail("LOCAL_SESSION_INVENTORY_CHECKPOINT_REGRESSION")
		var issue_delta: int = cursor["issued_sequence"] - _inventory_checkpoint["issued_sequence"]
		if issue_delta > 1:
			return _fail("LOCAL_SESSION_INVENTORY_ISSUE_JUMP")
		if issue_delta == 1 and (_inventory_checkpoint["pending_count"] != 0 or cursor["pending_count"] != 1 or cursor["processed_sequence"] != _inventory_checkpoint["processed_sequence"]):
			return _fail("LOCAL_SESSION_INVENTORY_ISSUE_ORDER")
		if cursor["processed_sequence"] == _inventory_checkpoint["processed_sequence"] and cursor["accepted_sequence"] != _inventory_checkpoint["accepted_sequence"]:
			return _fail("LOCAL_SESSION_INVENTORY_ACCEPTED_WITHOUT_REPLY")
		if cursor["accepted_sequence"] > _inventory_checkpoint["accepted_sequence"] and cursor["revision"] <= _inventory_checkpoint["revision"]:
			return _fail("LOCAL_SESSION_INVENTORY_ACCEPTED_WITHOUT_REVISION")
	if _inventory_cutoff >= 0 and cursor["issued_sequence"] != _inventory_cutoff:
		return _fail("LOCAL_SESSION_INVENTORY_AFTER_CUTOFF")
	_inventory_checkpoint = cursor.duplicate(true)
	return {"ok": true}

func begin_stop_inventory(cursor: Variant, issued_cutoff: Variant, connected: Variant, inventory_cursor: Variant) -> Dictionary:
	if not ready or not _inventory_required or _phase != "running" or typeof(connected) != TYPE_BOOL or not connected:
		return _fail("LOCAL_SESSION_STOP_NOT_READY")
	if not _inventory_integer(issued_cutoff):
		return _fail("LOCAL_SESSION_CUTOFF_INVALID")
	var checked := bind_checkpoint(cursor)
	if not checked["ok"]:
		return checked
	checked = bind_inventory_checkpoint(inventory_cursor)
	if not checked["ok"]:
		return checked
	if issued_cutoff < cursor["accepted_sequence"]:
		return _fail("LOCAL_SESSION_CUTOFF_INVALID")
	_cutoff = issued_cutoff
	_inventory_cutoff = inventory_cursor["issued_sequence"]
	_phase = "draining"
	return {"ok": true, "pending": true}

func poll_release_inventory(cursor: Variant, pending_count: Variant, connected: Variant, intent_count: Variant, inventory_cursor: Variant) -> Dictionary:
	if not ready or not _inventory_required or _phase != "draining" or typeof(connected) != TYPE_BOOL or not connected or _disconnected or not _inventory_integer(pending_count) or not _inventory_integer(intent_count):
		return _fail("LOCAL_SESSION_RELEASE_UNCONFIRMED")
	var checked := bind_checkpoint(cursor)
	if not checked["ok"]:
		return checked
	checked = bind_inventory_checkpoint(inventory_cursor)
	if not checked["ok"]:
		return checked
	if intent_count < _cutoff:
		return _fail("LOCAL_SESSION_CUTOFF_INVALID")
	if pending_count != 0 or cursor["accepted_sequence"] < _cutoff or inventory_cursor["pending_count"] != 0 or inventory_cursor["processed_sequence"] != _inventory_cutoff:
		return {"ok": false, "pending": true}
	_request = _manifest.duplicate(true)
	_request.merge(_identity, true)
	_request.merge({"client_pid": _client_pid, "accepted_sequence": cursor["accepted_sequence"], "actor_revision": cursor["actor_revision"], "cutoff_sequence": _cutoff, "pending_count": 0, "intent_count": intent_count}, true)
	_request.merge({"inventory_initial_sequence": inventory_cursor["initial_sequence"], "inventory_cutoff_sequence": _inventory_cutoff, "inventory_processed_sequence": inventory_cursor["processed_sequence"], "inventory_accepted_sequence": inventory_cursor["accepted_sequence"], "inventory_revision": inventory_cursor["revision"], "inventory_pending_count": 0}, true)
	_phase = "request_ready"
	return {"ok": true, "request": _request.duplicate(true)}

func mark_request_written() -> Dictionary:
	if not ready or _phase != "request_ready" or _request.is_empty():
		return _fail("LOCAL_SESSION_REQUEST_ORDER_INVALID")
	_phase = "waiting_server"
	return {"ok": true}

func expected_disconnect() -> bool:
	return ready and _phase == "waiting_server" and not _request.is_empty()

func observe_disconnect() -> Dictionary:
	if not expected_disconnect() or _disconnected:
		return _fail("LOCAL_SESSION_UNEXPECTED_DISCONNECT")
	_disconnected = true
	if not _receipt.is_empty():
		_phase = "close_ready"
	return {"ok": true, "close_ready": _phase == "close_ready"}

func accept_receipt(value: Variant) -> Dictionary:
	var fields: Array = _manifest_fields + _receipt_fields
	if not ready or _phase != "waiting_server" or not _receipt.is_empty() or not State.exact_fields(value, fields):
		return _fail("LOCAL_SESSION_RECEIPT_ORDER_OR_FIELDS")
	if _inventory_required:
		var inventory_checked := _validate_inventory_receipt(value)
		if not inventory_checked["ok"]:
			return inventory_checked
	for field in _manifest_fields:
		if typeof(value[field]) != typeof(_manifest[field]) or value[field] != _manifest[field]:
			return _fail("LOCAL_SESSION_RECEIPT_SCOPE")
	for field in ["client_pid", "peer_id", "input_generation", "cutoff_sequence", "accepted_sequence", "server_exit_code", "main_sequence"]:
		if typeof(value[field]) != TYPE_INT:
			return _fail("LOCAL_SESSION_RECEIPT_TYPES")
	for field in ["player_profile_id", "player_instance_id", "main_sha256", "reason"]:
		if not value[field] is String:
			return _fail("LOCAL_SESSION_RECEIPT_TYPES")
	for field in _exit_proof_fields + ["writer_lock_released", "main_committed", "complete"]:
		if typeof(value[field]) != TYPE_BOOL or not value[field]:
			return _fail("LOCAL_SESSION_SERVER_SAVE_UNPROVEN")
	for field in ["peer_id", "player_profile_id", "player_instance_id", "input_generation"]:
		if value[field] != _identity[field]:
			return _fail("LOCAL_SESSION_RECEIPT_BINDING")
	if value["client_pid"] != _client_pid or value["cutoff_sequence"] != _cutoff or value["accepted_sequence"] < _cutoff or value["accepted_sequence"] > Inputs.MAX_EXACT_INTEGER or value["server_exit_code"] != 0 or value["main_sequence"] < 1 or value["main_sequence"] > Inputs.MAX_EXACT_INTEGER or not _hex(value["main_sha256"], 64) or value["reason"] != "normal_shutdown":
		return _fail("LOCAL_SESSION_SERVER_SAVE_UNPROVEN")
	_receipt = value.duplicate(true)
	if _disconnected:
		_phase = "close_ready"
	return {"ok": true, "close_ready": _phase == "close_ready"}

func can_close() -> bool:
	return ready and _phase == "close_ready" and _disconnected and not _receipt.is_empty()

func mark_closed() -> Dictionary:
	if not can_close():
		return _fail("LOCAL_SESSION_CLOSE_UNPROVEN")
	_phase = "closed"
	return {"ok": true}

func statistics() -> Dictionary:
	return {"phase": _phase, "cutoff_sequence": _cutoff, "accepted_sequence": _checkpoint.get("accepted_sequence", -1), "request_written": not _request.is_empty() and _phase in ["waiting_server", "close_ready", "closed"], "server_disconnect_observed": _disconnected, "save_receipt_verified": not _receipt.is_empty(), "main_sequence": _receipt.get("main_sequence", -1), "error": _error}

func _validate_inventory_receipt(value: Dictionary) -> Dictionary:
	# Only the owning coordinator may construct this from inspected saved bytes,
	# the matching drained server queue, and actual child exit. No I/O occurs here.
	for field in ["client_pid", "peer_id", "input_generation", "cutoff_sequence", "accepted_sequence", "server_exit_code", "main_sequence", "inventory_initial_sequence", "inventory_cutoff_sequence", "inventory_processed_sequence", "inventory_saved_accepted_sequence", "inventory_saved_revision"]:
		if not _inventory_integer(value[field]):
			return _fail("LOCAL_SESSION_RECEIPT_TYPES")
	if typeof(value["inventory_queue_empty"]) != TYPE_BOOL or not value["inventory_queue_empty"]:
		return _fail("LOCAL_SESSION_INVENTORY_SAVE_UNPROVEN")
	if value["accepted_sequence"] != _request["accepted_sequence"] or value["inventory_initial_sequence"] != _request["inventory_initial_sequence"] or value["inventory_cutoff_sequence"] != _inventory_cutoff or value["inventory_processed_sequence"] != _inventory_cutoff or value["inventory_saved_accepted_sequence"] != _request["inventory_accepted_sequence"] or value["inventory_saved_accepted_sequence"] < value["inventory_initial_sequence"] or value["inventory_saved_accepted_sequence"] > value["inventory_processed_sequence"] or value["inventory_saved_revision"] < _request["inventory_revision"]:
		return _fail("LOCAL_SESSION_INVENTORY_SAVE_UNPROVEN")
	return {"ok": true}

func inventory_statistics() -> Dictionary:
	# A separate diagnostic keeps the exact legacy statistics dictionary intact.
	if not _inventory_required:
		return {}
	return {"initial_sequence": _inventory_checkpoint.get("initial_sequence", -1), "issued_sequence": _inventory_checkpoint.get("issued_sequence", -1), "processed_sequence": _inventory_checkpoint.get("processed_sequence", -1), "accepted_sequence": _inventory_checkpoint.get("accepted_sequence", -1), "revision": _inventory_checkpoint.get("revision", -1), "pending_count": _inventory_checkpoint.get("pending_count", -1), "cutoff_sequence": _inventory_cutoff}

static func _inventory_integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value <= Inputs.MAX_EXACT_INTEGER

func _fail(code: String) -> Dictionary:
	_error = code
	_phase = "failed"
	ready = false
	return {"ok": false, "code": code}

static func _hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for letter in value:
		if letter not in "0123456789abcdef":
			return false
	return true
