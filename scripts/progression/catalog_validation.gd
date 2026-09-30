extends RefCounted
const STATS = ["AD", "AP", "attack_speed", "crit_chance", "cooldown_reduction", "max_hp", "defense", "move_speed", "lifesteal", "tenacity", "penetration", "hp_regen"]
const UNITS = {"AD":"flat", "AP":"flat", "attack_speed":"base_fraction", "crit_chance":"fraction", "cooldown_reduction":"fraction", "max_hp":"flat", "defense":"flat", "move_speed":"base_fraction", "lifesteal":"fraction", "tenacity":"fraction", "penetration":"flat", "hp_regen":"hp_per_combat_second"}
const BANNED = ["skill_points", "grant_points", "bonus_points", "reward_points", "skill_strength"]

static func validate(c: Dictionary) -> Array:
	var errors: Array = []
	for key in ["items", "hexes", "passives", "body", "policies", "stat_units"]:
		if not c.get(key) is Dictionary: errors.append("missing_dictionary:" + key)
	if not errors.is_empty(): return errors
	if c.get("schema_version") != 2 or c.get("profile") != "playable_prototype": errors.append("invalid_profile")
	if c.stat_units != UNITS: errors.append("invalid_stat_units")
	var xp = c.get("xp_per_level")
	if not xp is Array or xp.size() != 17: errors.append("invalid_xp_curve")
	else:
		for step in xp:
			if not _positive_integer(step): errors.append("invalid_xp_step")
	var gates = c.get("r_gates")
	if not gates is Array or gates.size() != 3 or gates[0] != 6: errors.append("invalid_r_gates")
	var penalty = c.policies.get("hex_unlearned_weight_multiplier")
	if not _positive(penalty) or penalty > 1: errors.append("invalid_dependency_weight")
	_forbidden(c, "$", errors)
	var effect_keys := {}
	for id in c.items:
		var item = c.items[id]
		if not item is Dictionary:
			errors.append("invalid_item:" + id)
			continue
		_meta(item, id, errors)
		if not _positive_integer(item.get("price")): errors.append("invalid_price:" + id)
		if not item.get("components") is Array or not item.get("stats") is Dictionary:
			errors.append("invalid_item_shape:" + id)
			continue
		_stats(item.stats, id, errors)
		if not item.get("kind") in ["equipment", "normal", "special"]: errors.append("invalid_kind:" + id)
		var passive = item.get("passive", "")
		if not passive is String:
			errors.append("invalid_passive_id:" + id)
			continue
		if not passive.is_empty() and not c.passives.has(passive): errors.append("missing_passive:" + id)
		if item.get("kind") == "equipment" and item.stats.is_empty() and passive.is_empty(): errors.append("empty_effect:" + id)
		if item.get("kind") in ["normal", "special"]:
			var r = item.get("recovery", {})
			if not r is Dictionary or r.get("mode") != "instant_max_hp_fraction" or not _positive(r.get("amount")) or r.get("amount", 2) > 1: errors.append("invalid_recovery:" + id)
		var price_sum := 0
		for part in item.components:
			if not part is String or not c.items.has(part):
				errors.append("missing_component:" + id)
				continue
			var component = c.items[part]
			if not component is Dictionary: continue
			if component.get("kind") != "equipment": errors.append("consumable_recipe:" + id)
			if _positive_integer(component.get("price")): price_sum += int(component.price)
		if item.components.size() > 6: errors.append("recipe_over_six_slots:" + id)
		if not _nonnegative_integer(item.get("combine_fee")): errors.append("invalid_combine_fee:" + id)
		elif not item.components.is_empty() and int(item.get("price", 0)) != price_sum + int(item.combine_fee): errors.append("price_recipe_mismatch:" + id)
		elif item.components.is_empty() and item.combine_fee != 0: errors.append("leaf_combine_fee:" + id)
	for id in c.items: _visit(id, c.items, [], {}, errors)
	for id in c.passives:
		var passive = c.passives[id]
		if not passive is Dictionary:
			errors.append("invalid_passive:" + id)
			continue
		_meta(passive, id, errors)
		if passive.get("effect_key") != id: errors.append("passive_key_mismatch:" + id)
		_stats(passive.get("stats", {}), id, errors)
	for id in c.hexes:
		var hex = c.hexes[id]
		if not hex is Dictionary:
			errors.append("invalid_hex:" + id)
			continue
		_meta(hex, id, errors)
		_stats(hex.get("stats", {}), id, errors)
		if not _positive_integer(hex.get("weight")): errors.append("invalid_weight:" + id)
		if not hex.get("hero") in ["", "fengli"]: errors.append("invalid_hero:" + id)
		if not hex.get("requires") in ["", "P", "Q", "E", "R", "P1", "P2", "P3", "Q1", "Q2", "Q3", "E1", "E2", "E3", "R1", "R2"]: errors.append("invalid_dependency:" + id)
		var key = hex.get("effect_key", "")
		if not key is String or key.is_empty(): errors.append("missing_effect_key:" + id)
		elif effect_keys.has(key): errors.append("duplicate_effect_key:" + id)
		else: effect_keys[key] = id
		if hex.get("status") == "prototype_initial" and hex.get("stats", {}).is_empty(): errors.append("empty_enabled_hex:" + id)
	_meta(c.body, "body", errors)
	if not _positive_integer(c.body.get("cost")): errors.append("invalid_body_cost")
	if c.body.get("mode") != "choose_three": errors.append("invalid_body_mode")
	if not c.body.get("outcomes") is Dictionary or c.body.get("outcomes", {}).size() < 3: errors.append("insufficient_body_pool")
	else:
		for id in c.body.outcomes:
			var result = c.body.outcomes[id]
			if not result is Dictionary:
				errors.append("invalid_body_outcome:" + id)
				continue
			_meta(result, id, errors)
			_stats(result.get("stats", {}), id, errors)
			if result.get("stats", {}).size() != 1: errors.append("body_not_single_stat:" + id)
			if not _positive_integer(result.get("weight")): errors.append("invalid_body_weight:" + id)
	return errors

static func _meta(value: Dictionary, id: String, errors: Array):
	for key in ["name", "provenance", "source_ref", "design_notice"]:
		if not value.get(key) is String or value.get(key, "").is_empty(): errors.append("missing_meta:" + id + ":" + key)
	if not value.get("status") in ["prototype_initial", "unsupported"]: errors.append("invalid_status:" + id)
	if value.get("release_ready", true) != false: errors.append("not_release_content:" + id)
	if not value.get("required_hooks") is Array or value.get("required_hooks", []).is_empty(): errors.append("missing_hooks:" + id)

static func _positive(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value > 0

static func _positive_integer(value) -> bool:
	return _positive(value) and value == floor(value)

static func _nonnegative_integer(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value == floor(value)

static func _stats(value, id: String, errors: Array):
	if not value is Dictionary:
		errors.append("invalid_stats:" + id)
		return
	for stat in value:
		if not stat in STATS or not _positive(value[stat]): errors.append("invalid_stat:" + id + ":" + stat)

static func _visit(id: String, items: Dictionary, stack: Array, done: Dictionary, errors: Array):
	if id in stack:
		errors.append("recipe_cycle:" + id)
		return
	if done.has(id) or not items.get(id) is Dictionary: return
	var next := stack.duplicate()
	next.append(id)
	var components = items[id].get("components", [])
	if components is Array:
		for part in components:
			if part is String and items.has(part): _visit(part, items, next, done, errors)
	done[id] = true

static func _forbidden(value, path: String, errors: Array):
	if value is Dictionary:
		for key in value:
			if key in BANNED: errors.append("forbidden_field:" + path + ":" + key)
			_forbidden(value[key], path + "." + key, errors)
	elif value is Array:
		for entry in value: _forbidden(entry, path + "[]", errors)
