extends RefCounted
const Model = preload("res://scripts/progression/catalog_model.gd")
const Validator = preload("res://scripts/progression/catalog_validation.gd")
var checks := 0
var failures: Array = []
var sequence := 0
var definitions: Dictionary
var hooks: Array = []

func check(ok: bool, label: String):
	checks += 1
	if not ok: failures.append(label)

func send(m, action: String, args: Dictionary = {}) -> Dictionary:
	sequence += 1
	return m.command("catalog-" + str(sequence), action, args)

func model(seed_value: int = 17):
	var m = Model.new(definitions, "catalog_test", seed_value)
	m.set_supported_hooks(hooks)
	send(m, "reward_minion", {"event_id": "test_funds", "gold": 100000, "xp": 100000})
	return m

func reject(m, action: String, args: Dictionary, reason: String):
	var before = m.snapshot()
	var reply = send(m, action, args)
	check(not reply.accepted and reply.reason == reason and m.snapshot() == before, action + " atomically rejects " + reason)

func buy_tree(m, id: String):
	for part in definitions.items[id].components: buy_tree(m, part)
	check(send(m, "buy", {"item": id}).accepted, "recipe buy " + id)

func run() -> Dictionary:
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/prototype/catalog.json"))
	hooks = ["stats.v1", "recovery.v1"]
	for stat in Validator.STATS: hooks.append("stat." + stat + ".v1")
	check(Validator.validate(definitions).is_empty(), "catalog semantic schema valid")
	var legacy = preload("res://scripts/progression/model.gd").new(definitions)
	reject(legacy, "buy", {"item":"iron_blade"}, "catalog_adapter_required")
	var closed = Model.new(definitions)
	reject(closed, "buy", {"item": "iron_blade"}, "unsupported_effect")
	reject(closed, "buy", {"item": "normal_tonic"}, "unsupported_effect")
	reject(closed, "buy_body", {}, "unsupported_effect")
	reject(closed, "hex_open", {"milestone": 1}, "pool_exhausted")
	var broken = definitions.duplicate(true)
	broken.items.iron_blade.components = ["iron_blade"]
	check(not Validator.validate(broken).is_empty(), "recipe cycle invalid")
	broken = definitions.duplicate(true)
	broken.items.thrust_spike.components = ["missing"]
	check(not Validator.validate(broken).is_empty(), "dangling recipe invalid")
	broken = definitions.duplicate(true)
	broken.items.iron_blade.price = null
	check(not Validator.validate(broken).is_empty(), "null price invalid")
	broken = definitions.duplicate(true)
	broken.items.thrust_spike.combine_fee = -1
	check(not Validator.validate(broken).is_empty(), "negative combine fee invalid")
	broken = definitions.duplicate(true)
	broken.hexes.public_sharpen.stats = {"skill_strength": 10}
	check(not Validator.validate(broken).is_empty(), "thirteenth stat rejected")
	broken = definitions.duplicate(true)
	broken.hexes.public_sharpen.skill_points = 1
	var bad_model = Model.new(broken)
	reject(bad_model, "buy", {"item": "iron_blade"}, "invalid_catalog")
	for id in definitions.items:
		if definitions.items[id].tier != "complete": continue
		var m = model()
		var start: int = m.state.gold
		buy_tree(m, id)
		check(start - m.state.gold == int(definitions.items[id].price) and m.state.inventory.size() == 1, "full recipe cost equals cumulative actual investment " + id)
		var bought = m.state.inventory[0].duplicate(true)
		check(bought.invested == definitions.items[id].price, "investment propagated " + id)
		send(m, "sell", {"uid": bought.uid})
		check(m.state.gold == start - bought.invested + int(floor(bought.invested * 0.9)), "actual sale refund " + id)
		while not m.state.shop_undo.is_empty(): check(send(m, "undo_shop").accepted, "undo recipe chain " + id)
		check(m.state.gold == start and m.state.inventory.is_empty(), "no recipe/undo arbitrage " + id)
	var full = model()
	buy_tree(full, "piercing_core")
	buy_tree(full, "cooling_core")
	for i in range(4): buy_tree(full, "iron_blade")
	check(full.occupied_slots() == 6, "full inventory fixture")
	check(send(full, "buy", {"item": "thrust_spike"}).accepted and full.occupied_slots() == 5, "multi-component craft while full")
	var passive = model()
	buy_tree(passive, "sanguine_edge")
	buy_tree(passive, "living_shell")
	buy_tree(passive, "living_shell")
	check(passive.equipment_effects().stats.hp_regen == 3 and passive.equipment_effects().passives == ["sustain_tissue"], "different and duplicate equipment share unique passive once")
	check(passive.equipment_effects().stats.max_hp == 560, "duplicate core stats stack")
	var base := {"AD": 100, "AP": 0, "attack_speed": 2.4, "max_hp": 1000, "hp": 37, "cooldown_reduction": 0.64, "tenacity": .98, "move_speed": 6, "cooldowns": {"Q": 7}}
	var before_base := base.duplicate(true)
	check(passive.project_stats(base).hp == 37 and base == before_base, "projection preserves current HP and input snapshot")
	var body = model()
	check(send(body, "buy_body").accepted, "body buy safely without training node")
	var pending = body.snapshot().body_pending
	check(pending.candidates.size() == 3 and body.body_effects().is_empty(), "three revealed pure stats wait for choice")
	reject(body, "buy_body", {}, "body_choice_pending")
	reject(body, "refresh_body", {}, "unknown_command")
	var saved = body.save()
	var cloned = Model.new(definitions)
	check(cloned.restore(JSON.parse_string(JSON.stringify(saved))), "pending body JSON save")
	check(cloned.snapshot().body_pending == pending, "body results persist without reroll")
	reject(cloned, "select_body", {"purchase_id": 1, "outcome": pending.candidates[0]}, "unsupported_effect")
	cloned.set_supported_hooks(hooks)
	check(send(cloned, "select_body", {"purchase_id": 1, "outcome": pending.candidates[0]}).accepted, "select after runtime rebinding")
	reject(cloned, "select_body", {"purchase_id": 1, "outcome": pending.candidates[1]}, "already_selected")
	var stats = cloned.body_effects()
	check(stats.size() == 1, "one chosen body outcome only")
	send(cloned, "context", {"phase": "safe", "training": true})
	send(cloned, "respec")
	check(cloned.body_effects() == stats and cloned.state.gold == 99100, "respec cannot refund or erase body")
	check(send(cloned, "buy_body").accepted and cloned.state.gold == 98200, "repeat fixed body price")
	# Proceeds spent irreversibly cannot be duplicated by undoing the sale.
	var interleaved = Model.new(definitions)
	interleaved.set_supported_hooks(hooks)
	send(interleaved, "reward_minion", {"event_id": "limited", "gold": 950, "xp": 0})
	buy_tree(interleaved, "iron_blade")
	send(interleaved, "sell", {"uid": interleaved.state.inventory[0].uid})
	send(interleaved, "buy_body")
	reject(interleaved, "undo_shop", {}, "insufficient_gold")
	var pot = model()
	send(pot, "enter_level", {"combat_level_id": "stable_level_1"})
	buy_tree(pot, "normal_tonic")
	reject(pot, "buy", {"item": "special_tonic"}, "recovery_mutex")
	send(pot, "context", {"phase": "combat"})
	reject(pot, "use_item", {"uid": pot.state.inventory[0].uid}, "unsafe_phase")
	send(pot, "context", {"phase": "safe"})
	var heal = send(pot, "use_item", {"uid": pot.state.inventory[0].uid})
	check(heal.accepted and heal.events[1].recovery.amount == .18 and heal.events[1].provenance == "new_tunable_initial", "explicit recovery event, no HP mutation")
	# Exhaustion stress: every slot refreshed; all-right and all-left selection paths.
	for seed_value in range(1, 41):
		for chosen_slot in [0, 3]:
			var hex = model(seed_value * 7919)
			for milestone in [1, 4, 7, 10, 13]:
				check(send(hex, "hex_open", {"milestone": milestone}).accepted, "five-round open")
				for slot in ([0, 1, 2, 3] if seed_value % 2 else [3, 2, 1, 0]):
					check(send(hex, "hex_refresh", {"milestone": milestone, "slot": slot}).accepted, "five-round independent refresh")
					var offer = hex.state.offers[str(milestone)]
					check(definitions.hexes[offer.slots[3]].hero == "fengli", "right slot stays Fengli")
					var unique := {}
					for id in offer.slots:
						unique[definitions.hexes[id].effect_key] = true
						check(not id in offer.excluded and not id in hex.state.selected_hex and definitions.hexes[id].status == "prototype_initial", "no unsupported/removed/selected filler")
					check(unique.size() == 4, "distinct effect keys")
					reject(hex, "hex_refresh", {"milestone": milestone, "slot": slot}, "refresh_exhausted")
				check(send(hex, "hex_select", {"milestone": milestone, "slot": chosen_slot}).accepted, "selection accepted")
			check(hex.state.selected_hex.size() == 5 and hex.state.points == 18, "five selections never give skill points")
	var discounted = model()
	buy_tree(discounted, "iron_blade")
	# Trusted historical-ledger fixture: lower real investment than current sticker price.
	discounted.state.inventory[0].invested = 400
	var before_sale: int = discounted.state.gold
	send(discounted, "sell", {"uid": discounted.state.inventory[0].uid})
	check(discounted.state.gold - before_sale == 360, "sale uses actual 400 investment rather than 450 sticker")
	var cap = model()
	for i in range(6): buy_tree(cap, "mainspring")
	check(cap.project_stats(base).attack_speed == 2.5, "attack speed capped after base-linear stacking")
	var lost_hook = model()
	buy_tree(lost_hook, "iron_blade")
	lost_hook.set_supported_hooks([])
	check(lost_hook.equipment_effects().stats.is_empty(), "missing runtime hook makes owned effect inactive")
	var dorm = model()
	# Deterministic injection of an already-selected valid dependency option isolates activation.
	dorm.state.selected_hex = ["fengli_q1_training"]
	check(dorm.snapshot().hex_status.fengli_q1_training == "dormant" and dorm.aggregate_effects().stats.is_empty(), "unlearned Q1 catalog option dormant")
	send(dorm, "learn", {"slot":"Q", "candidate":"Q1", "expected_rank":0})
	check(dorm.snapshot().hex_status.fengli_q1_training == "active" and dorm.aggregate_effects().stats.AD == 16, "learn activates only supported numeric option")
	send(dorm, "context", {"phase":"safe", "training":true})
	send(dorm, "respec")
	check(dorm.snapshot().hex_status.fengli_q1_training == "dormant", "respec sleeps preserved catalog option")
	var pool_limited = model()
	pool_limited.set_supported_hooks(["stats.v1", "stat.AD.v1"])
	reject(pool_limited, "hex_open", {"milestone":1}, "pool_exhausted")
	reject(pool_limited, "buy_body", {}, "body_pool_exhausted")
	var saved_rng = model(991)
	send(saved_rng, "hex_open", {"milestone":1})
	var after_save = Model.new(definitions)
	after_save.restore(JSON.parse_string(JSON.stringify(saved_rng.save())))
	after_save.set_supported_hooks(hooks)
	var refresh_args := {"milestone":1, "slot":3}
	check(saved_rng.command("same_refresh", "hex_refresh", refresh_args) == after_save.command("same_refresh", "hex_refresh", refresh_args) and saved_rng.snapshot() == after_save.snapshot(), "catalog RNG resumes after JSON save")
	var no_xp = definitions.duplicate(true)
	no_xp.xp_per_level[0] = 0
	check(not Validator.validate(no_xp).is_empty(), "zero XP threshold rejected before reward loop")
	var deferred = model()
	send(deferred, "context", {"phase": "combat"})
	reject(deferred, "hex_open", {"milestone": 1}, "unsafe_phase")
	check(deferred.snapshot().pending_milestones == [1, 4, 7, 10, 13], "combat levelups defer all offers")
	return {"checks": checks, "failures": failures, "passed": failures.is_empty()}
