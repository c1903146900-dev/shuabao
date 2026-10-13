extends RefCounted
## Blender-authored connected mountain sections, no radial cone construction.
const MODEL_PATH: String="res://tests/ink_r2_scroll_art_20261008/candidate03/mountain_mesh.json"
const Roots = preload("res://tests/ink_r2_peak_art_20261006/candidate12/landscape_mesh.gd")
func build() -> ArrayMesh:
 var data_value: Variant=JSON.parse_string(FileAccess.get_file_as_string(MODEL_PATH))
 if not data_value is Dictionary:return null
 var data: Dictionary=data_value
 if data.get("schema","")!="hand_authored_connected_mountain_v1":return null
 if data.vertices.size()!=126 or data.triangles.size()!=208 or data.normals.size()!=126 or data.uvs.size()!=126:return null
 var vertices := PackedVector3Array();var normals := PackedVector3Array();var uvs := PackedVector2Array()
 var strokes := PackedVector2Array();var colors := PackedColorArray();var indices := PackedInt32Array()
 for i: int in range(126):
  var p: Array=data.vertices[i];var n: Array=data.normals[i];var uv: Array=data.uvs[i]
  var point := Vector3(float(p[0]),float(p[1]),float(p[2]))
  var normal := Vector3(float(n[0]),float(n[1]),float(n[2]))
  vertices.append(point);normals.append(normal);uvs.append(Vector2(float(uv[0]),float(uv[1])));strokes.append(Vector2.ZERO)
  colors.append(Color(0.0,clampf(0.50+normal.x*0.18+normal.z*0.12,0.20,0.80),point.y/3.63,1.0))
 for face: Array in data.triangles:
  indices.append_array(PackedInt32Array([int(face[0]),int(face[1]),int(face[2])]))
 var roots: RefCounted=Roots.new()
 vertices.append_array(roots.call("authored_root_vertices"))
 var strips: Array=roots.call("root_strokes")
 for strip: int in range(2):
  var stroke: Dictionary=strips[strip]
  for section: int in range(6):
   for side: int in range(2):
    var sign_value: float=-1.0 if side==0 else 1.0
    var pixel: Vector2=stroke.atlas_centres[section]+Vector2(0,float(stroke.atlas_half_heights[section])*sign_value)
    uvs.append(pixel/Vector2(1254,675));strokes.append(Vector2(float(section)/5.0,sign_value));colors.append(Color(1,0,0,1));normals.append(Vector3.UP)
   if section<5:
    var a: int=126+strip*12+section*2
    indices.append_array(PackedInt32Array([a,a+2,a+1,a+1,a+2,a+3]))
 var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs
 arrays[Mesh.ARRAY_TEX_UV2]=strokes;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func geometry_contract() -> Dictionary:
 return {"surfaces":1,"vertices":150,"triangles":228,"connected_masses":1,"body_triangles":208,"root_triangles":20,"source_radius_unchanged":true,"maximum_height_metres":3.63,"art_accepted":false}
