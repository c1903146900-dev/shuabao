#!/usr/bin/env python3
"""Copy only exact ordinary leaf/entry successors over the verified existing stage."""
from pathlib import Path
import argparse,hashlib,json,shutil
D=Path(__file__).resolve().parent;R=D.parents[3]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--dest',required=True);p.add_argument('--apply',action='store_true');p.add_argument('--receipt');a=p.parse_args();S=Path(a.dest).resolve()
if S==R or R in S.parents or not (S/'project.godot').is_file():raise SystemExit('Existing separate E1/R1-core stage required')
def rel(value):
 q=Path(value)
 if q.is_absolute() or '..' in q.parts or '.godot' in q.parts:raise SystemExit('Invalid closure path '+value)
 return q
b=json.loads((D/'source_binding.json').read_text());r=R/rel(b['parent_stage_receipt']['path'])
if sha(r)!=b['parent_stage_receipt']['sha256']:raise SystemExit('Parent stage receipt changed')
parent=json.loads(r.read_text());before_count=after_count=0
for target,item in parent['closure'].items():
 dest=S/rel(target)
 if not dest.is_file():raise SystemExit('Parent stage dependency missing '+target)
 actual=sha(dest);changed=b['ancestor_pin_replacements'].get('res://'+target,{})
 if actual==item['sha256']:before_count+=1
 elif changed and changed['before']==item['sha256'] and actual==changed['after']:after_count+=1
 else:raise SystemExit('Parent stage dependency mismatch '+target)
core=D.parent/'source_binding.json'
if sha(core)!=b['parent_core_sha256'] or sha(S/core.relative_to(R))!=b['parent_core_sha256']:raise SystemExit('Exact already-staged598 R1 core binding required')
for name,digest in json.loads(core.read_text())['candidate_files'].items():
 source=D.parent/rel(name);dest=S/source.relative_to(R)
 if sha(source)!=digest or not dest.is_file() or sha(dest)!=digest:raise SystemExit('Verified core dependency changed '+name)
plan={path.removeprefix('res://'):digest for path,digest in b['runtime_map'].items()}
plan[str((D/'source_binding.json').relative_to(R))]=sha(D/'source_binding.json')
for target,digest in plan.items():
 source=R/rel(target);dest=S/rel(target)
 if sha(source)!=digest:raise SystemExit('New ordinary source changed '+target)
 if S not in dest.resolve().parents:raise SystemExit('Destination escapes stage')
copied=0
if a.apply:
 for target,digest in plan.items():
  source=R/target;dest=S/target
  if not dest.is_file() or sha(dest)!=digest:dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest);copied+=1
  if sha(dest)!=digest:raise SystemExit('Ordinary staged mismatch '+target)
out={'status':'R1_ORDINARY_DELTA_COPIED_SHA_VERIFIED' if a.apply else 'R1_ORDINARY_PREFLIGHT_NO_COPY','stage':str(S),'parent_targets_verified':before_count+after_count,'already_updated_entry_targets':after_count,'candidate_targets':len(plan),'copied':copied,'binding_sha256':sha(D/'source_binding.json'),'engine_or_import_invoked':False,'copy_godot_cache':False,'closure':plan}
if a.receipt:
 output=Path(a.receipt)
 if not output.is_absolute():raise SystemExit('Receipt must be absolute')
 output.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(out,ensure_ascii=False,indent=2))
