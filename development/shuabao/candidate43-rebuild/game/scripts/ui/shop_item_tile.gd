extends Button
## Compact item grid cell with original category artwork and an owned marker.
var item:Dictionary={}
var art:Texture2D
var selected:=false
var tier:=0
func present(entry:Dictionary,texture:Texture2D,is_selected:bool) -> void:
	item=entry;art=texture;selected=is_selected
	tooltip_text="%s · %d金币\n%s" % [entry.name,entry.price,entry.description]
	queue_redraw()
func _draw() -> void:
	if item.is_empty():return
	var font:=get_theme_default_font()
	var icon_rect:=Rect2(Vector2((size.x-40)*0.5,5),Vector2(40,40))
	if art:draw_texture_rect(art,icon_rect,false,Color.WHITE if item.get("available",true) else Color(0.45,0.48,0.5))
	draw_rect(icon_rect,Color("d9be82") if selected else Color("526873"),false,1.5)
	var name_text:String=str(item.name)
	if name_text.length()>5:name_text=name_text.left(5)
	draw_string(font,Vector2(1,59),name_text,HORIZONTAL_ALIGNMENT_CENTER,size.x-2,10,Color("d9e4e7"))
	draw_string(font,Vector2(1,74),str(item.get("price",0)),HORIZONTAL_ALIGNMENT_CENTER,size.x-2,11,Color("d9be82"))
	if int(item.get("owned",0))>0:
		var badge:=Rect2(icon_rect.end.x-14,icon_rect.position.y,16,15)
		draw_rect(badge,Color("316b51"))
		draw_string(font,badge.position+Vector2(1,11),"%d" % item.owned,HORIZONTAL_ALIGNMENT_CENTER,14,10,Color.WHITE)
