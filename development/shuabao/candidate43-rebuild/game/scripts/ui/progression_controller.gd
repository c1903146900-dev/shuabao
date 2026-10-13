extends RefCounted
## Inject an existing per-actor progression authority. Never constructs rewards or owns combat.
signal command_completed(request: Dictionary, result: Dictionary)
signal combat_request(request: Dictionary)
signal gameplay_block_changed(blocked: bool)
signal test_loadout_requested(config: Dictionary)
signal hex_selection_required(milestone: int)
const ContentText = preload("res://scripts/ui/content_text.gd")
const FinalDesign = preload("res://data/final_design/catalog.gd")
var _opening_auto_hex := false
var _announced_milestone := 0
var _pending_test_loadout: Dictionary = {}
const HUD_SOURCE = preload("res://scripts/ui/combat_hud.gd")
const ERRORS := {
 "invalid_level":"等级必须在1到18之间", "invalid_hex_count":"最多指定5个海克斯", "invalid_hex":"海克斯不存在", "invalid_catalog":"内容数据校验失败，操作已阻止", "test_requires_fresh_authority":"测试载入必须使用独立新账本",
 "candidate_not_implemented":"此候选尚未接入", "charging":"当前冲锋尚未结束", "no_charges":"可用次数已耗尽", "dash_attack_used":"本次冲刺攻击已使用", "not_guarding":"当前未处于防御姿态",
 "test_loadout_phase":"仅开战前或胜利后可切换自由测试；败后请先续战并获胜", "test_loadout_unavailable":"当前无法切换自由测试",
 "full_health":"生命已满，未消耗药品", "already_consumed":"此用药请求已处理", "command_id_conflict":"请求身份冲突", "unknown_action":"该栏不是主动技能",
	"stage_not_available":"本阶段尚未开放", "unsupported_effect":"效果尚未接入", "no_target":"没有可用目标", "already_active":"效果仍在持续", "projectile_in_flight":"匕首飞行中", "mark_target_dead":"标记目标已死亡", "mark_expired":"标记已过期", "recast_window_expired":"重施窗口已结束", "all_rounds_used":"投掷次数已用完",
	"unsafe_phase": "仅安全阶段可操作", "training_required": "需要训练节点",
	"insufficient_gold": "金币不足", "insufficient_points": "技能点不足",
	"unresolved_r_gate": "终极技能解锁配置缺失", "level_gate": "尚未达到所需等级",
	"rank_cap": "已达到最高阶", "stale_rank": "技能状态已变化，请重试",
	"stale_state": "状态已更新，请重新操作", "invalid_candidate": "候选技能无效",
	"undo_boundary": "没有可撤销的本次投入", "missing_component": "缺少合成组件",
	"inventory_full": "六个装备槽已满", "missing_item": "物品已不存在",
	"recovery_mutex": "两类药品互斥", "normal_cap": "普通药品已达5份上限",
	"special_cap": "本战斗关特殊药品已用2次", "unresolved_policy": "药品政策尚未确定",
	"refresh_exhausted": "此候选已刷新过", "already_selected": "本轮海克斯已选定",
	"pool_exhausted": "候选池不足", "missing_offer": "请先打开此轮海克斯",
	"unresolved_rank_values": "该技能档位数值待定", "combat_unavailable": "战斗系统未接入，未改变生命/冷却或药品",
	"unknown_command": "此请求不属于成长界面", "actor_mismatch": "角色不匹配", "cooldown": "技能仍在冷却", "action_locked": "当前动作无法施放", "unlearned": "尚未学习", "not_alive": "战败，仅可查看，续战后恢复", "encounter_frozen": "战后状态冻结", "previous_candidate_active": "旧技能效果仍在持续", "transaction_in_progress": "请稍后再试"}
var model: RefCounted
var hud: Control
var definitions: Dictionary
var display: Dictionary
var combat: Dictionary = {}
var active_milestone := 0
var _projection_revision := -1
var _projection_phase := ""
const UI_DIAGNOSTIC_RECEIPT_LIMIT := 256
var last_result: Dictionary = {}
# Recent UI diagnostics only. Authority deduplication lives in model.receipts;
# transaction undo lives in model.state.shop_undo. Neither is truncated here.
var receipt_log: Array[Dictionary] = []

func bind(authority: RefCounted, view: Control, content: Dictionary, presentation: Dictionary = {}) -> void:
	if is_instance_valid(hud) and hud.adapter.request_emitted.is_connected(handle_request):
		hud.adapter.request_emitted.disconnect(handle_request)
		if hud.modal_changed.is_connected(_on_modal_changed):
			hud.modal_changed.disconnect(_on_modal_changed)
	_projection_revision = -1
	_projection_phase = ""
	active_milestone = 0
	_announced_milestone = 0
	model = authority
	hud = view
	for row in hud.rows.values():
		row.options.select(0)
	definitions = content.duplicate(true)
	display = presentation.duplicate(true)
	for slot in hud.rows:
		var options: OptionButton = hud.rows[slot].options
		var names: Array = definitions.get("candidate_names", HUD_SOURCE.CANDIDATES)[slot]
		options.clear()
		for candidate_name in names: options.add_item(candidate_name)
	hud.adapter.request_emitted.connect(handle_request)
	hud.modal_changed.connect(_on_modal_changed)
	refresh()

func present_combat(snapshot: Dictionary) -> void:
	# Economy permissions remain model-owned; test-scene transitions also require the actual room phase.
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
	if int(request.get("state_revision", -1)) != int(snapshot.revision) and str(request.get("action","")) not in ["item","use_item"]:
		_finish(request, _boundary("stale_state"))
		return
	var action := str(request.get("action", ""))
	if action == "test_loadout":
		var denial := _test_loadout_denial()
		if not denial.is_empty():
			_finish(request, _boundary(denial))
		else:
			_pending_test_loadout=request.duplicate(true)
			_projection_revision=-1
			refresh()
			hud.set_receipt("正在切换自由测试…",true)
			test_loadout_requested.emit(request.get("config", {}).duplicate(true))
		return
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
			var index:int=int(request.get("slot_index",-1))
			if index>=0 and index<snapshot.inventory.size():
				var held:Dictionary=snapshot.inventory[index]
				if int(request.get("uid",held.uid))!=int(held.uid):
					_finish(request,_boundary("stale_state"));return
				if definitions.items[held.id].kind in ["normal","special"]:
					var use_request:Dictionary=request.duplicate(true)
					use_request.action="use_item";use_request.uid=held.uid
					if combat_request.get_connections().is_empty():_finish(request,_boundary("combat_unavailable"))
					else:combat_request.emit(use_request)
					return
			hud.open_supply(1)
			return
		"learn":
			args = {"slot": request.get("slot_id", ""), "candidate": request.get("candidate_id", ""), "expected_rank": request.get("expected_rank", -1)}
		"undo_new_points", "undo_skill":
			action = "undo_skill"
		"respec", "open_shop", "undo_shop", "buy_body":
			pass
		"select_body":
			args={"purchase_id":request.get("purchase_id",-1),"outcome":request.get("outcome","")}
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

func _test_loadout_denial() -> String:
	if not _pending_test_loadout.is_empty(): return "transaction_in_progress"
	if test_loadout_requested.get_connections().is_empty(): return "test_loadout_unavailable"
	if model.snapshot().phase != "safe" or combat.get("phase", "") not in ["preparation", "victory"]: return "test_loadout_phase"
	return ""

# Only the host that actually swaps the room/ledger may acknowledge this operation.
func complete_test_loadout_request(result: Dictionary) -> void:
	if _pending_test_loadout.is_empty(): return
	var request := _pending_test_loadout.duplicate(true)
	_pending_test_loadout.clear()
	_projection_revision=-1
	var confirmed := result.duplicate(true)
	confirmed["origin"]="room_transition"
	if not confirmed.get("accepted",false) and confirmed.get("reason","")=="unsafe_phase": confirmed["reason"]="test_loadout_phase"
	_finish(request,confirmed)

func _boundary(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason, "state_revision": model.snapshot().revision, "events": [], "origin": "ui_boundary"}

func _finish(request: Dictionary, result: Dictionary) -> void:
	last_result = result.duplicate(true)
	while receipt_log.size() >= UI_DIAGNOSTIC_RECEIPT_LIMIT:
		receipt_log.pop_front()
	receipt_log.append({"request": request.duplicate(true), "result": result.duplicate(true)})
	refresh()
	var message := "操作已完成" if result.accepted else reason_text(str(result.reason))
	var captions := {"learn": "技能已更新", "undo_new_points": "已撤销上次投入", "undo_skill": "已撤销上次投入", "respec": "训练洗点完成", "buy": "买入完成", "sell": "出售完成", "undo_shop": "已撤销上次交易", "hex_select": "海克斯已选定", "hex_refresh": "候选已刷新", "buy_body": "锻体已购 · 请选择提升", "select_body":"锻体已生效 · 不可撤销"}
	if result.accepted:
		message = str(captions.get(request.action, message))
		if request.action=="test_loadout": message="已返回正式成长" if request.get("config",{}).get("return_normal",false) else "已进入独立测试"
	hud.set_receipt(message, result.accepted)
	hud.adapter.feedback({"kind": "progression", "text": message})
	command_completed.emit(request.duplicate(true), result.duplicate(true))
	if definitions.get("auto_hex_in_combat", false):
		ensure_auto_hex()

func refresh() -> void:
	if not is_instance_valid(hud) or model == null:
		return
	var s: Dictionary = model.snapshot()
	if s.get("actor_dead",false): hud.set_hex_required(false)
	var out := {"actor_id": s.actor_id, "hero_name": definitions.get("hero_name", "风厉"), "test_mode": s.get("test_mode", false), "skill_descriptions":definitions.get("skill_descriptions",{}), "candidate_names":definitions.get("candidate_names",HUD_SOURCE.CANDIDATES), "hero_id":s.hero_id, "skill_caps":definitions.get("skill_caps",HUD_SOURCE.CAPS), "resource":combat.get("resource",{}), "stats":combat.get("stats",{}), "status_effects":combat.get("status_effects",[]), "revision": s.revision, "level": s.level, "points": s.points, "xp": s.xp, "gold": s.gold,
		"actor_dead":s.get("actor_dead",false), "can_undo": not s.get("actor_dead",false) and s.phase == "safe" and not s.allocations.is_empty(), "can_respec": not s.get("actor_dead",false) and s.training,
		"combat_available": combat.has("hp"), "hp": combat.get("hp", 0), "hp_max": combat.get("hp_max", 1), "shield": combat.get("shield", 0),
		"room": combat.get("room", "训练节点" if s.training else "安全区域" if s.phase == "safe" else "战斗中"),
		"wave": combat.get("wave", "—"), "source_label": display.get("source_label", "成长模型"), "skills": {}, "equipment": []}
	if definitions.has("final_design_version"):
		out.base_description="固有机制\n"+FinalDesign.base_description(s.hero_id,"固有机制")+"\n\n基础攻击\n"+FinalDesign.base_description(s.hero_id,"基础攻击")
	var curve: Array = definitions.get("xp_per_level", [])
	out.xp_next = curve[s.level - 1] if s.level < 18 and curve.size() >= s.level else 0
	for slot in ["Q", "E", "R", "P", "Shift"]:
		var ability: Dictionary = combat.get("skills", {}).get(slot, {}).duplicate(true)
		if slot == "Shift":
			ability.merge({"name": "位移", "rank": 1}, true)
			if definitions.has("final_design_version"):ability.description=FinalDesign.base_description(s.hero_id,"Shift")
		else:
			var skill: Dictionary = s.skills[slot]
			var candidate := str(skill.candidate)
			var index := maxi(0, int(candidate.right(1)) - 1)
			var descriptions: Array = definitions.get("skill_descriptions",{}).get(candidate,[])
			if skill.rank > 0 and descriptions.size() >= skill.rank: ability.description = descriptions[skill.rank-1]
			ability.merge({"rank": skill.rank, "candidate_index": index, "name": definitions.get("candidate_names", HUD_SOURCE.CANDIDATES)[slot][index] if skill.rank > 0 else "未学习"}, true)
			if slot == "R" and skill.rank == 0 and s.level < 6:
				ability.upgrade_reason = "需要6级"
		if not ability.has("reason"):
			ability.reason = "待战斗接入" if not combat.has("hp") else "状态由战斗提供"
		if slot != "Shift" and s.skills[slot].rank == 0:
			ability.reason = "尚未学习"
		out.skills[slot] = ability
	for entry in s.inventory:
		out.equipment.append({"name": display.get("short_items", {}).get(entry.id, item_name(entry.id).left(2)), "description": "%s ×%d" % [item_name(entry.id), entry.count], "uid": entry.uid})
	hud.adapter.present(out)
	# Combat snapshots may arrive every frame; do not rebuild open growth menus.
	if _projection_revision == int(s.revision) and _projection_phase == str(combat.get("phase","")):
		return
	_projection_revision = int(s.revision)
	_projection_phase = str(combat.get("phase",""))
	var items: Array = []
	for id in model.shop_catalog():
		var entry: Dictionary = model.shop_catalog()[id]
		entry=entry.duplicate(true)
		if model.has_method("equipment_task_status"):
			for task in model.equipment_task_status().values():
				if task.definition.equipment_id==id:
					entry.description=entry.get("description","")+"\n一次性修业任务 · "+task.definition.description+"\n进度："+("已完成" if task.completed else "%s / %s"%[ContentText.number(task.progress),ContentText.number(task.definition.threshold)])
		var components: Array = []
		for component in entry.get("components", []):
			components.append(item_name(component))
		var quote: Dictionary = model.purchase_quote(id)
		var purchase_reason := reason_text("not_alive") if s.get("actor_dead",false) else "" if quote.accepted else reason_text(quote.reason)
		if not s.get("actor_dead",false) and quote.reason == "unsupported_effect" and s.hero_id == "xuanlei" and entry.get("stats",{}).has("AP"):
			purchase_reason = "玄垒当前技能没有法强收益；此装备尚无有效消费者，不可购买"
		var owned := 0
		for held in s.inventory:
			if held.id == id: owned += int(held.count)
		items.append({"id": id, "name": item_name(id), "price": entry.price, "components": "、".join(components), "component_ids": entry.get("components",[]), "kind": entry.get("kind", "equipment"), "available":entry.get("availability",{}).get("supported",true), "stats":entry.get("stats",{}), "description":ContentText.describe(entry,definitions), "owned":owned, "charge":quote.charge, "credit":quote.credit, "buyable":quote.accepted and not s.get("actor_dead",false), "reason_text":purchase_reason})
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
		var dependencies:=ContentText.hex_dependencies(definition)
		choices.append({"id": id, "name": display.get("hexes", {}).get(id, definition.get("name",id)), "hero_only": i == 3,
			"description": ContentText.display_numbers(model.hex_description(id) if model.has_method("hex_description") else ContentText.describe(definition,definitions)), "requires": definition.get("requires", ""), "skill_dependencies":dependencies, "dependency_label":ContentText.dependency_label(dependencies,definitions), "refreshed": offer.refresh_used[i], "selected": offer.get("selected", "") == id})
	var selected_text: Array = []
	for id in s.selected_hex:
		selected_text.append("%s · %s" % [display.get("hexes", {}).get(id, id), "生效" if s.hex_status[id] == "active" else "休眠"])
	var test_denial := _test_loadout_denial()
	hud.present_progression({"actor_dead":s.get("actor_dead",false), "phase": s.phase, "combat_phase":combat.get("phase",""), "test_loadout_allowed":test_denial.is_empty(), "test_loadout_reason":"" if test_denial.is_empty() else reason_text(test_denial), "learned_skills":s.skills, "test_mode":s.get("test_mode",false), "test_definitions":definitions, "training": s.training, "gold": s.gold, "catalog": items, "inventory": inventory,
		"recovery_notice": "普通5瓶堆1槽；持有互斥且本房使用互斥；战斗中可按1—6或点击行装用药\n普通18%% / 特殊30%%最大生命；本房特殊已用 %d/2；满血不消耗" % s.special_uses,
		"body_available": definitions.get("body_enabled",true), "recovery_allowed":not s.get("actor_dead",false) and combat.get("phase", "victory" if s.phase == "safe" else "combat") in ["preparation","victory","combat"], "can_undo_shop": not s.get("actor_dead",false) and s.phase == "safe" and not s.shop_undo.is_empty(), "body_cost": definitions.get("body", {}).get("cost", 0), "body_count": s.body.size(), "body_pending":s.get("body_pending",{}), "body_outcomes":definitions.get("body",{}).get("outcomes",{}),
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

# Room freezes actual simulation before invoking this. The offer is persisted in authority.
func auto_hex_pending() -> bool:
	return model != null and not model.snapshot().get("actor_dead",false) and definitions.get("auto_hex_in_combat", false) and not model.snapshot().pending_milestones.is_empty()

func ensure_auto_hex() -> void:
	if _opening_auto_hex or not auto_hex_pending():
		if is_instance_valid(hud) and not auto_hex_pending(): hud.set_hex_required(false)
		return
	var current: Dictionary = model.snapshot()
	if hud.hex_required and hud.hex_draft.visible and active_milestone == int(current.pending_milestones[0]): return
	_opening_auto_hex = true
	var s: Dictionary = current
	active_milestone = int(s.pending_milestones[0])
	var key := str(active_milestone)
	if not s.offers.has(key):
		var result: Dictionary = model.command("auto-hex-%s-%d" % [s.actor_id,active_milestone], "hex_open", {"milestone":active_milestone})
		if not result.accepted:
			hud.set_receipt(reason_text(result.reason),false)
			_opening_auto_hex = false
			return
	refresh()
	hud.set_hex_required(true)
	hud.show_required_hex()
	if _announced_milestone != active_milestone:
		_announced_milestone = active_milestone
		hex_selection_required.emit(active_milestone)
	_opening_auto_hex = false
