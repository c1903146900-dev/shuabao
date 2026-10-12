extends RefCounted
## Pure server-side candidate selection, not an interaction/transfer transaction.
## Caller must first verify the complete server-owned world component with World.
## These defensive structural checks do not replace its source/fingerprint checks.
const Address = preload("res://scripts/world/spatial_address.gd")
const CONNECTION_FIELDS := ["connection_instance_id", "endpoints", "body_side_cells", "safety_rect", "natural", "bidirectional", "interaction_required"]

static func select_natural_entry(component: Variant, actor_layer: Variant, actor_position: Variant, aim: Variant, interaction_range: Variant) -> Dictionary:
	if not Address.valid_layer(actor_layer) or not actor_position is Vector2 or not actor_position.is_finite() or not aim is Vector2 or not aim.is_finite():
		return _reject("INTERACTION_ADDRESS_INVALID")
	if typeof(interaction_range) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(interaction_range)) or interaction_range <= 0.0:
		return _reject("INTERACTION_RANGE_INVALID")
	if not component is Dictionary or not component.get("layout") is Dictionary:
		return _reject("INTERACTION_LAYOUT_INVALID")
	var layout: Dictionary = component["layout"]
	if layout.get("world_id") != actor_layer["world_id"] or not layout.get("connections") is Array:
		return _reject("INTERACTION_LAYOUT_INVALID")
	var ids: Dictionary = {}
	var pointed: Array = []
	for connection in layout["connections"]:
		if not _valid_connection(connection, layout["world_id"]):
			return _reject("INTERACTION_CONNECTION_INVALID")
		var connection_id: String = connection["connection_instance_id"]
		if ids.has(connection_id):
			return _reject("INTERACTION_DUPLICATE_CONNECTION")
		ids[connection_id] = true
		for index in range(2):
			var endpoint: Dictionary = connection["endpoints"][index]
			# Compare all logical address fields, never depth/map-kind alone.
			if Address.key(endpoint["layer"]) != Address.key(actor_layer):
				continue
			var cell := Vector2i(int(endpoint["cell"][0]), int(endpoint["cell"][1]))
			var side: int = int(connection["body_side_cells"])
			var half: int = (side - 1) >> 1
			# Actual generated body footprint (currently table-derived 3x3), not
			# the 7x7 safety surround, a point-radius, or a nearest-entry search.
			var body := Rect2(Vector2(cell - Vector2i(half, half)), Vector2(side, side))
			if not body.has_point(aim):
				continue
			# Existing cell-to-world mapping is a technical anchor choice; the
			# original source does not prescribe a separate subcell anchor.
			var point := Address.cell_center(cell)
			pointed.append({"kind": "natural_layer_entry", "connection_instance_id": connection_id, "endpoint_index": index, "source_endpoint": endpoint.duplicate(true), "destination_endpoint": connection["endpoints"][1 - index].duplicate(true), "interaction_point": [point.x, point.y]})
	if pointed.is_empty():
		return _reject("INTERACTION_NO_POINTED_ENTRY")
	if pointed.size() != 1:
		return _reject("INTERACTION_AMBIGUOUS_ENTRY")
	var candidate: Dictionary = pointed[0]
	var dx: float = float(actor_position.x) - float(candidate["interaction_point"][0])
	var dy: float = float(actor_position.y) - float(candidate["interaction_point"][1])
	# Inclusive source range, measured from authoritative actor position to the
	# entry anchor; pointer proximity/body radius never extends it. No epsilon.
	if dx * dx + dy * dy > float(interaction_range) * float(interaction_range):
		return _reject("INTERACTION_OUT_OF_RANGE")
	return {"ok": true, "selected": true, "candidate": candidate.duplicate(true)}

static func _valid_connection(value: Variant, world_id: String) -> bool:
	if not value is Dictionary or value.size() != CONNECTION_FIELDS.size():
		return false
	for field in CONNECTION_FIELDS:
		if not value.has(field):
			return false
	if not SandboxServerAuthority._valid_id(value["connection_instance_id"], "connection_"):
		return false
	for flag in ["natural", "bidirectional", "interaction_required"]:
		if typeof(value[flag]) != TYPE_BOOL or not value[flag]:
			return false
	if not Address.is_integer(value["body_side_cells"]) or value["body_side_cells"] <= 0 or int(value["body_side_cells"]) % 2 != 1:
		return false
	var endpoints: Variant = value["endpoints"]
	if not endpoints is Array or endpoints.size() != 2:
		return false
	for endpoint in endpoints:
		if not endpoint is Dictionary or endpoint.size() != 2 or not Address.valid_layer(endpoint.get("layer")) or not _integer_array(endpoint.get("cell"), 2):
			return false
		if endpoint["layer"]["world_id"] != world_id:
			return false
	var upper: Dictionary = endpoints[0]["layer"]
	var lower: Dictionary = endpoints[1]["layer"]
	if upper["body_instance_id"] != lower["body_instance_id"] or int(upper["depth"]) not in [0, 1] or int(lower["depth"]) != int(upper["depth"]) + 1 or endpoints[0]["cell"] != endpoints[1]["cell"]:
		return false
	var safety: Variant = value["safety_rect"]
	if not _integer_array(safety, 4) or safety[2] < value["body_side_cells"] or safety[2] != safety[3] or int(safety[2]) % 2 != 1:
		return false
	var half: int = (int(safety[2]) - 1) >> 1
	return safety[0] == endpoints[0]["cell"][0] - half and safety[1] == endpoints[0]["cell"][1] - half

static func _integer_array(value: Variant, length: int) -> bool:
	if not value is Array or value.size() != length:
		return false
	for item in value:
		if not Address.is_integer(item):
			return false
	return true

static func _reject(code: String) -> Dictionary:
	return {"ok": false, "selected": false, "code": code}
