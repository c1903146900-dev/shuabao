class_name SandboxSaveStore
extends RefCounted
## Server-only development save format. No old-project migration is implied.

const ExactScalarCodec = preload("res://scripts/save/exact_scalar_codec.gd")
const WindowsGenerations = preload("res://scripts/save/windows_generation_store.gd")
const PROJECT_ID := "shaheyouxi_experiment_20261004"
const SAVE_EPOCH := "shaheyouxi_20261004"
const SCHEMA_VERSION := 1
const ENVELOPE_FORMAT := "shaheyouxi.save.envelope"
var directory: String
var automatic_count: int
var manual_count: int
var last_sequence: int = 0
var _last_automatic_slot: int = 0
var _write_ready: bool = false
var last_error: Dictionary = {}
var _lock_owned: bool = false
var _world_id: String = ""
var _lock_token: String = ""
var _content_revision: String = ""
var _network_protocol_version: int = 0
var _state_validator: Callable = Callable()
var _schema_version: int = SCHEMA_VERSION
var _maximum_bytes: int = 0
var _exact_scalars: bool = false
var _windows_generations: RefCounted
var _generation_init_error: Dictionary = {}
var _generation_bound_adapter: RefCounted
var _generation_binding: Dictionary = {}

func _init(path: String, automatic_slots: int, manual_slots: int, content_revision: String = "", network_version: int = 0, state_validator: Callable = Callable(), schema_version: int = SCHEMA_VERSION, maximum_bytes: int = 0, exact_scalars: bool = false) -> void:
	directory = path
	automatic_count = automatic_slots
	manual_count = manual_slots
	_content_revision = content_revision
	_network_protocol_version = network_version
	_state_validator = state_validator
	_schema_version = schema_version
	_maximum_bytes = maximum_bytes
	_exact_scalars = exact_scalars

func configure_windows_generation_storage() -> Dictionary:
	# Only the ordinary owner explicitly opts in before acquire. Default Store
	# construction, Linux direct tests, schema and actual script identity stay.
	if _lock_owned or _write_ready or _windows_generations != null or not _generation_init_error.is_empty():
		_generation_init_error = _error("GENERATION_CONFIG_ORDER", "存档布局不能在会话中切换")
		return _generation_init_error.duplicate(true)
	var scope := _generation_scope_root()
	var slot := directory.get_base_dir().get_file()
	if automatic_count < 1 or automatic_count > 64 or manual_count < 1 or manual_count > 63 or not _generation_platform_supported() or _schema_version != 4 or not _exact_scalars or not _state_validator.is_valid() or _maximum_bytes != 4194304 or directory != directory.simplify_path() or directory.get_file() != "world" or directory.get_base_dir().get_base_dir() != scope or not WindowsGenerations._hex(slot, 32) or WindowsGenerations._is_link(scope) or WindowsGenerations._is_link(directory.get_base_dir()) or WindowsGenerations._is_link(directory):
		_generation_init_error = _error("GENERATION_SCOPE_REQUIRED", "仅新的普通Windows存档可选择代文件布局")
		return _generation_init_error.duplicate(true)
	# No automatic conversion, copying or deletion of old main/backup files.
	if WindowsGenerations._exists(directory.path_join("main.json")):
		_generation_init_error = _error("GENERATION_OLD_LAYOUT_REFUSED", "旧存档布局不能隐式切换")
		return _generation_init_error.duplicate(true)
	for folder in ["auto", "manual"]:
		var path := directory.path_join(folder)
		if WindowsGenerations._is_link(path):
			_generation_init_error = _error("GENERATION_OLD_LAYOUT_REFUSED", "旧目录或链接不能隐式切换")
			return _generation_init_error.duplicate(true)
		if WindowsGenerations._exists(path):
			var empty: Dictionary = WindowsGenerations._directory_entries(path, 0)
			if not empty.get("ok", false):
				_generation_init_error = _error("GENERATION_OLD_LAYOUT_REFUSED", "旧备份不能隐式切换")
				return _generation_init_error.duplicate(true)
	var candidate := WindowsGenerations.new()
	var logical_names: Array = ["main"]
	for kind in ["auto", "manual"]:
		var count := automatic_count if kind == "auto" else manual_count
		for number in range(1, count + 1):
			logical_names.append("%s_%02d" % [kind, number])
	var configured: Dictionary = candidate.configure(directory.path_join("ordinary_generations_v1"), "save_schema4", logical_names)
	if not configured.get("ok", false):
		_generation_init_error = configured.duplicate(true)
		return configured
	_windows_generations = candidate
	_generation_bound_adapter = candidate
	var rules: Array = candidate._logical_names.duplicate()
	rules.make_read_only()
	_generation_binding = {"instance_id": candidate.get_instance_id(), "root": candidate._root, "record_kind": candidate._kind,
		"maximum_bytes": candidate._maximum_bytes, "logical_names": rules}
	_generation_binding.make_read_only()
	return {"ok": true}

func _generation_binding_valid() -> bool:
	if not _generation_init_error.is_empty():
		return false
	if _generation_binding.is_empty():
		if _windows_generations == null:
			return true # Original default Store has no generation adapter at all.
	else:
		if _windows_generations != null and _windows_generations == _generation_bound_adapter and _windows_generations.get_script() == WindowsGenerations and _windows_generations.get_instance_id() == _generation_binding["instance_id"] and _windows_generations.ready and _windows_generations._root == _generation_binding["root"] and _windows_generations._root == directory.path_join("ordinary_generations_v1") and _windows_generations._kind == "save_schema4" and _windows_generations._maximum_bytes == _generation_binding["maximum_bytes"] and _windows_generations._maximum_bytes == 4194304 and _windows_generations._logical_names == _generation_binding["logical_names"]:
			return true
	_generation_init_error = _error("GENERATION_BINDING_CHANGED", "代存储实例或本槽绑定已改变，停止读写")
	return false

func _generation_write(key: String, text: String, sequence: int) -> Dictionary:
	return _windows_generations.write_generation(key, text, sequence, _validate_generation_text)

func _generation_platform_supported() -> bool:
	return OS.get_name() == "Windows" # Explicitly overridden only by source test fixture.

func _generation_scope_root() -> String:
	return ProjectSettings.globalize_path("user://local_play011/slots").simplify_path()

func _generation_key(path: String) -> String:
	if path == directory.path_join("main.json"):
		return "main"
	for kind in ["auto", "manual"]:
		var limit := automatic_count if kind == "auto" else manual_count
		for slot in range(1, limit + 1):
			var name := "%s_%02d" % [kind, slot]
			if path == directory.path_join(kind).path_join(name + ".json"):
				return name
	return ""

func _validate_generation_text(text: String) -> Dictionary:
	return _decode_text(text)

func inspect_main() -> Dictionary:
	# Full real Store validation without acquiring a writer or falling back.
	if not _generation_binding_valid():
		return _generation_init_error.duplicate(true)
	var source: Dictionary
	if _windows_generations != null:
		source = _windows_generations.read_latest("main", _validate_generation_text)
	else:
		source = _read_file_text(directory.path_join("main.json"))
	if not source.get("ok", false):
		return source
	var checked := _decode_text(source["text"], "main")
	if not _generation_binding_valid():
		return _generation_init_error.duplicate(true)
	if checked.get("ok", false):
		checked["validated_text"] = source["text"]
		checked["storage_layout"] = WindowsGenerations.FORMAT if _windows_generations != null else "legacy_main_file"
	return checked

func acquire() -> Dictionary:
	if not _generation_binding_valid():
		return _generation_init_error.duplicate(true)
	if _lock_owned:
		return {"ok": true}
	_write_ready = false
	if (_exact_scalars and (_maximum_bytes <= 0 or not _state_validator.is_valid())) or automatic_count < 1 or manual_count < 1 or _schema_version < 1 or _maximum_bytes < 0 or (_schema_version != SCHEMA_VERSION and not _state_validator.is_valid()):
		return _error("INVALID_CONFIG", "备份数量配置无效")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return _error("IO_ERROR", "无法创建存档目录")
	var lock_dir := directory.path_join(".writer_lock")
	var recovery_lock := directory.path_join(".writer_recovery_lock")
	if DirAccess.dir_exists_absolute(recovery_lock):
		return _error("LOCKED", "存档锁恢复正在进行或需要人工检查")
	var result := DirAccess.make_dir_absolute(lock_dir)
	if result == ERR_ALREADY_EXISTS:
		# Serialize stale-lock recovery before re-reading its owner; do not race two reclaimers.
		if DirAccess.make_dir_absolute(recovery_lock) != OK:
			return _error("LOCKED", "其他进程正在核验存档锁")
		var owner: Variant = JSON.parse_string(FileAccess.get_file_as_string(lock_dir.path_join("owner.json")))
		if not owner is Dictionary or not _integer(owner.get("pid")) or owner["pid"] < 1 or not owner.get("token") is String:
			DirAccess.remove_absolute(recovery_lock)
			return _error("LOCKED", "已有存档写入锁，身份未能验证")
		var owner_pid := int(owner["pid"])
		var owner_alive := true
		# Only a launcher-confirmed matching PID namespace permits stale recovery.
		# Unknown/cross-namespace owners remain locked for explicit inspection.
		var pid_namespace := OS.get_environment("SHAHEYOUXI_PID_NAMESPACE")
		if OS.get_name() == "Linux" and not pid_namespace.is_empty() and owner.get("pid_namespace") == pid_namespace:
			var actual_birth := _linux_process_birth(owner_pid)
			if not DirAccess.dir_exists_absolute("/proc/%d" % owner_pid):
				owner_alive = false
			elif not actual_birth.is_empty() and owner.get("process_birth", "") is String and not str(owner.get("process_birth", "")).is_empty():
				owner_alive = actual_birth == owner["process_birth"]
		if owner_alive:
			DirAccess.remove_absolute(recovery_lock)
			return _error("LOCKED", "此世界已有服务器进程使用")
		if DirAccess.remove_absolute(lock_dir.path_join("owner.json")) != OK or DirAccess.remove_absolute(lock_dir) != OK:
			DirAccess.remove_absolute(recovery_lock)
			return _error("IO_ERROR", "无法清理已退出进程的锁")
		result = DirAccess.make_dir_absolute(lock_dir)
		DirAccess.remove_absolute(recovery_lock)
	if result != OK:
		return _error("LOCKED", "无法取得存档写入锁")
	_lock_token = Crypto.new().generate_random_bytes(16).hex_encode()
	var owner_file := FileAccess.open(lock_dir.path_join("owner.json"), FileAccess.WRITE)
	if owner_file == null:
		DirAccess.remove_absolute(lock_dir)
		return _error("IO_ERROR", "无法写入存档锁身份")
	owner_file.store_string(JSON.stringify({"pid": OS.get_process_id(), "token": _lock_token, "process_birth": _linux_process_birth(OS.get_process_id()), "pid_namespace": OS.get_environment("SHAHEYOUXI_PID_NAMESPACE")}))
	owner_file.close()
	_lock_owned = true
	for subdirectory in ["auto", "manual"]:
		if DirAccess.make_dir_recursive_absolute(directory.path_join(subdirectory)) != OK:
			close()
			return _error("IO_ERROR", "无法创建备份目录")
	var marker_path := directory.path_join("world_identity.json")
	if _windows_generations != null and _windows_generations.has_layout() and not FileAccess.file_exists(marker_path):
		close()
		return _error("GENERATION_WORLD_IDENTITY_MISSING", "已有代布局缺少世界身份，禁止隐式恢复")
	if FileAccess.file_exists(marker_path):
		var marker: Variant = JSON.parse_string(FileAccess.get_file_as_string(marker_path))
		if not marker is Dictionary or marker.get("project_id") != PROJECT_ID or marker.get("save_epoch") != SAVE_EPOCH or not SandboxServerAuthority._valid_id(marker.get("world_id"), "world_"):
			close()
			return _error("INCOMPATIBLE_WORLD", "世界目录身份记录无效")
		_world_id = marker["world_id"]
	return {"ok": true}

func close() -> void:
	if not _lock_owned:
		return
	var lock_dir := directory.path_join(".writer_lock")
	var owner: Variant = JSON.parse_string(FileAccess.get_file_as_string(lock_dir.path_join("owner.json")))
	if owner is Dictionary and owner.get("token") == _lock_token:
		DirAccess.remove_absolute(lock_dir.path_join("owner.json"))
		DirAccess.remove_absolute(lock_dir)
	_lock_owned = false
	_write_ready = false

func save_main(state: Dictionary, reason: String) -> Dictionary:
	if not _write_ready:
		return _error("LOAD_REQUIRED", "必须先成功确认当前世界再保存")
	if not _lock_owned:
		return _error("LOCK_REQUIRED", "未取得世界写入锁")
	var validation := _validate_state(state)
	if not validation.get("ok", false):
		return _error("INVALID_STATE", validation.get("message", "世界状态无效"))
	if not _world_id.is_empty() and _world_id != state["world_id"]:
		return _error("INCOMPATIBLE_WORLD", "拒绝覆盖其他世界")
	var binding := _bind_world(state["world_id"])
	if not binding.get("ok", false):
		return binding
	var slot := (_last_automatic_slot % automatic_count) + 1
	var existing_backup := _read(directory.path_join("auto/auto_%02d.json" % slot), "main")
	if not existing_backup.get("ok", false) and existing_backup.get("code") not in ["MISSING", "CORRUPT"]:
		return existing_backup
	if last_sequence >= SandboxServerAuthority.MAX_EXACT_JSON_INTEGER:
		return _error("SEQUENCE_EXHAUSTED", "存档序号超出格式的精确范围")
	var sequence := last_sequence + 1
	var text := _encode(state, sequence, "main", reason, 0)
	if text.is_empty():
		return _error("EXACT_CODEC_ENCODE_FAILED", "无损数值编码失败，旧文件保留")
	var result := _atomic_write(directory.path_join("main.json"), text)
	if not result.get("ok", false):
		if _windows_generations != null and result.get("main_committed", false) and result.get("sequence") == sequence:
			# Complete marker publication is a real commit even if later retention
			# fails. Keep Frame's receipt/Store sequence consistent; no backup retry.
			last_sequence = sequence
			_world_id = state["world_id"]
		return result
	last_sequence = sequence
	_world_id = state["world_id"]
	var backup := _atomic_write(directory.path_join("auto/auto_%02d.json" % slot), text)
	if not backup.get("ok", false):
		return {"ok": false, "code": "MAIN_SAVED_BACKUP_FAILED", "message": "主档已完整保存，但自动备份失败", "main_committed": true, "sequence": sequence}
	_last_automatic_slot = slot
	last_error = {}
	return {"ok": true, "sequence": sequence, "automatic_slot": slot, "commit_order": ["main", "automatic_backup"]}

func save_manual(slot: int, state: Dictionary) -> Dictionary:
	if not _write_ready:
		return _error("LOAD_REQUIRED", "必须先成功确认当前世界再保存")
	if not _lock_owned:
		return _error("LOCK_REQUIRED", "未取得世界写入锁")
	if slot < 1 or slot > manual_count:
		return _error("INVALID_SLOT", "手动存档槽位无效")
	var validation := _validate_state(state)
	if not validation.get("ok", false):
		return _error("INVALID_STATE", validation.get("message", "世界状态无效"))
	if not _world_id.is_empty() and _world_id != state["world_id"]:
		return _error("INCOMPATIBLE_WORLD", "手动存档世界不匹配")
	var binding := _bind_world(state["world_id"])
	if not binding.get("ok", false):
		return binding
	var text := _encode(state, last_sequence, "manual", "manual_operator_request", slot)
	if text.is_empty():
		return _error("EXACT_CODEC_ENCODE_FAILED", "无损数值编码失败，旧文件保留")
	return _atomic_write(directory.path_join("manual/manual_%02d.json" % slot), text)

func load_latest() -> Dictionary:
	_write_ready = false
	if not _lock_owned:
		return _error("LOCK_REQUIRED", "未取得世界写入锁")
	var primary := _read(directory.path_join("main.json"), "main")
	if primary.get("ok", false):
		_accept(primary)
		primary["loaded_from"] = "main"
		return primary
	if primary.get("code") == "MISSING":
		if _windows_generations != null and _windows_generations.has_layout():
			return _error("GENERATION_MAIN_MISSING", "已有代布局缺少已提交主代，禁止重建世界")
		if not _world_id.is_empty():
			return _error("MISSING_MAIN_EXISTING_WORLD", "已有世界主档缺失，禁止静默创建新世界")
		for slot in range(1, manual_count + 1):
			if FileAccess.file_exists(directory.path_join("manual/manual_%02d.json" % slot)):
				return _error("MISSING_MAIN_WITH_BACKUPS", "主档缺失且手动存档存在，需明确恢复操作")
		# Existing backups with a missing primary are not silently treated as a new world.
		for slot in range(1, automatic_count + 1):
			if FileAccess.file_exists(directory.path_join("auto/auto_%02d.json" % slot)):
				return _error("MISSING_MAIN_WITH_BACKUPS", "主档缺失但备份存在，需明确恢复操作")
		_write_ready = true
		return {"ok": true, "new_world": true, "loaded_from": "new"}
	if _windows_generations != null:
		return primary # Committed generation failures never enter legacy fallback.
	if primary.get("code") != "CORRUPT":
		return primary
	if _world_id.is_empty():
		return _error("INCOMPATIBLE_WORLD", "主档损坏且世界身份无法确认，需要明确恢复选择")
	var candidates: Array = []
	for slot in range(1, automatic_count + 1):
		var candidate := _read(directory.path_join("auto/auto_%02d.json" % slot), "main")
		if candidate.get("ok", false):
			candidate["loaded_from"] = "auto_%02d" % slot
			candidates.append(candidate)
		elif candidate.get("code") not in ["MISSING", "CORRUPT"]:
			if candidate.get("ordering_verified", false):
				candidate["sequence"] = candidate["sequence_hint"]
				candidates.append(candidate)
			else:
				# Unreadable or foreign metadata cannot be safely ordered.
				return candidate
	if candidates.is_empty():
		return _error("NO_VALID_BACKUP", "主档损坏且没有有效自动备份")
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["sequence"] > b["sequence"])
	var recovered: Dictionary = candidates[0]
	for candidate in candidates:
		if candidate["sequence"] != recovered["sequence"]:
			break
		if not candidate.get("ok", false):
			return candidate
		if candidate.get("payload_sha256") != recovered.get("payload_sha256"):
			return _error("AMBIGUOUS_BACKUP_SEQUENCE", "同一最新序号有不同快照，拒绝猜测恢复")
	if not recovered.get("ok", false):
		return recovered
	_accept(recovered)
	recovered["recovered_from_corrupt_main"] = true
	# Loading never overwrites the corrupt main or promotes a backup implicitly.
	return recovered

func load_manual(slot: int) -> Dictionary:
	if not _lock_owned:
		return _error("LOCK_REQUIRED", "未取得世界写入锁")
	if slot < 1 or slot > manual_count:
		return _error("INVALID_SLOT", "手动存档槽位无效")
	var result := _read(directory.path_join("manual/manual_%02d.json" % slot), "manual")
	if result.get("ok", false):
		result["loaded_from"] = "manual_%02d" % slot
	return result

func _accept(result: Dictionary) -> void:
	_write_ready = true
	last_error = {}
	last_sequence = maxi(last_sequence, int(result["sequence"]))
	_world_id = result["state"]["world_id"]
	var newest_sequence: int = -1
	for slot in range(1, automatic_count + 1):
		var backup := _read(directory.path_join("auto/auto_%02d.json" % slot), "main")
		if backup.get("ok", false) and int(backup["sequence"]) > newest_sequence:
			newest_sequence = int(backup["sequence"])
			_last_automatic_slot = slot
			last_sequence = maxi(last_sequence, newest_sequence)
	last_error = {}

func _bind_world(id: String) -> Dictionary:
	if not _world_id.is_empty() and _world_id != id:
		return _error("INCOMPATIBLE_WORLD", "此目录已经属于另一个世界")
	var marker_path := directory.path_join("world_identity.json")
	if not FileAccess.file_exists(marker_path):
		var temporary := marker_path + ".tmp"
		var handle := FileAccess.open(temporary, FileAccess.WRITE)
		if handle == null:
			return _error("IO_ERROR", "无法写入世界身份")
		handle.store_string(JSON.stringify({"project_id": PROJECT_ID, "save_epoch": SAVE_EPOCH, "world_id": id}))
		handle.flush()
		var write_error := handle.get_error()
		handle.close()
		var marker_read := _read_file_text(temporary)
		if not marker_read.get("ok", false):
			return marker_read
		var verified: Variant = JSON.parse_string(marker_read["text"])
		if write_error != OK or not verified is Dictionary or verified.get("world_id") != id or verified.get("project_id") != PROJECT_ID or verified.get("save_epoch") != SAVE_EPOCH:
			return _error("IO_ERROR", "世界身份写后验证失败")
		if DirAccess.rename_absolute(temporary, marker_path) != OK:
			return _error("IO_ERROR", "世界身份提升失败")
	_world_id = id
	return {"ok": true}

func _encode(state: Dictionary, sequence: int, kind: String, reason: String, manual_slot: int) -> String:
	var payload := {
		"project_id": PROJECT_ID, "save_epoch": SAVE_EPOCH, "save_schema_version": _schema_version,
		"world_id": state["world_id"], "sequence": sequence, "kind": kind, "reason": reason,
		"manual_slot": manual_slot, "state": state,
		"created_at_utc": Time.get_datetime_string_from_system(true, true) + "Z",
		"build_identity": {"kind": "development_unreleased", "game_version": null, "build_id": null, "build_number": null, "content_revision": _content_revision, "network_protocol_version": _network_protocol_version},
	}
	if _exact_scalars:
		var encoded: Dictionary = ExactScalarCodec.encode(payload)
		if not encoded.get("ok", false):
			return ""
		var exact_text := JSON.stringify(encoded["value"], "", true, true)
		return JSON.stringify({"format": ENVELOPE_FORMAT, "envelope_version": 2.0, "payload_codec": "scalar_bits_le_v1", "payload_json": exact_text, "payload_sha256": exact_text.sha256_text()}, "", true, true)
	var payload_text := JSON.stringify(payload, "", true, true)
	return JSON.stringify({"format": ENVELOPE_FORMAT, "envelope_version": 1, "payload_json": payload_text, "payload_sha256": payload_text.sha256_text()}, "", true, true)

func _read_file_text(path: String) -> Dictionary:
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		var error := FileAccess.get_open_error()
		if error in [ERR_FILE_NOT_FOUND, ERR_DOES_NOT_EXIST]:
			return _error("MISSING", "存档文件不存在")
		return _error("IO_ERROR", "存档文件不可读：%s" % error_string(error))
	if _maximum_bytes > 0 and handle.get_length() > _maximum_bytes:
		handle.close()
		return _error("SAVE_SIZE_LIMIT", "技术快照超出已批准大小限制，不执行回退")
	var text := handle.get_as_text()
	var read_error := handle.get_error()
	handle.close()
	if read_error not in [OK, ERR_FILE_EOF]:
		return _error("IO_ERROR", "存档读取发生I/O错误，不执行自动回退")
	return {"ok": true, "text": text}

func _read(path: String, expected_kind: String = "") -> Dictionary:
	if not _generation_binding_valid():
		return _generation_init_error.duplicate(true)
	var read_result: Dictionary
	if _windows_generations != null:
		var key := _generation_key(path)
		if key.is_empty():
			return _error("GENERATION_LOGICAL_PATH_INVALID", "存档逻辑路径不在当前槽中")
		read_result = _windows_generations.read_latest(key, _validate_generation_text)
	else:
		read_result = _read_file_text(path)
	if not read_result.get("ok", false):
		return read_result
	var checked := _decode_text(read_result["text"], expected_kind)
	return checked if _generation_binding_valid() else _generation_init_error.duplicate(true)

func _decode_text(text: String, expected_kind: String = "") -> Dictionary:
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _error("CORRUPT", "存档JSON损坏")
	var envelope: Variant = parser.data
	if not envelope is Dictionary:
		return _error("CORRUPT", "存档封套损坏")
	if envelope.get("format") != ENVELOPE_FORMAT or envelope.get("envelope_version") != (2 if _exact_scalars else 1):
		return _error("INCOMPATIBLE_FORMAT", "未知存档格式，不能自动回退")
	if _exact_scalars:
		# Version2 is canonical JSON written by this codec. This also rejects duplicate
		# envelope keys that the generic JSON parser would otherwise silently merge.
		for key in envelope:
			if key not in ["format", "envelope_version", "payload_codec", "payload_json", "payload_sha256"]:
				return _error("INCOMPATIBLE_FORMAT", "无损数值封套存在未知字段，不自动回退")
		if envelope.size() != 5 or envelope.get("payload_codec") != "scalar_bits_le_v1" or text != JSON.stringify(envelope, "", true, true):
			return _error("INCOMPATIBLE_FORMAT", "无损数值封套格式未知或非规范，不自动回退")
	var payload_text: Variant = envelope.get("payload_json")
	if not payload_text is String or envelope.get("payload_sha256") != payload_text.sha256_text():
		return _error("CORRUPT", "存档校验和不符")
	if parser.parse(payload_text) != OK:
		return _error("CORRUPT", "存档内容JSON损坏")
	var decoded_payload: Variant = parser.data
	if _exact_scalars:
		if payload_text != JSON.stringify(decoded_payload, "", true, true):
			return _error("INCOMPATIBLE_CODEC", "无损数值树非规范，不自动回退")
		var decoded: Dictionary = ExactScalarCodec.decode(decoded_payload)
		if not decoded.get("ok", false):
			return _error("INCOMPATIBLE_CODEC", "无损数值编码无效或未知，不自动回退")
		decoded_payload = decoded["value"]
	if not decoded_payload is Dictionary:
		return _error("CORRUPT", "存档内容对象损坏")
	var payload: Dictionary = decoded_payload
	if payload.get("project_id") != PROJECT_ID or payload.get("save_epoch") != SAVE_EPOCH:
		return _error("INCOMPATIBLE_EPOCH", "存档项目/世代不匹配，不能自动回退")
	if payload.get("save_schema_version") != _schema_version:
		return _ordered_compatibility_error("UNSUPPORTED_SCHEMA", "存档Schema未知或需要迁移，不能自动回退", payload)
	if not _integer(payload.get("sequence")) or payload["sequence"] < 0 or payload.get("kind") not in ["main", "manual"]:
		return _error("CORRUPT", "存档序号或类型损坏")
	if not expected_kind.is_empty() and payload["kind"] != expected_kind:
		return _ordered_compatibility_error("POLICY_DENIED", "手动/自动存档类型不符，不执行隐式恢复", payload)
	var state: Variant = payload.get("state")
	if not state is Dictionary:
		return _error("CORRUPT", "存档世界状态损坏")
	var validation := _validate_state(state)
	if not validation.get("ok", false) and validation.get("recoverable_corruption", true) == false:
		return _ordered_compatibility_error(str(validation.get("code", "INCOMPATIBLE_STATE_CONTRACT")), str(validation.get("message", "世界组件合同不兼容")), payload)
	if not validation.get("ok", false) or payload.get("world_id") != state.get("world_id"):
		return _error("CORRUPT", "存档状态校验失败")
	if not _world_id.is_empty() and state["world_id"] != _world_id:
		return _error("INCOMPATIBLE_WORLD", "存档属于其他世界")
	return {"ok": true, "state": state, "sequence": int(payload["sequence"]), "kind": payload["kind"], "payload_sha256": envelope["payload_sha256"]}

func _ordered_compatibility_error(code: String, message: String, payload: Dictionary) -> Dictionary:
	var result := _error(code, message)
	# Caller has verified the envelope hash, project and epoch. This common metadata
	# belongs to the envelope contract, independently of the unsupported state schema.
	if not _world_id.is_empty() and payload.get("world_id") == _world_id and _integer(payload.get("sequence")) and payload["sequence"] >= 0:
		result["ordering_verified"] = true
		result["sequence_hint"] = int(payload["sequence"])
	return result

func _atomic_write(path: String, text: String) -> Dictionary:
	if not _generation_binding_valid():
		return _generation_init_error.duplicate(true)
	if _windows_generations != null:
		var key := _generation_key(path)
		var verified := _decode_text(text)
		if key.is_empty() or not verified.get("ok", false):
			return _error("GENERATION_CANDIDATE_INVALID", "存档代写入前校验失败")
		if not _generation_binding_valid():
			return _generation_init_error.duplicate(true)
		var result: Dictionary = _generation_write(key, text, int(verified["sequence"]))
		if not _generation_binding_valid():
			return _generation_init_error.duplicate(true)
		if not result.get("ok", false) and result.get("committed", false):
			result["main_committed"] = key == "main"
		return result
	if _maximum_bytes > 0 and text.to_utf8_buffer().size() > _maximum_bytes:
		return _error("SAVE_SIZE_LIMIT", "技术快照超出已批准大小限制")
	var temporary := path + ".tmp"
	var handle := FileAccess.open(temporary, FileAccess.WRITE)
	if handle == null:
		return _error("IO_ERROR", "无法写入临时存档")
	handle.store_string(text)
	handle.flush()
	var error := handle.get_error()
	handle.close()
	if error != OK:
		return _error("IO_ERROR", "临时存档写入失败")
	var verified := _read(temporary)
	if not verified.get("ok", false):
		return verified
	if DirAccess.rename_absolute(temporary, path) != OK:
		return _error("IO_ERROR", "存档原子提升失败，旧文件保留")
	return {"ok": true}

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and absf(float(value)) <= SandboxServerAuthority.MAX_EXACT_JSON_INTEGER and float(value) == floor(float(value))

func _error(code: String, message: String) -> Dictionary:
	last_error = {"ok": false, "code": code, "message": message}
	return last_error.duplicate(true)

static func _linux_process_birth(pid: int) -> String:
	if OS.get_name() != "Linux":
		return ""
	var path := "/proc/%d/stat" % pid
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	# procfs reports zero size; read a line rather than a length-sized buffer.
	var text := file.get_line()
	file.close()
	var end := text.rfind(")")
	if end < 0:
		return ""
	var fields := text.substr(end + 2).split(" ", false)
	return fields[19] if fields.size() > 19 else ""

func _validate_state(state: Dictionary) -> Dictionary:
	# Only trusted server composition configures this callback. No RPC accepts it.
	if _state_validator.is_valid():
		var result: Variant = _state_validator.call(state)
		if result is Dictionary and typeof(result.get("ok")) == TYPE_BOOL:
			return result
		return {"ok": false, "code": "INVALID_VALIDATOR_RESULT", "message": "服务器状态校验器返回无效", "recoverable_corruption": false}
	return SandboxServerAuthority.validate_persistent_state(state)
