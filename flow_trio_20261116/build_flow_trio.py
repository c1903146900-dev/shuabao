"""Offline isolated flow trio build. No engine/network. Existing outputs are never replaced."""
from pathlib import Path
import argparse,hashlib,json,subprocess,shutil,importlib.util,os
ap=argparse.ArgumentParser();ap.add_argument('--recovery',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
R=a.recovery.resolve();OUT=a.output.resolve();B=R/'source/rebuild_20261106/dash_trail01';I=R/'review_inputs'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(B/'boot/packs/runtime.pck')=='4112ebb636b77732788de4ed57d3d75f4dae67b488c9e76c063b8061a2e37c93'
for group in ['session_fault_latch_20261114','selected_entry_retry_20261114','objective_priority_20261116']:
 for n,h in json.loads((I/group/'FILE_HASHES.json').read_text()).items():assert sha(I/group/n)==h,(group,n)
spec=importlib.util.spec_from_file_location('recovery',R/'tools/rebuild_late.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
assert mod.binding_check(B/'runtime')==257
assert not OUT.exists();shutil.copytree(B/'runtime',OUT/'runtime')
patches=['session_fault_latch_20261114/host_fault_latch.patch','selected_entry_retry_20261114/host.patch','selected_entry_retry_20261114/session.patch','objective_priority_20261116/objective_priority.patch']
for rel in patches:
 p=I/rel;s=p.read_text()
 if s.startswith('--- \n+++ \n'):
  n='host.gd' if p.name=='host.patch' else 'session.gd'
  s=s.replace('--- \n+++ \n',f'--- a/fengli_route_20261024/{n}\n+++ b/fengli_route_20261024/{n}\n',1)
 subprocess.run(['git','apply','-'],input=s,text=True,cwd=OUT/'runtime',check=True)
h=mod.seal(OUT,R/'source/rebuild_20261106');bindings=mod.binding_check(OUT/'runtime')
before={p.relative_to(B/'runtime').as_posix():sha(p) for p in (B/'runtime').rglob('*') if p.is_file()}
after={p.relative_to(OUT/'runtime').as_posix():sha(p) for p in (OUT/'runtime').rglob('*') if p.is_file()}
changed=sorted(k for k in before.keys()|after.keys() if before.get(k)!=after.get(k))
assert changed==sorted(['fengli_route_20261024/host.gd','fengli_route_20261024/session.gd','fengli_route_20261024/flow_guidance.gd','first_hero_full_admission_20261020/manifest.json','release_generation_20261020/generation.gd'])
env=dict(os.environ,BASE_RUNTIME=str(B/'runtime'),CANDIDATE_RUNTIME=str(OUT/'runtime'))
checks=[]
for rel in ['session_fault_latch_20261114/test_pause_model.py','selected_entry_retry_20261114/test_contract.py','objective_priority_20261116/test_model.py']:
 r=subprocess.run(['python3',str(I/rel)],env=env,text=True,capture_output=True);assert r.returncode==0,(rel,r.stdout,r.stderr)
 checks.append({'test':rel,'stdout':r.stdout,'stderr':r.stderr})
assert mod.binding_check(B/'runtime')==257
report={'baseline':'4112ebb636b77732788de4ed57d3d75f4dae67b488c9e76c063b8061a2e37c93','candidate':h,'bindings':bindings,'changed':changed,'checks':checks,'engine_run':False,'parser_run':False,'full_floor':False,'windows':False,'selected':False,'baseline_unchanged':True}
(OUT/'BUILD.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
