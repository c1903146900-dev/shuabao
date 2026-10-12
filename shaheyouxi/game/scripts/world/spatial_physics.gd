extends RefCounted
## One real physics space per full logical layer identity. Caller must dispose().
const Address = preload("res://scripts/world/spatial_address.gd")
var _spaces: Dictionary = {}
var _actors: Dictionary = {}
var _bodies: Array[RID] = []
var _shapes: Array[RID] = []
var last_error: String = ""

func add_layer(model: RefCounted, identity: Dictionary) -> bool:
	var key := Address.key(identity)
	var view: Dictionary = model.layer_view(identity)
	if key.is_empty() or view.is_empty() or _spaces.has(key):
		return false
	var space := PhysicsServer2D.space_create()
	PhysicsServer2D.space_set_active(space, true)
	_spaces[key] = {"space": space, "bounds": view["bounds"]}
	var bounds: Rect2i = view["bounds"]
	var box := Rect2(Vector2(bounds.position), Vector2(bounds.size))
	# Four exterior slabs. Finite motions are additionally bounded by the logical box.
	_rectangle(space, Rect2(box.position - Vector2(1, 1), Vector2(box.size.x + 2, 1)))
	_rectangle(space, Rect2(Vector2(box.position.x - 1, box.end.y), Vector2(box.size.x + 2, 1)))
	_rectangle(space, Rect2(box.position - Vector2(1, 0), Vector2(1, box.size.y)))
	_rectangle(space, Rect2(Vector2(box.end.x, box.position.y), Vector2(1, box.size.y)))
	for record in view["objects"].values():
		var definition: Dictionary = model.definition(record["content_id"])
		if definition["blocks_motion"]:
			var size: Array = definition["collision_rect_cells"]["size"]
			_rectangle(space, Rect2(Vector2(record["anchor"]), Vector2(float(size[0]), float(size[1]))))
	return true

func add_actor(actor_id: String, identity: Dictionary, position: Vector2, radius: float) -> bool:
	var key := Address.key(identity)
	if actor_id.is_empty() or _actors.has(actor_id) or not _spaces.has(key) or not is_finite(radius) or radius <= 0 or not _inside(key, position, radius):
		return false
	if not _clear_at(key, position, radius):
		return false
	var shape := PhysicsServer2D.circle_shape_create()
	PhysicsServer2D.shape_set_data(shape, radius)
	_shapes.append(shape)
	var body := PhysicsServer2D.body_create()
	_bodies.append(body)
	PhysicsServer2D.body_set_mode(body, PhysicsServer2D.BODY_MODE_KINEMATIC)
	PhysicsServer2D.body_set_collision_layer(body, 2)
	PhysicsServer2D.body_set_collision_mask(body, 1)
	PhysicsServer2D.body_add_shape(body, shape)
	PhysicsServer2D.body_set_state(body, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, position))
	PhysicsServer2D.body_set_space(body, _spaces[key]["space"])
	_actors[actor_id] = {"body": body, "shape": shape, "layer_key": key, "position": position, "radius": radius}
	return true

func move_actor(actor_id: String, motion: Vector2) -> Dictionary:
	if not _actors.has(actor_id) or not motion.is_finite():
		return {"ok": false, "code": "INVALID_ACTOR_OR_MOTION"}
	var actor: Dictionary = _actors[actor_id]
	var position: Vector2 = actor["position"]
	var remaining := motion
	var collided := false
	# Swept body motion with up to four tangential slides; no endpoint-only tunnelling.
	for _iteration in range(4):
		if remaining.length_squared() < 0.0000000001:
			break
		var parameters := PhysicsTestMotionParameters2D.new()
		parameters.from = Transform2D(0.0, position)
		parameters.motion = remaining
		parameters.margin = 0.001
		var result := PhysicsTestMotionResult2D.new()
		if PhysicsServer2D.body_test_motion(actor["body"], parameters, result):
			collided = true
			position += result.get_travel()
			remaining = result.get_remainder().slide(result.get_collision_normal())
		else:
			position += remaining
			remaining = Vector2.ZERO
		PhysicsServer2D.body_set_state(actor["body"], PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, position))
	# Defense in depth: the complete circular collision body remains inside the box.
	var box: Rect2i = _spaces[actor["layer_key"]]["bounds"]
	position = position.clamp(Vector2(box.position) + Vector2.ONE * actor["radius"], Vector2(box.end) - Vector2.ONE * actor["radius"])
	actor["position"] = position
	PhysicsServer2D.body_set_state(actor["body"], PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, position))
	return {"ok": true, "position": position, "collided": collided}

func transfer_actor(actor_id: String, target: Dictionary) -> Dictionary:
	var key := Address.key(target)
	if not _actors.has(actor_id) or not _spaces.has(key):
		return {"ok": false, "code": "UNKNOWN_TARGET"}
	var actor: Dictionary = _actors[actor_id]
	var position: Vector2 = actor["position"]
	if not _inside(key, position, actor["radius"]):
		return {"ok": false, "code": "TARGET_OUT_OF_BOUNDS"}
	var state := PhysicsServer2D.space_get_direct_state(_spaces[key]["space"])
	if state == null:
		return {"ok": false, "code": "PHYSICS_SPACE_NOT_READY"}
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape_rid = actor["shape"]
	query.transform = Transform2D(0.0, position)
	query.collision_mask = 1
	if not state.intersect_shape(query, 1).is_empty():
		return {"ok": false, "code": "TARGET_BLOCKED"}
	PhysicsServer2D.body_set_space(actor["body"], _spaces[key]["space"])
	actor["layer_key"] = key
	return {"ok": true, "position": position}

func actor_view(actor_id: String) -> Dictionary:
	if not _actors.has(actor_id):
		return {}
	var actor: Dictionary = _actors[actor_id]
	return {"layer_key": actor["layer_key"], "position": actor["position"], "radius": actor["radius"]}

func dispose() -> void:
	for body in _bodies:
		PhysicsServer2D.free_rid(body)
	for shape in _shapes:
		PhysicsServer2D.free_rid(shape)
	for value in _spaces.values():
		PhysicsServer2D.free_rid(value["space"])
	_bodies.clear()
	_shapes.clear()
	_spaces.clear()
	_actors.clear()

func _inside(key: String, position: Vector2, radius: float) -> bool:
	if not position.is_finite():
		return false
	var bounds: Rect2i = _spaces[key]["bounds"]
	return position.x - radius >= bounds.position.x and position.y - radius >= bounds.position.y and position.x + radius <= bounds.end.x and position.y + radius <= bounds.end.y

func _rectangle(space: RID, box: Rect2) -> void:
	var shape := PhysicsServer2D.rectangle_shape_create()
	PhysicsServer2D.shape_set_data(shape, box.size / 2.0)
	_shapes.append(shape)
	var body := PhysicsServer2D.body_create()
	_bodies.append(body)
	PhysicsServer2D.body_set_mode(body, PhysicsServer2D.BODY_MODE_STATIC)
	PhysicsServer2D.body_set_collision_layer(body, 1)
	PhysicsServer2D.body_set_collision_mask(body, 0)
	PhysicsServer2D.body_add_shape(body, shape)
	PhysicsServer2D.body_set_state(body, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, box.get_center()))
	PhysicsServer2D.body_set_space(body, space)

func _clear_at(key: String, position: Vector2, radius: float) -> bool:
	var state := PhysicsServer2D.space_get_direct_state(_spaces[key]["space"])
	if state == null:
		return false
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, position)
	query.collision_mask = 1
	return state.intersect_shape(query, 1).is_empty()
