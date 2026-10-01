# Executed ONLY by Blender MCP after opening the approved source .blend.
import bpy,math,json
from pathlib import Path
from mathutils import Vector
kind=globals().get('CHARACTER','fengli')
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig.animation_data.action=bpy.data.actions['idle'];bpy.context.scene.frame_set(0)
for o in list(bpy.data.objects):
 if o.name.startswith('Polish_'):bpy.data.objects.remove(o,do_unlink=True)
def material(name,color,metal=.25,rough=.48):
 m=bpy.data.materials.new('Polish_'+name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=m.diffuse_color;p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;return m
def tint(match,color,metal=.25):
 for m in bpy.data.materials:
  if match in m.name and not m.name.startswith('Polish_'):
   m.diffuse_color=(*color,1)
   if m.use_nodes:
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=m.diffuse_color;p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.48
ink=material('flexible graphite',(.025,.035,.041),.05,.75)
bronze=material('brushed old copper',(.34,.19,.073),.60)
edge=material('pale steel arris',(.55,.64,.63),.55,.34)
steel=material('blue black steel',(.055,.095,.105),.55)
cloth=material('woven accent',{'fengli':(.035,.20,.22),'minion':(.23,.062,.034),'elite':(.07,.12,.13),'boss':(.18,.045,.039)}[kind],.02,.78)
plate=material('crafted outer plate',{'fengli':(.095,.22,.25),'minion':(.28,.12,.065),'elite':(.25,.32,.30),'boss':(.29,.31,.26)}[kind],.4 if kind!='boss' else .1)
def mesh(n,vs,fs,mat,bone,bevel=0):
 me=bpy.data.meshes.new('Polish_'+n);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new('Polish_'+n,me);bpy.context.collection.objects.link(o);o.data.materials.append(mat)
 if bevel:
  bpy.context.view_layer.objects.active=o;o.select_set(True);mod=o.modifiers.new('small forged arris','BEVEL');mod.width=bevel;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name);o.select_set(False)
 o.parent=rig;g=o.vertex_groups.new(name=bone);g.add(list(range(len(o.data.vertices))),1,'REPLACE');mod=o.modifiers.new('skin','ARMATURE');mod.object=rig;return o
def panel(n,outline,y,depth,mat,bone,bevel=.008):
 # XZ outline; a shallow shaped plate, never a primitive torso box.
 vs=[(x,y,z) for x,z in outline]+[(x,y-depth,z) for x,z in outline];N=len(outline)
 return mesh(n,vs,[tuple(range(N)),tuple(reversed(range(N,2*N)))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)],mat,bone,bevel)
def tube(n,a,b,ra,rb,mat,bone,N=12):
 a,b=Vector(a),Vector(b);q=(b-a).to_track_quat('Z','Y');vs=[]
 for t,r in [(0,ra),(.18,ra),(1,rb)]:
  for j in range(N):vs.append(a.lerp(b,t)+q@Vector((r*math.cos(j*math.tau/N),r*.83*math.sin(j*math.tau/N),0)))
 fs=[tuple(reversed(range(N))),tuple(range(2*N,3*N))]+[(k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j) for k in range(2) for j in range(N)]
 return mesh(n,vs,fs,mat,bone,.004)
def ring(n,c,rx,ry,z0,z1,mat,bone,N=12):
 vs=[]
 for z,scale in [(z0,.90),(z0+(z1-z0)*.25,1),(z1,.83)]:
  vs.extend([(c[0]+rx*scale*math.cos(j*math.tau/N),c[1]+ry*scale*math.sin(j*math.tau/N),z) for j in range(N)])
 return mesh(n,vs,[tuple(reversed(range(N))),tuple(range(2*N,3*N))]+[(k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j) for k in range(2) for j in range(N)],mat,bone,.005)
def remove(prefix):
 for o in list(bpy.data.objects):
  if o.type=='MESH' and o.name.startswith(prefix):bpy.data.objects.remove(o,do_unlink=True)
# Interlocking elbow and knee gussets retain bone positions and existing motion.
for sign in [-1,1]:
 for joint,bone,rad in [('elbow','fore',.070),('knee','shin',.082),('shoulder','upper',.10)]:
  b=rig.data.bones[bone+str(sign)];c=b.head_local.copy();factor={'fengli':1,'minion':.83,'elite':1.15,'boss':1.55}[kind];r=rad*factor
  tube(joint+str(sign),c+Vector((0,0,-r*.7)),c+Vector((0,0,r*.7)),r,r*.9,ink,b.name)
  if joint=='elbow':
   panel('elbow shell '+str(sign),[(c.x-r*.75,c.z+r*.5),(c.x+r*.75,c.z+r*.5),(c.x+r,c.z-r*.2),(c.x,c.z-r*.8),(c.x-r,c.z-r*.2)],c.y+r*.78,.028,plate,b.name)
 # Wrist cuff overlap and segmented finger plate break rectangular hands.
 b=rig.data.bones['hand'+str(sign)];c=b.head_local.copy();r={'fengli':.06,'minion':.052,'elite':.075,'boss':.105}[kind]
 ring('wrist clasp '+str(sign),(c.x,c.y),r*1.12,r,c.z-.03,c.z+.055,bronze,b.name)
 panel('knuckle plate '+str(sign),[(c.x-r,c.z-.018),(c.x+r,c.z-.018),(c.x+r*.8,c.z-.095),(c.x-r*.6,c.z-.10)],c.y+r,.018,plate,b.name,.004)
# Shape boots with a tapered armored vamp while keeping the original sole / foot envelope.
for sign in [-1,1]:
 b=rig.data.bones['foot'+str(sign)];c=b.head_local.copy();r={'fengli':.08,'minion':.0696,'elite':.0957,'boss':.1392}[kind];length=.31 if kind=='fengli' else (.43 if kind=='boss' else .32)
 vs=[(c.x-r*.95,c.y-.055,.02),(c.x+r*.95,c.y-.055,.02),(c.x+r*.80,c.y+length*.74,.02),(c.x-r*.80,c.y+length*.74,.02),(c.x-r*.75,c.y-.03,c.z*.86),(c.x+r*.75,c.y-.03,c.z*.86),(c.x+r*.58,c.y+length*.61,c.z*.50),(c.x-r*.58,c.y+length*.61,c.z*.50)]
 mesh('sabatons '+str(sign),vs,[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)],plate,b.name,.007)
if kind=='fengli':
 tint('storm teal',(.026,.115,.135),.0);tint('blue steel',(.065,.16,.19),.5);tint('pale brass',(.44,.27,.095),.55)
 # A sweeping asymmetrical breastplate and floating lower lames.
 panel('sculpted breast keel',[(-.20,1.43),(-.09,1.50),(.21,1.43),(.20,1.30),(.075,1.205),(-.17,1.26)],.205,.043,plate,'chest')
 panel('breast arris',[(-.18,1.432),(-.085,1.465),(.18,1.412),(.172,1.395),(-.084,1.441),(-.18,1.413)],.211,.014,bronze,'chest',.003)
 for z,width in [(1.23,.18),(1.16,.17)]:panel('lower cuirass '+str(z),[(-width,z+.047),(width,z+.047),(width*.84,z-.014),(0,z-.039),(-width*.84,z-.014)],.151,.025,steel,'chest')
 # Curved overlapping lames sit below the original dome; no coplanar front plates.
 for i in range(2):
  ring('shoulder underlame '+str(i),(-.31-i*.012,0),.163-i*.009,.188-i*.009,1.345+i*.045,1.405+i*.045,steel if i==0 else plate,'upper-1')
 panel('right leather shoulder',[ (.205,1.48),(.31,1.50),(.40,1.40),(.30,1.35)],.11,.21,cloth,'upper1')
 panel('face nose',[(-.017,1.77),(.017,1.77),(.025,1.70),(0,1.69),(-.023,1.704)],.133,.028,bpy.data.materials['05 • warm porcelain'],'head',.003)
 # Three swept locks give the head a forward-facing profile without a larger helmet.
 for i in range(3):
  x=-.085+i*.055
  mesh('swept fringe '+str(i),[(x-.025,.062,1.85),(x+.045,.06,1.87),(x+.035,.108,1.785+i*.013),(x+.005,-.015,1.93)],[(0,1,2),(0,3,1),(1,3,2),(2,3,0)],bpy.data.materials['06 • ash silver'],'head')
 # Guard swept into a slim hooked silhouette, grip bindings and pommel.
 remove('Swept crossguard')
 panel('sword wing guard',[(.33,1.005),(.39,1.055),(.50,1.026),(.61,1.055),(.67,1.005),(.58,.985),(.50,1.005),(.42,.985)],.215,.06,bronze,'weapon',.006)
 for i in range(5):tube('hilt binding '+str(i),(.5,.005+i*.035,1),(.5,.013+i*.035,1),.030,.030,bronze,'weapon',10)
 tube('pommel',(.5,-.055,1),(.5,-.018,1),.040,.03,steel,'weapon')
elif kind=='minion':
 tint('armor',(.24,.078,.042),.12);tint('ivory plate',(.39,.34,.23),.15);tint('steel edge',(.12,.18,.19),.5)
 # Triangular chest harness, longer swept hood, a narrow waist and asymmetrical capelet.
 panel('leather chest',[(-.17,1.20),(0,1.31),(.19,1.19),(.11,.98),(-.12,1.01)],.20,.038,plate,'chest')
 panel('diagonal harness',[(-.19,1.23),(-.14,1.26),(.16,1.00),(.12,.96)],.247,.014,bronze,'chest',.003)
 panel('hood brow',[(-.15,1.56),(0,1.65),(.15,1.56),(.10,1.515),(0,1.56),(-.10,1.515)],.137,.037,cloth,'head')
 panel('pointed respirator',[(-.092,1.47),(.092,1.47),(.065,1.39),(0,1.365),(-.065,1.39)],.16,.026,steel,'head')
 mesh('swept hood peak',[(-.13,-.10,1.58),(.12,-.10,1.59),(-.025,-.28,1.72),(-.03,-.08,1.68)],[(0,1,2),(0,3,1),(1,3,2),(2,3,0)],cloth,'head')
 for sign in [-1,1]:
  x=sign*.1488
  panel('pointed thigh leather '+str(sign),[(x-.065,.82),(x+.065,.82),(x+.075,.66),(x,.61),(x-.07,.68)],.085,.032,plate,'thigh'+str(sign))
 # Silver bevel follows the hook's outer contour; dark body remains visible against stone.
 x=.36;z=.71
 mesh('hook sharpened bevel',[(x+.035,.18,z+.019),(x+.16,.67,z+.019),(x+.07,.87,z+.019),(x+.105,.66,z+.024),(x+.013,.23,z+.024)],[(0,1,3,4),(1,2,3)],edge,'weapon')
 for i in range(4):tube('hook grip wrap '+str(i),(x,-.035+i*.042,z),(x,-.025+i*.042,z),.027,.027,bronze,'weapon',10)
elif kind=='elite':
 tint('ivory plate',(.28,.34,.31),.35);tint('armor',(.075,.14,.15),.4)
 panel('cuirass ridge',[(-.27,1.51),(0,1.60),(.27,1.51),(.23,1.22),(0,1.13),(-.23,1.22)],.225,.055,plate,'chest')
 panel('cuirass copper chevron',[(-.245,1.455),(0,1.37),(.245,1.455),(.23,1.425),(0,1.33),(-.23,1.425)],.286,.022,bronze,'chest')
 remove('Layered pauldron')
 for sign in [-1,1]:
  for i in range(3):
   ring('shieldbearer shoulder '+str(sign)+str(i),(sign*(.37+.01*(2-i)),0),.188-i*.008,.224-i*.012,1.43+i*.075,1.525+i*.075,bronze if i==0 else plate,'upper'+str(sign))
  x=sign*.2046
  panel('articulated hip tasset '+str(sign),[(x-.1,1.04),(x+.1,1.04),(x+.105,.89),(x,.81),(x-.1,.87)],.16,.040,plate,'thigh'+str(sign))
 # Shield stepped rim and inset field occupy the same original envelope.
 x=-.45;z=.90
 outline=[(x-.245,z-.36),(x+.245,z-.36),(x+.30,z+.38),(x,z+.565),(x-.30,z+.38)]
 panel('shield copper border',outline,.195,.045,bronze,'hand-1',.01)
 panel('shield inset face',[(x-.20,z-.30),(x+.20,z-.30),(x+.245,z+.355),(x,z+.50),(x-.245,z+.355)],.216,.026,steel,'hand-1',.012)
 panel('shield enamel kite',[(x,z+.38),(x+.11,z+.13),(x,z-.15),(x-.11,z+.13)],.250,.025,plate,'hand-1')
 for sign in [-1,1]:panel('visor cheek '+str(sign),[(sign*.05,1.84),(sign*.16,1.90),(sign*.18,1.77),(sign*.08,1.72)],.177,.03,steel,'head')
 # Thick double-faced pick rather than a zero-thickness polygon.
 remove('Beaked war pick');x=.45
 mesh('forged war pick',[(x-.1,.63,z-.06),(x+.27,.63,z-.035),(x+.45,.57,z),(x+.27,.72,z+.035),(x-.1,.72,z+.06),(x-.1,.62,z+.06),(x+.24,.65,z+.065)],[(0,1,2),(1,3,2),(3,4,5,6),(0,5,4),(0,6,5),(0,1,6),(1,2,3,6)],edge,'weapon',.006)
else:
 tint('ivory plate',(.31,.32,.26),.08);tint('armor',(.16,.048,.038),.15);tint('aged brass',(.31,.17,.055),.5)
 # Low, broad layered cuirass concentrates mass beneath the shoulders.
 panel('keystone breast',[(-.37,2.03),(-.16,2.11),(.28,2.06),(.40,1.88),(.28,1.55),(0,1.43),(-.31,1.60)],.335,.105,plate,'chest',.022)
 panel('keystone recess',[(-.14,1.94),(.14,1.96),(.19,1.73),(0,1.61),(-.16,1.75)],.45,.025,ink,'chest')
 panel('ochre breast rune',[(-.025,1.94),(.04,1.94),(.035,1.71),(0,1.68),(-.025,1.73)],.48,.018,bronze,'chest')
 for sign in [-1,1]:
  for i in range(2):
   x=sign*(.55+.025*i);z=2.13-.12*i
   panel('bastion shoulder mantle '+str(sign)+str(i),[(x-.25,z),(x-.19,z+.13),(x+.19,z+.11),(x+.28,z-.02),(x+.18,z-.17),(x-.18,z-.15)],.30+i*.018,.52,plate,'upper'+str(sign),.025)
  x=sign*.2976
  panel('heavy split thigh apron '+str(sign),[(x-.13,1.25),(x+.13,1.25),(x+.15,.99),(x+.06,.87),(x-.12,.93)],.17,.06,cloth,'thigh'+str(sign))
  panel('stone jaw '+str(sign),[(sign*.025,2.45),(sign*.23,2.49),(sign*.22,2.31),(sign*.09,2.24)],.225,.045,steel,'head',.014)
 # Maul end caps and recessed wrap break the plain block.
 x=.60;z=1.03
 for sign in [-1,1]:
  xx=x+sign*.363
  vs=[(xx,y,zz) for y,zz in [(.75,z-.105),(.81,z-.155),(.97,z-.155),(1.03,z-.105),(1.03,z+.105),(.97,z+.155),(.81,z+.155),(.75,z+.105)]]
  mesh('maul forged end '+str(sign),vs,[tuple(range(8))],steel,'weapon')
 for i in range(6):tube('maul leather wrap '+str(i),(x,-.22+i*.095,z),(x,-.18+i*.095,z),.057,.056,bronze if i in [0,5] else cloth,'weapon')
# Preserve all rig/action data; save revised source and production GLB via MCP.
bpy.context.scene.frame_set(0);rig.animation_data.action=bpy.data.actions['idle']
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for o in bpy.data.objects:
 if o.type=='MESH':o.select_set(True)
bpy.context.view_layer.objects.active=rig
out=Path('/workspace/shuabao/.local/mcp-fixture/assets')/('fengli' if kind=='fengli' else 'arena/enemies')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'source'/(kind+'.blend')))
bpy.ops.export_scene.gltf(filepath=str(out/(kind+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False)
print('POLISH_EXPORTED',kind,'bones',len(rig.data.bones),'actions',[a.name for a in bpy.data.actions],'meshes',sum(o.type=='MESH' for o in bpy.data.objects))
