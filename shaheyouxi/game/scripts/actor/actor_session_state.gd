extends RefCounted
## Pure combined-save contract. This does not activate actors, listen, or write files.
const Motion = preload("res://scripts/actor/actor_motion.gd")
const Inputs = preload("res://scripts/actor/actor_inputs.gd")
const State = preload("res://scripts/actor/actor_state.gd")
const CircleBoundary = preload("res://scripts/actor/actor_circle_boundary.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const WorldContract = preload("res://scripts/world_session/world_component.gd")
const LayoutContract = preload("res://scripts/worldgen/layout_validator.gd")
const PrefabContract = preload("res://scripts/prefab/prefab_validator.gd")
const FIELDS := ["world_id", "world_seconds", "revision", "next_auto_due_world_seconds", "profiles", "world_component", "actor_component"]
var ready: bool = false
var last_error: String = ""
var _world: RefCounted
var _actor_document: Dictionary = {}
var _half: float = 0.0

func _init(world: RefCounted, actor_document: Dictionary) -> void:
	var inputs := Inputs.new()
	if world == null or not world.ready or not inputs.load_document(actor_document):
		last_error = "ACTOR_SESSION_INPUTS_INVALID"
		return
	_world = world
	_actor_document = inputs.document()
	_half = inputs.parameter("actor_diameter_cells") / 2.0
	ready = true

func combine(authority: Dictionary, actors: RefCounted) -> Dictionary:
	if not ready or actors == null or not actors.ready:
		return State.error("ACTOR_SESSION_NOT_READY", "request")
	var state: Dictionary = _world.combine(authority)
	state["actor_component"] = actors.persistent_state()
	var checked := validate_combined_state(state)
	return {"ok": true, "state": state} if checked["ok"] else checked

func validate_combined_state(value: Variant) -> Dictionary:
	if not ready or not value is Dictionary:
		return State.error("ACTOR_SESSION_NOT_READY_OR_INVALID")
	# Unknown contract fields must never silently select an older backup.
	if not State.exact_fields(value, FIELDS):
		return State.error("ACTOR_SESSION_CONTRACT_INCOMPATIBLE", "incompatible")
	if _unknown_world_contract(value.get("world_component")):
		return State.error("ACTOR_SESSION_WORLD_CONTRACT_INCOMPATIBLE", "incompatible")
	var base: Dictionary = value.duplicate(true)
	base.erase("actor_component")
	var checked: Dictionary = _world.validate_combined_state(base)
	if not checked["ok"]:
		return checked
	# The saved world identity is checked by the existing authority/world validator
	# before constructing this stateless actor validator. It creates no actor or body.
	var validator := Motion.new(value["world_id"], _actor_document)
	if not validator.ready:
		return State.error("ACTOR_SESSION_VALIDATOR_NOT_READY", "incompatible")
	checked = validator.validate_persistent_state(value["actor_component"])
	if not checked["ok"]:
		return checked
	var actors: Dictionary = value["actor_component"]["actors"]
	if float(value["actor_component"]["clock"]) != float(value["world_seconds"]):
		return State.error("ACTOR_AUTHORITY_CLOCK_MISMATCH")
	var expected: Dictionary = {}
	for profile in value["profiles"].values():
		expected[profile["player_instance_id"]] = true
	if actors.size() != expected.size():
		return State.error("ACTOR_PROFILE_SET_MISMATCH")
	var layers := _loaded_layers(value["world_component"])
	var radius: float = value["world_component"]["layout"]["body"]["radius_cells"]
	for actor_id in actors:
		if not expected.has(actor_id):
			return State.error("ACTOR_PROFILE_SET_MISMATCH")
		var actor: Dictionary = actors[actor_id]
		for address in [actor["layer"], actor["fallback"]["layer"]]:
			if not layers.has(Address.key(address)):
				# This stage has no parent-removal/migration implementation. Unknown
				# loaded identity is not permission to teleport or choose old backups.
				return State.error("ACTOR_LAYER_NOT_IN_LOADED_WORLD", "incompatible")
		for position in [actor["position"], actor["fallback"]["position"]]:
			var contained: Dictionary = CircleBoundary.contains(State.vector(position), radius, _half)
			if not contained.get("ok", false) or not contained.get("inside", false):
				return State.error("ACTOR_COMPLETE_BODY_OUTSIDE_MAP")
	# Offline saved positions may coincide; native activation resolves occupied slots.
	# Do not invent persistent collisions for disconnected profiles.
	return {"ok": true}

static func authority_state(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	result.erase("world_component")
	result.erase("actor_component")
	return result

static func _loaded_layers(component: Dictionary) -> Dictionary:
	var layers: Dictionary = {}
	var layout: Dictionary = component["layout"]
	layers[Address.key(layout["spawn"]["layer"])] = true
	for connection in layout["connections"]:
		for endpoint in connection["endpoints"]:
			layers[Address.key(endpoint["layer"])] = true
	for instance in component["prefab_instances"]:
		for layer in instance["layers"]:
			layers[Address.key(layer["address"])] = true
	return layers

static func _extra_fields(value: Variant, allowed: Array) -> bool:
	if not value is Dictionary:
		return false # Known malformed/missing data is classified by its validator.
	for key in value:
		if key not in allowed:
			return true
	return false

static func _unknown_versioned_record(value: Variant, fields: Array) -> bool:
	if not value is Dictionary:
		return false
	if value.has("schema_version") and (not Inputs.integer(value["schema_version"]) or value["schema_version"] != 1):
		return true
	return _extra_fields(value, fields)

static func _unknown_world_contract(component: Variant) -> bool:
	# Compatibility preflight precedes legacy field-count rejection. Missing known
	# fields retain existing corruption handling; extra fields/unknown versions do not.
	if _unknown_versioned_record(component, WorldContract.FIELDS):
		return true
	if not component is Dictionary:
		return false
	var layout: Variant = component.get("layout")
	if _unknown_versioned_record(layout, LayoutContract.FIELDS):
		return true
	if layout is Dictionary:
		var spawn: Variant = layout.get("spawn")
		if _extra_fields(spawn, ["layer", "cell"]) or (spawn is Dictionary and _extra_fields(spawn.get("layer"), Address.LAYER_FIELDS)):
			return true
		if layout.get("permanent_changes") is Dictionary:
			for change in layout["permanent_changes"].values():
				if _extra_fields(change, ["depth", "cell", "cleared_default_rock"]):
					return true
	var instances: Variant = component.get("prefab_instances")
	if not instances is Array:
		return false
	for instance in instances:
		if _unknown_versioned_record(instance, PrefabContract.INSTANCE_FIELDS):
			return true
		if not instance is Dictionary:
			continue
		var template: Variant = instance.get("source_template")
		if _unknown_versioned_record(template, PrefabContract.TEMPLATE_FIELDS):
			return true
		var fields := {"layers": PrefabContract.LAYER_FIELDS, "objects": PrefabContract.OBJECT_FIELDS, "anchors": PrefabContract.ANCHOR_FIELDS, "connections": PrefabContract.CONNECTION_FIELDS, "protected_areas": PrefabContract.PROTECTED_FIELDS}
		var additions := {"layers": ["address"], "objects": ["instance_id", "layer"], "anchors": ["instance_id", "object_instance_id", "layer"], "connections": ["instance_id", "upper_anchor_instance_id", "lower_anchor_instance_id", "body_rect", "safety_rect"], "protected_areas": ["layer"]}
		for group in fields:
			if template is Dictionary and template.get(group) is Array:
				for row in template[group]:
					if _extra_fields(row, fields[group]):
						return true
			if instance.get(group) is Array:
				for row in instance[group]:
					if _extra_fields(row, fields[group] + additions[group]):
						return true
					if row is Dictionary:
						for key in ["layer", "address"]:
							if row.has(key) and _extra_fields(row[key], Address.LAYER_FIELDS):
								return true
	return false
