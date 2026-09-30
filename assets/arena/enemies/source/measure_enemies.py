import bpy,json
from pathlib import Path
from mathutils.bvhtree import BVHTree
r=next(o for o in bpy.data.objects if o.type=='ARMATURE');kind=r.name.replace('Rig','').lower();sc=bpy.context.scene
body=[o for o in bpy.data.objects if o.type=='MESH' and any(n in o.name for n in ['torso','Waist','mask','hood','helm'])]
weapons=[o for o in bpy.data.objects if o.type=='MESH' and any(g.name=='weapon' for g in o.vertex_groups)]
feet=[o for o in bpy.data.objects if o.name.startswith('Boot')]
def verts(o):
 e=o.evaluated_get(bpy.context.evaluated_depsgraph_get());m=e.to_mesh();v=[e.matrix_world@p.co for p in m.vertices];f=[list(p.vertices) for p in m.polygons];e.to_mesh_clear();return v,f
def bvh(o):
 v,f=verts(o);return BVHTree.FromPolygons(v,f)
report={'kind':kind,'sample_fps':30,'attack_weapon_body_intersections':[],'min_foot_height_attack':100.,'clips':{a.name:(a.frame_range[1]-a.frame_range[0])/60 for a in bpy.data.actions}}
r.animation_data.action=bpy.data.actions['attack'];end=int(r.animation_data.action.frame_range[1])
for f in range(0,end+1,2):
 sc.frame_set(f);bpy.context.view_layer.update();bt=[bvh(o) for o in body]
 if any(bvh(o).overlap(t) for o in weapons for t in bt):report['attack_weapon_body_intersections'].append(f)
 report['min_foot_height_attack']=min(report['min_foot_height_attack'],min(v.z for o in feet for v in verts(o)[0]))
r.animation_data.action=bpy.data.actions['death'];sc.frame_set(int(r.animation_data.action.frame_range[1]));bpy.context.view_layer.update()
report['death_mesh_lowest_z']=min(v.z for o in bpy.data.objects if o.type=='MESH' for v in verts(o)[0])
Path('/workspace/shuabao/.local/mcp-fixture/assets/arena/enemies/'+kind+'_metrics.json').write_text(json.dumps(report,indent=2))
print('ENEMY_METRICS',report)
