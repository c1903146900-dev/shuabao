extends RefCounted
## Shared specimen palette. Original broad value bands, no per-pixel shader noise.
const FONT_PATH := "res://assets/ui/NotoSansCJKsc-Regular.otf"
const SURFACE := Color("23333B")
const EDGE := Color("829394")
const TEXT := Color("EDF0E5")
const QUIET := Color("AABBB6")
const ACCENT := Color("82B8AF")
const DANGER := Color("CB8360")
const MAPS := {
	"stone": "res://tests/ink_style_specimen_20261004/textures/stone.png",
	"carapace": "res://tests/ink_style_specimen_20261004/textures/carapace.png",
	"bone": "res://tests/ink_style_specimen_20261004/textures/bone.png",
	"bronze": "res://tests/ink_style_specimen_20261004/textures/bronze.png"
}
static func matte(tint: Color, map_key: String = "") -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat.emission_enabled = false
	if MAPS.has(map_key):
		mat.albedo_texture = load(MAPS[map_key])
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat
static func ui_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = load(FONT_PATH)
	theme.default_font_size = 18
	for type_name in ["Label", "Button"]:
		theme.set_color("font_color", type_name, TEXT)
		theme.set_color("font_hover_color", type_name, TEXT)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color("31494D") if state in ["hover", "pressed"] else SURFACE
		panel.border_color = ACCENT if state == "focus" else EDGE
		panel.set_border_width_all(1)
		panel.set_corner_radius_all(3)
		panel.content_margin_left = 12
		panel.content_margin_right = 12
		theme.set_stylebox(state, "Button", panel)
	return theme
static func chamfer(rect: Rect2, cut: float = 5.0) -> PackedVector2Array:
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([p + Vector2(cut,0),Vector2(e.x-cut,p.y),Vector2(e.x,p.y+cut),Vector2(e.x,e.y-cut),e-Vector2(cut,0),Vector2(p.x+cut,e.y),Vector2(p.x,e.y-cut),p+Vector2(0,cut)])
