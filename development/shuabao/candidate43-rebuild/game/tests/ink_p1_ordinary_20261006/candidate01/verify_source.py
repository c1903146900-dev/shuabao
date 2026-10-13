#!/usr/bin/env python3
"""Bounded text/identity checks only. This does not parse or execute GDScript."""
import ast, hashlib, json, re
from pathlib import Path
D = Path(__file__).resolve().parent
R = D.parents[2]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
b = json.loads((D/'source_binding.json').read_text())
checks=[]
def check(value,label):
    checks.append({'passed':bool(value),'label':label})
    if not value: raise SystemExit(label)
for relative,expected in b['candidate_files'].items():
    check(sha(R/relative)==expected,'candidate pin '+relative)
    if relative.endswith('.py'): ast.parse((R/relative).read_text(),filename=relative)
for relative,expected in b['extra_reused_sources'].items(): check(sha(R/relative)==expected,'reused exact source '+relative)
for relative,expected in b['parent_bindings'].items(): check(sha(R/relative)==expected,'current parent pin '+relative)
pre=json.loads((D/'preimage_manifest.json').read_text())
for relative,expected in pre['files'].items(): check(sha(R/relative)==expected,'current frozen preimage '+relative)
checkpoint=json.loads((D/'core_checkpoint01.json').read_text())
repair=json.loads((D/'core_checkpoint02.json').read_text())
for name,expected in checkpoint['candidate_files'].items():
    if name in repair['source_changes']:
        change=repair['source_changes'][name]
        check(expected==change['before'] and sha(D/'preimage_gate01'/name)==expected and sha(D/name)==change['after'],'first saved source preserved and exact repaired successor '+name)
    else: check(sha(D/name)==expected,'first saved core unchanged '+name)
archive=D/'preimage_gate01'
manifest=json.loads((archive/'MANIFEST.json').read_text())
check(sha(archive/'MANIFEST.json')==repair['preimage_manifest_sha256'],'actual red preimage manifest identity')
for relative,expected in manifest['files'].items(): check(sha(archive/relative)==expected,'preserved source and actual-red evidence '+relative)
actual=json.loads((archive/'actual/result.json').read_text())
check(actual['checks']==325 and len(actual['failures'])==3 and not actual['passed'] and actual['source_binding_sha256']=='ce7a1899f426a2fb55505bb68f0d6b61fe31bdb7e32bb124f7c408731c4be906','original actual three-red result retained')
check('_q2_resume_from = tick_start' in (D/'sim.gd').read_text(),'narrow real interval cursor admission authored')
for name in ['sim.gd','settlement.gd','finite_gate.gd']:
    text=(D/name).read_text(); names=re.findall(r'^func (\w+)\(',text,re.M)
    check(len(names)==len(set(names)),'no duplicate method names '+name)
    check(not re.search(r'\bvar (seed|class_name|signal|self)\b',text),'bounded built-in-name hazard scan '+name)
text=(D/'settlement.gd').read_text()
check(text.startswith('extends "res://tests/ink_r1_ordinary_20261005/candidate01/sim.gd"'),'direct current R1 parent')
check('const P1_FAMILIES: Array = ["q1", "q2", "q3", "e1"]' in text,'only four admitted Q/E families')
check('func _e2_' not in text,'no old E2 lifecycle adapter')
gate=(D/'finite_gate.gd').read_text()
for group in b['required_groups']: check('func '+group+'()' in gate,'finite group authored '+group)
check('paused Q1 retains unfinished wave' in gate,'known source-review Q1 pause risk included as real public-step counterexample')
check('var sim_script: GDScript' in gate and 'var previous_script: GDScript' in gate,'typed reflection resources')
check(not b['production_promotion'],'no production P1 promotion')
print(json.dumps({'status':'SOURCE_TEXT_IDENTITY_PASS','passed':True,'checks':len(checks),'source_binding_sha256':sha(D/'source_binding.json'),'engine_invocations':0,'GDScript_parse':'NOT_RUN','runtime':'NOT_RUN','original_actual_gate':'325 checks, exactly 3 Q1 pause failures preserved','repair_runtime':'NOT_RUN'},ensure_ascii=False,indent=2))
