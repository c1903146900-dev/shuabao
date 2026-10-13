#!/usr/bin/env python3
"""Source-only composition of three frozen green leaves; no engine invocation."""
from pathlib import Path
import argparse,ast,hashlib,importlib.util,json,re
D=Path(__file__).resolve().parent;R=D.parents[2]
P=R/'tests/ink_p2_ordinary_20261006/ordinary01'
PARENT_SHA='6847fc2c3bcb41646198279ff6d48c14bd363b993509b657cab44fb5297869c8'
E1=R/'tests/ink_e1_reform_pause_20261006/candidate01'
CONSUMER=R/'tests/ink_ultimate_presentation_20261006/r1_consumer01'
ADAPTER='res://scripts/integration/yanguizhou_first_floor.gd';CHOOSER='res://scripts/ui/hero_chooser.gd'
CANDIDATES=['Q1','Q2','Q3','E1','E2','E3','P1','P2','R1']
RESOURCE=re.compile(r'''["']res://([^"'\n]+)["']''')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def relative(path):
 p=Path(path.removeprefix('res://'));assert not p.is_absolute() and '..' not in p.parts and '.godot' not in p.parts;return p
def encode(obj):return json.dumps(obj,ensure_ascii=False,indent=2)+'\n'
def static_check():
 spec=importlib.util.spec_from_file_location('proven_gd_preflight',P/'fix01/verify_source.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 old=m.static_issues(P/'finite_gate.gd');assert 'builtin_member:Projection' in old and 'class_resource_reflection:Production.get_base_script' in old
 checked={str(p.relative_to(R)):m.static_issues(p) for p in D.glob('*.gd')}
 assert not any(checked.values()),checked
 return {'original_bad_copy_rejected':old,'active_scripts_checked':len(checked),'active_issues':{k:v for k,v in checked.items() if v}}
def expected():
 assert sha(P/'source_binding.json')==PARENT_SHA
 parent=json.loads((P/'source_binding.json').read_text())
 e1=json.loads((E1/'source_binding.json').read_text());consumer=json.loads((CONSUMER/'source_binding.json').read_text())
 mapped=parent['runtime_map'].copy();aliases=parent['source_aliases'].copy();changes={}
 for target,name in [(ADAPTER,'production_adapter.gd'),(CHOOSER,'production_chooser.gd')]:
  changes[target]={'before':mapped[target],'after':sha(D/name),'scope':'single_composed_host_leaf_and_shared_catalog_text_only'}
  mapped[target]=sha(D/name);aliases[str(relative(target))]=str((D/name).relative_to(R))
 sources=[P/'source_binding.json',P/'fix02/source_binding.json',E1/'source_binding.json',CONSUMER/'source_binding.json']
 for p in sources:mapped['res://'+str(p.relative_to(R))]=sha(p)
 for path,digest in {**e1['frozen_inputs_sha256'],**e1['files_sha256']}.items():
  if path in changes:continue
  if path in mapped:assert mapped[path]==digest,('E1 source conflict',path)
  mapped[path]=digest
 for logical,entry in consumer['runtime_map'].items():
  key='res://'+logical
  if key in changes:continue
  if key in mapped:assert mapped[key]==entry['sha256'],('R1 consumer conflict',key)
  mapped[key]=entry['sha256']
  if entry['source']!=logical:
   assert logical not in aliases or aliases[logical]==entry['source'];aliases[logical]=entry['source']
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

def verify():
 b,mapped,aliases=collect()
 for path,digest in mapped.items():assert sha(R/relative(aliases.get(str(relative(path)),str(relative(path)))))==digest,path
 donor=(CONSUMER/'sim.gd').read_text().splitlines();combined=(D/'sim.gd').read_text().splitlines()
 assert donor[1:]==combined[1:] and combined[0]=='extends "res://tests/ink_e1_reform_pause_20261006/candidate01/sim.gd"'
 parent=json.loads((P/'source_binding.json').read_text())
 for target,name in [(ADAPTER,'production_adapter.gd'),(CHOOSER,'production_chooser.gd')]:
  # Root's actual production files intentionally remain on the earlier E3
  # source until final review. Only these three explicit revisions are valid.
  allowed=[parent['ancestor_pin_replacements'][target]['before'],b['ancestor_pin_replacements'][target]['before'],b['ancestor_pin_replacements'][target]['after']]
  assert sha(R/relative(target)) in allowed,(target,'unrecognized production revision')
  before=(P/name).read_text();after=(D/name).read_text()
  if target==ADAPTER:assert before.splitlines()[1:]==after.splitlines()[1:] and after.splitlines()[0]=='extends "res://tests/ink_ordinary_composed_20261006/candidate01/host.gd"'
  else:assert before.replace('res://tests/ink_p2_ordinary_20261006/ordinary01/runtime_text.gd','res://tests/ink_ordinary_composed_20261006/candidate01/runtime_text.gd')==after
 for p in D.glob('*.py'):ast.parse(p.read_text())
 assert len(b['required_groups'])==4 and not b['new_hex_admission']
 assert (D/'host.gd').read_text().splitlines()[0]=='extends "res://tests/ink_p2_ordinary_20261006/ordinary01/host.gd"'
 assert (D/'floor_session.gd').read_text().splitlines()[0]=='extends "res://tests/ink_p2_ordinary_20261006/ordinary01/floor_session.gd"'
 scan=static_check()
 return {'schema':'ink-ordinary-composed-source-check-1','passed':True,'source_binding_sha256':sha(D/'source_binding.json'),'closure_files':len(mapped),'consumer_body_only_extends_changed':True,'three_original_leaves_unchanged':True,'static_gd_preflight':scan,'planned_production_leaf_changes':list(b['ancestor_pin_replacements']),'godot_parse':'NOT_RUN','finite_runtime':'NOT_RUN','native_input':'NOT_RUN','final_presentation_animation':False,'real_multiplayer':False}

def freeze():
 assert not (D/'source_binding.json').exists(),'make successor instead of overwriting binding'
 parent,mapped,changes,aliases=expected()
 groups=json.loads(re.search(r'const REQUIRED_GROUPS: Array = (\[[^\n]+\])',(D/'finite_gate.gd').read_text()).group(1))
 b={'schema':'ink-ordinary-composed-candidate01','status':'SOURCE_ONLY_NOT_RUN','parent_binding_sha256':PARENT_SHA,'upstream_source_bindings':{str((p/'source_binding.json').relative_to(R)):sha(p/'source_binding.json') for p in [E1,CONSUMER,P/'fix02']},'runtime_candidates':CANDIDATES,'supported_hex_hooks':parent['supported_hex_hooks'],'runtime_map':mapped,'ancestor_pin_replacements':changes,'source_aliases':aliases,'required_groups':groups,'new_hex_admission':False,'production_source_cutover':False,'native_input':'NOT_RUN','final_presentation_animation':False,'real_multiplayer':False}
 (D/'source_binding.json').write_text(encode(b))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--freeze',action='store_true');a=p.parse_args()
 if a.freeze:freeze()
 print(encode(verify()),end='')
