extends RefCounted
## Detached storage of already-generated terrain. Restore validates existing rows;
## it never synthesizes, repairs, reassigns or replaces a cell record.
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const Inputs = preload("res://scripts/worldgen/generation_inputs.gd")
const LayoutValidator = preload("res://scripts/worldgen/layout_validator.gd")
const PrefabValidator = preload("res://scripts/prefab/prefab_validator.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const FORMAT := "required_entry_terrain_record_store_v1"
const MAX_BYTES: int = 4194304 # Detached operational cap, not an actor save schema.
const CONTRACT := "011-required-entry-static-terrain-v1"
const KIND := "required_entry_static_generation_artifact"
const ALGORITHM := {
	"version": "same-layer-existing-site-integer-voronoi-v1",
	"status": "explicit_engineering_choice_not_original_algorithm",
	"metric": "integer_squared_cell_distance",
	"tie_break": "biome_id_ascending_lexical",
	"new_sites": false, "random_selection": false,
	"spawn_biome_id": "x03_db_wendai_linyuan"
}
const MAX_JSON_EXACT_INTEGER: int = 9007199254740991
const CATEGORIES := ["biome", "source_ground", "default_rock", "generated_carve", "caves", "liquids", "minerals", "trees", "natural_initial_animals", "ordinary_poi", "prefab", "permanent_changes"]
const RESOLVED_STATUS := {
	"biome": "resolved_source_assignment", "source_ground": "resolved_source_H0",
	"default_rock": "resolved_generated_clear", "generated_carve": "resolved_applied_generation_operation",
	"caves": "resolved_required_opening", "liquids": "resolved_generation_exclusion",
	"minerals": "resolved_generation_exclusion", "trees": "resolved_generation_exclusion",
	"natural_initial_animals": "resolved_no_initial_candidates", "ordinary_poi": "resolved_generation_exclusion",
	"prefab": "resolved_existing_world_references", "permanent_changes": "resolved_existing_world_references"
}
const FIELDS := ["schema_version", "artifact_kind", "contract", "sources", "source_rules", "algorithm", "bindings", "biome_inputs", "biome_sites", "spawn_assignment", "operations", "regions", "existing_world_references", "outside_scope", "dynamic_occupancy", "completion", "formal_world_allowed", "native_clear_allowed", "transfer_allowed", "artifact_sha256"]
const REGION_FIELDS := ["region_id", "scope", "layer", "layer_sha256", "bounds", "endpoint_key", "cells"]
const SOURCE_RULES := {
	"spawn_identity": "cehua.docx:body52",
	"continuous_biome_role": "cehua.docx:body58",
	"underground_before_carving": "cehua.docx:body65",
	"same_xy_paired_entries": "cehua.docx:body68",
	"protected_exclusions": "cehua.docx:body69",
	"required_entries": "cehua.docx:body70",
	"generation_order": "cehua.docx:body74",
	"fail_closed": "cehua.docx:body75",
	"biome_identity_and_layer": "32_Biome总表!A9:D17",
	"biome_ground_and_rock": "32_Biome总表!X9:Y17",
	"entry_footprints": "38_层间连接!O6:P7",
	"rock_occupancy": "145_普通岩石天体参数!F2",
	"natural_animal_distribution": {
		"source_range": "23_动物!F1:F9", "header": "自然地表Biome",
		"rows": [
			{"cell": "23_动物!F2", "value": "行星3·温带林原；行星4·高草花原、彩叶疏林"},
			{"cell": "23_动物!F3", "value": "行星3·温带林原；行星4·巨蕨林带、彩叶疏林"},
			{"cell": "23_动物!F4", "value": "行星3·河湖湿地；行星4·清水湿地；行星5·雷雨湿原非液体地块"},
			{"cell": "23_动物!F5", "value": "行星3·温带林原；行星4·高草花原、彩叶疏林"},
			{"cell": "23_动物!F6", "value": "行星3·干旱砾漠；行星4·白岩林谷"},
			{"cell": "23_动物!F7", "value": "行星3·冻土冰原；行星8·白霜原野、霜林带"},
			{"cell": "23_动物!F8", "value": "行星6·酸雾平原、白壳林原、酸湖湿地非液体岸区"},
			{"cell": "23_动物!F9", "value": "行星7·云海主浮岛群、气囊林岛可行走地块"}
		],
		"interpretation": "initial_natural_distribution_surface_only_not_carried_animal_ban"
	},
	"depth2_natural_liquids": "36_层级液体许可!C10:G10"
}
# Existing world validators retain older Variant string comparisons. Preflight
# their textual slots here before calling them; no old loader behavior changes.
const WORLD_TEXT_FIELDS := ["artifact_kind", "generation_version", "world_id", "seed_decimal", "reference_frame", "body_instance_id", "map_kind", "biome_id", "ground_resource_id", "connection_instance_id", "stage", "status", "core_layout_fingerprint", "bundle_sha256", "template_id", "template_sha256", "body_content_id", "prefab_instance_id", "geometry_kind", "local_id", "content_id", "content_scope", "content_namespace", "layer_id", "plane", "instance_id", "kind", "object_local_id", "object_instance_id", "upper_anchor_id", "lower_anchor_id", "mode", "upper_anchor_instance_id", "lower_anchor_instance_id", "reason"]
const OP_FIELDS := ["operation_id", "endpoint_key", "connection_instance_id", "connection_sha256", "endpoint_index", "layer", "cell", "body_rect", "safety_rect", "mask_cells", "provenance", "stage", "after", "before", "clear_scope", "clear_default_rock_H1", "excluded_natural_population", "clears_prefab_or_user_objects", "triggered_by_interaction"]
const OP_RULES := {
	"provenance": "required_connection_world_generation", "stage": "base_terrain",
	"after": "source_H0_and_underground_H1_fill",
	"before": ["static_liquids", "underground_resources", "poi_and_civilization", "trees_and_animals"],
	"clear_scope": "default_geological_rock_H1_only", "clear_default_rock_H1": true,
	"excluded_natural_population": ["liquids", "minerals", "trees", "ordinary_poi"],
	"clears_prefab_or_user_objects": false, "triggered_by_interaction": false
}
const OUTSIDE := {"status": "unknown", "reason": "NOT_GENERATED_BY_THIS_STAGE", "implicit_air": false, "implicit_wall": false, "includes_surface_and_inspection_rings": true}
const DYNAMIC := {"status": "unknown", "scope": "actors_enemies_summons_carried_animals_and_user_objects", "cleared_by_stage": false}
const COMPLETION := {"scope": "declared_required_entry_initial_static_generation_only", "cell_count": 147, "unresolved_cell_count": 0, "local_static_generation_complete": true, "global_terrain_complete": false, "native_ready": false, "dynamic_occupancy_resolved": false}
var ready: bool = false
var last_error: String = ""
var _generation: Dictionary = {}
var _prefab: Dictionary = {}
var _bundle: Dictionary = {}
var _bundle_sha256: String = ""
var _layout_validator: RefCounted
var _prefab_validator: RefCounted

func _init(generation: Dictionary, prefab: Dictionary, bundle: Dictionary) -> void:
	if not _same(generation, JSON.parse_string(FileAccess.get_file_as_string("res://data/generation_settings.json"))) or not _same(prefab, JSON.parse_string(FileAccess.get_file_as_string("res://data/prefab_settings.json"))):
		last_error = "ENTRY_STORE_APPROVED_INPUT_TYPE_OR_BITS_MISMATCH"
		return
	var inputs := Inputs.new()
	if not inputs.load_document(generation):
		last_error = inputs.last_error
		return
	_prefab_validator = PrefabValidator.new(generation, prefab)
	if not _prefab_validator.ready:
		last_error = _prefab_validator.last_error
		return
	var bundle_text: String = FileAccess.get_file_as_string("res://data/actor_world_bundle011.json")
	var authority: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_world_bundle011_authorities.json"))
	var trusted: Variant = JSON.parse_string(bundle_text)
	if not authority is Dictionary or not _hash(authority.get("_projection_sha256")) or not _same(authority["_projection_sha256"], bundle_text.sha256_text()) or not _same(bundle, trusted):
		last_error = "ENTRY_STORE_BUNDLE_NOT_APPROVED"
		return
	if not _same(bundle.get("sources"), generation["sources"]) or not _same(bundle.get("generation_projection_sha256"), FileAccess.get_file_as_string("res://data/generation_settings.json").sha256_text()) or not _same(bundle.get("prefab_projection_sha256"), FileAccess.get_file_as_string("res://data/prefab_settings.json").sha256_text()):
		last_error = "ENTRY_STORE_BUNDLE_SOURCE_MISMATCH"
		return
	var actor_text: String = FileAccess.get_file_as_string("res://data/actor_settings.json")
	var actor_authority: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_authorities.json"))
	var actor: Variant = JSON.parse_string(actor_text)
	if not actor_authority is Dictionary or not _same(actor_authority.get("_projection_sha256"), actor_text.sha256_text()) or not actor is Dictionary or not _same(actor.get("sources"), generation["sources"]) or not _same(bundle.get("actor_projection_sha256"), actor_text.sha256_text()):
		last_error = "ENTRY_STORE_ACTOR_SOURCE_MISMATCH"
		return
	var template: Dictionary = _prefab_validator.validate_template(bundle.get("template"))
	if not template["ok"]:
		last_error = template["code"]
		return
	_generation = inputs.data.duplicate(true)
	_prefab = prefab.duplicate(true)
	_bundle = bundle.duplicate(true)
	_bundle["template"] = template["template"]
	_bundle_sha256 = bundle_text.sha256_text()
	_layout_validator = LayoutValidator.new(generation)
	ready = true

func encode(artifact: Variant, component: Variant, world_id: String) -> Dictionary:
	var checked: Dictionary = restore(artifact, component, world_id)
	if not checked["ok"]:
		return checked
	var tagged: Dictionary = Codec.encode(checked["artifact"])
	if not tagged["ok"]:
		return _bad(tagged["code"])
	var payload: String = JSON.stringify(tagged["value"], "", true, true)
	# Array framing prevents JSON duplicate-object-key collapse in the envelope.
	var bytes: PackedByteArray = JSON.stringify([FORMAT, Codec.FORMAT, world_id, payload, payload.sha256_text()], "", true, true).to_utf8_buffer()
	if bytes.size() > MAX_BYTES:
		return _bad("ENTRY_STORE_SIZE_LIMIT")
	return {"ok": true, "bytes": bytes, "formal_world_allowed": false, "native_clear_allowed": false, "transfer_allowed": false}

func decode(bytes: Variant, component: Variant, world_id: String) -> Dictionary:
	if not bytes is PackedByteArray:
		return _bad("ENTRY_STORE_BYTES_REQUIRED")
	if bytes.is_empty():
		return _bad("ENTRY_STORE_MISSING_ARTIFACT_NO_REGENERATION")
	if bytes.size() > MAX_BYTES:
		return _bad("ENTRY_STORE_SIZE_LIMIT")
	if not _valid_utf8(bytes):
		return _bad("ENTRY_STORE_UTF8_INVALID")
	var text: String = bytes.get_string_from_utf8()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _bad("ENTRY_STORE_JSON_INVALID")
	var envelope: Variant = parser.data
	# Existing SaveStore envelopes are a different artifact, irrespective of the
	# actor schema inside. Do not decode/migrate them or infer a terrain component.
	if envelope is Dictionary and _same(envelope.get("format"), "shaheyouxi.save.envelope"):
		return _bad("ENTRY_STORE_ACTOR_SAVE_ENVELOPE_REQUIRES_EXPLICIT_SCHEMA_WIRING")
	if _legacy(envelope):
		return _bad("ENTRY_STORE_LEGACY_ACTOR_SCHEMA3_TERRAIN_MISSING")
	if not envelope is Array or envelope.size() != 5:
		return _bad("ENTRY_STORE_ENVELOPE_INVALID")
	for field in envelope:
		if typeof(field) != TYPE_STRING:
			return _bad("ENTRY_STORE_ENVELOPE_INVALID")
	if envelope[0] != FORMAT or envelope[1] != Codec.FORMAT or envelope[2] != world_id:
		return _bad("ENTRY_STORE_IDENTITY_MISMATCH")
	if not _hash(envelope[4]) or envelope[3].sha256_text() != envelope[4]:
		return _bad("ENTRY_STORE_CHECKSUM_MISMATCH")
	var payload_parser := JSON.new()
	if payload_parser.parse(envelope[3]) != OK:
		return _bad("ENTRY_STORE_PAYLOAD_JSON_INVALID")
	var decoded: Dictionary = Codec.decode(payload_parser.data)
	if not decoded["ok"]:
		return _bad(decoded["code"])
	return restore(decoded["value"], component, world_id)

func restore(artifact: Variant, component: Variant, world_id: String) -> Dictionary:
	if typeof(artifact) == TYPE_NIL:
		return _bad("ENTRY_STORE_MISSING_ARTIFACT_NO_REGENERATION")
	if _legacy(artifact):
		return _bad("ENTRY_STORE_LEGACY_ACTOR_SCHEMA3_TERRAIN_MISSING")
	if not ready:
		return _bad("ENTRY_STORE_INPUTS_NOT_READY")
	var bounded: Dictionary = Codec.encode(artifact)
	if not bounded["ok"]:
		return _bad(bounded["code"])
	if JSON.stringify(bounded["value"], "", true, true).to_utf8_buffer().size() > MAX_BYTES:
		return _bad("ENTRY_STORE_SIZE_LIMIT")
	if not _fields(artifact, FIELDS):
		return _bad("ENTRY_STORE_ARTIFACT_FIELDS_INVALID")
	if not _same(artifact["schema_version"], 1) or not _same(artifact["artifact_kind"], KIND) or not _same(artifact["contract"], CONTRACT):
		return _bad("ENTRY_STORE_ARTIFACT_VERSION_UNSUPPORTED")
	for flag in ["formal_world_allowed", "native_clear_allowed", "transfer_allowed"]:
		if not _same(artifact[flag], false):
			return _bad("ENTRY_STORE_CERTIFICATION_FORBIDDEN")
	for key in ["sources", "biome_inputs", "source_rules"]:
		var expected: Variant = {"sources": _generation["sources"], "biome_inputs": _generation["biomes"], "source_rules": SOURCE_RULES}[key]
		if not _same(artifact[key], expected):
			return _bad("ENTRY_STORE_SOURCE_MISMATCH")
	if not _same(artifact["algorithm"], ALGORITHM):
		return _bad("ENTRY_STORE_ALGORITHM_MISMATCH")
	var world: Dictionary = _checked_world(component, world_id)
	if not world["ok"]:
		return world
	var existing: Dictionary = world["component"]
	var plan: Dictionary = existing["layout"]
	var bindings := {
		"world_id": world_id, "world_sha256": digest(existing), "bundle_sha256": _bundle_sha256,
		"layout_sha256": digest(plan), "core_layout_fingerprint": plan["core_layout_fingerprint"],
		"permanent_changes_sha256": digest(plan["permanent_changes"]), "generation_stages_sha256": digest(plan["generation_stages"]),
		"generation_version": plan["generation_version"], "generation_document_sha256": digest(_generation),
		"prefab_document_sha256": digest(_prefab), "algorithm_sha256": digest(ALGORITHM)
	}
	if not _same(artifact["bindings"], bindings):
		return _bad("ENTRY_STORE_WORLD_BINDING_MISMATCH")
	var sites: Array = plan["biome_sites"].duplicate(true)
	sites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["biome_id"] < b["biome_id"])
	if not _same(artifact["biome_sites"], sites):
		return _bad("ENTRY_STORE_SITE_BINDING_MISMATCH")
	var spawn: Variant = artifact["spawn_assignment"]
	if not _fields(spawn, ["layer", "cell", "assignment", "static_generation_complete"]) or not _same(spawn["layer"], plan["spawn"]["layer"]) or not _same(spawn["cell"], plan["spawn"]["cell"]) or not _same(spawn["static_generation_complete"], false):
		return _bad("ENTRY_STORE_SPAWN_INVALID")
	if not _assignment_valid(spawn["assignment"], plan, spawn["layer"], spawn["cell"]) or not _same(spawn["assignment"]["biome_id"], ALGORITHM["spawn_biome_id"]):
		return _bad("ENTRY_STORE_SPAWN_INVALID")
	var operation_check: Dictionary = _operations_valid(artifact["operations"], plan)
	if not operation_check["ok"]:
		return operation_check
	var regions: Variant = artifact["regions"]
	if not regions is Array or regions.size() != 3:
		return _bad("ENTRY_STORE_REGION_COVERAGE_INVALID")
	for index in range(3):
		var region: Variant = regions[index]
		var operation: Dictionary = artifact["operations"][index]
		if not _fields(region, REGION_FIELDS) or not _same(region["layer"], operation["layer"]) or not _hash(region["layer_sha256"]) or region["layer_sha256"] != digest(operation["layer"]):
			return _bad("ENTRY_STORE_FULL_LAYER_MISMATCH")
		if not _same(region["region_id"], "required_entry_region_" + digest([operation["layer"], operation["endpoint_key"]]).substr(0, 32)) or not _same(region["scope"], "required_underground_entry_initial_static_generation") or not _same(region["endpoint_key"], operation["endpoint_key"]) or not _same(region["bounds"], operation["safety_rect"]):
			return _bad("ENTRY_STORE_REGION_COVERAGE_INVALID")
		if not region["cells"] is Array or region["cells"].size() != 49:
			return _bad("ENTRY_STORE_CELL_COVERAGE_INVALID")
		for cell_index in range(49):
			var row: Variant = region["cells"][cell_index]
			if not _fields(row, ["cell", "categories"]) or not _same(row["cell"], operation["mask_cells"][cell_index]):
				return _bad("ENTRY_STORE_CELL_COVERAGE_INVALID")
			if not _cell_valid(row, operation, existing):
				return _bad("ENTRY_STORE_CELL_SEMANTICS_INVALID")
	if not _references_valid(artifact["existing_world_references"], existing) or not _same(artifact["outside_scope"], OUTSIDE) or not _same(artifact["dynamic_occupancy"], DYNAMIC) or not _same(artifact["completion"], COMPLETION):
		return _bad("ENTRY_STORE_SCOPE_OR_REFERENCES_INVALID")
	if not _hash(artifact["artifact_sha256"]):
		return _bad("ENTRY_STORE_ARTIFACT_CHECKSUM_MISMATCH")
	var unhashed: Dictionary = artifact.duplicate(true)
	unhashed.erase("artifact_sha256")
	if digest(unhashed) != artifact["artifact_sha256"]:
		return _bad("ENTRY_STORE_ARTIFACT_CHECKSUM_MISMATCH")
	# Return only the complete stored input, never a generated expected artifact.
	var result: Dictionary = COMPLETION.duplicate(true)
	result.merge({"ok": true, "code": "ENTRY_STORE_RESTORED_EXISTING_RECORDS", "artifact": artifact.duplicate(true), "formal_world_allowed": false, "native_clear_allowed": false, "transfer_allowed": false})
	return result

func _checked_world(value: Variant, world_id: String) -> Dictionary:
	var bounded: Dictionary = Codec.encode(value)
	if not bounded["ok"] or JSON.stringify(bounded.get("value"), "", true, true).to_utf8_buffer().size() > MAX_BYTES:
		return _bad("ENTRY_STORE_WORLD_LIMIT_OR_TYPE_INVALID")
	if not _fields(value, ["schema_version", "artifact_kind", "bundle_sha256", "layout", "prefab_instances", "formal_world_allowed"]) or not _same(value["schema_version"], 1) or not _same(value["artifact_kind"], "technical_network_world") or not _same(value["bundle_sha256"], _bundle_sha256) or not _same(value["formal_world_allowed"], false):
		return _bad("ENTRY_STORE_WORLD_INVALID")
	if not _world_text_types_valid(value):
		return _bad("ENTRY_STORE_WORLD_FIELD_TYPE_INVALID")
	# Biome sites use get() in the older validator: missing text slots and the
	# nullable surface rock slot need explicit checks before its comparisons.
	if value["layout"] is Dictionary and value["layout"].get("biome_sites") is Array:
		for site in value["layout"]["biome_sites"]:
			if not _fields(site, ["biome_id", "map_kind", "depth", "ground_resource_id", "default_rock_id", "cell"]) or typeof(site["biome_id"]) != TYPE_STRING or not _generation["biomes"].has(site["biome_id"]):
				return _bad("ENTRY_STORE_WORLD_FIELD_TYPE_INVALID")
			for field in ["map_kind", "ground_resource_id", "default_rock_id"]:
				if not _same(site[field], _generation["biomes"][site["biome_id"]][field]):
					return _bad("ENTRY_STORE_WORLD_SITE_SOURCE_INVALID")
	var checked_layout: Dictionary = _layout_validator.validate(value["layout"], world_id)
	if not checked_layout["ok"]:
		return _bad("ENTRY_STORE_WORLD_LAYOUT_INVALID:" + checked_layout["code"])
	if not value["prefab_instances"] is Array or value["prefab_instances"].size() != 1:
		return _bad("ENTRY_STORE_WORLD_PREFAB_INVALID")
	var raw_prefab: Variant = value["prefab_instances"][0]
	if not _fields(raw_prefab, PrefabValidator.INSTANCE_FIELDS) or not _same(raw_prefab["sources"], _generation["sources"]) or not _same(raw_prefab["source_template"], _bundle["template"]):
		return _bad("ENTRY_STORE_WORLD_PREFAB_SOURCE_INVALID")
	var checked_prefab: Dictionary = _prefab_validator.validate_instance(raw_prefab, world_id)
	if not checked_prefab["ok"]:
		return _bad("ENTRY_STORE_WORLD_PREFAB_INVALID:" + checked_prefab["code"])
	var plan: Dictionary = checked_layout["plan"]
	var instance: Dictionary = checked_prefab["instance"]
	if not _same(instance["prefab_instance_id"], "prefab_" + (world_id + "|initial-room-v1").sha256_text().substr(0, 32)) or not _same(instance["body_instance_id"], "body_0001") or not _same(instance["source_template"], _bundle["template"]) or not _same(instance["origin"], plan["spawn"]["cell"]):
		return _bad("ENTRY_STORE_WORLD_PREFAB_BINDING_INVALID")
	for connection in plan["connections"]:
		for endpoint in connection["endpoints"]:
			for object in instance["objects"]:
				if _same(object["layer"], endpoint["layer"]) and (_same(object["plane"], "H1") or object["is_liquid"]) and _intersects(object["rect"], connection["safety_rect"]):
					return _bad("ENTRY_STORE_WORLD_PREFAB_COVERS_ENTRY")
	return {"ok": true, "component": {"schema_version": 1, "artifact_kind": "technical_network_world", "bundle_sha256": _bundle_sha256, "layout": plan, "prefab_instances": [instance], "formal_world_allowed": false}}

func _operations_valid(operations: Variant, plan: Dictionary) -> Dictionary:
	if not operations is Array or operations.size() != 3:
		return _bad("ENTRY_STORE_OPERATION_COVERAGE_INVALID")
	var connections: Array = plan["connections"].duplicate(true)
	connections.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: int = a["endpoints"][0]["layer"]["depth"]
		var db: int = b["endpoints"][0]["layer"]["depth"]
		return da < db if da != db else a["connection_instance_id"] < b["connection_instance_id"])
	var ordinal: int = 0
	for connection in connections:
		for endpoint_index in range(2):
			var endpoint: Dictionary = connection["endpoints"][endpoint_index]
			if endpoint["layer"]["depth"] == 0:
				continue
			if ordinal >= 3:
				return _bad("ENTRY_STORE_OPERATION_COVERAGE_INVALID")
			var op: Variant = operations[ordinal]
			var key: String = connection["connection_instance_id"] + "|" + str(endpoint_index)
			if not _fields(op, OP_FIELDS):
				return _bad("ENTRY_STORE_OPERATION_FIELDS_INVALID")
			for field in OP_RULES:
				if not _same(op[field], OP_RULES[field]):
					return _bad("ENTRY_STORE_OPERATION_SEMANTICS_INVALID")
			if not _same(op["operation_id"], "required_entry_carve_" + key.sha256_text().substr(0, 32)) or not _same(op["endpoint_key"], key) or not _same(op["connection_instance_id"], connection["connection_instance_id"]) or not _hash(op["connection_sha256"]) or op["connection_sha256"] != digest(connection) or not _same(op["endpoint_index"], endpoint_index):
				return _bad("ENTRY_STORE_CONNECTION_BINDING_INVALID")
			if not _same(op["layer"], endpoint["layer"]) or not _supported_layer(plan, op["layer"]) or not _same(op["cell"], endpoint["cell"]):
				return _bad("ENTRY_STORE_FULL_LAYER_MISMATCH")
			var side: int = connection["body_side_cells"]
			var half: int = (side - 1) >> 1
			if not _same(op["body_rect"], [endpoint["cell"][0] - half, endpoint["cell"][1] - half, side, side]) or not _same(op["safety_rect"], connection["safety_rect"]):
				return _bad("ENTRY_STORE_MASK_INVALID")
			var bounds: Array = op["safety_rect"]
			if bounds[2] != 7 or bounds[3] != 7 or not op["mask_cells"] is Array or op["mask_cells"].size() != 49:
				return _bad("ENTRY_STORE_MASK_INVALID")
			for index in range(49):
				# Verify row-major coverage of EXISTING coordinates, never append cells.
				if not _same(op["mask_cells"][index], [bounds[0] + index % 7, bounds[1] + floori(float(index) / 7.0)]):
					return _bad("ENTRY_STORE_MASK_INVALID")
			for previous in range(ordinal):
				if _same(op["layer"], operations[previous]["layer"]) and _intersects(bounds, operations[previous]["safety_rect"]):
					return _bad("ENTRY_STORE_MASK_OVERLAP")
			ordinal += 1
	return {"ok": true} if ordinal == 3 else _bad("ENTRY_STORE_OPERATION_COVERAGE_INVALID")

func _assignment_valid(value: Variant, plan: Dictionary, layer: Variant, cell: Array) -> bool:
	if not _supported_layer(plan, layer) or not _fields(value, ["status", "biome_id", "site_cell", "distance_squared", "algorithm_version", "source_cells"]):
		return false
	if typeof(value["biome_id"]) != TYPE_STRING or not _generation["biomes"].has(value["biome_id"]):
		return false
	var winner: Dictionary = {}
	var distance: int = 0
	for site in plan["biome_sites"]:
		if site["map_kind"] != layer["map_kind"] or site["depth"] != layer["depth"]:
			continue
		var dx: int = cell[0] - site["cell"][0]
		var dy: int = cell[1] - site["cell"][1]
		var squared: int = dx * dx + dy * dy
		if winner.is_empty() or squared < distance or (squared == distance and site["biome_id"] < winner["biome_id"]):
			winner = site
			distance = squared
	if winner.is_empty():
		return false
	return _same(value["status"], RESOLVED_STATUS["biome"]) and _same(value["biome_id"], winner["biome_id"]) and _same(value["site_cell"], winner["cell"]) and _same(value["distance_squared"], distance) and _same(value["algorithm_version"], ALGORITHM["version"]) and _same(value["source_cells"], _generation["biomes"][winner["biome_id"]]["source_cells"])

func _cell_valid(row: Dictionary, op: Dictionary, component: Dictionary) -> bool:
	var cats: Variant = row["categories"]
	if not _fields(cats, CATEGORIES):
		return false
	if not _assignment_valid(cats["biome"], component["layout"], op["layer"], row["cell"]):
		return false
	var biome: Dictionary = _generation["biomes"][cats["biome"]["biome_id"]]
	var id: String = op["operation_id"]
	if not _same(cats["source_ground"], {"status": RESOLVED_STATUS["source_ground"], "plane": "H0", "resource_id": biome["ground_resource_id"], "source_cell": biome["source_cells"]["地面资源ID"], "occupied": true}):
		return false
	if not _same(cats["default_rock"], {"status": RESOLVED_STATUS["default_rock"], "plane": "H1", "resource_id": biome["default_rock_id"], "source_cell": biome["source_cells"]["普通岩石ID"], "initial_occupied": true, "initial_size_cells": [1, 1, 1], "initial_source": SOURCE_RULES["underground_before_carving"], "size_source": SOURCE_RULES["rock_occupancy"], "final_occupied": false, "removed_by_operation_id": id}):
		return false
	if not _same(cats["generated_carve"], {"status": RESOLVED_STATUS["generated_carve"], "operation_ids": [id], "clear_scope": "default_geological_rock_H1_only"}) or not _same(cats["caves"], {"status": RESOLVED_STATUS["caves"], "final_height": 0, "operation_id": id, "random_cave_topology_outside_scope": true}):
		return false
	for category in ["liquids", "minerals", "trees", "ordinary_poi"]:
		var rule := {"status": RESOLVED_STATUS[category], "source": SOURCE_RULES["protected_exclusions"], "operation_id": id, "natural_initial_occupied": false}
		if category == "liquids" and op["layer"]["depth"] == 2:
			rule["layer_prohibition_source"] = SOURCE_RULES["depth2_natural_liquids"]
		if not _same(cats[category], rule):
			return false
	if not _same(cats["natural_initial_animals"], {"status": RESOLVED_STATUS["natural_initial_animals"], "candidate_ids": [], "source_range": "23_动物!F1:F9", "scope": "initial_natural_distribution_only", "carried_animals_prohibited": false, "future_dynamic_occupancy_resolved": false}):
		return false
	var objects: Array = []
	for instance in component["prefab_instances"]:
		for object in instance["objects"]:
			if _same(object["layer"], op["layer"]) and _contains(object["rect"], row["cell"]):
				objects.append(object["instance_id"])
	objects.sort()
	if not _same(cats["prefab"], {"status": RESOLVED_STATUS["prefab"], "object_instance_ids": objects, "cleared_by_stage": false}):
		return false
	var key: String = "%d|%d,%d" % [op["layer"]["depth"], row["cell"][0], row["cell"][1]]
	var changes: Array = [key] if component["layout"]["permanent_changes"].has(key) else []
	return _same(cats["permanent_changes"], {"status": RESOLVED_STATUS["permanent_changes"], "change_keys": changes, "written_by_stage": false})

static func _references_valid(value: Variant, component: Dictionary) -> bool:
	if not _fields(value, ["prefab_instances", "permanent_changes", "stage_mutates_existing_world"]) or not _same(value["stage_mutates_existing_world"], false) or not _same(value["permanent_changes"], component["layout"]["permanent_changes"]):
		return false
	if not value["prefab_instances"] is Array or value["prefab_instances"].size() != component["prefab_instances"].size():
		return false
	for index in range(component["prefab_instances"].size()):
		var stored: Variant = value["prefab_instances"][index]
		var instance: Dictionary = component["prefab_instances"][index]
		if not _fields(stored, ["prefab_instance_id", "instance_sha256", "objects"]) or not _same(stored["prefab_instance_id"], instance["prefab_instance_id"]) or not _hash(stored["instance_sha256"]) or stored["instance_sha256"] != digest(instance):
			return false
		if not stored["objects"] is Array or stored["objects"].size() != instance["objects"].size():
			return false
		for object_index in range(instance["objects"].size()):
			var row: Variant = stored["objects"][object_index]
			var object: Dictionary = instance["objects"][object_index]
			if not _fields(row, ["instance_id", "object_sha256", "layer", "rect", "plane", "is_liquid"]) or not _hash(row["object_sha256"]) or row["object_sha256"] != digest(object):
				return false
			for field in ["instance_id", "layer", "rect", "plane", "is_liquid"]:
				if not _same(row[field], object[field]):
					return false
	return true

static func _world_text_types_valid(value: Variant, depth: int = 0) -> bool:
	if depth > Codec.MAX_DEPTH:
		return false
	if value is Dictionary:
		for key in value:
			if typeof(key) != TYPE_STRING:
				return false
			if key in WORLD_TEXT_FIELDS and typeof(value[key]) != TYPE_STRING:
				return false
			if not _world_text_types_valid(value[key], depth + 1):
				return false
	elif value is Array:
		for item in value:
			if not _world_text_types_valid(item, depth + 1):
				return false
	return true

static func _supported_layer(plan: Dictionary, layer: Variant) -> bool:
	if not _fields(layer, Address.LAYER_FIELDS) or not _world_text_types_valid(layer) or typeof(layer["depth"]) != TYPE_INT or not Address.valid_layer(layer):
		return false
	var supported: bool = _same(layer, plan["spawn"]["layer"])
	for connection in plan["connections"]:
		for endpoint in connection["endpoints"]:
			if _same(layer, endpoint["layer"]):
				supported = true
	if not supported:
		return false
	for site in plan["biome_sites"]:
		if site["map_kind"] == layer["map_kind"] and site["depth"] == layer["depth"]:
			return true
	return false

static func digest(value: Variant) -> String:
	return JSON.stringify(value, "", true, true).sha256_text()

static func _same(actual: Variant, expected: Variant, depth: int = 0) -> bool:
	# Exact typed/bit equality, including floats in approved biome source inputs.
	if depth > 64 or typeof(actual) != typeof(expected):
		return false
	if actual is Dictionary:
		if actual.size() != expected.size():
			return false
		for key in expected:
			if not key is String or not actual.has(key) or not _same(actual[key], expected[key], depth + 1):
				return false
		return true
	if actual is Array:
		if actual.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _same(actual[index], expected[index], depth + 1):
				return false
		return true
	if typeof(actual) == TYPE_FLOAT:
		if not is_finite(actual) or not is_finite(expected):
			return false
		var a := PackedByteArray()
		var b := PackedByteArray()
		a.resize(8)
		b.resize(8)
		a.encode_double(0, actual)
		b.encode_double(0, expected)
		return a == b
	return typeof(actual) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING] and actual == expected

static func _fields(value: Variant, fields: Array) -> bool:
	if not value is Dictionary or value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true

static func _hash(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true

static func _valid_utf8(bytes: PackedByteArray) -> bool:
	# Validate before Godot's text conversion so bad input causes a clean refusal,
	# without decoder error logs or replacement characters.
	var index: int = 0
	while index < bytes.size():
		var first: int = bytes[index]
		if first < 128:
			index += 1
			continue
		var length: int = 0
		var codepoint: int = 0
		var minimum: int = 0
		if first >= 194 and first <= 223:
			length = 2
			codepoint = first & 31
			minimum = 128
		elif first >= 224 and first <= 239:
			length = 3
			codepoint = first & 15
			minimum = 2048
		elif first >= 240 and first <= 244:
			length = 4
			codepoint = first & 7
			minimum = 65536
		else:
			return false
		if index + length > bytes.size():
			return false
		for offset in range(1, length):
			var byte: int = bytes[index + offset]
			if byte < 128 or byte > 191:
				return false
			codepoint = (codepoint << 6) | (byte & 63)
		if codepoint < minimum or codepoint > 1114111 or (codepoint >= 55296 and codepoint <= 57343):
			return false
		index += length
	return true

static func _legacy(value: Variant) -> bool:
	return value is Dictionary and typeof(value.get("save_schema_version")) in [TYPE_INT, TYPE_FLOAT] and value["save_schema_version"] == 3

static func _contains(bounds: Array, cell: Array) -> bool:
	return cell[0] >= bounds[0] and cell[1] >= bounds[1] and cell[0] < bounds[0] + bounds[2] and cell[1] < bounds[1] + bounds[3]

static func _intersects(a: Array, b: Array) -> bool:
	return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "local_static_generation_complete": false, "global_terrain_complete": false, "native_ready": false, "dynamic_occupancy_resolved": false, "formal_world_allowed": false, "native_clear_allowed": false, "transfer_allowed": false, "migration_route_available": false, "regeneration_allowed": false}
