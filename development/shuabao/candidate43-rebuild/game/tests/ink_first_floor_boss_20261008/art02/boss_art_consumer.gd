extends Node3D
## art02 exact-edge contrast and bone-grounded presentation successor.
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
const INK := Color(0.12,0.085,0.055,0.90)
const AMBER := Color(0.88,0.53,0.17,0.78)
const EDGE_WIDTH := 0.095
const INNER_WIDTH := 0.045
var _armor_restore: Array[Dictionary] = []
var _triangle_count: int = 0
var _warning_vertices: Array[Vector3] = []
var _capture_warning: bool = false

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
 _treat_existing_copper()
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
 _triangle_count=0; _warning_vertices.clear(); _capture_warning=false
 _mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 _contact_grounding(actor)
 var pieces: int=0
 if not geometry.is_empty():
  _capture_warning=state=="warning"
  if move=="A": pieces=_sweep(geometry,state,pose)
  elif move=="B": pieces=_fronts(geometry,cast,state,pose)
  elif move=="C": pieces=_stones(geometry,cast,state,pose)
 _capture_warning=false
 if int(snapshot.get("phase",1))==2: _cracks(state,pose)
 # Always emit a degenerate transparent triangle so empty states are valid.
 _triangle(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Color(0,0,0,0))
 _mesh.surface_end()
 report={"status":"candidate_read_only","clip":clip,"pose":pose,"state":state,"move":move,"scope":identity,"cast_id":cast.get("boss_cast_id",""),"geometry":geometry.duplicate(true),"pieces":pieces,"phase":snapshot.get("phase",1),"world_time":frame.get("world_time",0.0),"paused":frame.get("paused",false),"art_revision":"art02","triangles":_triangle_count,"warning_vertex_count":_warning_vertices.size(),"boundary_rule":"all warning vertices lie inside unchanged source shape","grounding":"projected original foot bones; floor-only feathered contact","armor_treatment_count":_armor_restore.size()}
 return report.duplicate(true)

func _triangle(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
 _triangle_count+=1
 for point: Vector3 in [a,b,c]:
  _mesh.surface_set_color(color); _mesh.surface_add_vertex(point)
  if _capture_warning: _warning_vertices.append(point)

func _stroke(a: Vector3,b: Vector3,width: float,color: Color) -> void:
 var across: Vector3=Vector3(-(b-a).z,0.0,(b-a).x).normalized()*width*0.5
 _triangle(a-across,a+across,b+across,color); _triangle(a-across,b+across,b-across,color)

func _ring(center: Vector3,radius: float,width: float,color: Color,start: float=0.0,end: float=TAU) -> void:
 for i in range(32):
  var a: float=lerpf(start,end,float(i)/32.0); var b: float=lerpf(start,end,float(i+1)/32.0)
  _stroke(center+Vector3(cos(a),0,sin(a))*radius,center+Vector3(cos(b),0,sin(b))*radius,width,color)

# Boundary bands grow inward: their outer edge is the exact source boundary.
# The broad amber sector/strip is deliberately low alpha and source-time driven.
func _band(center: Vector3,outer: float,width: float,color: Color,start: float=0.0,end: float=TAU) -> void:
 var inner: float=maxf(0.0,outer-width)
 for i in range(40):
  var a: float=lerpf(start,end,float(i)/40.0); var b: float=lerpf(start,end,float(i+1)/40.0)
  var da:=Vector3(cos(a),0,sin(a)); var db:=Vector3(cos(b),0,sin(b))
  _triangle(center+da*inner,center+da*outer,center+db*outer,color)
  _triangle(center+da*inner,center+db*outer,center+db*inner,color)

func _sector(center: Vector3,radius: float,start: float,end: float,color: Color) -> void:
 for i in range(40):
  var a: float=lerpf(start,end,float(i)/40.0); var b: float=lerpf(start,end,float(i+1)/40.0)
  _triangle(center,center+Vector3(cos(a),0,sin(a))*radius,center+Vector3(cos(b),0,sin(b))*radius,color)

func _quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color) -> void:
 _triangle(a,b,c,color); _triangle(a,c,d,color)

func _sweep(g: Dictionary,state: String,pose: float) -> int:
 if state!="warning" and not (state=="recover" and pose<1.11): return 0
 var origin: Vector3=g.origin+Vector3.UP*0.035
 var facing: Vector3=g.direction; var angle: float=atan2(facing.z,facing.x)
 var half: float=deg_to_rad(float(g.angle))*0.5
 var radius: float=float(g.radius)
 var progress: float=clampf(pose,0.0,1.0)
 _sector(origin,radius,angle-half,angle+half,Color(0.56,0.31,0.09,0.055))
 _sector(origin+Vector3.UP*0.002,radius*progress,angle-half,angle+half,Color(0.84,0.47,0.12,0.075))
 _band(origin+Vector3.UP*0.004,radius,EDGE_WIDTH,INK,angle-half,angle+half)
 _band(origin+Vector3.UP*0.006,radius-EDGE_WIDTH,INNER_WIDTH,AMBER,angle-half,angle+half)
 # Angular strips remain wholly inside the fan, including its tip and corners.
 var border_angle: float=EDGE_WIDTH/radius
 var highlight_angle: float=INNER_WIDTH/radius
 for sign_value: float in [-1.0,1.0]:
  var edge: float=angle+half*sign_value
  var inner: float=edge-border_angle*sign_value
  _sector(origin+Vector3.UP*0.004,radius,minf(edge,inner),maxf(edge,inner),INK)
  var amber_inner: float=inner-highlight_angle*sign_value
  _sector(origin+Vector3.UP*0.006,radius-EDGE_WIDTH,minf(inner,amber_inner),maxf(inner,amber_inner),AMBER)
 return 1

func _lane(origin: Vector3,forward: Vector3,side: Vector3,start: float,end: float,left: float,right: float,color: Color) -> void:
 _quad(origin+forward*start+side*left,origin+forward*end+side*left,origin+forward*end+side*right,origin+forward*start+side*right,color)

func _fronts(g: Dictionary,cast: Dictionary,state: String,pose: float) -> int:
 if state not in ["warning","boss_active"]: return 0
 var count: int=0
 for index in range(g.lines.size()):
  var line: Dictionary=g.lines[index]
  var origin: Vector3=line.origin+Vector3.UP*0.04
  var forward: Vector3=line.direction; var side:=Vector3(-forward.z,0,forward.x)
  var half: float=float(g.width)*0.5
  var length: float=float(line.length)
  if state=="warning":
   _lane(origin,forward,side,0.0,length,-half,half,Color(0.56,0.31,0.09,0.055))
   _lane(origin+Vector3.UP*0.002,forward,side,0.0,length*clampf(pose,0,1),-half,half,Color(0.84,0.47,0.12,0.075))
   for edge: float in [-1.0,1.0]:
    var outside: float=edge*half; var inside: float=edge*(half-EDGE_WIDTH)
    _lane(origin+Vector3.UP*0.004,forward,side,0.0,length,minf(outside,inside),maxf(outside,inside),INK)
    var highlight: float=edge*(half-EDGE_WIDTH-INNER_WIDTH)
    _lane(origin+Vector3.UP*0.006,forward,side,0.0,length,minf(inside,highlight),maxf(inside,highlight),AMBER)
   # End cap makes the finite, wall-clipped source length visible.
   _lane(origin+Vector3.UP*0.004,forward,side,maxf(0,length-EDGE_WIDTH),length,-half,half,INK)
  elif index<cast.get("fronts",[]).size():
   var front: Dictionary=cast.fronts[index]
   if bool(front.stopped): continue
   var distance: float=clampf(float(front.distance),0.0,length)
   # Entire moving lip lies BEHIND the source distance and INSIDE its 1.6m width.
   _lane(origin,forward,side,maxf(0,distance-0.19),distance,-half,half,INK)
   _lane(origin+Vector3.UP*0.005,forward,side,maxf(0,distance-0.12),maxf(0,distance-0.045),-half+0.07,half-0.07,AMBER)
   for shard in range(5):
    var offset: float=lerpf(-half+0.13,half-0.13,float(shard)/4.0)
    var p: Vector3=origin+forward*maxf(0,distance-0.055)+side*offset
    var behind: float=minf(0.19,maxf(0,distance-0.055))
    _triangle(p-side*0.11,p+side*0.11,p-forward*behind+Vector3.UP*(0.22+0.05*float(shard%2)),INK)
    _triangle(p-side*0.045+Vector3.UP*0.015,p+side*0.045+Vector3.UP*0.015,p-forward*minf(0.145,behind)+Vector3.UP*0.17,AMBER)
   _lane(origin-Vector3.UP*0.004,forward,side,maxf(0,distance-0.4),maxf(0,distance-0.19),-half*0.86,half*0.86,Color(0.20,0.15,0.09,0.14))
  count+=1
 return count

func _stones(g: Dictionary,cast: Dictionary,state: String,pose: float) -> int:
 if state not in ["warning","boss_active","recover"]: return 0
 var done: int=int(cast.get("rocks_done",g.points.size() if state=="recover" else 0))
 for index in range(mini(2,g.points.size())):
  var point: Vector3=g.points[index]
  if index<done:
   if state=="boss_active" and float(cast.get("elapsed",0.0))<0.12 or state=="recover" and pose<1.08:
    _band(point+Vector3.UP*0.035,float(g.radius),0.065,Color(0.23,0.15,0.07,0.38))
   continue
  var progress: float=clampf(pose,0,1) if state=="warning" else clampf(float(cast.get("elapsed",0.0))/0.65,0,1)
  var countdown: float=progress
  if index==1:
   countdown=clampf((1.5*progress if state=="warning" else 1.5+float(cast.get("elapsed",0.0)))/2.15,0,1)
  var center: Vector3=point+Vector3.UP*0.03
  var radius: float=float(g.radius)
  # Fixed outer ring = hit footprint. Amber inner arc = each stone's countdown.
  _sector(center,radius,-PI*0.5,TAU-PI*0.5,Color(0.54,0.29,0.08,0.045+0.035*countdown))
  _band(center+Vector3.UP*0.003,radius,EDGE_WIDTH,INK)
  _band(center+Vector3.UP*0.006,radius-EDGE_WIDTH,INNER_WIDTH+0.025,AMBER,-PI*0.5,-PI*0.5+TAU*countdown)
  # Soft compact landing shadow strengthens as the stone approaches contact.
  _soft_shadow(center-Vector3.UP*0.006,Vector3.RIGHT*(0.29+0.18*countdown),Vector3.FORWARD*(0.27+0.16*countdown),0.20+0.20*countdown)
  var height: float=lerpf(2.7,0.32,progress*progress)
  if index==1 and state=="warning": height=2.7+sin(progress*PI)*0.50
  var launch: Vector3=g.origin+Vector3.UP*2.45
  var flight: float=clampf(progress/0.50,0,1) if state=="warning" else 1.0
  var position_at: Vector3=launch.lerp(point+Vector3.UP*height,flight)
  _rocks[index].position=position_at; _rocks[index].rotation=Vector3(progress*2.1,float(index)*1.1+progress,progress*0.7); _rocks[index].visible=true
 return mini(2,g.points.size())

func _soft_shadow(center: Vector3,right: Vector3,forward: Vector3,opacity: float) -> void:
 # Vertex-alpha feather, not a flat opaque polygon or collision-size disc.
 for i in range(20):
  var a: float=TAU*float(i)/20.0; var b: float=TAU*float(i+1)/20.0
  var va: Vector3=center+right*cos(a)+forward*sin(a)
  var vb: Vector3=center+right*cos(b)+forward*sin(b)
  _triangle_count+=1
  for vertex: int in range(3):
   var p: Vector3=[center,va,vb][vertex]
   _mesh.surface_set_color(Color(0.10,0.09,0.07,opacity if vertex==0 else 0.0)); _mesh.surface_add_vertex(p)
   if _capture_warning: _warning_vertices.append(p)

func _contact_grounding(actor: Dictionary) -> void:
 var skeleton: Skeleton3D=_view.skeleton
 var basis: Basis=_view.global_transform.basis.orthonormalized()
 var scale_factor: float=_view.visual.scale.x
 for name: String in ["foot-1","foot1"]:
  var bone: int=skeleton.find_bone(name)
  if bone<0: continue
  var at: Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin
  var floor_y: float=Vector3(actor.get("position",_view.global_position)).y
  var clearance: float=maxf(0.0,at.y-floor_y-0.14*scale_factor)
  at.y=floor_y+0.017
  at-=basis.z*0.10*scale_factor
  _soft_shadow(at,basis.x*0.30*scale_factor,basis.z*0.38*scale_factor,0.42*clampf(1.0-clearance,0.15,1.0))

func _treat_existing_copper() -> void:
 # The old broad ochre islands are authored knee lames, not contact shadows.
 # Keep the existing mesh, skin, silhouette and all four action clips untouched.
 for mesh: MeshInstance3D in _view.meshes:
  if not str(mesh.name).begins_with("ContactFit_copper knee lames and tasset spines"): continue
  for surface in range(mesh.mesh.get_surface_count()):
   _armor_restore.append({"mesh":mesh,"surface":surface,"material":mesh.get_surface_override_material(surface)})
   var material:=StandardMaterial3D.new()
   material.albedo_color=Color(0.26,0.22,0.15,1.0)
   material.roughness=1.0; material.metallic=0.0
   material.specular_mode=BaseMaterial3D.SPECULAR_DISABLED
   mesh.set_surface_override_material(surface,material)

func _exit_tree() -> void:
 for entry: Dictionary in _armor_restore:
  if is_instance_valid(entry.mesh): entry.mesh.set_surface_override_material(int(entry.surface),entry.material)
 _armor_restore.clear()

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
