extends "res://tests/ink_normal_floor_host_20261004/growth_hud.gd"
## Presentation-only derivative. The live host applies this same helper to its
## already-bound HUD; no Controller, Adapter, Button or connection is replaced.
const PANEL_SIZE := Vector2(420, 228)
const RIGHT_MARGIN := 22.0
const BOTTOM_CLEARANCE := 122.0

func _ready() -> void:
 super._ready()
 apply_layout(self)

static func apply_layout(view: Control) -> void:
 # A CanvasLayer child has the viewport as its anchor reference. Explicitly
 # reset all root offsets so the anchor reference cannot be a zero-size root.
 view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 view.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var panel: PanelContainer = view.growth_panel
 panel.name = "VisibleQGrowthPanel"
 panel.mouse_filter = Control.MOUSE_FILTER_STOP
 panel.clip_contents = false
 panel.custom_minimum_size = PANEL_SIZE
 var box := StyleBoxFlat.new()
 box.bg_color = Color("23333BF5")
 box.border_color = Color("829394")
 box.set_border_width_all(1)
 box.set_corner_radius_all(3)
 box.content_margin_left = 8; box.content_margin_right = 8
 box.content_margin_top = 8; box.content_margin_bottom = 8
 panel.add_theme_stylebox_override("panel", box)
 var body: VBoxContainer = panel.get_child(0)
 body.add_theme_constant_override("separation", 8)
 var columns: HBoxContainer = body.get_child(1)
 columns.add_theme_constant_override("separation", 8)
 view.growth_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 for candidate: String in view.q_choices:
  var row: Dictionary = view.q_choices[candidate]
  row.name.mouse_filter = Control.MOUSE_FILTER_IGNORE
  row.upgrade.mouse_filter = Control.MOUSE_FILTER_STOP
 view.undo_button.custom_minimum_size.y = 36
 view.respec_button.custom_minimum_size.y = 36
 view.undo_button.mouse_filter = Control.MOUSE_FILTER_STOP
 view.respec_button.mouse_filter = Control.MOUSE_FILTER_STOP
 # Control.position is parent-local, NOT an offset from its anchors. The
 # frozen ancestor assigns y=-252 and hides the panel. Set four offsets only.
 panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 panel.offset_left = -RIGHT_MARGIN - PANEL_SIZE.x
 panel.offset_right = -RIGHT_MARGIN
 panel.offset_top = -BOTTOM_CLEARANCE - PANEL_SIZE.y
 panel.offset_bottom = -BOTTOM_CLEARANCE

