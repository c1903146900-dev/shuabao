extends Node2D
## Chinese authoritative-geometry display for the explicit technical play client.
## No input/target selection/simulation/collision body. Local intent hints are separate.
## consume keeps the existing world-view API; actor refreshes never copy the world.
const ActorProjection = preload("res://scripts/actor/actor_view_projection.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const DEFAULT_VIEWPORT := Rect2(0, 0, 1180, 812) # Technical window layout only.
const PLANE_COLORS := {"H0": Color("527353"), "H0_OVERLAY": Color("7695a0"), "H0_DECAL": Color("7f8475"), "H1": Color("ad8063")}
const DISPLAY_PATH := "res://data/actor_technical_display011.json"
var _camera: Dictionary = {}
var _component: Dictionary = {}
var _component_hash: String = ""
var _role: String = ""
var _players: Dictionary = {}
var _motion: Dictionary = {}
var _own_profile: String = ""
var _diameter: float = NAN
var _viewport_rect: Rect2 = DEFAULT_VIEWPORT
var _room_rect := Rect2()
var _projection: Dictionary = {}
var _local_presentation: Dictionary = {}
var _status: String = "ACTOR_PLAY_VIEW_EMPTY"
var _component_copies: int = 0
var _actor_updates: int = 0
var _projection_builds: int = 0
var _font: SystemFont
var _watched_viewport: Viewport

func configure_camera(ground_multiplier: float) -> Dictionary:
	_camera.clear()
	var settings: Variant = JSON.parse_string(FileAccess.get_file_as_string(DISPLAY_PATH))
	if not settings is Dictionary or settings.get("schema_version") != 1 or settings.get("purpose") != "technical_display_only" or settings.get("formal_world_allowed") != false or not _number(settings.get("pixels_per_cell")) or float(settings["pixels_per_cell"]) <= 0.0 or settings.get("camera_follow_deadzone_cells") != 0.0 or settings.get("camera_follow_damping_seconds") != 0.0 or settings.get("ground_multiplier_parameter") != "camera_ground_multiplier" or settings.get("zoom_transition_semantic") != "zoom_multiplier_transition_only" or not is_finite(ground_multiplier) or ground_multiplier <= 0.0:
		return _empty("ACTOR_PLAY_CAMERA_CONFIG_INVALID")
	_camera = {"pixels_per_cell":float(settings["pixels_per_cell"]),"ground_multiplier":ground_multiplier}
	_rebuild()
	return {"ok":true}

func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Noto Sans CJK SC", "DejaVu Sans"])
	_watched_viewport = get_viewport()
	if not _watched_viewport.size_changed.is_connected(_on_viewport_size_changed):
		_watched_viewport.size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

func _exit_tree() -> void:
	if is_instance_valid(_watched_viewport) and _watched_viewport.size_changed.is_connected(_on_viewport_size_changed):
		_watched_viewport.size_changed.disconnect(_on_viewport_size_changed)
	_watched_viewport = null

func consume(component: Dictionary, role: String) -> void:
	var role_changed := role != _role
	_role = role
	if component.is_empty():
		_component.clear()
		_component_hash = ""
		clear_actor_state()
		return
	# Callers may hand us a new Dictionary containing unchanged verified rows.
	# Equality avoids another world copy or JSON/hash allocation on this path.
	if component == _component:
		if role_changed:
			_request_redraw()
		return
	_component = component.duplicate(true)
	_component_copies += 1
	_component_hash = JSON.stringify(_component, "", true, true).sha256_text()
	_rebuild()

func consume_actor_state(players: Dictionary, motion: Dictionary, own_profile: String, diameter: float) -> Dictionary:
	clear_local_presentation() # Snapshot callback must re-publish the synchronized hint.
	if players == _players and motion == _motion and own_profile == _own_profile and diameter == _diameter:
		return _result()
	_players = players.duplicate(true)
	_motion = motion.duplicate(true)
	_own_profile = own_profile
	_diameter = diameter
	_actor_updates += 1
	return _rebuild()

func clear_actor_state() -> void:
	clear_local_presentation()
	_players.clear()
	_motion.clear()
	_own_profile = ""
	_diameter = NAN
	_empty("ACTOR_PLAY_VIEW_EMPTY")

func set_viewport_rect(viewport: Rect2) -> Dictionary:
	# Pure resize seam. A valid viewport may still be awaiting an actor binding.
	if not viewport.position.is_finite() or not viewport.size.is_finite() or not viewport.end.is_finite() or not viewport.has_area():
		_viewport_rect = Rect2()
		return _empty("ACTOR_PLAY_VIEW_METRICS_INVALID")
	if viewport == _viewport_rect:
		return {"ok": true, "projection_ready": not _projection.is_empty()}
	_viewport_rect = viewport
	_rebuild()
	return {"ok": true, "projection_ready": not _projection.is_empty()}

func pointer_to_world(view_position: Vector2) -> Dictionary:
	# Coordinates are local to this zero-offset view, matching its drawing space.
	if _projection.is_empty():
		return {"ok": false, "code": "ACTOR_PLAY_VIEW_POINTER_UNAVAILABLE"}
	return ActorProjection.screen_to_world(_projection, view_position)

func drawing_state() -> Dictionary:
	# Detached, bounded draw records for inspection; contains no full world copy.
	return _projection.duplicate(true)

func consume_local_presentation(state: Dictionary) -> Dictionary:
	clear_local_presentation()
	if state.is_empty():
		return {"ok":true}
	var binding: Dictionary = state.get("binding", {})
	if _projection.is_empty() or binding.get("world_id") != _projection["layer"]["world_id"] or binding.get("player_profile_id") != _own_profile or binding.get("player_instance_id") != _projection["own_actor_id"] or binding.get("actor_revision") != _motion.get("revision"):
		return {"ok":false,"code":"ACTOR_PLAY_PRESENTATION_VIEW_BINDING_INVALID"}
	# The only producer is the independently validated local presentation model.
	# No merge into _motion/_projection/public_state occurs on this path.
	_local_presentation = state.duplicate(true)
	_request_redraw()
	return {"ok":true}

func clear_local_presentation() -> void:
	_local_presentation.clear()
	_request_redraw()

func local_presentation_state() -> Dictionary:
	return _local_presentation.duplicate(true)

func statistics() -> Dictionary:
	var actor_ids: Array = []
	var object_ids: Array = []
	var visible_actors: int = 0
	for actor in _projection.get("actors", []):
		actor_ids.append(actor["actor_id"])
		if actor["visible"]:
			visible_actors += 1
	for object in _projection.get("objects", []):
		object_ids.append(object["instance_id"])
	return {
		# Immediate drawing creates no per-layer/object scene nodes. Do not report
		# projected rows as materialized authoritative objects or native bodies.
		"layer_nodes": 0, "materialized_object_nodes": 0,
		"component_sha256": _component_hash, "component_copy_count": _component_copies,
		"actor_state_updates": _actor_updates, "projection_builds": _projection_builds,
		"draw_ready": not _projection.is_empty(), "status": _status, "role": _role,
		"projected_objects": object_ids.size(), "projected_actors": actor_ids.size(), "visible_actors": visible_actors,
		"actor_ids": actor_ids, "object_instance_ids": object_ids,
		"own_actor_id": _projection.get("own_actor_id", ""), "layer": _projection.get("layer", {}).duplicate(true),
		"world_seconds": _motion.get("clock") if _number(_motion.get("clock")) else null,
		"actor_revision": _motion.get("revision") if _number(_motion.get("revision")) else null,
		"diameter_cells": _diameter if is_finite(_diameter) and _diameter > 0.0 else null,
		"room_viewport": [_room_rect.position.x, _room_rect.position.y, _room_rect.size.x, _room_rect.size.y],
		"camera_follow": _projection.get("camera_follow", false),
		"camera_center": _pair(_projection.get("camera_center")), "camera_scale": _projection.get("scale"),
		"presentation": "authoritative_actor_geometry_proxy", "prediction_implemented": false,
		"local_aim_action_hints": not _local_presentation.is_empty(), "positional_prediction": false,
		"formal_assets_implemented": false, "formal_world_allowed": false,
	}

func _on_viewport_size_changed() -> void:
	if is_inside_tree():
		set_viewport_rect(get_viewport_rect())
		_request_redraw()

func _rebuild() -> Dictionary:
	if _camera.is_empty():
		return _empty("ACTOR_PLAY_CAMERA_UNCONFIGURED")
	if _component.is_empty():
		return _empty("ACTOR_PLAY_VIEW_WORLD_UNAVAILABLE")
	if not _viewport_rect.has_area():
		return _empty("ACTOR_PLAY_VIEW_METRICS_INVALID")
	var hud_height: float = 68.0 + float(_current_layer_actor_count()) * 38.0
	_room_rect = Rect2(_viewport_rect.position + Vector2(20.0, 96.0), _viewport_rect.size - Vector2(40.0, 116.0 + hud_height))
	if _room_rect.size.x < 160.0 or _room_rect.size.y < 80.0:
		return _empty("ACTOR_PLAY_VIEW_VIEWPORT_TOO_SMALL")
	_projection_builds += 1
	var projected := _build_projection()
	if not projected.get("ok", false):
		return _empty(str(projected.get("code", "ACTOR_PLAY_VIEW_PROJECTION_INVALID")))
	_projection = projected
	_status = "ACTOR_PLAY_VIEW_READY"
	_request_redraw()
	return {"ok": true}

func _build_projection() -> Dictionary:
	return ActorProjection.build(_component, _players, _motion, _own_profile, _diameter, _room_rect, _camera)

func _current_layer_actor_count() -> int:
	if not _players.get(_own_profile) is Dictionary or not _motion.get("actors") is Dictionary:
		return 1
	var actors: Dictionary = _motion["actors"]
	var own_id: Variant = _players[_own_profile].get("player_instance_id")
	if not actors.get(own_id) is Dictionary or not Address.valid_layer(actors[own_id].get("layer")):
		return 1
	var key := Address.key(actors[own_id]["layer"])
	var count: int = 0
	for actor in actors.values():
		if actor is Dictionary and Address.valid_layer(actor.get("layer")) and Address.key(actor["layer"]) == key:
			count += 1
	return maxi(1, count)

func _empty(code: String) -> Dictionary:
	clear_local_presentation()
	_projection.clear()
	_room_rect = Rect2()
	_status = code
	_request_redraw()
	return {"ok": false, "code": code}

func _result() -> Dictionary:
	return {"ok": true} if not _projection.is_empty() else {"ok": false, "code": _status}

func _request_redraw() -> void:
	if is_inside_tree():
		queue_redraw()

func _object_color(object: Dictionary) -> Color:
	return PLANE_COLORS[object["plane"]]

func _draw_world_details() -> void:
	pass

func _controls_text() -> String:
	return "WASD移动 · 鼠标瞄准 · Shift闪避 · F仅发送意图（交互未接） · F10退出"

func _draw() -> void:
	if _font == null or not _viewport_rect.has_area():
		return
	var origin := _viewport_rect.position
	draw_rect(_viewport_rect, Color("17202d"))
	_text(origin + Vector2(20, 29), "011 人物视图 · 中文技术代理", 23)
	_text(origin + Vector2(20, 51), "位置/资源为权威快照；本地瞄准/动作提示暂定；正式放行=false", 14)
	if _projection.is_empty():
		_text(origin + Vector2(20, 88), "等待当前玩家的有效世界与人物状态，不切换为其他玩家视角", 16)
		_text(origin + Vector2(20, 112), "状态：" + _status, 12)
		return
	var layer: Dictionary = _projection["layer"]
	_text(origin + Vector2(20, 72), "世界：" + layer["world_id"], 12)
	_text(origin + Vector2(20, 90), "%s / %s / %s / 深度%d    服务器游戏秒：%s" % [layer["reference_frame"], layer["body_instance_id"], layer["map_kind"], int(layer["depth"]), _clock_text()], 12)
	draw_rect(_room_rect, Color("101822"))
	var mapped: Rect2 = _projection["screen_bounds"]
	draw_rect(mapped, Color("253344"))
	for object in _projection["objects"]:
		draw_rect(object["screen_rect"], _object_color(object))
		draw_rect(object["screen_rect"], Color("263445"), false, 1.0)
	_draw_world_details()
	for actor in _projection["actors"]:
		if not actor["visible"]:
			continue
		var color := Color("65c5ff") if actor["own"] else Color("f3c879")
		var center: Vector2 = actor["screen_position"]
		var body: Rect2 = actor["body_aabb"]
		draw_rect(body.intersection(mapped), Color(color, 0.38))
		draw_rect(body.intersection(mapped), color, false, 2.0)
		if mapped.encloses(body):
			draw_arc(center, actor["environment_radius"], 0.0, TAU, 48, Color("e1edf5"), 1.0, true)
		var shown_direction: Vector2 = actor["aim_direction"]
		if actor["own"] and not _local_presentation.is_empty():
			var aim: Array = _local_presentation["aim"]
			shown_direction = (Vector2(aim[0], aim[1]) - actor["world_position"]).normalized()
		var end: Vector2 = center + shown_direction * (float(actor["environment_radius"]) + 14.0)
		if mapped.has_point(center):
			draw_line(center, _aim_endpoint(center, end, mapped), color, 2.0, true)
		var label := Vector2(clampf(center.x + 5.0, mapped.position.x + 2.0, mapped.end.x - 75.0), clampf(center.y - 8.0, mapped.position.y + 13.0, mapped.end.y - 2.0))
		_text(label, ("本人 " if actor["own"] else "") + str(actor["actor_id"]).right(6), 11, color)
	var row_y: float = _room_rect.end.y + 21.0
	_text(Vector2(origin.x + 20.0, row_y), "当前层玩家 · 下列资源均为服务器当前值", 14)
	row_y += 19.0
	for actor in _projection["actors"]:
		var name_text: String = actor["display_name"]
		name_text = name_text.substr(0, 16) + "…" if name_text.length() > 16 else name_text
		_text(Vector2(origin.x + 20.0, row_y), ("本人 " if actor["own"] else "队友 ") + name_text + "  " + actor["actor_id"], 12)
		var direction: Vector2 = actor["aim_direction"]
		_text(Vector2(origin.x + 20.0, row_y + 15.0), _resources_text(actor["public_state"]) + "   瞄准方向(%.2f, %.2f)" % [direction.x, direction.y], 12)
		row_y += 38.0
	_text(Vector2(origin.x + 20.0, _viewport_rect.end.y - 29.0), _controls_text(), 12)
	_text(Vector2(origin.x + 20.0, _viewport_rect.end.y - 12.0), ("暂定输入：" + _action_hint_text() + "（未确认动作成功）") if not _local_presentation.get("action_intents", {}).is_empty() else "方框=玩家互碰；圆=环境体；短线=瞄准。技术镜头跟随本人权威位置", 12)

func _action_hint_text() -> String:
	var labels := {"dodge":"闪避", "interact":"交互", "pressed":"按下", "held":"保持", "released":"释放"}
	var parts := PackedStringArray()
	for action in _local_presentation.get("action_intents", {}):
		parts.append(labels[action] + labels[_local_presentation["action_intents"][action]["phase"]])
	return " / ".join(parts)

func _text(position: Vector2, value: String, size: int, color: Color = Color("e6edf5")) -> void:
	draw_string(_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _clock_text() -> String:
	return "%.3f" % float(_motion["clock"]) if _number(_motion.get("clock")) else "未提供"

static func _resources_text(actor: Dictionary) -> String:
	for key in ["health", "food", "energy"]:
		if not _number(actor.get(key)):
			return "权威资源字段缺失或无效"
	# No invented maxima and no local regeneration/countdown calculation.
	return "生命 %.2f  饱食 %.2f  能量 %.2f" % [float(actor["health"]), float(actor["food"]), float(actor["energy"])]

static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

static func _aim_endpoint(start: Vector2, end: Vector2, bounds: Rect2) -> Vector2:
	if not bounds.has_point(start):
		return start
	var delta := end - start
	var fraction: float = 1.0
	for axis in range(2):
		if delta[axis] > 0.0:
			fraction = minf(fraction, (bounds.end[axis] - start[axis]) / delta[axis])
		elif delta[axis] < 0.0:
			fraction = minf(fraction, (bounds.position[axis] - start[axis]) / delta[axis])
	return start + delta * clampf(fraction, 0.0, 1.0)

static func _pair(value: Variant) -> Variant:
	return [value.x,value.y] if value is Vector2 else null
