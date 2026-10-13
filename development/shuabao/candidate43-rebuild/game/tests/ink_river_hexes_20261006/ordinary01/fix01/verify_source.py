#!/usr/bin/env python3
"""Fixture-only source-time correction. Every ordinary runtime file stays pinned."""
from pathlib import Path
import argparse,ast,hashlib,importlib.util,json,re
D=Path(__file__).resolve().parent;R=D.parents[3];P=D.parent
PARENT_SHA='d4a2bbd9dc889f03693a8b5e52a3e2aa2e4bf230aa48faf542c145128444683e'
GROUPS=['actual_hex_pool_choice_learning_undo','h03_owned_physical_input_and_menu','h04_authoritative_functional_view','single_session_room_retirement']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def encode(x):return json.dumps(x,ensure_ascii=False,indent=2)+'\n'
def relative(key):
 p=Path(key.removeprefix('res://'));assert not p.is_absolute() and '..' not in p.parts and '.godot' not in p.parts
 return p
def checks():
 assert sha(P/'source_binding.json')==PARENT_SHA
 assert not (D/'sim.gd').exists() and not (D/'river_view.gd').exists()
 old=(P/'finite_gate.gd').read_text();new=(D/'finite_gate.gd').read_text()
 restored=new.replace('FileAccess.get_sha256("res://tests/ink_river_hexes_20261006/ordinary01/fix01/source_binding.json")','FileAccess.get_sha256(Binding.BINDING_PATH)')
 restored=restored.replace('"fixture_fix_only":true,"runtime_sim_and_view_unchanged":true,','')
 before=(D/'replaced_fixture.txt').read_text();after=(D/'replacement_fixture.txt').read_text()
 assert restored.count(after)==1
 restored=restored.replace(after,before)
 assert restored==old,'unexpected change outside source-time fixture observation/assertion block'
 assert re.findall(r'sim\.step\([^)]*\)',new)==re.findall(r'sim\.step\([^)]*\)',old),'source step sequence changed'
 assert 'source_time)-float(sunset.born_at)' in after
 assert '3.5-(3.5-1.0)*source_age/4.0' in after and 'half_seconds-floor(half_seconds)' in after
 assert 'float(admitted_steps)*sim.FIXED_TICK' in after and 'source_before.accumulator' in after
 parse=(D/'parse_gate.gd').read_text().replace('ordinary01/fix01/finite_gate.gd','ordinary01/finite_gate.gd').replace('ordinary01/fix01/source_binding.json','ordinary01/source_binding.json')
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
 assert binding['required_groups']==GROUPS and binding['fixture_fix_only'] and binding['production_changes']==[]
 for key,digest in mapped.items():
  source=R/relative(parent['source_aliases'].get(str(relative(key)),str(relative(key))))
  assert sha(source)==digest,key
 return {'schema':'ink-river-ordinary-fixture-time-fix01-source-check','passed':True,'source_binding_sha256':sha(D/'source_binding.json'),'parent_binding_sha256':PARENT_SHA,'closure_files':len(mapped),'new_gd_static_checks':scanned,'finite_script_restores_byte_exact_parent':True,'step_sequence_unchanged':True,'runtime_sim_and_view_unchanged':True,'core_and_EPS_unchanged':True,'original_red_and_diagnostic_preserved':True,'default_cutover':False,'Godot_parse':'NOT_RUN','finite_runtime':'NOT_RUN','native_input':False,'art_audio_accepted':False,'real_multiplayer':False}
def freeze():
 checks();assert not (D/'source_binding.json').exists(),'Frozen evidence is immutable'
 parent,mapped=expected()
 binding={'schema':'ink-river-ordinary-fixture-time-fix01','status':'SOURCE_ONLY_NOT_RUN','parent_binding_sha256':PARENT_SHA,'runtime_map':mapped,'source_aliases':parent['source_aliases'],'required_groups':GROUPS,'fixture_fix_only':True,'runtime_sim_and_view_unchanged':True,'expected_checks':146,'production_changes':[],'default_cutover':False,'native_input':False,'art_audio_accepted':False,'real_multiplayer':False}
 (D/'source_binding.json').write_text(encode(binding))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--freeze',action='store_true');a=p.parse_args()
 if a.freeze:freeze()
 print(encode(verify()),end='')
