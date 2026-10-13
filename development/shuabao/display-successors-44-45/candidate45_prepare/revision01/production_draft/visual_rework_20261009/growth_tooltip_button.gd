extends Button
## Presentation-only successor of an existing, signal-connected native Button.
## Keep all tooltip text. The original popup mechanism owns placement/lifetime.
func _make_custom_tooltip(for_text: String) -> Object:
 var panel := PanelContainer.new()
 var label := Label.new()
 var available: float = maxf(1.0, get_viewport().get_visible_rect().size.x - 48.0)
 label.custom_minimum_size.x = minf(430.0, available)
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size", 13)
 label.text = for_text
 panel.add_child(label)
 return panel
