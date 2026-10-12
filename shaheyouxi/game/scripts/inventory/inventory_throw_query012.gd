extends RefCounted
## Read-only H1 point sweep in the existing certified native layer.
const Address = preload("res://scripts/world/spatial_address.gd")
const Space = preload("res://scripts/actor/actor_terrain_space.gd")
static func landing(space: RefCounted, layer: Dictionary, origin: Vector2, direction: Vector2, distance: float) -> Dictionary:
	if space == null or space.get_script() != Space or not Address.valid_layer(layer) or not origin.is_finite() or not direction.is_finite() or direction.length_squared() <= 0.0 or not is_finite(distance) or distance <= 0.0: return {"ok": false, "code": "THROW_QUERY_INVALID"}
	var key: String = Address.key(layer)
	var motion: Vector2 = direction.normalized() * distance
	if not space._spaces.has(key) or not space._covered_sweep(key, origin, motion) or (origin + motion).length() >= space._radius: return {"ok": false, "code": "THROW_REGION_UNCERTIFIED"}
	var state: PhysicsDirectSpaceState2D = PhysicsServer2D.space_get_direct_state(space._spaces[key]["rid"])
	if state == null or not _clear(state, origin): return {"ok": false, "code": "THROW_ORIGIN_BLOCKED"}
	var ray := PhysicsRayQueryParameters2D.create(origin, origin + motion, 1)
	ray.hit_from_inside = true
	var hit: Dictionary = state.intersect_ray(ray)
	var fraction: float = 1.0
	if not hit.is_empty(): fraction = clampf(origin.distance_to(hit["position"]) / distance, 0.0, 1.0)
	var target: Vector2 = origin + motion * fraction
	if not _clear(state, target):
		var lower: float = 0.0
		var upper: float = fraction
		for _i in range(48):
			var middle: float = (lower + upper) * 0.5
			if middle <= lower or middle >= upper: break
			if _clear(state, origin + motion * middle): lower = middle
			else: upper = middle
		target = origin + motion * lower
	if not _clear(state, target): return {"ok": false, "code": "THROW_LANDING_UNCERTIFIED"}
	return {"ok": true, "landing": target, "blocked": not hit.is_empty()}
static func _clear(state: PhysicsDirectSpaceState2D, position: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = position
	query.collision_mask = 1
	return state.intersect_point(query, 1).is_empty()
