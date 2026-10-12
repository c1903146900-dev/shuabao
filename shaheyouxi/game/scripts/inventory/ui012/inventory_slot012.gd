extends Button
## Technical text slot. No generated or substitute final item art.
func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 132)
	var margin := MarginContainer.new()
	for edge in ["left", "right"]: margin.add_theme_constant_override("margin_" + edge, 18)
	for edge in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(margin)
	var label := Label.new()
	label.custom_minimum_size.x = 244
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = for_text
	margin.add_child(label)
	return panel
