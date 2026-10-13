extends "res://scripts/ui/combat_hud.gd"
signal modal_changed(blocked: bool)
## Growth panels consume projections only; every mutation is an adapter request.
var supply: PanelContainer
var supply_button: Button
var supply_close: Button
var tabs: TabContainer
var wallet: Label
var receipt: Label
var content_note: Label
var respec_button: Button
var shop_grid: GridContainer
var use_buttons: Array[Button] = []
var use_status: Label
var shop_buttons: Dictionary = {}
var sell_buttons: Array[Button] = []
var inventory_labels: Array[Label] = []
var undo_shop: Button
var body_button: Button
var body_label: Label
var body_choices:HBoxContainer
var body_choice_buttons:Array[Button]=[]
var milestone: OptionButton
var hex_open: Button
var hex_cards: Array[Dictionary] = []
var hex_summary: Label
var projection: Dictionary = {}
var match_shop: HBoxContainer
var hex_required := false
var test_tools: PanelContainer
var test_tools_button: Button
var test_panel: VBoxContainer
var hex_draft: PanelContainer

func _ready() -> void:
	super._ready()
	for b in slots.values():
		b.clip_text = true
	for b in equipment:
		b.clip_text = true
	supply_button = _button(self, "装备商店  [ P ]", "")
	supply_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	supply_button.offset_left = 24
	supply_button.offset_right = 210
	supply_button.offset_top = -63
	supply_button.offset_bottom = -20
	supply_button.pressed.connect(func(): open_supply())
	move_child(supply_button, shade.get_index())
	supply = card(Vector2(-568, -310), Vector2(1136, 620), Vector2(0.5, 0.5))
	var column_node := column(supply)
	var heading := HBoxContainer.new()
	column_node.add_child(heading)
	var title := label(heading, "装备商店", 22, TEAL)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wallet = label(heading, "", 17, GOLD)
	supply_close = _button(heading, "关闭  Esc", "")
	supply_close.pressed.connect(close_panels)
	content_note = label(column_node, "", 13, MUTED)
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(1112, 454)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column_node.add_child(tabs)
	var shop := VBoxContainer.new()
	shop.name = "补给商店"
	tabs.add_child(shop)
	label(shop, "固定装备  /  已持组件自动抵价  /  安全阶段交易", 12, MUTED)
	match_shop = preload("res://scripts/ui/shop_view.gd").new()
	shop.add_child(match_shop)
	match_shop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	match_shop.buy_requested.connect(func(id): adapter.request("buy", {"item":id}))
	undo_shop = _button(match_shop.footer, "撤销交易", "undo_shop")
	undo_shop.add_theme_font_size_override("font_size",12)
	var bag := VBoxContainer.new()
	bag.name = "六槽行装"
	tabs.add_child(bag)
	label(bag, "药品占槽 · 出售返还实际投入的90% · 整堆出售", 14, MUTED)
	for i in range(6):
		var line := HBoxContainer.new()
		bag.add_child(line)
		var item_label := label(line, "空槽", 16)
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inventory_labels.append(item_label)
		var use := _button(line, "使用", "")
		use.pressed.connect(func(): adapter.request("use_item", {"uid": use.get_meta("uid",-1)}))
		use_buttons.append(use)
		var sell := _button(line, "出售", "")
		sell.custom_minimum_size.x = 145
		for kind in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style: StyleBoxFlat = sell.get_theme_stylebox(kind, "Button").duplicate()
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			sell.add_theme_stylebox_override(kind, style)
		sell.pressed.connect(func(): adapter.request("sell", {"uid": sell.get_meta("uid", -1)}))
		sell_buttons.append(sell)
	var training_row:=HBoxContainer.new()
	bag.add_child(training_row)
	undo_button.reparent(training_row)
	undo_button.show()
	respec_button=_button(training_row,"训练洗点","respec")
	var body_row := HBoxContainer.new()
	bag.add_child(body_row)
	body_button = _button(body_row, "锻体", "buy_body")
	body_label = label(body_row, "", 14, MUTED)
	body_choices=HBoxContainer.new();bag.add_child(body_choices)
	for i in range(3):
		var choice:Button=_button(body_choices,"","")
		choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		choice.custom_minimum_size=Vector2(0,52)
		choice.pressed.connect(func():adapter.request("select_body",{"purchase_id":choice.get_meta("purchase_id",-1),"outcome":choice.get_meta("outcome","")}))
		body_choice_buttons.append(choice)
	use_status = label(bag, "当前不可使用药品", 13, MUTED)
	var hex_page := VBoxContainer.new()
	hex_page.name = "海克斯"
	tabs.add_child(hex_page)
	var offer_row := HBoxContainer.new()
	hex_page.add_child(offer_row)
	milestone = OptionButton.new()
	milestone.custom_minimum_size.x = 175
	offer_row.add_child(milestone)
	milestone.item_selected.connect(func(_i): _request_offer())
	hex_open = _button(offer_row, "查看本轮候选", "")
	hex_open.pressed.connect(_request_offer)
	label(offer_row, "四选一 · 右槽英雄专属 · 每槽可刷新一次", 14, MUTED)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	hex_page.add_child(choices)
	for i in range(4):
		var container := PanelContainer.new()
		container.custom_minimum_size = Vector2(242, 335)
		container.add_theme_stylebox_override("panel", box(INK, TEAL if i == 3 else Color("3c5c6c")))
		choices.add_child(container)
		var col := column(container)
		label(col, "英雄专属" if i == 3 else "混合候选", 15, TEAL if i == 3 else MUTED)
		var name_label := label(col, "等待候选", 17, GOLD)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size = Vector2(217, 40)
		var description := label(col, "", 14, MUTED)
		description.custom_minimum_size = Vector2(217, 170)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 14)
		var select := _button(col, "选择", "")
		select.pressed.connect(func(): adapter.request("hex_select", {"milestone": projection.get("active_milestone", 0), "slot": i}))
		var reroll := _button(col, "刷新  1/1", "")
		reroll.pressed.connect(func(): adapter.request("hex_refresh", {"milestone": projection.get("active_milestone", 0), "slot": i}))
		hex_cards.append({"name": name_label, "description": description, "select": select, "refresh": reroll})
	hex_summary = label(hex_page, "", 14, MUTED)
	hex_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hex_summary.custom_minimum_size.x = 800
	test_tools=card(Vector2(-530,-294),Vector2(1060,588),Vector2(0.5,0.5))
	test_tools.name="TestingTools"
	var testing_column:=column(test_tools)
	var testing_header:=HBoxContainer.new()
	testing_column.add_child(testing_header)
	var testing_title:=label(testing_header,"独立测试配置",21,TEAL)
	testing_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var testing_close:=_button(testing_header,"关闭  Esc","")
	testing_close.pressed.connect(close_panels)
	test_panel = preload("res://scripts/ui/test_loadout_panel.gd").new()
	testing_column.add_child(test_panel)
	test_tools.hide()
	test_tools_button=_button(self,"测试配置  [ F8 ]","")
	test_tools_button.add_theme_font_size_override("font_size",11)
	test_tools_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	test_tools_button.offset_left=24;test_tools_button.offset_right=210
	test_tools_button.offset_top=-98;test_tools_button.offset_bottom=-70
	test_tools_button.pressed.connect(open_test_tools)
	move_child(test_tools_button,shade.get_index())
	test_panel.requested.connect(func(config): adapter.request("test_loadout", {"config":config}))
	receipt = label(column_node, "选择装备查看详情与合成路线", 14, MUTED)
	receipt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	receipt.custom_minimum_size.x = 850
	tabs.tab_changed.connect(_tab_changed)
	supply.hide()
	hex_draft = preload("res://scripts/ui/hex_draft_view.gd").new()
	add_child(hex_draft)
	hex_draft.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hex_draft.offset_left=-560
	hex_draft.offset_top=-320
	hex_draft.offset_right=560
	hex_draft.offset_bottom=320
	hex_draft.selected.connect(func(slot): adapter.request("hex_select", {"milestone":projection.get("active_milestone",0),"slot":slot}))
	hex_draft.refreshed.connect(func(slot): adapter.request("hex_refresh", {"milestone":projection.get("active_milestone",0),"slot":slot}))
	hex_draft.hide()

func _button(parent: Node, caption: String, action: String) -> Button:
	var b := Button.new()
	b.text = caption
	parent.add_child(b)
	if not action.is_empty():
		b.pressed.connect(func(): adapter.request(action))
	return b

func render(snapshot: Dictionary) -> void:
	super.render(snapshot)
	if not snapshot.get("combat_available", true):
		health_text.text = "生命 —  等待战斗系统"
	if snapshot.get("xp_next", 0) == 0:
		provenance.text = "等级已满" if snapshot.get("level", 1) >= 18 else "经验待更新"
	if is_instance_valid(respec_button):
		respec_button.disabled = not snapshot.get("can_respec", false)
		respec_button.tooltip_text = "训练节点可重配；不恢复生命或冷却"

func _render_allocation() -> void:
	if is_instance_valid(respec_button):
		respec_button.disabled = not state.get("can_respec", false)
	super._render_allocation()
	if is_instance_valid(respec_button) and not respec_button.disabled:
		focus_chain.append(respec_button)
		_cycle_focus(focus_chain)

func present_progression(view: Dictionary) -> void:
	projection = view.duplicate(true)
	if is_instance_valid(hex_draft): hex_draft.present(view)
	wallet.text = "金币 %d  ·  %s" % [view.gold, "战败 · 只读" if view.get("combat_phase","")=="true_dead" else "训练节点" if view.training else "安全阶段" if view.phase == "safe" else "战斗中"]
	content_note.text = "战败 · 可查看装备与配置，续战后恢复操作" if view.get("actor_dead",false) else "安全阶段可购买、出售与合成 · 装备属性由实际账本结算"
	var safe: bool = view.phase == "safe" and not view.get("actor_dead",false)
	match_shop.present(view.catalog)
	shop_buttons = match_shop.buttons
	test_panel.present(view.get("test_definitions",{}), view.get("test_loadout_allowed",false), view.get("test_mode",false), view.get("test_loadout_reason","当前无法切换自由测试"))
	test_tools_button.visible=view.get("test_loadout_allowed",false) or view.get("test_mode",false)
	undo_shop.disabled = not view.can_undo_shop
	undo_button.disabled = not state.get("can_undo",false)
	for i in range(6):
		var sell := sell_buttons[i]
		var use := use_buttons[i]
		use.disabled = true
		if i < view.inventory.size():
			var entry: Dictionary = view.inventory[i]
			inventory_labels[i].text = "%02d   %s  ×%d" % [i + 1, entry.name, entry.count]
			sell.text = "出售 +%d" % entry.resale
			sell.set_meta("uid", entry.uid)
			use.set_meta("uid",entry.uid)
			use.disabled = not view.get("recovery_allowed",true) or entry.kind not in ["normal","special"] or view.get("combat_phase","")=="combat"
			use.tooltip_text = "战斗中请关闭商店，按1—6或点击下方行装使用" if view.get("combat_phase","")=="combat" else "满血不会消耗"
			sell.disabled = not safe
		else:
			inventory_labels[i].text = "%02d   空槽" % [i + 1]
			sell.text = "未装备"
			sell.set_meta("uid", -1)
			sell.disabled = true
	use_status.text = "战败，仅可查看，续战后恢复" if view.get("actor_dead",false) else view.get("recovery_notice","当前不可使用药品")
	body_button.text = "锻体 · %d金币" % view.body_cost
	body_button.disabled = view.get("actor_dead",false) or not safe or view.body_cost <= 0 or not view.get("body_available",true) or not view.get("body_pending",{}).is_empty()
	body_button.get_parent().visible = view.get("body_available",true)
	body_label.text = "已购买%d次 · 不可撤销，洗点不退款" % view.body_count
	var pending_body:Dictionary=view.get("body_pending",{})
	body_choices.visible=not pending_body.is_empty()
	for i in range(body_choice_buttons.size()):
		var choice:Button=body_choice_buttons[i]
		if i>=pending_body.get("candidates",[]).size():choice.visible=false;continue
		var outcome:String=pending_body.candidates[i]
		var definition:Dictionary=view.body_outcomes[outcome]
		var lines:PackedStringArray=[]
		var names:Dictionary={"AD":"攻击力","AP":"法术强度","attack_speed":"攻击速度","max_hp":"最大生命","defense":"防御力","penetration":"穿甲","crit_chance":"暴击率"}
		for key in definition.stats:
			var value:float=definition.stats[key]
			lines.append("%s +%s%s"%[names.get(key,key),String.num(value*100 if key in ["attack_speed","crit_chance"] else value,2).trim_suffix(".00"),"%" if key in ["attack_speed","crit_chance"] else ""])
		choice.text=definition.name+"\n"+" · ".join(lines)
		choice.set_meta("purchase_id",pending_body.purchase_id);choice.set_meta("outcome",outcome)
		choice.visible=true;choice.disabled=not safe or view.get("actor_dead",false)
	milestone.clear()
	for value in view.milestones:
		milestone.add_item("%d级海克斯" % value, value)
		if value == view.active_milestone:
			milestone.select(milestone.item_count - 1)
	hex_open.disabled = view.get("actor_dead",false) or view.milestones.is_empty()
	for i in range(4):
		var card_view: Dictionary = hex_cards[i]
		var exists: bool = i < view.choices.size()
		var data: Dictionary = view.choices[i] if exists else {}
		card_view.name.text = data.get("name", "尚未打开")
		var dependency_label:String=data.get("dependency_label",data.get("requires",""))
		card_view.description.text = (data.get("description", "") + "\n" + ("依赖 %s：全部学会后生效；未学或改学时休眠，重学后恢复" % dependency_label if not dependency_label.is_empty() else "无技能依赖")) if exists else "选择一个等级轮次"
		card_view.select.text = "已选定" if data.get("selected", false) else "选择"
		card_view.select.disabled = view.get("actor_dead",false) or not exists or view.offer_selected
		card_view.refresh.text = "刷新已用" if data.get("refreshed", false) else "刷新  1/1"
		card_view.refresh.disabled = view.get("actor_dead",false) or not exists or view.offer_selected or data.get("refreshed", false)
	hex_summary.text = "已获得：" + (view.selected_text if not view.selected_text.is_empty() else "暂无")
	call_deferred("_supply_focus")

func set_receipt(message: String, accepted: bool) -> void:
	receipt.text = message
	receipt.add_theme_color_override("font_color", TEAL if accepted else GOLD)
	if hex_required and is_instance_valid(hex_draft) and not accepted:
		hex_draft.show_error(message)

func _request_offer() -> void:
	if milestone.selected >= 0:
		adapter.request("hex_open", {"milestone": milestone.get_item_id(milestone.selected)})

func _tab_changed(index: int) -> void:
	if index == 2 and projection.get("choices", []).is_empty():
		_request_offer()
	call_deferred("_supply_focus")

func open_supply(index := 0) -> void:
	if index==3:
		open_test_tools();return
	if hex_required:
		show_required_hex()
		return
	if supply.visible and tabs.current_tab == index:
		close_panels()
		return
	old_focus = get_viewport().gui_get_focus_owner()
	_close_skill_choices()
	test_tools.hide()
	result_box.hide()
	shade.show()
	supply.show()
	modal_changed.emit(true)
	tabs.current_tab = index
	if index == 0:
		adapter.request("open_shop")
	elif index == 2:
		_request_offer()
	supply_close.grab_focus()
	call_deferred("_supply_focus")

func open_allocation() -> void:
	if hex_required or shade.visible: return
	if is_instance_valid(supply):
		supply.hide()
	shade.hide()
	super.open_allocation()
	modal_changed.emit(false)

func close_panels() -> void:
	if is_instance_valid(test_tools):test_tools.hide()
	if hex_required:
		set_receipt("请先完成当前海克斯选择", false)
		show_required_hex()
		return
	if is_instance_valid(supply):
		supply.hide()
	if is_instance_valid(hex_draft): hex_draft.hide()
	super.close_panels()
	modal_changed.emit(false)

func _cycle_focus(controls: Array[Control]) -> void:
	for i in range(controls.size()):
		controls[i].focus_next = controls[i].get_path_to(controls[(i + 1) % controls.size()])
		controls[i].focus_previous = controls[i].get_path_to(controls[(i + controls.size() - 1) % controls.size()])

func _supply_focus() -> void:
	if not supply.visible:
		return
	var controls: Array[Control] = [supply_close, tabs.get_tab_bar()]
	_collect_focus(tabs.get_current_tab_control(), controls)
	_cycle_focus(controls)
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and not controls.has(owner):
		supply_close.grab_focus()

func _collect_focus(node: Node, controls: Array[Control]) -> void:
	if node is Control and node.visible and node.focus_mode == Control.FOCUS_ALL:
		if not node is BaseButton or not node.disabled:
			controls.append(node)
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree():
			_collect_focus(child, controls)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F8:
		if test_tools.visible:close_panels()
		else:open_test_tools()
		get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		if supply.visible:
			close_panels()
		else:
			open_supply()
		get_viewport().set_input_as_handled()
		return
	super._input(event)
	if shade.visible and event is InputEventKey:
		var key_code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key_code in [KEY_Q, KEY_E, KEY_R, KEY_SHIFT, KEY_W, KEY_A, KEY_S, KEY_D]:
			get_viewport().set_input_as_handled()

func show_result(summary: Dictionary) -> void:
	if is_instance_valid(supply):
		supply.hide()
	super.show_result(summary)
	modal_changed.emit(true)

func set_hex_required(required: bool) -> void:
	if hex_required == required: return
	var was_required := hex_required
	hex_required = required
	if was_required and not required:
		hex_draft.hide()
		close_panels()

func show_required_hex() -> void:
	if hex_draft.visible: return
	panel.hide()
	result_box.hide()
	supply.hide()
	shade.show()
	hex_draft.show()
	hex_draft.present(projection)
	hex_draft.focus_first()
	modal_changed.emit(true)

func open_test_tools() -> void:
	if hex_required:return
	_close_skill_choices();supply.hide();result_box.hide()
	shade.show();test_tools.show()
	modal_changed.emit(true)
	var controls:Array[Control]=[]
	_collect_focus(test_tools,controls)
	_cycle_focus(controls)
	test_panel.level.get_line_edit().grab_focus()
