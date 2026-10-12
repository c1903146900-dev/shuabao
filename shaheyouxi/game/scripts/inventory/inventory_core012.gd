extends RefCounted
## Standalone server-side inventory transport. No RPC, main-save/schema4 change,
## item grant, combat-state certification, UI, pickup or unresolved input policy.
const Address = preload("res://scripts/world/spatial_address.gd")
const ActorState = preload("res://scripts/actor/actor_state.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const Scope = preload("res://scripts/actor/actor_local_session_scope.gd")
const RULES_PATH := "res://data/inventory012_rules.json"
const RULES_SHA256 := "a109a160363eb742e5263973c48d8e16aa55f7d3874af35225a9fb354ef75725"
const TREE_RULES_PATH := "res://data/inventory012_tree_rules.json"
const TREE_RULES_SHA256 := "ac60f8dca6b2648531b250191d0b6369844c59a001dc671e0bf76df321050cd0"
const CONTRACT := "sandbox012-inventory-core-v1"
const FORMAT := "inventory012-exact-snapshot-v1"
const GROUND_FIELDS := ["ground", "ground_serial", "ground_clock"]
const MAX_GROUND := 512 # Technical bounded slice, not a gameplay population cap.
const MAX_ENTITIES := 64 # Technical bounded-core budget, not game population.
const MAX_BYTES := 4194304
const MAX_SEQUENCE := 9007199254740991
const STACK_FIELDS := ["content_id", "quantity", "item_instance_id", "protected_instance_id", "state"]
const STATE_FIELDS := ["schema_version", "contract", "rules_sha256", "world_id", "revision", "players", "chests", "external_item_instance_ids", "external_protected_instance_ids"]
var _rules_identity: String = RULES_SHA256
var _tree_rules: bool = false
var _world_id: String = ""
var ready: bool = false
var _rules: Dictionary = {}
var _state: Dictionary = {}
var _access: Dictionary = {} # Ephemeral server-issued chest scopes; never loaded.

func _init(world_id: String, semantic_rules: String = "v1") -> void:
	if semantic_rules not in ["v1", "v2_tree_seed"]: return
	_tree_rules = semantic_rules == "v2_tree_seed"
	_rules_identity = TREE_RULES_SHA256 if _tree_rules else RULES_SHA256
	if not _world_id_valid(world_id): return
	_world_id = world_id
	var text: String = FileAccess.get_file_as_string(TREE_RULES_PATH if _tree_rules else RULES_PATH)
	if text.sha256_text() != _rules_identity: return
	var document: Variant = JSON.parse_string(text)
	if not document is Dictionary or document.get("contract") != ("inventory012-source-rules-v2-tree-seed" if _tree_rules else "inventory012-source-rules-v1"): return
	_rules = document
	_state = {"schema_version": 1, "contract": CONTRACT, "rules_sha256": _rules_identity, "world_id": _world_id, "revision": 0, "players": {}, "chests": {}, "external_item_instance_ids": [], "external_protected_instance_ids": []}
	ready = true

func revision() -> int:
	return int(_state.get("revision", -1))

func snapshot() -> Dictionary:
	return _state.duplicate(true) if ready else {}

func trusted_create_player(profile_id: String) -> Dictionary:
	if not ready or not _id(profile_id) or _state["players"].has(profile_id) or _state["players"].size() >= MAX_ENTITIES or revision() >= MAX_SEQUENCE: return _bad("INVENTORY_PLAYER_CREATE_INVALID")
	var candidate: Dictionary = snapshot()
	candidate["players"][profile_id] = {"bag": _empty_slots("bag"), "hotbar": _empty_slots("hotbar"), "carry": null, "carry_origin": null, "last_sequence": 0}
	candidate["revision"] += 1
	return _publish(candidate, "INVENTORY_EMPTY_PLAYER_CREATED")

func trusted_create_chest(instance_id: String) -> Dictionary:
	if not ready or not _id(instance_id) or _state["chests"].has(instance_id) or _state["chests"].size() >= MAX_ENTITIES or revision() >= MAX_SEQUENCE: return _bad("INVENTORY_CHEST_CREATE_INVALID")
	var candidate: Dictionary = snapshot()
	candidate["chests"][instance_id] = {"content_id": "chuwuxiang", "slots": _empty_slots("chest")}
	candidate["revision"] += 1
	return _publish(candidate, "INVENTORY_EMPTY_SINGLE_CHEST_CREATED")

func trusted_set_chest_access(profile_id: String, chest_id: String, allowed: bool) -> Dictionary:
	# Host must verify current actor/world/range/F context before granting this.
	# This is NOT an exposed client intent or proof of spatial accessibility.
	if not ready or not _state["players"].has(profile_id) or not _state["chests"].has(chest_id): return _bad("INVENTORY_ACCESS_SCOPE_INVALID")
	if not _access.has(profile_id): _access[profile_id] = {}
	if allowed: _access[profile_id][chest_id] = true
	else: _access[profile_id].erase(chest_id)
	return {"ok": true, "code": "INVENTORY_TRUSTED_SCOPE_UPDATED"}

func close_view(profile_id: String) -> Dictionary:
	if not ready or not _state["players"].has(profile_id): return _bad("INVENTORY_PLAYER_UNKNOWN")
	_access.erase(profile_id)
	# The server-owned carry remains exactly where it already is. No source
	# restoration, count change, implicit drop or disconnect decision occurs.
	return {"ok": true, "code": "INVENTORY_VIEW_CLOSED_CARRY_UNCHANGED", "revision": revision()}

func view(profile_id: String) -> Dictionary:
	if not ready or not _state["players"].has(profile_id): return {}
	var result: Dictionary = {"world_id": _world_id, "revision": revision(), "inventory": _state["players"][profile_id].duplicate(true), "chests": {}}
	for chest in _access.get(profile_id, {}):
		if _state["chests"].has(chest): result["chests"][chest] = _state["chests"][chest].duplicate(true)
	return result

func click_slot(profile_id: String, address: Variant, expected_revision: Variant, sequence: Variant) -> Dictionary:
	# profile_id comes from authenticated server connection context, never from
	# client-supplied item/count/result state. Expected revision covers all shared
	# containers, so two prepared chest takes cannot both commit an old view.
	if not ready or not _state["players"].has(profile_id): return _bad("INVENTORY_PLAYER_UNKNOWN")
	if typeof(expected_revision) != TYPE_INT or expected_revision != revision(): return _bad("INVENTORY_STALE_REVISION")
	if typeof(sequence) != TYPE_INT or sequence <= _state["players"][profile_id]["last_sequence"] or sequence > MAX_SEQUENCE: return _bad("INVENTORY_STALE_SEQUENCE")
	if revision() >= MAX_SEQUENCE: return _bad("INVENTORY_REVISION_LIMIT")
	var path: Dictionary = _address(profile_id, address)
	if not path["ok"]: return path
	var candidate: Dictionary = snapshot()
	var player: Dictionary = candidate["players"][profile_id]
	var slots: Array = candidate["chests"][address["owner"]]["slots"] if address["container"] == "chest" else player[address["container"]]
	var slot: int = address["slot"]
	var target: Variant = slots[slot]
	var held: Variant = player["carry"]
	var action: String = ""
	if held == null:
		if target == null: return _bad("INVENTORY_EMPTY_SLOT")
		player["carry"] = target
		player["carry_origin"] = address.duplicate(true)
		slots[slot] = null
		action = "lift"
	elif target == null:
		slots[slot] = held
		player["carry"] = null
		player["carry_origin"] = null
		action = "place"
	elif _mergeable(held, target):
		var room: int = int(_rules["item_rules"][target["content_id"]]["max_stack"]) - target["quantity"]
		if room <= 0: return _bad("INVENTORY_STACK_FULL")
		var moved: int = mini(room, held["quantity"])
		target["quantity"] += moved
		held["quantity"] -= moved
		if held["quantity"] == 0:
			player["carry"] = null
			player["carry_origin"] = null
		action = "merge"
	else:
		slots[slot] = held
		player["carry"] = target
		player["carry_origin"] = address.duplicate(true)
		action = "swap"
	player["last_sequence"] = sequence
	candidate["revision"] += 1
	if _totals(candidate) != _totals(_state): return _bad("INVENTORY_CONSERVATION_FAILED")
	var applied: Dictionary = _publish(candidate, "INVENTORY_TRANSACTION_COMMITTED")
	if applied["ok"]: applied.merge({"action": action, "sequence": sequence, "revision": revision()})
	return applied

func trusted_restore(value: Variant) -> Dictionary:
	# Internal server load/import boundary only. It is never an item-grant RPC.
	if not ready: return _bad("INVENTORY_RULES_NOT_READY")
	var validated: Dictionary = validate_snapshot(value)
	if not validated["ok"]: return validated
	_state = value.duplicate(true)
	_access.clear()
	return {"ok": true, "code": "INVENTORY_RESTORED_EXACT", "revision": revision()}

func encode_snapshot() -> Dictionary:
	var checked: Dictionary = validate_snapshot(_state)
	if not checked["ok"]: return checked
	var encoded: Dictionary = Codec.encode(_state)
	var payload: String = JSON.stringify(encoded["value"], "", true, true)
	var bytes: PackedByteArray = _snapshot_bytes(payload)
	return {"ok": true, "bytes": bytes} if bytes.size() <= MAX_BYTES else _bad("INVENTORY_SNAPSHOT_TOO_LARGE")

func decode_snapshot(bytes: Variant) -> Dictionary:
	if not bytes is PackedByteArray or bytes.is_empty() or bytes.size() > MAX_BYTES: return _bad("INVENTORY_BYTES_INVALID")
	var text: String = bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes: return _bad("INVENTORY_UTF8_INVALID")
	var envelope: Variant = JSON.parse_string(text)
	if not envelope is Array or envelope.size() != 3 or not envelope[0] is String or not envelope[1] is String or not envelope[2] is String or envelope[0] != FORMAT or envelope[1].sha256_text() != envelope[2]: return _bad("INVENTORY_ENVELOPE_INVALID")
	var decoded: Dictionary = Codec.decode(JSON.parse_string(envelope[1]))
	if not decoded["ok"]: return _bad("INVENTORY_EXACT_PAYLOAD_INVALID")
	return trusted_restore(decoded["value"])

func validate_snapshot(value: Variant) -> Dictionary:
	if not ready or not value is Dictionary: return _bad("INVENTORY_SCHEMA_INVALID")
	var has_ground: bool = typeof(value.get("schema_version")) == TYPE_INT and value["schema_version"] in [2, 3]
	if not _fields(value, STATE_FIELDS + GROUND_FIELDS if has_ground else STATE_FIELDS): return _bad("INVENTORY_SCHEMA_INVALID")
	var bounded: Dictionary = Codec.encode(value)
	if not bounded["ok"]: return _bad("INVENTORY_TYPE_OR_BUDGET_INVALID")
	var payload: String = JSON.stringify(bounded["value"], "", true, true)
	# Bound the final persisted envelope, including outer escaping, so every
	# accepted state is encodable under the same exact snapshot budget.
	if _snapshot_bytes(payload).size() > MAX_BYTES: return _bad("INVENTORY_TYPE_OR_BUDGET_INVALID")
	if typeof(value["schema_version"]) != TYPE_INT or value["schema_version"] not in ([1, 2, 3] if _tree_rules else [1, 2]) or not value["contract"] is String or value["contract"] != CONTRACT or not value["rules_sha256"] is String or value["rules_sha256"] != _rules_identity or not value["world_id"] is String or value["world_id"] != _world_id or typeof(value["revision"]) != TYPE_INT or value["revision"] < 0 or value["revision"] > MAX_SEQUENCE: return _bad("INVENTORY_CONTRACT_INVALID")
	if not value["players"] is Dictionary or not value["chests"] is Dictionary or value["players"].size() > MAX_ENTITIES or value["chests"].size() > MAX_ENTITIES: return _bad("INVENTORY_ENTITIES_INVALID")
	var instances: Dictionary = {}
	var protected: Dictionary = {}
	for pair in [["external_item_instance_ids", instances], ["external_protected_instance_ids", protected]]:
		if not value[pair[0]] is Array: return _bad("INVENTORY_EXTERNAL_SCOPE_INVALID")
		for id in value[pair[0]]:
			if not _id(id) or pair[1].has(id): return _bad("INVENTORY_EXTERNAL_ID_DUPLICATE")
			pair[1][id] = true
	for profile in value["players"]:
		var player: Variant = value["players"][profile]
		if not _id(profile) or not _fields(player, ["bag", "hotbar", "carry", "carry_origin", "last_sequence"]) or typeof(player["last_sequence"]) != TYPE_INT or player["last_sequence"] < 0 or player["last_sequence"] > MAX_SEQUENCE: return _bad("INVENTORY_PLAYER_INVALID")
		for kind in ["bag", "hotbar"]:
			if not _slots_valid(player[kind], kind, instances, protected): return _bad("INVENTORY_PLAYER_SLOTS_INVALID")
		if not _stack_valid(player["carry"], instances, protected): return _bad("INVENTORY_CARRY_INVALID")
		if player["carry"] == null:
			if player["carry_origin"] != null: return _bad("INVENTORY_EMPTY_CARRY_ORIGIN")
		elif not _origin_valid(value, profile, player["carry_origin"]): return _bad("INVENTORY_CARRY_ORIGIN_INVALID")
	for chest in value["chests"]:
		var record: Variant = value["chests"][chest]
		if not _id(chest) or not _fields(record, ["content_id", "slots"]) or not record["content_id"] is String or record["content_id"] != "chuwuxiang" or not _slots_valid(record["slots"], "chest", instances, protected): return _bad("INVENTORY_CHEST_INVALID")
	if has_ground:
		if typeof(value["ground_serial"]) != TYPE_INT or value["ground_serial"] < 0 or value["ground_serial"] > MAX_SEQUENCE or not ActorState.valid_clock(value["ground_clock"]) or not value["ground"] is Dictionary or value["ground"].size() > MAX_GROUND: return _bad("INVENTORY_GROUND_HEADER_INVALID")
		for id in value["ground"]:
			var record: Variant = value["ground"][id]
			if not _id(id) or not _fields(record, ["layer", "position", "stack", "lots", "trajectory"]) or not Address.valid_layer(record["layer"]) or record["layer"]["world_id"] != _world_id or not ActorState.valid_pair(record["position"]) or not _stack_valid(record["stack"], instances, protected) or record["stack"] == null: return _bad("INVENTORY_GROUND_RECORD_INVALID")
			if not record["lots"] is Array or record["lots"].is_empty() or record["lots"].size() > 64: return _bad("INVENTORY_GROUND_LOTS_INVALID")
			var quantity: int = 0
			for lot in record["lots"]:
				var natural: bool = value["schema_version"]==3 and lot is Dictionary and lot.get("source_kind")=="natural_harvest"
				var lot_fields: Array=["quantity","remaining_lifetime","remaining_delay","thrower","remaining_thrower_protection"]
				if natural: lot_fields.append_array(["source_kind","completion_id"])
				if not _fields(lot,lot_fields) or typeof(lot["quantity"])!=TYPE_INT or lot["quantity"]<1 or lot["quantity"]>record["stack"]["quantity"]: return _bad("INVENTORY_GROUND_LOT_INVALID")
				if natural:
					if lot["thrower"]!=null or lot["remaining_thrower_protection"]!=null or not _id(lot["completion_id"]) or not lot["completion_id"].begins_with("harvest_"): return _bad("INVENTORY_GROUND_NATURAL_SOURCE_INVALID")
				else:
					if not lot["thrower"] is String or not value["players"].has(lot["thrower"]): return _bad("INVENTORY_GROUND_LOT_INVALID")
					if not ActorState.valid_clock(lot["remaining_thrower_protection"]) or lot["remaining_thrower_protection"]>1.5: return _bad("INVENTORY_GROUND_LOT_TIMER_INVALID")
				for timer in ["remaining_lifetime","remaining_delay"]:
					if not ActorState.valid_clock(lot[timer]): return _bad("INVENTORY_GROUND_LOT_TIMER_INVALID")
				if lot["remaining_lifetime"]<=0.0 or lot["remaining_lifetime"]>300.0 or lot["remaining_delay"]>0.5: return _bad("INVENTORY_GROUND_LOT_TIMER_INVALID")
				quantity+=lot["quantity"]
			if quantity != record["stack"]["quantity"]: return _bad("INVENTORY_GROUND_LOT_QUANTITY_INVALID")
			var trajectory: Variant = record["trajectory"]
			if not _fields(trajectory, ["origin", "target", "remaining_seconds"]) or not ActorState.valid_pair(trajectory["origin"]) or not ActorState.valid_pair(trajectory["target"]) or not ActorState.valid_clock(trajectory["remaining_seconds"]) or trajectory["remaining_seconds"] > 0.5: return _bad("INVENTORY_GROUND_TRAJECTORY_INVALID")
	return {"ok": true}

func _publish(value: Dictionary, code: String) -> Dictionary:
	var checked: Dictionary = validate_snapshot(value)
	if not checked["ok"]: return checked
	_state = value.duplicate(true)
	return {"ok": true, "code": code}

func _empty_slots(kind: String) -> Array:
	var slots: Array = []
	slots.resize(int(_rules["capacities"][kind]))
	slots.fill(null)
	return slots

func _address(profile: String, value: Variant) -> Dictionary:
	if not _origin_valid(_state, profile, value): return _bad("INVENTORY_ADDRESS_INVALID")
	if value["container"] == "chest" and not _access.get(profile, {}).has(value["owner"]): return _bad("INVENTORY_CHEST_ACCESS_DENIED")
	return {"ok": true}

func _origin_valid(state: Dictionary, profile: String, value: Variant) -> bool:
	if not _fields(value, ["container", "owner", "slot"]) or not value["container"] is String or not value["owner"] is String or typeof(value["slot"]) != TYPE_INT: return false
	var kind: String = value["container"]
	if kind not in ["bag", "hotbar", "chest"] or value["slot"] < 0 or value["slot"] >= int(_rules["capacities"][kind]): return false
	return state["chests"].has(value["owner"]) if kind == "chest" else value["owner"] == profile

func _slots_valid(value: Variant, kind: String, instances: Dictionary, protected: Dictionary) -> bool:
	if not value is Array or value.size() != int(_rules["capacities"][kind]): return false
	for stack in value:
		if not _stack_valid(stack, instances, protected): return false
	return true

func _stack_valid(value: Variant, instances: Dictionary, protected: Dictionary) -> bool:
	if value == null: return true
	if not _fields(value, STACK_FIELDS) or not value["content_id"] is String or not _rules["item_rules"].has(value["content_id"]) or typeof(value["quantity"]) != TYPE_INT or value["quantity"] < 1 or value["quantity"] > int(_rules["item_rules"][value["content_id"]]["max_stack"]): return false
	if not value["item_instance_id"] is String or not value["protected_instance_id"] is String or not value["state"] is Dictionary: return false
	# This first transport slice does not support protected multi-unit stacks.
	# Refusal is an explicit scope limit, not a new gameplay stacking rule.
	if not value["protected_instance_id"].is_empty() and value["quantity"] != 1: return false
	var individual: bool = _rules["item_rules"][value["content_id"]]["instance"]
	if individual:
		if value["quantity"] != 1 or not _id(value["item_instance_id"]): return false
	elif not value["item_instance_id"].is_empty() or not value["state"].is_empty(): return false
	for pair in [["item_instance_id", instances], ["protected_instance_id", protected]]:
		var id: String = value[pair[0]]
		if id.is_empty(): continue
		if not _id(id) or pair[1].has(id): return false
		pair[1][id] = true
	# Opaque existing instance state is transported exactly, never recalculated
	# or newly granted here. Its combat-domain validity belongs to item authority.
	return true

func _mergeable(a: Dictionary, b: Dictionary) -> bool:
	return a["content_id"] == b["content_id"] and not _rules["item_rules"][a["content_id"]]["instance"] and a["item_instance_id"].is_empty() and b["item_instance_id"].is_empty() and a["protected_instance_id"].is_empty() and b["protected_instance_id"].is_empty() and _exact(a["state"]) == _exact(b["state"])

func _totals(value: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	for player in value["players"].values():
		for stack in player["bag"] + player["hotbar"] + [player["carry"]]: _count(totals, stack)
	for chest in value["chests"].values():
		for stack in chest["slots"]: _count(totals, stack)
	for record in value.get("ground", {}).values(): _count(totals, record["stack"])
	return totals

static func _count(totals: Dictionary, stack: Variant) -> void:
	if stack == null: return
	var key: String = _exact([stack["content_id"], stack["item_instance_id"], stack["protected_instance_id"], stack["state"]])
	totals[key] = int(totals.get(key, 0)) + stack["quantity"]

static func _snapshot_bytes(payload: String) -> PackedByteArray:
	return JSON.stringify([FORMAT, payload, payload.sha256_text()], "", true, true).to_utf8_buffer()

static func _world_id_valid(value: String) -> bool:
	if value.length() != 38 or not value.begins_with("world_"): return false
	for c in value.trim_prefix("world_"):
		if c not in "0123456789abcdef": return false
	return true

static func _exact(value: Variant) -> String:
	return JSON.stringify(Codec.encode(value).get("value"), "", true, true)

static func _fields(value: Variant, names: Array) -> bool:
	if not value is Dictionary or value.size() != names.size(): return false
	for name in names:
		if not value.has(name): return false
	return true

static func _id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 128: return false
	for c in value:
		if not (c >= "a" and c <= "z") and not (c >= "A" and c <= "Z") and not (c >= "0" and c <= "9") and c != "_": return false
	return true

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "state_changed": false}
