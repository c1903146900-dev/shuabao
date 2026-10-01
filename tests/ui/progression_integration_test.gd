extends Node
## Live Godot input tests against the UNMODIFIED progression model dependency.
var game: Node
var hud: Control
var checks: Array[Dictionary] = []
var frozen_combat: Dictionary

func start(root: Node) -> String:
	game = root
	hud = root.hud
	root.add_child(self)
	call_deferred("run")
	return "GROWTH_UI_TESTS_STARTED"

func check(name: String, passed: bool) -> void:
	checks.append({"name": name, "passed": passed})

func frames(n := 3) -> void:
	for i in range(n):
		await get_tree().process_frame

func click(position: Vector2) -> void:
	position = get_viewport().get_final_transform() * position
	var motion := InputEventMouseMotion.new()
	motion.position = position
	Input.parse_input_event(motion)
	await frames()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await frames()

func button(control: Control) -> void:
	await click(control.get_global_rect().get_center())

func key(code: int) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await frames()

func tab(index: int) -> void:
	var bar: TabBar = hud.tabs.get_tab_bar()
	await click(bar.global_position + bar.get_tab_rect(index).get_center())

func state() -> Dictionary:
	return game.model.snapshot()

func unchanged_combat() -> bool:
	return game.controller.combat == frozen_combat and hud.state.hp == 173 and hud.state.skills.Q.cooldown == 4.25

func run() -> void:
	hud.close_panels()
	game.build_fixture_for_test()
	await frames()
	check("real model starts with one finite 400-gold grant and 6 points", state().gold == 400 and state().points == 6 and state().reward_ids.size() == 1)
	check("no missing combat values disguised as valid HP", hud.health_text.text.contains("等待战斗"))
	# Exact 6ae6dd9 snapshot schema; injected static test data, NOT live combat.
	game.controller.present_fengli_snapshot({"phase": "combat", "combat_level_id": "ui-test", "hero": {"actor_id": "fengli", "hp": 173, "max_hp": 240,
		"cooldowns": {"q": 4.25, "e": 12.0, "r": 58.0, "shift": 1.5, "passive": 9.0}, "dead": false}})
	frozen_combat = game.controller.combat.duplicate(true)
	check("actual combat schema maps hero hp/max_hp and lowercase cooldowns", hud.state.hp == 173 and hud.state.hp_max == 240 and hud.state.skills.E.cooldown == 12.0)
	await click(Vector2(620, 340))
	check("world input reaches only the test counter", game.attack_count == 1)
	var polled_baseline: int = game.polled_attack_count
	await key(KEY_K)
	await key(KEY_Q)
	await key(KEY_E)
	await key(KEY_W)
	check("modal absorbs combat/movement keys before unhandled input", game.leaked_keys.is_empty())
	hud.rows.Q.options.grab_focus()
	await key(KEY_SPACE)
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	await button(hud.rows.Q.buy)
	check("keyboard candidate then mouse learn reaches real Q2", state().skills.Q.candidate == "Q2" and state().skills.Q.rank == 1 and state().points == 5)
	await button(hud.rows.Q.buy)
	await button(hud.rows.E.buy)
	check("real skill costs deducted", state().skills.Q.rank == 2 and state().skills.E.rank == 1 and state().points == 3)
	await button(hud.undo_button)
	check("undo_skill reverses only the newest E investment", state().skills.E.rank == 0 and state().skills.Q.rank == 2 and state().points == 4)
	await button(hud.undo_button)
	check("second undo reverses only Q upgrade", state().skills.Q.rank == 1 and state().points == 5)
	await button(hud.respec_button)
	check("training respec uses model and refunds true cost", state().skills.Q.rank == 0 and state().points == 6)
	await button(hud.rows.R.buy)
	await button(hud.rows.R.buy)
	await button(hud.rows.R.buy)
	check("real R learning/upgrades charge 1+2+2 under explicit fixture gates", state().skills.R.rank == 3 and state().points == 1)
	await button(hud.undo_button)
	check("single R undo refunds only last two-point investment", state().skills.R.rank == 2 and state().points == 3)
	await button(hud.respec_button)
	check("learn/upgrade/undo/respec preserve external HP and all CDs", unchanged_combat())
	var elapsed: float = game.elapsed
	game.set_demo_phase("combat")
	await button(hud.rows.Q.buy)
	await get_tree().create_timer(0.2).timeout
	check("learning in combat uses real model without pause", state().skills.Q.rank == 1 and game.elapsed > elapsed and not get_tree().paused)
	check("unsafe undo and respec visibly disabled", hud.undo_button.disabled and hud.respec_button.disabled)
	hud.adapter.request("undo_skill")
	check("model rejects unsafe undo with actual reason", game.controller.last_result.reason == "unsafe_phase" and game.controller.last_result.origin == "progression_model")
	await key(KEY_ESCAPE)
	await key(KEY_P)
	check("P opens combat-locked shop without successful transaction", hud.supply.visible and hud.shop_buttons.component.disabled and game.controller.last_result.reason == "unsafe_phase")
	hud.adapter.request("buy", {"item": "component"})
	check("model rejects forced unsafe buy atomically", game.controller.last_result.reason == "unsafe_phase" and state().gold == 400)
	await click(Vector2(40, 330))
	check("supply modal background blocks attack passthrough", game.attack_count == 1)
	await key(KEY_ESCAPE)
	for i in range(8):
		await key(KEY_P)
		await key(KEY_ESCAPE)
	check("eight shop open/cancel cycles do not grant money or reset CD", state().gold == 400 and unchanged_combat())
	game.set_demo_phase("safe", true)
	await key(KEY_P)
	await button(hud.shop_buttons.component)
	check("component purchase debits 100", state().gold == 300 and state().inventory[0].id == "component")
	await button(hud.shop_buttons.blade)
	check("composition charges 150 more and consumes component", state().gold == 150 and state().inventory.size() == 1 and state().inventory[0].id == "blade")
	var blade_uid: int = state().inventory[0].uid
	await button(hud.shop_buttons.normal)
	check("medicine occupies an actual inventory slot", state().gold == 140 and state().inventory.size() == 2 and hud.equipment[1].tooltip_text.contains("普通药品"))
	await button(hud.shop_buttons.special)
	check("mutually exclusive drug failure shown from actual model", state().gold == 140 and game.controller.last_result.reason == "recovery_mutex" and hud.receipt.text.contains("互斥"))
	await button(hud.shop_buttons.normal)
	var potion_uid: int = state().inventory[1].uid
	check("second normal potion stacks according to fixture policy", state().gold == 130 and state().inventory[1].count == 2)
	await tab(1)
	await button(hud.sell_buttons[1])
	check("sale sends actual potion uid and refunds 18", state().gold == 148 and state().inventory.size() == 1 and game.controller.receipt_log.back().request.uid == potion_uid)
	hud.adapter.request("undo_shop")
	check("one transaction undo restores exact uid/count/gold", state().gold == 130 and state().inventory[1].uid == potion_uid and state().inventory[1].count == 2)
	await button(hud.sell_buttons[0])
	check("blade sale uses blade uid and refund225", state().gold == 355 and game.controller.receipt_log.back().request.uid == blade_uid)
	check("compacted inventory row keeps correct remaining instance uid", int(hud.sell_buttons[0].get_meta("uid")) == potion_uid)
	await button(hud.sell_buttons[0])
	check("next row sale uses remaining potion uid, not old index", state().gold == 373 and state().inventory.is_empty())
	hud.adapter.request("undo_shop")
	hud.adapter.request("undo_shop")
	await button(hud.body_button)
	check("training body purchase really debits50 and persists", state().gold == 80 and state().body.size() == 1)
	await tab(0)
	await button(hud.shop_buttons.component)
	check("finite funds cause actual insufficient_gold, no free refill", state().gold == 80 and game.controller.last_result.reason == "insufficient_gold" and hud.receipt.text.contains("金币不足"))
	await tab(2)
	await frames()
	check("hex open calls model for milestone1 with four candidates", state().offers.has("1") and state().offers["1"].slots.size() == 4)
	var chosen: String = state().offers["1"].slots[0]
	await button(hud.hex_cards[3].refresh)
	check("right hero slot refresh consumes its sole allowance", state().offers["1"].refresh_used[3] and hud.hex_cards[3].refresh.disabled)
	var rng_before: int = state().rng
	hud.adapter.request("hex_refresh", {"milestone": 1, "slot": 3})
	check("model rejects repeated refresh without changing RNG", game.controller.last_result.reason == "refresh_exhausted" and state().rng == rng_before)
	await button(hud.hex_cards[0].select)
	check("selection persists real candidate ID and locks this offer", state().selected_hex.has(chosen) and hud.hex_cards[0].select.disabled)
	var saved_slots: Array = state().offers["1"].slots.duplicate()
	await key(KEY_ESCAPE)
	await key(KEY_P)
	await tab(2)
	check("reopening selected hex does not reroll or refund allowance", state().offers["1"].slots == saved_slots and state().offers["1"].refresh_used[3])
	hud.milestone.grab_focus()
	await key(KEY_SPACE)
	for i in range(12):
		game.controller.present_combat(frozen_combat)
	check("frequent combat snapshots do not rebuild or close milestone popup", hud.milestone.get_popup().visible)
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	await frames()
	check("keyboard milestone selector opens actual level4 offer", state().offers.has("4") and game.controller.active_milestone == 4)
	await button(hud.hex_cards[3].select)
	check("second selected offer uses model's hero-exclusive candidate", state().selected_hex.size() == 2 and game.fixture.definitions.hexes[state().offers["4"].selected].hero == "fengli")
	check("all growth transactions leave combat state unchanged", unchanged_combat())
	var prior: Dictionary = state()
	hud.adapter.request("reward_minion", {"gold": 9999, "xp": 9999})
	check("UI cannot mint rewards or enter trusted phase commands", game.controller.last_result.origin == "ui_boundary" and state() == prior)
	hud.adapter.request("use_item", {"uid": potion_uid})
	check("missing recovery coordinator never consumes medicine", game.controller.last_result.reason == "combat_unavailable" and state() == prior)
	var projected: Dictionary = hud.adapter.state.duplicate(true)
	projected.hp = 1
	check("consumer cannot mutate combat authority through snapshot", unchanged_combat())
	await key(KEY_ESCAPE)
	await key(KEY_K)
	await button(hud.respec_button)
	check("respec does not refund irreversible body purchase or touch HP/CD", state().body.size() == 1 and state().gold == 80 and unchanged_combat())
	for id in state().selected_hex:
		if not game.fixture.definitions.hexes[id].requires.is_empty():
			check("dependent selected hex renders dormant after respec", state().hex_status[id] == "dormant" and hud.hex_summary.text.contains("休眠"))
	await key(KEY_ESCAPE)
	await key(KEY_P)
	hud.supply_close.grab_focus()
	await key(KEY_TAB)
	check("supply tab focus stays inside modal", hud.supply.is_ancestor_of(get_viewport().gui_get_focus_owner()))
	hud.supply_close.grab_focus()
	await key(KEY_ENTER)
	check("keyboard close restores usable focus", not hud.supply.visible and get_viewport().gui_get_focus_owner() != null)
	check("all UI clicks avoided world input leakage", game.attack_count == 1)
	check("continuous held-mouse gate blocks all UI clicks", game.polled_attack_count == polled_baseline)
	check("finite grant remained unique throughout all operations", state().reward_ids.size() == 1 and state().gold == 80)
	game.controller.consume_fengli_event({"kind": "damage", "amount": 12.1, "critical": true}, Vector2(640, 320))
	check("native damage event uses actual amount and explicit screen projection", hud.feedback_layer.get_child(hud.feedback_layer.get_child_count() - 1).text == "13!" and unchanged_combat())
	var failures := 0
	for item in checks:
		if not item.passed:
			failures += 1
	var report := {"checks": checks, "count": checks.size(), "failures": failures, "window_size": str(get_window().size), "gold": state().gold, "combat_before": frozen_combat, "combat_after": game.controller.combat.duplicate(true),
		"dependency": "607bf6385f5f668155aa76f5df6eb184e5685cea", "combat_scope": "static external schema fixture; not live combat integration"}
	game.set_meta("growth_ui_report", report)
	print("GROWTH_UI_REPORT ", JSON.stringify(report))
	queue_free()
