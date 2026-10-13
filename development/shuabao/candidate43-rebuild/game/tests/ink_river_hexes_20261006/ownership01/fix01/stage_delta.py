#!/usr/bin/env python3
"""Add only this technical candidate to a coordinator-selected parent stage."""
from pathlib import Path
import argparse,json,shutil
from verify_source import D,R,P,PARENT_SHA,sha,verify,relative
p=argparse.ArgumentParser();p.add_argument('--dest',type=Path,required=True);p.add_argument('--apply',action='store_true');p.add_argument('--receipt',type=Path);a=p.parse_args()
report=verify();S=a.dest.resolve()
assert S!=R and R not in S.parents and (S/'project.godot').is_file()
binding=json.loads((D/'source_binding.json').read_text())
assert sha(S/P.relative_to(R)/'source_binding.json')==PARENT_SHA
new_prefix='res://'+str(D.relative_to(R))+'/'
added={k:v for k,v in binding['runtime_map'].items() if k.startswith(new_prefix)}
added[new_prefix+'source_binding.json']=sha(D/'source_binding.json')
for key,digest in binding['runtime_map'].items():
 if key.startswith(new_prefix):continue
 assert sha(S/relative(key))==digest,'parent stage changed: '+key
for key,digest in added.items():
 dest=S/relative(key);assert S in dest.resolve().parents
 if dest.exists():assert sha(dest)==digest,'candidate path already differs: '+key
copied=[]
if a.apply:
 for key,digest in added.items():
  dest=S/relative(key)
  if dest.is_file() and sha(dest)==digest:continue
  dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/relative(key),dest);assert sha(dest)==digest;copied.append(key)
report.update({'status':'RIVER_OWNERSHIP_FIXTUREFIX01_STAGE_APPLIED' if a.apply else 'RIVER_OWNERSHIP_FIXTUREFIX01_PREFLIGHT','stage':str(S),'new_files':len(added),'copied':copied,'production_source_changes':[]})
if a.receipt:a.receipt.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
