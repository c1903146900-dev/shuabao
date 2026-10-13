extends Node3D
## Read-only Q3 static shape candidate. Takes detached values, never a Sim/actor handle.
## No timer, physics, input, damage, collision, resources, source writes, or RNG.
const GEOMETRY_PATH := "res://tests/ink_q3_visual_20261004/static01/mountain_geometry.json"
const BRUSH_PATH := "res://tests/ink_q3_visual_20261004/static01/materials/mountain_brush.svg"
const MATERIAL_SHADER = preload("res://tests/ink_q3_visual_20261004/static01/materials/mountain.gdshader")
const RULES_SHA := "aef68e35a4becc25fcfa4158cfc2d55ee538a942023f99b7e7cefb07dac7cf53"
const EPS := 0.00001
var _geometry: Dictionary = {}
var _brush: Texture2D
var _root: Node3D
var _material: ShaderMaterial
var _state: Dictionary = {}
var _scope_key := ""
var _last_time := -1.0
var _last_revision := -1
var _blocked := false
var _diagnostics: Dictionary = {"status":"not_presented", "art_accepted":false}

func _ready() -> void:
 set_process(false)
 set_physics_process(false)

func _vector(value: Variant) -> Vector3:
 if value is Vector3: return value
 if value is Array and value.size() == 3: return Vector3(float(value[0]),float(value[1]),float(value[2]))
 return Vector3.INF

func _scope(item: Dictionary) -> String:
 return str(item.get("room_id","")) + ":" + str(item.get("generation",-1))

func _remove() -> void:
 if is_instance_valid(_root):
  _root.visible = false
  _root.queue_free()
 _root = null
 _state.clear()

func reset_visuals() -> void:
 _remove()
 _scope_key = ""
 _last_time = -1.0
 _last_revision = -1
 _blocked = false

func _hold(reason: String) -> void:
 _remove()
 _blocked = true
 _diagnostics = {"status":"HOLD", "reason":reason, "mountains":0, "art_accepted":false}

func _initialize() -> bool:
 if not _geometry.is_empty(): return true
 var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY_PATH))
 if not parsed is Dictionary or parsed.get("schema","") != "ink-q3-folded-mountain-1":
  _hold("missing_authored_mesh")
  return false
 _brush = load(BRUSH_PATH) as Texture2D
 if _brush == null:
  _hold("original_vector_brush_not_imported")
  return false
 _geometry = parsed
 return true

func _valid(state: Dictionary, now: float) -> bool:
 for key: String in ["terrain_id","cast_id","generation","room_id","position","axis","length","width","born_at","expires_at","source_time"]:
  if not state.has(key): return false
 if _scope(state) != _scope_key or str(state.terrain_id).is_empty(): return false
 var axis: Vector3 = _vector(state.axis)
 var center: Vector3 = _vector(state.position)
 var length: float = float(state.length)
 var width: float = float(state.width)
 var birth: float = float(state.born_at)
 var expiry: float = float(state.expires_at)
 return axis.is_finite() and center.is_finite() and absf(axis.y) < EPS and absf(axis.length()-1.0) < EPS and is_finite(length) and length > 0.0 and is_finite(width) and width > 0.0 and is_finite(birth) and is_finite(expiry) and expiry > birth and birth <= now + EPS and now < expiry and absf(float(state.source_time)-now) < EPS

func present(snapshot: Dictionary, _fresh_events: Array = [], readability: Dictionary = {}) -> void:
 if not _initialize(): return
 if snapshot.get("q3_schema","") != "ink-q3-mechanic-foundation-1" or str(snapshot.get("rules_hash","")) != RULES_SHA:
  _hold("source_schema_or_rules_mismatch")
  return
 var scope: Dictionary = snapshot.get("scope",{})
 var now: float = float(snapshot.get("source_time",-1.0))
 var revision: int = int(snapshot.get("revision",-1))
 if not scope.has("room_id") or not scope.has("generation") or not is_finite(now) or now < 0.0 or revision < 0:
  _hold("missing_scope_or_source_clock")
  return
 var next_scope: String = _scope(scope)
 if next_scope != _scope_key:
  reset_visuals()
  _scope_key = next_scope
 if _blocked: return
 if now < _last_time - EPS or revision < _last_revision:
  _hold("source_rewind_requires_explicit_reset")
  return
 _last_time = now
 _last_revision = revision
 var state: Dictionary = snapshot.get("mountain",{})
 if state.is_empty():
  _remove()
 else:
  if not _valid(state,now):
   _hold("invalid_current_mountain")
   return
  if not _state.is_empty() and str(state.terrain_id) == str(_state.terrain_id):
   for key: String in ["position","axis","length","width","born_at","expires_at","cast_id"]:
    if state[key] != _state[key]:
     _hold("same_terrain_identity_changed")
     return
  elif not _state.is_empty():
   _remove()
  if not is_instance_valid(_root): _create(state)
  _update_actor_apertures(snapshot,readability)
 _diagnostics = {"status":"static_shape_unreviewed", "scope":_scope_key, "source_time":now,
  "revision":revision, "mountains":1 if is_instance_valid(_root) else 0,
  "terrain_id":str(state.get("terrain_id","")), "actual_length":state.get("length",0.0),
  "actual_width":state.get("width",0.0), "max_cosmetic_height_m":1.78,
  "volume_triangles":int(_geometry.triangle_count), "source_mutation":false,
  "h05_visual_policy":"exact source length only; no height/width/collapse enlargement",
  "material_path":BRUSH_PATH, "actor05_q3_motion_accepted":false,
  "art_accepted":false, "native_input_accepted":false, "performance_accepted":false,
  "dynamic_scope":"not in static01; no inferred contact, moving front or expiry explosion"}

func _update_actor_apertures(snapshot: Dictionary, readability: Dictionary) -> void:
 var points := PackedVector3Array()
 var hero: Vector3 = _vector(snapshot.get("hero",{}).get("position",Vector3.INF))
 if hero.is_finite(): points.append(hero)
 if readability.get("scope",{}) == snapshot.get("scope",{}) and absf(float(readability.get("source_time",-2.0))-float(snapshot.source_time)) < EPS:
  for value: Variant in readability.get("actor_positions",[]):
   var at: Vector3 = _vector(value)
   if at.is_finite() and points.size() < 16: points.append(at)
 var count: int = points.size()
 while points.size() < 16: points.append(Vector3.ZERO)
 _material.set_shader_parameter("actor_feet",points)
 _material.set_shader_parameter("actor_count",count)

func _create(state: Dictionary) -> void:
 _state = state.duplicate(true)
 _root = Node3D.new()
 _root.name = "ActiveSourceMountain_" + str(state.cast_id)
 _root.position = _vector(state.position)
 var axis: Vector3 = _vector(state.axis)
 _root.basis = Basis(axis,Vector3.UP,Vector3(-axis.z,0.0,axis.x))
 add_child(_root)
 _material = ShaderMaterial.new()
 _material.shader = MATERIAL_SHADER
 _material.set_shader_parameter("authored_brush",_brush)
 var body := MeshInstance3D.new()
 body.name = "OriginalFoldedRidgeVolume"
 body.mesh = _volume(float(state.length),float(state.width))
 body.material_override = _material
 body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 _root.add_child(body)
 var seam := MeshInstance3D.new()
 seam.name = "ContinuousActualFootprintGroundSeam"
 seam.mesh = _seam(float(state.length),float(state.width))
 var pigment := StandardMaterial3D.new()
 pigment.albedo_color = Color("314B47")
 pigment.roughness = 1.0
 pigment.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 pigment.cull_mode = BaseMaterial3D.CULL_DISABLED
 seam.material_override = pigment
 seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 _root.add_child(seam)

func _volume(length: float,width: float) -> ArrayMesh:
 var vertices := PackedVector3Array()
 var normals := PackedVector3Array()
 var colors := PackedColorArray()
 var uvs := PackedVector2Array()
 for value: Array in _geometry.vertices:
  vertices.append(Vector3(float(value[0])*length,float(value[1]),float(value[2])*width))
 for index in range(0,vertices.size(),3):
  var n: Vector3 = (vertices[index+1]-vertices[index]).cross(vertices[index+2]-vertices[index]).normalized()
  for corner in range(3): normals.append(n)
 for value: Array in _geometry.colors: colors.append(Color(float(value[0]),float(value[1]),float(value[2]),1.0))
 for value: Array in _geometry.uvs: uvs.append(Vector2(float(value[0]),float(value[1])))
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_NORMAL] = normals
 arrays[Mesh.ARRAY_COLOR] = colors
 arrays[Mesh.ARRAY_TEX_UV] = uvs
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh

func _seam(length: float,width: float) -> ArrayMesh:
 var mesh := ImmediateMesh.new()
 mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 var half_l: float = length*.5
 var half_w: float = width*.5
 var corners: Array[Vector3] = [Vector3(-half_l,.028,-half_w),Vector3(half_l,.028,-half_w),Vector3(half_l,.028,half_w),Vector3(-half_l,.028,half_w)]
 for i in range(4):
  var a: Vector3 = corners[i]
  var b: Vector3 = corners[(i+1)%4]
  var inward: Vector3 = Vector3(-(b-a).z,0.0,(b-a).x).normalized()*.036
  for p: Vector3 in [a,b,b+inward,a,b+inward,a+inward]:
   mesh.surface_set_normal(Vector3.UP)
   mesh.surface_add_vertex(p)
 mesh.surface_end()
 # Return a retained ArrayMesh so diagnostics/tests can inspect exact geometry.
 var out := ArrayMesh.new()
 out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0))
 return out

func get_diagnostics() -> Dictionary:
 return _diagnostics.duplicate(true)
