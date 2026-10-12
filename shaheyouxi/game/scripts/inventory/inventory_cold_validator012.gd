extends RefCounted
## Read-only schema5 admission before the new authority adopts a saved world ID.
## No Authority clone, generation, restore, grant, actor activation or save-file I/O.
const TerrainSession = preload("res://scripts/actor/actor_terrain_session_state.gd")
const Authority = preload("res://scripts/network/server_authority.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Combined = preload("res://scripts/inventory/inventory_world_session012.gd")
var ready: bool = false
var _terrain: RefCounted
var _authority: RefCounted
var _legacy: RefCounted
var _terrain_store: RefCounted
var _content_revision: String = ""
var _protocol: int = 0

func _init(terrain: Variant, authority: Variant) -> void:
	if not terrain is RefCounted or terrain.get_script() != TerrainSession or not terrain.ready or not authority is RefCounted or authority.get_script() != Authority:
		return
	if terrain._legacy == null or terrain._legacy.get_script() != TerrainSession.LegacySession or not terrain._legacy.ready or terrain._terrain_store == null or terrain._terrain_store.get_script() != TerrainSession.TerrainStore or not terrain._terrain_store.ready:
		return
	if not valid_configuration(authority.catalogue_hash, authority.protocol_version):
		return
	_terrain = terrain
	_authority = authority
	_legacy = terrain._legacy
	_terrain_store = terrain._terrain_store
	_content_revision = authority.catalogue_hash
	_protocol = authority.protocol_version
	ready = true

func binding_matches(terrain: Variant, authority: Variant) -> bool:
	# The authority's random/current world ID is deliberately NOT this binding.
	if not terrain is RefCounted or not authority is RefCounted:
		return false
	return ready and terrain == _terrain and authority == _authority and _terrain != null and _terrain.get_script() == TerrainSession and _terrain.ready and _terrain._legacy == _legacy and _terrain._terrain_store == _terrain_store and _legacy != null and _legacy.get_script() == TerrainSession.LegacySession and _legacy.ready and _terrain_store != null and _terrain_store.get_script() == TerrainSession.TerrainStore and _terrain_store.ready and _authority != null and _authority.get_script() == Authority and _authority.catalogue_hash == _content_revision and _authority.protocol_version == _protocol and valid_configuration(_content_revision, _protocol)

func validate_combined_state(value: Variant) -> Dictionary:
	if not binding_matches(_terrain, _authority):
		return _bad("INVENTORY_COLD_BINDING_CHANGED")
	if not Core._fields(value, Combined.FIELDS) or not value["inventory_contract"] is String or value["inventory_contract"] != Combined.CONTRACT:
		return _bad("INVENTORY_WORLD_CONTRACT_NO_MIGRATION")
	if not value["world_id"] is String or not Core._world_id_valid(value["world_id"]):
		return _bad("INVENTORY_COLD_WORLD_ID_INVALID")
	# Reuse the actual full validators; never maintain a second inventory schema.
	var inventory_validator := Core.new(value["world_id"])
	var combined_validator := Combined.new(_terrain, inventory_validator, _authority, value["world_id"])
	if not inventory_validator.ready or not combined_validator.ready:
		return _bad("INVENTORY_COLD_NOT_READY")
	return combined_validator.validate_combined_state(value)

static func valid_configuration(content_revision: Variant, protocol: Variant) -> bool:
	if not content_revision is String or content_revision.length() != 64 or typeof(protocol) != TYPE_INT or protocol < 1 or protocol > Core.MAX_SEQUENCE:
		return false
	for character in content_revision:
		if character not in "0123456789abcdef":
			return false
	return true

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "recoverable_corruption": false}
