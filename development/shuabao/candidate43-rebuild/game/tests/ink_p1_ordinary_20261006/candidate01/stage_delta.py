#!/usr/bin/env python3
"""Verify the CURRENT ordinary R1 stage and copy only the bounded P1 candidate."""
import argparse, hashlib, json, shutil
from pathlib import Path
D = Path(__file__).resolve().parent
R = D.parents[2]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def safe(value):
    p = Path(value.removeprefix('res://'))
    if p.is_absolute() or '..' in p.parts or '.godot' in p.parts or 'sandbox' in str(p).lower():
        raise ValueError('Unsafe relative path: ' + value)
    return p
p = argparse.ArgumentParser()
p.add_argument('--dest', required=True); p.add_argument('--apply', action='store_true'); p.add_argument('--receipt')
a = p.parse_args(); S = Path(a.dest).resolve()
if S == R or R in S.parents or not (S/'project.godot').is_file(): raise SystemExit('Existing separate current R1 ordinary stage required')
b = json.loads((D/'source_binding.json').read_text())
for relative, expected in b['parent_bindings'].items():
    if sha(R/safe(relative)) != expected: raise SystemExit('Current parent binding changed: ' + relative)
e1 = json.loads((R/'tests/ink_e1_ordinary_20261005/candidate01/stage_receipt.json').read_text())
ordinary = json.loads((R/'tests/ink_r1_ordinary_20261005/candidate01/ordinary01/source_binding.json').read_text())
core_dir = Path('tests/ink_r1_ordinary_20261005/candidate01')
core = json.loads((R/core_dir/'source_binding.json').read_text())
# Preserve the two explicitly recorded entry replacements of current R1. Never
# replace current E1/R1/navigation with the historical isolated P1 parent chain.
parent = {target: item['sha256'] for target,item in e1['closure'].items()}
for uri, replacement in ordinary['ancestor_pin_replacements'].items():
    target = str(safe(uri))
    if parent.get(target) != replacement['before']: raise SystemExit('Unrecognized parent entry replacement: ' + target)
    parent[target] = replacement['after']
for name, expected in core['candidate_files'].items(): parent[str(core_dir/safe(name))] = expected
parent[str(core_dir/'source_binding.json')] = b['parent_bindings'][str(core_dir/'source_binding.json')]
parent.update({str(safe(uri)):digest for uri,digest in ordinary['runtime_map'].items()})
parent[str(core_dir/'ordinary01/source_binding.json')] = b['parent_bindings'][str(core_dir/'ordinary01/source_binding.json')]
for target,expected in parent.items():
    dest = S/safe(target)
    if not dest.is_file() or sha(dest) != expected: raise SystemExit('Current staged parent mismatch: ' + target)
plan = dict(b['candidate_files']); plan.update(b['extra_reused_sources'])
plan[str((D/'source_binding.json').relative_to(R))] = sha(D/'source_binding.json')
for target,expected in plan.items():
    source = R/safe(target); dest = S/safe(target)
    if not source.is_file() or sha(source) != expected: raise SystemExit('P1 candidate changed: ' + target)
    if S not in dest.resolve().parents: raise SystemExit('Escaped stage')
copied = 0
if a.apply:
    for target,expected in plan.items():
        source = R/safe(target); dest = S/safe(target)
        if not dest.is_file() or sha(dest) != expected:
            dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(source,dest); copied += 1
        if sha(dest) != expected: raise SystemExit('P1 staged mismatch: ' + target)
report = {'status':'P1_DELTA_SHA_VERIFIED' if a.apply else 'P1_PREFLIGHT_READY_NO_COPY','stage':str(S),'parent_targets_verified':len(parent),'candidate_targets':len(plan),'copied':copied,'binding_sha256':sha(D/'source_binding.json'),'engine_or_import_invoked':False,'production_entry_changed':False,'copy_godot_cache':False,'parent_closure':parent,'closure':plan}
if a.receipt:
    output = Path(a.receipt)
    if not output.is_absolute(): raise SystemExit('Receipt must be absolute')
    output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
