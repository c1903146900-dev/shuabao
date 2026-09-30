# Execute ONLY through Blender MCP execute_blender_code. Blender 4.3.
import bpy, math, json
from mathutils import Vector, Quaternion, Matrix, Euler
from pathlib import Path
OUT=Path('/workspace/shuabao/.local/mcp-fixture/assets')
(OUT/'fengli').mkdir(parents=True,exist_ok=True)
(OUT/'arena').mkdir(parents=True,exist_ok=True)
(OUT/'fengli/source').mkdir(exist_ok=True)
(OUT/'fengli/source/.gdignore').touch()
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
def mat(n,c,metal=0,rough=.5):
 m=bpy.data.materials.new(n); m.diffuse_color=(*c,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*c,1); p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 return m
cloth=mat('01 • storm teal',(.035,.18,.21)); armor=mat('02 • blue steel',(.14,.25,.29),.65,.32); edge=mat('03 • pale brass',(.72,.53,.26),.65,.3); dark=mat('04 • ink leather',(.025,.045,.06)); skin=mat('05 • warm porcelain',(.64,.43,.30)); hair=mat('06 • ash silver',(.72,.8,.78),.15); blade=mat('07 • honed silver',(.67,.84,.87),.85,.2); glow=mat('08 • jade inlay',(.07,.7,.6),.3)
parts=[]
def mesh(n,v,f,m,bone=None):
 me=bpy.data.meshes.new(n);me.from_pydata(v,[],f);me.update();o=bpy.data.objects.new(n,me);bpy.context.collection.objects.link(o);o.data.materials.append(m)
 if bone: parts.append((o,bone))
 return o
def rings(n,rs,m,bone=None,N=8):
 v=[(x+rx*math.cos(2*math.pi*j/N),y+ry*math.sin(2*math.pi*j/N),z) for x,y,z,rx,ry in rs for j in range(N)]
 f=[tuple(reversed(range(N)))]+[(k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j) for k in range(len(rs)-1) for j in range(N)]+[tuple((len(rs)-1)*N+j for j in range(N))]
 return mesh(n,v,f,m,bone)
def segment(n,a,b,r1,r2,m,bone,N=8):
 a,b=Vector(a),Vector(b);d=b-a; q=d.to_track_quat('Z','Y');v=[]
 for p,r in [(a,r1),(b,r2)]:
  for j in range(N):v.append(p+q@Vector((r*math.cos(j*2*math.pi/N),r*.8*math.sin(j*2*math.pi/N),0)))
 return mesh(n,v,[tuple(reversed(range(N))),tuple(range(N,2*N))]+[(j,(j+1)%N,(j+1)%N+N,j+N) for j in range(N)],m,bone)
def box(n,loc,scale,m,bone=None,bevel=.025):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=n;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
 if bevel:
  mod=o.modifiers.new('crafted bevel','BEVEL');mod.width=bevel;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 if bone:parts.append((o,bone))
 return o
# shaped chest, waist and tailored split coat
rings('Tailored torso',[(0,0,1.02,.18,.12),(0,0,1.2,.19,.13),(0,0,1.47,.30,.155),(0,0,1.55,.25,.13)],cloth,'chest')
rings('Waist wrap',[(0,0,.93,.22,.13),(0,0,1.08,.18,.13)],dark,'hips')
rings('Breastplate',[(0,.025,1.21,.185,.13),(0,.035,1.42,.265,.16),(0,.02,1.5,.22,.14)],armor,'chest')
box('Gilded belt',(0,.005,1.06),(.40,.29,.055),edge,'hips',.01)
box('Belt jade clasp',(0,.161,1.06),(.09,.035,.075),glow,'hips',.012)
for s in [-1,1]:
 # hip to ankle articulated silhouette
 segment('Trouser thigh',(.13*s,0,.99),(.16*s,.025,.59),.125,.085,dark,'thigh'+str(s))
 segment('Shin greave',(.16*s,.025,.57),(.16*s,0,.17),.087,.06,armor,'shin'+str(s))
 box('Toe boot',(.16*s,.09,.10),(.16,.31,.18),dark,'foot'+str(s),.04)
 box('Knee shield',(.16*s,.088,.58),(.17,.095,.17),edge,'shin'+str(s),.035)
 segment('Sleeve',(.27*s,0,1.47),(.41*s,.015,1.20),.1,.068,cloth,'upper'+str(s))
 segment('Bracer',(.41*s,.015,1.20),(.5*s,.06,1.00),.079,.06,armor,'fore'+str(s))
 box('Glove',(.5*s,.06,.99),(.115,.12,.14),dark,'hand'+str(s),.025)
 # individually tapered cloth panels, angular hem
 mesh('Split coat '+str(s),[(.045*s,-.07,1.02),(.22*s,-.04,1.02),(.29*s,-.06,.62),(.1*s,-.11,.56),(.045*s,-.15,1.02),(.22*s,-.18,1.02),(.29*s,-.16,.62),(.1*s,-.20,.56)],[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],cloth,'hips')
# one exaggerated pauldron, high collar, face / brows readable at distance
rings('Left layered pauldron',[(-.29,0,1.38,.14,.18),(-.30,0,1.51,.18,.19),(-.26,0,1.57,.12,.14)],armor,'upper-1')
segment('Neck',(0,0,1.5),(0,0,1.64),.08,.075,skin,'head')
rings('Raised collar',[(0,-.02,1.49,.13,.105),(0,-.02,1.62,.115,.095)],dark,'chest')
rings('Angular face',[(0,.02,1.60,.055,.06),(0,.025,1.68,.10,.095),(0,0,1.80,.12,.105),(0,-.015,1.88,.085,.075)],skin,'head')
rings('Swept silver crown',[(0,-.04,1.76,.123,.092),(0,-.035,1.87,.135,.105),(-.04,-.07,1.94,.075,.06),(-.08,-.105,1.95,.012,.015)],hair,'head')
for s in [-1,1]:
 box('Dark eyebrow',(.048*s,.099,1.77),(.062,.018,.021),dark,'head',.003)
 box('Jade eye',(.047*s,.11,1.752),(.033,.014,.012),glow,'head',.002)
 mesh('Temple swept lock',[(s*.1,.045,1.87),(s*.14,-.06,1.85),(s*.095,.085,1.71),(s*.06,.05,1.83)],[(0,1,2),(0,2,3),(0,3,1),(1,3,2)],hair,'head')
# asymmetric flowing scarf anchored to chest
mesh('Scarf tail',[(-.09,-.13,1.56),(.09,-.13,1.56),(.13,-.34,1.37),(.02,-.49,1.16),(-.05,-.43,1.2),(-.08,-.3,1.38)],[(0,1,2,5),(5,2,3,4)],cloth,'chest')
# sword held in right glove, blade extends forward (+Y -> Godot -Z)
segment('Sword grip',(.5,-.02,1.0),(.5,.20,1.0),.027,.027,dark,'weapon',8)
box('Swept crossguard',(.5,.2,1),(.32,.055,.055),edge,'weapon',.015)
mesh('Long diamond blade',[(.5,.23,1.027),(.565,.23,1),(.5,.23,.973),(.435,.23,1),(.5,1.23,1.025),(.548,1.13,1),(.5,1.23,.975),(.452,1.13,1),(.5,1.48,1)],[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,8),(5,6,8),(6,7,8),(7,4,8),(3,2,1,0)],blade,'weapon')
box('Sword jade fuller',(.5,.63,1.029),(.018,.72,.008),glow,'weapon',.002)
# bone hierarchy / rigid armor skinning; meaningful per-limb animation
bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='Fengli';bpy.ops.object.mode_set(mode='EDIT');eb=rig.data.edit_bones;eb.remove(eb[0])
def bone(n,h,t,p=None):
 b=eb.new(n);b.head=h;b.tail=t
 if p:b.parent=eb[p]
bone('root',(0,0,0),(0,0,.2));bone('hips',(0,0,.95),(0,0,1.15),'root');bone('chest',(0,0,1.15),(0,0,1.5),'hips');bone('head',(0,0,1.55),(0,0,1.85),'chest')
for s in [-1,1]:
 bone('thigh'+str(s),(.13*s,0,.99),(.16*s,.025,.59),'hips');bone('shin'+str(s),(.16*s,.025,.59),(.16*s,0,.17),'thigh'+str(s));bone('foot'+str(s),(.16*s,0,.17),(.16*s,.18,.10),'shin'+str(s))
 bone('upper'+str(s),(.27*s,0,1.47),(.41*s,.015,1.2),'chest');bone('fore'+str(s),(.41*s,.015,1.2),(.5*s,.06,1),'upper'+str(s));bone('hand'+str(s),(.5*s,.06,1),(.5*s,.16,1),'fore'+str(s))
bone('weapon',(.5,.06,1),(.5,.3,1),'hand1');bone('socket_blade_tip',(.5,1.48,1),(.5,1.55,1),'weapon');bone('socket_back',(0,-.15,1.4),(0,-.15,1.6),'chest')
bpy.ops.object.mode_set(mode='OBJECT')
for o,b in parts:
 g=o.vertex_groups.new(name=b);g.add(list(range(len(o.data.vertices))),1,'REPLACE');mod=o.modifiers.new('Fengli skin','ARMATURE');mod.object=rig;o.parent=rig
for p in rig.pose.bones:p.rotation_mode='XYZ'
scene=bpy.context.scene;scene.render.fps=30
clips={'idle':60,'run':24,'attack':24,'dash':18,'thrust':27,'overload':45,'ultimate':60,'hit':18,'death':48}
# Euler offsets are LOCAL bone rotations, not whole-object rotation.
def pose(frame,vals,drop=0):
 for p in rig.pose.bones:
  p.rotation_euler=(0,0,0);p.location=(0,0,0)
 for n,rot in vals.items():rig.pose.bones[n].rotation_euler=tuple(math.radians(x) for x in rot)
 rig.pose.bones['hips'].location.y=drop
 # Chest local +X leans backward; invert designed forward lean.
 rig.pose.bones['chest'].rotation_euler.x *= -1
 bpy.context.view_layer.update()
 # Art-directed sword orientation preserves a forward thrust and readable slash plane.
 angles = {
 'attack': {0:(0,0,0),7:(8,0,-75),10:(-8,0,70),16:(-5,0,35),24:(0,0,0)},
 'thrust': {0:(0,0,0),8:(0,0,-12),11:(0,0,0),17:(0,0,0),27:(0,0,0)},
 'dash': {0:(0,0,0),4:(-15,0,25),8:(-15,0,35),13:(-8,0,15),18:(0,0,0)},
 'overload': {0:(0,0,0),14:(65,0,0),23:(80,0,0),28:(-15,0,0),45:(0,0,0)},
 'ultimate': {0:(0,0,0),17:(10,0,-90),23:(-5,0,85),30:(80,0,0),35:(-20,0,0),45:(-10,0,10),60:(0,0,0)}}
 if name in angles:
  wp=rig.pose.bones['weapon']
  rotation=Euler(tuple(math.radians(x) for x in angles[name][frame]),'XYZ').to_quaternion() @ wp.bone.matrix_local.to_quaternion()
  wp.matrix=Matrix.LocRotScale(wp.matrix.translation,rotation,Vector((1,1,1)))
  bpy.context.view_layer.update()
 for p in rig.pose.bones:
  p.keyframe_insert('rotation_euler',frame=frame,group=p.name);p.keyframe_insert('location',frame=frame,group=p.name)
for name,end in clips.items():
 a=bpy.data.actions.new(name);rig.animation_data_create();rig.animation_data.action=a
 if name=='idle':
  for f,k in [(0,0),(30,1),(60,0)]:pose(f,{'chest':(2*k,0,-2),'fore1':(-8-k*3,0,0),'head':(0,0,k*3)},k*.012)
 elif name=='run':
  for f,k in [(0,1),(6,0),(12,-1),(18,0),(24,1)]:pose(f,{'chest':(12,0,0),'thigh1':(38*k,0,0),'thigh-1':(-38*k,0,0),'shin1':(-35*max(0,-k),0,0),'shin-1':(-35*max(0,k),0,0),'upper1':(-24*k,0,-12),'upper-1':(28*k,0,8),'fore1':(-20,0,0),'fore-1':(-35,0,0)},.025*(1-abs(k)))
 else:
  poses={
  'attack':[(0,{}),(7,{'chest':(0,0,-30),'upper1':(-75,0,-65),'fore1':(-50,0,0)}),(10,{'chest':(12,0,42),'upper1':(65,0,45),'fore1':(-12,0,0)}),(16,{'chest':(8,0,25),'upper1':(35,0,30)}),(24,{})],
  'dash':[(0,{}),(4,{'chest':(35,0,0),'thigh1':(55,0,0),'shin1':(-65,0,0),'upper1':(-30,0,-15)}),(8,{'chest':(48,0,0),'thigh1':(-35,0,0),'thigh-1':(50,0,0),'upper-1':(-65,0,0)}),(13,{'chest':(20,0,0),'thigh1':(30,0,0)}),(18,{})],
  'thrust':[(0,{}),(8,{'chest':(-8,0,-20),'upper1':(-45,0,-15),'fore1':(-75,0,0)}),(11,{'chest':(28,0,10),'upper1':(80,0,0),'fore1':(0,0,0),'thigh1':(35,0,0),'shin1':(-35,0,0)}),(17,{'chest':(20,0,8),'upper1':(65,0,0)}),(27,{})],
  'overload':[(0,{}),(14,{'chest':(-12,0,0),'upper1':(-135,0,-20),'fore1':(-25,0,0),'upper-1':(-60,0,45),'head':(-15,0,0)}),(23,{'chest':(-18,0,8),'upper1':(-160,0,0),'upper-1':(-100,0,55)}),(28,{'chest':(28,0,0),'upper1':(60,0,0),'upper-1':(25,0,20),'thigh1':(25,0,0)}),(45,{})],
  'ultimate':[(0,{}),(17,{'chest':(-8,0,-50),'upper1':(-100,0,-75),'fore1':(-70,0,0),'thigh1':(40,0,0)}),(23,{'chest':(18,0,65),'upper1':(70,0,90),'upper-1':(-20,0,-65)}),(30,{'chest':(-10,0,-35),'upper1':(-150,0,0),'fore1':(-40,0,0)}),(35,{'chest':(40,0,20),'upper1':(80,0,10),'thigh1':(55,0,0),'shin1':(-65,0,0)}),(45,{'chest':(20,0,10),'upper1':(40,0,15)}),(60,{})],
  'hit':[(0,{}),(3,{'chest':(-24,0,-12),'head':(-18,0,10),'upper1':(-20,0,-25),'upper-1':(-25,0,25)}),(8,{'chest':(-12,0,-5)}),(18,{})],
  'death':[(0,{}),(9,{'chest':(-25,0,10),'head':(-20,0,0)}),(20,{'hips':(-35,0,10),'chest':(-20,0,5),'thigh1':(40,0,0),'shin1':(-50,0,0)}),(32,{'hips':(-88,0,5),'chest':(-5,0,0),'upper1':(15,0,-45),'upper-1':(15,0,45)}),(48,{'hips':(-88,0,5),'chest':(-5,0,0),'upper1':(15,0,-45),'upper-1':(15,0,45)})]}
  for f,v in poses[name]:pose(f,v,(-.82*min(1,f/32) if name=='death' else (-.10 if name=='dash' and 4<=f<=13 else 0)))
 for fc in a.fcurves:
  for k in fc.keyframe_points:k.interpolation='LINEAR' if name=='run' else 'BEZIER'
 a.use_fake_user=True
rig.animation_data.action=bpy.data.actions['idle'];scene.frame_set(0);scene.frame_end=60
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for o,b in parts:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'fengli/source/fengli.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'fengli/fengli.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False)
print('FENGLI_EXPORTED', {n:f/30 for n,f in clips.items()},'bones',len(rig.data.bones),'meshes',len(parts))
# viewport framing / material color
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  area.spaces.active.shading.type='MATERIAL';area.spaces.active.region_3d.view_distance=4.6;area.spaces.active.region_3d.view_location=(0,.2,1);area.spaces.active.region_3d.view_rotation=Quaternion((.82,.48,.16,.24))
