extends RefCounted
## Bounded original code-native mountain study. Same 32x32 polygon grammar/palette.
## Functional candidate only, not final art or visual acceptance.
const Icons = preload("res://tests/ink_style_specimen_20261004/revision10_hud/icons.gd")
const SHAPES := [
 {"color":Icons.TEAL,"points":[[2,25],[7,15],[11,18],[17,4],[22,12],[25,10],[30,25]]},
 {"color":Icons.IVORY,"points":[[11,18],[17,4],[20,9],[17,8],[14,18]]},
 {"color":Icons.DEEP,"points":[[17,8],[22,17],[25,10],[30,25],[21,24],[16,18]]},
 {"color":Icons.WARM,"points":[[2,26],[10,25],[16,27],[23,26],[30,27],[25,29],[17,30],[9,28],[3,29]]}
]
static func draw_icon(canvas: CanvasItem, origin: Vector2, side: float = 32.0) -> void:
 for shape: Dictionary in SHAPES:
  var points := PackedVector2Array()
  for point: Array in shape.points: points.append(origin + Vector2(float(point[0]),float(point[1])) * side / 32.0)
  canvas.draw_colored_polygon(points,shape.color)
