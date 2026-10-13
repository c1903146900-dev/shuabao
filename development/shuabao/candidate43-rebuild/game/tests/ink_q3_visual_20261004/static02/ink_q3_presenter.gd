extends "res://tests/ink_q3_visual_20261004/static01/ink_q3_presenter.gd"
## Bounded normal-view response to actual static01 pixels. No mechanic changes.
const GEOMETRY2_PATH := "res://tests/ink_q3_visual_20261004/static02/mountain_geometry.json"
const MATERIAL2_SHADER = preload("res://tests/ink_q3_visual_20261004/static02/materials/mountain.gdshader")

func _initialize() -> bool:
 if not _geometry.is_empty(): return true
 var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY2_PATH))
 if not parsed is Dictionary or parsed.get("schema","") != "ink-q3-tapered-mountain-2":
  _hold("missing_authored_tapered_mesh")
  return false
 _brush = load(BRUSH_PATH) as Texture2D
 if _brush == null:
  _hold("original_vector_brush_not_imported")
  return false
 _geometry = parsed
 return true

func _create(state: Dictionary) -> void:
 super._create(state)
 _material.shader = MATERIAL2_SHADER
 _material.set_shader_parameter("authored_brush",_brush)
 var seam: MeshInstance3D = _root.get_node("ContinuousActualFootprintGroundSeam")
 var pigment := StandardMaterial3D.new()
 pigment.albedo_color = Color.WHITE
 pigment.vertex_color_use_as_albedo = true
 pigment.vertex_color_is_srgb = true
 pigment.roughness = 1.0
 pigment.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 pigment.cull_mode = BaseMaterial3D.CULL_DISABLED
 seam.material_override = pigment

func _seam(length: float,width: float) -> ArrayMesh:
 # Thin continuous true rectangle, with asymmetric loaded inward edges.
 # The outer coordinates never expand, indent or imply a narrower blocker.
 var vertices := PackedVector3Array()
 var normals := PackedVector3Array()
 var colors := PackedColorArray()
 var corners: Array[Vector3] = [Vector3(-length*.5,.024,-width*.5),Vector3(length*.5,.024,-width*.5),Vector3(length*.5,.024,width*.5),Vector3(-length*.5,.024,width*.5)]
 var stations: Array[float] = [0.0,.065,.18,.265,.39,.47,.59,.70,.77,.86,.95,1.0]
 var loads: Array[float] = [.024,.036,.065,.025,.038,.077,.028,.034,.020,.052,.068,.024]
 for edge in range(4):
  var begin: Vector3 = corners[edge]
  var end: Vector3 = corners[(edge+1)%4]
  var inward: Vector3 = Vector3(-(end-begin).z,0.0,(end-begin).x).normalized()
  for i in range(stations.size()-1):
   var a: Vector3 = begin.lerp(end,stations[i])
   var b: Vector3 = begin.lerp(end,stations[i+1])
   var load_a: float = loads[(i+edge*3)%loads.size()]
   var load_b: float = loads[(i+1+edge*3)%loads.size()]
   if edge%2==1:
    load_a *= .62
    load_b *= .62
   var points: Array[Vector3] = [a,b,b+inward*load_b,a,b+inward*load_b,a+inward*load_a]
   for corner in range(points.size()):
    vertices.append(points[corner])
    normals.append(Vector3.UP)
    # Pigment remains locally dark at pressure points but never a filled slab.
    var loaded: float = clampf((load_a+load_b)*5.0,0.0,1.0)
    colors.append(Color(.49,.57,.46).lerp(Color(.27,.40,.34),loaded))
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_NORMAL] = normals
 arrays[Mesh.ARRAY_COLOR] = colors
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh

func get_diagnostics() -> Dictionary:
 var report: Dictionary = super.get_diagnostics()
 report["visual_revision"] = "static02_tapered_body_loaded_footprint"
 report["authored_geometry_path"] = GEOMETRY2_PATH
 report["base_policy"] = "visible volume tapers inside unchanged actual XZ extent; continuous exact rectangular perimeter retained"
 report["tone_policy"] = "lighter distant planes, moderate near ink, original dry reserves"
 report["static01_source_preserved"] = true
 report["art_accepted"] = false
 return report
