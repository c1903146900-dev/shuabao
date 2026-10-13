extends Control
## Original geometric emblems: bronze gate, chain, impact or battlement.
var identity := ""
var dependency := ""
var accent := Color("dfba77")
func set_emblem(id: String, skill: String, color: Color) -> void:
	identity=id; dependency=skill; accent=color; queue_redraw()
func _draw() -> void:
	var c := size/2.0
	draw_circle(c,25.0,Color("162a31"))
	draw_arc(c,24.0,0,TAU,48,accent.darkened(0.45),1.5,true)
	var p := PackedVector2Array([c+Vector2(0,-21),c+Vector2(21,0),c+Vector2(0,21),c+Vector2(-21,0),c+Vector2(0,-21)])
	draw_polyline(p,accent.darkened(0.3),1.0,true)
	if dependency == "Q2":
		for i in range(3):
			var center := c+Vector2((i-1)*8,(i-1)*-6)
			draw_arc(center,6.0,-0.4,TAU-0.4,20,accent,2.0,true)
	elif dependency.begins_with("Q"):
		for i in range(3):
			var x := (i-1)*9.0
			draw_line(c+Vector2(x,-11),c+Vector2(x-4,3),accent,2.5,true)
			draw_line(c+Vector2(x-4,3),c+Vector2(x+3,1),accent,2.5,true)
			draw_line(c+Vector2(x+3,1),c+Vector2(x-1,12),accent,2.5,true)
	elif dependency.begins_with("E"):
		# E: shield-and-movement silhouette, distinct from Q's impact strokes.
		var shield := PackedVector2Array([c+Vector2(-12,-12),c+Vector2(12,-12),c+Vector2(10,6),c+Vector2(0,15),c+Vector2(-10,6),c+Vector2(-12,-12)])
		draw_polyline(shield,accent,2.0,true)
		draw_line(c+Vector2(-7,0),c+Vector2(7,0),accent,2.0,true)
		draw_line(c+Vector2(2,-5),c+Vector2(7,0),accent,2.0,true)
		draw_line(c+Vector2(2,5),c+Vector2(7,0),accent,2.0,true)
	elif dependency.begins_with("P"):
		# P: layered core, representing a persistent passive.
		draw_circle(c,7.0,accent,false,2.0,true)
		for i in range(6):
			var direction := Vector2.from_angle(i*TAU/6.0)
			draw_line(c+direction*11.0,c+direction*16.0,accent,2.2,true)
	elif dependency.begins_with("R"):
		# R: three crenellations of the great gate.
		var crown := PackedVector2Array([c+Vector2(-14,10),c+Vector2(-14,-10),c+Vector2(-7,-3),c+Vector2(0,-15),c+Vector2(7,-3),c+Vector2(14,-10),c+Vector2(14,10),c+Vector2(-14,10)])
		draw_polyline(crown,accent,2.0,true)
		draw_line(c+Vector2(-10,5),c+Vector2(10,5),accent,2.0,true)
	else:
		draw_rect(Rect2(c-Vector2(11,12),Vector2(22,25)),accent,false,2.0)
		draw_line(c+Vector2(0,-12),c+Vector2(0,13),accent,2.0,true)
		for y in [-6,5]: draw_line(c+Vector2(-11,y),c+Vector2(11,y),accent,1.5,true)
		for x in [-7,7]: draw_circle(c+Vector2(x,0),1.7,accent)
	# Unique small rune points distinguish emblems sharing a skill.
	var seed_value := absi(identity.hash())
	for i in range(4):
		if (seed_value >> i) & 1: draw_circle(c+Vector2(-9+i*6,20),1.4,accent)
