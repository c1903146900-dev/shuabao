extends RefCounted
## Fresh explicit generation only. Never used to restore a save or fill a missing
## child terrain artifact. Child stages preserve the supplied WorldComponent.
const EntryStage = preload("res://scripts/terrain/required_entry_terrain_stage.gd")
const SurfaceStage = preload("res://scripts/terrain/surface_approach_stage.gd")
const Store = preload("res://scripts/terrain/combined_terrain_store.gd")
const EntryStore = preload("res://scripts/terrain/required_entry_terrain_store.gd")
var ready: bool = false
var last_error: String = ""
var materialize_calls: int = 0
var _entry_stage: RefCounted
var _surface_stage: RefCounted
var _store: RefCounted

func _init(generation: Dictionary, prefab: Dictionary, bundle: Dictionary) -> void:
	_store = Store.new(generation, prefab, bundle)
	if not _store.ready:
		last_error = _store.last_error
		return
	_entry_stage = EntryStage.new(generation, prefab, bundle)
	_surface_stage = SurfaceStage.new(generation, prefab, bundle)
	if not _entry_stage.ready or not _surface_stage.ready:
		last_error = _entry_stage.last_error if not _entry_stage.ready else _surface_stage.last_error
		return
	ready = true

func materialize(component: Variant, world_id: String) -> Dictionary:
	if not ready or not _store.inputs_current():
		return Store._bad("COMBINED_TERRAIN_STAGE_INPUTS_NOT_READY_OR_DRIFTED")
	materialize_calls += 1
	var entries: Dictionary = _entry_stage.materialize(component, world_id)
	if not entries["ok"]:
		return Store._bad("COMBINED_TERRAIN_STAGE_ENTRIES_FAILED:" + str(entries["code"]))
	var surface: Dictionary = _surface_stage.materialize(component, world_id)
	if not surface["ok"]:
		return Store._bad("COMBINED_TERRAIN_STAGE_SURFACE_FAILED:" + str(surface["code"]))
	var a: Dictionary = surface["artifact"]
	var b: Dictionary = entries["artifact"]
	var artifact: Dictionary = {
		"schema_version": 1, "artifact_kind": Store.KIND, "contract": Store.CONTRACT,
		"sources": a["sources"].duplicate(true), "bindings": Store.bindings_for(a, b),
		"components": {"surface": a, "required_entries": b}, "counts": Store.counts_for(a, b),
		"completion": Store.COMPLETION.duplicate(true),
		"formal_world_allowed": false, "native_clear_allowed": false, "transfer_allowed": false
	}
	artifact["artifact_sha256"] = EntryStore.digest(artifact)
	return _store.restore(artifact, component, world_id)

func validate(artifact: Variant, component: Variant, world_id: String) -> Dictionary:
	return _store.restore(artifact, component, world_id)
