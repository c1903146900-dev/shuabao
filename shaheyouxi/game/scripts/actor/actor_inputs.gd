extends RefCounted
## Verified actor projection. There are no fallback gameplay values.
const PROJECT := "shaheyouxi_experiment_20261004"
const SETTINGS_PATH := "res://data/actor_settings.json"
const AUTHORITY_PATH := "res://data/actor_authorities.json"
const SOURCE_NAMES := ["shuzhi.xlsx", "sucai.xlsx", "cehua.docx"]
const REQUIRED_PARAMETERS := ["health_max", "food_max", "energy_max", "food_decay_per_second", "low_food_threshold", "low_food_movement_multiplier", "starvation_health_loss_per_second", "movement_speed_cells_per_second", "energy_regeneration_per_second", "energy_regeneration_delay_seconds", "dodge_energy_cost", "dodge_distance_cells", "dodge_duration_seconds", "dodge_invulnerability_seconds", "dodge_cooldown_seconds", "actor_diameter_cells", "interaction_range_cells", "bag_slots", "hotbar_slots", "rooted_blocks_movement", "rooted_blocks_dodge", "dodge_invulnerability_cancels_entire_hit"]
var ready: bool = false
var last_error: String = ""
var _data: Dictionary = {}
var _source_identity: Dictionary = {}

func load_file(path: String = SETTINGS_PATH) -> bool:
	return load_document(JSON.parse_string(FileAccess.get_file_as_string(path)))

func load_document(document: Variant) -> bool:
	# Only explicit frozen-frame instances refuse in-place reload; ordinary inputs
	# retain their previous configure/reset behavior. A new instance is required.
	if _data.is_read_only() or _source_identity.is_read_only():
		return _reject("FROZEN_ACTOR_INPUT_RELOAD_REQUIRES_NEW_INSTANCE")
	ready = false
	_data.clear()
	_source_identity.clear()
	last_error = ""
	if not document is Dictionary or not integer(document.get("schema_version")) or int(document["schema_version"]) != 1 or document.get("project") != PROJECT or document.get("artifact_kind") != "derived_authoritative_actor_inputs":
		return _reject("ACTOR_INPUT_IDENTITY_INVALID")
	var approved: Variant = JSON.parse_string(FileAccess.get_file_as_string(AUTHORITY_PATH))
	var trusted_text := FileAccess.get_file_as_string(SETTINGS_PATH)
	if not approved is Dictionary or not document.get("sources") is Dictionary or document["sources"].size() != SOURCE_NAMES.size():
		return _reject("ACTOR_SOURCE_MISSING")
	for name in SOURCE_NAMES:
		if not approved.get(name) is Dictionary or not digest(approved[name].get("sha256")) or document["sources"].get(name) != approved[name]["sha256"]:
			return _reject("ACTOR_SOURCE_MISMATCH")
	if not digest(approved.get("_projection_sha256")) or trusted_text.sha256_text() != approved["_projection_sha256"]:
		return _reject("APPROVED_PROJECTION_BYTES_MISMATCH")
	var trusted: Variant = JSON.parse_string(trusted_text)
	if not trusted is Dictionary or document != trusted:
		return _reject("DERIVED_CONTRACT_CHANGED_REBUILD_FROM_FORMAL_SOURCE")
	if typeof(document.get("formal_world_allowed")) != TYPE_BOOL or document["formal_world_allowed"]:
		return _reject("FORMAL_WORLD_GATE_CHANGED")
	var parameters: Variant = document.get("parameters")
	if not parameters is Dictionary or parameters.size() != 44:
		return _reject("ACTOR_PARAMETERS_MISSING")
	for key in REQUIRED_PARAMETERS:
		if not parameters.has(key):
			return _reject("ACTOR_REQUIRED_PARAMETER_MISSING")
	# The hash binds provenance, ID, source cell, type, range and mechanics together.
	# This typed pass prevents invalid runtime coercions even in a rebuilt package.
	for key in parameters:
		var item: Variant = parameters[key]
		if not key is String or not item is Dictionary or not item.get("id") is String or item["id"].is_empty() or item.get("source_file") != "shuzhi.xlsx" or not item.get("source_cell") is String:
			return _reject("ACTOR_PARAMETER_PROVENANCE_INVALID")
		var value: Variant = item.get("value")
		if typeof(value) != TYPE_BOOL and not number(value):
			return _reject("ACTOR_PARAMETER_TYPE_INVALID")
		if not item.get("legal_range") is Dictionary or not _in_range(value, item["legal_range"], parameters):
			return _reject("ACTOR_PARAMETER_RANGE_INVALID")
	for key in ["health_max", "food_max", "energy_max", "movement_speed_cells_per_second", "dodge_distance_cells", "dodge_duration_seconds", "actor_diameter_cells", "interaction_range_cells"]:
		if not parameters.has(key) or not number(parameters[key]["value"]) or float(parameters[key]["value"]) <= 0.0:
			return _reject("ACTOR_REQUIRED_POSITIVE_PARAMETER_INVALID")
	for key in ["bag_slots", "hotbar_slots"]:
		if not integer(parameters[key]["value"]):
			return _reject("ACTOR_SLOT_COUNT_INVALID")
	for key in ["rooted_blocks_movement", "rooted_blocks_dodge", "dodge_invulnerability_cancels_entire_hit"]:
		if typeof(parameters[key]["value"]) != TYPE_BOOL:
			return _reject("ACTOR_BOOLEAN_INVALID")
	if float(parameters["low_food_threshold"]["value"]) > float(parameters["food_max"]["value"]):
		return _reject("FOOD_THRESHOLD_EXCEEDS_CAP")
	_data = document.duplicate(true)
	_source_identity = {"projection_sha256": approved["_projection_sha256"], "sources": document["sources"].duplicate(true)}
	ready = true
	return true

func parameter(key: String) -> float:
	if not ready or not _data["parameters"].has(key) or not number(_data["parameters"][key]["value"]):
		return NAN
	return float(_data["parameters"][key]["value"])

func flag(key: String) -> Variant:
	if not ready or not _data["parameters"].has(key) or typeof(_data["parameters"][key]["value"]) != TYPE_BOOL:
		return null
	return _data["parameters"][key]["value"]

func document() -> Dictionary:
	return _data.duplicate(true)

func source_identity() -> Dictionary:
	return _source_identity.duplicate(true)

static func number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

const MAX_EXACT_INTEGER: int = 9007199254740991

static func integer(value: Variant) -> bool:
	# Keep native integer bounds entirely integer; the decimal float literal for
	# this boundary is not relied on as an exact source of the accepted range.
	if typeof(value) == TYPE_INT:
		return value >= -MAX_EXACT_INTEGER and value <= MAX_EXACT_INTEGER
	if typeof(value) != TYPE_FLOAT or not is_finite(value):
		return false
	return floor(value) == value and value >= -float(MAX_EXACT_INTEGER) and value <= float(MAX_EXACT_INTEGER)

static func digest(value: Variant) -> bool:
	return value is String and value.length() == 64 and value.is_valid_hex_number(false)

static func _in_range(value: Variant, rule: Dictionary, parameters: Dictionary) -> bool:
	match rule.get("kind"):
		"fixed":
			return typeof(value) == TYPE_BOOL and typeof(rule.get("value")) == TYPE_BOOL and value == rule["value"] if typeof(value) == TYPE_BOOL else number(value) and number(rule.get("value")) and value == rule["value"]
		"inclusive":
			return number(value) and number(rule.get("minimum")) and number(rule.get("maximum")) and value >= rule["minimum"] and value <= rule["maximum"]
		"exclusive_minimum":
			return number(value) and number(rule.get("minimum")) and value > rule["minimum"]
		"relation":
			var other: Variant = parameters.get(rule.get("parameter"))
			return rule.get("operator") == ">=" and number(value) and other is Dictionary and number(other.get("value")) and value >= other["value"]
		"not_specified":
			return number(value) and value > 0.0
	return false

func _reject(code: String) -> bool:
	last_error = code
	return false
