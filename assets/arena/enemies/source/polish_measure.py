import bpy,json
from pathlib import Path
from mathutils.bvhtree import BVHTree
r=next(o for o in bpy.data.objects if o.type=='ARMATURE');kind='fengli' if r.name=='Fengli' else r.name.replace('Rig','').lower();sc=bpy.context.scene
body=[o for o in bpy.data.objects if o.type=='MESH' and any(g.name in ['chest','hips','head'] for g in o.vertex_groups)]
weapons=[o for o in bpy.data.objects if o.type=='MESH' and any(g.name=='weapon' for g in o.vertex_groups)]
feet=[o for o in bpy.data.objects if o.type=='MESH' and any(g.name.startswith('foot') for g in o.vertex_groups)]
def geom(o):
 e=o.evaluated_get(bpy.context.evaluated_depsgraph_get());m=e.to_mesh();v=[e.matrix_world@p.co for p in m.vertices];f=[list(p.vertices) for p in m.polygons];e.to_mesh_clear();return v,f
def bvh(o):
 v,f=geom(o);return BVHTree.FromPolygons(v,f)
report={'kind':kind,'sample_fps':30,'frames':{},'scope':'All weapon-group meshes versus chest/hips/head-group meshes, including new armor; intentional armor/joint overlaps not tested.'}
for clip in ['idle','run' if kind=='fengli' else 'walk','attack','hit']:
 r.animation_data.action=bpy.data.actions[clip];bad=[];low=100.;end=int(r.animation_data.action.frame_range[1]);step=max(1,round(sc.render.fps/30))
 for f in range(0,end+1,step):
  sc.frame_set(f);bpy.context.view_layer.update();bt=[(o.name,bvh(o)) for o in body]
  wt=[(o.name,bvh(o)) for o in weapons]
  hits=[(name,n) for name,w in wt for n,t in bt if w.overlap(t)]
  if hits:bad.append({'frame':f,'pairs':hits[:5]})
  low=min(low,min(v.z for o in feet for v in geom(o)[0]))
 report['frames'][clip]={'intersections':bad,'min_foot_z':low}
Path('/workspace/shuabao/.local/mcp-fixture/assets/arena/enemies/'+kind+'_polish_metrics.json').write_text(json.dumps(report,indent=2));print('POLISH_METRICS',report)
