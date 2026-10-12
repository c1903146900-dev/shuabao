extends RefCounted
## One server-owned, materialized technical world component. Never publishes gameplay.
const Address = preload("res://scripts/world/spatial_address.gd")
const Seed = preload("res://scripts/worldgen/world_seed.gd")
const Inputs = preload("res://scripts/worldgen/generation_inputs.gd")
const Generator = preload("res://scripts/worldgen/layout_generator.gd")
const LayoutValidator = preload("res://scripts/worldgen/layout_validator.gd")
const PrefabValidator = preload("res://scripts/prefab/prefab_validator.gd")
const Factory = preload("res://scripts/prefab/prefab_instantiator.gd")
const CONTRACT := "sandbox010-technical-v1"
const FIELDS := ["schema_version", "artifact_kind", "bundle_sha256", "layout", "prefab_instances", "formal_world_allowed"]
var ready: bool = false
var last_error: String = ""
var generator: RefCounted
var factory: RefCounted
var random_calls: int = 0
var bundle_sha256: String = ""
var component: Dictionary = {}
var _generation: Dictionary
var _template: Dictionary = {}
var _layout_validator: RefCounted
var _prefab_validator: RefCounted

func _init(generation: Dictionary, prefab: Dictionary, bundle: Dictionary, technical_profile: String = "010") -> void:
	# Internal fixed profile, never a client-supplied resource path. Default010 unchanged.
	if technical_profile not in ["010", "011"]:
		last_error = "WORLD_PROFILE_NOT_APPROVED"
		return
	_generation = generation.duplicate(true)
	var inputs := Inputs.new()
	if not inputs.load_document(generation):
		last_error = inputs.last_error
		return
	_prefab_validator = PrefabValidator.new(generation, prefab)
	_layout_validator = LayoutValidator.new(generation)
	generator = Generator.new()
	factory = Factory.new(generation, prefab)
	if not _prefab_validator.ready or not factory.ready:
		last_error = "WORLD_PREFAB_INPUTS_NOT_READY"
		return
	var bundle_file := "world_bundle010" if technical_profile == "010" else "actor_world_bundle011"
	var text: String = FileAccess.get_file_as_string("res://data/" + bundle_file + ".json")
	var approved: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + bundle_file + "_authorities.json"))
	var trusted: Variant = JSON.parse_string(text)
	if not approved is Dictionary or approved.get("_projection_sha256") != text.sha256_text() or not trusted is Dictionary or bundle != trusted:
		last_error = "WORLD_BUNDLE_NOT_APPROVED"
		return
	if bundle.get("schema_version") != 1 or bundle.get("project") != "shaheyouxi_experiment_20261004" or bundle.get("artifact_kind") != "technical_world_room_bundle" or typeof(bundle.get("formal_world_allowed")) != TYPE_BOOL or bundle["formal_world_allowed"] or bundle.get("sources") != generation["sources"]:
		last_error = "WORLD_BUNDLE_IDENTITY_INVALID"
		return
	if bundle.get("generation_projection_sha256") != FileAccess.get_file_as_string("res://data/generation_settings.json").sha256_text() or bundle.get("prefab_projection_sha256") != FileAccess.get_file_as_string("res://data/prefab_settings.json").sha256_text():
		last_error = "WORLD_BUNDLE_SOURCE_MISMATCH"
		return
	if technical_profile == "011":
		var actor_text := FileAccess.get_file_as_string("res://data/actor_settings.json")
		var actor_approved: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_authorities.json"))
		var actor_inputs: Variant = JSON.parse_string(actor_text)
		if not actor_approved is Dictionary or actor_approved.get("_projection_sha256") != actor_text.sha256_text() or not actor_inputs is Dictionary or actor_inputs.get("sources") != generation["sources"] or bundle.get("actor_projection_sha256") != actor_text.sha256_text():
			last_error = "WORLD_ACTOR_SOURCE_MISMATCH"
			return
	var checked: Dictionary = _prefab_validator.validate_template(bundle.get("template"))
	if not checked["ok"]:
		last_error = checked["code"]
		return
	_template = checked["template"]
	bundle_sha256 = text.sha256_text()
	ready = true

func create(world_id: String, requested_seed: Variant, test_entry: bool, attempts: int) -> Dictionary:
	if not ready or not component.is_empty():
		return _bad("WORLD_NOT_READY_OR_ALREADY_CREATED")
	var selected: Dictionary = Seed.choose_for_server_creation(requested_seed, test_entry, _random_seed)
	if not selected["ok"]:
		return selected
	var generated: Dictionary = generator.generate(world_id, selected["value"], _generation, {"max_region_attempts": attempts})
	if not generated["ok"]:
		return generated
	var plan: Dictionary = generated["plan"]
	var made: Dictionary = factory.instantiate(_template, world_id, "body_0001", initial_prefab_id(world_id), plan["spawn"]["cell"])
	if not made["ok"]:
		return made
	var candidate: Dictionary = {"schema_version": 1, "artifact_kind": "technical_network_world", "bundle_sha256": bundle_sha256, "layout": plan, "prefab_instances": [made["instance"]], "formal_world_allowed": false}
	var checked: Dictionary = validate_component(candidate, world_id)
	if checked["ok"]:
		component = checked["component"]
	return checked

func restore(value: Variant, world_id: String) -> Dictionary:
	# No generator, random source or instantiator call on this path.
	var checked: Dictionary = validate_component(value, world_id)
	if checked["ok"]:
		component = checked["component"]
	return checked

func validate_component(value: Variant, world_id: String) -> Dictionary:
	if not ready or not _fields(value, FIELDS):
		return _bad("WORLD_COMPONENT_FIELDS_INVALID")
	if not Address.is_integer(value["schema_version"]) or int(value["schema_version"]) != 1 or value["artifact_kind"] != "technical_network_world":
		return _incompatible("UNSUPPORTED_WORLD_COMPONENT_SCHEMA")
	if value["bundle_sha256"] != bundle_sha256:
		return _incompatible("WORLD_CONTENT_MISMATCH")
	if typeof(value["formal_world_allowed"]) != TYPE_BOOL or value["formal_world_allowed"]:
		return _bad("WORLD_FORMAL_PUBLICATION_FORBIDDEN")
	if not value["layout"] is Dictionary or value["layout"].get("sources") != _generation["sources"]:
		return _incompatible("WORLD_CONTENT_MISMATCH")
	if not Address.is_integer(value["layout"].get("schema_version")) or value["layout"]["schema_version"] != 1 or value["layout"].get("generation_version") != Generator.GENERATION_VERSION:
		return _incompatible("UNSUPPORTED_WORLD_LAYOUT_SCHEMA")
	var layout: Dictionary = _layout_validator.validate(value["layout"], world_id)
	if not layout["ok"]:
		return _bad("WORLD_LAYOUT_INVALID:" + str(layout.get("code", "unknown")))
	if not value["prefab_instances"] is Array or value["prefab_instances"].size() != 1:
		return _bad("WORLD_PREFAB_SET_INVALID")
	var actual: Variant = value["prefab_instances"][0]
	if not actual is Dictionary or actual.get("sources") != _generation["sources"]:
		return _incompatible("WORLD_CONTENT_MISMATCH")
	if not Address.is_integer(actual.get("schema_version")) or actual["schema_version"] != 1:
		return _incompatible("UNSUPPORTED_WORLD_PREFAB_SCHEMA")
	var prefab: Dictionary = _prefab_validator.validate_instance(actual, world_id)
	if not prefab["ok"]:
		return _bad("WORLD_PREFAB_INVALID:" + str(prefab.get("code", "unknown")))
	var plan: Dictionary = layout["plan"]
	var instance: Dictionary = prefab["instance"]
	if instance["prefab_instance_id"] != initial_prefab_id(world_id) or instance["body_instance_id"] != "body_0001" or instance["source_template"] != _template or instance["origin"] != plan["spawn"]["cell"]:
		return _bad("WORLD_PREFAB_BINDING_INVALID")
	for connection in plan["connections"]:
		for endpoint in connection["endpoints"]:
			for object in instance["objects"]:
				if object["layer"]["depth"] == endpoint["layer"]["depth"] and (object["plane"] == "H1" or object["is_liquid"]) and PrefabValidator._intersects(object["rect"], connection["safety_rect"]):
					return _bad("WORLD_PREFAB_COVERS_REQUIRED_ENTRY")
	return {"ok": true, "component": {"schema_version": 1, "artifact_kind": "technical_network_world", "bundle_sha256": bundle_sha256, "layout": plan, "prefab_instances": [instance], "formal_world_allowed": false}, "formal_world_allowed": false}

func validate_combined_state(state: Dictionary) -> Dictionary:
	if not _fields(state, ["world_id", "world_seconds", "revision", "next_auto_due_world_seconds", "profiles", "world_component"]):
		return _bad("WORLD_COMBINED_FIELDS_INVALID")
	var authority: Dictionary = authority_state(state)
	var checked: Dictionary = SandboxServerAuthority.validate_persistent_state(authority)
	if not checked["ok"]:
		return _bad("WORLD_AUTHORITY_STATE_INVALID")
	return validate_component(state["world_component"], state["world_id"])

func combine(authority: Dictionary) -> Dictionary:
	var state: Dictionary = authority.duplicate(true)
	state["world_component"] = component.duplicate(true)
	return state

func public_component() -> Dictionary:
	return component.duplicate(true)

func component_sha256() -> String:
	return JSON.stringify(component, "", true, true).sha256_text()

func technical_clear_cell(depth: int, cell: Array) -> Dictionary:
	# Server test/operator seam only. No network RPC registers this mutation.
	if component.is_empty() or not PrefabValidator._cell(cell):
		return _bad("WORLD_CLEAR_INVALID")
	var candidate: Dictionary = component.duplicate(true)
	var key: String = "%d|%d,%d" % [depth, int(cell[0]), int(cell[1])]
	candidate["layout"]["permanent_changes"][key] = {"depth": depth, "cell": [int(cell[0]), int(cell[1])], "cleared_default_rock": true}
	var checked: Dictionary = validate_component(candidate, component["layout"]["world_id"])
	if checked["ok"]:
		component = checked["component"]
	return checked

func statistics() -> Dictionary:
	return {"generation_calls": generator.generation_calls if generator != null else 0, "instantiation_calls": factory.instantiation_calls if factory != null else 0, "world_seed_random_calls": random_calls, "component_sha256": component_sha256(), "formal_world_allowed": false}

func _random_seed() -> Variant:
	random_calls += 1
	return Seed.server_random_integer()

static func authority_state(state: Dictionary) -> Dictionary:
	var result: Dictionary = state.duplicate(true)
	result.erase("world_component")
	return result

static func initial_prefab_id(world_id: String) -> String:
	return "prefab_" + (world_id + "|initial-room-v1").sha256_text().substr(0, 32)

static func _fields(value: Variant, fields: Array) -> bool:
	if not value is Dictionary or value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "message": code, "formal_world_allowed": false}

static func _incompatible(code: String) -> Dictionary:
	var result: Dictionary = _bad(code)
	result["recoverable_corruption"] = false
	return result
