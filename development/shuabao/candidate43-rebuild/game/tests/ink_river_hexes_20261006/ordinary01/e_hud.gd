extends Control
## Read-only E1/E2/E3 card. Actual source identity, position and clocks are retained.
const Binding = preload("res://tests/ink_river_hexes_20261006/ordinary01/live_binding.gd")
const Design = preload("res://data/final_design/catalog.gd")
const PriorE1Card = preload("res://tests/ink_e1_ordinary_20261005/candidate01/e1_hud.gd")
const PATCH_NAME := "E3OrdinaryReadOnlyTemporaryCard"
const SCRIPT_PATH := "res://tests/ink_river_hexes_20261006/ordinary01/e_hud.gd"
const CARD_RECT := Rect2(692,640,46,58)
var projected: Dictionary = {}

static func model_from(source: Node) -> Dictionary:
 if not is_instance_valid(source) or source.get_script().resource_path != Binding.SIM_PATH:
  return {"accepted":false,"reason":"exact_e3_ordinary_sim_required"}
 if source.hero.loadout.e == "e3": return _e3_model_from(source)
 if source.hero.loadout.e != "e2":
  var e1: Dictionary = PriorE1Card.model_from(source)
  e1["accepted"] = true
  return e1
 var rank: int = int(source.hero.ranks.e)
 var learned: bool = rank > 0
 var boat: Dictionary = source.ink_boat
 var active: bool = source._e2_live(boat)
 var remaining: float = maxf(0.0,float(boat.get("voyage_until",source.hero_time))-source.hero_time) if active else 0.0
 var parked: bool = active and bool(boat.get("boundary_parked",false))
 var landing_legal: bool = active and source._e2_landing_legal(boat.position)
 var boarding_window: bool = active and boat.phase == "outward" and source.hero_time < float(boat.voyage_until)-source.TIME_EPS
 var cooldown: float = float(source.hero.cooldowns.e)
 var status: String = "当前位置可登舟" if landing_legal else "当前位置站不下：无法登舟，保留原船"
 if not boarding_window: status = "登舟窗口已关闭" if active else "E朝鼠标发舟"
 var detail: String = "E2 孤帆远影 · " + ("%d级" % rank if learned else "未学习")
 detail += "\n" + Design.description("yanguizhou","e2",rank if learned else 1).replace("规则已确认；该技能尚未实现。","基础E2已接入；美术与音效未完成。")
 detail += "\nE朝鼠标发舟；松开后再按E登到小舟当前位置，无需左键确认。从菜单返回或继续游戏后，先松开E，再按E。"
 detail += "\n1.1米宽的船头第一次碰到房间边界就原地停留，不沿边滑行，仍按原时间消散；小舟可穿墙，冷却不变；暂停时计时冻结。"
 detail += "\n落点在墙内或站不下时，拒绝登舟并保留原船，人物不会被移到别处；剩余时间和冷却不变。未登舟时，到期在小舟停留处消散。"
 detail += "\n%s · %s\n航程剩余 %.3f 秒 · 冷却 %.3f 秒\nH09/H10均未开放。临时功能显示；最终美术与音效未完成。" % ["触边停留" if parked else ("航行中" if active else "无船"),status,remaining,cooldown]
 return {"accepted":true,"candidate":"e2","learned":learned,"rank":rank,"active":active,"remaining":remaining,"cooldown":cooldown,"boundary_parked":parked,"landing_legal":landing_legal,"boarding_window":boarding_window,"status":status,"boat_id":str(boat.get("boat_id","")) if active else "","position":boat.get("position",Vector3.ZERO) if active else Vector3.ZERO,"voyage_until":float(boat.get("voyage_until",-1.0)) if active else -1.0,"label":("停%.1f" if parked else "舟%.1f") % remaining if active else ("%.1fs" % cooldown if learned and cooldown > source.TIME_EPS else ("就绪" if learned else "未学")),"tooltip":detail,"source_time":source.hero_time,"generation":source.encounter_generation,"room_id":source.room_id,"temporary_visual":true,"H09_H10_available":false}

static func _e3_model_from(source: Node) -> Dictionary:
 var rank: int = int(source.hero.ranks.e)
 var learned: bool = rank > 0
 var frames: Dictionary = source.ink_frames
 var active: bool = source._e3_live(frames)
 var waiting: bool = active and str(frames.phase) == "first"
 var remaining: float = maxf(0.0,float(frames.get("expires_at",source.hero_time))-source.hero_time) if waiting else 0.0
 var cooldown: float = float(source.hero.cooldowns.e)
 var status: String = "松开E后，在原5秒窗口内再按E放B" if waiting else ("交换结算中" if active else "E在鼠标落点放A")
 var detail: String = "E3 咫尺千里 · " + ("%d级" % rank if learned else "未学习")
 detail += "\n" + Design.description("yanguizhou","e3",rank if learned else 1).replace("规则已确认；该技能尚未实现。","基础E3已接入；美术与音效尚未完成。")
 detail += "\nE在10米内鼠标位置放圆A；松开E后，5秒内再次E放同尺寸圆B，无需左键确认。正在Q/R预瞄或按住左键时，先完成或取消原输入。"
 detail += "\n普通与精英敌人交换，Boss、自身与队友不交换；单侧为空时，将另一侧合格敌人整体移过去。只有实际被移动的敌人受普通伤害：实际移动距离2米以内最高，之后线性降低，到最大交换距离最低；同中心未移动不伤害。"
 detail += "\n允许隔墙交换；任一实际参与者的必需落点在墙内、房界外或对该对象不可通行时，整次拒绝。拒绝后保留原A与剩余窗口，不另起冷却；可松开E后换合法点重试，不延长窗口。"
 detail += "\nA放置不开始冷却；原5秒到期先移除A再起冷却，或合法完成B时起冷却。Esc/右键/失焦不删除已放A，暂停冻结计时；从菜单返回后须先松开E。"
 detail += "\n%s\n放B窗口 %.3f 秒 · 冷却 %.3f 秒\nH11/H12均未开放。临时A/B圆与文字显示；最终美术与音效未完成。" % [status,remaining,cooldown]
 return {"accepted":true,"candidate":"e3","learned":learned,"rank":rank,"active":active,"phase":str(frames.get("phase","none")),"remaining":remaining,"cooldown":cooldown,"status":status,"frame_id":str(frames.get("frame_id","")) if active else "","a":frames.get("a",Vector3.INF) if active else Vector3.INF,"radius":float(frames.get("radius",0.0)) if active else 0.0,"expires_at":float(frames.get("expires_at",-1.0)) if active else -1.0,"label":"A %.1f" % remaining if waiting else ("结算" if active else ("%.1fs" % cooldown if learned and cooldown > source.TIME_EPS else ("就绪" if learned else "未学"))),"tooltip":detail,"source_time":source.hero_time,"generation":source.encounter_generation,"room_id":source.room_id,"temporary_visual":true,"H11_H12_available":false}

static func apply_to(hud: Control, source: Node) -> Dictionary:
 var shown: Dictionary = model_from(source)
 var patch: Control = hud.get_node_or_null(NodePath(PATCH_NAME))
 if not shown.get("accepted",false):
  if patch != null: patch.hide()
  return shown
 # This exact successor replaces the E-slot view only. The E1 source, router
 # and release ownership are unchanged; no script identity is substituted.
 var e2_patch: Control = hud.get_node_or_null(NodePath("E2OrdinaryReadOnlyTemporaryCard"))
 if e2_patch != null: e2_patch.hide()
 var e1_patch: Control = hud.get_node_or_null(NodePath(PriorE1Card.PATCH_NAME))
 if e1_patch != null: e1_patch.hide()
 if patch == null:
  var card_script: Script = load(SCRIPT_PATH)
  patch = card_script.new()
  patch.name = PATCH_NAME; patch.position = CARD_RECT.position; patch.size = CARD_RECT.size
  patch.mouse_filter = Control.MOUSE_FILTER_STOP; patch.focus_mode = Control.FOCUS_NONE
  hud.add_child(patch)
  if is_instance_valid(hud.shop_group): hud.move_child(patch,hud.shop_group.get_index())
 patch.show(); patch.projected = shown.duplicate(true)
 patch.tooltip_text = str(shown.tooltip); patch.queue_redraw()
 hud.source_model["selected_e"] = shown.duplicate(true)
 return shown

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("293C42"))
 var color := Color("DFE2D1") if bool(projected.get("learned",false)) else Color("8EAAA9")
 draw_string(get_theme_default_font(),Vector2(4,23),str(projected.get("candidate","e")).to_upper(),HORIZONTAL_ALIGNMENT_CENTER,38,15,color)
 draw_string(get_theme_default_font(),Vector2(2,43),str(projected.get("label","未学")),HORIZONTAL_ALIGNMENT_CENTER,42,10,color)
 draw_string(get_theme_default_font(),Vector2(2,55),"临时",HORIZONTAL_ALIGNMENT_CENTER,42,9,Color("8EAAA9"))

func _make_custom_tooltip(_text: String) -> Object:
 var panel := PanelContainer.new(); var label := Label.new()
 label.custom_minimum_size.x = 430; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size",13); label.text = tooltip_text
 panel.add_child(label); return panel
