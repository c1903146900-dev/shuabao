extends RefCounted
## Single-authority technical artifacts only; full world transactions remain 010.
const Validator = preload("res://scripts/prefab/prefab_validator.gd")
const MAX_BYTES: int = 1048576
var _validator: RefCounted
var _directory: String
var ready: bool = false

func _init(generation_document: Dictionary, prefab_document: Dictionary, directory: String = "user://prefab_previews") -> void:
	_validator = Validator.new(generation_document, prefab_document)
	_directory = directory.trim_suffix("/")
	ready = _validator.ready and (_directory == "user://prefab_previews" or _directory.begins_with("user://prefab_previews/")) and not ".." in _directory and not "\\" in _directory

func save_template(value: Variant, expected_revision: String = "") -> Dictionary:
	if not ready:
		return _error("PREFAB_STORE_NOT_READY")
	var checked: Dictionary = _validator.validate_template(value)
	if not checked.get("ok", false):
		return checked
	var template: Dictionary = checked["template"]
	var identity: String = template["template_id"]
	if not _safe_id(identity):
		return _error("PREFAB_ID_INVALID")
	var exists: bool = FileAccess.file_exists(_path("templates", identity))
	if exists:
		var previous: Dictionary = load_template(identity)
		if not previous.get("ok", false):
			return previous
		if expected_revision.is_empty() or expected_revision != previous["revision_sha256"]:
			return _error("PREFAB_TEMPLATE_REVISION_CONFLICT")
		if template != previous["template"] and int(template["revision"]) != int(previous["template"]["revision"]) + 1:
			return _error("PREFAB_TEMPLATE_REVISION_SEQUENCE_INVALID")
	elif not expected_revision.is_empty():
		return _error("PREFAB_TEMPLATE_NOT_FOUND_NO_REGENERATION")
	return _write("templates", identity, template)

func load_template(template_id: String) -> Dictionary:
	var loaded: Dictionary = _read("templates", template_id)
	if not loaded.get("ok", false):
		return loaded
	var checked: Dictionary = _validator.validate_template(loaded["payload"])
	if not checked.get("ok", false):
		return checked
	if checked["template"].get("template_id") != template_id:
		return _error("PREFAB_PAYLOAD_ID_MISMATCH")
	checked["revision_sha256"] = loaded["revision_sha256"]
	return checked

func create_instance(value: Variant) -> Dictionary:
	if not ready or not value is Dictionary or not value.get("world_id") is String:
		return _error("PREFAB_INSTANCE_INVALID")
	var checked: Dictionary = _validator.validate_instance(value, value["world_id"])
	if not checked.get("ok", false):
		return checked
	var instance: Dictionary = checked["instance"]
	var identity: String = instance.get("prefab_instance_id", "")
	if not _safe_id(identity) or not identity.begins_with("prefab_"):
		return _error("PREFAB_INSTANCE_ID_INVALID")
	if FileAccess.file_exists(_path("instances", identity)):
		return _error("PREFAB_INSTANCE_ALREADY_EXISTS")
	return _write("instances", identity, instance)

func load_instance(prefab_instance_id: String, expected_world_id: String) -> Dictionary:
	var loaded: Dictionary = _read("instances", prefab_instance_id)
	if not loaded.get("ok", false):
		return loaded
	var checked: Dictionary = _validator.validate_instance(loaded["payload"], expected_world_id)
	if not checked.get("ok", false):
		return checked
	if checked["instance"].get("prefab_instance_id") != prefab_instance_id:
		return _error("PREFAB_PAYLOAD_ID_MISMATCH")
	checked["revision_sha256"] = loaded["revision_sha256"]
	return checked

func _read(kind: String, identity: String) -> Dictionary:
	if not ready or not _safe_id(identity):
		return _error("PREFAB_STORE_OR_ID_INVALID")
	var path: String = _path(kind, identity)
	if not FileAccess.file_exists(path):
		return _error("PREFAB_NOT_FOUND_NO_REGENERATION")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("PREFAB_READ_FAILED")
	if file.get_length() > MAX_BYTES:
		file.close()
		return _error("PREFAB_SIZE_LIMIT")
	var text: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _error("PREFAB_JSON_INVALID")
	var envelope: Variant = parser.data
	if not envelope is Dictionary or envelope.size() != 5 or envelope.get("format") != "shaheyouxi_technical_prefab_v1" or envelope.get("kind") != kind or envelope.get("id") != identity or not envelope.get("payload_json") is String or not envelope.get("payload_sha256") is String:
		return _error("PREFAB_ENVELOPE_INVALID")
	if envelope["payload_json"].sha256_text() != envelope["payload_sha256"]:
		return _error("PREFAB_CHECKSUM_MISMATCH")
	var payload_parser := JSON.new()
	if payload_parser.parse(envelope["payload_json"]) != OK:
		return _error("PREFAB_PAYLOAD_JSON_INVALID")
	return {"ok": true, "payload": payload_parser.data, "revision_sha256": envelope["payload_sha256"], "formal_world_allowed": false}

func _write(kind: String, identity: String, value: Dictionary) -> Dictionary:
	var payload: String = JSON.stringify(value, "", true, true)
	var digest: String = payload.sha256_text()
	var text: String = JSON.stringify({"format": "shaheyouxi_technical_prefab_v1", "kind": kind, "id": identity, "payload_json": payload, "payload_sha256": digest}, "", true, true)
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return _error("PREFAB_SIZE_LIMIT")
	var path: String = _path(kind, identity)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())) != OK:
		return _error("PREFAB_DIRECTORY_FAILED")
	var temporary: String = path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _error("PREFAB_WRITE_FAILED")
	file.store_string(text)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return _error("PREFAB_WRITE_FAILED")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) != OK:
		return _error("PREFAB_RENAME_FAILED")
	return {"ok": true, "revision_sha256": digest, "formal_world_allowed": false}

func _path(kind: String, identity: String) -> String:
	return _directory.path_join(kind).path_join(identity + ".json")

static func _safe_id(value: String) -> bool:
	if value.is_empty() or value.length() > 96:
		return false
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return true

static func _error(code: String) -> Dictionary:
	return {"ok": false, "code": code, "formal_world_allowed": false}
