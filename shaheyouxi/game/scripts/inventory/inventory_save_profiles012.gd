extends RefCounted
## Closed profile registry, not an extension/plugin system. Construction is inert.
## Existing entry/owner/Frame/Slots still select schema4 until a separate gate.
const SaveStore = preload("res://scripts/save/save_store.gd")
const BoundedStore = preload("res://scripts/inventory/inventory_world_save_store012.gd")
const TerrainSession = preload("res://scripts/actor/actor_terrain_session_state.gd")
const Authority = preload("res://scripts/network/server_authority.gd")
const ColdValidator = preload("res://scripts/inventory/inventory_cold_validator012.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const TreeColdValidator = preload("res://scripts/harvest/tree_cold_validator012.gd")
const TREE_PROFILE := 6
const TERRAIN_PROFILE := 4
const INVENTORY_PROFILE := 5
const MAX_BYTES := 4194304
var ready: bool = false
var _terrain: RefCounted
var _authority: RefCounted
var _cold: RefCounted
var _tree_cold: RefCounted
var _directory: String = ""
var _automatic_count: int = 0
var _manual_count: int = 0
var _content_revision: String = ""
var _protocol: int = 0

func _init(terrain: Variant, authority: Variant, path: Variant, automatic_slots: Variant, manual_slots: Variant) -> void:
	if not path is String or path.is_empty() or typeof(automatic_slots) != TYPE_INT or automatic_slots < 1 or automatic_slots > 64 or typeof(manual_slots) != TYPE_INT or manual_slots < 1 or manual_slots > 63:
		return
	var validator := ColdValidator.new(terrain, authority)
	if not validator.ready:
		return
	_terrain = terrain
	_authority = authority
	_cold = validator
	_tree_cold = TreeColdValidator.new(terrain,authority)
	_directory = path
	_automatic_count = automatic_slots
	_manual_count = manual_slots
	_content_revision = authority.catalogue_hash
	_protocol = authority.protocol_version
	ready = true

func descriptor(profile: Variant) -> Dictionary:
	if not _binding_valid():
		return _bad("INVENTORY_SAVE_REGISTRY_NOT_READY")
	if not _known_profile(profile):
		return _bad("INVENTORY_SAVE_PROFILE_UNSUPPORTED")
	if profile == TREE_PROFILE and (_tree_cold == null or _tree_cold.get_script()!=TreeColdValidator or not _tree_cold.binding_matches(_terrain,_authority)):
		return _bad("TREE_SAVE_REGISTRY_NOT_READY")
	return {"ok": true, "profile": profile, "schema_version": profile,
		"store_script": SaveStore if profile == TERRAIN_PROFILE else BoundedStore,
		"validator_script": TerrainSession if profile == TERRAIN_PROFILE else (TreeColdValidator if profile == TREE_PROFILE else ColdValidator),
		"validator_method": "validate_combined_state", "maximum_bytes": MAX_BYTES,
		"exact_scalars": true, "directory": _directory,
		"automatic_count": _automatic_count, "manual_count": _manual_count,
		"content_revision": _content_revision, "network_protocol_version": _protocol,
		"platform_supported": platform_supported(profile, OS.get_name())}

func make_store(profile: Variant) -> Dictionary:
	var description := descriptor(profile)
	if not description["ok"]:
		return description
	if not description["platform_supported"]:
		return _bad("INVENTORY_SAVE_SCHEMA5_WINDOWS_UNSUPPORTED")
	var validator: RefCounted = validator_for(profile)
	var store: RefCounted
	if profile == TERRAIN_PROFILE:
		store = SaveStore.new(_directory, _automatic_count, _manual_count, _content_revision, _protocol, Callable(validator, "validate_combined_state"), TERRAIN_PROFILE, MAX_BYTES, true)
	else:
		store = BoundedStore.new(_directory, _automatic_count, _manual_count, _content_revision, _protocol, Callable(validator, "validate_combined_state"), profile, MAX_BYTES, true)
	return {"ok": true, "store": store, "validator": validator, "descriptor": description}

func verify_binding(profile: Variant, store: Variant, expected_world_id: Variant = "") -> Dictionary:
	# Configuration admission only. The later owner/Frame must also check its
	# own original Store instance, live services, lock/readiness and receipt.
	var description := descriptor(profile)
	if not description["ok"]:
		return description
	if not description["platform_supported"]:
		return _bad("INVENTORY_SAVE_SCHEMA5_WINDOWS_UNSUPPORTED")
	if not store is RefCounted or store.get_script() != description["store_script"]:
		return _bad("INVENTORY_SAVE_STORE_TYPE_INVALID")
	var validator: RefCounted = validator_for(profile)
	if store._state_validator != Callable(validator, "validate_combined_state") or validator.get_script() != description["validator_script"]:
		return _bad("INVENTORY_SAVE_VALIDATOR_BINDING_INVALID")
	if store._schema_version != profile or store._maximum_bytes != MAX_BYTES or not store._exact_scalars or store._content_revision != _content_revision or store._network_protocol_version != _protocol or store.directory != _directory or store.automatic_count != _automatic_count or store.manual_count != _manual_count:
		return _bad("INVENTORY_SAVE_CONFIGURATION_CHANGED")
	if profile in [INVENTORY_PROFILE,TREE_PROFILE] and (store._windows_generations != null or store._generation_bound_adapter != null or not store._generation_binding.is_empty() or not store._generation_init_error.is_empty()):
		return _bad("INVENTORY_SAVE_SCHEMA5_STORAGE_UNSUPPORTED")
	if not expected_world_id is String or (not expected_world_id.is_empty() and not Core._world_id_valid(expected_world_id)) or (not store._world_id.is_empty() and not Core._world_id_valid(store._world_id)):
		return _bad("INVENTORY_SAVE_WORLD_BINDING_INVALID")
	if not expected_world_id.is_empty() and store._world_id != expected_world_id:
		return _bad("INVENTORY_SAVE_WORLD_BINDING_INVALID")
	return {"ok": true}

func _binding_valid() -> bool:
	return ready and _cold != null and _cold.get_script() == ColdValidator and _cold.binding_matches(_terrain, _authority) and _cold._content_revision == _content_revision and _cold._protocol == _protocol

static func _known_profile(profile: Variant) -> bool:
	return typeof(profile) == TYPE_INT and profile in [TERRAIN_PROFILE, INVENTORY_PROFILE,TREE_PROFILE]

static func platform_supported(profile: Variant, platform: String) -> bool:
	# Informational helper cannot override make_store's actual OS check.
	return _known_profile(profile) and not (profile in [INVENTORY_PROFILE,TREE_PROFILE] and platform == "Windows")

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "recoverable_corruption": false}

func validator_for(profile: int) -> RefCounted:
	if profile == TERRAIN_PROFILE: return _terrain
	if profile == INVENTORY_PROFILE: return _cold
	if profile == TREE_PROFILE: return _tree_cold
	return null
