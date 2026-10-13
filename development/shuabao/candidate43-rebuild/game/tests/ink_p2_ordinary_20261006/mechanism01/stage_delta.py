#!/usr/bin/env python3
"""Copy exact new source files only; existing stage dependencies must match."""
from pathlib import Path
import argparse,json,shutil
from verify_source import D,R,sha,relative,verify
p=argparse.ArgumentParser();p.add_argument('--dest',required=True);p.add_argument('--apply',action='store_true');p.add_argument('--receipt');a=p.parse_args()
report=verify();b=json.loads((D/'source_binding.json').read_text());S=Path(a.dest).resolve()
assert S!=R and R not in S.parents and (S/'project.godot').is_file()
for path,digest in b['frozen_inputs_sha256'].items():
 target=S/relative(path)
 assert target.is_file() and sha(target)==digest,'stage dependency mismatch: '+path
mapped=b['files_sha256'].copy();mapped['res://'+str((D/'source_binding.json').relative_to(R))]=sha(D/'source_binding.json')
for path,digest in mapped.items():
 target=S/relative(path)
 assert S in target.resolve().parents
 assert not target.exists() or sha(target)==digest,'unrecognized existing successor: '+path
copied=[]
if a.apply:
 for path,digest in mapped.items():
  target=S/relative(path)
  if target.is_file() and sha(target)==digest:continue
  target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/relative(path),target);assert sha(target)==digest;copied.append(path)
report.update({'status':'P2_MECHANISM_STAGE_APPLIED' if a.apply else 'P2_MECHANISM_STAGE_PREFLIGHT_PASS','stage':str(S),'copied':copied})
if a.receipt:Path(a.receipt).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
