extends RefCounted
## Detached source-contract candidate. This is not final terrain or a native-clear
## certificate. No generator, runtime, physics, scene, save or F integration.
const Address = preload("res://scripts/world/spatial_address.gd")
const World = preload("res://scripts/world_session/world_component.gd")
const Inputs = preload("res://scripts/worldgen/generation_inputs.gd")
const CONTRACT := "011-detached-required-entry-terrain-v2"
const KIND := "technical_bounded_terrain_contract"
# Operational contract limits and inspection ring, never gameplay balance values.
const MAX_JSON_EXACT_INTEGER: int = 9007199254740991
const MAX_CELLS := 4096
const RING_CELLS := 1
const CATEGORIES := ["biome", "source_ground", "default_rock", "generated_carve", "prefab", "permanent_changes", "caves", "liquids", "resources", "trees", "animals", "ordinary_poi"]
const FIELDS := ["schema_version", "artifact_kind", "contract", "sources", "bindings", "source_rules", "biome_inputs", "operations", "regions", "formal_world_allowed", "native_clear_allowed", "transfer_allowed", "artifact_sha256"]
const REGION_FIELDS := ["region_id", "scope", "layer", "layer_sha256", "bounds", "endpoint_keys", "cells"]
const SOURCE_RULES := {
	"underground_before_carving": "cehua.docx:body65",
	"same_xy_paired_entries": "cehua.docx:body68",
	"protected_exclusions": "cehua.docx:body69",
	"required_entry_guarantees": "cehua.docx:body70",
	"generation_order": "cehua.docx:body74",
	"fail_closed": "cehua.docx:body75",
	"entry_footprints": ["38_层间连接!O6:P6", "38_层间连接!O7:P7"],
	"biome_ground_and_rock": "32_Biome总表!X9:Y17",
	"surface_h1_permission": ["32_Biome总表!S9:S12", "32_Biome总表!W9:W12"],
	"rock_occupancy": "shuzhi.xlsx:sheet145!F2",
	"mother_surface_natural_minerals_forbidden": ["32_Biome总表!N9:N12", "32_Biome总表!S9:S12", "32_Biome总表!W9:W12"],
	"natural_liquid_layer_permissions": "36_层级液体许可!C8:G10"
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
	# Only inspect already materialized WorldComponent data. No generation call.
	if not ready:
		return _bad("TERRAIN_INPUTS_NOT_READY")
	var checked: Dictionary = _world.validate_component(value, expected_world_id)
	if not checked["ok"]:
		return _bad("TERRAIN_WORLD_INVALID:" + str(checked["code"]))
	var component: Dictionary = checked["component"]
	var plan: Dictionary = component["layout"]
	var operations: Array = _operations(plan)
	var regions: Array = _regions(component, operations)
	var total: int = 0
	for region in regions:
		var bounds: Array = region["bounds"]
		total += int(bounds[2]) * int(bounds[3])
		if total > MAX_CELLS:
			return _bad("TERRAIN_BOUNDED_SCOPE_LIMIT")
	# The first contract refuses overlapping same-layer work regions. It must not
	# double-count coverage or merge disjoint entry openings into a fake tunnel.
	for index in range(regions.size()):
		for previous in range(index):
			if regions[index]["layer"] == regions[previous]["layer"] and _intersects(regions[index]["bounds"], regions[previous]["bounds"]):
				return _bad("TERRAIN_REGION_OVERLAP_UNSUPPORTED")
	for region in regions:
		var bounds: Array = region["bounds"]
		for y in range(int(bounds[1]), int(bounds[1] + bounds[3])):
			for x in range(int(bounds[0]), int(bounds[0] + bounds[2])):
				region["cells"].append(_cell_record([x, y], region["layer"], component, operations, _generation))
	var artifact: Dictionary = {
		"schema_version": 1, "artifact_kind": KIND, "contract": CONTRACT,
		"sources": _generation["sources"].duplicate(true),
		"bindings": {
			"world_id": expected_world_id, "world_sha256": digest(component),
			"bundle_sha256": component["bundle_sha256"],
			"layout_sha256": digest(plan), "core_layout_fingerprint": plan["core_layout_fingerprint"],
			"permanent_changes_sha256": digest(plan["permanent_changes"]),
			"generation_stages_sha256": digest(plan["generation_stages"]),
			"generation_version": plan["generation_version"],
			"generation_document_sha256": _input_bindings["generation_document_sha256"],
			"prefab_document_sha256": _input_bindings["prefab_document_sha256"]
		},
		"source_rules": SOURCE_RULES.duplicate(true),
		# Preserve reviewed IDs/source cells and null area/cave/density inputs.
		# These are options, never a per-cell assignment or an empty default.
		"biome_inputs": _generation["biomes"].duplicate(true),
		"operations": operations, "regions": regions,
		"formal_world_allowed": false, "native_clear_allowed": false, "transfer_allowed": false
	}
	artifact["artifact_sha256"] = digest(artifact)
	return _report(artifact)

func validate(value: Variant, component: Variant, expected_world_id: String) -> Dictionary:
	if not _fields(value, FIELDS):
		return _bad("TERRAIN_SCHEMA_INVALID")
	if not Address.is_integer(value["schema_version"]) or value["schema_version"] != 1 or value["artifact_kind"] != KIND or value["contract"] != CONTRACT:
		return _bad("TERRAIN_VERSION_UNSUPPORTED")
	for flag in ["formal_world_allowed", "native_clear_allowed", "transfer_allowed"]:
		if typeof(value[flag]) != TYPE_BOOL or value[flag]:
			return _bad("TERRAIN_CERTIFICATION_FORBIDDEN")
	var made: Dictionary = materialize(component, expected_world_id)
	if not made["ok"]:
		return made
	var expected: Dictionary = made["artifact"]
	if not _same_json_contract(value["sources"], expected["sources"]) or not _same_json_contract(value["source_rules"], expected["source_rules"]) or not _same_json_contract(value["biome_inputs"], expected["biome_inputs"]):
		return _bad("TERRAIN_SOURCE_MISMATCH")
	if not _same_json_contract(value["bindings"], expected["bindings"]):
		return _bad("TERRAIN_WORLD_BINDING_MISMATCH")
	if not _same_json_contract(value["operations"], expected["operations"]):
		return _bad("TERRAIN_CONNECTION_OPERATION_MISMATCH")
	if not value["regions"] is Array or value["regions"].size() != expected["regions"].size():
		return _bad("TERRAIN_REGION_COVERAGE_INVALID")
	for index in range(expected["regions"].size()):
		var region: Variant = value["regions"][index]
		var target: Dictionary = expected["regions"][index]
		if not _fields(region, REGION_FIELDS):
			return _bad("TERRAIN_REGION_FIELDS_INVALID")
		if not _same_json_contract(region["layer"], target["layer"]) or region["layer_sha256"] != target["layer_sha256"]:
			return _bad("TERRAIN_LAYER_BINDING_MISMATCH")
		for key in ["region_id", "scope", "bounds", "endpoint_keys"]:
			if not _same_json_contract(region[key], target[key]):
				return _bad("TERRAIN_REGION_COVERAGE_INVALID")
		if not region["cells"] is Array or region["cells"].size() != target["cells"].size():
			return _bad("TERRAIN_CELL_COVERAGE_INVALID")
		for cell_index in range(target["cells"].size()):
			var row: Variant = region["cells"][cell_index]
			var target_row: Dictionary = target["cells"][cell_index]
			if not _fields(row, ["cell", "categories"]) or not _same_json_contract(row["cell"], target_row["cell"]):
				return _bad("TERRAIN_CELL_COVERAGE_INVALID")
			if not _fields(row["categories"], CATEGORIES):
				return _bad("TERRAIN_CATEGORY_COVERAGE_INVALID")
			for category in CATEGORIES:
				if not _same_json_contract(row["categories"][category], target_row["categories"][category]):
					return _bad("TERRAIN_CATEGORY_SEMANTICS_INVALID")
	# Compare the canonical expected digest, not a caller-rehashed altered record.
	if value["artifact_sha256"] != expected["artifact_sha256"]:
		return _bad("TERRAIN_ARTIFACT_FINGERPRINT_MISMATCH")
	return _report(expected)

func require_complete(value: Variant, component: Variant, expected_world_id: String) -> Dictionary:
	var checked: Dictionary = validate(value, component, expected_world_id)
	if not checked["ok"]:
		return checked
	# This version deliberately has no external 'resolved fixture' bypass.
	checked["ok"] = false
	checked["code"] = "TERRAIN_REQUIRED_CATEGORIES_UNRESOLVED"
	checked.erase("artifact")
	return checked

static func _operations(plan: Dictionary) -> Array:
	var result: Array = []
	for connection in plan["connections"]:
		for index in range(2):
			var endpoint: Dictionary = connection["endpoints"][index]
			var key: String = connection["connection_instance_id"] + "|" + str(index)
			var underground: bool = int(endpoint["layer"]["depth"]) > 0
			var side: int = int(connection["body_side_cells"])
			var half: int = (side - 1) >> 1
			var safety: Array = connection["safety_rect"].duplicate()
			var mask: Array = []
			for y in range(int(safety[1]), int(safety[1] + safety[3])):
				for x in range(int(safety[0]), int(safety[0] + safety[2])):
					mask.append([x, y])
			result.append({
				"operation_id": "entry_protection_" + key.sha256_text().substr(0, 32),
				"endpoint_key": key, "connection_instance_id": connection["connection_instance_id"],
				"connection_sha256": digest(connection), "endpoint_index": index,
				"layer": endpoint["layer"].duplicate(true), "cell": endpoint["cell"].duplicate(),
				"body_rect": [int(endpoint["cell"][0]) - half, int(endpoint["cell"][1]) - half, side, side],
				"safety_rect": safety, "mask_cells": mask,
				"provenance": "required_connection_world_generation_contract",
				"stage": "base_terrain", "after": "underground_H1_fill" if underground else "required_entry_reservation",
				"before": ["static_liquids", "underground_resources", "poi_and_civilization", "trees_and_animals"],
				"clear_default_rock_H1": underground,
				"excluded_population": ["liquids", "resources", "trees", "ordinary_poi"]
			})
	return result

static func _regions(component: Dictionary, operations: Array) -> Array:
	var result: Array = []
	# Surface union is an inspection scope only. It does not assert an approach,
	# traversable corridor, empty H1 or native coverage between the two bounds.
	var surface_layer: Dictionary = component["layout"]["spawn"]["layer"]
	var surface_bounds: Array = []
	var surface_keys: Array = []
	for instance in component["prefab_instances"]:
		for layer in instance["layers"]:
			if layer["address"] == surface_layer:
				surface_bounds = _union(surface_bounds, layer["bounds"])
	for operation in operations:
		if operation["layer"] == surface_layer:
			surface_bounds = _union(surface_bounds, operation["safety_rect"])
			surface_keys.append(operation["endpoint_key"])
	result.append(_region("surface_prefab_and_entry_inspection", surface_layer, surface_bounds, surface_keys))
	for operation in operations:
		if int(operation["layer"]["depth"]) > 0:
			var safety: Array = operation["safety_rect"]
			var bounds: Array = [int(safety[0]) - RING_CELLS, int(safety[1]) - RING_CELLS, int(safety[2]) + 2 * RING_CELLS, int(safety[3]) + 2 * RING_CELLS]
			result.append(_region("underground_entry_and_unknown_ring", operation["layer"], bounds, [operation["endpoint_key"]]))
	return result

static func _region(scope: String, layer: Dictionary, bounds: Array, endpoint_keys: Array) -> Dictionary:
	return {"region_id": "terrain_region_" + digest([scope, layer, bounds, endpoint_keys]).substr(0, 32), "scope": scope, "layer": layer.duplicate(true), "layer_sha256": digest(layer), "bounds": bounds, "endpoint_keys": endpoint_keys, "cells": []}

static func _cell_record(cell: Array, layer: Dictionary, component: Dictionary, operations: Array, generation: Dictionary) -> Dictionary:
	var protection_ids: Array = []
	var carve_ids: Array = []
	for operation in operations:
		if operation["layer"] == layer and _contains(operation["safety_rect"], cell):
			protection_ids.append(operation["operation_id"])
			if operation["clear_default_rock_H1"]:
				carve_ids.append(operation["operation_id"])
	var object_ids: Array = []
	for instance in component["prefab_instances"]:
		for object in instance["objects"]:
			if object["layer"] == layer and _contains(object["rect"], cell):
				object_ids.append(object["instance_id"])
	var permanent_keys: Array = []
	var key: String = "%d|%d,%d" % [int(layer["depth"]), int(cell[0]), int(cell[1])]
	# WorldComponent -> LayoutValidator has already required the exact three
	# fields and typed cleared_default_rock=true; arbitrary actions never reach here.
	if component["layout"]["permanent_changes"].has(key):
		permanent_keys.append(key)
	var rock: Dictionary = {"status": "not_applicable", "reason": "SURFACE_HAS_NO_DEFAULT_GEOLOGICAL_H1"}
	if int(layer["depth"]) > 0:
		rock = _unknown("PER_CELL_DEFAULT_ROCK_ID_UNRESOLVED")
		rock["initial_H1"] = "source_required_occupied_before_carving"
		rock["resource_id"] = null
		rock["after_required_carve"] = "cleared_by_required_entry" if not carve_ids.is_empty() else "initial_rock_until_unresolved_later_stages"
		rock["after_saved_permanent_change"] = "cleared_default_rock" if not permanent_keys.is_empty() else "no_recorded_change"
	var categories: Dictionary = {
		"biome": _unknown("PER_CELL_BIOME_UNRESOLVED"),
		"source_ground": _unknown("PER_CELL_SOURCE_GROUND_UNRESOLVED"),
		"default_rock": rock,
		"generated_carve": {"status": "resolved_contract", "operation_ids": carve_ids},
		"prefab": {"status": "resolved_existing_world", "object_instance_ids": object_ids},
		"permanent_changes": {"status": "resolved_existing_world", "change_keys": permanent_keys},
		"caves": _unknown("FINAL_CAVE_OCCUPANCY_UNRESOLVED"),
		"animals": _unknown("ANIMAL_POPULATION_UNRESOLVED")
	}
	for category in ["liquids", "resources", "trees", "ordinary_poi"]:
		categories[category] = _unknown("OUTSIDE_PROTECTION_POPULATION_UNRESOLVED") if protection_ids.is_empty() else {"status": "resolved_protected_exclusion_contract", "operation_ids": protection_ids.duplicate()}
	# These are source-wide exclusions, not a fabricated completion of random
	# population stages. "resources" here is natural geological mineral nodes;
	# Prefab objects, player edits, trees and animals retain separate categories.
	if layer["map_kind"] == "surface" and int(layer["depth"]) == 0:
		categories["resources"] = {"status": "resolved_source_prohibition_contract", "source_cells": SOURCE_RULES["mother_surface_natural_minerals_forbidden"].duplicate(), "scope": "natural_geological_minerals_only"}
	for permission in generation["liquid_permissions"]:
		if permission["map_kind"] == layer["map_kind"] and int(permission["depth"]) == int(layer["depth"]) and permission["allowed"] == false:
			categories["liquids"] = {"status": "resolved_layer_prohibition_contract", "source_cells": permission["source_cells"].duplicate(true), "scope": "natural_liquids_only"}
	return {"cell": cell.duplicate(), "categories": categories}

static func _report(artifact: Dictionary) -> Dictionary:
	var unknown: Dictionary = {}
	for category in CATEGORIES:
		unknown[category] = 0
	var count: int = 0
	var unresolved_cells: int = 0
	for region in artifact["regions"]:
		for row in region["cells"]:
			count += 1
			var unresolved: bool = false
			for category in CATEGORIES:
				if row["categories"][category]["status"] == "unknown":
					unknown[category] += 1
					unresolved = true
			if unresolved:
				unresolved_cells += 1
	return {"ok": true, "code": "TERRAIN_STRUCTURE_VALID_INCOMPLETE", "structure_valid": true, "occupancy_complete": false, "cell_count": count, "unresolved_cell_count": unresolved_cells, "unknown_by_category": unknown, "artifact": artifact.duplicate(true), "formal_world_allowed": false, "native_clear_allowed": false, "transfer_allowed": false}

static func digest(value: Variant) -> String:
	return JSON.stringify(value, "", true, true).sha256_text()

static func _unknown(reason: String) -> Dictionary:
	return {"status": "unknown", "reason": reason}

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

static func _union(a: Array, b: Array) -> Array:
	if a.is_empty():
		return b.duplicate()
	var x: int = mini(int(a[0]), int(b[0]))
	var y: int = mini(int(a[1]), int(b[1]))
	return [x, y, maxi(int(a[0] + a[2]), int(b[0] + b[2])) - x, maxi(int(a[1] + a[3]), int(b[1] + b[3])) - y]

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "structure_valid": false, "occupancy_complete": false, "formal_world_allowed": false, "native_clear_allowed": false, "transfer_allowed": false}

# Compare against the already validated, deterministically produced schema tree.
# Only positions whose expected value is an int admit JSON's float encoding of
# an exact safe integer. Float-valued source fields never receive coercion or
# tolerance; fingerprints remain the unchanged strings from expected records.
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
