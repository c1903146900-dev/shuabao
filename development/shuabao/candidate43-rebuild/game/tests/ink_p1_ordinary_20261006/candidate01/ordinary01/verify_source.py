#!/usr/bin/env python3
"""Bounded exact P1 ordinary source audit. No GDScript parse or engine call."""
from pathlib import Path
import ast, hashlib, json, re
D=Path(__file__).resolve().parent;R=D.parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
checks=[]
def check(v,label):
    checks.append({'passed':bool(v),'label':label})
    if not v:raise SystemExit(label)
b=json.loads((D/'source_binding.json').read_text())
for uri,digest in b['runtime_map'].items():
    p=R/uri.removeprefix('res://');check(sha(p)==digest,'ordinary pin '+uri)
    if p.suffix=='.py':ast.parse(p.read_text(),filename=str(p))
for path,digest in b['parent_bindings'].items():check(sha(R/path)==digest,'frozen parent binding '+path)
pre=json.loads((D/'preimage_manifest.json').read_text())
for path,digest in pre['parent_files'].items():check(sha(R/path)==digest,'old ordinary parent retained '+path)
for path,digest in pre['production_files'].items():
    saved=D/'preimage_production'/path
    check(sha(saved)==digest,'old cc0a production bytes preserved '+path)
    change=b['ancestor_pin_replacements'].get('res://'+path)
    if change:check(change['before']==digest and change['after']==sha(R/path),'explicit production leaf replacement '+path)
    else:check(sha(R/path)==digest,'production unchanged '+path)
first=D/'preimage_admission01';first_manifest=json.loads((first/'MANIFEST.json').read_text())
for name,digest in first_manifest.items():check(sha(first/name)==digest,'first ordinary checkpoint preserved '+name)
life_path=R/b['lifesteal_binding']['path'];check(sha(life_path)==b['lifesteal_binding']['sha256'],'exact lifesteal leaf binding')
life=json.loads(life_path.read_text())
for path,digest in life['candidate_files'].items():check(sha(R/path)==digest,'lifesteal leaf '+path)
for path,digest in life['frozen_parent_pins'].items():check(sha(R/path)==digest,'lifesteal parent '+path)
for p in list(D.glob('*.gd'))+[life_path.parent/'sim.gd']:
    text=p.read_text();names=re.findall(r'^func (\w+)\(',text,re.M)
    check(len(names)==len(set(names)),'no duplicate method '+p.name)
    check(not re.search(r'\bvar (seed|class_name|signal|self)\b',text),'bounded built-in-name scan '+p.name)
    check(not re.search(r'\b(?:Sim|OldSim|Room|Finite)\.(?:resource_path|get_base_script|can_instantiate)',text),'typed Script reflection '+p.name)
gate=(D/'finite_gate.gd').read_text()
for group in b['required_groups']:check('groups.append("'+group+'")' in gate,'authored required group '+group)
check('500' in gate and 'commerce_quote("base:B09")' in gate and '.s.submit(' in gate,'real B09 commerce gate is authored')
check('matching_commit' in (life_path.parent/'sim.gd').read_text(),'supplement matches real committed positive receipt')
check('extra shared core step' in gate and 'BASIC target never enters P1' in gate,'single concurrent BASIC/P1 pause counterexample authored')
check('P2' not in b['runtime_candidates'] and 'P3' not in b['runtime_candidates'] and len(b['supported_hex_hooks'])==10,'closed other passives and ten existing hooks')
check(b['ordinary_XP_gold_SP_granted']==False,'ordinary grants remain absent')
print(json.dumps({'status':'P1_ORDINARY_SOURCE_TEXT_IDENTITY_PASS','passed':True,'checks':len(checks),'binding_sha256':sha(D/'source_binding.json'),'lifesteal_binding_sha256':sha(life_path),'engine_invocations':0,'parse':'NOT_RUN','ordinary_runtime':'NOT_RUN','native_input':False},ensure_ascii=False,indent=2))
