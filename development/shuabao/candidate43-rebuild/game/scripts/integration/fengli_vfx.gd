extends Node3D
## Wind presentation only. Socket paths create wakes; authoritative runtime contacts create impacts.
## No collision, target query, health change, displacement, or synthesized gameplay event.
signal cue_requested(payload:Dictionary)
const WAKE_SHADER:=preload("res://assets/fengli/vfx/forged_wake.gdshader")
const EROSION:=preload("res://assets/fengli/vfx/thrust_erosion.png")
const DASH_PRESSURE:=preload("res://assets/fengli/vfx/dash_pressure.gd")
const R1_ART:=preload("res://assets/fengli/vfx/r1_convergence.gd")
const NAIL_FRONT:=preload("res://assets/fengli/vfx/nail_front.gd")
const PROJECTILE_ART:=preload("res://assets/fengli/vfx/projectile_art.gd")
const WAVE:=preload("res://assets/fengli/vfx/travelling_wave.gd")
const THRUST:=preload("res://assets/fengli/vfx/q1_thrust.gd")
var history:Array=[]
var particles:Array=[]
var effects:Array=[]
var receipts:Array=[]
var seen:Dictionary={}
var wake:MeshInstance3D
var clip:=""
var cast_id:=""
var clock:=0.0
var last_sample:=-1.0
var peak_area:=0.0
var contact_count:=0
var last_origin:=Vector3.ZERO
var moved:=0.0
var projectile_views:Dictionary={}
var phantom:Node3D
var phantom_id:=""
var mark:Node3D
var mark_target:=""
var mark_material:StandardMaterial3D
var enemy_heights:Dictionary={}
var enemy_states:Dictionary={}
var r1_art:Node3D
var r1_cast:=""
var r1_contacts:Dictionary={}
var nail_fronts:Dictionary={}
var impact_groups:Dictionary={}
var generation:=-1
var view:Node3D
var visual_scale:=1.25
var released:=false
var window:=Vector2.ZERO
var wake_life:=.085
var q2_mid_emitted:=false
var dash_pressure:Node3D
var dash_reach:=2.0

func setup(actor:Node3D)->void:
 view=actor
 enemy_heights=JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemies/siege_brood/animation_contract.json")).get("enemies",{})
 # The separate production Boss is absent from the seven-role catalog. Its actual
 # arena GLB bind bounds top at2.775m; keep E1 mark above it rather than inside its chest.
 enemy_heights["boss"]={"height_m":2.775}
 wake=MeshInstance3D.new();wake.name="ForgedSocketWake";add_child(wake)
 var mat:=ShaderMaterial.new();mat.shader=WAKE_SHADER;mat.set_shader_parameter("erosion_map",EROSION)
 wake.material_override=mat;wake.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;wake.visible=false;wake.extra_cull_margin=3

func combat_event(e:Dictionary)->void:
 var kind:String=str(e.get("kind",""))
 if e.has("generation"):
  var incoming:int=int(e.generation)
  if generation>=0 and incoming<generation:return
  if generation>=0 and incoming>generation:clear_transients()
  generation=incoming
 var key:String=str(e.get("combat_level_id",""))+":"+str(e.get("sequence",""))
 if e.has("sequence"):
  if seen.has(key):return
  seen[key]=true
  if seen.size()>512:seen.erase(seen.keys()[0])
 if kind in ["attack_started","dash_attack_started","q2_strike_started","q3_started","e2_started","r1_started"] or (kind=="e2_spin_started" and e.get("phase","")=="extra"):
  clip={"attack_started":"attack","dash_attack_started":"dash_attack","q3_started":"q3","r1_started":"r1"}.get(kind,"q2_entry" if int(e.get("strike",1))==1 else "q2_strike")
  if kind=="e2_started":clip="e2_spin3" if int(e.get("rotations",1))==3 else "e2_spin"
  if kind=="e2_spin_started":clip="e2_afterspin"
  if not view.contract.clips.has(clip):return
  cast_id=str(e.get("cast_id",""))
  history.clear();last_sample=-1;released=false;moved=0;last_origin=view.global_position;q2_mid_emitted=false
  var e2_mode:bool=clip in ["e2_spin","e2_spin3","e2_afterspin"]
  var rotation_time:float=float(e.get("rotation_duration",float(e.get("duration",.45))/maxi(1,int(e.get("rotations",1)))))
  wake_life=clampf(rotation_time*.27,.035,.075) if e2_mode else .10 if clip=="r1" else .085
  (wake.material_override as ShaderMaterial).set_shader_parameter("spin_material",1.0 if e2_mode else 0.0)
  (wake.material_override as ShaderMaterial).set_shader_parameter("stroke_seed",float(e.get("occurrence",0)))
  if kind=="q2_strike_started":_transition_afterimage(e.get("origin",view.global_position),.12)
  if kind=="dash_attack_started":
   dash_reach=float(e.get("shape",{}).get("radius",2.0));_transition_afterimage(view.global_position,.15)
  var markers:Dictionary=view.contract.clips[clip].phase_markers_s
  window=Vector2(float(markers.get("trail_start",0.0)),float(markers.get("trail_end",view.contract.clips[clip].duration_s)))
  _receipt({"kind":"wake_begin","clip":clip,"cast_id":cast_id})
 if kind in ["attack_cancelled","basic_cancelled","skill_cancelled","cast_cancelled","r1_cancelled"]:
  for identifier in e.get("cast_ids",[e.get("cast_id","")]):
   if not str(identifier).is_empty() and str(identifier)==cast_id:cancel(str(identifier))
  if str(e.get("cast_id",""))==r1_cast and is_instance_valid(r1_art):r1_art.queue_free();r1_art=null
 if kind=="r1_started":
  r1_cast=str(e.cast_id);r1_contacts.clear()
  r1_art=R1_ART.new();add_child(r1_art);r1_art.configure(e.position,float(e.radius),visual_scale);r1_art.set_meta("time_domain","real");effects.append(r1_art)
 if kind=="damage" and str(e.get("source",""))=="r1" and float(e.get("amount",0))>0:
  r1_contacts[str(e.target)]=e.position
 if kind=="r1_impact" and is_instance_valid(r1_art) and str(e.get("cast_id",""))==r1_cast:
  var positions:Array=[]
  for target in e.get("target_ids",[]):
   if r1_contacts.has(str(target)):positions.append(r1_contacts[str(target)])
  r1_art.settle(e.position,positions)
  _receipt({"kind":"unified_r1_settlement","cast_id":r1_cast,"contacts":positions.size(),"radius":e.radius})
 if kind=="r1_execute":
  _receipt({"kind":"committed_r1_execute","cast_id":str(e.cast_id),"target":str(e.target),"position":e.position})
  for i in range(3):
   var axis:Vector3=(Vector3.UP+view.global_basis.x*(i-1)*.65).normalized()
   _particle(e.position+Vector3.UP*(.8+.13*i),Basis.looking_at(axis,-view.global_basis.z),Vector3(.025,.055,.24),Color("783847"),.18,axis*.8,0,float(i))
   particles[-1]["time_domain"]="real"
 if kind=="r1_finished" and float(e.get("healed",0))>0:_ultimate_heal(e.position)
 if kind=="damage" and str(e.get("source","")) in ["r2_nail","r2_true"] and float(e.get("amount",0))>0:
  var group:String="%s:%s:%s:%s:%s"%[e.get("cast_id",""),e.get("round",0),e.get("target",""),e.get("world_time",0),e.source]
  if not impact_groups.has(group):
   impact_groups[group]=true
   if impact_groups.size()>512:impact_groups.erase(impact_groups.keys()[0])
   if e.source=="r2_true":_true_contact(e.position,e.get("direction",Vector3.FORWARD),str(e.cast_id))
   else:contact(e.position,e.get("direction",Vector3.FORWARD),"r2_nail","bone",str(e.cast_id))
 if kind=="e2_spin_started":(wake.material_override as ShaderMaterial).set_shader_parameter("stroke_seed",float(e.get("occurrence",0)))
 if kind=="damage" and float(e.get("amount",0))>0 and str(e.get("source",""))=="overload_true":
  _true_contact(e.get("position",Vector3.ZERO),e.get("direction",Vector3.FORWARD),str(e.get("cast_id","")))
 if kind=="e3_started":_state_burst(view.global_position,"overload_on")
 if kind=="e3_extended":_state_burst(view.global_position,"overload_extend")
 if kind=="e3_death_prevented":_state_burst(e.get("position",view.global_position),"lethal_immune")
 if kind=="passive_rescue":_state_burst(e.get("position",view.global_position),"passive_rescue")
 if kind=="permanent_attack_gained":_state_burst(view.global_position,"permanent_growth")

 if kind in ["e2_blink","e2_return"]:
  history.clear();last_sample=-1;wake.visible=false
  _blink_fold(e.get("origin",view.global_position),false)
  _blink_fold(e.get("position",view.global_position),true)
 if kind in ["q3_launched","e1_projectile"]:_sync_projectile(e)
 if kind in ["q3_expired","r2_nail_expired"]:_remove_projectile(str(e.get("id","")))
 if kind=="e1_pierce_started":
  _transition_afterimage(e.get("origin",view.global_position),.13)
  dash_pressure=DASH_PRESSURE.new();dash_pressure.visual_height_scale=visual_scale;add_child(dash_pressure)
  dash_pressure.configure(e.get("origin",view.global_position),e.get("direction",Vector3.FORWARD),.85,float(e.get("width",1.4)),0);effects.append(dash_pressure)
 if kind=="e1_finished" and bool(e.get("pierced",false)):
  _dust(e.get("position",view.global_position),-view.global_basis.z)

 if kind=="q2_finished":
  _dust(e.get("position",view.global_position),-view.global_basis.z)
 if kind=="dash":
  cue_requested.emit({"identity":"wind.shift.displacement","phase":"movement","cast_id":e.get("cast_id"),"material":"cloth_air","time_domain":"real"})
 if kind=="damage" and float(e.get("amount",0))>0 and str(e.get("source","")) in ["attack","dash_attack","q1","q2","q3","e1_dagger","e1_pierce","e2","e2_extra"]:
  contact(e.get("position",Vector3.ZERO),e.get("direction",Vector3.FORWARD),str(e.get("source")),str(e.get("target_material","metal")),str(e.get("cast_id","")))
 if kind=="q1_started":
  var thrust=THRUST.new();thrust.visual_height_scale=visual_scale;add_child(thrust)
  thrust.configure(e.get("position",e.get("origin",Vector3.ZERO)),e.direction,float(e.length),float(e.width),int(e.get("stacks",0)));thrust.set_meta("cast_id",str(e.get("cast_id","")));effects.append(thrust)
 if kind=="q1_impact":
  for effect in effects:
   if is_instance_valid(effect) and str(effect.get_meta("cast_id",""))==str(e.get("cast_id","")):effect.position=e.position

func cancel(identifier:String="")->void:
 if not identifier.is_empty() and identifier!=cast_id:return
 clip="";history.clear();last_sample=-1
 if is_instance_valid(wake):wake.visible=false

func advance(world_dt:float,real_dt:float=-1.0,hero_dt:float=-1.0)->void:
 var real:float=world_dt if real_dt<0 else real_dt
 var own_dt:float=world_dt if hero_dt<0 else hero_dt
 var dt:float=real if clip in ["dash_attack","r1"] else own_dt
 clock+=maxf(0,dt)
 if is_instance_valid(r1_art) and not r1_art.settled:r1_art.position=view.global_position
 if is_instance_valid(dash_pressure) and is_instance_valid(view) and view.current_clip in ["dash_attack","e1_pierce"]:
  dash_pressure.position=view.global_position;dash_pressure.rotation.y=view.rotation.y
 if is_instance_valid(view):visual_scale=view.effective_visual_scale
 _sample_wake(dt)
 for effect in effects:
  if is_instance_valid(effect):effect.advance(real if effect.get_meta("time_domain","hero")=="real" else world_dt if effect.get_meta("time_domain","hero")=="world" else own_dt)
 effects=effects.filter(func(e):return is_instance_valid(e))
 for i in range(particles.size()-1,-1,-1):
  var p:Dictionary=particles[i]
  var particle_dt:float=own_dt if p.get("time_domain","world")=="hero" else real if p.get("time_domain","world")=="real" else world_dt
  p.age+=particle_dt
  if p.age>=p.life:p.node.queue_free();particles.remove_at(i);continue
  var t:float=p.age/p.life
  p.velocity+=Vector3.DOWN*float(p.gravity)*particle_dt;p.node.position+=Vector3(p.velocity)*particle_dt
  p.node.rotate_object_local(Vector3.UP,float(p.spin)*particle_dt)
  if not p.get("static_scale",false):p.node.scale=Vector3(p.size)*maxf(.001,1.0-pow(t,2.0))
  (p.node.material_override as StandardMaterial3D).albedo_color.a=float(p.get("base_alpha",1.0))*(1.0-pow(t,1.3))

func _sample_wake(dt:float)->void:
 while not history.is_empty() and clock-float(history[0].time)>wake_life:history.pop_front()
 if clip.is_empty() or not is_instance_valid(view):wake.visible=false;return
 var at:float=view.clip_elapsed*view.playback_scale
 if view.current_clip!=clip and not history.is_empty():_draw();return
 if view.current_clip!=clip:cancel();return
 if at>=window.x and not released:
  released=true
  if clip=="dash_attack":
   dash_pressure=DASH_PRESSURE.new();dash_pressure.visual_height_scale=visual_scale;add_child(dash_pressure)
   dash_pressure.configure(view.global_position,-view.global_basis.z,dash_reach,1.05,0);dash_pressure.set_meta("time_domain","real");effects.append(dash_pressure)
  cue_requested.emit({"identity":"wind."+clip+".release","phase":"release","cast_id":cast_id,"material":"cold_steel_air","authored_s":window.x,"time_domain":"real" if clip=="dash_attack" else "world"})
 if clip in ["q2_entry","q2_strike"] and at>=.10 and not q2_mid_emitted:
  q2_mid_emitted=true;_transition_afterimage(view.global_position,.12)
 if is_instance_valid(dash_pressure) and clip=="dash_attack":
  dash_pressure.position=view.global_position
  dash_pressure.rotation.y=view.rotation.y
 if at>=window.x-.02 and at<=window.y and dt>0 and not is_equal_approx(last_sample,at):
  last_sample=at;view.skeleton.force_update_all_bone_transforms()
  var grip:Vector3=view.socket_position("weapon");var tip:Vector3=view.socket_position("blade_tip")
  var base:Vector3=grip.lerp(tip,.18)
  # Swept blade segment in world space. No center fan, analytical cone, or full-ring replacement.
  history.append({"base":base,"tip":tip,"time":clock})
 if clip in ["dash_attack","q2_entry","q2_strike"]:
  var displacement:Vector3=view.global_position-last_origin;moved+=displacement.length()
  if moved>.70 and dt>0:
   moved=0;_dust(view.global_position,displacement.normalized())
 last_origin=view.global_position
 if at>=window.x:_draw()
 else:wake.visible=false
 if at>window.y+wake_life and history.is_empty():clip=""

func _draw()->void:
 if history.size()<2:wake.visible=false;return
 var points:=PackedVector3Array();var uv:=PackedVector2Array();var colors:=PackedColorArray();var ids:=PackedInt32Array()
 var area:=0.0
 # A narrow, closed, bevelled pressure stroke hugs the outer physical sword.
 # It is not a fan from the hand: inner 58% of the blade stays negative space.
 # Unequal half widths, thickness and a torn tail preserve directional material mass.
 for i in history.size():
  var sample:Dictionary=history[i];var u:float=float(i)/float(history.size()-1)
  var life:float=clampf(1.-(clock-float(sample.time))/wake_life,0,1)
  var raw_base:Vector3=_soft_history(i,"base");var raw_tip:Vector3=_soft_history(i,"tip")
  var blade:Vector3=(raw_tip-raw_base).normalized()
  var tangent:Vector3=raw_tip-_soft_history(maxi(0,i-1),"tip")
  if tangent.length_squared()<.000001 and i+1<history.size():tangent=_soft_history(i+1,"tip")-raw_tip
  if tangent.length_squared()<.000001:tangent=Vector3.UP
  var normal:Vector3=blade.cross(tangent).normalized()
  if normal.length_squared()<.00001:normal=Vector3.UP
  var center:Vector3=raw_base.lerp(raw_tip,.82)
  var taper:float=pow(clampf(u*1.35,0,1),.50)*pow(life,.30)
  var spin_material:bool=clip in ["e2_spin","e2_spin3","e2_afterspin"]
  if spin_material:taper=pow(u,1.55)*(1.0-smoothstep(.84,1.0,u))*1.75*pow(life,.25)
  var broad:float=minf(.25*visual_scale,raw_base.distance_to(raw_tip)*.19)*taper
  var thin:float=(.009 if spin_material else .042)*visual_scale*taper
  # Six-sided volume: a forged narrow edge, with one raised bevel and an uneven inside lip.
  for j in range(6):
   var angle:float=TAU*float(j)/6.0
   points.append(center+blade*cos(angle)*broad+normal*sin(angle)*thin)
   uv.append(Vector2(u,float(j)/5.0));colors.append(Color(1,1,1,life))
  if i>0:
   for j in range(6):
    var a: int=(i-1)*6+j;var b: int=(i-1)*6+(j+1)%6;var c: int=i*6+j;var d: int=i*6+(j+1)%6
    ids.append_array(PackedInt32Array([a,c,b,b,c,d]))
   area+=(Vector3(history[i].tip)-Vector3(history[i-1].tip)).length()*broad*2
 for j in range(1,5):
  ids.append_array(PackedInt32Array([0,j+1,j,(history.size()-1)*6,(history.size()-1)*6+j,(history.size()-1)*6+j+1]))
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=ids
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);wake.mesh=mesh;(wake.material_override as ShaderMaterial).set_shader_parameter("stroke_clock",clock);wake.global_transform=Transform3D.IDENTITY;wake.visible=area>.002;peak_area=maxf(peak_area,area)

func _soft_history(index:int,key:String)->Vector3:
 if index==0 or index==history.size()-1:return history[index][key]
 return Vector3(history[index-1][key])*.25+Vector3(history[index][key])*.5+Vector3(history[index+1][key])*.25

func contact(at:Vector3,direction:Vector3,source:String,material:String,identifier:String)->void:
 contact_count+=1
 _receipt({"kind":"actual_contact","position":at,"source":source,"cast_id":identifier,"material":material})
 cue_requested.emit({"identity":"wind."+source+".contact","phase":"contact","cast_id":identifier,"material":material,"position":at})
 var normal:Vector3=direction.normalized() if direction.length_squared()>.001 else Vector3.FORWARD
 var side:Vector3=normal.cross(Vector3.UP)
 var origin:Vector3=at-normal*.38+Vector3.UP*1.0
 # Three unequal cold metallic cut splinters, no symmetrical generic star or circular blast.
 for i in range(5):
  var twist:float=-.65+float(i)*.48
  var velocity:Vector3=side*(-1.3+float(i)*.72)+Vector3.UP*(.7+.3*(i%3))-normal*.3
  var color:Color=Color("b6c8d5") if i%3!=0 else Color("611f32")
  var size:=Vector3(.018,.045,.45 if i==2 else .22+.06*(i%2))
  var basis:=Basis.looking_at((side*cos(twist)+Vector3.UP*sin(twist)).normalized(),normal)
  _particle(origin,basis,size,color,.10+.025*(i%3),velocity,3,1.1)
 for i in range(3):
  var color:Color=Color("748895") if material=="metal" else Color("c7c0b3") if material=="bone" else Color("746951")
  _particle(origin,Basis.from_euler(Vector3(.5,i*2.4,.3)),Vector3(.065,.035,.09),color,.26+i*.025,side*(-1+i)*1.4+Vector3.UP*1.4-normal*.2,12,i*3.5)

func _dust(at:Vector3,direction:Vector3)->void:
 for i in range(2):_particle(at+Vector3.UP*.07,Basis.IDENTITY,Vector3(.07,.025,.14),Color("66717a"),.22,-direction*.6+Vector3.UP*.15,1,0)

func _particle(at:Vector3,basis:Basis,size:Vector3,color:Color,life:float,velocity:Vector3,gravity:float,spin:float)->void:
 var node:=MeshInstance3D.new();node.mesh=_shard();node.transform=Transform3D(basis,at);node.scale=size
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color=color;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
 particles.append({"node":node,"age":0.,"life":life,"velocity":velocity,"size":size,"gravity":gravity,"spin":spin})

func _shard()->ArrayMesh:
 var a:=[];a.resize(Mesh.ARRAY_MAX)
 a[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(0,0,-1),Vector3(-1,0,0),Vector3(0,1,0),Vector3(1,0,0),Vector3(0,-1,0),Vector3(0,0,1)])
 a[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3,0,3,4,0,4,1,5,2,1,5,3,2,5,4,3,5,1,4])
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a);return mesh

func _receipt(data:Dictionary)->void:
 receipts.append(data)
 if receipts.size()>128:receipts.pop_front()
func clear_transients()->void:
 cancel();seen.clear();receipts.clear();contact_count=0;peak_area=0
 for p in particles:p.node.queue_free()
 for e in effects:if is_instance_valid(e):e.queue_free()
 particles.clear();effects.clear();r1_art=null;r1_cast="";r1_contacts.clear();impact_groups.clear()
 for id in nail_fronts:
  if is_instance_valid(nail_fronts[id]):nail_fronts[id].queue_free()
 nail_fronts.clear()
 for id in projectile_views:_remove_projectile_node(projectile_views[id])
 projectile_views.clear()
 if is_instance_valid(phantom):phantom.queue_free()
 phantom=null;phantom_id=""
 if is_instance_valid(mark):mark.queue_free()
 mark=null;mark_target=""
func debug_snapshot()->Dictionary:return {"clip":clip,"cast_id":cast_id,"history":history.size(),"peak_area_m2":peak_area,"contacts":contact_count,"particles":particles.size(),"receipts":receipts.duplicate(true)}


func sync_snapshot(snapshot:Dictionary)->void:
 if is_instance_valid(view):visual_scale=view.effective_visual_scale
 var next_generation:int=int(snapshot.get("generation",generation))
 if generation>=0 and next_generation<generation:return
 if generation>=0 and next_generation>generation:clear_transients()
 generation=next_generation
 _sync_phantom(snapshot.get("wind_phantom",{}))
 enemy_states.clear()
 for enemy in snapshot.get("enemies",[]):enemy_states[str(enemy.actor_id)]=enemy
 _sync_mark(snapshot.get("wind_mark",{}))
 var active:Dictionary={}
 for data in snapshot.get("wind_projectiles",[])+snapshot.get("wind_nails",[]):
  var projectile_type:String=str(data.get("type",""))
  if projectile_type not in ["sword_wave","dagger","bone_nail"]:continue
  var id:String=str(data.get("id",""))
  if id.is_empty():continue
  active[id]=true;_sync_projectile(data)
 var front_groups:Dictionary={}
 for data in snapshot.get("wind_nails",[]):
  var group:String=str(data.get("cast_id",""))+":"+str(data.get("round",0))
  if front_groups.has(group):continue
  front_groups[group]=true
  if not nail_fronts.has(group):
   var front=NAIL_FRONT.new();add_child(front);front.configure(float(data.get("width",2.8)),visual_scale);nail_fronts[group]=front
  nail_fronts[group].sync_projectile(data)
 for group in nail_fronts.keys():
  if not front_groups.has(group):
   if is_instance_valid(nail_fronts[group]):nail_fronts[group].queue_free()
   nail_fronts.erase(group)
 for id in projectile_views.keys():
  if not active.has(id):_remove_projectile(id)

func _sync_projectile(data:Dictionary)->void:
 var id:String=str(data.get("id",""))
 if id.is_empty() or not data.has("position"):return
 if not projectile_views.has(id):
  var projectile_type:String=str(data.get("type","sword_wave"))
  var node:Node3D
  if projectile_type in ["dagger","bone_nail"]:
   node=PROJECTILE_ART.new();add_child(node);node.configure(projectile_type,visual_scale)
  else:
   node=WAVE.new();add_child(node);node.configure(float(data.get("width",1.8)),visual_scale)
  node.name="Projectile_"+id.validate_node_name();projectile_views[id]=node
 projectile_views[id].sync_projectile(data)

func _remove_projectile(identifier:String)->void:
 if not projectile_views.has(identifier):return
 _remove_projectile_node(projectile_views[identifier]);projectile_views.erase(identifier)

func _remove_projectile_node(node:Node)->void:
 if is_instance_valid(node):node.queue_free()


func _blink_fold(at:Vector3,arrival:bool)->void:
 var forward:Vector3=-view.global_basis.z
 var side:Vector3=view.global_basis.x
 for i in range(7):
  var theta:float=float(i)*2.4
  var offset:Vector3=side*cos(theta)*.34+Vector3.UP*(.24+float(i)*.19)
  var velocity:Vector3=(offset*2.5 if not arrival else -offset*2.0)+forward*(.4 if arrival else -.4)
  _particle(at+offset,Basis.from_euler(Vector3(.2,theta,.3)),Vector3(.025,.085,.15),Color("a5b6c2") if i%2==0 else Color("632839"),.17+float(i%3)*.025,velocity,0,theta)

func _sync_phantom(data:Dictionary)->void:
 var id:String=str(data.get("id",""))
 if id.is_empty():
  if is_instance_valid(phantom):phantom.queue_free()
  phantom=null;phantom_id="";return
 if id!=phantom_id or not is_instance_valid(phantom):
  if is_instance_valid(phantom):phantom.queue_free()
  phantom=view.MODEL.instantiate();phantom.name="UntargetableAfterimage";add_child(phantom)
  var player:AnimationPlayer=_phantom_player(phantom)
  if player:
   player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;player.play("idle");player.seek(0,true);player.advance(0)
  _paint_phantom(phantom);phantom_id=id
 phantom.position=data.get("position",Vector3.ZERO)
 var facing:Vector3=data.get("facing",Vector3.FORWARD)
 phantom.rotation.y=atan2(-facing.x,-facing.z)
 phantom.scale=Vector3.ONE*visual_scale
 var left:float=float(data.get("left",1.0))
 _fade_phantom(phantom,clampf(left/.35,0,1))

func _phantom_player(node:Node)->AnimationPlayer:
 if node is AnimationPlayer:return node
 for child in node.get_children():
  var player:=_phantom_player(child)
  if player:return player
 return null

func _paint_phantom(node:Node)->void:
 if node is MeshInstance3D:
  var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
  mat.albedo_color=Color(.34,.065,.105,.28);node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for child in node.get_children():_paint_phantom(child)

func _fade_phantom(node:Node,factor:float)->void:
 if node is MeshInstance3D and node.material_override:node.material_override.albedo_color.a=.28*factor
 for child in node.get_children():_fade_phantom(child,factor)


func _true_contact(at:Vector3,direction:Vector3,identifier:String)->void:
 var axis:Vector3=direction.normalized() if direction.length_squared()>.001 else Vector3.FORWARD
 var side:Vector3=axis.cross(Vector3.UP)
 var origin:Vector3=at-axis*.42+Vector3.UP*1.10
 _receipt({"kind":"true_bonus_accent","position":at,"cast_id":identifier})
 for i in range(2):
  var cross:Vector3=(side*(1.0 if i==0 else -1.0)+Vector3.UP*.55).normalized()
  _particle(origin,Basis.looking_at(cross,axis),Vector3(.012,.022,.28),Color("dde4e9"),.075,axis*.15+cross*.65,0,0)

func _state_burst(at:Vector3,identity:String)->void:
 _receipt({"kind":"state_cue","identity":identity,"position":at})
 var side:Vector3=view.global_basis.x
 var forward:Vector3=-view.global_basis.z
 if identity=="lethal_immune":
  # A broken cut is pushed away from the surviving silhouette. No heal or corpse pose.
  for i in range(7):
   var offset:Vector3=side*(-.45+float(i)*.15)+Vector3.UP*(.7+.1*(i%3))
   _particle(at+offset,Basis.from_euler(Vector3(.3,float(i)*.7,.6)),Vector3(.026,.09,.18),Color("813444") if i%2==0 else Color("aabcc9"),.22,offset.normalized()*1.8+Vector3.UP*.4,2,float(i))
 elif identity=="passive_rescue":
  for i in range(5):
   var offset:Vector3=side*(-.32+.16*i)+forward*sin(i*2.4)*.18+Vector3.UP*(.45+.12*(i%2))
   _particle(at+offset,Basis.looking_at(Vector3.UP,forward),Vector3(.020,.05,.22),Color("a9c0cf"),.32,Vector3.UP*(1.5+.18*i),0,float(i)*.3)
 elif identity=="permanent_growth":
  var point:Vector3=view.socket_position("weapon").lerp(view.socket_position("blade_tip"),.58)
  for i in range(3):_particle(point+side*(i-1)*.055,Basis.looking_at(Vector3.UP,forward),Vector3(.015,.028,.11),Color("ac6877"),.30,Vector3.UP*.6+side*(i-1)*.12,0,0)
 else:
  var point:Vector3=view.socket_position("weapon")
  for i in range(3):_particle(point+side*(i-1)*.09,Basis.from_euler(Vector3(.4,i*.7,.2)),Vector3(.018,.03,.16),Color("834150"),.20,side*(i-1)*.4+Vector3.UP*.55,0,0)


func _transition_afterimage(at:Vector3,duration:float)->void:
 if not is_instance_valid(view) or not is_instance_valid(view.skeleton):return
 view.skeleton.force_update_all_bone_transforms()
 var vertices:=PackedVector3Array();var indices:=PackedInt32Array()
 _bake_silhouette(view.visual,vertices,indices,at-view.global_position)
 if vertices.is_empty():return
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var node:=MeshInstance3D.new();node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);node.global_transform=Transform3D.IDENTITY
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color=Color(.40,.49,.57,.22);node.material_override=mat
 particles.append({"node":node,"age":0.,"life":duration,"velocity":Vector3.ZERO,"size":Vector3.ONE,"gravity":0.,"spin":0.,"static_scale":true,"base_alpha":.22,"time_domain":"real" if clip=="dash_attack" else "hero"})
 _receipt({"kind":"transition_afterimage","position":at,"damage":false})

func _bake_silhouette(node:Node,vertices:PackedVector3Array,indices:PackedInt32Array,offset:Vector3)->void:
 if node is MeshInstance3D and node.mesh and node.skin:
  var transforms:Array=[]
  for bind in node.skin.get_bind_count():
   var bone:int=node.skin.get_bind_bone(bind)
   if bone<0:bone=view.skeleton.find_bone(node.skin.get_bind_name(bind))
   transforms.append(view.skeleton.global_transform*view.skeleton.get_bone_global_pose(bone)*node.skin.get_bind_pose(bind))
  for surface in node.mesh.get_surface_count():
   var a:Array=node.mesh.surface_get_arrays(surface)
   var points:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var bones:PackedInt32Array=a[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
   if bones.is_empty() or weights.is_empty():continue
   var base:int=vertices.size()
   for i in points.size():
    var point:=Vector3.ZERO
    for j in range(4):
     var weight:float=weights[i*4+j]
     if weight>0:point+=(transforms[bones[i*4+j]]*points[i])*weight
    vertices.append(point+offset)
   var faces:PackedInt32Array=a[Mesh.ARRAY_INDEX]
   if faces.is_empty():
    for i in points.size():indices.append(base+i)
   else:
    for face in faces:indices.append(base+face)
 for child in node.get_children():_bake_silhouette(child,vertices,indices,offset)


func _sync_mark(data:Dictionary)->void:
 var target:String=str(data.get("target_id",""))
 if target.is_empty():
  if is_instance_valid(mark):mark.queue_free()
  mark=null;mark_target="";return
 if not is_instance_valid(mark) or target!=mark_target:
  if is_instance_valid(mark):mark.queue_free()
  mark=Node3D.new();mark.name="DaggerTargetMark";add_child(mark);mark_target=target
  mark_material=StandardMaterial3D.new();mark_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mark_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mark_material.albedo_color=Color("aa5264")
  for i in range(3):
   var blade:=MeshInstance3D.new();blade.mesh=_shard();blade.scale=Vector3(.04,.025,.20);blade.rotation_degrees=Vector3(75,0,-35.0+35*i);blade.position=Vector3((i-1)*.19,.09*absf(i-1),0)
   blade.material_override=mark_material;blade.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mark.add_child(blade)
 var enemy:Dictionary=enemy_states.get(target,{})
 var kind:String=str(enemy.get("kind","armored"))
 var height:float=float(enemy_heights.get(kind,{}).get("height_m",1.5))
 mark.position=data.get("position",enemy.get("position",Vector3.ZERO))+Vector3(.28,height+.35,0)
 mark_material.albedo_color.a=.62+.26*clampf(float(data.get("remaining",1.0))/.7,0,1)


func _ultimate_heal(at:Vector3)->void:
 _receipt({"kind":"r1_after_presentation_heal","position":at})
 for i in range(7):
  var a:float=float(i)*TAU/7.0
  var offset:=Vector3(cos(a)*.58,.30+.08*(i%3),sin(a)*.58)
  _particle(at+offset,Basis.looking_at((-offset+Vector3.UP*.7).normalized()),Vector3(.025,.04,.18),Color("b3c2c9"),.35,-offset*1.9+Vector3.UP*.8,0,.3*i)
  particles[-1]["time_domain"]="real"
