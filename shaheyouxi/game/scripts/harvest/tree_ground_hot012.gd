extends RefCounted
## Ground-only dependency and semantic checks. No ticket, publication, full-world
## cache, metric construction, or claim that a caller has a legal transaction.
## The actual Frame owns every such decision and supplies a one-call context.
const Full = preload("res://scripts/harvest/tree_full_admission012.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Combined = preload("res://scripts/inventory/inventory_world_session012.gd")
const TreeSession = preload("res://scripts/harvest/tree_world_session012.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
const Definition = preload("res://scripts/harvest/tree_definition012.gd")
const Budget = preload("res://scripts/harvest/tree_ground_budget012.gd")
const Profiles = preload("res://scripts/inventory/inventory_save_profiles012.gd")
const Cold = preload("res://scripts/inventory/inventory_cold_validator012.gd")
const TreeCold = preload("res://scripts/harvest/tree_cold_validator012.gd")
const Lease = preload("res://scripts/actor/actor_frozen_source_lease.gd")
const ActorInputs = preload("res://scripts/actor/actor_inputs.gd")
const Motion = preload("res://scripts/actor/actor_motion.gd")
const Native = preload("res://scripts/harvest/tree_native012.gd")
const FRAME_PATH := "res://scripts/actor/actor_frame_transaction.gd"
const OWNER_PATH := "res://scripts/actor/actor_terrain_network_main.gd"
const SERVICE_PATH := "res://scripts/harvest/tree_inventory_owner012.gd"
const SPACE_PATH := "res://scripts/harvest/tree_terrain_space012.gd"
var _bound_certificate: Dictionary = {}
var _bound_frame: WeakRef

func runtime_sources(frame: Variant, service: Variant, base: Variant, candidate: Variant) -> Dictionary:
	# Dynamic loads break the existing Frame -> TreeOwner -> helper import cycle.
	# No call to busy-rejecting _owner_inventory_guard/_inventory_service_ready.
	if not _script(frame, load(FRAME_PATH)) or not _script(service, load(SERVICE_PATH)):
		return _identity("TREE_GROUND_FRAME_OR_SERVICE_IDENTITY")
	var lease: Variant = frame._source_lease
	if not _script(lease, Lease) or not lease.guard().get("ok", false):
		return _identity("TREE_GROUND_SOURCE_LEASE")
	var owner: Object = lease.bound_save_owner()
	if not _owner_matches(owner, frame) or not is_same(owner._inventory_owner, service):
		return _identity("TREE_GROUND_OWNER_IDENTITY")
	if not owner._save_profile_valid() or owner._save_profile != 6 or owner._arguments.get("test_entry") != "true" or owner._arguments.get("tree_fixture_profile") != "isolated":
		return _identity("TREE_GROUND_PROFILE_IDENTITY")
	if owner._mode not in ["server", "host"] or owner._closing or owner._fatal_shutdown or not owner._live_failure_code.is_empty() or not owner._physics_runtime_ready:
		return _identity("TREE_GROUND_OWNER_NOT_READY")
	if not service.ready or not service._initialized or not service._busy or not service._completion_reservation.is_empty():
		return _identity("TREE_GROUND_SERVICE_PHASE")
	if not _script(owner._authority, Combined.Authority) or not is_same(frame._authority, owner._authority) or not is_same(service._authority, owner._authority):
		return _identity("TREE_GROUND_AUTHORITY_IDENTITY")
	var registry: Variant = owner._inventory_registry
	if not _registry_objects(registry, owner._terrain_session, owner._authority):
		return _identity("TREE_GROUND_REGISTRY_IDENTITY")
	var binding: Variant = frame._owner_profile_binding
	if not Core._fields(binding, ["profile", "registry", "validator", "inventory", "registry_config"]) or not binding.is_read_only() or typeof(binding["profile"]) != TYPE_INT or binding["profile"] != 6:
		return _identity("TREE_GROUND_FRAME_PROFILE_BINDING")
	if not _weak_matches(binding["registry"], registry) or not _weak_matches(binding["validator"], registry._tree_cold) or not _weak_matches(binding["inventory"], service):
		return _identity("TREE_GROUND_FRAME_PROFILE_BINDING")
	var description: Dictionary = registry.descriptor(6)
	if not description.get("ok", false) or description.get("store_script") != Profiles.BoundedStore or description.get("validator_script") != TreeCold or not _descriptor_matches(description, binding["registry_config"]):
		return _identity("TREE_GROUND_REGISTRY_CONFIGURATION")
	if not Core._fields(owner._inventory_runtime_binding, ["registry", "owner"]) or not owner._inventory_runtime_binding.is_read_only() or not is_same(owner._inventory_runtime_binding["registry"], registry) or not is_same(owner._inventory_runtime_binding["owner"], service):
		return _identity("TREE_GROUND_RUNTIME_BINDING")
	if not _script(owner._save_store, Profiles.BoundedStore) or not owner._save_store._lock_owned or not owner._save_store._write_ready or not registry.verify_binding(6, owner._save_store).get("ok", false):
		return _identity("TREE_GROUND_SAVE_STORE_BINDING")

	var inner: Variant = service._contract
	var outer: Variant = service._tree_contract
	if not Full.standard_graph(inner, outer) or not inner.ready or not outer.ready or not outer._binding_valid():
		return _identity("TREE_GROUND_VALIDATOR_GRAPH")
	if not is_same(inner._terrain, owner._terrain_session) or not is_same(outer._authority, owner._authority) or not inner._inventory.ready:
		return _identity("TREE_GROUND_VALIDATOR_LINKS")
	if inner._world_id != owner._authority.world_id or service._world_id != inner._world_id or inner._content_revision != owner._authority.catalogue_hash or inner._protocol != owner._authority.protocol_version:
		return _identity("TREE_GROUND_VALIDATOR_CONFIGURATION")
	if not _budget_matches(inner._budget_store, 5, inner._content_revision, inner._protocol) or not _budget_matches(outer._budget_store, 6, inner._content_revision, inner._protocol):
		return _identity("TREE_GROUND_BUDGET_STORE_BINDING")

	# _copy_core still constructs the actual candidate from the original fixed-SHA
	# file. Compare actual rules, not just caller-replaceable SHA string fields.
	var rule_values: Array = []
	for core in [candidate, service._core, inner._inventory]:
		if not _script(core, Core) or not core.ready or not core._tree_rules or core._rules_identity != Core.TREE_RULES_SHA256 or core._world_id != inner._world_id:
			return _identity("TREE_GROUND_CORE_BINDING")
		var rules: String = _small_exact(core._rules)
		if rules.is_empty(): return _identity("TREE_GROUND_CORE_RULES")
		rule_values.append(rules)
	if is_same(candidate, service._core) or rule_values[0] != rule_values[1] or rule_values[0] != rule_values[2] or rule_values[0] != outer._inventory_rules_token:
		return _identity("TREE_GROUND_CORE_RULES")
	var tree_rules: Array = []
	for ledger in [service._trees, outer._ledger]:
		if not _script(ledger, Ledger) or not ledger.ready or ledger._world_id != inner._world_id or str(ledger._seed) != outer._seed_decimal or not _script(ledger._definition, Definition) or not ledger._definition.ready or not ledger._definition._rules.is_read_only():
			return _identity("TREE_GROUND_LEDGER_BINDING")
		var rules: String = _small_exact(ledger._definition._rules)
		if rules.is_empty(): return _identity("TREE_GROUND_DEFINITION_RULES")
		tree_rules.append(rules)
	if tree_rules[0] != tree_rules[1] or not service._binding_valid():
		return _identity("TREE_GROUND_BUNDLE_OR_RULES_BINDING")

	var terrain_session: RefCounted = inner._terrain
	var legacy: RefCounted = terrain_session._legacy
	var world: RefCounted = legacy._world
	var stores: RefCounted = terrain_session._terrain_store
	if not terrain_session.ready or not legacy.ready or not world.ready or not stores.ready or not is_same(legacy, owner._actor_session) or not is_same(world, owner._world) or not is_same(stores, owner._terrain_store):
		return _identity("TREE_GROUND_TERRAIN_LINKS")
	if not is_same(frame._world, world) or not is_same(frame._model, owner._actor_model) or not is_same(frame._inputs, owner._actor_inputs) or not is_same(frame._space, owner._actor_space):
		return _identity("TREE_GROUND_FRAME_SOURCE_LINKS")
	var inputs: Variant = owner._actor_inputs
	var model: Variant = owner._actor_model
	var space: Variant = owner._actor_space
	if not _script(inputs, ActorInputs) or not inputs.ready or not _script(model, Motion) or not model.ready or not _script(model._settings, ActorInputs) or not model._settings.ready or not _script(space, load(SPACE_PATH)):
		return _identity("TREE_GROUND_ACTOR_SOURCE_OBJECTS")
	if not is_same(space._terrain_store, stores) or not is_same(space._service, service) or not _weak_matches(space._owner_ref, owner) or not space._tree_native_ready or not _script(space._tree_native, Native):
		return _identity("TREE_GROUND_NATIVE_SOURCE_LINKS")
	var native: RefCounted = space._tree_native
	if not native._ready or not native._confirmed or not native._detachment.is_empty() or not is_same(native._space, space) or not is_same(native._contract, outer) or not is_same(native._authority, owner._authority) or not is_same(native._terrain_store, stores):
		return _identity("TREE_GROUND_NATIVE_SOURCE_LINKS")
	if not _validation_objects_ready(world._layout_validator, world._prefab_validator) or not stores._entry_store.ready or not stores._surface_store.ready or not stores._surface_store._base.ready or not stores._surface_store._rules.ready:
		return _identity("TREE_GROUND_WORLD_SOURCE_READINESS")
	for entry in [stores._entry_store, stores._surface_store._base]:
		if not _validation_objects_ready(entry._layout_validator, entry._prefab_validator):
			return _identity("TREE_GROUND_TERRAIN_SOURCE_READINESS")

	# The world validators and legacy ActorSession own independent document copies
	# absent from SourceLease's roots. Anchor them to its ACTUAL frozen sources.
	var generation: String = _small_exact(world._generation)
	var prefab: String = _small_exact(stores._entry_store._prefab)
	var actor_document: String = _small_exact(inputs._data)
	if generation.is_empty() or prefab.is_empty() or actor_document.is_empty() or not world._generation.is_read_only() or not stores._entry_store._prefab.is_read_only() or not inputs._data.is_read_only():
		return _identity("TREE_GROUND_FROZEN_CONFIGURATION")
	if _small_exact(world._layout_validator._inputs.data) != generation or _small_exact(world._prefab_validator._generation.data) != generation or _small_exact(world._prefab_validator._prefab) != prefab or _small_exact(legacy._actor_document) != actor_document:
		return _identity("TREE_GROUND_CONFIGURATION_DRIFT")
	var half: float = inputs.parameter("actor_diameter_cells") / 2.0
	if not is_finite(half) or not is_same(legacy._half, half) or not is_same(space._half, half) or not is_same(frame._half, half):
		return _identity("TREE_GROUND_ACTOR_GEOMETRY_DRIFT")
	if not Core._fields(base, Full.Terrain.FIELDS) or not base["actor_component"] is Dictionary:
		return _identity("TREE_GROUND_BASE_SOURCE_SHAPE")
	var world_root: Dictionary = lease.world_view()
	var terrain_root: Variant = owner._terrain_component
	if not world_root.is_read_only() or not terrain_root is Dictionary or not terrain_root.is_read_only() or not is_same(world_root, world.component) or not is_same(base["world_component"], world_root) or not is_same(base["terrain_component"], terrain_root):
		return _identity("TREE_GROUND_STATIC_ROOT_IDENTITY")

	# Original full5 dependency gates remain live: four terrain JSON reads and two
	# actor JSON reads, including the original complete actor source identity.
	if not stores.inputs_current():
		return _identity("TREE_GROUND_TERRAIN_DISK_SOURCE_DRIFT")
	var fresh_inputs := ActorInputs.new()
	if not fresh_inputs.load_document(legacy._actor_document):
		return _identity("TREE_GROUND_ACTOR_DISK_SOURCE_DRIFT")
	var actor_identity: String = _small_exact(fresh_inputs.source_identity())
	if actor_identity.is_empty() or actor_identity != _small_exact(base["actor_component"].get("source_identity")) or actor_identity != _small_exact(inputs.source_identity()):
		return _identity("TREE_GROUND_ACTOR_SOURCE_IDENTITY_DRIFT")

	# Stable services only. Source/current Core, live Ledger and live Definition
	# belong to this transaction's Frame ticket, never the long-lived nodes map.
	var nodes: Dictionary = {
		"helper": self, "frame": frame, "owner": owner, "lease": lease,
		"service": service, "authority": owner._authority, "registry": registry,
		"cold": registry._cold, "tree_cold": registry._tree_cold,
		"tree_cold_binding": registry._tree_cold._binding, "save_store": owner._save_store,
		"inner": inner, "outer": outer, "validator_core": inner._inventory,
		"validator_ledger": outer._ledger, "validator_definition": outer._ledger._definition,
		"budget5": inner._budget_store, "budget6": outer._budget_store,
		"terrain_session": terrain_session, "legacy": legacy, "world": world,
		"actor_inputs": inputs, "actor_model": model, "actor_settings": model._settings,
		"space": space, "native": native, "terrain_store": stores,
		"entry_store": stores._entry_store, "surface_store": stores._surface_store,
		"surface_base": stores._surface_store._base, "surface_rules": stores._surface_store._rules,
	}
	for pair in [["world", world], ["entry", stores._entry_store], ["surface_base", stores._surface_store._base]]:
		var source: RefCounted = pair[1]
		var prefix: String = pair[0]
		nodes[prefix + "_layout"] = source._layout_validator
		nodes[prefix + "_layout_inputs"] = source._layout_validator._inputs
		nodes[prefix + "_prefab"] = source._prefab_validator
		nodes[prefix + "_prefab_inputs"] = source._prefab_validator._generation
	var registry_metadata: Dictionary = description.duplicate(false)
	registry_metadata.erase("store_script")
	registry_metadata.erase("validator_script")
	var config: Dictionary = {
		"profile": 6, "world_id": inner._world_id, "seed_decimal": outer._seed_decimal,
		"content_revision": inner._content_revision, "protocol": inner._protocol,
		"registry": registry_metadata, "core_rules": rule_values[0], "tree_rules": tree_rules[0],
		"rules_identity": Core.TREE_RULES_SHA256, "tree_rules_enabled": true,
		"actor_identity": actor_identity, "actor_half": half,
		"budget5_schema": 5, "budget6_schema": 6, "maximum_bytes": Budget.MAX_BYTES,
		"exact_scalars": true,
	}
	if _small_exact(config).is_empty(): return _identity("TREE_GROUND_CONFIGURATION_TYPE")
	return {"ok": true, "owner": owner, "inner": inner, "outer": outer,
		"world": world_root, "terrain": terrain_root, "nodes": nodes, "config": config}

func validate_dynamic_and_budget(context: Dictionary, base: Dictionary, inventory: Dictionary, trees: Dictionary, metrics: Dictionary) -> Dictionary:
	# This only consumes Frame-supplied measurements. It never computes or retains
	# a replacement metric set and cannot turn a fabricated context into authority.
	var inner: Variant = context.get("inner")
	var outer: Variant = context.get("outer")
	if not context.get("ok", false) or not _script(inner, Combined) or not _script(outer, TreeSession) or not inner.ready or not outer.ready or not is_same(outer._inner, inner) or not outer._binding_valid():
		return _identity("TREE_GROUND_DYNAMIC_CONTEXT")
	if not _script(inner._inventory, Core) or not inner._inventory.ready or not _script(outer._ledger, Ledger) or not outer._ledger.ready or not _script(outer._ledger._definition, Definition) or not outer._ledger._definition.ready:
		return _identity("TREE_GROUND_DYNAMIC_VALIDATORS")
	if not _budget_matches(inner._budget_store, 5, inner._content_revision, inner._protocol) or not _budget_matches(outer._budget_store, 6, inner._content_revision, inner._protocol):
		return _identity("TREE_GROUND_BUDGET_STORE_BINDING")
	if not is_same(base.get("world_component"), context.get("world")) or not is_same(base.get("terrain_component"), context.get("terrain")):
		return _identity("TREE_GROUND_DYNAMIC_STATIC_ROOTS")
	if not Core._fields(base, Full.Terrain.FIELDS):
		return _semantic({"code": "INVENTORY_WORLD_BASE_CONTRACT_INVALID"})
	# Data-only preflight covers dynamic values, never the large static roots.
	if not Full.data_only([inventory, trees]):
		return _semantic({"code": "TREE_GROUND_DYNAMIC_TYPE_OR_BUDGET"})
	var checked: Dictionary = outer._ledger.validate_snapshot(trees)
	if not checked.get("ok", false): return _semantic(checked)
	if typeof(base["world_id"]) != TYPE_STRING or base["world_id"] != inner._world_id:
		return _semantic({"code": "INVENTORY_WORLD_ID_MISMATCH"})
	checked = inner._inventory.validate_snapshot(inventory)
	if not checked.get("ok", false): return _semantic(checked)
	if inventory["schema_version"] in [2, 3] and inventory["ground_clock"] != base["world_seconds"]:
		return _semantic({"code": "INVENTORY_GROUND_WORLD_CLOCK_MISMATCH"})
	if not base["profiles"] is Dictionary or inventory["players"].size() != base["profiles"].size():
		return _semantic({"code": "INVENTORY_WORLD_PROFILE_MISMATCH"})
	for profile in base["profiles"]:
		if not inventory["players"].has(profile):
			return _semantic({"code": "INVENTORY_WORLD_PROFILE_MISMATCH"})
	# Shallow root assembly preserves both original static Dictionary identities.
	# Frame independently proves current authority/actor and native boundaries.
	var value: Dictionary = base.duplicate(false)
	value["inventory_contract"] = Combined.CONTRACT
	value["inventory_component"] = inventory
	value["tree_contract"] = TreeSession.CONTRACT
	value["tree_component"] = trees
	checked = outer._validate_tree_dynamic_state(value)
	if not checked.get("ok", false): return _semantic(checked)
	var reduced6: Dictionary = value.duplicate(false)
	reduced6["world_component"] = null
	reduced6["terrain_component"] = null
	var reduced5: Dictionary = reduced6.duplicate(false)
	for field in TreeSession.EXTRA_FIELDS: reduced5.erase(field)
	checked = Budget.measure_dual(inner._budget_store, outer._budget_store, reduced5, reduced6, metrics)
	if not checked.get("ok", false): return _semantic(checked)
	return {"ok": true, "measurement_only": true, "budgets": checked}

func bind_certificate(frame: Variant, certificate: Variant) -> bool:
	# Called only AFTER Frame's full transaction postcondition. This association
	# detects unilateral replacement; it does not certify a transaction itself.
	if not _certificate_owner(frame, certificate): return false
	_bound_certificate = certificate
	_bound_frame = weakref(frame)
	return true

func certificate_matches(frame: Variant, certificate: Variant) -> bool:
	return _weak_matches(_bound_frame, frame) and _certificate_owner(frame, certificate) and is_same(_bound_certificate, certificate)

func clear_certificate() -> void:
	_bound_certificate = {}
	_bound_frame = null

static func _certificate_owner(frame: Variant, certificate: Variant) -> bool:
	if not _script(frame, load(FRAME_PATH)) or not certificate is Dictionary or certificate.is_empty() or not certificate.is_read_only() or not is_same(frame.get("_ground_certificate"), certificate): return false
	if not _script(frame._source_lease, Lease): return false
	var owner: Object = frame._source_lease.bound_save_owner()
	return _owner_matches(owner, frame)

static func _owner_matches(owner: Variant, frame: Variant) -> bool:
	return owner is Node and is_instance_valid(owner) and not owner.is_queued_for_deletion() and owner.get_script() == load(OWNER_PATH) and is_same(owner._bootstrap_frame, frame)

static func _registry_objects(registry: Variant, terrain: Variant, authority: Variant) -> bool:
	if not _script(registry, Profiles) or not registry.ready or not is_same(registry._terrain, terrain) or not is_same(registry._authority, authority): return false
	if not _script(registry._cold, Cold) or not registry._cold.binding_matches(terrain, authority): return false
	if not _script(registry._tree_cold, TreeCold) or not _script(registry._tree_cold._binding, Cold) or not registry._tree_cold.binding_matches(terrain, authority): return false
	return registry._binding_valid()

static func _descriptor_matches(actual: Dictionary, expected: Variant) -> bool:
	if not expected is Dictionary or actual.get("store_script") != expected.get("store_script") or actual.get("validator_script") != expected.get("validator_script"): return false
	var a: Dictionary = actual.duplicate(false)
	var b: Dictionary = expected.duplicate(false)
	for field in ["store_script", "validator_script"]:
		a.erase(field)
		b.erase(field)
	var token: String = _small_exact(a)
	return not token.is_empty() and token == _small_exact(b)

static func _validation_objects_ready(layout: Variant, prefab: Variant) -> bool:
	return _script(layout, Full.Layout) and _script(layout._inputs, Full.Inputs) and layout._inputs.ready and _script(prefab, Full.Prefab) and prefab.ready and _script(prefab._generation, Full.Inputs) and prefab._generation.ready

static func _budget_matches(store: Variant, schema: int, content: String, protocol: int) -> bool:
	return _script(store, Full.Store) and store._schema_version == schema and store._maximum_bytes == Budget.MAX_BYTES and store._exact_scalars and store._content_revision == content and store._network_protocol_version == protocol

static func _script(value: Variant, expected: Script) -> bool:
	return expected != null and value is RefCounted and is_instance_valid(value) and value.get_script() == expected

static func _weak_matches(reference: Variant, actual: Variant) -> bool:
	return reference is WeakRef and actual != null and is_same(reference.get_ref(), actual)

static func _small_exact(value: Variant) -> String:
	# Core._exact alone returns the nonempty text "null" when Codec rejects.
	# Validate first, so two invalid object/cycle/budget graphs can never match.
	var encoded: Dictionary = Core.Codec.encode(value)
	return JSON.stringify(encoded.get("value"), "", true, true) if encoded.get("ok", false) else ""

static func _identity(code: String) -> Dictionary:
	return {"ok": false, "code": code, "failure_kind": "identity", "recoverable_corruption": false}

static func _semantic(result: Dictionary) -> Dictionary:
	var failure: Dictionary = result.duplicate(false)
	failure["ok"] = false
	failure["failure_kind"] = "semantic"
	failure["recoverable_corruption"] = false
	return failure
