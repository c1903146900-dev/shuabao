extends "res://scripts/actor/actor_space.gd"
## Schema4's finite initial-static terrain adapter. No generation or transfer.
## The persisted artifact remains uncertified; these are local query-support facts.
const TerrainStore = preload("res://scripts/terrain/required_entry_terrain_store.gd")
const CombinedStore = preload("res://scripts/terrain/combined_terrain_store.gd")
const SurfaceRules = preload("res://scripts/terrain/surface_approach_rules.gd")
var _terrain: Variant
var _terrain_store: RefCounted
var _supported_regions: Array = []
var _supported_cell_count: int = 0
var _validated_artifact_sha256: String = ""
var _static_epoch: int = 0

func _init(terrain: Variant, terrain_store: RefCounted) -> void:
	_terrain = terrain.duplicate(true) if terrain is Dictionary else terrain
	_terrain_store = terrain_store

func configure(world: RefCounted, inputs: RefCounted) -> bool:
	if not _spaces.is_empty() or world == null or inputs == null or not world.ready or not inputs.ready:
		return _configuration_failed("TERRAIN_SPACE_ALREADY_CONFIGURED_OR_INPUTS_INVALID")
	# This must be the actual read-only Store, never Stage.validate (which generates).
	if not _supported_store():
		return _configuration_failed("TERRAIN_SPACE_STORE_NOT_READY")
	var component: Dictionary = world.public_component()
	var checked: Dictionary = _terrain_store.restore(_terrain, component, component.get("layout", {}).get("world_id", ""))
	if not checked.get("ok", false):
		return _configuration_failed(str(checked.get("code", "TERRAIN_SPACE_INVALID_ARTIFACT")))
	# Store validates all saved semantics/bindings. Independently translate actual
	# rows into occupancy support, before superclass configure allocates any RID.
	var support: Dictionary = _support_from_rows(checked["artifact"], component)
	if not support.get("ok", false):
		return _configuration_failed(support["code"])
	if not super.configure(world, inputs):
		return _configuration_failed(last_error)
	if not _publish_support(support["regions"]):
		return _configuration_failed(last_error)
	_supported_regions = support["regions"].duplicate(true)
	_supported_cell_count = support["cell_count"]
	_validated_artifact_sha256 = checked["artifact"]["artifact_sha256"]
	_static_epoch += 1
	last_error = ""
	return true

func _supported_store() -> bool:
	return _terrain_store != null and _terrain_store.get_script() in [TerrainStore, CombinedStore] and _terrain_store.ready

func _support_from_rows(artifact: Dictionary, component: Dictionary) -> Dictionary:
	if _terrain_store.get_script() == CombinedStore:
		return _combined_support_from_rows(artifact, component)
	return _entry_support_from_rows(artifact, component)

func _entry_support_from_rows(artifact: Dictionary, component: Dictionary) -> Dictionary:
	var objects: Dictionary = {}
	var layers: Dictionary = {}
	# The inherited adapter materializes these actual blocking rectangles. Refuse
	# unsupported occupancy even when it lies outside the new terrain rectangles.
	for instance in component["prefab_instances"]:
		for layer in instance["layers"]:
			layers[Address.key(layer["address"])] = layer["address"]
		for object in instance["objects"]:
			if objects.has(object["instance_id"]) or object["is_liquid"] or object["plane"] not in ["H0", "H1"] or (object["blocking"] and object["content_namespace"] != "technical_fixture"):
				return _support_error("TERRAIN_SPACE_UNSUPPORTED_WORLD_OCCUPANCY")
			objects[object["instance_id"]] = object
	var regions: Array = []
	var ids: Dictionary = {}
	var endpoints: Dictionary = {}
	var count: int = 0
	if artifact["regions"].size() != 3:
		return _support_error("TERRAIN_SPACE_REGION_COVERAGE_INVALID")
	for region in artifact["regions"]:
		var layer: Dictionary = region["layer"]
		var key: String = Address.key(layer)
		var bounds: Array = region["bounds"]
		if layer["map_kind"] != "underground" or not layers.has(key) or not TerrainStore._same(layers[key], layer) or bounds[2] != 7 or bounds[3] != 7 or region["cells"].size() != 49 or ids.has(region["region_id"]) or endpoints.has(region["endpoint_key"]):
			return _support_error("TERRAIN_SPACE_REGION_COVERAGE_INVALID")
		ids[region["region_id"]] = true
		endpoints[region["endpoint_key"]] = true
		var cells: Dictionary = {}
		for row in region["cells"]:
			var cell: Array = row["cell"]
			var cell_key: String = "%d,%d" % [cell[0], cell[1]]
			if cells.has(cell_key) or not TerrainStore._contains(bounds, cell) or not _cell_supports_native(row, layer, objects, component):
				return _support_error("TERRAIN_SPACE_CELL_OCCUPANCY_OR_COVERAGE_INVALID")
			cells[cell_key] = true
			count += 1
		# Explicit coverage, not completion.cell_count or a completion boolean.
		for y in range(bounds[1], bounds[1] + 7):
			for x in range(bounds[0], bounds[0] + 7):
				if not cells.has("%d,%d" % [x, y]):
					return _support_error("TERRAIN_SPACE_CELL_COVERAGE_INVALID")
		regions.append({"region_id": region["region_id"], "endpoint_key": region["endpoint_key"], "layer": layer.duplicate(true), "bounds": bounds.duplicate(), "cell_count": cells.size()})
	if count != 147:
		return _support_error("TERRAIN_SPACE_CELL_COVERAGE_INVALID")
	return {"ok": true, "regions": regions, "cell_count": count}

func _cell_supports_native(row: Dictionary, layer: Dictionary, objects: Dictionary, component: Dictionary) -> bool:
	var cats: Dictionary = row["categories"]
	for category in TerrainStore.CATEGORIES:
		if cats[category]["status"] != TerrainStore.RESOLVED_STATUS[category]:
			return false
	if cats["source_ground"]["plane"] != "H0" or not cats["source_ground"]["occupied"] or cats["default_rock"]["plane"] != "H1" or cats["default_rock"]["final_occupied"] or cats["caves"]["final_height"] != 0:
		return false
	if cats["generated_carve"]["clear_scope"] != "default_geological_rock_H1_only" or cats["generated_carve"]["operation_ids"] != [cats["default_rock"]["removed_by_operation_id"]]:
		return false
	for category in ["liquids", "minerals", "trees", "ordinary_poi"]:
		if cats[category]["natural_initial_occupied"]:
			return false
	if not cats["natural_initial_animals"]["candidate_ids"].is_empty() or cats["natural_initial_animals"]["future_dynamic_occupancy_resolved"] or cats["prefab"]["cleared_by_stage"] or cats["permanent_changes"]["written_by_stage"]:
		return false
	var expected_ids: Array = []
	for object_id in objects:
		var object: Dictionary = objects[object_id]
		if TerrainStore._same(object["layer"], layer) and TerrainStore._contains(object["rect"], row["cell"]):
			expected_ids.append(object_id)
	expected_ids.sort()
	if cats["prefab"]["object_instance_ids"] != expected_ids:
		return false
	# This slice has no native interpretation of permanent edits. Never ignore one.
	var change_key: String = "%d|%d,%d" % [layer["depth"], row["cell"][0], row["cell"][1]]
	return cats["permanent_changes"]["change_keys"].is_empty() and not component["layout"]["permanent_changes"].has(change_key)

func _combined_support_from_rows(artifact: Dictionary, component: Dictionary) -> Dictionary:
	var underground: Dictionary = _entry_support_from_rows(artifact["components"]["required_entries"], component)
	if not underground.get("ok", false):
		return underground
	var surface: Dictionary = artifact["components"]["surface"]
	var region: Dictionary = surface["regions"][0]
	var layer: Dictionary = region["layer"]
	var bounds: Array = region["bounds"]
	if layer["map_kind"] != "surface" or int(layer["depth"]) != 0 or not TerrainStore._same(layer, component["layout"]["spawn"]["layer"]):
		return _support_error("TERRAIN_SPACE_SURFACE_LAYER_INVALID")
	var objects: Dictionary = {}
	for instance in component["prefab_instances"]:
		for object in instance["objects"]:
			objects[object["instance_id"]] = object # Full occupancy was checked above, before any RID.
	var seen: Dictionary = {}
	var supported: Array = []
	var excluded: Array = []
	for row in region["cells"]:
		var cell: Array = row["cell"]
		var cell_key := "%d,%d" % [int(cell[0]), int(cell[1])]
		if seen.has(cell_key) or not TerrainStore._contains(bounds, cell):
			return _support_error("TERRAIN_SPACE_SURFACE_CELL_COVERAGE_INVALID")
		seen[cell_key] = true
		var checked: Dictionary = _surface_cell_support(row, layer, objects, component)
		if not checked.get("ok", false):
			return checked
		if checked["supported"]:
			supported.append(cell.duplicate())
		else:
			excluded.append(cell.duplicate()) # Valid liquid H0 remains unknown to actor movement.
	if seen.size() != int(bounds[2]) * int(bounds[3]):
		return _support_error("TERRAIN_SPACE_SURFACE_CELL_COVERAGE_INVALID")
	for y in range(int(bounds[1]), int(bounds[1] + bounds[3])):
		for x in range(int(bounds[0]), int(bounds[0] + bounds[2])):
			if not seen.has("%d,%d" % [x, y]):
				return _support_error("TERRAIN_SPACE_SURFACE_CELL_COVERAGE_INVALID")
	var regions: Array = [{"region_id": region["region_id"], "layer": layer.duplicate(true), "bounds": bounds.duplicate(), "coverage_mode": "exact_cell_union_v1", "supported_cells": supported, "unsupported_liquid_cells": excluded, "declared_cell_count": seen.size(), "cell_count": supported.size()}]
	for index in range(underground["regions"].size()):
		var entry: Dictionary = underground["regions"][index].duplicate(true)
		entry["coverage_mode"] = "exact_cell_union_v1"
		entry["supported_cells"] = []
		entry["unsupported_liquid_cells"] = []
		entry["declared_cell_count"] = entry["cell_count"]
		for row in artifact["components"]["required_entries"]["regions"][index]["cells"]:
			entry["supported_cells"].append(row["cell"].duplicate())
		regions.append(entry)
	return {"ok": true, "regions": regions, "cell_count": supported.size() + underground["cell_count"]}

func _surface_cell_support(row: Dictionary, layer: Dictionary, objects: Dictionary, component: Dictionary) -> Dictionary:
	var cats: Dictionary = row["categories"]
	if not TerrainStore._fields(cats, SurfaceRules.CATEGORIES):
		return _support_error("TERRAIN_SPACE_SURFACE_CATEGORY_INVALID")
	var effective: Dictionary = cats["effective_H0"]
	var liquid: Dictionary = cats["liquids"]
	if effective["status"] != "resolved_unique_H0" or effective["plane"] != "H0" or liquid["status"] != "resolved_static_field_composition" or liquid["final_occupied"] != effective["is_liquid"] or liquid["movement_policy"] != "unresolved_liquid_cannot_certify_actor_ground" or liquid["realtime_flow"]:
		return _support_error("TERRAIN_SPACE_SURFACE_H0_OR_LIQUID_INVALID")
	if cats["surface_geological_H1"]["status"] != "source_prohibits_random_geological_H1" or not cats["surface_geological_H1"]["instance_ids"].is_empty():
		return _support_error("TERRAIN_SPACE_SURFACE_H1_UNSUPPORTED")
	for category in ["trees", "natural_initial_animals", "ordinary_poi"]:
		if cats[category]["status"] != "disabled_by_technical_profile" or not cats[category]["instance_ids"].is_empty():
			return _support_error("TERRAIN_SPACE_SURFACE_POPULATION_UNSUPPORTED")
	var expected_ids: Array = []
	var h0_ids: Array = []
	for object_id in objects:
		var object: Dictionary = objects[object_id]
		if TerrainStore._same(object["layer"], layer) and TerrainStore._contains(object["rect"], row["cell"]):
			expected_ids.append(object_id)
			if object["plane"] == "H0":
				h0_ids.append(object_id)
	expected_ids.sort()
	var changes: Dictionary = cats["permanent_changes"]
	var change_key := "0|%d,%d" % [int(row["cell"][0]), int(row["cell"][1])]
	if cats["prefab"]["status"] != "resolved_existing_world_references" or cats["prefab"]["object_instance_ids"] != expected_ids or cats["prefab"]["cleared_by_stage"] or changes["status"] != "resolved_existing_world_references" or not changes["change_keys"].is_empty() or changes["written_by_stage"] or component["layout"]["permanent_changes"].has(change_key):
		return _support_error("TERRAIN_SPACE_SURFACE_EXISTING_OCCUPANCY_MISMATCH")
	if effective["kind"] == "source_static_water":
		if not effective["is_liquid"] or not h0_ids.is_empty() or cats["source_ground"]["effective"]:
			return _support_error("TERRAIN_SPACE_SURFACE_WATER_INVALID")
		return {"ok": true, "supported": false}
	if effective["is_liquid"] or liquid["final_occupied"]:
		return _support_error("TERRAIN_SPACE_SURFACE_UNSUPPORTED_H0")
	if effective["kind"] == "existing_prefab":
		if h0_ids.size() != 1 or effective["object_instance_id"] != h0_ids[0] or cats["source_ground"]["effective"]:
			return _support_error("TERRAIN_SPACE_SURFACE_PREFAB_H0_MISMATCH")
		var object: Dictionary = objects[h0_ids[0]]
		if object["is_liquid"] or effective["content_id"] != object["content_id"] or effective["content_namespace"] != object["content_namespace"]:
			return _support_error("TERRAIN_SPACE_SURFACE_PREFAB_H0_MISMATCH")
	elif effective["kind"] == "source_ground":
		if not h0_ids.is_empty() or not cats["source_ground"]["effective"] or cats["source_ground"]["plane"] != "H0" or cats["source_ground"]["resource_id"] != effective["content_id"] or effective["content_namespace"] != "formal_source":
			return _support_error("TERRAIN_SPACE_SURFACE_SOURCE_H0_MISMATCH")
	else:
		return _support_error("TERRAIN_SPACE_SURFACE_UNSUPPORTED_H0")
	return {"ok": true, "supported": true}

func _cell_publications(regions: Array) -> Dictionary:
	var result: Dictionary = {}
	for region in regions:
		var key := Address.key(region["layer"])
		if not result.has(key):
			result[key] = {"identity": region["layer"].duplicate(true), "cells": {}, "bounds": region["bounds"].duplicate()}
		else:
			result[key]["bounds"] = SurfaceRules._union(result[key]["bounds"], region["bounds"])
		for cell in region["supported_cells"]:
			result[key]["cells"]["%d,%d" % [int(cell[0]), int(cell[1])]] = true
	return result

func _publish_cell_support(regions: Array) -> bool:
	var publication: Dictionary = _cell_publications(regions)
	if publication.size() != _spaces.size():
		return _reject("TERRAIN_SPACE_NATIVE_LAYER_MISMATCH")
	for key in publication:
		if not _spaces.has(key) or not _spaces[key]["rid"].is_valid() or not TerrainStore._same(_spaces[key]["identity"], publication[key]["identity"]):
			return _reject("TERRAIN_SPACE_NATIVE_LAYER_MISMATCH")
	for key in publication:
		_spaces[key]["materialized_bounds"] = [] # No rectangle itself grants query support.
		_spaces[key]["coverage_mode"] = "exact_cell_union_v1"
		_spaces[key]["materialized_cells"] = publication[key]["cells"]
		_spaces[key]["cell_coverage_bounds"] = publication[key]["bounds"] # Enumeration bound only.
	return true

func _publish_support(regions: Array) -> bool:
	if not regions.is_empty() and regions[0].get("coverage_mode") == "exact_cell_union_v1":
		return _publish_cell_support(regions)
	# Check every target before publishing any support. Failure after native
	# allocation still runs dispose, including all inherited body/shape/space RIDs.
	for region in regions:
		var key: String = Address.key(region["layer"])
		if not _spaces.has(key) or not _spaces[key]["rid"].is_valid() or not TerrainStore._same(_spaces[key]["identity"], region["layer"]):
			return _reject("TERRAIN_SPACE_NATIVE_LAYER_MISMATCH")
	for region in regions:
		_spaces[Address.key(region["layer"])]["materialized_bounds"].append(region["bounds"].duplicate())
	return true

func _covered(key: String, position: Vector2) -> bool:
	if not _spaces.has(key) or not position.is_finite():
		return false
	if _spaces[key].get("coverage_mode") != "exact_cell_union_v1":
		return super._covered(key, position)
	return _cell_covered_segment(key, float(position.x), float(position.y), float(position.x), float(position.y))

func _covered_sweep(key: String, start: Vector2, motion: Vector2) -> bool:
	if not _spaces.has(key) or not start.is_finite() or not motion.is_finite():
		return false
	if _spaces[key].get("coverage_mode") != "exact_cell_union_v1":
		return super._covered_sweep(key, start, motion)
	var sx := float(start.x)
	var sy := float(start.y)
	var ex := sx + float(motion.x)
	var ey := sy + float(motion.y)
	if not _cell_covered_segment(key, sx, sy, ex, ey):
		return false
	# Cover both scalar-double solver construction and the actual rounded native
	# endpoint. No expanded rectangle, artificial wall or endpoint-only shortcut.
	var native_end := start + motion
	return (float(native_end.x) == ex and float(native_end.y) == ey) or _cell_covered_segment(key, sx, sy, float(native_end.x), float(native_end.y))

func _cell_covered_segment(key: String, sx: float, sy: float, ex: float, ey: float) -> bool:
	if not is_finite(sx) or not is_finite(sy) or not is_finite(ex) or not is_finite(ey) or not is_finite(_half) or _half <= 0.0:
		return false
	var space: Dictionary = _spaces[key]
	var cells: Dictionary = space["materialized_cells"]
	var bounds: Array = space["cell_coverage_bounds"]
	var left := minf(sx, ex) - _half
	var right := maxf(sx, ex) + _half
	var top := minf(sy, ey) - _half
	var bottom := maxf(sy, ey) + _half
	# This rejects only travel outside the outer enumeration bound. Holes and
	# water inside it are still checked one actual unit cell at a time below.
	if left < bounds[0] or top < bounds[1] or right > bounds[0] + bounds[2] or bottom > bounds[1] + bounds[3]:
		return false
	for y in range(floori(top), ceili(bottom)):
		for x in range(floori(left), ceili(right)):
			if not cells.has("%d,%d" % [x, y]) and _swept_disk_overlaps_cell(sx, sy, ex, ey, float(x), float(y), _half):
				return false
	return true

static func _swept_disk_overlaps_cell(sx: float, sy: float, ex: float, ey: float, x: float, y: float, radius: float) -> bool:
	# Exact cell selection for the circular environment body under finite float64
	# predicates, not arbitrary-precision geometry. No outward/inward epsilon.
	# Tangency alone does not enter an unknown cell's interior, matching the
	# legacy closed outer support boundary. Real blocking rows remain native RIDs.
	if _segment_intersects_cell(sx, sy, ex, ey, x, y):
		return true
	var distance := minf(_point_cell_distance_squared(sx, sy, x, y), _point_cell_distance_squared(ex, ey, x, y))
	for corner_x in [x, x + 1.0]:
		for corner_y in [y, y + 1.0]:
			distance = minf(distance, _point_segment_distance_squared(corner_x, corner_y, sx, sy, ex, ey))
	return not is_finite(distance) or distance < radius * radius

static func _segment_intersects_cell(sx: float, sy: float, ex: float, ey: float, x: float, y: float) -> bool:
	var enter := 0.0
	var leave := 1.0
	for axis in range(2):
		var start: float = sx if axis == 0 else sy
		var delta: float = ex - sx if axis == 0 else ey - sy
		var minimum: float = x if axis == 0 else y
		if delta == 0.0:
			if start < minimum or start > minimum + 1.0:
				return false
			continue
		var first := (minimum - start) / delta
		var last := (minimum + 1.0 - start) / delta
		enter = maxf(enter, minf(first, last))
		leave = minf(leave, maxf(first, last))
		if enter > leave:
			return false
	return true

static func _point_cell_distance_squared(px: float, py: float, x: float, y: float) -> float:
	var dx := px - clampf(px, x, x + 1.0)
	var dy := py - clampf(py, y, y + 1.0)
	return dx * dx + dy * dy

static func _point_segment_distance_squared(px: float, py: float, sx: float, sy: float, ex: float, ey: float) -> float:
	var dx := ex - sx
	var dy := ey - sy
	var length_squared := dx * dx + dy * dy
	var fraction := 0.0 if length_squared == 0.0 else clampf(((px - sx) * dx + (py - sy) * dy) / length_squared, 0.0, 1.0)
	var gap_x := px - (sx + fraction * dx)
	var gap_y := py - (sy + fraction * dy)
	return gap_x * gap_x + gap_y * gap_y

func runtime_evidence() -> Dictionary:
	# Detached, ephemeral evidence only. Other dynamic categories remain unknown;
	# inherited placement checks cover the currently registered actor peers only.
	var combined: bool = _terrain_store != null and _terrain_store.get_script() == CombinedStore
	var surface_cells: int = 0
	var liquid_cells: int = 0
	for region in _supported_regions:
		if region["layer"]["map_kind"] == "surface":
			surface_cells += int(region["declared_cell_count"])
			liquid_cells += region["unsupported_liquid_cells"].size()
	return {"adapter": "surface_and_required_entry_initial_static_native_v1" if combined else "required_entry_initial_static_native_v1", "coverage_policy": "circle_and_swept_circle_actual_cells" if combined else "legacy_single_rectangle", "saved_surface_rows_supported": combined, "declared_surface_cell_count": surface_cells, "unsupported_liquid_cell_count": liquid_cells, "artifact_sha256": _validated_artifact_sha256, "supported_regions": _supported_regions.duplicate(true), "supported_cell_count": _supported_cell_count, "native_space_count": _spaces.size(), "native_body_count": _bodies.size(), "native_shape_count": _shapes.size(), "active_actor_count": _actors.size(), "peer_occupancy_scope": "currently_registered_actor_peers_only", "other_dynamic_occupancy": "unknown", "outside_required_regions": "unknown", "surface_generation_added": false, "formal_world_allowed": false, "transfer_allowed": false}

func dispose() -> void:
	_static_epoch += 1 # Invalidate leases before freeing any native resource.
	super.dispose()
	if _supported_regions.is_read_only():
		_supported_regions = []
	else:
		_supported_regions.clear()
	_supported_cell_count = 0
	_validated_artifact_sha256 = ""

func _configuration_failed(code: String) -> bool:
	dispose()
	return _reject(code)

static func _support_error(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func transfer_context(world: RefCounted) -> Dictionary:
	# Read actual stored rows again; neither a completion flag nor runtime_evidence
	# substitutes for Store validation or unchanged native coverage publication.
	if world == null or not world.ready or not _supported_store() or _validated_artifact_sha256.is_empty():
		return _support_error("TRANSFER_TERRAIN_NOT_READY")
	var component: Dictionary = world.public_component()
	var checked: Dictionary = _terrain_store.restore(_terrain, component, component.get("layout", {}).get("world_id", ""))
	if not checked.get("ok", false):
		return checked
	var support := _support_from_rows(checked["artifact"], component)
	if not support.get("ok", false):
		return support
	if support["regions"] != _supported_regions or support["cell_count"] != _supported_cell_count or checked["artifact"]["artifact_sha256"] != _validated_artifact_sha256:
		return _support_error("TRANSFER_TERRAIN_SUPPORT_CHANGED")
	if _terrain_store.get_script() == CombinedStore:
		var publication: Dictionary = _cell_publications(support["regions"])
		if publication.size() != _spaces.size():
			return _support_error("TRANSFER_TERRAIN_NATIVE_COVERAGE_CHANGED")
		for key in publication:
			if not _spaces.has(key) or not _spaces[key]["rid"].is_valid() or _spaces[key].get("coverage_mode") != "exact_cell_union_v1" or not TerrainStore._same(_spaces[key]["identity"], publication[key]["identity"]) or not TerrainStore._same(_spaces[key].get("materialized_cells"), publication[key]["cells"]) or not TerrainStore._same(_spaces[key].get("cell_coverage_bounds"), publication[key]["bounds"]) or not _spaces[key]["materialized_bounds"].is_empty():
				return _support_error("TRANSFER_TERRAIN_NATIVE_COVERAGE_CHANGED")
		return {"ok": true, "artifact_sha256": _validated_artifact_sha256, "world_sha256": TerrainStore.digest(component), "supported_cell_count": _supported_cell_count}
	var bounds: Dictionary = {}
	for instance in component["prefab_instances"]:
		for layer in instance["layers"]:
			var key := Address.key(layer["address"])
			if not bounds.has(key):
				bounds[key] = []
			if layer["address"]["map_kind"] == "surface":
				bounds[key].append(layer["bounds"].duplicate())
	for region in support["regions"]:
		bounds[Address.key(region["layer"])].append(region["bounds"].duplicate())
	if bounds.size() != _spaces.size():
		return _support_error("TRANSFER_TERRAIN_NATIVE_COVERAGE_CHANGED")
	for key in bounds:
		if not _spaces.has(key) or _spaces[key]["materialized_bounds"] != bounds[key] or not _spaces[key]["rid"].is_valid():
			return _support_error("TRANSFER_TERRAIN_NATIVE_COVERAGE_CHANGED")
	return {"ok": true, "artifact_sha256": _validated_artifact_sha256, "world_sha256": TerrainStore.digest(component), "supported_cell_count": _supported_cell_count}
