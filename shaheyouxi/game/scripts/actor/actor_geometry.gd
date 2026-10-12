extends RefCounted
## Pure same-time relative AABB sweep. All units are world cells.
## Native environment queries and whole-batch commit are separate integration work.
const EPSILON := 0.000001
# Godot Vector2 uses float32 in this build; tolerate representation noise only.
const POSITION_EPSILON := 0.0000001

static func overlaps(a: Vector2, b: Vector2, half_a: float, half_b: float) -> bool:
	var extent := half_a + half_b
	return absf(a.x - b.x) < extent - POSITION_EPSILON and absf(a.y - b.y) < extent - POSITION_EPSILON

static func relative_sweep(a: Vector2, b: Vector2, motion_a: Vector2, motion_b: Vector2, half_a: float, half_b: float) -> Dictionary:
	if not a.is_finite() or not b.is_finite() or not motion_a.is_finite() or not motion_b.is_finite() or not is_finite(half_a) or not is_finite(half_b) or half_a <= 0.0 or half_b <= 0.0:
		return {"ok": false, "code": "INVALID_GEOMETRY"}
	if overlaps(a, b, half_a, half_b):
		return {"ok": false, "code": "INITIAL_OVERLAP"}
	var position := a - b
	var motion := motion_a - motion_b
	var extent := half_a + half_b
	var entry := -INF
	var leave := INF
	var normals: Array[Vector2] = []
	for axis in range(2):
		var p: float = position[axis]
		var v: float = motion[axis]
		if v == 0.0:
			# Exact edge tangency never enters the open overlap region.
			if absf(p) >= extent - POSITION_EPSILON:
				return {"ok": true, "hit": false}
			continue
		var first := (-extent - p) / v
		var last := (extent - p) / v
		var normal := Vector2.ZERO
		normal[axis] = -signf(v)
		if first > last:
			var swap := first
			first = last
			last = swap
		if first > entry + EPSILON:
			entry = first
			normals = [normal]
		elif absf(first - entry) <= EPSILON:
			normals.append(normal)
		leave = minf(leave, last)
	if entry >= leave or leave <= 0.0 or entry < -EPSILON or entry > 1.0:
		return {"ok": true, "hit": false}
	return {"ok": true, "hit": true, "fraction": maxf(0.0, entry), "normals": normals}

static func constrain_pair(velocity_a: Vector2, velocity_b: Vector2, normal: Vector2) -> Dictionary:
	# Normal points from B toward A. Never inject a new pushing velocity.
	# Remove only closing normal components; preserve both tangential components.
	var a := velocity_a.dot(normal)
	var b := velocity_b.dot(normal)
	if a >= b:
		return {"a": velocity_a, "b": velocity_b}
	var target_a := a
	var target_b := b
	if a < 0.0 and b > 0.0:
		target_a = 0.0
		target_b = 0.0
	elif b <= 0.0:
		target_a = b
	else:
		target_b = a
	return {"a": velocity_a + normal * (target_a - a), "b": velocity_b + normal * (target_b - b)}

static func earliest_contacts(actors: Dictionary) -> Dictionary:
	## Caller supplies one exact logical layer only; this helper never aliases layers.
	## Records are preview values, never live bodies. No input dictionary is mutated.
	var ids := actors.keys()
	for actor_id in ids:
		if not actor_id is String or not actors[actor_id] is Dictionary:
			return {"ok": false, "code": "INVALID_PREVIEW_ACTOR"}
		var actor: Dictionary = actors[actor_id]
		if not actor.get("position") is Vector2 or not actor.get("motion") is Vector2 or not (actor.get("half_extent") is float or actor.get("half_extent") is int):
			return {"ok": false, "code": "INVALID_PREVIEW_ACTOR"}
		if not actor["position"].is_finite() or not actor["motion"].is_finite() or not is_finite(float(actor["half_extent"])) or float(actor["half_extent"]) <= 0.0:
			return {"ok": false, "code": "INVALID_PREVIEW_ACTOR"}
	ids.sort()
	var earliest := INF
	var contacts: Array[Dictionary] = []
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a: Dictionary = actors[ids[i]]
			var b: Dictionary = actors[ids[j]]
			var hit := relative_sweep(a["position"], b["position"], a["motion"], b["motion"], float(a["half_extent"]), float(b["half_extent"]))
			if not hit["ok"]:
				return hit
			if not hit["hit"]:
				continue
			var fraction: float = hit["fraction"]
			if fraction < earliest - EPSILON:
				earliest = fraction
				contacts.clear()
			if absf(fraction - earliest) <= EPSILON:
				earliest = minf(earliest, fraction)
				contacts.append({"a": ids[i], "b": ids[j], "normals": hit["normals"]})
	return {"ok": true, "hit": not contacts.is_empty(), "fraction": earliest if not contacts.is_empty() else 1.0, "contacts": contacts}
