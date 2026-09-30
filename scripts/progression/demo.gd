extends Node
## Disposable demonstration adapter; does not import combat, UI or art modules.
const Model = preload("res://scripts/progression/model.gd")
var model
var report: Dictionary
var sequence := 0
var shop_open := false
var last_result := "Ready"

func _ready():
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/fixture.json"))
	model = Model.new(fixture, "demo_fengli", 12345)
	report = preload("res://tests/progression/suite.gd").new().run()
	issue("reward_minion", {"event_id": "demo_start", "gold": 1000, "xp": 500})
	issue("enter_level", {"combat_level_id": "demo_level_1"})
	issue("hex_open", {"milestone": 1})
	_render()
	print("PROGRESSION_DEMO_READY ", JSON.stringify(report))

func issue(action: String, args: Dictionary = {}) -> Dictionary:
	sequence += 1
	var result: Dictionary = model.command("demo-" + str(sequence), action, args)
	last_result = action + ": " + ("accepted" if result.accepted else result.reason)
	if is_node_ready(): _render()
	return result

func toggle_shop() -> Dictionary:
	var result := issue("open_shop")
	if result.accepted: shop_open = not shop_open
	_render()
	return result

func _unhandled_key_input(event: InputEvent):
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_P: toggle_shop()
		KEY_1: issue("learn", {"slot": "Q", "candidate": "Q1", "expected_rank": model.state.skills.Q.rank})
		KEY_2: issue("buy", {"item": "component"})
		KEY_3: issue("buy", {"item": "blade"})
		KEY_4:
			if not model.state.inventory.is_empty(): issue("sell", {"uid": model.state.inventory.back().uid})
		KEY_5: issue("undo_shop")
		KEY_6: issue("buy_body")
		KEY_U: issue("undo_skill")
		KEY_X: issue("respec")
		KEY_T: issue("context", {"phase": "safe", "training": true})
		KEY_C:
			shop_open = false
			issue("context", {"phase": "combat"})
		KEY_N: issue("hex_refresh", {"milestone": 1, "slot": 3})
		KEY_ENTER: issue("hex_select", {"milestone": 1, "slot": 3})
	_render()

# MCP invokes the same input handler; this is an injected-key probe, not a physical-key claim.
func probe_key(key: int) -> String:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	_unhandled_key_input(event)
	return last_result

func inspect() -> Dictionary:
	return {"suite": report, "snapshot": model.snapshot(), "shop_open": shop_open, "last_result": last_result, "effects": model.equipment_effects()}

func _render():
	if model == null or not has_node("Readout"): return
	var s: Dictionary = model.snapshot()
	var lines := PackedStringArray([
		"PROGRESSION LAB | synthetic fixtures v1 | NOT final game content",
		"Godot model checks: %d | failures: %s" % [report.get("checks", 0), str(report.get("failures", []))],
		"Actor: %s | Level %d / 18 | Points %d | Gold %d | XP %d" % [s.actor_id, s.level, s.points, s.gold, s.xp],
		"Phase: %s | Training: %s | Occupied equipment slots: %d / 6" % [s.phase, s.training, model.occupied_slots()],
		"Skills: " + str(s.skills),
		"Inventory: " + str(s.inventory),
		"Body purchases: %d (fixed fixture price 50, irreversible)" % s.body.size(),
		"Hex slots: " + str(s.offers.get("1", {}).get("slots", [])),
		"Refresh used: " + str(s.offers.get("1", {}).get("refresh_used", [])),
		"Hex activation: " + str(s.hex_status),
		"Last command: " + last_result,
		"",
		"P shop | 1 Q rank | 2 component | 3 combine blade | 4 sell last | 5 undo trade",
		"T safe training | C combat | U undo new skill point | X respec | 6 buy body",
		"N refresh hero hex (once) | Enter select hero hex",
		"",
		"FIXTURE POLICY: 5 normal potions share a slot; holding excludes special.",
		"Alternative single-unit slots / per-level-use mutex tested, neither is final.",
		"R later gates, prices, XP curve and numeric scales are TEST VALUES.",
		"HP / cooldowns remain owned by combat. No combat or official UI integration."
	])
	if shop_open:
		lines.append("\nSAFE SHOP: complete fixed fixture catalog (official table missing)")
		for id in model.shop_catalog(): lines.append(id + " : " + str(model.shop_catalog()[id]))
	$Readout.text = "\n".join(lines)
