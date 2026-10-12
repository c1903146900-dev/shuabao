extends RefCounted
## Opt-in, versioned JSON transport for a basic Variant tree only. No Object decoding.
## Every value is [tag, payload]. Dictionary payloads are [String key, tagged value]
## pairs, so duplicate keys survive JSON parsing and can be rejected explicitly.
## Depth counts edges from root (depth 0); nodes count values, including the root.
const FORMAT := "scalar_bits_le_v1"
const MAX_DEPTH := 64
const MAX_NODES := 100000
const HEX_DIGITS := "0123456789abcdef"

static func encode(value: Variant) -> Dictionary:
	return _encode(value, 0, {"nodes": 0})

static func decode(value: Variant) -> Dictionary:
	return _decode(value, 0, {"nodes": 0})

static func _encode(value: Variant, depth: int, budget: Dictionary) -> Dictionary:
	var limit: String = _enter(depth, budget)
	if not limit.is_empty():
		return _error(limit)
	match typeof(value):
		TYPE_NIL:
			return _ok(["null", null])
		TYPE_BOOL:
			return _ok(["bool", value])
		TYPE_STRING:
			return _ok(["string", value])
		TYPE_INT:
			var integer_bytes := PackedByteArray()
			integer_bytes.resize(8)
			integer_bytes.encode_s64(0, int(value))
			return _ok(["int64_le", integer_bytes.hex_encode()])
		TYPE_FLOAT:
			if not is_finite(float(value)):
				return _error("EXACT_SCALAR_NONFINITE")
			var float_bytes := PackedByteArray()
			float_bytes.resize(8)
			float_bytes.encode_double(0, float(value))
			return _ok(["float64_le", float_bytes.hex_encode()])
		TYPE_ARRAY:
			if value.size() > MAX_NODES - int(budget["nodes"]):
				return _error("EXACT_SCALAR_NODE_LIMIT")
			var items: Array = []
			for item in value:
				var encoded_item := _encode(item, depth + 1, budget)
				if not encoded_item["ok"]:
					return encoded_item
				items.append(encoded_item["value"])
			return _ok(["array", items])
		TYPE_DICTIONARY:
			if value.size() > MAX_NODES - int(budget["nodes"]):
				return _error("EXACT_SCALAR_NODE_LIMIT")
			var pairs: Array = []
			for key in value:
				if typeof(key) != TYPE_STRING:
					return _error("EXACT_SCALAR_DICTIONARY_KEY_INVALID")
				var encoded_value := _encode(value[key], depth + 1, budget)
				if not encoded_value["ok"]:
					return encoded_value
				pairs.append([key, encoded_value["value"]])
			return _ok(["dict", pairs])
		_:
			return _error("EXACT_SCALAR_UNSUPPORTED_TYPE")

static func _decode(value: Variant, depth: int, budget: Dictionary) -> Dictionary:
	var limit: String = _enter(depth, budget)
	if not limit.is_empty():
		return _error(limit)
	if not value is Array or value.size() != 2 or typeof(value[0]) != TYPE_STRING:
		return _error("EXACT_SCALAR_NODE_INVALID")
	var payload: Variant = value[1]
	match value[0]:
		"null":
			return _ok(null) if typeof(payload) == TYPE_NIL else _error("EXACT_SCALAR_PAYLOAD_INVALID")
		"bool":
			return _ok(payload) if typeof(payload) == TYPE_BOOL else _error("EXACT_SCALAR_PAYLOAD_INVALID")
		"string":
			return _ok(payload) if typeof(payload) == TYPE_STRING else _error("EXACT_SCALAR_PAYLOAD_INVALID")
		"int64_le", "float64_le":
			if not _valid_hex(payload):
				return _error("EXACT_SCALAR_HEX_INVALID")
			var bytes: PackedByteArray = payload.hex_decode()
			if value[0] == "int64_le":
				return _ok(bytes.decode_s64(0))
			var number: float = bytes.decode_double(0)
			return _ok(number) if is_finite(number) else _error("EXACT_SCALAR_NONFINITE")
		"array":
			if not payload is Array:
				return _error("EXACT_SCALAR_PAYLOAD_INVALID")
			if payload.size() > MAX_NODES - int(budget["nodes"]):
				return _error("EXACT_SCALAR_NODE_LIMIT")
			var items: Array = []
			for item in payload:
				var decoded_item := _decode(item, depth + 1, budget)
				if not decoded_item["ok"]:
					return decoded_item
				items.append(decoded_item["value"])
			return _ok(items)
		"dict":
			if not payload is Array:
				return _error("EXACT_SCALAR_PAYLOAD_INVALID")
			if payload.size() > MAX_NODES - int(budget["nodes"]):
				return _error("EXACT_SCALAR_NODE_LIMIT")
			var result: Dictionary = {}
			for pair in payload:
				if not pair is Array or pair.size() != 2 or typeof(pair[0]) != TYPE_STRING:
					return _error("EXACT_SCALAR_DICTIONARY_PAIR_INVALID")
				if result.has(pair[0]):
					return _error("EXACT_SCALAR_DUPLICATE_KEY")
				var decoded_value := _decode(pair[1], depth + 1, budget)
				if not decoded_value["ok"]:
					return decoded_value
				result[pair[0]] = decoded_value["value"]
			return _ok(result)
		_:
			return _error("EXACT_SCALAR_TAG_UNKNOWN")

static func _enter(depth: int, budget: Dictionary) -> String:
	if depth > MAX_DEPTH:
		return "EXACT_SCALAR_DEPTH_LIMIT"
	if int(budget["nodes"]) >= MAX_NODES:
		return "EXACT_SCALAR_NODE_LIMIT"
	budget["nodes"] = int(budget["nodes"]) + 1
	return ""

static func _valid_hex(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 16:
		return false
	for character in value:
		if character not in HEX_DIGITS:
			return false
	return true

static func _ok(value: Variant) -> Dictionary:
	return {"ok": true, "value": value}

static func _error(code: String) -> Dictionary:
	return {"ok": false, "code": code}
