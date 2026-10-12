extends RefCounted
## Explicit new ordinary-Windows layout. Immutable payload and published complete
## marker per generation; no existing file is replaced. This proves a protocol
## for process interruption, not filesystem flush/power-loss durability.
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const FORMAT := "ordinary_windows_generations_v1"
const MAX_SEQUENCE: int = 9007199254740991
const MAX_RECORDS := 8
const KEEP_VALID := 2
const REPORT_RECORDS := 3
const MARKER_LIMIT := 16384
const MARKER_FIELDS := ["format", "schema_version", "record_kind", "logical_name", "sequence", "data_size_bytes", "data_sha256"]
var ready: bool = false
var _root: String = ""
var _kind: String = ""
var _maximum_bytes: int = 0
var _logical_names: Array = []

func configure(root: String, record_kind: String, logical_names: Array = []) -> Dictionary:
	if ready or not _root.is_empty() or not root.is_absolute_path() or root != root.simplify_path() or record_kind not in ["save_schema4", "slot_index_v1", "local_report_v1"] or _is_link(root):
		return _bad("GENERATION_CONFIG_INVALID")
	_logical_names = logical_names.duplicate() if not logical_names.is_empty() else (["main"] if record_kind == "save_schema4" else ["index"] if record_kind == "slot_index_v1" else ["server"])
	if _logical_names.size() > 128:
		return _bad("GENERATION_CONFIG_INVALID")
	var unique: Dictionary = {}
	for name in _logical_names:
		if not name is String or not _logical(name) or unique.has(name):
			return _bad("GENERATION_CONFIG_INVALID")
		unique[name] = true
	_logical_names.sort()
	_root = root
	_kind = record_kind
	_maximum_bytes = 131072 if record_kind == "slot_index_v1" else 4194304
	var checked := _layout(false)
	if not checked["ok"] and checked["code"] != "MISSING":
		return checked
	ready = true
	return {"ok": true}

func read_latest(logical_name: String, validator: Callable) -> Dictionary:
	var scanned := _scan(logical_name, validator)
	if not scanned["ok"]:
		return scanned
	if scanned["records"].is_empty():
		return _bad("MISSING")
	var selected: Dictionary = scanned["records"][0]
	var data := _read_text(selected["directory"].path_join("payload.dat"), _maximum_bytes)
	if not data["ok"] or data["text"].sha256_text() != selected["sha256"]:
		return _bad("GENERATION_COMMITTED_DATA_CHANGED")
	return {"ok": true, "text": data["text"], "sequence": selected["sequence"], "sha256": selected["sha256"],
		"valid_generations": scanned["records"].size(), "uncommitted_generations": scanned["uncommitted"], "layout": FORMAT}

func write_generation(logical_name: String, text: String, sequence: int, validator: Callable) -> Dictionary:
	if not ready or not _logical(logical_name) or logical_name not in _logical_names or not _sequence(sequence) or not validator.is_valid() or text.to_utf8_buffer().size() < 1 or text.to_utf8_buffer().size() > _maximum_bytes:
		return _bad("GENERATION_WRITE_INVALID")
	if not _validate_text(text, sequence, validator):
		return _bad("GENERATION_CANDIDATE_INVALID")
	var layout := _layout(true)
	if not layout["ok"]:
		return layout
	var logical := _root.path_join(logical_name)
	if _is_link(logical) or DirAccess.make_dir_recursive_absolute(logical) != OK:
		return _bad("GENERATION_DIRECTORY_FAILED")
	var before := _scan(logical_name, validator)
	if not before["ok"]:
		return before
	if before["directory_count"] >= _record_limit():
		return _bad("GENERATION_DISK_PRESSURE")
	if not before["records"].is_empty() and sequence <= before["records"][0]["sequence"]:
		return _bad("GENERATION_SEQUENCE_COLLISION")
	var nonce := Crypto.new().generate_random_bytes(16).hex_encode()
	var directory := logical.path_join("g_" + str(sequence) + "_" + nonce)
	if DirAccess.make_dir_absolute(directory) != OK:
		return _bad("GENERATION_DIRECTORY_FAILED")
	var data := _write_new(directory.path_join("payload.dat"), text, _maximum_bytes)
	if not data["ok"]:
		return data # No complete marker exists, so interrupted data is not committed.
	var readback := _read_text(directory.path_join("payload.dat"), _maximum_bytes)
	if not readback["ok"] or readback["text"] != text or not _validate_text(readback["text"], sequence, validator):
		return _bad("GENERATION_DATA_VERIFY_FAILED")
	var marker := {"format": FORMAT, "schema_version": 1, "record_kind": _kind, "logical_name": logical_name,
		"sequence": sequence, "data_size_bytes": text.to_utf8_buffer().size(), "data_sha256": text.sha256_text()}
	var encoded: Dictionary = Codec.encode(marker)
	if not encoded.get("ok", false):
		return _bad("GENERATION_MARKER_ENCODE_FAILED")
	var marker_text := JSON.stringify(encoded["value"], "", true, true)
	var temporary := directory.path_join("complete.tmp")
	var written := _write_new(temporary, marker_text, MARKER_LIMIT)
	if not written["ok"]:
		return written
	var verified := _read_marker(temporary, logical_name, sequence)
	if not verified["ok"]:
		return verified
	var complete := directory.path_join("complete.json")
	# Destination has never existed in this exclusive random record directory.
	# Unlike overwriting index/main, this Windows MoveFile path deletes no target.
	if _exists(complete) or DirAccess.rename_absolute(temporary, complete) != OK:
		return _bad("GENERATION_MARKER_PUBLISH_FAILED")
	var after := _scan(logical_name, validator)
	if not after["ok"]:
		return _committed_failure(str(after["code"]), sequence)
	var retained := _retain_two(after["records"])
	if not retained["ok"]:
		return _committed_failure(str(retained["code"]), sequence)
	return {"ok": true, "committed": true, "sequence": sequence, "complete": true, "sha256": text.sha256_text()}

func _scan(logical_name: String, validator: Callable) -> Dictionary:
	if not ready or not _logical(logical_name) or logical_name not in _logical_names or not validator.is_valid():
		return _bad("GENERATION_READ_INVALID")
	var layout := _layout(false)
	if not layout["ok"]:
		if layout["code"] == "MISSING":
			return {"ok": true, "records": [], "uncommitted": 0, "directory_count": 0}
		return layout
	var logical := _root.path_join(logical_name)
	if _is_link(logical):
		return _bad("GENERATION_LINK_REFUSED")
	if not DirAccess.dir_exists_absolute(logical):
		return _bad("GENERATION_LAYOUT_CONTENT_INVALID") if FileAccess.file_exists(logical) else {"ok": true, "records": [], "uncommitted": 0, "directory_count": 0}
	var entries := _directory_entries(logical, _record_limit() + 1)
	if not entries["ok"]:
		return entries
	var names: Array[String] = []
	# A hint may be absent, stale or corrupt. It never selects the committed head.
	for entry in entries["entries"]:
		if entry["directory"]:
			names.append(entry["name"])
		elif entry["name"] != "hint.json" or _is_link(logical.path_join(entry["name"])):
			return _bad("GENERATION_LAYOUT_CONTENT_INVALID")
	if names.size() > _record_limit():
		return _bad("GENERATION_DISK_PRESSURE")
	var records: Array = []
	var sequences: Dictionary = {}
	var uncommitted: int = 0
	for name in names:
		var parts: PackedStringArray = name.split("_")
		if parts.size() != 3 or parts[0] != "g" or not parts[1].is_valid_int() or str(int(parts[1])) != parts[1] or not _sequence(int(parts[1])) or not _hex(parts[2], 32):
			return _bad("GENERATION_LAYOUT_CONTENT_INVALID")
		var path := logical.path_join(name)
		if _is_link(path):
			return _bad("GENERATION_LINK_REFUSED")
		var content := _directory_entries(path, 3)
		if not content["ok"]:
			return content
		for entry in content["entries"]:
			var file: String = entry["name"]
			if entry["directory"] or file not in ["payload.dat", "complete.tmp", "complete.json"] or _is_link(path.path_join(file)):
				return _bad("GENERATION_LAYOUT_CONTENT_INVALID")
			var handle := FileAccess.open(path.path_join(file), FileAccess.READ)
			if handle == null:
				return _bad("GENERATION_READ_FAILED")
			var size: int = handle.get_length()
			handle.close()
			if size > (_maximum_bytes if file == "payload.dat" else MARKER_LIMIT):
				return _bad("GENERATION_DISK_PRESSURE")
		var complete := path.path_join("complete.json")
		if not _exists(complete):
			uncommitted += 1
			continue
		var marker := _read_marker(complete, logical_name, int(parts[1]))
		if not marker["ok"]:
			return marker # Present complete is a promise; never roll back silently.
		var value: Dictionary = marker["value"]
		var data := _read_text(path.path_join("payload.dat"), _maximum_bytes)
		if not data["ok"] or data["text"].to_utf8_buffer().size() != value["data_size_bytes"] or data["text"].sha256_text() != value["data_sha256"]:
			return _bad("GENERATION_COMMITTED_HASH_INVALID")
		var checked: Variant = validator.call(data["text"])
		if not _valid_checked_text(checked, value["sequence"]):
			# An explicitly incompatible terrain contract is not corrupt data and
			# must remain visible to the ordinary slot UI. Never select an older head.
			if checked is Dictionary and checked.get("ok") is bool and not checked["ok"] and typeof(checked.get("code")) == TYPE_STRING and checked["code"] == "TERRAIN_CONTRACT_INCOMPATIBLE":
				return _bad("TERRAIN_CONTRACT_INCOMPATIBLE")
			return _bad("GENERATION_COMMITTED_SCHEMA_INVALID")
		if sequences.has(value["sequence"]):
			return _bad("GENERATION_SEQUENCE_COLLISION")
		sequences[value["sequence"]] = true
		records.append({"directory": path, "sequence": value["sequence"], "sha256": value["data_sha256"]})
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["sequence"] > b["sequence"])
	return {"ok": true, "records": records, "uncommitted": uncommitted, "directory_count": names.size()}

func _record_limit() -> int:
	return REPORT_RECORDS if _kind == "local_report_v1" else MAX_RECORDS

func _retain_two(records: Array) -> Dictionary:
	# A session publishes at most startup, close_cursor and terminal. Retain all
	# three immutable reports so a concurrent reader never races retirement.
	if _kind == "local_report_v1":
		return {"ok": true} if records.size() <= REPORT_RECORDS else _bad("GENERATION_DISK_PRESSURE")
	# Initial commit has one generation; from the second onward keep distinct
	# newest two. Remove an older complete marker first, never its data first.
	for index in range(KEEP_VALID, records.size()):
		var directory: String = records[index]["directory"]
		if DirAccess.remove_absolute(directory.path_join("complete.json")) != OK:
			return _bad("GENERATION_DISK_PRESSURE")
		for filename in ["payload.dat", "complete.tmp"]:
			var path := directory.path_join(filename)
			if _exists(path) and DirAccess.remove_absolute(path) != OK:
				return _bad("GENERATION_DISK_PRESSURE")
		if DirAccess.remove_absolute(directory) != OK:
			return _bad("GENERATION_DISK_PRESSURE")
	return {"ok": true}

func has_layout() -> bool:
	return _exists(_root)

func _layout(create: bool) -> Dictionary:
	if _is_link(_root):
		return _bad("GENERATION_LINK_REFUSED")
	if not DirAccess.dir_exists_absolute(_root):
		if _exists(_root):
			return _bad("GENERATION_LAYOUT_INVALID")
		if not create:
			return _bad("MISSING")
		if DirAccess.make_dir_recursive_absolute(_root) != OK:
			return _bad("GENERATION_DIRECTORY_FAILED")
	var path := _root.path_join("layout.json")
	var expected := {"format": FORMAT, "schema_version": 1, "record_kind": _kind, "logical_names": _logical_names.duplicate()}
	if not _exists(path):
		var empty := _directory_entries(_root, 0)
		if not create or not empty["ok"]:
			return _bad("GENERATION_LAYOUT_UNRECOGNIZED")
		var text := JSON.stringify(Codec.encode(expected)["value"], "", true, true)
		var staged := _write_new(_root.path_join("layout.tmp"), text, MARKER_LIMIT)
		if not staged["ok"] or _exists(path) or DirAccess.rename_absolute(_root.path_join("layout.tmp"), path) != OK:
			return _bad("GENERATION_LAYOUT_PUBLISH_FAILED")
	var root_entries := _directory_entries(_root, _logical_names.size() + 2)
	if not root_entries["ok"]:
		return root_entries
	for entry in root_entries["entries"]:
		var name: String = entry["name"]
		if _is_link(_root.path_join(name)) or (entry["directory"] and name not in _logical_names) or (not entry["directory"] and name not in ["layout.json", "layout.tmp"]):
			return _bad("GENERATION_LAYOUT_CONTENT_INVALID")
	var read := _read_text(path, MARKER_LIMIT)
	if not read["ok"]:
		return read
	var parser := JSON.new()
	if parser.parse(read["text"]) != OK:
		return _bad("GENERATION_LAYOUT_INVALID")
	var decoded: Dictionary = Codec.decode(parser.data)
	if not decoded.get("ok", false) or not _same(decoded["value"], expected):
		return _bad("GENERATION_LAYOUT_INVALID")
	return {"ok": true}

func _read_marker(path: String, logical: String, sequence: int) -> Dictionary:
	var read := _read_text(path, MARKER_LIMIT)
	if not read["ok"]:
		return _bad("GENERATION_COMMITTED_MARKER_INVALID")
	var parser := JSON.new()
	if parser.parse(read["text"]) != OK:
		return _bad("GENERATION_COMMITTED_MARKER_INVALID")
	var decoded: Dictionary = Codec.decode(parser.data)
	if not decoded.get("ok", false) or not _fields(decoded.get("value"), MARKER_FIELDS):
		return _bad("GENERATION_COMMITTED_MARKER_INVALID")
	var marker: Dictionary = decoded["value"]
	for field in ["format", "record_kind", "logical_name", "data_sha256"]:
		if not marker[field] is String:
			return _bad("GENERATION_COMMITTED_MARKER_INVALID")
	if marker["format"] != FORMAT or typeof(marker["schema_version"]) != TYPE_INT or marker["schema_version"] != 1 or marker["record_kind"] != _kind or marker["logical_name"] != logical or not _sequence(marker["sequence"]) or marker["sequence"] != sequence or typeof(marker["data_size_bytes"]) != TYPE_INT or marker["data_size_bytes"] < 1 or marker["data_size_bytes"] > _maximum_bytes or not _hex(marker["data_sha256"], 64):
		return _bad("GENERATION_COMMITTED_MARKER_INVALID")
	return {"ok": true, "value": marker}

func _validate_text(text: String, sequence: int, validator: Callable) -> bool:
	return _valid_checked_text(validator.call(text), sequence)

func _valid_checked_text(checked: Variant, sequence: int) -> bool:
	return checked is Dictionary and checked.get("ok") is bool and checked["ok"] and (_kind == "slot_index_v1" or (_sequence(checked.get("sequence")) and checked["sequence"] == sequence))

static func _directory_entries(path: String, maximum: int) -> Dictionary:
	var directory := DirAccess.open(path)
	if directory == null:
		return _bad("GENERATION_READ_FAILED")
	directory.include_hidden = true
	directory.include_navigational = false
	if directory.list_dir_begin() != OK:
		return _bad("GENERATION_READ_FAILED")
	var entries: Array = []
	while true:
		var name := directory.get_next()
		if name.is_empty():
			break
		if entries.size() >= maximum:
			directory.list_dir_end()
			return _bad("GENERATION_DISK_PRESSURE")
		entries.append({"name": name, "directory": directory.current_is_dir()})
	directory.list_dir_end()
	return {"ok": true, "entries": entries}

static func _fields(value: Variant, fields: Array) -> bool:
	if not value is Dictionary or value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true

static func _write_new(path: String, text: String, maximum: int) -> Dictionary:
	if _exists(path) or text.to_utf8_buffer().size() < 1 or text.to_utf8_buffer().size() > maximum:
		return _bad("GENERATION_WRITE_ONCE_REFUSED")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _bad("GENERATION_WRITE_FAILED")
	var written: bool = file.store_string(text)
	file.flush()
	var error: int = file.get_error()
	file.close()
	var readback := _read_text(path, maximum)
	if not written or error != OK or not readback["ok"] or readback["text"] != text:
		return _bad("GENERATION_WRITE_VERIFY_FAILED")
	return {"ok": true}

static func _read_text(path: String, maximum: int) -> Dictionary:
	if _is_link(path):
		return _bad("GENERATION_LINK_REFUSED")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _bad("GENERATION_READ_FAILED")
	var size: int = file.get_length()
	if size < 1 or size > maximum:
		file.close()
		return _bad("GENERATION_DATA_SIZE")
	var bytes: PackedByteArray = file.get_buffer(size)
	var after_size: int = file.get_length()
	var error: int = file.get_error()
	file.close()
	var text: String = bytes.get_string_from_utf8()
	if error not in [OK, ERR_FILE_EOF] or after_size != size or bytes.size() != size or text.to_utf8_buffer() != bytes:
		return _bad("GENERATION_READ_FAILED")
	return {"ok": true, "text": text}

static func _is_link(path: String) -> bool:
	var parent := DirAccess.open(path.get_base_dir())
	return parent != null and parent.is_link(path.get_file())

static func _exists(path: String) -> bool:
	return _is_link(path) or FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)

static func _sequence(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value > 0 and value <= MAX_SEQUENCE

static func _logical(value: String) -> bool:
	if value.is_empty() or value.length() > 32:
		return false
	for letter in value:
		if letter not in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return true

static func _hex(value: Variant, length: int) -> bool:
	if not value is String or value.length() != length:
		return false
	for letter in value:
		if letter not in "0123456789abcdef":
			return false
	return true

static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and var_to_bytes(a) == var_to_bytes(b)

static func _committed_failure(code: String, sequence: int) -> Dictionary:
	return {"ok": false, "code": code, "committed": true, "complete": false, "sequence": sequence}

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "committed": false}
