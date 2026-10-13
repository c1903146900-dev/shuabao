extends Node3D
## Cosmetic read-only fronts, release arcs and positive-contact marks.
const ATLAS="res://assets/ink_generated/r2_landscape01/ink_mountain_atlas01.png"
const SHADER="res://tests/ink_attack_feedback_20261007/candidate02/brush.gdshader"
const MAX_PROJECTILES=8
const MAX_PULSES=16
const SWEEP_SECONDS=0.14
const IMPACT_SECONDS=0.16
const TRAIL_METRES=1.35
var projectiles: Dictionary={}
var pulses: Dictionary={}
var seen: Dictionary={}
var scope: String=""
var last_sequence:int=-1
var texture: Texture2D
var shader: Shader
var base_material: ShaderMaterial
var report: Dictionary={}
var rejected: Array[String]=[]
var counts: Dictionary={"release":0,"contact":0}
var _enemy_applied: Array[Dictionary]=[]
var flash: StandardMaterial3D
func _ready()->void:
 set_process(false);set_physics_process(false);set_as_top_level(true);transform=Transform3D.IDENTITY;_ensure_resources()
func _ensure_resources()->bool:
 if base_material!=null:return true
 texture=ResourceLoader.load(ATLAS,"Texture2D") as Texture2D
 shader=ResourceLoader.load(SHADER,"Shader") as Shader
 if texture==null or shader==null:return false
 base_material=ShaderMaterial.new();base_material.shader=shader;base_material.set_shader_parameter("atlas",texture)
 flash=StandardMaterial3D.new();flash.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 flash.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;flash.albedo_color=Color(0.92,0.97,1.0,0.55)
 return true
func _key(snapshot:Dictionary)->String:
 var identity:Dictionary=snapshot.get("scope",{})
 return str(identity.get("room_id",""))+":"+str(identity.get("generation",-1))
func _bind(snapshot:Dictionary)->void:
 var next:String=_key(snapshot)
 if next!=scope:reset_visuals();scope=next
func _node()->MeshInstance3D:
 var node=MeshInstance3D.new();node.mesh=ArrayMesh.new();node.material_override=base_material.duplicate();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);return node
func _retire(node:MeshInstance3D)->void:
 node.visible=false;node.mesh=null;node.material_override=null;node.queue_free()
func _quad(vertices:PackedVector3Array,uvs:PackedVector2Array,colors:PackedColorArray,a:Vector3,b:Vector3,c:Vector3,d:Vector3,alpha:float=1.0,u_begin:float=0.0,u_end:float=1.0)->void:
 for row:Array in [[a,Vector2(u_begin,0)],[b,Vector2(u_end,0)],[c,Vector2(u_end,1)],[a,Vector2(u_begin,0)],[c,Vector2(u_end,1)],[d,Vector2(u_begin,1)]]:
  vertices.append(row[0]);uvs.append(row[1]);colors.append(Color(1,1,1,alpha))
func _mesh(node:MeshInstance3D,vertices:PackedVector3Array,uvs:PackedVector2Array,colors:PackedColorArray)->void:
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colors
 var mesh:ArrayMesh=node.mesh as ArrayMesh
 mesh.clear_surfaces();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
func consume(event:Dictionary,snapshot:Dictionary)->void:
 if not _ensure_resources():rejected.append("missing_standard_atlas");return
 _bind(snapshot)
 var identity:Dictionary=snapshot.get("scope",{})
 if event.get("room_id","")!=identity.get("room_id","") or int(event.get("generation",-1))!=int(identity.get("generation",-2)):return
 var sequence:int=int(event.get("sequence",-1))
 if sequence<=last_sequence:return
 last_sequence=sequence
 var kind:String=str(event.get("kind",""))
 if kind not in ["ink_basic_released","ink_basic_contact"] or event.get("source","") not in ["attack","dash_attack"]:return
 var key:String=str(event.get("wave_id","")) if kind=="ink_basic_released" else str(event.get("receipt_id",""))
 key=kind+":"+key
 if seen.has(key):return
 var source_rows:Array=snapshot.get("basics",[]) if kind=="ink_basic_released" else snapshot.get("receipts",[])
 var valid:bool=false
 for row:Dictionary in source_rows:
  if kind=="ink_basic_released":valid=row.get("wave_id","")==event.get("wave_id","") and row.get("cast_id",-1)==event.get("cast_id",-2) and row.get("released_at",-1)==event.get("released_at",-2)
  else:valid=row.get("receipt_id","")==event.get("receipt_id","") and row.get("target_id","")==event.get("target_id","") and row.get("actual_damage",-1)==event.get("actual_damage",-2) and row.get("contact_position",Vector3.INF)==event.get("contact_position",Vector3.ZERO)
  if valid:break
 if not valid:return
 if kind=="ink_basic_contact" and float(event.get("actual_damage",0.0))<=0.0:return
 seen[key]=true
 if seen.size()>256:seen.erase(seen.keys()[0])
 if pulses.size()>=MAX_PULSES:rejected.append("pulse_cap");return
 var direction:Vector3=event.get("front_direction",event.get("direction",Vector3.FORWARD));direction.y=0.0
 if direction.length_squared()<0.001:return
 direction=direction.normalized()
 var origin:Vector3=event.get("front_position",event.get("contact_position",Vector3.ZERO))
 var release:bool=kind=="ink_basic_released"
 pulses[key]={"node":_node(),"release":release,"origin":origin,"direction":direction,"born":float(snapshot.source_time),"world_born":float(snapshot.world_time),"target_id":str(event.get("target_id","")),"receipt":event.duplicate(true)}
 counts["release" if release else "contact"]+=1
func present_source(snapshot:Dictionary)->void:
 if not _ensure_resources():return
 _bind(snapshot)
 var now:float=float(snapshot.get("source_time",0.0));var active:Dictionary={}
 for shot:Dictionary in snapshot.get("basics",[]):
  var id:String=str(shot.wave_id);active[id]=true
  if not projectiles.has(id):
   if projectiles.size()>=MAX_PROJECTILES:rejected.append("projectile_cap");continue
   projectiles[id]=_node()
  var node:MeshInstance3D=projectiles[id];var front:Vector3=shot.front_position+Vector3(0,.70,0);var direction:Vector3=shot.front_direction;var side:Vector3=Vector3(direction.z,0,-direction.x)
  var length:float=minf(TRAIL_METRES,float(shot.front_distance));var half_width:float=float(shot.width)*.5
  var vertices=PackedVector3Array();var uvs=PackedVector2Array();var colors=PackedColorArray()
  var samples:Array=[0.0,.28,.66,1.0];var widths:Array=[.18,1.0,.65,.03]
  for i:int in range(3):
   var a:Vector3=front-direction*length*float(samples[i]);var b:Vector3=front-direction*length*float(samples[i+1])
   _quad(vertices,uvs,colors,a-side*half_width*float(widths[i]),b-side*half_width*float(widths[i+1]),b+side*half_width*float(widths[i+1]),a+side*half_width*float(widths[i]),1.0-float(i)*.12,float(samples[i]),float(samples[i+1]))
  _mesh(node,vertices,uvs,colors)
 for id:String in projectiles.keys():
  if not active.has(id):_retire(projectiles[id]);projectiles.erase(id)
 for id:String in pulses.keys():
  var pulse:Dictionary=pulses[id];var age:float=now-float(pulse.born);var duration:float=SWEEP_SECONDS if pulse.release else IMPACT_SECONDS
  if age<0.0:continue
  if age>=duration:_retire(pulse.node);pulses.erase(id);continue
  var progress:float=age/duration;var node:MeshInstance3D=pulse.node
  node.material_override.set_shader_parameter("fade",pow(1.0-progress,1.2))
  var vertices=PackedVector3Array();var uvs=PackedVector2Array();var colors=PackedColorArray();var direction:Vector3=pulse.direction;var side:Vector3=Vector3(direction.z,0,-direction.x)
  if pulse.release:
   var origin:Vector3=pulse.origin+Vector3(0,.95,0)
   for i:int in range(5):
    var a:float=lerpf(-.65,.65,float(i)/5.0);var b:float=lerpf(-.65,.65,float(i+1)/5.0)
    var da:Vector3=direction*cos(a)+side*sin(a);var db:Vector3=direction*cos(b)+side*sin(b)
    _quad(vertices,uvs,colors,origin+da*.38,origin+db*.38,origin+db*1.08,origin+da*1.08,.92,float(i)/5.0,float(i+1)/5.0)
  else:
   var origin:Vector3=pulse.origin+Vector3(0,.78,0)
   node.material_override.set_shader_parameter("impact",1.0)
   for i:int in range(4):
    var angle:float=float(i)*PI*.5+.3;var arm:Vector3=side*cos(angle)+Vector3.UP*sin(angle);var cross:Vector3=-side*sin(angle)+Vector3.UP*cos(angle)
    _quad(vertices,uvs,colors,origin-arm*.06-cross*.12,origin+arm*(.48+progress*.12)-cross*.01,origin+arm*(.48+progress*.12)+cross*.01,origin-arm*.06+cross*.12,1.0)
  _mesh(node,vertices,uvs,colors)
 report={"projectile_count":projectiles.size(),"pulse_count":pulses.size(),"counts":counts.duplicate(),"rejected":rejected.duplicate(),"source_time":now,"max_trail_metres":TRAIL_METRES,"damage_geometry_changed":false}
func clear_enemy_feedback()->void:
 for item:Dictionary in _enemy_applied:
  if not is_instance_valid(item.view):continue
  item.view.visual.transform=item.base_transform
  for pair:Array in item.overlays:
   if is_instance_valid(pair[0]):pair[0].material_overlay=pair[1]
 _enemy_applied.clear()
func apply_enemy_feedback(views:Dictionary,full:Dictionary)->void:
 var now:float=float(full.world_time)
 for pulse:Dictionary in pulses.values():
  if pulse.release or not views.has(pulse.target_id):continue
  var age:float=now-float(pulse.world_born)
  if age<0.0 or age>=IMPACT_SECONDS:continue
  var view=views[pulse.target_id]
  if not is_instance_valid(view) or view.sample_report.get("dead",true):continue
  if _enemy_applied.any(func(item):return item.view==view):continue
  var item:Dictionary={"view":view,"base_transform":view.visual.transform,"overlays":[]}
  for mesh:MeshInstance3D in view.meshes:
   item.overlays.append([mesh,mesh.material_overlay]);mesh.material_overlay=flash if age<.10 else mesh.material_overlay
  var weight:float=sin(clampf(age/IMPACT_SECONDS,0.0,1.0)*PI)
  view.visual.position+=view.global_basis.inverse()*Vector3(pulse.direction)*(.16*weight)
  view.visual.rotation.x-=.10*weight
  _enemy_applied.append(item)
func reset_visuals()->void:
 clear_enemy_feedback()
 for node:MeshInstance3D in projectiles.values():_retire(node)
 for pulse:Dictionary in pulses.values():_retire(pulse.node)
 projectiles.clear();pulses.clear();seen.clear();scope="";last_sequence=-1;report={}
func _exit_tree()->void:reset_visuals()
