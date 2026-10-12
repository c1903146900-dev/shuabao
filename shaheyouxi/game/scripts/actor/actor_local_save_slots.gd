extends RefCounted
## User-local slot metadata and read-only full schema4/5 inspection. No server,
## process, native space, world generation, migration or save writer is started.
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const Generations = preload("res://scripts/save/windows_generation_store.gd")
const Inputs = preload("res://scripts/actor/actor_inputs.gd")
const State = preload("res://scripts/actor/actor_state.gd")
const World = preload("res://scripts/world_session/world_component.gd")
const ActorSession = preload("res://scripts/actor/actor_session_state.gd")
const TerrainStore = preload("res://scripts/terrain/combined_terrain_store.gd")
const TerrainSession = preload("res://scripts/actor/actor_terrain_session_state.gd")
const Profiles = preload("res://scripts/inventory/inventory_save_profiles012.gd")
const ProfileMarker = preload("res://scripts/inventory/inventory_profile_marker012.gd")
const USER_ROOT := "user://local_play011"
const MAX_SLOTS := 16
const MAX_INDEX_BYTES := 131072
const MAX_SAVE_BYTES := 4194304
const MAX_SEQUENCE: int = 9007199254740991
const PROFILE_MARKER := ProfileMarker.FILENAME
const PROFILE_FIELDS := ProfileMarker.FIELDS
const MAX_PROFILE_BYTES := ProfileMarker.MAX_BYTES
const CREATION_QUARANTINE := "slot_creation_quarantine"
const MAX_QUARANTINED_CREATIONS := 16
const INDEX_FIELDS := ["schema_version", "slots", "last_slot_id"]
const SLOT_FIELDS := ["slot_id", "label", "status", "last_sequence", "world_id"]
var ready: bool = false
var _root: String = ""
var _index: Dictionary = {}
var _active_ticket: Dictionary = {}
# Kept outside the legacy four-field ticket and v1 index. Never caller-selected.
var _active_profile: Dictionary = {}
var _active_profile_faulted: bool = false
var _generation: int = 0
var _library_token: String = ""
var _index_generations: RefCounted
var _index_storage_sequence: int = 0

func configure() -> Dictionary:
	if ready or not _root.is_empty():
		return _bad("SLOT_ALREADY_CONFIGURED")
	_root = _storage_root()
	if not _root.is_absolute_path():
		return _bad("SLOT_USER_ROOT_INVALID")
	for name in ["", "slots", "sessions"]:
		var path := _root if name.is_empty() else _root.path_join(name)
		if _is_link(path) or DirAccess.make_dir_recursive_absolute(path) != OK:
			return _bad("SLOT_DIRECTORY_UNAVAILABLE")
	var library_lock := _root.path_join(".library_lock")
	if _is_link(library_lock) or DirAccess.make_dir_absolute(library_lock) != OK:
		return _bad("SLOT_LIBRARY_ALREADY_OPEN")
	_library_token = Crypto.new().generate_random_bytes(16).hex_encode()
	var ownership := _write_exact(library_lock.path_join("owner.json"), {"token": _library_token, "owner_id": get_instance_id()})
	if not ownership["ok"]:
		return ownership
	var index_lock := _root.path_join(".index_lock")
	if DirAccess.make_dir_absolute(index_lock) != OK:
		return _bad("SLOT_INDEX_BUSY")
	if _uses_windows_generations():
		if _path_exists(_root.path_join("index.json")):
			DirAccess.remove_absolute(index_lock)
			return _bad("SLOT_OLD_INDEX_LAYOUT_REFUSED")
		_index_generations = Generations.new()
		var generation_config: Dictionary = _index_generations.configure(_root.path_join("index_generations_v1"), "slot_index_v1")
		if not generation_config["ok"]:
			DirAccess.remove_absolute(index_lock)
			return generation_config
	var loaded := _load_index()
	if loaded["ok"]:
		_index_storage_sequence = loaded.get("storage_sequence", 0)
		if loaded.get("missing", false):
			var initial := _write_index_value(loaded["index"])
			if not initial["ok"]:
				loaded = initial
	DirAccess.remove_absolute(index_lock)
	if not loaded["ok"]:
		return loaded
	_index = loaded["index"]
	ready = true
	return {"ok": true}

func _uses_windows_generations() -> bool:
	return OS.get_name() == "Windows" # Test subclasses may select only their fresh fixture roots.

func _storage_root() -> String:
	return ProjectSettings.globalize_path(USER_ROOT).simplify_path()

func list_slots() -> Dictionary:
	if not ready or not _owns_library():
		return _bad("SLOT_NOT_READY")
	var loaded := _load_index()
	if not loaded["ok"]:
		return loaded
	_index = loaded["index"]
	_index_storage_sequence = loaded.get("storage_sequence", 0)
	var rows: Array = []
	var ids: Array = _index["slots"].keys()
	ids.sort()
	for id in ids:
		var row: Dictionary = _index["slots"][id].duplicate(true)
		var selection := slot_profile(id)
		if not selection["ok"]:
			row["profile_error"] = selection["code"]
		elif selection["profile"] == Profiles.INVENTORY_PROFILE:
			row["profile"] = selection["profile"]
		rows.append(row) # Read-only annotations never enter the persisted v1 index.
	return {"ok": true, "slots": rows, "last_slot_id": _index["last_slot_id"]}

func create_slot(label: String, profile: Variant = Profiles.TERRAIN_PROFILE) -> Dictionary:
	if not Profiles._known_profile(profile):
		return _bad("SLOT_PROFILE_UNSUPPORTED")
	# Fail before refreshing or writing any index/directory, including test seams.
	if profile == Profiles.INVENTORY_PROFILE and _uses_windows_generations():
		return _bad("INVENTORY_SAVE_SCHEMA5_WINDOWS_UNSUPPORTED")
	if not ready or not _active_ticket.is_empty():
		return _bad("SLOT_BUSY_OR_NOT_READY")
	var refreshed := list_slots()
	if not refreshed["ok"]:
		return refreshed
	var existing: Dictionary = Generations._directory_entries(_root.path_join("slots"), MAX_SLOTS)
	if not existing["ok"]:
		return _bad("SLOT_DIRECTORY_CAPACITY")
	for item in existing["entries"]:
		if not item["directory"] or not _index["slots"].has(item["name"]) or _is_link(_root.path_join("slots").path_join(item["name"])):
			return _bad("SLOT_UNINDEXED_DIRECTORY")
	if existing["entries"].size() != _index["slots"].size():
		return _bad("SLOT_INDEX_DIRECTORY_MISMATCH")
	var id := Crypto.new().generate_random_bytes(16).hex_encode()
	var changed := add_slot(_index, id, label)
	if not changed["ok"]:
		return changed
	var path: String = _paths(id, id)["slot_directory"]
	if _is_link(path) or DirAccess.make_dir_absolute(path) != OK:
		return _bad("SLOT_CREATE_FAILED")
	if profile == Profiles.INVENTORY_PROFILE:
		var marker := _write_profile_marker(id)
		if not marker.get("ok", false):
			return _preserve_failed_creation(id, marker)
		# Independent readback, also after a controlled test writer returns success.
		var selected := _read_slot_profile(id)
		if not selected["ok"] or selected["profile"] != profile:
			return _preserve_failed_creation(id, _bad("SLOT_PROFILE_MARKER_VERIFY_FAILED"))
	var stored := _persist_index(changed["index"])
	if not stored["ok"]:
		if profile == Profiles.INVENTORY_PROFILE:
			return _preserve_failed_creation(id, stored)
		# Only this call's still-empty new directory may be removed. A published
		# index generation may already name it, so preserve it after commitment.
		if not stored.get("committed", false) and not _is_link(path) and Generations._directory_entries(path, 0).get("ok", false):
			DirAccess.remove_absolute(path)
		return stored
	return {"ok": true, "slot_id": id}

func slot_profile(slot_id: String) -> Dictionary:
	if not ready or not _owns_library() or not valid_id(slot_id) or not _index["slots"].has(slot_id):
		return _bad("SLOT_UNKNOWN")
	var selected := _read_slot_profile(slot_id)
	if not _active_ticket.is_empty() and _active_ticket["slot_id"] == slot_id:
		if _active_profile_faulted or not selected["ok"] or not _same(selected, _active_profile):
			_active_profile_faulted = true
			return _bad("SLOT_SESSION_PROFILE_CHANGED")
	return selected

func _read_slot_profile(slot_id: String) -> Dictionary:
	if not ready or not _owns_library() or not valid_id(slot_id):
		return _bad("SLOT_PROFILE_READ_UNPROVEN")
	var slot: String = _paths(slot_id, slot_id)["slot_directory"]
	if _is_link(_root) or _is_link(_root.path_join("slots")) or _is_link(slot) or not DirAccess.dir_exists_absolute(slot):
		return _bad("SLOT_PATH_INVALID")
	var path := slot.path_join(PROFILE_MARKER)
	if not _path_exists(path):
		return {"ok": true, "profile": Profiles.TERRAIN_PROFILE, "marker_sha256": ""}
	var source := _read_text(path, MAX_PROFILE_BYTES)
	if not source["ok"]:
		return _bad("SLOT_PROFILE_MARKER_INVALID")
	return ProfileMarker.decode_text(source["text"], slot_id)

static func validate_profile_marker(value: Variant, slot_id: Variant) -> Dictionary:
	return ProfileMarker.validate(value, slot_id)

static func _profile_marker_value(slot_id: String) -> Dictionary:
	return ProfileMarker.make_value(slot_id)

func _write_profile_marker(slot_id: String) -> Dictionary:
	# Narrow failure-injection seam; production never overwrites a marker.
	if not ready or not _owns_library() or not valid_id(slot_id) or _index["slots"].has(slot_id):
		return _bad("SLOT_PROFILE_WRITE_UNPROVEN")
	var paths := _paths(slot_id, slot_id)
	var path: String = paths["slot_directory"].path_join(PROFILE_MARKER)
	if _is_link(_root) or _is_link(_root.path_join("slots")) or not _safe_paths(paths) or _path_exists(path):
		return _bad("SLOT_PROFILE_MARKER_EXISTS")
	if not Generations._directory_entries(paths["slot_directory"], 0).get("ok", false):
		return _bad("SLOT_PROFILE_NEW_DIRECTORY_NOT_EMPTY")
	return _write_exact(path, _profile_marker_value(slot_id))

func _preserve_failed_creation(slot_id: String, failure: Dictionary) -> Dictionary:
	# Only this call's newly allocated schema5 directory is eligible. Never move
	# indexed/committed data, or guess after an unreadable index/ownership loss.
	var result: Dictionary = failure.duplicate(true)
	result["ok"] = false
	result["files_preserved"] = true
	result["quarantined"] = false
	if failure.get("committed", false) or not _owns_library():
		return result
	var current := _load_index()
	if not current["ok"]:
		return result
	if current["index"]["slots"].has(slot_id):
		result["committed"] = true
		return result
	var source: String = _paths(slot_id, slot_id)["slot_directory"]
	var quarantine := _root.path_join(CREATION_QUARANTINE)
	if _is_link(source) or not DirAccess.dir_exists_absolute(source) or _is_link(quarantine):
		return result
	if not _path_exists(quarantine) and DirAccess.make_dir_absolute(quarantine) != OK:
		return result
	var entries: Dictionary = Generations._directory_entries(quarantine, MAX_QUARANTINED_CREATIONS)
	if not entries["ok"] or entries["entries"].size() >= MAX_QUARANTINED_CREATIONS:
		return result
	var destination := quarantine.path_join(slot_id)
	if _path_exists(destination) or DirAccess.rename_absolute(source, destination) != OK:
		return result
	result["quarantined"] = true
	result["quarantine_directory"] = destination
	var trace := destination.path_join("creation_failure.json")
	if not _path_exists(trace):
		var recorded := _write_exact(trace, {"slot_id": slot_id, "profile": Profiles.INVENTORY_PROFILE, "code": str(failure.get("code", "SLOT_CREATE_FAILED"))})
		result["failure_trace_written"] = recorded.get("ok", false)
	return result

func begin_session(slot_id: String) -> Dictionary:
	if not ready or not _active_ticket.is_empty() or not valid_id(slot_id):
		return _bad("SLOT_BUSY_OR_NOT_READY")
	var refreshed := list_slots()
	if not refreshed["ok"]:
		return refreshed
	if not _index["slots"].has(slot_id):
		return _bad("SLOT_UNKNOWN")
	var selection := slot_profile(slot_id)
	if not selection["ok"]:
		return selection
	if selection["profile"] == Profiles.INVENTORY_PROFILE and _uses_windows_generations():
		return _bad("INVENTORY_SAVE_SCHEMA5_WINDOWS_UNSUPPORTED")
	var entry: Dictionary = _index["slots"][slot_id]
	if entry["status"] == "incomplete":
		return _bad("SLOT_PREVIOUS_SESSION_INCOMPLETE")
	var session := Crypto.new().generate_random_bytes(16).hex_encode()
	var paths := _paths(slot_id, session)
	if not _safe_paths(paths) or not DirAccess.dir_exists_absolute(paths["slot_directory"]):
		return _bad("SLOT_PATH_INVALID")
	if entry["status"] == "ready":
		var saved := inspect_save(slot_id)
		if not saved["ok"]:
			return saved
		if saved["world_id"] != entry["world_id"] or saved["sequence"] != entry["last_sequence"]:
			return _bad("SLOT_INDEX_SAVE_MISMATCH")
	elif FileAccess.file_exists(paths["identity_path"]) or DirAccess.dir_exists_absolute(paths["world_directory"]):
		return _bad("SLOT_NEW_NOT_EMPTY")
	if not _same(selection, _read_slot_profile(slot_id)):
		return _bad("SLOT_SESSION_PROFILE_CHANGED")
	if DirAccess.make_dir_absolute(paths["session_lock"]) != OK:
		return _bad("SLOT_ALREADY_IN_USE")
	if DirAccess.make_dir_absolute(paths["session_directory"]) != OK:
		DirAccess.remove_absolute(paths["session_lock"])
		return _bad("SLOT_SESSION_CREATE_FAILED")
	_generation += 1
	var ticket := {"owner_id": get_instance_id(), "generation": _generation, "slot_id": slot_id, "session_id": session}
	var marker := _write_exact(paths["session_lock"].path_join("owner.json"), ticket)
	if not marker["ok"]:
		return marker
	var changed := mark_incomplete(_index, slot_id)
	var stored := _persist_index(changed["index"])
	if not stored["ok"]:
		return stored
	if not _same(selection, _read_slot_profile(slot_id)):
		return _bad("SLOT_SESSION_PROFILE_CHANGED")
	_active_ticket = ticket.duplicate(true)
	_active_profile = selection.duplicate(true)
	_active_profile_faulted = false
	var result := {"ok": true, "ticket": ticket.duplicate(true), "slot_id": slot_id, "session_id": session,
		"last_sequence": entry["last_sequence"], "world_id": entry["world_id"], "profile": selection["profile"], "profile_marker_sha256": selection["marker_sha256"]}
	result.merge(paths)
	return result

func finish_session(ticket: Dictionary, world_id: String, sequence: int) -> Dictionary:
	# Coordinator must first observe its actual server child exit0 and complete
	# confirmed-save receipt. This method independently rechecks the on-disk save;
	# it never accepts an externally supplied ok/state dictionary as disk evidence.
	if not _owns_ticket(ticket):
		return _bad("SLOT_TICKET_INVALID")
	var saved := inspect_save(ticket["slot_id"])
	if not saved["ok"]:
		return saved
	if saved["reason"] != "normal_shutdown" or saved["world_id"] != world_id or saved["sequence"] != sequence:
		return _bad("SLOT_CONFIRMED_SAVE_MISMATCH")
	var changed := after_verified_save(_index, ticket["slot_id"], world_id, sequence)
	if not changed["ok"]:
		return changed
	var paths := _paths(ticket["slot_id"], ticket["session_id"])
	if DirAccess.remove_absolute(paths["session_lock"].path_join("owner.json")) != OK or DirAccess.remove_absolute(paths["session_lock"]) != OK:
		return _bad("SLOT_SESSION_LOCK_RELEASE_FAILED")
	var stored := _persist_index(changed["index"])
	_active_ticket.clear()
	_active_profile.clear()
	_active_profile_faulted = false
	if not stored["ok"]:
		return stored # Main/identity stay intact; old index remains incomplete.
	return {"ok": true, "slot": _index["slots"][ticket["slot_id"]].duplicate(true)}

func fail_session(ticket: Dictionary, code: String = "SESSION_FAILED") -> Dictionary:
	if not _owns_ticket(ticket):
		return _bad("SLOT_TICKET_INVALID")
	# begin_session persisted incomplete already. Keep last valid main, identity,
	# controls and lock for explicit inspection; do not turn failure into ready.
	_active_ticket.clear()
	_active_profile.clear()
	_active_profile_faulted = false
	return {"ok": false, "code": code, "files_preserved": true}

func inspect_save(slot_id: String) -> Dictionary:
	if not ready or not _owns_library() or not valid_id(slot_id) or not _index["slots"].has(slot_id):
		return _bad("SLOT_UNKNOWN")
	var selection := slot_profile(slot_id)
	if not selection["ok"]:
		return selection
	if selection["profile"] == Profiles.INVENTORY_PROFILE and _uses_windows_generations():
		return _bad("INVENTORY_SAVE_SCHEMA5_WINDOWS_UNSUPPORTED")
	var paths := _paths(slot_id, slot_id)
	if not _safe_paths(paths) or _path_exists(paths["world_directory"].path_join(".writer_lock")) or _path_exists(paths["world_directory"].path_join(".writer_recovery_lock")):
		return _bad("SLOT_WRITER_STILL_ACTIVE")
	var documents: Array = []
	for name in ["generation_settings", "prefab_settings", "actor_world_bundle011", "network_settings", "save_settings"]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + name + ".json"))
		if not parsed is Dictionary:
			return _bad("SLOT_VALIDATOR_INPUTS_INVALID")
		documents.append(parsed)
	for setting in [[documents[3], "max_players"], [documents[3], "network_protocol_version"], [documents[4], "automatic_backup_count"], [documents[4], "manual_slot_count"]]:
		if not _positive_json_integer(setting[0].get(setting[1])):
			return _bad("SLOT_VALIDATOR_INPUTS_INVALID")
	var inputs := Inputs.new()
	var catalogue := SandboxContentCatalogue.new()
	if not inputs.load_file() or catalogue.load_file() != OK:
		return _bad("SLOT_VALIDATOR_INPUTS_INVALID")
	var world := World.new(documents[0], documents[1], documents[2], "011")
	var actor_session := ActorSession.new(world, inputs.document())
	var terrain_store := TerrainStore.new(documents[0], documents[1], documents[2])
	var terrain_session := TerrainSession.new(actor_session, terrain_store)
	if not world.ready or not actor_session.ready or not terrain_store.ready or not terrain_session.ready:
		return _bad("SLOT_VALIDATOR_INPUTS_INVALID")
	# Both profiles use the closed Registry and its real validators. The fresh
	# authority retains its random identity; cold schema5 admission adopts nothing.
	var authority := SandboxServerAuthority.new(int(documents[3]["max_players"]), int(documents[3]["network_protocol_version"]), catalogue.source_sha256)
	var authority_before := var_to_bytes(authority.persistent_state())
	var registry := Profiles.new(terrain_session, authority, paths["world_directory"], int(documents[4]["automatic_backup_count"]), int(documents[4]["manual_slot_count"]))
	var made: Dictionary = registry.make_store(selection["profile"])
	if not made["ok"]:
		return made
	var store: RefCounted = made["store"]
	var binding: Dictionary = registry.verify_binding(selection["profile"], store)
	if not binding["ok"]:
		return binding
	# No acquire/load_latest/save call: inspection cannot take a writer lock,
	# fall back, migrate, generate, or start the actual player runtime.
	if _uses_windows_generations():
		var generation_config: Dictionary = store.configure_windows_generation_storage()
		if not generation_config["ok"]:
			return generation_config
	var read: Dictionary = store.inspect_main()
	if not read.get("ok", false):
		return {"ok": false, "code": str(read.get("code", "SLOT_SAVE_INVALID"))}
	var text := {"ok": true, "text": read["validated_text"]}
	var payload_read := _readback_payload(text["text"], read)
	if not payload_read["ok"]:
		return payload_read
	var payload: Dictionary = payload_read["value"]
	var marker_text := _read_text(paths["world_directory"].path_join("world_identity.json"), 16384)
	if not marker_text["ok"]:
		return marker_text
	var marker: Variant = JSON.parse_string(marker_text["text"])
	if not State.exact_fields(marker, ["project_id", "save_epoch", "world_id"]) or not marker["project_id"] is String or not marker["save_epoch"] is String or not marker["world_id"] is String or marker["project_id"] != SandboxSaveStore.PROJECT_ID or marker["save_epoch"] != SandboxSaveStore.SAVE_EPOCH or marker["world_id"] != read["state"]["world_id"] or not payload.get("reason") is String:
		return _bad("SLOT_WORLD_MARKER_MISMATCH")
	var entry: Dictionary = _index["slots"][slot_id]
	if not valid_sequence(payload.get("sequence"), false) or (not entry["world_id"].is_empty() and entry["world_id"] != read["state"]["world_id"]):
		return _bad("SLOT_SAVE_IDENTITY_OR_SEQUENCE")
	var identity := verify_identity(paths["identity_path"], read["state"])
	if not identity["ok"]:
		return identity
	if not _same(selection, slot_profile(slot_id)):
		return _bad("SLOT_SESSION_PROFILE_CHANGED")
	binding = registry.verify_binding(selection["profile"], store)
	if not binding["ok"]:
		return binding
	if var_to_bytes(authority.persistent_state()) != authority_before:
		return _bad("SLOT_INSPECTION_ADOPTED_AUTHORITY")
	var stats: Dictionary = world.statistics()
	if stats["generation_calls"] != 0 or stats["instantiation_calls"] != 0 or stats["world_seed_random_calls"] != 0:
		return _bad("SLOT_INSPECTION_GENERATED_WORLD")
	return {"ok": true, "world_id": read["state"]["world_id"], "sequence": payload["sequence"], "reason": payload.get("reason", ""),
		"main_sha256": text["text"].sha256_text(), "state": read["state"], "identity": identity["identity"], "generation_calls": 0, "profile": selection["profile"]}

static func _readback_payload(text: String, read: Dictionary) -> Dictionary:
	if not read.get("state") is Dictionary or not valid_sequence(read.get("sequence"), true) or not read.get("payload_sha256") is String:
		return _bad("SLOT_SAVE_CHANGED_DURING_READ")
	var envelope: Variant = JSON.parse_string(text)
	if not State.exact_fields(envelope, ["format", "envelope_version", "payload_codec", "payload_json", "payload_sha256"]) or not envelope["payload_json"] is String or not envelope["payload_sha256"] is String or envelope["payload_sha256"] != envelope["payload_json"].sha256_text():
		return _bad("SLOT_SAVE_CHANGED_DURING_READ")
	if not envelope["format"] is String or not envelope["payload_codec"] is String or envelope["format"] != SandboxSaveStore.ENVELOPE_FORMAT or typeof(envelope["envelope_version"]) not in [TYPE_INT, TYPE_FLOAT] or envelope["envelope_version"] != 2 or envelope["payload_codec"] != Codec.FORMAT or text != JSON.stringify(envelope, "", true, true):
		return _bad("SLOT_SAVE_CHANGED_DURING_READ")
	var decoded: Dictionary = Codec.decode(JSON.parse_string(envelope["payload_json"]))
	if not decoded.get("ok", false) or not decoded["value"] is Dictionary:
		return _bad("SLOT_SAVE_CHANGED_DURING_READ")
	var payload: Dictionary = decoded["value"]
	if not valid_sequence(payload.get("sequence"), true) or not _same(payload.get("state"), read["state"]) or payload["sequence"] != read["sequence"] or envelope["payload_sha256"] != read["payload_sha256"]:
		return _bad("SLOT_SAVE_CHANGED_DURING_READ")
	return {"ok": true, "value": payload}

static func verify_identity(path: String, state: Dictionary) -> Dictionary:
	var text := _read_text(path, 16384)
	if not text["ok"]:
		return text
	var identity: Variant = JSON.parse_string(text["text"])
	if not State.exact_fields(identity, ["player_profile_id", "resume_secret"]) or not SandboxServerAuthority._valid_id(identity["player_profile_id"], "player_") or not SandboxServerAuthority._valid_id(identity["resume_secret"], "resume_"):
		return _bad("SLOT_PRIVATE_IDENTITY_INVALID")
	var profile_id: String = identity["player_profile_id"]
	if not state.get("profiles") is Dictionary or not state["profiles"].has(profile_id):
		return _bad("SLOT_PRIVATE_IDENTITY_MISMATCH")
	if not state["profiles"][profile_id] is Dictionary:
		return _bad("SLOT_PRIVATE_IDENTITY_MISMATCH")
	var profile: Dictionary = state["profiles"][profile_id]
	if not profile.get("secret_hash") is String or not profile.get("role") is String or profile["secret_hash"] != identity["resume_secret"].sha256_text() or profile.get("role") != "MEMBER":
		return _bad("SLOT_PRIVATE_IDENTITY_MISMATCH")
	return {"ok": true, "identity": identity.duplicate(true)}

func close() -> Dictionary:
	# The GUI coordinator calls only after its server child is gone. Never clear
	# an unknown/stale owner's library lock or any slot/SaveStore lock here.
	if not _active_ticket.is_empty() or not _owns_library():
		return _bad("SLOT_LIBRARY_CLOSE_UNPROVEN")
	var lock := _root.path_join(".library_lock")
	if DirAccess.remove_absolute(lock.path_join("owner.json")) != OK or DirAccess.remove_absolute(lock) != OK:
		return _bad("SLOT_LIBRARY_CLOSE_FAILED")
	_library_token = ""
	ready = false
	return {"ok": true}

func _owns_library() -> bool:
	if _root.is_empty() or _library_token.is_empty():
		return false
	var marker := _read_exact(_root.path_join(".library_lock/owner.json"))
	return marker.get("ok", false) and _same(marker["value"], {"token": _library_token, "owner_id": get_instance_id()})

func _owns_ticket(ticket: Dictionary) -> bool:
	if not ready or not _owns_library() or _active_ticket.is_empty() or not _same(ticket, _active_ticket):
		return false
	var paths := _paths(ticket["slot_id"], ticket["session_id"])
	var marker := _read_exact(paths["session_lock"].path_join("owner.json"))
	return marker.get("ok", false) and _same(marker["value"], ticket)

func _paths(slot_id: String, session_id: String) -> Dictionary:
	return derive_paths(_root, slot_id, session_id)

func _safe_paths(paths: Dictionary) -> bool:
	for path in paths.values():
		if _is_link(path):
			return false
	return true

func _load_index() -> Dictionary:
	var read: Dictionary
	var missing: bool = false
	var storage_sequence: int = 0
	if _index_generations != null:
		var selected: Dictionary = _index_generations.read_latest("index", _validate_index_text)
		if selected.get("ok", false):
			read = Codec.decode(JSON.parse_string(selected["text"]))
			storage_sequence = selected["sequence"]
		elif selected.get("code") == "MISSING":
			missing = true
		else:
			return selected
	else:
		var path := _root.path_join("index.json")
		missing = not _path_exists(path)
		if not missing:
			read = _read_exact(path)
	if missing:
		var empty: Dictionary = Generations._directory_entries(_root.path_join("slots"), 0)
		if not empty["ok"]:
			return _bad("SLOT_INDEX_MISSING_WITH_EXISTING_FILES")
		return {"ok": true, "index": empty_index(), "storage_sequence": 0, "missing": true}
	if not read.get("ok", false):
		return read
	var checked := validate_index(read["value"])
	return {"ok": true, "index": read["value"], "storage_sequence": storage_sequence} if checked["ok"] else checked

static func _validate_index_text(text: String) -> Dictionary:
	var decoded: Dictionary = Codec.decode(JSON.parse_string(text))
	return validate_index(decoded["value"]) if decoded.get("ok", false) else decoded

func _write_index_value(value: Dictionary) -> Dictionary:
	if _index_generations == null:
		return _write_exact(_root.path_join("index.json"), value)
	if _index_storage_sequence >= MAX_SEQUENCE:
		return _bad("SLOT_INDEX_SEQUENCE_EXHAUSTED")
	var encoded := Codec.encode(value)
	if not encoded["ok"]:
		return encoded
	var text := JSON.stringify(encoded["value"], "", true, true)
	var stored: Dictionary = _index_generations.write_generation("index", text, _index_storage_sequence + 1, _validate_index_text)
	if stored.get("committed", false):
		_index_storage_sequence = stored["sequence"]
	return stored

func _persist_index(value: Dictionary) -> Dictionary:
	if not _owns_library():
		return _bad("SLOT_LIBRARY_LOCK_LOST")
	var checked := validate_index(value)
	if not checked["ok"]:
		return checked
	var index_lock := _root.path_join(".index_lock")
	if _is_link(index_lock) or DirAccess.make_dir_absolute(index_lock) != OK:
		return _bad("SLOT_INDEX_BUSY")
	var current := _load_index()
	var stored := _bad("SLOT_INDEX_CHANGED")
	if current["ok"] and _same(current["index"], _index):
		if not _active_ticket.is_empty() and not slot_profile(_active_ticket["slot_id"])["ok"]:
			DirAccess.remove_absolute(index_lock)
			return _bad("SLOT_SESSION_PROFILE_CHANGED")
		_index_storage_sequence = current.get("storage_sequence", 0)
		stored = _write_index_value(value)
		if stored["ok"]:
			_index = value.duplicate(true)
	DirAccess.remove_absolute(index_lock)
	return stored

static func empty_index() -> Dictionary:
	return {"schema_version": 1, "slots": {}, "last_slot_id": ""}

static func validate_index(value: Variant) -> Dictionary:
	if not State.exact_fields(value, INDEX_FIELDS) or typeof(value["schema_version"]) != TYPE_INT or value["schema_version"] != 1 or not value["slots"] is Dictionary or value["slots"].size() > MAX_SLOTS or not value["last_slot_id"] is String:
		return _bad("SLOT_INDEX_INVALID")
	for key in value["slots"]:
		var row: Variant = value["slots"][key]
		if not valid_id(key) or not State.exact_fields(row, SLOT_FIELDS) or not row["slot_id"] is String or row["slot_id"] != key or not valid_label(row["label"]) or not row["status"] is String or row["status"] not in ["new", "ready", "incomplete"] or not valid_sequence(row["last_sequence"], true) or not row["world_id"] is String:
			return _bad("SLOT_ROW_INVALID")
		if row["world_id"].is_empty():
			if row["last_sequence"] != 0 or row["status"] == "ready":
				return _bad("SLOT_ROW_IDENTITY_INVALID")
		elif not SandboxServerAuthority._valid_id(row["world_id"], "world_") or row["last_sequence"] < 1:
			return _bad("SLOT_ROW_IDENTITY_INVALID")
	if not value["last_slot_id"].is_empty() and not value["slots"].has(value["last_slot_id"]):
		return _bad("SLOT_LAST_ID_INVALID")
	return {"ok": true}

static func add_slot(index: Dictionary, id: String, label: String) -> Dictionary:
	if not validate_index(index)["ok"] or not valid_id(id) or not valid_label(label) or index["slots"].has(id) or index["slots"].size() >= MAX_SLOTS:
		return _bad("SLOT_CREATE_INVALID")
	var result: Dictionary = index.duplicate(true)
	result["slots"][id] = {"slot_id": id, "label": label, "status": "new", "last_sequence": 0, "world_id": ""}
	return {"ok": true, "index": result}

static func mark_incomplete(index: Dictionary, id: String) -> Dictionary:
	if not validate_index(index)["ok"] or not index["slots"].has(id):
		return _bad("SLOT_UNKNOWN")
	var result: Dictionary = index.duplicate(true)
	result["slots"][id]["status"] = "incomplete"
	return {"ok": true, "index": result}

static func after_verified_save(index: Dictionary, id: String, world_id: String, sequence: int) -> Dictionary:
	if not validate_index(index)["ok"] or not index["slots"].has(id) or not SandboxServerAuthority._valid_id(world_id, "world_") or not valid_sequence(sequence, false):
		return _bad("SLOT_SAVE_METADATA_INVALID")
	var row: Dictionary = index["slots"][id]
	if sequence <= row["last_sequence"] or (not row["world_id"].is_empty() and row["world_id"] != world_id):
		return _bad("SLOT_SAVE_METADATA_REGRESSION")
	var result: Dictionary = index.duplicate(true)
	result["slots"][id].merge({"status": "ready", "last_sequence": sequence, "world_id": world_id}, true)
	result["last_slot_id"] = id
	return {"ok": true, "index": result}

static func derive_paths(root: String, slot_id: String, session_id: String) -> Dictionary:
	if not root.is_absolute_path() or root != root.simplify_path() or not valid_id(slot_id) or not valid_id(session_id):
		return {}
	var slot := root.path_join("slots").path_join(slot_id)
	return {"slot_directory": slot, "world_directory": slot.path_join("world"), "main_path": slot.path_join("world/main.json"),
		"identity_path": slot.path_join("identity.json"), "session_lock": slot.path_join(".session_lock"),
		"session_directory": root.path_join("sessions").path_join(session_id)}

static func valid_id(value: Variant) -> bool:
	if not value is String or value.length() != 32:
		return false
	for letter in value:
		if letter not in "0123456789abcdef":
			return false
	return true

static func valid_label(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 40 or value.strip_edges() != value:
		return false
	for position in range(value.length()):
		var code: int = value.unicode_at(position)
		if code < 32 or code == 127:
			return false
	return true

static func valid_sequence(value: Variant, allow_zero: bool) -> bool:
	return typeof(value) == TYPE_INT and value >= (0 if allow_zero else 1) and value <= MAX_SEQUENCE

static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and var_to_bytes(a) == var_to_bytes(b)

static func _is_link(path: String) -> bool:
	var parent := DirAccess.open(path.get_base_dir())
	return parent != null and parent.is_link(path.get_file())

static func _path_exists(path: String) -> bool:
	return _is_link(path) or FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)

static func _positive_json_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= 1 and value <= MAX_SEQUENCE and float(value) == floorf(float(value))

static func _read_text(path: String, maximum: int) -> Dictionary:
	if _is_link(path):
		return _bad("SLOT_LINK_REFUSED")
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return _bad("SLOT_FILE_UNREADABLE")
	var size: int = handle.get_length()
	if size < 1 or size > maximum:
		handle.close()
		return _bad("SLOT_FILE_SIZE")
	var text: String = handle.get_as_text()
	var error: int = handle.get_error()
	handle.close()
	if error not in [OK, ERR_FILE_EOF] or text.to_utf8_buffer().size() != size:
		return _bad("SLOT_FILE_READ_FAILED")
	return {"ok": true, "text": text}

static func _read_exact(path: String) -> Dictionary:
	var text := _read_text(path, MAX_INDEX_BYTES)
	if not text["ok"]:
		return text
	var parser := JSON.new()
	if parser.parse(text["text"]) != OK:
		return _bad("SLOT_INDEX_JSON_INVALID")
	return Codec.decode(parser.data)

static func _write_exact(path: String, value: Dictionary) -> Dictionary:
	if _is_link(path):
		return _bad("SLOT_LINK_REFUSED")
	var encoded := Codec.encode(value)
	if not encoded["ok"]:
		return _bad("SLOT_INDEX_ENCODE_FAILED")
	var text := JSON.stringify(encoded["value"], "", true, true)
	if text.to_utf8_buffer().size() > MAX_INDEX_BYTES:
		return _bad("SLOT_INDEX_SIZE")
	var temporary := path + ".tmp_" + Crypto.new().generate_random_bytes(16).hex_encode()
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _bad("SLOT_INDEX_WRITE_FAILED")
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	var verified := _read_exact(temporary)
	if error != OK or not verified.get("ok", false) or not _same(verified["value"], value):
		return _bad("SLOT_INDEX_VERIFY_FAILED")
	if DirAccess.rename_absolute(temporary, path) != OK:
		return _bad("SLOT_INDEX_PROMOTE_FAILED")
	return {"ok": true}

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}
