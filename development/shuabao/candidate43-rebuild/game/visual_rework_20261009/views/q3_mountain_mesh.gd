extends Node3D
var chunks:Array=[]
var mist:Array=[]
var rock_material:ShaderMaterial
var age=0.0
var collapse_age=-1.0
var collapse_direction=Vector3.FORWARD
var mountain_axis=Vector3.RIGHT
var normal=Vector3.FORWARD
var flow_materials:Array=[]
func h(x:float,z:float)->float:
 var edge=pow(maxf(0.0,1.0-pow(absf(x)/2.25,6.0)),.65)*pow(maxf(0.0,1.0-pow(absf(z)/.70,3.0)),.65)
 var heights=.2+1.70*exp(-pow((x+.55)/.72,2.0))+1.05*exp(-pow((x-1.05)/.51,2.0))+.62*exp(-pow((x+1.65)/.37,2.0))
 var spine=exp(-pow((z-.10*sin(x*3.1))/.48,2.0))
 var folded=1.0+.065*sin(x*19.0+z*6.0)+.035*sin(x*38.0-z*17.0)
 return .03+edge*heights*spine*folded
func setup(axis:Vector3,source_length:float=4.5,source_width:float=1.4)->void:
 var sx=source_length/4.5
 var sz=source_width/1.4
 mountain_axis=axis;normal=Vector3(-axis.z,0,axis.x)
 rock_material=ShaderMaterial.new();rock_material.shader=load("res://visual_rework_20261009/views/q3_rock.gdshader")
 # 15 unequal-looking rock sections share sampled continuous surface boundaries.
 for section in range(15):
  var pivot=axis*(-2.25+(float(section)+.5)*.3)*sx
  var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for ix in range(5):
   for iz in range(16):
    var x0=-2.25+float(section*5+ix)/75.0*4.5
    var x1=-2.25+float(section*5+ix+1)/75.0*4.5
    var z0=-.70+float(iz)/16.0*1.4
    var z1=-.70+float(iz+1)/16.0*1.4
    for p in [Vector2(x0,z0),Vector2(x1,z0),Vector2(x1,z1),Vector2(x0,z0),Vector2(x1,z1),Vector2(x0,z1)]:
     st.set_uv(Vector2((p.x+2.25)/4.5,(p.y+.7)/1.4));st.add_vertex(axis*p.x*sx+normal*p.y*sz+Vector3.UP*h(p.x,p.y)-pivot)
  st.generate_normals();var n=MeshInstance3D.new();n.mesh=st.commit();n.material_override=rock_material;n.position=pivot;n.set_meta("home",pivot);add_child(n);chunks.append(n)
 for k in range(4):
  var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for i in range(52):
   var u0=float(i)/52.0;var u1=float(i+1)/52.0
   for p in [Vector2(u0,0),Vector2(u1,0),Vector2(u1,1),Vector2(u0,0),Vector2(u1,1),Vector2(u0,1)]:
    var x=(p.x-.5)*5.05
    var y=.15+float(k)*.31+.15*sin(x*1.3+float(k))
    var z=.17+float(k)*.08+.3*sin(x*1.1+float(k)*2.3)+(p.y-.5)*.44
    st.set_uv(p);st.add_vertex(axis*x*sx+normal*z*sz+Vector3.UP*y)
  st.generate_normals();var n=MeshInstance3D.new();n.mesh=st.commit();var m=ShaderMaterial.new();m.shader=load("res://visual_rework_20261009/views/q3_mist.gdshader");m.set_shader_parameter("seed",float(k)*1.71);n.material_override=m;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(n);mist.append(n)
func collapse(direction:Vector3)->void:
 collapse_direction=direction;collapse_age=0.0
func present_at(source_age:float,remaining:float,source_collapse_age:float=-1.0)->void:
 age=maxf(0.0,source_age)
 collapse_age=source_collapse_age
 rock_material.set_shader_parameter("age",age)
 rock_material.set_shader_parameter("fade",smoothstep(0.0,.45,remaining) if collapse_age<0.0 else 1.0-smoothstep(.55,1.20,collapse_age))
 for i in range(chunks.size()):
  var n:MeshInstance3D=chunks[i]
  if collapse_age<0.0:
   n.scale.y=maxf(.015,smoothstep(float(i)*.008,.40+float(i)*.008,age))
  else:
   var t=maxf(0.0,collapse_age-float(i%4)*.026)
   n.position=n.get_meta("home")+collapse_direction*(t*(5.3+.6*sin(float(i)*1.7)))+normal*(sin(float(i)*3.4)*t*.23)+Vector3.UP*(sin(minf(t*3.0,PI))*.10-t*.65)
   n.rotation=Vector3(collapse_direction.z,0,-collapse_direction.x)*t*(2.2+.3*sin(float(i)*2.3))
   n.scale.y=1.0-smoothstep(.10,.72,t)*.88
 for i in range(mist.size()):
  mist[i].material_override.set_shader_parameter("age",age)
  mist[i].material_override.set_shader_parameter("strength",smoothstep(0.0,.2,age)*(smoothstep(0.0,.5,remaining) if collapse_age<0 else 1.0-smoothstep(.1,.8,collapse_age)))
 visible=remaining>0.0 if collapse_age<0.0 else collapse_age<1.25
