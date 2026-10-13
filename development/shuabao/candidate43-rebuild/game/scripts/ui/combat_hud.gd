extends Control
## Snapshot-only combat presentation. All learning and economy mutations use the adapter.
const SkillSlot = preload("res://scripts/ui/skill_slot.gd")
const Adapter = preload("res://scripts/ui/hud_adapter.gd")
const INK := Color("0c1820")
const TEAL := Color("77d9c9")
const GOLD := Color("cbb17c")
const MUTED := Color("94a8b1")
const CANDIDATES := {"Q":["短矩形突刺","连续锁敌突袭","长矩形剑气"],"E":["追踪匕首","旋斩与瞬移","超载"],"R":["巨圆乱剑","累计普攻骨钉"],"P":["普攻吸血","残血反打","击杀成长"]}
const CAPS := {"Q":6,"E":6,"R":4,"P":4}
var adapter = Adapter.new()
var state: Dictionary = {}
var hp: ProgressBar
var xp: ProgressBar
var resource_bar: ProgressBar
var health_text: Label
var resource_text: Label
var identity: Label
var stat_text: Label
var progress_text: Label
var gold_text: Label
var provenance: Label
var notice: Label
var slots: Dictionary = {}
var skill_actions: Dictionary = {}
var equipment: Array[Button] = []
var allocation: Button
var shade: ColorRect
var panel: PanelContainer
var rows: Dictionary = {}
var point_label: Label
var undo_button: Button
var result_box: PanelContainer
var result_text: Label
var close_button: Button
var old_focus: Control
var focus_chain: Array[Control] = []
var feedback_layer: Control
var notice_tween: Tween
var selected_skill_slot := "Q"
var candidate_cards: HBoxContainer
var candidate_buttons: Array[Button] = []
var status_row: HBoxContainer
var _candidate_key := ""
var dock: PanelContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := Theme.new()
	t.default_font = preload("res://assets/ui/NotoSansCJKsc-Regular.otf")
	t.default_font_size = 14
	t.set_color("font_color", "Label", Color("e4eeef"))
	for kind in ["normal","hover","pressed","focus","disabled"]:
		t.set_stylebox(kind,"Button",box(Color("152b35") if kind=="hover" else INK,TEAL if kind=="focus" else Color("3c545e")))
		t.set_stylebox(kind,"OptionButton",box(INK,Color("3c545e")))
	t.set_color("font_color","Button",Color("e4eeef"))
	t.set_color("font_disabled_color","Button",Color("62737b"))
	t.set_stylebox("panel","TabContainer",box(INK,Color("354b55")))
	t.set_stylebox("tab_selected","TabContainer",box(Color("17313b"),GOLD))
	t.set_stylebox("tab_unselected","TabContainer",box(INK,Color("354b55")))
	theme = t
	var route := card(Vector2(-268,18),Vector2(248,65),Vector2(1,0))
	var rv := column(route)
	progress_text = label(rv,"房间 / 波次",14)
	gold_text = label(rv,"金币  0",17,GOLD)
	dock = card(Vector2(-410,-142),Vector2(820,130),Vector2(0.5,1))
	dock.name = "CombatDock"
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation",14)
	dock.add_child(main)
	var info := column(main)
	info.custom_minimum_size.x = 181
	identity = label(info,"英雄  ·  LV.01",16,TEAL)
	identity.set_script(preload("res://scripts/ui/detail_label.gd"))
	stat_text = label(info,"攻击 —    法强 —\n防御 —    攻速 —",12,MUTED)
	stat_text.custom_minimum_size.y = 39
	stat_text.mouse_filter=Control.MOUSE_FILTER_STOP
	allocation = Button.new()
	allocation.text = "技能点  0"
	allocation.add_theme_font_size_override("font_size",12)
	allocation.pressed.connect(open_allocation)
	info.add_child(allocation)
	var center := column(main)
	center.custom_minimum_size.x = 355
	center.add_theme_constant_override("separation",3)
	var skill_row := HBoxContainer.new()
	skill_row.add_theme_constant_override("separation",7)
	center.add_child(skill_row)
	for slot in ["P","Q","E","R","Shift"]:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(65,64)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skill_row.add_child(holder)
		var b := SkillSlot.new()
		b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.pressed.connect(_slot_request.bind(slot))
		holder.add_child(b)
		slots[slot] = b
		if slot != "Shift":
			var action := Button.new()
			action.text = "+"
			action.position = Vector2(17,-31)
			action.custom_minimum_size = Vector2(32,26)
			action.add_theme_font_size_override("font_size",19)
			var action_style := box(Color("294438"),GOLD)
			action_style.content_margin_top=0; action_style.content_margin_bottom=0
			action.add_theme_stylebox_override("normal",action_style)
			action.pressed.connect(_skill_action.bind(slot))
			holder.add_child(action)
			skill_actions[slot] = action
	var health := Control.new()
	health.custom_minimum_size.y=16
	center.add_child(health)
	hp=bar(health,Color("39a879"),16)
	hp.step=0.0 # Preserve fractional live HP; Range defaults to whole-number steps.
	# Panel padding is not part of the fill: it otherwise inflates low HP widths.
	for style_name in ["background","fill"]:
		var health_style: StyleBoxFlat=hp.get_theme_stylebox(style_name)
		health_style.content_margin_left=0;health_style.content_margin_right=0
	hp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_text=label(health,"生命",11)
	health_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var resource := Control.new()
	resource.custom_minimum_size.y=13
	center.add_child(resource)
	resource_bar=bar(resource,Color("3989ae"),13)
	resource_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resource_text=label(resource,"无额外资源",10)
	resource_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resource_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	xp=bar(center,GOLD,3)
	var inventory := column(main)
	inventory.custom_minimum_size.x=206
	var inventory_header:=HBoxContainer.new()
	inventory.add_child(inventory_header)
	label(inventory_header,"行装",12,MUTED)
	provenance=label(inventory_header,"",11,MUTED)
	provenance.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	provenance.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var grid:=GridContainer.new()
	grid.columns=3
	grid.add_theme_constant_override("h_separation",5)
	grid.add_theme_constant_override("v_separation",5)
	inventory.add_child(grid)
	for i in range(6):
		var b:=Button.new()
		b.custom_minimum_size=Vector2(64,33)
		b.add_theme_font_size_override("font_size",12)
		b.clip_text=true
		b.pressed.connect(func(): adapter.request("item",{"slot_index":i,"uid":b.get_meta("uid",-1)}))
		grid.add_child(b)
		equipment.append(b)
	status_row=HBoxContainer.new()
	status_row.name="StatusEffects"
	status_row.add_theme_constant_override("separation",5)
	add_child(status_row)
	status_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	status_row.offset_left=-191;status_row.offset_right=192
	status_row.offset_top=-214;status_row.offset_bottom=-176
	notice=label(self,"",18,GOLD)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left=-290;notice.offset_right=290
	# Reserve a separate toast row below the room's two-line instructions.
	notice.offset_top=142;notice.offset_bottom=174
	notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	feedback_layer=Control.new()
	add_child(feedback_layer)
	feedback_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	feedback_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_build_panels()
	adapter.snapshot_changed.connect(render)
	adapter.feedback_emitted.connect(show_feedback)

func box(fill: Color,edge: Color) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=fill;s.border_color=edge
	s.set_border_width_all(1);s.set_corner_radius_all(2)
	s.content_margin_left=10;s.content_margin_right=10
	s.content_margin_top=7;s.content_margin_bottom=7
	return s

func card(pos:Vector2,dimensions:Vector2,anchor:=Vector2.ZERO) -> PanelContainer:
	var c:=PanelContainer.new()
	add_child(c)
	c.anchor_left=anchor.x;c.anchor_right=anchor.x;c.anchor_top=anchor.y;c.anchor_bottom=anchor.y
	c.offset_left=pos.x;c.offset_top=pos.y;c.offset_right=pos.x+dimensions.x;c.offset_bottom=pos.y+dimensions.y
	c.add_theme_stylebox_override("panel",box(INK,Color("52615b")))
	return c

func column(parent:Node) -> VBoxContainer:
	var v:=VBoxContainer.new()
	v.add_theme_constant_override("separation",6)
	parent.add_child(v)
	return v

func label(parent:Node,text:String,font_size:=14,color:=Color("e4eeef")) -> Label:
	var l:=Label.new()
	l.text=text;l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color)
	parent.add_child(l)
	return l

func bar(parent:Node,color:Color,height:int) -> ProgressBar:
	var b:=ProgressBar.new()
	b.custom_minimum_size.y=height;b.show_percentage=false;b.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var bg:=box(Color("1d3038"),Color.TRANSPARENT)
	bg.content_margin_top=0;bg.content_margin_bottom=0
	b.add_theme_stylebox_override("background",bg)
	var fill:=box(color,Color.TRANSPARENT)
	fill.content_margin_top=0;fill.content_margin_bottom=0
	b.add_theme_stylebox_override("fill",fill)
	parent.add_child(b)
	return b

func _build_panels() -> void:
	# Compatibility selectors are data adapters only; no learning page or dropdown is displayed.
	for slot in ["Q","E","R","P"]:
		var options:=OptionButton.new()
		for candidate in CANDIDATES[slot]:options.add_item(candidate)
		add_child(options);options.hide()
		rows[slot]={"options":options}
	shade=ColorRect.new()
	add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color=Color(0.015,0.025,0.035,0.63);shade.hide()
	panel=card(Vector2(-470,-526),Vector2(940,344),Vector2(0.5,1))
	panel.name="InlineSkillChoices"
	var v:=column(panel)
	var heading:=HBoxContainer.new()
	v.add_child(heading)
	point_label=label(heading,"",16,GOLD)
	point_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	close_button=Button.new();close_button.text="收起  Esc"
	close_button.add_theme_font_size_override("font_size",12)
	heading.add_child(close_button);close_button.pressed.connect(_close_skill_choices)
	candidate_cards=HBoxContainer.new()
	candidate_cards.size_flags_vertical=Control.SIZE_EXPAND_FILL
	candidate_cards.add_theme_constant_override("separation",10)
	v.add_child(candidate_cards)
	undo_button=Button.new();undo_button.text="撤销上次投入"
	undo_button.pressed.connect(func(): adapter.request("undo_new_points"))
	undo_button.hide();v.add_child(undo_button)
	panel.hide()
	result_box=card(Vector2(-230,-175),Vector2(460,350),Vector2(0.5,0.5))
	var end:=column(result_box)
	label(end,"战斗结算",26,TEAL)
	result_text=label(end,"",18)
	var done:=Button.new();done.text="返回战场视图  /  Esc"
	done.pressed.connect(close_panels);end.add_child(done)
	result_box.hide()

func render(snapshot:Dictionary) -> void:
	state=snapshot.duplicate(true)
	identity.text="%s  ·  %02d级" % [state.get("hero_name","英雄"),int(state.get("level",1))]
	identity.tooltip_text=str(state.get("base_description",""))
	identity.mouse_filter=Control.MOUSE_FILTER_STOP if not identity.tooltip_text.is_empty() else Control.MOUSE_FILTER_IGNORE
	var current_hp: float=maxf(0,float(state.get("hp",0)))
	var maximum_hp: float=maxf(0.001,float(state.get("hp_max",1)))
	var current_shield: float=maxf(0,float(state.get("shield",0)))
	health_text.text="%d / %d" % [ceili(current_hp),ceili(maximum_hp)]
	if current_shield>0: health_text.text+="  ·  护盾 %d" % ceili(current_shield)
	hp.max_value=maximum_hp;hp.value=clampf(current_hp,0,maximum_hp)
	xp.max_value=maxf(1,state.get("xp_next",1));xp.value=state.get("xp",0)
	provenance.text="经验 %d / %d" % [state.get("xp",0),state.get("xp_next",0)]
	var resource:Dictionary=state.get("resource",{})
	resource_bar.max_value=maxf(1,resource.get("max",1));resource_bar.value=resource.get("current",0)
	resource_text.text="%s  %d / %d" % [resource.get("name","资源"),resource.get("current",0),resource.get("max",0)] if not resource.is_empty() else "无额外资源"
	var stats:Dictionary=state.get("stats",{})
	stat_text.text="攻击 %s    法强 %s\n防御 %s    攻速 %s" % [_stat(stats,"AD"),_stat(stats,"AP"),_stat(stats,"defense"),_stat(stats,"attack_speed")]
	stat_text.tooltip_text="移动速度 %s · 暴击率 %s" % [_stat(stats,"move_speed"),_stat(stats,"crit_chance")]
	progress_text.text="%s  ·  波次 %s" % [state.get("room","—"),state.get("wave","—")]
	gold_text.text="金币  %s" % state.get("gold",0)
	allocation.text="技能点  %d  /  基础18点" % state.get("points",0)
	allocation.tooltip_text="Q / E 最高6阶；P / R 最高4阶。R 首阶1点，后续每阶2点；其余每阶1点。无法全部点满。"
	for slot in slots:
		var skill:Dictionary=state.get("skills",{}).get(slot,{}).duplicate(true)
		if slot!="Shift":
			var rank:=int(skill.get("rank",0))
			var candidate:="%s%d" % [slot,int(skill.get("candidate_index",0))+1]
			skill.rank_cap=_cap(slot)
			skill.next_description=_skill_description(candidate,rank+1) if rank>0 and rank<_cap(slot) else ""
			skill.upgrade_reason=_learning_reason(slot)
			skill_actions[slot].visible=_learning_reason(slot).is_empty()
			skill_actions[slot].text="+" if rank==0 else "↑"
			skill_actions[slot].tooltip_text="选择%s技能 · 1点" % slot if rank==0 else "升级至%d阶 · %d点\n%s" % [rank+1,_cost(slot),skill.next_description]
			skill_actions[slot].disabled=not _learning_reason(slot).is_empty()
		skill.hero_id=state.get("hero_id","")
		slots[slot].present(slot,skill)
	for i in range(6):
		var items:Array=state.get("equipment",[])
		var item:Dictionary=items[i] if i<items.size() else {}
		equipment[i].text=str(item.get("name","·"));equipment[i].tooltip_text=str(item.get("description","空装备槽"));equipment[i].set_meta("uid",item.get("uid",-1))
	_render_statuses()
	if panel.visible:_render_allocation()

func _stat(stats:Dictionary,key:String) -> String:
	return preload("res://scripts/ui/content_text.gd").number(float(stats[key]),2) if stats.has(key) else "—"
func _cap(slot:String) -> int:
	return int(state.get("skill_caps",CAPS).get(slot,CAPS.get(slot,1)))
func _cost(slot:String) -> int:
	return 2 if slot=="R" and int(state.get("skills",{}).get(slot,{}).get("rank",0))>0 else 1
func _learning_reason(slot:String) -> String:
	var skill:Dictionary=state.get("skills",{}).get(slot,{})
	if state.get("actor_dead",false):return "战败后无法投入点数"
	if int(skill.get("rank",0))>=_cap(slot):return "已满阶"
	if not str(skill.get("upgrade_reason","")).is_empty():return str(skill.upgrade_reason)
	if slot=="R" and int(skill.get("rank",0))==0 and int(state.get("level",1))<6:return "6级可学习"
	if int(state.get("points",0))<_cost(slot):return "技能点不足"
	return ""

func _render_allocation() -> void:
	var slot:=selected_skill_slot
	if not rows.has(slot):return
	if int(state.get("skills",{}).get(slot,{}).get("rank",0))>0 or not _learning_reason(slot).is_empty():
		_close_skill_choices();return
	point_label.text="%s · 选择一个技能    /    可用 %d 点" % ["被动 P" if slot=="P" else slot,state.get("points",0)]
	var names:Array=state.get("candidate_names",{}).get(slot,[])
	if names.is_empty():
		for i in rows[slot].options.item_count:names.append(rows[slot].options.get_item_text(i))
	var key:="%s:%s:%s" % [slot,names.hash(),state.get("skill_descriptions",{}).hash()]
	if key==_candidate_key:return
	_candidate_key=key
	for child in candidate_cards.get_children():child.free()
	candidate_buttons.clear()
	for i in names.size():
		var candidate:="%s%d" % [slot,i+1]
		var c:=PanelContainer.new()
		c.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		c.add_theme_stylebox_override("panel",box(Color("11242d"),Color("395762")))
		candidate_cards.add_child(c)
		var v:=column(c)
		var name_label:=label(v,str(names[i]),17,TEAL)
		name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label(v,"%s · 第1阶 / %d阶" % [candidate,_cap(slot)],11,MUTED)
		var scroll:=ScrollContainer.new()
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
		v.add_child(scroll)
		var description:=label(scroll,_skill_description(candidate,1),13)
		description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		description.custom_minimum_size.x=240
		var learn:=Button.new();learn.text="学习  ·  1点"
		learn.pressed.connect(func(): adapter.request("learn",{"slot_id":slot,"candidate_id":candidate,"expected_rank":0}))
		v.add_child(learn);candidate_buttons.append(learn)
	focus_chain=[close_button]
	for b in candidate_buttons:focus_chain.append(b)
	for i in focus_chain.size():
		focus_chain[i].focus_next=focus_chain[i].get_path_to(focus_chain[(i+1)%focus_chain.size()])
		focus_chain[i].focus_previous=focus_chain[i].get_path_to(focus_chain[(i+focus_chain.size()-1)%focus_chain.size()])

func _skill_action(slot:String) -> void:
	if not _learning_reason(slot).is_empty():return
	var skill:Dictionary=state.get("skills",{}).get(slot,{})
	var rank:=int(skill.get("rank",0))
	if rank>0:
		adapter.request("learn",{"slot_id":slot,"candidate_id":"%s%d" % [slot,int(skill.get("candidate_index",0))+1],"expected_rank":rank})
		return
	if panel.visible and selected_skill_slot==slot:
		_close_skill_choices();return
	selected_skill_slot=slot
	open_allocation()

func _slot_request(slot:String) -> void:
	if slot!="Shift" and int(state.get("skills",{}).get(slot,{}).get("rank",0))==0:
		_skill_action(slot)
	elif slot!="P":adapter.request("ability",{"slot_id":slot})

func open_allocation() -> void:
	if int(state.get("skills",{}).get(selected_skill_slot,{}).get("rank",0))>0 or not _learning_reason(selected_skill_slot).is_empty():
		var found:=false
		for slot in ["P","Q","E","R"]:
			if int(state.get("skills",{}).get(slot,{}).get("rank",0))==0 and _learning_reason(slot).is_empty():selected_skill_slot=slot;found=true;break
		if not found:return
	old_focus=get_viewport().gui_get_focus_owner()
	panel.show();status_row.hide();_candidate_key="";_render_allocation()
	if not candidate_buttons.is_empty():candidate_buttons[0].grab_focus()

func _close_skill_choices() -> void:
	panel.hide();status_row.show()
	if is_instance_valid(old_focus) and old_focus.is_visible_in_tree():old_focus.grab_focus()
func close_panels() -> void:
	_close_skill_choices();result_box.hide();shade.hide()
func show_result(summary:Dictionary) -> void:
	panel.hide();shade.show();result_box.show()
	result_text.text="%s\n\n击败敌人   %d\n本场金币   +%d\n本场经验   +%d\n\n%s" % [summary.get("title","战斗结束"),summary.get("kills",0),summary.get("gold",0),summary.get("xp",0),summary.get("source_label","")]
	result_box.get_child(0).get_child(2).grab_focus()

func show_feedback(event:Dictionary) -> void:
	if event.get("kind","")=="damage":
		var l:=label(feedback_layer,str(event.get("text","0")),27,GOLD if event.get("critical",false) else Color.WHITE)
		l.position=Vector2(event.get("screen_x",size.x*0.5),event.get("screen_y",size.y*0.43))
		var tw:=create_tween().set_parallel()
		tw.tween_property(l,"position:y",l.position.y-60,0.7);tw.tween_property(l,"modulate:a",0.0,0.7)
		tw.chain().tween_callback(l.queue_free)
	else:
		notice.text=str(event.get("text",""));notice.modulate.a=1.0
		if notice_tween and notice_tween.is_valid():notice_tween.kill()
		notice_tween=create_tween();notice_tween.tween_interval(1.5);notice_tween.tween_property(notice,"modulate:a",0.0,0.4)
func blocks_gameplay_input() -> bool:
	return shade.visible or get_viewport().gui_get_hovered_control()!=null
func _input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE and (shade.visible or panel.visible):close_panels();get_viewport().set_input_as_handled()
		elif event.keycode==KEY_K:
			if panel.visible:_close_skill_choices()
			else:open_allocation()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and panel.visible:
		if not panel.get_global_rect().has_point(event.position) and not dock.get_global_rect().grow(35).has_point(event.position):_close_skill_choices()
func _skill_description(candidate:String,rank:int) -> String:
	var descriptions:Array=state.get("skill_descriptions",{}).get(candidate,[])
	if rank>0 and rank<=descriptions.size():return preload("res://scripts/ui/content_text.gd").skill_description(str(descriptions[rank-1]))
	return "本阶说明尚未提供"
func _preview_skill(slot:String) -> void:
	selected_skill_slot=slot
	if panel.visible:_candidate_key="";_render_allocation()

func _render_statuses() -> void:
	var effects:Array=state.get("status_effects",[]).slice(0,10)
	while status_row.get_child_count()>effects.size():
		var removed:=status_row.get_child(status_row.get_child_count()-1)
		status_row.remove_child(removed);removed.queue_free()
	for i in effects.size():
		var effect:Dictionary=effects[i]
		var b:Button
		if i<status_row.get_child_count():b=status_row.get_child(i)
		else:
			b=preload("res://scripts/ui/status_effect_badge.gd").new()
			b.custom_minimum_size=Vector2(37,38)
			b.mouse_default_cursor_shape=Control.CURSOR_HELP
			status_row.add_child(b)
		var bad:bool=str(effect.get("kind","buff"))=="debuff"
		if not b.has_meta("bad") or b.get_meta("bad")!=bad:
			var style:=box(Color("302023") if bad else Color("18352f"),Color("bb6f71") if bad else TEAL)
			style.content_margin_left=2;style.content_margin_right=2;style.content_margin_top=1;style.content_margin_bottom=1
			b.add_theme_stylebox_override("normal",style)
			b.set_meta("bad",bad)
		b.present(effect)
