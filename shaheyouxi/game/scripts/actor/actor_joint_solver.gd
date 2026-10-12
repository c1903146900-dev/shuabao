extends RefCounted
## Read-only simultaneous preview resolver. Never moves a model or Physics RID.
## Native environment queries must exclude peers and use the registered full layer.
const Geometry = preload("res://scripts/actor/actor_geometry.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const Circle = preload("res://scripts/actor/actor_circle_boundary.gd")
const CIRCLE_SAGITTA := 0.0001 # Inward curvature approximation, never outward allowance.
const MAX_CIRCLE_INTERVALS := 256
const VALUE_EPSILON := 0.00001
const DEFAULT_MAX_EVENTS := 256
const DEFAULT_MAX_CONSTRAINT_PASSES := 64
const MAX_EVENT_RETREATS := 64
const MAX_ACTORS := 256
const MAX_SEGMENTS := 4096
const PHASES := ["idle", "dead", "controlled", "dodge", "walk"]

static func resolve(preview: Variant, environment_query: Callable, expected_half_extent: Variant, limits: Dictionary = {}, circle_boundaries: Variant = null) -> Dictionary:
	var checked := _validate(preview, limits, expected_half_extent)
	if not checked["ok"]:
		return checked
	if not environment_query.is_valid():
		return _failure("ENVIRONMENT_QUERY_REQUIRED")
	if circle_boundaries != null:
		return _resolve_circle(preview, environment_query, float(expected_half_extent), limits, circle_boundaries, checked)
	# Detached values only. Preview freshness remains ActorMotion.commit_preview's job.
	var source: Dictionary = preview.duplicate(true)
	var ids: Array = checked["ids"]
	var boundaries: Array = checked["boundaries"]
	var actors: Dictionary = source["actors"]
	var positions: Dictionary = {}
	var resolved: Dictionary = {}
	for actor_id in ids:
		positions[actor_id] = actors[actor_id]["position"]
		resolved[actor_id] = {"layer": actors[actor_id]["layer"].duplicate(true)}
	var initial := _separated(ids, actors, positions)
	if not initial["ok"]:
		return initial
	# The adapter must reject unknown terrain and existing environment penetration.
	for actor_id in ids:
		var query := _query(environment_query, actor_id, actors[actor_id], positions[actor_id], Vector2.ZERO)
		if not query["ok"]:
			return query
		if query["hit"]:
			return _failure("INITIAL_ENVIRONMENT_CONTACT", actor_id)
	var trajectory: Array[Dictionary] = []
	var events: Array[Dictionary] = []
	var iterations := 0
	var max_events: int = limits.get("max_events", DEFAULT_MAX_EVENTS)
	var max_passes: int = limits.get("max_constraint_passes", DEFAULT_MAX_CONSTRAINT_PASSES)
	for interval_index in range(boundaries.size() - 1):
		var now: float = boundaries[interval_index]
		var until: float = boundaries[interval_index + 1]
		var velocities: Dictionary = {}
		var phases: Dictionary = {}
		for actor_id in ids:
			var segment := _segment_at(actors[actor_id]["segments"], now)
			velocities[actor_id] = segment["velocity"]
			phases[actor_id] = segment["phase"]
		while now < until:
			if iterations >= max_events:
				return _failure("JOINT_EVENT_LIMIT")
			iterations += 1
			var remaining := until - now
			var earliest := _earliest(ids, actors, positions, velocities, remaining, environment_query)
			if not earliest["ok"]:
				return earliest
			var fraction: float = earliest["fraction"]
			var finish := until if fraction == 1.0 else now + remaining * fraction
			if finish > now:
				var step := _advance(ids, actors, positions, velocities, phases, now, finish, not earliest["contacts"].is_empty(), environment_query, max_passes)
				if not step["ok"]:
					return step
				if step["span"] != null:
					trajectory.append(step["span"])
				now = step["at"]
			if earliest["contacts"].is_empty():
				break
			# Keep the original normals even when representation requires retreating
			# all the way to now. Apply them early, then consume the true remainder.
			var before := velocities.duplicate(true)
			var constrained := _constrain(earliest["contacts"], velocities, max_passes)
			if not constrained["ok"]:
				return constrained
			events.append({"kind": "contact", "at": now, "contacts": earliest["contacts"].duplicate(true), "before_velocities": before, "after_velocities": velocities.duplicate(true)})
			# Requery EVERY actor after constraints; a changed leader or wall slide can
			# expose a new zero-time peer contact. Never advance on unresolved contact.
			if now < until and velocities == before:
				return _failure("JOINT_CONTACT_NO_PROGRESS")
		for actor_id in ids:
			if actors[actor_id]["dodge_end_at"] != null and float(actors[actor_id]["dodge_end_at"]) == until:
				resolved[actor_id]["dodge_end_position"] = positions[actor_id]
	for actor_id in ids:
		resolved[actor_id]["position"] = positions[actor_id]
	var budgets := _resolved_budgets(ids, actors, resolved)
	if not budgets["ok"]:
		return budgets
	return {"ok": true, "positions": resolved, "resolved_positions": resolved.duplicate(true), "trajectory": trajectory, "events": events, "from": source["from"], "to": source["to"], "iterations": iterations}

# Circle mode is a detached branch: the null-boundary legacy path is unchanged.
static func _resolve_circle(preview: Dictionary, environment_query: Callable, expected_half: float, limits: Dictionary, boundaries_input: Variant, checked: Dictionary) -> Dictionary:
	var source := preview.duplicate(true)
	var ids: Array = checked["ids"]
	var actors: Dictionary = source["actors"]
	var validation := _circle_shapes(ids, actors, expected_half, boundaries_input)
	if not validation["ok"]:
		return validation
	var shapes: Dictionary = validation["shapes"]
	var positions: Dictionary = {}
	var resolved: Dictionary = {}
	var active: Dictionary = {}
	for actor_id in ids:
		positions[actor_id] = actors[actor_id]["position"]
		resolved[actor_id] = {"layer": actors[actor_id]["layer"].duplicate(true)}
		var query := _query(environment_query, actor_id, actors[actor_id], positions[actor_id], Vector2.ZERO)
		if not query["ok"]:
			return query
		if query["hit"]:
			return _failure("INITIAL_ENVIRONMENT_CONTACT", actor_id)
	var separated := _separated(ids, actors, positions)
	if not separated["ok"]:
		return separated
	var trajectory: Array[Dictionary] = []
	var events: Array[Dictionary] = []
	var iterations := 0
	var circle_intervals := 0
	var max_events: int = limits.get("max_events", DEFAULT_MAX_EVENTS)
	var max_passes: int = limits.get("max_constraint_passes", DEFAULT_MAX_CONSTRAINT_PASSES)
	var boundaries: Array = checked["boundaries"]
	for index in range(boundaries.size() - 1):
		var now: float = boundaries[index]
		var until: float = boundaries[index + 1]
		var intents: Dictionary = {}
		var phases: Dictionary = {}
		# Artificial curvature steps never clear these physical contact constraints.
		var retained: Array[Dictionary] = []
		for actor_id in ids:
			var segment := _segment_at(actors[actor_id]["segments"], now)
			intents[actor_id] = segment["velocity"]
			phases[actor_id] = segment["phase"]
		while now < until:
			if iterations >= max_events:
				return _failure("JOINT_EVENT_LIMIT")
			iterations += 1
			var plan := _circle_plan(ids, positions, intents, retained, active, shapes, until - now, max_passes)
			if not plan["ok"]:
				return plan
			var duration: float = plan["duration"]
			if duration == 0.0:
				var changed := false
				for contact in plan["circle_hits"]:
					if not active.has(contact["actor_id"]):
						active[contact["actor_id"]] = true
						changed = true
				if not changed:
					return _failure("CIRCLE_CONTACT_NO_PROGRESS")
				events.append({"kind": "circle", "at": now, "contacts": plan["circle_hits"].duplicate(true)})
				continue
			if now + duration <= now:
				return _failure("IMPRECISE_CIRCLE_CLOCK")
			if plan["curved"]:
				if circle_intervals >= MAX_CIRCLE_INTERVALS:
					return _failure("CIRCLE_INTERVAL_LIMIT")
				circle_intervals += 1
			var velocities: Dictionary = plan["velocities"]
			var motions: Dictionary = {}
			var endpoints: Dictionary = {}
			var endpoint_budgets: Dictionary = {}
			for actor_id in ids:
				var budget := minf(float(intents[actor_id].length()), float(plan["speed_limits"][actor_id])) * duration
				var target: Vector2 = plan["targets"].get(actor_id, positions[actor_id] + velocities[actor_id] * duration)
				var fitted := _circle_fit_target(positions[actor_id], target, budget, shapes[actor_id])
				if not fitted["ok"]:
					return fitted
				endpoints[actor_id] = fitted["position"]
				endpoint_budgets[actor_id] = _distance64(positions[actor_id], fitted["position"])
				motions[actor_id] = fitted["position"] - positions[actor_id]
				velocities[actor_id] = motions[actor_id] / duration
			var earliest := _circle_earliest(ids, actors, positions, motions, environment_query)
			if not earliest["ok"]:
				return earliest
			var fraction: float = earliest["fraction"]
			var finish := minf(until, now + duration * fraction)
			var at_circle: bool = fraction == 1.0 and not plan["circle_hits"].is_empty()
			if finish > now:
				var event_endpoints: Dictionary = {}
				var event_budgets: Dictionary = {}
				for actor_id in ids:
					event_endpoints[actor_id] = _endpoint_prefix(positions[actor_id], endpoints[actor_id], fraction)
					event_budgets[actor_id] = float(endpoint_budgets[actor_id]) * fraction
				var step := _advance(ids, actors, positions, velocities, phases, now, finish, at_circle or not earliest["contacts"].is_empty(), environment_query, max_passes, shapes, event_endpoints, event_budgets)
				if not step["ok"]:
					return step
				if step["span"] != null:
					trajectory.append(step["span"])
				now = step["at"]
			if not earliest["contacts"].is_empty():
				var before := velocities.duplicate(true)
				var old_count := retained.size()
				for contact in earliest["contacts"]:
					var persistent: Dictionary = contact.duplicate(true)
					persistent.erase("fraction")
					if not retained.has(persistent):
						retained.append(persistent)
				var constrained := _constrain(retained, velocities, max_passes)
				if not constrained["ok"]:
					return constrained
				events.append({"kind": "contact", "at": now, "contacts": earliest["contacts"].duplicate(true), "before_velocities": before, "after_velocities": velocities.duplicate(true)})
				if fraction == 0.0 and velocities == before and retained.size() == old_count:
					return _failure("JOINT_CONTACT_NO_PROGRESS")
			if at_circle:
				for contact in plan["circle_hits"]:
					active[contact["actor_id"]] = true
				events.append({"kind": "circle", "at": now, "contacts": plan["circle_hits"].duplicate(true)})
		for actor_id in ids:
			if actors[actor_id]["dodge_end_at"] != null and float(actors[actor_id]["dodge_end_at"]) == until:
				resolved[actor_id]["dodge_end_position"] = positions[actor_id]
	for actor_id in ids:
		resolved[actor_id]["position"] = positions[actor_id]
	var budgets := _resolved_budgets(ids, actors, resolved)
	if not budgets["ok"]:
		return budgets
	return {"ok": true, "positions": resolved, "resolved_positions": resolved.duplicate(true), "trajectory": trajectory, "events": events, "from": source["from"], "to": source["to"], "iterations": iterations, "circle_intervals": circle_intervals}

static func _circle_shapes(ids: Array, actors: Dictionary, expected_half: float, boundaries: Variant) -> Dictionary:
	if not boundaries is Dictionary:
		return _failure("INVALID_CIRCLE_BOUNDARIES")
	var shapes: Dictionary = {}
	for actor_id in ids:
		var key := Address.key(actors[actor_id]["layer"])
		if not boundaries.has(key) or not boundaries[key] is Dictionary:
			return _failure("MISSING_CIRCLE_BOUNDARY", actor_id)
		var entry: Dictionary = boundaries[key]
		if not _number(entry.get("body_radius")) or float(entry["body_radius"]) != expected_half:
			return _failure("CIRCLE_BODY_RADIUS_MISMATCH", actor_id)
		var shape := Circle.parameters(entry.get("map_radius"), entry["body_radius"])
		if not shape["ok"]:
			return _failure(shape["code"], actor_id)
		var inside := Circle.contains(actors[actor_id]["position"], shape["map_radius"], shape["body_radius"])
		if not inside["ok"] or not inside.get("inside", false):
			return _failure("CIRCLE_START_OUTSIDE_OR_UNREPRESENTABLE", actor_id)
		shapes[actor_id] = shape
	return {"ok": true, "shapes": shapes}

static func _circle_plan(ids: Array, positions: Dictionary, intents: Dictionary, retained: Array[Dictionary], active: Dictionary, shapes: Dictionary, remaining: float, max_passes: int) -> Dictionary:
	var velocities := intents.duplicate(true)
	var constrained := _constrain(retained, velocities, max_passes)
	if not constrained["ok"]:
		return constrained
	var duration := remaining
	var curved := false
	for actor_id in ids:
		if not active.has(actor_id):
			continue
		var point: Vector2 = positions[actor_id]
		var velocity: Vector2 = velocities[actor_id]
		if _dot64(point, velocity) < 0.0:
			active.erase(actor_id)
			continue
		var distance := sqrt(_dot64(point, point))
		if not is_finite(distance) or distance <= 0.0:
			return _failure("UNREPRESENTABLE_CIRCLE_CONTACT", actor_id)
		var normal := -point / distance
		var tangent := _project_environment(velocity, normal)
		if not tangent["ok"]:
			return tangent
		velocities[actor_id] = tangent["velocity"]
		var speed := sqrt(_dot64(tangent["velocity"], tangent["velocity"]))
		if speed > 0.0:
			var radius: float = shapes[actor_id]["center_radius"]
			var sagitta := minf(CIRCLE_SAGITTA, radius * 0.25)
			var chord_limit := 2.0 * sqrt(2.0 * radius * sagitta - sagitta * sagitta)
			if not is_finite(chord_limit) or chord_limit <= 0.0:
				return _failure("UNREPRESENTABLE_CIRCLE_CHORD", actor_id)
			duration = minf(duration, chord_limit / speed)
			curved = true
	var chord_targets: Dictionary = {}
	var chord_velocities: Dictionary = {}
	var speed_limits: Dictionary = {}
	for actor_id in ids:
		if not active.has(actor_id) or velocities[actor_id] == Vector2.ZERO:
			continue
		var point: Vector2 = positions[actor_id]
		var velocity: Vector2 = velocities[actor_id]
		var x := float(point.x) + float(velocity.x) * duration
		var y := float(point.y) + float(velocity.y) * duration
		var radius: float = shapes[actor_id]["center_radius"]
		var length := sqrt(x * x + y * y)
		if not is_finite(length) or length <= 0.0:
			return _failure("UNREPRESENTABLE_CIRCLE_CHORD", actor_id)
		var ratio := minf(1.0, radius / length)
		var candidate := Vector2(x * ratio, y * ratio)
		var fitted := _circle_fit_target(point, candidate, sqrt(_dot64(velocity, velocity)) * duration, shapes[actor_id], true)
		if not fitted["ok"]:
			return fitted
		velocities[actor_id] = (fitted["position"] - point) / duration
		chord_targets[actor_id] = fitted["position"]
		chord_velocities[actor_id] = velocities[actor_id]
		speed_limits[actor_id] = sqrt(_dot64(velocity, velocity))
	# Retained peer/wall planes may remove an inward chord component. Reapply
	# them, then shorten that altered line; do not regenerate its removed motion.
	var settled := false
	for pass_index in range(max_passes):
		var before := velocities.duplicate(true)
		constrained = _constrain(retained, velocities, max_passes)
		if not constrained["ok"]:
			return constrained
		for actor_id in ids:
			if not active.has(actor_id):
				continue
			# Preserve the certified seed in this loop too. A no-op retained pass
			# must not discard it through a velocity -> endpoint roundtrip.
			var target: Vector2 = chord_targets[actor_id] if chord_targets.has(actor_id) and velocities[actor_id] == chord_velocities[actor_id] else positions[actor_id] + velocities[actor_id] * duration
			var inside := Circle.contains(target, shapes[actor_id]["map_radius"], shapes[actor_id]["body_radius"])
			if not inside["ok"]:
				return _failure(inside["code"], actor_id)
			if not inside["inside"]:
				var budget := sqrt(_dot64(velocities[actor_id], velocities[actor_id])) * duration
				var fitted := _circle_fit_target(positions[actor_id], target, budget, shapes[actor_id])
				if not fitted["ok"]:
					return fitted
				velocities[actor_id] = (fitted["position"] - positions[actor_id]) / duration
		if velocities == before:
			settled = true
			break
	if not settled:
		return _failure("CIRCLE_CONSTRAINT_LIMIT")
	var first := 1.0
	var hits: Array[Dictionary] = []
	for actor_id in ids:
		if active.has(actor_id):
			continue
		var hit := Circle.first_exit(positions[actor_id], velocities[actor_id] * duration, shapes[actor_id]["map_radius"], shapes[actor_id]["body_radius"])
		if not hit["ok"]:
			return _failure(hit["code"], actor_id)
		if hit["hit"]:
			if hit["fraction"] < first:
				first = hit["fraction"]
				hits.clear()
			if hit["fraction"] == first:
				hits.append({"actor_id": actor_id, "normal": hit["normal"]})
	var targets: Dictionary = {}
	for actor_id in ids:
		if chord_targets.has(actor_id) and velocities[actor_id] == chord_velocities[actor_id]:
			# Preserve the already-fitted endpoint, not a lossy velocity roundtrip.
			# A shorter common horizon uses that actual chord's linear prefix.
			targets[actor_id] = _endpoint_prefix(positions[actor_id], chord_targets[actor_id], first)
		else:
			speed_limits[actor_id] = sqrt(_dot64(velocities[actor_id], velocities[actor_id]))
	return {"ok": true, "duration": duration * first, "velocities": velocities, "targets": targets, "speed_limits": speed_limits, "circle_hits": hits, "curved": curved}

static func _circle_fit_target(start: Vector2, proposed: Vector2, budget: float, shape: Dictionary, radial_seed: bool = false) -> Dictionary:
	var candidate := proposed
	for correction in range(32):
		var inside := Circle.contains(candidate, shape["map_radius"], shape["body_radius"])
		if not inside["ok"]:
			return _failure(inside["code"])
		if not inside["inside"]:
			# Radial construction belongs ONLY to a new unconstrained sliding
			# chord. Later physical constraints may have deleted its inward part.
			var repaired := _circle_round_inward(candidate, shape) if radial_seed else _circle_shorten_line(start, candidate, shape)
			if not repaired["ok"]:
				return repaired
			candidate = repaired["position"]
		var fitted := _fit_query_endpoint(start, candidate, budget)
		if not fitted["ok"]:
			return fitted
		candidate = fitted["position"]
		inside = Circle.contains(candidate, shape["map_radius"], shape["body_radius"])
		if not inside["ok"]:
			return _failure(inside["code"])
		if inside["inside"]:
			return {"ok": true, "position": candidate}
	return _failure("CIRCLE_CANDIDATE_LIMIT")

static func _circle_shorten_line(start: Vector2, proposed: Vector2, shape: Dictionary) -> Dictionary:
	var initial := Circle.contains(start, shape["map_radius"], shape["body_radius"])
	if not initial["ok"] or not initial.get("inside", false):
		return _failure("CIRCLE_START_OUTSIDE_OR_UNREPRESENTABLE")
	var upper := 1.0
	var first := Circle.first_exit(start, proposed - start, shape["map_radius"], shape["body_radius"])
	if first["ok"] and first["hit"]:
		upper = first["fraction"]
	# If the analytic fraction is unrepresentable, retain only separately
	# certified endpoints below. No radius epsilon and no radial reprojection.
	var lower := 0.0
	var accepted := start
	for retreat in range(MAX_EVENT_RETREATS):
		var fraction := upper if retreat == 0 else lower + (upper - lower) * 0.5
		if fraction <= lower:
			break
		var candidate := Vector2.ZERO
		for axis in range(2):
			candidate[axis] = _directed_coordinate(start[axis], (float(proposed[axis]) - float(start[axis])) * fraction)
		var inside := Circle.contains(candidate, shape["map_radius"], shape["body_radius"])
		if not inside["ok"]:
			return _failure(inside["code"])
		if inside["inside"]:
			accepted = candidate
			lower = fraction
		else:
			upper = fraction
		if lower == upper:
			break
	return {"ok": true, "position": accepted}

static func _circle_round_inward(proposed: Vector2, shape: Dictionary) -> Dictionary:
	var candidate := proposed
	var length := sqrt(_dot64(candidate, candidate))
	if not is_finite(length) or length <= 0.0:
		return _failure("UNREPRESENTABLE_CIRCLE_CANDIDATE")
	var ratio := minf(1.0, float(shape["center_radius"]) / length)
	candidate = Vector2(float(candidate.x) * ratio, float(candidate.y) * ratio)
	for correction in range(32):
		var inside := Circle.contains(candidate, shape["map_radius"], shape["body_radius"])
		if not inside["ok"]:
			return _failure(inside["code"])
		if inside["inside"]:
			return {"ok": true, "position": candidate}
		var axis := 0 if absf(candidate.x) >= absf(candidate.y) else 1
		candidate[axis] = _float32_toward_zero(candidate[axis])
	return _failure("CIRCLE_CANDIDATE_LIMIT")

static func _circle_earliest(ids: Array, actors: Dictionary, positions: Dictionary, motions: Dictionary, environment_query: Callable) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var first := 1.0
	for i in range(ids.size()):
		var actor_id: String = ids[i]
		var query := _query(environment_query, actor_id, actors[actor_id], positions[actor_id], motions[actor_id])
		if not query["ok"]:
			return query
		if query["hit"]:
			first = minf(first, query["fraction"])
			candidates.append({"kind": "environment", "actor_id": actor_id, "normal": query["normal"], "fraction": query["fraction"]})
		for j in range(i + 1, ids.size()):
			var other_id: String = ids[j]
			if Address.key(actors[actor_id]["layer"]) != Address.key(actors[other_id]["layer"]):
				continue
			var hit := Geometry.relative_sweep(positions[actor_id], positions[other_id], motions[actor_id], motions[other_id], actors[actor_id]["half_extent"], actors[other_id]["half_extent"])
			if not hit["ok"]:
				return hit
			if hit["hit"]:
				first = minf(first, hit["fraction"])
				candidates.append({"kind": "peer", "a": actor_id, "b": other_id, "normals": hit["normals"].duplicate(), "fraction": hit["fraction"]})
	var contacts: Array[Dictionary] = []
	for candidate in candidates:
		if candidate["fraction"] <= first + Geometry.EPSILON:
			contacts.append(candidate)
	return {"ok": true, "fraction": first, "contacts": contacts}

static func _validate(preview: Variant, limits: Dictionary, expected_half_extent: Variant) -> Dictionary:
	if not _number(expected_half_extent) or expected_half_extent <= 0.0:
		return _failure("INVALID_EXPECTED_HALF_EXTENT")
	for key in limits:
		if key not in ["max_events", "max_constraint_passes"] or not limits[key] is int or limits[key] <= 0 or limits[key] > 65536:
			return _failure("INVALID_SOLVER_LIMITS")
	if not preview is Dictionary or not preview.get("ok") is bool or not preview["ok"] or not preview.get("actors") is Dictionary or not _number(preview.get("from")) or not _number(preview.get("to")):
		return _failure("INVALID_JOINT_PREVIEW")
	var start := float(preview["from"])
	var finish := float(preview["to"])
	if start < 0.0 or finish < start or finish > 4294967296.0:
		return _failure("INVALID_PREVIEW_CLOCK")
	if not preview.get("paused", false) is bool:
		return _failure("INVALID_JOINT_PREVIEW")
	var paused: bool = preview.get("paused", false)
	var ids: Array = preview["actors"].keys()
	if ids.size() > MAX_ACTORS or (paused and (not ids.is_empty() or start != finish)) or (not paused and finish <= start):
		return _failure("INVALID_PREVIEW_INTERVAL")
	var boundaries: Array = [start, finish] if start != finish else [start]
	var count := 0
	for actor_id in ids:
		if not actor_id is String or actor_id.is_empty() or not preview["actors"][actor_id] is Dictionary:
			return _failure("INVALID_PREVIEW_ACTOR")
		var actor: Dictionary = preview["actors"][actor_id]
		if actor.get("actor_id") != actor_id or not Address.valid_layer(actor.get("layer")) or not _vector(actor.get("position")) or not _number(actor.get("half_extent")) or float(actor["half_extent"]) != float(expected_half_extent):
			return _failure("INVALID_PREVIEW_ACTOR", actor_id)
		if not actor.get("segments") is Array or actor["segments"].is_empty() or not _vector(actor.get("requested_motion")) or not _number(actor.get("maximum_distance")) or actor["maximum_distance"] < 0.0 or not actor.has("dodge_end_at"):
			return _failure("INVALID_PREVIEW_TRAJECTORY", actor_id)
		var cursor := start
		var motion_sum := Vector2.ZERO
		var distance := 0.0
		var actor_boundaries: Array = [start]
		for segment in actor["segments"]:
			count += 1
			if count > MAX_SEGMENTS or not segment is Dictionary:
				return _failure("INVALID_PREVIEW_SEGMENTS", actor_id)
			if not _number(segment.get("from")) or not _number(segment.get("to")) or segment["from"] != cursor or segment["to"] <= cursor or segment["to"] > finish or segment.get("phase") not in PHASES or not _vector(segment.get("velocity")) or not _vector(segment.get("motion")):
				return _failure("INVALID_PREVIEW_SEGMENT", actor_id)
			var duration := float(segment["to"]) - cursor
			var expected: Vector2 = segment["velocity"] * duration
			if not expected.is_finite() or not _near_vector(expected, segment["motion"]) or (segment["phase"] in ["idle", "dead", "controlled"] and segment["velocity"] != Vector2.ZERO):
				return _failure("INCONSISTENT_PREVIEW_SEGMENT", actor_id)
			motion_sum += segment["motion"]
			distance += float(segment["velocity"].length()) * duration
			cursor = float(segment["to"])
			actor_boundaries.append(cursor)
			if not boundaries.has(cursor):
				boundaries.append(cursor)
		if cursor != finish or not motion_sum.is_finite() or not is_finite(distance) or not _near_vector(motion_sum, actor["requested_motion"]) or absf(distance - float(actor["maximum_distance"])) > VALUE_EPSILON:
			return _failure("INCONSISTENT_PREVIEW_BUDGET", actor_id)
		var dodge: Variant = actor["dodge_end_at"]
		if dodge != null and (not _number(dodge) or dodge <= start or dodge >= finish or not actor_boundaries.has(dodge)):
			return _failure("INVALID_DODGE_BOUNDARY", actor_id)
	ids.sort()
	boundaries.sort()
	return {"ok": true, "ids": ids, "boundaries": boundaries}

static func _segment_at(segments: Array, at: float) -> Dictionary:
	for segment in segments:
		if segment["from"] <= at and at < segment["to"]:
			return segment
	return {} # Unreachable after contiguous coverage validation.

static func _earliest(ids: Array, actors: Dictionary, positions: Dictionary, velocities: Dictionary, duration: float, environment_query: Callable) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var earliest := 1.0
	for i in range(ids.size()):
		var actor_id: String = ids[i]
		var motion: Vector2 = velocities[actor_id] * duration
		if not motion.is_finite():
			return _failure("NONFINITE_RESOLVED_MOTION", actor_id)
		var environment := _query(environment_query, actor_id, actors[actor_id], positions[actor_id], motion)
		if not environment["ok"]:
			return environment
		if environment["hit"]:
			var fraction: float = environment["fraction"]
			earliest = minf(earliest, fraction)
			candidates.append({"kind": "environment", "actor_id": actor_id, "normal": environment["normal"], "fraction": fraction})
		for j in range(i + 1, ids.size()):
			var other_id: String = ids[j]
			if Address.key(actors[actor_id]["layer"]) != Address.key(actors[other_id]["layer"]):
				continue
			var peer := Geometry.relative_sweep(positions[actor_id], positions[other_id], motion, velocities[other_id] * duration, float(actors[actor_id]["half_extent"]), float(actors[other_id]["half_extent"]))
			if not peer["ok"]:
				return _failure(peer["code"], actor_id)
			if peer["hit"]:
				var fraction: float = peer["fraction"]
				earliest = minf(earliest, fraction)
				candidates.append({"kind": "peer", "a": actor_id, "b": other_id, "normals": peer["normals"].duplicate(), "fraction": fraction})
	var contacts: Array[Dictionary] = []
	for candidate in candidates:
		# Never advance past the exact minimum. Numerically simultaneous contacts
		# may be constrained slightly early, never after their first collision.
		if candidate["fraction"] <= earliest + Geometry.EPSILON:
			contacts.append(candidate)
	return {"ok": true, "fraction": earliest, "contacts": contacts}

static func _query(callback: Callable, actor_id: String, actor: Dictionary, start: Vector2, motion: Vector2) -> Dictionary:
	var result: Variant = callback.call(actor_id, start, motion)
	if not result is Dictionary or not result.get("ok") is bool:
		return _failure("INVALID_ENVIRONMENT_RESPONSE", actor_id)
	if not result["ok"]:
		var failure := _failure("ENVIRONMENT_QUERY_FAILED", actor_id)
		failure["cause"] = str(result.get("code", "UNSPECIFIED"))
		failure["query_start"] = [start.x,start.y]
		failure["query_motion"] = [motion.x,motion.y]
		return failure
	if not result.get("hit") is bool or not _number(result.get("fraction")) or result["fraction"] < 0.0 or result["fraction"] > 1.0 or not _vector(result.get("normal")):
		return _failure("INVALID_ENVIRONMENT_RESPONSE", actor_id)
	if result.has("layer_key") and result["layer_key"] != Address.key(actor["layer"]):
		return _failure("ENVIRONMENT_LAYER_MISMATCH", actor_id)
	if result["hit"]:
		var normal: Vector2 = result["normal"]
		if absf(float(normal.length_squared()) - 1.0) > 0.001:
			return _failure("INVALID_ENVIRONMENT_NORMAL", actor_id)
	elif result["fraction"] != 1.0:
		return _failure("INVALID_ENVIRONMENT_RESPONSE", actor_id)
	return result.duplicate(true)

static func _constrain(contacts: Array[Dictionary], velocities: Dictionary, max_passes: int) -> Dictionary:
	for pass_index in range(max_passes):
		for contact in contacts:
			if contact["kind"] == "peer":
				for normal in contact["normals"]:
					var pair := Geometry.constrain_pair(velocities[contact["a"]], velocities[contact["b"]], normal)
					velocities[contact["a"]] = pair["a"]
					velocities[contact["b"]] = pair["b"]
			else:
				var actor_id: String = contact["actor_id"]
				var normal: Vector2 = contact["normal"]
				var velocity: Vector2 = velocities[actor_id]
				if _dot64(velocity, normal) < 0.0 or velocity.dot(normal) < 0.0:
					var projected := _project_environment(velocity, normal)
					if not projected["ok"]:
						return projected
					velocities[actor_id] = projected["velocity"]
		var satisfied := true
		for contact in contacts:
			if contact["kind"] == "peer":
				for normal in contact["normals"]:
					if (velocities[contact["a"]] - velocities[contact["b"]]).dot(normal) < 0.0:
						satisfied = false
			elif _dot64(velocities[contact["actor_id"]], contact["normal"]) < 0.0 or velocities[contact["actor_id"]].dot(contact["normal"]) < 0.0:
				satisfied = false
		if satisfied:
			return {"ok": true}
	return _failure("JOINT_CONSTRAINT_LIMIT")

static func _project_environment(velocity: Vector2, normal: Vector2) -> Dictionary:
	var closing := _dot64(velocity, normal)
	var candidate := velocity - normal * (minf(0.0, closing) / _dot64(normal, normal))
	var speed_squared := _dot64(velocity, velocity)
	# Float32 projection can leave a negative ulp that another projection cannot
	# change. Remove representable inward speed instead of permitting penetration.
	# Every adjustment is exactly one float32 ULP toward zero, never a push-out.
	for correction in range(16):
		var inward := _dot64(candidate, normal) < 0.0 or candidate.dot(normal) < 0.0
		if not inward and _dot64(candidate, candidate) <= speed_squared:
			return {"ok": true, "velocity": candidate}
		var axis := -1
		if inward:
			for component in range(2):
				if float(candidate[component]) * float(normal[component]) < 0.0:
					if axis < 0 or absf(float(candidate[component]) * float(normal[component])) > absf(float(candidate[axis]) * float(normal[axis])):
						axis = component
		else:
			axis = 0 if absf(candidate.x) >= absf(candidate.y) else 1
		if axis < 0:
			return _failure("UNRESOLVED_ENVIRONMENT_ROUNDING")
		candidate[axis] = _float32_toward_zero(candidate[axis])
	return _failure("UNRESOLVED_ENVIRONMENT_ROUNDING")

static func _float32_toward_zero(value: float) -> float:
	if value == 0.0:
		return 0.0
	var encoded := PackedByteArray()
	encoded.resize(4)
	encoded.encode_float(0, value)
	# IEEE754 positive and negative finite magnitudes both decrease toward zero
	# when the unsigned encoding decreases by one; preserve the sign bit.
	encoded.encode_u32(0, encoded.decode_u32(0) - 1)
	return encoded.decode_float(0)

static func _dot64(a: Vector2, b: Vector2) -> float:
	return float(a.x) * float(b.x) + float(a.y) * float(b.y)

static func _advance(ids: Array, actors: Dictionary, positions: Dictionary, velocities: Dictionary, phases: Dictionary, start: float, finish: float, may_retreat: bool, environment_query: Callable, max_passes: int, circle_shapes: Dictionary = {}, endpoint_seeds: Dictionary = {}, endpoint_budgets: Dictionary = {}) -> Dictionary:
	var accepted := _unrounded_candidate(ids, actors, positions, velocities, start, finish)
	var accepted_at := finish
	if not accepted["ok"]:
		if accepted["code"] != "PEER_PATH_OVERLAP":
			return accepted
		# A mathematical contact may round inward when each actor is stored as a
		# Vector2. Search common times, never independently snap/push positions.
		# Only an explicitly certified candidate is retained; safety need not be
		# monotone over float32 rounding cells for this bounded search to be safe.
		if may_retreat:
			var lower := start
			var upper := finish
			accepted_at = start
			for retreat in range(MAX_EVENT_RETREATS):
				var middle := lower + (upper - lower) * 0.5
				if middle <= lower or middle >= upper:
					break
				var candidate := _unrounded_candidate(ids, actors, positions, velocities, start, middle)
				if candidate["ok"]:
					lower = middle
					accepted_at = middle
				elif candidate["code"] == "PEER_PATH_OVERLAP":
					upper = middle
				else:
					return candidate
	if accepted_at == start:
		return {"ok": true, "at": start, "span": null}
	# Even a contact-free equal-speed span can round closed at x=16/32/etc.
	# Certify a directed, limited candidate before changing any working position.
	var seed_fraction := (accepted_at - start) / (finish - start)
	var certified := _candidate_span(ids, actors, positions, velocities, phases, start, accepted_at, environment_query, max_passes, circle_shapes, endpoint_seeds, endpoint_budgets, seed_fraction)
	if not certified["ok"]:
		return certified
	for actor_id in ids:
		positions[actor_id] = certified["span"]["actors"][actor_id]["to_position"]
	return {"ok": true, "at": accepted_at, "span": certified["span"]}

static func _unrounded_candidate(ids: Array, actors: Dictionary, positions: Dictionary, velocities: Dictionary, start: float, finish: float) -> Dictionary:
	var candidates: Dictionary = {}
	for actor_id in ids:
		var position: Vector2 = positions[actor_id] + velocities[actor_id] * (finish - start)
		if not position.is_finite():
			return _failure("NONFINITE_RESOLVED_POSITION", actor_id)
		candidates[actor_id] = position
	return _span_separated(ids, actors, positions, candidates)

static func _candidate_span(ids: Array, actors: Dictionary, starts: Dictionary, velocities: Dictionary, phases: Dictionary, start: float, finish: float, environment_query: Callable, max_passes: int, circle_shapes: Dictionary = {}, endpoint_seeds: Dictionary = {}, endpoint_budgets: Dictionary = {}, seed_fraction: float = 1.0) -> Dictionary:
	var duration := finish - start
	var candidates: Dictionary = {}
	var budgets: Dictionary = {}
	for actor_id in ids:
		var point: Vector2 = starts[actor_id]
		if endpoint_seeds.has(actor_id):
			point = _endpoint_prefix(starts[actor_id], endpoint_seeds[actor_id], seed_fraction)
		else:
			for axis in range(2):
				point[axis] = _directed_coordinate(starts[actor_id][axis], float(velocities[actor_id][axis]) * duration)
		if not point.is_finite():
			return _failure("NONFINITE_RESOLVED_POSITION", actor_id)
		candidates[actor_id] = point
		var requested := _segment_at(actors[actor_id]["segments"], start)
		if endpoint_seeds.has(actor_id):
			# This distance was already bounded before velocity quantization.
			# A rounded Vector2 speed is diagnostic, not a second smaller budget.
			budgets[actor_id] = minf(float(requested["velocity"].length()) * duration, float(endpoint_budgets[actor_id]) * seed_fraction)
		else:
			budgets[actor_id] = minf(float(requested["velocity"].length()), sqrt(_dot64(velocities[actor_id], velocities[actor_id]))) * duration
	for pass_index in range(max_passes):
		var before := candidates.duplicate(true)
		for actor_id in ids:
			var fitted := _fit_query_endpoint(starts[actor_id], candidates[actor_id], budgets[actor_id])
			if not fitted["ok"]:
				return _failure(fitted["code"], actor_id)
			candidates[actor_id] = fitted["position"]
			if circle_shapes.has(actor_id):
				var circle_fit := _circle_fit_target(starts[actor_id], candidates[actor_id], budgets[actor_id], circle_shapes[actor_id])
				if not circle_fit["ok"]:
					return circle_fit
				candidates[actor_id] = circle_fit["position"]
		for i in range(ids.size()):
			for j in range(i + 1, ids.size()):
				var a: String = ids[i]
				var b: String = ids[j]
				if Address.key(actors[a]["layer"]) != Address.key(actors[b]["layer"]):
					continue
				var extent := float(actors[a]["half_extent"]) + float(actors[b]["half_extent"]) - Geometry.POSITION_EPSILON
				var contact := _path_contact(starts[a], starts[b], candidates[a], candidates[b], extent)
				if contact["hit"] and not _limit_peer_candidate(a, b, starts, candidates, contact["normals"], extent):
					return _failure("UNRESOLVED_PEER_CANDIDATE", a)
		# Peer limits change the line sent to the environment. Rebuild its exact
		# Vector2 motion, then query every actor; never reuse the nominal query.
		for actor_id in ids:
			var fitted := _fit_query_endpoint(starts[actor_id], candidates[actor_id], budgets[actor_id])
			if not fitted["ok"]:
				return _failure(fitted["code"], actor_id)
			candidates[actor_id] = fitted["position"]
			if circle_shapes.has(actor_id):
				var circle_fit := _circle_fit_target(starts[actor_id], candidates[actor_id], budgets[actor_id], circle_shapes[actor_id])
				if not circle_fit["ok"]:
					return circle_fit
				candidates[actor_id] = circle_fit["position"]
			var motion: Vector2 = candidates[actor_id] - starts[actor_id]
			var query := _query(environment_query, actor_id, actors[actor_id], starts[actor_id], motion)
			if not query["ok"]:
				return query
			if query["hit"] and query["fraction"] < 1.0:
				var limited := _limit_environment_candidate(starts[actor_id], candidates[actor_id], motion, query["normal"], query["fraction"])
				if not limited["ok"]:
					return _failure(limited["code"], actor_id)
				candidates[actor_id] = limited["position"]
		# A later actor/wall correction can close an earlier pair. Only a whole
		# unchanged pass proves that every final path was queried and certified.
		if candidates != before:
			continue
		var separated := _span_separated(ids, actors, starts, candidates)
		if not separated["ok"]:
			return separated
		var records: Dictionary = {}
		for actor_id in ids:
			var from_position: Vector2 = starts[actor_id]
			var to_position: Vector2 = candidates[actor_id]
			var motion := to_position - from_position
			if from_position + motion != to_position:
				return _failure("UNREPRESENTABLE_ENVIRONMENT_MOTION", actor_id)
			records[actor_id] = {"layer": actors[actor_id]["layer"].duplicate(true), "from_position": from_position, "to_position": to_position, "constrained_velocity": velocities[actor_id], "actual_velocity": [(float(to_position.x) - float(from_position.x)) / duration, (float(to_position.y) - float(from_position.y)) / duration], "query_motion": motion, "phase": phases[actor_id]}
		return {"ok": true, "span": {"from": start, "to": finish, "actors": records}}
	return _failure("JOINT_CANDIDATE_LIMIT")

static func _endpoint_prefix(start: Vector2, finish: Vector2, fraction: float) -> Vector2:
	if fraction == 1.0:
		return finish
	if fraction == 0.0:
		return start
	return Vector2(float(start.x) + (float(finish.x) - float(start.x)) * fraction, float(start.y) + (float(finish.y) - float(start.y)) * fraction)

static func _directed_coordinate(start: float, displacement: float) -> float:
	var ideal := start + displacement
	var encoded := PackedByteArray()
	encoded.resize(4)
	encoded.encode_float(0, ideal)
	var rounded := encoded.decode_float(0)
	if not is_finite(rounded):
		return rounded
	if (displacement > 0.0 and rounded > ideal) or (displacement < 0.0 and rounded < ideal):
		rounded = _float32_toward(rounded, start)
	return rounded

static func _float32_toward(value: float, target: float) -> float:
	if value == target:
		return value
	var encoded := PackedByteArray()
	encoded.resize(4)
	if value == 0.0:
		encoded.encode_u32(0, 1 if target > 0.0 else 2147483649)
	else:
		encoded.encode_float(0, value)
		var bits := encoded.decode_u32(0)
		bits += 1 if (target > value) == (value > 0.0) else -1
		encoded.encode_u32(0, bits)
	return encoded.decode_float(0)

static func _limited_coordinate(current: float, start: float, target: float) -> float:
	# target lies between current and start. Round the required reduction toward
	# start, so nearest rounding cannot leave the closing component unchanged.
	var encoded := PackedByteArray()
	encoded.resize(4)
	encoded.encode_float(0, target)
	var rounded := encoded.decode_float(0)
	if absf(rounded - start) > absf(target - start):
		rounded = _float32_toward(rounded, start)
	if rounded == current and target != current:
		rounded = _float32_toward(current, start)
	return clampf(rounded, minf(current, start), maxf(current, start))

static func _distance64(a: Vector2, b: Vector2) -> float:
	var x := float(b.x) - float(a.x)
	var y := float(b.y) - float(a.y)
	return sqrt(x * x + y * y)

static func _fit_query_endpoint(start: Vector2, proposed: Vector2, budget: float) -> Dictionary:
	var candidate := proposed
	for correction in range(16):
		var motion := candidate - start
		var reconstructed := start + motion
		for axis in range(2):
			if reconstructed[axis] == candidate[axis]:
				continue
			# Only accept a reconstruction closer to the original start. If the
			# subtraction/addition overshoots, reduce the query motion by one ULP.
			if reconstructed[axis] < minf(start[axis], candidate[axis]) or reconstructed[axis] > maxf(start[axis], candidate[axis]):
				motion[axis] = _float32_toward_zero(motion[axis])
				reconstructed = start + motion
			if reconstructed[axis] < minf(start[axis], candidate[axis]) or reconstructed[axis] > maxf(start[axis], candidate[axis]):
				return {"ok": false, "code": "UNREPRESENTABLE_ENVIRONMENT_MOTION"}
			candidate[axis] = reconstructed[axis]
		var distance := _distance64(start, candidate)
		if distance > budget:
			var ratio := budget / distance
			var before := candidate
			for axis in range(2):
				candidate[axis] = _directed_coordinate(start[axis], (float(candidate[axis]) - float(start[axis])) * ratio)
			if candidate == before:
				var axis := 0 if absf(float(candidate.x) - float(start.x)) >= absf(float(candidate.y) - float(start.y)) else 1
				candidate[axis] = _float32_toward(candidate[axis], start[axis])
			continue
		motion = candidate - start
		if start + motion == candidate:
			return {"ok": true, "position": candidate}
	return {"ok": false, "code": "UNRESOLVED_CANDIDATE_BUDGET"}

static func _path_contact(a: Vector2, b: Vector2, end_a: Vector2, end_b: Vector2, extent: float) -> Dictionary:
	if extent <= 0.0:
		return {"hit": false}
	var enter := -INF
	var leave := INF
	var normals: Array[Vector2] = []
	for axis in range(2):
		var offset := float(a[axis]) - float(b[axis])
		var end_offset := float(end_a[axis]) - float(end_b[axis])
		var rate := end_offset - offset
		if rate == 0.0:
			if absf(offset) >= extent:
				return {"hit": false}
			continue
		var first := (-extent - offset) / rate
		var last := (extent - offset) / rate
		var normal := Vector2.ZERO
		normal[axis] = -signf(rate)
		if first > last:
			var swap := first
			first = last
			last = swap
		if first > enter:
			enter = first
			normals = [normal]
		elif first == enter:
			normals.append(normal)
		leave = minf(leave, last)
	if maxf(0.0, enter) >= minf(1.0, leave):
		return {"hit": false}
	return {"hit": true, "normals": normals}

static func _limit_peer_candidate(a: String, b: String, starts: Dictionary, candidates: Dictionary, normals: Array, extent: float) -> bool:
	for normal in normals:
		var axis := 0 if normal.x != 0.0 else 1
		var direction: float = normal[axis]
		var point_a: Vector2 = candidates[a]
		var point_b: Vector2 = candidates[b]
		if direction * (float(point_a[axis]) - float(point_b[axis])) >= extent:
			continue
		# Remove only a component moving toward this peer. A same-speed leader
		# cannot be pushed forward, and neither actor can pass its own start.
		if direction * (float(starts[a][axis]) - float(point_a[axis])) > 0.0:
			var target := minf(direction * float(starts[a][axis]), direction * float(point_b[axis]) + extent) * direction
			point_a[axis] = _limited_coordinate(point_a[axis], starts[a][axis], target)
		if direction * (float(point_a[axis]) - float(point_b[axis])) < extent and direction * (float(point_b[axis]) - float(starts[b][axis])) > 0.0:
			var target := maxf(direction * float(starts[b][axis]), direction * float(point_a[axis]) - extent) * direction
			point_b[axis] = _limited_coordinate(point_b[axis], starts[b][axis], target)
		if direction * (float(point_a[axis]) - float(point_b[axis])) < extent:
			return false
		candidates[a] = point_a
		candidates[b] = point_b
	return not normals.is_empty()

static func _limit_environment_candidate(start: Vector2, proposed: Vector2, query_motion: Vector2, normal: Vector2, fraction: float) -> Dictionary:
	var query_rate := _dot64(query_motion, normal)
	if query_rate >= 0.0:
		return {"ok": false, "code": "UNRESOLVED_ENVIRONMENT_CANDIDATE"}
	var target := query_rate * fraction
	var candidate := proposed
	for correction in range(2):
		var actual := (float(candidate.x) - float(start.x)) * float(normal.x) + (float(candidate.y) - float(start.y)) * float(normal.y)
		if actual >= target:
			break
		var axis := -1
		var available := 0.0
		for component in range(2):
			var inward := -(float(candidate[component]) - float(start[component])) * float(normal[component])
			if inward > available:
				axis = component
				available = inward
		if axis < 0:
			return {"ok": false, "code": "UNRESOLVED_ENVIRONMENT_CANDIDATE"}
		var removal := minf(target - actual, available) / absf(float(normal[axis]))
		var coordinate := float(candidate[axis]) + signf(float(start[axis]) - float(candidate[axis])) * removal
		candidate[axis] = _limited_coordinate(candidate[axis], start[axis], coordinate)
	if candidate == proposed:
		return {"ok": false, "code": "UNRESOLVED_ENVIRONMENT_CANDIDATE"}
	# This plane is only a candidate reduction. A fresh native query, not the
	# normal alone, must certify it; finite walls/corners may expose more hits.
	return {"ok": true, "position": candidate}

static func _resolved_budgets(ids: Array, actors: Dictionary, resolved: Dictionary) -> Dictionary:
	for actor_id in ids:
		var actor: Dictionary = actors[actor_id]
		var result: Dictionary = resolved[actor_id]
		# Match ActorMotion's existing checks without relaxing its tolerance.
		if actor["position"].distance_to(result["position"]) > float(actor["maximum_distance"]) + VALUE_EPSILON:
			return _failure("RESOLVED_DISTANCE_BUDGET", actor_id)
		if actor["dodge_end_at"] != null:
			var before := 0.0
			for segment in actor["segments"]:
				before += float(segment["velocity"].length()) * maxf(0.0, minf(float(segment["to"]), float(actor["dodge_end_at"])) - float(segment["from"]))
			if not result.has("dodge_end_position") or actor["position"].distance_to(result["dodge_end_position"]) > before + VALUE_EPSILON or result["dodge_end_position"].distance_to(result["position"]) > float(actor["maximum_distance"]) - before + VALUE_EPSILON:
				return _failure("RESOLVED_DODGE_BOUNDARY_BUDGET", actor_id)
	return {"ok": true}

static func _span_separated(ids: Array, actors: Dictionary, starts: Dictionary, finishes: Dictionary) -> Dictionary:
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a: String = ids[i]
			var b: String = ids[j]
			if Address.key(actors[a]["layer"]) != Address.key(actors[b]["layer"]):
				continue
			# Match Geometry.overlaps exactly; do not enlarge its tolerance.
			var extent := float(actors[a]["half_extent"]) + float(actors[b]["half_extent"]) - Geometry.POSITION_EPSILON
			if extent <= 0.0:
				continue
			var enter := 0.0
			var leave := 1.0
			for axis in range(2):
				# Convert components before subtraction: Vector2 differences would
				# round away evidence about the already-rounded endpoints.
				var offset := float(starts[a][axis]) - float(starts[b][axis])
				var end_offset := float(finishes[a][axis]) - float(finishes[b][axis])
				var rate := end_offset - offset
				if rate == 0.0:
					if absf(offset) >= extent:
						leave = enter
						break
				else:
					var first := (-extent - offset) / rate
					var last := (extent - offset) / rate
					enter = maxf(enter, minf(first, last))
					leave = minf(leave, maxf(first, last))
			if enter < leave:
				return _failure("PEER_PATH_OVERLAP", a)
	return {"ok": true}

static func _separated(ids: Array, actors: Dictionary, positions: Dictionary) -> Dictionary:
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			if Address.key(actors[ids[i]]["layer"]) == Address.key(actors[ids[j]]["layer"]) and Geometry.overlaps(positions[ids[i]], positions[ids[j]], float(actors[ids[i]]["half_extent"]), float(actors[ids[j]]["half_extent"])):
				return _failure("PEER_OVERLAP", ids[i])
	return {"ok": true}

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _vector(value: Variant) -> bool:
	return value is Vector2 and value.is_finite()

static func _near_vector(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) <= VALUE_EPSILON

static func _failure(code: String, actor_id: String = "") -> Dictionary:
	# Never publish partial candidates/trajectories as a successful transaction.
	return {"ok": false, "code": code, "actor_id": actor_id, "category": "resolver", "recoverable_corruption": false}
