extends RefCounted
## Server-owned whole-component candidates. No caller may publish only one half.
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Plan = preload("res://scripts/inventory/inventory_drop_plan012.gd")
const State = preload("res://scripts/actor/actor_state.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const LIFETIME := 300.0 # cehua P142; 133_死亡恢复掉落 C5.
const BASE_DELAY := 0.5 # actor_settings base_pickup_delay_seconds.
const THROWER_EXTRA := 1.0 # actor_settings thrower_extra_pickup_delay_seconds.

static func prepare_drop(core: RefCounted, profile: String, kind: String, address: Variant, revision: Variant, sequence: Variant, layer: Dictionary, origin: Vector2, landing: Vector2, world_seconds: float) -> Dictionary:
	if core == null or core.get_script() != Core or not core.ready: return Core._bad("GROUND_CORE_INVALID")
	var source_token: String = Core._exact(core.snapshot())
	# Layer/origin/landing come from the confirmed actor and an H1 throw query,
	# never client coordinates. This pure helper cannot certify that world query.
	if not Address.valid_layer(layer) or layer["world_id"] != core._world_id or not origin.is_finite() or not landing.is_finite() or not State.valid_clock(world_seconds): return Core._bad("GROUND_SPATIAL_CONTEXT_INVALID")
	if origin.distance_to(landing) > 3.000001: return Core._bad("GROUND_THROW_DISTANCE_INVALID")
	var result: Dictionary = Plan.prepare(core, profile, kind, address, revision, sequence)
	if not result.get("ok", false): return result
	var candidate: Dictionary = result["inventory"]
	if result["drop"] != null:
		if candidate["schema_version"] == 1:
			# Exact additive transition occurs only with the first real drop.
			candidate["schema_version"] = 2
			candidate["ground"] = {}
			candidate["ground_serial"] = 0
			candidate["ground_clock"] = world_seconds
		if candidate["ground"].size() >= Core.MAX_GROUND or candidate["ground_serial"] >= Core.MAX_SEQUENCE: return Core._bad("GROUND_CAPACITY_LIMIT")
		if candidate["ground_clock"] != world_seconds: return Core._bad("GROUND_CONFIRMED_CLOCK_REQUIRED")
		candidate["ground_serial"] += 1
		var id: String = "drop_" + core._world_id.trim_prefix("world_") + "_" + str(candidate["ground_serial"])
		if candidate["ground"].has(id): return Core._bad("GROUND_ID_REPLAY")
		candidate["ground"][id] = {"layer": layer.duplicate(true), "position": State.pair(origin), "stack": result["drop"].duplicate(true), "lots": [{"quantity": result["drop"]["quantity"], "remaining_lifetime": LIFETIME, "remaining_delay": BASE_DELAY, "thrower": profile, "remaining_thrower_protection": BASE_DELAY + THROWER_EXTRA}], "trajectory": {"origin": State.pair(origin), "target": State.pair(landing), "remaining_seconds": BASE_DELAY}}
	var checked: Dictionary = core.validate_snapshot(candidate)
	if not checked["ok"]: return checked
	if core._totals(candidate) != core._totals(core.snapshot()): return Core._bad("INVENTORY_CONSERVATION_FAILED")
	return {"ok": true, "source_token": source_token, "state": candidate, "action": result["action"], "sequence": sequence, "published": false, "durable": false}

static func advance(core: RefCounted, world_seconds: float) -> Dictionary:
	if core == null or core.get_script() != Core or not core.ready: return Core._bad("GROUND_CORE_INVALID")
	var source_token: String = Core._exact(core.snapshot())
	var candidate: Dictionary = core.snapshot()
	if not State.valid_clock(world_seconds): return Core._bad("GROUND_CLOCK_INVALID")
	if candidate["schema_version"] == 1: return {"ok": true, "source_token": source_token, "state": candidate, "expired": {}}
	if world_seconds < candidate["ground_clock"]: return Core._bad("GROUND_CLOCK_REGRESSED")
	var delta: float = world_seconds - candidate["ground_clock"]
	candidate["ground_clock"] = world_seconds
	var expired: Dictionary = {}
	for id in candidate["ground"].keys():
		var record: Dictionary = candidate["ground"][id]
		var trajectory: Dictionary = record["trajectory"]
		if trajectory["remaining_seconds"] > 0.0:
			trajectory["remaining_seconds"] = maxf(0.0, trajectory["remaining_seconds"] - delta)
			var weight: float = 1.0 - trajectory["remaining_seconds"] / BASE_DELAY
			record["position"] = State.pair(State.vector(trajectory["origin"]).lerp(State.vector(trajectory["target"]), weight))
		var kept: Array = []
		var total: int = 0
		for lot in record["lots"]:
			for timer in ["remaining_lifetime", "remaining_delay", "remaining_thrower_protection"]:
				if lot[timer] != null: lot[timer] = maxf(0.0, lot[timer] - delta)
			if lot["remaining_lifetime"] == 0.0:
				var gone: Dictionary = record["stack"].duplicate(true)
				gone["quantity"] = lot["quantity"]
				Core._count(expired, gone)
			else:
				kept.append(lot)
				total += lot["quantity"]
		if total == 0: candidate["ground"].erase(id)
		else:
			record["lots"] = kept
			record["stack"]["quantity"] = total
	_merge_settled(core, candidate["ground"])
	var checked: Dictionary = core.validate_snapshot(candidate)
	if not checked["ok"]: return checked
	var accounted: Dictionary = core._totals(candidate)
	for key in expired: accounted[key] = int(accounted.get(key, 0)) + expired[key]
	if accounted != core._totals(core.snapshot()): return Core._bad("GROUND_EXPIRY_CONSERVATION_FAILED")
	return {"ok": true, "source_token": source_token, "state": candidate, "expired": expired, "published": false, "durable": false}

static func _merge_settled(core: RefCounted, ground: Dictionary) -> void:
	var ids: Array = ground.keys()
	ids.sort()
	for target_index in range(ids.size()):
		if not ground.has(ids[target_index]): continue
		var target: Dictionary = ground[ids[target_index]]
		if target["trajectory"]["remaining_seconds"] > 0.0: continue
		for source_index in range(target_index + 1, ids.size()):
			var source_id: String = ids[source_index]
			if not ground.has(source_id): continue
			var source: Dictionary = ground[source_id]
			if source["trajectory"]["remaining_seconds"] > 0.0 or source["layer"] != target["layer"] or State.vector(source["position"]).distance_squared_to(State.vector(target["position"])) > 1.0 or not core._mergeable(source["stack"], target["stack"]): continue
			var room: int = int(core._rules["item_rules"][target["stack"]["content_id"]]["max_stack"]) - target["stack"]["quantity"]
			if room <= 0: break
			# Preserve each cohort's own expiry and thrower protection. Merging
			# never renews old loot or makes the new thrower eligible too early.
			while room > 0 and not source["lots"].is_empty() and target["lots"].size() < 64:
				var lot: Dictionary = source["lots"][0]
				var moved: int = mini(room, lot["quantity"])
				var transferred: Dictionary = lot.duplicate(true)
				transferred["quantity"] = moved
				target["lots"].append(transferred)
				target["stack"]["quantity"] += moved
				source["stack"]["quantity"] -= moved
				lot["quantity"] -= moved
				room -= moved
				if lot["quantity"] == 0: source["lots"].pop_front()
			if source["stack"]["quantity"] == 0: ground.erase(source_id)

static func pickup(core: RefCounted, active: Dictionary, delta: float, pickup_range: float, speed: float) -> Dictionary:
	if core == null or core.get_script() != Core or not core.ready or not is_finite(delta) or delta < 0.0 or not is_finite(pickup_range) or pickup_range <= 0.0 or not is_finite(speed) or speed <= 0.0: return Core._bad("GROUND_PICKUP_CONTEXT")
	var candidate: Dictionary = core.snapshot()
	var source_token: String = Core._exact(candidate)
	if candidate["schema_version"] == 1: return {"ok": true, "state": candidate, "source_token": source_token}
	var profiles: Array = active.keys()
	profiles.sort()
	for profile in profiles:
		if not candidate["players"].has(profile) or not Core._fields(active[profile], ["layer", "position"]) or not Address.valid_layer(active[profile]["layer"]) or active[profile]["layer"]["world_id"] != core._world_id or not State.valid_pair(active[profile]["position"]): return Core._bad("GROUND_PICKUP_CONTEXT")
	var transferred: bool = false
	var ids: Array = candidate["ground"].keys()
	ids.sort()
	for id in ids:
		var record: Dictionary = candidate["ground"][id]
		if record["trajectory"]["remaining_seconds"] > 0.0: continue
		var target: String = ""
		var distance: float = INF
		for profile in profiles:
			if active[profile]["layer"] != record["layer"] or _eligible_quantity(record["lots"], profile) == 0 or _capacity(core, candidate["players"][profile], record["stack"]) == 0: continue
			var d: float = State.vector(record["position"]).distance_to(State.vector(active[profile]["position"]))
			# Sorted stable profile IDs retain the first exactly tied candidate.
			if d <= pickup_range and d < distance:
				target = profile
				distance = d
		if target.is_empty(): continue
		var destination: Vector2 = State.vector(active[target]["position"])
		if distance > speed * delta:
			record["position"] = State.pair(State.vector(record["position"]).move_toward(destination, speed * delta))
			continue
		record["position"] = State.pair(destination)
		var lots: Array = []
		for lot in record["lots"]:
			if not _eligible(lot, target):
				lots.append(lot)
				continue
			var stack: Dictionary = record["stack"].duplicate(true)
			stack["quantity"] = lot["quantity"]
			var received: int = _insert(core, candidate["players"][target], stack)
			lot["quantity"] -= received
			record["stack"]["quantity"] -= received
			transferred = transferred or received > 0
			if lot["quantity"] > 0: lots.append(lot)
		if record["stack"]["quantity"] == 0: candidate["ground"].erase(id)
		else: record["lots"] = lots
	if transferred:
		if candidate["revision"] >= Core.MAX_SEQUENCE: return Core._bad("INVENTORY_REVISION_LIMIT")
		candidate["revision"] += 1
	var checked: Dictionary = core.validate_snapshot(candidate)
	if not checked["ok"]: return checked
	if core._totals(candidate) != core._totals(core.snapshot()): return Core._bad("INVENTORY_CONSERVATION_FAILED")
	return {"ok": true, "state": candidate, "source_token": source_token, "published": false, "durable": false}

static func _eligible(lot: Dictionary, profile: String) -> bool:
	return lot["remaining_delay"] <= 0.0 and (lot["thrower"] != profile or lot["remaining_thrower_protection"] <= 0.0)
static func _eligible_quantity(lots: Array, profile: String) -> int:
	var total: int = 0
	for lot in lots:
		if _eligible(lot, profile): total += lot["quantity"]
	return total
static func _capacity(core: RefCounted, player: Dictionary, stack: Dictionary) -> int:
	var room: int = 0
	var maximum: int = core._rules["item_rules"][stack["content_id"]]["max_stack"]
	for kind in ["hotbar", "bag"]:
		for current in player[kind]:
			if current == null: room += maximum
			elif core._mergeable(current, stack): room += maximum - current["quantity"]
	return room
static func _insert(core: RefCounted, player: Dictionary, stack: Dictionary) -> int:
	var remaining: int = stack["quantity"]
	var maximum: int = core._rules["item_rules"][stack["content_id"]]["max_stack"]
	for kind in ["hotbar", "bag"]:
		# Fill compatible stacks before occupying empty slots, within hotbar first.
		for index in range(player[kind].size()):
			var current: Variant = player[kind][index]
			if current == null or not core._mergeable(current, stack): continue
			var moved: int = mini(remaining, maximum - current["quantity"])
			current["quantity"] += moved
			remaining -= moved
			if remaining == 0: return stack["quantity"]
		for index in range(player[kind].size()):
			if player[kind][index] != null: continue
			var moved: int = mini(remaining, maximum)
			player[kind][index] = stack.duplicate(true)
			player[kind][index]["quantity"] = moved
			remaining -= moved
			if remaining == 0: return stack["quantity"]
	return stack["quantity"] - remaining
