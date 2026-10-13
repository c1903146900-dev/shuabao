#!/usr/bin/env python3
"""Exact two-entry successor plan. Does not change R or S or run software."""
from pathlib import Path
import argparse,ast,hashlib,importlib.util,json,re
D=Path(__file__).resolve().parent;R=D.parents[2]
P=R/'tests/ink_river_hexes_20261006/ordinary01/fix01'
ORDINARY=R/'tests/ink_river_hexes_20261006/ordinary01'
R2=R/'tests/ink_r2_ordinary_20261006/candidate01'
PARENT_SHA='83cd99cb7972b13ac88fd10a8eb028369e7e6d2c6e0786eb13e49f5860f5eefe'
GROUPS=['exact_entry_whitelist_and_same_sim','one_frontdoor_suspend_resume_close']
ENTRY_BEFORE={'res://scripts/integration/yanguizhou_first_floor.gd':'55b2863eb27215aa8fd113fdec296b88fa450e297312280fb19a506cd788bc29','res://scripts/ui/hero_chooser.gd':'d281f2f909c40e39a432557c1df146717e703426f09a867255dc064e34dc38ad'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def encode(x):return json.dumps(x,ensure_ascii=False,indent=2)+'\n'
def relative(key):
 p=Path(key.removeprefix('res://'));assert not p.is_absolute() and '..' not in p.parts and '.godot' not in p.parts
 return p
def plans():return json.loads((D/'planned_entries.json').read_text())['changes']
def checks():
 assert sha(P/'source_binding.json')==PARENT_SHA
 plan=plans();assert {c['target']:c['before'] for c in plan}==ENTRY_BEFORE and len(plan)==2
 states=[]
 for change in plan:
  target=R/relative(change['target']);source=R/change['planned_source']
  assert sha(source)==change['after'] and change['changed_lines']==1
  current=sha(target);assert current in [change['before'],change['after']]
  states.append('before' if current==change['before'] else 'after')
 assert len(set(states))==1,'default source entries are only partly changed'
 adapter=(D/'planned_adapter.gd').read_text();old_adapter=(R2/'production_adapter.gd').read_text()
 assert adapter.splitlines()[1:]==old_adapter.splitlines()[1:]
 assert adapter.splitlines()[0]=='extends "res://tests/ink_river_hexes_20261006/frontdoor01/host.gd"'
 chooser=(D/'planned_chooser.gd').read_text().replace('res://tests/ink_river_hexes_20261006/ordinary01/runtime_text.gd','res://tests/ink_r2_ordinary_20261006/candidate01/runtime_text.gd')
 assert chooser==(R2/'production_chooser.gd').read_text(),'other hero branch/body changed'
 host=(D/'host.gd').read_text().replace('extends "res://tests/ink_r2_ordinary_20261006/candidate01/host.gd"','extends "res://tests/ink_r2_ordinary_20261006/candidate01/production_adapter.gd"')
 for name in ['floor_session.gd','navigation_install.gd','live_binding.gd']:
  host=host.replace('res://tests/ink_river_hexes_20261006/frontdoor01/'+name,'res://tests/ink_river_hexes_20261006/ordinary01/'+name)
 assert host==(ORDINARY/'host.gd').read_text(),'ordinary Host body changed'
 for name in ['floor_session.gd','bridge.gd','navigation_install.gd']:
  new=(D/name).read_text().replace('res://tests/ink_river_hexes_20261006/frontdoor01/live_binding.gd','res://tests/ink_river_hexes_20261006/ordinary01/live_binding.gd')
  if name=='floor_session.gd':new=new.replace('res://tests/ink_river_hexes_20261006/frontdoor01/bridge.gd','res://tests/ink_river_hexes_20261006/ordinary01/bridge.gd')
  assert new==(ORDINARY/name).read_text(),('consumer body changed',name)
 assert not (D/'sim.gd').exists()
 admission=(D/'live_binding.gd').read_text()
 for required in ['changes.size()!=2','path not in ENTRY_PATHS','change.get("before","")!=expected','mapped.get(path,"")!=expected','FileAccess.get_sha256(path)!=str(mapped[path])']:
  assert required in admission,('missing explicit negative whitelist check',required)
 assert 'ordinary_entry_ready' not in (R/'scripts/ui/hero_chooser.gd').read_text()
 assert 'ordinary_entry_ready' not in (D/'bridge.gd').read_text() and 'ordinary_entry_ready' not in (D/'floor_session.gd').read_text()
 for p in D.glob('*.py'):ast.parse(p.read_text())
 spec=importlib.util.spec_from_file_location('bounded_static_gd_preflight',R/'tests/ink_p2_ordinary_20261006/ordinary01/fix01/verify_source.py')
 m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 scan={p.name:m.static_issues(p) for p in D.glob('*.gd')};assert not any(scan.values()),scan
 return states[0],scan
def expected():
 parent=json.loads((P/'source_binding.json').read_text());mapped=parent['runtime_map'].copy();aliases=parent['source_aliases'].copy();changes={}
 for change in plans():
  target=change['target'];assert mapped[target]==change['before']
  mapped[target]=change['after'];aliases[str(relative(target))]=change['planned_source']
  changes[target]={'before':change['before'],'after':change['after'],'scope':'one_exact_frontdoor_entry_line_only'}
 mapped['res://'+str((P/'source_binding.json').relative_to(R))]=PARENT_SHA
 for p in D.iterdir():
  if p.is_file() and (p.suffix in ['.gd','.py','.md','.patch'] or p.name=='planned_entries.json'):
   key='res://'+str(p.relative_to(R));assert key not in mapped;mapped[key]=sha(p)
 return parent,dict(sorted(mapped.items())),aliases,changes
def verify():
 state,scan=checks();parent,mapped,aliases,changes=expected();b=json.loads((D/'source_binding.json').read_text())
 assert b['runtime_map']==mapped and b['source_aliases']==aliases and b['ancestor_pin_replacements']==changes and b['required_groups']==GROUPS
 for key,digest in mapped.items():assert sha(R/relative(aliases.get(str(relative(key)),str(relative(key)))))==digest,key
 return {'schema':'ink-river-frontdoor-source-check-1','passed':True,'source_binding_sha256':sha(D/'source_binding.json'),'parent_binding_sha256':PARENT_SHA,'closure_files':len(mapped),'static_gd':scan,'default_R_entry_state':state,'planned_entry_changes':changes,'unchanged_ordinary_sim':True,'ordinary_Host_body_preserved':True,'single_frontdoor_layer':True,'other_hero_bodies_byte_exact':True,'Godot_parse':'NOT_RUN','lifecycle_runtime':'NOT_RUN','default_click_native':False,'gameplay_matrix_rerun':False}
def freeze():
 checks();assert not (D/'source_binding.json').exists(),'Frozen sources are immutable'
 parent,mapped,aliases,changes=expected()
 original=json.loads((ORDINARY/'source_binding.json').read_text())
 b={'schema':'ink-river-frontdoor01','status':'SOURCE_ONLY_PLAN_NOT_RUN','parent_binding_sha256':PARENT_SHA,'runtime_map':mapped,'source_aliases':aliases,'ancestor_pin_replacements':changes,'runtime_candidates':original['runtime_candidates'],'supported_hex_hooks':original['supported_hex_hooks'],'required_groups':GROUPS,'production_R_applied':False,'stage_aliases_applied':False,'default_click_native':False,'gameplay_matrix_rerun':False}
 (D/'source_binding.json').write_text(encode(b))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--freeze',action='store_true');p.add_argument('--draft-check',action='store_true');a=p.parse_args()
 if a.draft_check:print(encode({'source_static':checks(),'Godot_parse':'NOT_RUN'}),end='')
 else:
  if a.freeze:freeze()
  print(encode(verify()),end='')
