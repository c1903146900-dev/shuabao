extends RefCounted
## Detached peer-only reconnect candidates. Caller must supply ALL active peers
## already filtered by the retained full Address.key. No environment/native/join
## operation occurs here. Success is a minimum in the stated numerical metric,
## not an arbitrary-precision Euclidean or full-environment placement proof.
const Geometry = preload("res://scripts/actor/actor_geometry.gd")
const METRIC := "scalar_float64_squared_distance_on_finite_binary32"
const MAX_FINITE_BITS := 0x7f7fffff
const ZERO_KEY := MAX_FINITE_BITS
const MAX_KEY := 2 * MAX_FINITE_BITS
const MAX_PEERS := 256 # Technical work limit; not a gameplay player limit.
const MAX_CANDIDATE_LIMIT := 65536
const MAX_PREDICATE_CHECKS := 1048576

static func nearest(original: Variant, peers: Variant, half: Variant, max_candidates: int = 4096) -> Dictionary:
	if not _vector(original) or not peers is Array or not _number(half) or half <= 0.0 or max_candidates <= 0 or max_candidates > MAX_CANDIDATE_LIMIT:
		return _error("INVALID_PEER_RECONNECT_INPUT")
	var half_extent := float(half)
	var extent := half_extent + half_extent - Geometry.POSITION_EPSILON
	if not is_finite(extent) or extent <= 0.0:
		return _error("INVALID_PEER_RECONNECT_EXTENT")
	if peers.size() > MAX_PEERS:
		return _error("PEER_RECONNECT_WORK_LIMIT")
	for peer in peers:
		if not _vector(peer):
			return _error("INVALID_PEER_RECONNECT_PEER")
	# Original placement takes precedence over enumeration, without grid snapping.
	if _peer_free(original, peers, half_extent):
		return _result([original], 0.0, 0)
	var xs: Dictionary = {float(original.x): true}
	var ys: Dictionary = {float(original.y): true}
	for peer in peers:
		for axis in range(2):
			for direction in [-1, 1]:
				var edge := _outside_boundary(float(peer[axis]), extent, direction)
				if not edge["ok"]:
					return edge
				if edge["exists"]:
					if axis == 0:
						xs[edge["value"]] = true
					else:
						ys[edge["value"]] = true
	var x_values := xs.keys()
	var y_values := ys.keys()
	x_values.sort()
	y_values.sort()
	var count := x_values.size() * y_values.size()
	if count > max_candidates:
		return _error("PEER_RECONNECT_CANDIDATE_LIMIT")
	# Each boundary has <=32 bisections plus its endpoint/certificate checks.
	if count * peers.size() + peers.size() * 4 * 36 > MAX_PREDICATE_CHECKS:
		return _error("PEER_RECONNECT_WORK_LIMIT")
	var best := INF
	var positions: Array[Vector2] = []
	for x in x_values:
		for y in y_values:
			var point := Vector2(x, y)
			if not point.is_finite() or float(point.x) != x or float(point.y) != y:
				return _error("UNREPRESENTABLE_PEER_RECONNECT_COORDINATE")
			if not _peer_free(point, peers, half_extent):
				continue
			var dx := float(point.x) - float(original.x)
			var dy := float(point.y) - float(original.y)
			var distance_squared := dx * dx + dy * dy
			if not is_finite(distance_squared):
				return _error("UNREPRESENTABLE_PEER_RECONNECT_DISTANCE")
			if distance_squared < best:
				best = distance_squared
				positions.clear()
			if distance_squared == best:
				positions.append(point)
	if positions.is_empty():
		return _error("NO_PEER_FREE_FINITE_POINT")
	# Ascending x then y enumeration already gives a stable order for exact ties.
	# Publish only after the complete bounded scan; no partial best on failure.
	return _result(positions, best, count)

static func _outside_boundary(center: float, extent: float, direction: int) -> Dictionary:
	var inside_key := _key(center)
	var outside_key := 0 if direction < 0 else MAX_KEY
	var extreme := _coordinate(outside_key)
	if not extreme["ok"]:
		return extreme
	if _axis_occupied(extreme["value"], center, extent):
		# Monotonicity on this side proves no outside finite coordinate exists.
		return {"ok": true, "exists": false}
	for iteration in range(32):
		if absi(outside_key - inside_key) <= 1:
			break
		var middle := (outside_key + inside_key) >> 1
		var value := _coordinate(middle)
		if not value["ok"]:
			return value
		if _axis_occupied(value["value"], center, extent):
			inside_key = middle
		else:
			outside_key = middle
	if absi(outside_key - inside_key) != 1:
		return _error("UNRESOLVED_PEER_AXIS_TRANSITION")
	var outside := _coordinate(outside_key)
	var inside := _coordinate(inside_key)
	if not outside["ok"]:
		return outside
	if not inside["ok"]:
		return inside
	if _axis_occupied(outside["value"], center, extent) or not _axis_occupied(inside["value"], center, extent):
		return _error("UNRESOLVED_PEER_AXIS_TRANSITION")
	return {"ok": true, "exists": true, "value": outside["value"]}

static func _axis_occupied(value: float, center: float, extent: float) -> bool:
	# Match Geometry.overlaps' scalar component subtraction, NOT Vector2 delta.
	return absf(value - center) < extent

static func _peer_free(position: Vector2, peers: Array, half: float) -> bool:
	for peer in peers:
		if Geometry.overlaps(position, peer, half, half):
			return false
	return true

static func _key(value: float) -> int:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, value)
	var bits := bytes.decode_u32(0)
	var magnitude := bits & 0x7fffffff
	# Canonical zero collapses -0/+0. Every remaining finite binary32 appears
	# once, in numerical order, from -max (key 0) to +max (key MAX_KEY).
	return ZERO_KEY - magnitude if bits & 0x80000000 else ZERO_KEY + magnitude

static func _coordinate(key: int) -> Dictionary:
	if key < 0 or key > MAX_KEY:
		return _error("INVALID_BINARY32_ORDER_KEY")
	var bits := (0x80000000 | (ZERO_KEY - key)) if key < ZERO_KEY else key - ZERO_KEY
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, bits)
	var value := bytes.decode_float(0)
	# Refuse a platform conversion that flushes/aliases a decoded coordinate.
	if not is_finite(value) or _key(value) != key:
		return _error("UNREPRESENTABLE_BINARY32_AXIS")
	return {"ok": true, "value": value}

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _vector(value: Variant) -> bool:
	return value is Vector2 and value.is_finite()

static func _result(positions: Array, distance_squared: float, candidate_count: int) -> Dictionary:
	return {"ok": true, "positions": positions, "distance_squared": distance_squared, "metric": METRIC, "candidate_count": candidate_count}

static func _error(code: String) -> Dictionary:
	return {"ok": false, "code": code}
