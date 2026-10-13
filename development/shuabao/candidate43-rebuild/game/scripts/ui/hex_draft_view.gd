extends PanelContainer
## Dedicated mandatory level-up choice. No shop, wallet, tabs, or progression debug UI.
signal selected(slot: int)
signal refreshed(slot: int)
const Icon = preload("res://scripts/ui/hex_icon.gd")
const ContentText = preload("res://scripts/ui/content_text.gd")
const GOLD := Color("e5bf7c")
const TEAL := Color("8addcc")
const TEXT := Color("edf1ed")
const MUTED := Color("aab8b8")
var subtitle: Label
var footer: Label
var cards: Array[Dictionary] = []
var choosing := false
var current_milestone := 0
var shown := false
var last_view: Dictionary = {}
var error_text := ""
func _ready() -> void:
	add_theme_stylebox_override("panel", _style(Color("09141bea"),Color("466068"),16,0))
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation",14)
	add_child(frame)
	var title := _label(frame,"选择海克斯强化",32,TEXT)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	subtitle=_label(frame,"第1级 · 四选一",16,MUTED)
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation",14)
	frame.add_child(grid)
	for i in range(4):
		var card := PanelContainer.new()
		card.custom_minimum_size=Vector2(258,420)
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel",_style(Color("13242c"),TEAL.darkened(0.3) if i==3 else Color("48524b"),14,1))
		grid.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",8)
		card.add_child(column)
		var icon_row := HBoxContainer.new()
		column.add_child(icon_row)
		var icon := Icon.new()
		icon.custom_minimum_size=Vector2(54,54)
		icon_row.add_child(icon)
		var badge := _label(icon_row,"英雄专属" if i==3 else "海克斯强化",13,TEAL if i==3 else GOLD)
		badge.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		var title_label := _label(column,"",21,TEXT)
		title_label.custom_minimum_size=Vector2(224,54)
		title_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var dependency := _label(column,"",13,GOLD)
		dependency.custom_minimum_size.y=22
		dependency.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var description := _label(column,"",15,Color("cbd6d5"))
		description.custom_minimum_size=Vector2(224,180)
		description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_vertical=Control.SIZE_EXPAND_FILL
		var select := Button.new()
		select.text="选择强化"
		select.custom_minimum_size.y=40
		select.add_theme_color_override("font_color",Color("f0e3c5"))
		select.add_theme_stylebox_override("normal",_style(Color("294139"),Color("819977"),6,1))
		select.add_theme_stylebox_override("hover",_style(Color("365447"),GOLD,6,1))
		select.add_theme_stylebox_override("focus",_style(Color("365447"),GOLD,6,2))
		column.add_child(select)
		select.pressed.connect(func(): _choose(i))
		var refresh := Button.new()
		refresh.text="↻ 换一个 · 1次"
		refresh.custom_minimum_size.y=30
		refresh.add_theme_font_size_override("font_size",13)
		refresh.add_theme_stylebox_override("normal",_style(Color("13242c"),Color("13242c"),4,0))
		refresh.pressed.connect(func():
			if not choosing:
				error_text=""
				refreshed.emit(i))
		column.add_child(refresh)
		cards.append({"panel":card,"icon":icon,"name":title_label,"dependency":dependency,"description":description,"select":select,"refresh":refresh})
	footer=_label(frame,"每张卡可独立刷新一次 · 选择后返回测试场",13,MUTED)
	footer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
func present(view: Dictionary) -> void:
	last_view=view.duplicate(true)
	var milestone: int=view.get("active_milestone",1)
	if milestone != current_milestone:
		choosing=false
		current_milestone=milestone
		error_text=""
	subtitle.text="第 %d 级 · 四选一" % milestone
	var definitions: Dictionary=view.get("test_definitions",{})
	var skills: Dictionary=view.get("learned_skills",{})
	for i in range(cards.size()):
		var row: Dictionary=cards[i]
		var exists: bool=i<view.get("choices",[]).size()
		var choice: Dictionary=view.choices[i] if exists else {}
		var dependencies:=ContentText.hex_dependencies(choice)
		if dependencies.is_empty():
			dependencies=ContentText.hex_dependencies(definitions.get("hexes",{}).get(choice.get("id",""),{}))
		var dependency_label:=ContentText.dependency_label(dependencies,definitions)
		var dependency: String=str(dependencies[0]) if not dependencies.is_empty() else ""
		var active := true
		for candidate in dependencies:
			var learned := false
			for slot in skills:
				var skill:Dictionary=skills[slot]
				if skill.get("rank",0)>0 and (skill.get("candidate","")==candidate or slot==candidate): learned=true
			active=active and learned
		row.icon.set_emblem(choice.get("id",""),dependency,TEAL if i==3 else GOLD)
		row.name.text=choice.get("name", "等待候选")
		row.dependency.text="全技能适用" if dependencies.is_empty() else dependency_label+("" if active else " · 待学习")
		row.dependency.tooltip_text="学习全部对应技能后生效；改学其他技能时休眠，重学后恢复" if not dependencies.is_empty() else "无需学习特定技能即可生效"
		row.description.text=_player_description(choice.get("description",""))
		row.description.tooltip_text=ContentText.display_numbers(choice.get("description",""))+ ("\n学习%s后生效；未学或改学其他技能时休眠，重学后恢复。" % dependency_label if not dependencies.is_empty() else "")
		row.select.disabled=view.get("actor_dead",false) or not exists or choosing or view.get("offer_selected",false)
		row.refresh.disabled=view.get("actor_dead",false) or not exists or choosing or view.get("offer_selected",false) or choice.get("refreshed",false)
		row.refresh.text="本卡刷新已用" if choice.get("refreshed",false) else "↻ 换一个 · 1次"
		if not choosing:
			row.select.text="选择强化"
			row.panel.modulate=Color.WHITE
	footer.text=error_text if not error_text.is_empty() else "每张卡可独立刷新一次 · 选择后返回测试场"
	_focus_ring()
func _player_description(value: String) -> String:
	# Only remove redundant implementation phrasing; all numbers and conditions stay.
	return ContentText.display_numbers(value).replace("普通敌人", "普通怪").replace("本次实际推动", "推动").replace("本次有效冷却", "本次冷却").replace("直接命中最终伤害", "命中伤害").replace("基础摧城", "摧城").replace("；不能再次触发余震", "；余震不连锁").replace("；单人有效", "")
func _choose(index: int) -> void:
	if choosing or last_view.get("actor_dead",false): return
	choosing=true
	error_text=""
	for i in range(cards.size()):
		cards[i].select.disabled=true
		cards[i].refresh.disabled=true
		cards[i].panel.modulate=Color.WHITE if i==index else Color(0.55,0.6,0.6,0.75)
	cards[index].select.text="✓ 已选择"
	footer.text="获得强化："+cards[index].name.text
	# Show a short commitment flash while the authority still keeps combat paused.
	await get_tree().create_timer(0.24).timeout
	selected.emit(index)
	choosing=false
	present(last_view)
func show_error(message: String) -> void:
	error_text=message
	footer.text=message

func _focus_ring() -> void:
	var controls: Array[Control]=[]
	for card in cards:
		for field in ["select","refresh"]:
			if not card[field].disabled: controls.append(card[field])
	for i in range(controls.size()):
		controls[i].focus_next=controls[i].get_path_to(controls[(i+1)%controls.size()])
		controls[i].focus_previous=controls[i].get_path_to(controls[(i-1+controls.size())%controls.size()])

func focus_first() -> void:
	for card in cards:
		if not card.select.disabled:
			card.select.grab_focus()
			return
func _label(parent: Node,text: String,size_value: int,color: Color) -> Label:
	var node := Label.new();node.text=text;node.add_theme_font_size_override("font_size",size_value);node.add_theme_color_override("font_color",color);parent.add_child(node);return node
func _style(fill: Color,edge: Color,padding: int,width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=fill;style.border_color=edge
	style.set_border_width_all(width);style.set_corner_radius_all(5)
	style.content_margin_left=padding;style.content_margin_right=padding;style.content_margin_top=padding;style.content_margin_bottom=padding
	return style
