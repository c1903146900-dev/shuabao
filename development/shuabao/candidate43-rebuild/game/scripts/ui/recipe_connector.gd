extends Control
## Recipe lines follow real laid-out component buttons, including repeated components.
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y=14
	resized.connect(queue_redraw)
func _draw() -> void:
	var tree:=get_parent()
	if tree==null or tree.get_child_count()<3:return
	var selected:=tree.get_child(0)
	var components:=tree.get_child(2)
	if selected.get_child_count()==0 or components.get_child_count()==0 or not components.get_child(0) is Button:return
	var origin:=global_position
	var parent_x:float=selected.get_child(0).get_global_rect().get_center().x-origin.x
	var xs:Array[float]=[]
	for button in components.get_children():xs.append(button.get_global_rect().get_center().x-origin.x)
	var tint:=Color("3c9694")
	var middle:=size.y*0.45
	draw_line(Vector2(parent_x,0),Vector2(parent_x,middle),tint,1.3,true)
	draw_line(Vector2(xs.min(),middle),Vector2(xs.max(),middle),tint,1.3,true)
	for x in xs:draw_line(Vector2(x,middle),Vector2(x,size.y),tint,1.3,true)
