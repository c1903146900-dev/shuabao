extends Node3D
## Visual-only low beacon. No collision, damage, or gameplay ownership.
var pieces:Array=[]
var fire_pieces:Array=[]
const MOUTH_HEIGHT=1.04
func block(pos:Vector3,size:Vector3,color:Color)->MeshInstance3D:
 var n=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=size;n.mesh=mesh;n.position=pos
 var mat=ShaderMaterial.new();mat.shader=load("res://visual_rework_20261009/views/q2_beacon_stone.gdshader");mat.set_shader_parameter("stone_color",Vector3(color.r,color.g,color.b));n.material_override=mat
 n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(n);pieces.append(n);return n
func _ready()->void:
 block(Vector3(0,.09,0),Vector3(1.38,.18,1.38),Color(.41,.36,.28))
 block(Vector3(0,.21,0),Vector3(1.20,.10,1.20),Color(.53,.46,.35))
 var n=MeshInstance3D.new();var body=CylinderMesh.new();body.top_radius=.60;body.bottom_radius=.77;body.height=.64;body.radial_segments=4;body.rings=1;n.mesh=body;n.position.y=.58;n.rotation.y=PI/4
 var mat=ShaderMaterial.new();mat.shader=load("res://visual_rework_20261009/views/q2_beacon_stone.gdshader");mat.set_shader_parameter("stone_color",Vector3(.51,.435,.33));n.material_override=mat;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(n);pieces.append(n)
 block(Vector3(0,.92,0),Vector3(1.06,.12,1.06),Color(.62,.53,.39))
 # A recessed fire mouth and four distinct rim stones.
 block(Vector3(0,.991,0),Vector3(.68,.035,.68),Color(.085,.064,.039))
 for z in [-.44,.44]:block(Vector3(0,1.035,z),Vector3(1.06,.15,.18),Color(.55,.46,.33))
 for x in [-.44,.44]:block(Vector3(x,1.035,0),Vector3(.18,.15,.70),Color(.55,.46,.33))
 # Small front access opening helps read a beacon rather than a plinth.
 block(Vector3(0,.43,.493),Vector3(.25,.36,.014),Color(.12,.095,.063))
 block(Vector3(0,.19,.72),Vector3(.46,.16,.24),Color(.45,.39,.29))
 for i in range(4):
  var flame=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=.009;mesh.bottom_radius=.085;mesh.height=.30;mesh.radial_segments=5;mesh.rings=1;flame.mesh=mesh
  flame.position=Vector3(.16*cos(i*1.57),1.09,.16*sin(i*1.57));var fm=StandardMaterial3D.new();fm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;fm.albedo_color=Color(.77,.22,.035);flame.material_override=fm;add_child(flame);fire_pieces.append(flame)
func advance(age:float,remaining:float)->void:
 var fade=smoothstep(0.0,.14,age)*smoothstep(0.0,.25,remaining)
 scale.y=maxf(.01,fade)
 for i in range(fire_pieces.size()):
  var f=fire_pieces[i];var a=.5+.5*sin(age*8.7+float(i)*2.1)
  f.scale=Vector3(.65+a*.28,.45+a*.65,.65+a*.28)*fade
  f.position.y=1.08+a*.035
