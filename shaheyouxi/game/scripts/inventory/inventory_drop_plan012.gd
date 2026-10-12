extends RefCounted
## Pure detached transfer planning. Never publishes either ownership half.
## The server must commit inventory+world together after spatial/auth checks.
const Address = preload("res://scripts/world/spatial_address.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")

static func prepare(core: RefCounted, profile: String, kind: String, address: Variant, expected_revision: Variant, sequence: Variant) -> Dictionary:
	if core == null or core.get_script() != Core or not core.ready: return Core._bad("DROP_CORE_INVALID")
	var before: Dictionary = core.snapshot()
	if not before["players"].has(profile): return Core._bad("INVENTORY_PLAYER_UNKNOWN")
	if typeof(expected_revision) != TYPE_INT or expected_revision != before["revision"]: return Core._bad("INVENTORY_STALE_REVISION")
	if typeof(sequence) != TYPE_INT or sequence <= before["players"][profile]["last_sequence"] or sequence > Core.MAX_SEQUENCE: return Core._bad("INVENTORY_STALE_SEQUENCE")
	if before["revision"] >= Core.MAX_SEQUENCE: return Core._bad("INVENTORY_REVISION_LIMIT")
	if kind not in ["q_one", "carry_all", "right_half"]: return Core._bad("DROP_KIND_INVALID")
	var candidate: Dictionary = before.duplicate(true)
	var player: Dictionary = candidate["players"][profile]
	var source: Variant = player["carry"]
	var slots: Array = []
	var slot: int = -1
	if kind == "q_one":
		# The UI resolves hovered/selected slot; authority rechecks its scope.
		var allowed: Dictionary = core._address(profile, address)
		if not allowed["ok"]: return allowed
		slots = candidate["chests"][address["owner"]]["slots"] if address["container"] == "chest" else player[address["container"]]
		slot = address["slot"]
		source = slots[slot]
	if source == null: return Core._bad("INVENTORY_EMPTY_SLOT")
	var amount: int = 1 if kind == "q_one" else source["quantity"]
	if kind == "right_half": amount = (int(source["quantity"]) + 1) / 2
	var moved: Dictionary = source.duplicate(true)
	moved["quantity"] = amount
	var dropped: Variant = moved
	var action: String = "drop"
	if kind == "right_half":
		var origin: Dictionary = player["carry_origin"]
		# A chest whose grant expired must not be written remotely.
		if core._address(profile, origin)["ok"]:
			var origin_slots: Array = candidate["chests"][origin["owner"]]["slots"] if origin["container"] == "chest" else player[origin["container"]]
			var target: Variant = origin_slots[origin["slot"]]
			if target == null:
				origin_slots[origin["slot"]] = moved
				dropped = null
			elif core._mergeable(moved, target) and target["quantity"] + amount <= core._rules["item_rules"][target["content_id"]]["max_stack"]:
				target["quantity"] += amount
				dropped = null
		if dropped == null: action = "half_return"
		else: action = "half_drop"
	source["quantity"] -= amount
	if source["quantity"] == 0:
		if kind == "q_one": slots[slot] = null
		else:
			player["carry"] = null
			player["carry_origin"] = null
	player["last_sequence"] = sequence
	candidate["revision"] += 1
	var checked: Dictionary = core.validate_snapshot(candidate)
	if not checked["ok"]: return checked
	var totals: Dictionary = core._totals(candidate)
	Core._count(totals, dropped)
	if totals != core._totals(before): return Core._bad("INVENTORY_CONSERVATION_FAILED")
	return {"ok": true, "action": action, "inventory": candidate, "drop": dropped, "source_revision": expected_revision, "sequence": sequence, "published": false, "durable": false}

static func merge_nearby(core: RefCounted, incoming: Dictionary, existing: Array) -> Dictionary:
	# Records are server-produced {id, scope, position:Vector2 (cell units), stack}. No clocks
	# are altered here. The future world owner retains per-record lifetime rules.
	if core == null or core.get_script() != Core or not core.ready or not _record_valid(core, incoming): return Core._bad("DROP_RECORD_INVALID")
	var ids: Dictionary = {incoming["id"]: true}
	var instances: Dictionary = {}
	var protected: Dictionary = {}
	if not core._stack_valid(incoming["stack"], instances, protected): return Core._bad("DROP_RECORD_INVALID")
	var candidates: Array = existing.duplicate(true)
	for record in candidates:
		if not _record_valid(core, record) or ids.has(record["id"]): return Core._bad("DROP_RECORD_INVALID")
		ids[record["id"]] = true
		if not core._stack_valid(record["stack"], instances, protected): return Core._bad("DROP_DUPLICATE_INSTANCE")
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	var remainder: Dictionary = incoming.duplicate(true)
	var initial: Dictionary = {}
	for record in candidates: Core._count(initial, record["stack"])
	Core._count(initial, remainder["stack"])
	for record in candidates:
		if record["scope"] != remainder["scope"] or record["position"].distance_squared_to(remainder["position"]) > 1.0: continue
		if not core._mergeable(record["stack"], remainder["stack"]): continue
		var room: int = core._rules["item_rules"][record["stack"]["content_id"]]["max_stack"] - record["stack"]["quantity"]
		var quantity: int = mini(room, remainder["stack"]["quantity"])
		record["stack"]["quantity"] += quantity
		remainder["stack"]["quantity"] -= quantity
		if remainder["stack"]["quantity"] == 0: break
	if remainder["stack"]["quantity"] > 0: candidates.append(remainder)
	var after: Dictionary = {}
	for record in candidates: Core._count(after, record["stack"])
	if initial != after: return Core._bad("INVENTORY_CONSERVATION_FAILED")
	return {"ok": true, "records": candidates, "published": false, "durable": false}

static func _record_valid(core: RefCounted, value: Variant) -> bool:
	if not Core._fields(value, ["id", "scope", "position", "stack"]) or not Core._id(value["id"]) or not _scope_valid(value["scope"], core._world_id) or not value["position"] is Vector2 or not value["position"].is_finite() or value["stack"] == null: return false
	return core._stack_valid(value["stack"], {}, {})

static func _scope_valid(value: Variant, world_id: String) -> bool:
	return Address.valid_layer(value) and value["world_id"] == world_id
