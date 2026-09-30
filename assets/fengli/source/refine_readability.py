# Run via Blender MCP after opening the existing approved Fengli .blend.
import bpy
from pathlib import Path
r=bpy.data.objects['Fengli']
blade=bpy.data.materials['07 • honed silver'];p=blade.node_tree.nodes.get('Principled BSDF')
blade.diffuse_color=(.07,.15,.19,1);p.inputs['Base Color'].default_value=blade.diffuse_color;p.inputs['Roughness'].default_value=.38;p.inputs['Metallic'].default_value=.55
edge=bpy.data.materials.get('09 • readable silver bevel') or bpy.data.materials.new('09 • readable silver bevel')
edge.use_nodes=True;edge.diffuse_color=(.58,.72,.73,1);p=edge.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=edge.diffuse_color;p.inputs['Metallic'].default_value=.6;p.inputs['Roughness'].default_value=.32
sword=bpy.data.objects['Long diamond blade']
if edge.name not in sword.data.materials:sword.data.materials.append(edge)
for polygon in sword.data.polygons:polygon.material_index=1 if polygon.index in [3,7] else 0
bpy.context.scene.frame_set(0);r.animation_data.action=bpy.data.actions['idle']
bpy.ops.object.select_all(action='DESELECT');r.select_set(True)
for o in bpy.data.objects:
 if o.type=='MESH':o.select_set(True)
bpy.context.view_layer.objects.active=r
out=Path('/workspace/shuabao/.local/mcp-fixture/assets/fengli')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'source/fengli.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'fengli.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False)
print('FENGLI_MATERIAL_ONLY_READABILITY_UPDATE')
