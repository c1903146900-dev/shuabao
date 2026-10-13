#!/usr/bin/env python3
"""Exact source delta onto the existing current ordinary runtime stage; no engine."""
from pathlib import Path
import argparse,json,shutil
from verify_source import R,D,relative,sha,collect,verify
p=argparse.ArgumentParser();p.add_argument('--dest',required=True);p.add_argument('--apply',action='store_true');p.add_argument('--receipt');a=p.parse_args()
report=verify();b,mapped,aliases=collect();S=Path(a.dest).resolve()
assert S!=R and R not in S.parents and (S/'project.godot').is_file()
mapped['res://'+str((D/'source_binding.json').relative_to(R))]=sha(D/'source_binding.json')
for path,digest in mapped.items():
 dest=S/relative(path);assert S in dest.resolve().parents
 if not dest.exists():continue
 change=b['ancestor_pin_replacements'].get(path)
 assert sha(dest) in ([change['before'],digest] if change else [digest]),'Unrecognized stage difference: '+path
copied=[]
if a.apply:
 for path,digest in mapped.items():
  dest=S/relative(path)
  if dest.is_file() and sha(dest)==digest:continue
  source=R/relative(aliases.get(str(relative(path)),str(relative(path))))
  assert sha(source)==digest;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,dest);assert sha(dest)==digest;copied.append(path)
 for path,digest in mapped.items(): assert sha(S/relative(path))==digest
report.update({'status':'INK_R2_ORDINARY_STAGE_APPLIED' if a.apply else 'INK_R2_ORDINARY_STAGE_PREFLIGHT_PASS','stage':str(S),'plan_files':len(mapped),'copied':copied})
if a.receipt:Path(a.receipt).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
