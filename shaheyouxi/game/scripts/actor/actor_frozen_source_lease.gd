extends RefCounted
## Explicit schema4/frame opt-in. Freeze the ACTUAL runtime roots after one full
## source validation; reference/epoch guards replace repeated static tree scans.
const Transfer = preload("res://scripts/actor/actor_natural_transfer.gd")
const Session = preload("res://scripts/actor/actor_session_state.gd")
const TerrainSession = preload("res://scripts/actor/actor_terrain_session_state.gd")
const Inputs = preload("res://scripts/actor/actor_inputs.gd")
const InputState = preload("res://scripts/actor/actor_input_state.gd")
const Store = preload("res://scripts/terrain/required_entry_terrain_store.gd")
const CombinedStore = preload("res://scripts/terrain/combined_terrain_store.gd")
const SurfaceStore = preload("res://scripts/terrain/surface_approach_store.gd")
const SurfaceRules = preload("res://scripts/terrain/surface_approach_rules.gd")
const LayoutValidator = preload("res://scripts/worldgen/layout_validator.gd")
const PrefabValidator = preload("res://scripts/prefab/prefab_validator.gd")
const GenerationInputs = preload("res://scripts/worldgen/generation_inputs.gd")
const State = preload("res://scripts/actor/actor_state.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const Circle = preload("res://scripts/actor/actor_circle_boundary.gd")
const MAX_DEPTH := 64
const MAX_NODES := 500000 # Aggregate cold-root traversal budget, not gameplay data.
const ROOT_FIELDS := {"world": ["component", "_generation", "_template"], "space": ["_terrain", "_supported_regions", "_spaces"], "inputs": ["_data", "_source_identity"], "settings": ["_data", "_source_identity"]}
const SAVE_OWNER_SCRIPT := "res://scripts/actor/actor_terrain_network_main.gd"
const SAVE_OWNER_SERVICES := {"authority": "_authority", "world": "_world", "model": "_actor_model", "space": "_actor_space", "inputs": "_actor_inputs", "store": "_terrain_store"}
var _attempted: bool = false
var _valid: bool = false
var _objects: Dictionary = {}
var _scripts: Dictionary = {}
var _roots: Array = []
var _object_links: Array = []
var _ready_owners: Array = ["world", "model", "inputs", "settings", "store"]
var _combined_store: bool = false
var _scalars: Dictionary = {}
var _ticket: Dictionary = {}
var _world_root: Dictionary = {}
var _layers: Dictionary = {}
var _terrain_context: Dictionary = {}
var _radius: float = 0.0
var _half: float = 0.0
var _world_id: String = ""
var _full_validation_calls: int = 0
var _hot_full_validation_calls: int = 0
var _guard_calls: int = 0
var _setup_usec: int = 0

func prepare(authority: RefCounted, world: RefCounted, model: RefCounted, space: RefCounted, inputs: RefCounted, save_owner: Object = null) -> Dictionary:
	if _attempted:
		return _bad("SOURCE_LEASE_ALREADY_ATTEMPTED")
	_attempted = true
	var started := Time.get_ticks_usec()
	if authority == null or world == null or model == null or space == null or inputs == null or not world.ready or not model.ready or not inputs.ready or not space.has_method("transfer_context") or not space.has_method("validate_actor_frame_boundary"):
		return _bad("SOURCE_LEASE_SERVICES_INVALID")
	if not SandboxServerAuthority._valid_id(authority.server_epoch, "session_"):
		return _bad("SOURCE_LEASE_AUTHORITY_EPOCH_INVALID")
	if not State.valid_clock(authority.automatic_interval_seconds):
		return _bad("SOURCE_LEASE_AUTOMATIC_INTERVAL_INVALID")
	var store: RefCounted = space._terrain_store
	var settings: RefCounted = model._settings
	if store == null or store.get_script() not in [Store, CombinedStore] or not store.ready or settings == null or not settings.ready:
		return _bad("SOURCE_LEASE_CONFIG_INVALID")
	_combined_store = store.get_script() == CombinedStore
	# Legacy 147-cell services remain an explicit ownerless test/API boundary.
	# A new4 save owner never selects or falls back to that earlier contract.
	if save_owner != null and not _combined_store:
		return _bad("SOURCE_LEASE_COMPOSITE_OWNER_REQUIRED")
	var actual := {"authority": authority, "world": world, "model": model, "space": space, "inputs": inputs, "settings": settings, "store": store}
	if save_owner != null:
		# Inspect the already-loaded exact script, avoiding an owner/Frame import
		# cycle. guard retains that script identity, never just a set of field names.
		if not is_instance_valid(save_owner) or not save_owner is Node or save_owner.is_queued_for_deletion():
			return _bad("SOURCE_LEASE_SAVE_OWNER_INVALID")
		var owner_script: Script = save_owner.get_script()
		if owner_script == null or owner_script.resource_path != SAVE_OWNER_SCRIPT:
			return _bad("SOURCE_LEASE_SAVE_OWNER_INVALID")
		for name in SAVE_OWNER_SERVICES:
			if not is_same(save_owner.get(SAVE_OWNER_SERVICES[name]), actual[name]):
				return _bad("SOURCE_LEASE_SAVE_OWNER_SERVICE_MISMATCH")
		var saved_terrain: Variant = save_owner.get("_terrain_component")
		if not saved_terrain is Dictionary:
			return _bad("SOURCE_LEASE_SAVE_TERRAIN_TYPE_INVALID")
		actual["save_owner"] = save_owner
		_roots.append({"owner": "save_owner", "field": "_terrain_component", "root": saved_terrain})
	if not _capture_store_sources(actual):
		return _bad("SOURCE_LEASE_STORE_GRAPH_INVALID")
	for name in actual:
		_objects[name] = weakref(actual[name])
		_scripts[name] = actual[name].get_script()
	for name in ROOT_FIELDS:
		for field in ROOT_FIELDS[name]:
			var root: Variant = actual[name].get(field)
			if not root is Dictionary and not root is Array:
				return _bad("SOURCE_LEASE_ROOT_TYPE_INVALID")
			_roots.append({"owner": name, "field": field, "root": root})
	# Validate the entire graph before making even its first container readonly.
	# This also rejects cycles/objects before entering the existing validators.
	var budget := {"nodes": 0}
	for binding in _roots:
		if not _freezable(binding["root"], binding["owner"] == "space" and binding["field"] == "_spaces", 0, budget, []):
			return _bad("SOURCE_LEASE_UNFREEZABLE_GRAPH")
	var checked := _validate_full_sources(authority, world, model, space, inputs, store, settings)
	if not checked.get("ok", false):
		return checked
	if save_owner != null:
		# Compare before entering older validators, so even malformed typed fields
		# reject safely. Then validate the actual persistence root through Store.
		if not Store._same(save_owner.get("_terrain_component"), space._terrain):
			return _bad("SOURCE_LEASE_SAVE_TERRAIN_MISMATCH")
		var saved: Dictionary = store.restore(save_owner.get("_terrain_component"), world.component, authority.world_id)
		if not saved.get("ok", false):
			return _bad("SOURCE_LEASE_SAVE_TERRAIN_INVALID")
	var native: Dictionary = space.validate_actor_frame_boundary()
	if not native.get("ok", false):
		return native
	_radius = float(world.component["layout"]["body"]["radius_cells"])
	_half = inputs.parameter("actor_diameter_cells") / 2.0
	if space._radius != _radius or space._half != _half or settings.parameter("actor_diameter_cells") / 2.0 != _half:
		return _bad("SOURCE_LEASE_GEOMETRY_CONFIG_MISMATCH")
	_world_id = authority.world_id
	_world_root = world.component
	_layers = Session._loaded_layers(_world_root)
	_terrain_context = checked["context"]["terrain"].duplicate(true)
	_scalars = {"authority": {"world_id": authority.world_id, "server_epoch": authority.server_epoch, "protocol_version": authority.protocol_version, "catalogue_hash": authority.catalogue_hash, "max_players": authority.max_players}, "world": {"bundle_sha256": world.bundle_sha256}, "model": {"_world_id": model._world_id}, "space": {"_static_epoch": space._static_epoch, "_radius": space._radius, "_half": space._half, "_supported_cell_count": space._supported_cell_count, "_validated_artifact_sha256": space._validated_artifact_sha256}}
	for name in (["entry_store", "surface_base"] if _combined_store else ["store"]):
		_scalars[name] = {"_bundle_sha256": actual[name]._bundle_sha256}
	_scalars["authority"]["automatic_interval_seconds"] = authority.automatic_interval_seconds
	# All prior operations were read-only. The validated acyclic graphs cannot fail
	# this synchronous postorder freeze. Old aliases point at these same containers.
	for binding in _roots:
		_freeze(binding["root"])
	_freeze(_layers)
	_freeze(_terrain_context)
	_ticket = {"owner_id": get_instance_id(), "generation": 1}
	_valid = true
	_setup_usec = Time.get_ticks_usec() - started
	return {"ok": true, "ticket": _ticket.duplicate(true)}

func guard() -> Dictionary:
	_guard_calls += 1
	if not _valid:
		return _bad("SOURCE_LEASE_INVALID_OR_RELEASED")
	for name in _objects:
		var object: Object = _objects[name].get_ref()
		if object == null or object.get_script() != _scripts[name]:
			return _invalidate("SOURCE_LEASE_OWNER_CHANGED")
		if name == "save_owner" and object.is_queued_for_deletion():
			return _invalidate("SOURCE_LEASE_SAVE_OWNER_RELEASED")
		if name in _ready_owners and not object.ready:
			return _invalidate("SOURCE_LEASE_OWNER_NOT_READY")
	for link in _object_links:
		if not is_same(_objects[link["owner"]].get_ref().get(link["field"]), _objects[link["child"]].get_ref()):
			return _invalidate("SOURCE_LEASE_STORE_OBJECT_REPLACED")
	var model: RefCounted = _objects["model"].get_ref()
	var space: RefCounted = _objects["space"].get_ref()
	if not is_same(model._settings, _objects["settings"].get_ref()) or not is_same(space._terrain_store, _objects["store"].get_ref()):
		return _invalidate("SOURCE_LEASE_CONFIG_OWNER_CHANGED")
	if _objects.has("save_owner"):
		var save_owner: Object = _objects["save_owner"].get_ref()
		for name in SAVE_OWNER_SERVICES:
			if not is_same(save_owner.get(SAVE_OWNER_SERVICES[name]), _objects[name].get_ref()):
				return _invalidate("SOURCE_LEASE_SAVE_OWNER_SERVICE_MISMATCH")
	for binding in _roots:
		var actual: Variant = _objects[binding["owner"]].get_ref().get(binding["field"])
		if typeof(actual) != typeof(binding["root"]) or not is_same(actual, binding["root"]) or not actual.is_read_only():
			return _invalidate("SOURCE_LEASE_ROOT_REPLACED")
	for name in _scalars:
		var object: RefCounted = _objects[name].get_ref()
		for field in _scalars[name]:
			if not is_same(object.get(field), _scalars[name][field]):
				return _invalidate("SOURCE_LEASE_EPOCH_OR_CONFIG_CHANGED")
	return {"ok": true, "ticket": _ticket.duplicate(true)}

func _capture_store_sources(actual: Dictionary) -> bool:
	if not _combined_store:
		return _capture_roots(actual, "store", ["_generation", "_prefab", "_bundle"])
	# This fixed graph is the composition's actual validation path. Do not freeze
	# detached configuration descriptors while leaving the child services mutable.
	if not _link_source(actual, "store", "_entry_store", "entry_store", Store) or not _link_source(actual, "store", "_surface_store", "surface_store", SurfaceStore):
		return false
	if not _link_source(actual, "surface_store", "_base", "surface_base", Store) or not _link_source(actual, "surface_store", "_rules", "surface_rules", SurfaceRules):
		return false
	if not _capture_roots(actual, "store", ["_initial_input_digests"]) or not _capture_roots(actual, "surface_rules", ["settings", "generation", "_initial_input_digests"]):
		return false
	for name in ["entry_store", "surface_base"]:
		if not _capture_roots(actual, name, ["_generation", "_prefab", "_bundle"]):
			return false
		if not _link_source(actual, name, "_layout_validator", name + "_layout", LayoutValidator, false) or not _link_source(actual, name + "_layout", "_inputs", name + "_layout_inputs", GenerationInputs):
			return false
		if not _link_source(actual, name, "_prefab_validator", name + "_prefab", PrefabValidator) or not _link_source(actual, name + "_prefab", "_generation", name + "_prefab_inputs", GenerationInputs):
			return false
		if not _capture_roots(actual, name + "_layout_inputs", ["data"]) or not _capture_roots(actual, name + "_prefab", ["_prefab"]) or not _capture_roots(actual, name + "_prefab_inputs", ["data"]):
			return false
	return true

func _link_source(actual: Dictionary, parent: String, field: String, name: String, script: Script, check_ready: bool = true) -> bool:
	var child: Variant = actual[parent].get(field)
	if not child is RefCounted or child.get_script() != script or (check_ready and not child.ready):
		return false
	actual[name] = child
	_object_links.append({"owner": parent, "field": field, "child": name})
	if check_ready:
		_ready_owners.append(name)
	return true

func _capture_roots(actual: Dictionary, name: String, fields: Array) -> bool:
	for field in fields:
		var value: Variant = actual[name].get(field)
		if not value is Dictionary and not value is Array:
			return false
		_roots.append({"owner": name, "field": field, "root": value})
	return true

func matches_save_owner(candidate: Object) -> bool:
	# Inspection only; this cannot attach a new owner to an existing lease.
	if candidate == null:
		return not _objects.has("save_owner")
	return is_instance_valid(candidate) and _objects.has("save_owner") and is_same(candidate, _objects["save_owner"].get_ref())

func bound_save_owner() -> Object:
	if not guard().get("ok", false) or not _objects.has("save_owner"):
		return null
	return _objects["save_owner"].get_ref()

func projection_settings(candidate: RefCounted) -> Dictionary:
	var checked := guard()
	if not checked["ok"]:
		return checked
	var settings: RefCounted = _objects["settings"].get_ref()
	if candidate == null or not candidate.ready or candidate._world_id != _world_id or not is_same(candidate._settings, settings):
		return _bad("SOURCE_LEASE_PROJECTION_CONFIG_MISMATCH")
	return {"ok": true, "settings": settings}

func world_view() -> Dictionary:
	# Internal readonly view. Root identity is checked before each frame operation.
	return _world_root

func dynamic_boundary() -> Dictionary:
	var checked := guard()
	if not checked["ok"]:
		return checked
	var space: RefCounted = _objects["space"].get_ref()
	var applied: Dictionary = space.validate_actor_frame_boundary()
	if not applied.get("ok", false):
		return applied
	return _dynamic_after_native()

func pending_tree_boundary(frame: Variant, ticket: Variant) -> Dictionary:
	var checked:=guard()
	if not checked.get("ok",false): return checked
	var owner: Object=bound_save_owner()
	var space: RefCounted=_objects["space"].get_ref()
	if owner==null or owner._save_profile!=6 or not frame is RefCounted or frame.get_script()!=load("res://scripts/actor/actor_frame_transaction.gd") or owner._bootstrap_frame!=frame or frame._source_lease!=self or frame._space!=space or not frame._tree_pending is Dictionary or not is_same(frame._tree_pending.get("ticket"),ticket) or frame._tree_pending.get("phase") not in ["detached","restoring"]: return _bad("SOURCE_TREE_PENDING_IDENTITY")
	if space.get_script()!=load("res://scripts/harvest/tree_terrain_space012.gd"): return _bad("SOURCE_TREE_PENDING_SPACE")
	checked=space.validate_completion_boundary(frame,ticket)
	if not checked.get("ok",false): return checked
	return _dynamic_after_native()

func ground_boundary(frame: Variant, ticket: Variant) -> Dictionary:
	# Separate synchronous profile6 capability, never a general busy bypass or
	# a detached-tree ticket. Original dynamic_boundary remains unchanged.
	var checked:=guard()
	if not checked.get("ok",false): return checked
	var owner: Object=bound_save_owner()
	var space: RefCounted=_objects["space"].get_ref()
	if owner==null or owner._save_profile!=6 or not frame is RefCounted or frame.get_script()!=load("res://scripts/actor/actor_frame_transaction.gd") or owner._bootstrap_frame!=frame or frame._source_lease!=self or frame._space!=space: return _bad("SOURCE_GROUND_FRAME_IDENTITY")
	checked=frame._ground_ticket_state(ticket,"validating")
	if not checked.get("ok",false) or checked.get("owner")!=owner or checked.get("service")!=owner._inventory_owner: return _bad("SOURCE_GROUND_TICKET_IDENTITY")
	if space.get_script()!=load("res://scripts/harvest/tree_terrain_space012.gd"): return _bad("SOURCE_GROUND_SPACE_IDENTITY")
	checked=space.validate_ground_boundary(frame,ticket)
	if not checked.get("ok",false): return checked
	return _dynamic_after_native()

func _dynamic_after_native() -> Dictionary:
	# Shared byte-identical authority/model/input/profile/active binding checks.
	# Both callers independently pass the original frozen guard and their exact
	# native proof. The ordinary entry point has no pending bypass.
	var authority: RefCounted=_objects["authority"].get_ref()
	var model: RefCounted=_objects["model"].get_ref()
	var space: RefCounted=_objects["space"].get_ref()
	var checked: Dictionary
	var authority_state: Dictionary = authority.persistent_state()
	# Keep the complete authority/profile and actor snapshot checks, including
	# inactive profiles. Only already-frozen world/source validation is replaced.
	for profile in authority_state.get("profiles", {}).values():
		if not profile is Dictionary:
			return _bad("SOURCE_DYNAMIC_PROFILE_INVALID")
		for field in ["player_profile_id", "player_instance_id", "display_name", "role", "secret_hash"]:
			if not profile.get(field) is String:
				return _bad("SOURCE_DYNAMIC_PROFILE_INVALID")
	checked = SandboxServerAuthority.validate_persistent_state(authority_state)
	if not checked.get("ok", false):
		return _bad("SOURCE_DYNAMIC_AUTHORITY_INVALID")
	if not _runtime_inputs_valid(model):
		return _bad("SOURCE_DYNAMIC_INPUT_STATE_INVALID")
	if not _actor_record_preflight_valid(model):
		return _bad("SOURCE_DYNAMIC_ACTOR_FIELDS_INVALID")
	var actor_state: Dictionary = model.persistent_state()
	checked = model.validate_persistent_state(actor_state)
	if not checked.get("ok", false):
		return checked
	if actor_state["world_id"] != _world_id or actor_state["clock"] != authority_state["world_seconds"]:
		return _bad("ACTOR_AUTHORITY_CLOCK_MISMATCH")
	var expected: Dictionary = {}
	for profile in authority_state["profiles"].values():
		expected[profile["player_instance_id"]] = true
	if actor_state["actors"].size() != expected.size():
		return _bad("ACTOR_PROFILE_SET_MISMATCH")
	for actor_id in actor_state["actors"]:
		if not expected.has(actor_id):
			return _bad("ACTOR_PROFILE_SET_MISMATCH")
		var actor: Dictionary = actor_state["actors"][actor_id]
		for address in [actor["layer"], actor["fallback"]["layer"]]:
			if not _layers.has(Address.key(address)):
				return _bad("ACTOR_LAYER_NOT_IN_LOADED_WORLD")
		for position in [actor["position"], actor["fallback"]["position"]]:
			var contained := Circle.contains(State.vector(position), _radius, _half)
			if not contained.get("ok", false) or not contained.get("inside", false):
				return _bad("ACTOR_COMPLETE_BODY_OUTSIDE_MAP")
	for peer_id in authority._peer_profiles:
		var profile_id: Variant = authority._peer_profiles[peer_id]
		if typeof(peer_id) != TYPE_INT or peer_id < 1 or not profile_id is String or not authority_state["profiles"].has(profile_id):
			return _bad("SOURCE_DYNAMIC_PEER_BINDING_INVALID")
	var public: Dictionary = authority.public_snapshot()
	var active: Array = []
	for player in public["players"].values():
		active.append(player["player_instance_id"])
	active.sort()
	if active != model.active_actor_ids() or active != space.active_actor_ids():
		return _bad("TRANSFER_ACTOR_BINDING_MISMATCH")
	for actor_id in active:
		var record: Dictionary = actor_state["actors"][actor_id]
		var native: Dictionary = space.actor_view(actor_id)
		if native.get("layer_key") != Address.key(record["layer"]) or native.get("position") != State.vector(record["position"]) or native.get("half_extent") != _half:
			return _bad("TRANSFER_ACTOR_BINDING_MISMATCH")
	return {"ok": true, "boundary": {"model": actor_state, "public": model.public_snapshot(), "inputs": model.frame_input_state(), "authority": authority_state, "authority_public": public, "terrain": _terrain_context, "native": space.frame_boundary_context()}}

func _actor_record_preflight_valid(model: RefCounted) -> bool:
	# persistent_record indexes every State field before validation, so missing
	# fields must fail here as well as unsafe older address/string comparisons.
	# These are dynamic actor fields, not a repeated static-world walk.
	for actor in model._actors.values():
		if not State.exact_fields(actor, State.FIELDS) or not actor.get("actor_id") is String or not State.exact_fields(actor.get("fallback"), ["layer", "position"]):
			return false
		for layer in [actor.get("layer"), actor["fallback"].get("layer")]:
			if not layer is Dictionary:
				return false
			for field in ["world_id", "reference_frame", "body_instance_id", "map_kind"]:
				if not layer.get(field) is String:
					return false
	return true

func _runtime_inputs_valid(model: RefCounted) -> bool:
	var active: Array = model.active_actor_ids()
	var inputs: Array = model._inputs.keys()
	var generations: Array = model._input_generations.keys()
	inputs.sort()
	generations.sort()
	if inputs != active or generations != active:
		return false
	for actor_id in active:
		var input: Variant = model._inputs[actor_id]
		var generation: Variant = model._input_generations[actor_id]
		if not input is RefCounted or input.get_script() != InputState or typeof(generation) != TYPE_INT or generation < 1 or generation > Inputs.MAX_EXACT_INTEGER:
			return false
		if input.sequence < 0 or input.sequence > Inputs.MAX_EXACT_INTEGER or not input.move_direction.is_finite() or not input.aim.is_finite() or input.pressed_action != "":
			return false
		if not State.exact_fields(input.held, ["dodge", "interact"]) or typeof(input.held["dodge"]) != TYPE_BOOL or typeof(input.held["interact"]) != TYPE_BOOL:
			return false
		if (input.sequence == 0 and input.fingerprint != "") or (input.sequence > 0 and not Inputs.digest(input.fingerprint)):
			return false
	return true

func release() -> void:
	_valid = false

func statistics() -> Dictionary:
	var current_valid: bool = guard().get("ok", false) if _valid else false
	return {"valid": current_valid, "full_validation_calls": _full_validation_calls, "hot_full_validation_calls": _hot_full_validation_calls, "guard_calls": _guard_calls, "setup_usec": _setup_usec}

func _validate_full_sources(authority: RefCounted, world: RefCounted, model: RefCounted, space: RefCounted, inputs: RefCounted, store: RefCounted, settings: RefCounted) -> Dictionary:
	_full_validation_calls += 1
	if _valid:
		_hot_full_validation_calls += 1
	var config := _validate_actual_configs(world, store, inputs, settings)
	if not config["ok"]:
		return config
	if not Store._world_text_types_valid(world.component) or not _actor_record_preflight_valid(model):
		return _bad("SOURCE_LEASE_TEXT_TYPE_INVALID")
	var budget := {"nodes": 0}
	if not _freezable(authority._profiles, false, 0, budget, []) or not _freezable(model._actors, false, 0, budget, []):
		return _bad("SOURCE_LEASE_DYNAMIC_INITIAL_GRAPH_INVALID")
	var base: Dictionary = authority.persistent_state()
	base["actor_component"] = model.persistent_state()
	base["world_component"] = world.component
	if not TerrainSession._legacy_text_types(base) or not TerrainSession._legacy_identity_slots(base) or not _runtime_inputs_valid(model):
		return _bad("SOURCE_LEASE_TEXT_TYPE_INVALID")
	return Transfer.new(authority, world, model, space, inputs)._validate_context()

func _validate_actual_configs(world: RefCounted, store: RefCounted, inputs: RefCounted, settings: RefCounted) -> Dictionary:
	var generation: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/generation_settings.json"))
	var prefab: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/prefab_settings.json"))
	var bundle: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_world_bundle011.json"))
	if not generation is Dictionary or not prefab is Dictionary or not bundle is Dictionary:
		return _bad("SOURCE_LEASE_APPROVED_DOCUMENT_UNAVAILABLE")
	var trusted := Store.new(generation, prefab, bundle)
	if not trusted.ready or not Store._same(world._generation, trusted._generation) or not Store._same(world._template, trusted._bundle["template"]):
		return _bad("SOURCE_LEASE_WORLD_CONFIG_MISMATCH")
	if _combined_store and not store.inputs_current():
		return _bad("SOURCE_LEASE_STORE_CONFIG_MISMATCH")
	for candidate in ([store._entry_store, store._surface_store._base] if _combined_store else [store]):
		for field in ["_generation", "_prefab", "_bundle", "_bundle_sha256"]:
			if not Store._same(candidate.get(field), trusted.get(field)):
				return _bad("SOURCE_LEASE_STORE_CONFIG_MISMATCH")
		if _combined_store and (not Store._same(candidate._layout_validator._inputs.data, trusted._generation) or not Store._same(candidate._prefab_validator._generation.data, trusted._generation) or not Store._same(candidate._prefab_validator._prefab, trusted._prefab)):
			return _bad("SOURCE_LEASE_STORE_VALIDATOR_CONFIG_MISMATCH")
	for actual in [inputs, settings]:
		var approved := Inputs.new()
		if not approved.load_file() or not Store._same(actual._data, approved._data) or not Store._same(actual._source_identity, approved._source_identity):
			return _bad("SOURCE_LEASE_ACTOR_CONFIG_MISMATCH")
	return {"ok": true}

func _freezable(value: Variant, allow_rid: bool, depth: int, budget: Dictionary, ancestors: Array) -> bool:
	budget["nodes"] += 1
	if depth > MAX_DEPTH or budget["nodes"] > MAX_NODES:
		return false
	if value is Dictionary or value is Array:
		for previous in ancestors:
			if is_same(value, previous):
				return false
		ancestors.append(value)
		if value is Dictionary:
			for key in value:
				if not key is String or not _freezable(value[key], allow_rid, depth + 1, budget, ancestors):
					ancestors.pop_back()
					return false
		else:
			for item in value:
				if not _freezable(item, allow_rid, depth + 1, budget, ancestors):
					ancestors.pop_back()
					return false
		ancestors.pop_back()
		return true
	return typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_STRING, TYPE_INT] or (typeof(value) == TYPE_FLOAT and is_finite(value)) or (allow_rid and typeof(value) == TYPE_RID)

func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for key in value:
			_freeze(value[key])
		value.make_read_only()
	elif value is Array:
		for item in value:
			_freeze(item)
		value.make_read_only()

func _invalidate(code: String) -> Dictionary:
	_valid = false
	return _bad(code)

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "recoverable_corruption": false}
