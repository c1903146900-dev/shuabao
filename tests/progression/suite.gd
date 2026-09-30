extends RefCounted
const EXPECTED_RANKS = {"P": 3, "Q": 5, "E": 5, "R": 3}
const Model = preload("res://scripts/progression/model.gd")
var checks := 0
var failures: Array = []
var serial := 0
var definitions: Dictionary

func check(condition: bool, label: String):
	checks += 1
	if not condition: failures.append(label)

func send(model, action: String, args: Dictionary = {}) -> Dictionary:
	serial += 1
	return model.command(str(serial), action, args)

func rich(config_override: Dictionary = {}):
	var d := definitions.duplicate(true)
	for key in config_override: d[key] = config_override[key]
	var m = Model.new(d)
	send(m, "reward_minion", {"event_id": "seed", "gold": 10000, "xp": 1700})
	return m

func learn(m, slot: String, candidate: String = "") -> Dictionary:
	return send(m, "learn", {"slot": slot, "candidate": candidate if not candidate.is_empty() else slot + "1", "expected_rank": m.state.skills[slot].rank})

func unchanged_failure(m, action: String, args: Dictionary, reason: String):
	var before = m.snapshot()
	var result = send(m, action, args)
	check(not result.accepted and result.reason == reason and m.snapshot() == before, action + ": " + reason + " atomic")

func run() -> Dictionary:
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/fixture.json"))
	var m = Model.new(definitions)
	check(m.state.points == 1 and m.state.level == 1, "level 1 grants 1")
	for level in range(2, 19):
		send(m, "reward_minion", {"event_id": str(level), "gold": 1, "xp": 100})
		check(m.state.points == level and m.state.granted_level_ids.size() == level, "level conservation " + str(level))
	unchanged_failure(m, "reward_minion", {"event_id": "18", "gold": 1, "xp": 100}, "duplicate_reward")
	send(m, "reward_minion", {"event_id": "cap", "gold": 0, "xp": 100000})
	check(m.state.level == 18 and m.state.points == 18, "18 hard cap")
	for slot in ["P", "Q", "E", "R"]:
		for rank in range(EXPECTED_RANKS[slot]): check(learn(m, slot).accepted, "full build " + slot + str(rank))
	check(m.state.points == 0, "full build costs 18")
	unchanged_failure(m, "learn", {"slot": "Q", "candidate": "Q1", "expected_rank": 5}, "rank_cap")
	unchanged_failure(m, "respec", {}, "training_required")
	send(m, "context", {"phase": "safe", "training": true})
	send(m, "respec")
	check(m.state.points == 18, "respec refunds actual R costs")
	var unresolved = definitions.duplicate(true)
	unresolved.erase("r_gates")
	var gates = Model.new(unresolved)
	send(gates, "reward_minion", {"event_id": "level", "gold": 0, "xp": 1700})
	check(learn(gates, "R").accepted, "R first gate at six")
	unchanged_failure(gates, "learn", {"slot": "R", "candidate": "R1", "expected_rank": 1}, "unresolved_r_gate")
	var low = Model.new(definitions)
	unchanged_failure(low, "learn", {"slot": "R", "candidate": "R1", "expected_rank": 0}, "level_gate")
	learn(low, "Q")
	unchanged_failure(low, "learn", {"slot": "E", "candidate": "E1", "expected_rank": 0}, "insufficient_points")
	var one = rich()
	for slot in ["P", "Q", "E"]:
		for rank in range(EXPECTED_RANKS[slot]): learn(one, slot)
	learn(one, "R")
	learn(one, "R")
	# 16 spent, consume one fresh non-R point using a separately constrained level-17 ledger.
	var rlow = Model.new(definitions)
	send(rlow, "reward_minion", {"event_id": "level6", "gold": 0, "xp": 500})
	learn(rlow, "R")
	for rank in range(4): learn(rlow, "Q")
	unchanged_failure(rlow, "learn", {"slot": "R", "candidate": "R1", "expected_rank": 1}, "insufficient_points")
	# Allocate in combat, undo safely before next encounter; old allocations are committed.
	send(m, "context", {"phase": "combat"})
	learn(m, "Q")
	unchanged_failure(m, "undo_skill", {}, "unsafe_phase")
	send(m, "context", {"phase": "safe"})
	check(send(m, "undo_skill").accepted, "combat new points reversible before next combat")
	learn(m, "Q")
	send(m, "context", {"phase": "combat"})
	send(m, "context", {"phase": "safe"})
	unchanged_failure(m, "undo_skill", {}, "undo_boundary")
	# All eleven candidates are independently learnable, no cross-slot requirements.
	for slot in definitions.candidates:
		for candidate in definitions.candidates[slot]:
			var isolated = rich()
			check(learn(isolated, slot, candidate).accepted, "independent " + candidate)
	var shop = rich()
	for i in range(6): check(send(shop, "buy", {"item": "component"}).accepted, "fill slot " + str(i))
	check(send(shop, "buy", {"item": "blade"}).accepted and shop.occupied_slots() == 6 and shop.state.gold == 9250, "full inventory combine consumes before capacity; component credit")
	unchanged_failure(shop, "buy", {"item": "component"}, "inventory_full")
	var blade = shop.state.inventory.back()
	check(blade.invested == 250, "recipe actual investment")
	send(shop, "sell", {"uid": blade.uid})
	check(shop.state.gold == 9475, "sell 90 percent actual investment")
	send(shop, "undo_shop")
	check(shop.state.gold == 9250 and shop.state.inventory.back() == blade, "sell undo exact")
	send(shop, "undo_shop")
	check(shop.state.gold == 9400 and shop.state.inventory.size() == 6, "combine undo restores components")
	var poor = Model.new(definitions)
	unchanged_failure(poor, "buy", {"item": "component"}, "insufficient_gold")
	var replay = rich()
	var r1 = replay.command("buy-once", "buy", {"item": "component"})
	var r2 = replay.command("buy-once", "buy", {"item": "component"})
	check(r1 == r2 and replay.state.gold == 9900 and replay.state.inventory.size() == 1, "duplicate command is exactly once")
	check(replay.command("buy-once", "sell", {"uid": 1}).reason == "command_id_conflict", "command id cannot change payload")
	for i in range(2):
		send(replay, "buy", {"item": "component"})
		send(replay, "buy", {"item": "blade"})
	check(replay.equipment_effects().stats.AD == 7 and replay.equipment_effects().passives.size() == 1, "duplicate equipment stats stack passive unique")
	var body = rich()
	send(body, "context", {"phase": "safe", "training": true})
	send(body, "buy", {"item": "component"})
	for i in range(3): check(send(body, "buy_body").accepted, "repeat fixed body price")
	send(body, "undo_shop")
	send(body, "respec")
	check(body.state.gold == 9850 and body.state.body.size() == 3, "body expense survives shop undo and respec")
	unchanged_failure(body, "undo_body", {}, "unknown_command")
	var pot = rich()
	for i in range(5): check(send(pot, "buy", {"item": "normal"}).accepted, "normal potion " + str(i))
	check(pot.occupied_slots() == 1, "explicit stack experiment")
	unchanged_failure(pot, "buy", {"item": "normal"}, "normal_cap")
	unchanged_failure(pot, "buy", {"item": "special"}, "recovery_mutex")
	var singles = rich({"potion_policy": {"normal_stack": false, "mutex": "holding"}})
	for i in range(5): send(singles, "buy", {"item": "normal"})
	check(singles.occupied_slots() == 5, "explicit one-unit-one-slot experiment")
	var no_policy = Model.new({"items": definitions.items})
	unchanged_failure(no_policy, "buy", {"item": "normal"}, "unresolved_policy")
	var special = rich()
	send(special, "enter_level", {"combat_level_id": "act1-level1"})
	for i in range(3): send(special, "buy", {"item": "special"})
	for i in range(2): check(send(special, "use_item", {"uid": special.state.inventory[0].uid}).accepted, "special use " + str(i))
	unchanged_failure(special, "use_item", {"uid": special.state.inventory[0].uid}, "special_cap")
	send(special, "enter_level", {"combat_level_id": "act1-level1"})
	check(special.state.special_uses == 2, "same level cannot reset recovery")
	send(special, "enter_level", {"combat_level_id": "act1-level2"})
	check(send(special, "use_item", {"uid": special.state.inventory[0].uid}).accepted, "new level resets recovery")
	unchanged_failure(special, "enter_level", {"combat_level_id": "act1-level1"}, "old_level_id")
	var use_mutex = rich({"potion_policy": {"normal_stack": false, "mutex": "per_level_use"}})
	send(use_mutex, "enter_level", {"combat_level_id": "level"})
	send(use_mutex, "buy", {"item": "normal"})
	send(use_mutex, "buy", {"item": "special"})
	send(use_mutex, "use_item", {"uid": 1})
	unchanged_failure(use_mutex, "use_item", {"uid": 2}, "recovery_mutex")
	var hex = rich()
	for milestone in Model.MILESTONES:
		check(send(hex, "hex_open", {"milestone": milestone}).accepted, "milestone " + str(milestone))
		var offer = hex.state.offers[str(milestone)]
		check(definitions.hexes[offer.slots[3]].hero == "fengli", "right hero slot")
		var unique := {}
		for id in offer.slots: unique[id] = true
		check(unique.size() == 4, "offer unique")
		for slot in range(4):
			check(send(hex, "hex_refresh", {"milestone": milestone, "slot": slot}).accepted, "refresh slot " + str(slot))
			unchanged_failure(hex, "hex_refresh", {"milestone": milestone, "slot": slot}, "refresh_exhausted")
			for id in offer.slots: check(not id in offer.excluded and not id in hex.state.selected_hex, "no selected/excluded repeat")
		check(send(hex, "hex_select", {"milestone": milestone, "slot": 3}).accepted, "select once")
		unchanged_failure(hex, "hex_select", {"milestone": milestone, "slot": 0}, "already_selected")
	unchanged_failure(hex, "hex_open", {"milestone": 2}, "invalid_milestone")
	var seeded = rich()
	send(seeded, "hex_open", {"milestone": 1})
	var clone = Model.new(definitions)
	check(clone.restore(seeded.save()), "restore checkpoint")
	var request := {"milestone": 1, "slot": 3}
	check(seeded.command("determinism", "hex_refresh", request) == clone.command("determinism", "hex_refresh", request) and seeded.save() == clone.save(), "saved random state and receipts deterministic")
	var rthird = Model.new(definitions)
	send(rthird, "reward_minion", {"event_id": "six", "gold": 0, "xp": 500})
	learn(rthird, "R")
	learn(rthird, "R")
	learn(rthird, "Q")
	learn(rthird, "Q")
	unchanged_failure(rthird, "learn", {"slot": "R", "candidate": "R1", "expected_rank": 2}, "insufficient_points")
	var atom = Model.new(definitions)
	send(atom, "reward_minion", {"event_id": "poor", "gold": 100, "xp": 0})
	send(atom, "buy", {"item": "component"})
	unchanged_failure(atom, "buy", {"item": "blade"}, "insufficient_gold")
	check(atom.state.inventory.size() == 1 and atom.state.inventory[0].id == "component", "failed recipe restores component")
	var cycles = rich()
	for i in range(20):
		send(cycles, "buy", {"item": "component"})
		send(cycles, "buy", {"item": "blade"})
		send(cycles, "sell", {"uid": cycles.state.inventory[0].uid})
		for j in range(3): send(cycles, "undo_shop")
	check(cycles.state.gold == 10000 and cycles.state.inventory.is_empty(), "20 buy combine sell reverse cycles no arbitrage")
	check(body.body_effects().get("AD") == 3, "body attributes stack")
	var numbers = rich()
	learn(numbers, "Q")
	var first_numbers = numbers.skill_values("Q")
	learn(numbers, "Q")
	check(first_numbers.numbers.fixture_numeric_scale == 1.0 and numbers.skill_values("Q").numbers.fixture_numeric_scale == 1.1, "rank projection changes numeric values only")
	var dormant_config = definitions.duplicate(true)
	for id in dormant_config.hexes: dormant_config.hexes[id].requires = "Q1"
	var dormant = rich(dormant_config)
	send(dormant, "hex_open", {"milestone": 1})
	send(dormant, "hex_select", {"milestone": 1, "slot": 3})
	var selected: String = dormant.state.selected_hex[0]
	check(dormant.snapshot().hex_status[selected] == "dormant", "unlearned corresponding hex dormant")
	learn(dormant, "Q")
	check(dormant.snapshot().hex_status[selected] == "active", "learning wakes corresponding hex")
	send(dormant, "context", {"phase": "safe", "training": true})
	send(dormant, "respec")
	check(dormant.snapshot().hex_status[selected] == "dormant", "respec preserves selection and sleeps hex")
	var json_clone = Model.new(definitions)
	check(json_clone.restore(JSON.parse_string(JSON.stringify(seeded.save()))), "JSON checkpoint restores")
	check(JSON.stringify(seeded.command("after-json", "hex_open", {"milestone": 4})) == JSON.stringify(json_clone.command("after-json", "hex_open", {"milestone": 4})) and JSON.stringify(seeded.snapshot()) == JSON.stringify(json_clone.snapshot()), "JSON RNG roundtrip continuation")
	check(json_clone.command("determinism", "hex_refresh", request) == seeded.receipts["determinism"].result, "JSON replay receipt idempotency")
	var tiny = rich({"hexes": {"only": {"hero": "fengli", "weight": 100}}})
	unchanged_failure(tiny, "hex_open", {"milestone": 1}, "pool_exhausted")
	check(tiny.state.seen_hex.is_empty(), "pool exhaustion rolls back seen and RNG")
	var pending = rich()
	check(pending.snapshot().pending_milestones == [1, 4, 7, 10, 13], "multi-level gain preserves all pending milestones")
	send(pending, "hex_open", {"milestone": 1})
	var displayed: Array = pending.state.offers["1"].slots.duplicate()
	send(pending, "hex_open", {"milestone": 4})
	for id in pending.state.offers["4"].slots: check(not id in displayed, "concurrent offers exclude displayed candidates")
	var original = pending.snapshot()
	send(pending, "hex_open", {"milestone": 1})
	check(pending.state.offers == original.offers, "reopen preserves offer and refresh allowance")
	var reduced_hits := 0
	var fresh_hits := 0
	for trial in range(1, 201):
		var fresh = Model.new(definitions, "weight-fixture", trial * 7919)
		var seen = Model.new(definitions, "weight-fixture", trial * 7919)
		seen.state.seen_hex["fixture_hex_00"] = 10
		if fresh._draw(false, []) == "fixture_hex_00": fresh_hits += 1
		if seen._draw(false, []) == "fixture_hex_00": reduced_hits += 1
	check(reduced_hits < fresh_hits, "fixed seed population reduces seen-unselected weight")
	var no_extras = rich()
	for action in ["reward_equipment_points", "quest_points", "hex_points", "body_points", "grant_points"]:
		unchanged_failure(no_extras, action, {"points": 1}, "unknown_command")
	unchanged_failure(no_extras, "reward_minion", {"event_id": "invalid", "gold": 1, "xp": 0, "equipment": ["blade"]}, "invalid_reward")
	# Runtime remains owned by combat, never accepted as writable progression arguments.
	var combat_runtime := {"hp": 37, "cooldowns": {"Q": 12.5}}
	var before_runtime := combat_runtime.duplicate(true)
	send(body, "respec")
	check(combat_runtime == before_runtime and not body.snapshot().has("hp"), "model cannot mutate external HP/CD (integration still required)")
	check(Model.new(definitions, "other").state.gold == 0 and Model.new(definitions, "other").state.xp == 0, "personal wallets XP isolated")
	return {"checks": checks, "failures": failures, "passed": failures.is_empty()}
