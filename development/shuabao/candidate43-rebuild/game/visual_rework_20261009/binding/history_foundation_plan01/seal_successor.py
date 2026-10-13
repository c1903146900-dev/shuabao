"""Run after applying four staged postimages and copying visual_rework to a new project.
Never edits original resources or old manifests. Seals only new binding manifests.
Any later visual edit requires re-running this command before engine admission.
"""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--project',required=True);args=p.parse_args()
root=Path(args.project).resolve();folder=root/'visual_rework_20261009/binding'
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
plan=json.loads((folder/'replacement_plan.json').read_text())
parent_file=root/plan['parent_path'][6:]
assert sha(parent_file)==plan['parent_sha256'],'Frozen parent changed'
parent=json.loads(parent_file.read_text());assert len(parent['runtime_map'])==1078
mapped=parent['runtime_map'].copy();changes={}
for path,change in plan['replacements'].items():
 assert mapped[path]==change['before'],f'Parent preimage mismatch {path}'
 assert sha(root/path[6:])==change['after'],f'Exact staged postimage not applied {path}'
 assert sha(root/change['preimage'][6:])==change['before'],f'Preimage preservation failed {path}'
 changes[path]={k:v for k,v in change.items() if k!='staged_postimage'}
 mapped[path]=change['after'];mapped[change['preimage']]=change['before']
# Explicit restored dynamic reward dependency pins; never infer or accept drift.
reward_pins={
 'res://tests/ink_first_floor_user_route_20261005/runtime01/reward_table.json':'5ff699caeaf1d1085ccc4aa677562f8805f4a573d5a7db3388811d81e1a5b78d',
 'res://tests/ink_first_floor_user_route_20261005/runtime01/rewards.csv':'6db7878df90b8bd642a1405c2b7f9279e9d45195f99173e1ee7d4a7272103895',
 'res://tests/ink_first_floor_user_route_20261005/runtime01/validation_result.json':'59ea4e61954be976449380a944c9f9911064c1f80839bba87671fc179ad2630d'}
for path,expected in reward_pins.items():
 assert path not in parent['runtime_map'],f'Dynamic dependency already inherited: {path}'
 assert sha(root/path[6:])==expected,f'Explicit reward dependency drift: {path}'
 mapped[path]=expected
for path,expected in mapped.items():assert sha(root/path[6:])==expected,f'Unexpected inherited resource edit {path}'
visual={}
for file in sorted((root/'visual_rework_20261009').rglob('*')):
 if not file.is_file() or '.godot' in file.parts or 'binding' in file.relative_to(root/'visual_rework_20261009').parts:continue
 if file.suffix.lower() not in {'.gd','.gdshader','.tscn','.tres','.png','.jpg','.webp','.glb','.gltf','.bin','.json','.wav','.ogg','.svg'}:continue
 visual['res://'+file.relative_to(root).as_posix()]=sha(file)
assert any('/views/' in k for k in visual),'Missing visual dependencies'
visual_file=folder/'visual_binding.json';visual_file.write_text(json.dumps({'schema':'ink-visual-dependencies-1','runtime_map':visual},indent=2)+'\n')
for rel in ['visual_rework_20261009/binding/live_binding.gd','visual_rework_20261009/binding/bridge.gd','visual_rework_20261009/binding/visual_binding.json','visual_rework_20261009/input/q1_free_curve_sampler.gd',plan['parent_path'][6:]]:
 mapped['res://'+rel]=sha(root/rel)
binding={'schema':'ink-q1-free-curve-visual-successor-1','status':'SOURCE_SEALED_ENGINE_UNVERIFIED','parent_path':plan['parent_path'],'parent_sha256':plan['parent_sha256'],'ancestor_pin_replacements':changes,'runtime_candidates':parent['runtime_candidates'],'supported_hex_hooks':parent['supported_hex_hooks'],'runtime_map':mapped,'h01_conflict':'Baseline free curves supersede old H01 corner unlock; length bonus unchanged; no replacement mechanic invented.','explicit_dynamic_dependencies':reward_pins,'claims':{'engine_passed':False,'native_input_passed':False,'visual_accepted':False}}
(folder/'source_binding.json').write_text(json.dumps(binding,indent=2)+'\n')
print(json.dumps({'sealed':True,'inherited_pins':1078,'exact_replacements':len(changes),'runtime_pins':len(mapped),'visual_pins':len(visual),'binding_sha256':sha(folder/'source_binding.json'),'engine_run':False}))
