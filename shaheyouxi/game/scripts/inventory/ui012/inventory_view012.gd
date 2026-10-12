extends RefCounted
## Read-only client cache. A transport must authenticate the sender and bind the
## expected profile/world independently. This is validation, not authentication.
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const CONTRACT := "sandbox012-inventory-view-v1"
const FIELDS := ["schema_version", "contract", "world_id", "profile_id", "view_sequence", "revision", "inventory", "chests"]
const CAPACITIES := {"bag": 40, "hotbar": 10, "chest": 30}
var _world: String
var _profile: String
var _cache: Dictionary = {}
var _rules: Dictionary = {}
var _chest_fingerprints: Dictionary = {}

func _init(world_id: String, profile_id: String) -> void:
	_world = world_id
	_profile = profile_id
	var source: String = FileAccess.get_file_as_string(Core.RULES_PATH)
	if source.sha256_text() == Core.RULES_SHA256:
		_rules = JSON.parse_string(source)

static func server_view(core: RefCounted, authenticated_profile: String, view_sequence: int) -> Dictionary:
	# Server-only adapter. Never stamp untrusted client content with a profile.
	var value: Dictionary = core.view(authenticated_profile)
	if value.is_empty(): return {}
	value.merge({"schema_version": 1, "contract": CONTRACT, "profile_id": authenticated_profile, "view_sequence": view_sequence})
	return value

func snapshot() -> Dictionary:
	return _cache.duplicate(true)

func accept(value: Variant) -> Dictionary:
	var checked: Dictionary = validate(value)
	if not checked["ok"]: return checked
	if not _cache.is_empty():
		if value["view_sequence"] <= _cache["view_sequence"] or value["revision"] < _cache["revision"]: return _bad("VIEW_STALE")
		if value["inventory"]["last_sequence"] < _cache["inventory"]["last_sequence"]: return _bad("VIEW_SEQUENCE_REGRESSED")
		if value["revision"] == _cache["revision"]:
			if _exact(value["inventory"]) != _exact(_cache["inventory"]): return _bad("VIEW_SAME_REVISION_MUTATION")
			for chest in value["chests"]:
				if _chest_fingerprints.has(chest) and _exact(value["chests"][chest]).sha256_text() != _chest_fingerprints[chest]: return _bad("VIEW_SAME_REVISION_MUTATION")
	var fingerprints: Dictionary = {} if _cache.is_empty() or value["revision"] > _cache["revision"] else _chest_fingerprints.duplicate()
	for chest in value["chests"]: fingerprints[chest] = _exact(value["chests"][chest]).sha256_text()
	if fingerprints.size() > Core.MAX_ENTITIES: return _bad("VIEW_CHEST_HISTORY_BUDGET")
	_chest_fingerprints = fingerprints
	_cache = value.duplicate(true)
	return {"ok": true}

func validate(value: Variant) -> Dictionary:
	if _rules.is_empty() or not Core._world_id_valid(_world) or not Core._id(_profile): return _bad("VIEW_BINDING_INVALID")
	if not Core._fields(value, FIELDS): return _bad("VIEW_FIELDS_INVALID")
	var bounded: Dictionary = Codec.encode(value)
	if not bounded["ok"] or JSON.stringify(bounded.get("value")).to_utf8_buffer().size() > Core.MAX_BYTES: return _bad("VIEW_BUDGET_INVALID")
	if typeof(value["schema_version"]) != TYPE_INT or value["schema_version"] != 1 or not value["contract"] is String or value["contract"] != CONTRACT: return _bad("VIEW_CONTRACT_INVALID")
	if not value["world_id"] is String or value["world_id"] != _world or not value["profile_id"] is String or value["profile_id"] != _profile: return _bad("VIEW_BINDING_MISMATCH")
	for key in ["revision", "view_sequence"]:
		if not _counter(value[key]): return _bad("VIEW_COUNTER_INVALID")
	var player: Variant = value["inventory"]
	if not Core._fields(player, ["bag", "hotbar", "carry", "carry_origin", "last_sequence"]) or not _counter(player["last_sequence"]): return _bad("VIEW_PLAYER_INVALID")
	if not value["chests"] is Dictionary or value["chests"].size() > Core.MAX_ENTITIES: return _bad("VIEW_CHESTS_INVALID")
	var ids: Dictionary = {}
	var protected: Dictionary = {}
	for kind in ["bag", "hotbar"]:
		if not _slots(player[kind], CAPACITIES[kind], ids, protected): return _bad("VIEW_SLOTS_INVALID")
	if not _stack(player["carry"], ids, protected): return _bad("VIEW_CARRY_INVALID")
	if player["carry"] == null:
		if player["carry_origin"] != null: return _bad("VIEW_ORIGIN_INVALID")
	elif not address_valid(player["carry_origin"], false, value): return _bad("VIEW_ORIGIN_INVALID")
	for chest in value["chests"]:
		var record: Variant = value["chests"][chest]
		if not Core._id(chest) or not Core._fields(record, ["content_id", "slots"]) or not record["content_id"] is String or record["content_id"] != "chuwuxiang" or not _slots(record["slots"], 30, ids, protected): return _bad("VIEW_CHEST_INVALID")
	return {"ok": true}

func address_valid(address: Variant, require_visible_chest: bool = true, value: Dictionary = {}) -> bool:
	if not Core._fields(address, ["container", "owner", "slot"]): return false
	if not address["container"] is String or not CAPACITIES.has(address["container"]) or not Core._id(address["owner"]) or typeof(address["slot"]) != TYPE_INT: return false
	if address["slot"] < 0 or address["slot"] >= CAPACITIES[address["container"]]: return false
	if address["container"] != "chest": return address["owner"] == _profile
	# A carried stack can retain the origin of a chest that is no longer visible.
	var current: Dictionary = _cache if value.is_empty() else value
	return not require_visible_chest or current.get("chests", {}).has(address["owner"])

func _slots(value: Variant, capacity: int, ids: Dictionary, protected: Dictionary) -> bool:
	if not value is Array or value.size() != capacity: return false
	for entry in value:
		if not _stack(entry, ids, protected): return false
	return true

func _stack(value: Variant, ids: Dictionary, protected: Dictionary) -> bool:
	if value == null: return true
	if not Core._fields(value, Core.STACK_FIELDS) or not value["content_id"] is String or not _rules["item_rules"].has(value["content_id"]): return false
	var rule: Dictionary = _rules["item_rules"][value["content_id"]]
	if typeof(value["quantity"]) != TYPE_INT or value["quantity"] < 1 or value["quantity"] > int(rule["max_stack"]): return false
	if not value["item_instance_id"] is String or not value["protected_instance_id"] is String or not value["state"] is Dictionary: return false
	if not value["protected_instance_id"].is_empty() and value["quantity"] != 1: return false
	if rule["instance"]:
		if value["quantity"] != 1 or not Core._id(value["item_instance_id"]): return false
	elif not value["item_instance_id"].is_empty() or not value["state"].is_empty(): return false
	for pair in [["item_instance_id", ids], ["protected_instance_id", protected]]:
		var id: String = value[pair[0]]
		if id.is_empty(): continue
		if not Core._id(id) or pair[1].has(id): return false
		pair[1][id] = true
	return true

static func _counter(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value <= Core.MAX_SEQUENCE

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "state_changed": false}

static func _exact(value: Variant) -> String:
	# Key insertion order is not inventory state; scalar bits still are.
	return JSON.stringify(Codec.encode(_canonical(value)).get("value"), "", true, true)

static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys: result[key] = _canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value: result.append(_canonical(entry))
		return result
	return value
