extends RefCounted
## Deterministic first-body TECHNICAL PREVIEW, never a playable-world publisher.
const Seed = preload("res://scripts/worldgen/world_seed.gd")
const Inputs = preload("res://scripts/worldgen/generation_inputs.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const GENERATION_VERSION := "007-mother-skeleton-v1"
const ARTIFACT_KIND := "technical_world_layout_preview"
var generation_calls: int = 0
var _seed_decimal: String = ""
var _attempts: int = 0
var _radius: int = 0
var _retry_counts: Dictionary = {}

func generate(world_id: String, seed_value: Variant, input_document: Dictionary, options: Dictionary) -> Dictionary:
	generation_calls += 1
	_seed_decimal = ""
	_retry_counts = {}
	var selected: Dictionary = Seed.from_integer(seed_value)
	if not selected["ok"]:
		return selected
	_seed_decimal = selected["decimal"]
	if not SandboxServerAuthority._valid_id(world_id, "world_"):
		return _failure("INVALID_WORLD_ID")
	var inputs := Inputs.new()
	if not inputs.load_document(input_document):
		return _failure(inputs.last_error)
	# Operational safety ceiling, not a new gameplay balance quantity. No default.
	if not Address.is_integer(options.get("max_region_attempts")) or options["max_region_attempts"] < 1 or options["max_region_attempts"] > 128:
		return _failure("EXPLICIT_BOUNDED_RETRY_CONFIGURATION_REQUIRED")
	_seed_decimal = selected["decimal"]
	_attempts = int(options["max_region_attempts"])
	_radius = int(inputs.data["body"]["radius_cells"])
	_retry_counts = {}
	var spawn_result: Dictionary = _disc_cell("spawn", int(inputs.data["body"]["spawn_center_radius_cells"]), {})
	if not spawn_result["ok"]:
		return spawn_result
	var spawn: Vector2i = spawn_result["cell"]
	var sites: Array = []
	for depth in [0, 1, 2]:
		var ids: Array = []
		for id in inputs.data["biomes"]:
			if int(inputs.data["biomes"][id]["depth"]) == depth:
				ids.append(id)
		ids.sort()
		var used: Dictionary = {}
		if depth == 0:
			used[Address.cell_key(spawn)] = true
		for id in ids:
			var row: Dictionary = inputs.data["biomes"][id]
			var cell := spawn
			if id != inputs.data["body"]["starting_biome_id"]:
				var choice: Dictionary = _disc_cell("biome|" + id, _radius, used)
				if not choice["ok"]:
					return choice
				cell = choice["cell"]
			used[Address.cell_key(cell)] = true
			sites.append({"biome_id": id, "map_kind": row["map_kind"], "depth": depth, "cell": _array(cell), "ground_resource_id": row["ground_resource_id"], "default_rock_id": row["default_rock_id"]})
	var connections: Array = []
	var first_rule: Dictionary = inputs.data["connections"][0]
	var second_rule: Dictionary = inputs.data["connections"][1]
	var surface_bodies: Array[Rect2i] = []
	var middle_bodies: Array[Rect2i] = []
	for index in range(int(first_rule["spawn_min_count"])):
		var first: Dictionary = _entry_cell("entry0|%d" % index, spawn, int(first_rule["spawn_min_distance"]), int(first_rule["spawn_max_distance"]), int(first_rule["body_side_cells"]), int(first_rule["safety_side_cells"]), surface_bodies)
		if not first["ok"]:
			return first
		var cell: Vector2i = first["cell"]
		var body: Rect2i = _centered_rect(cell, int(first_rule["body_side_cells"]))
		surface_bodies.append(body)
		middle_bodies.append(body)
		connections.append(_connection(world_id, first_rule, cell))
	var upper_connections: Array = connections.duplicate(true)
	var deeper_bodies: Array[Rect2i] = []
	for upper in upper_connections:
		var landing: Vector2i = Vector2i(int(upper["endpoints"][1]["cell"][0]), int(upper["endpoints"][1]["cell"][1]))
		for index in range(int(first_rule["continuation_min_count"])):
			var domain: String = "entry1|%s|%d" % [Address.cell_key(landing), index]
			var next: Dictionary = _entry_cell(domain, landing, 0, int(first_rule["continuation_radius"]), int(second_rule["body_side_cells"]), int(second_rule["safety_side_cells"]), middle_bodies)
			if not next["ok"]:
				return next
			var cell: Vector2i = next["cell"]
			var body: Rect2i = _centered_rect(cell, int(second_rule["body_side_cells"]))
			middle_bodies.append(body)
			deeper_bodies.append(body)
			connections.append(_connection(world_id, second_rule, cell))
	var stages: Array = stage_records()
	var plan: Dictionary = {"schema_version": 1, "artifact_kind": ARTIFACT_KIND, "generation_version": GENERATION_VERSION, "world_id": world_id, "seed_decimal": _seed_decimal, "sources": inputs.data["sources"].duplicate(true), "body": inputs.data["body"].duplicate(true), "spawn": {"layer": Address.layer(world_id, "body_0001", "surface", 0), "cell": _array(spawn)}, "biome_sites": sites, "connections": connections, "generation_stages": stages, "retry_configuration": {"max_region_attempts": _attempts}, "retry_counts": _retry_counts.duplicate(true), "permanent_changes": {}, "formal_world_allowed": false, "unresolved": inputs.data["unresolved"].duplicate(true)}
	for key in ["radius_cells", "diameter_cells", "spawn_center_radius_cells"]:
		plan["body"][key] = int(plan["body"][key])
	plan["core_layout_fingerprint"] = core_fingerprint(plan)
	return {"ok": true, "plan": plan, "formal_world_allowed": false}

func _disc_cell(domain: String, radius: int, used: Dictionary) -> Dictionary:
	for attempt in range(_attempts):
		var cell := Vector2i(_sample(domain + "|x", attempt, -radius, radius - 1), _sample(domain + "|y", attempt, -radius, radius - 1))
		if _center_in_disc(cell, radius) and not used.has(Address.cell_key(cell)):
			_retry_counts[domain] = attempt + 1
			return {"ok": true, "cell": cell}
	return _failure("REGION_RETRY_LIMIT", domain)

func _entry_cell(domain: String, origin: Vector2i, minimum: int, maximum: int, body_side: int, safety_side: int, occupied: Array[Rect2i]) -> Dictionary:
	for attempt in range(_attempts):
		var offset := Vector2i(_sample(domain + "|x", attempt, -maximum, maximum), _sample(domain + "|y", attempt, -maximum, maximum))
		var distance_squared: int = int(offset.x) * int(offset.x) + int(offset.y) * int(offset.y)
		if distance_squared < minimum * minimum or distance_squared > maximum * maximum:
			continue
		var cx: int = int(origin.x) + int(offset.x)
		var cy: int = int(origin.y) + int(offset.y)
		var half: int = (safety_side - 1) >> 1
		if cx - half < -_radius or cy - half < -_radius or cx + half + 1 > _radius or cy + half + 1 > _radius:
			continue
		var cell := Vector2i(cx, cy)
		var body: Rect2i = _centered_rect(cell, body_side)
		if not _rectangle_in_disc(_centered_rect(cell, safety_side), _radius):
			continue
		var conflict: bool = false
		for other in occupied:
			if body.intersects(other):
				conflict = true
				break
		if not conflict:
			_retry_counts[domain] = attempt + 1
			return {"ok": true, "cell": cell}
	return _failure("REGION_RETRY_LIMIT", domain)

func _sample(domain: String, attempt: int, minimum: int, maximum: int) -> int:
	var message: String = JSON.stringify([GENERATION_VERSION, _seed_decimal, "xingxing_03", domain, attempt])
	var word: int = message.sha256_text().substr(0, 8).hex_to_int()
	return minimum + word % (maximum - minimum + 1)

static func _connection(world_id: String, rule: Dictionary, cell: Vector2i) -> Dictionary:
	var endpoints: Array = []
	for key in ["upper", "lower"]:
		var layer: Dictionary = rule[key]
		endpoints.append({"layer": Address.layer(world_id, "body_0001", layer["map_kind"], int(layer["depth"])), "cell": _array(cell)})
	var side: int = int(rule["safety_side_cells"])
	var box: Rect2i = _centered_rect(cell, side)
	var id_material: String = JSON.stringify([world_id, int(rule["upper"]["depth"]), int(rule["lower"]["depth"]), _array(cell)])
	return {"connection_instance_id": "connection_" + id_material.sha256_text().substr(0, 32), "endpoints": endpoints, "body_side_cells": int(rule["body_side_cells"]), "safety_rect": [box.position.x, box.position.y, box.size.x, box.size.y], "natural": true, "bidirectional": true, "interaction_required": true}

static func _centered_rect(cell: Vector2i, side: int) -> Rect2i:
	var half: int = (side - 1) >> 1
	return Rect2i(cell - Vector2i(half, half), Vector2i(side, side))

static func _center_in_disc(cell: Vector2i, radius: int) -> bool:
	var x: int = 2 * int(cell.x) + 1
	var y: int = 2 * int(cell.y) + 1
	return x * x + y * y <= 4 * radius * radius

static func _rectangle_in_disc(box: Rect2i, radius: int) -> bool:
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			if int(x) * int(x) + int(y) * int(y) > radius * radius:
				return false
	return true

static func _array(cell: Vector2i) -> Array:
	return [cell.x, cell.y]

static func core_fingerprint(plan: Dictionary) -> String:
	# Core identity excludes transient world/connection instance IDs and all visuals.
	var links: Array = []
	for connection in plan["connections"]:
		var ends: Array = []
		for endpoint in connection["endpoints"]:
			ends.append({"map_kind": endpoint["layer"]["map_kind"], "depth": int(endpoint["layer"]["depth"]), "cell": endpoint["cell"]})
		links.append({"endpoints": ends, "body_side_cells": connection["body_side_cells"], "safety_rect": connection["safety_rect"]})
	var core: Dictionary = {"generation_version": plan["generation_version"], "seed_decimal": plan["seed_decimal"], "body_id": plan["body"]["body_id"], "radius_cells": plan["body"]["radius_cells"], "spawn_cell": plan["spawn"]["cell"], "biome_sites": plan["biome_sites"], "connections": links}
	return JSON.stringify(core, "", true, true).sha256_text()

func _failure(code: String, region: String = "") -> Dictionary:
	return {"ok": false, "code": code, "region": region, "seed_decimal": _seed_decimal, "formal_world_allowed": false}

static func stage_records() -> Array:
	var stages: Array = []
	for stage in Inputs.ORDER:
		stages.append({"stage": stage, "status": "interface_declared_not_complete"})
	stages[0]["status"] = "technical_skeleton_materialized"
	stages[2]["status"] = "technical_entry_contract_positions_materialized"
	stages[3]["status"] = "technical_biome_sites_materialized"
	stages[-1]["status"] = "formal_world_blocked_by_unresolved_dependencies"
	return stages
