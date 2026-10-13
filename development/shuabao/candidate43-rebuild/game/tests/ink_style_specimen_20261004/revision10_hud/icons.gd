extends RefCounted
## Original code-native silhouettes. Ink belongs to this hero's icons only.
## Local 32 x 32 art board; no raster/reference art, importer or shader.
const IVORY := Color("EDF0E5")
const TEAL := Color("82B8AF")
const DEEP := Color("182B32")
const WARM := Color("C7B78D")
const SHAPES := {
	"basic": [
		{"color":WARM,"points":[[10,20],[24,4],[27,6],[13,23]]},
		{"color":IVORY,"points":[[9,19],[14,23],[9,28],[3,30],[6,24]]},
		{"color":DEEP,"points":[[9,19],[12,16],[17,20],[14,23]]},
		{"color":TEAL,"points":[[3,30],[6,24],[9,28]]},
		{"color":TEAL,"points":[[16,28],[24,24],[30,23],[24,27]]}
	],
	"q1": [
		{"color":TEAL,"points":[[2,24],[7,19],[10,10],[14,5],[20,3],[25,6],[20,7],[17,11],[16,18],[21,21],[29,20],[25,25],[16,27],[8,26]]},
		{"color":IVORY,"points":[[7,18],[10,9],[14,5],[20,3],[25,6],[19,6],[14,10],[12,18]]},
		{"color":DEEP,"points":[[12,22],[13,16],[17,11],[16,18],[21,21],[28,21],[22,24],[17,24]]},
		{"color":TEAL,"points":[[3,27],[10,29],[19,28],[25,27],[30,25],[28,29],[20,31],[10,31]]}
	],
	"shift": [
		{"color":TEAL,"points":[[2,10],[11,10],[9,12],[1,12]]},
		{"color":TEAL,"points":[[0,16],[10,16],[8,18],[0,18]]},
		{"color":TEAL,"points":[[4,22],[10,22],[8,24],[3,24]]},
		{"color":IVORY,"points":[[15,4],[22,4],[19,14],[22,18],[29,19],[31,23],[24,26],[12,25],[9,22],[15,17],[17,11]]},
		{"color":WARM,"points":[[9,22],[12,25],[24,26],[31,23],[29,27],[22,29],[11,28],[7,25]]},
		{"color":DEEP,"points":[[18,15],[22,18],[25,19],[21,21],[16,19]]}
	]
}

static func draw_icon(canvas: CanvasItem, icon: String, origin: Vector2, side: float = 32.0) -> void:
	var scale_factor := side / 32.0
	for shape: Dictionary in SHAPES.get(icon, []):
		var vertices := PackedVector2Array()
		for point: Array in shape.points:
			vertices.append(origin + Vector2(float(point[0]),float(point[1])) * scale_factor)
		canvas.draw_colored_polygon(vertices, shape.color)
