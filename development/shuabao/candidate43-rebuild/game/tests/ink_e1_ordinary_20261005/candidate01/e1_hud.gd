extends Control
## Read-only temporary E card; no art, sound or skill commands.
const Design = preload("res://data/final_design/catalog.gd")
const PATCH_NAME := "E1ReadOnlyTemporaryCard"
var projected: Dictionary = {}

static func model_from(source: Node) -> Dictionary:
 var learned: bool = source.hero.loadout.e == "e1" and int(source.hero.ranks.e) > 0
 var active: bool = source._e1_form_current()
 var rank: int = int(source.hero.ranks.e)
 var remaining: float = maxf(0.0,float(source.ink_rain.get("expires_at",source.hero_time))-source.hero_time) if active else 0.0
 var cooldown: float = float(source.hero.cooldowns.e)
 var detail: String = "E1 一蓑烟雨 · " + ("%d级" % rank if learned else "未学习")
 if learned: detail += "\n" + Design.description("yanguizhou","e1",rank).replace("规则已确认；该技能尚未实现。","基础E1机制已接入候选，形态美术/音频未完成")
 detail += "\n按住E入形，松开或到时聚形；圈外雨痕无追加伤害，聚形后全部清除。\n雨形期间禁止新普攻/Q/R；WASD仍受真实控制，Shift独立。\n本次基础E1无净化、无伤或免控；H07/H08均未开放。\n成功入形起CD一次为既有实现约定，原文未指定起点。\n形态剩余 %.3f 秒 · CD %.3f 秒 · 暂停冻结\n临时文字显示；形态美术/音频未完成，普通敌人类别穿行未验" % [remaining,cooldown]
 return {"candidate":"e1","learned":learned,"rank":rank,"active":active,"remaining":remaining,"cooldown":cooldown,"release_pending":bool(source.ink_rain.get("release_pending",false)),"label":"雨 %.1f" % remaining if active else ("%.1fs" % cooldown if learned and cooldown > source.TIME_EPS else ("就绪" if learned else "未学")),"tooltip":detail,"source_time":source.hero_time,"room_id":source.room_id,"generation":source.encounter_generation,"temporary_visual":true,"H07_H08_available":false}

static func apply_to(hud: Control, source: Node) -> Dictionary:
 var shown: Dictionary = model_from(source)
 var patch: Control = hud.get_node_or_null(NodePath(PATCH_NAME))
 if patch == null:
  patch = load("res://tests/ink_e1_ordinary_20261005/candidate01/e1_hud.gd").new()
  patch.name = PATCH_NAME; patch.position = Vector2(692,640); patch.size = Vector2(46,58)
  patch.mouse_filter = Control.MOUSE_FILTER_STOP; patch.focus_mode = Control.FOCUS_NONE
  hud.add_child(patch)
  if is_instance_valid(hud.shop_group): hud.move_child(patch,hud.shop_group.get_index())
 patch.projected = shown.duplicate(true); patch.tooltip_text = str(shown.tooltip); patch.queue_redraw()
 hud.source_model["selected_e"] = shown.duplicate(true)
 return shown

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("293C42"))
 var color := Color("DFE2D1") if bool(projected.get("learned",false)) else Color("8EAAA9")
 draw_string(get_theme_default_font(),Vector2(4,23),"E1",HORIZONTAL_ALIGNMENT_CENTER,38,15,color)
 draw_string(get_theme_default_font(),Vector2(2,43),str(projected.get("label","未学")),HORIZONTAL_ALIGNMENT_CENTER,42,10,color)
 draw_string(get_theme_default_font(),Vector2(2,55),"临时",HORIZONTAL_ALIGNMENT_CENTER,42,9,Color("8EAAA9"))

func _make_custom_tooltip(_text: String) -> Object:
 var panel := PanelContainer.new()
 var label := Label.new(); label.custom_minimum_size.x = 390
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size",13); label.text = tooltip_text
 panel.add_child(label); return panel
