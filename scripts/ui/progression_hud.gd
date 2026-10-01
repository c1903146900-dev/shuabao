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
var shop_buttons: Dictionary = {}
var sell_buttons: Array[Button] = []
var inventory_labels: Array[Label] = []
var undo_shop: Button
var body_button: Button
var body_label: Label
var milestone: OptionButton
var hex_open: Button
var hex_cards: Array[Dictionary] = []
var hex_summary: Label
var projection: Dictionary = {}

func _ready() -> void:
	super._ready()
	for b in slots.values():
		b.clip_text = true
	for b in equipment:
		b.clip_text = true
	# Share a row so training does not make the allocation panel taller.
	var allocation_column: VBoxContainer = panel.get_child(0)
	var row := HBoxContainer.new()
	var index := undo_button.get_index()
	allocation_column.add_child(row)
	allocation_column.move_child(row, index)
	undo_button.reparent(row)
	undo_button.text = "撤销上次投入"
	undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	respec_button = _button(row, "训练洗点", "respec")
	respec_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	supply_button = _button(self, "行装与补给  [ P ]", "")
	supply_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	supply_button.offset_left = 24
	supply_button.offset_right = 284
	supply_button.offset_top = -136
	supply_button.offset_bottom = -91
	supply_button.pressed.connect(func(): open_supply())
	move_child(supply_button, shade.get_index())
	supply = card(Vector2(-448, -267), Vector2(896, 534), Vector2(0.5, 0.5))
	var column_node := column(supply)
	var heading := HBoxContainer.new()
	column_node.add_child(heading)
	var title := label(heading, "行装与补给", 25, TEAL)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wallet = label(heading, "", 20, GOLD)
	supply_close = _button(heading, "关闭  Esc", "")
	supply_close.pressed.connect(close_panels)
	content_note = label(column_node, "", 13, MUTED)
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(864, 385)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column_node.add_child(tabs)
	var shop := VBoxContainer.new()
	shop.name = "补给商店"
	tabs.add_child(shop)
	label(shop, "固定目录 · 组件按实际投入抵价 · 安全阶段可交易", 14, MUTED)
	shop_grid = GridContainer.new()
	shop_grid.columns = 2
	shop_grid.add_theme_constant_override("h_separation", 12)
	shop_grid.add_theme_constant_override("v_separation", 10)
	var shop_scroll := ScrollContainer.new()
	shop_scroll.custom_minimum_size.y = 280
	shop_scroll.follow_focus = true
	shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop.add_child(shop_scroll)
	shop_scroll.add_child(shop_grid)
	shop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo_shop = _button(shop, "撤销上次交易", "undo_shop")
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
		var sell := _button(line, "出售", "")
		sell.custom_minimum_size.x = 145
		for kind in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style: StyleBoxFlat = sell.get_theme_stylebox(kind, "Button").duplicate()
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			sell.add_theme_stylebox_override(kind, style)
		sell.pressed.connect(func(): adapter.request("sell", {"uid": sell.get_meta("uid", -1)}))
		sell_buttons.append(sell)
	var body_row := HBoxContainer.new()
	bag.add_child(body_row)
	body_button = _button(body_row, "锻体", "buy_body")
	body_label = label(body_row, "", 14, MUTED)
	label(bag, "药品仅查看：恢复量与合法时机须由战斗协调层确认。", 14, MUTED)
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
		container.custom_minimum_size = Vector2(201, 243)
		container.add_theme_stylebox_override("panel", box(INK, TEAL if i == 3 else Color("3c5c6c")))
		choices.add_child(container)
		var col := column(container)
		label(col, "风厉专属" if i == 3 else "混合候选", 15, TEAL if i == 3 else MUTED)
		var name_label := label(col, "等待候选", 17, GOLD)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size = Vector2(176, 55)
		var description := label(col, "", 14, MUTED)
		description.custom_minimum_size.y = 42
		var select := _button(col, "选择", "")
		select.pressed.connect(func(): adapter.request("hex_select", {"milestone": projection.get("active_milestone", 0), "slot": i}))
		var reroll := _button(col, "刷新  1/1", "")
		reroll.pressed.connect(func(): adapter.request("hex_refresh", {"milestone": projection.get("active_milestone", 0), "slot": i}))
		hex_cards.append({"name": name_label, "description": description, "select": select, "refresh": reroll})
	hex_summary = label(hex_page, "", 14, MUTED)
	hex_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hex_summary.custom_minimum_size.x = 800
	receipt = label(column_node, "所有操作由成长模型确认；生命与冷却由战斗持有。", 14, MUTED)
	receipt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	receipt.custom_minimum_size.x = 850
	tabs.tab_changed.connect(_tab_changed)
	supply.hide()

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
		provenance.text = "%s · %s" % [snapshot.get("source_label", "成长模型"), "等级已满" if snapshot.get("level", 1) >= 18 else "经验曲线待定"]
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
	wallet.text = "金币 %d  ·  %s" % [view.gold, "训练节点" if view.training else "安全阶段" if view.phase == "safe" else "战斗中"]
	content_note.text = view.content_label
	var safe: bool = view.phase == "safe"
	# Stable catalog controls retain focus across command responses.
	for entry in view.catalog:
		if not shop_buttons.has(entry.id):
			var block := PanelContainer.new()
			block.custom_minimum_size.x = 408
			block.add_theme_stylebox_override("panel", box(INK, Color("3c5c6c")))
			shop_grid.add_child(block)
			var col := column(block)
			var item_title := label(col, entry.name, 18, TEAL)
			item_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var item_price := label(col, "", 14)
			item_price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var buy := _button(col, "合成 / 买入" if not entry.components.is_empty() else "买入", "")
			var item_id: String = entry.id
			buy.pressed.connect(func(): adapter.request("buy", {"item": item_id}))
			shop_buttons[entry.id] = buy
		var item_column: VBoxContainer = shop_buttons[entry.id].get_parent()
		item_column.get_child(0).text = entry.name
		item_column.get_child(1).text = "总价 %d 金币%s" % [entry.price, " · 需" + entry.components if not entry.components.is_empty() else ""]
		shop_buttons[entry.id].disabled = not safe
		shop_buttons[entry.id].tooltip_text = "由模型计算实际扣费" if safe else "仅安全阶段可交易"
	undo_shop.disabled = not view.can_undo_shop
	for i in range(6):
		var sell := sell_buttons[i]
		if i < view.inventory.size():
			var entry: Dictionary = view.inventory[i]
			inventory_labels[i].text = "%02d   %s  ×%d" % [i + 1, entry.name, entry.count]
			sell.text = "出售 +%d" % entry.resale
			sell.set_meta("uid", entry.uid)
			sell.disabled = not safe
		else:
			inventory_labels[i].text = "%02d   空槽" % [i + 1]
			sell.text = "未装备"
			sell.set_meta("uid", -1)
			sell.disabled = true
	body_button.text = "锻体 · %d金币" % view.body_cost
	body_button.disabled = not view.training or view.body_cost <= 0
	body_label.text = "已购买%d次 · 不可撤销，洗点不退款" % view.body_count
	milestone.clear()
	for value in view.milestones:
		milestone.add_item("%d级海克斯" % value, value)
		if value == view.active_milestone:
			milestone.select(milestone.item_count - 1)
	hex_open.disabled = view.milestones.is_empty()
	for i in range(4):
		var card_view: Dictionary = hex_cards[i]
		var exists: bool = i < view.choices.size()
		var data: Dictionary = view.choices[i] if exists else {}
		card_view.name.text = data.get("name", "尚未打开")
		card_view.description.text = ("需%s\n未学习时休眠" % data.requires if not data.get("requires", "").is_empty() else "无技能依赖") if exists else "选择一个等级轮次"
		card_view.select.text = "已选定" if data.get("selected", false) else "选择"
		card_view.select.disabled = not exists or view.offer_selected
		card_view.refresh.text = "刷新已用" if data.get("refreshed", false) else "刷新  1/1"
		card_view.refresh.disabled = not exists or view.offer_selected or data.get("refreshed", false)
	hex_summary.text = "已获得：" + (view.selected_text if not view.selected_text.is_empty() else "暂无")
	call_deferred("_supply_focus")

func set_receipt(message: String, accepted: bool) -> void:
	receipt.text = message
	receipt.add_theme_color_override("font_color", TEAL if accepted else GOLD)

func _request_offer() -> void:
	if milestone.selected >= 0:
		adapter.request("hex_open", {"milestone": milestone.get_item_id(milestone.selected)})

func _tab_changed(index: int) -> void:
	if index == 2 and projection.get("choices", []).is_empty():
		_request_offer()
	call_deferred("_supply_focus")

func open_supply(index := 0) -> void:
	if supply.visible and tabs.current_tab == index:
		close_panels()
		return
	old_focus = get_viewport().gui_get_focus_owner()
	panel.hide()
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
	if is_instance_valid(supply):
		supply.hide()
	super.open_allocation()
	modal_changed.emit(shade.visible)

func close_panels() -> void:
	if is_instance_valid(supply):
		supply.hide()
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
