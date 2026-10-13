extends Node3D
## Layered presentation only. No collision, damage, timers or actor translation writes.
## Caller advances world time via step(dt), never _process; hit pause pauses these cues.
const ART := "res://assets/xuanlei/vfx/cuicheng/"
const EARTH = preload("res://assets/enemies/siege_brood/vfx/enemy_surface.gdshader")
const ENERGY = preload("res://assets/enemies/siege_brood/vfx/enemy_energy.gdshader")
const MAX_BATCHES := 36
var batches: Array[Dictionary] = []
var projectile_nodes: Array[Node3D] = []
var hostile_zone_nodes: Array[Node3D] = []
var actor_views: Dictionary = {}
var spore_mesh: ArrayMesh
var tendril_mesh: ArrayMesh
const VAPOR = preload("res://assets/enemies/siege_brood/vfx/spore_vapor.gdshader")
const CORROSIVE = preload("res://assets/enemies/siege_brood/vfx/corrosive_material.gdshader")
var textures: Dictionary = {}
var movement_smear: Node3D
var dash_node: Node3D
var dash_left := 0.0
var dash_id := -1
var dash_direction := Vector3.FORWARD
var cue_serial := 0
var event_actor := ""
var evidence: Array[Dictionary] = []

func _texture(name: String) -> Texture2D:
 if not textures.has(name): textures[name]=load(ART+name+".png")
 return textures[name]
func _material(art: String, tint: Color, energy := false, recolor := false) -> ShaderMaterial:
 var mat:=ShaderMaterial.new()
 mat.shader=ENERGY if energy else EARTH
 mat.set_shader_parameter("art_texture",_texture(art))
 mat.set_shader_parameter("erosion_texture",_texture("erosion"))
 mat.set_shader_parameter("tint",tint)
 mat.set_shader_parameter("palette_mix",1.0 if recolor else 0.0)
 mat.set_shader_parameter("glow",0.28 if energy else 0.0)
 return mat
func _mesh(mesh: Mesh, mat: Material, parent: Node3D) -> MeshInstance3D:
 var node:=MeshInstance3D.new()
 node.mesh=mesh;node.material_override=mat
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(node)
 return node
func _card(parent: Node3D, art: String, size: Vector2, offset: Vector3, tint: Color, energy := false, flat := true, recolor := false) -> MeshInstance3D:
 var quad:=QuadMesh.new();quad.size=size
 var node:=_mesh(quad,_material(art,tint,energy,recolor),parent)
 node.position=offset
 if flat:node.rotation.x=-PI/2
 return node
func _basis(direction: Vector3) -> float:
 return atan2(-direction.x,-direction.z) if direction.length_squared()>.001 else 0.0
func _batch(at: Vector3, direction: Vector3, life: float, kind: String) -> Dictionary:
 while batches.size()>=MAX_BATCHES:
  var old: Dictionary=batches.pop_front()
  if is_instance_valid(old.node):old.node.queue_free()
 var root:=Node3D.new();add_child(root);root.position=at;root.rotation.y=_basis(direction)
 var batch: Dictionary={"node":root,"age":0.0,"life":life,"parts":[],"kind":kind,"actor_id":event_actor}
 batches.append(batch);cue_serial+=1
 if evidence.size()<128:evidence.append({"cue":kind,"position":at,"direction":direction,"life":life,"serial":cue_serial})
 return batch
func _part(batch: Dictionary, node: MeshInstance3D, life: float, delay := 0.0, mode := "fade", velocity := Vector3.ZERO, growth := Vector3.ONE, spin := 0.0) -> void:
 batch.parts.append({"node":node,"mat":node.material_override,"life":life,"delay":delay,"mode":mode,"origin":node.position,"velocity":velocity,"growth":growth,"spin":spin,"base_rotation":node.rotation})
 node.visible=delay<=0
func _ribbon(width: float, length: float, height: float, depth: float) -> ArrayMesh:
 # A bowed, rising impact sheet, with uneven silhouette and authored streak texture.
 var vertices:=PackedVector3Array();var uvs:=PackedVector2Array();var indices:=PackedInt32Array()
 for i in range(25):
  var u:=float(i)/24.0;var x:=u*2-1
  var crown:=sqrt(maxf(0,1-x*x))
  var z: float=-length*(.61+.39*crown)
  var top: float=height*(.38+.62*crown)*(1+.09*sin(u*37.0))
  vertices.append(Vector3(x*width*.5,.04,z+depth));uvs.append(Vector2(u,1))
  vertices.append(Vector3(x*width*.5,top,z));uvs.append(Vector2(u,0))
  if i<24:
   var a:=i*2;indices.append_array(PackedInt32Array([a,a+1,a+2,a+1,a+3,a+2]))
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func _stone(index: int) -> ArrayMesh:
 # Irregular faceted shard. No sphere/box placeholder particles.
 var verts:=PackedVector3Array([Vector3(-.6,0,-.35),Vector3(.34,0,-.46),Vector3(.58,0,.21),Vector3(-.3,0,.48),Vector3(-.42,.38,-.19),Vector3(.23,.56,-.22),Vector3(.31,.29,.19),Vector3(-.23,.28,.31)])
 var faces: Array= [[0,2,1],[0,3,2],[4,5,6],[4,6,7],[0,1,5],[0,5,4],[1,2,6],[1,6,5],[2,3,7],[2,7,6],[3,0,4],[3,4,7]]
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for face in faces:
  for k in range(3):
   st.set_uv([Vector2.ZERO,Vector2(1,0),Vector2(.4,1)][k]);st.add_vertex(verts[face[k]])
 st.generate_normals();return st.commit()
func _debris(batch: Dictionary, count: int, power: float, tint: Color) -> void:
 for i in range(count):
  var a: float=-.95+1.9*float(i)/maxi(1,count-1)
  var side:=sin(a);var front:=cos(a)
  var n:=_mesh(_stone(i),_material("basalt_grain",tint),batch.node)
  n.position=Vector3((.64 if str(batch.kind)=="impact_elite" else 0.0)+side*.32,.035,-.92-front*.15)
  var size: float=(.11+.08*fposmod(float(i)*.618,1))*power
  n.scale=Vector3(size*1.4,size*.6,size)
  _part(batch,n,.43+.08*(i%3),.012*(i%2),"ballistic",Vector3(side*(1.6+.2*i),1.2+.25*(i%3),-front*(1.5+.2*i))*power,Vector3.ONE,.7+i*.39)
func _dust(batch: Dictionary, count: int, width: float, forward: float, scale_value: float) -> void:
 for i in range(count):
  var side: float=(float(i)/maxi(1,count-1)*2-1)
  var n:=_card(batch.node,"dust_%d"%(i%3),Vector2(1.12,.78)*scale_value,Vector3(side*width*.29,.18,-forward*(.55+.25*(1-absf(side)))),Color(1.12,1.01,.86,.88),false,false)
  n.rotation.z=.1*sin(i*8.13)
  _part(batch,n,.39+.08*(i%3),.025+.018*(i%2),"dust",Vector3(side*.55,.33,-.3)*scale_value,Vector3(1.75,1.55,1.0),.12*side)
func play_event(event: Dictionary, enemy_kind := "") -> void:
 var kind: String=enemy_kind if not enemy_kind.is_empty() else str(event.get("enemy_kind","minion"))
 var at: Vector3=event.get("position",Vector3.ZERO)
 var direction: Vector3=event.get("direction",Vector3.FORWARD)
 var e: String=str(event.get("kind",""))
 event_actor=str(event.get("actor_id",event.get("target","")))
 if e in ["enemy_impact","enemy_shot","enemy_pounce_started","enemy_attack_cancelled","kill"]:cancel_actor(event_actor)
 if e=="enemy_warning":_anticipation(at,direction,kind,float(event.get("duration",.7)))
 elif e=="enemy_impact":_impact(at,direction,kind,bool(event.get("hit",false)),float(event.get("radius",3.25)),float(event.get("angle",80.0)))
 elif e=="enemy_shot":
  var source: Vector3=actor_views[event_actor].cast_socket_world() if actor_views.has(event_actor) and is_instance_valid(actor_views[event_actor]) else at+Vector3.UP*1.35
  _role_shot(source,direction,str(event.get("projectile_type","bolt")))
 elif e in ["enemy_lob","enemy_hex_shot"]:_shot(at,direction)
 elif e=="enemy_pounce_started":
  var batch:=_batch(at,direction,.5,"pounce_takeoff")
  _dust(batch,3,1.0,.05,.7)
 elif e=="dash_attack_started":
  _end_dash();dash_id=int(event.get("dash_id",-1));dash_direction=direction
  dash_left=float(event.get("active_duration",.18));dash_node=Node3D.new();add_child(dash_node);dash_node.position=at;dash_node.rotation.y=_basis(direction)
  _mesh(_ribbon(1.70,1.55,.48,.30),_material("pressure_sheet",Color(.42,1.4,1.8,.68),true,true),dash_node)
  _card(dash_node,"contact_ground",Vector2(.85,1.1),Vector3(0,.055,-.68),Color(.3,1.0,1.3,.38),true,true,true)
 elif e=="dash_attack_hit":
  var positions: Array=event.get("target_positions",[])
  if positions.is_empty():positions=[at+direction*.9]
  for pos in positions:
   var batch:=_batch(pos,direction,.19,"dash_contact")
   var n:=_card(batch.node,"contact_spike",Vector2(.66,.9),Vector3(0,.55,0),Color(.6,1.3,1.6,.78),true,false,true)
   _part(batch,n,.105,0.0,"snap",Vector3.ZERO,Vector3(1.45,1.15,1))
 elif e=="dash_attack_ended":_end_dash()
func _anticipation(at: Vector3, direction: Vector3, kind: String, duration: float) -> void:
 var batch:=_batch(at,direction,duration,"warning_"+kind)
 # Charge belongs to the weapon/body, never a blanket floor warning footprint.
 if kind in ["elite","boss","armored"]:
  var dust:=_card(batch.node,"dust_1",Vector2(.75,.32),Vector3(0,.09,.07),Color(.72,.61,.48,.25),false,false)
  _part(batch,dust,duration,0.0,"charge")
 elif kind in ["ranged","support","pitcher"]:
  var tone:=Color(.43,.97,.71,.60) if kind=="support" else Color(1.13,.59,.14,.60) if kind=="pitcher" else Color(.82,.5,1.3,.60)
  var offset:=Vector3(0,1.40,-.26) if kind=="support" else Vector3(.64,1.57,-.3) if kind=="pitcher" else Vector3(0,1.35,-.95)
  batch["socket_anchored"]=true
  var focus:=_card(batch.node,"contact_spike",Vector2(.45,.56),offset,tone,true,false,true)
  focus.name="SocketCharge"
  _part(batch,focus,duration,0.0,"charge")
func _impact(at: Vector3, direction: Vector3, kind: String, hit: bool, attack_range := 3.25, attack_angle := 80.0) -> void:
 if kind=="pouncer":
  _pounce_contact(at,direction,hit)
  return
 var heavy: bool=kind in ["elite","boss","armored"]
 var boss: bool=kind=="boss"
 var power: float=1.5 if boss else 1.2 if kind=="elite" else .9 if kind=="armored" else .76
 var width: float=2.0*sin(deg_to_rad(attack_angle*.5))*attack_range
 var length: float=attack_range
 var batch:=_batch(at,direction,.85,"impact_"+kind)
 var tone:=Color(1.58,.52,.18,.87 if hit else .66)
 var impact_time: float=.09 if kind in ["elite","boss"] else .115
 var contact_size:=Vector2(.70,.82) if kind in ["elite","boss"] else Vector2(.85,.86)
 var contact_x: float=.64 if kind=="elite" else .35 if kind=="boss" else 0.0
 var flash:=_card(batch.node,"contact_spike",contact_size*maxf(.9,power),Vector3(contact_x,.42,-.88),Color(1.65,1.13,.77,.96),true,false,true)
 _part(batch,flash,impact_time,0.0,"enemy_contact",Vector3.ZERO,Vector3(1.2,1.2,1))
 var ground:=_card(batch.node,"contact_ground",Vector2(1.9,1.4)*maxf(.88,power),Vector3(contact_x,.07,-.78),tone,true,true,true)
 _part(batch,ground,.19,0.0,"enemy_contact",Vector3.ZERO,Vector3(1.45,1.4,1))
 var wave_height: float=.32 if kind=="minion" else .38 if kind=="armored" else .66*power
 var wave_depth: float=.20 if kind=="minion" else .62 if kind=="armored" else .48*power
 var sheet:=_mesh(_ribbon(width,length,wave_height,wave_depth),_material("pressure_sheet",tone,true,true),batch.node)
 _part(batch,sheet,.17 if kind=="minion" else .285,.006,"enemy_wave",Vector3.ZERO,Vector3.ONE)
 if kind=="minion":
  sheet.rotation.z=.50
  sheet.rotation.y=-.24
 var scar:=_card(batch.node,"ground_scar",Vector2(width*.66,length*.65),Vector3(0,.041,-length*.48),Color(.37,.22,.18,.55))
 _part(batch,scar,.70,0.0,"scar")
 _dust(batch,5 if heavy else 3,width,length,maxf(.86,power))
 _debris(batch,5 if heavy else 2,power,Color(.65,.58,.49,.9))
func _pounce_contact(at: Vector3, direction: Vector3, hit: bool) -> void:
 # Pounce damage is travelling body contact. Landing has NO separate AoE/range cue.
 var batch:=_batch(at,direction,.52,"pounce_body_hit" if hit else "pounce_landing_miss")
 if hit:
  var core:=_card(batch.node,"contact_spike",Vector2(.95,.85),Vector3(0,.58,-.80),Color(1.6,1.05,.67,.94),true,false,true)
  _part(batch,core,.11,0.0,"enemy_contact")
 var scratch:=_card(batch.node,"ground_faults",Vector2(.92,.74),Vector3(0,.05,-.10),Color(.75,.33,.14,.5 if hit else .23),false,true,true)
 _part(batch,scratch,.30,0.0,"scar")
 for side in [-1.0,1.0]:
  var dust:=_card(batch.node,"dust_1" if side<0 else "dust_2",Vector2(.66,.48),Vector3(side*.45,.16,.02),Color(1.03,.93,.8,.86),false,false)
  _part(batch,dust,.34,.012,"dust",Vector3(side*.32,.20,.05),Vector3(1.4,1.3,1),side*.12)
  var stone:=_mesh(_stone(0),_material("basalt_grain",Color(.68,.60,.50,.8)),batch.node)
  stone.position=Vector3(side*.26,.03,.02);stone.scale=Vector3(.13,.08,.12)
  _part(batch,stone,.39,0.0,"ballistic",Vector3(side*.55,.90,.08),Vector3.ONE,side*.8)
func _shot(at: Vector3, direction: Vector3) -> void:
 var batch:=_batch(at,direction,.33,"ranged_muzzle")
 var flare:=_card(batch.node,"contact_spike",Vector2(.9,1.06),Vector3(0,0,-.12),Color(1.02,.68,1.8,.96),true,false,true)
 _part(batch,flare,.13,0.0,"enemy_contact",Vector3.ZERO,Vector3(1.45,1.4,1))
 var n:=_mesh(_ribbon(.94,1.25,.66,.25),_material("pressure_sheet",Color(.95,.62,1.6,.8),true,true),batch.node)
 n.position.y=0.0;_part(batch,n,.25,0.0,"enemy_wave")
func _role_shot(at: Vector3, direction: Vector3, type: String) -> void:
 if type=="bolt":_shot(at,direction);return
 var batch:=_batch(at,direction,.28,"throw_release" if type=="lob" else "curse_release")
 var tone:=Color(1.20,.61,.16,.84) if type=="lob" else Color(.47,1.05,.76,.82)
 var n:=_card(batch.node,"spark",Vector2(.48,.70),Vector3(0,0,-.05),tone,true,false,true)
 _part(batch,n,.12,0.0,"snap",Vector3.ZERO,Vector3(1.4,1.3,1))
 if type=="lob":_dust(batch,2,.8,.1,.55)
func sync_hero(state: Dictionary) -> void:
 var moving_dash: float=float(state.get("dash_left",0.0))
 if moving_dash>0:
  if not is_instance_valid(movement_smear):
   movement_smear=Node3D.new();add_child(movement_smear)
   _card(movement_smear,"contact_spike",Vector2(.66,1.7),Vector3(0,.075,.62),Color(.30,.90,1.13,.37),true,true,true)
   _card(movement_smear,"dust_2",Vector2(.92,1.3),Vector3(0,.048,.72),Color(.67,.86,.91,.45),false,true,true)
  movement_smear.position=state.get("position",Vector3.ZERO)
  movement_smear.rotation.y=_basis(state.get("dash_direction",Vector3.FORWARD))
  movement_smear.scale=Vector3.ONE*clampf(moving_dash/.06,.05,1.0)
 elif is_instance_valid(movement_smear):
  movement_smear.queue_free();movement_smear=null
 if is_instance_valid(dash_node):dash_node.position=state.get("position",dash_node.position);dash_node.rotation.y=_basis(dash_direction)
func _end_dash() -> void:
 if is_instance_valid(dash_node):dash_node.queue_free()
 dash_node=null;dash_left=0.0;dash_id=-1
func _projectile_geometry(node: Node3D) -> void:
 var bolt:=Node3D.new();bolt.name="Bolt";node.add_child(bolt)
 var core:=_mesh(_flying_spear(),_solid_material(Color("b783ff"),.26,1.2),bolt)
 var head:=_card(bolt,"spark",Vector2(.47,.68),Vector3(0,0,-.1),Color(1.30,.90,1.70,.9),true,false,true)
 head.rotation.x=-.45
 _card(bolt,"contact_spike",Vector2(.45,1.55),Vector3(0,-.02,.51),Color(.73,.39,1.25,.70),true,true,true)
 var lob:=Node3D.new();lob.name="Lob";node.add_child(lob)
 var pottery:=CylinderMesh.new();pottery.top_radius=.23;pottery.bottom_radius=.16;pottery.height=.40;pottery.radial_segments=7
 var clay:=StandardMaterial3D.new();clay.albedo_color=Color("875029");clay.roughness=.82
 _mesh(pottery,clay,lob)
 var rim:=TorusMesh.new();rim.inner_radius=.19;rim.outer_radius=.24;rim.rings=10;rim.ring_segments=4
 var metal:=StandardMaterial3D.new();metal.albedo_color=Color("c69242");metal.metallic=.65
 var lip:=_mesh(rim,metal,lob);lip.position.y=.20
 var ember:=_card(lob,"spark",Vector2(.25,.42),Vector3(0,.29,0),Color(1.35,.68,.13,.86),true,false,true)
 ember.rotation.y=.6
 var hex:=Node3D.new();hex.name="Hex";node.add_child(hex)
 # A turning broken seal is visually different from the shooter's needle bolt.
 var hex_core:=_mesh(_flying_spear(),_solid_material(Color("72dda9"),.3,.75),hex)
 hex_core.scale=Vector3(1.25,1.5,.56);hex_core.rotation.x=PI*.5
 for i in range(4):
  var shard:=_mesh(_stone(i),_solid_material(Color("c8e58c"),.45,.6),hex)
  shard.position=Vector3(cos(i*TAU/4)*.25,0,sin(i*TAU/4)*.25)
  shard.scale=Vector3(.24,.25,.20);shard.rotation.z=i*TAU/4
 _card(hex,"spark",Vector2(.63,.72),Vector3.ZERO,Color(.54,1.2,.88,.60),true,false,true)
 _card(hex,"contact_spike",Vector2(.50,.86),Vector3(0,-.02,.37),Color(.3,.83,.59,.52),true,true,true)
func sync_projectiles(projectiles: Array) -> void:
 while projectile_nodes.size()<projectiles.size():
  var n:=Node3D.new();add_child(n);projectile_nodes.append(n);_projectile_geometry(n)
 for i in range(projectile_nodes.size()):
  var node: Node3D=projectile_nodes[i];node.visible=i<projectiles.size()
  if not node.visible:continue
  var projectile: Dictionary=projectiles[i]
  var type: String=str(projectile.get("type","bolt"))
  var progress: float=clampf(1.0-float(projectile.get("left",1.0))/maxf(.001,float(projectile.get("duration",1.0))),0,1)
  var visual_height: float=float(projectile.get("height",0.0))+(1.65*(1.0-progress)+.15 if type=="lob" else 1.46 if type=="hex_bolt" else 1.32)
  node.position=projectile.position+Vector3.UP*visual_height
  node.rotation.y=_basis(projectile.get("direction",Vector3.FORWARD))
  node.get_node("Bolt").visible=type=="bolt"
  node.get_node("Lob").visible=type=="lob"
  node.get_node("Hex").visible=type=="hex_bolt"
  var phase: float=progress*float(projectile.get("duration",1.0))
  node.get_node("Lob").rotation=Vector3(phase*7,phase*5,phase*3)
  node.get_node("Hex").rotation.y=phase*9
func _solid_material(color: Color, roughness: float, glow := 0.0) -> StandardMaterial3D:
 var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=roughness;mat.metallic=.2
 if glow>0:mat.emission_enabled=true;mat.emission=color;mat.emission_energy_multiplier=glow
 return mat
func _flying_spear() -> ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var points: Array[Vector3]=[Vector3(0,0,-.56),Vector3(-.18,0,.10),Vector3(0,.12,.15),Vector3(.18,0,.10),Vector3(0,-.12,.15),Vector3(0,0,.44)]
 for face in [[0,1,2],[0,2,3],[0,3,4],[0,4,1],[5,2,1],[5,3,2],[5,4,3],[5,1,4]]:
  for index in [face[2],face[1],face[0]]:st.add_vertex(points[index])
 st.generate_normals();return st.commit()
func _spore_form() -> ArrayMesh:
 # Broad organic cap on a narrow bent stalk; deliberately not a closed pebble.
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_smooth_group(0)
 var levels: Array=[Vector2(.17,0.0),Vector2(.12,.34),Vector2(.17,.67),Vector2(.87,.77),Vector2(1.0,.90),Vector2(.75,1.12),Vector2(.25,1.27)]
 var points: Array[Vector3]=[]
 var sides:=18
 for ring in levels.size():
  for side in range(sides):
   var a: float=side*TAU/sides
   var ripple: float=1.0+.13*sin(a*3.0+.6)+.055*cos(a*7.0)
   var radius: float=levels[ring].x*ripple
   var lean: float=sin(levels[ring].y*1.5)*.23
   points.append(Vector3(cos(a)*radius+lean,levels[ring].y*(1.0+.075*sin(a*2.0)),sin(a)*radius*.78))
 for ring in range(levels.size()-1):
  var tone:=Color(.42,.49,.37) if ring<3 else Color(.72,.80,.63) if ring==3 else Color(1,1,1)
  st.set_color(tone)
  for side in range(sides):
   var n: int=(side+1)%sides
   for index in [ring*sides+side,ring*sides+n,(ring+1)*sides+side,ring*sides+n,(ring+1)*sides+n,(ring+1)*sides+side]:
    st.add_vertex(points[index])
 st.set_color(Color(.88,.93,.81))
 for side in range(sides):
  for vertex in [Vector3(.22,1.31,0),points[6*sides+side],points[6*sides+(side+1)%sides]]:st.add_vertex(vertex)
 st.generate_normals();return st.commit()
func _tendril_form() -> ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_smooth_group(0)
 var points: Array[Vector3]=[]
 var sections:=8;var sides:=6
 for step in range(sections):
  var t: float=float(step)/(sections-1)
  var center:=Vector3(.27*sin(t*2.5),t*.9,.17*(1-cos(t*2.9)))
  var radius: float=lerpf(.075,.017,t)
  for side in range(sides):
   var a: float=side*TAU/sides
   points.append(center+Vector3(cos(a)*radius,0,sin(a)*radius))
 for step in range(sections-1):
  for side in range(sides):
   var n: int=(side+1)%sides
   for index in [step*sides+side,step*sides+n,(step+1)*sides+side,step*sides+n,(step+1)*sides+n,(step+1)*sides+side]:st.add_vertex(points[index])
 st.generate_normals();return st.commit()
func _hurt_perimeter() -> ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(72):
  if i%9 in [0,1]:continue
  var a: float=i*TAU/72;var b: float=(i+1)*TAU/72
  var alpha: float=.24+.22*fposmod(float(i)*.618,1.0)
  st.set_color(Color(.58,.56,.29,alpha))
  for v in [Vector3(cos(a),0,sin(a)),Vector3(cos(b),0,sin(b)),Vector3(cos(a)*.982,0,sin(a)*.982),Vector3(cos(b),0,sin(b)),Vector3(cos(b)*.982,0,sin(b)*.982),Vector3(cos(a)*.982,0,sin(a)*.982)]:st.add_vertex(v)
 st.generate_normals();return st.commit()
func _make_hostile_material() -> Node3D:
 var root:=Node3D.new();add_child(root)
 var card:=QuadMesh.new();card.size=Vector2(2,2)
 var mat:=ShaderMaterial.new();mat.shader=CORROSIVE
 var pool:=_mesh(card,mat,root);pool.name="Pool";pool.rotation.x=-PI/2
 if spore_mesh==null:spore_mesh=_spore_form()
 var spores:=MultiMeshInstance3D.new();spores.name="SporeVolume";root.add_child(spores)
 var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=spore_mesh;multi.instance_count=9
 spores.multimesh=multi
 var wet:=_solid_material(Color.WHITE,.42,0.0);wet.metallic=0.0;wet.vertex_color_use_as_albedo=true;spores.material_override=wet
 var transforms: Array[Transform3D]=[]
 for i in range(9):
  var a: float=i*2.399963
  var radius: float=.63*sqrt(float(i)/9.0)
  var size: float=.16+.075*fposmod(i*.618,1.0)
  var at:=Vector3(cos(a)*radius,.018,sin(a)*radius)
  var basis:=Basis(Vector3.UP,a).scaled(Vector3(size,.21+.10*fposmod(i*.414,1),size))
  var transform:=Transform3D(basis,at);transforms.append(transform);multi.set_instance_transform(i,transform)
  multi.set_instance_color(i,Color("70856b").lerp(Color("40533e"),fposmod(i*.618,1.0)))
 root.set_meta("spore_transforms",transforms)
 spores.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 if tendril_mesh==null:tendril_mesh=_tendril_form()
 var stalks:=MultiMeshInstance3D.new();stalks.name="Tendrils";root.add_child(stalks)
 var stem_multi:=MultiMesh.new();stem_multi.transform_format=MultiMesh.TRANSFORM_3D;stem_multi.mesh=tendril_mesh;stem_multi.instance_count=4;stalks.multimesh=stem_multi
 stalks.material_override=_solid_material(Color("354d3a"),.58,0.0);stalks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for i in range(4):
  var angle: float=.4+i*2.25
  stem_multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,angle).scaled(Vector3(.55,.42+.12*(i%2),.55)),Vector3(cos(angle)*.55,.01,sin(angle)*.55)))
 var vapor:=MultiMeshInstance3D.new();vapor.name="Vapor";root.add_child(vapor)
 var mist_multi:=MultiMesh.new();mist_multi.transform_format=MultiMesh.TRANSFORM_3D
 var mist_card:=QuadMesh.new();mist_card.size=Vector2(1,1);mist_multi.mesh=mist_card;mist_multi.instance_count=3;vapor.multimesh=mist_multi
 var mist_mat:=ShaderMaterial.new();mist_mat.shader=VAPOR;vapor.material_override=mist_mat;vapor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var edge_mat:=_solid_material(Color.WHITE,.48);edge_mat.vertex_color_use_as_albedo=true;edge_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;edge_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;edge_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 var edge:=_mesh(_hurt_perimeter(),edge_mat,root);edge.name="ActualHurtRadius";edge.position.y=.012
 return root
func sync_hostile_zones(zones: Array) -> void:
 var visible_zones: Array=[]
 for zone in zones:
  if str(zone.get("team",""))=="enemy" and str(zone.get("material",""))=="corrosive_ink":visible_zones.append(zone)
 while hostile_zone_nodes.size()<visible_zones.size():hostile_zone_nodes.append(_make_hostile_material())
 for i in range(hostile_zone_nodes.size()):
  var node: Node3D=hostile_zone_nodes[i];node.visible=i<visible_zones.size()
  if not node.visible:continue
  var zone: Dictionary=visible_zones[i]
  var radius: float=float(zone.get("radius",1.45))
  node.position=zone.get("position",zone.get("center",Vector3.ZERO))+Vector3(0,.028,0)
  node.scale=Vector3(radius,1,radius)
  var duration: float=maxf(.001,float(zone.get("duration",2.4)))
  var left: float=float(zone.get("left",duration));var age: float=duration-left
  var pool: MeshInstance3D=node.get_node("Pool")
  pool.material_override.set_shader_parameter("remaining",left/duration)
  pool.material_override.set_shader_parameter("age",age)
  var spores: MultiMeshInstance3D=node.get_node("SporeVolume")
  var original: Array=node.get_meta("spore_transforms")
  for j in range(original.size()):
   var tr: Transform3D=original[j]
   var swell: float=(.82+.18*sin(age*3.0+j*.71))*smoothstep(0.0,.12,age)*smoothstep(0.0,.20,left)
   tr.basis=tr.basis.scaled(Vector3(1,maxf(.15,swell),1));spores.multimesh.set_instance_transform(j,tr)
  var vapor: MultiMeshInstance3D=node.get_node("Vapor")
  vapor.material_override.set_shader_parameter("age",age);vapor.material_override.set_shader_parameter("remaining",left/duration)
  for j in range(3):
   var phase: float=fposmod(age*.45+j*.31,1.0)
   var a: float=j*2.4+age*.12
   var at:=Vector3(cos(a)*.27,.26+phase*.40,sin(a)*.27)
   vapor.multimesh.set_instance_transform(j,Transform3D(Basis.IDENTITY.scaled(Vector3(.62+phase*.20,.50+phase*.20,1)),at))
func sync_actor_views(views: Dictionary) -> void:
 actor_views=views
 for batch in batches:
  if not bool(batch.get("socket_anchored",false)):continue
  var id: String=str(batch.get("actor_id",""))
  if not views.has(id) or not is_instance_valid(views[id]):continue
  if not views[id].has_method("cast_socket_world"):continue
  batch.node.global_position=views[id].cast_socket_world()
  var focus: Node3D=batch.node.get_node_or_null("SocketCharge")
  if focus:focus.position=Vector3.ZERO
func sync_enemies(enemies: Array) -> void:
 var by_id: Dictionary={}
 for actor in enemies:by_id[str(actor.get("actor_id",""))]=actor
 for i in range(batches.size()-1,-1,-1):
  var b: Dictionary=batches[i]
  if not str(b.kind).begins_with("warning_") or str(b.actor_id).is_empty():continue
  var actor: Dictionary=by_id.get(str(b.actor_id),{})
  if actor.is_empty() or bool(actor.get("dead",false)) or str(actor.get("state",""))!="warning":
   if is_instance_valid(b.node):b.node.queue_free()
   batches.remove_at(i);continue
  b.node.position=actor.position
  b.node.rotation.y=_basis(actor.get("aim",Vector3.FORWARD))
  b.life=maxf(.001,float(actor.get("warning_duration",b.life)))
  b.age=clampf(float(actor.get("warning_progress",0.0)),0,.999999)*b.life
  b["locked_warning"]=true
func step(dt: float) -> void:
 if dt<=0:return
 if dash_left>0:
  dash_left=maxf(0,dash_left-dt)
  if dash_left<=0:_end_dash()
 for i in range(batches.size()-1,-1,-1):
  var b: Dictionary=batches[i]
  if not bool(b.get("locked_warning",false)):b.age+=dt
  if b.age>=b.life:
   if is_instance_valid(b.node):b.node.queue_free()
   batches.remove_at(i);continue
  for part in b.parts:
   var age: float=b.age-part.delay
   var t: float=clampf(age/part.life,0,1)
   var node: MeshInstance3D=part.node
   node.visible=age>=0 and t<1
   if not node.visible:continue
   var opacity: float=1.0-t
   var erode: float=maxf(0,(t-.20)/.8)*.92
   var mode: String=part.mode
   if mode=="charge":opacity=.10+.60*t*t;erode=0;node.scale=Vector3.ONE*(.55+.45*t)
   elif mode=="enemy_wave":
    opacity=1.0-smoothstep(.50,1.0,t)
    erode=maxf(0,(t-.34)/.66)*.90
    node.scale=Vector3.ONE*lerpf(.38,1.0,1.0-pow(1.0-minf(1,t/.36),3))
   elif mode=="wave":
    opacity=(1.0-smoothstep(.45,1.0,t))*.80
    node.scale=Vector3.ONE*lerpf(.32,1.0,1.0-pow(1.0-minf(1,t/.40),3))
   elif mode=="ballistic":
    node.position=part.origin+part.velocity*age+Vector3(0,-3.8*age*age,0)
    node.position.y=maxf(.025,node.position.y)
    node.rotation=part.base_rotation+Vector3(1,.3,.5)*part.spin*age*5
    opacity=1.0-smoothstep(.62,1.0,t);erode=maxf(0,(t-.75)*3)
   else:
    node.position=part.origin+part.velocity*age
    node.scale=Vector3.ONE.lerp(part.growth,t)
    node.rotation.z=part.base_rotation.z+part.spin*age
    if mode=="dust":opacity=sin(PI*minf(1,t*1.15))*.93;erode=t*.72
    elif mode=="enemy_contact":opacity=1.0-smoothstep(.24,1.0,t);erode=maxf(0,(t-.55)/.45)*.75
    elif mode=="snap":opacity=pow(1.0-t,1.8)
    elif mode=="scar":opacity=(1-smoothstep(.20,1,t))*.65;erode=t*.8
   part.mat.set_shader_parameter("opacity",opacity)
   part.mat.set_shader_parameter("erosion",erode)
func cancel_actor(actor_id: String) -> void:
 if actor_id.is_empty():return
 for i in range(batches.size()-1,-1,-1):
  var b: Dictionary=batches[i]
  if b.actor_id==actor_id and str(b.kind).begins_with("warning_"):
   if is_instance_valid(b.node):b.node.queue_free()
   batches.remove_at(i)
func clear() -> void:
 for b in batches:
  if is_instance_valid(b.node):b.node.queue_free()
 batches.clear();_end_dash()
 if is_instance_valid(movement_smear):movement_smear.queue_free()
 movement_smear=null
 for n in projectile_nodes:
  if is_instance_valid(n):n.queue_free()
 projectile_nodes.clear()
 for n in hostile_zone_nodes:
  if is_instance_valid(n):n.queue_free()
 hostile_zone_nodes.clear()
func inspect() -> Dictionary:
 return {"active_batches":batches.size(),"projectile_pool":projectile_nodes.size(),"hostile_material_pool":hostile_zone_nodes.size(),"dash_active":is_instance_valid(dash_node),"cue_serial":cue_serial,"evidence":evidence.duplicate(true),"authority":"presentation_only"}
