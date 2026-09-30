# Executed by Blender MCP; samples evaluated meshes, not just Action names.
import bpy,json,math
from pathlib import Path
from mathutils.bvhtree import BVHTree
r=bpy.data.objects['Fengli'];sc=bpy.context.scene
label='after' if bpy.data.objects.get('Elbow gusset1') else 'before'
foots=[o for o in bpy.data.objects if o.name.startswith('Toe boot')]
body=[bpy.data.objects[n] for n in ['Tailored torso','Breastplate','Waist wrap','Angular face']]
body += [o for o in bpy.data.objects if o.name.startswith(('Split coat','Scarf tail','Swept silver','Temple swept'))]
weapons=[bpy.data.objects['Long diamond blade']]
forearms=[o for o in bpy.data.objects if o.name.startswith(('Bracer','Glove'))]
def vertices(o):
 ob=o.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ob.to_mesh();vs=[ob.matrix_world@v.co for v in me.vertices];faces=[list(p.vertices) for p in me.polygons];ob.to_mesh_clear();return vs,faces
def bvh(o):
 v,f=vertices(o);return BVHTree.FromPolygons(v,f)
report={'label':label,'clips':{},'method':'every half frame (60 Hz); evaluated mesh surface intersections; feet minimum vertex Z; virtual forward travel 2 m/s for run'}
for name,end in [('idle',60),('run',24),('attack',24),('dash',18),('thrust',27),('overload',45),('ultimate',60),('hit',18)]:
 r.animation_data.action=bpy.data.actions[name]
 hits=[];arms=[];ground=[];stance=[];rot=[]
 for sample_index in range(end*2+1):
  f=sample_index/2
  sc.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
  ground.append([f]+[min(v.z for v in vertices(o)[0]) for o in foots])
  trees=[bvh(o) for o in body]
  if any(bvh(o).overlap(t) for o in weapons for t in trees):hits.append(f)
  if any(bvh(o).overlap(t) for o in forearms for t in trees):arms.append(f)
  if name=='run' and f<=12:
   p=r.pose.bones['foot1'].head.copy();p.y+=2*f/30;stance.append(list(p))
  rot.append(list(r.pose.bones['fore1'].rotation_euler)+list(r.pose.bones['thigh1'].rotation_euler))
 clip={'blade_body_intersection_frames':hits,'forearm_body_intersection_frames':arms,'foot_heights':ground,'limb_pose_variation':max(max(v[k] for v in rot)-min(v[k] for v in rot) for k in range(6))}
 if stance:clip['run_stance_virtual_world_drift_m']=max((sum((a-b)**2 for a,b in zip(p,stance[0])))**.5 for p in stance)
 report['clips'][name]=clip
Path('/workspace/shuabao/.local/fengli-quality/'+label+'-metrics.json').write_text(json.dumps(report,indent=2))
print('QUALITY_METRICS',label,{n:{k:v for k,v in d.items() if k!='foot_heights'} for n,d in report['clips'].items()})
