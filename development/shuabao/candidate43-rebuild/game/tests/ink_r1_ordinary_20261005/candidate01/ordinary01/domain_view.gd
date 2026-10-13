extends Node3D
## TEMPORARY FUNCTIONAL CIRCLES ONLY. R1 art and audio are NOT complete.
## Detached snapshots are the only authority; no source reference, physics,
## local lifetime clock, texture, imported asset, animation or gameplay write.
const PRESENTATION_SCOPE: String = "temporary_functional_circle_art_incomplete"
const CIRCLE_SEGMENTS: int = 96
const HEIGHT_ABOVE_GROUND: float = 0.065
var domain_sample: Dictionary = {}
var preview_sample: Dictionary = {}
var _domain_ring: MeshInstance3D
var _preview_ring: MeshInstance3D

func _ready() -> void:
 _ensure_visuals()

func _ensure_visuals() -> void:
 if is_instance_valid(_domain_ring): return
 name = "TemporaryR1FunctionalCircles_ArtIncomplete"
 # The input contains world ground points; ancestor transforms are irrelevant.
 set_as_top_level(true)
 transform = Transform3D.IDENTITY
 var circle: ImmediateMesh = _make_circle()
 _domain_ring = _make_ring("TemporaryCommittedDomainBoundary",circle,Color(0.54,0.87,0.96,0.88))
 _preview_ring = _make_ring("TemporaryR1PlacementPreview",circle,Color(1.0,0.84,0.34,0.78))

func _make_circle() -> ImmediateMesh:
 # An inward-only annulus: outer edge is exactly the source-provided radius.
 # Share the unit mesh; each snapshot supplies scale without rebuilding it.
 var out: ImmediateMesh = ImmediateMesh.new()
 out.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 for index: int in range(CIRCLE_SEGMENTS):
  var a: float = TAU * float(index) / float(CIRCLE_SEGMENTS)
  var b: float = TAU * float(index + 1) / float(CIRCLE_SEGMENTS)
  var outer_a: Vector3 = Vector3(cos(a),0.0,sin(a))
  var outer_b: Vector3 = Vector3(cos(b),0.0,sin(b))
  var inner_a: Vector3 = outer_a * 0.99
  var inner_b: Vector3 = outer_b * 0.99
  for vertex: Vector3 in [outer_a,inner_a,outer_b,outer_b,inner_a,inner_b]:
   out.surface_add_vertex(vertex)
 out.surface_end()
 return out

func _make_ring(label: String, circle: ImmediateMesh, tint: Color) -> MeshInstance3D:
 var ring: MeshInstance3D = MeshInstance3D.new()
 ring.name = label; ring.mesh = circle; ring.visible = false
 ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material: StandardMaterial3D = StandardMaterial3D.new()
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 material.albedo_color = tint
 ring.material_override = material
 add_child(ring)
 return ring

func _same_scope(value: Dictionary, scope: Dictionary) -> bool:
 return not value.is_empty() and int(value.get("generation",-1)) == int(scope.get("generation",-2)) and str(value.get("room_id","")) == str(scope.get("room_id","?"))

func _finite_circle(value: Dictionary) -> bool:
 if not value.get("position",null) is Vector3: return false
 var point: Vector3 = value.position
 var radius: float = float(value.get("radius",0.0))
 return point.is_finite() and is_finite(radius) and radius > 0.0

func _show_circle(ring: MeshInstance3D, value: Dictionary, height: float) -> void:
 var point: Vector3 = value.position
 var radius: float = float(value.radius)
 ring.position = Vector3(point.x,height,point.z)
 ring.scale = Vector3(radius,1.0,radius)
 ring.visible = true

func present_source(ink_snapshot: Dictionary, preview_dictionary: Dictionary) -> void:
 _ensure_visuals()
 _domain_ring.visible = false; _preview_ring.visible = false
 domain_sample = {}; preview_sample = {}
 var scope: Dictionary = ink_snapshot.get("scope",{})
 var snow: Dictionary = ink_snapshot.get("snow",{})
 # Inspect only the public snow identity, geometry and lifetime fields.
 if _same_scope(snow,scope) and _finite_circle(snow):
  var remaining: float = float(snow.get("remaining",0.0))
  var born: float = float(snow.get("born_at",INF))
  var expires: float = float(snow.get("expires_at",-INF))
  if not str(snow.get("domain_id","")).is_empty() and is_finite(remaining) and remaining > 0.0 and is_finite(born) and is_finite(expires) and expires > born:
   for field: String in ["domain_id","generation","room_id","position","radius","born_at","expires_at","remaining"]:
    domain_sample[field] = snow[field]
   _show_circle(_domain_ring,domain_sample,HEIGHT_ABOVE_GROUND)
 var armed: Dictionary = preview_dictionary.get("armed_identity",{})
 if bool(preview_dictionary.get("accepted",false)) and _same_scope(armed,scope) and _finite_circle(preview_dictionary):
  preview_sample = {"position":preview_dictionary.position,"radius":preview_dictionary.radius,"armed_identity":armed.duplicate(true),"preview_only":true}
  _show_circle(_preview_ring,preview_sample,HEIGHT_ABOVE_GROUND + 0.01)

func reset_visuals() -> void:
 domain_sample = {}; preview_sample = {}
 if is_instance_valid(_domain_ring): _domain_ring.visible = false
 if is_instance_valid(_preview_ring): _preview_ring.visible = false
