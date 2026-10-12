extends "res://scripts/network/network_main.gd"
## Explicit 010 technical session. Authority owns creation; clients consume saved rows.
const WorldComponent = preload("res://scripts/world_session/world_component.gd")
const WorldSeed = preload("res://scripts/worldgen/world_seed.gd")
const WorldView = preload("res://scripts/world_session/world_view.gd")
var _world: RefCounted
var _world_view: Node2D
var _received_component: Dictionary = {}
var _received_hash: String = ""

func _prepare_session() -> bool:
	if _mode in ["server", "host"] and _save_directory.is_empty():
		_fail("WORLD_SAVE_REQUIRED", "010世界必须有独立持久目录")
		return false
	var documents: Array = []
	for path in ["generation_settings.json", "prefab_settings.json", "world_bundle010.json"]:
		var document: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + path))
		if not document is Dictionary:
			_fail("WORLD_INPUT_INVALID", path)
			return false
		documents.append(document)
	_world = WorldComponent.new(documents[0], documents[1], documents[2])
	if not _world.ready:
		_fail("WORLD_INPUT_INVALID", _world.last_error)
		return false
	_world_view = WorldView.new()
	_world_view.name = "TechnicalWorld"
	add_child(_world_view)
	return true

func _make_save_store() -> SandboxSaveStore:
	return SandboxSaveStore.new(_save_directory, int(_save_settings["automatic_backup_count"]), int(_save_settings["manual_slot_count"]), _catalogue.source_sha256, int(_settings["network_protocol_version"]), _world.validate_combined_state, 2, 4194304)

func _create_new_world() -> bool:
	var requested: Variant = null
	if _arguments.has("seed"):
		var parsed: Dictionary = WorldSeed.from_decimal(_arguments["seed"])
		if not parsed["ok"]:
			_fail(parsed["code"], "Seed必须是精确整数十进制")
			return false
		requested = parsed["value"]
	var result: Dictionary = _world.create(_authority.world_id, requested, _arguments.get("test_entry", "false") == "true", 32)
	if not result["ok"]:
		_fail(result["code"], "世界创建失败，未开始监听")
		return false
	if _arguments.get("technical_clear_fixture", "false") == "true":
		result = _world.technical_clear_cell(1, [200, 0])
		if not result["ok"]:
			_fail(result["code"], "技术持久变化夹具被拒绝")
			return false
		_authority.revision += 1
	return true

func _restore_authority_state(state: Dictionary) -> Dictionary:
	var checked: Dictionary = _world.validate_combined_state(state)
	if not checked["ok"]:
		return checked
	var restored: Dictionary = _world.restore(state["world_component"], state["world_id"])
	if not restored["ok"]:
		return restored
	return _authority.restore_persistent_state(WorldComponent.authority_state(state))

func _persistent_state_for_save(advance_auto: bool) -> Dictionary:
	return _world.combine(super._persistent_state_for_save(advance_auto))

func _public_snapshot() -> Dictionary:
	var result: Dictionary = super._public_snapshot()
	result["world_component"] = _world.public_component()
	return result

func _base_hello(display_name: String) -> Dictionary:
	var request: Dictionary = super._base_hello(display_name)
	request["world_contract"] = WorldComponent.CONTRACT
	request["world_bundle_sha256"] = _world.bundle_sha256
	return request

func _validate_remote_hello(request: Dictionary) -> Dictionary:
	if request.get("world_contract") != WorldComponent.CONTRACT or request.get("world_bundle_sha256") != _world.bundle_sha256:
		return {"ok": false, "code": "WORLD_CONTRACT_MISMATCH", "message": "技术世界版本或模板来源不兼容"}
	var filtered: Dictionary = request.duplicate(true)
	filtered.erase("world_contract")
	filtered.erase("world_bundle_sha256")
	return {"ok": true, "request": filtered}

func _client_accept_snapshot(incoming: Dictionary) -> bool:
	if not incoming.get("world_id") is String or not incoming.get("players") is Dictionary or _contains_private_key(incoming):
		_fail("WORLD_PUBLIC_SNAPSHOT_INVALID", "服务器公开快照无效")
		return false
	var checked: Dictionary = _world.validate_component(incoming.get("world_component"), incoming["world_id"])
	if not checked["ok"]:
		_fail(checked["code"], "服务器世界组件校验失败")
		return false
	_received_component = checked["component"]
	_received_hash = JSON.stringify(_received_component, "", true, true).sha256_text()
	return true

func _after_client_snapshot(_incoming: Dictionary) -> void:
	_world_view.consume(_received_component, _mode)

func _sync_server_nodes() -> void:
	super._sync_server_nodes()
	_world_view.consume(_world.public_component(), _mode)

func _write_report(data: Dictionary) -> void:
	var report: Dictionary = data.duplicate(true)
	if _world != null:
		report["world_statistics"] = _world.statistics()
		report["received_component_sha256"] = _received_hash
		report["world_contract"] = WorldComponent.CONTRACT
	if _world_view != null:
		report["world_view"] = _world_view.statistics()
	super._write_report(report)

func _on_server_disconnected() -> void:
	if _arguments.get("expect_server_shutdown", "false") == "true" and _reported_ready and not _closing:
		_closing = true
		_write_report({"status": "expected_server_shutdown", "snapshot": _snapshot, "player_profile_id": _welcome.get("player_profile_id"), "player_instance_id": _welcome.get("player_instance_id")})
		get_tree().quit(0)
		return
	super._on_server_disconnected()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		_stop_requested = true

static func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if key in ["resume_secret", "secret_hash", "profiles"] or _contains_private_key(value[key]):
				return true
	elif value is Array:
		for item in value:
			if _contains_private_key(item):
				return true
	return false
