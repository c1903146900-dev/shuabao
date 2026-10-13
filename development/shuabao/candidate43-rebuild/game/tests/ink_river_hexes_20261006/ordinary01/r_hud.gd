extends Control
## Read-only original R slot. No command dispatch or fabricated cooldown/rank.
const R2OrdinaryBinding = preload("res://tests/ink_river_hexes_20261006/ordinary01/live_binding.gd")
const R2OrdinaryRuntimeText = preload("res://tests/ink_river_hexes_20261006/ordinary01/runtime_text.gd")
const Design = preload("res://data/final_design/catalog.gd")
const PATCH_NAME := "R1ReadOnlyTemporaryCard"
const CARD_RECT := Rect2(746,640,46,58)
var projected: Dictionary = {}
static func model_from(source: Node) -> Dictionary:
 if not is_instance_valid(source) or source.get_script().resource_path != R2OrdinaryBinding.SIM_PATH: return {"accepted":false,"reason":"exact_composed_sim_required"}
 var rank: int = int(source.hero.ranks.r)
 var candidate: String = str(source.hero.loadout.r)
 var learned: bool = candidate in ["r1","r2"] and rank > 0
 var level: int = int(source.progression.snapshot().get("level",1))
 var domain: Dictionary = source.ink_peaks if candidate == "r2" else source.ink_snow
 var current: bool = source._r2_current(domain) if candidate == "r2" else source._r1_current(domain)
 var active: bool = current and source.hero_time < float(domain.expires_at)
 var remaining: float = maxf(0.0,float(domain.get("expires_at",source.hero_time))-source.hero_time) if active else 0.0
 var cooldown: float = float(source.hero.cooldowns.r)
 var label: String = "域%.1f" % remaining if active else ("%.1fs" % cooldown if learned and cooldown > source.TIME_EPS else ("就绪" if learned else ("Lv6" if level < 6 else "未学")))
 var detail: String = "R1 独钓寒江雪 · " + ("%d级" % rank if learned else "未学习")
 detail += "\n" + Design.description("yanguizhou","r1",rank if learned else 1)
 detail += "\nR预瞄→新左键确认；右键/Esc取消预瞄。固定圆心，不随英雄移动；普通/精英/Boss分别降低移动与攻击速度，英雄行动正常。\n受控或烟雨时不能新施放；已生成领域保持。无伤害、无冻结、无治疗、无无敌；H13/H14未开放。\n首次英雄6级学习1SP，之后每阶2SP，无额外等级门。\n领域剩余%.3f秒 · CD %.3f秒；暂停冻结，换房不免费重置CD。\n临时功能圈；雪景美术与音频未完成" % [remaining,cooldown]
 if candidate == "r2": detail = R2OrdinaryRuntimeText.RuntimeCatalog.r2_description(rank if learned else 1)+"\n领域剩余%.3f秒 · CD %.3f秒" % [remaining,cooldown]
 detail = R2OrdinaryRuntimeText.correct(candidate,detail)
 return {"accepted":true,"candidate":candidate,"learned":learned,"rank":rank,"level":level,"active":active,"remaining":remaining,"cooldown":cooldown,"label":label,"tooltip":detail,"source_time":source.hero_time,"generation":source.encounter_generation,"room_id":source.room_id,"temporary_visual":true,"H13_H14_available":false,"H15_H16_available":false,"presentation_active":not source._current_show.is_empty() and source.clock.domain.is_invulnerable(source._current_show.token)}

static func apply_to(hud: Control, source: Node) -> Dictionary:
 var shown: Dictionary = model_from(source)
 if not shown.get("accepted",false): return shown
 var patch: Control = hud.get_node_or_null(NodePath(PATCH_NAME))
 if patch == null:
  patch = load("res://tests/ink_river_hexes_20261006/ordinary01/r_hud.gd").new()
  patch.name = PATCH_NAME; patch.position = CARD_RECT.position; patch.size = CARD_RECT.size
  patch.mouse_filter = Control.MOUSE_FILTER_STOP; patch.focus_mode = Control.FOCUS_NONE
  hud.add_child(patch)
  if is_instance_valid(hud.shop_group): hud.move_child(patch,hud.shop_group.get_index())
 patch.projected = shown.duplicate(true); patch.tooltip_text = str(shown.tooltip); patch.queue_redraw()
 hud.source_model["selected_r"] = shown.duplicate(true)
 return shown

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("293C42"))
 var color := Color("DFE2D1") if bool(projected.get("learned",false)) else Color("8EAAA9")
 draw_string(get_theme_default_font(),Vector2(4,23),str(projected.get("candidate","r")).to_upper(),HORIZONTAL_ALIGNMENT_CENTER,38,15,color)
 draw_string(get_theme_default_font(),Vector2(2,43),str(projected.get("label","Lv6")),HORIZONTAL_ALIGNMENT_CENTER,42,10,color)
 draw_string(get_theme_default_font(),Vector2(2,55),"临时",HORIZONTAL_ALIGNMENT_CENTER,42,9,Color("8EAAA9"))

func _make_custom_tooltip(_text: String) -> Object:
 var panel := PanelContainer.new()
 var label := Label.new(); label.custom_minimum_size.x = 390
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size",13); label.text = tooltip_text
 panel.add_child(label); return panel
