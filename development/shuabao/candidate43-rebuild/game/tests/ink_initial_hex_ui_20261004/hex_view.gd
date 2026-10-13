extends "res://scripts/ui/hex_draft_view.gd"
## Existing four independent real UI signals, only shared-theme presentation.
const Style = preload("res://tests/ink_style_specimen_20261004/style.gd")
func _ready() -> void:
 super._ready()
 theme = Style.ui_theme()
 add_theme_stylebox_override("panel", _shared_panel(Style.SURFACE, Style.EDGE, 14))
 for row in cards:
  row.panel.custom_minimum_size = Vector2(242, 404)
  row.panel.add_theme_stylebox_override("panel", _shared_panel(Style.SURFACE, Style.EDGE, 12))
  row.name.custom_minimum_size.x = 214
  row.description.custom_minimum_size = Vector2(214, 162)
  for button in [row.select, row.refresh]:
   for state in ["normal", "hover", "pressed", "focus", "disabled"]: button.remove_theme_stylebox_override(state)
   button.remove_theme_color_override("font_color")
  row.name.add_theme_color_override("font_color", Style.TEXT)
  row.description.add_theme_color_override("font_color", Style.TEXT)
  row.dependency.add_theme_color_override("font_color", Style.ACCENT)
 footer.text = "每格可独立刷新一次 · 选择不会增加技能点"
func present(view: Dictionary) -> void:
 super.present(view)
 if error_text.is_empty(): footer.text = "每格可独立刷新一次 · 右格为个人强化 · 选择不会增加技能点"
func _shared_panel(fill: Color, edge: Color, padding: int) -> StyleBoxFlat:
 var box := StyleBoxFlat.new()
 box.bg_color = fill; box.border_color = edge
 box.set_border_width_all(1); box.set_corner_radius_all(3)
 box.content_margin_left = padding; box.content_margin_right = padding
 box.content_margin_top = padding; box.content_margin_bottom = padding
 return box
