extends RefCounted
## Schema-4 persistence-only contract. No generation, activation, I/O or migration.
const LegacySession = preload("res://scripts/actor/actor_session_state.gd")
const TerrainStore = preload("res://scripts/terrain/combined_terrain_store.gd")
const State = preload("res://scripts/actor/actor_state.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const FIELDS := ["world_id", "world_seconds", "revision", "next_auto_due_world_seconds", "profiles", "world_component", "actor_component", "terrain_component"]
const LEGACY_TEXT_FIELDS := ["project", "artifact_kind", "world_id", "actor_id", "player_profile_id", "player_instance_id", "display_name", "role", "secret_hash", "reference_frame", "body_instance_id", "map_kind", "plane", "parent_instance_id", "layer_id"]
var ready: bool = false
var last_error: String = ""
var _legacy: RefCounted
var _terrain_store: RefCounted

func _init(legacy: RefCounted, terrain_store: RefCounted) -> void:
	if legacy == null or legacy.get_script() != LegacySession or terrain_store == null or terrain_store.get_script() != TerrainStore or not legacy.ready or not terrain_store.ready:
		last_error = "ACTOR_TERRAIN_SESSION_INPUTS_INVALID"
		return
	_legacy = legacy
	_terrain_store = terrain_store
	ready = true

func combine(base: Dictionary, terrain: Variant) -> Dictionary:
	# Never silently discard a caller's unknown field or overwrite supplied terrain.
	if not State.exact_fields(base, LegacySession.FIELDS):
		return _bad("ACTOR_TERRAIN_BASE_CONTRACT_INCOMPATIBLE")
	var combined: Dictionary = base.duplicate(true)
	combined["terrain_component"] = terrain.duplicate(true) if terrain is Dictionary else terrain
	var checked := validate_combined_state(combined)
	return {"ok": true, "state": combined} if checked["ok"] else checked

func validate_combined_state(value: Variant) -> Dictionary:
	if not ready or _legacy == null or _legacy.get_script() != LegacySession or not _legacy.ready or _terrain_store == null or _terrain_store.get_script() != TerrainStore or not _terrain_store.ready:
		return _bad("ACTOR_TERRAIN_SESSION_NOT_READY")
	if not value is Dictionary:
		return _bad("ACTOR_TERRAIN_COMBINED_STATE_INVALID")
	if not value.has("terrain_component") or value["terrain_component"] == null:
		return _bad("ACTOR_TERRAIN_COMPONENT_REQUIRED_NO_MIGRATION")
	if not State.exact_fields(value, FIELDS):
		return _bad("ACTOR_TERRAIN_CONTRACT_INCOMPATIBLE")
	if not SandboxServerAuthority._valid_id(value.get("world_id"), "world_"):
		return _bad("ACTOR_TERRAIN_WORLD_ID_INVALID")
	var base := legacy_state(value)
	# Guard older scalar/container comparisons before entering unchanged legacy
	# validators. The codec bounds recursion/types; no current component is applied.
	var bounded: Dictionary = Codec.encode(base)
	if not bounded.get("ok", false) or not _legacy_text_types(base):
		return _bad("ACTOR_TERRAIN_BASE_FIELD_TYPE_INVALID")
	var actor: Variant = base["actor_component"]
	if not actor is Dictionary or not actor.get("project") is String or not actor.get("artifact_kind") is String:
		return _bad("ACTOR_TERRAIN_ACTOR_CONTRACT_INVALID")
	var identity: Variant = actor.get("source_identity")
	if not State.exact_fields(identity, ["projection_sha256", "sources"]) or not identity["projection_sha256"] is String or not identity["sources"] is Dictionary:
		return _bad("ACTOR_SNAPSHOT_INCOMPATIBLE_SOURCE")
	for source in identity["sources"].values():
		if not source is String:
			return _bad("ACTOR_SNAPSHOT_INCOMPATIBLE_SOURCE")
	if not _legacy_identity_slots(base):
		return _bad("ACTOR_TERRAIN_BASE_IDENTITY_TYPE_INVALID")
	# Read-only Store checks every saved terrain row and the complete world binding.
	# It neither constructs Stage nor rebuilds an expected generated artifact.
	var checked: Dictionary = _terrain_store.restore(value["terrain_component"], value["world_component"], value["world_id"])
	if not checked.get("ok", false):
		return _closed(checked)
	checked = _legacy.validate_combined_state(base)
	return {"ok": true} if checked.get("ok", false) else _closed(checked)

static func legacy_state(value: Dictionary) -> Dictionary:
	# Projection alone confers no validity. The owner may pass it to legacy restore
	# only after full schema-4 validation; authority_state preserves unknown fields.
	var base: Dictionary = value.duplicate(true)
	base.erase("terrain_component")
	return base

static func _legacy_identity_slots(base: Dictionary) -> bool:
	if not base["profiles"] is Dictionary or not base["actor_component"].get("actors") is Dictionary:
		return false
	for profile in base["profiles"].values():
		if not profile is Dictionary:
			return false
		for field in ["player_profile_id", "player_instance_id", "display_name", "role", "secret_hash"]:
			if not profile.get(field) is String:
				return false
	for actor in base["actor_component"]["actors"].values():
		if not actor is Dictionary or not actor.get("actor_id") is String:
			return false
	return true

static func _legacy_text_types(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if key in LEGACY_TEXT_FIELDS and typeof(value[key]) != TYPE_STRING:
				return false
			if not _legacy_text_types(value[key]):
				return false
	elif value is Array:
		for item in value:
			if not _legacy_text_types(item):
				return false
	return true

static func _closed(result: Dictionary) -> Dictionary:
	var closed: Dictionary = result.duplicate(true)
	closed["ok"] = false
	closed["recoverable_corruption"] = false
	if not closed.has("code"):
		closed["code"] = "ACTOR_TERRAIN_BASE_STATE_INVALID"
	return closed

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "recoverable_corruption": false}
