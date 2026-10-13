extends Button
## Skill tile only. Availability and cooldowns are projected by the game authority.
var hotkey:="Q"
var rank:=0
var cap:=6
var remaining:=0.0
var learned:=false
var artwork:Texture2D
var skill_name:="未学习"
var detail:=""
var icon_path:=""
var recast:=false
var charges:=-1
var max_charges:=0
var recast_window:=0.0
func _ready() -> void:
	custom_minimum_size=Vector2(65,64)
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func present(slot:String,skill:Dictionary) -> void:
	hotkey="P" if slot=="P" else slot
	rank=int(skill.get("rank",0));cap=int(skill.get("rank_cap",4 if slot in ["R","P"] else 6))
	learned=rank>0 or slot=="Shift";remaining=float(skill.get("cooldown",0.0))
	recast=skill.get("recast",false);charges=int(skill.get("charges",-1));max_charges=int(skill.get("max_charges",0));recast_window=float(skill.get("recast_window",0.0))
	skill_name=str(skill.get("name","未学习"))
	var path:=str(skill.get("icon",""))
	if path.is_empty() and str(skill.get("hero_id","xuanlei"))=="xuanlei" and slot!="Shift":path="res://assets/xuanlei/icons/%s%d.svg" % [slot.to_lower(),int(skill.get("candidate_index",0))+1]
	if path!=icon_path:
		icon_path=path;artwork=load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
	detail="%s · %s%s\n%s\n%s" % [hotkey,skill_name," · %d / %d阶" % [rank,cap] if slot!="Shift" else "",preload("res://scripts/ui/content_text.gd").skill_description(str(skill.get("description","点击上方 + 选择并学习技能"))),str(skill.get("reason","就绪"))]
	if learned and slot!="Shift":
		detail+="\n\n下一阶 · %d / %d\n%s" % [rank+1,cap,skill.get("next_description","")] if rank<cap else "\n\n已达到最高阶"
		if not str(skill.get("upgrade_reason","")).is_empty():detail+="\n"+str(skill.upgrade_reason)
	tooltip_text=detail;queue_redraw()
func _draw() -> void:
	var font:=get_theme_default_font()
	var rect:=Rect2(Vector2(7,5),Vector2(size.x-14,39))
	var tint:=Color("77d9c9") if learned else Color("50626b")
	if artwork:draw_texture_rect(artwork,rect,false,Color.WHITE if learned else Color(0.4,0.5,0.54))
	else:
		var c:=rect.get_center()
		if hotkey=="Shift":
			for x in [-8,3]:draw_polyline(PackedVector2Array([c+Vector2(x-5,-10),c+Vector2(x+5,0),c+Vector2(x-5,10)]),tint,2,true)
		else:
			draw_polyline(PackedVector2Array([c+Vector2(0,-17),c+Vector2(17,0),c+Vector2(0,17),c+Vector2(-17,0),c+Vector2(0,-17)]),tint,1.5,true)
			draw_string(font,c+Vector2(-7,6),hotkey if learned else "?",HORIZONTAL_ALIGNMENT_LEFT,-1,18,tint)
	if remaining>0:
		draw_rect(rect,Color(0.02,0.04,0.06,0.78))
		draw_string(font,Vector2(0,33),"%.1f" % remaining,HORIZONTAL_ALIGNMENT_CENTER,size.x,20,Color.WHITE)
	if recast:
		draw_rect(Rect2(4,3,size.x-8,42),Color("77d9c9"),false,1.5)
		if recast_window>0:draw_string(font,Vector2(0,44),"%.1fs"%recast_window,HORIZONTAL_ALIGNMENT_CENTER,size.x,10,Color("a7f3df"))
	if charges>=0:
		draw_rect(Rect2(size.x-26,4,23,17),Color("0c1820"))
		draw_string(font,Vector2(size.x-26,17),str(charges)+"/"+str(max_charges),HORIZONTAL_ALIGNMENT_CENTER,23,11,Color("f4d89a"))
	draw_string(font,Vector2(0,55),hotkey,HORIZONTAL_ALIGNMENT_CENTER,size.x,11,Color("e4eeef"))
	if hotkey!="Shift":
		var start:=(size.x-float(cap*7-2))*0.5
		for i in cap:draw_rect(Rect2(start+i*7,size.y-4,5,2),Color("cbb17c") if i<rank else Color("344b55"))
func _make_custom_tooltip(_for_text:String) -> Object:
	var panel:=PanelContainer.new()
	var style:=StyleBoxFlat.new();style.bg_color=Color("0c1820");style.border_color=Color("6f827d");style.set_border_width_all(1)
	style.content_margin_left=14;style.content_margin_right=14;style.content_margin_top=12;style.content_margin_bottom=12
	panel.add_theme_stylebox_override("panel",style)
	var text_label:=Label.new();text_label.custom_minimum_size.x=420
	text_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text_label.text=detail;text_label.add_theme_font_size_override("font_size",13)
	panel.add_child(text_label)
	return panel
