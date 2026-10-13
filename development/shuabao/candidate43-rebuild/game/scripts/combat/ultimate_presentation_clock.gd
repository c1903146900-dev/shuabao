extends RefCounted
## One authority, one room generation, one world clock. No Engine.time_scale.
## Independent candidate: callers must explicitly integrate its returned segments.

var _scope: Dictionary = {}
var _durations: Dictionary = {}
var _slow_factor: float = 1.0
var _ready: bool = false
var _active: Dictionary = {}
var _casts: Dictionary = {}
var _serial: int = 0
var _real_time: float = 0.0
var _world_time: float = 0.0

func _init(scope: Dictionary, authoring: Dictionary) -> void:
	if not _valid_scope(scope):
		return
	var slow: Variant = authoring.get("world_slow_factor")
	var durations: Variant = authoring.get("presentation_seconds")
	if not _positive_number(slow) or float(slow) >= 1.0 or not durations is Dictionary or durations.is_empty():
		return
	for ability_id: Variant in durations:
		if not ability_id is String or String(ability_id).is_empty() or not _positive_number(durations[ability_id]):
			return
	_scope = scope.duplicate(true)
	_durations = durations.duplicate(true)
	_slow_factor = float(slow)
	_ready = true

func configuration_ready() -> bool:
	return _ready

func begin_presentation(request: Dictionary) -> Dictionary:
	if not _ready or not _matches_scope(request):
		return {"ok": false, "reason": "invalid_scope"}
	for key: String in ["actor_id", "cast_id", "ability_id"]:
		if not request.get(key) is String or String(request[key]).is_empty():
			return {"ok": false, "reason": "invalid_identity"}
	var actor_id: String = request["actor_id"]
	var ability_id: String = request["ability_id"]
	if not _durations.has(ability_id):
		return {"ok": false, "reason": "unknown_ability"}
	var cast_key: String = JSON.stringify([actor_id, request["cast_id"]])
	if _casts.has(cast_key):
		var previous: Dictionary = _casts[cast_key]
		if previous["ability_id"] != ability_id:
			return {"ok": false, "reason": "cast_conflict"}
		return {"ok": true, "reason": "duplicate", "token": previous.duplicate(true), "active": is_invulnerable(previous)}
	# An actor cannot overlap two presentations. Reject without renewing the first.
	if _active.has(actor_id):
		return {"ok": false, "reason": "actor_already_presenting"}
	var expires_at: float = _real_time + float(_durations[ability_id])
	if not is_finite(expires_at) or expires_at <= _real_time:
		return {"ok": false, "reason": "unrepresentable_expiry"}
	_serial += 1
	var token: Dictionary = _scope.duplicate(true)
	token.merge({"actor_id": actor_id, "cast_id": request["cast_id"], "ability_id": ability_id, "serial": _serial})
	_casts[cast_key] = token.duplicate(true)
	_active[actor_id] = {"token": token.duplicate(true), "expires_at": expires_at}
	return {"ok": true, "reason": "started", "token": token.duplicate(true), "active": true}

func end_presentation(token: Dictionary) -> bool:
	if not is_invulnerable(token):
		return false
	_active.erase(String(token["actor_id"]))
	return true

func is_invulnerable(token: Dictionary) -> bool:
	# Immunity is the current presentation token's eligibility, never a slow buff.
	if not _ready or not _matches_scope(token):
		return false
	var actor_id: Variant = token.get("actor_id")
	if not actor_id is String or not _active.has(actor_id):
		return false
	var entry: Dictionary = _active[actor_id]
	var expected: Dictionary = entry["token"]
	if token.size() != expected.size():
		return false
	for key: String in expected:
		if not token.has(key) or typeof(token[key]) != typeof(expected[key]) or token[key] != expected[key]:
			return false
	return true

func reset_scope(next_scope: Dictionary) -> bool:
	# Authority ownership cannot be switched in-place; room/generation may advance.
	if not _ready or not _valid_scope(next_scope):
		return false
	if next_scope["owner_id"] != _scope["owner_id"] or int(next_scope["generation"]) <= int(_scope["generation"]):
		return false
	_scope = next_scope.duplicate(true)
	_active.clear()
	_casts.clear()
	_real_time = 0.0
	_world_time = 0.0
	return true

func advance(real_delta: float, actor_ids: Array, paused: bool = false) -> Dictionary:
	if not _ready or not is_finite(real_delta) or real_delta < 0.0 or not is_finite(_real_time + real_delta):
		return {"ok": false, "reason": "invalid_delta_or_configuration"}
	if not paused and real_delta > 0.0 and _real_time + real_delta <= _real_time:
		return {"ok": false, "reason": "unrepresentable_delta"}
	var actors: Array = []
	for actor_id: Variant in actor_ids:
		if not actor_id is String or String(actor_id).is_empty():
			return {"ok": false, "reason": "invalid_actor_id"}
		if not actors.has(actor_id):
			actors.append(actor_id)
	for actor_id: Variant in _active:
		if not actors.has(actor_id):
			actors.append(actor_id)
	actors.sort()
	var actor_totals: Dictionary = {}
	var presentation_totals: Dictionary = {}
	for actor_id: String in actors:
		actor_totals[actor_id] = 0.0
		presentation_totals[actor_id] = 0.0
	var frame: Dictionary = {"ok": true, "paused": paused, "input_real_dt": real_delta, "real_dt": 0.0, "world_dt": 0.0, "actor_group_dt": actor_totals, "presentation_dt": presentation_totals, "segments": []}
	var frame_start: float = _real_time
	var frame_end: float = frame_start if paused else frame_start + real_delta
	while _real_time < frame_end:
		var boundary: float = frame_end
		for entry: Dictionary in _active.values():
			boundary = minf(boundary, float(entry["expires_at"]))
		var slice_dt: float = boundary - _real_time
		var scale: float = 1.0 if _active.is_empty() else _slow_factor
		var world_dt: float = slice_dt * scale
		var slice_actors: Dictionary = {}
		var slice_tokens: Dictionary = {}
		for actor_id: String in actors:
			var presenting: bool = _active.has(actor_id)
			var actor_dt: float = slice_dt if presenting else world_dt
			slice_actors[actor_id] = actor_dt
			actor_totals[actor_id] += actor_dt
			if presenting:
				presentation_totals[actor_id] += slice_dt
				slice_tokens[actor_id] = _active[actor_id]["token"].duplicate(true)
		frame["segments"].append({"real_offset": _real_time - frame_start, "real_dt": slice_dt, "world_dt": world_dt, "world_scale": scale, "actor_group_dt": slice_actors, "presentation_tokens": slice_tokens})
		frame["world_dt"] += world_dt
		_world_time += world_dt
		_real_time = boundary
		for actor_id: Variant in _active.keys():
			if float(_active[actor_id]["expires_at"]) <= _real_time:
				_active.erase(actor_id)
	frame["real_dt"] = _real_time - frame_start
	frame["world_time"] = _world_time
	frame["active_real_time"] = _real_time
	frame["end_presenters"] = _active.keys()
	return frame

func snapshot() -> Dictionary:
	return {"ready": _ready, "scope": _scope.duplicate(true), "world_time": _world_time, "active_real_time": _real_time, "presentations": _active.duplicate(true)}

func _matches_scope(value: Dictionary) -> bool:
	for key: String in ["owner_id", "room_id", "generation"]:
		if not value.has(key) or typeof(value[key]) != typeof(_scope.get(key)) or value[key] != _scope.get(key):
			return false
	return true

func _valid_scope(scope: Dictionary) -> bool:
	if scope.size() != 3:
		return false
	for key: String in ["owner_id", "room_id"]:
		if not scope.get(key) is String or String(scope[key]).is_empty():
			return false
	return scope.get("generation") is int and int(scope["generation"]) >= 0

func _positive_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) > 0.0
