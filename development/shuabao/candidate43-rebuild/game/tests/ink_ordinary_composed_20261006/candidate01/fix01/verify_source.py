#!/usr/bin/env python3
"""Fixture-only successor: retain original runtime and revision protection."""
from pathlib import Path
import argparse,ast,hashlib,importlib.util,json,re
D=Path(__file__).resolve().parent;P=D.parent;R=D.parents[3]
PARENT_SHA='b9f793bcf444150a170c573b70768ad888a17fe089fb8661167c14dc664f0e6e'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def relative(path):
 p=Path(path.removeprefix('res://'));assert not p.is_absolute() and '..' not in p.parts and '.godot' not in p.parts;return p
def encode(v):return json.dumps(v,ensure_ascii=False,indent=2)+'\n'
def original():
 spec=importlib.util.spec_from_file_location('combined_runtime_source',P/'verify_source.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 m.verify();return m.collect()
def static_check():
 path=R/'tests/ink_p2_ordinary_20261006/ordinary01/fix01/verify_source.py'
 spec=importlib.util.spec_from_file_location('proven_gd_preflight',path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 original_bad=m.static_issues(R/'tests/ink_p2_ordinary_20261006/ordinary01/finite_gate.gd')
 assert 'builtin_member:Projection' in original_bad and 'class_resource_reflection:Production.get_base_script' in original_bad
 files=json.loads(re.search(r'const FILES := (\[[^\n]+\])',(D/'parse_gate.gd').read_text()).group(1))
 found={path:m.static_issues(R/relative(path)) for path in files};found[str(D/'parse_gate.gd')]=m.static_issues(D/'parse_gate.gd')
 assert not any(found.values()),found
 return {'original_bad_copy_rejected':original_bad,'active_scripts_checked':len(found),'active_issues':{k:v for k,v in found.items() if v}}
def collect():
 assert sha(P/'source_binding.json')==PARENT_SHA
 parent,mapped,aliases=original();mapped=mapped.copy()
 mapped['res://'+str((P/'source_binding.json').relative_to(R))]=PARENT_SHA
 for p in D.iterdir():
  if p.is_file() and p.suffix in ['.gd','.py','.md']:mapped['res://'+str(p.relative_to(R))]=sha(p)
 b=json.loads((D/'source_binding.json').read_text())
 assert b['runtime_map']==dict(sorted(mapped.items())) and b['source_aliases']==aliases and b['ancestor_pin_replacements']==parent['ancestor_pin_replacements']
 assert b['runtime_source_binding_sha256']==PARENT_SHA and b['required_groups']==parent['required_groups']
 return b,mapped,aliases

def verify():
 b,mapped,aliases=collect()
 for path,digest in mapped.items():assert sha(R/relative(aliases.get(str(relative(path)),str(relative(path)))))==digest,path
 for p in D.glob('*.py'):ast.parse(p.read_text())
 before=(P/'finite_gate.gd').read_text();after=(D/'finite_gate.gd').read_text()
 assert before.count('check(')<=after.count('check(') and before.count('near(')<=after.count('near(')
 assert 'room._transition_result("select_node",selected)' in after and 'room._transition_result("enter_selected_node",entered)' in after
 assert 'stale_result.reason == "stale_state"' in after and 'old pre-room window request remains refused' in after
 assert 'actual live P2 upgrade retains stacks' in after
 return {'schema':'ink-composed-fixture-fix01-source','passed':True,'source_binding_sha256':sha(D/'source_binding.json'),'runtime_source_binding_sha256':PARENT_SHA,'closure_files':len(mapped),'static_gd_preflight':static_check(),'fixture_uses_original_host_transition':True,'production_changed':False,'runtime_source_changed':False,'godot_parse':'NOT_RUN','finite_runtime':'NOT_RUN'}

def freeze():
 assert not (D/'source_binding.json').exists()
 assert sha(P/'source_binding.json')==PARENT_SHA
 parent,mapped,aliases=original();mapped=mapped.copy();mapped['res://'+str((P/'source_binding.json').relative_to(R))]=PARENT_SHA
 for p in D.iterdir():
  if p.is_file() and p.suffix in ['.gd','.py','.md']:mapped['res://'+str(p.relative_to(R))]=sha(p)
 b={'schema':'ink-composed-fixture-fix01','status':'SOURCE_ONLY_NOT_RUN','runtime_source_binding_sha256':PARENT_SHA,'runtime_map':dict(sorted(mapped.items())),'source_aliases':aliases,'ancestor_pin_replacements':parent['ancestor_pin_replacements'],'required_groups':parent['required_groups'],'repair_sha256':{name:{'before_path':'res://'+str((P/name).relative_to(R)),'before':sha(P/name),'after_path':'res://'+str((D/name).relative_to(R)),'after':sha(D/name),'stage_update':'add distinct fixture successor; original bytes unchanged'} for name in ['finite_gate.gd','parse_gate.gd']}}
 (D/'source_binding.json').write_text(encode(b))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--freeze',action='store_true');a=p.parse_args()
 if a.freeze:freeze()
 print(encode(verify()),end='')
