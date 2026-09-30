extends "res://scripts/progression/model.gd"
## Additive prototype adapter. Original Model API and fixture behavior remain intact.
const Catalog = preload("res://scripts/progression/catalog_validation.gd")
var supported_hooks: Array = []
var catalog_errors: Array = []

func _init(definitions: Dictionary = {}, actor_id: String = "local", seed_value: int = 1):
	super(definitions, actor_id, seed_value)
	catalog_errors = Catalog.validate(config)

# Trusted coordinator only. Names are a declaration, never proof that combat implements them.
# Runtime capabilities are deliberately NOT saved: loading a checkpoint cannot enable a hook.
func set_supported_hooks(hooks: Array) -> void:
	supported_hooks = hooks.duplicate()

func support(definition: Dictionary) -> Dictionary:
	var missing: Array = []
	for hook in definition.get("required_hooks", []):
		if not hook in supported_hooks: missing.append(hook)
	var available: bool = catalog_errors.is_empty() and definition.get("status") == "prototype_initial" and missing.is_empty()
	return {"supported": available, "status": "available" if available else "unsupported", "missing_hooks": missing, "catalog_errors": catalog_errors.duplicate()}

func _item_support(id: String) -> bool:
	if not config.items.has(id): return false
	var item: Dictionary = config.items[id]
	if not support(item).supported: return false
	var passive: String = item.get("passive", "")
	return passive.is_empty() or support(config.passives[passive]).supported

func _dependency_met(hex: Dictionary) -> bool:
	var required: String = hex.get("requires", "")
	if required.is_empty(): return true
	for slot in state.skills:
		var skill: Dictionary = state.skills[slot]
		if skill.rank > 0 and (skill.candidate == required or slot == required): return true
	return false

func snapshot() -> Dictionary:
	var out := super.snapshot()
	for id in state.selected_hex:
		out.hex_status[id] = "unsupported" if not support(config.hexes[id]).supported else ("active" if _dependency_met(config.hexes[id]) else "dormant")
	out["body_pending"] = {}
	for purchase in state.body:
		if purchase.get("selected", "").is_empty(): out.body_pending = purchase.duplicate(true)
	out["content_profile"] = "playable_prototype"
	out["catalog_errors"] = catalog_errors.duplicate()
	out["content_warnings"] = []
	var passive_counts := {}
	for entry in state.inventory:
		var item: Dictionary = config.items[entry.id]
		if not item.passive.is_empty(): passive_counts[item.passive] = passive_counts.get(item.passive, 0) + 1
		if not _item_support(entry.id): out.content_warnings.append({"reason":"unsupported_effect", "item_id":entry.id})
	for key in passive_counts:
		if passive_counts[key] > 1: out.content_warnings.append({"reason":"duplicate_unique_passive", "effect_key":key, "owned_copies":passive_counts[key], "active_copies":1 if support(config.passives[key]).supported else 0})
	return out

func shop_catalog() -> Dictionary:
	var out := super.shop_catalog()
	for id in out:
		out[id]["availability"] = support(out[id])
		out[id].availability.supported = _item_support(id)
		out[id].availability.status = "available" if _item_support(id) else "unsupported"
	return out

func _apply(action: String, a: Dictionary) -> String:
	if not catalog_errors.is_empty(): return "invalid_catalog"
	if action == "buy_body":
		if state.phase != "safe": return "unsafe_phase"
		if not support(config.body).supported: return "unsupported_effect"
		for purchase in state.body:
			if purchase.selected.is_empty(): return "body_choice_pending"
		if state.gold < config.body.cost: return "insufficient_gold"
		var available := 0
		for outcome in config.body.outcomes.values():
			if support(outcome).supported: available += 1
		if available < 3: return "body_pool_exhausted"
		var candidates: Array = []
		for count in range(3):
			var pool: Array = []
			var total := 0
			for id in config.body.outcomes:
				if id in candidates or not support(config.body.outcomes[id]).supported: continue
				total += int(config.body.outcomes[id].weight)
				pool.append([id, total])
			state.rng = (int(state.rng) * 48271) % 2147483647
			for pair in pool:
				if int(state.rng) % total < pair[1]:
					candidates.append(pair[0])
					break
		state.gold -= config.body.cost
		state.body.append({"purchase_id": state.body.size() + 1, "cost": config.body.cost, "definition_version": config.version, "candidates": candidates, "selected": ""})
		return ""
	if action == "select_body":
		if state.phase != "safe": return "unsafe_phase"
		if not support(config.body).supported: return "unsupported_effect"
		for purchase in state.body:
			if purchase.purchase_id != a.get("purchase_id", -1): continue
			if not purchase.selected.is_empty(): return "already_selected"
			if not a.get("outcome", "") in purchase.candidates: return "invalid_body_choice"
			if not support(config.body.outcomes[a.outcome]).supported: return "unsupported_effect"
			purchase.selected = a.outcome
			return ""
		return "missing_body_purchase"
	if action in ["hex_open", "hex_refresh", "hex_select"] and state.phase != "safe": return "unsafe_phase"
	if action == "hex_select":
		var offer: Dictionary = state.offers.get(str(a.get("milestone", 0)), {})
		var index: int = a.get("slot", -1)
		if not offer.is_empty() and index >= 0 and index < 4:
			if not support(config.hexes[offer.slots[index]]).supported: return "unsupported_effect"
	return super._apply(action, a)

func _buy(id: String) -> String:
	if not config.items.has(id): return "missing_definition"
	if not _item_support(id): return "unsupported_effect"
	return super._buy(id)

func _use(uid: int) -> String:
	for entry in state.inventory:
		if entry.uid != uid: continue
		if not _item_support(entry.id): return "unsupported_effect"
		var recovery: Dictionary = config.items[entry.id].get("recovery", {})
		if not state.phase in recovery.get("allowed_phases", []): return "unsafe_phase"
	return super._use(uid)

func equipment_effects() -> Dictionary:
	var result := {"stats": {}, "passives": []}
	for entry in state.inventory:
		if not _item_support(entry.id): continue
		var item: Dictionary = config.items[entry.id]
		_add_stats(result.stats, item.stats, entry.count)
		var passive: String = item.passive
		if not passive.is_empty() and not passive in result.passives:
			result.passives.append(passive)
			_add_stats(result.stats, config.passives[passive].stats)
	return result

func body_effects() -> Dictionary:
	var stats := {}
	if not support(config.body).supported: return stats
	for purchase in state.body:
		if not purchase.selected.is_empty() and support(config.body.outcomes[purchase.selected]).supported: _add_stats(stats, config.body.outcomes[purchase.selected].stats)
	return stats

func aggregate_effects() -> Dictionary:
	var result := equipment_effects()
	_add_stats(result.stats, body_effects())
	result["hexes"] = []
	for id in state.selected_hex:
		if support(config.hexes[id]).supported and _dependency_met(config.hexes[id]):
			_add_stats(result.stats, config.hexes[id].stats)
			result.hexes.append(id)
	return result

# Pure numeric projection, no mutation of current HP/CD/charges or combat actor.
func project_stats(base: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	var additions: Dictionary = aggregate_effects().stats
	for stat in additions:
		if config.stat_units[stat] == "base_fraction": out[stat] = base.get(stat, 0) * (1.0 + additions[stat])
		else: out[stat] = base.get(stat, 0) + additions[stat]
	for entry in [["cooldown_reduction", 0.65], ["tenacity", 1.0], ["attack_speed", 2.5]]:
		if out.has(entry[0]): out[entry[0]] = minf(out[entry[0]], entry[1])
	return out

func _add_stats(target: Dictionary, additions: Dictionary, count: int = 1) -> void:
	for stat in additions: target[stat] = target.get(stat, 0) + additions[stat] * count

func _draw(hero_only: bool, excluded: Array) -> String:
	var pool: Array = []
	var total := 0
	var excluded_keys: Array = []
	for id in excluded + state.selected_hex:
		if config.hexes.has(id): excluded_keys.append(config.hexes[id].effect_key)
	for offer in state.offers.values():
		if offer.selected.is_empty():
			for id in offer.slots: excluded_keys.append(config.hexes[id].effect_key)
	for id in config.hexes:
		var hex: Dictionary = config.hexes[id]
		if not support(hex).supported or hex.effect_key in excluded_keys: continue
		if not hex.hero in ["", state.hero_id]: continue
		if hero_only and hex.hero != state.hero_id: continue
		var weight: int = maxi(1, int(hex.weight) / (1 + int(state.seen_hex.get(id, 0))))
		if not _dependency_met(hex): weight = maxi(1, int(weight * config.policies.hex_unlearned_weight_multiplier))
		total += weight
		pool.append([id, total])
	if pool.is_empty(): return ""
	state.rng = (int(state.rng) * 48271) % 2147483647
	for pair in pool:
		if int(state.rng) % total < pair[1]:
			state.seen_hex[pair[0]] = int(state.seen_hex.get(pair[0], 0)) + 1
			return pair[0]
	return ""

func _supports_catalog_profile() -> bool:
	return true
