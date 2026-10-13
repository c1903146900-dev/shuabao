extends Node3D
## Candidate R1 snow artwork. Detached snapshots are the only authority.
## Two stable meshes/materials, no Sim/actor reference, events, timer or physics.
const PRESENTATION_SCOPE: String = "r1_snow_art_successor03_source_only"
const ATLAS_PATH: String = "res://assets/ink_generated/r2_landscape01/ink_mountain_atlas01.png"
const MESH_PATH: String = "res://tests/ink_r1_snow_art_20261008/candidate03/snow_geometry.gd"
const SHADER_PATH: String = "res://tests/ink_r1_snow_art_20261008/candidate03/snow_ink.gdshader"
const OPEN_WORLD_SECONDS: float = 0.25
const CLOSE_WORLD_SECONDS: float = 0.28
var domain_sample: Dictionary = {}
var preview_sample: Dictionary = {}
var ink_node: MeshInstance3D
var ink_mesh: ArrayMesh
var ink_material: ShaderMaterial
var preview_node: MeshInstance3D
var preview_mesh: ArrayMesh
var preview_material: StandardMaterial3D
var _locked: Dictionary = {}
var _display_report: Dictionary = {}
var _scope_key: String = ""
var _closed_domain_id: String = ""
var _closed_born_at: float = -INF
var _resources_attempted: bool = false
var _resources_ready: bool = false

func _ready() -> void:
 _ensure_resources()

func _ensure_resources() -> bool:
 if _resources_attempted: return _resources_ready
 _resources_attempted = true
 name = "R1SnowDomainArtSuccessor03"
 set_as_top_level(true)
 transform = Transform3D.IDENTITY
 var mesh_script: GDScript = ResourceLoader.load(MESH_PATH,"GDScript") as GDScript
 var texture: Texture2D = ResourceLoader.load(ATLAS_PATH,"Texture2D") as Texture2D
 var shader: Shader = ResourceLoader.load(SHADER_PATH,"Shader") as Shader
 if mesh_script == null or not mesh_script.can_instantiate() or texture == null or shader == null:
  push_error("R1 snow requires candidate source and the existing standard imported atlas")
  return false
 if texture.get_width() != 1254 or texture.get_height() != 1254:
  push_error("R1 snow requires the unchanged 1254-square atlas")
  return false
 var builder: RefCounted = mesh_script.new()
 ink_mesh = builder.call("build") as ArrayMesh
 preview_mesh = builder.call("build_preview") as ArrayMesh
 if ink_mesh == null or preview_mesh == null: return false
 ink_material = ShaderMaterial.new()
 ink_material.shader = shader
 ink_material.set_shader_parameter("landscape_atlas",texture)
 preview_material = StandardMaterial3D.new()
 preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED
 preview_material.albedo_color = Color(1.0,0.84,0.34,0.78)
 ink_node = _make_node("FixedSnowLandscape")
 preview_node = _make_node("UncommittedR1Placement")
 _resources_ready = true
 return true

func _make_node(label: String) -> MeshInstance3D:
 var mesh_node := MeshInstance3D.new()
 mesh_node.name = label
 mesh_node.visible = false
 mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(mesh_node)
 return mesh_node

func _finite_number(value: Variant) -> bool:
 return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

func _valid_scope(value: Variant) -> bool:
 return value is Dictionary and typeof(value.get("generation",null)) == TYPE_INT and value.get("room_id",null) is String and not str(value.room_id).is_empty()

func _same_scope(value: Dictionary, scope: Dictionary) -> bool:
 return _valid_scope(value) and value.generation == scope.generation and value.room_id == scope.room_id

func _finite_circle(value: Dictionary) -> bool:
 if not value.get("position",null) is Vector3: return false
 var point: Vector3 = value.position
 return point.is_finite() and _finite_number(value.get("radius",null)) and float(value.radius) > 0.0

func _valid_domain(value: Dictionary, scope: Dictionary) -> bool:
 if not _same_scope(value,scope) or not _finite_circle(value): return false
 if not value.get("domain_id",null) is String or str(value.domain_id).is_empty(): return false
 for key: String in ["born_at","expires_at","remaining"]:
  if not _finite_number(value.get(key,null)): return false
 return float(value.expires_at) > float(value.born_at) and float(value.remaining) > 0.0

func _hide_domain() -> void:
 if is_instance_valid(ink_node):
  ink_node.visible = false
  ink_node.mesh = null
  ink_node.material_override = null
 if ink_material != null: ink_material.set_shader_parameter("visible_ink",0.0)
 domain_sample = {}

func _hide_preview() -> void:
 if is_instance_valid(preview_node):
  preview_node.visible = false
  preview_node.mesh = null
  preview_node.material_override = null
 preview_sample = {}

func _close(reason: String, now: float) -> void:
 if not _locked.is_empty():
  _closed_domain_id = str(_locked.domain_id)
  _closed_born_at = maxf(_closed_born_at,float(_locked.born_at))
 _locked = {}
 _hide_domain()
 _display_report = {"active":false,"reason":reason,"world_time":now,"closed_domain_id":_closed_domain_id,"visual_tail_seconds":0.0,"fixed_boundary_visible":true,"art_accepted":false}

func _present_preview(value: Dictionary, scope: Dictionary) -> void:
 _hide_preview()
 var armed_value: Variant = value.get("armed_identity",{})
 if not armed_value is Dictionary or value.get("accepted",false) != true: return
 var armed: Dictionary = armed_value
 if not _same_scope(armed,scope) or not _finite_circle(value): return
 preview_sample = {"position":value.position,"radius":value.radius,"armed_identity":armed.duplicate(true),"preview_only":true}
 preview_node.position = Vector3(value.position.x,value.position.y+0.075,value.position.z)
 preview_node.scale = Vector3(float(value.radius),1.0,float(value.radius))
 preview_node.mesh = preview_mesh
 preview_node.material_override = preview_material
 preview_node.visible = true

func present_source(ink_snapshot: Dictionary, preview_dictionary: Dictionary = {}) -> void:
 if not _ensure_resources():
  reset_visuals()
  _display_report = {"active":false,"reason":"resources_unavailable","art_accepted":false}
  return
 var scope_value: Variant = ink_snapshot.get("scope",{})
 if not _valid_scope(scope_value) or not _finite_number(ink_snapshot.get("world_time",null)):
  reset_visuals()
  return
 var scope: Dictionary = scope_value
 var now: float = float(ink_snapshot.world_time)
 var next_scope: String = JSON.stringify([scope.generation,scope.room_id])
 if next_scope != _scope_key:
  reset_visuals()
  _scope_key = next_scope
 _present_preview(preview_dictionary,scope)
 # Exact lifetime is the source field's lifetime. The one-second actor
 # presentation clock is deliberately absent from every read and calculation.
 if not _locked.is_empty() and now >= float(_locked.expires_at):
  _close("actual_expiry",now)
  return
 var snow_value: Variant = ink_snapshot.get("snow",{})
 var snow: Dictionary = snow_value if snow_value is Dictionary else {}
 if not _valid_domain(snow,scope):
  _close("source_removed_or_invalid",now)
  return
 if str(snow.domain_id) == _closed_domain_id or float(snow.born_at) < _closed_born_at:
  _hide_domain()
  _display_report = {"active":false,"reason":"closed_or_stale_domain","world_time":now,"visual_tail_seconds":0.0,"fixed_boundary_visible":true,"art_accepted":false}
  return
 if not _locked.is_empty() and str(_locked.domain_id) != str(snow.domain_id):
  _close("replaced_domain",now)
 if _locked.is_empty():
  for field: String in ["domain_id","generation","room_id","position","radius","born_at","expires_at"]:
   _locked[field] = snow[field]
 if now < float(_locked.born_at):
  _hide_domain()
  _display_report = {"active":false,"reason":"before_birth","world_time":now,"art_accepted":false}
  return
 if now >= float(_locked.expires_at):
  _close("actual_expiry",now)
  return
 if not _locked.has("opening_origin"):
  var hero_value: Variant = ink_snapshot.get("hero",{})
  var origin: Vector3 = _locked.position
  if hero_value is Dictionary and hero_value.get("position",null) is Vector3 and hero_value.position.is_finite():
   origin = hero_value.position
  var local_origin := Vector2(origin.x-_locked.position.x,origin.z-_locked.position.z)/float(_locked.radius)
  _locked["opening_origin"] = local_origin.limit_length(0.88)
 var age: float = now-float(_locked.born_at)
 var remaining: float = float(_locked.expires_at)-now
 var opening: float = clampf(age/OPEN_WORLD_SECONDS,0.0,1.0)
 var closing: float = clampf(1.0-remaining/CLOSE_WORLD_SECONDS,0.0,1.0)
 domain_sample = _locked.duplicate(true)
 domain_sample["remaining"] = remaining
 ink_node.position = _locked.position
 ink_node.scale = Vector3(float(_locked.radius),1.0,float(_locked.radius))
 ink_node.mesh = ink_mesh
 ink_node.material_override = ink_material
 ink_material.set_shader_parameter("domain_center",_locked.position)
 ink_material.set_shader_parameter("domain_radius",float(_locked.radius))
 ink_material.set_shader_parameter("source_age",age)
 ink_material.set_shader_parameter("opening_origin",_locked.opening_origin)
 ink_material.set_shader_parameter("open_progress",opening)
 ink_material.set_shader_parameter("close_progress",closing)
 ink_material.set_shader_parameter("visible_ink",1.0)
 ink_node.visible = true
 _display_report = {"active":true,"world_time":now,"source_age":age,"domain_id":_locked.domain_id,"position":_locked.position,"radius":_locked.radius,"born_at":_locked.born_at,"expires_at":_locked.expires_at,"remaining":remaining,"open_progress":opening,"close_progress":closing,"visual_tail_seconds":0.0,"fixed_boundary_visible":true,"art_accepted":false}

func presentation_snapshot() -> Dictionary:
 return _display_report.duplicate(true)

func reset_visuals() -> void:
 _hide_domain()
 _hide_preview()
 _locked = {}
 _display_report = {}
 _scope_key = ""
 _closed_domain_id = ""
 _closed_born_at = -INF

func _exit_tree() -> void:
 reset_visuals()
