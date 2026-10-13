#!/usr/bin/env python3
"""Bounded source checks/freeze. Does not import or start Godot."""
from pathlib import Path
import argparse,ast,hashlib,importlib.util,json,re
D=Path(__file__).resolve().parent
R=D.parents[2]
P=R/'tests/ink_r2_ordinary_20261006/candidate01'
PARENT_SHA='85d026d3ed60f80332c727cef089d7156fe734285e5ecd99e1b64a669062eaa5'
DONOR=R/'tests/ink_e3_ordinary_20261006/ordinary01/q2_jump_seams.gd'
GROUPS=['h03_physical_scope','h04_source_ticks','h04_discontinuous_atomic_samples','composition_retirement']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def encode(x):return json.dumps(x,ensure_ascii=False,indent=2)+'\n'
def functions(text):
 out={}
 for m in re.finditer(r'^func (\w+)\(',text,re.M):
  end=text.find('\nfunc ',m.end());out[m.group(1)]=text[m.start():end if end>=0 else len(text)].strip()
 return out
def relative(key):
 p=Path(key.removeprefix('res://'))
 assert not p.is_absolute() and '..' not in p.parts and '.godot' not in p.parts
 return p
def checks():
 assert sha(P/'source_binding.json')==PARENT_SHA
 sim=(D/'sim.gd').read_text();router=(D/'input_adapter.gd').read_text()
 assert sim.splitlines()[0]=='extends "res://tests/ink_r2_ordinary_20261006/candidate01/sim.gd"'
 assert router.splitlines()[0]=='extends "res://tests/ink_r2_ordinary_20261006/candidate01/input_adapter.gd"'
 donor=functions(DONOR.read_text());active=functions(sim)
 old=donor['_q2_collect_contacts'];new=active['_q2_collect_contacts']
 assert old[:old.index('  if bool(state.h04_at_completion):')]==new[:new.index('  if bool(state.h04_at_completion):')]
 assert old[old.index(' contacts.sort_custom'):]==new[new.index(' contacts.sort_custom'):]
 old=donor['_qe_record_jumps'];new=active['_qe_record_jumps']
 prefix=' for river in ink_rivers.duplicate():'
 assert old[:old.index(prefix)]==new[:new.index(' # H04 tickets are sampled lazily')]
 assert old[old.index(' var contacts: Array = []'):]==new[new.index(' var contacts: Array = []'):]
 assert not {'step','_fixed_step','_p1_packet_allowed','_p2_packet_allowed','_p1_bind_q2_river','_hero_cast_skill','_settle_motion_interval'}&set(active)
 assert 'H04_discontinuity_sampling_unresolved' not in sim
 assert 'source.request_q2("corner"' in router and 'event.ctrl_pressed' in router
 assert 'ordinary_admission":false' in sim
 for p in D.glob('*.py'):ast.parse(p.read_text())
 spec=importlib.util.spec_from_file_location('bounded_static_gd_preflight',R/'tests/ink_p2_ordinary_20261006/ordinary01/fix01/verify_source.py')
 module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 scanned={p.name:module.static_issues(p) for p in D.glob('*.gd')}
 assert not any(scanned.values()),scanned
 return scanned
def expected():
 parent=json.loads((P/'source_binding.json').read_text())
 mapped=parent['runtime_map'].copy()
 mapped['res://'+str((P/'source_binding.json').relative_to(R))]=PARENT_SHA
 for p in D.iterdir():
  if p.is_file() and p.suffix in ['.gd','.py','.md']:
   key='res://'+str(p.relative_to(R));assert key not in mapped;mapped[key]=sha(p)
 return parent,dict(sorted(mapped.items()))
def verify():
 scanned=checks();parent,mapped=expected()
 binding=json.loads((D/'source_binding.json').read_text())
 assert binding['runtime_map']==mapped
 assert binding['source_aliases']==parent['source_aliases']
 assert binding['required_groups']==GROUPS and not binding['ordinary_admission']
 for key,digest in mapped.items():
  source=R/relative(parent['source_aliases'].get(str(relative(key)),str(relative(key))))
  assert sha(source)==digest,key
 return {'schema':'ink-river-hex-source-check-1','passed':True,'source_binding_sha256':sha(D/'source_binding.json'),'parent_binding_sha256':PARENT_SHA,'closure_files':len(mapped),'new_gd_static_checks':scanned,'non_H04_river_collection_preserved':True,'E3_arrival_body_preserved':True,'ordinary_admission':False,'P1_P2_ownership_guards_preserved':True,'Godot_parse':'NOT_RUN','finite_runtime':'NOT_RUN','native_input':'NOT_RUN','art_audio_accepted':False,'real_multiplayer':False}
def freeze():
 checks();assert not (D/'source_binding.json').exists(),'Frozen evidence is immutable; make successor'
 parent,mapped=expected()
 binding={'schema':'ink-river-hex-technical-candidate01','status':'SOURCE_ONLY_NOT_RUN','parent_binding_sha256':PARENT_SHA,'runtime_map':mapped,'source_aliases':parent['source_aliases'],'required_groups':GROUPS,'ordinary_admission':False,'P1_P2_H04_ownership':'HOLD','production_changes':[],'native_input':'NOT_RUN','art_audio_accepted':False,'real_multiplayer':False}
 (D/'source_binding.json').write_text(encode(binding))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--freeze',action='store_true');p.add_argument('--draft-check',action='store_true');a=p.parse_args()
 if a.draft_check:print(encode({'draft_static':checks(),'Godot_parse':'NOT_RUN'}),end='')
 else:
  if a.freeze:freeze()
  print(encode(verify()),end='')
