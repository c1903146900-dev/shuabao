extends Label
## Long informational tooltips stay wrapped inside the combat viewport.
func _make_custom_tooltip(for_text:String) -> Object:
	var panel:=PanelContainer.new()
	var style:=StyleBoxFlat.new();style.bg_color=Color("0c1820");style.border_color=Color("6f827d");style.set_border_width_all(1)
	style.content_margin_left=13;style.content_margin_right=13;style.content_margin_top=10;style.content_margin_bottom=10
	panel.add_theme_stylebox_override("panel",style)
	var contents:=Label.new();contents.custom_minimum_size.x=420
	contents.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	contents.add_theme_font_size_override("font_size",13)
	contents.text=preload("res://scripts/ui/content_text.gd").skill_description(for_text)
	panel.add_child(contents);return panel
