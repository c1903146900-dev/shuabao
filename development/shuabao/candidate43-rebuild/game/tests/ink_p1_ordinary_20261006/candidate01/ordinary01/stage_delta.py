#!/usr/bin/env python3
"""Pin current staged R1 + tested P1 core; copy only this ordinary successor."""
from pathlib import Path
import argparse, hashlib, json, shutil
D=Path(__file__).resolve().parent;R=D.parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def rel(p):
    q=Path(p.removeprefix('res://'))
    if q.is_absolute() or '..' in q.parts or '.godot' in q.parts or 'sandbox' in str(q).lower():raise ValueError('Unsafe path '+p)
    return q
p=argparse.ArgumentParser();p.add_argument('--dest',required=True);p.add_argument('--apply',action='store_true');p.add_argument('--receipt');a=p.parse_args();S=Path(a.dest).resolve()
if S==R or R in S.parents or not (S/'project.godot').is_file():raise SystemExit('Existing separate R1/P1-core stage required')
b=json.loads((D/'source_binding.json').read_text())
for path,digest in b['parent_bindings'].items():
    if sha(R/rel(path))!=digest:raise SystemExit('Frozen parent manifest changed '+path)
e1=json.loads((R/'tests/ink_e1_ordinary_20261005/candidate01/stage_receipt.json').read_text())
r1_dir=Path('tests/ink_r1_ordinary_20261005/candidate01');r1=json.loads((R/r1_dir/'ordinary01/source_binding.json').read_text());core=json.loads((R/r1_dir/'source_binding.json').read_text())
parent={target:item['sha256'] for target,item in e1['closure'].items()}
for uri,change in r1['ancestor_pin_replacements'].items():
    target=str(rel(uri))
    if parent.get(target)!=change['before']:raise SystemExit('Unknown old entry replacement '+target)
    parent[target]=change['after']
for name,digest in core['candidate_files'].items():parent[str(r1_dir/rel(name))]=digest
parent[str(r1_dir/'source_binding.json')]=sha(R/r1_dir/'source_binding.json')
parent.update({str(rel(uri)):digest for uri,digest in r1['runtime_map'].items()})
parent[str(r1_dir/'ordinary01/source_binding.json')]=sha(R/r1_dir/'ordinary01/source_binding.json')
p1path=R/'tests/ink_p1_ordinary_20261006/candidate01/source_binding.json';p1=json.loads(p1path.read_text())
parent.update(p1['candidate_files']);parent.update(p1['extra_reused_sources']);parent[str(p1path.relative_to(R))]=sha(p1path)
already=0
for target,digest in parent.items():
    path=S/rel(target)
    if not path.is_file():raise SystemExit('Staged parent missing '+target)
    actual=sha(path);change=b['ancestor_pin_replacements'].get('res://'+target,{})
    if actual==digest:continue
    if change and change['before']==digest and actual==change['after']:already+=1
    else:raise SystemExit('Staged parent changed '+target)
plan={str(rel(uri)):digest for uri,digest in b['runtime_map'].items()}
life_path=R/rel(b['lifesteal_binding']['path'])
if sha(life_path)!=b['lifesteal_binding']['sha256']:raise SystemExit('Lifesteal leaf pin changed')
life=json.loads(life_path.read_text());plan.update(life['candidate_files']);plan[str(life_path.relative_to(R))]=sha(life_path)
plan[str((D/'source_binding.json').relative_to(R))]=sha(D/'source_binding.json')
for target,digest in plan.items():
    if sha(R/rel(target))!=digest:raise SystemExit('Candidate changed '+target)
    if S not in (S/rel(target)).resolve().parents:raise SystemExit('Escaped stage')
copied=0
if a.apply:
    for target,digest in plan.items():
        source=R/rel(target);dest=S/rel(target)
        if not dest.is_file() or sha(dest)!=digest:dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest);copied+=1
        if sha(dest)!=digest:raise SystemExit('Copied hash mismatch '+target)
out={'status':'P1_ORDINARY_DELTA_SHA_VERIFIED' if a.apply else 'P1_ORDINARY_PREFLIGHT_NO_COPY','stage':str(S),'parent_targets_verified':len(parent),'already_updated_entries':already,'candidate_targets':len(plan),'copied':copied,'binding_sha256':sha(D/'source_binding.json'),'lifesteal_binding_sha256':sha(life_path),'engine_or_import_invoked':False,'copy_godot_cache':False,'parent_closure':parent,'closure':plan}
if a.receipt:
    dest=Path(a.receipt)
    if not dest.is_absolute():raise SystemExit('Absolute receipt required')
    dest.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(out,ensure_ascii=False,indent=2))
