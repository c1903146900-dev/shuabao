extends RefCounted
## Hand-authored technical proxy examples, not production geometry or balance.
## The literal dimensions below demonstrate the format; no table size text is
## interpreted as cell dimensions, loot, difficulty, population, or guarantees.

static func multilayer(sources: Dictionary) -> Dictionary:
	var template: Dictionary = _base("fixture_multilayer_proxy", sources)
	for depth in range(3):
		var layer_id: String = "layer_%d" % depth
		template["layers"].append(_layer(layer_id, depth, [-12, -12, 25, 25]))
		template["objects"].append(_fixture("ground_%d" % depth, "fixture_ground", layer_id, "H0", [-12, -12, 25, 25], false))
		template["protected_areas"].append({"local_id": "protected_%d" % depth, "layer_id": layer_id, "rect": [-10, -10, 21, 21], "reason": "Explicit technical fixture reservation; not authoritative POI geometry"})
	template["objects"].append(_fixture("floor", "fixture_floor", "layer_0", "H0_OVERLAY", [-8, -8, 2, 2], false))
	template["objects"].append(_fixture("decal", "fixture_decal", "layer_0", "H0_DECAL", [-8, -8, 2, 2], false))
	template["objects"].append(_fixture("wall", "fixture_wall", "layer_0", "H1", [-8, -4, 2, 1], true))
	template["objects"].append(_authoritative("container", "tuozhi_tongyong_xiang", "poi_container", "layer_1", "H1", [-8, 5, 2, 2], true))
	template["objects"].append(_authoritative("boss", "boss_dimai_guanshou", "content", "layer_2", "H1", [5, 5, 3, 3], true))
	template["anchors"] = [
		_anchor("spawn", "spawn", "layer_0", [-5, 0]),
		_anchor("entry_01_upper", "entrance", "layer_0", [0, 0]),
		_anchor("entry_01_lower", "entrance", "layer_1", [0, 0]),
		_anchor("entry_12_upper", "entrance", "layer_1", [6, 0]),
		_anchor("entry_12_lower", "entrance", "layer_2", [6, 0]),
		_anchor("container_anchor", "container", "layer_1", [-8, 5], "container"),
		_anchor("boss_anchor", "boss", "layer_2", [6, 6], "boss")
	]
	# These 3/7 values are checked against generation_settings.connections, never
	# used as an alternative authority if that source changes or denies the pair.
	template["connections"] = [
		_connection("connection_01", "entry_01_upper", "entry_01_lower"),
		_connection("connection_12", "entry_12_upper", "entry_12_lower")
	]
	return _ordered(template)

static func spawn_proxy(sources: Dictionary) -> Dictionary:
	var template: Dictionary = _base("poi_x03_chusheng_anquan", sources)
	template["layers"] = [_layer("surface", 0, [-4, -4, 9, 9])]
	template["objects"] = [_authoritative("ground", "dikuai_x03_wendai_linyuan_01", "ground_resource", "surface", "H0", [-4, -4, 9, 9], false)]
	template["anchors"] = [_anchor("spawn", "spawn", "surface", [0, 0])]
	template["protected_areas"] = [{"local_id": "spawn_reservation", "layer_id": "surface", "rect": [-4, -4, 9, 9], "reason": "Explicit spawn proxy fixture; not formal safe-area dimensions"}]
	return _ordered(template)

static func core_proxy(sources: Dictionary) -> Dictionary:
	var template: Dictionary = _base("poi_x03_shenceng_hexin", sources)
	template["layers"] = [_layer("deep_core", 2, [-6, -6, 13, 13])]
	template["objects"] = [
		_fixture("ground", "fixture_ground", "deep_core", "H0", [-6, -6, 13, 13], false),
		_authoritative("boss", "boss_dimai_guanshou", "content", "deep_core", "H1", [1, 1, 3, 3], true)
	]
	template["anchors"] = [_anchor("boss_anchor", "boss", "deep_core", [2, 2], "boss")]
	template["protected_areas"] = [{"local_id": "core_reservation", "layer_id": "deep_core", "rect": [-6, -6, 13, 13], "reason": "Explicit core proxy fixture; no combat, loot or progression integration"}]
	return _ordered(template)

static func _base(template_id: String, sources: Dictionary) -> Dictionary:
	return {"schema_version": 1, "artifact_kind": "technical_prefab_template", "template_id": template_id, "revision": 1, "sources": sources.duplicate(true), "body_content_id": "xingxing_03", "geometry_kind": "explicit_technical_fixture", "formal_world_allowed": false, "layers": [], "objects": [], "anchors": [], "connections": [], "protected_areas": []}

static func _layer(local_id: String, depth: int, bounds: Array) -> Dictionary:
	return {"local_id": local_id, "map_kind": "surface" if depth == 0 else "underground", "depth": depth, "bounds": bounds}

static func _fixture(local_id: String, content_id: String, layer_id: String, plane: String, rect: Array, blocking: bool, is_liquid: bool = false) -> Dictionary:
	return {"local_id": local_id, "content_id": content_id, "content_scope": "technical_fixture", "content_namespace": "technical_fixture", "layer_id": layer_id, "plane": plane, "rect": rect, "blocking": blocking, "is_liquid": is_liquid}

static func _authoritative(local_id: String, content_id: String, content_namespace: String, layer_id: String, plane: String, rect: Array, blocking: bool) -> Dictionary:
	return {"local_id": local_id, "content_id": content_id, "content_scope": "authoritative", "content_namespace": content_namespace, "layer_id": layer_id, "plane": plane, "rect": rect, "blocking": blocking, "is_liquid": false}

static func _anchor(local_id: String, kind: String, layer_id: String, cell: Array, object_local_id: String = "") -> Dictionary:
	return {"local_id": local_id, "kind": kind, "layer_id": layer_id, "cell": cell, "object_local_id": object_local_id}

static func _connection(local_id: String, upper: String, lower: String) -> Dictionary:
	return {"local_id": local_id, "upper_anchor_id": upper, "lower_anchor_id": lower, "mode": "natural", "body_side_cells": 3, "safety_side_cells": 7}

static func _ordered(template: Dictionary) -> Dictionary:
	for key in ["layers", "objects", "anchors", "connections", "protected_areas"]:
		template[key].sort_custom(_by_local_id)
	return template

static func _by_local_id(a: Dictionary, b: Dictionary) -> bool:
	return a["local_id"] < b["local_id"]
