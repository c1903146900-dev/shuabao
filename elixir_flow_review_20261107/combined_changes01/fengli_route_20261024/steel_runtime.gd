extends RefCounted
## Pure derived steel consumer: ledger remains the sole lifetime authority.
const VALUES="res://fengli_route_20261024/steel_values.json"
const VALUES_SHA256="007d13d64d4254e4dcad42565f68c4646a002fad4756c043e06fb084c8a08db0"
var _source_key:String=""
var _sim:WeakRef
var _consumer:WeakRef
var _values:Dictionary={}
var _segments:Array=[]
var _allies:Array=[]
var _iron_projected:bool=false
var _last_projection:Dictionary={}

func bind(sim:Node,consumer:RefCounted)->Dictionary:
 if _sim!=null:return {"accepted":false,"reason":"steel_already_bound"}
 if FileAccess.get_sha256(VALUES)!=VALUES_SHA256:return {"accepted":false,"reason":"steel_values_identity_rejected"}
 var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(VALUES))
 if not data is Dictionary or data.get("format","")!="fengli-steel-values-1":return {"accepted":false,"reason":"steel_values_invalid"}
 _values=data.get("parameters",{})
 var units:Dictionary={"elixir:03.max_health":"percent_points","elixir:03.tenacity":"percent_points","elixir:03.defense":"defense_points","elixir:03.ally_move_bonus":"percent_points","elixir:03.path_duration":"seconds","elixir:03.price":"gold","path_width":"world_units","minimum_segment_length":"world_units"}
 for key in units:
  var entry:Dictionary=_values.get(key,{})
  if entry.get("unit","")!=units[key] or not (entry.get("value") is float or entry.get("value") is int):return {"accepted":false,"reason":"steel_units_invalid"}
  if not is_finite(float(entry.value)) or float(entry.value)<=0.0:return {"accepted":false,"reason":"steel_values_invalid"}
 _source_key="elixir:03:path:%d"%get_instance_id()
 _sim=weakref(sim);_consumer=weakref(consumer)
 return {"accepted":true,"reason":""}
func value(key:String)->float:return float(_values.get(key,{}).get("value",0.0))
func _active()->bool:
 return _consumer!=null and _consumer.get_ref()!=null and _consumer.get_ref()._live_item()=="elixir:03"
func commit_final_projection(actor:RefCounted,projected:Dictionary)->void:
 # The common bridge calls this once per final projection. Never call it back.
 var iron:bool=_consumer!=null and _consumer.get_ref()!=null and _consumer.get_ref().active_item()=="elixir:03"
 var before_hp:float=actor.hp
 var before_max:float=actor.stats.max_hp
 assert(is_finite(before_hp) and is_finite(before_max) and before_max>0.0)
 var final_stats:Dictionary=projected.duplicate(true)
 if iron:final_stats.max_hp=float(final_stats.max_hp)*(1.0+value("elixir:03.max_health")*0.01)
 var after_max:float=float(final_stats.max_hp)
 assert(is_finite(after_max) and after_max>0.0)
 actor.stats=final_stats
 # Preserve ratio on entry, every active max-HP change, and removal. Do not heal.
 if (iron or _iron_projected) and before_max!=after_max:
  actor.hp=clampf(before_hp/before_max,0.0,1.0)*after_max if not actor.dead else 0.0
  _last_projection={"before_hp":before_hp,"before_max":before_max,"after_hp":actor.hp,"after_max":after_max,"steel_active":iron,"healing_event_emitted":false}
 else:actor.hp=minf(before_hp,after_max)
 _iron_projected=iron
func track_ally(actor:RefCounted)->void:
 if _sim==null or not is_instance_valid(_sim.get_ref()) or actor==null:return
 var sim:Node=_sim.get_ref()
 if actor==sim.hero or actor not in sim.allies:return
 if not actor.has_method("bind_movement_source"):return
 for ref:WeakRef in _allies:
  if is_same(ref.get_ref(),actor):return
 _allies.append(weakref(actor));actor.bind_movement_source(_source_key,self)
func advance()->void:
 if not _active():clear_paths();return
 var sim:Node=_sim.get_ref()
 for segment:Dictionary in _segments.duplicate():
  if float(segment.until)<=float(sim.clock.world_time):_remove_segment(segment)
 for ref:WeakRef in _allies.duplicate():
  var actor:RefCounted=ref.get_ref()
  if actor==null or actor not in sim.allies or actor.dead:
   if actor!=null:actor.unbind_movement_source(_source_key,self)
   _allies.erase(ref)
 for actor:RefCounted in sim.allies:
  if not actor.dead:track_ally(actor)
func record_movement(origin:Vector3,destination:Vector3)->void:
 if not _active():return
 var sim:Node=_sim.get_ref()
 if sim.paused or sim.transaction_active:return
 var a:Vector3=Vector3(origin.x,0.0,origin.z)
 var b:Vector3=Vector3(destination.x,0.0,destination.z)
 if not a.is_finite() or not b.is_finite() or a.distance_to(b)<=value("minimum_segment_length"):return
 advance()
 var segment:Dictionary={"a":a,"b":b,"until":float(sim.clock.world_time)+value("elixir:03.path_duration"),"mesh":null}
 # A visible ground strip, owned by this exact segment and lifetime. No hostile zones.
 var mesh:MeshInstance3D=MeshInstance3D.new()
 var box:BoxMesh=BoxMesh.new();box.size=Vector3(value("path_width"),0.025,a.distance_to(b))
 var material:StandardMaterial3D=StandardMaterial3D.new()
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.albedo_color=Color(0.25,0.8,0.9,0.65)
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 box.material=material;mesh.mesh=box
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 sim.add_child(mesh)
 mesh.position=(a+b)*0.5+Vector3(0.0,0.035,0.0)
 mesh.rotation.y=atan2((b-a).x,(b-a).z)
 segment.mesh=mesh;_segments.append(segment)
func movement_bonus_for(actor:RefCounted)->float:
 if not _active():return 0.0
 var sim:Node=_sim.get_ref()
 if actor==sim.hero or actor.dead or actor not in sim.allies:return 0.0
 var point:Vector3=Vector3(actor.position.x,0.0,actor.position.z)
 var radius:float=value("path_width")*0.5
 for segment:Dictionary in _segments:
  if float(segment.until)<=float(sim.clock.world_time):continue
  var delta:Vector3=segment.b-segment.a
  var t:float=(point-Vector3(segment.a)).dot(delta)/delta.length_squared()
  if t<0.0 or t>1.0:continue
  if point.distance_squared_to(Vector3(segment.a)+delta*t)<=radius*radius:return value("elixir:03.ally_move_bonus")*0.01
 return 0.0
func _remove_segment(segment:Dictionary)->void:
 if is_instance_valid(segment.mesh):
  segment.mesh.visible=false
  segment.mesh.queue_free()
 _segments.erase(segment)
func clear_paths()->void:
 for segment:Dictionary in _segments.duplicate():_remove_segment(segment)
 for ref:WeakRef in _allies:
  var actor:RefCounted=ref.get_ref()
  if actor!=null:actor.unbind_movement_source(_source_key,self)
 _allies.clear()
func snapshot()->Dictionary:
 var paths:Array=[]
 if _active():
  var now:float=float(_sim.get_ref().clock.world_time)
  for segment:Dictionary in _segments:
   if float(segment.until)>now:paths.append({"from":segment.a,"to":segment.b,"seconds":float(segment.until)-now,"width":value("path_width")})
 return {"paths":paths,"clock":"world_combat_seconds","hp_transition":_last_projection.duplicate(true),"steel_projected":_iron_projected,"ally_consumer":"source_speed_query"}
