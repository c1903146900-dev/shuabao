extends RefCounted
## Explicit candidate, not installed in the current schema4 owner or factories.
## Validation only: no generation, grants, migration, RPC or transaction publish.
const TerrainSession = preload("res://scripts/actor/actor_terrain_session_state.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Authority = preload("res://scripts/network/server_authority.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const BoundedStore = preload("res://scripts/inventory/inventory_world_save_store012.gd")
const CONTRACT := "sandbox012-world-inventory-v1"
const SCHEMA := 5
const MAX_BYTES := 4194304
const FIELDS := ["world_id", "world_seconds", "revision", "next_auto_due_world_seconds", "profiles", "world_component", "actor_component", "terrain_component", "inventory_contract", "inventory_component"]
var ready: bool = false
var _terrain: RefCounted
var _inventory: RefCounted
var _world_id: String = ""
var _content_revision: String = ""
var _protocol: int = 0
var _budget_store: RefCounted

func _init(terrain: RefCounted, inventory: RefCounted, authority: RefCounted, validation_world_id: String = "") -> void:
	if terrain == null or terrain.get_script() != TerrainSession or not terrain.ready or inventory == null or inventory.get_script() != Core or not inventory.ready or authority == null or authority.get_script() != Authority:
		return
	# Optional cold-validation scope only: the real authority keeps its freshly
	# allocated identity. Metadata still comes from that exact authority service.
	var binding_world_id: String = authority.world_id if validation_world_id.is_empty() else validation_world_id
	if not Core._world_id_valid(binding_world_id) or inventory._world_id != binding_world_id or authority.catalogue_hash.length() != 64 or authority.protocol_version < 1:
		return
	_terrain = terrain
	_inventory = inventory
	_world_id = binding_world_id
	# Taken from the actual approved authority service, never a fabricated hash.
	_content_revision = authority.catalogue_hash
	_protocol = authority.protocol_version
	# _encode does not invoke a validator. This object does no I/O and carries
	# no callback: combined admission cannot recurse through itself.
	_budget_store = SaveStore.new("", 1, 1, _content_revision, _protocol, Callable(), SCHEMA, MAX_BYTES, true)
	ready = true

func make_store(path: String, automatic_slots: int, manual_slots: int) -> RefCounted:
	if not ready or _inventory._tree_rules or automatic_slots < 1 or automatic_slots > 64 or manual_slots < 1 or manual_slots > 63:
		return null
	return BoundedStore.new(path, automatic_slots, manual_slots, _content_revision, _protocol, validate_combined_state, SCHEMA, MAX_BYTES, true)

func combine(base: Dictionary, inventory: Variant) -> Dictionary:
	if not Core._fields(base, TerrainSession.FIELDS):
		return _bad("INVENTORY_WORLD_BASE_CONTRACT_INVALID")
	var candidate: Dictionary = base.duplicate(true)
	candidate["inventory_contract"] = CONTRACT
	candidate["inventory_component"] = inventory.duplicate(true) if inventory is Dictionary else inventory
	var checked := validate_combined_state(candidate)
	return {"ok": true, "state": candidate} if checked["ok"] else checked

func validate_combined_state(value: Variant) -> Dictionary:
	if not ready or _terrain.get_script() != TerrainSession or not _terrain.ready or _inventory.get_script() != Core or not _inventory.ready or _inventory._world_id != _world_id:
		return _bad("INVENTORY_WORLD_NOT_READY")
	if not Core._fields(value, FIELDS) or not value["inventory_contract"] is String or value["inventory_contract"] != CONTRACT:
		return _bad("INVENTORY_WORLD_CONTRACT_NO_MIGRATION")
	if not value["world_id"] is String or value["world_id"] != _world_id:
		return _bad("INVENTORY_WORLD_ID_MISMATCH")
	var checked: Dictionary = _inventory.validate_snapshot(value["inventory_component"])
	if not checked["ok"]:
		return _closed(checked)
	if value["inventory_component"]["schema_version"] in [2, 3] and value["inventory_component"]["ground_clock"] != value["world_seconds"]:
		return _bad("INVENTORY_GROUND_WORLD_CLOCK_MISMATCH")
	if not value["profiles"] is Dictionary:
		return _bad("INVENTORY_WORLD_PROFILE_MISMATCH")
	var players: Dictionary = value["inventory_component"]["players"]
	if players.size() != value["profiles"].size():
		return _bad("INVENTORY_WORLD_PROFILE_MISMATCH")
	for profile in value["profiles"]:
		if not players.has(profile):
			return _bad("INVENTORY_WORLD_PROFILE_MISMATCH")
	checked = _terrain.validate_combined_state(terrain_state(value))
	if not checked["ok"]:
		return _closed(checked)
	# Use the ACTUAL final Store envelope, including exact-codec and JSON escaping.
	# Fixed-size integer codec and worst bounded reason/kind cover main/manual
	# writes, all admitted slots and sequences. Store checks actual bytes again.
	var text: String = _budget_store._encode(value, Core.MAX_SEQUENCE, "manual", "W".repeat(BoundedStore.MAX_REASON), 63)
	if text.is_empty() or text.to_utf8_buffer().size() > MAX_BYTES:
		return _bad("INVENTORY_WORLD_FINAL_ENVELOPE_TOO_LARGE")
	return {"ok": true}

static func terrain_state(value: Dictionary) -> Dictionary:
	# Projection grants no validity or authority to apply. Validate full state first.
	var base: Dictionary = value.duplicate(true)
	base.erase("inventory_contract")
	base.erase("inventory_component")
	return base

static func _closed(result: Dictionary) -> Dictionary:
	var closed: Dictionary = result.duplicate(true)
	closed["ok"] = false
	closed["recoverable_corruption"] = false
	return closed

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "recoverable_corruption": false}
