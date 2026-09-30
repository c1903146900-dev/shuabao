# Entire payload is executed by Blender MCP execute_blender_code. No direct bpy process.
import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix,Euler
KIND=globals().get('ENEMY_KIND','minion')
P={'minion':dict(h=1.68,w=.24,hip=.84,shoulder=1.29,arm=.29,leg=.31,color=(.38,.12,.065),warning=.85,recovery=1.1,speed=2.35),
   'elite':dict(h=2.12,w=.33,hip=1.03,shoulder=1.62,arm=.36,leg=.39,color=(.31,.36,.32),warning=1.,recovery=1.1,speed=1.95),
   'boss':dict(h=2.78,w=.48,hip=1.26,shoulder=2.13,arm=.55,leg=.47,color=(.28,.095,.10),warning=1.35,recovery=1.6,speed=1.5)}[KIND]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
OUT=Path('/workspace/shuabao/.local/mcp-fixture/assets/arena/enemies');(OUT/'source').mkdir(parents=True,exist_ok=True);(OUT/'source/.gdignore').touch()
parts=[]
def mat(n,c,metal=0):
 m=bpy.data.materials.new(KIND+' '+n);m.diffuse_color=(*c,1);m.use_nodes=True;q=m.node_tree.nodes.get('Principled BSDF');q.inputs['Base Color'].default_value=(*c,1);q.inputs['Metallic'].default_value=metal;q.inputs['Roughness'].default_value=.57;return m
armor=mat('armor',P['color'],.35);dark=mat('charcoal joints',(.037,.052,.06));trim=mat('aged brass',(.47,.30,.12),.6);pale=mat('ivory plate',(.49,.52,.44),.3);steel=mat('steel edge',(.43,.51,.53),.65);cloth=mat('cloth',(.15,.065,.045) if KIND=='minion' else (.07,.10,.115));eye=mat('eye slit',(.8,.25,.055))
def mesh(n,v,f,m,b):
 me=bpy.data.meshes.new(n);me.from_pydata(v,[],f);me.update();o=bpy.data.objects.new(n,me);bpy.context.collection.objects.link(o);o.data.materials.append(m);parts.append((o,b));return o
def rings(n,rs,m,b,N=8):
 v=[(x+rx*math.cos(j*2*math.pi/N),y+ry*math.sin(j*2*math.pi/N),z) for x,y,z,rx,ry in rs for j in range(N)]
 f=[tuple(reversed(range(N)))]+[(k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j) for k in range(len(rs)-1) for j in range(N)]+[tuple((len(rs)-1)*N+j for j in range(N))]
 return mesh(n,v,f,m,b)
def box(n,c,s,m,b,bev=.025):
 bpy.ops.mesh.primitive_cube_add(size=1,location=c);o=bpy.context.view_layer.objects.active;o.name=n;o.dimensions=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
 if bev:
  mod=o.modifiers.new('chamfer','BEVEL');mod.width=bev;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 parts.append((o,b));return o
def seg(n,a,b,ra,rb,m,bone):
 a,b=Vector(a),Vector(b);q=(b-a).to_track_quat('Z','Y');v=[]
 for p,radius in [(a,ra),(b,rb)]:
  for j in range(8):v.append(p+q@Vector((radius*math.cos(j*math.pi/4),radius*.8*math.sin(j*math.pi/4),0)))
 return mesh(n,v,[tuple(reversed(range(8))),tuple(range(8,16))]+[(j,(j+1)%8,(j+1)%8+8,j+8) for j in range(8)],m,bone)
h=P['h'];hip=P['hip'];sh=P['shoulder'];w=P['w'];arm=P['arm'];leg=P['leg'];ankle=.15 if KIND=='minion' else (.18 if KIND=='elite' else .22)
# Bone rest heads/tails use +Y forward, +Z up. Feet plane z=.01.
bones=[('root',(0,0,0),(0,0,.2),None),('hips',(0,0,hip),(0,0,hip+.15),'root'),('chest',(0,0,hip+.15),(0,0,sh),'hips'),('head',(0,0,sh+.07),(0,0,h-.1),'chest')]
for s in [-1,1]:
 x=s*w*.62;shoulder=(s*(w+.055),0,sh);elbow=(s*(w+.10),0,sh-arm);hand=(s*(w+.12),.025,sh-arm*2)
 bones.extend([('thigh'+str(s),(x,0,hip),(x,.035,ankle+leg),'hips'),('shin'+str(s),(x,.035,ankle+leg),(x,0,ankle),'thigh'+str(s)),('foot'+str(s),(x,0,ankle),(x,.2,ankle-.04),'shin'+str(s)),('upper'+str(s),shoulder,elbow,'chest'),('fore'+str(s),elbow,hand,'upper'+str(s)),('hand'+str(s),hand,(hand[0],hand[1]+.12,hand[2]),'fore'+str(s))])
handz=sh-arm*2
bones.extend([('weapon',(w+.12,.025,handz),(w+.12,.30,handz),'hand1'),('socket_weapon_tip',(w+.12,{'minion':.87,'elite':.76,'boss':.89}[KIND],handz),(w+.12,{'minion':.97,'elite':.86,'boss':.99}[KIND],handz),'weapon'),('socket_warning',(0,0,.015),(0,.1,.015),'root')])
rings('Tapered armored torso',[(0,0,hip,.76*w,.15),(0,0,hip+.2,.78*w,.17),(0,0,sh-.08,w,.20 if KIND!='boss' else .30),(0,0,sh+.035,.83*w,.17 if KIND!='boss' else .27)],armor,'chest')
rings('Waist',[(0,0,hip-.12,.85*w,.16),(0,0,hip+.04,.78*w,.17)],dark,'hips')
box('Belt',(0,0,hip+.02),(w*1.65,.35,.075),trim,'hips')
for s in [-1,1]:
 x=s*w*.62
 seg('Thigh '+str(s),(x,0,hip),(x,.035,ankle+leg),w*.32,w*.25,cloth,'thigh'+str(s))
 seg('Greave '+str(s),(x,.035,ankle+leg),(x,0,ankle),w*.28,w*.22,armor,'shin'+str(s))
 box('Boot '+str(s),(x,.07,(ankle+.01)/2),(w*.58,.32 if KIND!='boss' else .43,ankle-.01),dark,'foot'+str(s))
 box('Knee cap '+str(s),(x,.09,ankle+leg),(w*.58,.12,.15 if KIND!='boss' else .22),pale,'shin'+str(s))
 seg('Upper arm '+str(s),(s*(w+.055),0,sh),(s*(w+.1),0,sh-arm),w*.3,w*.24,cloth,'upper'+str(s))
 seg('Forearm '+str(s),(s*(w+.1),0,sh-arm),(s*(w+.12),.025,handz),w*.30,w*.22,armor,'fore'+str(s))
 box('Gauntlet '+str(s),(s*(w+.12),.025,handz),(w*.48,.15,.16),dark,'hand'+str(s))
 # Small joint gussets rather than capsule limbs.
 for joint,z,bone in [('elbow',sh-arm,'fore'),('knee',ankle+leg,'shin')]:
  rings(joint+str(s),[(s*(w+.1) if joint=='elbow' else x,.02,z-.05,w*.235,w*.20),(s*(w+.1) if joint=='elbow' else x,.02,z+.05,w*.235,w*.20)],dark,bone+str(s))
# Three deliberately different silhouettes, not scaled copies.
if KIND=='minion':
 rings('Narrow hood',[(0,-.02,sh,.13,.13),(0,-.025,h-.10,.16,.15),(-.035,-.07,h,.025,.03)],cloth,'head')
 box('Slit mask',(0,.115,h-.22),(.19,.065,.23),pale,'head')
 box('Eye slit',(0,.154,h-.2),(.14,.012,.026),dark,'head',.003)
 rings('Asymmetric leather shoulder',[(-w-.025,0,sh-.06,.10,.16),(-w-.04,0,sh+.10,.14,.17)],armor,'upper-1')
 for s in [-1,1]:
  mesh('Short split tab '+str(s),[(s*.04,-.1,hip),(s*.19,-.09,hip),(s*.24,-.12,hip-.32),(s*.08,-.16,hip-.36)],[(0,1,2,3)],cloth,'hips')
 # Faceted hooked cleaver in the forward horizontal plane.
 x=w+.12;z=handz
 seg('Wrapped grip',(x,-.05,z),(x,.18,z),.024,.024,dark,'weapon')
 mesh('Hooked cleaver',[(x-.035,.18,z-.018),(x+.035,.18,z-.018),(x+.16,.67,z-.018),(x+.07,.87,z-.018),(x-.04,.63,z-.018),(x-.035,.18,z+.018),(x+.035,.18,z+.018),(x+.16,.67,z+.018),(x+.07,.87,z+.018),(x-.04,.63,z+.018)],[(0,1,2,3,4),(9,8,7,6,5)]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)],steel,'weapon')
elif KIND=='elite':
 rings('Crest helm',[(0,0,sh+.02,.12,.12),(0,0,h-.13,.20,.17),(0,-.02,h-.02,.11,.11)],pale,'head')
 box('Helmet transverse crest',(0,-.01,h),(.49,.075,.15),trim,'head')
 box('Dark visor',(0,.17,h-.24),(.28,.03,.065),dark,'head')
 for s in [-1,1]:box('Layered pauldron '+str(s),(s*(w+.04),0,sh+.02),(.32,.40,.20),pale,'upper'+str(s),.05)
 # Forward canted tower shield with narrow waist and reinforced central ridge.
 x=-w-.12;z=handz
 v=[(x-.27,.10,z-.40),(x+.27,.10,z-.40),(x+.33,.10,z+.40),(x,.10,z+.61),(x-.33,.10,z+.40)]
 vv=v+[(a,b+.085,c) for a,b,c in v]
 mesh('Tower shield',vv,[(4,3,2,1,0),(5,6,7,8,9)]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)],pale,'hand-1')
 box('Shield central ridge',(x,.205,z+.04),(.075,.05,.91),trim,'hand-1')
 x=w+.12
 seg('War pick haft',(x,-.14,z),(x,.76,z),.035,.035,dark,'weapon')
 mesh('Beaked war pick',[(x-.10,.63,z-.06),(x+.27,.63,z-.035),(x+.45,.57,z),(x+.27,.72,z+.035),(x-.10,.72,z+.06)],[(0,1,2,3,4),(4,3,2,1,0)],steel,'weapon')
 box('Pick poll',(x-.14,.68,z),(.22,.18,.17),trim,'weapon')
else:
 rings('Stone mask',[(0,0,sh+.03,.22,.2),(0,0,h-.20,.26,.22),(0,-.03,h-.09,.18,.17)],pale,'head')
 box('Deep boss visor',(0,.215,h-.36),(.34,.055,.07),dark,'head')
 box('Boss eye slit',(0,.25,h-.36),(.21,.013,.018),eye,'head',.002)
 for s in [-1,1]:
  rings('Octagonal bastion shoulder '+str(s),[(s*.56,-.03,sh-.16,.24,.29),(s*.57,-.04,sh+.13,.30,.32),(s*.52,-.08,sh+.24,.20,.23)],pale,'upper'+str(s))
  # Open silhouette behind head, leaves the central warning direction visible.
  box('Back fork upright '+str(s),(s*.32,-.31,sh+.28),(.13,.15,.73),trim,'chest')
 box('Back fork crossbar',(0,-.31,sh+.07),(.75,.16,.14),trim,'chest')
 box('Chest recessed plaque',(0,.29,sh-.25),(.42,.06,.40),dark,'chest')
 box('Chest brass vertical',(0,.335,sh-.25),(.07,.025,.30),trim,'chest')
 x=w+.12;z=handz
 seg('Great maul haft',(x,-.28,z),(x,.94,z),.052,.045,dark,'weapon')
 box('Great maul head',(x,.89,z),(.72,.38,.34),pale,'weapon',.065)
 for s in [-1,1]:box('Maul striking collar',(x+s*.31,.89,z),(.10,.40,.35),trim,'weapon',.025)
bpy.ops.object.armature_add();r=bpy.context.view_layer.objects.active;r.name=KIND.title()+'Rig';bpy.ops.object.mode_set(mode='EDIT');eb=r.data.edit_bones;eb.remove(eb[0])
for n,a,b,parent in bones:
 q=eb.new(n);q.head=a;q.tail=b
 if parent:q.parent=eb[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for o,b in parts:
 o.parent=r;o.vertex_groups.new(name=b).add(list(range(len(o.data.vertices))),1,'REPLACE');m=o.modifiers.new('skin','ARMATURE');m.object=r
for b in r.pose.bones:b.rotation_mode='XYZ'
sc=bpy.context.scene;sc.render.fps=60

def update():bpy.context.view_layer.update()
def orient(n,a,b):
 p=r.pose.bones[n];rest=p.bone;q=(rest.tail_local-rest.head_local).rotation_difference(Vector(b)-Vector(a))@rest.matrix_local.to_quaternion();p.matrix=Matrix.LocRotScale(Vector(a),q,Vector((1,1,1)));update()
def fixed(n,a,angles=(0,0,0)):
 p=r.pose.bones[n];q=Euler(tuple(math.radians(v) for v in angles),'XYZ').to_quaternion()@p.bone.matrix_local.to_quaternion();p.matrix=Matrix.LocRotScale(Vector(a),q,Vector((1,1,1)));update()
def ik(u,l,target,pole):
 p=r.pose.bones[u];a=p.head.copy();d=Vector(target)-a;L1=p.bone.length;L2=r.pose.bones[l].bone.length;D=min(d.length,L1+L2-.0001);d.normalize();end=a+d*D;x=(L1*L1-L2*L2+D*D)/(2*D);h=math.sqrt(max(0,L1*L1-x*x));bend=Vector(pole)-a;bend-=d*bend.dot(d);bend.normalize();joint=a+d*x+bend*h;orient(u,a,joint);orient(l,joint,end);return end

def interp(keys,t):
 for (a,v),(b,wv) in zip(keys,keys[1:]):
  if a<=t<=b:
   k=(t-a)/(b-a);k=k*k*(3-2*k);return Vector(v).lerp(Vector(wv),k)
 return Vector(keys[-1][1])
warn=P['warning'];recovery=P['recovery'];total=warn+recovery
# Held telegraph pose until final 0.13s; strike at the simulation's existing warning expiry.
def pose(kind,t):
 for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4)
 r.pose.bones['hips'].location.y=-.075 if KIND!='boss' else -.10
 chest=r.pose.bones['chest'];right=Vector((w+.15,.15,handz+.08));left=Vector((-w-.15,.13,handz+.08));angles=(0,0,0)
 if kind=='idle':chest.rotation_euler.x=math.radians(-2*math.sin(t*math.pi));right.z+=.01*math.sin(t*math.pi)
 if kind=='walk':
  chest.rotation_euler.x=math.radians(-10);right.y+=.14*math.sin(t*2*math.pi/.8);left.y-=.14*math.sin(t*2*math.pi/.8)
 if kind in ['attack','windup','release','heavy_attack']:
  phase=t if kind not in ['release'] else t+warn
  peak=warn-.13
  if KIND=='minion':
   right=interp([(0,right),(peak,(w+.31,-.025,sh+.02)),(warn,(w+.03,.43,sh-.20)),(warn+.2,(w-.02,.36,sh-.30)),(total,(w+.15,.15,handz+.08))],phase)
   angles=interp([(0,(0,0,0)),(peak,(10,0,-80)),(warn,(-5,0,65)),(warn+.2,(-5,0,40)),(total,(0,0,0))],phase)
  else:
   right=interp([(0,right),(peak,(w+.22,.10,sh+.20)),(warn,(w+.06,.42,sh-.43)),(warn+.22,(w+.08,.42,sh-.44)),(total,(w+.15,.15,handz+.08))],phase)
   angles=interp([(0,(0,0,0)),(peak,(80,0,-15)),(warn,(-24,0,0)),(warn+.22,(-25,0,0)),(total,(0,0,0))],phase)
   if KIND=='boss':left=right+Vector((-.13,-.17,-.02))
  chest.rotation_euler.x=math.radians(interp([(0,(0,0,0)),(peak,(8,0,0)),(warn,(-24,0,0)),(warn+.2,(-21,0,0)),(total,(0,0,0))],phase).x)
 if kind=='hit':
  strength=math.sin(math.pi*min(1,t/.55))
  chest.rotation_euler.x=math.radians(17*strength);chest.rotation_euler.z=math.radians(-10*strength)
  right.x+=.16*strength;right.z+=.09*strength;left.x-=.10*strength
 if kind=='death':
  fall=min(1,t/(.9 if KIND!='boss' else 1.2));fall=fall*fall*(3-2*fall)
  r.pose.bones['hips'].rotation_euler.x=math.radians(-86*fall);r.pose.bones['hips'].location.y=-(hip-({'minion':.30,'elite':.315,'boss':.40}[KIND]))*fall
  chest.rotation_euler.x=math.radians(-8*fall)
  for s in [-1,1]:r.pose.bones['upper'+str(s)].rotation_euler.z=math.radians(s*35*fall);r.pose.bones['fore'+str(s)].rotation_euler.x=math.radians(-25*fall)
  update();fixed("weapon",r.pose.bones["weapon"].head.copy(),(0,0,40*fall));return
 update()
 for s in [-1,1]:
  x=s*w*.62;y=.10*s if kind in ['attack','windup','release','heavy_attack'] else 0;z=ankle
  if kind=='walk':
   p=(t/.8+(0 if s==1 else .5))%1
   # Walk is an in-place test cycle; speed must be calibrated externally.
   y=.23-.92*p if p<=.5 else -.23+.46*(p-.5)*2
   if p>.5:z+=.10*math.sin(math.pi*(p-.5)*2)
  end=ik('thigh'+str(s),'shin'+str(s),(x,y,z),(x,.8,hip*.5));fixed('foot'+str(s),end)
 end=ik('upper1','fore1',right,(w+1,.1,sh-.15));fixed('hand1',end);fixed('weapon',end,angles)
 end=ik('upper-1','fore-1',left,(-w-1,.1,sh-.15));fixed('hand-1',end)

clips={'idle':2.,'walk':.8,'attack':total,'windup':warn,'release':recovery,'hit':.55,'death':1.7 if KIND!='boss' else 2.1}
if KIND=='boss':clips['heavy_attack']=total
for name,duration in clips.items():
 r.animation_data_create();a=bpy.data.actions.new(name);r.animation_data.action=a
 for f in range(round(duration*60)+1):
  pose(name,f/60)
  for p in r.pose.bones:
   p.keyframe_insert('location',frame=f,group=p.name);p.keyframe_insert('rotation_euler',frame=f,group=p.name)
 for fc in a.fcurves:
  for k in fc.keyframe_points:k.interpolation='LINEAR'
 a.use_fake_user=True
r.animation_data.action=bpy.data.actions['idle'];sc.frame_set(0);sc.frame_end=120
bpy.ops.object.select_all(action='DESELECT');r.select_set(True)
for o,b in parts:o.select_set(True)
bpy.context.view_layer.objects.active=r
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source'/(KIND+'.blend')))
bpy.ops.export_scene.gltf(filepath=str(OUT/(KIND+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False)
print('ENEMY_ASSET_EXPORTED',KIND,'height',h,'bones',len(r.data.bones),'meshes',len(parts),'clips',clips,'impact_frame',round(warn*60))
