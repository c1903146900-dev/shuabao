extends Node3D
var sail:MeshInstance3D
var wake:Node3D
var wake_meshes:Array=[]
var wake_origin=Vector3.ZERO
var wake_dir=Vector3.FORWARD
var painting:Texture2D
var ink:Texture2D
var travel=0.0
var last_travel=-1.0
var retired_at=-1.0
func texture(path:String)->Texture2D:
 return load(path) as Texture2D
func line(a:Vector3,b:Vector3,r:float,c:Color)->void:
 var n=MeshInstance3D.new();var m=CylinderMesh.new();m.top_radius=r*.65;m.bottom_radius=r;m.height=a.distance_to(b);m.radial_segments=7;n.mesh=m;n.position=(a+b)*.5;n.quaternion=Quaternion(Vector3.UP,(b-a).normalized());var mat=StandardMaterial3D.new();mat.albedo_color=c;mat.roughness=.9;n.material_override=mat;add_child(n)
func _ready()->void:
 painting=texture("res://visual_rework_20261009/assets/guzhou_fan_atlas.png");ink=texture("res://visual_rework_20261009/assets/huamo_bimo_atlas.png")
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(12):
  for j in range(36):
   for p in [Vector2(float(i)/12,float(j)/36),Vector2(float(i+1)/12,float(j)/36),Vector2(float(i+1)/12,float(j+1)/36),Vector2(float(i)/12,float(j)/36),Vector2(float(i+1)/12,float(j+1)/36),Vector2(float(i)/12,float(j+1)/36)]:
    var x=(p.x-.5)*.94;var z=(.5-p.y)*2.55
    var y=.10+.25*pow(absf(z)/1.275,3.0)+.065*pow(absf(x)/.47,2.0)
    st.set_uv(p);st.add_vertex(Vector3(x,y,z))
 var hull=MeshInstance3D.new();hull.mesh=st.commit();var hm=ShaderMaterial.new();hm.shader=load("res://visual_rework_20261009/views/e2_painted_boat.gdshader");hm.set_shader_parameter("painting",painting);hull.material_override=hm;hull.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(hull)
 line(Vector3(0,.12,.05),Vector3(-.025,1.62,.05),.023,Color(.22,.20,.16))
 var cloth=SurfaceTool.new();cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(14):
  for j in range(18):
   for p in [Vector2(float(i)/14,float(j)/18),Vector2(float(i+1)/14,float(j)/18),Vector2(float(i+1)/14,float(j+1)/18),Vector2(float(i)/14,float(j)/18),Vector2(float(i+1)/14,float(j+1)/18),Vector2(float(i)/14,float(j+1)/18)]:
    var x=p.x*1.02;var y=.37+(1.0-p.y)*1.25;var z=.065+.17*sin(p.x*PI)*sin(p.y*PI)
    cloth.set_uv(p);cloth.add_vertex(Vector3(x,y,z))
 sail=MeshInstance3D.new();sail.mesh=cloth.commit();var sm=ShaderMaterial.new();sm.shader=load("res://visual_rework_20261009/views/e2_painted_boat.gdshader");sm.set_shader_parameter("painting",painting);sm.set_shader_parameter("region",Vector4(.6184,.0575,.330,.8264));sm.set_shader_parameter("sail",true);sail.material_override=sm;sail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(sail)
func advance(t:float)->void:
 position.y=.055+.016*sin(t*2.0);rotation.z=.012*sin(t*1.7)
 sail.material_override.set_shader_parameter("age",t)
