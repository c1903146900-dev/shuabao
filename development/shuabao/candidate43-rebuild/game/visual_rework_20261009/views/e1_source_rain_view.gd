extends Node3D
const Bridge=preload("res://visual_rework_20261009/snapshot_bridge.gd")
const Paint=preload("res://visual_rework_20261009/views/paint_factory.gd")
var bridge=Bridge.new()
var rain:MeshInstance3D
var wet:MeshInstance3D
var burst:MeshInstance3D
var burst_receipt:Dictionary={}
var desired_actor_rain_form=false # Host actor presenter consumes; no actor write here.
func _ready()->void:
 set_as_top_level(true);transform=Transform3D.IDENTITY
 rain=Paint.plane(Vector2(2.8,2.7),0,Vector3(.18,.25,.25));rain.rotation_degrees.x=70;add_child(rain)
 wet=Paint.plane(Vector2(1.85,1.60),4,Vector3(.14,.20,.20));add_child(wet)
 burst=Paint.plane(Vector2(1,1),3,Vector3(.14,.22,.21));add_child(burst);reset_visuals()
func reset_visuals()->void:
 desired_actor_rain_form=false;burst_receipt={}
 for n in [rain,wet,burst]:
  if is_instance_valid(n):n.visible=false
func present_source(snapshot:Dictionary)->void:
 if not is_instance_valid(rain):return
 var prior_scope=bridge.current_scope.duplicate(true)
 var data=bridge.normalize(snapshot)
 rain.visible=false;wet.visible=false;burst.visible=false;desired_actor_rain_form=false
 if not data.accepted or prior_scope!=data.scope:burst_receipt={}
 if not data.accepted:return
 for row:Dictionary in data.effects:
  if row.kind!="e1":continue
  desired_actor_rain_form=true;rain.visible=true;wet.visible=true
  rain.position=row.position+Vector3.UP*.8;wet.position=row.position+Vector3.UP*.025
  rain.material_override.set_shader_parameter("age",row.age);wet.material_override.set_shader_parameter("age",row.age)
 for row:Dictionary in data.transients:
  if row.kind=="e1_finished":burst_receipt=row.source.duplicate(true)
 if not burst_receipt.is_empty():
  var age=data.source_time-float(burst_receipt.get("finished_at",-INF))
  if age>=0 and age<.7 and burst_receipt.get("position") is Vector3:
   var radius=float(burst_receipt.get("radius",0.0))
   if radius>0:
    burst.visible=true;burst.position=burst_receipt.position+Vector3.UP*.04;burst.scale=Vector3(radius*2,1,radius*2);burst.material_override.set_shader_parameter("age",age)

func receive_source(event:Dictionary,snapshot:Dictionary)->void:
 if event.get("kind","")!="ink_e1_reform_started":return
 var scope:Dictionary=snapshot.get("scope",{})
 if not bridge.same_scope(event,scope):return
 burst_receipt=event.duplicate(true)
 if not burst_receipt.has("finished_at"):burst_receipt.finished_at=float(event.get("source_time",snapshot.get("hero_time",0.0)))
