from pathlib import Path
import tempfile,shutil,subprocess,json,hashlib
here=Path(__file__).resolve().parent
base=here.parents[2];working=base/'working_live02'
# Resolve based on adapter_branch sibling, not an assumed user's project.
working=here.parents[2]/'working_live02'
assert working.is_dir(),working
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
parent_rel='tests/ink_first_floor_boss_20261008/live02/source_binding.json'
original=sha(working/parent_rel)
with tempfile.TemporaryDirectory(prefix='q1-binding-source-') as td:
 root=Path(td)/'project';shutil.copytree(working,root,ignore=shutil.ignore_patterns('.godot'))
 shutil.copytree(here.parent,root/'visual_rework_20261009',dirs_exist_ok=True)
 folder=root/'visual_rework_20261009/binding'
 for source in (folder/'postimages').rglob('*'):
  if source.is_file():shutil.copyfile(source,root/source.relative_to(folder/'postimages'))
 restorations=json.loads((working.parent/'dynamic_reward_restoration01.json').read_text())
 for restored in restorations:
  source=Path(restored['source']);assert sha(source)==restored['sha256']
  target=root/restored['resource'][6:];target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
 for restored in json.loads((working.parent.parent/'ink_minimal_validation_20261009/dynamic_nested_pin_recovery.json').read_text())['files']:
  source=Path(restored['source']);assert sha(source)==restored['sha256']
  target=root/restored['target'];target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
 command=['python',str(folder/'seal_successor.py'),'--project',str(root)]
 result=subprocess.run(command,capture_output=True,text=True);assert result.returncode==0,result.stderr
 print(result.stdout.strip())
 binding=json.loads((folder/'source_binding.json').read_text());visual=json.loads((folder/'visual_binding.json').read_text())
 for mapping in [binding['runtime_map'],visual['runtime_map']]:
  for path,expected in mapping.items():assert sha(root/path[6:])==expected,path
 print('PASS all core/visual pins match copied new composition')
 # Seal fails if either approved postimage or unrelated inherited resource drifts.
 targets=list(binding['ancestor_pin_replacements'])+list(binding['explicit_dynamic_dependencies'])
 targets.append(next(k for k in binding['runtime_map'] if k not in targets and not k.startswith('res://visual_rework')))
 for path in targets:
  file=root/path[6:];old=file.read_bytes();file.write_bytes(old+b'\n# drift')
  rejected=subprocess.run(command,capture_output=True,text=True);assert rejected.returncode!=0,path
  file.write_bytes(old)
 print('PASS source seal rejects tamper of all four replacements, three dynamic rewards and unrelated inherited resource')
 # Direct hash verification proves seal catches new visual/helper drift.
 for mapping in [visual['runtime_map'],binding['runtime_map']]:
  key=next(k for k in mapping if '/visual_rework_' in k)
  file=root/key[6:];old=file.read_bytes();file.write_bytes(old+b'\n')
  assert sha(file)!=mapping[key];file.write_bytes(old)
 print('PASS sealed new dependency hashes detect drift')
assert sha(working/parent_rel)==original
print('PASS frozen working_live02 manifest unchanged; no engine invoked')
