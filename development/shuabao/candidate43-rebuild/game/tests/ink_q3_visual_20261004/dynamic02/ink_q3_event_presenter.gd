extends "res://tests/ink_q3_visual_20261004/static02/ink_q3_presenter.gd"
## Candidate event layer. All ages use the detached authoritative source sample.
## Static02 is the bounded second pixel-review gate; this adds no simulation handles.
const FOLD_SECONDS := 0.24
const AFTER_SECONDS := 0.34
const CONTACT_SECONDS := 0.16
var _dynamic_scope := ""
var _remembered: Dictionary = {}
var _seen_events: Dictionary = {}
var _folds: Array = []
var _contacts: Array = []
var _event_diagnostics: Dictionary = {}

func _clear_dynamic() -> void:
 for record: Dictionary in _folds + _contacts:
  var node: Node3D = record.node
  node.visible = false
  node.queue_free()
 _folds.clear()
 _contacts.clear()
 _remembered.clear()
 _seen_events.clear()

func reset_visuals() -> void:
 _clear_dynamic()
 _dynamic_scope = ""
 super.reset_visuals()

func present(snapshot: Dictionary, fresh_events: Array = [], readability: Dictionary = {}) -> void:
 var retained: Dictionary = _state.duplicate(true)
 super.present(snapshot,[],readability)
 if _diagnostics.get("status","") == "HOLD" or _blocked:
  _clear_dynamic()
  return
 if _dynamic_scope != _scope_key:
  _clear_dynamic()
  _dynamic_scope = _scope_key
 if not retained.is_empty() and _scope(retained) == _scope_key: _remembered = retained
 var live: Dictionary = snapshot.get("mountain",{})
 if not live.is_empty(): _remembered = live.duplicate(true)
 var now: float = float(snapshot.source_time)
 var accepted_contacts: int = 0
 var rejected: int = 0
 var accepted_collapses: int = 0
 # The host must give fresh detached callback events, never the historical journal.
 # Full snapshot receipt/finish identities independently corroborate every cue.
 for value: Variant in fresh_events:
  if not value is Dictionary: continue
  var event: Dictionary = value
  if _scope(event) != _scope_key: rejected += 1; continue
  var kind: String = str(event.get("kind",""))
  var at: float = float(event.get("source_time",-1.0))
  if not is_finite(at) or at < 0.0 or at > now + EPS: rejected += 1; continue
  if kind == "ink_q3_raised":
   # Retain real raise geometry for a same-render raise+collapse batch.
   if _corroborated_raise(event,snapshot) and _valid(event,at):
    _remembered = event.duplicate(true)
  elif kind == "ink_q3_collapse_started":
   if now-at >= AFTER_SECONDS: continue
   var key: String = str(event.get("terrain_id","")) + ":collapse"
   if _seen_events.has(key): continue
   if not _corroborated_collapse(event,snapshot): rejected += 1; continue
   _seen_events[key] = at
   _create_fold(event,now)
   accepted_collapses += 1
  elif kind == "ink_q3_contact":
   if now-at >= CONTACT_SECONDS: continue
   var key: String = str(event.get("source_event_id",""))
   if _seen_events.has(key): continue
   if not _corroborated_contact(event,snapshot): rejected += 1; continue
   _seen_events[key] = at
   _create_contact(event,now)
   accepted_contacts += 1
 for i in range(_folds.size()-1,-1,-1):
  var record: Dictionary = _folds[i]
  if now-float(record.at) >= AFTER_SECONDS:
   record.node.visible = false
   record.node.queue_free()
   _folds.remove_at(i)
  else: _update_fold(record,now,snapshot,readability)
 for i in range(_contacts.size()-1,-1,-1):
  var record: Dictionary = _contacts[i]
  var age: float = now-float(record.at)
  if age >= CONTACT_SECONDS:
   record.node.visible = false
   record.node.queue_free()
   _contacts.remove_at(i)
  else:
   # Immediate fixed-location strike, then retract in place. No traveling hit.
   record.dark.visible = age < .075
   record.dry.scale = Vector3.ONE * (1.0-smoothstep(.045,CONTACT_SECONDS,age)*.86)
 for key: String in _seen_events.keys():
  if now-float(_seen_events[key]) > 1.0: _seen_events.erase(key)
 _event_diagnostics = {"accepted_new_contacts":accepted_contacts,"accepted_new_collapses":accepted_collapses,
  "rejected_events":rejected,"active_contacts":_contacts.size(),"active_collapses":_folds.size(),
  "contact_age_basis":"source_time; immediate recorded target_position; never moved with push",
  "collapse_damage_visual":"entire true rectangle present at first sample, no travelling front",
  "natural_expiry":"quiet immediate retirement, no collapse/contact/ring inference",
  "H06":"no inferred stun icon; unchanged source controls only", "dynamic_art_accepted":false}

func _corroborated_raise(event: Dictionary,snapshot: Dictionary) -> bool:
 var live: Dictionary = snapshot.get("mountain",{})
 if not live.is_empty() and str(live.get("terrain_id","")) == str(event.get("terrain_id","")):
  for key: String in ["cast_id","position","axis","length","width","born_at","expires_at"]:
   if event.get(key) != live.get(key): return false
  return true
 for finished: Dictionary in snapshot.get("q3_finished",[]):
  if _scope(finished) != _scope_key or finished.get("terrain_id") != event.get("terrain_id"): continue
  for key: String in ["cast_id","position","axis","length","width","born_at","expires_at"]:
   if event.get(key) != finished.get(key): return false
  return true
 return false

func _corroborated_collapse(event: Dictionary,snapshot: Dictionary) -> bool:
 for key: String in ["terrain_id","cast_id","position","direction","axis","length","width","collapse_length","collapse_width","source_time"]:
  if not event.has(key): return false
 var direction: Vector3 = _vector(event.direction)
 if not direction.is_finite() or absf(direction.y) > EPS or absf(direction.length()-1.0) > EPS: return false
 if float(event.length) != float(event.collapse_length) or float(event.width) != float(event.collapse_width): return false
 if float(event.length) <= 0.0 or float(event.width) <= 0.0: return false
 for finished: Dictionary in snapshot.get("q3_finished",[]):
  if _scope(finished) != _scope_key or finished.get("terrain_id") != event.terrain_id or finished.get("cast_id") != event.cast_id: continue
  if finished.get("reason","") != "collapsed" or absf(float(finished.get("finished_at",-1.0))-float(event.source_time)) > EPS: continue
  for key: String in ["position","axis","collapse_length","collapse_width","born_at","expires_at"]:
   if event.get(key) != finished.get(key): return false
  return true
 return false

func _corroborated_contact(event: Dictionary,snapshot: Dictionary) -> bool:
 for key: String in ["source_event_id","terrain_id","cast_id","segment_id","target_id","source_time","target_position","target_radius","direction","origin","length","width"]:
  if not event.has(key): return false
 if str(event.source_event_id).is_empty() or str(event.target_id).is_empty(): return false
 if event.segment_id not in ["mountain_raise_burst","mountain_collapse"]: return false
 if not _vector(event.target_position).is_finite() or not _vector(event.direction).is_finite(): return false
 for receipt: Dictionary in snapshot.get("q3_receipts",[]):
  if _scope(receipt) != _scope_key or receipt.get("source_event_id") != event.source_event_id: continue
  for key: String in ["terrain_id","cast_id","segment_id","target_id","source_time","target_position","target_radius","direction","origin","length","width"]:
   if receipt.get(key) != event.get(key): return false
  return true
 return false

func _plain_material(color: Color) -> StandardMaterial3D:
 var material := StandardMaterial3D.new()
 material.albedo_color = color
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 material.roughness = 1.0
 return material

func _mesh_from_points(vertices: PackedVector3Array) -> ArrayMesh:
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 var normals := PackedVector3Array()
 for i in range(0,vertices.size(),3):
  var n: Vector3 = (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).normalized()
  for c in range(3): normals.append(n)
 arrays[Mesh.ARRAY_NORMAL] = normals
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh

func _create_fold(event: Dictionary,now: float) -> void:
 var root := Node3D.new()
 root.name = "ActualCollapse_" + str(event.cast_id)
 add_child(root)
 var body := MeshInstance3D.new()
 body.name = "RetainedRaiseShapeFoldsLocally"
 body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(body)
 var remembered: Dictionary = {}
 if _remembered.get("terrain_id","") == event.terrain_id and _remembered.get("cast_id",-1) == event.cast_id:
  remembered = _remembered.duplicate(true)
 # If no prior real raise sample exists, do not invent a mountain to fold.
 # The independently corroborated instantaneous ground afterlayer still appears.
 var pigment: ShaderMaterial = null
 if not remembered.is_empty():
  pigment = ShaderMaterial.new()
  pigment.shader = MATERIAL2_SHADER
  pigment.set_shader_parameter("authored_brush",_brush)
  body.material_override = pigment
 var trace := MeshInstance3D.new()
 trace.name = "InstantFullRectangleSparseAfterstroke"
 trace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 trace.material_override = _plain_material(Color("4D625B"))
 root.add_child(trace)
 var record: Dictionary = {"node":root,"body":body,"trace":trace,"material":pigment,"at":float(event.source_time),"event":event.duplicate(true),"raised":remembered}
 _folds.append(record)
 _update_fold(record,now,{}, {})

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
 # Full-length sparse strokes exist at age zero. Only width retracts in place.
 # Never grow distance with time, delay far contacts, or move an attacking edge.
 var thin: float = 1.0-smoothstep(.035,AFTER_SECONDS,age)*.985
 var lines := PackedVector3Array()
 var authored: Array = [
  [[.00,-.24],[.13,-.19],[.28,-.24],[.49,-.09],[.74,-.17],[1.0,-.10]],
  [[.04,.08],[.22,.01],[.44,.13],[.68,.08],[.93,.19]],
  [[.18,.34],[.40,.25],[.62,.31],[.82,.25],[1.0,.30]]]
 var stroke_widths: Array[float] = [.085,.145,.049]
 for row_index in range(authored.size()):
  var row: Array = authored[row_index]
  for index in range(row.size()-1):
   if row_index == 2 and index == 1: continue # One intentional dry break, no front.
   var a: Vector3 = origin+direction*float(row[index][0])*float(event.length)+side*float(row[index][1])*float(event.width)
   var b: Vector3 = origin+direction*float(row[index+1][0])*float(event.length)+side*float(row[index+1][1])*float(event.width)
   a.y = .033+row_index*.002
   b.y = a.y
   var wa: Vector3 = side*stroke_widths[row_index]*float(event.width)*thin*(.45 if index == 0 else .72)
   var wb: Vector3 = side*stroke_widths[row_index]*float(event.width)*thin*(.08 if index == row.size()-2 else .55)
   for p: Vector3 in [a-wa,a+wa,b+wb,a-wa,b+wb,b-wb]: lines.append(p)
 trace.mesh = _mesh_from_points(lines)

func _create_contact(event: Dictionary,now: float) -> void:
 var root := Node3D.new()
 root.name = "ActualContact_" + str(event.target_id)
 root.position = _vector(event.target_position)
 var direction: Vector3 = _vector(event.direction).normalized()
 root.basis = Basis(Vector3(-direction.z,0.0,direction.x),Vector3.UP,-direction)
 add_child(root)
 var dark := MeshInstance3D.new()
 dark.name = "ImmediateLocalInkWedge"
 dark.mesh = _mesh_from_points(PackedVector3Array([Vector3(-.29,.33,.04),Vector3(.17,.43,.08),Vector3(.10,.98,-.16),Vector3(.08,.41,.02),Vector3(.36,.30,.14),Vector3(.20,.69,-.14)]))
 dark.material_override = _plain_material(Color("1F3539"))
 dark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(dark)
 var dry := MeshInstance3D.new()
 dry.name = "ShortDryContactCut"
 dry.mesh = _mesh_from_points(PackedVector3Array([Vector3(-.24,.40,.08),Vector3(-.10,.36,.12),Vector3(.25,.80,-.20),Vector3(.02,.40,.12),Vector3(.14,.33,.16),Vector3(.39,.59,-.06)]))
 dry.material_override = _plain_material(Color("DFE5D3"))
 dry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(dry)
 dark.visible = now-float(event.source_time) < .075
 _contacts.append({"node":root,"dark":dark,"dry":dry,"at":float(event.source_time),"source_event_id":str(event.source_event_id),"source_position":_vector(event.target_position)})

func get_diagnostics() -> Dictionary:
 var report: Dictionary = super.get_diagnostics()
 report["event_layer"] = _event_diagnostics.duplicate(true)
 report["dynamic_visual_accepted"] = false
 return report
