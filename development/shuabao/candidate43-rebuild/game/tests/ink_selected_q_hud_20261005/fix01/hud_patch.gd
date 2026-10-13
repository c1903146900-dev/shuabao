extends Control
## Only projects the selected Q card after the frozen HUD.present call.
## Keep the exact frozen HUD script: ancestor hosts use an exact-script guard.
const Style = preload("res://tests/ink_style_specimen_20261004/style.gd")
const SelectedQModel = preload("res://tests/ink_selected_q_hud_20261005/projection.gd")
const MountainIcon = preload("res://tests/ink_selected_q_hud_20261005/icon.gd")
const Icons = preload("res://tests/ink_style_specimen_20261004/revision10_hud/icons.gd")
const PATCH_NAME := "SelectedQReadOnlyProjection"
const CARD_RECT := Rect2(532,640,152,58)
var projected: Dictionary = {}

static func apply_to(hud: Control, full: Dictionary, ink: Dictionary, context: Dictionary) -> Dictionary:
 if not is_instance_valid(hud) or not is_instance_valid(hud.q_label): return {}
 var patch: Control = hud.get_node_or_null(NodePath(PATCH_NAME))
 if patch == null:
  patch = load("res://tests/ink_selected_q_hud_20261005/fix01/hud_patch.gd").new()
  patch.name = PATCH_NAME; patch.position = CARD_RECT.position; patch.size = CARD_RECT.size
  patch.mouse_filter = Control.MOUSE_FILTER_STOP; patch.focus_mode = Control.FOCUS_NONE
  hud.add_child(patch)
  # Shop overlay remains above the patch. No expansion of the existing STOP bar.
  if is_instance_valid(hud.shop_group): hud.move_child(patch,hud.shop_group.get_index())
 var model: Dictionary = SelectedQModel.model_from(full,ink,context)
 patch.projected = model.duplicate(true); patch.tooltip_text = str(model.tooltip)
 hud.q_label.text = str(model.name); hud.q_rank_label.text = str(model.rank_text)
 hud.q_cooldown.text = str(model.cooldown_text)
 hud.q_rank_label.modulate = Style.ACCENT if model.learned else Style.QUIET
 hud.q_plus_backplate.tooltip_text = "请使用学习面板；底栏仅显示已选Q技能的真实状态"
 hud.source_model["q_rank"] = model.rank_text; hud.source_model["q_learned"] = model.learned
 hud.source_model["q_cooldown"] = model.cooldown_text; hud.source_model["selected_q"] = model.duplicate(true)
 patch.queue_redraw()
 return model

func _draw() -> void:
 # Erase only the inherited Q1 icon. Other cards, labels, geometry and plus stay.
 draw_rect(Rect2(6,6,34,42),Color("22363D"))
 if projected.get("icon","") == "q1": Icons.draw_icon(self,"q1",Vector2(7,10),32.0)
 elif projected.get("icon","") == "q3": MountainIcon.draw_icon(self,Vector2(7,8),32.0)
 else:
  draw_polyline(PackedVector2Array([Vector2(23,11),Vector2(36,25),Vector2(23,39),Vector2(10,25),Vector2(23,11)]),Icons.TEAL,1.0,true)
  draw_string(get_theme_default_font(),Vector2(18,31),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Icons.IVORY)
 if not bool(projected.get("learned",false)): draw_rect(Rect2(6,6,34,42),Color(0.08,0.14,0.16,0.50))
 if bool(projected.get("q3_live",false)):
  var color: Color = Icons.TEAL if bool(projected.get("recast_ready",false)) else Color("84938D")
  draw_rect(Rect2(6,6,34,42),color,false,1.0)
  draw_rect(Rect2(7,35,32,12),Color("182B32"))
  draw_string(get_theme_default_font(),Vector2(7,45),"倒山",HORIZONTAL_ALIGNMENT_CENTER,32,10,color)

func _make_custom_tooltip(_text: String) -> Object:
 var panel := PanelContainer.new()
 var label := Label.new(); label.custom_minimum_size.x = 390
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size",13); label.text = tooltip_text
 panel.add_child(label)
 return panel
