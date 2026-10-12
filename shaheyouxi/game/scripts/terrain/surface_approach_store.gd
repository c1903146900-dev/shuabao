extends RefCounted
## Independent exact-record surface store. Never calls Stage or creates missing
## terrain; mathematical provenance checks verify the existing saved rows only.
const EntryStore = preload("res://scripts/terrain/required_entry_terrain_store.gd")
const Rules = preload("res://scripts/terrain/surface_approach_rules.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const FORMAT := "surface_approach_terrain_record_store_v1"
const MAX_BYTES: int = 4194304
const FIELDS := ["schema_version", "artifact_kind", "contract", "sources", "source_rules", "settings", "biome_algorithm", "bindings", "entries", "regions", "existing_world_references", "counts", "completion", "outside_scope", "dynamic_occupancy", "formal_world_allowed", "native_clear_allowed", "transfer_allowed", "artifact_sha256"]
const REGION_FIELDS := ["region_id", "scope", "layer", "layer_sha256", "bounds", "cells"]
const COMPLETION := {"local_static_generation_complete": true, "scope": "bounded_surface_technical_population_profile", "global_terrain_complete": false, "liquid_actor_movement_policy_resolved": false, "native_ready": false, "dynamic_occupancy_resolved": false}
const OUTSIDE := {"status": "unknown", "implicit_air": false, "implicit_wall": false, "automatic_extension": false}
const DYNAMIC := {"status": "unknown", "cleared_by_stage": false}
var ready: bool = false
var last_error: String = ""
var _base: RefCounted
var _rules: RefCounted

func _init(generation: Dictionary, prefab: Dictionary, bundle: Dictionary, settings: Dictionary = {}) -> void:
	_base = EntryStore.new(generation, prefab, bundle)
	if not _base.ready:
		last_error = _base.last_error
		return
	var parameters: Dictionary = settings
	if parameters.is_empty():
		if not FileAccess.file_exists("res://data/surface_approach_settings011.json"):
			last_error = "SURFACE_APPROACH_PARAMETERS_MISSING"
			return
		var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_approach_settings011.json"))
		if not loaded is Dictionary:
			last_error = "SURFACE_APPROACH_PARAMETERS_MISSING"
			return
		parameters = loaded
	_rules = Rules.new(generation, parameters)
	if not _rules.ready:
		last_error = _rules.last_error
		return
	ready = true

func restore(artifact: Variant, component: Variant, world_id: String) -> Dictionary:
	if artifact == null:
		return _bad("SURFACE_STORE_MISSING_ARTIFACT_NO_REGENERATION")
	if not ready:
		return _bad("SURFACE_STORE_INPUTS_NOT_READY")
	if not inputs_current():
		return _bad("SURFACE_STORE_APPROVED_INPUT_DRIFT")
	var bounded: Dictionary = Codec.encode(artifact)
	if not bounded["ok"] or JSON.stringify(bounded.get("value"), "", true, true).to_utf8_buffer().size() > MAX_BYTES:
		return _bad("SURFACE_STORE_LIMIT_OR_TYPE_INVALID")
	if not EntryStore._fields(artifact, FIELDS):
		return _bad("SURFACE_STORE_ARTIFACT_FIELDS_INVALID")
	if not EntryStore._same(artifact["schema_version"], 1) or not EntryStore._same(artifact["artifact_kind"], Rules.KIND) or not EntryStore._same(artifact["contract"], Rules.CONTRACT):
		return _bad("SURFACE_STORE_VERSION_UNSUPPORTED_NO_MIGRATION")
	for flag in ["formal_world_allowed", "native_clear_allowed", "transfer_allowed"]:
		if not EntryStore._same(artifact[flag], false):
			return _bad("SURFACE_STORE_CERTIFICATION_FORBIDDEN")
	for key in ["sources", "source_rules", "settings", "biome_algorithm"]:
		var expected: Variant = {"sources": _base._generation["sources"], "source_rules": Rules.SOURCE_RULES, "settings": _rules.settings, "biome_algorithm": EntryStore.ALGORITHM}[key]
		if not EntryStore._same(artifact[key], expected):
			return _bad("SURFACE_STORE_SOURCE_OR_PARAMETERS_MISMATCH")
	var world: Dictionary = _base._checked_world(component, world_id)
	if not world["ok"]:
		return _bad("SURFACE_STORE_WORLD_INVALID:" + str(world["code"]))
	var existing: Dictionary = world["component"]
	var scope: Dictionary = _rules.scope(existing)
	if not scope["ok"]:
		return _bad(scope["code"])
	if not EntryStore._same(artifact["bindings"], bindings(existing)) or not EntryStore._same(artifact["entries"], scope["entries"]):
		return _bad("SURFACE_STORE_WORLD_OR_ENTRY_BINDING_MISMATCH")
	if not artifact["regions"] is Array or artifact["regions"].size() != 1:
		return _bad("SURFACE_STORE_REGION_COVERAGE_INVALID")
	var region: Variant = artifact["regions"][0]
	if not EntryStore._fields(region, REGION_FIELDS):
		return _bad("SURFACE_STORE_REGION_FIELDS_INVALID")
	var region_header: Dictionary = {"region_id": scope["region_id"], "scope": "surface_prefab_actual_entry_bounding_union", "layer": scope["layer"], "layer_sha256": EntryStore.digest(scope["layer"]), "bounds": scope["bounds"]}
	for field in region_header:
		if not EntryStore._same(region[field], region_header[field]):
			return _bad("SURFACE_STORE_REGION_BINDING_INVALID")
	var bounds: Array = scope["bounds"]
	var count: int = int(bounds[2]) * int(bounds[3])
	if not region["cells"] is Array or region["cells"].size() != count:
		return _bad("SURFACE_STORE_CELL_COVERAGE_INVALID")
	for index in range(count):
		var row: Variant = region["cells"][index]
		var cell: Array = [int(bounds[0]) + index % int(bounds[2]), int(bounds[1]) + Rules._quotient(index, int(bounds[2]))]
		if not EntryStore._fields(row, ["cell", "categories"]) or not EntryStore._same(row["cell"], cell) or not EntryStore._fields(row["categories"], Rules.CATEGORIES):
			return _bad("SURFACE_STORE_CELL_OR_CATEGORY_COVERAGE_INVALID")
		var cats: Dictionary = row["categories"]
		if not _base._assignment_valid(cats["biome"], existing["layout"], scope["layer"], cell):
			return _bad("SURFACE_STORE_BIOME_ASSIGNMENT_INVALID")
		# Verify only this existing row's saved water sample. This never returns a
		# replacement row or fills omitted cells; corrupt samples fail before use.
		var sample: Dictionary = _rules.water_sample(existing["layout"], cats["biome"]["biome_id"], cell)
		var expected_categories: Dictionary = _rules.cell_categories(existing, scope, cell, cats["biome"], sample)
		if expected_categories.is_empty() or not EntryStore._same(cats, expected_categories):
			return _bad("SURFACE_STORE_CELL_SEMANTICS_INVALID")
	if not _base._references_valid(artifact["existing_world_references"], existing):
		return _bad("SURFACE_STORE_EXISTING_WORLD_REFERENCES_INVALID")
	for key in ["counts", "completion", "outside_scope", "dynamic_occupancy"]:
		var expected: Variant = {"counts": Rules.counts(artifact["regions"]), "completion": COMPLETION, "outside_scope": OUTSIDE, "dynamic_occupancy": DYNAMIC}[key]
		if not EntryStore._same(artifact[key], expected):
			return _bad("SURFACE_STORE_SCOPE_OR_COUNTS_INVALID")
	if not EntryStore._hash(artifact["artifact_sha256"]):
		return _bad("SURFACE_STORE_ARTIFACT_CHECKSUM_MISMATCH")
	var unhashed: Dictionary = artifact.duplicate(true)
	unhashed.erase("artifact_sha256")
	if EntryStore.digest(unhashed) != artifact["artifact_sha256"]:
		return _bad("SURFACE_STORE_ARTIFACT_CHECKSUM_MISMATCH")
	return {"ok": true, "code": "SURFACE_STORE_RESTORED_EXISTING_RECORDS", "artifact": artifact.duplicate(true), "formal_world_allowed": false, "native_clear_allowed": false, "transfer_allowed": false}

func inputs_current() -> bool:
	return ready and _rules != null and _rules.get_script() == Rules and _rules.current_inputs_valid() and EntryStore._same(_base._generation, _rules.generation)

func bindings(component: Dictionary) -> Dictionary:
	var plan: Dictionary = component["layout"]
	return {"world_id": plan["world_id"], "world_sha256": EntryStore.digest(component), "layout_sha256": EntryStore.digest(plan), "core_layout_fingerprint": plan["core_layout_fingerprint"], "bundle_sha256": component["bundle_sha256"], "permanent_changes_sha256": EntryStore.digest(plan["permanent_changes"]), "generation_stages_sha256": EntryStore.digest(plan["generation_stages"]), "generation_document_sha256": EntryStore.digest(_base._generation), "prefab_document_sha256": EntryStore.digest(_base._prefab), "settings_sha256": EntryStore.digest(_rules.settings)}

func encode(artifact: Variant, component: Variant, world_id: String) -> Dictionary:
	var checked: Dictionary = restore(artifact, component, world_id)
	if not checked["ok"]:
		return checked
	var tagged: Dictionary = Codec.encode(checked["artifact"])
	if not tagged["ok"]:
		return _bad(tagged["code"])
	var payload: String = JSON.stringify(tagged["value"], "", true, true)
	var bytes: PackedByteArray = JSON.stringify([FORMAT, Codec.FORMAT, world_id, payload, payload.sha256_text()], "", true, true).to_utf8_buffer()
	if bytes.size() > MAX_BYTES:
		return _bad("SURFACE_STORE_SIZE_LIMIT")
	return {"ok": true, "bytes": bytes}

func decode(bytes: Variant, component: Variant, world_id: String) -> Dictionary:
	if not bytes is PackedByteArray:
		return _bad("SURFACE_STORE_BYTES_REQUIRED")
	if bytes.is_empty():
		return _bad("SURFACE_STORE_MISSING_ARTIFACT_NO_REGENERATION")
	if bytes.size() > MAX_BYTES or not EntryStore._valid_utf8(bytes):
		return _bad("SURFACE_STORE_BYTES_LIMIT_OR_UTF8_INVALID")
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK:
		return _bad("SURFACE_STORE_JSON_INVALID")
	var envelope: Variant = parser.data
	if not envelope is Array or envelope.size() != 5:
		return _bad("SURFACE_STORE_OLD_OR_INVALID_ENVELOPE_NO_MIGRATION")
	for value in envelope:
		if typeof(value) != TYPE_STRING:
			return _bad("SURFACE_STORE_ENVELOPE_TYPE_INVALID")
	if envelope[0] != FORMAT or envelope[1] != Codec.FORMAT or envelope[2] != world_id:
		return _bad("SURFACE_STORE_IDENTITY_MISMATCH_NO_MIGRATION")
	if not EntryStore._hash(envelope[4]) or envelope[3].sha256_text() != envelope[4]:
		return _bad("SURFACE_STORE_CHECKSUM_MISMATCH")
	if parser.parse(envelope[3]) != OK:
		return _bad("SURFACE_STORE_PAYLOAD_JSON_INVALID")
	var decoded: Dictionary = Codec.decode(parser.data)
	if not decoded["ok"]:
		return _bad(decoded["code"])
	return restore(decoded["value"], component, world_id)

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "formal_world_allowed": false, "native_clear_allowed": false, "transfer_allowed": false, "migration_route_available": false, "regeneration_allowed": false}
