extends Node3D
## Detached roster owner. No Sim, callbacks, source-array references or gameplay.
const View = preload("res://tests/ink_first_floor_enemy_views_20261004/enemy_view.gd")
const Cursor = preload("res://tests/ink_first_floor_enemy_views_20261004/fix01/pose_cursor.gd")
const Catalog = preload("res://tests/ink_first_floor_enemy_views_20261004/asset_catalog.gd")
const MAX_ACTORS := 6
var views: Dictionary = {}
var cursors: Dictionary = {}
var retired: Dictionary = {}
var _kinds: Dictionary = {}
var _ids: Dictionary = {}
var _reader := -1
var _epoch := -1
var _serial := -1
var _scope: Dictionary = {}
var _last_world := -1.0
var report: Dictionary = {}
var view_factory: Callable # Finite contract-test injection only; real path defaults View.

func _ready() -> void:
	set_process(false); set_physics_process(false)

func reset_owner() -> void:
	_clear_views()
	_reader = -1; _epoch = -1; _serial = -1; _scope.clear(); _last_world = -1.0

func _clear_views() -> void:
	for token: String in views: views[token].free()
	views.clear(); cursors.clear(); retired.clear(); _kinds.clear(); _ids.clear()

func present(input: Dictionary) -> Dictionary:
	# Deep copy at public boundary; no consumer method sees caller-owned arrays.
	var frame: Dictionary = input.duplicate(true)
	var reason := _validate(frame)
	if not reason.is_empty():
		# An invalid current source must not leave a convincing stale live roster.
		visible = false
		report = {"status":"HOLD","reason":reason}; return report.duplicate(true)
	visible = true
	if int(frame.epoch) != _epoch:
		_clear_views(); _last_world = -1.0
	_reader = int(frame.reader_id); _epoch = int(frame.epoch); _serial = int(frame.sample_serial)
	_scope = frame.scope.duplicate(true); _last_world = float(frame.world_time)
	var present_tokens: Dictionary = {}
	var samples: Array = []
	var errors: Array = []
	for actor: Dictionary in frame.actors:
		var token := str(actor.token)
		present_tokens[token] = true
		if retired.has(token): continue
		if not cursors.has(token):
			var cursor: RefCounted = Cursor.new(); cursor.configure(str(actor.state.kind)); cursors[token] = cursor
			_kinds[token] = str(actor.state.kind); _ids[token] = str(actor.state.actor_id)
			var view: Node3D = view_factory.call() if view_factory.is_valid() else View.new()
			add_child(view)
			if not view.configure(str(actor.state.kind)):
				errors.append(view.import_report.duplicate(true)); view.free(); continue
			views[token] = view
		if not views.has(token):
			errors.append({"token":token,"status":"HOLD_view_unavailable"}); continue
		var sample: Dictionary = cursors[token].sample(actor,frame)
		if bool(sample.get("cleanup",false)):
			views[token].free(); views.erase(token); cursors.erase(token); retired[token] = true
		else:
			views[token].apply_sample(sample)
			if str(views[token].sample_report.get("status","")) != "ready": errors.append(views[token].sample_report.duplicate(true))
		samples.append(sample)
	for token: String in views.keys():
		if not present_tokens.has(token):
			views[token].free(); views.erase(token); cursors.erase(token); _kinds.erase(token); _ids.erase(token)
	for token: String in retired.keys():
		if not present_tokens.has(token): retired.erase(token); _kinds.erase(token); _ids.erase(token)
	report = {"status":"ready" if errors.is_empty() else "HOLD","scope":_scope.duplicate(true),"view_count":views.size(),"retired_corpse_count":retired.size(),"source_actor_count":frame.actors.size(),"samples":samples,"errors":errors,"normal_full_floor":false,"pixels_verified":false}
	if not errors.is_empty(): visible = false
	return report.duplicate(true)

func _validate(frame: Dictionary) -> String:
	if frame.get("schema","") != "enemy-roster-1" or frame.get("status","") != "ready": return "source_not_ready"
	for key: String in ["reader_id","epoch","sample_serial","scope","world_time","phase","paused","hero_dead","actors"]:
		if not frame.has(key): return "missing_" + key
	if not frame.scope is Dictionary or not frame.actors is Array: return "invalid_scope_or_actors"
	for key: String in ["source_instance","room_id","generation"]:
		if not frame.scope.has(key): return "scope_missing_" + key
	if frame.actors.size() > MAX_ACTORS: return "candidate_roster_exceeds_six"
	if _reader >= 0 and int(frame.reader_id) != _reader: return "new_reader_requires_explicit_reset"
	if int(frame.epoch) < _epoch or int(frame.sample_serial) < _serial: return "stale_scope_or_sample"
	if int(frame.epoch) == _epoch and frame.scope != _scope: return "scope_changed_without_epoch"
	if not is_finite(float(frame.world_time)) or (int(frame.epoch) == _epoch and float(frame.world_time) < _last_world): return "source_time_regression"
	var tokens: Dictionary = {}; var ids: Dictionary = {}
	for actor: Dictionary in frame.actors:
		if not actor.has("token") or not actor.has("state") or not actor.has("dead_at"): return "invalid_actor_envelope"
		var token := str(actor.token); var state: Dictionary = actor.state
		for key: String in ["actor_id","kind","position","hp","max_hp","dead","room_id","generation"]:
			if not state.has(key): return "actor_missing_" + key
		if token.is_empty() or tokens.has(token) or ids.has(state.actor_id): return "duplicate_actor_identity"
		if state.kind not in Catalog.ROLES: return "unsupported_role"
		if int(frame.epoch) == _epoch and _ids.has(token) and _ids[token] != state.actor_id: return "incarnation_changed_actor_id"
		if int(frame.epoch) == _epoch and _kinds.has(token) and _kinds[token] != state.kind: return "incarnation_changed_role"
		if str(state.room_id) != str(frame.scope.room_id) or int(state.generation) != int(frame.scope.generation): return "actor_scope_mismatch"
		if not state.position is Vector3 or not state.position.is_finite() or not is_finite(float(state.hp)) or not is_finite(float(state.max_hp)) or float(state.max_hp) <= 0.0 or not is_finite(float(state.get("shield",0.0))): return "invalid_actor_values"
		if not is_finite(float(state.get("common_model_scale",1.0))) or float(state.get("common_model_scale",1.0)) <= 0.0: return "invalid_model_scale"
		var contact: Dictionary = actor.get("contact",{})
		if not contact.is_empty() and (contact.get("token","") != token or contact.get("actor_id","") != state.actor_id or contact.get("scope",{}) != frame.scope): return "contact_identity_mismatch"
		tokens[token] = true; ids[state.actor_id] = true
	return ""

func actor_view_map() -> Dictionary:
	# Fresh presentation-only mapping for the existing socket-aware VFX consumer.
	# Caller must clear that consumer on room epoch or actor-token replacement.
	var result: Dictionary = {}
	if report.get("status", "") != "ready": return result
	for token: String in views: result[str(_ids[token])] = views[token]
	return result
