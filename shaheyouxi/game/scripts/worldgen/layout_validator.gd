extends RefCounted
const Seed = preload("res://scripts/worldgen/world_seed.gd")
const Inputs = preload("res://scripts/worldgen/generation_inputs.gd")
const Generator = preload("res://scripts/worldgen/layout_generator.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const FIELDS := ["schema_version", "artifact_kind", "generation_version", "world_id", "seed_decimal", "sources", "body", "spawn", "biome_sites", "connections", "generation_stages", "retry_configuration", "retry_counts", "permanent_changes", "formal_world_allowed", "unresolved", "core_layout_fingerprint"]
var _inputs: RefCounted

func _init(input_document: Dictionary) -> void:
	_inputs = Inputs.new()
	_inputs.load_document(input_document)

func validate(value: Variant, expected_world_id: String) -> Dictionary:
	if not _inputs.ready or not value is Dictionary or value.size() != FIELDS.size():
		return _bad("LAYOUT_SCHEMA_INVALID")
	for field in FIELDS:
		if not value.has(field):
			return _bad("LAYOUT_FIELD_MISSING")
	if not Address.is_integer(value["schema_version"]) or int(value["schema_version"]) != 1 or not value["artifact_kind"] is String or value["artifact_kind"] != Generator.ARTIFACT_KIND or not value["generation_version"] is String or value["generation_version"] != Generator.GENERATION_VERSION:
		return _bad("UNSUPPORTED_LAYOUT_VERSION_OR_KIND")
	if not SandboxServerAuthority._valid_id(expected_world_id, "world_") or not SandboxServerAuthority._valid_id(value["world_id"], "world_") or value["world_id"] != expected_world_id or not Seed.from_decimal(value["seed_decimal"])["ok"]:
		return _bad("LAYOUT_WORLD_OR_SEED_INVALID")
	if not value["sources"] is Dictionary or value["sources"] != _inputs.data["sources"] or typeof(value["formal_world_allowed"]) != TYPE_BOOL or value["formal_world_allowed"] != false:
		return _bad("LAYOUT_SOURCE_OR_FORMAL_BOUNDARY_INVALID")
	var plan: Dictionary = value.duplicate(true)
	plan["schema_version"] = 1
	if not plan["body"] is Dictionary:
		return _bad("BODY_RECORD_INVALID")
	var expected_body: Dictionary = _inputs.data["body"].duplicate(true)
	for key in ["radius_cells", "diameter_cells", "spawn_center_radius_cells"]:
		if not Address.is_integer(plan["body"].get(key)):
			return _bad("BODY_RECORD_INVALID")
		plan["body"][key] = int(plan["body"][key])
		expected_body[key] = int(expected_body[key])
	if plan["body"] != expected_body:
		return _bad("BODY_CONTRACT_CHANGED")
	var radius: int = expected_body["radius_cells"]
	if not plan["spawn"] is Dictionary or plan["spawn"].size() != 2 or not _layer(plan["spawn"].get("layer"), expected_world_id, 0):
		return _bad("SPAWN_LAYER_INVALID")
	var spawn: Dictionary = _cell(plan["spawn"].get("cell"), radius)
	if not spawn["ok"] or not Generator._center_in_disc(spawn["cell"], expected_body["spawn_center_radius_cells"]):
		return _bad("SPAWN_BOUNDS_INVALID")
	plan["spawn"]["cell"] = Generator._array(spawn["cell"])
	plan["spawn"]["layer"]["depth"] = 0
	if not plan["biome_sites"] is Array or plan["biome_sites"].size() != _inputs.data["biomes"].size():
		return _bad("BIOME_SITES_INCOMPLETE")
	var seen_biomes: Dictionary = {}
	var occupied_sites: Dictionary = {}
	for site in plan["biome_sites"]:
		if not site is Dictionary or site.size() != 6 or not _inputs.data["biomes"].has(site.get("biome_id")) or seen_biomes.has(site.get("biome_id")):
			return _bad("BIOME_SITE_REFERENCE_INVALID")
		var source: Dictionary = _inputs.data["biomes"][site["biome_id"]]
		if not Address.is_integer(site.get("depth")) or int(site["depth"]) != int(source["depth"]) or site.get("map_kind") != source["map_kind"] or site.get("ground_resource_id") != source["ground_resource_id"] or site.get("default_rock_id") != source["default_rock_id"]:
			return _bad("BIOME_SITE_CONTRACT_CHANGED")
		var position: Dictionary = _cell(site.get("cell"), radius)
		if not position["ok"]:
			return _bad("BIOME_SITE_BOUNDS_INVALID")
		var key: String = "%d|%s" % [int(site["depth"]), Address.cell_key(position["cell"])]
		if occupied_sites.has(key):
			return _bad("DUPLICATE_BIOME_SITE_CELL")
		if site["biome_id"] == expected_body["starting_biome_id"] and position["cell"] != spawn["cell"]:
			return _bad("SPAWN_BIOME_SITE_MISMATCH")
		seen_biomes[site["biome_id"]] = true
		occupied_sites[key] = true
		site["depth"] = int(site["depth"])
		site["cell"] = Generator._array(position["cell"])
	if not plan["connections"] is Array:
		return _bad("CONNECTIONS_MISSING")
	var first_rule: Dictionary = _inputs.data["connections"][0]
	var expected_first: int = int(first_rule["spawn_min_count"])
	var expected_second: int = expected_first * int(first_rule["continuation_min_count"])
	if plan["connections"].size() != expected_first + expected_second:
		return _bad("CONNECTION_COUNT_INVALID")
	var first_cells: Array[Vector2i] = []
	var second_cells: Array[Vector2i] = []
	var used_ids: Dictionary = {}
	var bodies_by_depth := {0: [], 1: [], 2: []}
	for connection in plan["connections"]:
		if not connection is Dictionary or connection.size() != 7 or not SandboxServerAuthority._valid_id(connection.get("connection_instance_id"), "connection_") or used_ids.has(connection.get("connection_instance_id")):
			return _bad("CONNECTION_ID_INVALID")
		for flag in ["natural", "bidirectional", "interaction_required"]:
			if typeof(connection.get(flag)) != TYPE_BOOL or not connection[flag]:
				return _bad("CONNECTION_BEHAVIOR_INVALID")
		var ends: Variant = connection.get("endpoints")
		if not ends is Array or ends.size() != 2 or not ends[0] is Dictionary or not ends[1] is Dictionary or ends[0].size() != 2 or ends[1].size() != 2:
			return _bad("CONNECTION_ENDPOINTS_INVALID")
		if not Address.valid_layer(ends[0].get("layer")):
			return _bad("CONNECTION_LAYER_INVALID")
		var upper: int = int(ends[0]["layer"]["depth"])
		if upper not in [0, 1] or not _layer(ends[0]["layer"], expected_world_id, upper) or not _layer(ends[1].get("layer"), expected_world_id, upper + 1):
			return _bad("CONNECTION_LAYER_PAIR_FORBIDDEN")
		var a: Dictionary = _cell(ends[0].get("cell"), radius)
		var b: Dictionary = _cell(ends[1].get("cell"), radius)
		if not a["ok"] or not b["ok"] or a["cell"] != b["cell"]:
			return _bad("CONNECTION_COORDINATES_MISMATCH")
		var rule: Dictionary = _inputs.data["connections"][upper]
		if not Address.is_integer(connection.get("body_side_cells")) or int(connection["body_side_cells"]) != int(rule["body_side_cells"]) or not _integer_array(connection.get("safety_rect"), 4):
			return _bad("CONNECTION_FOOTPRINT_INVALID")
		var box: Rect2i = Generator._centered_rect(a["cell"], int(rule["safety_side_cells"]))
		var expected_rect: Array = [box.position.x, box.position.y, box.size.x, box.size.y]
		var normalized_rect: Array = []
		for number in connection["safety_rect"]:
			normalized_rect.append(int(number))
		if normalized_rect != expected_rect or not Generator._rectangle_in_disc(box, radius):
			return _bad("CONNECTION_SAFETY_INVALID")
		var body: Rect2i = Generator._centered_rect(a["cell"], int(rule["body_side_cells"]))
		for depth in [upper, upper + 1]:
			for other in bodies_by_depth[depth]:
				if body.intersects(other):
					return _bad("CONNECTION_BODY_OVERLAP")
			bodies_by_depth[depth].append(body)
		for endpoint in ends:
			endpoint["cell"] = Generator._array(a["cell"])
			endpoint["layer"]["depth"] = int(endpoint["layer"]["depth"])
		connection["body_side_cells"] = int(connection["body_side_cells"])
		connection["safety_rect"] = normalized_rect
		used_ids[connection["connection_instance_id"]] = true
		if upper == 0:
			var squared: int = _distance_squared(a["cell"], spawn["cell"])
			if squared < int(first_rule["spawn_min_distance"]) ** 2 or squared > int(first_rule["spawn_max_distance"]) ** 2:
				return _bad("SPAWN_ENTRY_DISTANCE_INVALID")
			first_cells.append(a["cell"])
		else:
			second_cells.append(a["cell"])
	if first_cells.size() != expected_first or second_cells.size() != expected_second:
		return _bad("CONNECTION_COUNTS_BY_LAYER_INVALID")
	for landing in first_cells:
		var near_count: int = 0
		for destination in second_cells:
			if _distance_squared(landing, destination) <= int(first_rule["continuation_radius"]) ** 2:
				near_count += 1
		if near_count < int(first_rule["continuation_min_count"]):
			return _bad("DEEPER_CONNECTION_GUARANTEE_MISSING")
	if not plan["retry_configuration"] is Dictionary or not Address.is_integer(plan["retry_configuration"].get("max_region_attempts")) or plan["retry_configuration"]["max_region_attempts"] < 1 or plan["retry_configuration"]["max_region_attempts"] > 128 or not plan["retry_counts"] is Dictionary:
		return _bad("RETRY_RECORD_INVALID")
	plan["retry_configuration"]["max_region_attempts"] = int(plan["retry_configuration"]["max_region_attempts"])
	for region in plan["retry_counts"]:
		var count: Variant = plan["retry_counts"][region]
		if not region is String or not Address.is_integer(count) or count < 1 or count > plan["retry_configuration"]["max_region_attempts"]:
			return _bad("RETRY_COUNT_OUT_OF_BOUNDS")
		plan["retry_counts"][region] = int(count)
	if not plan["generation_stages"] is Array or plan["generation_stages"].size() != Inputs.ORDER.size() or not plan["unresolved"] is Array or plan["unresolved"] != _inputs.data["unresolved"]:
		return _bad("STAGE_DEPENDENCY_RECORD_INVALID")
	for index in range(Inputs.ORDER.size()):
		var stage: Variant = plan["generation_stages"][index]
		if not stage is Dictionary or stage.size() != 2 or not stage.get("stage") is String or stage["stage"] != Inputs.ORDER[index] or not stage.get("status") is String or stage["status"] != Generator.stage_records()[index]["status"]:
			return _bad("GENERATION_STAGE_ORDER_INVALID")
	if not plan["permanent_changes"] is Dictionary:
		return _bad("PERMANENT_CHANGES_INVALID")
	for key in plan["permanent_changes"]:
		var change: Variant = plan["permanent_changes"][key]
		if not change is Dictionary or change.size() != 3 or not Address.is_integer(change.get("depth")) or int(change["depth"]) not in [1, 2] or typeof(change.get("cleared_default_rock")) != TYPE_BOOL or not change["cleared_default_rock"]:
			return _bad("UNSUPPORTED_PERMANENT_CHANGE")
		var position: Dictionary = _cell(change.get("cell"), radius)
		if not position["ok"] or key != "%d|%s" % [int(change["depth"]), Address.cell_key(position["cell"])]:
			return _bad("PERMANENT_CHANGE_IDENTITY_INVALID")
		change["depth"] = int(change["depth"])
		change["cell"] = Generator._array(position["cell"])
	if not plan["core_layout_fingerprint"] is String or plan["core_layout_fingerprint"] != Generator.core_fingerprint(plan):
		return _bad("CORE_LAYOUT_FINGERPRINT_MISMATCH")
	return {"ok": true, "plan": plan, "formal_world_allowed": false}

func formal_publication_report(plan: Variant, world_id: String) -> Dictionary:
	var checked: Dictionary = validate(plan, world_id)
	if not checked["ok"]:
		return checked
	return {"ok": false, "code": "FORMAL_WORLD_DEPENDENCIES_UNRESOLVED", "missing": ["required_template_geometry", "boss_and_civilization_integration", "traceable_necessary_material_minimum_proof"], "formal_world_allowed": false}

static func _layer(value: Variant, world_id: String, depth: int) -> bool:
	return Address.valid_layer(value) and value["world_id"] == world_id and value["body_instance_id"] == "body_0001" and int(value["depth"]) == depth and value["map_kind"] == ("surface" if depth == 0 else "underground")

static func _cell(value: Variant, radius: int) -> Dictionary:
	if not _integer_array(value, 2):
		return {"ok": false}
	if value[0] < -radius or value[1] < -radius or value[0] >= radius or value[1] >= radius:
		return {"ok": false}
	var cell := Vector2i(int(value[0]), int(value[1]))
	return {"ok": Generator._center_in_disc(cell, radius), "cell": cell}

static func _integer_array(value: Variant, length: int) -> bool:
	if not value is Array or value.size() != length:
		return false
	for item in value:
		if not Address.is_integer(item):
			return false
	return true

static func _distance_squared(a: Vector2i, b: Vector2i) -> int:
	var x: int = int(a.x) - int(b.x)
	var y: int = int(a.y) - int(b.y)
	return x * x + y * y

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "formal_world_allowed": false}
