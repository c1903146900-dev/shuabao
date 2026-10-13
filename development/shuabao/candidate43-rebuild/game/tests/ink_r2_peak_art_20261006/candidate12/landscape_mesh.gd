extends RefCounted
## C11's exact 9-vertex folded painting, plus two asymmetric ground-root strips.
## One ArrayMesh surface; COLOR.r identifies roots, UV2 carries stroke distance.
const PIXEL_TO_METRE: float = 4.0 / 1159.0
const BASELINE_PIXEL_Y: float = 617.0
const CENTER_PIXEL_X: float = 649.5
const ATLAS_SIZE: float = 1254.0
const CELL_HEIGHT: float = 675.0
const SHEET_UP: Vector3 = Vector3(0.0, 0.7660444431, -0.6427876097)
const SHEET_NORMAL: Vector3 = Vector3(0.0, 0.6427876097, 0.7660444431)
const ROOT_GROUND_LIFT: float = 0.012

func authored_vertices() -> PackedVector3Array:
 var points := PackedVector3Array()
 # The fold closes exactly at the painted root. It never raises the baseline.
 for pixel_y: float in [0.0, BASELINE_PIXEL_Y, CELL_HEIGHT]:
  for pixel_x: float in [0.0, CENTER_PIXEL_X, ATLAS_SIZE]:
   var fold: float = 0.055 if pixel_x == CENTER_PIXEL_X and pixel_y == 0.0 else 0.0
   points.append(Vector3.RIGHT * ((pixel_x - CENTER_PIXEL_X) * PIXEL_TO_METRE) + SHEET_UP * ((BASELINE_PIXEL_Y - pixel_y) * PIXEL_TO_METRE) + SHEET_NORMAL * fold)
 return points

func root_strokes() -> Array:
 # Ordered outer tip -> painted foreground ridge foot, not the cell centre.
 # The two endpoints project to atlas x~478.5 and ~542.3, at its y617 baseline.
 # Each pair of source UVs is a cross-section through REAL lower top-cell ink.
 return [
  {"centres": PackedVector2Array([Vector2(-1.82, 0.34), Vector2(-1.61, 0.57), Vector2(-1.30, 0.51), Vector2(-1.02, 0.29), Vector2(-0.79, 0.12), Vector2(-0.59, 0.025)]),
   "half_widths": PackedFloat32Array([0.014, 0.075, 0.145, 0.180, 0.120, 0.035]),
   "atlas_centres": PackedVector2Array([Vector2(125, 586), Vector2(245, 577), Vector2(365, 587), Vector2(490, 600), Vector2(605, 590), Vector2(755, 601)]),
   "atlas_half_heights": PackedFloat32Array([6, 20, 15, 12, 20, 12])},
  {"centres": PackedVector2Array([Vector2(1.78, 0.24), Vector2(1.45, -0.08), Vector2(1.04, -0.04), Vector2(0.52, 0.19), Vector2(0.01, 0.16), Vector2(-0.37, 0.025)]),
   "half_widths": PackedFloat32Array([0.015, 0.085, 0.160, 0.185, 0.155, 0.045]),
   "atlas_centres": PackedVector2Array([Vector2(1175, 584), Vector2(1050, 574), Vector2(920, 586), Vector2(800, 591), Vector2(690, 580), Vector2(555, 591)]),
   "atlas_half_heights": PackedFloat32Array([7, 20, 13, 18, 25, 20])}
 ]

func authored_root_vertices() -> PackedVector3Array:
 var points := PackedVector3Array()
 for stroke: Dictionary in root_strokes():
  var centres: PackedVector2Array = stroke.centres
  for section: int in range(centres.size()):
   var tangent: Vector2 = (centres[mini(section + 1, centres.size() - 1)] - centres[maxi(section - 1, 0)]).normalized()
   var side: Vector2 = Vector2(-tangent.y, tangent.x) * float(stroke.half_widths[section])
   for sign_value: float in [-1.0, 1.0]:
    var point: Vector2 = centres[section] + side * sign_value
    points.append(Vector3(point.x, ROOT_GROUND_LIFT, point.y))
 return points

func build() -> ArrayMesh:
 var vertices: PackedVector3Array = authored_vertices()
 var uvs := PackedVector2Array()
 var stroke_uvs := PackedVector2Array()
 var colours := PackedColorArray()
 var normals := PackedVector3Array()
 for pixel_y: float in [0.0, BASELINE_PIXEL_Y, CELL_HEIGHT]:
  for pixel_x: float in [0.0, CENTER_PIXEL_X, ATLAS_SIZE]:
   uvs.append(Vector2(pixel_x / ATLAS_SIZE, pixel_y / CELL_HEIGHT))
   stroke_uvs.append(Vector2.ZERO)
   colours.append(Color(0.0, 0.0, 0.0, 1.0))
   normals.append(SHEET_NORMAL)
 var indices := PackedInt32Array()
 for row: int in range(2):
  for column: int in range(2):
   var a: int = row * 3 + column
   indices.append_array(PackedInt32Array([a, a + 3, a + 1, a + 1, a + 3, a + 4]))
 vertices.append_array(authored_root_vertices())
 var root_base: int = 9
 var stroke_id: int = 0
 for stroke: Dictionary in root_strokes():
  for section: int in range(6):
   var atlas_centre: Vector2 = stroke.atlas_centres[section]
   for sign_value: float in [-1.0, 1.0]:
    var atlas_pixel: Vector2 = atlas_centre + Vector2(0.0, float(stroke.atlas_half_heights[section]) * sign_value)
    uvs.append(atlas_pixel / Vector2(ATLAS_SIZE, CELL_HEIGHT))
    stroke_uvs.append(Vector2(float(section) / 5.0, sign_value))
    colours.append(Color(1.0, float(stroke_id), 0.0, 1.0))
    normals.append(Vector3.UP)
   if section < 5:
    var a: int = root_base + section * 2
    indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
  root_base += 12
  stroke_id += 1
 var arrays: Array = []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_NORMAL] = normals
 arrays[Mesh.ARRAY_TEX_UV] = uvs
 arrays[Mesh.ARRAY_TEX_UV2] = stroke_uvs
 arrays[Mesh.ARRAY_COLOR] = colours
 arrays[Mesh.ARRAY_INDEX] = indices
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
 return mesh

func geometry_contract() -> Dictionary:
 return {"surfaces": 1, "vertices": 33, "peak_vertices": 9, "root_vertices": 24, "triangles": 28, "peak_triangles": 8, "root_strips": 2, "safe_cell_xyxy_exclusive": [0, 0, 1254, 675], "root_uv_pixel_bounds": [125, 554, 1175, 613], "root_sample_clamp_xyxy_centres": [0.5, 540.5, 1253.5, 616.5], "visible_bbox_xyxy_exclusive": [70, 74, 1229, 617], "visible_width_metres": 4.0, "visible_projected_height_metres": 543.0 * PIXEL_TO_METRE, "maximum_fold_metres": 0.055, "baseline_pixel_y": BASELINE_PIXEL_Y, "root_ground_lift_metres": ROOT_GROUND_LIFT, "root_tip_world_xz": [[-0.59, 0.025], [-0.37, 0.025]], "camera_elevation_degrees": 40.0, "split_painted_submountains": false}
