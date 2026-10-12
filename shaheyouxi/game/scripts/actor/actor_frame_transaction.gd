extends RefCounted
## Confirmed Frame core and sole actual owner Store writer/receipt authority.
## Internal FIFO envelopes -> fresh actions/transfers -> exactly one normal tick
## -> sealed expected-state proof -> next-physics confirmation/publication.
const Motion = preload("res://scripts/actor/actor_motion.gd")
const JoinPlacement = preload("res://scripts/actor/actor_join_placement_selector.gd")
const State = preload("res://scripts/actor/actor_state.gd")
const Command = preload("res://scripts/actor/actor_command.gd")
const Selector = preload("res://scripts/actor/actor_interaction_selector.gd")
const SourceLease = preload("res://scripts/actor/actor_frozen_source_lease.gd")
const Solver = preload("res://scripts/actor/actor_joint_solver.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const TerrainSession = preload("res://scripts/actor/actor_terrain_session_state.gd")
const ActorSession = preload("res://scripts/actor/actor_session_state.gd")
const Store = preload("res://scripts/terrain/required_entry_terrain_store.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const SaveScript = preload("res://scripts/save/save_store.gd")
const TreeInventoryOwner = preload("res://scripts/harvest/tree_inventory_owner012.gd")
const InventoryProfiles = preload("res://scripts/inventory/inventory_save_profiles012.gd")
const ThrowQuery = preload("res://scripts/inventory/inventory_throw_query012.gd")
const InventoryOwner = preload("res://scripts/inventory/inventory_owner012.gd")
const GroundHot = preload("res://scripts/harvest/tree_ground_hot012.gd")
const GroundBudget = preload("res://scripts/harvest/tree_ground_budget012.gd")
const GroundCore = preload("res://scripts/inventory/inventory_core012.gd")
const MAX_ENVELOPES := 64 # Technical per-frame work bound, not an F rate/cooldown.
const MAX_ENVELOPE_BYTES := 4096
const MAX_BATCH_BYTES := 65536
const ENVELOPE_FIELDS := ["peer_id", "actor_id", "input_generation", "server_epoch", "world_id", "request"]
var _authority: RefCounted
var _world: RefCounted
var _model: RefCounted
var _space: RefCounted
var _source_lease: RefCounted
var _inputs: RefCounted
var _half: float = 0.0
var _range: float = 0.0
var _generation: int = 0
var _last_submit_frame: int = -1
var _sealed: Dictionary = {}
var _initial_attempted: bool = false
var _initial_closed: bool = false
var _initial_boundary: Dictionary = {}
var _bootstrap_presence: Dictionary = {}
var _save_binding: Dictionary = {}
var _owner_profile_binding: Dictionary = {}
var _inventory_lineage: String = ""
var _tree_pending: Dictionary = {}
# Actual synchronous Frame transaction state, never supplied by a client/service.
var _ground_pending: Dictionary = {}
var _ground_certificate: Dictionary = {}
var _ground_cached_bundle: Dictionary = {}
var _ground_provisional: Dictionary = {}
var _ground_hot: RefCounted = GroundHot.new()
var _ground_invalidated: bool = false
var _ground_full_checks: int = 0
var _ground_hot_checks: int = 0
var _save_serial: int = 0
var _lineage: Dictionary = {}
var _last_snapshot: Dictionary = {}
var _last_state: Dictionary = {}
var _validation_calls: int = 0
var _validation_usec: int = 0
var _tick_committed: bool = false
var fatal_error: String = ""

func _init(authority: RefCounted, world: RefCounted, model: RefCounted, space: RefCounted, inputs: RefCounted) -> void:
	_authority = authority
	_world = world
	_model = model
	_space = space
	_inputs = inputs
	# Core geometry is derived only after successful frozen-source validation.

func prepare_frozen_sources(save_owner: Object = null) -> Dictionary:
	if not _ground_pending.is_empty(): return _reject("TREE_GROUND_SYNCHRONOUS_PENDING")
	# Never silently reconstruct a failed, replaced or released source lease.
	if _initial_closed:
		return _reject("FRAME_INITIAL_BOUNDARY_CLOSED")
	if _source_lease != null:
		if save_owner != null and not _source_lease.matches_save_owner(save_owner):
			return _reject("FRAME_SOURCE_SAVE_OWNER_BINDING_CHANGED")
		var inventory_guard := _owner_inventory_guard()
		return _source_lease.guard() if inventory_guard.get("ok", false) else inventory_guard
	if not _sealed.is_empty() or not _lineage.is_empty() or not fatal_error.is_empty():
		return _reject("FRAME_SOURCE_PREPARATION_NOT_ALLOWED")
	_source_lease = SourceLease.new()
	var prepared: Dictionary = _source_lease.prepare(_authority, _world, _model, _space, _inputs, save_owner)
	if prepared.get("ok", false):
		# Construction and explicit preparation can be separated. Derive the core
		# geometry only from the now-validated immutable inputs, never a stale cache.
		_half = _inputs.parameter("actor_diameter_cells") / 2.0
		_range = _inputs.parameter("interaction_range_cells")
		if save_owner != null:
			var profile: Dictionary = save_owner._freeze_save_profile()
			if not profile.get("ok", false):
				return profile
			_owner_profile_binding = {"profile": save_owner._save_profile}
			if save_owner._save_profile in [5,6]:
				if not save_owner._inventory_service_ready():
					return _reject("INVENTORY_CONFIRMED_OWNER_NOT_READY")
				_owner_profile_binding["registry"] = weakref(save_owner._inventory_registry)
				_owner_profile_binding["validator"] = weakref(save_owner._inventory_registry.validator_for(save_owner._save_profile))
				_owner_profile_binding["inventory"] = weakref(save_owner._inventory_owner)
				_owner_profile_binding["registry_config"] = save_owner._inventory_registry.descriptor(save_owner._save_profile)
				_inventory_lineage = save_owner._inventory_owner.boundary_token()
				if _inventory_lineage.is_empty():
					return _reject("INVENTORY_CONFIRMED_BOUNDARY_INVALID")
			_owner_profile_binding.make_read_only()
	return prepared

func _owner_inventory_guard(compare_token: bool = true) -> Dictionary:
	var owner: Object = _source_lease.bound_save_owner() if _source_lease != null else null
	if owner == null:
		return {"ok": true} if _owner_profile_binding.is_empty() else _reject("INVENTORY_SAVE_OWNER_LOST")
	if _owner_profile_binding.is_empty() or not owner._save_profile_valid() or owner._save_profile != _owner_profile_binding["profile"]:
		return _reject("INVENTORY_SAVE_PROFILE_CHANGED")
	if owner._save_profile == 4:
		return {"ok": true}
	if not owner._inventory_service_ready() or _owner_profile_binding["registry"].get_ref() != owner._inventory_registry or _owner_profile_binding["validator"].get_ref() != owner._inventory_registry.validator_for(owner._save_profile) or _owner_profile_binding["inventory"].get_ref() != owner._inventory_owner or owner._inventory_registry.get_script() != InventoryProfiles or owner._inventory_owner.get_script() != (TreeInventoryOwner if owner._save_profile == 6 else InventoryOwner) or owner._inventory_registry.descriptor(owner._save_profile) != _owner_profile_binding["registry_config"]:
		return _reject("INVENTORY_SAVE_OWNER_BINDING_CHANGED")
	var token: String = owner._inventory_owner.boundary_token()
	if token.is_empty() or (compare_token and token != _inventory_lineage):
		return _reject("INVENTORY_CONFIRMED_LINEAGE_CHANGED")
	return {"ok": true, "token": token}

func _inventory_terrain_base(owner: Object) -> Dictionary:
	return owner._terrain_session.combine(_last_state, owner._terrain_component)

func _inventory_transaction_base(owner: Object) -> Dictionary:
	# Only after _publication_gate. Static roots retain the exact readonly lease
	# identity; HotBoundary rechecks dynamic lineage before atomic publication.
	var base: Dictionary = _last_state.duplicate(false)
	base["terrain_component"] = owner._terrain_component
	return {"ok":true,"state":base}

func _confirm_inventory_presence(is_new: bool, profile_id: String) -> Dictionary:
	var owner: Object = _source_lease.bound_save_owner()
	if owner == null or owner._save_profile == 4:
		return {"ok": true}
	var guarded := _owner_inventory_guard()
	if not guarded.get("ok", false):
		return _fatal("INVENTORY_JOIN_OWNER_CHANGED")
	var base := _inventory_terrain_base(owner)
	if not base.get("ok", false):
		return _fatal("INVENTORY_JOIN_BASE_INVALID")
	# is_new comes only from the confirmed Authority identity ticket. A resume
	# never invokes creation; complete profile equality rejects a missing bag.
	var result: Dictionary = owner._inventory_owner.prepare_new_player(base["state"], profile_id) if is_new else owner._inventory_owner.combine_for_save(base["state"])
	var after := _owner_inventory_guard(false)
	var actual: Dictionary = _source_lease.dynamic_boundary()
	if not result.get("ok", false) or not after.get("ok", false) or not actual.get("ok", false) or actual["boundary"] != _lineage:
		return _fatal("INVENTORY_JOIN_CONFIRMATION_FAILED")
	_inventory_lineage = after["token"]
	return {"ok": true}

func apply_confirmed_inventory_left(owner: Object, authenticated_profile: String, address: Variant, expected_revision: Variant, sequence: Variant) -> Dictionary:
	# Internal synchronous mutation boundary. The network queue owns transport
	# authorization; this method admits only a currently active confirmed profile.
	var gate := _publication_gate()
	if not gate.get("ok", false):
		return gate
	if owner == null or owner != _source_lease.bound_save_owner() or owner._save_profile not in [5,6] or owner._mode not in ["server", "host"] or owner._closing or owner._fatal_shutdown or not owner._live_failure_code.is_empty() or not owner._physics_runtime_ready or not owner._inventory_service_ready():
		return _reject("INVENTORY_CONFIRMED_OWNER_NOT_READY")
	var players: Dictionary = _authority.public_snapshot()["players"]
	if not players.has(authenticated_profile) or not players[authenticated_profile]["player_instance_id"] in _model.active_actor_ids():
		return _reject("INVENTORY_CONFIRMED_PROFILE_INACTIVE")
	var base := _inventory_transaction_base(owner)
	if not base.get("ok", false):
		return _fatal("INVENTORY_CONFIRMED_BASE_INVALID")
	var result: Dictionary = owner._inventory_owner.apply_left(base["state"], authenticated_profile, address, expected_revision, sequence, {"frame":self,"lease":_source_lease})
	var after := _owner_inventory_guard(false)
	var actual: Dictionary = _source_lease.dynamic_boundary()
	if not after.get("ok", false) or not actual.get("ok", false) or actual["boundary"] != _lineage or (not result.get("ok", false) and after["token"] != _inventory_lineage):
		return _fatal("INVENTORY_ACTION_POSTCONDITION")
	_inventory_lineage = after["token"]
	# Authoritative in memory only. save_confirmed_owner owns durable receipts.
	return result

func apply_confirmed_inventory_drop(owner: Object, profile: String, kind: String, address: Variant, expected_revision: Variant, sequence: Variant, aim: Vector2) -> Dictionary:
	return _apply_confirmed_ground(owner, profile, kind, address, expected_revision, sequence, aim, false)

func advance_confirmed_ground(owner: Object) -> Dictionary:
	return _apply_confirmed_ground(owner, "", "", {}, -1, -1, Vector2.ZERO, true)

func _apply_confirmed_ground(owner: Object, profile: String, kind: String, address: Variant, expected_revision: Variant, sequence: Variant, aim: Vector2, advancing: bool) -> Dictionary:
	var gate := _publication_gate()
	if not gate.get("ok", false): return gate
	if owner == null or owner != _source_lease.bound_save_owner() or owner._save_profile not in [5,6] or owner._mode not in ["server", "host"] or owner._closing or owner._fatal_shutdown or not owner._live_failure_code.is_empty() or not owner._physics_runtime_ready or not owner._inventory_service_ready(): return _reject("INVENTORY_CONFIRMED_OWNER_NOT_READY")
	var base := _inventory_transaction_base(owner)
	if not base.get("ok", false): return _fatal("INVENTORY_CONFIRMED_BASE_INVALID")
	var result: Dictionary
	var ground_proof: Dictionary = {}
	if advancing:
		var context: Dictionary = {"frame":self,"lease":_source_lease}
		if owner._save_profile == 6:
			if _ground_invalidated: return _reject("TREE_GROUND_RUNTIME_INVALIDATED")
			if not _ground_pending.is_empty() or not _ground_provisional.is_empty(): return _reject("TREE_GROUND_REENTRANT")
			if not _ground_hot is RefCounted or _ground_hot.get_script() != GroundHot: return _ground_identity_failure("TREE_GROUND_HELPER_IDENTITY")
			if owner == null or owner != _source_lease.bound_save_owner() or owner._bootstrap_frame != self or owner._save_profile != 6 or owner._inventory_owner.get_script() != TreeInventoryOwner: return _reject("TREE_GROUND_OWNER_IDENTITY")
			var service: RefCounted = owner._inventory_owner
			var exact: String = _ground_base_exact(base["state"])
			if exact.is_empty() or not service._bundle.is_read_only() or service._busy: return _reject("TREE_GROUND_SOURCE_BUNDLE")
			# Cross-check BOTH retained sides before any legitimate cache eviction.
			# Clearing one field cannot impersonate a first call or a new business root.
			if not _ground_certificate.is_empty() or not _ground_cached_bundle.is_empty() or not _ground_hot._bound_certificate.is_empty():
				if not GroundCore._fields(_ground_certificate, ["nodes","config","world","terrain","metrics","published_bundle"]) or not _ground_hot.certificate_matches(self, _ground_certificate) or not is_same(_ground_cached_bundle, _ground_certificate["published_bundle"]): return _ground_identity_failure("TREE_GROUND_CERTIFICATE_ASSOCIATION_CHANGED")
			# A different business transaction never inherits a ground-only certificate.
			if not is_same(_ground_cached_bundle, service._bundle): _clear_ground_certificate()
			var ticket := RefCounted.new()
			_ground_pending = {"ticket": ticket, "phase": "issued", "owner": weakref(owner),
				"service": weakref(service), "lease": weakref(_source_lease),
				"physics_frame": Engine.get_physics_frames(), "bundle": service._bundle,
				"core": weakref(service._core), "trees": weakref(service._trees),
				"source_token": _inventory_lineage, "base_exact": exact,
				"world": base["state"]["world_component"], "terrain": base["state"]["terrain_component"],
				"now": _authority.world_seconds, "pickup_range": _inputs.parameter("pickup_range_cells"),
				"pickup_speed": _inputs.parameter("pickup_attraction_speed_cells_per_second")}
			_ground_pending.make_read_only()
			context["ground_ticket"] = ticket
		result = owner._inventory_owner.advance_ground(base["state"], _authority.world_seconds, _inputs.parameter("pickup_range_cells"), _inputs.parameter("pickup_attraction_speed_cells_per_second"), context)
		if owner._save_profile == 6:
			# Retire even an unconsumed ticket when planning failed early. The service
			# has cleared busy before this return; ordinary postconditions stay full.
			ground_proof = _ground_provisional
			_ground_pending = {}
			_ground_provisional = {}
			if not result.get("ok", false): _clear_ground_certificate()
	else:
		var players: Dictionary = _authority.public_snapshot()["players"]
		if not players.has(profile) or not players[profile]["player_instance_id"] in _model.active_actor_ids(): return _reject("INVENTORY_CONFIRMED_PROFILE_INACTIVE")
		var actor_id: String = players[profile]["player_instance_id"]
		var actor: Dictionary = _model.persistent_state()["actors"][actor_id]
		var origin: Vector2 = State.vector(actor["position"])
		var needed: Dictionary = owner._inventory_owner.drop_requires_world(profile, kind, address, expected_revision, sequence)
		if not needed.get("ok", false): return needed
		var target: Dictionary = ThrowQuery.landing(_space, actor["layer"], origin, aim, _inputs.parameter("throw_distance_cells")) if needed["required"] else {"ok": true, "landing": origin}
		if not target.get("ok", false): return target
		result = owner._inventory_owner.apply_drop(base["state"], profile, kind, address, expected_revision, sequence, actor["layer"], origin, target["landing"], _authority.world_seconds, {"frame":self,"lease":_source_lease})
	var after := _owner_inventory_guard(false)
	var actual: Dictionary = _source_lease.dynamic_boundary()
	if not after.get("ok", false) or not actual.get("ok", false) or actual["boundary"] != _lineage or (not result.get("ok", false) and after["token"] != _inventory_lineage): return _fatal("INVENTORY_ACTION_POSTCONDITION")
	_inventory_lineage = after["token"]
	if advancing and owner._save_profile == 6 and result.get("ok", false):
		if ground_proof.is_empty() or not ground_proof.is_read_only(): return _fatal("TREE_GROUND_POSTCONDITION_PROOF_MISSING")
		var promoted: Dictionary = ground_proof.duplicate(false)
		promoted["published_bundle"] = owner._inventory_owner._bundle
		promoted.make_read_only()
		_ground_certificate = promoted
		_ground_cached_bundle = owner._inventory_owner._bundle
		if not _ground_hot.bind_certificate(self, _ground_certificate): return _fatal("TREE_GROUND_POSTCONDITION_BIND_FAILED")
	return result


# Capability lifecycle: issue -> consume before validation -> single service CAS
# -> retire -> original Frame postcondition -> promote a provisional certificate.
# No await, callback, caller metric installation, or general busy bypass exists.
func _ground_ticket_state(ticket: Variant, phase: String) -> Dictionary:
	# Only identity inspection here: native/lease call this while checking the
	# dedicated boundary, so recursively calling them here would be incorrect.
	if not GroundCore._fields(_ground_pending, ["ticket","phase","owner","service","lease","physics_frame","bundle","core","trees","source_token","base_exact","world","terrain","now","pickup_range","pickup_speed"]) or not _ground_pending.is_read_only() or not ticket is RefCounted or not is_same(ticket, _ground_pending["ticket"]) or _ground_pending["phase"] != phase:
		return _reject("TREE_GROUND_TICKET_OR_PHASE")
	if not fatal_error.is_empty() or not _tree_pending.is_empty() or not _sealed.is_empty() or not _initial_boundary.is_empty() or not _bootstrap_presence.is_empty() or _initial_closed or _ground_pending["physics_frame"] != Engine.get_physics_frames(): return _reject("TREE_GROUND_TICKET_EXPIRED")
	for field in ["owner", "service", "lease", "core", "trees"]:
		if not _ground_pending[field] is WeakRef or _ground_pending[field].get_ref() == null: return _reject("TREE_GROUND_TICKET_OBJECT_LOST")
	var owner: Object = _ground_pending["owner"].get_ref()
	var service_value: Variant = _ground_pending["service"].get_ref()
	if not service_value is RefCounted: return _reject("TREE_GROUND_TICKET_SERVICE_TYPE")
	var service: RefCounted = service_value
	if _source_lease == null or _source_lease.get_script() != SourceLease or not is_same(_ground_pending["lease"].get_ref(), _source_lease): return _reject("TREE_GROUND_TICKET_LEASE")
	if owner.get_script() != load("res://scripts/actor/actor_terrain_network_main.gd") or owner._bootstrap_frame != self or owner._inventory_owner != service or service.get_script() != TreeInventoryOwner or not service._busy or not service._initialized or not service._completion_reservation.is_empty(): return _reject("TREE_GROUND_TICKET_OWNER_PHASE")
	if not is_same(service._bundle, _ground_pending["bundle"]) or not is_same(service._core, _ground_pending["core"].get_ref()) or not is_same(service._trees, _ground_pending["trees"].get_ref()) or service.boundary_token() != _ground_pending["source_token"] or _inventory_lineage != _ground_pending["source_token"]: return _reject("TREE_GROUND_TICKET_SOURCE_CHANGED")
	return {"ok": true, "owner": owner, "service": service}

func _validate_tree_ground_candidate(service: Variant, base: Dictionary, candidate: Variant, ticket: Variant, now: float, pickup_range: float, pickup_speed: float) -> Dictionary:
	var current: Dictionary = _ground_ticket_state(ticket, "issued")
	if not current.get("ok", false):
		if not _ground_pending.is_empty() and is_same(_ground_pending.get("ticket"), ticket): return _ground_identity_failure(str(current.get("code", "TREE_GROUND_TICKET_INVALID")))
		return current
	# Consume BEFORE inspecting caller candidate/configuration. Every outcome is
	# retired by the sole issuing callsite, including early planner rejection.
	var consumed: Dictionary = _ground_pending.duplicate(false)
	consumed["phase"] = "validating"
	consumed.make_read_only()
	_ground_pending = consumed
	if not is_same(service, current["service"]) or not candidate is RefCounted or candidate.get_script() != GroundCore or not candidate.ready or is_same(candidate, service._core): return _ground_identity_failure("TREE_GROUND_CANDIDATE_IDENTITY")
	if not is_same(now, _ground_pending["now"]) or not is_same(pickup_range, _ground_pending["pickup_range"]) or not is_same(pickup_speed, _ground_pending["pickup_speed"]) or not is_same(now, _authority.world_seconds) or not is_same(pickup_range, _inputs.parameter("pickup_range_cells")) or not is_same(pickup_speed, _inputs.parameter("pickup_attraction_speed_cells_per_second")): return _ground_identity_failure("TREE_GROUND_CALLER_PARAMETERS")
	var boundary: Dictionary = _ground_validation_boundary(ticket, base)
	if not boundary.get("ok", false): return _ground_identity_failure(str(boundary.get("code", "TREE_GROUND_BOUNDARY_FAILED")))
	var context: Dictionary = _ground_hot.runtime_sources(self, service, base, candidate)
	if not context.get("ok", false): return _ground_identity_failure(str(context.get("code", "TREE_GROUND_SOURCE_IDENTITY")))
	if not _ground_certificate.is_empty() and not _ground_certificate_matches(context):
		return _ground_identity_failure("TREE_GROUND_CERTIFICATE_IDENTITY_CHANGED")
	if not _ground_certificate.is_empty():
		var quick: Dictionary = _ground_hot.validate_dynamic_and_budget(context, base, candidate.snapshot(), service.tree_snapshot(), _ground_certificate["metrics"])
		if quick.get("ok", false):
			_ground_hot_checks += 1
			_ground_provisional = _ground_certificate
			boundary = _ground_validation_boundary(ticket, base)
			return boundary if boundary.get("ok", false) else _ground_identity_failure(str(boundary.get("code", "TREE_GROUND_BOUNDARY_FAILED")))
		if quick.get("failure_kind") != "semantic": return _ground_identity_failure(str(quick.get("code", "TREE_GROUND_DYNAMIC_IDENTITY")))
		# Original full path provides the original failure ordering. Identity or
		# native failures never become eligible by taking this semantic fallback.
		boundary = _ground_validation_boundary(ticket, base)
		if not boundary.get("ok", false): return _ground_identity_failure(str(boundary.get("code", "TREE_GROUND_BOUNDARY_FAILED")))
	_clear_ground_certificate()
	_ground_full_checks += 1
	var checked: Dictionary = service._combine_for_publication(base, candidate, service._trees)
	if not checked.get("ok", false): return checked
	boundary = _ground_validation_boundary(ticket, base)
	if not boundary.get("ok", false): return _ground_identity_failure(str(boundary.get("code", "TREE_GROUND_BOUNDARY_FAILED")))
	var after: Dictionary = _ground_hot.runtime_sources(self, service, base, candidate)
	if not after.get("ok", false) or not _ground_context_same(context, after): return _ground_identity_failure("TREE_GROUND_FULL_PROOF_SOURCE_CHANGED")
	# Only THIS actual Frame computes metrics from its proven readonly roots.
	var metrics: Dictionary = GroundBudget.static_measure(context["world"], context["terrain"])
	if not metrics.get("ok", false): return metrics
	_ground_provisional = _ground_capture_certificate(context, metrics)
	return {"ok": true}

func _ground_validation_boundary(ticket: Variant, base: Dictionary) -> Dictionary:
	var current: Dictionary = _ground_ticket_state(ticket, "validating")
	if not current.get("ok", false): return current
	if _ground_base_exact(base) != _ground_pending["base_exact"] or not is_same(base.get("world_component"), _ground_pending["world"]) or not is_same(base.get("terrain_component"), _ground_pending["terrain"]): return _reject("TREE_GROUND_BASE_CHANGED")
	var checked: Dictionary = _source_lease.ground_boundary(self, ticket)
	if not checked.get("ok", false): return checked
	if checked["boundary"] != _lineage: return _reject("TREE_GROUND_DYNAMIC_LINEAGE_CHANGED")
	var actual: Dictionary = checked["boundary"]["authority"].duplicate(false)
	actual["actor_component"] = checked["boundary"]["model"]
	var supplied: Dictionary = base.duplicate(false)
	supplied.erase("world_component")
	supplied.erase("terrain_component")
	var exact: String = _ground_exact(actual)
	if exact.is_empty() or exact != _ground_exact(supplied): return _reject("TREE_GROUND_AUTHORITY_BASE_MISMATCH")
	return {"ok": true}

func _ground_capture_certificate(context: Dictionary, metrics: Dictionary) -> Dictionary:
	var nodes: Dictionary = {}
	for key in context["nodes"]:
		var object: Object = context["nodes"][key]
		var record: Dictionary = {"object": weakref(object), "script": object.get_script()}
		record.make_read_only()
		nodes[key] = record
	nodes.make_read_only()
	var proof: Dictionary = {"nodes": nodes, "config": _ground_exact(context["config"]), "world": context["world"], "terrain": context["terrain"], "metrics": metrics}
	proof.make_read_only()
	return proof

func _ground_certificate_matches(context: Dictionary) -> bool:
	if not GroundCore._fields(_ground_certificate, ["nodes","config","world","terrain","metrics","published_bundle"]) or not _ground_certificate.is_read_only() or not _ground_hot.certificate_matches(self, _ground_certificate): return false
	if not is_same(_ground_cached_bundle, _ground_pending["bundle"]) or not is_same(_ground_certificate["world"], context["world"]) or not is_same(_ground_certificate["terrain"], context["terrain"]) or _ground_certificate["config"] != _ground_exact(context["config"]): return false
	var nodes: Variant = _ground_certificate["nodes"]
	if not nodes is Dictionary or not nodes.is_read_only() or nodes.size() != context["nodes"].size(): return false
	for key in context["nodes"]:
		if not nodes.has(key) or not GroundCore._fields(nodes[key], ["object","script"]) or not nodes[key].is_read_only() or not nodes[key]["object"] is WeakRef: return false
		var actual: Object = context["nodes"][key]
		if not is_same(nodes[key]["object"].get_ref(), actual) or nodes[key]["script"] != actual.get_script(): return false
	return true

func _ground_context_same(a: Dictionary, b: Dictionary) -> bool:
	if not is_same(a["world"], b["world"]) or not is_same(a["terrain"], b["terrain"]) or _ground_exact(a["config"]) != _ground_exact(b["config"]) or a["nodes"].size() != b["nodes"].size(): return false
	for key in a["nodes"]:
		if not b["nodes"].has(key) or not is_same(a["nodes"][key], b["nodes"][key]): return false
	return true

func _ground_base_exact(base: Dictionary) -> String:
	var dynamic: Dictionary = base.duplicate(false)
	dynamic.erase("world_component")
	dynamic.erase("terrain_component")
	return _ground_exact(dynamic)

func _ground_exact(value: Variant) -> String:
	var encoded: Dictionary = Codec.encode(value)
	return JSON.stringify(encoded["value"], "", true, true) if encoded.get("ok", false) else ""

func _ground_identity_failure(code: String) -> Dictionary:
	_ground_invalidated = true
	_clear_ground_certificate()
	return _reject(code)

func _clear_ground_certificate() -> void:
	_ground_certificate = {}
	_ground_cached_bundle = {}
	if _ground_hot is RefCounted and _ground_hot.get_script() == GroundHot: _ground_hot.clear_certificate()

func _clear_ground_transaction() -> void:
	_ground_pending = {}
	_ground_provisional = {}
	_clear_ground_certificate()

# Technical completion fixture seam only. No gameplay hit timing is invented.
# Future harvesting must supply its authenticated, accumulated completion proof
# before exposing a non-fixture entry point. Network request kinds are unchanged.
func prepare_fixture_tree_completion(owner: Object, peer_id: int, tree_id: String, event_id: String) -> Dictionary:
	var gate:=_publication_gate()
	if not gate.get("ok",false): return gate
	if owner==null or owner!=_source_lease.bound_save_owner() or owner._bootstrap_frame!=self or owner._save_profile!=6 or owner._arguments.get("test_entry")!="true" or owner._arguments.get("tree_fixture_profile")!="isolated" or owner._mode not in ["server","host"] or owner._closing or owner._fatal_shutdown or not owner._live_failure_code.is_empty() or not owner._inventory_service_ready() or _space.get_script()!=load("res://scripts/harvest/tree_terrain_space012.gd"): return _reject("TREE_COMPLETION_FIXTURE_ONLY")
	var actor_id:=_actor_for_peer(peer_id)
	if actor_id.is_empty() or not actor_id in _model.active_actor_ids() or not _authority._peer_profiles.has(peer_id): return _reject("TREE_COMPLETION_ACTOR_BINDING")
	var profile: String=_authority._peer_profiles[peer_id]
	var service: RefCounted=owner._inventory_owner
	var trees: Dictionary=service.tree_snapshot()
	if not trees["trees"].has(tree_id): return _reject("TREE_COMPLETION_UNKNOWN")
	var tree: Dictionary=trees["trees"][tree_id]
	var actor: Dictionary=_model.persistent_state()["actors"][actor_id]
	var center:=Vector2(float(tree["cell"][0])+0.5,float(tree["cell"][1])+0.5)
	var maximum: float=service._trees._definition._rules["harvest"]["maximum_distance_cells"]
	if actor["layer"]!=tree["layer"] or State.vector(actor["position"]).distance_to(center)>maximum: return _reject("TREE_COMPLETION_RANGE_OR_LAYER")
	var base:=_inventory_terrain_base(owner)
	if not base.get("ok",false): return base
	var prepared: Dictionary=service.plan_fixture_completion(base["state"],tree_id,event_id,profile,_inventory_lineage)
	if not prepared.get("ok",false): return prepared
	if prepared["plan"]["replay"]:
		return {"ok":true,"replay":true,"created_drop_ids":[],"completion":trees["completions"][event_id].duplicate(true),"fixture_only":true,"durable":false}
	_tick_committed=false
	var ticket:=RefCounted.new()
	_tree_pending={"ticket":ticket,"service":service,"phase":"preparing","bundle":_inventory_lineage,"boundary":_lineage.duplicate(true),"runtime":_authority_runtime(),"prepared":prepared,"native_ticket":null}
	_tree_pending.make_read_only()
	var reserved: Dictionary=service.reserve_fixture_completion(self,prepared)
	if not reserved.get("ok",false):
		_tree_pending={}
		return reserved
	var started: Dictionary=_space._tree_native.begin_detachment(trees,prepared["tree_plan"])
	if not started.get("ok",false):
		_tree_phase("restored")
		var released: Dictionary=service.release_completion_reservation(self,false)
		if not released.get("ok",false): return _fatal("TREE_COMPLETION_PREPARE_RELEASE_FAILED")
		_tree_pending={}
		return started
	var pending: Dictionary=_tree_pending.duplicate(false)
	pending["native_ticket"]=started["ticket"]
	pending["phase"]="detached"
	pending.make_read_only()
	_tree_pending=pending
	return {"ok":true,"pending":true,"ticket":ticket,"fixture_only":true,"logical_published":false}

func _tree_phase(phase: String) -> void:
	var pending: Dictionary=_tree_pending.duplicate(false)
	pending["phase"]=phase
	pending.make_read_only()
	_tree_pending=pending

func _tree_pending_gate(ticket: Variant, phase: String) -> Dictionary:
	if not fatal_error.is_empty() or not ticket is RefCounted or _tree_pending.is_empty() or not _tree_pending.is_read_only() or not is_same(ticket,_tree_pending["ticket"]) or _tree_pending["phase"]!=phase: return _reject("TREE_COMPLETION_TICKET_OR_PHASE")
	var service: RefCounted=_tree_pending["service"]
	if not service._reserved_frame_matches(self) or service.boundary_token()!=_tree_pending["bundle"] or _authority_runtime()!=_tree_pending["runtime"] or _lineage!=_tree_pending["boundary"]: return _fatal("TREE_COMPLETION_LINEAGE_CHANGED")
	if _source_lease==null or not _source_lease.guard().get("ok",false): return _fatal("TREE_COMPLETION_SOURCE_LOST")
	var owner: Object=_source_lease.bound_save_owner()
	if owner==null or _space==null or _space.get_script()!=load("res://scripts/harvest/tree_terrain_space012.gd") or owner._actor_space!=_space: return _fatal("TREE_COMPLETION_SPACE_LOST")
	if _space._tree_native==null or _space._tree_native.get_script()!=load("res://scripts/harvest/tree_native012.gd") or not _space._tree_native._detachment_matches(_tree_pending["native_ticket"],phase): return _fatal("TREE_COMPLETION_NATIVE_TICKET_LOST")
	if Engine.get_physics_frames()<=_space._tree_native._detachment["physics_frame"]: return _pending("TREE_COMPLETION_AWAIT_PHYSICS")
	var actual: Dictionary=_source_lease.pending_tree_boundary(self,ticket)
	if not actual.get("ok",false): return _fatal(str(actual.get("code","TREE_COMPLETION_PENDING_NATIVE_INVALID")))
	return {"ok":true} if actual["boundary"]==_tree_pending["boundary"] else _fatal("TREE_COMPLETION_DYNAMIC_CHANGED")

func confirm_fixture_tree_completion(ticket: Variant) -> Dictionary:
	if not _ground_pending.is_empty(): return _reject("TREE_GROUND_SYNCHRONOUS_PENDING")
	var gate:=_tree_pending_gate(ticket,"detached")
	if not gate.get("ok",false): return gate
	var service: RefCounted=_tree_pending["service"]
	var prepared: Dictionary=_tree_pending["prepared"]
	var old_trees: Dictionary=service.tree_snapshot()
	var next_trees: Dictionary=prepared["tree_plan"]["state"]
	var native: RefCounted=_space._tree_native
	var checked: Dictionary=native.publication_ready(_tree_pending["native_ticket"],old_trees,next_trees)
	if not checked.get("ok",false): return _fatal("TREE_COMPLETION_PREPUBLICATION_NATIVE_FAILED")
	# The service revalidates the whole profile6 candidate and performs its CAS.
	# Native publication follows in this same synchronous stack, no user callbacks.
	var published: Dictionary=service.publish_reserved_completion(self)
	if not published.get("ok",false): return _fatal(str(published.get("code","TREE_COMPLETION_PREPUBLICATION_PLAN_FAILED")))
	checked=native.publish_detachment(_tree_pending["native_ticket"],old_trees,next_trees)
	if not checked.get("ok",false): return _fatal("TREE_COMPLETION_POSTPUBLICATION_NATIVE_FAILED")
	_tree_phase("published")
	checked=service.release_completion_reservation(self,true)
	if not checked.get("ok",false): return _fatal("TREE_COMPLETION_POSTPUBLICATION_RELEASE_FAILED")
	var binding:=_owner_inventory_guard(false)
	var actual: Dictionary=_source_lease.dynamic_boundary()
	if not binding.get("ok",false) or not actual.get("ok",false) or actual["boundary"]!=_lineage or _authority_runtime()!=_tree_pending["runtime"]: return _fatal("TREE_COMPLETION_POSTPUBLICATION_BOUNDARY_FAILED")
	_inventory_lineage=binding["token"]
	_tree_pending={}
	published["fixture_only"]=true
	published["replay"]=false
	return published

func begin_fixture_tree_rollback(ticket: Variant) -> Dictionary:
	if not _ground_pending.is_empty(): return _reject("TREE_GROUND_SYNCHRONOUS_PENDING")
	var gate:=_tree_pending_gate(ticket,"detached")
	if not gate.get("ok",false): return gate
	var checked: Dictionary=_space._tree_native.begin_rollback(_tree_pending["native_ticket"],_tree_pending["service"].tree_snapshot())
	if not checked.get("ok",false): return _fatal("TREE_COMPLETION_ROLLBACK_BEGIN_FAILED")
	_tree_phase("restoring")
	return {"ok":true,"pending":true,"ticket":ticket,"rollback_confirmed":false}

func confirm_fixture_tree_rollback(ticket: Variant) -> Dictionary:
	if not _ground_pending.is_empty(): return _reject("TREE_GROUND_SYNCHRONOUS_PENDING")
	var gate:=_tree_pending_gate(ticket,"restoring")
	if not gate.get("ok",false): return gate
	var service: RefCounted=_tree_pending["service"]
	var checked: Dictionary=_space._tree_native.confirm_rollback(_tree_pending["native_ticket"],service.tree_snapshot())
	if not checked.get("ok",false): return _fatal("TREE_COMPLETION_ROLLBACK_NATIVE_FAILED")
	_tree_phase("restored")
	checked=service.release_completion_reservation(self,false)
	if not checked.get("ok",false): return _fatal("TREE_COMPLETION_ROLLBACK_RELEASE_FAILED")
	var actual: Dictionary=_source_lease.dynamic_boundary()
	if not actual.get("ok",false) or actual["boundary"]!=_lineage or not _owner_inventory_guard().get("ok",false): return _fatal("TREE_COMPLETION_ROLLBACK_BOUNDARY_FAILED")
	_tree_pending={}
	return {"ok":true,"rollback_confirmed":true,"published":false}

func prepare_initial_boundary(save_owner: Object = null) -> Dictionary:
	if not _ground_pending.is_empty(): return _reject("TREE_GROUND_SYNCHRONOUS_PENDING")
	# The one startup baseline precedes host/remote activation. Restored inactive
	# profiles remain fully validated; this is not a general-purpose rebase API.
	if _initial_attempted or _initial_closed or _last_submit_frame >= 0 or not _sealed.is_empty() or not _lineage.is_empty() or not fatal_error.is_empty():
		return _reject("FRAME_INITIAL_BOUNDARY_NOT_ALLOWED")
	_initial_attempted = true
	if _authority == null or _model == null or _space == null or not _authority.active_peer_ids().is_empty() or not _model.active_actor_ids().is_empty() or not _space.active_actor_ids().is_empty():
		_initial_closed = true
		if _source_lease != null:
			_source_lease.release()
		return _reject("FRAME_INITIAL_BOUNDARY_REQUIRES_INACTIVE_RUNTIME")
	if _generation >= Motion.MAX_REVISION:
		_initial_closed = true
		if _source_lease != null:
			_source_lease.release()
		return _reject("FRAME_INITIAL_BOUNDARY_GENERATION_EXHAUSTED")
	var prepared := prepare_frozen_sources(save_owner)
	if not prepared.get("ok", false):
		_initial_closed = true
		if _source_lease != null:
			_source_lease.release()
		return prepared
	var checked := _validated_boundary()
	if not checked.get("ok", false):
		_initial_closed = true
		_source_lease.release()
		return checked
	_generation += 1
	var ticket := {"owner_id": get_instance_id(), "generation": _generation, "kind": "initial_boundary"}
	_initial_boundary = {"ticket": ticket.duplicate(true), "physics_frame": Engine.get_physics_frames(), "expected": checked["boundary"].duplicate(true)}
	return {"ok": false, "pending": true, "prepared": true, "initial_boundary": true, "confirmed": false, "save_ready": false, "delta_consumed": false, "ticket": ticket}

func confirm_initial_boundary(ticket: Variant) -> Dictionary:
	if not _ground_pending.is_empty(): return _reject("TREE_GROUND_SYNCHRONOUS_PENDING")
	if not fatal_error.is_empty():
		return _reject("FRAME_STOPPED", true)
	if not _matches_initial_boundary(ticket):
		return _reject("INVALID_INITIAL_BOUNDARY_TICKET")
	if Engine.get_physics_frames() <= _initial_boundary["physics_frame"]:
		return _pending("FRAME_INITIAL_PHYSICS_CONFIRMATION_PENDING")
	var checked := _validated_boundary()
	if not checked.get("ok", false) or checked["boundary"] != _initial_boundary["expected"]:
		return _fatal("FRAME_INITIAL_BOUNDARY_CHANGED")
	# Reuse the exact prepared proof, never adopt a freshly observed mutation.
	_lineage = _initial_boundary["expected"].duplicate(true)
	_cache_confirmed(_lineage)
	_initial_boundary.clear()
	_tick_committed = false
	return {"ok": true, "confirmed": true, "initial_boundary": true, "pending": false, "save_ready": true, "delta_consumed": false}

func cancel_initial_boundary(ticket: Variant) -> Dictionary:
	if not _ground_pending.is_empty(): return _reject("TREE_GROUND_SYNCHRONOUS_PENDING")
	if not fatal_error.is_empty():
		return _reject("FRAME_STOPPED", true)
	if not _matches_initial_boundary(ticket):
		return _reject("INVALID_INITIAL_BOUNDARY_TICKET")
	_initial_boundary.clear()
	_initial_closed = true
	_source_lease.release()
	# No model/native write occurred. The owner retains normal cleanup ownership.
	return {"ok": true, "cancelled": true, "initial_boundary": true, "pending": false, "save_ready": false, "delta_consumed": false}

func capture_envelope(peer_id: int, request: Variant) -> Dictionary:
	if not _ground_pending.is_empty(): return _reject("TREE_GROUND_SYNCHRONOUS_PENDING")
	# Owner calls this with its actual transport sender/local-host binding. No
	# identity/generation is taken from request or exposed as a new wire field.
	var actor_id := _actor_for_peer(peer_id)
	if actor_id.is_empty() or _model == null or not _model.ready or not actor_id in _model.active_actor_ids():
		return _reject("FRAME_PEER_NOT_JOINED")
	var checked := _command_check(request)
	if not checked.get("ok", false):
		return checked
	var cursor: Dictionary = _model.public_snapshot()["input_cursors"][actor_id]
	var envelope := {"peer_id": peer_id, "actor_id": actor_id, "input_generation": cursor["input_generation"], "server_epoch": _authority.server_epoch, "world_id": _authority.world_id, "request": request.duplicate(true)}
	var bounded := _envelope_check(envelope)
	return {"ok": true, "envelope": envelope} if bounded["ok"] else bounded

func _authority_runtime() -> Dictionary:
	return {"peers": _authority._peer_profiles.duplicate(true), "welcomes": _authority._welcome_cache.duplicate(true), "commands": _authority._command_cache.duplicate(true), "used_ids": _authority._used_ids.duplicate(true), "join_generation": _authority._join_generation}

func prepare_bootstrap_presence(peer_id: int, request: Variant, local_host: bool = false) -> Dictionary:
	if not _ground_pending.is_empty(): return _reject("TREE_GROUND_SYNCHRONOUS_PENDING")
	var gate := _publication_gate()
	if not gate.get("ok", false):
		return gate
	var owner: Object = _source_lease.bound_save_owner()
	if owner == null or owner._closing or owner._fatal_shutdown or owner._mode not in ["server", "host"] or peer_id < 1 or (local_host and (peer_id != 1 or owner._mode != "host")) or (not local_host and peer_id <= 1):
		return _reject("BOOTSTRAP_PEER_BINDING_INVALID")
	if not State.exact_fields(request, ["network_protocol_version", "catalogue_sha256", "display_name", "resume_profile_id", "resume_secret"]) or typeof(request["network_protocol_version"]) != TYPE_INT:
		return _reject("BOOTSTRAP_HELLO_INVALID")
	for field in ["catalogue_sha256", "display_name", "resume_profile_id", "resume_secret"]:
		if not request[field] is String or request[field].length() > 128:
			return _reject("BOOTSTRAP_HELLO_INVALID")
	if var_to_bytes(request).size() > MAX_ENVELOPE_BYTES or _generation >= Motion.MAX_REVISION:
		return _reject("BOOTSTRAP_REQUEST_OR_GENERATION_LIMIT")
	var before: Dictionary = _lineage.duplicate(true)
	var runtime_before := _authority_runtime()
	var identity: Dictionary = _authority.prepare_join(peer_id, request, local_host)
	if not identity.get("ok", false):
		return identity
	var identity_ticket: Dictionary = identity["ticket"]
	if identity["already_active"]:
		_authority.cancel_prepared_join(identity_ticket)
		return _reject("BOOTSTRAP_ALREADY_ACTIVE_UNSUPPORTED")
	var is_new: bool = identity["is_new"]
	var identity_effect: Dictionary = _authority.prepared_join_effect(identity_ticket)["effect"]
	var profile_id: String = identity["player_profile_id"]
	var actor_id: String = identity["player_instance_id"]
	var profile: Dictionary = identity_effect["profile"]
	var welcome: Dictionary = identity_effect["welcome"]
	var expected_ids := {profile_id: true, actor_id: true, welcome["resume_secret"]: true} if is_new else {}
	var expected_profile: Dictionary = {"player_profile_id": profile_id, "player_instance_id": actor_id, "display_name": request["display_name"], "role": "HOST" if local_host else "MEMBER", "secret_hash": welcome["resume_secret"].sha256_text()} if is_new else before["authority"]["profiles"][profile_id]
	if request["display_name"] != profile["display_name"] or (local_host and profile["role"] != "HOST") or profile != expected_profile or identity_effect["added_ids"] != expected_ids or identity_effect["revision_after"] != before["authority"]["revision"] + 1 or identity_effect["peer_id"] != peer_id or identity_effect["profile_id"] != profile_id or welcome != {"ok": true, "player_profile_id": profile_id, "player_instance_id": actor_id, "resume_secret": welcome["resume_secret"], "server_epoch": _authority.server_epoch}:
		_authority.cancel_prepared_join(identity_ticket)
		return _reject("BOOTSTRAP_PROFILE_CHANGE_UNSUPPORTED")
	for identifier in expected_ids:
		if runtime_before["used_ids"].has(identifier):
			_authority.cancel_prepared_join(identity_ticket)
			return _reject("BOOTSTRAP_NEW_ID_COLLISION")
	var retained: Dictionary = _model.actor_record(actor_id)
	if (is_new and (not retained.is_empty() or before["authority"]["profiles"].has(profile_id))) or (not is_new and retained.is_empty()):
		_authority.cancel_prepared_join(identity_ticket)
		return _reject("BOOTSTRAP_ACTOR_PRESENCE_CONFLICT")
	var placement: Dictionary = JoinPlacement.choose_new(_source_lease.world_view(), actor_id, _space) if is_new else _space.check_actor_placement(actor_id, retained["layer"], State.vector(retained["position"]))
	if not placement.get("ok", false):
		_authority.cancel_prepared_join(identity_ticket)
		return placement
	var layer: Dictionary = placement["layer"] if is_new else retained["layer"]
	var position: Vector2 = placement["position"] if is_new else State.vector(retained["position"])
	var fallback: Dictionary = {"layer": layer.duplicate(true), "position": State.pair(position)} if is_new else {}
	var presence: Dictionary = _model.prepare_presence(actor_id, layer, position, fallback)
	if not presence.get("ok", false):
		_authority.cancel_prepared_join(identity_ticket)
		return presence
	var presence_ticket: Dictionary = presence["ticket"]
	var presence_effect: Dictionary = _model.prepared_presence_effect(presence_ticket)["effect"]
	var projection: RefCounted = _model.frame_projection(_source_lease)
	var projected: bool = projection != null
	if projected and is_new:
		projected = projection.create_actor(actor_id, layer, position, fallback).get("ok", false)
	if projected:
		projected = projection.activate(actor_id, layer, position).get("ok", false)
	if not projected or presence_effect["record"] != projection.actor_record(actor_id) or presence_effect["is_new"] != is_new or presence_effect["revision_increment"] != (2 if is_new else 1):
		_authority.cancel_prepared_join(identity_ticket)
		_model.cancel_prepared_presence(presence_ticket)
		return _fatal("BOOTSTRAP_PRESENCE_PROJECTION_INVALID")
	var native: Dictionary = _space.prepare_actor_placement(actor_id, layer, position)
	if not native.get("ok", false):
		_authority.cancel_prepared_join(identity_ticket)
		_model.cancel_prepared_presence(presence_ticket)
		return native
	var native_effect: Dictionary = _space.prepared_actor_placement_effect(native["ticket"])
	if not native_effect.get("ok", false):
		_authority.cancel_prepared_join(identity_ticket)
		_model.cancel_prepared_presence(presence_ticket)
		_space.cancel_prepared_actor_placement(native["ticket"])
		return _fatal("BOOTSTRAP_NATIVE_PREPARATION_CHANGED")
	var expected_read: Dictionary = before.duplicate(true)
	expected_read["native"]["native_generation"] += 1
	var expected: Dictionary = before.duplicate(true)
	expected["model"] = projection.persistent_state()
	expected["public"] = projection.public_snapshot()
	expected["authority"]["revision"] += 1
	if is_new:
		expected["authority"]["profiles"][profile_id] = profile.duplicate(true)
	expected["authority_public"]["revision"] += 1
	expected["authority_public"]["players"][profile_id] = {"player_profile_id": profile_id, "player_instance_id": actor_id, "display_name": profile["display_name"], "role": profile["role"], "peer_id": peer_id}
	var runtime_expected: Dictionary = runtime_before.duplicate(true)
	runtime_expected["join_generation"] += 1
	var runtime_prepared: Dictionary = runtime_expected.duplicate(true)
	runtime_expected["peers"][peer_id] = profile_id
	runtime_expected["welcomes"][peer_id] = identity_effect["welcome"].duplicate(true)
	for identifier in identity_effect["added_ids"]:
		runtime_expected["used_ids"][identifier] = true
	_generation += 1
	var ticket := {"owner_id": get_instance_id(), "generation": _generation, "kind": "bootstrap_presence"}
	_bootstrap_presence = {"ticket": ticket.duplicate(true), "phase": "prepared", "is_new": is_new, "profile_id": profile_id, "actor_id": actor_id, "owner_mode": owner._mode, "identity_ticket": identity_ticket, "presence_ticket": presence_ticket, "native_ticket": native["ticket"], "identity_effect": identity_effect, "presence_effect": presence_effect, "native_effect": native_effect["effect"], "expected_read": expected_read, "expected": expected, "input_values": projection.frame_input_state(false), "runtime_prepared": runtime_prepared, "runtime_expected": runtime_expected}
	return {"ok": true, "prepared": true, "confirmed": false, "save_ready": false, "delta_consumed": false, "ticket": ticket}

func commit_bootstrap_presence(ticket: Variant) -> Dictionary:
	if not _ground_pending.is_empty(): return _reject("TREE_GROUND_SYNCHRONOUS_PENDING")
	if not fatal_error.is_empty():
		return _reject("FRAME_STOPPED", true)
	if not _matches_bootstrap_presence(ticket) or _bootstrap_presence["phase"] != "prepared":
		return _reject("INVALID_BOOTSTRAP_PRESENCE_TICKET")
	var current := _validated_boundary()
	var owner: Object = _source_lease.bound_save_owner()
	var identity: Dictionary = _authority.prepared_join_effect(_bootstrap_presence["identity_ticket"])
	var presence: Dictionary = _model.prepared_presence_effect(_bootstrap_presence["presence_ticket"])
	var native_candidate: Dictionary = _space.prepared_actor_placement_effect(_bootstrap_presence["native_ticket"])
	if not current.get("ok", false) or current["boundary"] != _bootstrap_presence["expected_read"] or owner == null or owner._mode != _bootstrap_presence["owner_mode"] or _authority_runtime() != _bootstrap_presence["runtime_prepared"] or not identity.get("ok", false) or not presence.get("ok", false) or not native_candidate.get("ok", false) or identity["effect"] != _bootstrap_presence["identity_effect"] or presence["effect"] != _bootstrap_presence["presence_effect"] or native_candidate["effect"] != _bootstrap_presence["native_effect"]:
		return _fatal("BOOTSTRAP_PREPARED_STATE_CHANGED")
	var native: Dictionary = _space.commit_bootstrap_actor_placement(_bootstrap_presence["native_ticket"])
	if not native.get("ok", false):
		return _fatal(str(native.get("code", "BOOTSTRAP_NATIVE_COMMIT_FAILED")))
	var committed: Dictionary = _model.commit_prepared_presence(_bootstrap_presence["presence_ticket"])
	if not committed.get("ok", false):
		return _fatal("BOOTSTRAP_MODEL_COMMIT_FAILED")
	var welcome: Dictionary = _authority.commit_prepared_join(_bootstrap_presence["identity_ticket"])
	var expected: Dictionary = _bootstrap_presence["expected"]
	if welcome != _bootstrap_presence["identity_effect"]["welcome"] or _authority_runtime() != _bootstrap_presence["runtime_expected"] or _authority.persistent_state() != expected["authority"] or _authority.public_snapshot() != expected["authority_public"] or _model.persistent_state() != expected["model"] or _model.public_snapshot() != expected["public"] or _model.frame_input_state(false) != _bootstrap_presence["input_values"]:
		return _fatal("BOOTSTRAP_MODEL_AUTHORITY_POSTCONDITION")
	var inputs: Dictionary = _model.frame_input_state()
	var actor_id: String = _bootstrap_presence["actor_id"]
	for other_id in _bootstrap_presence["expected_read"]["inputs"]:
		if inputs.get(other_id) != _bootstrap_presence["expected_read"]["inputs"][other_id] or inputs[actor_id]["identity"] == inputs[other_id]["identity"]:
			return _fatal("BOOTSTRAP_INPUT_IDENTITY_POSTCONDITION")
	# Only the named fresh InputState and native allocations contribute new runtime
	# identities. Every logical field and every previous binding was pre-derived.
	expected["inputs"] = inputs
	expected["native"] = native["boundary"]
	_bootstrap_presence["phase"] = "committed"
	_bootstrap_presence["physics_frame"] = Engine.get_physics_frames()
	return {"ok": false, "pending": true, "committed": true, "confirmed": false, "save_ready": false, "delta_consumed": false, "ticket": ticket.duplicate(true)}

func confirm_bootstrap_presence(ticket: Variant) -> Dictionary:
	if not _ground_pending.is_empty(): return _reject("TREE_GROUND_SYNCHRONOUS_PENDING")
	if not fatal_error.is_empty():
		return _reject("FRAME_STOPPED", true)
	if not _matches_bootstrap_presence(ticket) or _bootstrap_presence["phase"] != "committed":
		return _reject("INVALID_BOOTSTRAP_PRESENCE_TICKET")
	if Engine.get_physics_frames() <= _bootstrap_presence["physics_frame"]:
		return _pending("BOOTSTRAP_PRESENCE_PHYSICS_PENDING")
	var current := _validated_boundary()
	var owner: Object = _source_lease.bound_save_owner()
	if not current.get("ok", false) or current["boundary"] != _bootstrap_presence["expected"] or _authority_runtime() != _bootstrap_presence["runtime_expected"] or owner == null or owner._mode != _bootstrap_presence["owner_mode"]:
		return _fatal("BOOTSTRAP_CONFIRMED_STATE_CHANGED")
	_lineage = _bootstrap_presence["expected"].duplicate(true)
	_cache_confirmed(_lineage)
	var welcome: Dictionary = _bootstrap_presence["identity_effect"]["welcome"].duplicate(true)
	var surface_bootstrap: bool = _lineage["model"]["actors"][_bootstrap_presence["actor_id"]]["layer"]["map_kind"] == "surface"
	var is_new: bool = _bootstrap_presence["is_new"]
	var profile_id: String = _bootstrap_presence["profile_id"]
	_bootstrap_presence.clear()
	var inventory := _confirm_inventory_presence(is_new, profile_id)
	if not inventory.get("ok", false):
		return inventory
	return {"ok": true, "confirmed": true, "pending": false, "save_ready": true, "delta_consumed": false, "surface_bootstrap": surface_bootstrap, "welcome": welcome}

func cancel_bootstrap_presence(ticket: Variant) -> Dictionary:
	if not _ground_pending.is_empty(): return _reject("TREE_GROUND_SYNCHRONOUS_PENDING")
	if not fatal_error.is_empty():
		return _reject("FRAME_STOPPED", true)
	if not _matches_bootstrap_presence(ticket) or _bootstrap_presence["phase"] != "prepared":
		return _reject("INVALID_BOOTSTRAP_PRESENCE_TICKET")
	var current := _validated_boundary()
	if not current.get("ok", false) or current["boundary"] != _bootstrap_presence["expected_read"] or _authority_runtime() != _bootstrap_presence["runtime_prepared"]:
		return _fatal("BOOTSTRAP_CANCEL_STATE_CHANGED")
	for result in [_space.cancel_prepared_actor_placement(_bootstrap_presence["native_ticket"]), _model.cancel_prepared_presence(_bootstrap_presence["presence_ticket"]), _authority.cancel_prepared_join(_bootstrap_presence["identity_ticket"])]:
		if not result.get("ok", false):
			return _fatal("BOOTSTRAP_CANCEL_TICKET_CHANGED")
	# Native preparation consumed exactly its reserved generation, no actor write.
	_lineage = _bootstrap_presence["expected_read"].duplicate(true)
	_cache_confirmed(_lineage)
	_bootstrap_presence.clear()
	return {"ok": true, "cancelled": true, "delta_consumed": false}

func _matches_bootstrap_presence(ticket: Variant) -> bool:
	return fatal_error.is_empty() and ticket is Dictionary and ticket.size() == 3 and typeof(ticket.get("owner_id")) == TYPE_INT and typeof(ticket.get("generation")) == TYPE_INT and ticket.get("kind") is String and ticket["kind"] == "bootstrap_presence" and not _bootstrap_presence.is_empty() and ticket == _bootstrap_presence["ticket"]

func submit(delta: float, ordered_envelopes: Variant) -> Dictionary:
	if not _ground_pending.is_empty(): return _reject("TREE_GROUND_SYNCHRONOUS_PENDING")
	if not fatal_error.is_empty():
		return _reject("FRAME_STOPPED", true)
	if not _tree_pending.is_empty(): return _pending("TREE_COMPLETION_PHYSICS_PENDING")
	if _initial_closed:
		return _reject("FRAME_INITIAL_BOUNDARY_CLOSED")
	if not _bootstrap_presence.is_empty():
		return _pending("BOOTSTRAP_PRESENCE_PENDING")
	if not _initial_boundary.is_empty():
		return _pending("FRAME_INITIAL_CONFIRMATION_PENDING")
	if not _sealed.is_empty():
		return _pending("FRAME_CONFIRMATION_PENDING")
	var frame := Engine.get_physics_frames()
	if frame <= _last_submit_frame:
		return _reject("FRAME_ALREADY_SUBMITTED")
	# Accounting belongs to this new attempt, not a previously confirmed frame.
	_tick_committed = false
	if not State.valid_clock(delta) or delta <= 0.0 or not ordered_envelopes is Array or ordered_envelopes.size() > MAX_ENVELOPES:
		return _reject("FRAME_BATCH_OR_DELTA_INVALID")
	var batch: Array = []
	var byte_count: int = 0
	for value in ordered_envelopes:
		var checked := _envelope_check(value)
		if checked["ok"]:
			byte_count += checked["bytes"]
			batch.append({"ok": true, "envelope": value.duplicate(true)})
		else:
			batch.append(checked) # Never retain/copy an oversized or malformed payload.
	if byte_count > MAX_BATCH_BYTES:
		return _reject("FRAME_BATCH_BYTES_EXCEEDED")
	var source := _validated_boundary()
	if not source.get("ok", false):
		return _fatal(str(source.get("code", "FRAME_CONTEXT_INVALID")))
	if not _lineage.is_empty() and source["boundary"] != _lineage:
		return _fatal("FRAME_CONFIRMED_LINEAGE_CHANGED")
	var before: Dictionary = source["boundary"]
	if _model.active_actor_ids().is_empty():
		return _reject("FRAME_NO_ACTIVE_ACTORS")
	if not State.valid_clock(_model.clock_seconds() + delta) or _model.clock_seconds() + delta <= _model.clock_seconds():
		return _reject("FRAME_CLOCK_CAPACITY")
	# Worst case each valid envelope admits input and transfers, plus one tick.
	if before["model"]["revision"] > Motion.MAX_REVISION - (2 * batch.size() + 1) or _generation >= Motion.MAX_REVISION:
		return _reject("FRAME_MODEL_REVISION_CAPACITY")
	var native: Dictionary = _space.begin_actor_frame(batch.size())
	if not native.get("ok", false):
		return native
	_last_submit_frame = frame
	_tick_committed = false
	_generation += 1
	var ticket := {"owner_id": get_instance_id(), "generation": _generation}
	var native_ticket: Dictionary = native["ticket"]
	var projection: RefCounted = _model.frame_projection(_source_lease)
	if projection == null:
		return _fatal("FRAME_SOURCE_PROJECTION_UNAVAILABLE")
	var admissions: Array = []
	var interactions: Array = []
	# This initial stable snapshot is safe for readonly requests while this first
	# frame is pending. It contains no tentative actor layer or position.
	if _last_snapshot.is_empty():
		_cache_confirmed(before)
	for item in batch:
		if not item["ok"]:
			admissions.append(item.duplicate(true))
			continue
		var envelope: Dictionary = item["envelope"]
		var binding := _envelope_binding(envelope)
		if not binding["ok"]:
			admissions.append(binding)
			continue
		var actor_id: String = envelope["actor_id"]
		var input_before: Dictionary = _model.frame_input_state()
		# Derive the exact admission/model/input values before the live admission.
		var predicted: Dictionary = projection.accept_input(actor_id, envelope["request"])
		var admitted: Dictionary = _model.accept_input(actor_id, envelope["request"])
		if admitted != predicted or not _model_matches(projection) or not _input_identity_transition(input_before, actor_id, admitted.get("ok", false) and not admitted.get("duplicate", false)):
			return _fatal("FRAME_INPUT_PROJECTION_MISMATCH")
		admissions.append(admitted.duplicate(true))
		if not admitted.get("ok", false) or admitted.get("duplicate", false) or not admitted.get("action", {}).get("interaction_requested", false):
			continue
		var cursor: Dictionary = _model.public_snapshot()["input_cursors"][actor_id]
		var receipt: Dictionary = _model.consume_interaction_admission(actor_id, admitted, cursor)
		if not receipt.get("ok", false):
			return _fatal("FRAME_F_RECEIPT_MISMATCH")
		var action := _transfer_one(native_ticket, actor_id, admitted["aim"], projection)
		if action.get("fatal", false):
			return _fatal(str(action.get("code", "FRAME_TRANSFER_FATAL")))
		if action.get("transferred", false):
			projection = action["projection"]
			action.erase("projection")
			# Submitted layer changes are not externally confirmed interactions.
			action["ok"] = false
			action["submitted"] = true
			action["transfer_pending"] = true
			action["transferred"] = false
		interactions.append(action)
	# Model projections copy no terrain or authority secrets. A preview is generated
	# independently on each side, then the existing joint solver resolves once.
	var expected_preview: Dictionary = projection.preview_tick(delta)
	var preview: Dictionary = _model.preview_tick(delta)
	if preview != expected_preview or not preview.get("ok", false) or preview.get("paused", false):
		return _fatal("FRAME_TICK_PREVIEW_MISMATCH")
	var query: Callable = _space.query_frame_environment_motion.bind(native_ticket)
	var solved := Solver.resolve(preview, query, _half, {}, _space.circle_boundaries())
	if not solved.get("ok", false):
		return _fatal(str(solved.get("code", "FRAME_RESOLUTION_FAILED")))
	var prepared: Dictionary = _space.prepare_frame_positions(native_ticket, preview, solved["positions"])
	if not prepared.get("ok", false):
		return _fatal(str(prepared.get("code", "FRAME_NATIVE_TICK_PREPARE_FAILED")))
	var expected_tick: Dictionary = projection.commit_preview(expected_preview, solved["positions"])
	if not expected_tick.get("ok", false):
		return _fatal("FRAME_PROJECTED_TICK_REJECTED")
	var expected_model: Dictionary = projection.persistent_state()
	var expected_public: Dictionary = projection.public_snapshot()
	var expected_inputs: Dictionary = _model.frame_input_state() # Tick must retain these identities.
	var expected_authority: Dictionary = before["authority"].duplicate(true)
	var expected_authority_public: Dictionary = before["authority_public"].duplicate(true)
	expected_authority["world_seconds"] = preview["to"]
	expected_authority_public["world_seconds"] = preview["to"]
	var committed: Dictionary = _model.commit_preview(preview, solved["positions"])
	_tick_committed = _model.clock_seconds() == preview["to"]
	if committed != expected_tick or not _model_matches(projection) or _model.frame_input_state() != expected_inputs:
		return _fatal("FRAME_MODEL_TICK_POSTCONDITION")
	var submitted: Dictionary = _space.commit_frame_positions(native_ticket, prepared["ticket"])
	if not submitted.get("ok", false):
		return _fatal(str(submitted.get("code", "FRAME_NATIVE_TICK_COMMIT_FAILED")))
	_authority.advance(delta)
	if _authority.persistent_state() != expected_authority or _authority.public_snapshot() != expected_authority_public:
		return _fatal("FRAME_AUTHORITY_TICK_POSTCONDITION")
	var expected_native: Dictionary = _space.actor_frame_expected_boundary(native_ticket)
	if not expected_native.get("ok", false):
		return _fatal("FRAME_NATIVE_SEAL_MISSING")
	var expected := {"model": expected_model, "public": expected_public, "inputs": expected_inputs, "authority": expected_authority, "authority_public": expected_authority_public, "terrain": before["terrain"].duplicate(true), "native": expected_native["boundary"]}
	_sealed = {"ticket": ticket.duplicate(true), "native_ticket": native_ticket, "physics_frame": frame, "expected": expected, "delta": delta, "interactions": interactions.duplicate(true)}
	return {"ok": false, "pending": true, "sealed": true, "confirmed": false, "save_ready": false, "delta_consumed": true, "consumed_count": batch.size(), "ticket": ticket, "admissions": admissions, "interactions": interactions}

func _transfer_one(native_ticket: Dictionary, actor_id: String, aim: Vector2, projection: RefCounted) -> Dictionary:
	var source_check: Dictionary = _source_lease.guard()
	if not source_check.get("ok", false):
		return {"ok": false, "code": source_check.get("code", "FRAME_SOURCE_CHANGED"), "fatal": true}
	var record: Dictionary = _model.actor_record(actor_id)
	var selected := Selector.select_natural_entry(_source_lease.world_view(), record["layer"], State.vector(record["position"]), aim, _range)
	if not selected.get("ok", false):
		return selected
	var target: Dictionary = selected["candidate"]["destination_endpoint"]["layer"]
	var model: Dictionary = _model.prepare_layer_transfer(actor_id, target)
	if not model.get("ok", false):
		return model
	var native: Dictionary = _space.prepare_frame_actor_transfer(native_ticket, actor_id, record["layer"], target, State.vector(record["position"]))
	if not native.get("ok", false):
		_model.cancel_prepared_layer_transfer(model["ticket"])
		return native
	# A separate next projection leaves the current proof untouched if native
	# submission is rejected and proven restored before the model layer commit.
	var next_projection: RefCounted = projection.frame_projection(_source_lease)
	if next_projection == null:
		return {"ok": false, "code": "FRAME_SOURCE_PROJECTION_UNAVAILABLE", "fatal": true}
	var predicted: Dictionary = next_projection.prepare_layer_transfer(actor_id, target)
	if not predicted.get("ok", false) or not next_projection.commit_prepared_layer_transfer(predicted["ticket"]).get("ok", false):
		return {"ok": false, "code": "FRAME_TRANSFER_PROJECTION_FAILED", "fatal": true}
	var input_before: Dictionary = _model.frame_input_state()
	var checked: Dictionary = _model.validate_prepared_layer_transfer(model["ticket"])
	if not checked.get("ok", false):
		return {"ok": false, "code": "FRAME_TRANSFER_MODEL_TICKET_CHANGED", "fatal": true}
	var moved: Dictionary = _space.commit_frame_actor_transfer(native_ticket, native["ticket"])
	if not moved.get("ok", false):
		_model.cancel_prepared_layer_transfer(model["ticket"])
		return moved
	var committed: Dictionary = _model.commit_prepared_layer_transfer(model["ticket"])
	if not committed.get("ok", false):
		var restored: Dictionary = _space.rollback_frame_actor_transfer(native_ticket, native["ticket"])
		_model.cancel_prepared_layer_transfer(model["ticket"])
		if not restored.get("ok", false) or not _model_matches(projection) or _model.frame_input_state() != input_before:
			return {"ok": false, "code": "FRAME_TRANSFER_ROLLBACK_UNPROVED", "fatal": true}
		return {"ok": false, "code": "FRAME_TRANSFER_MODEL_REJECTED", "restored": true, "transferred": false}
	if not _model_matches(next_projection) or _model.frame_input_state() != input_before:
		return {"ok": false, "code": "FRAME_TRANSFER_MODEL_POSTCONDITION", "fatal": true}
	return {"ok": true, "transferred": true, "projection": next_projection}

func confirm(ticket: Variant) -> Dictionary:
	if not _ground_pending.is_empty(): return _reject("TREE_GROUND_SYNCHRONOUS_PENDING")
	if not fatal_error.is_empty():
		return _reject("FRAME_STOPPED", true)
	if not _matches(ticket):
		return _reject("INVALID_FRAME_CONFIRMATION_TICKET")
	if Engine.get_physics_frames() <= _sealed["physics_frame"]:
		return _pending("FRAME_PHYSICS_CONFIRMATION_PENDING")
	var checked := _validated_boundary()
	if not checked.get("ok", false) or checked["boundary"] != _sealed["expected"]:
		return _fatal("FRAME_SEALED_STATE_CHANGED")
	var native: Dictionary = _space.confirm_actor_frame(_sealed["native_ticket"])
	if not native.get("ok", false) or native.get("boundary", {}) != _sealed["expected"]["native"]:
		return _fatal(str(native.get("code", "FRAME_NATIVE_CONFIRMATION_MISMATCH")))
	_lineage = _sealed["expected"].duplicate(true)
	_cache_confirmed(_lineage)
	var interactions: Array = _sealed["interactions"].duplicate(true)
	for action in interactions:
		if action.get("submitted", false):
			action["ok"] = true
			action["transfer_pending"] = false
			action["transferred"] = true
	_sealed.clear()
	_tick_committed = false
	return {"ok": true, "confirmed": true, "pending": false, "save_ready": true, "interactions": interactions}

func last_confirmed_snapshot() -> Dictionary:
	if not _ground_pending.is_empty(): return {}
	return _last_snapshot.duplicate(true)

func public_snapshot() -> Dictionary:
	var gate := _publication_gate()
	return {"ok": true, "snapshot": _last_snapshot.duplicate(true)} if gate["ok"] else gate

func combined_save_state(advance_auto: bool = false) -> Dictionary:
	var gate := _publication_gate()
	if not gate["ok"]:
		return gate
	var state := _last_state.duplicate(true)
	if advance_auto:
		# Pure preview only. A later owner must acknowledge its actual save/deadline
		# transaction at a confirmed boundary; it cannot mutate sealed authority.
		state["next_auto_due_world_seconds"] = _authority.state_for_automatic_save()["next_auto_due_world_seconds"]
	return {"ok": true, "state": state, "state_scope": "authority_world_actor_base", "requires_terrain_wrapper": true}

func _save_store_config(save_store: SandboxSaveStore) -> Dictionary:
	return {"directory": save_store.directory, "automatic_count": save_store.automatic_count, "manual_count": save_store.manual_count, "validator": save_store._state_validator, "schema": save_store._schema_version, "maximum_bytes": save_store._maximum_bytes, "exact": save_store._exact_scalars, "content": save_store._content_revision, "protocol": save_store._network_protocol_version}

func save_confirmed_owner(reason: String, advance_auto: bool = false) -> Dictionary:
	# No external result/receipt argument exists. Only this exact synchronous call
	# to the owner's real SaveStore may acknowledge a persisted deadline transition.
	var gate := _publication_gate()
	if not gate.get("ok", false):
		return gate
	var owner: Object = _source_lease.bound_save_owner()
	if owner == null or owner._fatal_shutdown or owner._mode not in ["server", "host"] or reason not in ["initial_world", "bootstrap_join", "automatic", "normal_shutdown"] or _save_serial >= Motion.MAX_REVISION:
		return _fatal("BOOTSTRAP_SAVE_OWNER_INVALID")
	var save_store: SandboxSaveStore = owner._save_store
	var terrain_session: RefCounted = owner._terrain_session
	var actor_session: RefCounted = owner._actor_session
	if save_store == null or (owner._save_profile == 4 and save_store.get_script() != SaveScript) or terrain_session == null or terrain_session.get_script() != TerrainSession or not terrain_session.ready or terrain_session._terrain_store != owner._terrain_store or terrain_session._legacy != actor_session or actor_session == null or actor_session.get_script() != ActorSession or not actor_session.ready or actor_session._world != _world:
		return _fatal("BOOTSTRAP_SAVE_STORE_BINDING_INVALID")
	if not Store._same(actor_session._actor_document, _inputs.document()) or actor_session._half != _half:
		return _fatal("BOOTSTRAP_SAVE_ACTOR_CONTRACT_INVALID")
	if owner._save_profile == 4:
		# Preserve the existing exact old4 branch, including concrete script type.
		if save_store.get_script() != SaveScript or save_store._state_validator != Callable(terrain_session, "validate_combined_state") or save_store._schema_version != 4 or not save_store._exact_scalars or save_store._maximum_bytes != 4194304 or save_store._content_revision != _authority.catalogue_hash or save_store._network_protocol_version != _authority.protocol_version:
			return _fatal("BOOTSTRAP_SAVE_CONTRACT_INVALID")
	elif owner._save_profile in [5,6]:
		# Only the closed registry admits the exact bounded Store + cold validator.
		# Arbitrary subclasses, callbacks and lookalike configurations stay closed.
		var registered: Dictionary = owner._inventory_registry.verify_binding(owner._save_profile, save_store)
		if not registered.get("ok", false) or not _owner_inventory_guard().get("ok", false):
			return _fatal("BOOTSTRAP_SAVE_INVENTORY_CONTRACT_INVALID")
	else:
		return _fatal("BOOTSTRAP_SAVE_CONTRACT_INVALID")
	for field in ["automatic_backup_count", "manual_slot_count"]:
		var count: Variant = owner._save_settings.get(field)
		if typeof(count) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(count)) or float(count) < 1.0 or float(count) > Motion.MAX_REVISION or floor(float(count)) != float(count):
			return _fatal("BOOTSTRAP_OWNER_SAVE_CONFIG_INVALID")
	if save_store.directory != owner._save_directory or save_store.automatic_count != int(owner._save_settings["automatic_backup_count"]) or save_store.manual_count != int(owner._save_settings["manual_slot_count"]):
		return _fatal("BOOTSTRAP_OWNER_SAVE_TARGET_MISMATCH")
	var interval: Variant = owner._save_settings.get("automatic_interval_seconds")
	if typeof(interval) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(interval)) or float(interval) < 0.0 or float(interval) != _authority.automatic_interval_seconds:
		return _fatal("BOOTSTRAP_OWNER_SAVE_INTERVAL_MISMATCH")
	var config := _save_store_config(save_store)
	if _save_binding.is_empty():
		_save_binding = {"store": weakref(save_store), "config": config, "actor_session": weakref(actor_session), "terrain_session": weakref(terrain_session)}
	elif _save_binding["store"].get_ref() != save_store or _save_binding["config"] != config or _save_binding["actor_session"].get_ref() != actor_session or _save_binding["terrain_session"].get_ref() != terrain_session:
		return _fatal("BOOTSTRAP_SAVE_STORE_REPLACED")
	if not save_store._lock_owned or not save_store._write_ready or save_store.last_sequence < 0 or save_store.last_sequence >= Motion.MAX_REVISION or save_store.automatic_count < 1 or (not save_store._world_id.is_empty() and save_store._world_id != _authority.world_id):
		return _fatal("BOOTSTRAP_SAVE_STORE_NOT_READY")
	var sequence: int = save_store.last_sequence + 1
	var slot: int = (save_store._last_automatic_slot % save_store.automatic_count) + 1
	var prior_slot: int = save_store._last_automatic_slot
	var lock_token: String = save_store._lock_token
	var before: Dictionary = _lineage.duplicate(true)
	var expected: Dictionary = before.duplicate(true)
	var base: Dictionary = _last_state.duplicate(true)
	if advance_auto:
		base["next_auto_due_world_seconds"] = _authority.state_for_automatic_save()["next_auto_due_world_seconds"]
	expected["authority"]["next_auto_due_world_seconds"] = base["next_auto_due_world_seconds"]
	var combined: Dictionary = terrain_session.combine(base, owner._terrain_component)
	if combined.get("ok", false) and owner._save_profile in [5,6]:
		combined = owner._inventory_owner.combine_for_save(combined["state"])
	if not combined.get("ok", false):
		return _fatal("BOOTSTRAP_SAVE_STATE_INVALID")
	var state: Dictionary = combined["state"]
	var encoded: Dictionary = Codec.encode(state)
	if not encoded.get("ok", false):
		return _fatal("BOOTSTRAP_SAVE_CODEC_INVALID")
	var state_hash: String = JSON.stringify(encoded["value"], "", true, true).sha256_text()
	# Codec owns a detached tagged tree. Only the immutable hash is retained;
	# release this scratch tree before SaveStore encodes and verifies its file.
	encoded.clear()
	_save_serial += 1
	var result: Dictionary = save_store.save_main(state, reason)
	var main_committed: bool = result.get("ok", false) or result.get("main_committed", false)
	var receipt := {"owner_id": get_instance_id(), "generation": _save_serial, "store_id": save_store.get_instance_id(), "sequence": result.get("sequence", -1), "state_sha256": state_hash, "main_committed": main_committed, "complete": result.get("ok", false)}
	var current := _validated_boundary()
	var registry_unchanged: bool = owner._save_profile == 4 or (_owner_inventory_guard().get("ok", false) and owner._inventory_registry.verify_binding(owner._save_profile, save_store).get("ok", false))
	if not current.get("ok", false) or not registry_unchanged or current["boundary"] != before or owner._save_store != save_store or _save_store_config(save_store) != config or save_store._lock_token != lock_token or not save_store._lock_owned or not save_store._write_ready:
		var failed := _fatal("BOOTSTRAP_SAVE_POSTCONDITION")
		failed["main_committed"] = main_committed
		failed["save_receipt"] = receipt
		return failed
	if main_committed:
		if result.get("sequence") != sequence or save_store.last_sequence != sequence or save_store._world_id != _authority.world_id or (result.get("ok", false) and (result.get("automatic_slot") != slot or save_store._last_automatic_slot != slot)) or (not result.get("ok", false) and save_store._last_automatic_slot != prior_slot):
			var failed := _fatal("BOOTSTRAP_SAVE_RECEIPT_MISMATCH")
			failed["main_committed"] = true
			failed["save_receipt"] = receipt
			return failed
		_authority.next_auto_due_world_seconds = base["next_auto_due_world_seconds"]
		current = _validated_boundary()
		if not current.get("ok", false) or current["boundary"] != expected:
			var failed := _fatal("BOOTSTRAP_SAVE_DEADLINE_POSTCONDITION")
			failed["main_committed"] = true
			failed["save_receipt"] = receipt
			return failed
		_lineage = expected
		_cache_confirmed(_lineage)
	if not result.get("ok", false):
		var failed := _fatal(str(result.get("code", "BOOTSTRAP_SAVE_FAILED")))
		failed["main_committed"] = main_committed
		failed["save_receipt"] = receipt
		return failed
	result["main_committed"] = true
	result["save_receipt"] = receipt
	return result

func status() -> Dictionary:
	var save_ready: bool = false
	if not _lineage.is_empty() and _sealed.is_empty() and _initial_boundary.is_empty() and _bootstrap_presence.is_empty() and not _initial_closed and fatal_error.is_empty():
		save_ready = _publication_gate().get("ok", false)
	return {"pending": not _sealed.is_empty() or not _initial_boundary.is_empty() or not _bootstrap_presence.is_empty(), "sealed": not _sealed.is_empty(), "initial_pending": not _initial_boundary.is_empty(), "initial_closed": _initial_closed, "bootstrap_phase": _bootstrap_presence.get("phase", ""), "fatal": not fatal_error.is_empty(), "save_ready": save_ready, "last_submit_frame": _last_submit_frame, "validation_calls": _validation_calls, "validation_usec": _validation_usec, "source_lease": _source_lease.statistics() if _source_lease != null else {}}

func _publication_gate() -> Dictionary:
	if not _ground_pending.is_empty(): return _reject("TREE_GROUND_SYNCHRONOUS_PENDING")
	if not fatal_error.is_empty():
		return _reject("FRAME_STOPPED", true)
	if not _tree_pending.is_empty(): return _pending("TREE_COMPLETION_PHYSICS_PENDING")
	if _initial_closed:
		return _reject("FRAME_INITIAL_BOUNDARY_CLOSED")
	if not _bootstrap_presence.is_empty():
		return _pending("BOOTSTRAP_PRESENCE_PUBLICATION_PENDING")
	if not _initial_boundary.is_empty():
		return _pending("FRAME_INITIAL_PUBLICATION_PENDING")
	if not _sealed.is_empty():
		return _pending("FRAME_PUBLICATION_PENDING")
	if _lineage.is_empty():
		return _reject("FRAME_NOT_CONFIRMED")
	var checked := _validated_boundary()
	if not checked.get("ok", false) or checked["boundary"] != _lineage:
		return _fatal("FRAME_CONFIRMED_LINEAGE_CHANGED")
	return {"ok": true}

func _validated_boundary() -> Dictionary:
	_validation_calls += 1
	var started := Time.get_ticks_usec()
	var prepared := prepare_frozen_sources()
	var checked: Dictionary = _source_lease.dynamic_boundary() if prepared.get("ok", false) else prepared
	_validation_usec += Time.get_ticks_usec() - started
	return checked

func _cache_confirmed(boundary: Dictionary) -> void:
	_last_snapshot = boundary["authority_public"].duplicate(true)
	_last_snapshot["world_component"] = _source_lease.world_view()
	_last_snapshot["actor_public"] = boundary["public"].duplicate(true)
	_last_state = boundary["authority"].duplicate(true)
	_last_state["world_component"] = _last_snapshot["world_component"]
	_last_state["actor_component"] = boundary["model"].duplicate(true)

func _model_matches(projection: RefCounted) -> bool:
	return _model.persistent_state() == projection.persistent_state() and _model.public_snapshot() == projection.public_snapshot() and _model.frame_input_state(false) == projection.frame_input_state(false)

func _input_identity_transition(before: Dictionary, actor_id: String, admitted: bool) -> bool:
	var after: Dictionary = _model.frame_input_state()
	if before.size() != after.size():
		return false
	for other_id in before:
		if not after.has(other_id):
			return false
		if other_id == actor_id and admitted:
			if before[other_id]["identity"] == after[other_id]["identity"]:
				return false
		elif before[other_id] != after[other_id]:
			return false
	return true

func _command_check(request: Variant) -> Dictionary:
	# Guard the new frame boundary without changing the legacy Command contract.
	# Its kind comparison expects a String and must never see an arbitrary Variant.
	if not request is Dictionary:
		return _reject("INVALID_INPUT_FIELDS")
	if request.has("kind") and not request["kind"] is String:
		return _reject("INVALID_INPUT_KIND")
	return Command.validate(request)

func _envelope_check(value: Variant) -> Dictionary:
	if not State.exact_fields(value, ENVELOPE_FIELDS) or typeof(value["peer_id"]) != TYPE_INT or value["peer_id"] < 1 or typeof(value["input_generation"]) != TYPE_INT or value["input_generation"] < 1 or value["input_generation"] > Motion.MAX_REVISION:
		return _reject("FRAME_ENVELOPE_INVALID")
	for key in ["actor_id", "server_epoch", "world_id"]:
		if not value[key] is String or value[key].length() > 80:
			return _reject("FRAME_ENVELOPE_INVALID")
	var command := _command_check(value["request"])
	if not command.get("ok", false):
		return command
	var bytes := var_to_bytes(value).size()
	if bytes > MAX_ENVELOPE_BYTES:
		return _reject("FRAME_ENVELOPE_BYTES_EXCEEDED")
	return {"ok": true, "bytes": bytes}

func _envelope_binding(envelope: Dictionary) -> Dictionary:
	var actor_id := _actor_for_peer(envelope["peer_id"])
	if actor_id.is_empty() or actor_id != envelope["actor_id"] or envelope["world_id"] != _authority.world_id or envelope["server_epoch"] != _authority.server_epoch or not actor_id in _model.active_actor_ids():
		return _reject("FRAME_ENVELOPE_BINDING_STALE")
	if _model.public_snapshot()["input_cursors"][actor_id]["input_generation"] != envelope["input_generation"]:
		return _reject("FRAME_ENVELOPE_GENERATION_STALE")
	return {"ok": true}

func _actor_for_peer(peer_id: int) -> String:
	if _authority == null or peer_id < 1:
		return ""
	for player in _authority.public_snapshot()["players"].values():
		if player["peer_id"] == peer_id:
			return player["player_instance_id"]
	return ""

func _matches(ticket: Variant) -> bool:
	return ticket is Dictionary and ticket.size() == 2 and typeof(ticket.get("owner_id")) == TYPE_INT and typeof(ticket.get("generation")) == TYPE_INT and not _sealed.is_empty() and ticket == _sealed["ticket"]

func _matches_initial_boundary(ticket: Variant) -> bool:
	return ticket is Dictionary and ticket.size() == 3 and typeof(ticket.get("owner_id")) == TYPE_INT and typeof(ticket.get("generation")) == TYPE_INT and ticket.get("kind") is String and ticket["kind"] == "initial_boundary" and not _initial_boundary.is_empty() and ticket == _initial_boundary["ticket"]

func _pending(code: String) -> Dictionary:
	return {"ok": false, "code": code, "pending": true, "sealed": not _sealed.is_empty(), "initial_boundary": not _initial_boundary.is_empty(), "save_ready": false, "delta_consumed": false}

func _reject(code: String, fatal: bool = false) -> Dictionary:
	var result := {"ok": false, "code": code, "fatal": fatal, "save_ready": false, "delta_consumed": false}
	if fatal:
		result["retry_allowed"] = false
		result["delta_disposition"] = "failed_no_retry"
	return result

func _fatal(code: String) -> Dictionary:
	_clear_ground_transaction()
	fatal_error = code
	if not _bootstrap_presence.is_empty():
		_authority.cancel_prepared_join(_bootstrap_presence["identity_ticket"])
		_bootstrap_presence.clear()
	if not _initial_boundary.is_empty():
		_initial_boundary.clear()
		_initial_closed = true
	if _source_lease != null:
		_source_lease.release()
	# Current-frame model writes cannot be safely rewound. The future owner must
	# propagate top-level fatal, retain durable saves, and stop; it must not publish.
	if _model != null:
		_model.release_runtime_sessions()
	if _space != null:
		_space.dispose()
	var result := _reject(code, true)
	result["delta_consumed"] = _tick_committed
	result["retry_allowed"] = false
	result["delta_disposition"] = "failed_no_retry"
	return result
