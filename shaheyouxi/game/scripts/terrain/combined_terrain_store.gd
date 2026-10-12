extends RefCounted
## Explicit composition of the two complete stored terrain records. Restore has
## no Stage dependency and never fills, upgrades or generates either component.
const EntryStore = preload("res://scripts/terrain/required_entry_terrain_store.gd")
const SurfaceStore = preload("res://scripts/terrain/surface_approach_store.gd")
const SurfaceRules = preload("res://scripts/terrain/surface_approach_rules.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const CONTRACT := "011-surface-and-required-entry-terrain-v1"
const KIND := "combined_surface_required_entry_terrain"
const FORMAT := "combined_surface_required_entry_record_store_v1"
const MAX_BYTES: int = 4194304
const FIELDS := ["schema_version", "artifact_kind", "contract", "sources", "bindings", "components", "counts", "completion", "formal_world_allowed", "native_clear_allowed", "transfer_allowed", "artifact_sha256"]
const SHARED_BINDINGS := ["world_id", "world_sha256", "layout_sha256", "core_layout_fingerprint", "bundle_sha256", "permanent_changes_sha256", "generation_stages_sha256", "generation_document_sha256", "prefab_document_sha256"]
const COMPLETION := {"scope": "bounded_surface_and_required_underground_entry_initial_static_generation", "local_static_generation_complete": true, "global_terrain_complete": false, "native_ready": false, "dynamic_occupancy_resolved": false, "liquid_actor_movement_policy_resolved": false, "outside_declared_regions": "unknown", "implicit_air": false, "implicit_wall": false}
var ready: bool = false
var last_error: String = ""
# These are the actual validating services, not facade copies for a future lease.
var _entry_store: RefCounted
var _surface_store: RefCounted
var _initial_input_digests: Dictionary = {}
# One successful exact validation, local to this service instance. Strings retain
# scalar type/bits and dictionary order; no digest collision or object identity
# can grant a hit. Changed/unsupported inputs take the original complete path.
var _validated_artifact_encoding: String = ""
var _validated_component_encoding: String = ""
var _validated_world_id: String = ""
var full_restore_validations: int = 0
var exact_restore_cache_hits: int = 0

func _init(generation: Dictionary, prefab: Dictionary, bundle: Dictionary) -> void:
	_entry_store = EntryStore.new(generation, prefab, bundle)
	_surface_store = SurfaceStore.new(generation, prefab, bundle)
	if not _entry_store.ready or not _surface_store.ready:
		last_error = _entry_store.last_error if not _entry_store.ready else _surface_store.last_error
		return
	_initial_input_digests = _input_signature()
	if _initial_input_digests.is_empty():
		last_error = "COMBINED_TERRAIN_INPUT_SIGNATURE_INVALID"
		return
	_initial_input_digests.make_read_only()
	ready = true

func inputs_current() -> bool:
	if not ready or not _initial_input_digests.is_read_only() or _entry_store == null or _entry_store.get_script() != EntryStore or not _entry_store.ready or _surface_store == null or _surface_store.get_script() != SurfaceStore or not _surface_store.ready:
		return false
	if _surface_store._base == null or _surface_store._base.get_script() != EntryStore or not _surface_store._base.ready or not _surface_store.inputs_current():
		return false
	var actual: Dictionary = _input_signature()
	return not actual.is_empty() and EntryStore._same(actual, _initial_input_digests)

func restore(artifact: Variant, component: Variant, world_id: String) -> Dictionary:
	if artifact == null:
		return _bad("COMBINED_TERRAIN_MISSING_NO_GENERATION")
	if not inputs_current():
		return _bad("COMBINED_TERRAIN_INPUTS_NOT_READY_OR_DRIFTED")
	var bounded: Dictionary = Codec.encode(artifact)
	if not bounded["ok"]:
		return _bad("COMBINED_TERRAIN_LIMIT_OR_TYPE_INVALID")
	var artifact_encoding: String = JSON.stringify(bounded["value"], "", true, true)
	if artifact_encoding.to_utf8_buffer().size() > MAX_BYTES:
		return _bad("COMBINED_TERRAIN_LIMIT_OR_TYPE_INVALID")
	bounded.clear() # Release the temporary codec tree before child restore copies.
	var encoded_component: Dictionary = Codec.encode(component)
	var component_encoding: String = JSON.stringify(encoded_component["value"], "", true, true) if encoded_component["ok"] else ""
	encoded_component.clear()
	# inputs_current() and the existing artifact codec/size gates always precede
	# a hit. Never cache a failed validation or a component outside the codec.
	if not component_encoding.is_empty() and artifact_encoding == _validated_artifact_encoding and component_encoding == _validated_component_encoding and world_id == _validated_world_id:
		exact_restore_cache_hits += 1
		return _restored(artifact)
	full_restore_validations += 1
	if not EntryStore._fields(artifact, FIELDS):
		return _bad("TERRAIN_CONTRACT_INCOMPATIBLE")
	if not EntryStore._same(artifact["schema_version"], 1) or not EntryStore._same(artifact["artifact_kind"], KIND) or not EntryStore._same(artifact["contract"], CONTRACT):
		return _bad("TERRAIN_CONTRACT_INCOMPATIBLE")
	for flag in ["formal_world_allowed", "native_clear_allowed", "transfer_allowed"]:
		if not EntryStore._same(artifact[flag], false):
			return _bad("COMBINED_TERRAIN_CERTIFICATION_FORBIDDEN")
	if not EntryStore._same(artifact["sources"], _entry_store._generation["sources"]):
		return _bad("COMBINED_TERRAIN_SOURCE_MISMATCH")
	if not EntryStore._fields(artifact["components"], ["surface", "required_entries"]):
		return _bad("COMBINED_TERRAIN_BOTH_COMPONENTS_REQUIRED")
	# Every child validates all actual saved rows against this SAME world. Passing
	# a complete child never grants permission to manufacture a missing sibling.
	var surface: Dictionary = _surface_store.restore(artifact["components"]["surface"], component, world_id)
	if not surface["ok"]:
		return _bad("COMBINED_TERRAIN_SURFACE_INVALID:" + str(surface["code"]))
	var entries: Dictionary = _entry_store.restore(artifact["components"]["required_entries"], component, world_id)
	if not entries["ok"]:
		return _bad("COMBINED_TERRAIN_ENTRIES_INVALID:" + str(entries["code"]))
	var a: Dictionary = surface["artifact"]
	var b: Dictionary = entries["artifact"]
	for field in SHARED_BINDINGS:
		if not EntryStore._same(a["bindings"][field], b["bindings"][field]):
			return _bad("COMBINED_TERRAIN_CHILD_WORLD_OR_SOURCE_MISMATCH")
	if not EntryStore._same(artifact["bindings"], bindings_for(a, b)):
		return _bad("COMBINED_TERRAIN_BINDING_MISMATCH")
	if not EntryStore._same(artifact["counts"], counts_for(a, b)) or not EntryStore._same(artifact["completion"], COMPLETION):
		return _bad("COMBINED_TERRAIN_SCOPE_OR_COUNTS_INVALID")
	if not EntryStore._hash(artifact["artifact_sha256"]):
		return _bad("COMBINED_TERRAIN_ARTIFACT_CHECKSUM_MISMATCH")
	var unhashed: Dictionary = artifact.duplicate(true)
	unhashed.erase("artifact_sha256")
	if EntryStore.digest(unhashed) != artifact["artifact_sha256"]:
		return _bad("COMBINED_TERRAIN_ARTIFACT_CHECKSUM_MISMATCH")
	# Preserve the supplied typed records; never replace them with regenerated
	# or normalized rows. The two nested child artifacts remain byte-equivalent.
	if not component_encoding.is_empty():
		_validated_artifact_encoding = artifact_encoding
		_validated_component_encoding = component_encoding
		_validated_world_id = world_id
	return _restored(artifact)

static func _restored(artifact: Dictionary) -> Dictionary:
	# Always a new deep copy, including cache hits; callers cannot mutate the
	# input or a future result through a previously returned dictionary.
	return {"ok": true, "code": "COMBINED_TERRAIN_RESTORED_EXISTING_RECORDS", "artifact": artifact.duplicate(true), "formal_world_allowed": false, "native_clear_allowed": false, "transfer_allowed": false}

static func bindings_for(surface: Dictionary, entries: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in SHARED_BINDINGS:
		result[field] = surface["bindings"][field]
	result.merge({"surface_contract": surface["contract"], "surface_artifact_sha256": surface["artifact_sha256"], "surface_settings_sha256": surface["bindings"]["settings_sha256"], "required_entry_contract": entries["contract"], "required_entry_artifact_sha256": entries["artifact_sha256"]})
	return result

static func counts_for(surface: Dictionary, entries: Dictionary) -> Dictionary:
	var surface_cells: int = int(surface["counts"]["cell_count"])
	var entry_cells: int = int(entries["completion"]["cell_count"])
	return {"surface_cells": surface_cells, "required_entry_cells": entry_cells, "total_cells": surface_cells + entry_cells, "region_count": surface["regions"].size() + entries["regions"].size()}

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
		return _bad("COMBINED_TERRAIN_SIZE_LIMIT")
	return {"ok": true, "bytes": bytes}

func decode(bytes: Variant, component: Variant, world_id: String) -> Dictionary:
	if not bytes is PackedByteArray or bytes.is_empty():
		return _bad("COMBINED_TERRAIN_BYTES_REQUIRED_NO_GENERATION")
	if bytes.size() > MAX_BYTES or not EntryStore._valid_utf8(bytes):
		return _bad("COMBINED_TERRAIN_BYTES_LIMIT_OR_UTF8_INVALID")
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK:
		return _bad("COMBINED_TERRAIN_JSON_INVALID")
	var envelope: Variant = parser.data
	if not envelope is Array or envelope.size() != 5:
		return _bad("TERRAIN_CONTRACT_INCOMPATIBLE")
	for value in envelope:
		if typeof(value) != TYPE_STRING:
			return _bad("COMBINED_TERRAIN_ENVELOPE_TYPE_INVALID")
	if envelope[0] != FORMAT or envelope[1] != Codec.FORMAT:
		return _bad("TERRAIN_CONTRACT_INCOMPATIBLE")
	if envelope[2] != world_id:
		return _bad("COMBINED_TERRAIN_WORLD_IDENTITY_MISMATCH")
	if not EntryStore._hash(envelope[4]) or envelope[3].sha256_text() != envelope[4]:
		return _bad("COMBINED_TERRAIN_PAYLOAD_CHECKSUM_MISMATCH")
	if parser.parse(envelope[3]) != OK:
		return _bad("COMBINED_TERRAIN_PAYLOAD_JSON_INVALID")
	var decoded: Dictionary = Codec.decode(parser.data)
	if not decoded["ok"]:
		return _bad(decoded["code"])
	return restore(decoded["value"], component, world_id)

func _input_signature() -> Dictionary:
	var entry: Dictionary = _store_inputs(_entry_store)
	var surface: Dictionary = _store_inputs(_surface_store._base)
	if entry.is_empty() or surface.is_empty() or _surface_store._rules == null or _surface_store._rules.get_script() != SurfaceRules or not _surface_store._rules.ready:
		return {}
	var trees: Dictionary = {"entry": entry, "surface": surface, "settings": _surface_store._rules.settings, "rule_generation": _surface_store._rules.generation, "rule_initial_digests": _surface_store._rules._initial_input_digests}
	if not Codec.encode(trees)["ok"]:
		return {}
	return {"configuration_sha256": EntryStore.digest(trees), "entry_store_id": _entry_store.get_instance_id(), "surface_store_id": _surface_store.get_instance_id(), "surface_base_id": _surface_store._base.get_instance_id(), "surface_rules_id": _surface_store._rules.get_instance_id()}

static func _store_inputs(store: RefCounted) -> Dictionary:
	if store == null or store.get_script() != EntryStore or not store.ready or store._layout_validator == null or store._layout_validator.get_script() != EntryStore.LayoutValidator or store._layout_validator._inputs == null or store._layout_validator._inputs.get_script() != EntryStore.Inputs or not store._layout_validator._inputs.ready or store._prefab_validator == null or store._prefab_validator.get_script() != EntryStore.PrefabValidator or not store._prefab_validator.ready or store._prefab_validator._generation == null or store._prefab_validator._generation.get_script() != EntryStore.Inputs or not store._prefab_validator._generation.ready:
		return {}
	return {"generation": store._generation, "prefab": store._prefab, "bundle": store._bundle, "bundle_sha256": store._bundle_sha256, "layout_generation": store._layout_validator._inputs.data, "prefab_generation": store._prefab_validator._generation.data, "prefab_inputs": store._prefab_validator._prefab}

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "formal_world_allowed": false, "native_clear_allowed": false, "transfer_allowed": false, "migration_route_available": false, "regeneration_allowed": false, "recoverable_corruption": false}
