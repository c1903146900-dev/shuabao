extends "res://tests/ink_normal_floor_host_20261004/preview.gd"
## Temporary functional outlines using the existing preview material unchanged.
## Authority is the detached source snapshot, not this mesh or any wall clock.
var source_sample: Dictionary = {}
var river_sample: Dictionary = {}

func present_source(ink: Dictionary, aim: Dictionary) -> void:
 source_sample = ink.duplicate(true)
 sample = aim.duplicate(true)
 var scope: Dictionary = ink.get("scope",{})
 var now: float = float(ink.get("source_time",-1.0))
 var lines: Array[Vector3] = []
 var marker: Dictionary = ink.get("q2_input",{})
 var active: Array = []
 if _same_scope(marker,scope) and now >= 0.0 and now < float(marker.get("expires_at",-1.0)):
  var path: Array = marker.get("path",[])
  if not path.is_empty(): _cross(lines,path[0])
 for river: Dictionary in ink.get("rivers",[]):
  if not _same_scope(river,scope) or bool(river.get("river_expired",true)) or now < 0.0 or now >= float(river.get("expires_at",-1.0)): continue
  var path: Array = river.get("path",[])
  var width: float = float(river.get("width",0.0))
  if path.size() < 2 or width <= 0.0: continue
  _path_outline(lines,path,width)
  active.append({"river_id":river.river_id,"path":path.duplicate(true),"width":width,"expires_at":river.expires_at})
 if aim.get("accepted",false):
  if aim.get("phase","") == "first": _cross(lines,aim.point)
  elif aim.get("phase","") == "second": _path_outline(lines,aim.path,float(aim.width))
 river_sample = {"temporary_functional_display":true,"art_audio_implemented":false,"source_time":now,"marker":marker.duplicate(true),"active":active,"vertex_count":lines.size()}
 mesh_view.visible = not lines.is_empty()
 if lines.is_empty(): mesh_view.mesh = null; return
 var mesh := ImmediateMesh.new(); mesh.surface_begin(Mesh.PRIMITIVE_LINES)
 for vertex: Vector3 in lines: mesh.surface_add_vertex(vertex + Vector3.UP * .055)
 mesh.surface_end(); mesh_view.mesh = mesh

func _same_scope(value: Dictionary, scope: Dictionary) -> bool:
 return not value.is_empty() and value.get("generation",-1) == scope.get("generation",-2) and value.get("room_id","") == scope.get("room_id","?")
func _cross(lines: Array[Vector3], point: Vector3) -> void:
 # Point glyph only, no fabricated collision or damage radius.
 lines.append_array([point-Vector3.RIGHT*.18,point+Vector3.RIGHT*.18,point-Vector3.FORWARD*.18,point+Vector3.FORWARD*.18])
func _path_outline(lines: Array[Vector3], path: Array, width: float) -> void:
 for index in range(path.size()-1):
  var a: Vector3 = path[index]; var b: Vector3 = path[index+1]
  var axis: Vector3 = (b-a).normalized()
  if axis.length_squared() < .001: continue
  var side := Vector3(-axis.z,0,axis.x)
  var radius: float = width*.5
  lines.append_array([a-side*radius,b-side*radius,a+side*radius,b+side*radius])
  for endpoint in [0,1]:
   var center: Vector3 = a if endpoint == 0 else b
   var outward: Vector3 = -axis if endpoint == 0 else axis
   for arc in range(12):
    var t0: float = -PI*.5 + PI*float(arc)/12.0
    var t1: float = -PI*.5 + PI*float(arc+1)/12.0
    lines.append(center+(outward*cos(t0)+side*sin(t0))*radius)
    lines.append(center+(outward*cos(t1)+side*sin(t1))*radius)
