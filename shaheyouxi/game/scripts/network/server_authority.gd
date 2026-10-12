class_name SandboxServerAuthority
extends RefCounted
## Only this server-owned object creates profiles and player instance identities.

const MAX_EXACT_JSON_INTEGER := 9007199254740991
var max_players: int
var protocol_version: int
var catalogue_hash: String
var server_epoch: String
var world_id: String
var automatic_interval_seconds: float = 0.0
var next_auto_due_world_seconds: float = 0.0
var world_seconds: float = 0.0
var revision: int = 0
var _profiles: Dictionary = {}
var _peer_profiles: Dictionary = {}
var _welcome_cache: Dictionary = {}
var _command_cache: Dictionary = {}
var _used_ids: Dictionary = {}
var _crypto := Crypto.new()
# Server-only, single outstanding candidate. Never serialize or publish this state.
var _join_generation: int = 0
var _prepared_join: Dictionary = {}

func _init(capacity: int, version: int, content_hash: String, save_interval: float = 0.0) -> void:
	max_players = capacity
	protocol_version = version
	catalogue_hash = content_hash
	server_epoch = _new_id("session_")
	world_id = _new_id("world_")
	automatic_interval_seconds = save_interval
	next_auto_due_world_seconds = save_interval

func join(peer_id: int, request: Dictionary, local_host: bool = false) -> Dictionary:
	if peer_id <= 0:
		return _error("INVALID_PEER", "连接身份无效")
	if typeof(request.get("network_protocol_version")) != TYPE_INT or request.get("network_protocol_version") != protocol_version:
		return _error("UPDATE_REQUIRED", "客户端协议%s，服务器协议%d，请更新客户端" % [str(request.get("network_protocol_version", "缺失")), protocol_version])
	if request.get("catalogue_sha256") != catalogue_hash:
		return _error("CONTENT_MISMATCH", "正式数据版本不一致，请使用同一构建")
	for key in request:
		if key not in ["network_protocol_version", "catalogue_sha256", "display_name", "resume_profile_id", "resume_secret"]:
			return _error("UNEXPECTED_FIELD", "客户端不能指定权威身份或状态")
	var display_name: Variant = request.get("display_name")
	if not display_name is String or display_name.strip_edges().is_empty() or display_name.length() > 64:
		return _error("INVALID_NAME", "显示名格式无效")
	if _peer_profiles.has(peer_id):
		return _welcome_cache[peer_id].duplicate(true)
	if _peer_profiles.size() >= max_players:
		return _error("SERVER_FULL", "服务器人数已满")
	var profile_id: Variant = request.get("resume_profile_id", "")
	var secret: Variant = request.get("resume_secret", "")
	if not profile_id is String or not secret is String:
		return _error("INVALID_RESUME", "重连身份格式无效")
	var issued_secret := ""
	if not profile_id.is_empty():
		if not _profiles.has(profile_id) or _profiles[profile_id]["secret_hash"] != secret.sha256_text():
			return _error("INVALID_RESUME", "重连身份凭据无效")
		if _peer_profiles.values().has(profile_id):
			return _error("PROFILE_IN_USE", "该玩家档案已经连接")
		_profiles[profile_id]["display_name"] = display_name
	else:
		if not secret.is_empty():
			return _error("INVALID_RESUME", "缺少重连档案身份")
		profile_id = _new_id("player_")
		issued_secret = _new_id("resume_")
		_profiles[profile_id] = {
			"player_profile_id": profile_id,
			"player_instance_id": _new_id("entity_player_"),
			"display_name": display_name,
			"role": "HOST" if local_host else "MEMBER",
			"secret_hash": issued_secret.sha256_text(),
		}
	_peer_profiles[peer_id] = profile_id
	revision += 1
	var response := {
		"ok": true,
		"player_profile_id": profile_id,
		"player_instance_id": _profiles[profile_id]["player_instance_id"],
		"resume_secret": issued_secret if not issued_secret.is_empty() else secret,
		"server_epoch": server_epoch,
	}
	_welcome_cache[peer_id] = response.duplicate(true)
	return response

func prepare_join(peer_id: int, request: Dictionary, local_host: bool = false) -> Dictionary:
	# Reuse the original authentication path on an isolated authority. A rejected
	# preparation leaves both live state and an earlier successful preparation intact.
	if revision < 0 or revision >= MAX_EXACT_JSON_INTEGER:
		return _error("JOIN_REVISION_EXHAUSTED", "无法准备新的身份事务")
	if _join_generation < 0 or _join_generation >= MAX_EXACT_JSON_INTEGER:
		return _error("JOIN_GENERATION_EXHAUSTED", "身份事务代次已耗尽")
	if not _valid_id(server_epoch, "session_") or not validate_persistent_state(persistent_state()).get("ok", false):
		return _error("INVALID_JOIN_AUTHORITY_STATE", "身份事务的权威状态无效")
	var candidate := _copy_for_prepared_join()
	var welcome: Dictionary = candidate.join(peer_id, request.duplicate(true), local_host)
	if not welcome.get("ok", false):
		return welcome
	var profile_id: String = welcome["player_profile_id"]
	var already_active := _peer_profiles.has(peer_id)
	var is_new := not _profiles.has(profile_id)
	var added_ids: Dictionary = {}
	for identifier in candidate._used_ids:
		if not _used_ids.has(identifier):
			added_ids[identifier] = true
	_join_generation += 1
	var ticket := {"owner_id": get_instance_id(), "generation": _join_generation}
	_prepared_join = {
		"ticket": ticket.duplicate(true), "context": _prepared_join_context(),
		"peer_id": peer_id, "profile_id": profile_id,
		"profile": candidate._profiles[profile_id].duplicate(true),
		"welcome": welcome.duplicate(true), "added_ids": added_ids,
		"revision_after": candidate.revision, "already_active": already_active,
	}
	return {"ok": true, "ticket": ticket, "player_profile_id": profile_id, "player_instance_id": welcome["player_instance_id"], "is_new": is_new, "already_active": already_active}

func validate_prepared_join(ticket: Variant) -> Dictionary:
	if not _matches_prepared_join_ticket(ticket):
		return _error("INVALID_JOIN_TICKET", "身份事务票据无效或已失效")
	if _prepared_join["context"] != _prepared_join_context():
		return _error("STALE_JOIN_TICKET", "准备身份后权威状态已改变")
	if revision < 0 or revision >= MAX_EXACT_JSON_INTEGER:
		return _error("JOIN_REVISION_EXHAUSTED", "无法提交新的身份事务")
	return {"ok": true}

func commit_prepared_join(ticket: Variant) -> Dictionary:
	var checked := validate_prepared_join(ticket)
	if not checked["ok"]:
		return checked
	# No await or callbacks after validation. Merge only this join's write set;
	# read-only commands on another connection may have updated its cache meanwhile.
	var welcome: Dictionary = _prepared_join["welcome"].duplicate(true)
	if not _prepared_join["already_active"]:
		var profile_id: String = _prepared_join["profile_id"]
		var peer_id: int = _prepared_join["peer_id"]
		_profiles[profile_id] = _prepared_join["profile"].duplicate(true)
		_peer_profiles[peer_id] = profile_id
		_welcome_cache[peer_id] = welcome.duplicate(true)
		for identifier in _prepared_join["added_ids"]:
			_used_ids[identifier] = true
		revision = int(_prepared_join["revision_after"])
	_prepared_join.clear()
	return welcome

func prepared_join_effect(ticket: Variant) -> Dictionary:
	# Server-only private write set. Never send this (including its welcome) before
	# the enclosing native presence has been confirmed and durably saved.
	var checked := validate_prepared_join(ticket)
	return {"ok": true, "effect": _prepared_join.duplicate(true)} if checked["ok"] else checked

func cancel_prepared_join(ticket: Variant) -> Dictionary:
	# Cancellation can dispose a matching candidate even after its clock/revision
	# became stale. It never commits, restores, or removes any live identity.
	if not _matches_prepared_join_ticket(ticket):
		return _error("INVALID_JOIN_TICKET", "身份事务票据无效或已失效")
	_prepared_join.clear()
	return {"ok": true}

func _matches_prepared_join_ticket(ticket: Variant) -> bool:
	if not ticket is Dictionary or ticket.size() != 2 or not ticket.get("owner_id") is int or not ticket.get("generation") is int:
		return false
	if ticket["owner_id"] != get_instance_id() or ticket["generation"] < 1 or ticket["generation"] > MAX_EXACT_JSON_INTEGER:
		return false
	return not _prepared_join.is_empty() and ticket == _prepared_join["ticket"]

func _prepared_join_context() -> Dictionary:
	return {"revision": revision, "world_id": world_id, "server_epoch": server_epoch, "world_seconds": world_seconds, "max_players": max_players, "protocol_version": protocol_version, "catalogue_hash": catalogue_hash}

func _copy_for_prepared_join() -> SandboxServerAuthority:
	var candidate := SandboxServerAuthority.new(max_players, protocol_version, catalogue_hash, automatic_interval_seconds)
	candidate.server_epoch = server_epoch
	candidate.world_id = world_id
	candidate.world_seconds = world_seconds
	candidate.revision = revision
	candidate.next_auto_due_world_seconds = next_auto_due_world_seconds
	candidate._profiles = _profiles.duplicate(true)
	candidate._peer_profiles = _peer_profiles.duplicate(true)
	candidate._welcome_cache = _welcome_cache.duplicate(true)
	candidate._command_cache = _command_cache.duplicate(true)
	# Discard the clone constructor's private throwaway IDs before computing deltas.
	candidate._used_ids = _used_ids.duplicate(true)
	return candidate

func disconnect_peer(peer_id: int) -> void:
	if _peer_profiles.has(peer_id):
		_peer_profiles.erase(peer_id)
		_welcome_cache.erase(peer_id)
		_command_cache.erase(peer_id)
		revision += 1

func active_peer_ids() -> Array:
	return _peer_profiles.keys()

func advance(delta: float) -> void:
	if not _peer_profiles.is_empty() and is_finite(delta) and delta > 0.0:
		world_seconds += delta

func public_snapshot() -> Dictionary:
	var players: Dictionary = {}
	for peer_id in _peer_profiles:
		var profile_id: String = _peer_profiles[peer_id]
		var profile: Dictionary = _profiles[profile_id]
		players[profile_id] = {
			"player_profile_id": profile_id,
			"player_instance_id": profile["player_instance_id"],
			"display_name": profile["display_name"],
			"role": profile["role"],
			"peer_id": peer_id,
		}
	return {"server_epoch": server_epoch, "world_id": world_id, "revision": revision, "world_seconds": world_seconds, "players": players, "max_players": max_players}

func read_only_command(peer_id: int, request: Dictionary) -> Dictionary:
	if request.get("kind") != "request_snapshot":
		return _error("AUTHORITY_REQUIRED", "客户端不能直接写权威状态")
	return handle_command(peer_id, request)

func handle_command(peer_id: int, request: Dictionary, trusted_public_snapshot: Dictionary = {}) -> Dictionary:
	if not _peer_profiles.has(peer_id):
		return _error("NOT_JOINED", "尚未完成联机身份确认")
	var kind: Variant = request.get("kind")
	if kind not in ["request_snapshot", "set_display_name"]:
		return _error("AUTHORITY_REQUIRED", "客户端只能提交已登记意图，不能写玩家状态")
	var expected_fields := 2 if kind == "request_snapshot" else 3
	if request.size() != expected_fields or not request.has("command_id") or (kind == "set_display_name" and not request.has("display_name")):
		return _error("AUTHORITY_REQUIRED", "命令字段不符合登记接口")
	var command_id: Variant = request["command_id"]
	if typeof(command_id) != TYPE_INT or command_id < 1:
		return _error("INVALID_COMMAND_ID", "命令序号无效")
	var fingerprint := JSON.stringify(request, "", true, true)
	if _command_cache.has(peer_id):
		var cached: Dictionary = _command_cache[peer_id]
		if command_id == cached["id"]:
			if fingerprint != cached["fingerprint"]:
				return _error("COMMAND_ID_REUSED", "同一命令序号不能承载不同意图")
			return cached["response"].duplicate(true)
		if command_id < cached["id"]:
			return _error("STALE_COMMAND", "命令序号已过期")
	var response: Dictionary
	if kind == "set_display_name":
		var display_name: Variant = request["display_name"]
		if not display_name is String or display_name.strip_edges().is_empty() or display_name.length() > 64:
			return _error("INVALID_NAME", "显示名格式无效")
		var profile_id: String = _peer_profiles[peer_id]
		if _profiles[profile_id]["display_name"] != display_name:
			_profiles[profile_id]["display_name"] = display_name
			revision += 1
		response = {"ok": true, "kind": kind, "command_id": command_id, "display_name": display_name, "player_profile_id": profile_id}
	else:
		response = {"ok": true, "kind": kind, "command_id": command_id, "snapshot": public_snapshot() if trusted_public_snapshot.is_empty() else trusted_public_snapshot.duplicate(true)}
	_command_cache[peer_id] = {"id": command_id, "fingerprint": fingerprint, "response": response.duplicate(true)}
	return response

func persistent_state() -> Dictionary:
	# No peer IDs, caches, scene nodes, plaintext resume tokens or session epoch.
	return {"world_id": world_id, "world_seconds": world_seconds, "revision": revision, "next_auto_due_world_seconds": next_auto_due_world_seconds, "profiles": _profiles.duplicate(true)}

func restore_persistent_state(state: Dictionary) -> Dictionary:
	var validation := validate_persistent_state(state)
	if not validation.get("ok", false):
		return validation
	# Validate first, then replace as one authority-owned operation.
	var profiles: Dictionary = state["profiles"].duplicate(true)
	world_id = state["world_id"]
	world_seconds = float(state["world_seconds"])
	revision = int(state["revision"])
	next_auto_due_world_seconds = float(state["next_auto_due_world_seconds"])
	_profiles = profiles
	_peer_profiles.clear()
	_welcome_cache.clear()
	_command_cache.clear()
	_used_ids = {server_epoch: true, world_id: true}
	for profile_id in profiles:
		_used_ids[profile_id] = true
		_used_ids[profiles[profile_id]["player_instance_id"]] = true
	# Never reset the monotonic generation: an identical restored snapshot must not
	# revive a ticket issued before restore. Failed restores leave the candidate intact.
	_prepared_join.clear()
	return {"ok": true}

func automatic_save_due() -> bool:
	return automatic_interval_seconds > 0.0 and not _peer_profiles.is_empty() and world_seconds >= next_auto_due_world_seconds

func state_for_automatic_save() -> Dictionary:
	var state := persistent_state()
	var due := next_auto_due_world_seconds
	if due <= world_seconds and automatic_interval_seconds > 0.0:
		var periods: float = floor((world_seconds - due) / automatic_interval_seconds) + 1.0
		due += periods * automatic_interval_seconds
	state["next_auto_due_world_seconds"] = due
	return state

static func validate_persistent_state(state: Dictionary) -> Dictionary:
	for key in state:
		if key not in ["world_id", "world_seconds", "revision", "next_auto_due_world_seconds", "profiles"]:
			return {"ok": false, "message": "存档包含未登记世界字段"}
	if not _valid_id(state.get("world_id"), "world_"):
		return {"ok": false, "message": "世界身份无效"}
	for key in ["world_seconds", "next_auto_due_world_seconds"]:
		var value: Variant = state.get(key)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value < 0 or value > MAX_EXACT_JSON_INTEGER:
			return {"ok": false, "message": "世界时钟/自动保存时刻无效"}
	var stored_revision: Variant = state.get("revision")
	if typeof(stored_revision) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(stored_revision)) or stored_revision < 0 or stored_revision > MAX_EXACT_JSON_INTEGER or float(stored_revision) != floor(float(stored_revision)):
		return {"ok": false, "message": "状态修订无效"}
	var profiles: Variant = state.get("profiles")
	if not profiles is Dictionary:
		return {"ok": false, "message": "玩家档案结构无效"}
	var used_instances: Dictionary = {}
	for profile_id in profiles:
		var profile: Variant = profiles[profile_id]
		if not _valid_id(profile_id, "player_") or not profile is Dictionary or profile.get("player_profile_id") != profile_id:
			return {"ok": false, "message": "玩家档案身份不匹配"}
		for key in profile:
			if key not in ["player_profile_id", "player_instance_id", "display_name", "role", "secret_hash"]:
				return {"ok": false, "message": "档案包含连接/临时或未登记字段"}
		var instance_id: Variant = profile.get("player_instance_id")
		if not _valid_id(instance_id, "entity_player_") or used_instances.has(instance_id):
			return {"ok": false, "message": "玩家实体身份无效或重复"}
		used_instances[instance_id] = true
		var display_name: Variant = profile.get("display_name")
		var secret_hash: Variant = profile.get("secret_hash")
		if not display_name is String or display_name.strip_edges().is_empty() or display_name.length() > 64 or profile.get("role") not in ["HOST", "ADMIN", "MEMBER"]:
			return {"ok": false, "message": "玩家名称或权限无效"}
		if not secret_hash is String or secret_hash.length() != 64 or not secret_hash.is_valid_hex_number(false):
			return {"ok": false, "message": "玩家恢复身份hash无效"}
	return {"ok": true}

static func _valid_id(value: Variant, prefix: String) -> bool:
	return value is String and value.begins_with(prefix) and value.length() == prefix.length() + 32 and value.trim_prefix(prefix).is_valid_hex_number(false)

func _new_id(prefix: String) -> String:
	var result := prefix + _crypto.generate_random_bytes(16).hex_encode()
	while _used_ids.has(result):
		result = prefix + _crypto.generate_random_bytes(16).hex_encode()
	_used_ids[result] = true
	return result

func _error(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
