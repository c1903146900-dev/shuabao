#!/usr/bin/env python3
"""Freeze/audit exact E3 successor source; never launch Godot or import assets."""
from pathlib import Path
import argparse, ast, hashlib, json, re
D=Path(__file__).resolve().parent
R=D.parents[2]
P=R/'tests/ink_e2_boundary_20261006/ordinary01/text01'
PARENT_SHA='74b0d5e086895281f693ca7c758c77a3aacd7ff77c6b6246c7efc508f06e548a'
BOUNDARY=R/'tests/ink_e3_boundary_20261006/candidate01/source_binding.json'
BOUNDARY_SHA='01e2a9c5763f3abd752e18e7e3ec11d4e3e0367bbfb74e501ee556ce48527745'
ADAPTER='res://scripts/integration/yanguizhou_first_floor.gd'
CHOOSER='res://scripts/ui/hero_chooser.gd'
CANDIDATES=['Q1','Q2','Q3','E1','E2','E3','P1','R1']
RESOURCE=re.compile(r'''["']res://([^"'\n]+)["']''')
SKIP={'source_binding.json','source_audit_result.json','stage_receipt.json'}
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def relative(path):
 p=Path(path.removeprefix('res://'))
 assert not p.is_absolute() and '..' not in p.parts and '.godot' not in p.parts
 return p
def encode(value): return json.dumps(value,ensure_ascii=False,indent=2)+'\n'
def expected():
 assert sha(P/'source_binding.json')==PARENT_SHA
 assert sha(BOUNDARY)==BOUNDARY_SHA
 parent=json.loads((P/'source_binding.json').read_text())
 mapped=dict(parent['runtime_map']); aliases=parent['source_aliases']; changes={}
 for path in [ADAPTER,CHOOSER]:
  changes[path]={'before':mapped[path],'after':sha(R/relative(path)),'scope':'exact_E3_ordinary_successor'}
  mapped[path]=changes[path]['after']
 provenance=[R/'tests/ink_e3_exchange_foundation_20261005/candidate03/ink_e3_sim.gd',R/'tests/ink_q2_e3_composition_20261005/candidate02/q2_over_e3_sim.gd',R/'tests/ink_e3_boundary_20261006/candidate01/sim.gd',R/'tests/ink_q2_e3_composition_20261005/candidate02/source_binding.json',R/'tests/ink_e3_exchange_foundation_20261005/candidate03/source_binding.json']
 for file in [P/'source_binding.json',BOUNDARY,D.parent/'source_basis.md']+provenance:
  mapped['res://'+str(file.relative_to(R))]=sha(file)
 for file in sorted(D.rglob('*')):
  if file.is_file() and '__pycache__' not in file.parts and file.name not in SKIP:
   mapped['res://'+str(file.relative_to(R))]=sha(file)
 own_prefix='res://'+str(D.relative_to(R))+'/'
 queue=[key for key in mapped if key.startswith(own_prefix) and key.endswith(('.gd','.tscn','.tres')) and '/preimage_' not in key and '/source_checkpoint' not in key]
 seen=set()
 while queue:
  path=queue.pop()
  if path in seen: continue
  seen.add(path)
  source=R/relative(aliases.get(str(relative(path)),str(relative(path))))
  for dep in RESOURCE.findall(source.read_text()):
   if dep.endswith('/'): continue
   key='res://'+dep
   if key=='res://'+str((D/'source_binding.json').relative_to(R)): continue
   fresh=key not in mapped
   if fresh:
    target=R/relative(aliases.get(dep,dep))
    assert target.is_file(),'Missing referenced source: '+key+' from '+path
    mapped[key]=sha(target)
   if fresh and key.endswith(('.gd','.tscn','.tres')): queue.append(key)
 return parent,dict(sorted(mapped.items())),changes

def collect():
 b=json.loads((D/'source_binding.json').read_text());parent,mapped,changes=expected()
 assert b['runtime_map']==mapped
 assert b['ancestor_pin_replacements']==changes
 assert b['runtime_candidates']==CANDIDATES
 assert b['supported_hex_hooks']==parent['supported_hex_hooks']
 assert b['source_aliases']==parent['source_aliases']
 return b,mapped,parent['source_aliases']

def verify():
 b,mapped,aliases=collect()
 for path,digest in mapped.items():
  assert sha(R/relative(aliases.get(str(relative(path)),str(relative(path)))))==digest,'Exact source changed: '+path
 pre=json.loads((D/'preimage_manifest.json').read_text())
 for path,digest in pre['files'].items(): assert sha(D/'preimage_native01'/path)==digest
 before=(D/'preimage_native01'/relative(ADAPTER)).read_text().splitlines()
 after=(R/relative(ADAPTER)).read_text().splitlines()
 assert before[1:]==after[1:] and after[0]=='extends "res://tests/ink_e3_ordinary_20261006/ordinary01/host.gd"'
 before=(D/'preimage_native01'/relative(CHOOSER)).read_text()
 assert before.replace('res://tests/ink_e2_boundary_20261006/ordinary01/text01/runtime_text.gd','res://tests/ink_e3_ordinary_20261006/ordinary01/runtime_text.gd')==(R/relative(CHOOSER)).read_text()
 donor=(R/'tests/ink_e3_exchange_foundation_20261005/candidate03/ink_e3_sim.gd').read_text()
 copied=(D/'e3_base.gd').read_text()
 assert donor[donor.index('const ExchangeCommon'):]==copied[copied.index('const ExchangeCommon'):], 'E3 body drift beyond explicit parent/header transplant'
 boundary=(R/'tests/ink_e3_boundary_20261006/candidate01/sim.gd').read_text()
 local_boundary=(D/'e3_boundary.gd').read_text()
 assert boundary[boundary.index('const E3_BOUNDARY_DECISION'):boundary.index('\nfunc composition_fixture_status()')].rstrip()==local_boundary[local_boundary.index('const E3_BOUNDARY_DECISION'):].rstrip(), 'Boundary implementation drift'
 seams=(D/'q2_jump_seams.gd').read_text()
 jump_donor=(R/'tests/ink_q2_e3_composition_20261005/candidate02/q2_over_e3_sim.gd').read_text()
 def method(body,name):
  hit=re.search(r'^func '+re.escape(name)+r'\(',body,re.M);assert hit
  end=body.find('\nfunc ',hit.start()+1)
  return body[hit.start():end if end>=0 else len(body)].strip()
 for name in ['_q2_birth_contacts','_q2_collect_contacts','_q2_motion_events','_e3_return','_qe_observe_exchange','_qe_observe_return','_qe_record_jumps','_qe_motion_legs','_qe_leg_position','_qe_queued_river_current','_qe_split_prior_traces']:
  actual=method(seams,name)
  if name=='_q2_motion_events': actual=actual.replace(' if _qe_jumps.is_empty(): return super._q2_motion_events(before,tick_start,tick_end,from_time)\n','')
  assert actual==method(jump_donor,name),'Jump seam body drift: '+name
 assert 'func _q2_dispatch_contacts(' not in seams and 'super._settle_motion_interval(before,tick_start,tick_end)' in seams
 assert 'super._q2_hit_impact(hit)' in seams and '_qe_queued_river_current(hit)' in seams
 assert 'super._fixed_step(real_dt)' in seams and 'common =' not in seams
 bridge=(P/'bridge.gd').read_text().replace('res://tests/ink_e2_boundary_20261006/ordinary01/text01/','res://tests/ink_e3_ordinary_20261006/ordinary01/').replace('TextBinding','ExchangeBinding').replace('TextBridge','ExchangeBridge').replace('BoatCatalog','ExchangeCatalog').replace('res://tests/ink_e2_boundary_20261006/ordinary01/catalog.gd','res://tests/ink_e3_ordinary_20261006/ordinary01/catalog.gd').replace('res://tests/ink_e2_boundary_20261006/ordinary01/sim.gd','res://tests/ink_e3_ordinary_20261006/ordinary01/sim.gd')
 assert bridge==(D/'bridge.gd').read_text(),'Bridge body drift'
 for path in D.glob('*.py'): ast.parse(path.read_text())
 for path in D.glob('*.gd'):
  names=re.findall(r'^func (\w+)\(',path.read_text(),re.M)
  assert len(names)==len(set(names)), 'Duplicate GDScript method '+str(path)
 assert b['godot_parse']=='NOT_RUN' and b['finite_runtime']=='NOT_RUN' and b['native_input']=='NOT_RUN'
 assert not b['H11_H12_ordinary_enabled'] and not b['old_full_matrices_rerun']
 return {'status':'E3_ORDINARY_SOURCE_PASS','passed':True,'binding_sha256':sha(D/'source_binding.json'),'closure_files':len(mapped),'unchanged_parent_runtime_except_two_declared_leaves':True,'engine_invocations':0,'parse':'NOT_RUN','finite':'NOT_RUN'}

def freeze():
 assert not (D/'source_binding.json').exists(),'Binding already frozen; create a successor for any changed source'
 parent,mapped,changes=expected()
 # The actual gate's declared seven groups, not arbitrary source-text guesses.
 gate=(D/'finite_gate.gd').read_text()
 match=re.search(r'const REQUIRED_GROUPS\s*(?::[^=]+)?=\s*(\[[^\]]+\])',gate,re.S)
 assert match,'finite gate must declare REQUIRED_GROUPS'
 groups=ast.literal_eval(match.group(1))
 assert len(groups)==7
 b={'schema':'ink-e3-ordinary-composition-1','status':'SOURCE_ONLY_NOT_RUN','parent_binding_sha256':PARENT_SHA,'boundary_binding_sha256':BOUNDARY_SHA,'runtime_candidates':CANDIDATES,'supported_hex_hooks':parent['supported_hex_hooks'],'runtime_map':mapped,'ancestor_pin_replacements':changes,'source_aliases':parent['source_aliases'],'required_groups':groups,'H11_H12_ordinary_enabled':False,'old_full_matrices_rerun':False,'godot_parse':'NOT_RUN','finite_runtime':'NOT_RUN','native_input':'NOT_RUN','art_acceptance':False,'production_source_cutover':True,'production_runtime_validated':False}
 (D/'source_binding.json').write_text(encode(b))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--freeze',action='store_true');a=p.parse_args()
 if a.freeze: freeze()
 print(encode(verify()),end='')
