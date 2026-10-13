#!/usr/bin/env python3
"""Preflight an existing ordinary runtime stage; apply only exact pinned delta."""
from pathlib import Path
import argparse,json,shutil
from verify_source import R,D,ADAPTER,BEFORE,relative,sha,parents,collect,verify
p=argparse.ArgumentParser(); p.add_argument('--dest',required=True); p.add_argument('--apply',action='store_true'); p.add_argument('--receipt')
a=p.parse_args(); report=verify(); b,closure,aliases=collect(); _,old,_,_=parents()
S=Path(a.dest).resolve()
assert S != R and R not in S.parents and (S/'project.godot').is_file(), 'Separate existing ordinary stage required'
new_prefix=str(D.relative_to(R))+'/'
plan=dict(closure); plan[str((D/'source_binding.json').relative_to(R))]=sha(D/'source_binding.json')
for path,digest in plan.items():
    dest=S/relative(path)
    assert S in dest.resolve().parents
    if not dest.exists(): continue
    if 'res://'+path == ADAPTER: assert sha(dest) in [BEFORE,digest], 'Unknown staged production adapter'
    else: assert sha(dest)==digest, 'Existing pinned staged file differs: '+path
copied=[]
if a.apply:
    for path,digest in plan.items():
        dest=S/relative(path)
        if dest.is_file() and sha(dest)==digest: continue
        source=R/relative(aliases.get(path,path)); assert sha(source)==digest
        dest.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(source,dest)
        assert sha(dest)==digest; copied.append(path)
    for path,digest in plan.items(): assert sha(S/relative(path))==digest
report.update({'status':'E2_ORDINARY_STAGE_APPLIED' if a.apply else 'E2_ORDINARY_STAGE_PREFLIGHT_PASS','stage':str(S),'copied':copied,'plan_files':len(plan)})
if a.receipt: Path(a.receipt).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
