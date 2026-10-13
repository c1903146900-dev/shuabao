#!/usr/bin/env python3
"""Independent ordinary adapter, additive exact closure, no default cutover."""
from pathlib import Path
import argparse,ast,hashlib,importlib.util,json,re
D=Path(__file__).resolve().parent;R=D.parents[2]
P=R/'tests/ink_river_hexes_20261006/ownership01/fix01'
PARENT_SHA='f77466574d9631b03710f79201a2cd52b6cdbebd28be6fe607870988f4a6d9bc'
BASE=R/'tests/ink_r2_ordinary_20261006/candidate01'
GROUPS=['actual_hex_pool_choice_learning_undo','h03_owned_physical_input_and_menu','h04_authoritative_functional_view','single_session_room_retirement']
NEW='res://tests/ink_river_hexes_20261006/ordinary01/'
OLD='res://tests/ink_r2_ordinary_20261006/candidate01/'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def encode(x):return json.dumps(x,ensure_ascii=False,indent=2)+'\n'
def relative(key):
 p=Path(key.removeprefix('res://'));assert not p.is_absolute() and '..' not in p.parts and '.godot' not in p.parts
 return p
def array(text,name):return json.loads(re.search(r'const '+name+r' = (\[[^\n]+\])',text).group(1))
def checks():
 assert sha(P/'source_binding.json')==PARENT_SHA
 sim=(D/'sim.gd').read_text();host=(D/'host.gd').read_text();view=(D/'river_view.gd').read_text()
 assert sim.splitlines()[0]=='extends "res://tests/ink_river_hexes_20261006/ownership01/sim.gd"'
 assert re.findall(r'^func (\w+)\(',sim,re.M)==['ink_presenter_snapshot']
 assert host.splitlines()[0]=='extends "res://tests/ink_r2_ordinary_20261006/candidate01/production_adapter.gd"'
 assert 'res://tests/ink_river_hexes_20261006/candidate01/input_adapter.gd' in host
 for name in ['bridge.gd','floor_session.gd','navigation_install.gd','e_hud.gd','r_hud.gd']:
  assert (D/name).read_text().replace(NEW,OLD)==(BASE/name).read_text(),('unexpected inherited consumer edit',name)
 old=(BASE/'catalog.gd').read_text();catalog=(D/'catalog.gd').read_text()
 candidates=array(catalog,'FIRST_SLICE_ALLOWED_CANDIDATES');hooks=array(catalog,'FIRST_SLICE_HEX_HOOKS')
 assert candidates==array(old,'FIRST_SLICE_ALLOWED_CANDIDATES') and 'P3' not in candidates
 assert len(hooks)==12 and set(hooks)-set(array(old,'FIRST_SLICE_HEX_HOOKS'))=={'hex.final_design.yanguizhou_h03.v1','hex.final_design.yanguizhou_h04.v1'}
 assert set(array(old,'FIRST_SLICE_HEX_HOOKS'))<=set(hooks)
 assert not re.search(r'^func (_process|_physics_process|step|_fixed_step)\(',view,re.M)
 assert 'entry.radius' in view and 'entry.tick_progress' in view and 'ink.get("h04_sunsets",[])' in view
 assert 'source.hx("yanguizhou_h03")' in (D/'hud_projection.gd').read_text()
 assert not (D/'production_adapter.gd').exists() and not (D/'production_chooser.gd').exists()
 for p in D.glob('*.py'):ast.parse(p.read_text())
 spec=importlib.util.spec_from_file_location('bounded_static_gd_preflight',R/'tests/ink_p2_ordinary_20261006/ordinary01/fix01/verify_source.py')
 m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 scan={p.name:m.static_issues(p) for p in D.glob('*.gd')};assert not any(scan.values()),scan
 return candidates,hooks,scan
def expected():
 parent=json.loads((P/'source_binding.json').read_text());mapped=parent['runtime_map'].copy()
 mapped['res://'+str((P/'source_binding.json').relative_to(R))]=PARENT_SHA
 for p in D.iterdir():
  if p.is_file() and p.suffix in ['.gd','.py','.md']:
   key='res://'+str(p.relative_to(R));assert key not in mapped;mapped[key]=sha(p)
 return parent,dict(sorted(mapped.items()))
def verify():
 candidates,hooks,scan=checks();parent,mapped=expected();b=json.loads((D/'source_binding.json').read_text())
 assert b['runtime_map']==mapped and b['source_aliases']==parent['source_aliases']
 assert b['runtime_candidates']==candidates and b['supported_hex_hooks']==hooks and b['required_groups']==GROUPS and b['production_changes']==[]
 for key,digest in mapped.items():
  source=R/relative(parent['source_aliases'].get(str(relative(key)),str(relative(key))))
  assert sha(source)==digest,key
 for leaf in ['scripts/integration/yanguizhou_first_floor.gd','scripts/ui/hero_chooser.gd']:
  assert sha(R/leaf)==mapped['res://'+leaf],'default production entry changed'
 return {'schema':'ink-river-ordinary-source-check-1','passed':True,'source_binding_sha256':sha(D/'source_binding.json'),'parent_binding_sha256':PARENT_SHA,'closure_files':len(mapped),'static_gd':scan,'new_hex_hooks':['H03','H04'],'copied_consumers_only_rebound':True,'gameplay_methods_unchanged':True,'default_entries_unchanged':True,'one_inherited_Session':True,'Godot_parse':'NOT_RUN','finite_runtime':'NOT_RUN','native_input':False,'art_audio_accepted':False,'real_multiplayer':False}
def freeze():
 candidates,hooks,_=checks();assert not (D/'source_binding.json').exists(),'Frozen sources are immutable'
 parent,mapped=expected()
 b={'schema':'ink-river-ordinary01','status':'SOURCE_ONLY_NOT_RUN','parent_binding_sha256':PARENT_SHA,'runtime_map':mapped,'source_aliases':parent['source_aliases'],'runtime_candidates':candidates,'supported_hex_hooks':hooks,'required_groups':GROUPS,'new_hex_hooks':['H03','H04'],'production_changes':[],'default_cutover':False,'native_input':False,'art_audio_accepted':False,'real_multiplayer':False}
 (D/'source_binding.json').write_text(encode(b))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--freeze',action='store_true');p.add_argument('--draft-check',action='store_true');a=p.parse_args()
 if a.draft_check:print(encode({'source_static':checks(),'Godot_parse':'NOT_RUN'}),end='')
 else:
  if a.freeze:freeze()
  print(encode(verify()),end='')
