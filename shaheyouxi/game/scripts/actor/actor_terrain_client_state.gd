extends RefCounted
## Explicit new4 read-only adapter. The old3 exact parser is unchanged; stripping
## extension fields happens only here after validation, never as fallback.
const Legacy = preload("res://scripts/actor/actor_client_state.gd")
const TerrainProjection = preload("res://scripts/actor/actor_terrain_public_projection.gd")
const Store = preload("res://scripts/terrain/combined_terrain_store.gd")
const EntryStore = preload("res://scripts/terrain/required_entry_terrain_store.gd")
const Session = preload("res://scripts/actor/actor_session_state.gd")
const State = preload("res://scripts/actor/actor_state.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const WIRE_CONTRACT := "sandbox011-new4-public-terrain-v2"
const REFERENCE_CONTRACT := "011-new4-terrain-reference-v1"
const MAX_CELLS := 8192 # Wire-resource ceiling, not world certification.
const PUBLIC_FIELDS := ["contract", "world_id", "terrain_contract", "artifact_sha256", "world_component_sha256", "cells", "objects", "formal_world_allowed", "projection_sha256"]
var ready: bool = false
var last_error: String = ""
var _legacy := Legacy.new()
var _terrain: Dictionary = {}
var _consume_profile: Dictionary = {"accepted_count": 0, "tree_usec": 0, "binding_usec": 0, "legacy_usec": 0, "total_usec": 0, "max_total_usec": 0, "first_total_usec": 0, "first_packet_variant_bytes": 0}

func configure(world: RefCounted, inputs: RefCounted, network_settings: Dictionary) -> Dictionary:
	var result: Dictionary = _legacy.configure(world, inputs, network_settings)
	ready = _legacy.ready
	last_error = _legacy.last_error
	return result

func consume(value: Variant, expected_epoch: String = "") -> Dictionary:
	var profile_start: int = Time.get_ticks_usec()
	if not ready:
		return _reject("TERRAIN_CLIENT_NOT_CONFIGURED")
	var fields: Array = Legacy.SNAPSHOT_FIELDS.duplicate()
	fields.append("terrain_public")
	var full_packet: bool = State.exact_fields(value, fields)
	var reference_fields: Array = Legacy.SNAPSHOT_FIELDS.duplicate()
	reference_fields.append("terrain_reference")
	if not full_packet and not State.exact_fields(value, reference_fields):
		return _reject("TERRAIN_CLIENT_SNAPSHOT_FIELDS_INVALID")
	var tree_error: String = _legacy._tree_error(value, 0, {"nodes": 0})
	if not tree_error.is_empty():
		return _reject(tree_error)
	if not value["world_id"] is String or not SandboxServerAuthority._valid_id(value["world_id"], "world_"):
		return _reject("TERRAIN_CLIENT_WORLD_INVALID")
	var profile_tree_done: int = Time.get_ticks_usec()
	var terrain: Variant = value["terrain_public"] if full_packet else _terrain
	if _terrain.is_empty():
		if not full_packet:
			return _reject("TERRAIN_CLIENT_BASELINE_REQUIRED")
		# Validate the component before traversing it, without committing either
		# cache. Legacy.consume performs its remaining exact-envelope checks below.
		if Session._unknown_world_contract(value["world_component"]):
			return _reject("TERRAIN_CLIENT_WORLD_INVALID")
		var world_check: Dictionary = _legacy._world.validate_component(value["world_component"], value["world_id"])
		if not world_check.get("ok", false) or not validate_public(terrain, value["world_id"], value["world_component"]):
			return _reject("TERRAIN_CLIENT_PUBLIC_INVALID")
	else:
		# Initial-static data cannot change underneath this session. Equal data
		# needs neither rehashing nor a second retained deep copy.
		if not full_packet and not EntryStore._same(value["terrain_reference"], reference_for(_terrain)):
			return _reject("TERRAIN_CLIENT_REFERENCE_MISMATCH")
		if (full_packet and not EntryStore._same(terrain, _terrain)) or not EntryStore._same(value["world_component"], _legacy._cache["world_component"]):
			return _reject("TERRAIN_CLIENT_STATIC_TERRAIN_CHANGED")
	var legacy_value: Dictionary = {}
	for field in Legacy.SNAPSHOT_FIELDS:
		legacy_value[field] = value[field]
	var profile_binding_done: int = Time.get_ticks_usec()
	var result: Dictionary = _legacy.consume(legacy_value, expected_epoch)
	var profile_legacy_done: int = Time.get_ticks_usec()
	if not result.get("ok", false):
		return _reject(str(result.get("code", "TERRAIN_CLIENT_LEGACY_INVALID")))
	if _terrain.is_empty():
		_terrain = terrain.duplicate(true)
	last_error = ""
	var elapsed: int = Time.get_ticks_usec() - profile_start
	_consume_profile["accepted_count"] += 1
	_consume_profile["tree_usec"] += profile_tree_done - profile_start
	_consume_profile["binding_usec"] += profile_binding_done - profile_tree_done
	_consume_profile["legacy_usec"] += profile_legacy_done - profile_binding_done
	_consume_profile["total_usec"] += elapsed
	_consume_profile["max_total_usec"] = maxi(_consume_profile["max_total_usec"], elapsed)
	if _consume_profile["accepted_count"] == 1:
		_consume_profile["first_total_usec"] = elapsed
		_consume_profile["first_packet_variant_bytes"] = var_to_bytes(value).size()
	return result

func consume_statistics() -> Dictionary:
	return _consume_profile.duplicate(true)

static func reference_for(public: Dictionary) -> Dictionary:
	return {"contract": REFERENCE_CONTRACT, "world_id": public["world_id"], "terrain_contract": public["terrain_contract"], "artifact_sha256": public["artifact_sha256"], "projection_sha256": public["projection_sha256"], "world_component_sha256": public["world_component_sha256"]}

func terrain_snapshot() -> Dictionary:
	return _terrain.duplicate(true)

func matches_wire_snapshot(value: Variant) -> bool:
	if _terrain.is_empty() or not value is Dictionary:
		return false
	var fields: Array = Legacy.SNAPSHOT_FIELDS.duplicate()
	fields.append("terrain_public")
	var full: bool = State.exact_fields(value, fields)
	var references: Array = Legacy.SNAPSHOT_FIELDS.duplicate()
	references.append("terrain_reference")
	if not full and not State.exact_fields(value, references):
		return false
	var static_matches: bool = EntryStore._same(value["terrain_public"], _terrain) if full else EntryStore._same(value["terrain_reference"], reference_for(_terrain))
	if not static_matches:
		return false
	for field in Legacy.SNAPSHOT_FIELDS:
		if not EntryStore._same(value[field], _legacy._cache[field]):
			return false
	return true

func snapshot() -> Dictionary:
	var result: Dictionary = _legacy.snapshot()
	if not result.is_empty():
		result["terrain_public"] = _terrain.duplicate(true)
	return result

func world_component_snapshot() -> Dictionary:
	# Avoid copying the entire terrain merely to feed the unchanged world view.
	return _legacy._cache.get("world_component", {}).duplicate(true)

func public_actor(actor_id: String) -> Dictionary:
	return _legacy._cache.get("actor_public", {}).get("actors", {}).get(actor_id, {}).duplicate(true)

func input_checkpoint(profile_id: Variant, peer_id: Variant) -> Dictionary:
	return _legacy.input_checkpoint(profile_id, peer_id)

# component must already pass the configured World validator. This helper is
# a cross-binding check, not an arbitrary untrusted-world parser.
static func validate_public(value: Variant, world_id: Variant, component: Dictionary) -> bool:
	if not State.exact_fields(value, PUBLIC_FIELDS) or not world_id is String or value["world_id"] != world_id or value["contract"] != TerrainProjection.CONTRACT or value["terrain_contract"] != Store.CONTRACT or not EntryStore._same(value["formal_world_allowed"], false):
		return false
	if not EntryStore._hash(value["world_component_sha256"]) or value["world_component_sha256"] != EntryStore.digest(component) or not EntryStore._hash(value["artifact_sha256"]) or not EntryStore._hash(value["projection_sha256"]) or not value["cells"] is Array or value["cells"].is_empty() or value["cells"].size() > MAX_CELLS or not value["objects"] is Array or value["objects"].size() > MAX_CELLS:
		return false
	var layers: Dictionary = Session._loaded_layers(component)
	var expected_h1: Array = []
	var h0: Array = []
	for instance in component["prefab_instances"]:
		for object in instance["objects"]:
			if object["plane"] == "H1":
				expected_h1.append({"layer": object["layer"].duplicate(true), "rect": object["rect"].duplicate(), "plane": "H1", "object_instance_id": object["instance_id"], "content_id": object["content_id"], "content_namespace": object["content_namespace"], "is_liquid": object["is_liquid"], "blocking": object["blocking"]})
			elif object["plane"] == "H0":
				h0.append(object)
	if value["objects"] != expected_h1:
		return false
	var seen: Dictionary = {}
	for row in value["cells"]:
		if not State.exact_fields(row, ["layer", "cell", "plane", "ground"]) or not Address.valid_layer(row["layer"]) or row["layer"]["world_id"] != world_id or row["plane"] != "H0" or not row["cell"] is Array or row["cell"].size() != 2:
			return false
		for number in row["cell"]:
			if typeof(number) != TYPE_INT or number < -2147483647 or number > 2147483647:
				return false
		if not layers.has(Address.key(row["layer"])) or not _prefab_ground_matches(row, h0):
			return false
		var key: String = Address.key(row["layer"]) + "|%d,%d" % [row["cell"][0], row["cell"][1]]
		if seen.has(key) or not _ground_valid(row["ground"]):
			return false
		seen[key] = true
	seen.clear()
	for row in value["objects"]:
		if not State.exact_fields(row, ["layer", "rect", "plane", "object_instance_id", "content_id", "content_namespace", "is_liquid", "blocking"]) or not Address.valid_layer(row["layer"]) or row["layer"]["world_id"] != world_id or row["plane"] != "H1":
			return false
		if not _text(row["object_instance_id"]) or seen.has(row["object_instance_id"]) or not _text(row["content_id"]) or not _text(row["content_namespace"]) or typeof(row["is_liquid"]) != TYPE_BOOL or typeof(row["blocking"]) != TYPE_BOOL:
			return false
		if not row["rect"] is Array or row["rect"].size() != 4:
			return false
		for number in row["rect"]:
			if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or absf(float(number)) > 2147483647.0:
				return false
		if row["rect"][2] <= 0 or row["rect"][3] <= 0:
			return false
		seen[row["object_instance_id"]] = true
	var unhashed: Dictionary = value.duplicate(true)
	unhashed.erase("projection_sha256")
	return EntryStore.digest(unhashed) == value["projection_sha256"]

static func _prefab_ground_matches(row: Dictionary, objects: Array) -> bool:
	var overlapping: Array = []
	for object in objects:
		if object["layer"] == row["layer"] and EntryStore._contains(object["rect"], row["cell"]):
			overlapping.append(object)
	if overlapping.size() > 1:
		return false
	if overlapping.is_empty():
		return row["ground"] is Dictionary and row["ground"].get("kind") != "existing_prefab"
	var object: Dictionary = overlapping[0]
	return row["ground"] == {"kind": "existing_prefab", "content_id": object["content_id"], "content_namespace": object["content_namespace"], "object_instance_id": object["instance_id"], "is_liquid": object["is_liquid"]}

static func _ground_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.get("kind") == "source_static_water":
		return State.exact_fields(value, ["kind", "liquid_type", "parameter_id", "is_liquid"]) and _text(value["liquid_type"]) and _text(value["parameter_id"]) and EntryStore._same(value["is_liquid"], true)
	if not State.exact_fields(value, ["kind", "content_id", "content_namespace", "object_instance_id", "is_liquid"]) or value["kind"] not in ["source_ground", "existing_prefab"] or not _text(value["content_id"]) or not _text(value["content_namespace"]) or not value["object_instance_id"] is String or typeof(value["is_liquid"]) != TYPE_BOOL:
		return false
	return _text(value["object_instance_id"]) if value["kind"] == "existing_prefab" else value["object_instance_id"].is_empty() and not value["is_liquid"]

static func _text(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 256

func _reject(code: String) -> Dictionary:
	last_error = code
	return {"ok": false, "code": code}
