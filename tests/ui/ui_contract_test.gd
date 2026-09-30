extends Node
## Runs inside the live Godot game via the standard MCP execute_game_script tool.
var checks: Array[Dictionary] = []
var game: Node
var hud: Control

func start(root: Node) -> String:
	game = root
	hud = root.hud
	root.add_child(self)
	call_deferred("run")
	return "UI_SUITE_STARTED"

func check(name: String, passed: bool) -> void:
	checks.append({"name": name, "passed": passed})

func frames(count := 3) -> void:
	for i in range(count):
		await get_tree().process_frame

func click(pos: Vector2) -> void:
	pos = get_viewport().get_final_transform() * pos
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	Input.parse_input_event(motion)
	await frames()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await frames()

func key(code: int) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await frames()

func run() -> void:
	hud.close_panels()
	game.attack_count = 0
	game.requests.clear()
	game.reset_fixture()
	await frames()
	var copy: Dictionary = game.model.duplicate(true)
	hud.adapter.present(copy)
	copy.hp = 99
	check("adapter deep copies snapshot", hud.state.hp == 760)
	var original_hp: int = game.model.hp
	hud.adapter.feedback({"kind": "damage", "text": "999"})
	check("feedback cannot change HP", game.model.hp == original_hp)
	await click(Vector2(620, 340))
	check("world click reaches demo attack", game.attack_count == 1)
	var attacks: int = game.attack_count
	await click(hud.slots.Q.get_global_rect().get_center())
	check("skill button emits request without attack passthrough", game.attack_count == attacks and game.requests.back().action == "ability")
	await click(hud.allocation.get_global_rect().get_center())
	check("mouse opens allocation", hud.panel.visible)
	check("initial panel focus", get_viewport().gui_get_focus_owner() == hud.close_button)
	var elapsed: float = game.elapsed
	var cd: float = game.model.skills.Q.cooldown
	await get_tree().create_timer(0.25).timeout
	check("allocation never pauses demo clock or cooldown", not get_tree().paused and game.elapsed > elapsed and game.model.skills.Q.cooldown < cd)
	await key(KEY_TAB)
	check("tab navigates within allocation", hud.focus_chain.has(get_viewport().gui_get_focus_owner()) and get_viewport().gui_get_focus_owner() != hud.close_button)
	await click(Vector2(620, 340))
	check("modal background blocks mouse attack", game.attack_count == attacks)
	await key(KEY_Q)
	check("modal keyboard does not issue ability", game.requests.back().action == "ability" and game.requests.size() == 1)
	await key(KEY_ESCAPE)
	check("escape closes and restores focus", not hud.panel.visible and get_viewport().gui_get_focus_owner() == hud.allocation)
	for i in range(12):
		await key(KEY_K)
		await key(KEY_ESCAPE)
	check("12 reopen/cancel cycles stable", not hud.shade.visible and game.model.points == 13)
	game.reset_fixture()
	game.model.level = 5
	game.model.points = 0
	game.model.skills.R.rank = 0
	game.model.skills.R.name = "未学习"
	game.model.skills.R.reason = "6级可学习"
	hud.adapter.present(game.model)
	hud.open_allocation()
	await frames()
	check("R pre-level-6 blocked with reason", hud.rows.R.buy.disabled and hud.rows.R.reason.text == "6级可学习")
	check("zero-point upgrade blocked", hud.rows.Q.buy.disabled)
	check("unlearned Q/E/R/P choices total eleven", hud.CANDIDATES.Q.size() + hud.CANDIDATES.E.size() + hud.CANDIDATES.R.size() + hud.CANDIDATES.P.size() == 11)
	hud.close_panels()
	game.reset_fixture()
	hud.open_allocation()
	for slot in ["Q", "E", "R", "P"]:
		for attempt in range(5):
			if game.model.skills[slot].rank >= hud.CAPS[slot]:
				break
			var button: Button = hud.rows[slot].buy
			await click(button.get_global_rect().get_center())
	print("ALLOCATION_STATE ", JSON.stringify(game.model))
	check("18-point full allocation 5/5/3/3 leaves zero", game.model.points == 0 and game.model.skills.R.rank == 3)
	check("R costs 1/2/2 represented", hud.rows.R.buy.text.contains("2点"))
	check("full ranks block further upgrade", hud.rows.Q.buy.disabled and hud.rows.R.buy.disabled)
	check("six equipment slots include medicine", hud.equipment.size() == 6 and hud.equipment[5].text == "药品")
	var request: Dictionary = game.requests.back()
	check("request includes actor/revision/id/expected rank", request.has("actor_id") and request.has("state_revision") and request.has("command_id") and request.has("expected_rank"))
	hud.close_panels()
	game.finish_demo()
	await frames()
	check("result visible with fixture label", hud.result_box.visible and hud.result_text.text.contains("非真实战斗"))
	var result_focus: Control = get_viewport().gui_get_focus_owner()
	await key(KEY_TAB)
	check("result panel traps tab focus", get_viewport().gui_get_focus_owner() == result_focus)
	var final_cd: float = game.model.skills.Q.cooldown
	await get_tree().create_timer(0.25).timeout
	check("fixture end freezes cooldown and HP", game.model.skills.Q.cooldown == final_cd and game.model.hp == original_hp)
	await key(KEY_ESCAPE)
	hud.open_allocation()
	await frames()
	await click(hud.undo_button.get_global_rect().get_center())
	print("UNDO_STATE ", JSON.stringify(game.model))
	check("fixture undo restores only points/ranks", game.model.points == 13 and game.model.hp == original_hp and game.model.skills.Q.cooldown == final_cd)
	hud.close_panels()
	game.clear_demo_loadout()
	hud.open_allocation()
	await frames()
	hud.rows.Q.options.grab_focus()
	await key(KEY_SPACE)
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	check("keyboard selects second initial Q candidate", hud.rows.Q.options.selected == 1)
	await key(KEY_TAB)
	await key(KEY_ENTER)
	check("keyboard learning emits Q2 and renders authoritative response", game.model.skills.Q.rank == 1 and game.model.skills.Q.candidate_index == 1)
	hud.close_button.grab_focus()
	await key(KEY_ENTER)
	check("keyboard activates close button", not hud.panel.visible)
	game.finish_demo()
	hud.close_panels()
	hud.open_allocation()
	await frames()
	await click(hud.undo_button.get_global_rect().get_center())
	check("undo newly learned fixture skill restores unlearned label", game.model.skills.Q.rank == 0 and game.model.skills.Q.name == "未学习" and game.model.points == 18)
	hud.close_panels()
	game.reset_fixture()
	var chinese_ok := true
	for character in "风厉生命经验金币剑技修习药品冷却":
		chinese_ok = chinese_ok and hud.theme.default_font.has_char(character.unicode_at(0))
	check("bundled font contains required Chinese glyphs", chinese_ok)
	var failures := 0
	for result in checks:
		if not result.passed:
			failures += 1
	var report := {"window_size": str(get_window().size), "checks": checks, "count": checks.size(), "failures": failures, "scope": "UI fixture only; no real combat integration"}
	game.set_meta("ui_test_report", report)
	print("UI_TEST_REPORT ", JSON.stringify(report))
	queue_free()
