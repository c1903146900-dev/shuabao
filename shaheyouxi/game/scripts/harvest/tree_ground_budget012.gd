extends RefCounted
## Arithmetic only. This does not validate a world, grant publication, bind a
## lease, or turn a profile5 proof into a profile6 proof. No Owner/Frame hooks.
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const BoundedStore = preload("res://scripts/inventory/inventory_world_save_store012.gd")
const FORMAT := "tree_ground_budget012.measurement.v1"
const MAX_BYTES := 4194304
const MAX_SEQUENCE := 9007199254740991
const STATIC_ROOT_DEPTH := 2
const METRIC_FIELDS := ["ok", "measurement_only", "format", "codec_format", "root_depth", "maximum_bytes", "maximum_nodes", "maximum_depth", "null_escaped_bytes", "world", "terrain", "bytes_delta", "nodes_delta"]
const COMPONENT_FIELDS := ["escaped_bytes", "codec_nodes", "local_depth"]

static func static_measure(world: Variant, terrain: Variant) -> Dictionary:
	# The actual SaveStore payload is root0 -> state1 -> component2. Encoding
	# either component at depth0 would wrongly admit local depths63 and64.
	var encoded: Dictionary = Codec.encode({"state": {"world_component": world, "terrain_component": terrain}})
	if not encoded.get("ok", false):
		return _bad(str(encoded.get("code", "TREE_GROUND_BUDGET_STATIC_CODEC")))
	var state: Array = _tagged_child(encoded["value"], "state")
	var world_measure := _fragment_measure(_tagged_child(state, "world_component"))
	var terrain_measure := _fragment_measure(_tagged_child(state, "terrain_component"))
	var null_bytes := _escaped_bytes(["null", null])
	var result: Dictionary = {
		"ok": true, "measurement_only": true, "format": FORMAT,
		"codec_format": Codec.FORMAT, "root_depth": STATIC_ROOT_DEPTH,
		"maximum_bytes": MAX_BYTES, "maximum_nodes": Codec.MAX_NODES,
		"maximum_depth": Codec.MAX_DEPTH, "null_escaped_bytes": null_bytes,
		"world": world_measure, "terrain": terrain_measure,
		"bytes_delta": world_measure["escaped_bytes"] + terrain_measure["escaped_bytes"] - 2 * null_bytes,
		"nodes_delta": world_measure["codec_nodes"] + terrain_measure["codec_nodes"] - 2,
	}
	# Only numbers/strings/bools remain. No static graph or source identity is
	# retained. Readonly helps accidental misuse; it is NOT an authenticity seal.
	world_measure.make_read_only()
	terrain_measure.make_read_only()
	result.make_read_only()
	return result

static func measure_profile(store: Variant, profile: Variant, reduced_state: Variant, metrics: Variant) -> Dictionary:
	if typeof(profile) != TYPE_INT or profile not in [5, 6]:
		return _bad("TREE_GROUND_BUDGET_PROFILE")
	# Exact script identity excludes subclasses, mocks and overridden encoders.
	if not store is RefCounted or store.get_script() != SaveStore:
		return _bad("TREE_GROUND_BUDGET_STORE_BINDING")
	if store._schema_version != profile or not store._exact_scalars or store._maximum_bytes != MAX_BYTES:
		return _bad("TREE_GROUND_BUDGET_STORE_BINDING")
	if not reduced_state is Dictionary or not reduced_state.has("world_id") or typeof(reduced_state["world_id"]) != TYPE_STRING:
		return _bad("TREE_GROUND_BUDGET_REDUCED_STATE")
	# Missing is not null. Never silently insert placeholders or discard data.
	for field in ["world_component", "terrain_component"]:
		if not reduced_state.has(field) or typeof(reduced_state[field]) != TYPE_NIL:
			return _bad("TREE_GROUND_BUDGET_REDUCED_STATE")
	if not _metrics_valid(metrics):
		return _bad("TREE_GROUND_BUDGET_STATIC_METRICS")
	# Real per-profile metadata and dynamic depth/node checks. _encode has NO
	# byte-limit early return: an empty string means the ExactCodec rejected it.
	var envelope: String = store._encode(reduced_state, MAX_SEQUENCE, "manual", "W".repeat(BoundedStore.MAX_REASON), 63)
	if envelope.is_empty():
		return _bad("TREE_GROUND_BUDGET_REDUCED_CODEC")
	var outer: Variant = JSON.parse_string(envelope)
	if not outer is Dictionary or typeof(outer.get("payload_json")) != TYPE_STRING:
		return _bad("TREE_GROUND_BUDGET_ENCODED_PAYLOAD")
	var tagged: Variant = JSON.parse_string(outer["payload_json"])
	if not tagged is Array or tagged.size() != 2 or tagged[0] != "dict":
		return _bad("TREE_GROUND_BUDGET_ENCODED_PAYLOAD")
	# Count original Variant VALUES, including actual metadata/root/state.
	# Dictionary keys, codec tag arrays and outer JSON fields are not nodes.
	var shape := _tagged_shape(tagged)
	var size: int = envelope.to_utf8_buffer().size() + metrics["bytes_delta"]
	var nodes: int = shape["codec_nodes"] + metrics["nodes_delta"]
	var result := {
		"ok": size <= MAX_BYTES and nodes <= Codec.MAX_NODES,
		"measurement_only": true, "profile": profile,
		"envelope_bytes": size, "codec_nodes": nodes,
		"byte_limit_ok": size <= MAX_BYTES, "node_limit_ok": nodes <= Codec.MAX_NODES,
	}
	if size > MAX_BYTES:
		result["code"] = "TREE_GROUND_BUDGET_FINAL_BYTES_LIMIT"
	elif nodes > Codec.MAX_NODES:
		result["code"] = "TREE_GROUND_BUDGET_FINAL_NODE_LIMIT"
	return result

static func measure_dual(store5: Variant, store6: Variant, reduced5: Variant, reduced6: Variant, metrics: Variant) -> Dictionary:
	# Neither profile is inferred from the other. Even on an inner rejection,
	# evaluate the outer measurement independently and report both outcomes.
	var inner := measure_profile(store5, 5, reduced5, metrics)
	var outer := measure_profile(store6, 6, reduced6, metrics)
	var result := {"ok": inner["ok"] and outer["ok"], "measurement_only": true, "profile5": inner, "profile6": outer}
	if not inner["ok"]:
		result["failed_profile"] = 5
		result["code"] = inner["code"]
	elif not outer["ok"]:
		result["failed_profile"] = 6
		result["code"] = outer["code"]
	return result

static func _metrics_valid(value: Variant) -> bool:
	if not _fields(value, METRIC_FIELDS):
		return false
	if typeof(value["ok"]) != TYPE_BOOL or not value["ok"] or typeof(value["measurement_only"]) != TYPE_BOOL or not value["measurement_only"]:
		return false
	if typeof(value["format"]) != TYPE_STRING or value["format"] != FORMAT or typeof(value["codec_format"]) != TYPE_STRING or value["codec_format"] != Codec.FORMAT:
		return false
	for pair in [["root_depth", STATIC_ROOT_DEPTH], ["maximum_bytes", MAX_BYTES], ["maximum_nodes", Codec.MAX_NODES], ["maximum_depth", Codec.MAX_DEPTH], ["null_escaped_bytes", _escaped_bytes(["null", null])]]:
		if typeof(value[pair[0]]) != TYPE_INT or value[pair[0]] != pair[1]:
			return false
	for name in ["world", "terrain"]:
		var component: Variant = value[name]
		if not _fields(component, COMPONENT_FIELDS):
			return false
		if not _integer_between(component["escaped_bytes"], _escaped_bytes(["dict", []]), MAX_SEQUENCE) or not _integer_between(component["codec_nodes"], 1, Codec.MAX_NODES):
			return false
		if not _integer_between(component["local_depth"], 0, Codec.MAX_DEPTH - STATIC_ROOT_DEPTH) or component["local_depth"] >= component["codec_nodes"]:
			return false
	# Empty dictionaries serialize shorter than null: byte deltas are signed.
	var minimum_delta: int = 2 * _escaped_bytes(["dict", []]) - 2 * value["null_escaped_bytes"]
	if not _integer_between(value["bytes_delta"], minimum_delta, MAX_SEQUENCE) or not _integer_between(value["nodes_delta"], 0, Codec.MAX_NODES):
		return false
	var world: Dictionary = value["world"]
	var terrain: Dictionary = value["terrain"]
	return value["bytes_delta"] == world["escaped_bytes"] + terrain["escaped_bytes"] - 2 * value["null_escaped_bytes"] and value["nodes_delta"] == world["codec_nodes"] + terrain["codec_nodes"] - 2 and world["codec_nodes"] + terrain["codec_nodes"] + 2 <= Codec.MAX_NODES

static func _fragment_measure(tagged: Array) -> Dictionary:
	var result := _tagged_shape(tagged)
	result["escaped_bytes"] = _escaped_bytes(tagged)
	return result

static func _escaped_bytes(tagged: Array) -> int:
	# First serialize the actual ExactCodec tag tree. Then escape that JSON as
	# the outer payload_json string. Both surrounding quotes cancel in deltas.
	var fragment: String = JSON.stringify(tagged, "", true, true)
	return JSON.stringify(fragment, "", true, true).to_utf8_buffer().size()

static func _tagged_shape(tagged: Array) -> Dictionary:
	# Private: input comes only from successful actual Codec/SaveStore encoding.
	var nodes: int = 1
	var depth: int = 0
	if tagged[0] == "dict":
		for pair in tagged[1]:
			var child := _tagged_shape(pair[1])
			nodes += child["codec_nodes"]
			depth = maxi(depth, child["local_depth"] + 1)
	elif tagged[0] == "array":
		for item in tagged[1]:
			var child := _tagged_shape(item)
			nodes += child["codec_nodes"]
			depth = maxi(depth, child["local_depth"] + 1)
	return {"codec_nodes": nodes, "local_depth": depth}

static func _tagged_child(tagged: Array, key: String) -> Array:
	for pair in tagged[1]:
		if pair[0] == key:
			return pair[1]
	return [] # Internal keys are supplied immediately above, not caller input.

static func _integer_between(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) == TYPE_INT and value >= minimum and value <= maximum

static func _fields(value: Variant, names: Array) -> bool:
	if not value is Dictionary or value.size() != names.size():
		return false
	for name in names:
		if not value.has(name):
			return false
	return true

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "measurement_only": true, "code": code}
