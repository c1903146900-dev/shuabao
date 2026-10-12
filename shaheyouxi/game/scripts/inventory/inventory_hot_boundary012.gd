extends RefCounted
## Narrow in-memory Frame transaction validator. Full load/save stay unchanged.
## Static graphs are the actual recursively-readonly SourceLease roots. Dynamic
## authority/actor/inventory are revalidated, not a cached mutable snapshot.
const SourceLease = preload("res://scripts/actor/actor_frozen_source_lease.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Combined = preload("res://scripts/inventory/inventory_world_session012.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const FRAME_PATH := "res://scripts/actor/actor_frame_transaction.gd"
var _cache: Dictionary = {}
var _failed := false
var _cache_ready := false
var _full_checks := 0
var _hot_checks := 0
var _last_bytes := -1
var _last_nodes := -1

func validate(base: Dictionary, inventory: Dictionary, service: RefCounted, context: Dictionary) -> Dictionary:
	if _failed: return _bad("INVENTORY_HOT_CONTEXT_INVALIDATED")
	var binding := _context(base, service, context)
	if not binding.get("ok", false): return _invalidate(str(binding.get("code", "INVENTORY_HOT_BINDING")))
	var contract: RefCounted = service._contract
	if _cache_ready and not _cache_matches(base, service, context, binding["ticket"]): return _invalidate("INVENTORY_HOT_CACHE_BINDING_CHANGED")
	# Whole small inventory validation still covers every unique/protected ID,
	# stack/lot/timer/trajectory, player/chest and external-ownership collision.
	var checked: Dictionary = contract._inventory.validate_snapshot(inventory)
	if not checked.get("ok", false): return checked
	if inventory["schema_version"] == 2 and inventory["ground_clock"] != base["world_seconds"]: return _bad("INVENTORY_GROUND_WORLD_CLOCK_MISMATCH")
	if inventory["players"].size() != base["profiles"].size(): return _bad("INVENTORY_WORLD_PROFILE_MISMATCH")
	for profile in base["profiles"]:
		if not inventory["players"].has(profile): return _bad("INVENTORY_WORLD_PROFILE_MISMATCH")
	if _cache.is_empty():
		# Cold proof includes the full payload depth/node/byte limits at the actual
		# nested location, as well as all original combined-state checks.
		_full_checks += 1
		checked = contract.combine(base, inventory)
		if not checked.get("ok", false): return checked
		checked.clear() # Full candidate was validation-only; do not retain a second world graph.
		var world := encoded_measure(base["world_component"])
		var terrain := encoded_measure(base["terrain_component"])
		var empty := encoded_measure(null)
		if not world.get("ok", false) or not terrain.get("ok", false) or not empty.get("ok", false): return _invalidate("INVENTORY_HOT_STATIC_CODEC")
		_cache = {"lease":weakref(context["lease"]),"frame":weakref(context["frame"]),"service":weakref(service),"contract":weakref(contract),"budget_store":weakref(contract._budget_store),"world":base["world_component"],"terrain":base["terrain_component"],"ticket":binding["ticket"],"rules_token":Core._exact(contract._inventory._rules),"bytes_delta":world["escaped_bytes"]+terrain["escaped_bytes"]-2*empty["escaped_bytes"],"nodes_delta":world["nodes"]+terrain["nodes"]-2}
		_cache["ticket"].make_read_only()
		_cache.make_read_only()
		_cache_ready = true
	var measured: Dictionary = candidate_measure(contract._budget_store, base, inventory, _cache["bytes_delta"], _cache["nodes_delta"])
	_last_bytes = int(measured.get("envelope_bytes",-1))
	_last_nodes = int(measured.get("codec_nodes",-1))
	if not measured.get("ok",false): return measured
	_hot_checks += 1
	return measured

func _cache_matches(base: Dictionary, service: RefCounted, context: Dictionary, ticket: Dictionary) -> bool:
	if not _cache.is_read_only() or not Core._fields(_cache,["lease","frame","service","contract","budget_store","world","terrain","ticket","rules_token","bytes_delta","nodes_delta"]): return false
	for name in ["lease","frame","service","contract","budget_store"]:
		if not _cache[name] is WeakRef: return false
	return _cache["lease"].get_ref() == context["lease"] and _cache["frame"].get_ref() == context["frame"] and _cache["service"].get_ref() == service and _cache["contract"].get_ref() == service._contract and _cache["budget_store"].get_ref() == service._contract._budget_store and _cache["ticket"] == ticket and is_same(_cache["world"],base["world_component"]) and is_same(_cache["terrain"],base["terrain_component"]) and _cache["rules_token"] == Core._exact(service._contract._inventory._rules)

func _context(base: Dictionary, service: RefCounted, context: Dictionary) -> Dictionary:
	if not Core._fields(context,["frame","lease"]) or service == null or service.get_script() == null or service.get_script().resource_path != "res://scripts/inventory/inventory_owner012.gd" or not service._binding_valid() or not service._initialized or service._contract == null or service._contract.get_script() != Combined or not service._contract.ready:
		return _bad("INVENTORY_HOT_BINDING")
	var lease: Variant = context["lease"]
	var frame: Variant = context["frame"]
	if not lease is RefCounted or lease.get_script() != SourceLease or not frame is RefCounted or frame.get_script() == null or frame.get_script().resource_path != FRAME_PATH or frame._source_lease != lease:
		return _bad("INVENTORY_HOT_FRAME_IDENTITY")
	var guarded: Dictionary = lease.guard()
	if not guarded.get("ok", false): return guarded
	var owner: Object = lease.bound_save_owner()
	if owner == null or owner._bootstrap_frame != frame or owner._inventory_owner != service or owner._save_profile != 5 or not owner._inventory_registry_ready() or owner._inventory_runtime_binding.get("owner") != service or owner._inventory_runtime_binding.get("registry") != owner._inventory_registry:
		return _bad("INVENTORY_HOT_OWNER_IDENTITY")
	if not frame.fatal_error.is_empty() or frame._initial_closed or not frame._bootstrap_presence.is_empty() or not frame._initial_boundary.is_empty() or not frame._sealed.is_empty() or frame._lineage.is_empty():
		return _bad("INVENTORY_HOT_FRAME_NOT_CONFIRMED")
	var profile_binding: Dictionary = frame._owner_profile_binding
	if not Core._fields(profile_binding,["profile","registry","validator","inventory","registry_config"]) or profile_binding.get("profile") != 5 or not profile_binding["inventory"] is WeakRef or not profile_binding["registry"] is WeakRef or not profile_binding["validator"] is WeakRef or profile_binding["inventory"].get_ref() != service or profile_binding["registry"].get_ref() != owner._inventory_registry or profile_binding["validator"].get_ref() != owner._inventory_registry._cold or profile_binding["registry_config"] != owner._inventory_registry.descriptor(5) or frame._inventory_lineage != service.boundary_token():
		return _bad("INVENTORY_HOT_INVENTORY_LINEAGE")
	var contract: RefCounted = service._contract
	if contract._terrain != owner._terrain_session or contract._terrain.get_script() != Combined.TerrainSession or not contract._terrain.ready or contract._inventory == null or contract._inventory.get_script() != Core or not contract._inventory.ready or contract._inventory._world_id != service._world_id or contract._world_id != service._world_id:
		return _bad("INVENTORY_HOT_CONTRACT_CHANGED")
	var budget: RefCounted = contract._budget_store
	if budget == null or budget.get_script() != Combined.SaveStore or budget._schema_version != Combined.SCHEMA or not budget._exact_scalars or budget._maximum_bytes != Combined.MAX_BYTES or budget._content_revision != service._catalogue_hash or budget._network_protocol_version != service._protocol:
		return _bad("INVENTORY_HOT_BUDGET_BINDING_CHANGED")
	if not Core._fields(base,Combined.TerrainSession.FIELDS) or not base["world_component"] is Dictionary or not base["terrain_component"] is Dictionary or not is_same(base["world_component"],lease.world_view()) or not is_same(base["terrain_component"],owner._terrain_component) or not base["world_component"].is_read_only() or not base["terrain_component"].is_read_only():
		return _bad("INVENTORY_HOT_STATIC_ROOT_CHANGED")
	var dynamic: Dictionary = lease.dynamic_boundary()
	if not dynamic.get("ok", false) or dynamic["boundary"] != frame._lineage: return _bad("INVENTORY_HOT_DYNAMIC_LINEAGE_CHANGED")
	var authority_part := base.duplicate(false)
	authority_part.erase("world_component")
	authority_part.erase("terrain_component")
	authority_part.erase("actor_component")
	if authority_part != dynamic["boundary"]["authority"] or base["actor_component"] != dynamic["boundary"]["model"]: return _bad("INVENTORY_HOT_DYNAMIC_BASE_CHANGED")
	return {"ok":true,"ticket":guarded["ticket"].duplicate(true)}

static func candidate_measure(store: RefCounted, base: Dictionary, inventory: Dictionary, bytes_delta: int, nodes_delta: int) -> Dictionary:
	var reduced: Dictionary = base.duplicate(false)
	reduced["world_component"] = null
	reduced["terrain_component"] = null
	reduced["inventory_contract"] = Combined.CONTRACT
	reduced["inventory_component"] = inventory
	var envelope: String = store._encode(reduced, Core.MAX_SEQUENCE, "manual", "W".repeat(Combined.BoundedStore.MAX_REASON), 63)
	if envelope.is_empty(): return _bad("INVENTORY_WORLD_FINAL_ENVELOPE_TOO_LARGE")
	var size: int = envelope.to_utf8_buffer().size() + bytes_delta
	if size > Combined.MAX_BYTES: return {"ok":false,"code":"INVENTORY_WORLD_FINAL_ENVELOPE_TOO_LARGE","envelope_bytes":size}
	# Count original Variant value nodes through the ACTUAL tagged payload. The
	# metadata/root/state are included; tag arrays and dictionary keys are not.
	var outer: Dictionary = JSON.parse_string(envelope)
	var tagged: Array = JSON.parse_string(outer["payload_json"])
	var nodes: int = encoded_nodes(tagged) + nodes_delta
	if nodes > Codec.MAX_NODES: return {"ok":false,"code":"INVENTORY_WORLD_FINAL_ENVELOPE_TOO_LARGE","envelope_bytes":size,"codec_nodes":nodes}
	return {"ok":true,"hot_boundary":true,"envelope_bytes":size,"codec_nodes":nodes}

static func encoded_measure(value: Variant) -> Dictionary:
	var encoded: Dictionary = Codec.encode(value)
	if not encoded.get("ok", false): return encoded
	var payload_fragment: String = JSON.stringify(encoded["value"], "", true, true)
	return {"ok":true,"escaped_bytes":JSON.stringify(payload_fragment,"",true,true).to_utf8_buffer().size(),"nodes":encoded_nodes(encoded["value"])}

static func encoded_nodes(tagged: Array) -> int:
	var count: int = 1
	if tagged[0] == "dict":
		for pair in tagged[1]: count += encoded_nodes(pair[1])
	elif tagged[0] == "array":
		for child in tagged[1]: count += encoded_nodes(child)
	return count

func statistics() -> Dictionary:
	return {"full_checks":_full_checks,"hot_checks":_hot_checks,"last_envelope_bytes":_last_bytes,"last_codec_nodes":_last_nodes,"invalidated":_failed}
func _invalidate(code: String) -> Dictionary:
	_failed = true
	return _bad(code)
static func _bad(code: String) -> Dictionary:
	return {"ok":false,"code":code,"recoverable_corruption":false}
