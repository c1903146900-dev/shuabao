extends Node3D
const Forms=preload("res://visual_rework_20261009/views/r_forms.gd")
var scope={}
var identity=""
var field:MeshInstance3D
var painting:MeshInstance3D
var flakes=[]
func _ready()->void:
 set_as_top_level(true);transform=Transform3D.IDENTITY
func reset_visuals()->void:
 for child in get_children():
  if child is Node3D:child.visible=false
  child.queue_free()
 field=null;painting=null;flakes=[];identity=""
func receive_source(_event:Dictionary,_snapshot:Dictionary)->void:pass
func present_source(ink:Dictionary,_projection:Dictionary={})->void:
 var next=ink.get("scope",{})
 if scope!=next:reset_visuals();scope=next.duplicate(true)
 var snow:Dictionary=ink.get("snow",{});var now=float(ink.get("hero_time",NAN))
 if snow.is_empty() or not is_finite(now):reset_visuals();return
 var center=snow.get("position",Vector3.INF);var radius=float(snow.get("radius",0));var born=float(snow.get("born_at",NAN));var end=float(snow.get("expires_at",NAN))
 if not center is Vector3 or not center.is_finite() or radius<=0 or not is_finite(born) or not is_finite(end) or now>=end:reset_visuals();return
 if identity!=str(snow.get("domain_id","")):
  reset_visuals();identity=str(snow.domain_id)
  var pm=PlaneMesh.new();pm.size=Vector2.ONE*radius*2
  var fm=ShaderMaterial.new();fm.shader=load("res://visual_rework_20261009/views/r_field.gdshader");fm.set_shader_parameter("snow",true);fm.set_shader_parameter("life",end-born)
  field=Forms.mesh(self,pm,center+Vector3.UP*.02,fm)
  var am=PlaneMesh.new();am.size=Vector2(19,14)*(radius/11.0)
  var mm=ShaderMaterial.new();mm.shader=load("res://visual_rework_20261009/views/r_ink_layer.gdshader");mm.set_shader_parameter("painting",load("res://visual_rework_20261009/assets/r1_snow_banks.png"));mm.set_shader_parameter("strength",.46);mm.set_shader_parameter("life",end-born)
  painting=Forms.mesh(self,am,center+Vector3.UP*.06,mm)
  var rng=RandomNumberGenerator.new();rng.seed=737
  for i in range(22):
   var q=QuadMesh.new();q.size=Vector2(.016,.022)*(1+rng.randf())
   var start=Vector3(rng.randf_range(-9,9),rng.randf_range(.1,3),rng.randf_range(-7,7))*(radius/11.0)
   var n=Forms.mesh(self,q,center+start,Forms.mat(Color(.81,.85,.84,.33)));n.rotation_degrees.x=-40;flakes.append({"node":n,"start":start,"speed":rng.randf_range(.12,.3)})
 var age=now-born;field.material_override.set_shader_parameter("age",age);painting.material_override.set_shader_parameter("age",age)
 for f in flakes:f.node.position=center+f.start+Vector3(age*.18,-fmod(age*f.speed+f.start.y,3.0)+1.5,0)
