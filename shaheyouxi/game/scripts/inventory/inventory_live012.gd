extends RefCounted
## Bounded transport bookkeeping used by the actual schema5 leaves. No state
## grants, authority selection, persistence, clocks, sockets or retry policy.
const State = preload("res://scripts/actor/actor_state.gd")
const Authority = preload("res://scripts/network/server_authority.gd")
const MAX_SEQUENCE := 9007199254740991
const CAPACITIES := {"bag": 40, "hotbar": 10, "chest": 30}
const CONTRACT := "sandbox012-inventory-live-v1"
const IDENTITY: Array = ["world_id", "server_epoch", "player_profile_id", "player_instance_id", "peer_id", "input_generation"]
const BASE: Array = ["schema_version", "contract", "world_id", "server_epoch", "player_profile_id", "player_instance_id", "peer_id", "input_generation"]
const CONTROL: Array = ["kind", "request_id", "context_epoch"]
const LEFT: Array = ["kind", "request_id", "context_epoch", "sequence", "expected_revision", "address"]
const DROP: Array = ["kind", "request_id", "context_epoch", "sequence", "expected_revision", "address", "drop_kind", "aim"]
const REPLY: Array = ["kind", "request_id", "context_epoch", "sequence", "initial_sequence", "processed_sequence", "accepted_sequence", "revision", "ok", "code", "authoritative", "durable", "view"]
const PROOF: Array = ["ok", "world_id", "server_epoch", "player_profile_id", "player_instance_id", "peer_id", "input_generation", "initial_sequence", "cutoff_sequence", "processed_sequence", "accepted_sequence", "revision", "queue_empty", "stopping"]
const MAX_REQUEST_BYTES := 2048
const MAX_PROOFS := 64
const MAX_QUEUE := 64
const MAX_QUEUE_BYTES := 131072
const MAX_CONTROLS := 8
var _role: String = ""
var _stopping: bool = false
var _failed: bool = false
var _streams: Dictionary = {}
var _queue: Array = []
var _queue_bytes: int = 0
var _identity: Dictionary = {}
var _transport: Dictionary = {}
var _client_pending: Array = []
var _client_request_id: int = 0
var _initial: int = -1
var _issued: int = -1
var _processed: int = -1
var _accepted: int = -1
var _revision: int = -1
var _view_sequence: int = -1

static func counter(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value <= MAX_SEQUENCE

static func identity_valid(value: Variant) -> bool:
	if not _fields(value, IDENTITY): return false
	for pair in [["world_id", "world_"], ["server_epoch", "session_"], ["player_profile_id", "player_"], ["player_instance_id", "entity_player_"]]:
		if not Authority._valid_id(value[pair[0]], pair[1]): return false
	return typeof(value["peer_id"]) == TYPE_INT and value["peer_id"] > 0 and value["peer_id"] <= 2147483647 and counter(value["input_generation"]) and value["input_generation"] > 0

static func identity_of(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in IDENTITY:
		if not value.has(field): return {}
		result[field] = value[field]
	return result

static func validate_request(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("kind") is String or value["kind"] not in ["view", "close", "left", "drop"]: return bad("INVENTORY_WIRE_KIND")
	if not _fields(value, BASE + (DROP if value["kind"] == "drop" else (LEFT if value["kind"] == "left" else CONTROL))): return bad("INVENTORY_WIRE_FIELDS")
	if typeof(value["schema_version"]) != TYPE_INT or value["schema_version"] != 1 or not value["contract"] is String or value["contract"] != CONTRACT or not identity_valid(identity_of(value)): return bad("INVENTORY_WIRE_IDENTITY")
	if not counter(value["request_id"]) or value["request_id"] < 1 or not counter(value["context_epoch"]): return bad("INVENTORY_WIRE_COUNTER")
	if value["kind"] in ["left", "drop"]:
		if not counter(value["sequence"]) or value["sequence"] < 1 or not counter(value["expected_revision"]): return bad("INVENTORY_WIRE_COUNTER")
		var address: Variant = value["address"]
		if not _fields(address, ["container", "owner", "slot"]) or not address["container"] is String or not CAPACITIES.has(address["container"]) or not _id(address["owner"]) or typeof(address["slot"]) != TYPE_INT: return bad("INVENTORY_WIRE_ADDRESS")
		if address["slot"] < 0 or address["slot"] >= CAPACITIES[address["container"]]: return bad("INVENTORY_WIRE_ADDRESS")
		if address["container"] != "chest" and address["owner"] != value["player_profile_id"]: return bad("INVENTORY_WIRE_ADDRESS")
	if value["kind"] == "drop":
		if not value["drop_kind"] is String or value["drop_kind"] not in ["q_one", "carry_all", "right_half"] or not State.valid_pair(value["aim"]): return bad("INVENTORY_WIRE_DROP")
	if var_to_bytes(value).size() > MAX_REQUEST_BYTES: return bad("INVENTORY_WIRE_BYTES")
	return {"ok": true}

func bind_server(identity: Dictionary, transport: Dictionary, accepted: Variant, revision: Variant) -> Dictionary:
	if _role not in ["", "server"] or _stopping or _failed or not identity_valid(identity) or transport.is_empty() or not counter(accepted) or not counter(revision) or _streams.has(identity["peer_id"]) or _streams.size() >= MAX_QUEUE: return bad("INVENTORY_STREAM_BINDING")
	_role = "server"
	_streams[identity["peer_id"]] = {"identity": identity.duplicate(true), "transport": transport.duplicate(true), "initial": accepted, "received": accepted, "processed": accepted, "accepted": accepted, "revision": revision, "request_id": 0, "view_sequence": 0, "controls": 0, "cutoff": -1}
	return {"ok": true}

func admit_server(peer: int, request: Variant, identity: Dictionary, transport: Dictionary) -> Dictionary:
	if _role != "server" or _stopping or _failed or not _streams.has(peer): return bad("INVENTORY_STREAM_CLOSED")
	var checked := validate_request(request)
	if not checked["ok"]: return checked
	var stream: Dictionary = _streams[peer]
	if identity != stream["identity"] or identity_of(request) != identity or transport != stream["transport"] or identity["peer_id"] != peer: return bad("INVENTORY_STREAM_CHANGED")
	if stream["request_id"] >= MAX_SEQUENCE or request["request_id"] != stream["request_id"] + 1: return bad("INVENTORY_REQUEST_ORDER")
	if request["kind"] in ["left", "drop"]:
		if stream["received"] != stream["processed"] or stream["received"] >= MAX_SEQUENCE or request["sequence"] != stream["received"] + 1: return bad("INVENTORY_SEQUENCE_ORDER")
	elif stream["controls"] >= MAX_CONTROLS: return bad("INVENTORY_CONTROL_BUDGET")
	var event := {"peer": peer, "request": request.duplicate(true), "identity": identity.duplicate(true), "transport": transport.duplicate(true), "bytes": 0}
	var size: int = var_to_bytes(event).size()
	if _queue.size() >= MAX_QUEUE or _queue_bytes + size > MAX_QUEUE_BYTES: return bad("INVENTORY_QUEUE_BUDGET")
	event["bytes"] = size
	_queue.append(event)
	_queue_bytes += size
	stream["request_id"] = request["request_id"]
	if request["kind"] in ["left", "drop"]: stream["received"] = request["sequence"]
	else: stream["controls"] += 1
	return {"ok": true, "queued": true}

func head_server() -> Dictionary:
	return _queue[0].duplicate(true) if _role == "server" and not _failed and not _queue.is_empty() else {}

func validate_head_server(identity: Dictionary, transport: Dictionary) -> Dictionary:
	if _queue.is_empty() or _failed: return bad("INVENTORY_QUEUE_EMPTY")
	var event: Dictionary = _queue[0]
	var peer: int = event["peer"]
	if not _streams.has(peer) or identity != event["identity"] or transport != event["transport"] or identity != _streams[peer]["identity"] or transport != _streams[peer]["transport"] or not validate_request(event["request"])["ok"] or var_to_bytes(event).size() != event["bytes"]: return bad("INVENTORY_DEQUEUE_CONTEXT")
	if _stopping and event["request"]["kind"] in ["left", "drop"] and event["request"]["sequence"] > _streams[peer]["cutoff"]: return bad("INVENTORY_AFTER_CUTOFF")
	return {"ok": true}

func next_view_sequence(peer: int) -> int:
	return _streams[peer]["view_sequence"] + 1 if _streams.has(peer) and _streams[peer]["view_sequence"] < MAX_SEQUENCE else -1

func complete_server(result: Dictionary, view: Dictionary) -> Dictionary:
	if _queue.is_empty() or _failed: return bad("INVENTORY_QUEUE_EMPTY")
	var event: Dictionary = _queue[0]
	var request: Dictionary = event["request"]
	var stream: Dictionary = _streams[event["peer"]]
	if not _view_header_valid(view, stream["identity"]) or view["view_sequence"] != next_view_sequence(event["peer"]) or typeof(result.get("ok")) != TYPE_BOOL: return bad("INVENTORY_REPLY_VIEW")
	var accepted: int = view["inventory"]["last_sequence"]
	var revision: int = view["revision"]
	var is_left: bool = request["kind"] in ["left", "drop"]
	if accepted < stream["accepted"] or revision < stream["revision"] or (not is_left and accepted != stream["accepted"]): return bad("INVENTORY_REPLY_CURSOR")
	if is_left:
		if request["sequence"] != stream["processed"] + 1 or (result["ok"] and (accepted != request["sequence"] or revision <= stream["revision"])) or (not result["ok"] and accepted != stream["accepted"]): return bad("INVENTORY_REPLY_CURSOR")
		stream["processed"] = request["sequence"] # Valid rejection retires transport only.
	else: stream["controls"] -= 1
	stream["accepted"] = accepted
	stream["revision"] = revision
	stream["view_sequence"] = view["view_sequence"]
	var reply: Dictionary = stream["identity"].duplicate(true)
	reply.merge({"schema_version": 1, "contract": CONTRACT, "kind": request["kind"], "request_id": request["request_id"], "context_epoch": request["context_epoch"], "sequence": request.get("sequence", 0), "initial_sequence": stream["initial"], "processed_sequence": stream["processed"], "accepted_sequence": accepted, "revision": revision, "ok": result["ok"], "code": str(result.get("code", "")), "authoritative": true, "durable": false, "view": view.duplicate(true)})
	_queue_bytes -= event["bytes"]
	_queue.pop_front()
	return {"ok": true, "peer_id": event["peer"], "reply": reply}

func stop_server() -> void:
	if _stopping: return
	_stopping = true
	for stream in _streams.values(): stream["cutoff"] = stream["received"]

func server_drained() -> bool:
	if _role != "server" or _failed or not _queue.is_empty() or _queue_bytes != 0: return false
	for stream in _streams.values():
		if stream["controls"] != 0 or stream["received"] != stream["processed"] or (_stopping and stream["processed"] != stream["cutoff"]): return false
	return true

func server_proof(peer: int, actual_view: Dictionary) -> Dictionary:
	if not _streams.has(peer): return {}
	var stream: Dictionary = _streams[peer]
	if not _view_header_valid(actual_view, stream["identity"]) or actual_view["inventory"]["last_sequence"] != stream["accepted"] or actual_view["revision"] < stream["revision"]: return {}
	var proof: Dictionary = stream["identity"].duplicate(true)
	proof.merge({"ok": true, "initial_sequence": stream["initial"], "cutoff_sequence": stream["cutoff"], "processed_sequence": stream["processed"], "accepted_sequence": stream["accepted"], "revision": actual_view["revision"], "queue_empty": server_drained(), "stopping": _stopping})
	return proof

static func validate_close_proof(proof: Variant, request: Dictionary) -> Dictionary:
	if not _fields(proof, PROOF) or not identity_valid(identity_of(proof)): return bad("INVENTORY_CLOSE_PROOF_FIELDS")
	for key in ["ok", "queue_empty", "stopping"]:
		if typeof(proof[key]) != TYPE_BOOL or not proof[key]: return bad("INVENTORY_CLOSE_NOT_DRAINED")
	for key in ["initial_sequence", "cutoff_sequence", "processed_sequence", "accepted_sequence", "revision"]:
		if not counter(proof[key]): return bad("INVENTORY_CLOSE_PROOF_COUNTER")
	for key in IDENTITY:
		if typeof(request.get(key)) != typeof(proof[key]) or request.get(key) != proof[key]: return bad("INVENTORY_CLOSE_PROOF_IDENTITY")
	for pair in [["initial_sequence", "inventory_initial_sequence"], ["cutoff_sequence", "inventory_cutoff_sequence"], ["processed_sequence", "inventory_processed_sequence"], ["accepted_sequence", "inventory_accepted_sequence"]]:
		if not counter(request.get(pair[1])) or proof[pair[0]] != request[pair[1]]: return bad("INVENTORY_CLOSE_PROOF_MISMATCH")
	if not counter(request.get("inventory_revision")) or typeof(request.get("inventory_pending_count")) != TYPE_INT or request["inventory_pending_count"] != 0 or proof["revision"] < request["inventory_revision"] or proof["initial_sequence"] > proof["accepted_sequence"] or proof["accepted_sequence"] > proof["processed_sequence"] or proof["processed_sequence"] != proof["cutoff_sequence"]: return bad("INVENTORY_CLOSE_PROOF_MISMATCH")
	return {"ok": true}

static func validate_request_coverage(proof: Variant, request: Dictionary) -> Dictionary:
	# A report can lag behind an acknowledged request. Wait within the existing
	# close deadline; regressions in identity/initial or any future cursor refuse.
	if not _fields(proof, PROOF) or not identity_valid(identity_of(proof)): return bad("INVENTORY_COVERAGE_FIELDS")
	for field in ["ok", "stopping", "queue_empty"]:
		if typeof(proof[field]) != TYPE_BOOL: return bad("INVENTORY_COVERAGE_TYPES")
	if not proof["ok"] or proof["stopping"] or typeof(proof["cutoff_sequence"]) != TYPE_INT or proof["cutoff_sequence"] != -1: return bad("INVENTORY_COVERAGE_NOT_RUNNING")
	for field in IDENTITY:
		if typeof(request.get(field)) != typeof(proof[field]) or request.get(field) != proof[field]: return bad("INVENTORY_CLOSE_PROOF_IDENTITY")
	for field in ["initial_sequence", "processed_sequence", "accepted_sequence", "revision"]:
		if not counter(proof[field]): return bad("INVENTORY_COVERAGE_COUNTER")
	for field in ["inventory_initial_sequence", "inventory_cutoff_sequence", "inventory_processed_sequence", "inventory_accepted_sequence", "inventory_revision", "inventory_pending_count"]:
		if not counter(request.get(field)): return bad("INVENTORY_COVERAGE_COUNTER")
	if request["inventory_pending_count"] != 0 or request["inventory_processed_sequence"] != request["inventory_cutoff_sequence"] or request["inventory_initial_sequence"] > request["inventory_accepted_sequence"] or request["inventory_accepted_sequence"] > request["inventory_processed_sequence"] or proof["initial_sequence"] != request["inventory_initial_sequence"] or proof["initial_sequence"] > proof["accepted_sequence"] or proof["accepted_sequence"] > proof["processed_sequence"] or proof["processed_sequence"] > request["inventory_cutoff_sequence"] or proof["accepted_sequence"] > request["inventory_accepted_sequence"]: return bad("INVENTORY_COVERAGE_CURSOR")
	if not proof["queue_empty"] or proof["processed_sequence"] < request["inventory_processed_sequence"] or proof["accepted_sequence"] < request["inventory_accepted_sequence"] or proof["revision"] < request["inventory_revision"]: return {"ok": false, "pending": true, "code": "INVENTORY_COVERAGE_PENDING"}
	return {"ok": true}

static func normalize_close_proof_json(value: Variant) -> Dictionary:
	# Disk-report JSON only. Never call this on a network RPC packet.
	if not _fields(value, PROOF): return bad("INVENTORY_CLOSE_PROOF_FIELDS")
	var result: Dictionary = value.duplicate(true)
	for field in ["peer_id", "input_generation", "initial_sequence", "cutoff_sequence", "processed_sequence", "accepted_sequence", "revision"]:
		var number: Variant = result[field]
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or absf(float(number)) > MAX_SEQUENCE or floorf(float(number)) != float(number): return bad("INVENTORY_CLOSE_PROOF_COUNTER")
		result[field] = int(number)
	if not identity_valid(identity_of(result)): return bad("INVENTORY_CLOSE_PROOF_IDENTITY")
	for field in ["ok", "stopping", "queue_empty"]:
		if typeof(result[field]) != TYPE_BOOL: return bad("INVENTORY_CLOSE_PROOF_TYPES")
	for field in ["initial_sequence", "processed_sequence", "accepted_sequence", "revision"]:
		if not counter(result[field]): return bad("INVENTORY_CLOSE_PROOF_COUNTER")
	if (result["stopping"] and not counter(result["cutoff_sequence"])) or (not result["stopping"] and result["cutoff_sequence"] != -1): return bad("INVENTORY_CLOSE_PROOF_COUNTER")
	return {"ok": true, "proof": result}

func configure_client(identity: Dictionary, transport: Dictionary) -> Dictionary:
	if not _role.is_empty() or _failed or not identity_valid(identity) or transport.is_empty(): return bad("INVENTORY_CLIENT_BINDING")
	_role = "client"
	_identity = identity.duplicate(true)
	_transport = transport.duplicate(true)
	return {"ok": true}

func client_matches(identity: Dictionary, transport: Dictionary) -> bool:
	return _role == "client" and not _failed and identity == _identity and transport == _transport

func client_ready() -> bool:
	return _role == "client" and not _failed and _initial >= 0

func issue_client(kind: String, epoch: int, address: Dictionary = {}, revision: int = -1, sequence: int = -1, drop_kind: String = "", aim: Array = []) -> Dictionary:
	if _role != "client" or _stopping or _failed or _client_request_id >= MAX_SEQUENCE or _client_pending.size() >= MAX_CONTROLS or kind not in ["view", "close", "left", "drop"]: return bad("INVENTORY_CLIENT_CLOSED")
	if kind in ["left", "drop"] and (not client_ready() or not _client_pending.is_empty() or _issued != _processed or _issued >= MAX_SEQUENCE or sequence != _issued + 1): return bad("INVENTORY_CLIENT_PENDING")
	var request: Dictionary = _identity.duplicate(true)
	request.merge({"schema_version": 1, "contract": CONTRACT, "kind": kind, "request_id": _client_request_id + 1, "context_epoch": epoch})
	if kind in ["left", "drop"]: request.merge({"sequence": sequence, "expected_revision": revision, "address": address.duplicate(true)})
	if kind == "drop": request.merge({"drop_kind": drop_kind, "aim": aim.duplicate()})
	var checked := validate_request(request)
	if not checked["ok"]: return checked
	_client_request_id += 1
	_client_pending.append(request.duplicate(true))
	if kind in ["left", "drop"]: _issued = sequence
	return {"ok": true, "request": request}

func accept_client(value: Variant) -> Dictionary:
	if _role != "client" or _failed or _client_pending.is_empty() or not _fields(value, BASE + REPLY): return bad("INVENTORY_CLIENT_REPLY_FIELDS")
	if typeof(value["schema_version"]) != TYPE_INT or value["schema_version"] != 1 or not value["contract"] is String or value["contract"] != CONTRACT or not identity_valid(identity_of(value)) or identity_of(value) != _identity: return bad("INVENTORY_CLIENT_REPLY_IDENTITY")
	for field in ["request_id", "context_epoch", "sequence", "initial_sequence", "processed_sequence", "accepted_sequence", "revision"]:
		if not counter(value[field]): return bad("INVENTORY_CLIENT_REPLY_COUNTER")
	for field in ["ok", "authoritative", "durable"]:
		if typeof(value[field]) != TYPE_BOOL: return bad("INVENTORY_CLIENT_REPLY_RESULT")
	if not value["authoritative"] or value["durable"] or not value["code"] is String or value["code"].length() > 128 or not value["kind"] is String: return bad("INVENTORY_CLIENT_REPLY_RESULT")
	var request: Dictionary = _client_pending[0]
	for key in CONTROL:
		if value[key] != request[key]: return bad("INVENTORY_CLIENT_REPLY_ORDER")
	if value["sequence"] != request.get("sequence", 0): return bad("INVENTORY_CLIENT_REPLY_ORDER")
	if not _view_header_valid(value["view"], _identity) or value["view"]["view_sequence"] <= _view_sequence or value["view"]["revision"] != value["revision"] or value["view"]["inventory"]["last_sequence"] != value["accepted_sequence"]: return bad("INVENTORY_CLIENT_REPLY_VIEW")
	if _initial < 0:
		if request["kind"] != "view" or not value["ok"] or value["initial_sequence"] != value["processed_sequence"] or value["initial_sequence"] != value["accepted_sequence"]: return bad("INVENTORY_CLIENT_INITIAL_CURSOR")
	else:
		if value["initial_sequence"] != _initial or value["accepted_sequence"] < _accepted or value["revision"] < _revision: return bad("INVENTORY_CLIENT_REPLY_REGRESSION")
		if request["kind"] in ["left", "drop"]:
			if value["processed_sequence"] != _issued or (value["ok"] and (value["accepted_sequence"] != _issued or value["revision"] <= _revision)) or (not value["ok"] and value["accepted_sequence"] != _accepted): return bad("INVENTORY_CLIENT_REPLY_CURSOR")
		elif value["processed_sequence"] != _processed or value["accepted_sequence"] != _accepted: return bad("INVENTORY_CLIENT_REPLY_CURSOR")
	if _initial < 0:
		_initial = value["initial_sequence"]
		_issued = _initial
	_processed = value["processed_sequence"]
	_accepted = value["accepted_sequence"]
	_revision = value["revision"]
	_view_sequence = value["view"]["view_sequence"]
	_client_pending.pop_front()
	return {"ok": true, "action_ok": value["ok"], "kind": value["kind"], "context_epoch": value["context_epoch"], "sequence": value["sequence"], "view": value["view"].duplicate(true)}

func client_checkpoint() -> Dictionary:
	if not client_ready(): return {}
	var cursor: Dictionary = _identity.duplicate(true)
	cursor.merge({"initial_sequence": _initial, "issued_sequence": _issued, "processed_sequence": _processed, "accepted_sequence": _accepted, "revision": _revision, "pending_count": _issued - _processed})
	return cursor

func client_pending_count() -> int:
	return _client_pending.size()

func stop_client() -> void:
	_stopping = true

func close() -> void:
	_failed = true
	_stopping = true
	# No reconfiguration or replay. Diagnostics survive until owner destruction.

static func bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

static func _fields(value: Variant, names: Array) -> bool:
	if not value is Dictionary or value.size() != names.size(): return false
	for name in names:
		if not value.has(name): return false
	return true

static func _id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 128: return false
	for c in value:
		if not (c >= "a" and c <= "z") and not (c >= "A" and c <= "Z") and not (c >= "0" and c <= "9") and c != "_": return false
	return true

static func _view_header_valid(value: Variant, identity: Dictionary) -> bool:
	# Item/slot/opaque-state and monotonic-view validation belongs to the exact
	# production View model in the client, before its Close checkpoint is bound.
	return _fields(value, ["schema_version", "contract", "world_id", "profile_id", "view_sequence", "revision", "inventory", "chests"]) and typeof(value["schema_version"]) == TYPE_INT and value["schema_version"] == 1 and value["contract"] is String and value["contract"] == "sandbox012-inventory-view-v1" and value["world_id"] is String and value["world_id"] == identity["world_id"] and value["profile_id"] is String and value["profile_id"] == identity["player_profile_id"] and counter(value["view_sequence"]) and counter(value["revision"]) and _fields(value["inventory"], ["bag", "hotbar", "carry", "carry_origin", "last_sequence"]) and counter(value["inventory"]["last_sequence"])

func sync_server(peer: int, view: Dictionary) -> Dictionary:
	if _role != "server" or _failed or _stopping or not _streams.has(peer): return bad("INVENTORY_SYNC_CLOSED")
	var stream: Dictionary = _streams[peer]
	if stream["received"] != stream["processed"] or stream["controls"] != 0: return {"ok": false, "pending": true}
	if not _view_header_valid(view, stream["identity"]) or view["view_sequence"] != next_view_sequence(peer) or view["inventory"]["last_sequence"] != stream["accepted"] or view["revision"] < stream["revision"]: return bad("INVENTORY_SYNC_VIEW")
	stream["revision"] = view["revision"]
	stream["view_sequence"] = view["view_sequence"]
	return {"ok": true, "identity": stream["identity"].duplicate(true), "view": view.duplicate(true)}

func accept_sync_client(identity: Dictionary, view: Dictionary) -> Dictionary:
	if _role != "client" or _failed or identity != _identity: return bad("INVENTORY_SYNC_IDENTITY")
	if not _view_header_valid(view, identity): return bad("INVENTORY_SYNC_VIEW")
	# Initial snapshot can trigger an unsolicited sync before the explicit first
	# private-view ACK returns. An already-in-flight sync can also arrive after
	# close freezes admissions. Neither is a reply or a close receipt. Preserve
	# every action/control cursor until its real reply; a later sync converges.
	if _stopping or not client_ready() or not _client_pending.is_empty(): return {"ok": true, "skipped": true}
	if not _view_header_valid(view, identity) or view["view_sequence"] <= _view_sequence or view["revision"] < _revision or view["inventory"]["last_sequence"] != _accepted: return bad("INVENTORY_SYNC_VIEW")
	_revision = view["revision"]
	_view_sequence = view["view_sequence"]
	return {"ok": true, "skipped": false}
