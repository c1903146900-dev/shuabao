extends RefCounted
## DEMO-ONLY trusted construction. Not used by the production controller.
## One finite grant through the actual model; no frame-based money, no free reset key.
static func create() -> Dictionary:
	if not ResourceLoader.exists("res://scripts/progression/model.gd"):
		return {"error": "缺少成长依赖607bf638；先按UI_PROGRESS准备集成副本。"}
	var source := FileAccess.get_file_as_string("res://data/progression/fixture.json")
	var definitions: Dictionary = JSON.parse_string(source)
	var authority = load("res://scripts/progression/model.gd").new(definitions, "fengli", 37)
	var setup: Array = []
	setup.append(authority.command("demo-enter-once", "enter_level", {"combat_level_id": "ui-training-01"}))
	setup.append(authority.command("demo-grant-once", "reward_minion", {"event_id": "ui-demo-initial-only", "gold": 400, "xp": 500}))
	setup.append(authority.command("demo-training-once", "context", {"phase": "safe", "training": true}))
	var hex_names := {}
	for id in definitions.hexes:
		hex_names[id] = "测试海克斯 %02d" % (int(str(id).right(2)) + 1)
	return {"model": authority, "definitions": definitions, "setup_results": setup,
		"presentation": {"short_items": {"component": "组件", "blade": "长剑", "normal": "普药", "special": "特药"}, "items": {"component": "练习组件", "blade": "练习长剑", "normal": "普通药品", "special": "特殊药品"}, "hexes": hex_names,
		"source_label": "真实成长·测试定义", "content_label": "测试目录与数值 · 初始仅400金币 / 6级 · 无自动补充 · HP/CD等待战斗接入"}}
