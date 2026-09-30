extends RefCounted
## Pure per-actor authority. No HP/CD references or wall-clock side effects.
const COSTS = {"P": [1, 1, 1], "Q": [1, 1, 1, 1, 1], "E": [1, 1, 1, 1, 1], "R": [1, 2, 2]}
const MILESTONES = [1, 4, 7, 10, 13]
var config: Dictionary
var state: Dictionary
var receipts: Dictionary = {}

func _init(definitions: Dictionary = {}, actor_id: String = "local", seed_value: int = 1):
	config = _canonical(definitions)
	state = {"actor_id": actor_id, "hero_id": "fengli", "revision": 0, "level": 1, "xp": 0, "gold": 0, "granted_level_ids": [1], "points": 1, "skills": {}, "allocations": [], "inventory": [], "next_item": 1, "shop_undo": [], "body": [], "phase": "safe", "training": false, "combat_level_id": "", "visited_levels": [], "special_uses": 0, "recovery_mode": "", "offers": {}, "selected_hex": [], "seen_hex": {}, "rng": maxi(1, seed_value % 2147483647), "reward_ids": []}
	for slot in COSTS:
		state.skills[slot] = {"candidate": "", "rank": 0}

func snapshot() -> Dictionary:
	var out = state.duplicate(true)
	out["definition_version"] = config.get("version", "unresolved")
	out["hex_status"] = {}
	out["pending_milestones"] = []
	for milestone in MILESTONES:
		if milestone <= state.level and (not state.offers.has(str(milestone)) or state.offers[str(milestone)].selected.is_empty()): out.pending_milestones.append(milestone)
	for id in state.selected_hex:
		var required: String = config.hexes[id].get("requires", "")
		var active := required.is_empty()
		for skill in state.skills.values():
			active = active or (skill.candidate == required and skill.rank > 0)
		out.hex_status[id] = "active" if active else "dormant"
	return out

func save() -> Dictionary:
	return {"schema": 1, "definition_version": config.get("version", ""), "state": state.duplicate(true), "receipts": receipts.duplicate(true)}

# Trusted local checkpoint only; network/user-controlled save validation belongs to integration.
func restore(checkpoint: Dictionary) -> bool:
	if checkpoint.get("schema") != 1 or checkpoint.get("definition_version") != config.get("version", ""):
		return false
	state = _canonical(checkpoint.state)
	receipts = _canonical(checkpoint.receipts)
	return true

func command(id: String, action: String, args: Dictionary = {}) -> Dictionary:
	if id.is_empty():
		return {"accepted": false, "reason": "missing_command_id", "state_revision": state.revision, "events": []}
	var request := {"action": action, "args": _canonical(args)}
	if receipts.has(id):
		if receipts[id].request != request:
			return {"accepted": false, "reason": "command_id_conflict", "state_revision": state.revision, "events": []}
		return receipts[id].result.duplicate(true)
	var before := state.duplicate(true)
	var reason := _apply(action, args)
	if not reason.is_empty():
		state = before
	else:
		state.revision += 1
	var result := {"accepted": reason.is_empty(), "reason": reason, "state_revision": state.revision, "events": []}
	if reason.is_empty():
		result.events.append({"type": action, "actor_id": state.actor_id, "parameters": _canonical(args), "definition_version": config.get("version", "unresolved")})
		if action == "use_item":
			for entry in before.inventory:
				if entry.uid == args.get("uid", -1):
					result.events.append({"type": "recovery_requested", "actor_id": state.actor_id, "item_id": entry.id, "recovery": config.items[entry.id].get("recovery", {}), "provenance": "unresolved" if not config.items[entry.id].has("recovery") else config.get("provenance", "unresolved")})
	receipts[id] = {"request": request, "result": result.duplicate(true)}
	return result

func _apply(action: String, a: Dictionary) -> String:
	match action:
		"context":
			if not a.get("phase", "") in ["safe", "combat"]: return "invalid_phase"
			if a.phase == "combat" and state.phase != "combat":
				state.allocations.clear()
				state.shop_undo.clear()
			state.phase = a.phase
			state.training = a.get("training", false) and a.phase == "safe"
			return ""
		"enter_level":
			var level_id: String = a.get("combat_level_id", "")
			if level_id.is_empty(): return "missing_level_id"
			if level_id == state.combat_level_id: return ""
			if level_id in state.visited_levels: return "old_level_id"
			state.visited_levels.append(level_id)
			state.combat_level_id = level_id
			state.allocations.clear()
			state.special_uses = 0
			state.recovery_mode = ""
			state.shop_undo.clear()
			return ""
		"reward_minion":
			var event: String = a.get("event_id", "")
			if event.is_empty(): return "missing_event_id"
			if event in state.reward_ids: return "duplicate_reward"
			if a.has("equipment") or a.has("points"): return "invalid_reward"
			var gold: int = a.get("gold", -1)
			var xp: int = a.get("xp", -1)
			if gold < 0 or xp < 0: return "invalid_reward"
			if not config.has("xp_per_level"): return "unresolved_xp_curve"
			state.reward_ids.append(event)
			state.gold += gold
			state.xp += xp
			while state.level < 18 and state.xp >= config.xp_per_level[state.level - 1]:
				state.xp -= config.xp_per_level[state.level - 1]
				state.level += 1
				state.granted_level_ids.append(state.level)
				state.points += 1
			return ""
		"learn":
			var slot: String = a.get("slot", "")
			if not COSTS.has(slot): return "invalid_slot"
			var skill: Dictionary = state.skills[slot]
			var rank: int = skill.rank
			if rank != a.get("expected_rank", -1): return "stale_rank"
			if rank >= COSTS[slot].size(): return "rank_cap"
			var candidate: String = a.get("candidate", "")
			if not candidate in config.get("candidates", {}).get(slot, []): return "invalid_candidate"
			if rank > 0 and candidate != skill.candidate: return "training_required"
			if state.points < COSTS[slot][rank]: return "insufficient_points"
			if slot == "R":
				var gates: Array = config.get("r_gates", [6, null, null]).duplicate()
				gates[0] = 6
				if gates[rank] == null: return "unresolved_r_gate"
				if state.level < gates[rank]: return "level_gate"
			state.allocations.append({"slot": slot, "before": skill.duplicate(true), "cost": COSTS[slot][rank]})
			state.points -= COSTS[slot][rank]
			skill.candidate = candidate
			skill.rank += 1
			return ""
		"undo_skill":
			if state.phase != "safe": return "unsafe_phase"
			if state.allocations.is_empty(): return "undo_boundary"
			var allocation: Dictionary = state.allocations.pop_back()
			state.skills[allocation.slot] = allocation.before
			state.points += allocation.cost
			return ""
		"respec":
			if not state.training: return "training_required"
			for slot in COSTS:
				for rank in range(state.skills[slot].rank): state.points += COSTS[slot][rank]
				state.skills[slot] = {"candidate": "", "rank": 0}
			state.allocations.clear()
			return ""
		"open_shop":
			return "" if state.phase == "safe" else "unsafe_phase"
		"buy", "sell", "undo_shop":
			if state.phase != "safe": return "unsafe_phase"
			if action == "undo_shop":
				if state.shop_undo.is_empty(): return "undo_boundary"
				var undo: Dictionary = state.shop_undo.pop_back()
				state.gold += undo.gold_delta
				state.inventory = undo.inventory
				return ""
			var previous: Array = state.inventory.duplicate(true)
			var money: int = state.gold
			var error := _buy(a.get("item", "")) if action == "buy" else _sell(a.get("uid", -1))
			if not error.is_empty(): return error
			state.shop_undo.append({"inventory": previous, "gold_delta": money - state.gold})
			return ""
		"buy_body":
			if not state.training: return "training_required"
			if not config.has("body"): return "unresolved_body"
			if state.gold < config.body.cost: return "insufficient_gold"
			state.gold -= config.body.cost
			state.body.append({"cost": config.body.cost, "definition_version": config.version})
			# Irreversible inventory-independent purchase is not placed in undo ledger.
			return ""
		"use_item":
			return _use(a.get("uid", -1))
		"hex_open":
			return _open_offer(int(a.get("milestone", 0)))
		"hex_refresh", "hex_select":
			var key := str(a.get("milestone", 0))
			if not state.offers.has(key): return "missing_offer"
			var offer: Dictionary = state.offers[key]
			var slot: int = a.get("slot", -1)
			if slot < 0 or slot > 3: return "invalid_slot"
			if not offer.selected.is_empty(): return "already_selected"
			if action == "hex_select":
				offer.selected = offer.slots[slot]
				state.selected_hex.append(offer.selected)
				return ""
			if offer.refresh_used[slot]: return "refresh_exhausted"
			var removed: String = offer.slots[slot]
			offer.excluded.append(removed)
			var pick := _draw(slot == 3, offer.slots + offer.excluded)
			if pick.is_empty(): return "pool_exhausted"
			offer.slots[slot] = pick
			offer.refresh_used[slot] = true
			return ""
	return "unknown_command"

func _count(kind: String) -> int:
	var count := 0
	for item in state.inventory:
		if config.items[item.id].get("kind", "equipment") == kind: count += item.count
	return count

func occupied_slots() -> int:
	return state.inventory.size()

func _buy(id: String) -> String:
	if not config.get("items", {}).has(id): return "missing_definition"
	var item: Dictionary = config.items[id]
	var kind: String = item.get("kind", "equipment")
	if kind in ["normal", "special"]:
		if not config.has("potion_policy"): return "unresolved_policy"
		if not config.potion_policy.get("mutex", "") in ["holding", "per_level_use"] or not config.potion_policy.has("normal_stack"): return "unresolved_policy"
		if config.potion_policy.mutex == "holding" and _count("special" if kind == "normal" else "normal") > 0: return "recovery_mutex"
		if kind == "normal" and _count("normal") >= 5: return "normal_cap"
	var paid := 0
	for component in item.get("components", []):
		var found := -1
		for i in range(state.inventory.size()):
			if state.inventory[i].id == component:
				found = i
				break
		if found == -1: return "missing_component"
		paid += state.inventory[found].invested
		state.inventory.remove_at(found)
	var charge: int = maxi(0, int(item.price) - paid)
	if state.gold < charge: return "insufficient_gold"
	var stacked := false
	if kind == "normal" and config.potion_policy.normal_stack:
		for entry in state.inventory:
			if entry.id == id:
				entry.count += 1
				entry.invested += charge
				stacked = true
				break
	if not stacked:
		if occupied_slots() >= 6: return "inventory_full"
		state.inventory.append({"uid": state.next_item, "id": id, "count": 1, "invested": paid + charge})
		state.next_item += 1
	state.gold -= charge
	return ""

func _sell(uid: int) -> String:
	for i in range(state.inventory.size()):
		if state.inventory[i].uid == uid:
			state.gold += int(floor(state.inventory[i].invested * 0.9))
			state.inventory.remove_at(i)
			return ""
	return "missing_item"

func _use(uid: int) -> String:
	if not config.has("potion_policy"): return "unresolved_policy"
	if not config.potion_policy.get("mutex", "") in ["holding", "per_level_use"]: return "unresolved_policy"
	if state.combat_level_id.is_empty(): return "missing_level_id"
	for i in range(state.inventory.size()):
		var entry: Dictionary = state.inventory[i]
		if entry.uid != uid: continue
		var kind: String = config.items[entry.id].get("kind", "equipment")
		if not kind in ["normal", "special"]: return "not_consumable"
		if config.potion_policy.mutex == "per_level_use" and not state.recovery_mode in ["", kind]: return "recovery_mutex"
		if kind == "special" and state.special_uses >= 2: return "special_cap"
		if kind == "special": state.special_uses += 1
		state.recovery_mode = kind
		# Keep actual investment of remaining units. Fixture units have equal price.
		entry.invested -= int(entry.invested / entry.count)
		entry.count -= 1
		if entry.count == 0: state.inventory.remove_at(i)
		state.shop_undo.clear()
		return ""
	return "missing_item"

func equipment_effects() -> Dictionary:
	var result := {"stats": {}, "passives": []}
	for entry in state.inventory:
		var item: Dictionary = config.items[entry.id]
		for stat in item.get("stats", {}): result.stats[stat] = result.stats.get(stat, 0) + item.stats[stat] * entry.count
		var passive: String = item.get("passive", "")
		if not passive.is_empty() and not passive in result.passives: result.passives.append(passive)
	return result

func _draw(hero_only: bool, excluded: Array) -> String:
	var pool: Array = []
	var total := 0
	for id in config.get("hexes", {}):
		var hex: Dictionary = config.hexes[id]
		if id in excluded or id in state.selected_hex: continue
		var displayed_elsewhere := false
		for offer in state.offers.values():
			if offer.selected.is_empty() and id in offer.slots: displayed_elsewhere = true
		if displayed_elsewhere: continue
		if not hex.get("hero", "") in ["", state.hero_id]: continue
		if hero_only and hex.get("hero", "") != state.hero_id: continue
		var weight: int = maxi(1, int(hex.get("weight", 100)) / (1 + int(state.seen_hex.get(id, 0))))
		total += weight
		pool.append([id, total])
	if pool.is_empty(): return ""
	state.rng = (int(state.rng) * 48271) % 2147483647
	var value: int = int(state.rng) % total
	for pair in pool:
		if value < pair[1]:
			state.seen_hex[pair[0]] = int(state.seen_hex.get(pair[0], 0)) + 1
			return pair[0]
	return ""

func _open_offer(milestone: int) -> String:
	if not milestone in MILESTONES or milestone > state.level: return "invalid_milestone"
	var key := str(milestone)
	if state.offers.has(key): return ""
	var offer := {"slots": ["", "", "", ""], "refresh_used": [false, false, false, false], "selected": "", "excluded": []}
	# Reserve exclusive slot first so a small pool cannot be consumed by mixed slots.
	for slot in [3, 0, 1, 2]:
		var pick := _draw(slot == 3, offer.slots)
		if pick.is_empty(): return "pool_exhausted"
		offer.slots[slot] = pick
	state.offers[key] = offer
	return ""

## Numeric projections only; mechanisms belong to the chosen base ability, never rank branches.
func skill_values(slot: String) -> Dictionary:
	if not state.skills.has(slot): return {"reason": "invalid_slot"}
	var skill: Dictionary = state.skills[slot]
	if skill.rank == 0: return {}
	var table: Array = config.get("skill_numbers", {}).get(skill.candidate, [])
	if table.size() < skill.rank: return {"reason": "unresolved_rank_values"}
	return {"numbers": table[skill.rank - 1].duplicate(true), "provenance": config.get("provenance", "unresolved"), "definition_version": config.version}

func body_effects() -> Dictionary:
	var stats := {}
	for purchase in state.body:
		for stat in config.body.get("stats", {}): stats[stat] = stats.get(stat, 0) + config.body.stats[stat]
	return stats

func shop_catalog() -> Dictionary:
	return config.get("items", {}).duplicate(true)

# Godot JSON parses all numbers as floats. Canonicalize exact integers for counters,
# dictionary equality and replay receipts, preserving fractional numeric parameters.
func _canonical(value: Variant) -> Variant:
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
