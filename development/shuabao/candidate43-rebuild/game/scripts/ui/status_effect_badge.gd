extends Button
## Compact effect icon. No clocks are advanced here; timers come from the snapshot.
var effect:Dictionary={}
func present(value:Dictionary) -> void:
	effect=value.duplicate(true)
	var stacks:=int(effect.get("stacks",1))
	var timer:=float(effect.get("remaining",-1))
	tooltip_text="%s%s\n%s%s" % [effect.get("name","状态")," · %d层" % stacks if stacks>1 else "",effect.get("description",""),"\n剩余 %.1f秒" % timer if timer>=0 else ""]
	queue_redraw()
func _draw() -> void:
	if effect.is_empty():return
	var bad:bool=effect.get("kind","buff")=="debuff"
	var tint:=Color("df8586") if bad else Color("77d9c9")
	var c:=Vector2(size.x*0.5,14)
	var id:=str(effect.get("id",""))
	if id.contains("shield") or str(effect.get("name","")).contains("盾"):
		draw_polyline(PackedVector2Array([c+Vector2(-8,-7),c+Vector2(8,-7),c+Vector2(7,2),c+Vector2(0,9),c+Vector2(-7,2),c+Vector2(-8,-7)]),tint,1.8,true)
	else:
		draw_polyline(PackedVector2Array([c+Vector2(0,-9),c+Vector2(9,0),c+Vector2(0,9),c+Vector2(-9,0),c+Vector2(0,-9)]),tint,1.7,true)
		draw_line(c+Vector2(-5,0),c+Vector2(5,0),tint,2,true)
		if not bad:draw_line(c+Vector2(0,-5),c+Vector2(0,5),tint,2,true)
	var font:=get_theme_default_font()
	var stacks:=int(effect.get("stacks",1))
	if stacks>1:
		draw_rect(Rect2(size.x-14,0,14,13),Color("27353e"))
		draw_string(font,Vector2(size.x-14,10),str(stacks),HORIZONTAL_ALIGNMENT_CENTER,14,10,Color.WHITE)
	var timer:=float(effect.get("remaining",-1))
	draw_string(font,Vector2(0,size.y-3),"%.1fs" % timer if timer>=0 else "∞",HORIZONTAL_ALIGNMENT_CENTER,size.x,10,tint)
