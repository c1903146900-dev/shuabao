extends RefCounted
## Single-authority technical preview store. Not batch004's formal world schema.
const Validator = preload("res://scripts/worldgen/layout_validator.gd")
const MAX_PREVIEW_BYTES: int = 1048576 # Operational preview cap, not world balance.
var _validator: RefCounted
var _directory: String
var ready: bool = false

func _init(input_document: Dictionary, directory: String = "user://generation_previews") -> void:
	_validator = Validator.new(input_document)
	_directory = directory.trim_suffix("/")
	ready = _validator._inputs.ready and (_directory == "user://generation_previews" or _directory.begins_with("user://generation_previews/")) and not ".." in _directory and not "\\" in _directory

func exists(world_id: String) -> bool:
	return ready and SandboxServerAuthority._valid_id(world_id, "world_") and FileAccess.file_exists(_path(world_id))

func create(plan: Variant) -> Dictionary:
	if not ready or not plan is Dictionary or not SandboxServerAuthority._valid_id(plan.get("world_id"), "world_"):
		return _error("INVALID_PREVIEW_STORE_OR_WORLD")
	var checked: Dictionary = _validator.validate(plan, plan["world_id"])
	if not checked["ok"]:
		return checked
	if exists(plan["world_id"]):
		return _error("PREVIEW_ALREADY_EXISTS")
	return _write(checked["plan"])

func load_existing(world_id: String) -> Dictionary:
	if not ready or not SandboxServerAuthority._valid_id(world_id, "world_"):
		return _error("INVALID_PREVIEW_STORE_OR_WORLD")
	var path: String = _path(world_id)
	if not FileAccess.file_exists(path):
		return _error("PREVIEW_NOT_FOUND_NO_REGENERATION")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("PREVIEW_READ_FAILED")
	if file.get_length() > MAX_PREVIEW_BYTES:
		file.close()
		return _error("PREVIEW_SIZE_LIMIT")
	var text: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _error("PREVIEW_JSON_INVALID")
	var envelope: Variant = parser.data
	if not envelope is Dictionary or envelope.size() != 4 or not envelope.get("format") is String or envelope["format"] != "shaheyouxi_technical_layout_v1" or not envelope.get("world_id") is String or envelope["world_id"] != world_id or not envelope.get("payload_json") is String or not envelope.get("payload_sha256") is String:
		return _error("PREVIEW_ENVELOPE_INVALID")
	if envelope["payload_json"].sha256_text() != envelope["payload_sha256"]:
		return _error("PREVIEW_CHECKSUM_MISMATCH")
	var payload_parser := JSON.new()
	if payload_parser.parse(envelope["payload_json"]) != OK:
		return _error("PREVIEW_PAYLOAD_JSON_INVALID")
	var checked: Dictionary = _validator.validate(payload_parser.data, world_id)
	if checked["ok"]:
		checked["revision_sha256"] = envelope["payload_sha256"]
	return checked

func update_permanent_changes(plan: Variant, expected_revision_sha256: String) -> Dictionary:
	if not ready or not plan is Dictionary or not SandboxServerAuthority._valid_id(plan.get("world_id"), "world_"):
		return _error("INVALID_PREVIEW_STORE_OR_WORLD")
	var current: Dictionary = load_existing(plan["world_id"])
	if not current["ok"]:
		return current
	if current["revision_sha256"] != expected_revision_sha256:
		return _error("PREVIEW_REVISION_CONFLICT")
	var checked: Dictionary = _validator.validate(plan, plan["world_id"])
	if not checked["ok"]:
		return checked
	# A current revision permits appending changes, never resurrecting cleared rock.
	var old_changes: Dictionary = current["plan"]["permanent_changes"]
	var new_changes: Dictionary = checked["plan"]["permanent_changes"]
	for key in old_changes:
		if not new_changes.has(key) or new_changes[key] != old_changes[key]:
			return _error("PERMANENT_CHANGE_REVERSAL_FORBIDDEN")
	var old_immutable: Dictionary = current["plan"].duplicate(true)
	var new_immutable: Dictionary = checked["plan"].duplicate(true)
	old_immutable.erase("permanent_changes")
	new_immutable.erase("permanent_changes")
	if old_immutable != new_immutable:
		return _error("GENERATED_LAYOUT_IS_IMMUTABLE")
	return _write(checked["plan"])

func _write(plan: Dictionary) -> Dictionary:
	var payload: String = JSON.stringify(plan, "", true, true)
	var digest: String = payload.sha256_text()
	var envelope: String = JSON.stringify({"format": "shaheyouxi_technical_layout_v1", "world_id": plan["world_id"], "payload_json": payload, "payload_sha256": digest}, "", true, true)
	if envelope.to_utf8_buffer().size() > MAX_PREVIEW_BYTES:
		return _error("PREVIEW_SIZE_LIMIT")
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_directory)) != OK:
		return _error("PREVIEW_DIRECTORY_FAILED")
	var path: String = _path(plan["world_id"])
	var temporary: String = path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _error("PREVIEW_WRITE_FAILED")
	file.store_string(envelope)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return _error("PREVIEW_WRITE_FAILED")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return _error("PREVIEW_ATOMIC_RENAME_FAILED")
	return {"ok": true, "revision_sha256": digest, "formal_world_allowed": false}

func _path(world_id: String) -> String:
	return _directory.path_join(world_id + ".json")

static func _error(code: String) -> Dictionary:
	return {"ok": false, "code": code, "formal_world_allowed": false}
