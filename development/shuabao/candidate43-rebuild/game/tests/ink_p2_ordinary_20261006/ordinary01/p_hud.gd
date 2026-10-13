extends "res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/p_hud.gd"
## Read-only renderer in the original P rectangle; no input or cooldown owner.
func _draw() -> void:
 if str(projected.get("candidate","p1")) != "p2":
  super._draw()
  return
 draw_rect(Rect2(Vector2.ZERO,size),Color("293C42"))
 var color := Color("DFE2D1") if bool(projected.get("learned",false)) else Color("8EAAA9")
 draw_string(get_theme_default_font(),Vector2(2,16),"P2",HORIZONTAL_ALIGNMENT_CENTER,42,13,color)
 draw_string(get_theme_default_font(),Vector2(2,29),str(projected.get("label","未学")),HORIZONTAL_ALIGNMENT_CENTER,42,10,color)
 draw_string(get_theme_default_font(),Vector2(2,42),"待触发" if bool(projected.get("ready",false)) else "墨 %d/3"%int(projected.get("stacks",0)),HORIZONTAL_ALIGNMENT_CENTER,42,9,color)
 draw_string(get_theme_default_font(),Vector2(2,55),"%.1fs"%float(projected.get("remaining",0.0)),HORIZONTAL_ALIGNMENT_CENTER,42,9,Color("8EAAA9"))
