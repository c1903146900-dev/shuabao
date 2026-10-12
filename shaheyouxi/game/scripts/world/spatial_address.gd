extends RefCounted
## Stable logical address. No display offset or scene node is part of its identity.
const LAYER_FIELDS := ["world_id", "reference_frame", "body_instance_id", "map_kind", "depth"]
const PLANES := ["H0", "H0_OVERLAY", "H0_DECAL", "H1"]

static func is_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and floor(float(value)) == float(value) and absf(float(value)) <= 2147483647.0

static func is_body_instance_id(value: Variant) -> bool:
	if not value is String or not value.begins_with("body_") or value.length() < 6 or value.length() > 80:
		return false
	for character in value.trim_prefix("body_"):
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return true

static func valid_layer(value: Variant) -> bool:
	if not value is Dictionary or value.size() != LAYER_FIELDS.size():
		return false
	for field in LAYER_FIELDS:
		if not value.has(field):
			return false
	if not SandboxServerAuthority._valid_id(value["world_id"], "world_") or not is_body_instance_id(value["body_instance_id"]):
		return false
	if value["reference_frame"] != "celestial_local" or not is_integer(value["depth"]):
		return false
	return (value["map_kind"] == "surface" and value["depth"] == 0) or (value["map_kind"] == "underground" and value["depth"] > 0)

static func layer(world_id: String, body_instance_id: String, map_kind: String, depth: int) -> Dictionary:
	var result := {"world_id": world_id, "reference_frame": "celestial_local", "body_instance_id": body_instance_id, "map_kind": map_kind, "depth": depth}
	return result if valid_layer(result) else {}

static func key(value: Dictionary) -> String:
	if not valid_layer(value):
		return ""
	return "%s|celestial_local|%s|%s|%d" % [value["world_id"], value["body_instance_id"], value["map_kind"], int(value["depth"])]

static func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

static func cell_at(position: Vector2) -> Dictionary:
	if not position.is_finite() or absf(position.x) >= 2147483647.0 or absf(position.y) >= 2147483647.0:
		return {"ok": false, "code": "INVALID_POSITION"}
	return {"ok": true, "cell": Vector2i(floori(position.x), floori(position.y))}

static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) + Vector2(0.5, 0.5)
