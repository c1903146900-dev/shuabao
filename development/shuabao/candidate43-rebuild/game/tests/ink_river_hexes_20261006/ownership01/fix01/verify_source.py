#!/usr/bin/env python3
"""Exact fixture-only correction above the unchanged ownership01 runtime."""
from pathlib import Path
import argparse,ast,hashlib,importlib.util,json,re
D=Path(__file__).resolve().parent;R=D.parents[3];P=D.parent
PARENT_SHA='bdbb59957072db7727c5fbac76d8912353f909791936bf444acff75744178266'
GROUPS=['p1_complete_river_and_sunset','p1_terminal_pause_and_victory','p2_new_use_sunset_entitlement','original_packet_scope_and_retirement']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def encode(x):return json.dumps(x,ensure_ascii=False,indent=2)+'\n'
def relative(key):
 p=Path(key.removeprefix('res://'));assert not p.is_absolute() and '..' not in p.parts and '.godot' not in p.parts
 return p
def checks():
 assert sha(P/'source_binding.json')==PARENT_SHA
 assert not (D/'sim.gd').exists(),'test-only fix cannot introduce another runtime Sim'
 old=(P/'finite_gate.gd').read_text();new=(D/'finite_gate.gd').read_text()
 assert new.splitlines()[1]==old.splitlines()[1]=='const Sim = preload("res://tests/ink_river_hexes_20261006/ownership01/sim.gd")'
 restored=new.replace('res://tests/ink_river_hexes_20261006/ownership01/fix01/source_binding.json','res://tests/ink_river_hexes_20261006/ownership01/source_binding.json')
 restored=restored.replace('"fixture_fix_only":true,"runtime_sim_unchanged":true,','')
 begin=restored.index('func scope_state(sim) -> Dictionary:');end=restored.index('func original_packet_scope_and_retirement()',begin)
 restored=restored[:begin]+restored[end:]
 before=(D/'replaced_fixture.txt').read_text().rstrip('\n');after=(D/'replacement_fixture.txt').read_text().rstrip('\n')
 assert restored.count(after)==1
 restored=restored.replace(after,before)
 assert restored==old,'unexpected finite change outside exact room lifecycle fix'
 assert new.count('sim.step(')==old.count('sim.step(')
 assert 'sim.end_encounter("cleared")' in after and 'check(entered.accepted' in after
 assert '.clear(' not in after and 'sim.phase=' not in after.replace('sim.phase==','')
 parse=(D/'parse_gate.gd').read_text().replace('ownership01/fix01/finite_gate.gd','ownership01/finite_gate.gd').replace('ownership01/fix01/source_binding.json','ownership01/source_binding.json')
 assert parse==(P/'parse_gate.gd').read_text()
 for p in D.glob('*.py'):ast.parse(p.read_text())
 spec=importlib.util.spec_from_file_location('bounded_static_gd_preflight',R/'tests/ink_p2_ordinary_20261006/ordinary01/fix01/verify_source.py')
 module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 scanned={p.name:module.static_issues(p) for p in D.glob('*.gd')};assert not any(scanned.values()),scanned
 return scanned
def expected():
 parent=json.loads((P/'source_binding.json').read_text());mapped=parent['runtime_map'].copy()
 mapped['res://'+str((P/'source_binding.json').relative_to(R))]=PARENT_SHA
 for p in D.iterdir():
  if p.is_file() and p.suffix in ['.gd','.py','.md','.txt']:
   key='res://'+str(p.relative_to(R));assert key not in mapped;mapped[key]=sha(p)
 return parent,dict(sorted(mapped.items()))
def verify():
 scanned=checks();parent,mapped=expected();binding=json.loads((D/'source_binding.json').read_text())
 assert binding['runtime_map']==mapped and binding['source_aliases']==parent['source_aliases']
 assert binding['required_groups']==GROUPS and binding['fixture_fix_only'] and not binding['ordinary_admission']
 for key,digest in mapped.items():
  source=R/relative(parent['source_aliases'].get(str(relative(key)),str(relative(key))))
  assert sha(source)==digest,key
 return {'schema':'ink-river-ownership-fixture-fix01-source-check','passed':True,'source_binding_sha256':sha(D/'source_binding.json'),'parent_binding_sha256':PARENT_SHA,'closure_files':len(mapped),'new_gd_static_checks':scanned,'finite_script_restores_byte_exact_parent':True,'runtime_sim_unchanged':True,'P2_history_contract_unchanged':True,'original_red_and_diagnostic_preserved':True,'ordinary_admission':False,'Godot_parse':'NOT_RUN','finite_runtime':'NOT_RUN','native_input':'NOT_RUN','art_audio_accepted':False,'real_multiplayer':False}
def freeze():
 checks();assert not (D/'source_binding.json').exists(),'Frozen evidence is immutable; make successor'
 parent,mapped=expected()
 binding={'schema':'ink-river-ownership-fixture-fix01','status':'SOURCE_ONLY_NOT_RUN','parent_binding_sha256':PARENT_SHA,'runtime_map':mapped,'source_aliases':parent['source_aliases'],'required_groups':GROUPS,'fixture_fix_only':True,'runtime_sim_unchanged':True,'expected_checks':150,'ordinary_admission':False,'production_changes':[],'native_input':'NOT_RUN','art_audio_accepted':False,'real_multiplayer':False}
 (D/'source_binding.json').write_text(encode(binding))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--freeze',action='store_true');a=p.parse_args()
 if a.freeze:freeze()
 print(encode(verify()),end='')
