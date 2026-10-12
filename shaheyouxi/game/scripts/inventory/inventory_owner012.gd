extends RefCounted
## Private inventory service for the explicit schema5 owner. The actual network
## owner must authenticate/queue/recheck requests at a confirmed Frame boundary.
## Atomic authoritative actions are NOT durable receipts. No save-file I/O here.
const DropPlan = preload("res://scripts/inventory/inventory_drop_plan012.gd")
const Ground = preload("res://scripts/inventory/inventory_ground012.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Combined = preload("res://scripts/inventory/inventory_world_session012.gd")
const View = preload("res://scripts/inventory/ui012/inventory_view012.gd")
const HotBoundary = preload("res://scripts/inventory/inventory_hot_boundary012.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
var ready: bool = false
var _initialized: bool = false
var _busy: bool = false
var _world_id: String = ""
var _core: RefCounted
var _contract: RefCounted
var _access: Dictionary = {}
var _authority: RefCounted
var _catalogue_hash: String = ""
var _protocol: int = 0
var _hot_boundary: RefCounted = HotBoundary.new()

func _init(terrain: RefCounted, authority: RefCounted) -> void:
	# Construct only after successful ordinary authority restore, or for a new
	# authority. Cold-load validation is a separate read-only registry path.
	if authority == null or authority.get_script() != Combined.Authority: return
	_authority = authority
	_world_id = authority.world_id
	_catalogue_hash = authority.catalogue_hash
	_protocol = authority.protocol_version
	_core = Core.new(_world_id)
	_contract = Combined.new(terrain, _core, authority)
	ready = _core.ready and _contract.ready

func _binding_valid() -> bool:
	return ready and _authority != null and _authority.get_script() == Combined.Authority and _authority.world_id == _world_id and _authority.catalogue_hash == _catalogue_hash and _authority.protocol_version == _protocol

func initialize_empty(base: Dictionary) -> Dictionary:
	if not _binding_valid() or _initialized or _busy: return _bad("INVENTORY_OWNER_ALREADY_BOUND")
	var checked: Dictionary = _contract.combine(base, _core.snapshot())
	if not checked.get("ok", false): return checked
	_initialized = true
	return {"ok": true}

func initialize_loaded(value: Variant) -> Dictionary:
	if not _binding_valid() or _initialized or _busy: return _bad("INVENTORY_OWNER_ALREADY_BOUND")
	var checked: Dictionary = _contract.validate_combined_state(value)
	if not checked.get("ok", false): return checked
	var candidate := Core.new(_world_id)
	checked = candidate.trusted_restore(value["inventory_component"])
	if not checked.get("ok", false): return checked
	_core = candidate
	_initialized = true
	return {"ok": true}

func snapshot() -> Dictionary:
	return _core.snapshot() if _binding_valid() and _initialized else {}

func has_ground_component() -> bool:
	return _binding_valid() and _initialized and _core._state.get("schema_version") == 2

func revision() -> int:
	return _core.revision() if _binding_valid() and _initialized else -1

func boundary_token() -> String:
	if not _binding_valid() or not _initialized: return ""
	var encoded: Dictionary = Codec.encode(_core.snapshot())
	return JSON.stringify(encoded["value"], "", true, true) if encoded.get("ok", false) else ""

func combine_for_save(base: Dictionary) -> Dictionary:
	if not _binding_valid() or not _initialized or _busy: return _bad("INVENTORY_OWNER_NOT_AVAILABLE")
	return _contract.combine(base, _core.snapshot())

func prepare_new_player(base: Dictionary, authenticated_profile: String) -> Dictionary:
	# Only the real newly confirmed join calls this. Resume never creates a bag.
	if not _binding_valid() or not _initialized or _busy: return _bad("INVENTORY_OWNER_NOT_AVAILABLE")
	_busy = true
	var candidate := _copy_core()
	if candidate == null:
		_busy = false
		return _bad("INVENTORY_OWNER_COPY_INVALID")
	var action: Dictionary = candidate.trusted_create_player(authenticated_profile)
	var result := _publish_checked(base, candidate, action)
	_busy = false
	return result

func apply_left(base: Dictionary, authenticated_profile: String, address: Variant, expected_revision: Variant, sequence: Variant, hot_context: Dictionary = {}) -> Dictionary:
	# No client can call this directly. Peer/epoch/incarnation and FIFO cutoffs
	# belong to the actual network owner, not a client-supplied profile field.
	if not _binding_valid() or not _initialized or _busy: return _bad("INVENTORY_OWNER_NOT_AVAILABLE")
	_busy = true
	var candidate := _copy_core()
	if candidate == null:
		_busy = false
		return _bad("INVENTORY_OWNER_COPY_INVALID")
	if address is Dictionary and address.get("container") is String and address.get("container") == "chest" and address.get("owner") is String and _access.get(authenticated_profile, {}).has(address["owner"]):
		var grant: Dictionary = candidate.trusted_set_chest_access(authenticated_profile, address["owner"], true)
		if not grant.get("ok", false):
			_busy = false
			return grant
	var action: Dictionary = candidate.click_slot(authenticated_profile, address, expected_revision, sequence)
	var result := _publish_checked(base, candidate, action, hot_context)
	_busy = false
	return result

func drop_requires_world(profile: String, kind: String, address: Variant, expected_revision: Variant, sequence: Variant) -> Dictionary:
	if not _binding_valid() or not _initialized or _busy: return _bad("INVENTORY_OWNER_NOT_AVAILABLE")
	var candidate := _copy_core()
	if candidate == null: return _bad("INVENTORY_OWNER_COPY_INVALID")
	for chest in _access.get(profile, {}): candidate.trusted_set_chest_access(profile, chest, true)
	var planned: Dictionary = DropPlan.prepare(candidate, profile, kind, address, expected_revision, sequence)
	return {"ok": true, "required": planned["drop"] != null} if planned.get("ok", false) else planned

func apply_drop(base: Dictionary, profile: String, kind: String, address: Variant, expected_revision: Variant, sequence: Variant, layer: Dictionary, origin: Vector2, landing: Vector2, now: float, hot_context: Dictionary = {}) -> Dictionary:
	if not _binding_valid() or not _initialized or _busy: return _bad("INVENTORY_OWNER_NOT_AVAILABLE")
	_busy = true
	var candidate := _copy_core()
	if candidate == null:
		_busy = false
		return _bad("INVENTORY_OWNER_COPY_INVALID")
	for chest in _access.get(profile, {}): candidate.trusted_set_chest_access(profile, chest, true)
	var planned: Dictionary = Ground.prepare_drop(candidate, profile, kind, address, expected_revision, sequence, layer, origin, landing, now)
	if not planned.get("ok", false):
		_busy = false
		return planned
	var restored: Dictionary = candidate.trusted_restore(planned["state"])
	var result := _publish_checked(base, candidate, planned if restored.get("ok", false) else restored, hot_context)
	_busy = false
	return result

func advance_ground(base: Dictionary, now: float, pickup_range: float, pickup_speed: float, hot_context: Dictionary = {}) -> Dictionary:
	if not _binding_valid() or not _initialized or _busy: return _bad("INVENTORY_OWNER_NOT_AVAILABLE")
	_busy = true
	var candidate := _copy_core()
	if candidate == null:
		_busy = false
		return _bad("INVENTORY_OWNER_COPY_INVALID")
	var original: Dictionary = candidate.snapshot()
	var original_token: String = Core._exact(original)
	var delta: float = maxf(0.0, now - float(original.get("ground_clock", now)))
	var planned: Dictionary = Ground.advance(candidate, now)
	if not planned.get("ok", false):
		_busy = false
		return planned
	var restored: Dictionary = candidate.trusted_restore(planned["state"])
	if not restored.get("ok", false):
		_busy = false
		return restored
	var active: Dictionary = {}
	var players: Dictionary = _authority.public_snapshot()["players"]
	for profile in players:
		var actor_id: String = players[profile]["player_instance_id"]
		if not base["actor_component"]["actors"].has(actor_id):
			_busy = false
			return _bad("GROUND_PICKUP_ACTOR_MISSING")
		var actor: Dictionary = base["actor_component"]["actors"][actor_id]
		active[profile] = {"layer": actor["layer"].duplicate(true), "position": actor["position"].duplicate()}
	# Values are source-pinned by actor_settings; current exact approved values.
	var picked: Dictionary = Ground.pickup(candidate, active, delta, pickup_range, pickup_speed)
	if not picked.get("ok", false):
		_busy = false
		return picked
	restored = candidate.trusted_restore(picked["state"])
	picked["source_token"] = original_token
	var result := _publish_checked(base, candidate, picked if restored.get("ok", false) else restored, hot_context)
	_busy = false
	return result


func trusted_set_access(profile: String, chest: String, allowed: bool) -> Dictionary:
	# The real owner must establish current actor, range, layer and F context.
	if not _binding_valid() or not _initialized or _busy: return _bad("INVENTORY_OWNER_NOT_AVAILABLE")
	var state: Dictionary = _core.snapshot()
	if not state["players"].has(profile) or not state["chests"].has(chest): return _bad("INVENTORY_ACCESS_SCOPE_INVALID")
	if not _access.has(profile): _access[profile] = {}
	if allowed: _access[profile][chest] = true
	else: _access[profile].erase(chest)
	return {"ok": true}

func close_view(profile: String) -> Dictionary:
	if not _binding_valid() or not _initialized or _busy or not _core.snapshot()["players"].has(profile): return _bad("INVENTORY_PLAYER_UNKNOWN")
	_access.erase(profile)
	return {"ok": true, "revision": revision()}

func view_for(profile: String, view_sequence: int) -> Dictionary:
	if not _binding_valid() or not _initialized or view_sequence < 0 or view_sequence > Core.MAX_SEQUENCE: return {}
	var projection := _copy_core()
	if projection == null: return {}
	for chest in _access.get(profile, {}):
		if not projection.trusted_set_chest_access(profile, chest, true).get("ok", false): return {}
	return View.server_view(projection, profile, view_sequence)

func _copy_core() -> RefCounted:
	var candidate := Core.new(_world_id)
	return candidate if candidate.trusted_restore(_core.snapshot()).get("ok", false) else null

func _publish_checked(base: Dictionary, candidate: RefCounted, action: Dictionary, hot_context: Dictionary = {}) -> Dictionary:
	if not action.get("ok", false): return action
	if action.has("source_token") and action["source_token"] != Core._exact(_core.snapshot()): return _bad("INVENTORY_WHOLE_STATE_STALE")
	# Reject a locally valid inventory if the actual combined snapshot would not
	# fit or would mismatch world/profile/actor/terrain. No partial publication.
	var checked: Dictionary = _contract.combine(base, candidate.snapshot()) if hot_context.is_empty() else _hot_boundary.validate(base, candidate.snapshot(), self, hot_context)
	if not checked.get("ok", false): return checked
	_core = candidate
	var result: Dictionary = action.duplicate(true)
	result["authoritative"] = true
	result["published"] = true
	result["durable"] = false
	return result

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}
