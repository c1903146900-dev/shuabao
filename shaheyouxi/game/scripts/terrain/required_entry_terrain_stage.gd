extends RefCounted
## Detached real generation stage for only the three required underground masks.
## No world generation, random source, save, scene, native physics or F mutation.
const Address = preload("res://scripts/world/spatial_address.gd")
const World = preload("res://scripts/world_session/world_component.gd")
const Inputs = preload("res://scripts/worldgen/generation_inputs.gd")
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
var ready: bool = false
var last_error: String = ""
var _world: RefCounted
var _generation: Dictionary = {}
var _input_bindings: Dictionary = {}

func _init(generation: Dictionary, prefab: Dictionary, bundle: Dictionary, technical_profile: String = "011") -> void:
	var inputs := Inputs.new()
	if not inputs.load_document(generation):
		last_error = inputs.last_error
		return
	_world = World.new(generation, prefab, bundle, technical_profile)
	if not _world.ready:
		last_error = _world.last_error
		return
	_generation = inputs.data.duplicate(true)
	_input_bindings = {"generation_document_sha256": digest(_generation), "prefab_document_sha256": digest(prefab)}
	ready = true

func materialize(value: Variant, expected_world_id: String) -> Dictionary:
	var checked: Dictionary = _validated_world(value, expected_world_id)
	if not checked["ok"]:
		return checked
	var component: Dictionary = checked["component"]
	var plan: Dictionary = component["layout"]
	var spawn: Dictionary = plan["spawn"]
	if not _supported_layer(plan, spawn["layer"]):
		return _bad("ENTRY_TERRAIN_BIOME_ASSIGNMENT_UNAVAILABLE")
	var spawn_assignment: Dictionary = _assignment(plan, spawn["layer"], spawn["cell"])
	if spawn_assignment.is_empty():
		return _bad("ENTRY_TERRAIN_BIOME_ASSIGNMENT_UNAVAILABLE")
	var operations: Array = _operations(plan)
	if operations.size() != 3:
		return _bad("ENTRY_TERRAIN_ENDPOINT_SCOPE_UNSUPPORTED")
	for index in range(operations.size()):
		if not _supported_layer(plan, operations[index]["layer"]):
			return _bad("ENTRY_TERRAIN_BIOME_ASSIGNMENT_UNAVAILABLE")
		if operations[index]["mask_cells"].size() != 49:
			return _bad("ENTRY_TERRAIN_ENDPOINT_SCOPE_UNSUPPORTED")
		for previous in range(index):
			if operations[index]["layer"] == operations[previous]["layer"] and _intersects(operations[index]["safety_rect"], operations[previous]["safety_rect"]):
				return _bad("ENTRY_TERRAIN_REGION_OVERLAP_UNSUPPORTED")
	var regions: Array = []
	for operation in operations:
		var cells: Array = []
		for cell in operation["mask_cells"]:
			var row: Dictionary = _cell_record(cell, operation, component)
			if row.is_empty():
				return _bad("ENTRY_TERRAIN_BIOME_ASSIGNMENT_UNAVAILABLE")
			cells.append(row)
		regions.append({
			"region_id": "required_entry_region_" + digest([operation["layer"], operation["endpoint_key"]]).substr(0, 32),
			"scope": "required_underground_entry_initial_static_generation",
			"layer": operation["layer"].duplicate(true), "layer_sha256": digest(operation["layer"]),
			"bounds": operation["safety_rect"].duplicate(), "endpoint_key": operation["endpoint_key"], "cells": cells
		})
	var sites: Array = plan["biome_sites"].duplicate(true)
	sites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["biome_id"] < b["biome_id"])
	var artifact: Dictionary = {
		"schema_version": 1, "artifact_kind": KIND, "contract": CONTRACT,
		"sources": _generation["sources"].duplicate(true), "source_rules": SOURCE_RULES.duplicate(true),
		"algorithm": ALGORITHM.duplicate(true),
		"bindings": {
			"world_id": expected_world_id, "world_sha256": digest(component), "bundle_sha256": component["bundle_sha256"],
			"layout_sha256": digest(plan), "core_layout_fingerprint": plan["core_layout_fingerprint"],
			"permanent_changes_sha256": digest(plan["permanent_changes"]), "generation_stages_sha256": digest(plan["generation_stages"]),
			"generation_version": plan["generation_version"], "generation_document_sha256": _input_bindings["generation_document_sha256"],
			"prefab_document_sha256": _input_bindings["prefab_document_sha256"], "algorithm_sha256": digest(ALGORITHM)
		},
		"biome_inputs": _generation["biomes"].duplicate(true), "biome_sites": sites,
		"spawn_assignment": {"layer": spawn["layer"].duplicate(true), "cell": spawn["cell"].duplicate(), "assignment": spawn_assignment, "static_generation_complete": false},
		"operations": operations, "regions": regions,
		"existing_world_references": _existing_references(component),
		"outside_scope": {"status": "unknown", "reason": "NOT_GENERATED_BY_THIS_STAGE", "implicit_air": false, "implicit_wall": false, "includes_surface_and_inspection_rings": true},
		"dynamic_occupancy": {"status": "unknown", "scope": "actors_enemies_summons_carried_animals_and_user_objects", "cleared_by_stage": false},
		"completion": _completion(regions),
		"formal_world_allowed": false, "native_clear_allowed": false, "transfer_allowed": false
	}
	artifact["artifact_sha256"] = digest(artifact)
	return _report(artifact)

func validate(value: Variant, component: Variant, expected_world_id: String) -> Dictionary:
	if not _fields(value, FIELDS):
		return _bad("ENTRY_TERRAIN_SCHEMA_INVALID")
	if not _same_json_contract(value["schema_version"], 1) or value["artifact_kind"] != KIND or value["contract"] != CONTRACT:
		return _bad("ENTRY_TERRAIN_VERSION_UNSUPPORTED")
	for flag in ["formal_world_allowed", "native_clear_allowed", "transfer_allowed"]:
		if typeof(value[flag]) != TYPE_BOOL or value[flag]:
			return _bad("ENTRY_TERRAIN_CERTIFICATION_FORBIDDEN")
	var made: Dictionary = materialize(component, expected_world_id)
	if not made["ok"]:
		return made
	var expected: Dictionary = made["artifact"]
	for key in ["sources", "source_rules", "biome_inputs"]:
		if not _same_json_contract(value[key], expected[key]):
			return _bad("ENTRY_TERRAIN_SOURCE_MISMATCH")
	if not _same_json_contract(value["algorithm"], expected["algorithm"]):
		return _bad("ENTRY_TERRAIN_ALGORITHM_MISMATCH")
	if not _same_json_contract(value["bindings"], expected["bindings"]):
		return _bad("ENTRY_TERRAIN_WORLD_BINDING_MISMATCH")
	for key in ["biome_sites", "spawn_assignment"]:
		if not _same_json_contract(value[key], expected[key]):
			return _bad("ENTRY_TERRAIN_ASSIGNMENT_MISMATCH")
	if not _same_json_contract(value["operations"], expected["operations"]):
		return _bad("ENTRY_TERRAIN_CONNECTION_OPERATION_MISMATCH")
	if not value["regions"] is Array or value["regions"].size() != expected["regions"].size():
		return _bad("ENTRY_TERRAIN_REGION_COVERAGE_INVALID")
	for index in range(expected["regions"].size()):
		var region: Variant = value["regions"][index]
		var target: Dictionary = expected["regions"][index]
		if not _fields(region, REGION_FIELDS):
			return _bad("ENTRY_TERRAIN_REGION_FIELDS_INVALID")
		if not _same_json_contract(region["layer"], target["layer"]) or region["layer_sha256"] != target["layer_sha256"]:
			return _bad("ENTRY_TERRAIN_LAYER_BINDING_MISMATCH")
		for key in ["region_id", "scope", "bounds", "endpoint_key"]:
			if not _same_json_contract(region[key], target[key]):
				return _bad("ENTRY_TERRAIN_REGION_COVERAGE_INVALID")
		if not region["cells"] is Array or region["cells"].size() != target["cells"].size():
			return _bad("ENTRY_TERRAIN_CELL_COVERAGE_INVALID")
		for cell_index in range(target["cells"].size()):
			var row: Variant = region["cells"][cell_index]
			var expected_row: Dictionary = target["cells"][cell_index]
			if not _fields(row, ["cell", "categories"]) or not _same_json_contract(row["cell"], expected_row["cell"]):
				return _bad("ENTRY_TERRAIN_CELL_COVERAGE_INVALID")
			if not _fields(row["categories"], CATEGORIES):
				return _bad("ENTRY_TERRAIN_CATEGORY_COVERAGE_INVALID")
			if not _same_json_contract(row["categories"], expected_row["categories"]):
				return _bad("ENTRY_TERRAIN_CATEGORY_SEMANTICS_INVALID")
	for key in ["existing_world_references", "outside_scope", "dynamic_occupancy", "completion"]:
		if not _same_json_contract(value[key], expected[key]):
			return _bad("ENTRY_TERRAIN_SCOPE_OR_COMPLETENESS_INVALID")
	if value["artifact_sha256"] != expected["artifact_sha256"]:
		return _bad("ENTRY_TERRAIN_ARTIFACT_FINGERPRINT_MISMATCH")
	return _report(expected)

func biome_at(component: Variant, expected_world_id: String, layer: Variant, cell: Variant) -> Dictionary:
	var checked: Dictionary = _validated_world(component, expected_world_id)
	if not checked["ok"]:
		return checked
	if not _valid_query(checked["component"], layer, cell):
		return _bad("ENTRY_TERRAIN_QUERY_ADDRESS_INVALID")
	var assignment: Dictionary = _assignment(checked["component"]["layout"], layer, [int(cell[0]), int(cell[1])])
	if assignment.is_empty():
		return _bad("ENTRY_TERRAIN_BIOME_ASSIGNMENT_UNAVAILABLE")
	return {"ok": true, "assignment": assignment, "static_generation_complete": false}

func inspect_cell(value: Variant, component: Variant, expected_world_id: String, layer: Variant, cell: Variant) -> Dictionary:
	var checked: Dictionary = validate(value, component, expected_world_id)
	if not checked["ok"]:
		return checked
	if not _valid_query(component, layer, cell):
		return _bad("ENTRY_TERRAIN_QUERY_ADDRESS_INVALID")
	var result: Dictionary = {"ok": true, "status": "unknown", "local_static_generation_complete": false, "native_clear_allowed": false, "formal_world_allowed": false, "transfer_allowed": false, "dynamic_occupancy_resolved": false}
	for region in checked["artifact"]["regions"]:
		if _same_json_contract(layer, region["layer"]) and _contains(region["bounds"], cell):
			for row in region["cells"]:
				if _same_json_contract(cell, row["cell"]):
					result["status"] = "resolved_initial_static_generation"
					result["local_static_generation_complete"] = true
					result["record"] = row.duplicate(true)
					return result
	result["reason"] = "OUTSIDE_MATERIALIZED_REQUIRED_ENTRY_MASKS"
	result["implicit_air"] = false
	result["implicit_wall"] = false
	return result

func require_native_ready(value: Variant, component: Variant, expected_world_id: String) -> Dictionary:
	var checked: Dictionary = validate(value, component, expected_world_id)
	if not checked["ok"]:
		return checked
	checked["ok"] = false
	checked["code"] = "ENTRY_TERRAIN_NATIVE_AND_DYNAMIC_READINESS_UNPROVEN"
	checked.erase("artifact")
	return checked

func _validated_world(value: Variant, expected_world_id: String) -> Dictionary:
	if not ready:
		return _bad("ENTRY_TERRAIN_INPUTS_NOT_READY")
	var checked: Dictionary = _world.validate_component(value, expected_world_id)
	if not checked["ok"]:
		return _bad("ENTRY_TERRAIN_WORLD_INVALID:" + str(checked["code"]))
	return checked

func _assignment(plan: Dictionary, layer: Dictionary, cell: Array) -> Dictionary:
	if not _supported_layer(plan, layer):
		return {}
	var selected: Dictionary = {}
	var nearest_squared: int = 0
	for site in plan["biome_sites"]:
		if site["map_kind"] != layer["map_kind"] or int(site["depth"]) != int(layer["depth"]):
			continue
		var dx: int = int(cell[0]) - int(site["cell"][0])
		var dy: int = int(cell[1]) - int(site["cell"][1])
		var squared: int = dx * dx + dy * dy
		if selected.is_empty() or squared < nearest_squared or (squared == nearest_squared and site["biome_id"] < selected["biome_id"]):
			selected = site
			nearest_squared = squared
	if selected.is_empty() or not _generation["biomes"].has(selected["biome_id"]):
		return {}
	var biome: Dictionary = _generation["biomes"][selected["biome_id"]]
	return {"status": "resolved_source_assignment", "biome_id": selected["biome_id"], "site_cell": selected["cell"].duplicate(), "distance_squared": nearest_squared, "algorithm_version": ALGORITHM["version"], "source_cells": biome["source_cells"].duplicate(true)}

static func _operations(plan: Dictionary) -> Array:
	var connections: Array = plan["connections"].duplicate(true)
	connections.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: int = int(a["endpoints"][0]["layer"]["depth"])
		var db: int = int(b["endpoints"][0]["layer"]["depth"])
		return da < db if da != db else a["connection_instance_id"] < b["connection_instance_id"])
	var result: Array = []
	for connection in connections:
		for index in range(2):
			var endpoint: Dictionary = connection["endpoints"][index]
			if int(endpoint["layer"]["depth"]) == 0:
				continue
			var key: String = connection["connection_instance_id"] + "|" + str(index)
			var safety: Array = connection["safety_rect"].duplicate()
			var mask: Array = []
			for y in range(int(safety[1]), int(safety[1] + safety[3])):
				for x in range(int(safety[0]), int(safety[0] + safety[2])):
					mask.append([x, y])
			var side: int = int(connection["body_side_cells"])
			var half: int = (side - 1) >> 1
			result.append({
				"operation_id": "required_entry_carve_" + key.sha256_text().substr(0, 32), "endpoint_key": key,
				"connection_instance_id": connection["connection_instance_id"], "connection_sha256": digest(connection), "endpoint_index": index,
				"layer": endpoint["layer"].duplicate(true), "cell": endpoint["cell"].duplicate(),
				"body_rect": [int(endpoint["cell"][0]) - half, int(endpoint["cell"][1]) - half, side, side],
				"safety_rect": safety, "mask_cells": mask, "provenance": "required_connection_world_generation",
				"stage": "base_terrain", "after": "source_H0_and_underground_H1_fill",
				"before": ["static_liquids", "underground_resources", "poi_and_civilization", "trees_and_animals"],
				"clear_scope": "default_geological_rock_H1_only", "clear_default_rock_H1": true,
				"excluded_natural_population": ["liquids", "minerals", "trees", "ordinary_poi"],
				"clears_prefab_or_user_objects": false, "triggered_by_interaction": false
			})
	return result

func _cell_record(cell: Array, operation: Dictionary, component: Dictionary) -> Dictionary:
	var layer: Dictionary = operation["layer"]
	var assignment: Dictionary = _assignment(component["layout"], layer, cell)
	if assignment.is_empty():
		return {}
	var biome: Dictionary = _generation["biomes"][assignment["biome_id"]]
	var operation_id: String = operation["operation_id"]
	var object_ids: Array = []
	for instance in component["prefab_instances"]:
		for object in instance["objects"]:
			if object["layer"] == layer and _contains(object["rect"], cell):
				object_ids.append(object["instance_id"])
	object_ids.sort()
	var change_keys: Array = []
	var key: String = "%d|%d,%d" % [int(layer["depth"]), int(cell[0]), int(cell[1])]
	if component["layout"]["permanent_changes"].has(key):
		change_keys.append(key)
	var categories: Dictionary = {
		"biome": assignment,
		"source_ground": {"status": "resolved_source_H0", "plane": "H0", "resource_id": biome["ground_resource_id"], "source_cell": biome["source_cells"]["地面资源ID"], "occupied": true},
		"default_rock": {"status": "resolved_generated_clear", "plane": "H1", "resource_id": biome["default_rock_id"], "source_cell": biome["source_cells"]["普通岩石ID"], "initial_occupied": true, "initial_size_cells": [1, 1, 1], "initial_source": SOURCE_RULES["underground_before_carving"], "size_source": SOURCE_RULES["rock_occupancy"], "final_occupied": false, "removed_by_operation_id": operation_id},
		"generated_carve": {"status": "resolved_applied_generation_operation", "operation_ids": [operation_id], "clear_scope": "default_geological_rock_H1_only"},
		"caves": {"status": "resolved_required_opening", "final_height": 0, "operation_id": operation_id, "random_cave_topology_outside_scope": true},
		"natural_initial_animals": {"status": "resolved_no_initial_candidates", "candidate_ids": [], "source_range": "23_动物!F1:F9", "scope": "initial_natural_distribution_only", "carried_animals_prohibited": false, "future_dynamic_occupancy_resolved": false},
		"prefab": {"status": "resolved_existing_world_references", "object_instance_ids": object_ids, "cleared_by_stage": false},
		"permanent_changes": {"status": "resolved_existing_world_references", "change_keys": change_keys, "written_by_stage": false}
	}
	for category in ["liquids", "minerals", "trees", "ordinary_poi"]:
		categories[category] = {"status": "resolved_generation_exclusion", "source": SOURCE_RULES["protected_exclusions"], "operation_id": operation_id, "natural_initial_occupied": false}
	if int(layer["depth"]) == 2:
		categories["liquids"]["layer_prohibition_source"] = SOURCE_RULES["depth2_natural_liquids"]
	return {"cell": cell.duplicate(), "categories": categories}

static func _existing_references(component: Dictionary) -> Dictionary:
	var prefabs: Array = []
	for instance in component["prefab_instances"]:
		var objects: Array = []
		for object in instance["objects"]:
			objects.append({"instance_id": object["instance_id"], "object_sha256": digest(object), "layer": object["layer"].duplicate(true), "rect": object["rect"].duplicate(), "plane": object["plane"], "is_liquid": object["is_liquid"]})
		prefabs.append({"prefab_instance_id": instance["prefab_instance_id"], "instance_sha256": digest(instance), "objects": objects})
	return {"prefab_instances": prefabs, "permanent_changes": component["layout"]["permanent_changes"].duplicate(true), "stage_mutates_existing_world": false}

static func _completion(regions: Array) -> Dictionary:
	var count: int = 0
	var unresolved: int = 0
	for region in regions:
		for row in region["cells"]:
			count += 1
			var complete: bool = true
			for category in CATEGORIES:
				if not row["categories"].has(category) or row["categories"][category].get("status", "unknown") != RESOLVED_STATUS[category]:
					complete = false
			if not complete:
				unresolved += 1
	return {"scope": "declared_required_entry_initial_static_generation_only", "cell_count": count, "unresolved_cell_count": unresolved, "local_static_generation_complete": count > 0 and unresolved == 0, "global_terrain_complete": false, "native_ready": false, "dynamic_occupancy_resolved": false}

static func _report(artifact: Dictionary) -> Dictionary:
	var report: Dictionary = artifact["completion"].duplicate(true)
	report.merge({"ok": true, "code": "ENTRY_TERRAIN_LOCAL_STATIC_GENERATION_COMPLETE", "structure_valid": true, "artifact": artifact.duplicate(true), "formal_world_allowed": false, "native_clear_allowed": false, "transfer_allowed": false})
	return report

static func _valid_query(component: Dictionary, layer: Variant, cell: Variant) -> bool:
	if not Address.valid_layer(layer) or layer["world_id"] != component["layout"]["world_id"] or layer["body_instance_id"] != component["layout"]["body"]["required_instance_id"] or int(layer["depth"]) not in [0, 1, 2]:
		return false
	if not _supported_layer(component["layout"], layer):
		return false
	if not cell is Array or cell.size() != 2 or not Address.is_integer(cell[0]) or not Address.is_integer(cell[1]):
		return false
	var radius: int = int(component["layout"]["body"]["radius_cells"])
	# Doubled cell-center coordinates give an exact integer disc check.
	var x: int = int(cell[0])
	var y: int = int(cell[1])
	return x >= -radius and x < radius and y >= -radius and y < radius and (2 * x + 1) * (2 * x + 1) + (2 * y + 1) * (2 * y + 1) <= 4 * radius * radius

static func _supported_layer(plan: Dictionary, layer: Variant) -> bool:
	if not Address.valid_layer(layer):
		return false
	# A same-depth row is insufficient: the full address must already belong to
	# the validated spawn/endpoint set, and the site's same-layer set must exist.
	var supported: bool = _same_json_contract(layer, plan["spawn"]["layer"])
	for connection in plan["connections"]:
		for endpoint in connection["endpoints"]:
			if _same_json_contract(layer, endpoint["layer"]):
				supported = true
	if not supported:
		return false
	for site in plan["biome_sites"]:
		if site["map_kind"] == layer["map_kind"] and int(site["depth"]) == int(layer["depth"]):
			return true
	return false

static func digest(value: Variant) -> String:
	return JSON.stringify(value, "", true, true).sha256_text()

static func _fields(value: Variant, fields: Array) -> bool:
	if not value is Dictionary or value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true

static func _contains(bounds: Array, cell: Array) -> bool:
	return cell[0] >= bounds[0] and cell[1] >= bounds[1] and cell[0] < bounds[0] + bounds[2] and cell[1] < bounds[1] + bounds[3]

static func _intersects(a: Array, b: Array) -> bool:
	return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "structure_valid": false, "local_static_generation_complete": false, "global_terrain_complete": false, "formal_world_allowed": false, "native_clear_allowed": false, "transfer_allowed": false}

# Exact-safe expected-schema comparison, identical semantics to the verified
# bounded contract repair. Never rewrite caller data or normalize hash strings.
static func _same_json_contract(actual: Variant, expected: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	var kind: int = typeof(expected)
	if kind == TYPE_INT:
		if typeof(actual) == TYPE_INT:
			return actual == expected
		if typeof(actual) != TYPE_FLOAT or not is_finite(actual) or absf(actual) > float(MAX_JSON_EXACT_INTEGER) or expected < -MAX_JSON_EXACT_INTEGER or expected > MAX_JSON_EXACT_INTEGER:
			return false
		return actual == floor(actual) and int(actual) == expected
	if typeof(actual) != kind:
		return false
	if kind == TYPE_DICTIONARY:
		if actual.size() != expected.size():
			return false
		for key in expected:
			if not key is String or not actual.has(key) or not _same_json_contract(actual[key], expected[key], depth + 1):
				return false
		return true
	if kind == TYPE_ARRAY:
		if actual.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _same_json_contract(actual[index], expected[index], depth + 1):
				return false
		return true
	if kind == TYPE_FLOAT:
		return is_finite(actual) and is_finite(expected) and actual == expected
	return kind in [TYPE_NIL, TYPE_BOOL, TYPE_STRING] and actual == expected
