extends RefCounted
## Independent finite surface generation candidate. It does not alter the world,
## legacy 147-cell terrain contract, saves, native coverage, actor movement or F.
const EntryStage = preload("res://scripts/terrain/required_entry_terrain_stage.gd")
const EntryStore = preload("res://scripts/terrain/required_entry_terrain_store.gd")
const Store = preload("res://scripts/terrain/surface_approach_store.gd")
const Rules = preload("res://scripts/terrain/surface_approach_rules.gd")
var ready: bool = false
var last_error: String = ""
var materialize_calls: int = 0
var _entry_stage: RefCounted
var _store: RefCounted

func _init(generation: Dictionary, prefab: Dictionary, bundle: Dictionary, settings: Dictionary = {}) -> void:
	_store = Store.new(generation, prefab, bundle, settings)
	if not _store.ready:
		last_error = _store.last_error
		return
	_entry_stage = EntryStage.new(generation, prefab, bundle)
	if not _entry_stage.ready:
		last_error = _entry_stage.last_error
		return
	ready = true

func materialize(component: Variant, world_id: String) -> Dictionary:
	if not ready:
		return Store._bad("SURFACE_STAGE_INPUTS_NOT_READY")
	if not _store.inputs_current():
		return Store._bad("SURFACE_STAGE_APPROVED_INPUT_DRIFT")
	var world: Dictionary = _store._base._checked_world(component, world_id)
	if not world["ok"]:
		return Store._bad("SURFACE_STAGE_WORLD_INVALID:" + str(world["code"]))
	var existing: Dictionary = world["component"]
	var scope: Dictionary = _store._rules.scope(existing)
	if not scope["ok"]:
		return Store._bad(scope["code"])
	materialize_calls += 1
	var bounds: Array = scope["bounds"]
	var cells: Array = []
	for y in range(int(bounds[1]), int(bounds[1] + bounds[3])):
		for x in range(int(bounds[0]), int(bounds[0] + bounds[2])):
			var cell: Array = [x, y]
			var assignment: Dictionary = _entry_stage._assignment(existing["layout"], scope["layer"], cell)
			if assignment.is_empty():
				return Store._bad("SURFACE_STAGE_BIOME_ASSIGNMENT_UNAVAILABLE")
			var sample: Dictionary = _store._rules.water_sample(existing["layout"], assignment["biome_id"], cell)
			var categories: Dictionary = _store._rules.cell_categories(existing, scope, cell, assignment, sample)
			if categories.is_empty():
				return Store._bad("SURFACE_STAGE_MULTIPLE_EFFECTIVE_PREFAB_H0")
			cells.append({"cell": cell, "categories": categories})
	var regions: Array = [{"region_id": scope["region_id"], "scope": "surface_prefab_actual_entry_bounding_union", "layer": scope["layer"], "layer_sha256": EntryStore.digest(scope["layer"]), "bounds": bounds, "cells": cells}]
	var artifact: Dictionary = {
		"schema_version": 1, "artifact_kind": Rules.KIND, "contract": Rules.CONTRACT,
		"sources": _store._base._generation["sources"].duplicate(true), "source_rules": Rules.SOURCE_RULES.duplicate(true),
		"settings": _store._rules.settings.duplicate(true), "biome_algorithm": EntryStore.ALGORITHM.duplicate(true),
		"bindings": _store.bindings(existing), "entries": scope["entries"], "regions": regions,
		"existing_world_references": EntryStage._existing_references(existing), "counts": Rules.counts(regions),
		"completion": Store.COMPLETION.duplicate(true), "outside_scope": Store.OUTSIDE.duplicate(true), "dynamic_occupancy": Store.DYNAMIC.duplicate(true),
		"formal_world_allowed": false, "native_clear_allowed": false, "transfer_allowed": false
	}
	artifact["artifact_sha256"] = EntryStore.digest(artifact)
	return _store.restore(artifact, existing, world_id)

func validate(artifact: Variant, component: Variant, world_id: String) -> Dictionary:
	# Unlike the old stage validator this delegates only to saved-record checks.
	return _store.restore(artifact, component, world_id)
