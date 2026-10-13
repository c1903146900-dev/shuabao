extends Node3D
var age=0.0
var duration=5.0
var paper:MeshInstance3D
var shafts=[]
var curls=[]
var mist:MeshInstance3D
var painting:MeshInstance3D
const Forms=preload("res://visual_rework_20261009/views/r_forms.gd")
func edge_mat(color:Color)->ShaderMaterial:
 var m=ShaderMaterial.new();m.shader=load("res://visual_rework_20261009/views/r2_scroll_edge.gdshader");m.set_shader_parameter("tint",color);return m
func _ready()->void:
 var parchment=edge_mat(Color(.79,.77,.67,.29))
 var paper_shader=ShaderMaterial.new();paper_shader.shader=load("res://visual_rework_20261009/views/r2_scroll_paper.gdshader")
 var p=PlaneMesh.new();p.size=Vector2(1,20.0);paper=Forms.mesh(self,p,Vector3(0,.045,0),paper_shader)
 var art_plane=PlaneMesh.new();art_plane.size=Vector2(20.0,20.0)
 var ground_image=Image.load_from_file("res://visual_rework_20261009/assets/r2_river_scroll_ground.png")
 var ground_texture:Texture2D=null
 if ground_image!=null and not ground_image.is_empty():ground_texture=ImageTexture.create_from_image(ground_image)
 else:push_warning("R2 ground painting PNG could not be decoded")
 var art_material=ShaderMaterial.new();art_material.shader=load("res://visual_rework_20261009/views/r2_scroll_paint.gdshader")
 if ground_texture!=null:art_material.set_shader_parameter("painting",ground_texture)
 painting=Forms.mesh(self,art_plane,Vector3(0,.055,0),art_material);painting.visible=ground_texture!=null
 for side in [-1,1]:
  var holder=Node3D.new();add_child(holder);shafts.append(holder)
  var rod=CylinderMesh.new();rod.top_radius=.12;rod.bottom_radius=.12;rod.height=20.4;rod.radial_segments=20
  var n=Forms.mesh(holder,rod,Vector3(0,.22,0),edge_mat(Color(.24,.18,.115,.88)));n.rotation.x=PI*.5
  var roll=CylinderMesh.new();roll.top_radius=.23;roll.bottom_radius=.23;roll.height=20.0;roll.radial_segments=24
  var rr=Forms.mesh(holder,roll,Vector3(0,.24,0),edge_mat(Color(.82,.79,.67,.88)));rr.rotation.x=PI*.5
  for z in [-10.18,10.18]:
   var cap=SphereMesh.new();cap.radius=.155;cap.height=.23;Forms.mesh(holder,cap,Vector3(0,.22,z),edge_mat(Color(.20,.13,.075,.9)))
  # Separate rolled paper edge: geometric curl, not a border painted into an image.
  var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for j in range(20):
   var a=float(j)/20.0*PI*.65;var b=float(j+1)/20.0*PI*.65
   var v=[Vector3(side*sin(a)*.36,.06+.36*(1-cos(a)),-10.0),Vector3(side*sin(b)*.36,.06+.36*(1-cos(b)),-10.0),Vector3(side*sin(a)*.36,.06+.36*(1-cos(a)),10.0),Vector3(side*sin(b)*.36,.06+.36*(1-cos(b)),10.0)]
   for k in [0,2,1,1,2,3]:st.add_vertex(v[k])
  st.generate_normals();curls.append(Forms.mesh(holder,st.commit(),Vector3.ZERO,parchment))
func advance(a:float)->void:
 age=a
 var opening=smoothstep(0,.18,age)
 var closing=1.0-smoothstep(duration,duration+.17,age)
 var span=maxf(.05,20.0*opening*closing)
 paper.scale.x=span
 paper.material_override.set_shader_parameter("open",opening*closing)
 painting.material_override.set_shader_parameter("open",opening*closing)
 painting.material_override.set_shader_parameter("age",age)
 shafts[0].position.x=-span*.5;shafts[1].position.x=span*.5
 for shaft in shafts:
  for part in shaft.get_children():
   if part is MeshInstance3D and part.material_override is ShaderMaterial:part.material_override.set_shader_parameter("effect_center",global_position);part.material_override.set_shader_parameter("effect_radius",10.0*global_basis.x.length())

 visible=age<duration+.20
