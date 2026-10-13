#!/usr/bin/env python3
"""Additive Q2/H03/H04 root ownership source checks. Never starts Godot."""
from pathlib import Path
import argparse,ast,hashlib,importlib.util,json,re
D=Path(__file__).resolve().parent
R=D.parents[2]
P=R/'tests/ink_river_hexes_20261006/candidate01'
PARENT_SHA='8976d2520ee4486df0af146d28e4944039b35318da8dfe09272b9bce51b13900'
GROUPS=['p1_complete_river_and_sunset','p1_terminal_pause_and_victory','p2_new_use_sunset_entitlement','original_packet_scope_and_retirement']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def encode(x):return json.dumps(x,ensure_ascii=False,indent=2)+'\n'
def functions(text):
 out={}
 for m in re.finditer(r'^func (\w+)\(',text,re.M):
  end=text.find('\nfunc ',m.end());out[m.group(1)]=text[m.start():end if end>=0 else len(text)].strip()
 return out
def relative(key):
 p=Path(key.removeprefix('res://'));assert not p.is_absolute() and '..' not in p.parts and '.godot' not in p.parts
 return p
def checks():
 assert sha(P/'source_binding.json')==PARENT_SHA
 sim=(D/'sim.gd').read_text();active=functions(sim)
 assert sim.splitlines()[0]=='extends "res://tests/ink_river_hexes_20261006/candidate01/sim.gd"'
 donor=functions((R/'tests/ink_p1_ordinary_20261006/candidate01/sim.gd').read_text())
 old=donor['_p1_bind_q2_river'];new=active['_p1_bind_q2_river']
 assert old[:old.index(' # Existing ordinary admission')]==new[:new.index(' # H03 changes')]
 assert old.splitlines()[-1]==new.splitlines()[-1]==' _p1_q2_rivers[id] = matched'
 assert not {'step','_fixed_step','damage_enemy','_q2_collect_contacts','_q2_hit_impact','_qe_record_jumps','_settle_motion_interval','_p1_flush','_p1_q2_terminal_milestone','_p2_complete','_p2_drain_splashes'}&set(active)
 assert 'p2.claim_positive(int(frame.cast_id),"q2"' in sim
 assert '"original_packet_source"] = "hex_yanguizhou_h04"' in sim
 assert 'frame.seen = true' in active['emit_event'] and 'super.emit_event(kind,data)' in active['emit_event']
 assert 'int(p1.roots[id].depth)>0' in active['_q2_finish']
 assert '_river_hex_original_packet(source,id,metadata)' in active['_p1_packet_allowed'] and '_river_hex_original_packet(source,id,metadata)' in active['_p2_packet_allowed']
 # The old exact expiry terminal is still correct for every formal source rank.
 hero=json.loads((R/'data/final_design/catalog.json').read_text())['heroes']['yanguizhou']
 durations=hero['parameters']['Q2-5']['values']
 h04=hero['hexes']['H04']['parameters']['H04-1']['values']
 assert durations==[4,4.16,4.4,4.8,5.34,6] and h04==[4]
 assert all(value>=h04[0] for value in durations)
 assert 'maxf(float(state.expires_at),float(state.sunset_expires_at)' in active['_q2_finish']
 for p in D.glob('*.py'):ast.parse(p.read_text())
 spec=importlib.util.spec_from_file_location('bounded_static_gd_preflight',R/'tests/ink_p2_ordinary_20261006/ordinary01/fix01/verify_source.py')
 module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 scanned={p.name:module.static_issues(p) for p in D.glob('*.gd')};assert not any(scanned.values()),scanned
 return scanned
def expected():
 parent=json.loads((P/'source_binding.json').read_text());mapped=parent['runtime_map'].copy()
 mapped['res://'+str((P/'source_binding.json').relative_to(R))]=PARENT_SHA
 for p in D.iterdir():
  if p.is_file() and p.suffix in ['.gd','.py','.md']:
   key='res://'+str(p.relative_to(R));assert key not in mapped;mapped[key]=sha(p)
 return parent,dict(sorted(mapped.items()))
def verify():
 scanned=checks();parent,mapped=expected();binding=json.loads((D/'source_binding.json').read_text())
 assert binding['runtime_map']==mapped and binding['source_aliases']==parent['source_aliases']
 assert binding['required_groups']==GROUPS and not binding['ordinary_admission']
 for key,digest in mapped.items():
  source=R/relative(parent['source_aliases'].get(str(relative(key)),str(relative(key))))
  assert sha(source)==digest,key
 return {'schema':'ink-river-ownership-source-check-1','passed':True,'source_binding_sha256':sha(D/'source_binding.json'),'parent_binding_sha256':PARENT_SHA,'closure_files':len(mapped),'new_gd_static_checks':scanned,'technical_sampler_and_input_unchanged':True,'current_E1_P2_P1_R2_ancestors_unchanged':True,'original_source_and_hex_provenance_preserved':True,'ordinary_admission':False,'Godot_parse':'NOT_RUN','finite_runtime':'NOT_RUN','native_input':'NOT_RUN','art_audio_accepted':False,'real_multiplayer':False}
def freeze():
 checks();assert not (D/'source_binding.json').exists(),'Frozen evidence is immutable; make successor'
 parent,mapped=expected()
 binding={'schema':'ink-river-hex-ownership01','status':'SOURCE_ONLY_NOT_RUN','parent_binding_sha256':PARENT_SHA,'runtime_map':mapped,'source_aliases':parent['source_aliases'],'required_groups':GROUPS,'ordinary_admission':False,'source_scope':'same_Q2_root_P1_and_existing_P2_use_epoch_only','production_changes':[],'native_input':'NOT_RUN','art_audio_accepted':False,'real_multiplayer':False}
 (D/'source_binding.json').write_text(encode(binding))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--freeze',action='store_true');p.add_argument('--draft-check',action='store_true');a=p.parse_args()
 if a.draft_check:print(encode({'draft_static':checks(),'Godot_parse':'NOT_RUN'}),end='')
 else:
  if a.freeze:freeze()
  print(encode(verify()),end='')
