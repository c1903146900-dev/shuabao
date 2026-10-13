#!/usr/bin/env python3
"""Source-only R2 ordinary successor. No engine, import or stage mutation."""
from pathlib import Path
import argparse,ast,hashlib,importlib.util,json,re
D=Path(__file__).resolve().parent;R=D.parents[2]
P=R/'tests/ink_ordinary_composed_20261006/candidate01'
PARENT_SHA='b9f793bcf444150a170c573b70768ad888a17fe089fb8661167c14dc664f0e6e'
MECHANISM=R/'tests/ink_r2_peaks_20261006/candidate01'
CONSUMER=R/'tests/ink_ultimate_presentation_20261006/r1_consumer01'
ADAPTER='res://scripts/integration/yanguizhou_first_floor.gd';CHOOSER='res://scripts/ui/hero_chooser.gd'
CANDIDATES=['Q1','Q2','Q3','E1','E2','E3','P1','P2','R1','R2']
RESOURCE=re.compile(r'''["']res://([^"'\n]+)["']''')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def relative(path):
 p=Path(path.removeprefix('res://'));assert not p.is_absolute() and '..' not in p.parts and '.godot' not in p.parts;return p
def encode(obj):return json.dumps(obj,ensure_ascii=False,indent=2)+'\n'
def static_check():
 prior=R/'tests/ink_p2_ordinary_20261006/ordinary01'
 spec=importlib.util.spec_from_file_location('proven_gd_preflight',prior/'fix01/verify_source.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 old=m.static_issues(prior/'finite_gate.gd');assert 'builtin_member:Projection' in old and 'class_resource_reflection:Production.get_base_script' in old
 checked={str(p.relative_to(R)):m.static_issues(p) for p in D.glob('*.gd')}
 assert not any(checked.values()),checked
 return {'original_bad_copy_rejected':old,'active_scripts_checked':len(checked),'active_issues':{k:v for k,v in checked.items() if v}}
def expected():
 assert sha(P/'source_binding.json')==PARENT_SHA
 parent=json.loads((P/'source_binding.json').read_text());mechanism=json.loads((MECHANISM/'source_binding.json').read_text())
 mapped=parent['runtime_map'].copy();aliases=parent['source_aliases'].copy();changes={}
 for target,name in [(ADAPTER,'production_adapter.gd'),(CHOOSER,'production_chooser.gd')]:
  changes[target]={'before':mapped[target],'after':sha(D/name),'scope':'independent_R2_ordinary_host_and_shared_catalog_text_only'}
  mapped[target]=sha(D/name);aliases[str(relative(target))]=str((D/name).relative_to(R))
 for path,digest in {**mechanism['frozen_inputs_sha256'],**mechanism['source_inputs_sha256'],**mechanism['files_sha256']}.items():
  if path in changes:continue
  if path in mapped:assert mapped[path]==digest,('R2 mechanism source conflict',path)
  mapped[path]=digest
 for p in [P/'source_binding.json',P/'fix01/source_binding.json',MECHANISM/'source_binding.json',MECHANISM/'fixture_onlyfix01/source_binding.json']:
  mapped['res://'+str(p.relative_to(R))]=sha(p)
 for p in D.iterdir():
  if p.is_file() and p.suffix in ['.gd','.py','.md']:mapped['res://'+str(p.relative_to(R))]=sha(p)
 queue=[k for k in mapped if k.startswith('res://'+str(D.relative_to(R))+'/') and k.endswith(('.gd','.tscn','.tres')) and not k.endswith('/production_chooser.gd')];seen=set()
 binding='res://'+str((D/'source_binding.json').relative_to(R))
 while queue:
  key=queue.pop()
  if key in seen:continue
  seen.add(key);source=R/relative(aliases.get(str(relative(key)),str(relative(key))))
  for ref in RESOURCE.findall(source.read_text()):
   if ref.endswith('/'):continue
   target='res://'+ref
   if target==binding:continue
   fresh=target not in mapped
   if fresh:
    file=R/relative(aliases.get(ref,ref));assert file.is_file(),(key,target)
    mapped[target]=sha(file)
   if fresh and target.endswith(('.gd','.tscn','.tres')):queue.append(target)
 return parent,dict(sorted(mapped.items())),changes,aliases
def collect():
 b=json.loads((D/'source_binding.json').read_text());parent,mapped,changes,aliases=expected()
 assert b['runtime_map']==mapped and b['ancestor_pin_replacements']==changes and b['source_aliases']==aliases
 assert b['runtime_candidates']==CANDIDATES and b['supported_hex_hooks']==parent['supported_hex_hooks']
 return b,mapped,aliases
def functions(text):
 out={}
 for match in re.finditer(r'^func (\w+)\(',text,re.M):
  end=text.find('\nfunc ',match.end());out[match.group(1)]=text[match.start():end if end>=0 else len(text)].strip()
 return out
def verify():
 b,mapped,aliases=collect()
 for path,digest in mapped.items():assert sha(R/relative(aliases.get(str(relative(path)),str(relative(path)))))==digest,path
 donor=functions((CONSUMER/'sim.gd').read_text());active=functions((D/'sim.gd').read_text())
 generalized={'_hero_action_policy','emit_event','_finish_show_if_due','_hero_clear_transients','step','_fixed_step'}
 for name,body in donor.items():
  if name not in generalized:assert active[name]==body,('unapproved consumer body change',name)
 assert set(active)-set(donor)=={'_hero_cast_skill','_created_presentation'}
 assert (D/'sim.gd').read_text().splitlines()[0]=='extends "res://tests/ink_r2_peaks_20261006/candidate01/sim.gd"'
 for target,name in [(ADAPTER,'production_adapter.gd'),(CHOOSER,'production_chooser.gd')]:
  assert sha(R/relative(target)) in [b['ancestor_pin_replacements'][target]['before'],b['ancestor_pin_replacements'][target]['after']],('unrecognized production revision',target)
  before=(P/name).read_text();after=(D/name).read_text()
  if target==ADAPTER:assert before.splitlines()[1:]==after.splitlines()[1:]
  else:assert before.replace('res://tests/ink_ordinary_composed_20261006/candidate01/runtime_text.gd','res://tests/ink_r2_ordinary_20261006/candidate01/runtime_text.gd')==after
 for p in D.glob('*.py'):ast.parse(p.read_text())
 assert len(b['required_groups'])==4 and not b['new_hex_admission']
 assert 'room._transition_result("enter_selected_node",entered)' in (D/'finite_gate.gd').read_text()
 scan=static_check()
 return {'schema':'ink-r2-ordinary-source-check-1','passed':True,'source_binding_sha256':sha(D/'source_binding.json'),'closure_files':len(mapped),'unchanged_consumer_functions':sorted(set(donor)-generalized),'static_gd_preflight':scan,'planned_production_leaf_changes':list(b['ancestor_pin_replacements']),'godot_parse':'NOT_RUN','finite_runtime':'NOT_RUN','native_input':'NOT_RUN','final_presentation_animation':False,'real_multiplayer':False}
def freeze():
 assert not (D/'source_binding.json').exists(),'make successor instead of overwriting binding'
 parent,mapped,changes,aliases=expected()
 groups=json.loads(re.search(r'const REQUIRED_GROUPS: Array = (\[[^\n]+\])',(D/'finite_gate.gd').read_text()).group(1))
 b={'schema':'ink-r2-ordinary-candidate01','status':'SOURCE_ONLY_NOT_RUN','parent_binding_sha256':PARENT_SHA,'runtime_candidates':CANDIDATES,'supported_hex_hooks':parent['supported_hex_hooks'],'runtime_map':mapped,'ancestor_pin_replacements':changes,'source_aliases':aliases,'required_groups':groups,'new_hex_admission':False,'production_source_cutover':False,'native_input':'NOT_RUN','final_presentation_animation':False,'real_multiplayer':False}
 (D/'source_binding.json').write_text(encode(b))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--freeze',action='store_true');a=p.parse_args()
 if a.freeze:freeze()
 print(encode(verify()),end='')
