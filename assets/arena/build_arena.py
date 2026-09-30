# Submitted to execute_blender_code over MCP, never run as a standalone bpy job.
import bpy, math
from pathlib import Path
OUT=Path('/workspace/shuabao/.local/mcp-fixture/assets/arena');OUT.mkdir(parents=True,exist_ok=True)
(OUT/'source').mkdir(exist_ok=True);(OUT/'source/.gdignore').touch()
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(n,c,metal=0):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.65;return m
stone=mat('Warm limestone',(.39,.43,.40));trim=mat('Dark basalt',(.13,.19,.20));gold=mat('Old brass',(.6,.41,.19),.5);red=mat('Enemy terracotta',(.52,.15,.09));black=mat('Enemy charcoal',(.09,.12,.14));white=mat('Elite ivory',(.72,.65,.47))
def box(n,p,s,m,b=.04):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.name=n;o.dimensions=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m);q=o.modifiers.new('stone bevel','BEVEL');q.width=b;q.segments=2;bpy.ops.object.modifier_apply(modifier=q.name);return o
def export(n):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(OUT/(n+'.glb')),export_format='GLB',use_selection=True);bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source'/(n+'.blend')));bpy.ops.object.delete(use_global=False)
# exactly 4m module, top plane at 0. Insets leave combat floor calm.
box('Basalt foundation',(0,0,-.20),(4,4,.30),trim)
for x in [-1,1]:
 for y in [-1,1]:box('Dressed stone slab',(x*.99,y*.99,-.035),(1.95,1.95,.09),stone,.025)
for x in [-1,1]:box('Brass registration mark',(x*1.7,0,.014),(.025,.40,.008),gold,.003)
export('training_tile')
for elite in [False,True]:
 box('Angular torso',(0,0,1),(.55,.34,.62),white if elite else red,.08)
 box('Waist',(0,0,.67),(.33,.29,.18),black)
 for s in [-1,1]:
  box('Leg',(s*.16,0,.35),(.18,.20,.56),black);box('Foot',(s*.16,.06,.08),(.22,.33,.16),trim)
  box('Arm',(s*.39,0,.92),(.16,.22,.49),red)
  if elite:box('Wide elite mantle',(s*.40,0,1.28),(.32,.43,.24),gold)
 box('Masked head',(0,0,1.49),(.28,.25,.31),black,.055)
 box('Eye slit',(0,.134,1.51),(.22,.02,.032),gold,.005)
 if elite:
  for s in [-1,1]:
   bpy.ops.mesh.primitive_cone_add(vertices=4,radius1=.10,radius2=.025,depth=.42,location=(s*.15,0,1.82));bpy.context.object.data.materials.append(gold)
  box('Elite shield',(-.56,.14,1),(.16,.50,.70),white)
 export('enemy_elite' if elite else 'enemy_regular')
print('ARENA_AND_ENEMIES_EXPORTED')
