extends Node3D
## Detached read-only consumer. Call AFTER ordinary view.apply_sample each frame.
## No _process, timers, source setters, damage, collision or authoritative clock.
const Actions = preload("res://tests/ink_first_floor_boss_20261008/art01/boss_actions.glb")
const WARNING := {"A":1.1,"B":1.35,"C":1.5}
const RECOVERY := {"A":1.6,"B":1.7,"C":2.0}
var report: Dictionary = {}
var _view: Node3D
var _draw: MeshInstance3D
var _mesh: ImmediateMesh
var _rocks: Array[MeshInstance3D] = []
var _scope: String = ""
var _last_cast: Dictionary = {}
var _material: StandardMaterial3D

func configure(view: Node3D) -> bool:
 set_process(false); set_physics_process(false)
 _view=view
 if view.get("skeleton")==null or view.get("player")==null: return false
 if view.skeleton.get_bone_count()!=19: return false
 var donor: Node=Actions.instantiate()
 var players: Array[Node]=donor.find_children("*","AnimationPlayer",true,false)
 if players.is_empty(): donor.free(); return false
 var player: AnimationPlayer=players[0] as AnimationPlayer
 var library:=AnimationLibrary.new()
 for name: String in ["boss_A","boss_B","boss_C","boss_phase"]:
  var found: bool=false
  for key: StringName in player.get_animation_list():
   if str(key).get_slice("/",str(key).get_slice_count("/")-1)==name:
    library.add_animation(name,player.get_animation(key).duplicate(true)); found=true; break
  if not found: donor.free(); return false
 if view.player.has_animation_library("boss_art01"): view.player.remove_animation_library("boss_art01")
 view.player.add_animation_library("boss_art01",library)
 donor.free()
 _mesh=ImmediateMesh.new(); _draw=MeshInstance3D.new(); _draw.mesh=_mesh
 _draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 _material=StandardMaterial3D.new(); _material.vertex_color_use_as_albedo=true
 _material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 _material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 _material.cull_mode=BaseMaterial3D.CULL_DISABLED
 _draw.material_override=_material; add_child(_draw)
 for index in range(2):
  var rock:=MeshInstance3D.new(); rock.mesh=_rock_mesh(index)
  var material:=StandardMaterial3D.new(); material.albedo_color=Color("777b68") if index==0 else Color("8b826d")
  material.roughness=1.0; rock.material_override=material; rock.visible=false
  add_child(rock); _rocks.append(rock)
 return true

func clear() -> void:
 if _mesh!=null: _mesh.clear_surfaces()
 for rock: MeshInstance3D in _rocks: rock.visible=false
 _last_cast={}; report={"status":"inactive","effects":0}

func sample(snapshot: Dictionary, actor: Dictionary, frame: Dictionary) -> Dictionary:
 if _view==null or _mesh==null: return {"status":"HOLD_unconfigured"}
 var identity: String="%s|%s|%s|%s"%[snapshot.get("source_instance_id",-1),snapshot.get("run_id",""),snapshot.get("room_id",""),snapshot.get("generation",-1)]
 if identity!=_scope: clear(); _scope=identity
 if not bool(snapshot.get("current",false)) or bool(actor.get("dead",false)) or bool(frame.get("hero_dead",false)) or bool(frame.get("loading",false)) or bool(frame.get("finished",false)):
  clear(); return report.duplicate(true)
 # Coordinates emitted by cast.geometry are world-space. Keep effects in world.
 top_level=true; global_transform=Transform3D.IDENTITY
 _mesh.clear_surfaces()
 for rock: MeshInstance3D in _rocks: rock.visible=false
 var state: String=str(snapshot.get("state",""))
 var cast: Dictionary=snapshot.get("cast",{})
 if not cast.is_empty(): _last_cast=cast.duplicate(true)
 elif state!="recover": _last_cast={}
 var move: String=str(cast.get("move",snapshot.get("last_move","")))
 var clip: String=""
 var pose: float=0.0
 if state=="warning" and WARNING.has(move):
  clip="boss_"+move; pose=clampf(1.0-float(snapshot.timer)/float(WARNING[move]),0.0,1.0)
 elif state=="boss_active" and WARNING.has(move):
  clip="boss_"+move; pose=1.0
 elif state=="recover" and RECOVERY.has(move):
  clip="boss_"+move; pose=1.0+clampf(1.0-float(snapshot.timer)/float(RECOVERY[move]),0.0,1.0)
 elif state=="boss_transition":
  clip="boss_phase"; pose=clampf(1.0-float(snapshot.timer)/1.6,0.0,1.0)
 if not clip.is_empty():
  _view.skeleton.reset_bone_poses()
  _view.player.play("boss_art01/"+clip); _view.player.seek(pose,true)
  _view.skeleton.force_update_all_bone_transforms()
 var geometry: Dictionary=cast.get("geometry",{})
 if geometry.is_empty() and state=="recover": geometry=_last_cast.get("geometry",{})
 _mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 var pieces: int=0
 if not geometry.is_empty():
  if move=="A": pieces=_sweep(geometry,state,pose)
  elif move=="B": pieces=_fronts(geometry,cast,state)
  elif move=="C": pieces=_stones(geometry,cast,state,pose)
 if int(snapshot.get("phase",1))==2: _cracks(state,pose)
 # Always emit a degenerate transparent triangle so empty states are valid.
 _triangle(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Color(0,0,0,0))
 _mesh.surface_end()
 report={"status":"candidate_read_only","clip":clip,"pose":pose,"state":state,"move":move,"scope":identity,"cast_id":cast.get("boss_cast_id",""),"geometry":geometry.duplicate(true),"pieces":pieces,"phase":snapshot.get("phase",1),"world_time":frame.get("world_time",0.0),"paused":frame.get("paused",false)}
 return report.duplicate(true)

func _triangle(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
 for point: Vector3 in [a,b,c]: _mesh.surface_set_color(color); _mesh.surface_add_vertex(point)

func _stroke(a: Vector3,b: Vector3,width: float,color: Color) -> void:
 var across: Vector3=Vector3(-(b-a).z,0.0,(b-a).x).normalized()*width*0.5
 _triangle(a-across,a+across,b+across,color); _triangle(a-across,b+across,b-across,color)

func _ring(center: Vector3,radius: float,width: float,color: Color,start: float=0.0,end: float=TAU) -> void:
 for i in range(32):
  var a: float=lerpf(start,end,float(i)/32.0); var b: float=lerpf(start,end,float(i+1)/32.0)
  _stroke(center+Vector3(cos(a),0,sin(a))*radius,center+Vector3(cos(b),0,sin(b))*radius,width,color)

func _sweep(g: Dictionary,state: String,pose: float) -> int:
 if state!="warning" and not (state=="recover" and pose<1.11): return 0
 var origin: Vector3=g.origin+Vector3.UP*0.035
 var facing: Vector3=g.direction; var angle: float=atan2(facing.z,facing.x)
 var half: float=deg_to_rad(float(g.angle))*0.5
 var color:=Color(0.70,0.60,0.34,0.30) if state=="warning" else Color(0.91,0.80,0.50,0.75)
 _ring(origin,float(g.radius),0.045,color,angle-half,angle+half)
 for sign_value: float in [-1.0,1.0]:
  var direction:=Vector3(cos(angle+half*sign_value),0,sin(angle+half*sign_value))
  _stroke(origin+direction*1.25,origin+direction*float(g.radius),0.035,color)
 return 1

func _fronts(g: Dictionary,cast: Dictionary,state: String) -> int:
 if state not in ["warning","boss_active"]: return 0
 var count: int=0
 for index in range(g.lines.size()):
  var line: Dictionary=g.lines[index]
  var origin: Vector3=line.origin+Vector3.UP*0.04
  var forward: Vector3=line.direction; var side:=Vector3(-forward.z,0,forward.x)
  if state=="warning":
   for edge: float in [-0.5,0.5]:
    for dash in range(8):
     var a: float=float(line.length)*float(dash)/8.0
     var b: float=minf(float(line.length),a+float(line.length)/12.0)
     _stroke(origin+forward*a+side*float(g.width)*edge,origin+forward*b+side*float(g.width)*edge,0.038,Color(0.69,0.62,0.42,0.38))
  elif index<cast.get("fronts",[]).size():
   var front: Dictionary=cast.fronts[index]
   if bool(front.stopped): continue
   var at: Vector3=origin+forward*float(front.distance)
   # Bright leading lip at actual source distance, not a full-lane damage glow.
   _stroke(at-side*float(g.width)*0.5,at+side*float(g.width)*0.5,0.10,Color(0.96,0.85,0.56,0.95))
   for shard in range(5):
    var p: Vector3=at+side*(float(shard)/4.0-0.5)*float(g.width)
    _triangle(p-side*0.10,p+side*0.10,p-forward*0.20+Vector3.UP*(0.17+0.05*float(shard%2)),Color(0.62,0.56,0.42,0.85))
   _stroke(at-forward*minf(0.4,float(front.distance)),at,0.16,Color(0.65,0.59,0.41,0.20))
  count+=1
 return count

func _stones(g: Dictionary,cast: Dictionary,state: String,pose: float) -> int:
 if state not in ["warning","boss_active","recover"]: return 0
 var done: int=int(cast.get("rocks_done",g.points.size() if state=="recover" else 0))
 for index in range(mini(2,g.points.size())):
  var point: Vector3=g.points[index]
  if index<done:
   if state=="boss_active" and float(cast.get("elapsed",0.0))<0.12 or state=="recover" and pose<1.08:
    _ring(point+Vector3.UP*0.035,float(g.radius),0.07,Color(0.78,0.72,0.53,0.50))
   continue
  var progress: float=clampf(pose,0,1) if state=="warning" else clampf(float(cast.get("elapsed",0.0))/0.65,0,1)
  # Both fixed shadows/airborne objects exist from commit; no target re-aim.
  _ring(point+Vector3.UP*0.026,float(g.radius),0.045,Color(0.58,0.49,0.31,0.64))
  _ring(point+Vector3.UP*0.028,0.35+0.18*progress,0.09,Color(0.15,0.17,0.13,0.35))
  var height: float=lerpf(2.7,0.32,progress*progress)
  if index==1 and state=="warning": height=2.7+sin(progress*PI)*0.50
  var launch: Vector3=g.origin+Vector3.UP*2.45
  var flight: float=clampf(progress/0.50,0,1) if state=="warning" else 1.0
  var position_at: Vector3=launch.lerp(point+Vector3.UP*height,flight)
  _rocks[index].position=position_at; _rocks[index].rotation=Vector3(progress*2.1,float(index)*1.1+progress,progress*0.7); _rocks[index].visible=true
 return mini(2,g.points.size())

func _cracks(state: String,pose: float) -> void:
 var skeleton: Skeleton3D=_view.skeleton
 var chest: int=skeleton.find_bone("chest")
 if chest<0: return
 var matrix: Transform3D=skeleton.global_transform*skeleton.get_bone_global_pose(chest)
 var amount: float=clampf(pose*1.8,0,1) if state=="boss_transition" else 1.0
 # Thin ochre seams on existing back frame. No opaque cloud or invulnerability.
 for side: float in [-1.0,1.0]:
  var a: Vector3=matrix*Vector3(side*0.36,0.33,0.31)
  var b: Vector3=matrix*Vector3(side*0.29,0.58,0.33)
  var c: Vector3=matrix*Vector3(side*0.37,0.82,0.32)
  _stroke(a,b,0.026,Color(0.91,0.59,0.24,amount)); _stroke(b,c,0.026,Color(0.91,0.59,0.24,amount))

func _rock_mesh(index: int) -> ArrayMesh:
 var vertices:=PackedVector3Array()
 var points: Array[Vector3]=[Vector3(0,.39,0),Vector3(0,-.28,0),Vector3(.37,0,0),Vector3(0,0,.32),Vector3(-.32,.04,0),Vector3(0,0,-.40)]
 for i in range(4):
  for vertex: int in [0,2+i,2+(i+1)%4,1,2+(i+1)%4,2+i]: vertices.append(points[vertex]*(1.0-0.08*float(index)))
 var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=vertices
 var normals:=PackedVector3Array()
 for i in range(0,vertices.size(),3):
  var normal: Vector3=(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).normalized()
  for _j in range(3): normals.append(normal)
 arrays[Mesh.ARRAY_NORMAL]=normals
 var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); return mesh
