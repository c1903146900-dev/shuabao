extends RefCounted
## Explicit new4 server-side public render projection. Not a movement clearance
## certificate. No generation, scene mutation, native body, network or save write.
const Store = preload("res://scripts/terrain/combined_terrain_store.gd")
const EntryStore = preload("res://scripts/terrain/required_entry_terrain_store.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const CONTRACT := "011-new4-public-terrain-render-v1"

static func build(store: RefCounted, artifact: Variant, component: Dictionary, world_id: String) -> Dictionary:
	if store == null or store.get_script() != Store or not store.ready:
		return {"ok": false, "code": "TERRAIN_PUBLIC_STORE_REQUIRED"}
	# An actual Store validation is mandatory. A caller's boolean, count or hash
	# alone cannot certify rows; the Stage must never be used on this read path.
	var checked: Dictionary = store.restore(artifact, component, world_id)
	if not checked.get("ok", false):
		return {"ok": false, "code": "TERRAIN_PUBLIC_INVALID:" + str(checked.get("code", "UNKNOWN"))}
	var saved: Dictionary = checked["artifact"]
	var objects: Dictionary = {}
	var h1: Array = []
	for instance in component["prefab_instances"]:
		for object in instance["objects"]:
			objects[object["instance_id"]] = object
			if object["plane"] == "H1":
				h1.append({"layer": object["layer"].duplicate(true), "rect": object["rect"].duplicate(), "plane": "H1", "object_instance_id": object["instance_id"], "content_id": object["content_id"], "content_namespace": object["content_namespace"], "is_liquid": object["is_liquid"], "blocking": object["blocking"]})
	var cells: Array = []
	var seen: Dictionary = {}
	for child in ["surface", "required_entries"]:
		for region in saved["components"][child]["regions"]:
			for row in region["cells"]:
				var layer: Dictionary = region["layer"]
				var cell: Array = row["cell"]
				var key: String = Address.key(layer) + "|%d,%d" % [cell[0], cell[1]]
				if seen.has(key):
					return {"ok": false, "code": "TERRAIN_PUBLIC_DUPLICATE_CELL"}
				seen[key] = true
				var ground: Dictionary = _ground(child, row["categories"], objects)
				if ground.is_empty():
					return {"ok": false, "code": "TERRAIN_PUBLIC_EFFECTIVE_GROUND_INVALID"}
				cells.append({"layer": layer.duplicate(true), "cell": cell.duplicate(), "plane": "H0", "ground": ground})
	if cells.size() != saved["counts"]["total_cells"]:
		return {"ok": false, "code": "TERRAIN_PUBLIC_CELL_COUNT_MISMATCH"}
	var public: Dictionary = {"contract": CONTRACT, "world_id": world_id, "terrain_contract": Store.CONTRACT, "world_component_sha256": EntryStore.digest(component), "artifact_sha256": saved["artifact_sha256"], "cells": cells, "objects": h1, "formal_world_allowed": false}
	public["projection_sha256"] = EntryStore.digest(public)
	return {"ok": true, "projection": public}

static func _ground(child: String, categories: Dictionary, objects: Dictionary) -> Dictionary:
	var effective: Dictionary
	if child == "surface":
		effective = categories["effective_H0"]
	else:
		# Preserve prefab H0 precedence in underground cells too. Never draw a
		# second generated ground over a real prefab, or resurrect carved H1.
		var overlays: Array = []
		for object_id in categories["prefab"]["object_instance_ids"]:
			if objects[object_id]["plane"] == "H0":
				overlays.append(objects[object_id])
		if overlays.size() > 1:
			return {}
		if overlays.is_empty():
			effective = {"kind": "source_ground", "content_id": categories["source_ground"]["resource_id"], "content_namespace": "formal_source", "object_instance_id": "", "is_liquid": false}
		else:
			var object: Dictionary = overlays[0]
			effective = {"kind": "existing_prefab", "content_id": object["content_id"], "content_namespace": object["content_namespace"], "object_instance_id": object["instance_id"], "is_liquid": object["is_liquid"]}
	if effective["kind"] == "source_static_water":
		# Water has a source-backed kind, not an invented stable resource ID.
		return {"kind": effective["kind"], "liquid_type": effective["liquid_type"], "parameter_id": effective["parameter_id"], "is_liquid": true}
	return {"kind": effective["kind"], "content_id": effective["content_id"], "content_namespace": effective["content_namespace"], "object_instance_id": effective["object_instance_id"], "is_liquid": effective["is_liquid"]}

static func visible_rows(public: Dictionary, layer: Dictionary, visible: Rect2) -> Dictionary:
	# Only an already-validated new4 cache should call this helper. It cannot
	# replace client envelope validation or grant movement support.
	if public.get("contract") != CONTRACT or not Address.valid_layer(layer) or public.get("world_id") != layer["world_id"] or not visible.position.is_finite() or not visible.size.is_finite() or not visible.end.is_finite() or not visible.has_area():
		return {"ok": false, "code": "TERRAIN_PUBLIC_VIEW_INVALID"}
	var cells: Array = []
	var objects: Array = []
	var key: String = Address.key(layer)
	for row in public["cells"]:
		if Address.key(row["layer"]) == key and visible.intersects(Rect2(Vector2(row["cell"][0], row["cell"][1]), Vector2.ONE)):
			cells.append(row.duplicate(true))
	for row in public["objects"]:
		var rect: Array = row["rect"]
		if Address.key(row["layer"]) == key and visible.intersects(Rect2(Vector2(rect[0], rect[1]), Vector2(rect[2], rect[3]))):
			objects.append(row.duplicate(true))
	return {"ok": true, "cells": cells, "objects": objects}
