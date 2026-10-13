extends Control
## Read-only overlay on the original passive slot; no active command or CD.
const Design = preload("res://data/final_design/catalog.gd")
const Binding = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/live_binding.gd")
const PATCH_NAME := "P1ReadOnlyTemporaryCard"
const CARD_RECT := Rect2(478,640,46,58)
var projected: Dictionary = {}
static func model_from(source: Node) -> Dictionary:
 if not is_instance_valid(source) or source.get_script().resource_path != Binding.SIM_PATH: return {"accepted":false,"reason":"exact_p1_ordinary_sim_required"}
 var rank: int = int(source.hero.ranks.passive)
 var learned: bool = source.hero.loadout.passive == "p1" and rank > 0
 var detail: String = "P1 计白当黑 · "+("%d阶" % rank if learned else "未学习")
 detail += "\n"+Design.description("yanguizhou","p1",rank if learned else 1)
 detail += "\n被动，无主动施放与独立冷却。各段正常伤害先结算；整次Q/E结束后只命中过一敌才一次补增伤、返当时剩余冷却，不提前击杀。每条完整Q2河独立计算；R1/BASIC不计入。"
 detail += "\n补算只对实际损失生命的伤害按原Q/E面积系数参与已有吸血；不再触发一次命中、暴击或减伤。每阶1SP，上限4阶。P2/P3与未接强化未开放；临时文字卡，无美术/音频验收。"
 return {"accepted":true,"candidate":"p1","rank":rank,"learned":learned,"label":"%d/4" % rank if learned else "未学","tooltip":detail,"passive_only":true,"has_active_input":false,"source_time":source.hero_time,"generation":source.encounter_generation,"room_id":source.room_id,"temporary_visual":true}
static func apply_to(hud: Control, source: Node) -> Dictionary:
 var shown: Dictionary = model_from(source)
 var patch: Control = hud.get_node_or_null(NodePath(PATCH_NAME))
 if not shown.accepted:
  if patch != null: patch.hide()
  return shown
 if patch == null:
  patch = load("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/p_hud.gd").new()
  patch.name = PATCH_NAME; patch.position = CARD_RECT.position; patch.size = CARD_RECT.size
  patch.mouse_filter = Control.MOUSE_FILTER_STOP; patch.focus_mode = Control.FOCUS_NONE
  hud.add_child(patch)
  if is_instance_valid(hud.shop_group): hud.move_child(patch,hud.shop_group.get_index())
 patch.show(); patch.projected = shown.duplicate(true); patch.tooltip_text = str(shown.tooltip); patch.queue_redraw()
 hud.source_model["selected_p"] = shown.duplicate(true)
 return shown
func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("293C42"))
 var color := Color("DFE2D1") if bool(projected.get("learned",false)) else Color("8EAAA9")
 draw_string(get_theme_default_font(),Vector2(4,23),"P1",HORIZONTAL_ALIGNMENT_CENTER,38,15,color)
 draw_string(get_theme_default_font(),Vector2(2,43),str(projected.get("label","未学")),HORIZONTAL_ALIGNMENT_CENTER,42,10,color)
 draw_string(get_theme_default_font(),Vector2(2,55),"被动",HORIZONTAL_ALIGNMENT_CENTER,42,9,Color("8EAAA9"))
func _make_custom_tooltip(_text: String) -> Object:
 var panel := PanelContainer.new(); var label := Label.new(); label.custom_minimum_size.x = 390
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.add_theme_font_size_override("font_size",13); label.text = tooltip_text
 panel.add_child(label); return panel
