extends Node3D
## Read-only view. The production Sim owns time, geometry, damage and collision.
## HeroCombatCore.emit_event flattens payload into the event; no data wrapper.
const Mountain=preload("res://visual_rework_20261009/views/q3_mountain_mesh.gd")
const WAVE_SHADER=preload("res://visual_rework_20261009/views/q3_wave.gdshader")
var mountain:Node3D
var wave:MeshInstance3D
var terrain:Dictionary={}
var scope_key:Dictionary={}
var collapse_event:Dictionary={}
var seen_events:Dictionary={}
var last_time=-INF
var held_reason=""
func _ready()->void:
 set_as_top_level(true);transform=Transform3D.IDENTITY
func _drop_mountain()->void:
 if is_instance_valid(mountain):mountain.queue_free()
 mountain=null;terrain={}
func _drop_wave()->void:
 if is_instance_valid(wave):wave.queue_free()
 wave=null
func reset_visuals()->void:
 _drop_mountain();_drop_wave();collapse_event={};seen_events.clear();scope_key={};last_time=-INF;held_reason=""
func _same_scope(row:Dictionary,scope:Dictionary)->bool:
 return row.get("generation",-1)==scope.get("generation",-2) and str(row.get("room_id",""))==str(scope.get("room_id","?"))
func _point(v:Variant)->bool:return v is Vector3 and v.is_finite()
func _clock(ink:Dictionary)->float:return float(ink.get("hero_time",ink.get("source_time",NAN)))
func _admit(ink:Dictionary)->bool:
 var scope:Dictionary=ink.get("scope",{})
 var now=_clock(ink)
 if not scope.has("generation") or not scope.has("room_id") or not is_finite(now):
  reset_visuals();held_reason="invalid_source_scope_or_clock";return false
 if scope_key!=scope:
  reset_visuals();scope_key=scope.duplicate(true)
 if now<last_time:
  reset_visuals();scope_key=scope.duplicate(true);held_reason="source_rewind_reset"
 last_time=now
 return true
func _valid_mountain(row:Dictionary,now:float)->bool:
 if not _same_scope(row,scope_key):return false
 if not _point(row.get("position")) or not _point(row.get("axis")):return false
 var length=float(row.get("length",NAN));var width=float(row.get("width",NAN))
 var born=float(row.get("born_at",NAN));var expiry=float(row.get("expires_at",NAN))
 return row.has("terrain_id") and row.axis.length_squared()>.000001 and is_finite(length) and length>0 and is_finite(width) and width>0 and is_finite(born) and is_finite(expiry) and born<=now and now<expiry
func _create_mountain(row:Dictionary)->void:
 _drop_mountain();terrain=row.duplicate(true)
 mountain=Mountain.new();add_child(mountain)
 mountain.position=row.position
 mountain.setup(row.axis.normalized(),float(row.length),float(row.width))
func _create_wave(event:Dictionary)->void:
 _drop_wave()
 var direction:Vector3=event.direction.normalized()
 var side=Vector3(-direction.z,0,direction.x)
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for uv in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
  st.set_uv(uv)
  st.add_vertex(event.position+direction*uv.x*float(event.length)+side*(uv.y-.5)*float(event.width)+Vector3.UP*.045)
 wave=MeshInstance3D.new();wave.mesh=st.commit()
 var mat=ShaderMaterial.new();mat.shader=WAVE_SHADER;wave.material_override=mat
 wave.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(wave)
func receive_source(event:Dictionary,ink_snapshot:Dictionary)->void:
 if not _admit(ink_snapshot) or not _same_scope(event,scope_key):return
 var kind=str(event.get("kind",""))
 if kind=="ink_q3_finished":
  # 'collapsed' is emitted in the same transaction; keep its short source-clock tail.
  if str(event.get("reason",""))!="collapsed" and str(event.get("terrain_id",""))==str(terrain.get("terrain_id","?")):
   _drop_mountain();_drop_wave();collapse_event={}
  return
 if kind!="ink_q3_collapse_started":return
 var now=_clock(ink_snapshot);var at=float(event.get("source_time",NAN))
 if not is_finite(at) or at>now or now-at>1.45:return
 if not _point(event.get("position")) or not _point(event.get("direction")) or event.direction.length_squared()<.000001:return
 for key in ["length","width"]:
  var value=float(event.get(key,NAN))
  if not is_finite(value) or value<=0:return
 var token="%s:%s:%s"%[str(event.get("terrain_id","")),str(event.get("cast_id","")),str(at)]
 if seen_events.has(token):return
 seen_events[token]=true;collapse_event=event.duplicate(true)
 if is_instance_valid(mountain) and str(terrain.get("terrain_id",""))==str(event.get("terrain_id","?")):
  mountain.collapse(event.direction.normalized())
 else:
  # Missing prior snapshot cannot establish the original raised length (event length
  # is now the collapse length). Do not fabricate a mountain from overwritten data.
  _drop_mountain()
 _create_wave(event)
 present_source(ink_snapshot)
func present_source(ink_snapshot:Dictionary,_preview:Dictionary={})->void:
 if not _admit(ink_snapshot):return
 var now=_clock(ink_snapshot)
 var row:Dictionary=ink_snapshot.get("mountain",{})
 if not row.is_empty() and _valid_mountain(row,now):
  if terrain.get("terrain_id","")!=row.terrain_id:
   _drop_wave();collapse_event={};_create_mountain(row)
  else:
   for key in ["position","axis","length","width","born_at","expires_at","cast_id"]:
    if row.get(key)!=terrain.get(key):
     _drop_mountain();held_reason="same_terrain_source_geometry_changed";return
  if is_instance_valid(mountain):mountain.present_at(now-float(row.born_at),float(row.expires_at)-now)
 elif collapse_event.is_empty():
  _drop_mountain()
 if not collapse_event.is_empty():
  var elapsed=now-float(collapse_event.source_time)
  if elapsed<0 or elapsed>=1.45:
   _drop_mountain();_drop_wave();collapse_event={}
  else:
   if is_instance_valid(mountain):mountain.present_at(now-float(terrain.born_at),0.0,elapsed)
   if is_instance_valid(wave):wave.material_override.set_shader_parameter("age",elapsed)
