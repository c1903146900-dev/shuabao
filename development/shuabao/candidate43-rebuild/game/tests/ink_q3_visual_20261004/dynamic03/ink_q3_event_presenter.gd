extends "res://tests/ink_q3_visual_20261004/dynamic02/ink_q3_event_presenter.gd"
## Pure read-only display revision after actual dynamic02 pixel rejection.
const PRESSURE_SHADER = preload("res://tests/ink_q3_visual_20261004/dynamic03/materials/pressure_ink.gdshader")
const PRESSURE_PATH := "res://tests/ink_q3_visual_20261004/dynamic03/materials/collapse_pressure.svg"
const CONTACT_INK_PATH := "res://tests/ink_q3_visual_20261004/dynamic03/materials/contact_ink.svg"
const CONTACT_RESERVE_PATH := "res://tests/ink_q3_visual_20261004/dynamic03/materials/contact_reserve.svg"
var pressure_texture: Texture2D
var contact_ink_texture: Texture2D
var contact_reserve_texture: Texture2D

func _initialize() -> bool:
 if not super._initialize(): return false
 if pressure_texture != null and contact_ink_texture != null and contact_reserve_texture != null: return true
 pressure_texture = load(PRESSURE_PATH) as Texture2D
 contact_ink_texture = load(CONTACT_INK_PATH) as Texture2D
 contact_reserve_texture = load(CONTACT_RESERVE_PATH) as Texture2D
 if pressure_texture == null or contact_ink_texture == null or contact_reserve_texture == null:
  _hold("original_dynamic03_vector_pigment_not_imported")
  return false
 return true

func _ink_material(texture: Texture2D,after: bool,white_key: bool=true) -> ShaderMaterial:
 var material := ShaderMaterial.new()
 material.shader = PRESSURE_SHADER
 material.set_shader_parameter("authored_ink",texture)
 material.set_shader_parameter("afterlayer",after)
 material.set_shader_parameter("white_reserve_key",white_key)
 return material

func _quad(points: Array[Vector3],uv: Array[Vector2]) -> ArrayMesh:
 var vertices := PackedVector3Array()
 var coordinates := PackedVector2Array()
 for index in [0,1,2,0,2,3]:
  vertices.append(points[index])
  coordinates.append(uv[index])
 var mesh: ArrayMesh = _mesh_from_points(vertices)
 var arrays: Array = mesh.surface_get_arrays(0)
 arrays[Mesh.ARRAY_TEX_UV] = coordinates
 mesh.clear_surfaces()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh

func _update_fold(record: Dictionary,now: float,snapshot: Dictionary,readability: Dictionary) -> void:
 var age: float = maxf(0.0,now-float(record.at))
 var event: Dictionary = record.event
 var direction: Vector3 = _vector(event.direction)
 var side: Vector3 = Vector3(-direction.z,0.0,direction.x)
 var origin: Vector3 = _vector(event.position)
 var body: MeshInstance3D = record.body
 body.visible = age < FOLD_SECONDS and not record.raised.is_empty()
 if body.visible:
  var raised: Dictionary = record.raised
  var axis: Vector3 = _vector(raised.axis)
  var across: Vector3 = Vector3(-axis.z,0.0,axis.x)
  var u: float = clampf(age/FOLD_SECONDS,0.0,1.0)
  var fold: float = 1.0-pow(1.0-u,3.0)
  var vertices := PackedVector3Array()
  var colors := PackedColorArray()
  var uvs := PackedVector2Array()
  for i in range(0,_geometry.vertices.size(),3):
   var triangle: Array[Vector3] = []
   var center := Vector3.ZERO
   for c in range(3):
    var p: Array = _geometry.vertices[i+c]
    var height: float = float(p[1])
    var world: Vector3 = origin + axis*float(p[0])*float(raised.length) + across*float(p[2])*float(raised.width)
    world += direction*height*.53*fold
    world.y = .026 + height*pow(1.0-fold,1.2)
    triangle.append(world)
    center += world/3.0
   var shrink: float = 1.0-smoothstep(.25+float((i / 3) % 5)*.04,.98,u)
   for c in range(3):
    vertices.append(center+(triangle[c]-center)*maxf(.015,shrink))
    var tone: Array = _geometry.colors[i+c]
    colors.append(Color(float(tone[0]),float(tone[1]),float(tone[2]),1.0))
    var uv: Array = _geometry.uvs[i+c]
    uvs.append(Vector2(float(uv[0]),float(uv[1])))
  var folded: ArrayMesh = _mesh_from_points(vertices)
  var arrays: Array = folded.surface_get_arrays(0)
  arrays[Mesh.ARRAY_COLOR] = colors
  arrays[Mesh.ARRAY_TEX_UV] = uvs
  folded.clear_surfaces()
  folded.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  body.mesh = folded
  if not snapshot.is_empty():
   var old_material: ShaderMaterial = _material
   _material = record.material
   _update_actor_apertures(snapshot,readability)
   _material = old_material
 var trace: MeshInstance3D = record.trace
 # The carrier is the complete authoritative rectangle from the FIRST sample.
 # Original alpha pigment makes brush shape/tears; no procedural zigzag fill.
 # Neither quad reach nor UVs depend on age; no travelling hit/front exists.
 var half_width: Vector3 = side*float(event.width)*.5
 var far: Vector3 = origin+direction*float(event.length)
 var p0: Vector3 = origin-half_width+Vector3(0,.034,0)
 var p1: Vector3 = far-half_width+Vector3(0,.034,0)
 var p2: Vector3 = far+half_width+Vector3(0,.034,0)
 var p3: Vector3 = origin+half_width+Vector3(0,.034,0)
 if not record.has("pressure_material"):
  record["pressure_material"] = _ink_material(pressure_texture,true)
  trace.material_override = record.pressure_material
  trace.mesh = _quad([p0,p1,p2,p3],[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
 var material: ShaderMaterial = record.pressure_material
 material.set_shader_parameter("source_age",age)

func _create_contact(event: Dictionary,now: float) -> void:
 var root := Node3D.new()
 root.name = "ActualBrushContact_" + str(event.target_id)
 root.position = _vector(event.target_position)
 var direction: Vector3 = _vector(event.direction).normalized()
 root.basis = Basis(Vector3(-direction.z,0.0,direction.x),Vector3.UP,-direction)
 add_child(root)
 var uv: Array[Vector2] = [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
 var dark := MeshInstance3D.new()
 dark.name = "ActualInkPressureContact"
 dark.mesh = _quad([Vector3(-.42,.24,.10),Vector3(.42,.24,.10),Vector3(.34,1.08,-.14),Vector3(-.34,1.08,-.14)],uv)
 dark.material_override = _ink_material(contact_ink_texture,false)
 dark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(dark)
 var dry := MeshInstance3D.new()
 dry.name = "ShortPaleMineralContactCut"
 dry.mesh = _quad([Vector3(-.37,.26,.12),Vector3(.37,.26,.12),Vector3(.32,1.02,-.12),Vector3(-.32,1.02,-.12)],uv)
 dry.material_override = _ink_material(contact_reserve_texture,false,false)
 dry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(dry)
 dark.visible = now-float(event.source_time) < .075
 _contacts.append({"node":root,"dark":dark,"dry":dry,"at":float(event.source_time),"source_event_id":str(event.source_event_id),"source_position":_vector(event.target_position)})

func get_diagnostics() -> Dictionary:
 var report: Dictionary = super.get_diagnostics()
 report["dynamic_visual_revision"] = "dynamic03_original_pressure_ink"
 report["afterlayer_material"] = PRESSURE_PATH
 report["dry_reserve_method"] = "original white-key directional vector cuts, stable UVs, no SVG mask dependency"
 report["instant_rectangle_carrier"] = true
 report["mountain_fold_algorithm_changed"] = false
 report["art_accepted"] = false
 return report
