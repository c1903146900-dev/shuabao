extends Node3D
## Temporary A/B functional circles from detached source snapshots only.
## No collision, local clock, source reference, cast or gameplay-position write.
const PRESENTATION_SCOPE := "temporary_e3_AB_circles_final_art_audio_incomplete"
const CIRCLE_SEGMENTS := 96
const HEIGHT_ABOVE_GROUND := 0.075
var frame_sample: Dictionary = {}
var preview_sample: Dictionary = {}
var _a_ring: MeshInstance3D
var _b_ring: MeshInstance3D
var _preview_ring: MeshInstance3D
var _a_label: Label3D
var _b_label: Label3D
var _preview_label: Label3D

func _ready() -> void:
 _ensure_visuals()

func _ensure_visuals() -> void:
 if is_instance_valid(_a_ring): return
 name = "TemporaryE3FrameCircles_ArtIncomplete"
 set_as_top_level(true); transform = Transform3D.IDENTITY
 var circle := ImmediateMesh.new()
 circle.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 for index: int in range(CIRCLE_SEGMENTS):
  var a: float = TAU * float(index) / float(CIRCLE_SEGMENTS)
  var b: float = TAU * float(index + 1) / float(CIRCLE_SEGMENTS)
  var outer_a := Vector3(cos(a),0.0,sin(a))
  var outer_b := Vector3(cos(b),0.0,sin(b))
  for vertex: Vector3 in [outer_a,outer_a*0.99,outer_b,outer_b,outer_a*0.99,outer_b*0.99]:
   circle.surface_add_vertex(vertex)
 circle.surface_end()
 _a_ring = _make_ring("CommittedA",circle,Color("9DDCD5"))
 _b_ring = _make_ring("CommittedB",circle,Color("C0A8E6"))
 _preview_ring = _make_ring("CurrentMousePlacementOnly",circle,Color("EDD991"))
 _a_label = _make_label("SourceAWindow")
 _b_label = _make_label("SourceBState")
 _preview_label = _make_label("CurrentMousePlacementHint")

func _make_ring(label: String, circle: ImmediateMesh, tint: Color) -> MeshInstance3D:
 var ring := MeshInstance3D.new()
 ring.name = label; ring.mesh = circle; ring.visible = false
 ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material := StandardMaterial3D.new()
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 material.albedo_color = tint
 ring.material_override = material; add_child(ring)
 return ring

func _make_label(label: String) -> Label3D:
 var shown := Label3D.new()
 shown.name = label; shown.font_size = 25; shown.pixel_size = 0.009
 shown.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 shown.no_depth_test = true; shown.visible = false; add_child(shown)
 return shown

func _same_scope(value: Dictionary, scope: Dictionary) -> bool:
 return not value.is_empty() and int(value.get("generation",-1)) == int(scope.get("generation",-2)) and str(value.get("room_id","")) == str(scope.get("room_id","?"))

func _valid_circle(point: Variant, radius: float) -> bool:
 return point is Vector3 and point.is_finite() and is_finite(radius) and radius > 0.0

func _show_circle(ring: MeshInstance3D, label: Label3D, point: Vector3, radius: float, text: String) -> void:
 ring.position = Vector3(point.x,HEIGHT_ABOVE_GROUND,point.z)
 ring.scale = Vector3(radius,1.0,radius); ring.visible = true
 label.position = Vector3(point.x,0.75,point.z); label.text = text; label.visible = true

func present_source(ink_snapshot: Dictionary, preview: Dictionary = {}, e_projection: Dictionary = {}) -> void:
 _ensure_visuals(); reset_visuals()
 var scope: Dictionary = ink_snapshot.get("scope",{})
 var frames: Dictionary = ink_snapshot.get("frames",{})
 var source_time: float = float(ink_snapshot.get("hero_time",NAN))
 if not is_finite(source_time): return
 if not _same_scope(e_projection,scope) or str(e_projection.get("candidate","")) != "e3" or not bool(e_projection.get("learned",false)): return
 if float(e_projection.get("source_time",-INF)) != source_time: return
 var cooldown: float = float(e_projection.get("cooldown",0.0))
 var current: bool = _same_scope(frames,scope) and not bool(frames.get("retired",true)) and not str(frames.get("frame_id","")).is_empty()
 current = current and str(frames.get("frame_id","")) == str(e_projection.get("frame_id","")) and bool(e_projection.get("active",false))
 if current and _valid_circle(frames.get("a",null),float(frames.get("radius",0.0))):
  var radius: float = float(frames.radius)
  for field: String in ["frame_id","cast_id","generation","room_id","rank","phase","a","b","radius","max_distance","born_at","expires_at","exchange_at"]:
   if frames.has(field): frame_sample[field] = frames[field]
  frame_sample["source_time"] = source_time; frame_sample["cooldown"] = cooldown
  var remaining: float = maxf(0.0,float(frames.get("expires_at",source_time))-source_time) if str(frames.phase) == "first" else 0.0
  frame_sample["remaining"] = remaining
  var hint: String = "A · 放B剩余 %.1fs" % remaining if str(frames.phase) == "first" else "A · 交换结算"
  _show_circle(_a_ring,_a_label,frames.a,radius,hint+"\nCD %.1fs · 临时显示" % cooldown)
  if _valid_circle(frames.get("b",null),radius): _show_circle(_b_ring,_b_label,frames.b,radius,"B · 已确认\n临时显示")
 # No stale preview may survive room/rank/frame changes or a newer clock.
 if not bool(preview.get("displayable",false)) or not _same_scope(preview,scope) or float(preview.get("source_time",-INF)) != source_time: return
 if str(preview.get("frame_id","")) != str(frames.get("frame_id","")): return
 if str(preview.get("frame_phase","none")) != str(frames.get("phase","none")): return
 if not _valid_circle(preview.get("position",null),float(preview.get("radius",0.0))): return
 preview_sample = preview.duplicate(true)
 var legal: bool = bool(preview.get("accepted",false))
 var material: StandardMaterial3D = _preview_ring.material_override
 material.albedo_color = Color("EDD991") if legal else Color("E58F8A")
 var hint: String = str(preview.get("placement_label","A")) + (" · 按E确认" if legal else " · 此处不可确认")
 if str(preview.get("placement_label","A")) == "B": hint += "\n只移动敌人受伤 · 近高远低"
 _show_circle(_preview_ring,_preview_label,preview.position,float(preview.radius),hint+"\n临时预览")

func reset_visuals() -> void:
 frame_sample = {}; preview_sample = {}
 for visual in [_a_ring,_b_ring,_preview_ring,_a_label,_b_label,_preview_label]:
  if is_instance_valid(visual): visual.visible = false
