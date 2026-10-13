extends HBoxContainer
## Reference-led match shop. Uses authority quotes; never estimates component credit locally.
signal buy_requested(id:String)
const ItemTile=preload("res://scripts/ui/shop_item_tile.gd")
const Text=preload("res://scripts/ui/content_text.gd")
const TEAL=Color("77d9c9")
const GOLD=Color("cbb17c")
const MUTED=Color("94a8b1")
var filters:OptionButton
var search:LineEdit
var listing:VBoxContainer
var details:Label
var tree:VBoxContainer
var purchase:Button
var summary:Label
var footer:HBoxContainer
var current_id:=""
var catalog:Array=[]
var buttons:Dictionary={}
var selected_filter:="全部"
var category_buttons:Dictionary={}
var tier_sections:Dictionary={}
var upgrade_row:HBoxContainer
var selected_row:HBoxContainer
var component_row:HBoxContainer
var recipe_note:Label
var recipe_connector:Control
var item_title:Label
var item_price:Label
var item_art:TextureRect
var _icons:Dictionary={}
var _catalog_structure:=""
var _selected_detail:=""
func _ready() -> void:
	add_theme_constant_override("separation",16)
	var left:=VBoxContainer.new();left.custom_minimum_size.x=584
	left.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_child(left)
	search=LineEdit.new();search.placeholder_text="搜索名称、属性或装备效果…";search.clear_button_enabled=true
	search.custom_minimum_size.y=32
	search.text_changed.connect(func(_text):_list())
	left.add_child(search)
	var categories:=HBoxContainer.new();categories.add_theme_constant_override("separation",4)
	left.add_child(categories)
	# Keep a non-visual compatibility filter for existing callers.
	filters=OptionButton.new();add_child(filters);filters.hide()
	for category in ["全部","攻击","防御","法术","功能","药品"]:
		filters.add_item(category)
		var b:=Button.new();b.text=category;b.custom_minimum_size=Vector2(72,30)
		b.add_theme_font_size_override("font_size",12)
		b.pressed.connect(func():selected_filter=category;_list())
		categories.add_child(b);category_buttons[category]=b
	filters.item_selected.connect(func(i):selected_filter=filters.get_item_text(i);_list())
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(584,280)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	listing=VBoxContainer.new();listing.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	listing.add_theme_constant_override("separation",10);scroll.add_child(listing)
	footer=HBoxContainer.new();footer.add_theme_constant_override("separation",8);left.add_child(footer)
	var hint:=_label(footer,"P 关闭  ·  点击图标查看路线",11,MUTED);hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var separator:=VSeparator.new();add_child(separator)
	var right:=VBoxContainer.new();right.custom_minimum_size.x=450
	right.add_theme_constant_override("separation",6);add_child(right)
	_label(right,"可升级为",12,MUTED)
	upgrade_row=HBoxContainer.new();upgrade_row.custom_minimum_size.y=39;upgrade_row.add_theme_constant_override("separation",5);right.add_child(upgrade_row)
	tree=VBoxContainer.new();tree.custom_minimum_size.y=110;tree.add_theme_constant_override("separation",3);right.add_child(tree)
	selected_row=HBoxContainer.new();selected_row.alignment=BoxContainer.ALIGNMENT_CENTER;tree.add_child(selected_row)
	recipe_connector=preload("res://scripts/ui/recipe_connector.gd").new();tree.add_child(recipe_connector)
	component_row=HBoxContainer.new();component_row.alignment=BoxContainer.ALIGNMENT_CENTER;component_row.add_theme_constant_override("separation",22);tree.add_child(component_row)
	recipe_note=_label(right,"",11,MUTED)
	var divider:=HSeparator.new();right.add_child(divider)
	var title_row:=HBoxContainer.new();title_row.add_theme_constant_override("separation",10);right.add_child(title_row)
	item_art=TextureRect.new();item_art.custom_minimum_size=Vector2(42,42);item_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;item_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;title_row.add_child(item_art)
	var title_col:=VBoxContainer.new();title_col.add_theme_constant_override("separation",0);title_row.add_child(title_col)
	item_title=_label(title_col,"",17,GOLD);item_price=_label(title_col,"",12,MUTED)
	var description_scroll:=ScrollContainer.new();description_scroll.custom_minimum_size.y=105
	description_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;description_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;right.add_child(description_scroll)
	details=_label(description_scroll,"",13,Color("dbe6e8"));details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.custom_minimum_size.x=432;details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	summary=_label(right,"",12,GOLD);summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;summary.custom_minimum_size.x=432
	purchase=Button.new();purchase.custom_minimum_size.y=35;purchase.add_theme_font_size_override("font_size",15)
	purchase.pressed.connect(func():if not purchase.disabled:buy_requested.emit(current_id))
	right.add_child(purchase)
func _label(parent:Node,value:String,font_size:int,color:Color) -> Label:
	var l:=Label.new();l.text=value;l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color);parent.add_child(l);return l
func present(entries:Array) -> void:
	catalog=entries.duplicate(true)
	if _entry(current_id).is_empty() and not catalog.is_empty():current_id=catalog[0].id
	_list();_detail()
func _category(entry:Dictionary) -> String:
	if entry.kind in ["normal","special"]:return "药品"
	var stats:Dictionary=entry.get("stats",{})
	if stats.has("AD") or stats.has("crit_chance") or stats.has("attack_speed"):return "攻击"
	if stats.has("AP"):return "法术"
	if stats.has("max_hp") or stats.has("defense"):return "防御"
	return "功能"
func _matches_category(entry:Dictionary) -> bool:
	if selected_filter=="全部":return true
	if selected_filter=="药品":return entry.kind in ["normal","special"]
	var stats:Dictionary=entry.get("stats",{})
	var keys:Array={"攻击":["AD","crit_chance","attack_speed","lifesteal","penetration"],"防御":["max_hp","defense","tenacity","hp_regen"],"法术":["AP","cooldown_reduction"],"功能":["move_speed","cooldown_reduction"]}.get(selected_filter,[])
	for key in keys:
		if stats.has(key):return true
	return _category(entry)==selected_filter
func _tier(entry:Dictionary) -> String:
	if entry.kind in ["normal","special"]:return "消耗品"
	if entry.get("component_ids",[]).is_empty():return "基础装备"
	for parent_entry in catalog:
		if entry.id in parent_entry.get("component_ids",[]):return "进阶装备"
	return "成装"
func _list() -> void:
	var ids:Array=[]
	for entry in catalog:ids.append(entry.id)
	var structure:=str(ids.hash())
	if structure!=_catalog_structure:
		_catalog_structure=structure
		for child in listing.get_children():child.free()
		buttons.clear();tier_sections.clear()
		for tier_name in ["成装","进阶装备","基础装备","消耗品"]:
			var section:=VBoxContainer.new();section.add_theme_constant_override("separation",4);listing.add_child(section)
			_label(section,tier_name,12,MUTED)
			var grid:=GridContainer.new();grid.columns=7;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",5);section.add_child(grid)
			tier_sections[tier_name]={"section":section,"grid":grid}
		for entry in catalog:
			var b:=ItemTile.new();b.custom_minimum_size=Vector2(74,80);b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
			var empty:=StyleBoxEmpty.new();b.add_theme_stylebox_override("normal",empty)
			var id:String=entry.id;b.pressed.connect(func():inspect(id))
			tier_sections[_tier(entry)].grid.add_child(b);buttons[id]=b
	var needle:=search.text.strip_edges().to_lower()
	for entry in catalog:
		var b:Button=buttons[entry.id]
		b.present(entry,_icon(entry.id,_category(entry)),entry.id==current_id)
		b.visible=_matches_category(entry) and (needle.is_empty() or (str(entry.name)+" "+str(entry.description)+" "+Text.stats(entry.get("stats",{}))).to_lower().contains(needle))
	for tier_name in tier_sections:
		var has_visible:=false
		for child in tier_sections[tier_name].grid.get_children():
			if child.visible:has_visible=true;break
		tier_sections[tier_name].section.visible=has_visible
	for category in category_buttons:category_buttons[category].add_theme_color_override("font_color",GOLD if category==selected_filter else MUTED)
func inspect(id:String) -> void:
	if _entry(id).is_empty():return
	current_id=id;_list();_detail()
func _entry(id:String) -> Dictionary:
	for entry in catalog:
		if entry.id==id:return entry
	return {}
func _detail() -> void:
	var entry:=_entry(current_id)
	if entry.is_empty():return
	item_title.text=entry.name;item_price.text="总价  %d 金币" % entry.price;item_art.texture=_icon(entry.id,_category(entry))
	details.text=entry.description
	for row in [upgrade_row,selected_row,component_row]:
		for child in row.get_children():
			row.remove_child(child);child.queue_free()
	for upgraded in catalog:
		if current_id in upgraded.get("component_ids",[]):_recipe_button(upgrade_row,upgraded,false)
	if upgrade_row.get_child_count()==0:_label(upgrade_row,"已是最终装备" if not entry.get("component_ids",[]).is_empty() else "无后续升级",11,MUTED)
	_recipe_button(selected_row,entry,true)
	for part in entry.get("component_ids",[]):
		var component:=_entry(part)
		if not component.is_empty():_recipe_button(component_row,component,true)
	if component_row.get_child_count()==0:_label(component_row,"直接购买",11,MUTED)
	recipe_note.text="组件可点击查看下级路线 · 绿色角标为已持有数量"
	recipe_connector.queue_redraw.call_deferred()
	var purchase_note:="药品按规则堆叠或占用装备槽" if entry.kind in ["normal","special"] else "购买后占用1个装备槽" if entry.get("component_ids",[]).is_empty() else "合成自动消耗可抵价组件，成装占用1槽"
	summary.text="组件抵扣 %d  ·  本次实付 %d 金币\n%s" % [entry.credit,entry.charge,entry.reason_text if not entry.buyable else purchase_note]
	purchase.text=("购买" if entry.get("component_ids",[]).is_empty() else "购买 / 合成")+"    %d 金币" % entry.charge
	purchase.disabled=not entry.buyable;purchase.tooltip_text=entry.reason_text
func _recipe_button(parent:Node,entry:Dictionary,with_price:bool) -> Button:
	var b:=Button.new();b.icon=_icon(entry.id,_category(entry));b.expand_icon=true
	b.custom_minimum_size=Vector2(76 if with_price else 42,36)
	b.add_theme_constant_override("icon_max_width",28)
	b.add_theme_font_size_override("font_size",11)
	b.text=(str(entry.price) if with_price else "")+(" ✓" if entry.get("owned",0)>0 else "")
	b.tooltip_text="%s · %d金币%s\n%s" % [entry.name,entry.price," · 已持有%d件" % entry.owned if entry.get("owned",0)>0 else "",entry.description]
	b.pressed.connect(func():inspect(entry.id));parent.add_child(b);return b
func _icon(id:String,_category_name:String) -> Texture2D:
	return preload("res://scripts/ui/item_icon_library.gd").texture(id)
