extends RefCounted
## Inject an existing per-actor progression authority. Never constructs rewards or owns combat.
signal command_completed(request: Dictionary, result: Dictionary)
signal combat_request(request: Dictionary)
signal gameplay_block_changed(blocked: bool)
const HUD_SOURCE = preload("res://scripts/ui/combat_hud.gd")
const ERRORS := {
	"stage_not_available":"本阶段尚未开放", "unsupported_effect":"效果尚未接入", "no_target":"没有可用目标", "already_active":"效果仍在持续", "projectile_in_flight":"匕首飞行中", "mark_target_dead":"标记目标已死亡", "mark_expired":"标记已过期", "recast_window_expired":"重施窗口已结束", "all_rounds_used":"投掷次数已用完",
	"unsafe_phase": "仅安全阶段可操作", "training_required": "需要训练节点",
	"insufficient_gold": "金币不足", "insufficient_points": "技能点不足",
	"unresolved_r_gate": "R后两阶等级门槛待定", "level_gate": "尚未达到所需等级",
	"rank_cap": "已达到最高阶", "stale_rank": "技能状态已变化，请重试",
	"stale_state": "状态已更新，请重新操作", "invalid_candidate": "候选技能无效",
	"undo_boundary": "没有可撤销的本次投入", "missing_component": "缺少合成组件",
	"inventory_full": "六个装备槽已满", "missing_item": "物品已不存在",
	"recovery_mutex": "两类药品互斥", "normal_cap": "普通药品已达5份上限",
	"special_cap": "本战斗关特殊药品已用2次", "unresolved_policy": "药品政策尚未确定",
	"refresh_exhausted": "此候选已刷新过", "already_selected": "本轮海克斯已选定",
	"pool_exhausted": "候选池不足", "missing_offer": "请先打开此轮海克斯",
	"unresolved_rank_values": "该技能档位数值待定", "combat_unavailable": "战斗系统未接入，未改变生命/冷却或药品",
	"unknown_command": "此请求不属于成长界面", "actor_mismatch": "角色不匹配", "cooldown": "技能仍在冷却", "action_locked": "当前动作无法施放", "unlearned": "尚未学习", "not_alive": "无法行动", "encounter_frozen": "战后状态冻结", "previous_candidate_active": "旧技能效果仍在持续", "transaction_in_progress": "请稍后再试"}
var model: RefCounted
var hud: Control
var definitions: Dictionary
var display: Dictionary
var combat: Dictionary = {}
var active_milestone := 0
var _projection_revision := -1
var last_result: Dictionary = {}
var receipt_log: Array[Dictionary] = []

func bind(authority: RefCounted, view: Control, content: Dictionary, presentation: Dictionary = {}) -> void:
	if is_instance_valid(hud) and hud.adapter.request_emitted.is_connected(handle_request):
		hud.adapter.request_emitted.disconnect(handle_request)
		if hud.modal_changed.is_connected(_on_modal_changed):
			hud.modal_changed.disconnect(_on_modal_changed)
	_projection_revision = -1
	model = authority
	hud = view
	for row in hud.rows.values():
		row.options.select(0)
	definitions = content.duplicate(true)
	display = presentation.duplicate(true)
	hud.adapter.request_emitted.connect(handle_request)
	hud.modal_changed.connect(_on_modal_changed)
	refresh()

func present_combat(snapshot: Dictionary) -> void:
	# Includes HP / CD / room / wave only. Phase permissions remain model-owned.
	combat = snapshot.duplicate(true)
	refresh()

func consume_combat_event(event: Dictionary) -> void:
	hud.adapter.feedback(event)

func item_name(id: String) -> String:
	return str(display.get("items", {}).get(id, definitions.get("items", {}).get(id, {}).get("name", id)))

func reason_text(reason: String) -> String:
	return str(ERRORS.get(reason, "操作失败：" + reason))

func handle_request(request: Dictionary) -> void:
	var snapshot: Dictionary = model.snapshot()
	if request.get("actor_id", "") != snapshot.actor_id:
		_finish(request, _boundary("actor_mismatch"))
		return
	if int(request.get("state_revision", -1)) != int(snapshot.revision):
		_finish(request, _boundary("stale_state"))
		return
	var action := str(request.get("action", ""))
	var args: Dictionary = {}
	match action:
		"ability", "use_item":
			# A trusted coordinator validates and executes combat/consumption transactions.
			if combat_request.get_connections().is_empty():
				_finish(request, _boundary("combat_unavailable"))
			else:
				combat_request.emit(request.duplicate(true))
			return
		"item":
			hud.open_supply(1)
			return
		"learn":
			args = {"slot": request.get("slot_id", ""), "candidate": request.get("candidate_id", ""), "expected_rank": request.get("expected_rank", -1)}
		"undo_new_points", "undo_skill":
			action = "undo_skill"
		"respec", "open_shop", "undo_shop", "buy_body":
			pass
		"buy":
			args = {"item": request.get("item", "")}
		"sell":
			args = {"uid": request.get("uid", -1)}
		"hex_open", "hex_refresh", "hex_select":
			args = {"milestone": int(request.get("milestone", 0))}
			if action != "hex_open":
				args.slot = int(request.get("slot", -1))
		_:
			_finish(request, _boundary("unknown_command"))
			return
	var result: Dictionary = model.command(str(request.command_id), action, args)
	if result.accepted and action.begins_with("hex_"):
		active_milestone = args.milestone
	result["origin"] = "progression_model"
	_finish(request, result)

func _boundary(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason, "state_revision": model.snapshot().revision, "events": [], "origin": "ui_boundary"}

func _finish(request: Dictionary, result: Dictionary) -> void:
	last_result = result.duplicate(true)
	receipt_log.append({"request": request.duplicate(true), "result": result.duplicate(true)})
	refresh()
	var message := "操作已完成" if result.accepted else reason_text(str(result.reason))
	var captions := {"learn": "技能已更新", "undo_new_points": "已撤销上次投入", "undo_skill": "已撤销上次投入", "respec": "训练洗点完成", "buy": "买入完成", "sell": "出售完成", "undo_shop": "已撤销上次交易", "hex_select": "海克斯已选定", "hex_refresh": "候选已刷新", "buy_body": "锻体完成 · 不可撤销"}
	if result.accepted:
		message = str(captions.get(request.action, message))
	hud.set_receipt(message, result.accepted)
	hud.adapter.feedback({"kind": "progression", "text": message})
	command_completed.emit(request.duplicate(true), result.duplicate(true))

func refresh() -> void:
	if not is_instance_valid(hud) or model == null:
		return
	var s: Dictionary = model.snapshot()
	var out := {"actor_id": s.actor_id, "revision": s.revision, "level": s.level, "points": s.points, "xp": s.xp, "gold": s.gold,
		"can_undo": s.phase == "safe" and not s.allocations.is_empty(), "can_respec": s.training,
		"combat_available": combat.has("hp"), "hp": combat.get("hp", 0), "hp_max": combat.get("hp_max", 1),
		"room": combat.get("room", "训练节点" if s.training else "安全区域" if s.phase == "safe" else "战斗中"),
		"wave": combat.get("wave", "—"), "source_label": display.get("source_label", "成长模型"), "skills": {}, "equipment": []}
	var curve: Array = definitions.get("xp_per_level", [])
	out.xp_next = curve[s.level - 1] if s.level < 18 and curve.size() >= s.level else 0
	for slot in ["Q", "E", "R", "P", "Shift"]:
		var ability: Dictionary = combat.get("skills", {}).get(slot, {}).duplicate(true)
		if slot == "Shift":
			ability.merge({"name": "冲刺", "rank": 1}, true)
		else:
			var skill: Dictionary = s.skills[slot]
			var candidate := str(skill.candidate)
			var index := maxi(0, int(candidate.right(1)) - 1)
			ability.merge({"rank": skill.rank, "candidate_index": index, "name": HUD_SOURCE.CANDIDATES[slot][index] if skill.rank > 0 else "未学习"}, true)
			if slot == "R" and skill.rank < 3:
				var gates: Array = definitions.get("r_gates", [6, null, null])
				if gates.size() <= skill.rank or gates[skill.rank] == null:
					ability.upgrade_reason = reason_text("unresolved_r_gate")
				elif s.level < gates[skill.rank]:
					ability.upgrade_reason = "需要%d级" % gates[skill.rank]
		if not ability.has("reason"):
			ability.reason = "待战斗接入" if not combat.has("hp") else "状态由战斗提供"
		if slot != "Shift" and s.skills[slot].rank == 0:
			ability.reason = "尚未学习"
		out.skills[slot] = ability
	for entry in s.inventory:
		out.equipment.append({"name": display.get("short_items", {}).get(entry.id, item_name(entry.id).left(2)), "description": "%s ×%d" % [item_name(entry.id), entry.count], "uid": entry.uid})
	hud.adapter.present(out)
	# Combat snapshots may arrive every frame; do not rebuild open growth menus.
	if _projection_revision == int(s.revision):
		return
	_projection_revision = int(s.revision)
	var items: Array = []
	for id in model.shop_catalog():
		var entry: Dictionary = model.shop_catalog()[id]
		var components: Array = []
		for component in entry.get("components", []):
			components.append(item_name(component))
		items.append({"id": id, "name": item_name(id), "price": entry.price, "components": "、".join(components), "kind": entry.get("kind", "equipment"), "available":entry.get("availability",{}).get("supported",true)})
	var inventory: Array = []
	for entry in s.inventory:
		inventory.append({"uid": entry.uid, "name": item_name(entry.id), "count": entry.count, "resale": int(floor(entry.invested * 0.9)), "kind": definitions.items[entry.id].get("kind", "equipment")})
	var milestones: Array = s.pending_milestones.duplicate()
	for key in s.offers:
		if not int(key) in milestones:
			milestones.append(int(key))
	if not display.get("hex_enabled",true): milestones.clear()
	milestones.sort()
	if active_milestone == 0 and not milestones.is_empty():
		active_milestone = milestones[0]
	var offer: Dictionary = s.offers.get(str(active_milestone), {})
	var choices: Array = []
	for i in range(offer.get("slots", []).size()):
		var id: String = offer.slots[i]
		var definition: Dictionary = definitions.get("hexes", {}).get(id, {})
		choices.append({"id": id, "name": display.get("hexes", {}).get(id, id), "hero_only": i == 3,
			"requires": definition.get("requires", ""), "refreshed": offer.refresh_used[i], "selected": offer.get("selected", "") == id})
	var selected_text: Array = []
	for id in s.selected_hex:
		selected_text.append("%s · %s" % [display.get("hexes", {}).get(id, id), "生效" if s.hex_status[id] == "active" else "休眠"])
	hud.present_progression({"phase": s.phase, "training": s.training, "gold": s.gold, "catalog": items, "inventory": inventory,
		"can_undo_shop": s.phase == "safe" and not s.shop_undo.is_empty(), "body_cost": definitions.get("body", {}).get("cost", 0), "body_count": s.body.size(),
		"milestones": milestones, "active_milestone": active_milestone, "choices": choices, "offer_selected": not offer.get("selected", "").is_empty(),
		"selected_text": "  /  ".join(selected_text), "content_label": display.get("content_label", "定义版本：" + str(s.definition_version))})

func complete_combat_request(request: Dictionary, result: Dictionary) -> void:
	# Called by the combat coordinator AFTER its transaction; no local HP/CD writes.
	var response := result.duplicate(true)
	response["origin"] = "combat_coordinator"
	_finish(request, response)

func blocks_gameplay_input() -> bool:
	return hud.blocks_gameplay_input()

func present_fengli_snapshot(snapshot: Dictionary, room: String = "", wave: String = "—") -> void:
	# Matches feature/fengli-combat 6ae6dd9; ignores its separate progression fixture.
	var hero: Dictionary = snapshot.get("hero", {})
	var view := {"hp": hero.get("hp", 0), "hp_max": hero.get("max_hp", 1), "skills": {},
		"room": room if not room.is_empty() else str(snapshot.get("combat_level_id", "—")), "wave": wave}
	for pair in [["Q", "q"], ["E", "e"], ["R", "r"], ["Shift", "shift"], ["P", "passive"]]:
		var reason := "就绪"
		if snapshot.get("phase", "") != "combat":
			reason = "战后冻结"
		elif hero.get("dead", false):
			reason = "无法行动"
		elif pair[0] == "P":
			reason = "被动生效"
		elif pair[0] == "E" and hero.get("overload_left", 0.0) > 0:
			reason = "超载 %.1fs" % hero.overload_left
		view.skills[pair[0]] = {"cooldown": hero.get("cooldowns", {}).get(pair[1], 0.0), "reason": reason}
	present_combat(view)

func _on_modal_changed(blocked: bool) -> void:
	gameplay_block_changed.emit(blocked)

func consume_fengli_event(event: Dictionary, screen_position := Vector2.INF) -> void:
	# A host Camera projects world position. Do not pretend world coordinates are pixels.
	var kind: String = event.get("kind", "")
	if kind == "damage" and screen_position.is_finite():
		hud.adapter.feedback({"kind": "damage", "text": "%d%s" % [ceili(event.get("amount", 0)), "!" if event.get("critical", false) else ""],
			"critical": event.get("critical", false), "screen_x": screen_position.x, "screen_y": screen_position.y})
	elif kind == "hero_damaged":
		hud.adapter.feedback({"text": "受到 %d 伤害" % ceili(event.get("amount", 0))})
	elif kind in ["ultimate_started", "overload_started", "low_health_passive"]:
		hud.adapter.feedback({"text": {"ultimate_started": "绝技施放", "overload_started": "超载开启", "low_health_passive": "残血反打触发"}[kind]})
