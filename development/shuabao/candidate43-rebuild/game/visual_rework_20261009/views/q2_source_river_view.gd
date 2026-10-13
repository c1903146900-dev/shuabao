extends Node3D
## Ordinary two-point river only. H03 polylines and H04 damage-circle visuals
## remain under the existing production renderer until separately adapted.
const Bridge=preload("res://visual_rework_20261009/snapshot_bridge.gd")
const Geometry=preload("res://visual_rework_20261009/views/q2_geometry.gd")
const Beacon=preload("res://visual_rework_20261009/views/q2_beacon.gd")
const ROOT="res://visual_rework_20261009/views/"
var bridge=Bridge.new()
var rows:Dictionary={}
var camera:Camera3D
var river_sample:Dictionary={}
var sunset_samples:Array=[]
var fallback_required=false
var reveal_range_hint_enabled=false # Proposal defaults off pending review.
func _ready()->void:set_as_top_level(true);transform=Transform3D.IDENTITY
func reset_visuals()->void:
 for row in rows.values():
  for node in row.nodes:
   if is_instance_valid(node):node.queue_free()
 rows.clear();river_sample={};sunset_samples=[];fallback_required=false
func _texture(name:String)->Texture2D:return load(ROOT+name)
func _make_marker(key:String,point:Vector3,born:float,expiry:float)->Dictionary:
 var beacon=Beacon.new();beacon.position=point;add_child(beacon)
 var smoke=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(2.2,3.05,1.65);smoke.mesh=box
 var mouth=point+Vector3.UP*Beacon.MOUTH_HEIGHT;smoke.position=mouth+Vector3(.35,1.525,0)
 var mat=ShaderMaterial.new();mat.shader=load(ROOT+"q2_smoke.gdshader");mat.set_shader_parameter("root_world",mouth);mat.render_priority=4;smoke.material_override=mat;add_child(smoke)
 return {"nodes":[beacon,smoke],"beacon":beacon,"smoke":smoke,"born":born,"expiry":expiry,"surfaces":[],"sun":null,"committed":false,"key":key}
func _make_river(row:Dictionary,source:Dictionary)->void:
 var geo=Geometry.new();geo.configure(source.path[0],source.path[1],camera.global_position,float(source.width))
 for kind in ["far","near","water","dust"]:
  var shader=load(ROOT+("q2_water.gdshader" if kind=="water" else "q2_dust.gdshader" if kind=="dust" else "q2_land.gdshader"))
  var n=geo.surface(kind,shader);add_child(n);row.nodes.append(n);row.surfaces.append(n)
  if kind in ["far","near"]:
   n.material_override.set_shader_parameter("pigment_texture",_texture("q2_water_wash.png"));n.material_override.set_shader_parameter("stroke_texture",_texture("q2_water_atlas.png"))
  elif kind=="water":n.material_override.set_shader_parameter("flow_texture",_texture("q2_water_atlas.png"))
  else:n.material_override.set_shader_parameter("dust_texture",_texture("q2_atmosphere_atlas.png"))
 var sun=MeshInstance3D.new();var q=SurfaceTool.new();q.begin(Mesh.PRIMITIVE_TRIANGLES)
 for uv in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
  q.set_uv(uv);q.add_vertex(Vector3((uv.x-.5)*1.92,(uv.y-.5)*1.92,0))
 sun.mesh=q.commit();sun.position=geo.sun_position();sun.basis=camera.global_basis
 var mat=ShaderMaterial.new();mat.shader=load(ROOT+"q2_sun.gdshader");mat.set_shader_parameter("pigment_texture",_texture("q2_water_wash.png"));mat.set_shader_parameter("dust_texture",_texture("q2_atmosphere_atlas.png"));mat.render_priority=3;sun.material_override=mat;add_child(sun);row.nodes.append(sun);row.sun=sun
 row.committed=true;row.river_born=source.born_at;row.expiry=source.expires_at
func present_source(snapshot:Dictionary,_aim:Dictionary={})->void:
 if camera==null:camera=get_viewport().get_camera_3d()
 if camera==null:return
 var old_scope=bridge.current_scope.duplicate(true);var data=bridge.normalize(snapshot)
 if not data.accepted or old_scope!=data.scope:reset_visuals()
 if not data.accepted:return
 var needs_legacy=not data.fallbacks.is_empty()
 # H04 sunset outlives its river; keep legacy until its source expiry too.
 for sunset:Dictionary in snapshot.get("h04_sunsets",[]):
  if bridge.same_scope(sunset,data.scope) and data.source_time<float(sunset.get("expires_at",-INF)):needs_legacy=true
 for effect:Dictionary in data.effects:
  if effect.kind=="q2" and bool(effect.source.get("h04_at_completion",false)):needs_legacy=true
 if needs_legacy:
  reset_visuals();fallback_required=true;river_sample=data.duplicate(true)
  return
 var used={};fallback_required=false;river_sample=data.duplicate(true)
 for effect:Dictionary in data.effects:
  if effect.kind not in ["q2_marker","q2"]:continue
  var s:Dictionary=effect.source
  if effect.kind=="q2" and bool(s.get("h04_at_completion",false)):
   fallback_required=true;continue
  var key=str(s.cast_id);used[key]=true
  if not rows.has(key):rows[key]=_make_marker(key,effect.a,float(s.get("born_at",data.source_time)),float(s.expires_at))
  var row:Dictionary=rows[key]
  if effect.kind=="q2" and not row.committed:_make_river(row,s)
  var smoke_age=maxf(0,data.source_time-row.born);row.beacon.advance(smoke_age,row.expiry-data.source_time)
  row.smoke.material_override.set_shader_parameter("flow_time",smoke_age);row.smoke.material_override.set_shader_parameter("eye_direction",-camera.global_basis.z)
  row.smoke.material_override.set_shader_parameter("strength",1.0-.28*smoothstep(row.expiry-.45,row.expiry,data.source_time))
  if row.committed:
   var age=maxf(0,data.source_time-row.river_born)
   for n in row.surfaces:
    n.material_override.set_shader_parameter("age",age);n.material_override.set_shader_parameter("source_lifetime",row.expiry-row.river_born)
   row.sun.basis=camera.global_basis;row.sun.material_override.set_shader_parameter("age",age);row.sun.material_override.set_shader_parameter("source_lifetime",row.expiry-row.river_born)
 for key in rows.keys():
  if used.has(key):continue
  for n in rows[key].nodes:if is_instance_valid(n):n.queue_free()
  rows.erase(key)

const BeaconOcclusion = preload("res://visual_rework_20261009/views/q2_beacon_occlusion.gd")
func present_combat_readability(actors: Array, hero_position: Vector3, hero_radius: float) -> void:
 if camera == null or not is_instance_valid(camera): return
 var at: float = float(river_sample.get("source_time",0.0))
 for row: Dictionary in rows.values():
  var beacon: Node3D = row.beacon
  if not is_instance_valid(beacon): continue
  var blocked: Array = []
  if BeaconOcclusion.blocks_actor(camera.global_position,beacon.global_transform,hero_position,hero_radius): blocked.append("hero")
  for actor: Dictionary in actors:
   if actor.get("dead",false): continue
   if BeaconOcclusion.blocks_actor(camera.global_position,beacon.global_transform,actor.position,float(actor.get("radius",0.3))): blocked.append(str(actor.get("actor_id","")))
  beacon.present_occlusion(blocked,at)
