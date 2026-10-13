extends "res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/domain_view.gd"
## Read-only temporary diagnostics. No collision, authored mesh, local clock,
## input dispatch, damage or movement. Every phase comes from detached source.
var peak_samples: Array = []
var peak_rings: Dictionary = {}

func present_source(ink_snapshot: Dictionary, preview_dictionary: Dictionary) -> void:
 var adapted: Dictionary = ink_snapshot.duplicate(true)
 adapted["snow"] = ink_snapshot.get("peaks_domain",{}).duplicate(true)
 super.present_source(adapted,preview_dictionary)
 name = "TemporaryR2PeakDiagnostics_ArtIncomplete"
 peak_samples.clear()
 for ring: MeshInstance3D in peak_rings.values(): ring.visible = false
 var scope: Dictionary = ink_snapshot.get("scope",{})
 var domain: Dictionary = ink_snapshot.get("peaks_domain",{})
 if not _same_scope(domain,scope) or not _finite_circle(domain): return
 for peak: Dictionary in ink_snapshot.get("ground_peaks",[]):
  if not _same_scope(peak,scope) or str(peak.get("domain_id","")) != str(domain.get("domain_id","")): continue
  if str(peak.get("phase","")) not in ["warning","rise","hit","fade"]: continue
  if not peak.get("position",null) is Vector3 or not Vector3(peak.position).is_finite(): continue
  var radius: float = float(peak.get("peak_radius",0.0))
  if not is_finite(radius) or radius <= 0.0: continue
  var key: String = str(peak.get("peak_id",""))
  if key.is_empty(): continue
  var ring: MeshInstance3D
  if peak_rings.has(key): ring = peak_rings[key]
  else:
   ring = _make_ring("TemporaryPeakPhase",ImmediateMesh.new(),Color.WHITE)
   peak_rings[key] = ring
  ring.mesh = _clipped_ring(peak.position,radius,domain.position,float(domain.radius))
  var tint: Color = Color("D7B964") if peak.phase == "warning" else (Color("9EADB7") if peak.phase == "fade" else Color("75B5AC"))
  if bool(peak.get("harmless",false)): tint = Color("687079")
  var material: StandardMaterial3D = ring.material_override
  material.albedo_color = tint
  ring.visible = true
  peak_samples.append(peak.duplicate(true))
 for key: String in peak_rings.keys():
  if not peak_rings[key].visible:
   peak_rings[key].queue_free(); peak_rings.erase(key)

func _clipped_ring(center: Vector3, radius: float, domain_center: Vector3, domain_radius: float) -> ImmediateMesh:
 var mesh: ImmediateMesh = ImmediateMesh.new()
 var vertices: Array[Vector3] = []
 for index: int in range(CIRCLE_SEGMENTS):
  var a: float = TAU*float(index)/float(CIRCLE_SEGMENTS)
  var b: float = TAU*float(index+1)/float(CIRCLE_SEGMENTS)
  var first: Vector3 = center+Vector3(cos(a)*radius,0.0,sin(a)*radius)
  var last: Vector3 = center+Vector3(cos(b)*radius,0.0,sin(b)*radius)
  if Vector2(first.x-domain_center.x,first.z-domain_center.z).length() > domain_radius or Vector2(last.x-domain_center.x,last.z-domain_center.z).length() > domain_radius: continue
  vertices.append(Vector3(first.x,HEIGHT_ABOVE_GROUND+0.03,first.z))
  vertices.append(Vector3(last.x,HEIGHT_ABOVE_GROUND+0.03,last.z))
 if not vertices.is_empty():
  mesh.surface_begin(Mesh.PRIMITIVE_LINES)
  for vertex: Vector3 in vertices: mesh.surface_add_vertex(vertex)
  mesh.surface_end()
 return mesh

func reset_visuals() -> void:
 super.reset_visuals()
 peak_samples.clear()
 for ring: MeshInstance3D in peak_rings.values(): ring.visible = false
