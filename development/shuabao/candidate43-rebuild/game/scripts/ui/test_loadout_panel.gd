extends VBoxContainer
## Emits a specification only. Host must create a distinct sandbox authority.
signal requested(config: Dictionary)
var level: SpinBox
var skills := {}
var item_slots: Array[OptionButton] = []
var hex_slots: Array[OptionButton] = []
var apply_button: Button
var return_button: Button
var notice: Label
var built := false
var built_for := ""
func _ready() -> void:
	notice = Label.new()
	notice.text = "自由测试 · 独立临时账本 · 不改变正式存档、奖励或物品"
	add_child(notice)
	var top := HBoxContainer.new()
	add_child(top)
	var caption := Label.new()
	caption.text = "等级"
	top.add_child(caption)
	level = SpinBox.new()
	level.min_value=1; level.max_value=18; level.value=18
	top.add_child(level)
	for slot in ["P","Q","E","R"]:
		var pick := OptionButton.new()
		top.add_child(pick)
		var rank := SpinBox.new()
		rank.min_value=0; rank.max_value=4 if slot in ["P","R"] else 6; rank.value=3 if slot in ["P","R"] else 5
		top.add_child(rank)
		skills[slot]={"pick":pick,"rank":rank}
	var info := Label.new()
	info.text = "基础18点预算；Q/E最高6阶，P/R最高4阶。R耗点1/2/2/2，6级学习后可随时升级。无法全满。"
	add_child(info)
	for pair in [["六槽指定装备",6,item_slots],["五个指定海克斯",5,hex_slots]]:
		var title := Label.new(); title.text=pair[0]; add_child(title)
		var grid := GridContainer.new(); grid.columns=3; add_child(grid)
		for i in range(pair[1]):
			var pick := OptionButton.new(); pick.custom_minimum_size=Vector2(310,38); grid.add_child(pick); pair[2].append(pick)
	apply_button=Button.new(); apply_button.text="进入独立测试（不产生正式收益）"; add_child(apply_button)
	apply_button.pressed.connect(_apply)
	return_button=Button.new(); return_button.text="返回正式账本"; add_child(return_button)
	return_button.pressed.connect(func(): requested.emit({"return_normal":true}))
func present(definitions: Dictionary, allowed: bool, test_mode: bool, reason := "") -> void:
	apply_button.disabled=not allowed
	return_button.disabled=not allowed or not test_mode
	notice.text="当前：%s · %s" % ["自由测试（不产正式收益）" if test_mode else "正式成长", "开战前或胜利后可切换，正式成长独立保留" if allowed else reason]
	apply_button.tooltip_text=reason
	return_button.tooltip_text=reason
	if definitions.is_empty(): return
	var identity:=str(definitions.get("candidate_names",{}).hash())+str(definitions.get("hexes",{}).hash())
	if built and built_for==identity:return
	built=true;built_for=identity
	for slot in skills:
		var pick: OptionButton=skills[slot].pick
		pick.clear()
		var names: Array=definitions.get("candidate_names",{}).get(slot,definitions.candidates[slot])
		for i in range(names.size()): pick.add_item("%s · %s" % [slot,names[i]]); pick.set_item_metadata(i,definitions.candidates[slot][i])
	for pick in item_slots:
		pick.clear()
		pick.add_item("空槽");pick.set_item_metadata(0,"")
		for id in definitions.items:
			pick.add_item(definitions.items[id].name);pick.set_item_metadata(pick.item_count-1,id)
	for pick in hex_slots:
		pick.clear()
		pick.add_item("无海克斯");pick.set_item_metadata(0,"")
		for id in definitions.hexes:
			pick.add_item(definitions.hexes[id].name);pick.set_item_metadata(pick.item_count-1,id)
func _apply() -> void:
	var out := {"level":int(level.value),"skills":{},"items":[],"hexes":[]}
	for slot in skills:
		var row: Dictionary=skills[slot]
		out.skills[slot]={"candidate":row.pick.get_item_metadata(row.pick.selected),"rank":int(row.rank.value)}
	for pick in item_slots:
		var id: String=pick.get_item_metadata(pick.selected)
		if not id.is_empty():out.items.append(id)
	for pick in hex_slots:
		var id: String=pick.get_item_metadata(pick.selected)
		if not id.is_empty():out.hexes.append(id)
	requested.emit(out)
