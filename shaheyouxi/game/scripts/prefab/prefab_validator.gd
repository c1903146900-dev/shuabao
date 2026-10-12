extends RefCounted
## 008 technical-only, JSON-safe Prefab schema. Geometry is explicit fixture data,
## never inferred from a source table's human-readable size or population text.
const Address = preload("res://scripts/world/spatial_address.gd")
const GenerationInputs = preload("res://scripts/worldgen/generation_inputs.gd")
const TEMPLATE_KIND := "technical_prefab_template"
const INSTANCE_KIND := "technical_prefab_instance"
const FORMAT_VERSION := 1
const TEMPLATE_FIELDS := ["schema_version", "artifact_kind", "template_id", "revision", "sources", "body_content_id", "geometry_kind", "formal_world_allowed", "layers", "objects", "anchors", "connections", "protected_areas"]
const INSTANCE_FIELDS := ["schema_version", "artifact_kind", "template_id", "template_revision", "template_sha256", "source_template", "world_id", "body_instance_id", "body_content_id", "prefab_instance_id", "origin", "sources", "formal_world_allowed", "layers", "objects", "anchors", "connections", "protected_areas"]
const LAYER_FIELDS := ["local_id", "map_kind", "depth", "bounds"]
const OBJECT_FIELDS := ["local_id", "content_id", "content_scope", "content_namespace", "layer_id", "plane", "rect", "blocking", "is_liquid"]
const ANCHOR_FIELDS := ["local_id", "kind", "layer_id", "cell", "object_local_id"]
const CONNECTION_FIELDS := ["local_id", "upper_anchor_id", "lower_anchor_id", "mode", "body_side_cells", "safety_side_cells"]
const PROTECTED_FIELDS := ["local_id", "layer_id", "rect", "reason"]
# Operational limits for this small technical format, not authoritative balance.
const MAX_OBJECTS := 256
const MAX_ANCHORS := 256
const MAX_CONNECTIONS := 128
const MAX_PROTECTED := 128
const MAX_COORDINATE := 4096
const MAX_SIDE := 512
const FIXTURE_DEFINITIONS := {
	"fixture_ground": {"kind": "ground", "plane": "H0", "blocking": false, "is_liquid": false},
	"fixture_floor": {"kind": "overlay", "plane": "H0_OVERLAY", "blocking": false, "is_liquid": false},
	"fixture_decal": {"kind": "decal", "plane": "H0_DECAL", "blocking": false, "is_liquid": false},
	"fixture_wall": {"kind": "wall", "plane": "H1", "blocking": true, "is_liquid": false},
	"fixture_liquid": {"kind": "liquid", "plane": "H0_OVERLAY", "blocking": false, "is_liquid": true},
	"fixture_container": {"kind": "container", "plane": "H1", "blocking": true, "is_liquid": false},
	"fixture_boss": {"kind": "boss", "plane": "H1", "blocking": true, "is_liquid": false}
}
var ready: bool = false
var last_error: String = ""
var _generation: RefCounted
var _prefab: Dictionary = {}

func _init(generation_document: Dictionary, prefab_document: Dictionary) -> void:
	_generation = GenerationInputs.new()
	if not _generation.load_document(generation_document):
		last_error = _generation.last_error
		return
	ready = _load_prefab_inputs(prefab_document)

func _load_prefab_inputs(document: Dictionary) -> bool:
	var approved: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/prefab_authorities.json"))
	var generation_approved: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/generation_authorities.json"))
	var trusted_text: String = FileAccess.get_file_as_string("res://data/prefab_settings.json")
	if not approved is Dictionary or not approved.get("_projection_sha256") is String or trusted_text.sha256_text() != approved["_projection_sha256"]:
		return _input_error("PREFAB_APPROVED_PROJECTION_BYTES_MISMATCH")
	var trusted: Variant = JSON.parse_string(trusted_text)
	if not trusted is Dictionary or document != trusted:
		return _input_error("PREFAB_DERIVED_CONTRACT_CHANGED")
	if not _fields(document, ["schema_version", "project", "artifact_kind", "sources", "generation_projection_sha256", "object_definitions", "template_interfaces", "formal_world_allowed"]) or not _version(document["schema_version"]) or document["project"] != "shaheyouxi_experiment_20261004" or document["artifact_kind"] != "derived_authoritative_prefab_inputs" or not _false_flag(document["formal_world_allowed"]):
		return _input_error("PREFAB_INPUT_IDENTITY_INVALID")
	if not generation_approved is Dictionary or not generation_approved.get("_projection_sha256") is String or document["generation_projection_sha256"] != generation_approved["_projection_sha256"] or document["sources"] != _generation.data["sources"]:
		return _input_error("PREFAB_GENERATION_SOURCE_MISMATCH")
	for name in _generation.data["sources"]:
		if not approved.get(name) is Dictionary or approved[name].get("sha256") != _generation.data["sources"][name]:
			return _input_error("PREFAB_SOURCE_MISMATCH")
	if not document["object_definitions"] is Dictionary or not document["template_interfaces"] is Dictionary:
		return _input_error("PREFAB_CONTENT_INTERFACES_INVALID")
	for content_id in document["object_definitions"]:
		var definition: Variant = document["object_definitions"][content_id]
		if not _token(content_id) or not definition is Dictionary or definition.get("content_id") != content_id or not definition.get("kind") is String or not definition.get("namespace") is String or typeof(definition.get("is_liquid")) != TYPE_BOOL:
			return _input_error("PREFAB_CONTENT_DEFINITION_INVALID")
	_prefab = document.duplicate(true)
	return true

func validate_template(value: Variant) -> Dictionary:
	if not ready:
		return _bad("PREFAB_INPUTS_NOT_READY")
	if not _fields(value, TEMPLATE_FIELDS) or not _json_value(value):
		return _bad("PREFAB_TEMPLATE_FIELDS_INVALID")
	if not _version(value["schema_version"]) or value["artifact_kind"] != TEMPLATE_KIND or not _positive_integer(value["revision"]):
		return _bad("PREFAB_TEMPLATE_VERSION_INVALID")
	if not _false_flag(value["formal_world_allowed"]) or value["geometry_kind"] != "explicit_technical_fixture" or value["sources"] != _generation.data["sources"] or value["body_content_id"] != _generation.data["body"]["body_id"]:
		return _bad("PREFAB_TEMPLATE_SOURCE_OR_BOUNDARY_INVALID")
	if not _token(value["template_id"]) or not (_prefab["template_interfaces"].has(value["template_id"]) or (value["template_id"].begins_with("fixture_") and value["template_id"].length() > 8)):
		return _bad("PREFAB_TEMPLATE_ID_UNKNOWN")
	if not _bounded_array(value["layers"], 1, 8) or not _bounded_array(value["objects"], 0, MAX_OBJECTS) or not _bounded_array(value["anchors"], 0, MAX_ANCHORS) or not _bounded_array(value["connections"], 0, MAX_CONNECTIONS) or not _bounded_array(value["protected_areas"], 0, MAX_PROTECTED):
		return _bad("PREFAB_ARRAY_OR_OPERATIONAL_LIMIT_INVALID")
	var template: Dictionary = value.duplicate(true)
	template["schema_version"] = FORMAT_VERSION
	template["revision"] = int(template["revision"])
	var ids: Dictionary = {}
	var layers: Dictionary = {}
	var layer_identities: Dictionary = {}
	for row in template["layers"]:
		if not _fields(row, LAYER_FIELDS) or not _claim_id(row["local_id"], ids) or not _allowed_layer(row) or not _rect(row["bounds"]):
			return _bad("PREFAB_LAYER_INVALID_OR_DUPLICATE")
		if not _template_permits_layer(template["template_id"], row):
			return _bad("PREFAB_TEMPLATE_LAYER_FORBIDDEN")
		row["depth"] = int(row["depth"])
		row["bounds"] = _integers(row["bounds"])
		var identity: String = "%s|%d" % [row["map_kind"], row["depth"]]
		if layer_identities.has(identity):
			return _bad("PREFAB_DUPLICATE_LAYER_IDENTITY")
		layer_identities[identity] = true
		layers[row["local_id"]] = row
	var objects: Dictionary = {}
	for row in template["objects"]:
		if not _fields(row, OBJECT_FIELDS) or not _claim_id(row["local_id"], ids) or not layers.has(row["layer_id"]) or not _rect(row["rect"]) or not _rect_contains(layers[row["layer_id"]]["bounds"], row["rect"]):
			return _bad("PREFAB_OBJECT_GEOMETRY_OR_ID_INVALID")
		var definition: Dictionary = _object_definition(row)
		if definition.is_empty():
			return _bad("PREFAB_OBJECT_CONTENT_OR_SEMANTICS_INVALID")
		if not _template_permits_object(template["template_id"], row, definition):
			return _bad("PREFAB_TEMPLATE_OBJECT_FORBIDDEN")
		row["rect"] = _integers(row["rect"])
		for other in objects.values():
			if row["layer_id"] == other["layer_id"] and row["plane"] == other["plane"] and row["plane"] != "H0_DECAL" and _intersects(row["rect"], other["rect"]):
				return _bad("PREFAB_OBJECT_OCCUPANCY_CONFLICT")
		objects[row["local_id"]] = row
	var anchors: Dictionary = {}
	var linked_objects: Dictionary = {}
	for row in template["anchors"]:
		if not _fields(row, ANCHOR_FIELDS) or not _claim_id(row["local_id"], ids) or not layers.has(row["layer_id"]) or not _cell(row["cell"]) or not _contains(layers[row["layer_id"]]["bounds"], row["cell"]) or row["kind"] not in ["entrance", "spawn", "container", "boss"] or not row["object_local_id"] is String:
			return _bad("PREFAB_ANCHOR_INVALID")
		row["cell"] = _integers(row["cell"])
		if row["kind"] in ["container", "boss"]:
			if not objects.has(row["object_local_id"]) or linked_objects.has(row["object_local_id"]):
				return _bad("PREFAB_ANCHOR_DANGLING_OR_DUPLICATE_TARGET")
			var target: Dictionary = objects[row["object_local_id"]]
			var kind: String = _object_definition(target)["kind"]
			if target["layer_id"] != row["layer_id"] or target["plane"] != "H1" or not _contains(target["rect"], row["cell"]) or (row["kind"] == "boss" and kind != "boss") or (row["kind"] == "container" and kind not in ["container", "breakable_container"]):
				return _bad("PREFAB_ANCHOR_TARGET_MISMATCH")
			linked_objects[row["object_local_id"]] = true
		else:
			if row["object_local_id"] != "":
				return _bad("PREFAB_ANCHOR_UNEXPECTED_TARGET")
			if _hazard_intersects(objects, row["layer_id"], [row["cell"][0], row["cell"][1], 1, 1]):
				return _bad("PREFAB_TRAVEL_ANCHOR_BLOCKED")
		anchors[row["local_id"]] = row
	# A semantic boss/container cannot enter this format without its named anchor.
	for row in objects.values():
		if _object_definition(row)["kind"] in ["boss", "container", "breakable_container"] and not linked_objects.has(row["local_id"]):
			return _bad("PREFAB_REQUIRED_OBJECT_ANCHOR_MISSING")
	var used_entrances: Dictionary = {}
	var entry_bodies: Dictionary = {}
	for row in template["connections"]:
		if not _fields(row, CONNECTION_FIELDS) or not _claim_id(row["local_id"], ids) or not anchors.has(row["upper_anchor_id"]) or not anchors.has(row["lower_anchor_id"]):
			return _bad("PREFAB_CONNECTION_INVALID_OR_DANGLING")
		var upper: Dictionary = anchors[row["upper_anchor_id"]]
		var lower: Dictionary = anchors[row["lower_anchor_id"]]
		if upper["kind"] != "entrance" or lower["kind"] != "entrance" or used_entrances.has(upper["local_id"]) or used_entrances.has(lower["local_id"]) or upper["local_id"] == lower["local_id"]:
			return _bad("PREFAB_CONNECTION_ENDPOINT_INVALID_OR_REUSED")
		if upper["cell"] != lower["cell"]:
			return _bad("PREFAB_CONNECTION_XY_MISMATCH")
		var rule: Dictionary = _connection_rule(layers[upper["layer_id"]], layers[lower["layer_id"]])
		if rule.is_empty() or row["mode"] != "natural" or rule["natural_allowed"] != true:
			return _bad("PREFAB_CONNECTION_LAYER_OR_MODE_FORBIDDEN")
		if not Address.is_integer(row["body_side_cells"]) or not Address.is_integer(row["safety_side_cells"]) or row["body_side_cells"] != rule["body_side_cells"] or row["safety_side_cells"] != rule["safety_side_cells"]:
			return _bad("PREFAB_CONNECTION_FOOTPRINT_CONTRACT_CHANGED")
		row["body_side_cells"] = int(row["body_side_cells"])
		row["safety_side_cells"] = int(row["safety_side_cells"])
		var body: Array = centered_rect(upper["cell"], row["body_side_cells"])
		var safety: Array = centered_rect(upper["cell"], row["safety_side_cells"])
		for endpoint in [upper, lower]:
			var layer_id: String = endpoint["layer_id"]
			if not _rect_contains(layers[layer_id]["bounds"], safety):
				return _bad("PREFAB_CONNECTION_SAFETY_OUT_OF_BOUNDS")
			if _hazard_intersects(objects, layer_id, safety):
				return _bad("PREFAB_CONNECTION_SAFETY_BLOCKED")
			if not entry_bodies.has(layer_id):
				entry_bodies[layer_id] = []
			for previous in entry_bodies[layer_id]:
				if _intersects(body, previous):
					return _bad("PREFAB_CONNECTION_BODY_OVERLAP")
			entry_bodies[layer_id].append(body)
			used_entrances[endpoint["local_id"]] = true
	for row in anchors.values():
		if row["kind"] == "entrance" and not used_entrances.has(row["local_id"]):
			return _bad("PREFAB_UNPAIRED_ENTRANCE")
	for row in template["protected_areas"]:
		if not _fields(row, PROTECTED_FIELDS) or not _claim_id(row["local_id"], ids) or not layers.has(row["layer_id"]) or not _rect(row["rect"]) or not _rect_contains(layers[row["layer_id"]]["bounds"], row["rect"]) or not row["reason"] is String or row["reason"].strip_edges().is_empty() or row["reason"].length() > 256:
			return _bad("PREFAB_PROTECTED_AREA_INVALID")
		row["rect"] = _integers(row["rect"])
	# Canonical ordering also makes ID/fingerprint invariant to editor array order.
	for key in ["layers", "objects", "anchors", "connections", "protected_areas"]:
		template[key].sort_custom(_by_local_id)
	return {"ok": true, "template": template, "formal_world_allowed": false}

func _object_definition(row: Dictionary) -> Dictionary:
	if not _token(row["content_id"]) or row["plane"] not in Address.PLANES or typeof(row["blocking"]) != TYPE_BOOL or typeof(row["is_liquid"]) != TYPE_BOOL:
		return {}
	var definition: Dictionary
	if row["content_scope"] == "technical_fixture":
		if row["content_namespace"] != "technical_fixture" or not FIXTURE_DEFINITIONS.has(row["content_id"]):
			return {}
		definition = FIXTURE_DEFINITIONS[row["content_id"]]
		if row["plane"] != definition["plane"] or row["blocking"] != definition["blocking"] or row["is_liquid"] != definition["is_liquid"]:
			return {}
	elif row["content_scope"] == "authoritative":
		if not _prefab["object_definitions"].has(row["content_id"]):
			return {}
		definition = _prefab["object_definitions"][row["content_id"]]
		if row["content_namespace"] != definition["namespace"] or row["is_liquid"] != definition["is_liquid"]:
			return {}
		if definition["kind"] == "ground":
			if row["plane"] != "H0" or row["blocking"]:
				return {}
		elif definition["kind"] in ["rock", "resource", "tree", "boss", "container", "breakable_container"]:
			if row["plane"] != "H1":
				return {}
		else:
			return {}
	else:
		return {}
	if row["plane"] != "H1" and row["blocking"]:
		return {}
	if row["plane"] == "H0_DECAL" and row["is_liquid"]:
		return {}
	return definition

func _allowed_layer(row: Dictionary) -> bool:
	if not Address.is_integer(row["depth"]) or not row["map_kind"] is String:
		return false
	for biome in _generation.data["biomes"].values():
		if biome["map_kind"] == row["map_kind"] and biome["depth"] == row["depth"]:
			return true
	return false

func _template_permits_layer(template_id: String, row: Dictionary) -> bool:
	if template_id.begins_with("fixture_"):
		return true
	for poi in _generation.data["poi_interfaces"]:
		if poi["template_id"] == template_id:
			for identity in poi["applicable_layers"]:
				if identity["map_kind"] == row["map_kind"] and identity["depth"] == row["depth"]:
					return true
	return false

func _template_permits_object(template_id: String, row: Dictionary, definition: Dictionary) -> bool:
	if template_id.begins_with("fixture_"):
		return true
	var contract: Dictionary = _prefab["template_interfaces"][template_id]
	if definition["kind"] in ["container", "breakable_container"]:
		if contract["container_content_id"] == null or row["content_scope"] != "authoritative" or row["content_id"] != contract["container_content_id"]:
			return false
	if template_id == "poi_x03_chusheng_anquan" and definition["kind"] == "boss":
		return false
	if definition["kind"] == "boss" and row["content_scope"] == "authoritative":
		# The approved named core POI owns this Boss interface. Do not infer a
		# different home from a future deepest layer or a human-readable label.
		if template_id != "poi_x03_shenceng_hexin" or row["content_id"] != _generation.data["required_boss"]["content_id"]:
			return false
	return true

func _connection_rule(upper: Dictionary, lower: Dictionary) -> Dictionary:
	for rule in _generation.data["connections"]:
		if rule["upper"]["map_kind"] == upper["map_kind"] and rule["upper"]["depth"] == upper["depth"] and rule["lower"]["map_kind"] == lower["map_kind"] and rule["lower"]["depth"] == lower["depth"]:
			return rule
	return {}

static func _fields(value: Variant, names: Array) -> bool:
	if not value is Dictionary or value.size() != names.size():
		return false
	for name in names:
		if not value.has(name):
			return false
	return true

static func _version(value: Variant) -> bool:
	return Address.is_integer(value) and int(value) == FORMAT_VERSION

static func _positive_integer(value: Variant) -> bool:
	return Address.is_integer(value) and value > 0

static func _false_flag(value: Variant) -> bool:
	return typeof(value) == TYPE_BOOL and value == false

static func _bounded_array(value: Variant, minimum: int, maximum: int) -> bool:
	return value is Array and value.size() >= minimum and value.size() <= maximum

static func _token(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 80:
		return false
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return true

static func _claim_id(value: Variant, used: Dictionary) -> bool:
	if not _token(value) or used.has(value):
		return false
	used[value] = true
	return true

static func _cell(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	return Address.is_integer(value[0]) and Address.is_integer(value[1]) and abs(value[0]) <= MAX_COORDINATE and abs(value[1]) <= MAX_COORDINATE

static func _rect(value: Variant) -> bool:
	if not value is Array or value.size() != 4:
		return false
	for element in value:
		if not Address.is_integer(element):
			return false
	return abs(value[0]) <= MAX_COORDINATE and abs(value[1]) <= MAX_COORDINATE and value[2] >= 1 and value[3] >= 1 and value[2] <= MAX_SIDE and value[3] <= MAX_SIDE and abs(value[0] + value[2]) <= MAX_COORDINATE and abs(value[1] + value[3]) <= MAX_COORDINATE

static func _integers(value: Array) -> Array:
	var result: Array = []
	for item in value:
		result.append(int(item))
	return result

static func _contains(rect: Array, cell: Array) -> bool:
	return cell[0] >= rect[0] and cell[1] >= rect[1] and cell[0] < rect[0] + rect[2] and cell[1] < rect[1] + rect[3]

static func _rect_contains(outer: Array, inner: Array) -> bool:
	return inner[0] >= outer[0] and inner[1] >= outer[1] and inner[0] + inner[2] <= outer[0] + outer[2] and inner[1] + inner[3] <= outer[1] + outer[3]

static func _intersects(a: Array, b: Array) -> bool:
	return a[0] < b[0] + b[2] and a[0] + a[2] > b[0] and a[1] < b[1] + b[3] and a[1] + a[3] > b[1]

static func _hazard_intersects(objects: Dictionary, layer_id: String, rect: Array) -> bool:
	for row in objects.values():
		if row["layer_id"] == layer_id and (row["plane"] == "H1" or row["is_liquid"]) and _intersects(row["rect"], rect):
			return true
	return false

static func centered_rect(cell: Array, side: int) -> Array:
	var half: int = (side - 1) >> 1
	return [int(cell[0]) - half, int(cell[1]) - half, side, side]

static func _by_local_id(a: Dictionary, b: Dictionary) -> bool:
	return a["local_id"] < b["local_id"]

func _input_error(code: String) -> bool:
	last_error = code
	return false

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "formal_world_allowed": false}

func validate_instance(value: Variant, expected_world_id: String) -> Dictionary:
	# Deliberately no Instantiator dependency or call: validate saved rows in place.
	if not ready or not _fields(value, INSTANCE_FIELDS) or not _json_value(value):
		return _bad("PREFAB_INSTANCE_FIELDS_INVALID")
	if not _version(value["schema_version"]) or value["artifact_kind"] != INSTANCE_KIND or not _false_flag(value["formal_world_allowed"]):
		return _bad("PREFAB_INSTANCE_VERSION_OR_BOUNDARY_INVALID")
	if not SandboxServerAuthority._valid_id(expected_world_id, "world_") or value["world_id"] != expected_world_id or not Address.is_body_instance_id(value["body_instance_id"]) or not valid_prefab_instance_id(value["prefab_instance_id"]) or not _cell(value["origin"]):
		return _bad("PREFAB_INSTANCE_IDENTITY_INVALID")
	var checked: Dictionary = validate_template(value["source_template"])
	if not checked["ok"]:
		return checked
	var template: Dictionary = checked["template"]
	if value["template_id"] != template["template_id"] or not Address.is_integer(value["template_revision"]) or value["template_revision"] != template["revision"] or value["template_sha256"] != template_digest(template) or value["body_content_id"] != template["body_content_id"] or value["sources"] != template["sources"]:
		return _bad("PREFAB_INSTANCE_TEMPLATE_BINDING_INVALID")
	var instance: Dictionary = value.duplicate(true)
	instance["schema_version"] = FORMAT_VERSION
	instance["template_revision"] = int(instance["template_revision"])
	instance["origin"] = _integers(instance["origin"])
	instance["source_template"] = template
	var origin: Array = instance["origin"]
	var layers: Dictionary = {}
	var objects: Dictionary = {}
	var anchors: Dictionary = {}
	var runtime_ids: Dictionary = {instance["prefab_instance_id"]: true}
	for group in ["layers", "objects", "anchors", "connections", "protected_areas"]:
		if not instance[group] is Array or instance[group].size() != template[group].size():
			return _bad("PREFAB_INSTANCE_RECORD_SET_INVALID")
	# Every numeric Array comparison below follows _rect/_cell validation and
	# compares normalized integers; float coercion must not admit bad JSON types.
	var actual_layers: Dictionary = _record_map(instance["layers"], LAYER_FIELDS + ["address"])
	if not actual_layers["ok"]:
		return actual_layers
	for source in template["layers"]:
		if not actual_layers["records"].has(source["local_id"]):
			return _bad("PREFAB_INSTANCE_LOCAL_ID_MISSING")
		var row: Dictionary = actual_layers["records"][source["local_id"]]
		var expected_address: Dictionary = Address.layer(expected_world_id, instance["body_instance_id"], source["map_kind"], int(source["depth"]))
		if not _instance_layer_matches(row["address"], expected_address) or row["map_kind"] != source["map_kind"] or not Address.is_integer(row["depth"]) or row["depth"] != source["depth"] or not _rect(row["bounds"]) or _integers(row["bounds"]) != translated_rect(source["bounds"], origin):
			return _bad("PREFAB_INSTANCE_LAYER_TRANSFORM_INVALID")
		if not _rect_in_body(row["bounds"]):
			return _bad("PREFAB_INSTANCE_OUTSIDE_BODY")
		row["depth"] = int(row["depth"])
		row["bounds"] = _integers(row["bounds"])
		row["address"]["depth"] = int(row["address"]["depth"])
		layers[row["local_id"]] = row["address"]
	var actual_objects: Dictionary = _record_map(instance["objects"], OBJECT_FIELDS + ["instance_id", "layer"])
	if not actual_objects["ok"]:
		return actual_objects
	for source in template["objects"]:
		if not actual_objects["records"].has(source["local_id"]):
			return _bad("PREFAB_INSTANCE_LOCAL_ID_MISSING")
		var row: Dictionary = actual_objects["records"][source["local_id"]]
		var expected_id: String = runtime_id("entity", expected_world_id, instance["body_instance_id"], instance["prefab_instance_id"], source["local_id"])
		if not _runtime_identity(row["instance_id"], expected_id, runtime_ids) or not _instance_layer_matches(row["layer"], layers[source["layer_id"]]):
			return _bad("PREFAB_INSTANCE_OBJECT_ID_OR_LAYER_INVALID")
		for field in ["content_id", "content_scope", "content_namespace", "layer_id", "plane"]:
			if row[field] != source[field]:
				return _bad("PREFAB_INSTANCE_OBJECT_CONTENT_CHANGED")
		if typeof(row["blocking"]) != TYPE_BOOL or typeof(row["is_liquid"]) != TYPE_BOOL or row["blocking"] != source["blocking"] or row["is_liquid"] != source["is_liquid"] or not _rect(row["rect"]) or _integers(row["rect"]) != translated_rect(source["rect"], origin):
			return _bad("PREFAB_INSTANCE_OBJECT_GEOMETRY_CHANGED")
		row["rect"] = _integers(row["rect"])
		row["layer"]["depth"] = int(row["layer"]["depth"])
		objects[row["local_id"]] = row["instance_id"]
	var actual_anchors: Dictionary = _record_map(instance["anchors"], ANCHOR_FIELDS + ["instance_id", "object_instance_id", "layer"])
	if not actual_anchors["ok"]:
		return actual_anchors
	for source in template["anchors"]:
		if not actual_anchors["records"].has(source["local_id"]):
			return _bad("PREFAB_INSTANCE_LOCAL_ID_MISSING")
		var row: Dictionary = actual_anchors["records"][source["local_id"]]
		var expected_id: String = runtime_id("anchor", expected_world_id, instance["body_instance_id"], instance["prefab_instance_id"], source["local_id"])
		var expected_object: String = "" if source["object_local_id"] == "" else objects[source["object_local_id"]]
		if not _runtime_identity(row["instance_id"], expected_id, runtime_ids) or not _instance_layer_matches(row["layer"], layers[source["layer_id"]]) or row["object_instance_id"] != expected_object:
			return _bad("PREFAB_INSTANCE_ANCHOR_BINDING_INVALID")
		for field in ["kind", "layer_id", "object_local_id"]:
			if row[field] != source[field]:
				return _bad("PREFAB_INSTANCE_ANCHOR_CONTENT_CHANGED")
		if not _cell(row["cell"]) or _integers(row["cell"]) != translated_cell(source["cell"], origin):
			return _bad("PREFAB_INSTANCE_ANCHOR_TRANSFORM_INVALID")
		row["cell"] = _integers(row["cell"])
		row["layer"]["depth"] = int(row["layer"]["depth"])
		anchors[row["local_id"]] = row
	var actual_connections: Dictionary = _record_map(instance["connections"], CONNECTION_FIELDS + ["instance_id", "upper_anchor_instance_id", "lower_anchor_instance_id", "body_rect", "safety_rect"])
	if not actual_connections["ok"]:
		return actual_connections
	for source in template["connections"]:
		if not actual_connections["records"].has(source["local_id"]):
			return _bad("PREFAB_INSTANCE_LOCAL_ID_MISSING")
		var row: Dictionary = actual_connections["records"][source["local_id"]]
		var expected_id: String = runtime_id("connection", expected_world_id, instance["body_instance_id"], instance["prefab_instance_id"], source["local_id"])
		if not _runtime_identity(row["instance_id"], expected_id, runtime_ids) or row["upper_anchor_instance_id"] != anchors[source["upper_anchor_id"]]["instance_id"] or row["lower_anchor_instance_id"] != anchors[source["lower_anchor_id"]]["instance_id"]:
			return _bad("PREFAB_INSTANCE_CONNECTION_BINDING_INVALID")
		for field in ["upper_anchor_id", "lower_anchor_id", "mode"]:
			if row[field] != source[field]:
				return _bad("PREFAB_INSTANCE_CONNECTION_CONTENT_CHANGED")
		for field in ["body_side_cells", "safety_side_cells"]:
			if not Address.is_integer(row[field]) or row[field] != source[field]:
				return _bad("PREFAB_INSTANCE_CONNECTION_FOOTPRINT_CHANGED")
			row[field] = int(row[field])
		var cell: Array = anchors[source["upper_anchor_id"]]["cell"]
		if not _rect(row["body_rect"]) or not _rect(row["safety_rect"]) or _integers(row["body_rect"]) != centered_rect(cell, int(source["body_side_cells"])) or _integers(row["safety_rect"]) != centered_rect(cell, int(source["safety_side_cells"])):
			return _bad("PREFAB_INSTANCE_CONNECTION_GEOMETRY_CHANGED")
		row["body_rect"] = _integers(row["body_rect"])
		row["safety_rect"] = _integers(row["safety_rect"])
	var actual_protected: Dictionary = _record_map(instance["protected_areas"], PROTECTED_FIELDS + ["layer"])
	if not actual_protected["ok"]:
		return actual_protected
	for source in template["protected_areas"]:
		if not actual_protected["records"].has(source["local_id"]):
			return _bad("PREFAB_INSTANCE_LOCAL_ID_MISSING")
		var row: Dictionary = actual_protected["records"][source["local_id"]]
		if row["layer_id"] != source["layer_id"] or row["reason"] != source["reason"] or not _instance_layer_matches(row["layer"], layers[source["layer_id"]]) or not _rect(row["rect"]) or _integers(row["rect"]) != translated_rect(source["rect"], origin):
			return _bad("PREFAB_INSTANCE_PROTECTED_AREA_CHANGED")
		row["rect"] = _integers(row["rect"])
		row["layer"]["depth"] = int(row["layer"]["depth"])
	for group in ["layers", "objects", "anchors", "connections", "protected_areas"]:
		instance[group].sort_custom(_by_local_id)
	return {"ok": true, "instance": instance, "formal_world_allowed": false}

func _rect_in_body(rect: Array) -> bool:
	var radius: float = float(_generation.data["body"]["radius_cells"])
	for x in [float(rect[0]), float(rect[0] + rect[2])]:
		for y in [float(rect[1]), float(rect[1] + rect[3])]:
			if x * x + y * y > radius * radius:
				return false
	return true

static func valid_prefab_instance_id(value: Variant) -> bool:
	return _token(value) and value.begins_with("prefab_") and value.length() > 7

static func template_digest(template: Dictionary) -> String:
	return JSON.stringify(template, "", true, true).sha256_text()

static func runtime_id(prefix: String, world_id: String, body_instance_id: String, prefab_instance_id: String, local_id: String) -> String:
	# Domain, world, celestial instance and local ID are all part of identity.
	return prefix + "_" + JSON.stringify(["prefab-v1", prefix, world_id, body_instance_id, prefab_instance_id, local_id]).sha256_text().substr(0, 32)

static func translated_cell(cell: Array, origin: Array) -> Array:
	return [int(cell[0]) + int(origin[0]), int(cell[1]) + int(origin[1])]

static func translated_rect(rect: Array, origin: Array) -> Array:
	return [int(rect[0]) + int(origin[0]), int(rect[1]) + int(origin[1]), int(rect[2]), int(rect[3])]

static func _record_map(rows: Array, fields: Array) -> Dictionary:
	var records: Dictionary = {}
	for row in rows:
		if not _fields(row, fields) or not _token(row["local_id"]) or records.has(row["local_id"]):
			return _bad("PREFAB_INSTANCE_RECORD_FIELDS_OR_DUPLICATE_INVALID")
		records[row["local_id"]] = row
	return {"ok": true, "records": records}

static func _runtime_identity(value: Variant, expected: String, used: Dictionary) -> bool:
	if not value is String or value != expected or used.has(value):
		return false
	used[value] = true
	return true

static func _instance_layer_matches(value: Variant, expected: Dictionary) -> bool:
	# JSON numbers decode as floats. Validate the complete address first, then
	# normalize only its proven integer slot before exact Dictionary comparison.
	if not Address.valid_layer(value):
		return false
	var canonical: Dictionary = value.duplicate(true)
	canonical["depth"] = int(canonical["depth"])
	return canonical == expected

static func _json_value(value: Variant, depth: int = 0) -> bool:
	if depth > 16:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			if value.size() > 4096:
				return false
			for item in value:
				if not _json_value(item, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			if value.size() > 4096:
				return false
			for key in value:
				if not key is String or not _json_value(value[key], depth + 1):
					return false
			return true
	return false
