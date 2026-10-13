extends "res://tests/ink_q2_ordinary_20261005/candidate01/river_view.gd"
## Detached exact-source circles and tick pointers. No clock/process/collision.
var sunset_view: MeshInstance3D
var sunset_samples: Array=[]
func _ready() -> void:
 super._ready()
 sunset_view=MeshInstance3D.new(); add_child(sunset_view)
 sunset_view.material_override=mesh_view.material_override
 sunset_view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func present_source(ink: Dictionary, aim: Dictionary) -> void:
 super.present_source(ink,aim)
 sunset_samples=[]
 var lines: Array[Vector3]=[]
 var scope: Dictionary=ink.get("scope",{})
 var now: float=float(ink.get("source_time",-1.0))
 for value: Dictionary in ink.get("h04_sunsets",[]):
  if not _same_scope(value,scope) or now<0.0 or now>=float(value.expires_at) or float(value.radius)<=0.0: continue
  var entry: Dictionary=value.duplicate(true)
  sunset_samples.append(entry)
  var center: Vector3=entry.center
  var radius: float=entry.radius
  for index in range(64):
   var a: float=TAU*float(index)/64.0
   var b: float=TAU*float(index+1)/64.0
   lines.append(center+Vector3(cos(a),0,sin(a))*radius)
   lines.append(center+Vector3(cos(b),0,sin(b))*radius)
  # One revolution per authoritative half-second interval. Its angular value
  # is supplied by Sim; repeated rendering and pause cannot advance it.
  var angle: float=TAU*float(entry.tick_progress)
  var axis:=Vector3(cos(angle),0,sin(angle))
  lines.append(center+axis*radius*0.82); lines.append(center+axis*radius)
 var marker: Dictionary=ink.get("q2_input",{})
 if _same_scope(marker,scope) and now<float(marker.get("expires_at",-1.0)):
  for point: Vector3 in marker.get("path",[]).slice(1): _cross(lines,point)
 sunset_view.visible=not lines.is_empty()
 if lines.is_empty(): sunset_view.mesh=null; return
 var mesh:=ImmediateMesh.new(); mesh.surface_begin(Mesh.PRIMITIVE_LINES)
 for vertex: Vector3 in lines: mesh.surface_add_vertex(vertex+Vector3.UP*0.06)
 mesh.surface_end(); sunset_view.mesh=mesh
