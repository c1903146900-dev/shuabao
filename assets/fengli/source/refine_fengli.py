# Run only via Blender MCP execute_blender_code. Refine baseline with baked two-bone IK.
import bpy, math, json
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion, Euler
r=bpy.data.objects['Fengli'];sc=bpy.context.scene
# Turn hard elbow/knee seams into small articulated cloth gussets, preserving armor silhouette.
for s in [-1,1]:
 for name,center,scale,bones in [('Elbow gusset',(.41*s,.015,1.20),(.069,.063,.070),['upper'+str(s),'fore'+str(s)]),('Knee gusset',(.16*s,.025,.59),(.075,.072,.073),['thigh'+str(s),'shin'+str(s)])]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=1,location=center)
  o=bpy.context.view_layer.objects.active;o.name=name+str(s);o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  o.data.materials.append(bpy.data.materials['04 • ink leather']);o.parent=r
  for n in bones:o.vertex_groups.new(name=n).add(list(range(len(o.data.vertices))),.5,'REPLACE')
  m=o.modifiers.new('Fengli skin','ARMATURE');m.object=r
# The former scarf was a rigid flap crossing the arm swing envelope. Retuck behind left shoulder.
o=bpy.data.objects.get('Scarf tail')
if o:
 for v in o.data.vertices:
  v.co.x-=.13;v.co.y-=.06

def orient(name,head,tail):
 p=r.pose.bones[name];rest=p.bone
 q=(rest.tail_local-rest.head_local).rotation_difference(Vector(tail)-Vector(head)) @ rest.matrix_local.to_quaternion()
 p.matrix=Matrix.LocRotScale(Vector(head),q,Vector((1,1,1)))
 bpy.context.view_layer.update()
def fixed_rotation(name,head,rotation=(0,0,0)):
 p=r.pose.bones[name]
 q=Euler(tuple(math.radians(v) for v in rotation),'XYZ').to_quaternion() @ p.bone.matrix_local.to_quaternion()
 p.matrix=Matrix.LocRotScale(Vector(head),q,Vector((1,1,1)));bpy.context.view_layer.update()
def ik(upper,lower,target,pole):
 p=r.pose.bones[upper];a=p.head.copy();b=Vector(target);d=b-a
 l1=p.bone.length;l2=r.pose.bones[lower].bone.length
 dist=min(d.length,l1+l2-.0001);direction=d.normalized();b=a+direction*dist
 x=(l1*l1-l2*l2+dist*dist)/(2*dist);height=math.sqrt(max(0,l1*l1-x*x))
 bend=Vector(pole)-a;bend-=direction*bend.dot(direction);bend.normalize()
 knee=a+direction*x+bend*height
 orient(upper,a,knee);orient(lower,knee,b)
 return b

def lerp_keys(keys,t):
 for (a,va),(b,vb) in zip(keys,keys[1:]):
  if a<=t<=b:
   k=(t-a)/(b-a);k=k*k*(3-2*k)
   return Vector(va).lerp(Vector(vb),k)
 return Vector(keys[-1][1])
ends={'idle':60,'run':24,'attack':24,'dash':18,'thrust':27,'overload':45,'ultimate':60,'hit':18,'death':48}
# Hand placements stay outside the chest envelope; paths arc in front of the body.
hand_paths={
 'attack':[(0,(.49,.14,1.04)),(7,(.68,.03,1.37)),(10,(.27,.49,1.30)),(16,(.18,.39,1.11)),(24,(.49,.14,1.04))],
 'thrust':[(0,(.49,.14,1.04)),(8,(.49,.08,1.26)),(11,(.37,.48,1.29)),(17,(.37,.43,1.26)),(27,(.49,.14,1.04))],
 'overload':[(0,(.49,.14,1.04)),(14,(.54,.16,1.69)),(23,(.48,.22,1.81)),(28,(.38,.47,1.02)),(45,(.49,.14,1.04))],
 'ultimate':[(0,(.49,.14,1.04)),(17,(.68,.03,1.41)),(23,(.63,.43,1.32)),(30,(.54,.25,1.81)),(35,(.38,.48,1.02)),(45,(.45,.33,1.1)),(60,(.49,.14,1.04))],
 'dash':[(0,(.49,.14,1.04)),(4,(.62,.04,.98)),(8,(.65,-.03,.92)),(13,(.55,.12,1.00)),(18,(.49,.14,1.04))],
 'hit':[(0,(.49,.14,1.04)),(3,(.58,.22,1.18)),(8,(.53,.18,1.10)),(18,(.49,.14,1.04))]}
# Existing chest/weapon pose is sampled first; refinement is baked without live constraints.
baselines={}
for name,end in ends.items():
 a=bpy.data.actions[name];r.animation_data.action=a;rows=[]
 for f in range(end+1):
  sc.frame_set(f);bpy.context.view_layer.update()
  rows.append({p.name:(p.matrix_basis.copy(),p.matrix.copy()) for p in r.pose.bones})
 baselines[name]=rows
for name,end in ends.items():
 old=bpy.data.actions[name];old.name='legacy_'+name;old.use_fake_user=False
 a=bpy.data.actions.new(name);r.animation_data.action=a
 for f in range(end+1):
  for p in r.pose.bones:p.matrix_basis=baselines[name][f][p.name][0]
  # Hard planted feet for idle/combat; run is calibrated for 2 m/s at speed_scale 1.
  if name!='death':
   for p in r.pose.bones:
    if p.name not in ['chest','head','weapon']:p.matrix_basis=Matrix.Identity(4)
   if name=='ultimate':r.pose.bones['chest'].rotation_euler.z*=.55
   hip_drop=-.105
   if name=='run':hip_drop=-.13+.014*math.cos(4*math.pi*f/24)
   if name in ['dash','thrust','ultimate']:hip_drop-=.06*math.sin(math.pi*f/end)**2
   r.pose.bones['hips'].location.y=hip_drop
   bpy.context.view_layer.update()
   for s in [-1,1]:
    y=0;z=.17;x=.16*s
    if name=='run':
     phase=(f/24+(0 if s==1 else .5))%1
     if phase<=.5:y=.4-1.6*phase
     else:
      k=(phase-.5)*2;y=-.4+.8*k;z+=.19*math.sin(math.pi*k)
    elif name in ['attack','thrust','ultimate']:
     # Stable split stance, no stepping in-place while loaded.
     y=.17*s;x=.19*s
    elif name=='dash':y=.20*s;x=.19*s
    ankle=ik('thigh'+str(s),'shin'+str(s),(x,y,z),(x,.9,.55))
    fixed_rotation('foot'+str(s),ankle)
   if name=='run':
    phase=2*math.pi*f/24
    hand=Vector((.51,.12+.18*math.sin(phase),1.09+.04*math.cos(phase)))
   elif name=='idle':hand=Vector((.49,.14,1.04))
   else:hand=lerp_keys(hand_paths[name],f)
   right=ik('upper1','fore1',hand,(1,.12,1.2))
   fixed_rotation('hand1',right)
   left=Vector((-.50,.12,1.03))
   if name=='run':left.y=.12-.18*math.sin(2*math.pi*f/24);left.z=1.12
   if name in ['dash','hit']:left=Vector((-.60,.12,.98 if name=='dash' else 1.20))
   wrist=ik('upper-1','fore-1',left,(-1,.15,1.2));fixed_rotation('hand-1',wrist)
   # Keep grip seated in the palm while preserving authored blade orientation.
   wp=r.pose.bones['weapon'];desired=baselines[name][f]['weapon'][1].to_quaternion()
   if name=='ultimate':
    angles=lerp_keys([(0,(0,0,0)),(17,(10,0,-75)),(23,(-5,0,45)),(26,(35,0,-20)),(30,(80,0,-20)),(32,(45,0,-10)),(35,(-20,0,0)),(45,(-10,0,10)),(60,(0,0,0))],f)
    desired=Euler(tuple(math.radians(x) for x in angles),'XYZ').to_quaternion() @ wp.bone.matrix_local.to_quaternion()
   wp.matrix=Matrix.LocRotScale(right,desired,Vector((1,1,1)));bpy.context.view_layer.update()
  for p in r.pose.bones:
   p.keyframe_insert('location',frame=f,group=p.name);p.keyframe_insert('rotation_euler',frame=f,group=p.name);p.keyframe_insert('scale',frame=f,group=p.name)
 for fc in a.fcurves:
  for k in fc.keyframe_points:k.interpolation='LINEAR'
 a.use_fake_user=True
 bpy.data.actions.remove(old)
r.animation_data.action=bpy.data.actions['idle'];sc.frame_set(0);sc.frame_end=60
bpy.ops.object.select_all(action='DESELECT');r.select_set(True)
for o in bpy.data.objects:
 if o.type=='MESH':o.select_set(True)
bpy.context.view_layer.objects.active=r
out=Path('/workspace/shuabao/.local/mcp-fixture/assets/fengli')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'source/fengli.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'fengli.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False)
print('REFINEMENT_BAKED',len(r.data.bones),list(ends))
