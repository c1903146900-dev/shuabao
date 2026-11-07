extends "res://tests/ink_initial_hex_ui_20261004/hex_hud.gd"
const R2Projection=preload("res://fengli_route_20261024/r2_projection.gd")
const E2Projection = preload("res://fengli_route_20261024/e2_projection.gd")
const OverloadProjection = preload("res://fengli_route_20261024/overload_projection.gd")
const LearningProjection = preload("res://scripts/ui/skill_learning_projection.gd")
## Fengli-only read-only projection. All choices use the existing HUD adapter.
class SkillTile extends Button:
 var slot:String="Q"
 var learned:bool=false
 var action_visible:bool=false
 var remaining:float=0.0
 var cooldown_known:bool=false
 var passive_cooldown:bool=false
 var r2_mode:bool=false
 var r2_heading:String=""
 var r2_time:String=""
 var e2_mode:bool=false
 var e2_heading:String=""
 var e2_time:String=""
 var overload_mode:bool=false
 var overload_heading:String=""
 var overload_time:String=""
 var charge_mode:bool=false
 var charge_count:String=""
 var charge_recovery:String=""
 func _draw()->void:
  # The upper 44 px is the existing glyph/state surface. The name/rank Label
  # lives inside the same detail button below it, not in another layout row.
  # A separately hit-tested 32 px action button owns the top-right corner.
  var display_width:float=size.x-(38.0 if action_visible else 0.0)
  var c:=Vector2(display_width*.5,23)
  var color:=Color("42e4d1") if learned else Color("8897b5")
  # Wind-only symbols; geometry is a UI glyph, never an attack range preview.
  if slot=="P":
   draw_polyline(PackedVector2Array([c+Vector2(-17,14),c+Vector2(6,-16),c+Vector2(10,-19),c+Vector2(9,-12),c+Vector2(-13,17)]),color,2,true)
   draw_line(c+Vector2(-18,6),c+Vector2(-7,14),color,2,true)
   draw_colored_polygon(PackedVector2Array([c+Vector2(17,2),c+Vector2(11,12),c+Vector2(12,17),c+Vector2(17,20),c+Vector2(22,17),c+Vector2(23,12)]),color)
  elif slot=="Q":
   draw_polyline(PackedVector2Array([c+Vector2(-24,-3),c+Vector2(14,-3),c+Vector2(25,0),c+Vector2(14,3),c+Vector2(-24,3)]),color,2,true)
   draw_line(c+Vector2(-14,-10),c+Vector2(-14,10),color,2,true)
   draw_line(c+Vector2(17,-12),c+Vector2(25,-8),color,2,true)
   draw_line(c+Vector2(17,12),c+Vector2(25,8),color,2,true)
  elif slot=="E":
   draw_polyline(PackedVector2Array([c+Vector2(-13,13),c+Vector2(5,-11),c+Vector2(14,-17),c+Vector2(10,-5),c+Vector2(-9,16)]),color,2,true)
   draw_line(c+Vector2(-17,4),c+Vector2(-4,14),color,2,true)
   for sign_x:float in [-1.0,1.0]:
    for sign_y:float in [-1.0,1.0]:
     var corner:=c+Vector2(sign_x*23,sign_y*19)
     draw_line(corner,corner-Vector2(sign_x*6,0),color,1.5,true)
     draw_line(corner,corner-Vector2(0,sign_y*6),color,1.5,true)
  else:
   for index:int in range(3):
    var direction:=Vector2.RIGHT.rotated(float(index)*TAU/3.0-PI*.5)
    var side:=direction.orthogonal()
    draw_colored_polygon(PackedVector2Array([c+direction*23,c+direction*5+side*4,c-direction*10-side*2]),color)
   draw_circle(c,2.5,Color("141a30"))
  if r2_mode:
   draw_rect(Rect2(4,2,display_width-8,42),Color(.04,.06,.12,.9))
   draw_string(get_theme_default_font(),Vector2(0,21),r2_heading,HORIZONTAL_ALIGNMENT_CENTER,display_width,12,Color("f4e99a"))
   draw_string(get_theme_default_font(),Vector2(0,39),r2_time,HORIZONTAL_ALIGNMENT_CENTER,display_width,11,Color.WHITE)
  elif e2_mode:
   draw_rect(Rect2(4,2,display_width-8,42),Color(.04,.06,.12,.9))
   draw_string(get_theme_default_font(),Vector2(0,21),e2_heading,HORIZONTAL_ALIGNMENT_CENTER,display_width,14,Color("42e4d1"))
   draw_string(get_theme_default_font(),Vector2(0,39),e2_time,HORIZONTAL_ALIGNMENT_CENTER,display_width,15,Color.WHITE)
  elif overload_mode:
   draw_rect(Rect2(4,2,display_width-8,42),Color(.04,.06,.12,.9))
   draw_string(get_theme_default_font(),Vector2(0,21),overload_heading,HORIZONTAL_ALIGNMENT_CENTER,display_width,14,Color("ffd37c"))
   draw_string(get_theme_default_font(),Vector2(0,39),overload_time,HORIZONTAL_ALIGNMENT_CENTER,display_width,15,Color.WHITE)
  elif charge_mode:
   # Q3 charges are not the shared cooldown: one shot may be ready while another recovers.
   draw_rect(Rect2(4,2,display_width-8,42),Color(.04,.06,.12,.8))
   draw_string(get_theme_default_font(),Vector2(0,21),charge_count,HORIZONTAL_ALIGNMENT_CENTER,display_width,16,Color.WHITE)
   draw_string(get_theme_default_font(),Vector2(0,39),charge_recovery,HORIZONTAL_ALIGNMENT_CENTER,display_width,12,Color("42e4d1"))
  elif (slot!="P" or passive_cooldown) and not cooldown_known:
   draw_string(get_theme_default_font(),Vector2(0,33),"?",HORIZONTAL_ALIGNMENT_CENTER,display_width,19,Color("8897b5"))
  elif remaining>.05:
   draw_rect(Rect2(4,2,display_width-8,42),Color(.04,.06,.12,.8))
   draw_string(get_theme_default_font(),Vector2(0,33),"%.1f"%remaining,HORIZONTAL_ALIGNMENT_CENTER,display_width,19,Color.WHITE)

signal training_requested
var bottom_bar: PanelContainer
var bottom_status: Label
var bottom_popup: PanelContainer
var bottom_actions: Dictionary = {}
var bottom_slots: Dictionary = {}
var bottom_candidate_buttons: Dictionary = {}
var bottom_open_slot: String = ""
var _state: Dictionary = {}
var _definitions: Dictionary = {}
var _definitions_source: Dictionary = {}
var _definitions_version: String = ""
var _cards_key: String = ""
var _cards: HBoxContainer
var bottom_labels:Dictionary={}
var bottom_health:ProgressBar
var bottom_dash:Label
var bottom_undo:Button
var bottom_respec:Button
var _cooldowns:Dictionary={}
var _hp:float=0.0
var _max_hp:float=1.0
var _q3_charges:Dictionary={}
var _overload:Dictionary={}
var _e2:Dictionary={}
var _r2:Dictionary={}
# Logical canvas units: no camera, world projection or physical-window scaling.
const COMPACT_BAR_HEIGHT:float=110.0
const COMPACT_BAR_WIDTH:float=760.0
const COMPACT_BAR_MARGIN:float=16.0
const POTION_DOCK_GAP:float=8.0
var _potion_dock_width:float=0.0
func _panel()->StyleBoxFlat:
 var style:=StyleBoxFlat.new();style.bg_color=Color("141a30");style.border_color=Color("426678");style.set_border_width_all(1);style.set_content_margin_all(8);style.set_corner_radius_all(6);return style
func _style_button(button:Button)->void:
 for state in ["normal","hover","pressed","disabled","focus"]:
  var box:=_panel();box.content_margin_top=2;box.content_margin_bottom=2;box.content_margin_left=6;box.content_margin_right=6;box.bg_color=Color("203247") if state in ["hover","pressed"] else Color("18223a")
  box.border_color=Color("42e4d1") if state in ["hover","focus"] else Color("426678")
  if state=="disabled":box.border_color=Color("303d54")
  button.add_theme_stylebox_override(state,box)
 button.add_theme_color_override("font_color",Color("e2f5f4"));button.add_theme_color_override("font_disabled_color",Color("6e7c92"));button.add_theme_font_size_override("font_size",13)
func present_source_vitals(hp:float,maximum:float,cooldowns:Dictionary)->void:
 if not is_finite(hp) or not is_finite(maximum) or maximum<=0:return
 _hp=hp;_max_hp=maximum;_cooldowns=cooldowns.duplicate()
 if bottom_health!=null:
  bottom_health.max_value=maximum;bottom_health.value=clampf(hp,0,maximum)
 for slot in bottom_slots:
  var projected:Dictionary=slot_cooldown_projection(str(slot),_state.get("skills",{}),_cooldowns)
  bottom_slots[slot].passive_cooldown=bool(projected.passive_cooldown)
  bottom_slots[slot].cooldown_known=bool(projected.known)
  bottom_slots[slot].remaining=float(projected.remaining)
  bottom_slots[slot].queue_redraw()
 var dash_value:Variant=_cooldowns.get("shift")
 var dash_known:bool=(dash_value is float or dash_value is int) and is_finite(float(dash_value)) and float(dash_value)>=0.0
 bottom_dash.text=("Shift\n%.1f"%float(dash_value) if float(dash_value)>.05 else "Shift\n就绪") if dash_known else "Shift\n未知"
 _status()
# P2 has a source-owned passive timer; P1 does not display an invented P cooldown.
static func slot_cooldown_projection(slot:String,skills:Dictionary,cooldowns:Dictionary)->Dictionary:
 var skill:Dictionary=skills.get(slot,{})
 var passive:bool=slot=="P" and str(skill.get("candidate","")).to_upper()=="P2" and int(skill.get("rank",0))>0
 if slot=="P" and not passive:return {"known":true,"remaining":0.0,"passive_cooldown":false}
 var value:Variant=cooldowns.get("passive" if passive else slot.to_lower())
 var known:bool=(value is float or value is int) and is_finite(float(value)) and float(value)>=0.0
 return {"known":known,"remaining":float(value) if known else 0.0,"passive_cooldown":passive}

# Pure formatting boundary: no source timers, actions, cooldown synchronisation or mutation.
static func q3_charge_projection(charges:Dictionary)->Dictionary:
 var unknown:Dictionary={"known":false,"count":"充能未知","recovery":"等待源状态","tooltip":"长距剑气充能状态未知"}
 var available:Variant=charges.get("available")
 var capacity:Variant=charges.get("capacity")
 var recoveries:Variant=charges.get("recoveries")
 var next:Variant=charges.get("next_recovery")
 if not (available is int or available is float) or not (capacity is int or capacity is float):return unknown
 if not is_finite(float(available)) or not is_finite(float(capacity)) or float(available)!=floor(float(available)) or float(capacity)!=floor(float(capacity)):return unknown
 if int(capacity) not in [1,2] or int(available)<0 or int(available)>int(capacity):return unknown
 if not recoveries is Array or recoveries.size()>2 or not (next is int or next is float) or not is_finite(float(next)) or float(next)<0:return unknown
 for left:Variant in recoveries:
  if not (left is int or left is float) or not is_finite(float(left)) or float(left)<0:return unknown
 if int(available)!=maxi(0,int(capacity)-recoveries.size()):return unknown
 var expected_next:float=0.0 if recoveries.is_empty() else float(recoveries.min())
 if not is_equal_approx(float(next),expected_next):return unknown
 var recovery:String="全部就绪" if recoveries.is_empty() else "下次 %.1f秒"%float(next)
 var times:Array=[]
 for left:Variant in recoveries:times.append("%.1f秒"%float(left))
 var tooltip:String="长距剑气 · 可用 %d / %d"%[int(available),int(capacity)]
 if not times.is_empty():tooltip+="\n各次独立恢复："+" / ".join(times)
 return {"known":true,"count":"充能 %d/%d"%[int(available),int(capacity)],"recovery":recovery,"tooltip":tooltip}

func present_q3_charges(charges:Dictionary)->void:
 _q3_charges=charges.duplicate(true)
 _refresh_q3_charges()

func _refresh_q3_charges()->void:
 if not bottom_slots.has("Q"):return
 var skill:Dictionary=_state.get("skills",{}).get("Q",{})
 var active:bool=not _q3_charges.is_empty() and str(skill.get("candidate","")).to_upper()=="Q3" and int(skill.get("rank",0))>0
 var tile:SkillTile=bottom_slots["Q"]
 tile.charge_mode=active
 tile.charge_count=""
 tile.charge_recovery=""
 if active:
  var projection:Dictionary=q3_charge_projection(_q3_charges)
  tile.charge_count=projection.count
  tile.charge_recovery=projection.recovery
  var availability:Dictionary=LearningProjection.slot_action(_state,_definitions,"Q")
  tile.tooltip_text=str(projection.tooltip)+"\n"+str(availability.label)
 elif not skill.is_empty():
  var definition:Dictionary=_definitions.get("skill_definitions",{}).get(str(skill.get("candidate","")),{})
  tile.tooltip_text="Q · %s Lv.%d"%[str(definition.get("name","未学习")),int(skill.get("rank",0))]+"\n"+str(LearningProjection.slot_action(_state,_definitions,"Q").label)
 tile.queue_redraw()

func present_r2(value:Dictionary)->void:
 _r2=value.duplicate(true);_refresh_r2();_status()
func _refresh_r2()->void:
 if not bottom_slots.has("R"):return
 var tile:SkillTile=bottom_slots["R"]
 var skill:Dictionary=_state.get("skills",{}).get("R",{})
 var selected:bool=str(skill.get("candidate","")).to_upper()=="R2" and int(skill.get("rank",0))>0
 var display:Dictionary=R2Projection.format(_r2)
 tile.r2_mode=selected and (not display.known or display.show)
 tile.r2_heading=str(display.heading);tile.r2_time=str(display.time)
 if selected:tile.tooltip_text=str(display.tooltip)+"\n"+str(LearningProjection.slot_action(_state,_definitions,"R").label)
 tile.queue_redraw()

func present_e2(value:Dictionary)->void:
 _e2=value.duplicate(true)
 _refresh_e2()
 _status()
func _refresh_e2()->void:
 if not bottom_slots.has("E"):return
 var tile:SkillTile=bottom_slots["E"]
 var skill:Dictionary=_state.get("skills",{}).get("E",{})
 var selected:bool=str(skill.get("candidate","")).to_upper()=="E2" and int(skill.get("rank",0))>0
 var display:Dictionary=E2Projection.format(_e2)
 tile.e2_mode=selected and (not display.known or display.show)
 tile.e2_heading=str(display.heading)
 tile.e2_time=str(display.time)
 if selected:tile.tooltip_text=str(display.tooltip)+"\n"+str(LearningProjection.slot_action(_state,_definitions,"E").label)
 tile.queue_redraw()

func present_overload(value:Dictionary)->void:
 _overload=value.duplicate(true)
 _refresh_overload()
 _status()
func _refresh_overload()->void:
 if not bottom_slots.has("E"):return
 var tile:SkillTile=bottom_slots["E"]
 var skill:Dictionary=_state.get("skills",{}).get("E",{})
 var selected:bool=str(skill.get("candidate","")).to_upper()=="E3" and int(skill.get("rank",0))>0
 var display:Dictionary=OverloadProjection.format(_overload)
 tile.overload_mode=selected and (not display.known or display.active)
 tile.overload_heading=str(display.heading)
 tile.overload_time=str(display.time)
 if selected:
  tile.tooltip_text=str(display.tooltip)+"\n"+str(LearningProjection.slot_action(_state,_definitions,"E").label)
 tile.queue_redraw()

func _status()->void:
 if _state.is_empty() or bottom_status==null:return
 bottom_status.text="HP %d / %d · Lv.%d · SP %d · 金币 %d"%[roundi(_hp),roundi(_max_hp),_state.level,_state.points,_state.gold]
 var display:Dictionary=OverloadProjection.format(_overload)
 if display.known and display.active:bottom_status.text+=" · 超载 "+str(display.time)
 bottom_status.tooltip_text=str(display.tooltip)
 var e2_display:Dictionary=E2Projection.format(_e2)
 if e2_display.known and not str(e2_display.status).is_empty():bottom_status.text+=" · "+str(e2_display.status)
 if not _e2.is_empty():bottom_status.tooltip_text=str(e2_display.tooltip)
 var r2_display:Dictionary=R2Projection.format(_r2)
 if r2_display.known and not str(r2_display.status).is_empty():bottom_status.text+=" · "+str(r2_display.status)
 if not _r2.is_empty():bottom_status.tooltip_text=str(r2_display.tooltip)

func _ready() -> void:
 super._ready()
 _configure_hex_modal_fit()
 bottom_bar=PanelContainer.new();bottom_bar.name="BottomSkillBar"
 var bar_style:=_panel();bar_style.set_content_margin_all(6)
 bottom_bar.add_theme_stylebox_override("panel",bar_style)
 bottom_bar.mouse_filter=Control.MOUSE_FILTER_STOP
 add_child(bottom_bar);move_child(bottom_bar,0)
 var body:=VBoxContainer.new();body.add_theme_constant_override("separation",4);bottom_bar.add_child(body)
 var slots:=HBoxContainer.new();slots.add_theme_constant_override("separation",6);body.add_child(slots)
 for slot:String in ["P","Q","E","R"]:
  var cell:=Control.new();cell.custom_minimum_size=Vector2(144,62)
  cell.mouse_filter=Control.MOUSE_FILTER_IGNORE
  cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL;slots.add_child(cell)
  var tile:=SkillTile.new();tile.slot=slot;tile.name="SkillDetails"+slot
  tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _style_button(tile);cell.add_child(tile);bottom_slots[slot]=tile
  tile.pressed.connect(func():toggle_slot(slot))
  var label:=Label.new();label.name="SkillNameAndRank";label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  label.add_theme_font_size_override("font_size",12);label.clip_text=true
  label.mouse_filter=Control.MOUSE_FILTER_IGNORE
  tile.add_child(label);label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
  label.offset_left=3;label.offset_right=-3;label.offset_top=-19;label.offset_bottom=-1
  bottom_labels[slot]=label
  # This sibling consumes its own click. It never forwards an upgrade to details,
  # and the rest of the 62 px skill button still opens the original detail cards.
  var action:=Button.new();action.name="SkillUpgrade"+slot;_style_button(action)
  action.add_theme_font_size_override("font_size",17);action.custom_minimum_size=Vector2(32,32)
  cell.add_child(action);action.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
  action.offset_left=-36;action.offset_right=-4;action.offset_top=4;action.offset_bottom=36
  bottom_actions[slot]=action;action.pressed.connect(func():_slot_action(slot))
 bottom_dash=Label.new();bottom_dash.custom_minimum_size=Vector2(56,0);bottom_dash.add_theme_font_size_override("font_size",12)
 bottom_dash.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;bottom_dash.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;slots.add_child(bottom_dash)
 var info:=HBoxContainer.new();info.custom_minimum_size=Vector2(0,32);info.add_theme_constant_override("separation",6);body.add_child(info)
 var vitals:=VBoxContainer.new();vitals.add_theme_constant_override("separation",2);vitals.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 vitals.size_flags_vertical=Control.SIZE_SHRINK_CENTER;info.add_child(vitals)
 bottom_status=Label.new();bottom_status.add_theme_font_size_override("font_size",12);bottom_status.clip_text=true;vitals.add_child(bottom_status)
 bottom_health=ProgressBar.new();bottom_health.custom_minimum_size=Vector2(0,6);bottom_health.show_percentage=false
 bottom_health.mouse_filter=Control.MOUSE_FILTER_IGNORE;vitals.add_child(bottom_health)
 var health_bg:=StyleBoxFlat.new();health_bg.bg_color=Color("0c1222");health_bg.set_corner_radius_all(3);bottom_health.add_theme_stylebox_override("background",health_bg)
 var health_fill:=StyleBoxFlat.new();health_fill.bg_color=Color("42e4d1");health_fill.set_corner_radius_all(3);bottom_health.add_theme_stylebox_override("fill",health_fill)
 bottom_undo=Button.new();bottom_undo.text="撤销";bottom_undo.custom_minimum_size=Vector2(48,32);_style_button(bottom_undo);info.add_child(bottom_undo);bottom_undo.pressed.connect(func():
  if LearningProjection.can_undo(_state):adapter.request("undo_new_points"))
 bottom_respec=Button.new();bottom_respec.text="洗点";bottom_respec.custom_minimum_size=Vector2(48,32);_style_button(bottom_respec);info.add_child(bottom_respec);bottom_respec.pressed.connect(func():
  if LearningProjection.can_respec(_state):training_requested.emit())
 bottom_popup=PanelContainer.new();bottom_popup.add_theme_stylebox_override("panel",_panel());add_child(bottom_popup);move_child(bottom_popup,1)
 var popup_body:=VBoxContainer.new();bottom_popup.add_child(popup_body)
 var close:=Button.new();close.text="收起技能说明";_style_button(close);popup_body.add_child(close);close.pressed.connect(func():bottom_open_slot="";bottom_popup.hide())
 var hint:=Label.new();hint.text="左键普攻 · WASD移动 · Shift冲刺 · 点击技能格查看详情；+ / ↑ 加点"
 # This fixed hint is 383 px at font 12, within the original 684 px content
 # width. Do not autowrap it while the new popup still has an unset width:
 # that transient narrow width can inflate the Panel's actual height to 801.
 hint.add_theme_font_size_override("font_size",12);popup_body.add_child(hint)
 _cards=HBoxContainer.new();_cards.add_theme_constant_override("separation",8);popup_body.add_child(_cards)
 bottom_popup.hide();_layout();resized.connect(_layout)
# The separate potion control keeps its source-owned children and UID callbacks.
# It reserves only its visible columns beside this bar, never a strip above it.
func set_potion_dock_width(width:float)->void:
 if is_equal_approx(_potion_dock_width,width):return
 _potion_dock_width=maxf(0.0,width)
 _layout()
func _layout()->void:
 if bottom_bar==null:return
 var dock_space:float=_potion_dock_width+POTION_DOCK_GAP if _potion_dock_width>0.0 else 0.0
 var width:float=minf(COMPACT_BAR_WIDTH,maxf(0.0,size.x-COMPACT_BAR_MARGIN*2.0-dock_space))
 var left:float=(size.x-width)*0.5
 if dock_space>0.0:left=minf(left,size.x-COMPACT_BAR_MARGIN-dock_space-width)
 bottom_bar.position=Vector2(maxf(COMPACT_BAR_MARGIN,left),size.y-COMPACT_BAR_MARGIN-COMPACT_BAR_HEIGHT)
 bottom_bar.size=Vector2(width,COMPACT_BAR_HEIGHT)
 # Detail cards retain their original width, callbacks and usable text area.
 var popup_width:float=minf(700.0,maxf(0.0,size.x-32.0))
 bottom_popup.position=Vector2((size.x-popup_width)*0.5,maxf(16.0,bottom_bar.position.y-280.0))
 bottom_popup.size=Vector2(popup_width,270)
func toggle_slot(slot:String)->void:
 if hex_required:return
 bottom_open_slot="" if bottom_open_slot==slot else slot
 _rebuild_cards()
func present_q_growth(state:Dictionary,definitions:Dictionary)->void:
 _state=state.duplicate(true)
 # Controller.bind creates a new immutable content Dictionary. Rebind or an explicit
 # version change invalidates only this presentation copy, never model/receipt state.
 var content_version:String=str(definitions.get("version",""))
 if not is_same(_definitions_source,definitions) or _definitions_version!=content_version:
  _definitions_source=definitions
  _definitions_version=content_version
  _definitions=definitions.duplicate(true)
  _cards_key=""
 if bottom_bar==null:return
 for slot in bottom_actions:
  var skill:Dictionary=state.skills[slot]
  var candidate:String=str(skill.candidate)
  var definition:Dictionary=definitions.get("skill_definitions",{}).get(candidate,{})
  var name:String=str(definition.get("name","未学习"))
  var blocked:bool=bool(state.get("actor_dead",false)) or not state.pending_milestones.is_empty()
  bottom_slots[slot].learned=int(skill.rank)>0
  var short_name:String="匕首标记" if candidate.to_upper()=="E1" else name
  bottom_labels[slot].text="%s · %s Lv.%d"%[slot,short_name,int(skill.rank)]
  var full_label:String="%s · %s Lv.%d"%[slot,name,int(skill.rank)]
  bottom_labels[slot].tooltip_text=full_label
  bottom_slots[slot].tooltip_text=full_label+"\n点击查看技能说明"
  bottom_slots[slot].queue_redraw()
  bottom_slots[slot].disabled=blocked
  var availability:Dictionary=LearningProjection.slot_action(state,definitions,slot)
  var can_spend:bool=availability.enabled
  bottom_actions[slot].tooltip_text=availability.label
  bottom_slots[slot].tooltip_text+="\n"+str(availability.label)
  bottom_actions[slot].text="+" if int(skill.rank)==0 else "↑"
  bottom_slots[slot].action_visible=can_spend
  bottom_actions[slot].visible=can_spend
  bottom_actions[slot].disabled=not can_spend
 present_source_vitals(_hp,_max_hp,_cooldowns)
 _refresh_q3_charges()
 _refresh_overload()
 _refresh_e2()
 _refresh_r2()
 bottom_undo.disabled=not LearningProjection.can_undo(_state)
 bottom_respec.disabled=not LearningProjection.can_respec(_state)
 _status()
 _rebuild_cards()
func _slot_action(slot:String)->void:
 if _state.is_empty() or not LearningProjection.slot_action(_state,_definitions,slot).enabled:return
 var skill:Dictionary=adapter.state.skills[slot]
 if int(skill.rank)==0:
  bottom_open_slot=slot;_rebuild_cards()
 else:
  adapter.request("learn",{"slot_id":slot,"candidate_id":str(skill.candidate),"expected_rank":int(skill.rank)})
func _rebuild_cards()->void:
 if _cards==null:return
 var key:String=JSON.stringify([_state.get("revision",-1),bottom_open_slot,hex_required])
 bottom_popup.visible=not bottom_open_slot.is_empty() and not hex_required
 if key==_cards_key:return
 _cards_key=key
 for child in _cards.get_children():_cards.remove_child(child);child.queue_free()
 bottom_candidate_buttons.clear()
 bottom_popup.visible=not bottom_open_slot.is_empty() and not hex_required
 if not bottom_popup.visible or _state.is_empty():return
 var slot:String=bottom_open_slot
 var learned:Dictionary=_state.skills[slot]
 for candidate: String in _definitions.candidates[slot]:
  var column:=VBoxContainer.new();column.custom_minimum_size=Vector2(210,0);_cards.add_child(column)
  var name:=Label.new();name.text=str(_definitions.skill_definitions[candidate].name);name.add_theme_font_size_override("font_size",14);column.add_child(name)
  var description:=Label.new();description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  description.custom_minimum_size=Vector2(210,130);description.text=str(_definitions.skill_descriptions[candidate][mini(int(learned.rank),_definitions.skill_descriptions[candidate].size()-1)])
  description.add_theme_font_size_override("font_size",13)
  var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.custom_minimum_size=Vector2(210,146);column.add_child(scroll)
  var details:=VBoxContainer.new();scroll.add_child(details)
  var preview:=Label.new();preview.name="RankPreview";preview.custom_minimum_size=Vector2(210,0);preview.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  preview.add_theme_font_size_override("font_size",12);preview.add_theme_color_override("font_color",Color("9be8e0"))
  preview.text=LearningProjection.preview_label(learned,candidate,_definitions.skill_descriptions[candidate].size())
  details.add_child(preview);details.add_child(description)
  var availability:Dictionary=LearningProjection.choice(_state,_definitions,slot,candidate)
  var button:=Button.new();button.text=availability.label;button.tooltip_text=availability.label;_style_button(button);column.add_child(button)
  button.disabled=not availability.enabled
  button.pressed.connect(func():
   if LearningProjection.choice(_state,_definitions,slot,candidate).enabled:
    adapter.request("learn",{"slot_id":slot,"candidate_id":candidate,"expected_rank":int(adapter.state.skills[slot].rank)}))
  bottom_candidate_buttons[candidate]=button
func set_hex_required(required:bool)->void:
 super.set_hex_required(required)
 if required and bottom_popup!=null:bottom_popup.hide()

# Fengli-only layout boundary. Keep the original cards, Labels, controls and callbacks.
func _configure_hex_modal_fit()->void:
 var frame:VBoxContainer=hex_draft.get_child(0) as VBoxContainer
 var grid:HBoxContainer=hex_draft.cards[0].panel.get_parent() as HBoxContainer
 # Emergency outer scrolling makes all controls reachable even below the card minima.
 # At normal viewport heights the footer and action rows stay outside the info scrolls.
 var outer:=ScrollContainer.new();outer.name="HexModalViewport"
 outer.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 outer.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;outer.follow_focus=true
 hex_draft.remove_child(frame);hex_draft.add_child(outer);outer.add_child(frame)
 frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 frame.size_flags_vertical=Control.SIZE_EXPAND_FILL
 # A narrow logical viewport scrolls the four original cards horizontally, not offscreen.
 var grid_index:int=grid.get_index()
 var strip:=ScrollContainer.new();strip.name="HexCardStrip"
 strip.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
 strip.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;strip.follow_focus=true
 strip.size_flags_vertical=Control.SIZE_EXPAND_FILL
 frame.remove_child(grid);frame.add_child(strip);frame.move_child(strip,grid_index);strip.add_child(grid)
 grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 grid.size_flags_vertical=Control.SIZE_EXPAND_FILL
 for row:Dictionary in hex_draft.cards:
  var card:PanelContainer=row.panel
  var column:VBoxContainer=row.description.get_parent() as VBoxContainer
  card.custom_minimum_size.y=0
  # Reparent the existing information block as a whole; never shorten effect text.
  var info:=VBoxContainer.new();info.add_theme_constant_override("separation",8)
  info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  var scroll:=ScrollContainer.new();scroll.name="HexCardInformation"
  scroll.custom_minimum_size=Vector2(0,48)
  scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
  scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
  scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.follow_focus=true
  var informational:Array=column.get_children().slice(0,4)
  column.add_child(scroll);column.move_child(scroll,0);scroll.add_child(info)
  for original:Node in informational:
   column.remove_child(original);info.add_child(original)
  # Original font sizes, full text and tooltip remain; wrapping may use narrower cards.
  row.name.custom_minimum_size.x=0
  row.description.custom_minimum_size.x=0
 hex_draft.footer.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 hex_draft.footer.custom_minimum_size.x=0
 hex_draft.custom_minimum_size=Vector2.ZERO
 hex_draft.clip_contents=true
 hex_draft.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 resized.connect(_fit_hex_modal)
 get_viewport().size_changed.connect(_fit_hex_modal)
 _fit_hex_modal()

func _fit_hex_modal()->void:
 if hex_draft==null:return
 var available:Vector2=get_viewport_rect().size
 var target:=Vector2(minf(1052.0,maxf(0.0,available.x-32.0)),minf(680.0,maxf(0.0,available.y-32.0)))
 hex_draft.position=(available-target)*0.5
 hex_draft.size=target
