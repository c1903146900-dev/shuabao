extends RefCounted
static func mat(color:Color)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.96;m.cull_mode=BaseMaterial3D.CULL_DISABLED
 if color.a<1:m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 return m
static func mesh(parent:Node3D,m:Mesh,p:Vector3,material:Material)->MeshInstance3D:
 var n=MeshInstance3D.new();n.mesh=m;n.position=p;n.material_override=material;parent.add_child(n);return n
static func stick(parent:Node3D,a:Vector3,b:Vector3,r:float,material:Material)->MeshInstance3D:
 var m=CylinderMesh.new();m.top_radius=r*.6;m.bottom_radius=r;m.height=a.distance_to(b);m.radial_segments=7
 var n=mesh(parent,m,(a+b)*.5,material);n.quaternion=Quaternion(Vector3.UP,(b-a).normalized());return n
static func boat()->Node3D:
 var root=Node3D.new();var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var dark=mat(Color(.14,.13,.105));var wood=mat(Color(.23,.205,.15));var cloth=mat(Color(.23,.25,.23))
 # Tapered continuous hull, curvature belongs to the geometry rather than picture wobble.
 for i in range(30):
  var a=-1.3+2.6*i/30.0;var b=-1.3+2.6*(i+1)/30.0
  var wa=.38*pow(maxf(0,1-pow(a/1.3,2)),.7);var wb=.38*pow(maxf(0,1-pow(b/1.3,2)),.7)
  for side in [-1,1]:
   var p=[Vector3(a,.10+pow(absf(a)/1.3,3)*.14,wa*side),Vector3(b,.10+pow(absf(b)/1.3,3)*.14,wb*side),Vector3(a,-.09,wa*.58*side),Vector3(b,-.09,wb*.58*side)]
   for k in [0,2,1,1,2,3]:st.add_vertex(p[k])
 st.generate_normals();mesh(root,st.commit(),Vector3.ZERO,dark)
 var deck=SurfaceTool.new();deck.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(30):
  var a=-1.24+2.48*i/30.0;var b=-1.24+2.48*(i+1)/30.0
  var wa=.34*pow(maxf(0,1-pow(a/1.3,2)),.7);var wb=.34*pow(maxf(0,1-pow(b/1.3,2)),.7)
  for v in [Vector3(a,.055,-wa),Vector3(a,.055,wa),Vector3(b,.055,-wb),Vector3(b,.055,-wb),Vector3(a,.055,wa),Vector3(b,.055,wb)]:deck.add_vertex(v)
 deck.generate_normals();mesh(root,deck.commit(),Vector3.ZERO,wood)
 for i in range(9):
  var x=-1.0+i*.25;stick(root,Vector3(x,.02,-.21),Vector3(x,.02,.21),.035,wood)
 # Seated fisher: low cone rain cape, hat brim, head and held rod readable from gameplay view.
 var cape=CylinderMesh.new();cape.top_radius=.085;cape.bottom_radius=.28;cape.height=.5;cape.radial_segments=13
 mesh(root,cape,Vector3(-.3,.38,0),cloth)
 var hat=CylinderMesh.new();hat.top_radius=.005;hat.bottom_radius=.29;hat.height=.13;hat.radial_segments=20
 mesh(root,hat,Vector3(-.3,.72,0),wood)
 stick(root,Vector3(-.27,.43,0),Vector3(.05,.29,-.13),.038,cloth)
 stick(root,Vector3(.04,.29,-.13),Vector3(1.26,.6,-1.02),.018,wood)
 stick(root,Vector3(1.26,.6,-1.02),Vector3(1.30,.03,-1.02),.005,mat(Color(.48,.49,.46,.65)))
 return root
static func mountain(seed_number:int)->Node3D:
 var root=Node3D.new();var rng=RandomNumberGenerator.new();rng.seed=seed_number+1937
 var profile=[0.0,.2,.45,1.15,.8,1.6,1.05,.56,.83,.31,.1,0.0]
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(profile.size()-1):
  var x=-1.9+3.8*i/(profile.size()-1.0);var nx=-1.9+3.8*(i+1)/(profile.size()-1.0)
  var height=float(profile[i])*(.9+rng.randf()*.17);var nh=float(profile[i+1])*(.9+rng.randf()*.17)
  for side in [-1,1]:
   var p=[Vector3(x,height,0),Vector3(nx,nh,0),Vector3(x,0,side*(.8+.2*sin(i))),Vector3(nx,0,side*(.8+.2*sin(i+1)))]
   for k in [0,2,1,1,2,3]:st.set_uv(Vector2((p[k].x+1.9)/3.8,p[k].y/1.8));st.add_vertex(p[k])
 st.generate_normals();var material=ShaderMaterial.new();material.shader=load("res://visual_rework_20261009/views/r_legacy_mountain.gdshader");mesh(root,st.commit(),Vector3.ZERO,material)
 root.rotation.y=rng.randf()*TAU
 return root
