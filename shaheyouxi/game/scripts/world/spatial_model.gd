extends RefCounted
## Server-owned layer data. Physics RIDs and visual decals are deliberately absent.
const Address = preload("res://scripts/world/spatial_address.gd")
const Inputs = preload("res://scripts/world/spatial_inputs.gd")
const START_BODY_INSTANCE_ID := "body_0001" # cehua original paragraph 143.
var ready: bool = false
var _world_id: String
var _inputs: Dictionary = {}
var _bodies: Dictionary = {}
var _layers: Dictionary = {}
var _instance_layers: Dictionary = {}
var last_error: String = ""

func _init(world_id: String, input_document: Dictionary) -> void:
	_world_id = world_id
	var checked := Inputs.new()
	ready = SandboxServerAuthority._valid_id(world_id, "world_") and checked.load_document(input_document)
	if ready:
		_inputs = checked.data.duplicate(true)
	else:
		last_error = "世界身份或空间输入无效"

func create_starting_body() -> Dictionary:
	if not ready:
		return _error("NOT_READY")
	if _bodies.has(START_BODY_INSTANCE_ID):
		return {"ok": true, "body": _bodies[START_BODY_INSTANCE_ID].duplicate(true)}
	if not _bodies.is_empty():
		return _error("START_BODY_MUST_BE_FIRST")
	var body := {"body_instance_id": START_BODY_INSTANCE_ID, "body_id": _inputs["starting_body"]["body_id"], "biome_id": _inputs["starting_body"]["biome_id"]}
	_bodies[START_BODY_INSTANCE_ID] = body
	return {"ok": true, "body": body.duplicate(true)}

func register_body(body_instance_id: String, body_id: String) -> Dictionary:
	if not ready or not _bodies.has(START_BODY_INSTANCE_ID):
		return _error("START_BODY_REQUIRED")
	if not Address.is_body_instance_id(body_instance_id) or not _inputs["body_definitions"].has(body_id) or _bodies.has(body_instance_id):
		return _error("INVALID_OR_DUPLICATE_BODY")
	for existing in _bodies.values():
		if existing["body_id"] == body_id:
			return _error("DUPLICATE_NATURAL_BODY_DEFINITION")
	_bodies[body_instance_id] = {"body_instance_id": body_instance_id, "body_id": body_id, "biome_id": ""}
	return {"ok": true}

func add_layer(identity: Dictionary, bounds: Rect2i) -> Dictionary:
	if not _valid_identity(identity) or not _valid_bounds(bounds):
		return _error("INVALID_LAYER")
	var layer_key := Address.key(identity)
	if _layers.has(layer_key):
		return _error("DUPLICATE_LAYER")
	var definition: Dictionary = _inputs["body_definitions"][_bodies[identity["body_instance_id"]]["body_id"]]
	var raw_layers: String = definition["raw_map_layers"]
	if identity["map_kind"] == "surface" and not raw_layers.contains("地表"):
		return _error("UNSUPPORTED_BODY_LAYER")
	if identity["map_kind"] == "underground":
		var expression := RegEx.new()
		expression.compile("地下([1-9][0-9]*)")
		var supported: Array = []
		for found in expression.search_all(raw_layers):
			supported.append(int(found.get_string(1)))
		if not (int(identity["depth"]) in supported):
			return _error("UNSUPPORTED_BODY_DEPTH")
	var canonical_identity := identity.duplicate(true)
	canonical_identity["depth"] = int(identity["depth"])
	_layers[layer_key] = {"identity": canonical_identity, "bounds": bounds, "h0_overrides": {}, "objects": {}, "occupancy": {"H0_OVERLAY": {}, "H1": {}}}
	return {"ok": true}

func set_h0(identity: Dictionary, cell: Vector2i, ground_resource_id: String) -> Dictionary:
	var layer_key := Address.key(identity)
	if not _layers.has(layer_key) or not _layers[layer_key]["bounds"].has_point(cell) or ground_resource_id != _inputs["starting_body"]["ground_resource_id"]:
		return _error("INVALID_GROUND")
	_layers[layer_key]["h0_overrides"][Address.cell_key(cell)] = ground_resource_id
	return {"ok": true}

func place_object(identity: Dictionary, plane: String, instance_id: String, content_id: String, anchor: Vector2i) -> Dictionary:
	var layer_key := Address.key(identity)
	if not ready or not _layers.has(layer_key) or not _inputs["object_definitions"].has(content_id):
		return _error("UNKNOWN_LAYER_OR_CONTENT")
	if not SandboxServerAuthority._valid_id(instance_id, "entity_") or _instance_layers.has(instance_id):
		return _error("INVALID_OR_DUPLICATE_INSTANCE")
	var definition: Dictionary = _inputs["object_definitions"][content_id]
	if plane not in ["H0_OVERLAY", "H1"] or plane != definition["plane"]:
		return _error("WRONG_PLANE_OR_VISUAL_ONLY")
	var size := Vector2i(int(definition["footprint_cells"][0]), int(definition["footprint_cells"][1]))
	var bounds: Rect2i = _layers[layer_key]["bounds"]
	# Check in int64 before adding into a Vector2i, preventing overflow/wrapped footprints.
	if anchor.x < bounds.position.x or anchor.y < bounds.position.y or int(anchor.x) + int(size.x) > int(bounds.position.x) + int(bounds.size.x) or int(anchor.y) + int(size.y) > int(bounds.position.y) + int(bounds.size.y):
		return _error("OUT_OF_BOUNDS")
	var occupied: Dictionary = _layers[layer_key]["occupancy"][plane]
	var cells: Array[Vector2i] = []
	for y in range(anchor.y, anchor.y + size.y):
		for x in range(anchor.x, anchor.x + size.x):
			var cell := Vector2i(x, y)
			if occupied.has(Address.cell_key(cell)):
				return _error("OCCUPIED")
			cells.append(cell)
	var record := {"instance_id": instance_id, "content_id": content_id, "plane": plane, "anchor": anchor}
	# Commit only after the entire footprint has been checked.
	_layers[layer_key]["objects"][instance_id] = record
	for cell in cells:
		occupied[Address.cell_key(cell)] = instance_id
	_instance_layers[instance_id] = layer_key
	return {"ok": true}

func remove_object(instance_id: String) -> Dictionary:
	if not _instance_layers.has(instance_id):
		return _error("UNKNOWN_INSTANCE")
	var layer_key: String = _instance_layers[instance_id]
	var record: Dictionary = _layers[layer_key]["objects"][instance_id]
	var occupied: Dictionary = _layers[layer_key]["occupancy"][record["plane"]]
	for cell_key in occupied.keys():
		if occupied[cell_key] == instance_id:
			occupied.erase(cell_key)
	_layers[layer_key]["objects"].erase(instance_id)
	_instance_layers.erase(instance_id)
	return {"ok": true}

func occupant(identity: Dictionary, plane: String, cell: Vector2i) -> String:
	var layer_key := Address.key(identity)
	if not _layers.has(layer_key) or not _layers[layer_key]["bounds"].has_point(cell):
		return ""
	if plane == "H0":
		return _layers[layer_key]["h0_overrides"].get(Address.cell_key(cell), _inputs["starting_body"]["ground_resource_id"])
	if plane not in ["H0_OVERLAY", "H1"]:
		return "" # H0_DECAL has no gameplay occupancy.
	return _layers[layer_key]["occupancy"][plane].get(Address.cell_key(cell), "")

func layer_view(identity: Dictionary) -> Dictionary:
	return _layers.get(Address.key(identity), {}).duplicate(true)

func definition(content_id: String) -> Dictionary:
	return _inputs["object_definitions"].get(content_id, {}).duplicate(true)

func body_view(body_instance_id: String) -> Dictionary:
	return _bodies.get(body_instance_id, {}).duplicate(true)

func snapshot() -> Dictionary:
	if not ready:
		return {}
	var body_ids: Array = _bodies.keys()
	body_ids.sort()
	var bodies: Array = []
	for body_id in body_ids:
		bodies.append(_bodies[body_id].duplicate(true))
	var layer_ids: Array = _layers.keys()
	layer_ids.sort()
	var layers: Array = []
	for layer_id in layer_ids:
		var source: Dictionary = _layers[layer_id]
		var bounds: Rect2i = source["bounds"]
		var objects: Array = []
		var ids: Array = source["objects"].keys()
		ids.sort()
		for instance_id in ids:
			var record: Dictionary = source["objects"][instance_id].duplicate(true)
			record["anchor"] = [record["anchor"].x, record["anchor"].y]
			objects.append(record)
		layers.append({"identity": source["identity"].duplicate(true), "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y], "h0_overrides": source["h0_overrides"].duplicate(true), "objects": objects})
	return {"spatial_schema_version": 1, "world_id": _world_id, "numeric_source_sha256": _inputs.get("sources", {}).get("shuzhi_sha256", ""), "body_instances": bodies, "layers": layers}

func restore(document: Variant) -> Dictionary:
	if not ready or not document is Dictionary or document.size() != 5 or document.get("spatial_schema_version") != 1 or document.get("world_id") != _world_id or document.get("numeric_source_sha256") != _inputs["sources"]["shuzhi_sha256"]:
		return _error("INCOMPATIBLE_SPATIAL_SNAPSHOT")
	if not document.get("body_instances") is Array or not document.get("layers") is Array:
		return _error("INVALID_SPATIAL_SNAPSHOT")
	# A blank candidate restores the saved IDs; it does not allocate a new starting body.
	var candidate = get_script().new(_world_id, _inputs)
	for body in document["body_instances"]:
		if not body is Dictionary or body.size() != 3 or not Address.is_body_instance_id(body.get("body_instance_id")) or not _inputs["body_definitions"].has(body.get("body_id")) or not body.get("biome_id") is String or candidate._bodies.has(body["body_instance_id"]):
			return _error("INVALID_BODY_RECORD")
		if body["body_instance_id"] != START_BODY_INSTANCE_ID and not body["biome_id"].is_empty():
			return _error("UNSUPPORTED_BODY_BIOME")
		for previous in candidate._bodies.values():
			if previous["body_id"] == body["body_id"]:
				return _error("DUPLICATE_BODY_DEFINITION")
		candidate._bodies[body["body_instance_id"]] = body.duplicate(true)
	var start: Dictionary = candidate._bodies.get(START_BODY_INSTANCE_ID, {})
	if start.get("body_id") != _inputs["starting_body"]["body_id"] or start.get("biome_id") != _inputs["starting_body"]["biome_id"]:
		return _error("MISSING_STARTING_BODY_RECORD")
	for layer in document["layers"]:
		if not layer is Dictionary or layer.size() != 4 or not Address.valid_layer(layer.get("identity")) or not _integer_array(layer.get("bounds"), 4) or not layer.get("h0_overrides") is Dictionary or not layer.get("objects") is Array:
			return _error("INVALID_LAYER_RECORD")
		var box: Array = layer["bounds"]
		var bounds := Rect2i(int(box[0]), int(box[1]), int(box[2]), int(box[3]))
		if not candidate.add_layer(layer["identity"], bounds)["ok"]:
			return _error("INVALID_LAYER_RECORD")
		for cell_key in layer["h0_overrides"]:
			var cell := _parse_cell_key(cell_key)
			if not cell["ok"] or not layer["h0_overrides"][cell_key] is String or not candidate.set_h0(layer["identity"], cell["cell"], layer["h0_overrides"][cell_key])["ok"]:
				return _error("INVALID_GROUND_RECORD")
		for record in layer["objects"]:
			if not record is Dictionary or record.size() != 4 or not _integer_array(record.get("anchor"), 2) or not record.get("instance_id") is String or not record.get("plane") is String or not record.get("content_id") is String:
				return _error("INVALID_OBJECT_RECORD")
			if not candidate.place_object(layer["identity"], record["plane"], record["instance_id"], record["content_id"], Vector2i(int(record["anchor"][0]), int(record["anchor"][1])))["ok"]:
				return _error("INVALID_OBJECT_RECORD")
	_bodies = candidate._bodies
	_layers = candidate._layers
	_instance_layers = candidate._instance_layers
	return {"ok": true}

func _valid_identity(identity: Dictionary) -> bool:
	return ready and Address.valid_layer(identity) and identity["world_id"] == _world_id and _bodies.has(identity["body_instance_id"])

static func _valid_bounds(bounds: Rect2i) -> bool:
	return bounds.size.x > 0 and bounds.size.y > 0 and Address.is_integer(int(bounds.position.x) + int(bounds.size.x)) and Address.is_integer(int(bounds.position.y) + int(bounds.size.y))

static func _integer_array(value: Variant, size: int) -> bool:
	if not value is Array or value.size() != size:
		return false
	for item in value:
		if not Address.is_integer(item):
			return false
	return true

static func _parse_cell_key(value: Variant) -> Dictionary:
	if not value is String:
		return {"ok": false}
	var pair: PackedStringArray = value.split(",")
	if pair.size() != 2 or not pair[0].is_valid_int() or not pair[1].is_valid_int():
		return {"ok": false}
	if not Address.is_integer(int(pair[0])) or not Address.is_integer(int(pair[1])):
		return {"ok": false}
	var cell := Vector2i(int(pair[0]), int(pair[1]))
	return {"ok": Address.cell_key(cell) == value, "cell": cell}

func _error(code: String) -> Dictionary:
	last_error = code
	return {"ok": false, "code": code}
