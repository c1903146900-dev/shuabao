extends RefCounted
## Read-only technical drawing/pointer projection. It performs no collision,
## simulation, target selection, actor creation or mutation of authority records.
const Address = preload("res://scripts/world/spatial_address.gd")
const State = preload("res://scripts/actor/actor_state.gd")
const Command = preload("res://scripts/actor/actor_command.gd")
const PLANE_ORDER := {"H0":0,"H0_OVERLAY":1,"H0_DECAL":2,"H1":3}

static func build(component: Dictionary, players: Dictionary, motion: Dictionary, own_profile: String, diameter: float, viewport: Rect2, camera: Dictionary = {}, actual_terrain_bounds: Rect2 = Rect2()) -> Dictionary:
	if not is_finite(diameter) or diameter <= 0.0 or not viewport.position.is_finite() or not viewport.size.is_finite() or not viewport.end.is_finite() or not viewport.has_area():
		return {"ok":false,"code":"ACTOR_VIEW_METRICS_INVALID"}
	if not players.get(own_profile) is Dictionary or not motion.get("actors") is Dictionary:
		return {"ok":false,"code":"ACTOR_VIEW_BINDING_UNAVAILABLE"}
	var own_id: Variant = players[own_profile].get("player_instance_id")
	if not own_id is String or not motion["actors"].get(own_id) is Dictionary:
		return {"ok":false,"code":"ACTOR_VIEW_BINDING_UNAVAILABLE"}
	var own: Dictionary = motion["actors"][own_id]
	var layer: Variant = own.get("layer")
	if not Address.valid_layer(layer) or not component.get("layout") is Dictionary or layer["world_id"] != component["layout"].get("world_id") or layer["world_id"] != motion.get("world_id") or not component.get("prefab_instances") is Array:
		return {"ok":false,"code":"ACTOR_VIEW_LAYER_INVALID"}
	var layer_key := Address.key(layer)
	# Optional new4 bounds come from actual received cells and only establish
	# display coordinates. They never add draw rows or collision coverage.
	if not actual_terrain_bounds.position.is_finite() or not actual_terrain_bounds.size.is_finite() or not actual_terrain_bounds.end.is_finite():
		return {"ok":false,"code":"ACTOR_VIEW_METRICS_INVALID"}
	var world_bounds := actual_terrain_bounds
	var found := actual_terrain_bounds.has_area()
	for instance in component["prefab_instances"]:
		if not instance is Dictionary or not instance.get("layers") is Array or not instance.get("objects") is Array:
			return {"ok":false,"code":"ACTOR_VIEW_COMPONENT_INVALID"}
		for region in instance["layers"]:
			if not region is Dictionary or not Address.valid_layer(region.get("address")):
				return {"ok":false,"code":"ACTOR_VIEW_REGION_INVALID"}
			if Address.key(region["address"]) != layer_key:
				continue
			if not _valid_rect(region.get("bounds")):
				return {"ok":false,"code":"ACTOR_VIEW_REGION_INVALID"}
			var bounds := _rect(region["bounds"])
			world_bounds = world_bounds.merge(bounds) if found else bounds
			found = true
	if not found:
		return {"ok":false,"code":"ACTOR_VIEW_REGION_UNAVAILABLE"}
	# Legacy overview remains explicit; the play view supplies validated follow metrics.
	var scale_value: float = minf(viewport.size.x / world_bounds.size.x, viewport.size.y / world_bounds.size.y)
	var mapped := Rect2(viewport.position + (viewport.size - world_bounds.size * scale_value) * 0.5, world_bounds.size * scale_value)
	var visible_world := world_bounds
	var camera_center := world_bounds.get_center()
	if not camera.is_empty():
		if camera.size() != 2 or not State.valid_pair(own.get("position")) or not _positive(camera.get("pixels_per_cell")) or not _positive(camera.get("ground_multiplier")):
			return {"ok":false,"code":"ACTOR_VIEW_CAMERA_INVALID"}
		# Larger multiplier means a wider world view, not a larger sprite.
		scale_value = float(camera["pixels_per_cell"]) / float(camera["ground_multiplier"])
		camera_center = State.vector(own["position"])
		mapped = viewport
		visible_world = Rect2(camera_center - viewport.size / scale_value * 0.5, viewport.size / scale_value)
	if not is_finite(scale_value) or scale_value <= 0.0 or not mapped.position.is_finite() or not mapped.size.is_finite() or not mapped.end.is_finite() or not mapped.has_area() or not visible_world.position.is_finite() or not visible_world.size.is_finite() or not visible_world.end.is_finite() or not visible_world.has_area():
		return {"ok":false,"code":"ACTOR_VIEW_METRICS_INVALID"}
	var projection := {"ok":true,"world_bounds":visible_world,"materialized_bounds":world_bounds,"screen_bounds":mapped,"scale":scale_value,"camera_center":camera_center,"camera_follow":not camera.is_empty(),"layer":layer.duplicate(true),"own_actor_id":own_id,"objects":[],"actors":[],"presentation":"authoritative_geometry_proxy","formal_world_allowed":false}

	for instance in component["prefab_instances"]:
		for row in instance["objects"]:
			if not row is Dictionary or not Address.valid_layer(row.get("layer")):
				return {"ok":false,"code":"ACTOR_VIEW_OBJECT_INVALID"}
			if Address.key(row["layer"]) != layer_key:
				continue
			if not _valid_rect(row.get("rect")) or row.get("plane") not in PLANE_ORDER or not row.get("instance_id") is String:
				return {"ok":false,"code":"ACTOR_VIEW_OBJECT_INVALID"}
			var world_rect := _rect(row["rect"]).intersection(world_bounds)
			if not world_rect.has_area():
				continue
			var screen_rect := Rect2(world_to_screen(projection,world_rect.position),world_rect.size*scale_value).intersection(mapped)
			if screen_rect.has_area():
				projection["objects"].append({"screen_rect":screen_rect,"instance_id":row["instance_id"],"plane":row["plane"],"blocking":row.get("blocking",false)})
	projection["objects"].sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return a["instance_id"] < b["instance_id"] if PLANE_ORDER[a["plane"]] == PLANE_ORDER[b["plane"]] else PLANE_ORDER[a["plane"]] < PLANE_ORDER[b["plane"]])
	var names: Dictionary = {}
	for profile_id in players:
		var player: Variant = players[profile_id]
		if player is Dictionary and player.get("player_instance_id") is String and player.get("display_name") is String:
			names[player["player_instance_id"]] = player["display_name"]
	var actor_ids: Array = motion["actors"].keys()
	actor_ids.sort()
	for actor_id in actor_ids:
		var actor: Variant = motion["actors"][actor_id]
		if not actor is Dictionary or not Address.valid_layer(actor.get("layer")):
			return {"ok":false,"code":"ACTOR_VIEW_ACTOR_INVALID"}
		if Address.key(actor["layer"]) != layer_key:
			continue
		if not State.valid_pair(actor.get("position")) or not _valid_aim(actor.get("aim_position")):
			return {"ok":false,"code":"ACTOR_VIEW_ACTOR_INVALID"}
		var world_position := State.vector(actor["position"])
		var center := world_to_screen(projection,world_position)
		var side: float = diameter * scale_value
		if not center.is_finite() or not is_finite(side) or not (Vector2.ONE * side).is_finite():
			return {"ok":false,"code":"ACTOR_VIEW_METRICS_INVALID"}
		var body_aabb := Rect2(center-Vector2.ONE*side*0.5,Vector2.ONE*side)
		if not body_aabb.position.is_finite() or not body_aabb.end.is_finite():
			return {"ok":false,"code":"ACTOR_VIEW_METRICS_INVALID"}
		var direction: Vector2 = State.vector(actor["aim_position"]) - world_position
		projection["actors"].append({"actor_id":actor_id,"display_name":names.get(actor_id,""),"own":actor_id == own_id,"world_position":world_position,"screen_position":center,"body_aabb":body_aabb,"environment_radius":side*0.5,"aim_direction":direction.normalized() if direction != Vector2.ZERO else Vector2.ZERO,"visible":mapped.intersects(body_aabb),"public_state":actor.duplicate(true)})
	return projection

static func world_to_screen(projection: Dictionary, world_position: Vector2) -> Vector2:
	if projection.get("camera_follow",false):
		return projection["screen_bounds"].get_center() + (world_position-projection["camera_center"]) * projection["scale"]
	return projection["screen_bounds"].position + (world_position - projection["world_bounds"].position) * projection["scale"]

static func screen_to_world(projection: Dictionary, screen_position: Vector2) -> Dictionary:
	if not projection.get("ok",false) or not screen_position.is_finite() or not projection["screen_bounds"].has_point(screen_position):
		return {"ok":false,"code":"ACTOR_VIEW_POINTER_OUTSIDE"}
	var point: Vector2
	if projection.get("camera_follow",false):
		point = projection["camera_center"] + (screen_position-projection["screen_bounds"].get_center()) / projection["scale"]
	else:
		point = projection["world_bounds"].position + (screen_position-projection["screen_bounds"].position) / projection["scale"]
	if not State.valid_pair(State.pair(point)):
		return {"ok":false,"code":"ACTOR_VIEW_POINTER_INVALID"}
	return {"ok":true,"world_point":State.pair(point),"layer":projection["layer"].duplicate(true)}

static func _valid_aim(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	var limit: float = absf(Vector2(Command.MAX_AIM,0.0).x)
	for number in value:
		if not (number is int or number is float) or not is_finite(float(number)) or absf(float(number)) > limit:
			return false
	return true

static func _valid_rect(value: Variant) -> bool:
	if not value is Array or value.size() != 4:
		return false
	for number in value:
		if not (number is int or number is float) or not is_finite(float(number)) or absf(float(number)) > 2147483647.0:
			return false
	return value[2] > 0.0 and value[3] > 0.0

static func _rect(value: Array) -> Rect2:
	return Rect2(Vector2(value[0],value[1]),Vector2(value[2],value[3]))

static func _positive(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) > 0.0
