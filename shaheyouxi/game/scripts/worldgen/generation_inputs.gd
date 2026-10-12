extends RefCounted
const Address = preload("res://scripts/world/spatial_address.gd")
const ORDER := ["natural_body_skeleton", "required_templates_and_protected_areas", "spawn_and_required_connections", "biomes", "base_terrain", "static_liquids", "underground_resources", "poi_and_civilization", "trees_and_animals", "integrity_validation"]
var ready: bool = false
var data: Dictionary = {}
var last_error: String = ""

func load_file(path: String = "res://data/generation_settings.json") -> bool:
	return load_document(JSON.parse_string(FileAccess.get_file_as_string(path)))

func load_document(document: Variant) -> bool:
	ready = false
	data = {}
	last_error = ""
	if not document is Dictionary or not Address.is_integer(document.get("schema_version")) or int(document["schema_version"]) != 1 or not document.get("project") is String or document["project"] != "shaheyouxi_experiment_20261004" or not document.get("artifact_kind") is String or document["artifact_kind"] != "derived_authoritative_generation_inputs":
		return _reject("GENERATION_INPUT_IDENTITY_INVALID")
	var approved: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/generation_authorities.json"))
	if not approved is Dictionary or not document.get("sources") is Dictionary:
		return _reject("GENERATION_SOURCE_MISSING")
	for name in ["shuzhi.xlsx", "sucai.xlsx", "cehua.docx"]:
		if not approved.get(name) is Dictionary or not approved[name].get("sha256") is String or not document["sources"].get(name) is String or document["sources"][name] != approved[name]["sha256"]:
			return _reject("GENERATION_SOURCE_MISMATCH")
	# Bind every projected value to the builder-reviewed source result, without a
	# second hard-coded table of radii, Biome counts or resource-rank mappings.
	var trusted_text: String = FileAccess.get_file_as_string("res://data/generation_settings.json")
	if not approved.get("_projection_sha256") is String or trusted_text.sha256_text() != approved["_projection_sha256"]:
		return _reject("APPROVED_PROJECTION_BYTES_MISMATCH")
	var trusted: Variant = JSON.parse_string(trusted_text)
	if not trusted is Dictionary or document != trusted:
		return _reject("DERIVED_CONTRACT_CHANGED_REBUILD_FROM_FORMAL_SOURCE")
	if document.get("generation_order") != ORDER or document.get("formal_world_ready") != false or typeof(document.get("formal_world_ready")) != TYPE_BOOL:
		return _reject("STAGE_ORDER_OR_PREVIEW_BOUNDARY_CHANGED")
	var body: Variant = document.get("body")
	if not body is Dictionary or body.get("body_id") != "xingxing_03" or body.get("required_instance_id") != "body_0001" or body.get("starting_biome_id") != "x03_db_wendai_linyuan":
		return _reject("STARTING_BODY_REFERENCE_INVALID")
	for key in ["radius_cells", "diameter_cells", "spawn_center_radius_cells"]:
		if not Address.is_integer(body.get(key)) or body[key] <= 0:
			return _reject("BODY_SIZE_INVALID")
	if body["diameter_cells"] != body["radius_cells"] * 2 or body["spawn_center_radius_cells"] > body["radius_cells"]:
		return _reject("BODY_SIZE_RELATION_INVALID")
	var catalogue := SandboxContentCatalogue.new()
	if catalogue.load_file() != OK:
		return _reject("CANONICAL_CONTENT_REGISTRY_UNAVAILABLE")
	var ranks: Variant = document.get("material_by_rank")
	if not ranks is Dictionary or ranks.size() != 4:
		return _reject("MATERIAL_RANK_REFERENCES_MISSING")
	var expected_materials: Dictionary = {"ordinary_rock": true}
	for rank in ["1", "2", "3", "4"]:
		if not ranks.get(rank) is Dictionary or not ranks[rank].get("resource_id") is String or catalogue.get_content(ranks[rank]["resource_id"]).is_empty():
			return _reject("MATERIAL_REFERENCE_INVALID")
		expected_materials[ranks[rank]["resource_id"]] = true
	var biomes: Variant = document.get("biomes")
	if not biomes is Dictionary or not biomes.has(body["starting_biome_id"]):
		return _reject("BIOMES_MISSING")
	var layer_counts := {0: 0, 1: 0, 2: 0}
	for id in biomes:
		var row: Variant = biomes[id]
		if not id is String or not row is Dictionary or row.get("biome_id") != id or not _layer(row) or not row.get("ground_resource_id") is String or row["ground_resource_id"].is_empty():
			return _reject("BIOME_REFERENCE_INVALID")
		layer_counts[int(row["depth"])] += 1
		if row["depth"] > 0:
			if not row.get("default_rock_id") is String or not row.get("material_weights") is Dictionary:
				return _reject("UNDERGROUND_INTERFACE_MISSING")
			if catalogue.get_content(row["default_rock_id"]).is_empty() or row["material_weights"].size() != expected_materials.size():
				return _reject("UNDERGROUND_CONTENT_REFERENCE_INVALID")
			for resource_id in row["material_weights"]:
				if not expected_materials.has(resource_id):
					return _reject("UNKNOWN_WEIGHTED_RESOURCE")
			var total: int = 0
			for weight in row["material_weights"].values():
				if not Address.is_integer(weight) or weight < 0:
					return _reject("MATERIAL_WEIGHT_INVALID")
				total += int(weight)
			if total != 100:
				return _reject("MATERIAL_WEIGHT_SUM_INVALID")
	for count in layer_counts.values():
		if count < 1:
			return _reject("BODY_LAYER_HAS_NO_BIOME")
	var connections: Variant = document.get("connections")
	if not connections is Array or connections.size() != 2:
		return _reject("CONNECTION_CONTRACT_MISSING")
	for index in range(2):
		var rule: Variant = connections[index]
		if not rule is Dictionary or not _layer(rule.get("upper")) or not _layer(rule.get("lower")) or rule["upper"]["depth"] != index or rule["lower"]["depth"] != index + 1:
			return _reject("CONNECTION_LAYER_PAIR_INVALID")
		if rule.get("natural_allowed") != true or typeof(rule.get("natural_allowed")) != TYPE_BOOL:
			return _reject("STARTING_CONNECTION_NOT_ALLOWED")
		for field in ["body_side_cells", "safety_side_cells"]:
			if not Address.is_integer(rule.get(field)) or rule[field] < 1 or int(rule[field]) % 2 != 1:
				return _reject("ENTRY_ODD_FOOTPRINT_UNSUPPORTED")
		if rule["safety_side_cells"] < rule["body_side_cells"]:
			return _reject("ENTRY_SAFETY_SMALLER_THAN_BODY")
	var first: Dictionary = connections[0]
	for field in ["spawn_min_distance", "spawn_max_distance", "spawn_min_count", "continuation_radius", "continuation_min_count"]:
		if not Address.is_integer(first.get(field)) or first[field] < 1:
			return _reject("CONNECTION_GUARANTEE_INVALID")
	if first["spawn_min_distance"] > first["spawn_max_distance"]:
		return _reject("CONNECTION_DISTANCE_REVERSED")
	var pois: Variant = document.get("poi_interfaces")
	if not pois is Array:
		return _reject("POI_INTERFACES_MISSING")
	var required: Dictionary = {}
	for poi in pois:
		if not poi is Dictionary or not poi.get("template_id") is String or not poi.get("applicable_layers") is Array:
			return _reject("POI_INTERFACE_INVALID")
		for identity in poi["applicable_layers"]:
			if not _layer(identity):
				return _reject("POI_LAYER_INVALID")
		if poi.get("required") == true:
			if not Address.is_integer(poi.get("fixed_count")) or poi["fixed_count"] < 1 or required.has(poi["template_id"]):
				return _reject("REQUIRED_POI_COUNT_INVALID")
			required[poi["template_id"]] = true
	for id in ["poi_x03_chusheng_anquan", "poi_x03_shenceng_hexin"]:
		if not required.has(id):
			return _reject("REQUIRED_POI_REFERENCE_MISSING")
	if not document.get("required_boss") is Dictionary or document["required_boss"].get("content_id") != "boss_dimai_guanshou":
		return _reject("REQUIRED_BOSS_REFERENCE_MISSING")
	data = document.duplicate(true)
	ready = true
	return true

static func _layer(value: Variant) -> bool:
	if not value is Dictionary or not Address.is_integer(value.get("depth")):
		return false
	var depth: int = int(value["depth"])
	return (value.get("map_kind") == "surface" and depth == 0) or (value.get("map_kind") == "underground" and depth in [1, 2])

func _reject(code: String) -> bool:
	last_error = code
	return false
