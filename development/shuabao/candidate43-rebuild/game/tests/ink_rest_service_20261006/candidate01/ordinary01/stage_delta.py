#!/usr/bin/env python3
"""Verify the complete existing P1/rest stage, then copy only this new leaf."""
from pathlib import Path
import argparse,json,shutil
from verify_source import R,D,ADAPTER,relative,sha,collect,verify
parser=argparse.ArgumentParser()
parser.add_argument('--dest',required=True)
parser.add_argument('--apply',action='store_true')
parser.add_argument('--receipt')
args=parser.parse_args()
source=verify(); b,closure,aliases=collect()
S=Path(args.dest).resolve()
assert S!=R and R not in S.parents and (S/'project.godot').is_file(), 'Existing separate P1/rest stage required'
plan={str(relative(path)):digest for path,digest in b['runtime_map'].items()}
# Historical manifest bytes are required by this complete audit even where the
# older stage omitted non-runtime metadata. Copy only exact already-pinned bytes.
plan.update({str(relative(path)):digest for path,digest in b['parent_bindings'].items()})
plan[str((D/'source_binding.json').relative_to(R))]=sha(D/'source_binding.json')
new_prefix=str(D.relative_to(R))+'/'
for path,digest in closure.items():
    destination=S/relative(path)
    assert S in destination.resolve().parents, 'Escaped destination'
    if path.startswith(new_prefix):
        if destination.exists(): assert sha(destination)==digest, 'Existing rest ordinary leaf differs: '+path
        continue
    if not destination.exists() and path in plan: continue
    assert destination.is_file(), 'Staged parent missing: '+path
    actual=sha(destination)
    if 'res://'+path==ADAPTER:
        assert actual in [b['ancestor_pin_replacements'][ADAPTER]['before'],digest], 'Unknown staged production adapter'
    else: assert actual==digest, 'Staged frozen parent differs: '+path
copied=[]
if args.apply:
    for path,digest in plan.items():
        destination=S/relative(path)
        if destination.is_file() and sha(destination)==digest: continue
        destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(R/relative(path),destination)
        assert sha(destination)==digest, 'Copy verification failed: '+path
        copied.append(path)
    for path,digest in closure.items(): assert sha(S/relative(path))==digest, 'Final stage pin failed: '+path
report={'status':'REST_ORDINARY_STAGE_APPLIED' if args.apply else 'REST_ORDINARY_STAGE_PREFLIGHT_PASS','binding_sha256':source['binding_sha256'],'stage':str(S),'closure_files':len(closure),'plan_files':len(plan),'copied':copied,'files':plan,'engine_invocations':0,'parse':'NOT_RUN','finite':'NOT_RUN','native_input':False}
if args.receipt: Path(args.receipt).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
