extends RefCounted
## Pure circle-boundary math in layer-local coordinates; the map centre is (0,0).
## R and r come from the trusted world/ActorInputs, never client movement packets.
## This does not move actors, repair starting positions, build sliding chords,
## certify native float32 endpoints, or alter ActorMotion preview/commit tickets.
## Predicates remain finite float64 calculations, not arbitrary-precision proofs.
## No outward epsilon is added to the closed circle.

static func parameters(map_radius: Variant, body_radius: Variant) -> Dictionary:
	if not _number(map_radius) or not _number(body_radius) or body_radius <= 0.0 or map_radius <= body_radius:
		return _error("INVALID_CIRCLE_PARAMETERS")
	var outer := float(map_radius)
	var body := float(body_radius)
	var radius := outer - body
	var squared := radius * radius
	# A lost subtraction margin would quietly treat a full body as a point.
	# Underflow/overflow is a representation failure, not permission to widen R.
	if not is_finite(radius) or radius <= 0.0 or radius >= outer or not is_finite(squared) or squared <= 0.0:
		return _error("UNREPRESENTABLE_CIRCLE_PARAMETERS")
	return {"ok": true, "map_radius": outer, "body_radius": body, "center_radius": radius, "radius_squared": squared}

static func contains(position: Variant, map_radius: Variant, body_radius: Variant) -> Dictionary:
	## Successful result: {ok:true, inside:bool}. The closed boundary is inside.
	## Scalar signed gap avoids adding a tiny perpendicular square to R*R.
	var shape := parameters(map_radius, body_radius)
	if not shape["ok"]:
		return shape
	if not _vector(position):
		return _error("INVALID_CIRCLE_POSITION")
	var x := float(position.x)
	var y := float(position.y)
	var gap := _signed_gap(x, y, float(shape["center_radius"]))
	if not gap["ok"]:
		return gap
	return {"ok": true, "inside": gap["value"] <= 0.0}

static func first_exit(start: Variant, motion: Variant, map_radius: Variant, body_radius: Variant) -> Dictionary:
	## Continuous line p(t) = scalar(start) + t*scalar(motion), t in [0,1].
	## motion is displacement, not velocity. Components are converted BEFORE math.
	## hit=true includes contact at t=1; at the boundary a nonzero outward OR
	## tangent motion hits at t=0. Inward motion uses its later exit, not entry t=0.
	## Zero displacement has no hit even at the boundary. No hit => fraction=1,
	## normal=ZERO. Hit => inward unit direction (Vector2 representation precision).
	## fraction is a double analytic contact estimate, NOT a safe native endpoint.
	## A caller must separately certify the actual rounded path and final body.
	var shape := parameters(map_radius, body_radius)
	if not shape["ok"]:
		return shape
	if not _vector(start) or not _vector(motion):
		return _error("INVALID_CIRCLE_MOTION")
	var px := float(start.x)
	var py := float(start.y)
	var dx := float(motion.x)
	var dy := float(motion.y)
	var radius := float(shape["center_radius"])
	var start_gap := _signed_gap(px, py, radius)
	if not start_gap["ok"]:
		return start_gap
	var c: float = start_gap["value"]
	if c > 0.0:
		return _error("CIRCLE_START_OUTSIDE")
	var a := dx * dx + dy * dy
	var b := px * dx + py * dy
	if not is_finite(a) or not is_finite(b):
		return _error("UNREPRESENTABLE_CIRCLE_QUERY")
	if a == 0.0:
		return _clear() if dx == 0.0 and dy == 0.0 else _error("UNREPRESENTABLE_CIRCLE_QUERY")
	if c == 0.0 and b >= 0.0:
		return _hit(0.0, px, py)
	var end_x := px + dx
	var end_y := py + dy
	var end_gap := _signed_gap(end_x, end_y, radius)
	if not end_gap["ok"]:
		return end_gap
	if end_gap["value"] < 0.0:
		# A disk is convex: with a legal start, this entire straight segment fits.
		return _clear()
	if end_gap["value"] == 0.0:
		return _hit(1.0, end_x, end_y)
	# Solve a*t*t + 2*b*t + c = 0. Since c<=0 the exit is the positive root.
	var b_squared := b * b
	var ac := a * c
	if not is_finite(b_squared) or not is_finite(ac) or (b != 0.0 and b_squared == 0.0) or (c != 0.0 and ac == 0.0):
		return _error("UNREPRESENTABLE_CIRCLE_QUERY")
	var discriminant := b_squared - ac
	if not is_finite(discriminant) or discriminant <= 0.0:
		return _error("UNREPRESENTABLE_CIRCLE_QUERY")
	var root := sqrt(discriminant)
	if not is_finite(root) or root <= 0.0:
		return _error("UNREPRESENTABLE_CIRCLE_QUERY")
	var fraction: float
	if b >= 0.0:
		# Rationalized positive root avoids sqrt(D)-b cancellation near the edge.
		var denominator := b + root
		if not is_finite(denominator) or denominator <= 0.0:
			return _error("UNREPRESENTABLE_CIRCLE_QUERY")
		fraction = -c / denominator
	else:
		fraction = (root - b) / a
	# The endpoint has a strictly positive gap here. If its earlier exit rounds
	# to t=1, do not mislabel the known-outside endpoint as exact closed contact.
	if not is_finite(fraction) or fraction < 0.0 or fraction >= 1.0 or (c < 0.0 and fraction == 0.0):
		return _error("UNREPRESENTABLE_CIRCLE_QUERY")
	return _hit(fraction, px + dx * fraction, py + dy * fraction)

static func _signed_gap(x: float, y: float, radius: float) -> Dictionary:
	if not is_finite(x) or not is_finite(y) or not is_finite(radius) or radius <= 0.0:
		return _error("UNREPRESENTABLE_CIRCLE_QUERY")
	var large := maxf(absf(x), absf(y))
	var small := minf(absf(x), absf(y))
	var small_squared := small * small
	var difference := radius - large
	var sum := radius + large
	if not is_finite(small_squared) or not is_finite(difference) or not is_finite(sum) or (small != 0.0 and small_squared == 0.0):
		return _error("UNREPRESENTABLE_CIRCLE_QUERY")
	var radial_product := difference * sum
	if not is_finite(radial_product) or (difference != 0.0 and radial_product == 0.0):
		return _error("UNREPRESENTABLE_CIRCLE_QUERY")
	# Equivalent to x*x+y*y-radius*radius, without rounding radius^2 plus a
	# tiny transverse offset back to radius^2. Still bounded double arithmetic.
	var value := small_squared - radial_product
	if not is_finite(value) or (small_squared != radial_product and value == 0.0):
		return _error("UNREPRESENTABLE_CIRCLE_QUERY")
	return {"ok": true, "value": value}

static func _hit(fraction: float, x: float, y: float) -> Dictionary:
	var length_squared := x * x + y * y
	if not is_finite(length_squared) or length_squared <= 0.0:
		return _error("UNREPRESENTABLE_CIRCLE_NORMAL")
	var length := sqrt(length_squared)
	if not is_finite(length) or length <= 0.0:
		return _error("UNREPRESENTABLE_CIRCLE_NORMAL")
	var normal := Vector2(-x / length, -y / length)
	if not normal.is_finite() or normal == Vector2.ZERO:
		return _error("UNREPRESENTABLE_CIRCLE_NORMAL")
	return {"ok": true, "hit": true, "fraction": fraction, "normal": normal}

static func _clear() -> Dictionary:
	return {"ok": true, "hit": false, "fraction": 1.0, "normal": Vector2.ZERO}

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _vector(value: Variant) -> bool:
	return value is Vector2 and value.is_finite()

static func _error(code: String) -> Dictionary:
	return {"ok": false, "code": code}
