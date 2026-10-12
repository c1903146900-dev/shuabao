extends "res://scripts/actor/actor_play_view.gd"
## Explicit new4 renderer. Uses received validated public rows, never Stage or
## an enclosing rectangle as generated ground. Shares the existing actor/HUD.
const TerrainProjection = preload("res://scripts/actor/actor_terrain_public_projection.gd")
var _terrain_public: Dictionary = {}
var _ground_layer: Dictionary = {}
var _ground_records: Array = []
var _render_profile: Dictionary = {"build_count": 0, "total_usec": 0, "max_usec": 0, "last_visible_rows": 0}

func terrain_ready() -> bool:
	return not _terrain_public.is_empty()

func consume_validated_terrain(value: Dictionary) -> Dictionary:
	# Called only after ActorTerrainClientState accepted the complete envelope.
	# This view is not a network trust boundary or a geometry authority.
	if value.get("contract") != TerrainProjection.CONTRACT:
		return _empty("TERRAIN_PLAY_PUBLIC_REQUIRED")
	if not _terrain_public.is_empty():
		return {"ok": true} if value == _terrain_public else _empty("TERRAIN_PLAY_STATIC_CHANGE")
	_terrain_public = value.duplicate(true)
	return {"ok": true} # The actor callback rebuilds after world and actor state.

func _build_projection() -> Dictionary:
	if _terrain_public.is_empty() or not _players.get(_own_profile) is Dictionary:
		return {"ok": false, "code": "TERRAIN_PLAY_PUBLIC_REQUIRED"}
	var own_id: String = _players[_own_profile]["player_instance_id"]
	if not _motion.get("actors", {}).get(own_id) is Dictionary:
		return {"ok": false, "code": "ACTOR_VIEW_BINDING_UNAVAILABLE"}
	var layer: Dictionary = _motion["actors"][own_id]["layer"]
	var bounds := Rect2()
	var found := false
	for row in _terrain_public["cells"]:
		if row["layer"] == layer:
			var rect := Rect2(Vector2(row["cell"][0], row["cell"][1]), Vector2.ONE)
			bounds = bounds.merge(rect) if found else rect
			found = true
	if not found:
		return {"ok": false, "code": "TERRAIN_PLAY_LAYER_UNAVAILABLE"}
	return ActorProjection.build(_component, _players, _motion, _own_profile, _diameter, _room_rect, _camera, bounds)

func _rebuild() -> Dictionary:
	var profile_start: int = Time.get_ticks_usec()
	var result: Dictionary = super._rebuild()
	if not result.get("ok", false):
		return result
	if _terrain_public.is_empty():
		return _empty("TERRAIN_PLAY_PUBLIC_REQUIRED")
	var visible: Dictionary = TerrainProjection.visible_rows(_terrain_public, _projection["layer"], _projection["world_bounds"])
	if not visible.get("ok", false):
		return _empty(str(visible.get("code", "TERRAIN_PLAY_PROJECTION_INVALID")))
	var drawn: Array = []
	for row in visible["cells"]:
		var rect := Rect2(Vector2(row["cell"][0], row["cell"][1]), Vector2.ONE)
		var ground: Dictionary = row["ground"]
		drawn.append(_screen_row(rect, "H0", str(ground.get("object_instance_id", "")), bool(ground["is_liquid"]), false))
	for row in visible["objects"]:
		var rect: Array = row["rect"]
		drawn.append(_screen_row(Rect2(Vector2(rect[0], rect[1]), Vector2(rect[2], rect[3])), "H1", row["object_instance_id"], row["is_liquid"], row["blocking"]))
	# Replaces the old prefab-only list. H0 first, actual H1 second, actors last;
	# prefab ground is therefore never drawn twice over the effective cell rows.
	_projection["objects"] = drawn
	var elapsed: int = Time.get_ticks_usec() - profile_start
	_render_profile["build_count"] += 1
	_render_profile["total_usec"] += elapsed
	_render_profile["max_usec"] = maxi(_render_profile["max_usec"], elapsed)
	_render_profile["last_visible_rows"] = drawn.size()
	_request_redraw()
	return {"ok": true}

func terrain_render_statistics() -> Dictionary:
	return _render_profile.duplicate(true)

func _screen_row(rect: Rect2, plane: String, object_id: String, liquid: bool, blocking: bool) -> Dictionary:
	var screen := Rect2(ActorProjection.world_to_screen(_projection, rect.position), rect.size * _projection["scale"]).intersection(_projection["screen_bounds"])
	return {"screen_rect": screen, "instance_id": object_id, "plane": plane, "is_liquid": liquid, "blocking": blocking}

func _object_color(object: Dictionary) -> Color:
	return Color("326985") if object.get("is_liquid", false) else super._object_color(object)

func _controls_text() -> String:
	return "WASD移动 · 鼠标瞄准 · Shift闪避 · 靠近入口并指向后按F · F10保存返回"

func _draw_world_details() -> void:
	_draw_ground_records()
	# Actual public connection bodies only. This marker does not select a target,
	# assert interaction range, or say the authority accepted the F command.
	var mapped: Rect2 = _projection["screen_bounds"]
	var layer: Dictionary = _projection["layer"]
	for connection in _component["layout"]["connections"]:
		var side: int = int(connection["body_side_cells"])
		var half: int = (side - 1) >> 1
		for endpoint in connection["endpoints"]:
			if endpoint["layer"] != layer:
				continue
			var cell: Array = endpoint["cell"]
			var origin := Vector2(int(cell[0]) - half, int(cell[1]) - half)
			var screen := Rect2(ActorProjection.world_to_screen(_projection, origin), Vector2.ONE * side * _projection["scale"]).intersection(mapped)
			if not screen.has_area():
				continue
			draw_rect(screen, Color("e6ce7a"), false, 2.0)
			if screen.size.x >= 36.0 and screen.size.y >= 18.0:
				_text(screen.position + Vector2(4, 15), "F 入口", 12, Color("f3dda0"))

func consume_ground_view(layer: Dictionary, records: Array) -> void:
	# Client leaf already validated its authenticated world, layer and bounded rows.
	_ground_layer = layer.duplicate(true)
	_ground_records = records.duplicate(true)
	_request_redraw()

func _draw_ground_records() -> void:
	if _projection.is_empty() or _projection["layer"] != _ground_layer: return
	var bounds: Rect2 = _projection["screen_bounds"]
	for record in _ground_records:
		var point: Vector2 = ActorProjection.world_to_screen(_projection, Vector2(record["position"][0], record["position"][1]))
		if not bounds.has_point(point): continue
		var color := Color("ac8559") if record["content_id"] == "mucai" else Color("a3a5a9")
		draw_rect(Rect2(point - Vector2(5, 4), Vector2(10, 8)), color)
		_text(point + Vector2(7, -5), str(record["quantity"]), 12, Color.WHITE)
