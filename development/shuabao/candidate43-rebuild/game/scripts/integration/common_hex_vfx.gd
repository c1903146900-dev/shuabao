extends Node3D
## Read-only common Hex presentation. Runtime owns every location and lifetime.
## sync(full_snapshot, world_dt, room.views) and combat_event(event, full_snapshot, room.views).
## No collision, gameplay timers, input targeting, stat writes, rewards or Hex activation.
const SURFACE = preload("res://assets/hexes/hex_surface.gdshader")
const ART := "res://assets/xuanlei/vfx/cuicheng/"
const MAX_BATCHES := 48
const MAX_ENTITIES := 96
const JADE := Color(0.48,1.00,0.89,0.85)
const IVORY := Color(1.15,1.09,0.77,0.84)
const REPLAY := Color(0.56,0.79,0.98,0.88)
var entities: Dictionary = {}
var batches: Array[Dictionary] = []
var suppressed_corpses: Dictionary = {}
var evidence: Array[Dictionary] = []
var _captured_corpses: Dictionary = {}
var _textures: Dictionary = {}
var _scenes: Dictionary = {}
var _event_ids: Dictionary = {}
var _encounter := ""
var _age := 0.0
var _state: Dictionary = {}
var _views: Dictionary = {}
var _serial := 0

func reset() -> void:
 for entry in entities.values():
  if is_instance_valid(entry.node): entry.node.queue_free()
 for batch in batches:
  if is_instance_valid(batch.node): batch.node.queue_free()
 for node in _captured_corpses.values():
  if is_instance_valid(node): node.free()
 entities.clear();batches.clear();suppressed_corpses.clear();_captured_corpses.clear();_event_ids.clear()
 _encounter="";_age=0.0

func _scope(state: Dictionary) -> void:
 var common: Dictionary=state.get("common_hexes",{})
 var identity: String="%s/%s/%s"%[str(state.get("run_id",common.get("run_id",""))),str(common.get("room_id",state.get("room_id",""))),str(common.get("generation",state.get("generation",0)))]
 if not _encounter.is_empty() and identity!=_encounter:reset()
 _encounter=identity;_state=state

func sync(state: Dictionary, dt: float, actor_views: Dictionary = {}) -> void:
 _scope(state);_views=actor_views
 var step: float=maxf(0.0,dt)
 _age+=step
 _step_batches(step)
 var common: Dictionary=state.get("common_hexes",{})
 var present: Dictionary={}
 for group in ["souls","projectiles","turrets"]:
  var items: Array=common.get(group,[])
  for i in range(items.size()):
   var data: Dictionary=items[i]
   var kind: String="soul" if group=="souls" else "turret" if group=="turrets" else str(data.get("kind",""))
   if kind not in ["soul","missile","corpse","turret"]:continue
   var key: String=_entity_key(kind,data,i)
   present[key]=true
   if not entities.has(key):
    if entities.size()>=MAX_ENTITIES:continue
    entities[key]=_create_entity(kind,data)
   _update_entity(entities[key],data,step)
 for data in common.get("scheduled",[]):
  if str(data.get("kind",""))!="bombardment":continue
  if not data.has("radius") or float(data.radius)<=0:
   push_error("Common Hex bombardment presentation requires its authoritative positive radius")
   continue
  var at: Vector3=data.get("position",Vector3.ZERO)
  var key: String="warning:%s:%s"%[str(data.get("entity_id",data.get("due",0))),str(at)]
  present[key]=true
  var remaining: float=maxf(0.0,float(data.get("due",0))-float(common.get("time",0)))
  if not entities.has(key):
   var warning: Dictionary=data.duplicate(true)
   warning["radius"]=float(data.radius);warning["left"]=remaining
   entities[key]=_create_entity("warning",warning)
  _update_warning(entities[key],at,remaining,step)
 # Common rescue shields are actual shield records, never inferred from a heal proc.
 var actors: Array=state.get("allies",[]).duplicate()
 if not state.get("hero",{}).is_empty():actors.append(state.hero)
 for actor in actors:
  for shield_id in actor.get("shields",{}):
   var shield: Dictionary=actor.shields[shield_id]
   if str(shield.get("source_hex",shield.get("source","")))!="common_g13" or float(shield.get("amount",0))<=0:continue
   var key: String="shield:%s:%s"%[str(actor.get("actor_id","")),str(shield_id)]
   present[key]=true
   if not entities.has(key):entities[key]=_create_entity("shield",{"position":actor.position})
   var record: Dictionary=entities[key]
   record.node.position=actor.position
   record.node.rotation.y=sin(_age*.7)*.09
   var ratio: float=clampf(float(shield.amount)/maxf(.001,float(shield.get("initial_amount",shield.amount))),0.0,1.0)
   for j in range(record.parts.size()):
    var part: MeshInstance3D=record.parts[j]
    part.visible=float(j)/3.0<ratio
    part.material_override.set_shader_parameter("opacity",.46+.28*ratio)
 for key in entities.keys():
  if present.has(key):continue
  var record: Dictionary=entities[key]
  if is_instance_valid(record.node):record.node.queue_free()
  entities.erase(key)

func combat_event(event: Dictionary, state: Dictionary, actor_views: Dictionary = {}) -> void:
 var kind: String=str(event.get("kind",""))
 var actual_contact:bool=kind=="damage" and str(event.get("source","")).begins_with("common_")
 # Runtime common_hex_damage describes nominal intent after application. Only the
 # simulator's positive committed damage event can produce a contact flash.
 if kind=="common_hex_damage":return
 if actual_contact:
  if float(event.get("amount",0))<=0:return
  event=event.duplicate(true)
  event["target_id"]=str(event.get("target",""))
  event["position"]=event.get("source_position",event.get("position",Vector3.ZERO))
  event["event_id"]="damage:%s:%s"%[str(event.get("room_id","")),str(event.get("sequence",event.get("event_id","")))]
  kind="common_hex_damage"
 elif not kind.begins_with("common_hex_"):return
 _scope(state);_views=actor_views
 var id: String=str(event.get("event_id",""))
 if not id.is_empty():
  if _event_ids.has(id):return
  _event_ids[id]=true
  if _event_ids.size()>1024:_event_ids.erase(_event_ids.keys()[0])
 var source: String=str(event.get("source",""))
 var target: Dictionary=_actor(str(event.get("target_id","")))
 var at: Vector3=event.get("position",target.get("position",state.get("hero",{}).get("position",Vector3.ZERO)))
 match kind:
  "common_hex_execute":
   var target_id: String=str(event.get("target_id",""))
   suppressed_corpses[target_id]=true
   if not _captured_corpses.has(target_id):
    var corpse: Node3D=_clone_body(target_id)
    if corpse:_captured_corpses[target_id]=corpse
   _burst(at+Vector3.UP*.45,JADE,.42,"execute",.48)
  "common_hex_soul_pickup":
   _heal_threads(at+Vector3.UP*.3,JADE,"soul_pickup",.66)
  "common_hex_soul_spawn":
   _burst(at+Vector3.UP*.25,JADE,.44,"soul_spawn",.48)
  "common_hex_area_effect":
   if source=="common_g11":_impact(at,float(event.get("radius",1.6)),Color(.86,.70,.42,.84),"corpse_explosion")
   elif source=="common_g12":_impact(at,float(event.get("radius",2)),IVORY,"bombardment")
   elif source=="common_g26":_impact(at,float(event.get("radius",2)),JADE,"shield_break")
   elif source=="common_g23":_impact(at,float(event.get("radius",2)),Color(.49,.70,.51,.78),"potion_pulse")
  "common_hex_heal":
   if float(event.get("applied_amount",0))<=0:return
   if source=="common_g13":_heal_threads(at,JADE,"rescue_heal",.9)
   elif source=="common_g18":_echo(at,Vector3.FORWARD,true)
  "common_hex_shield":
   if source in ["common_g13","common_g09"]:_heal_threads(at,IVORY,"shield_grant",.6)
  "common_hex_enemy_modifiers":
   if float(event.get("duration",0))>0:
    var hero: Dictionary=state.get("hero",{})
    _beam(hero.get("position",Vector3.ZERO)+Vector3(.34,2.05,0),at+Vector3.UP*.7,JADE,.18,"shrink_ray",.055)
    _burst(at+Vector3.UP*.75,JADE,.32,"shrink_contact",.32)
  "common_hex_damage":
   if source=="common_g16":_burst(target.get("position",at)+Vector3.UP*.65,IVORY,.28,"missile_contact",.38)
   elif source=="common_g28":
    _beam(at+Vector3.UP*.56,target.get("position",at)+Vector3.UP*.65,IVORY,.13,"turret_fire",.045)
    _burst(target.get("position",at)+Vector3.UP*.55,JADE,.25,"turret_contact",.26)
   elif source=="common_g18":_echo(target.get("position",at),event.get("saved_aim",Vector3.FORWARD),false,2.15 if str(target.get("kind",""))=="boss" else 1.65)
  "common_hex_turret_spawn":_deploy(at)

func _entity_key(kind: String, data: Dictionary, index: int) -> String:
 if data.has("entity_id"):return kind+":"+str(data.entity_id)
 if kind=="corpse":return "corpse:"+str(data.get("ignore_id",index))
 # Compatibility fallback only. Current runtime must supply stable entity IDs.
 return "%s:%s:%s:%d"%[kind,str(data.get("cast_id","")),str(data.get("target_id","")),index]

func _actor(id: String) -> Dictionary:
 if id.is_empty():return {}
 var hero: Dictionary=_state.get("hero",{})
 if str(hero.get("actor_id",""))==id:return hero
 for actor in _state.get("enemies",[])+_state.get("allies",[]):
  if str(actor.get("actor_id",""))==id:return actor
 return {}

func _scene(kind: String) -> Node3D:
 var path: String="res://assets/hexes/%s.glb"%kind
 if not _scenes.has(path):
  if not ResourceLoader.exists(path):return null
  _scenes[path]=load(path)
 return _scenes[path].instantiate()

func _create_entity(kind: String, data: Dictionary) -> Dictionary:
 var root:=Node3D.new();root.name="CommonHex_"+kind;add_child(root)
 var record: Dictionary={"node":root,"kind":kind,"age":0.0,"last":data.get("position",Vector3.ZERO),"parts":[],"duration":maxf(.01,float(data.get("left",.6))),"trail_clock":0.0}
 if kind in ["soul","missile","turret"]:
  var model: Node3D=_scene(kind)
  if model:root.add_child(model);record["model"]=model
  if kind=="turret" and model:record["head"]=model.find_child("TurretHead",true,false)
 elif kind=="corpse":
  var actor_id: String=str(data.get("ignore_id",""))
  suppressed_corpses[actor_id]=true
  var model: Node3D=_captured_corpses.get(actor_id,null)
  _captured_corpses.erase(actor_id)
  if not model:model=_clone_body(actor_id,str(data.get("source_kind","")))
  if model:
   root.add_child(model);record["model"]=model
   # Lie the body down along travel, preserving the captured articulated pose.
   var pivot:=Node3D.new();root.add_child(pivot);model.reparent(pivot,false)
   pivot.rotation.x=-PI*.40;pivot.position.y=.48;record["pivot"]=pivot
  else:
   # Missing source identity is an integration error, never disguise it as a sphere.
   push_warning("Common Hex corpse missing source body: "+actor_id)
 elif kind=="warning":
  record["radius"]=float(data.radius)
  var radius: float=record.radius
  for i in range(4):
   var part:=_mesh(_chevron_mesh(.30,.51),_material("basalt_grain",IVORY),root)
   part.position=Vector3(sin(i*PI*.5),0,cos(i*PI*.5))*radius+Vector3.UP*.045
   part.rotation.y=i*PI*.5
   record.parts.append(part)
  var center:=_card(root,"ground_faults",Vector2(radius*.92,radius*.92),Vector3.UP*.036,Color(.44,.51,.43,.32),true)
  record.parts.append(center)
 elif kind=="shield":
  for i in range(3):
   var part:=_mesh(_shield_mesh(),_material("basalt_grain",Color(.58,1.05,.93,.72)),root)
   part.rotation.y=PI/3+float(i)*TAU/3;part.position=Vector3(sin(part.rotation.y),0,cos(part.rotation.y))*1.04+Vector3.UP*.42
   var edge:=_mesh(_shield_edge_mesh(),_material("basalt_grain",Color(.57,1.24,1.09,.78),.20),part)
   edge.position.z=.006
   record.parts.append(part)
 _record(kind,data.get("position",Vector3.ZERO))
 return record

func _update_entity(record: Dictionary, data: Dictionary, dt: float) -> void:
 var node: Node3D=record.node
 var at: Vector3=data.get("position",Vector3.ZERO)
 record.age+=dt
 match str(record.kind):
  "soul":
   node.position=at+Vector3.UP*(.86+.95*exp(-record.age*3.0)+.07*sin(record.age*2.5))
   node.rotation.y=record.age*.48
   node.scale=Vector3.ONE*1.28
   _fade_model(node,clampf(float(data.get("left",10))/.7,0,1))
  "missile":
   node.position=at+Vector3.UP*.72
   var target: Dictionary=_actor(str(data.get("target_id","")))
   var direction: Vector3=at-record.last
   if direction.length_squared()<.00001:direction=target.get("position",at+Vector3.FORWARD)-at
   _face(node,direction)
   record.trail_clock+=dt
   if record.trail_clock>=.055 and dt>0:
    record.trail_clock=0.0
    var back: Vector3=direction.normalized()*.53
    _beam(node.position-back,node.position,JADE,.15,"missile_trail",.045)
  "corpse":
   node.position=at+Vector3.UP*.18
   var direction: Vector3=data.get("direction",Vector3.FORWARD)
   _face(node,direction)
   if record.has("pivot"):record.pivot.rotation.z=sin(record.age*10)*.12
   record.trail_clock+=dt
   if record.trail_clock>=.085 and dt>0:
    record.trail_clock=0.0
    _dust(at,Vector3(-direction.x,0,-direction.z),.5,.32)
  "turret":
   node.position=at
   var target: Dictionary=_nearest(at)
   if not target.is_empty() and is_instance_valid(record.get("head",null)):_face(record.head,target.position-at)
   var deploy: float=clampf(record.age/.20,0,1)
   node.scale=Vector3.ONE*(.82+.18*deploy)
   _fade_model(node,clampf(float(data.get("left",10))/.35,0,1))
 record.last=at

func _update_warning(record: Dictionary, at: Vector3, left: float, dt: float) -> void:
 record.age+=dt;record.node.position=at
 var progress: float=1.0-clampf(left/float(record.duration),0,1)
 for i in range(4):
  var part: MeshInstance3D=record.parts[i]
  part.scale=Vector3.ONE*(.85+.15*progress)
  part.material_override.set_shader_parameter("opacity",.55+.35*progress)
 if left<.17 and not record.get("falling",false):
  record["falling"]=true
  for i in range(3):
   var offset:=Vector3((i-1)*.37,0,.18 if i==1 else -.14)
   _beam(at+offset+Vector3(.18,3.5,0),at+offset+Vector3.UP*.08,IVORY,.20,"bombardment_descent",.07)

func _nearest(at: Vector3) -> Dictionary:
 var found: Dictionary={};var dist: float=INF
 for actor in _state.get("enemies",[]):
  if actor.get("dead",false):continue
  var d: float=at.distance_squared_to(actor.get("position",at))
  if d<dist:dist=d;found=actor
 return found

func _clone_body(actor_id: String, source_kind: String = "") -> Node3D:
 var view: Node=_views.get(actor_id,null)
 if is_instance_valid(view) and is_instance_valid(view.get("visual")):
  var clone: Node3D=view.visual.duplicate(0)
  clone.visible=true
  var original: Skeleton3D=view.get("skeleton")
  var skeleton: Skeleton3D=_find_type(clone,"Skeleton3D")
  if original and skeleton:
   for i in range(mini(original.get_bone_count(),skeleton.get_bone_count())):skeleton.set_bone_pose(i,original.get_bone_pose(i))
  _disable_animation(clone)
  return clone
 var source: Dictionary=_actor(actor_id)
 var kind: String=str(source.get("kind",source_kind))
 if kind.is_empty():return null
 var path: String="res://assets/enemies/siege_brood/%s/%s.glb"%[kind,kind]
 if not ResourceLoader.exists(path):return null
 var clone: Node3D=load(path).instantiate()
 var player: AnimationPlayer=_find_type(clone,"AnimationPlayer")
 if player and player.has_animation("death"):
  player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  player.play("death");player.seek(.12,true);player.pause()
 clone.scale*=float(source.get("common_model_scale",1.0))
 _disable_animation(clone)
 return clone

func _disable_animation(node: Node) -> void:
 if node is AnimationPlayer:node.active=false
 if node is MeshInstance3D:
  node.material_overlay=null
  node.transparency=0.0
 for child in node.get_children():_disable_animation(child)

func _find_type(node: Node, type: String):
 if node.is_class(type):return node
 for child in node.get_children():
  var result=_find_type(child,type)
  if result:return result
 return null

func _fade_model(node: Node, opacity: float) -> void:
 if node is GeometryInstance3D:node.transparency=1.0-opacity
 for child in node.get_children():_fade_model(child,opacity)

func _face(node: Node3D, direction: Vector3) -> void:
 if direction.length_squared()>.00001:node.rotation.y=atan2(-direction.x,-direction.z)

func _texture(name: String) -> Texture2D:
 if not _textures.has(name):_textures[name]=load(ART+name+".png")
 return _textures[name]

func _material(art: String, tint: Color, glow: float = .0) -> ShaderMaterial:
 var material:=ShaderMaterial.new();material.shader=SURFACE
 material.set_shader_parameter("art_texture",_texture(art));material.set_shader_parameter("erosion_texture",_texture("erosion"))
 material.set_shader_parameter("tint",tint);material.set_shader_parameter("glow",glow)
 return material

func _mesh(shape: Mesh, material: Material, parent: Node3D) -> MeshInstance3D:
 var node:=MeshInstance3D.new();node.mesh=shape;node.material_override=material
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(node);return node

func _card(parent: Node3D, art: String, size: Vector2, at: Vector3, tint: Color, flat: bool = false) -> MeshInstance3D:
 var quad:=QuadMesh.new();quad.size=size
 var node:=_mesh(quad,_material(art,tint),parent);node.position=at
 if flat:node.rotation.x=-PI/2
 return node

func _array_mesh(points: Array, faces: Array, uvs: Array = []) -> ArrayMesh:
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for face in faces:
  for j in range(face.size()):
   var index: int=face[j]
   surface.set_uv(uvs[index] if index<uvs.size() else [Vector2.ZERO,Vector2(1,0),Vector2(.5,1)][j%3])
   surface.add_vertex(points[index])
 surface.generate_normals();return surface.commit()

func _chevron_mesh(width: float, length: float) -> ArrayMesh:
 return _array_mesh([Vector3(-width,0,0),Vector3(0,0,-length),Vector3(width,0,0),Vector3(width*.57,0,0),Vector3(0,0,-length*.59),Vector3(-width*.57,0,0)],[[0,1,5],[5,1,4],[4,1,2],[4,2,3]])

func _shield_mesh() -> ArrayMesh:
 # Small curved overlapping lamellae; open gaps keep the hero animation visible.
 var verts: Array=[];var faces: Array=[];var uv: Array=[]
 for i in range(5):
  var x: float=float(i)/4*2-1
  verts.append(Vector3(x*.39,.06+.08*absf(x),-.14*x*x));uv.append(Vector2(float(i)/4,1))
  verts.append(Vector3(x*.39,1.18-.24*absf(x),-.14*x*x));uv.append(Vector2(float(i)/4,0))
  if i<4:faces.append([i*2,i*2+1,i*2+2]);faces.append([i*2+1,i*2+3,i*2+2])
 return _array_mesh(verts,faces,uv)

func _shield_edge_mesh() -> ArrayMesh:
 var outline: Array=[Vector3(-.39,.14,-.14),Vector3(-.39,.94,-.14),Vector3(0,1.18,0),Vector3(.39,.94,-.14),Vector3(.39,.14,-.14),Vector3(0,.06,0)]
 var verts: Array=[];var faces: Array=[]
 var center:=Vector3(0,.59,-.04)
 for i in range(outline.size()):
  verts.append(outline[i]);verts.append(outline[i].lerp(center,.06))
  var next: int=(i+1)%outline.size()
  faces.append([i*2,i*2+1,next*2]);faces.append([i*2+1,next*2+1,next*2])
 return _array_mesh(verts,faces)

func _batch(at: Vector3, life: float, kind: String) -> Dictionary:
 while batches.size()>=MAX_BATCHES:
  var old: Dictionary=batches.pop_front()
  if is_instance_valid(old.node):old.node.queue_free()
 var root:=Node3D.new();add_child(root);root.position=at
 var batch: Dictionary={"node":root,"age":0.0,"life":life,"kind":kind,"parts":[]}
 batches.append(batch);_record(kind,at);return batch

func _record(kind: String, at: Vector3) -> void:
 _serial+=1
 if evidence.size()>=192:evidence.pop_front()
 evidence.append({"kind":kind,"position":at,"serial":_serial})

func _part(batch: Dictionary, node: MeshInstance3D, life: float, velocity: Vector3 = Vector3.ZERO, growth: Vector3 = Vector3.ONE, spin: float = .0, delay: float = .0, gravity: float = .0) -> void:
 batch.parts.append({"node":node,"life":life,"delay":delay,"origin":node.position,"base_scale":node.scale,"rotation":node.rotation,"velocity":velocity,"growth":growth,"spin":spin,"gravity":gravity})
 node.visible=delay<=0

func _step_batches(dt: float) -> void:
 for batch in batches.duplicate():
  batch.age+=dt
  if batch.age>=batch.life:
   batch.node.queue_free();batches.erase(batch);continue
  for part in batch.parts:
   var age: float=float(batch.age)-float(part.delay)
   part.node.visible=age>=0 and age<float(part.life)
   if not part.node.visible:continue
   var t: float=clampf(age/float(part.life),0,1)
   var opacity: float=(minf(1.0,t*9+.2))*(1.0-smoothstep(.35,1.0,t))
   part.node.material_override.set_shader_parameter("opacity",opacity)
   part.node.material_override.set_shader_parameter("erosion",maxf(0.0,(t-.25)*.85))
   part.node.position=part.origin+part.velocity*age-Vector3.UP*float(part.gravity)*age*age*.5
   part.node.scale=part.base_scale.lerp(part.base_scale*part.growth,t)
   part.node.rotation=part.rotation+Vector3(0,0,part.spin*age)

func _beam(a: Vector3, b: Vector3, tint: Color, life: float, kind: String, width: float) -> void:
 var delta: Vector3=b-a
 if delta.length()<.001:return
 var batch: Dictionary=_batch(a,life,kind)
 var direction: Vector3=delta.normalized()
 var side: Vector3=direction.cross(Vector3.UP).normalized()
 if side.length_squared()<.01:side=Vector3.RIGHT
 var verts: Array=[];var uv: Array=[];var faces: Array=[]
 for i in range(6):
  var t: float=float(i)/5
  var center: Vector3=delta*t+Vector3.UP*sin(t*PI)*width*.8
  var w: float=width*(.35+.65*sin(t*PI))
  verts.append(center-side*w);verts.append(center+side*w)
  uv.append(Vector2(t,0));uv.append(Vector2(t,1))
  if i<5:faces.append([i*2,i*2+1,i*2+2]);faces.append([i*2+1,i*2+3,i*2+2])
 var node:=_mesh(_array_mesh(verts,faces,uv),_material("pressure_sheet",tint,.16),batch.node)
 _part(batch,node,life)

func _burst(at: Vector3, tint: Color, size: float, kind: String, life: float) -> void:
 var batch: Dictionary=_batch(at,life,kind)
 for i in range(4):
  var direction:=Vector3(cos(float(i)*TAU/4+.24),.32,sin(float(i)*TAU/4+.24))
  var node:=_card(batch.node,"spark",Vector2(size*.27,size),Vector3.ZERO,tint)
  node.rotation=Vector3(.3,0,float(i)*PI*.5+.2)
  _part(batch,node,life*(.72+.07*i),direction*size*1.4,Vector3(.35,1.25,1),.12)

func _heal_threads(at: Vector3, tint: Color, kind: String, height: float) -> void:
 var batch: Dictionary=_batch(at,.74,kind)
 for i in range(5):
  var angle: float=float(i)*TAU/5+.3
  var node:=_card(batch.node,"pressure_sheet",Vector2(.24,.90),Vector3(cos(angle)*.87,.42,sin(angle)*.87),tint)
  node.rotation.y=-angle
  node.material_override.set_shader_parameter("glow",.30)
  _part(batch,node,.51,Vector3(-cos(angle)*.18,height*1.4,-sin(angle)*.18),Vector3(.35,1.15,1),.0,float(i)*.035)

func _impact(at: Vector3, radius: float, tint: Color, kind: String) -> void:
 var batch: Dictionary=_batch(at,.64,kind)
 var scar:=_card(batch.node,"ground_scar",Vector2(radius*1.32,radius*1.1),Vector3.UP*.042,Color(tint.r*.48,tint.g*.41,tint.b*.30,.60),true)
 _part(batch,scar,.58,Vector3.ZERO,Vector3(1.12,1.12,1.12))
 for i in range(6):
  var angle: float=float(i)*TAU/6+.14
  var dir:=Vector3(cos(angle),0,sin(angle))
  var shard:=_card(batch.node,"contact_spike",Vector2(radius*.30,radius*.70),dir*radius*.22+Vector3.UP*.18,tint)
  shard.rotation.y=-angle;shard.rotation.z=.17*sin(i*2.7)
  _part(batch,shard,.25+.025*(i%3),dir*radius*.42+Vector3.UP*.28,Vector3(.28,1.30,1),.0,.014*(i%2))
  var grit:=_mesh(_debris_mesh(),_material("basalt_grain",Color(.52,.43,.29,.9)),batch.node)
  grit.position=dir*.22+Vector3.UP*.06;grit.scale=Vector3.ONE*(.08+.03*(i%3))
  _part(batch,grit,.47,dir*radius*1.03+Vector3.UP*(1.0+.14*i),Vector3.ONE,.8+i*.3,.0,5.5)
 for i in range(3):_dust(at,Vector3(cos(i*2.09),0,sin(i*2.09)),radius*.55,.52)

func _debris_mesh() -> ArrayMesh:
 return _array_mesh([Vector3(-.6,0,-.3),Vector3(.38,0,-.4),Vector3(.48,0,.3),Vector3(-.3,0,.4),Vector3(-.2,.5,-.12),Vector3(.3,.35,.2)],[[0,1,4],[1,2,5],[1,5,4],[2,3,5],[3,0,4],[3,4,5],[4,5,2],[0,3,2],[0,2,1]])

func _dust(at: Vector3, direction: Vector3, size: float, life: float) -> void:
 var batch: Dictionary=_batch(at,life,"ground_dust")
 var node:=_card(batch.node,"dust_%d"%(_serial%3),Vector2(size*1.6,size*.8),Vector3.UP*.15,Color(.76,.67,.51,.34))
 _part(batch,node,life,direction*.8+Vector3.UP*.14,Vector3(1.6,1.3,1),.16)

func _echo(at: Vector3, direction: Vector3, healing: bool, height:float=1.65) -> void:
 # A short off-body blue after-stroke is visible above packed armor. It remains
 # contact-only, not a repeated cast, damage radius or ground warning.
 var batch: Dictionary=_batch(at,.44,"replay_heal" if healing else "replay_damage")
 _face(batch.node,direction)
 for i in range(2):
  var slash:=_card(batch.node,"pressure_sheet",Vector2(1.28,.25),Vector3(.83+.10*i,height+.24*i,-.1),REPLAY)
  slash.rotation.z=-.35
  slash.material_override.set_shader_parameter("glow",.34)
  _part(batch,slash,.37,Vector3(.28,.25,0),Vector3(1.18,.42,1),.0,.045*i)

func _deploy(at: Vector3) -> void:
 var batch: Dictionary=_batch(at,.36,"turret_deploy")
 for i in range(3):
  var angle: float=i*TAU/3+PI/6
  var node:=_mesh(_chevron_mesh(.12,.20),_material("basalt_grain",JADE),batch.node)
  node.position=Vector3(cos(angle)*.55,.045,sin(angle)*.55);node.rotation.y=-angle+PI/2
  _part(batch,node,.34,Vector3(cos(angle)*.14,0,sin(angle)*.14),Vector3(.55,.55,.55))
