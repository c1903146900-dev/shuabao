extends RefCounted
## Immutable-by-copy source API plus explicit user-approved effective projections.
## Source getters keep original wording; descriptions apply provenance-backed rules.
## A 100 %AD cell returns 100; fraction() returns 1.0. No old-rank interpolation.
const PATH = "res://data/final_design/catalog.json"
static var _cached: Dictionary = {}
static var _override_cache: Dictionary = {}
static var _runtime_rule_cache: Dictionary = {}
static var _map_cache: Dictionary = {}

static func data() -> Dictionary:
	return _source().duplicate(true)

static func _source() -> Dictionary:
	if _cached.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary: _cached = _canonical(parsed)
	return _cached

static func hero_ids() -> Array:
	return _source().get("heroes", {}).keys()

static func hero(hero_id: String) -> Dictionary:
	return _source().get("heroes", {}).get(hero_id, {}).duplicate(true)

static func skill(hero_id: String, candidate: String) -> Dictionary:
	return _source().get("heroes", {}).get(hero_id, {}).get("skills", {}).get(candidate.to_upper(), {}).duplicate(true)

static func parameter_data(hero_id: String, token: String) -> Dictionary:
	return _source().get("heroes", {}).get(hero_id, {}).get("parameters", {}).get(_token(token), {}).duplicate(true)

static func parameter(hero_id: String, token: String, rank: int = 1) -> float:
	var p := parameter_data(hero_id, token)
	var override: Dictionary = effective_overrides().get("heroes", {}).get(hero_id, {}).get(_token(token), {})
	if not override.is_empty(): p.values = override.values
	return _value(p, rank)

static func fraction(hero_id: String, token: String, rank: int = 1) -> float:
	var p := parameter_data(hero_id, token)
	if not str(p.get("unit", "")).contains("%"):
		push_error("final_design fraction requires percent unit: " + hero_id + "/" + token)
		return NAN
	return parameter(hero_id, token, rank) / 100.0

static func description(hero_id: String, candidate: String, rank: int = 1) -> String:
	var definition := skill(hero_id, candidate)
	var descriptions: Array = definition.get("descriptions", [])
	if rank < 1 or rank > descriptions.size(): return ""
	var result := _render(hero_id, effective_template(hero_id, candidate, definition.template), definition.parameters, rank)
	for amendment in effective_semantics(hero_id,candidate).get("amendments",[]):
		if amendment.has("target"): continue # Resolution text is already in the effective template.
		var addition: String = amendment.rules.get("description_append","")
		if not addition.is_empty(): result += "\n" + addition
	return result

static func base_description(hero_id: String, section: String) -> String:
	var definition: Dictionary = _source().get("heroes", {}).get(hero_id, {}).get("base", {}).get(section, {})
	return _render(hero_id, definition.get("template", ""), definition.get("parameters", {}), 1)

static func hex_ids(hero_id: String = "", include_common: bool = true) -> Array:
	var result: Array = []
	for id in hero_ids():
		if not hero_id.is_empty() and id != hero_id: continue
		for value in _source().heroes[id].hexes.values(): result.append(value.id)
	if include_common:
		for value in _source().common_hexes.values(): result.append(value.id)
	return result

static func hex_definition(id: String) -> Dictionary:
	if id.begins_with("common_"):
		return _source().get("common_hexes", {}).get(id.trim_prefix("common_").to_upper(), {}).duplicate(true)
	for hero_id in hero_ids():
		if id.begins_with(hero_id + "_"):
			return _source().heroes[hero_id].hexes.get(id.trim_prefix(hero_id + "_").to_upper(), {}).duplicate(true)
	return {}

static func hex_parameter(id: String, token: String) -> float:
	var p: Dictionary = hex_definition(id).get("parameters", {}).get(_token(token), {})
	var override: Dictionary = effective_overrides().get("hexes", {}).get(id, {}).get(_token(token), {})
	if not override.is_empty(): p.values = override.values
	return _value(p, 1)

static func hex_fraction(id: String, token: String) -> float:
	var p: Dictionary = hex_definition(id).get("parameters", {}).get(_token(token), {})
	if not str(p.get("unit", "")).contains("%"):
		push_error("final_design hex_fraction requires percent unit: " + id + "/" + token)
		return NAN
	return hex_parameter(id, token) / 100.0

static func progression_rules() -> Dictionary:
	return _source().get("progression", {}).duplicate(true)

static func build_progression(hero_id: String = "xuanlei") -> Dictionary:
	var h := hero(hero_id)
	if h.is_empty(): return {}
	# Existing gear, recipes, prices, stat units, body, XP and potion rules stay intact.
	var c: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/prototype/catalog.json"))
	c.version = _source().version + "-" + hero_id
	c.final_design_version = _source().version
	c.effective_rule_version = effective_rule_resolutions().get("version", "")
	c.hero_id = hero_id
	c.hero_name = h.name
	c.hero_ranged = h.ranged
	c.auto_hex_in_combat = true
	c.body_enabled = true
	for item_id in c.items:
		if c.items[item_id].get("kind","") in ["normal","special"]:
			c.items[item_id].recovery.allowed_phases = ["safe","combat"]
	c.policies.healing_phase = "safe_and_combat_confirmed"
	c.candidates = h.candidates.duplicate(true)
	c.candidate_names = {}
	c.skill_descriptions = {}
	c.skill_definitions = h.skills.duplicate(true)
	c.progression_rules = progression_rules()
	c.r_gates = c.progression_rules.r_gates.duplicate()
	c.policies.recipe_purchase = "owned_recursive_discount"
	for slot in c.candidates:
		c.candidate_names[slot] = []
		for candidate in c.candidates[slot]:
			c.candidate_names[slot].append(h.skills[candidate].name)
			c.skill_definitions[candidate]["source_definition"] = h.skills[candidate].duplicate(true)
			c.skill_definitions[candidate]["template"] = effective_template(hero_id, candidate, h.skills[candidate].template)
			c.skill_definitions[candidate]["effective_semantics"] = effective_semantics(hero_id, candidate)
			c.skill_descriptions[candidate] = []
			for rank in range(1, int(h.skills[candidate].rank_cap) + 1):
				c.skill_descriptions[candidate].append(description(hero_id, candidate, rank))
			c.skill_definitions[candidate]["descriptions"] = c.skill_descriptions[candidate].duplicate()
	c.equipment_tasks = equipment_tasks().tasks.duplicate(true)
	c.campaign_acts = {} # Set only from an authored campaign; test waves are not acts.
	c.hexes = {}
	for id in hex_ids(hero_id):
		var source := hex_definition(id)
		var ready: bool = source.activation_status == "eligible_when_implemented" or id in approved_proposals()
		c.hexes[id] = {
			"name": source.name, "hero": source.hero, "requires": source.requires,
			"skill_dependencies": source.skill_dependencies.duplicate(), "weight": 100,
			"effect_key": id, "stats": {}, "effects": {"mechanism": id},
			"description": hex_description(id), "template": effective_template(source.hero, source.source_id, source.template),
			"status": "source_final" if ready else "unsupported",
			"activation_status": "eligible_when_implemented" if ready else source.activation_status, "design_status": source.design_status, "effective_design_status":"user_confirmed_formal" if id in approved_proposals() else source.design_status,
			"ranged_only": source.ranged_only,
			"provenance": "mechanics_docx_v03_and_values_xlsx_v03",
			"source_ref": source.source.file + ":paragraph=" + str(source.source.paragraph_all_body_descendants),
			"design_notice": "原稿机制与逐行数值；实机平衡尚未验收" if ready else "原稿保留；等待规则确认",
			"release_ready": false, "required_hooks": source.required_hooks.duplicate(),
			"source_definition": source, "effective_semantics": effective_hex_semantics(id)
		}
		if not rule_resolutions(source.hero, source.source_id).is_empty():
			c.hexes[id]["effective_design_status"] = "user_confirmed_rule"
			c.hexes[id]["design_notice"] = "规则已确认；实现与验收另行验证"
	return c

static func _token(token: String) -> String:
	return token.trim_prefix("[").trim_suffix("]").to_upper()

static func _value(p: Dictionary, rank: int) -> float:
	var values: Array = p.get("values", [])
	# Single-value base and Hex parameters do not gain invented ranks.
	if values.size() == 1 and rank >= 1: return float(values[0])
	if rank < 1 or rank > values.size():
		push_error("Missing final-design parameter/rank: " + str(p.get("token", "unknown")) + "/" + str(rank))
		return NAN
	return float(values[rank - 1])

static func effective_overrides() -> Dictionary:
	if _override_cache.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/final_design/effective_overrides.json"))
		if parsed is Dictionary: _override_cache = _canonical(parsed)
	return _override_cache.duplicate(true)

static func _render(hero_id: String, template: String, parameters: Dictionary, rank: int) -> String:
	var result := template
	for token in parameters:
		result = result.replace("[" + token + "]", String.num(parameter(hero_id, token, rank), 6))
	return result

static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = _canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value: result.append(_canonical(entry))
		return result
	if value is float and value == floor(value): return int(value)
	return value

static func hex_description(id: String) -> String:
	var definition := hex_definition(id)
	var result: String = effective_template(definition.get("hero", ""), definition.get("source_id", ""), definition.get("template", ""))
	for token in definition.get("parameters", {}):
		result = result.replace("[" + token + "]", String.num(hex_parameter(id, token), 6))
	return result

static func runtime_rules() -> Dictionary:
	if _runtime_rule_cache.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/final_design/runtime_rules.json"))
		if parsed is Dictionary: _runtime_rule_cache = _canonical(parsed)
	return _runtime_rule_cache.duplicate(true)

static func effective_semantics(hero_id: String, candidate: String) -> Dictionary:
	var original: Dictionary = skill(hero_id, candidate).get("semantics", {}).duplicate(true)
	return _effective_semantics(original, hero_id, candidate)

static func effective_hex_semantics(id: String) -> Dictionary:
	var definition := hex_definition(id)
	return _effective_semantics(definition.get("semantics", {}), definition.get("hero", ""), definition.get("source_id", ""))

static func _effective_semantics(original: Dictionary, hero_id: String, candidate: String) -> Dictionary:
	var result := original.duplicate(true)
	result["amendments"] = []
	var resolved_ids: Array = []
	for amendment in runtime_rules().get("amendments", []):
		if amendment.get("hero_id","") == hero_id and amendment.get("candidate","") == candidate.to_upper() and amendment.get("status","") == "user_confirmed":
			result.amendments.append(amendment.duplicate(true))
			resolved_ids.append_array(amendment.get("amends_source_comment_ids",[]))
	for resolution in rule_resolutions(hero_id, candidate):
		result.amendments.append(resolution)
		resolved_ids.append_array(resolution.target.get("amends_source_comment_ids", []))
	result["unresolved"] = []
	for entry in original.get("unresolved", []):
		if not entry.comment_id in resolved_ids: result.unresolved.append(entry.duplicate(true))
	return result

static func effective_rule_resolutions() -> Dictionary:
	return _json_map("res://data/final_design/effective_rule_resolutions.json")

static func rule_resolutions(hero_id: String, candidate: String) -> Array:
	# Approval changes rules/text, never runtime hooks, availability or acceptance.
	var layer := effective_rule_resolutions()
	var result: Array = []
	for resolution in layer.get("resolutions", []):
		if resolution.get("status", "") != "user_confirmed": continue
		for target in resolution.get("targets", []):
			if target.get("hero_id", "") != hero_id or target.get("key", "") != candidate.to_upper(): continue
			var entry: Dictionary = resolution.duplicate(true)
			entry.erase("targets")
			entry["target"] = target.duplicate(true)
			entry["authority"] = resolution.get("authority", layer.get("authority", {})).duplicate(true)
			result.append(entry)
	return result

static func effective_template(hero_id: String, candidate: String, source_template: String) -> String:
	var result := source_template
	for resolution in rule_resolutions(hero_id, candidate):
		var presentation: Dictionary = resolution.target.get("description", {})
		for replacement in presentation.get("replace", []):
			result = result.replace(replacement.from, replacement.to)
		for field in ["append", "implementation_notice"]:
			var addition: String = presentation.get(field, "")
			if not addition.is_empty(): result += "\n" + addition
	return result

static func equipment_tasks() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/final_design/equipment_tasks.json"))
	return _canonical(parsed) if parsed is Dictionary else {}

static func replay_map() -> Dictionary:
	return _json_map("res://data/final_design/replay_segments.json")
static func enhancement_map() -> Dictionary:
	return _json_map("res://data/final_design/enhancement_fields.json")
static func common_hook_map() -> Dictionary:
	return _json_map("res://data/final_design/common_hex_hooks.json")
static func _json_map(path: String) -> Dictionary:
	return _json_source(path).duplicate(true)
static func _json_source(path: String) -> Dictionary:
	if not _map_cache.has(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		_map_cache[path] = _canonical(parsed) if parsed is Dictionary else {}
	return _map_cache[path]
static func enhancement_fields(id: String) -> Array:
	var mapping: Dictionary = _json_source("res://data/final_design/enhancement_fields.json").get("hexes",{}).get(id,{})
	return mapping.get("approved_fields",[]).duplicate() if mapping.get("eligible_when_selected_and_approved",false) or id in approved_proposals() else []
static func replay_definition(hero_id: String, candidate: String) -> Dictionary:
	return _json_source("res://data/final_design/replay_segments.json").get("skills",{}).get(hero_id+"_"+candidate.to_lower(),{}).duplicate(true)

static func approved_proposals() -> Array:
	var result:Array=[]
	for amendment in runtime_rules().get("amendments",[]):
		if amendment.get("status","")!="user_confirmed":continue
		for id in amendment.get("rules",{}).get("enabled_common_hexes",[]):
			if id not in result:result.append(id)
	return result
