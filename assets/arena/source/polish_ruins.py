# Executed by Blender MCP only. Existing 4m tile and ground datum (+Z .01m) retained.
import bpy,math
import numpy as np
from pathlib import Path
OUT=Path('/workspace/shuabao/.local/mcp-fixture/assets/arena')
(OUT/'source').mkdir(exist_ok=True)
def clear():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(n,c,metal=0):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=m.diffuse_color;p.inputs['Roughness'].default_value=.8;p.inputs['Metallic'].default_value=metal;return m
stone=[material('Ruins limestone '+str(i),(.23+i*.009,.255+i*.008,.245+i*.007)) for i in range(4)]
# Embedded, self-authored limestone color map. Subtle mottling; no external textures.
size=512;rng=np.random.default_rng(6031);field=np.zeros((size,size),dtype=np.float32)
for cells,amp in [(8,.022),(24,.014),(96,.008)]:
 grid=rng.random((cells,cells)).astype(np.float32)-.5
 xs=np.linspace(0,cells-1,size);temp=np.array([np.interp(xs,np.arange(cells),row) for row in grid])
 field+=np.array([np.interp(xs,np.arange(cells),temp[:,i]) for i in range(size)]).T*amp
field+=(rng.random((size,size))-.5)*.018
pixels=np.ones((size,size,4),dtype=np.float32)
for k,c in enumerate([.37,.395,.378]):pixels[:,:,k]=c+field
image=bpy.data.images.new('Ruins hand-authored limestone',width=size,height=size,alpha=False)
image.pixels.foreach_set(pixels.ravel());image.filepath_raw=str(OUT/'source/ruins_stone_basecolor.png');image.file_format='PNG';image.save();image.pack()
for m in stone:
 texture=m.node_tree.nodes.new('ShaderNodeTexImage');texture.image=image;m.node_tree.links.new(texture.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
side=material('Ruins cut edge',(.11,.145,.14));base=material('Ruins foundation',(.068,.092,.095));copper=material('Ruins worn warm copper',(.40,.20,.068),.45);charcoal=material('Ruins engraved inset',(.047,.065,.066))
def poly(n,outline,z0,z1,top,wall,bev=.015):
 vs=[(x,y,z) for z in [z0,z1] for x,y in outline];N=len(outline);fs=[tuple(reversed(range(N))),tuple(range(N,2*N))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)]
 me=bpy.data.meshes.new(n);me.from_pydata(vs,[],fs);me.update();uv=me.uv_layers.new(name='StoneUV')
 for loop in me.loops:
  v=me.vertices[loop.vertex_index].co;uv.data[loop.index].uv=((v.x+2)/4,(v.y+2)/4)
 o=bpy.data.objects.new(n,me);bpy.context.collection.objects.link(o);o.data.materials.append(top);o.data.materials.append(wall)
 for p in o.data.polygons:p.material_index=0 if p.index==1 else 1
 bpy.context.view_layer.objects.active=o
 if bev:
  mod=o.modifiers.new('stone arris','BEVEL');mod.width=bev;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def rect(x,y,w,h,ch=.05):return [(x-w/2+ch,y-h/2),(x+w/2-ch,y-h/2),(x+w/2,y-h/2+ch),(x+w/2,y+h/2-ch),(x+w/2-ch,y+h/2),(x-w/2+ch,y+h/2),(x-w/2,y+h/2-ch),(x-w/2,y-h/2+ch)]
def save(n):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source'/(n+'.blend')));bpy.ops.export_scene.gltf(filepath=str(OUT/(n+'.glb')),export_format='GLB',use_selection=True,export_animations=False);print('RUIN_EXPORTED',n)
clear();poly('Recessed dark foundation',rect(0,0,4,4,.08),-.29,-.045,base,base,.018)
# Four irregularly chamfered slabs; edge chips stay below the walk plane.
for i,(x,y) in enumerate([(-.994,-.994),(.994,-.994),(-.994,.994),(.994,.994)]):
 outline=rect(x,y,1.976,1.976,.055+(i%2)*.024)
 poly('Dressed limestone '+str(i),outline,-.07,.01,stone[i],side,.009)
# Two restrained locating insets at module edges, not a luminous central pattern.
for s in [-1,1]:
 poly('Copper corner marker '+str(s),rect(s*1.82,s*1.82,.11,.24,.025),.0103,.012,copper,copper,.001)
save('training_tile')
clear()
poly('Pier foot',rect(0,0,1.1,.95,.15),0,.17,stone[1],side,.035)
poly('Pier plinth',rect(0,0,.82,.72,.10),.17,.34,stone[2],side,.026)
# Tapered octagonal shaft, broken sloped crown; no inaccessible decorations over central floor.
outline=rect(0,0,.61,.56,.12);N=len(outline);vs=[(x,y,.32) for x,y in outline]+[(x*.84,y*.84,1.50+[.05,-.05,.02,.14,.09,-.03,-.07,.01][i]) for i,(x,y) in enumerate(outline)]
me=bpy.data.meshes.new('Broken pillar');me.from_pydata(vs,[],[tuple(range(N,2*N))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)]);me.update();o=bpy.data.objects.new('Broken pillar',me);bpy.context.collection.objects.link(o);o.data.materials.append(stone[0])
poly('Copper collar',rect(0,0,.66,.61,.13),.53,.61,copper,side,.009)
poly('Side rubble',rect(.55,.13,.32,.40,.10),0,.20,stone[3],side,.028)
save('ruin_pier')
clear()
poly('Waystone foot',rect(0,0,.70,.58,.09),0,.12,stone[1],side,.025)
poly('Waystone body',rect(0,0,.48,.37,.08),.12,.64,stone[0],side,.025)
poly('Warm waystone cap',rect(0,0,.56,.44,.10),.63,.69,copper,side,.018)
poly('Dark inset crown',rect(0,0,.29,.22,.05),.69,.711,charcoal,charcoal,.004)
save('ruin_marker')
