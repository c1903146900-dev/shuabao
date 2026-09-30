extends Node
## Content-review scene. Live purchases stay fail-closed; test suite uses isolated mocks.
const CatalogModel = preload("res://scripts/progression/catalog_model.gd")
var model
var report: Dictionary = {}
var command_number := 0
var page := 0
var last_result := "No live combat hooks registered; purchases and draws are blocked."

func _ready():
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/prototype/catalog.json"))
	model = CatalogModel.new(data, "catalog_review", 381)
	model.command("review_funds", "reward_minion", {"event_id": "review_funds", "gold": 10000, "xp": 100000})
	report = preload("res://tests/progression/catalog_suite.gd").new().run()
	_render()
	print("CATALOG_DEMO_READY ", JSON.stringify(report))

func probe_locked_buy() -> bool:
	var before: Dictionary = model.snapshot()
	command_number += 1
	var reply: Dictionary = model.command("locked-buy-" + str(command_number), "buy", {"item": "iron_blade"})
	last_result = "Live buy iron_blade: " + reply.reason + "; gold unchanged " + str(model.state.gold)
	_render()
	return not reply.accepted and reply.reason == "unsupported_effect" and model.snapshot() == before

func inspect() -> Dictionary:
	return {"suite": report, "snapshot": model.snapshot(), "catalog_errors": model.catalog_errors, "hooks": model.supported_hooks, "shop": model.shop_catalog()}

func show_page(index: int) -> int:
	page = index % 4
	_render()
	return page

func _unhandled_key_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P: show_page(page + 1)
		if event.keycode == KEY_B: probe_locked_buy()

func _render():
	if not has_node("Readout") or model == null: return
	var lines := PackedStringArray([
		"成长内容审阅 / PROTOTYPE CATALOG V2",
		"新增可调初值，非历史确认定值 | 模型预览，不是战斗整合",
		"12组件 + 3中级 + 8成装 + 2药品 | 24数值海克斯 + 19未支持草案",
		"独立内容测试: %s项 / 失败 %s | P翻页 / B验证禁止空买" % [report.get("checks", 0), str(report.get("failures", []))],
		last_result, ""
	])
	if page < 3:
		for id in model.config.items:
			var item: Dictionary = model.config.items[id]
			if (page == 0 and item.tier == "component") or (page == 1 and item.tier in ["intermediate", "consumable"]) or (page == 2 and item.tier == "complete"):
				lines.append("%s  %d金  %s" % [item.name, item.price, str(item.stats)])
				if page in [1, 2]: lines.append("  配方 %s + %d金  / 唯一组: %s" % [str(item.components), item.combine_fee, item.passive])
	else:
		lines.append("锻体: 固定900金 / 三个不同属性随机选一 / 不退款、不刷新、不洗掉")
		lines.append("24个新纯属性初值：公共12 / 风厉12（含4个技能依赖，未学休眠）")
		lines.append("五轮全四槽刷新：40种固定种子 × 左/右选择路径，无耗尽。")
		lines.append("原草案保留但禁用：疾驰、狩猎、连击、余震、双重施法、猎杀时刻")
		lines.append("无限火力、玻璃大炮、第二套弹匣、终极狂热、血债、超频、炼金术")
		lines.append("风厉：饮血磨锋、杀意未歇、一步十杀、无处可逃、留影、越战越狂")
		lines.append("一步十杀 / 剑走偏锋：同一效果，不作为两项入池。")
		lines.append("药品实验策略：普通5瓶同槽 / 持有互斥 / 安全使用 / 特殊单份消耗。")
		lines.append("普通18% / 特殊30%最大生命回复量，仅初值；尚无战斗恢复hook。")
	lines.append("")
	lines.append("本审阅场景不注册战斗hook：全部实际购买/抽选保持unsupported。")
	lines.append("测试使用独立模拟消费者验证事务；不能据此宣称实际战斗效果已实现。")
	$Readout.text = "\n".join(lines)
