extends Node3D
## Original cold-forged tracking dagger / bone nail meshes. Runtime position owns all travel.
var body:Node3D
var projectile_type:="dagger"
var visual_height_scale:=1.25
func configure(kind:String,height_scale:float)->void:
 projectile_type=kind;visual_height_scale=height_scale
 body=Node3D.new();body.position.y=1.05*height_scale;add_child(body)
 if kind=="dagger":
  _part(_blade(.070,.48,.018),Color("c2d1db"),Vector3(0,0,.48))
  _part(_blade(.016,.18,.020),Color("76283b"),Vector3(0,0,.79))
  var guard:=BoxMesh.new();guard.size=Vector3(.22,.040,.05);_part(guard,Color("7c93a4"),Vector3(0,0,.665))
 else:
  _part(_blade(.067,.70,.032),Color("f0e4cd"),Vector3(0,0,.70))
  var head:=BoxMesh.new();head.size=Vector3(.13,.065,.065);_part(head,Color("8f999d"),Vector3(0,0,1.01))
func sync_projectile(data:Dictionary)->void:
 position=data.position
 if projectile_type=="bone_nail":
  var count:int=maxi(1,int(data.get("count",1)));var index:int=int(data.get("index",0))
  body.scale.x=clampf(8.0/float(count),.48,1.0)
  body.position.x=lerpf(-float(data.get("width",2.8))*.36,float(data.get("width",2.8))*.36,float(index)/float(count-1)) if count>1 else 0.0
  if count>1:
   body.position.x+=.020*sin(index*2.1)
   body.scale.z=.84+.22*(.5+.5*sin(index*1.91))
   body.rotation.z=.10*sin(index*1.63)
  body.position.y=(1.05+(.105*sin(index*2.4) if count>1 else 0.0))*visual_height_scale
 var direction:Vector3=data.get("direction",Vector3.FORWARD)
 if direction.length_squared()>.0001:rotation.y=atan2(-direction.x,-direction.z)
func _part(shape:Mesh,color:Color,at:Vector3)->void:
 var node:=MeshInstance3D.new();node.mesh=shape;node.position=at
 var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.vertex_color_use_as_albedo=true;mat.metallic=.65 if projectile_type=="dagger" else .12;mat.roughness=.34 if projectile_type=="dagger" else .6
 node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;body.add_child(node)
func _blade(width:float,length:float,thickness:float)->ArrayMesh:
 var v:=PackedVector3Array([Vector3(0,0,-length),Vector3(-width,0,0),Vector3(0,thickness,-.03),Vector3(width,0,0),Vector3(0,-thickness,-.03),Vector3(0,0,.11)])
 var i:=PackedInt32Array([0,1,2,0,2,3,0,3,4,0,4,1,5,2,1,5,3,2,5,4,3,5,1,4])
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for index in i:
  surface.set_color(Color(.25,.31,.36) if index==4 else Color(.78,.81,.80) if index in [1,3,5] else Color(1,1,1))
  surface.add_vertex(v[index])
 surface.generate_normals();return surface.commit()
