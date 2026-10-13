extends Node3D
## Temporary source-front marker, not boat art/audio or a gameplay collider.
## Detached snapshots alone supply identity, center, direction, width and time.
## No source handle, local clock, obstacle query, interpolation or position inset.
const PRESENTATION_SCOPE := "temporary_e2_front_marker_final_art_audio_incomplete"
const HEIGHT_ABOVE_GROUND := 0.07
var boat_sample: Dictionary = {}
var _front: MeshInstance3D
var _label: Label3D
var _mesh: ImmediateMesh
var _last_direction: Vector3 = Vector3.ZERO
var _last_width: float = -1.0

func _ready() -> void:
 _ensure_visuals()

func _ensure_visuals() -> void:
 if is_instance_valid(_front): return
 name = "TemporaryE2PhysicalFront_ArtIncomplete"
 set_as_top_level(true); transform = Transform3D.IDENTITY
 _mesh = ImmediateMesh.new()
 _front = MeshInstance3D.new(); _front.name = "SourceWidthFrontMarker"
 _front.mesh = _mesh; _front.visible = false
 _front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material := StandardMaterial3D.new()
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 material.albedo_color = Color("9DDCD5")
 _front.material_override = material; add_child(_front)
 _label = Label3D.new(); _label.name = "SourceBoatStatus"
 _label.font_size = 28; _label.pixel_size = 0.008
 _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 _label.no_depth_test = true; _label.visible = false
 add_child(_label)

func _same_scope(value: Dictionary, scope: Dictionary) -> bool:
 return not value.is_empty() and int(value.get("generation",-1)) == int(scope.get("generation",-2)) and str(value.get("room_id","")) == str(scope.get("room_id","?"))

func _valid_front(boat: Dictionary) -> bool:
 if not boat.get("position",null) is Vector3 or not boat.get("direction",null) is Vector3: return false
 var point: Vector3 = boat.position
 var direction: Vector3 = boat.direction
 var width: float = float(boat.get("width",0.0))
 return point.is_finite() and direction.is_finite() and direction.length_squared() > 0.0 and is_finite(width) and width > 0.0

func _rebuild_front(direction: Vector3, width: float) -> void:
 if direction == _last_direction and width == _last_width: return
 _last_direction = direction; _last_width = width
 var side: Vector3 = Vector3(-direction.z,0.0,direction.x)
 var a: Vector3 = side*width*0.5
 var b: Vector3 = -a
 # The marker's leading edge is the exact source front. Its tiny thickness
 # and center tail extend backward only; they have no collision meaning.
 var back: Vector3 = -direction*0.035
 var center_tail: Vector3 = -direction*0.32
 var tail_half: Vector3 = side*0.025
 _mesh.clear_surfaces(); _mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 for vertex: Vector3 in [a,b,a+back,b,b+back,a+back,tail_half,-tail_half,center_tail]:
  _mesh.surface_add_vertex(vertex)
 _mesh.surface_end()

func present_source(ink_snapshot: Dictionary, e_projection: Dictionary = {}) -> void:
 _ensure_visuals(); reset_visuals()
 var scope: Dictionary = ink_snapshot.get("scope",{})
 var boat: Dictionary = ink_snapshot.get("boat",{})
 if not _same_scope(boat,scope) or not _valid_front(boat): return
 if bool(boat.get("retired",true)) or str(boat.get("boat_id","")).is_empty(): return
 var source_time: float = float(ink_snapshot.get("hero_time",NAN))
 var voyage_until: float = float(boat.get("voyage_until",NAN))
 if not is_finite(source_time) or not is_finite(voyage_until): return
 for field: String in ["boat_id","cast_id","generation","room_id","position","direction","width","phase","born_at","voyage_until","boundary_parked"]:
  if boat.has(field): boat_sample[field] = boat[field]
 boat_sample["source_time"] = source_time
 boat_sample["remaining"] = maxf(0.0,voyage_until-source_time)
 _rebuild_front(boat.direction,float(boat.width))
 var point: Vector3 = boat.position
 _front.position = Vector3(point.x,HEIGHT_ABOVE_GROUND,point.z); _front.visible = true
 _label.position = Vector3(point.x,0.7,point.z)
 var parked: bool = bool(boat.get("boundary_parked",false))
 _label.text = ("触边停留" if parked else "孤帆航行") + " · %.1fs" % float(boat_sample.remaining)
 if _same_scope(e_projection,scope) and str(e_projection.get("boat_id","")) == str(boat.boat_id) and float(e_projection.get("source_time",-INF)) == source_time:
  _label.text += "\n当前位置可登舟" if bool(e_projection.get("landing_legal",false)) else "\n当前位置站不下，无法登舟，保留原船"
 _label.text += "\n临时功能显示"
 _label.visible = true

func reset_visuals() -> void:
 boat_sample = {}
 if is_instance_valid(_front): _front.visible = false
 if is_instance_valid(_label): _label.visible = false
