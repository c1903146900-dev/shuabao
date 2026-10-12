extends RefCounted
## Narrow rules shared by generation and verification of saved surface rows.
## The global-coordinate water field has no work-region or RNG input.
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const EntryStore = preload("res://scripts/terrain/required_entry_terrain_store.gd")
const CONTRACT := "011-surface-approach-static-terrain-v1"
const KIND := "surface_approach_static_generation_artifact"
const CATEGORIES := ["biome", "source_ground", "effective_H0", "liquids", "surface_geological_H1", "trees", "natural_initial_animals", "ordinary_poi", "prefab", "permanent_changes"]
const SOURCE_RULES := {
	"unique_base_H0_including_water": "cehua.docx:all-paragraph151-152",
	"static_liquids": "cehua.docx:body66/all-paragraph172",
	"protected_entry_exclusion": "cehua.docx:body69/all-paragraph175",
	"template_before_terrain": "cehua.docx:body74/all-paragraph180",
	"ground_ids": "32_Biome总表!X9:X12",
	"surface_random_geology_prohibition": "32_Biome总表!S9:S12,W9:W12",
	"liquid_targets_shapes": "37_生态区液体!G2:J4",
	"frozen_solid_no_liquid": "32_Biome总表!T12:V12",
	"bridge_crosses_water": "10_建材家具装饰!J54:J66"
}
var ready: bool = false
var last_error: String = ""
var settings: Dictionary = {}
var generation: Dictionary = {}
var _initial_input_digests: Dictionary = {}

func _init(generation_document: Dictionary, parameter_document: Dictionary) -> void:
	if not FileAccess.file_exists("res://data/surface_approach_settings011.json") or not FileAccess.file_exists("res://data/surface_approach_authorities011.json"):
		last_error = "SURFACE_APPROACH_PARAMETER_FILES_MISSING"
		return
	var raw: String = FileAccess.get_file_as_string("res://data/surface_approach_settings011.json")
	var authority: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_approach_authorities011.json"))
	if raw.is_empty() or not authority is Dictionary or not EntryStore._hash(authority.get("_projection_sha256")) or authority["_projection_sha256"] != raw.sha256_text() or not EntryStore._same(parameter_document, JSON.parse_string(raw)):
		last_error = "SURFACE_APPROACH_PARAMETERS_NOT_APPROVED"
		return
	if not EntryStore._same(parameter_document.get("sources"), generation_document.get("sources")) or not EntryStore._same(authority.get("sources"), generation_document.get("sources")) or not EntryStore._same(parameter_document.get("parameter_table_sha256"), authority.get("parameter_table_sha256")):
		last_error = "SURFACE_APPROACH_PARAMETER_SOURCE_MISMATCH"
		return
	if not _parameters_valid(parameter_document, generation_document):
		last_error = "SURFACE_APPROACH_PARAMETER_SCHEMA_OR_RANGE_INVALID"
		return
	settings = parameter_document.duplicate(true)
	generation = generation_document.duplicate(true)
	_initial_input_digests = {"settings": EntryStore.digest(settings), "generation": EntryStore.digest(generation)}
	_initial_input_digests.make_read_only()
	ready = true

func current_inputs_valid() -> bool:
	# Read-only generation/restore boundary check, not an actor-frame operation.
	# Do not trust a mutated or replaced settings/generation dictionary simply
	# because it was approved when this Rules instance was first constructed.
	if not ready or not _initial_input_digests.is_read_only():
		return false
	# Immutable constructor baseline also rejects jointly changed disk and active
	# inputs. A new approved version requires a new Rules/Store instance.
	if not Codec.encode(settings)["ok"] or not Codec.encode(generation)["ok"]:
		return false
	if EntryStore.digest(settings) != _initial_input_digests["settings"] or EntryStore.digest(generation) != _initial_input_digests["generation"]:
		return false
	for path in ["res://data/surface_approach_settings011.json", "res://data/surface_approach_authorities011.json", "res://data/generation_settings.json", "res://data/generation_authorities.json"]:
		if not FileAccess.file_exists(path):
			return false
	var parameter_raw: String = FileAccess.get_file_as_string("res://data/surface_approach_settings011.json")
	var generation_raw: String = FileAccess.get_file_as_string("res://data/generation_settings.json")
	var parameter_authority: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_approach_authorities011.json"))
	var generation_authority: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/generation_authorities.json"))
	if not parameter_authority is Dictionary or not generation_authority is Dictionary or not EntryStore._hash(parameter_authority.get("_projection_sha256")) or not EntryStore._hash(generation_authority.get("_projection_sha256")):
		return false
	if parameter_raw.sha256_text() != parameter_authority["_projection_sha256"] or generation_raw.sha256_text() != generation_authority["_projection_sha256"]:
		return false
	if not EntryStore._same(settings, JSON.parse_string(parameter_raw)) or not EntryStore._same(generation, JSON.parse_string(generation_raw)):
		return false
	return EntryStore._same(settings.get("sources"), generation.get("sources")) and EntryStore._same(parameter_authority.get("sources"), generation.get("sources")) and EntryStore._same(settings.get("parameter_table_sha256"), parameter_authority.get("parameter_table_sha256")) and _parameters_valid(settings, generation)

static func _parameters_valid(value: Dictionary, generation_document: Dictionary) -> bool:
	var fields: Array = ["schema_version", "artifact_kind", "version", "classification", "sources", "parameter_table_path", "parameter_table_sha256", "max_scope_cells", "basis_point_denominator", "permille_denominator", "pi_numerator", "pi_denominator", "water_identity", "population_scope", "profiles", "formal_world_allowed"]
	if not EntryStore._fields(value, fields) or not _integer_in(value["schema_version"], 1, 1) or not EntryStore._same(value["artifact_kind"], "technical_surface_approach_parameters") or not EntryStore._same(value["version"], "surface-approach-field-v1") or not EntryStore._same(value["classification"], "authorized_engineering_choice_not_original_algorithm") or not EntryStore._same(value["formal_world_allowed"], false):
		return false
	if not EntryStore._same(value["parameter_table_path"], "asset_sources/terrain/surface_approach_parameters011.csv") or not EntryStore._hash(value["parameter_table_sha256"]):
		return false
	for key in ["basis_point_denominator", "permille_denominator", "pi_numerator", "pi_denominator"]:
		var exact: int = {"basis_point_denominator": 10000, "permille_denominator": 1000, "pi_numerator": 355, "pi_denominator": 113}[key]
		if not _integer_in(value[key], exact, exact):
			return false
	if not _integer_in(value["max_scope_cells"], 1, 4096) or not EntryStore._same(value["population_scope"], {"trees": "technical_disabled", "natural_initial_animals": "technical_disabled", "ordinary_poi": "technical_disabled"}):
		return false
	var water: Variant = value["water_identity"]
	if not EntryStore._fields(water, ["liquid_type", "status", "material_association"]) or not EntryStore._same(water["liquid_type"], "普通水") or not EntryStore._same(water["status"], "source_named_H0_liquid_without_terrain_resource_id"):
		return false
	if not EntryStore._same(water["material_association"], {"item_id": "shui", "relation": "extracted_material_not_terrain_identity", "source_cells": ["shuzhi.xlsx:sheet02!A615:I615", "shuzhi.xlsx:sheet04!D100:I100", "shuzhi.xlsx:sheet07!B72:F72,R72"]}):
		return false
	var ids: Array = []
	for id in generation_document["biomes"]:
		if int(generation_document["biomes"][id]["depth"]) == 0:
			ids.append(id)
	if not EntryStore._fields(value["profiles"], ids):
		return false
	for id in ids:
		var profile: Variant = value["profiles"][id]
		var profile_fields: Array = ["version", "river_share_permille", "river_period_cells", "river_wave_cells", "river_meander_cells", "lake_width_cells", "lake_height_cells", "source_target_cell", "source_shape_cell", "classification"]
		if not EntryStore._fields(profile, profile_fields) or not EntryStore._same(profile["version"], value["version"]):
			return false
		for key in ["river_share_permille", "river_period_cells", "river_wave_cells", "river_meander_cells", "lake_width_cells", "lake_height_cells"]:
			var limits: Array = {"river_share_permille": [0, 1000], "river_period_cells": [16, 256], "river_wave_cells": [4, 512], "river_meander_cells": [0, 128], "lake_width_cells": [8, 128], "lake_height_cells": [8, 128]}[key]
			if not _integer_in(profile[key], limits[0], limits[1]):
				return false
		var biome: Dictionary = generation_document["biomes"][id]
		if biome.has("liquid_interface"):
			if not EntryStore._same(profile["source_target_cell"], biome["liquid_interface"]["source_cells"]["目标覆盖率"]) or not EntryStore._same(profile["source_shape_cell"], biome["liquid_interface"]["source_cells"]["主要形态"]) or not EntryStore._same(profile["classification"], "authorized_engineering_parameters_not_original_values"):
				return false
		elif not EntryStore._same(id, "x03_db_dongtu_bingyuan") or not EntryStore._same(profile["source_target_cell"], SOURCE_RULES["frozen_solid_no_liquid"]) or not EntryStore._same(profile["source_shape_cell"], SOURCE_RULES["frozen_solid_no_liquid"]) or not EntryStore._same(profile["classification"], "source_prohibits_liquid_solid_ice"):
			return false
	return true

static func _integer_in(value: Variant, minimum: int, maximum: int) -> bool:
	return Address.is_integer(value) and int(value) >= minimum and int(value) <= maximum

func scope(component: Dictionary) -> Dictionary:
	var layer: Dictionary = component["layout"]["spawn"]["layer"]
	var bounds: Array = []
	var entries: Array = []
	for instance in component["prefab_instances"]:
		for row in instance["layers"]:
			if EntryStore._same(row["address"], layer):
				bounds = _union(bounds, row["bounds"])
	for connection in component["layout"]["connections"]:
		for index in range(2):
			var endpoint: Dictionary = connection["endpoints"][index]
			if not EntryStore._same(endpoint["layer"], layer):
				continue
			var safety: Array = connection["safety_rect"].duplicate()
			bounds = _union(bounds, safety)
			entries.append({"connection_instance_id": connection["connection_instance_id"], "connection_sha256": EntryStore.digest(connection), "endpoint_index": index, "layer": layer.duplicate(true), "cell": endpoint["cell"].duplicate(), "safety_rect": safety, "body_side_cells": connection["body_side_cells"]})
	if bounds.is_empty() or entries.size() != 1 or int(bounds[2]) * int(bounds[3]) > int(settings["max_scope_cells"]):
		return {"ok": false, "code": "SURFACE_APPROACH_SCOPE_UNSUPPORTED"}
	return {"ok": true, "layer": layer.duplicate(true), "bounds": bounds, "entries": entries, "region_id": "surface_approach_" + EntryStore.digest([layer, bounds, entries]).substr(0, 32)}

func water_sample(plan: Dictionary, biome_id: String, cell: Array) -> Dictionary:
	var profile: Dictionary = settings["profiles"][biome_id]
	var biome: Dictionary = generation["biomes"][biome_id]
	var base: Dictionary = {"version": settings["version"], "biome_id": biome_id, "cell": cell.duplicate(), "coordinate_frame": "celestial_global_cells", "domain_dependent": false}
	if not biome.has("liquid_interface"):
		base.merge({"target_basis_points": 0, "river_rank": 0, "lake_rank": 0, "river_threshold": 0, "lake_threshold": 0, "candidate": false, "source_exclusion": SOURCE_RULES["frozen_solid_no_liquid"]})
		return base
	var target: int = roundi(float(biome["liquid_interface"]["target_percent"]) * 100.0)
	var river_threshold: int = _quotient(target * int(profile["river_share_permille"]), 1000)
	# Union correction: river and lake shares refer to the original target before
	# biome clipping, existing H0 and protected masks. Never enforce a local quota.
	var lake_threshold: int = _quotient((target - river_threshold) * 10000, 10000 - river_threshold)
	# plan.body.body_id is the actual source-bound LayoutValidator body record.
	var token: Array = [settings["version"], plan["seed_decimal"], plan["body"]["body_id"], biome_id]
	var period: int = int(profile["river_period_cells"])
	var wave: int = int(profile["river_wave_cells"])
	var phase_x: int = _word(token, "river_x", [0, 0]) % period
	var phase_y: int = _word(token, "river_y", [0, 0]) % wave
	var cycle: int = posmod(int(cell[1]) + phase_y, wave)
	var triangle: int = absi(2 * cycle - wave)
	var offset: int = _quotient((2 * triangle - wave) * int(profile["river_meander_cells"]), wave)
	var distance2: int = absi(posmod(2 * int(cell[0]) + 1 - 2 * (phase_x + offset) + period, 2 * period) - period)
	var river_rank: int = _quotient(distance2 * 10000, period)
	var width: int = int(profile["lake_width_cells"])
	var height: int = int(profile["lake_height_cells"])
	var tile: Array = [_quotient(int(cell[0]), width), _quotient(int(cell[1]), height)]
	var center_x2: int = 2 * int(tile[0]) * width + _quotient(width, 2) + _word(token, "lake_x", tile) % width
	var center_y2: int = 2 * int(tile[1]) * height + _quotient(height, 2) + _word(token, "lake_y", tile) % height
	var dx2: int = 2 * int(cell[0]) + 1 - center_x2
	var dy2: int = 2 * int(cell[1]) + 1 - center_y2
	var numerator: int = (dx2 * dx2 * height * height + dy2 * dy2 * width * width) * int(settings["pi_numerator"]) * 10000
	var denominator: int = 4 * width * width * height * height * int(settings["pi_denominator"])
	var lake_rank: int = _quotient(numerator, denominator)
	base.merge({"target_basis_points": target, "river_rank": river_rank, "lake_rank": lake_rank, "river_threshold": river_threshold, "lake_threshold": lake_threshold, "candidate": river_rank < river_threshold or lake_rank < lake_threshold, "source_exclusion": ""})
	return base

func cell_categories(component: Dictionary, scope_record: Dictionary, cell: Array, assignment: Dictionary, sample: Dictionary) -> Dictionary:
	var layer: Dictionary = scope_record["layer"]
	var biome: Dictionary = generation["biomes"][assignment["biome_id"]]
	var object_ids: Array = []
	var h0_objects: Array = []
	for instance in component["prefab_instances"]:
		for object in instance["objects"]:
			if EntryStore._same(object["layer"], layer) and EntryStore._contains(object["rect"], cell):
				object_ids.append(object["instance_id"])
				if object["plane"] == "H0":
					h0_objects.append(object)
	if h0_objects.size() > 1:
		return {}
	object_ids.sort()
	var protected_ids: Array = []
	for entry in scope_record["entries"]:
		if EntryStore._contains(entry["safety_rect"], cell):
			protected_ids.append(entry["connection_instance_id"])
	var exclusion: String = "existing_prefab_H0" if not h0_objects.is_empty() else ("required_entry_safety" if not protected_ids.is_empty() else str(sample["source_exclusion"]))
	var water: bool = sample["candidate"] and exclusion.is_empty()
	var ground: Dictionary = {"status": "resolved_source_ground_candidate", "resource_id": biome["ground_resource_id"], "source_cell": biome["source_cells"]["地面资源ID"], "plane": "H0", "effective": not water and h0_objects.is_empty()}
	var effective: Dictionary = {"status": "resolved_unique_H0", "kind": "source_ground", "plane": "H0", "content_id": biome["ground_resource_id"], "content_namespace": "formal_source", "object_instance_id": "", "source_name": "", "source_cell": biome["source_cells"]["地面资源ID"], "is_liquid": false}
	if not h0_objects.is_empty():
		var object: Dictionary = h0_objects[0]
		effective = {"status": "resolved_unique_H0", "kind": "existing_prefab", "plane": "H0", "content_id": object["content_id"], "content_namespace": object["content_namespace"], "object_instance_id": object["instance_id"], "source_name": "", "source_cell": "existing_validated_prefab", "is_liquid": object["is_liquid"]}
	elif water:
		# A named H0 kind is source-backed. Do not invent a stable resource ID or
		# reuse an inventory material ID as terrain until that mapping is reviewed.
		effective = {"status": "resolved_unique_H0", "kind": "source_static_water", "plane": "H0", "liquid_type": settings["water_identity"]["liquid_type"], "parameter_id": biome["liquid_interface"]["parameter_id"], "source_cells": biome["liquid_interface"]["source_cells"].duplicate(true), "material_association": settings["water_identity"]["material_association"].duplicate(true), "is_liquid": true}
	var categories: Dictionary = {
		"biome": assignment.duplicate(true), "source_ground": ground, "effective_H0": effective,
		"liquids": {"status": "resolved_static_field_composition", "sample": sample.duplicate(true), "candidate": sample["candidate"], "final_occupied": effective["is_liquid"], "exclusion": exclusion, "protected_connection_ids": protected_ids, "movement_policy": "unresolved_liquid_cannot_certify_actor_ground", "realtime_flow": false},
		"surface_geological_H1": {"status": "source_prohibits_random_geological_H1", "instance_ids": [], "source": biome["source_cells"]["地表高度1生成许可"]},
		"prefab": {"status": "resolved_existing_world_references", "object_instance_ids": object_ids, "cleared_by_stage": false},
		"permanent_changes": {"status": "resolved_existing_world_references", "change_keys": [], "written_by_stage": false}
	}
	for category in ["trees", "natural_initial_animals", "ordinary_poi"]:
		categories[category] = {"status": "disabled_by_technical_profile", "instance_ids": [], "original_prohibition": false, "profile_version": settings["version"]}
	return categories

static func counts(regions: Array) -> Dictionary:
	var result: Dictionary = {"cell_count": 0, "existing_prefab_H0_cells": 0, "new_surface_cells": 0, "source_ground_cells": 0, "water_cells": 0, "water_candidate_cells": 0, "prefab_suppressed_water_cells": 0, "entry_suppressed_water_cells": 0}
	for region in regions:
		for row in region["cells"]:
			var cats: Dictionary = row["categories"]
			result["cell_count"] += 1
			if cats["effective_H0"]["kind"] == "existing_prefab":
				result["existing_prefab_H0_cells"] += 1
			else:
				result["new_surface_cells"] += 1
			if cats["effective_H0"]["kind"] == "source_ground":
				result["source_ground_cells"] += 1
			if cats["effective_H0"]["is_liquid"]:
				result["water_cells"] += 1
			if cats["liquids"]["candidate"]:
				result["water_candidate_cells"] += 1
				if cats["liquids"]["exclusion"] == "existing_prefab_H0":
					result["prefab_suppressed_water_cells"] += 1
				elif cats["liquids"]["exclusion"] == "required_entry_safety":
					result["entry_suppressed_water_cells"] += 1
	return result

static func _word(token: Array, domain: String, tile: Array) -> int:
	return JSON.stringify([token, domain, tile], "", true, true).sha256_text().substr(0, 8).hex_to_int()

static func _quotient(numerator: int, denominator: int) -> int:
	return floori(float(numerator) / float(denominator))

static func _union(a: Array, b: Array) -> Array:
	if a.is_empty():
		return b.duplicate()
	var x: int = mini(int(a[0]), int(b[0]))
	var y: int = mini(int(a[1]), int(b[1]))
	return [x, y, maxi(int(a[0] + a[2]), int(b[0] + b[2])) - x, maxi(int(a[1] + a[3]), int(b[1] + b[3])) - y]
