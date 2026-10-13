extends Node3D
var materials=[]
var front:MeshInstance3D
var mist:MeshInstance3D
func _ready()->void:
 # Curved relief surface carries an authored ink massif; silhouette comes from painting alpha.
 # This is 2.5D relief art, not a claim of a completed full-3D mountain asset.
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var cols=48;var rows=32
 for y in range(rows):
  for x in range(cols):
   for offset in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
    var u=(float(x)+offset.x)/cols;var v=(float(y)+offset.y)/rows
    st.set_uv(Vector2(u,1-v));st.add_vertex(Vector3((u-.5)*4.0,v*2.65,.34*sin(u*PI)*sin(v*PI)))
 st.generate_normals();var relief_mesh=st.commit()
 for layer in range(3):
  front=MeshInstance3D.new();front.mesh=relief_mesh;front.position.z=float(layer)*.12;add_child(front)
  var material=ShaderMaterial.new();material.shader=load("res://visual_rework_20261009/views/r_ink_layer.gdshader");material.set_shader_parameter("painting",load("res://visual_rework_20261009/assets/r2_ink_massif.png"));material.set_shader_parameter("mountain",true);material.set_shader_parameter("strength",1.0);material.set_shader_parameter("layer",layer);front.material_override=material;materials.append(material)
  front.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func advance(age:float)->void:
 for material in materials:material.set_shader_parameter("age",age)
