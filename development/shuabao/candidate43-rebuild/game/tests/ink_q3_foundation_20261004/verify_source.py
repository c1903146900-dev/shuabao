#!/usr/bin/env python3
"""Source integrity and explicit regression deltas only. Never invokes an engine."""
from pathlib import Path
from zipfile import ZipFile
import argparse, copy, difflib, hashlib, importlib.util, json, re, sys, xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent; R=H.parents[1]
UP='tests/ink_intermediate_stats_20261004/source_binding.json'
EXPECTED='a79fc889f1cb028099c9baf2882b44f84a3345179b6415ef6113304a8901720e'
PREFIX='res://tests/ink_q3_foundation_20261004/'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text())
dump=lambda v:json.dumps(v,ensure_ascii=False,indent=2)+'\n'
checks=[]
def check(ok,label):
 checks.append(label)
 assert ok,label

def audit():
 contract=load(H/'source_contract.json');up=load(R/UP)
 check(sha(R/UP)==EXPECTED,'exact a79fc upstream binding')
 for rel,v in contract['frozen_inputs'].items():check(sha(R/rel)==v['sha256'] and (R/rel).stat().st_size==v['bytes'],'frozen '+rel)
 for target,entry in up['runtime_map'].items():check(sha(R/entry['source'])==entry['sha256'],'upstream runtime source '+target)
 catalog=load(R/'data/final_design/catalog.json')
 sys.dont_write_bytecode=True
 spec=importlib.util.spec_from_file_location('original_cells',R/'docs/ink_source_preparation/verify_sources.py');helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
 workbook=helper.workbook_cells(R/'data/final_design/sources/heroes_balance_values_v03(1).xlsx')
 w={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
 doc=ET.fromstring(ZipFile(R/'data/final_design/sources/heroes_mechanics_no_values_v03(1).docx').read('word/document.xml'))
 paragraphs=doc.findall('.//w:body//w:p',w)
 total=0
 for key,group in [('Q3','skills'),('H05','hexes'),('H06','hexes')]:
  record=catalog['heroes']['yanguizhou'][group][key];evidence=contract['records'][key]
  check(record==evidence['catalog'],'exact original catalog '+key)
  text=''.join(t.text or '' for t in paragraphs[record['source']['paragraph_all_body_descendants']-1].findall('.//w:t',w))
  check(text==evidence['original_full_paragraph'],'exact DOCX '+key)
  for token,p in record['parameters'].items():
   s=p['source'];actual=[workbook[s['sheet']][c] for c in s['cells']]
   check(actual==evidence['numeric_cells'][token]['actual'] and [c['value'] for c in actual]==p['values'],'exact cells '+token)
   total+=len(actual)
 check(total==74,'74 original numeric cells')
 conventions=load(H/'implementation_conventions.json')
 check(conventions['pending']==[] and not conventions['source_literal_claim'] and not conventions['production_runtime_enabled'],'technical decisions explicit without source/production claims')
 check(len(load(R/'tests/ink_q2_source_contract_20261004/pending_rules.json')['pending'])==3,'Q2 three pending rules preserved')
 original=(R/'tests/ink_intermediate_stats_20261004/ink_intermediate_bridge.gd').read_text()
 desired=original.replace('res://tests/ink_intermediate_stats_20261004/ink_intermediate_sim.gd',PREFIX+'ink_q3_sim.gd')
 check((H/'ink_q3_bridge.gd').read_text()==desired,'bridge exact one-path startup substitution')
 patches=list(difflib.unified_diff(original.splitlines(True),desired.splitlines(True),fromfile='tests/ink_intermediate_stats_20261004/ink_intermediate_bridge.gd',tofile='tests/ink_q3_foundation_20261004/ink_q3_bridge.gd'))
 for row in load(H/'regression_spec.json'):
  old=(R/row['source']).read_text();text=old
  text=text.replace('res://tests/ink_q1_h02_20261004/ink_h02_sim.gd',PREFIX+'ink_q3_sim.gd').replace('res://tests/ink_intermediate_stats_20261004/ink_intermediate_sim.gd',PREFIX+'ink_q3_sim.gd').replace('res://tests/ink_intermediate_stats_20261004/ink_intermediate_bridge.gd',PREFIX+'ink_q3_bridge.gd')
  for folder in ['ink_q1_h02_20261004','ink_intermediate_stats_20261004']:text=text.replace('res://tests/'+folder+'/'+row['source_output'],PREFIX+row['output'])
  text=text.replace('res://tests/ink_intermediate_stats_20261004/source_binding.json',PREFIX+'source_binding.json')
  if '"source_binding_id"' not in text:text=text.replace('var report:Dictionary={','var report:Dictionary={"source_binding_id":FileAccess.get_sha256("'+PREFIX+'source_binding.json"),',1)
  check((H/row['gate']).read_text()==text,'no assertion weakened '+row['gate'])
  patches.extend(difflib.unified_diff(old.splitlines(True),text.splitlines(True),fromfile=row['source'],tofile=str(H.relative_to(R)/row['gate'])))
 check((H/'regression_rebindings.patch').read_text()==''.join(patches),'all exact rebindings recorded')
 sim=(H/'ink_q3_sim.gd').read_text();director=(H/'ink_q3_enemy_director.gd').read_text();gate=(H/'q3_gate.gd').read_text()
 check(sim.startswith('extends "res://tests/ink_intermediate_stats_20261004/ink_intermediate_sim.gd"'),'versioned Sim above exact chain')
 for method in ['damage_enemy','damage_hero','heal','new_cast','start_skill_cooldown','step','configure_test_loadout']:
  check(not re.search(r'^func '+method+r'\(',sim,re.M),'existing shared authority not rewritten '+method)
 check('"cast_id":ink_mountain.cast_id' in sim and '"bypass_cooldown":true' in sim,'recast uses original root and CD exception')
 check('"collapse_width":v("Q3-8",rank)' in sim and '"length":v("Q3-4",rank)*(1.0+T.hex_parameter("H05-1")' in sim,'H05 only mountain dimension')
 check('metadata.get("source","")=="yanguizhou_h06"' in sim and 'enemy.stun_left=' not in sim,'no generic Boss stun exemption or base push stun')
 check('projectile.get("type","bolt")=="lob"' in director and 'super.step_projectiles(sim,dt)' in director,'all actual families then original movement/landing')
 check('step_projectiles' not in sim and 'super._fixed_step(real_dt)' in sim,'one inherited world step')
 check('sims[0].event_log==sims[1].event_log' in gate,'before after exact controls/event comparison')
 check('charge_target.dead=' not in gate and 'state.gold=' not in sim,'no forced kill or new funding authority')
 mapping=copy.deepcopy(up['runtime_map'])
 for name in ['source_binding.json','live_binding.gd','capabilities.json']:
  rel='tests/ink_intermediate_stats_20261004/'+name;mapping[rel]={'source':rel,'sha256':sha(R/rel)}
 excluded={'source_binding.json','source_result.json','authoring_manifest.json','authoring_manifest.sha256','.gdignore'}
 authored={}
 for p in sorted(H.iterdir()):
  if not p.is_file() or p.name in excluded or p.name.endswith('_result.json'):continue
  rel=p.relative_to(R).as_posix();authored[rel]={'sha256':sha(p),'bytes':p.stat().st_size};mapping[rel]={'source':rel,'sha256':sha(p)}
 outputs={'source_binding.json','q3_result.json'}|{r['output'] for r in load(H/'regression_spec.json')}
 for p in H.glob('*.gd'):
  funcs=re.findall(r'^func (\w+)\(',p.read_text(),re.M)
  check(len(funcs)==len(set(funcs)),'no duplicate function names '+p.name)
  for ref in re.findall(r'res://([^"\n]+)',p.read_text()):
   if Path(ref).name in outputs and ref.startswith(str(H.relative_to(R))+'/'):continue
   check(ref in mapping,'bound direct resource '+ref)
 manifest={'schema':1,'author_engine_invocations':0,'source_only':True,'scope':['Q3','H05','H06'],'upstream_binding':EXPECTED,'authored_files':authored,'frozen_input_count':len(contract['frozen_inputs']),'production_host_changes':False,'capability_promotions':False}
 binding={'schema':1,'version':'ink-q3-foundation-1','scope':'isolated source mechanic candidate; Q3 H05 H06 plus exact retained a79fc chain','upstream_binding_sha256':EXPECTED,'files':{v['source']:v['sha256'] for v in mapping.values()},'runtime_map':dict(sorted(mapping.items())),'authoring_manifest_sha256':hashlib.sha256(dump(manifest).encode()).hexdigest(),'author_engine_invocations':0,'ordinary_entry_ready':False,'production_ready':False}
 return manifest,binding

def main():
 p=argparse.ArgumentParser();p.add_argument('--write',action='store_true');args=p.parse_args()
 manifest,binding=audit()
 if args.write:
  for name in ['authoring_manifest.json','source_binding.json','source_result.json']:check(not (H/name).exists(),'never overwrite frozen '+name)
  (H/'authoring_manifest.json').write_text(dump(manifest));(H/'source_binding.json').write_text(dump(binding))
  (H/'authoring_manifest.sha256').write_text(sha(H/'authoring_manifest.json')+'  authoring_manifest.json\n')
 else:
  check(load(H/'authoring_manifest.json')==manifest,'authored manifest unchanged')
  check(load(H/'source_binding.json')==binding,'binding unchanged')
 result={'passed':True,'mode':'source_only_not_gdscript_parse_or_runtime','source_records':3,'parameters':14,'numeric_cells':74,'frozen_inputs':manifest['frozen_input_count'],'runtime_files':len(binding['runtime_map']),'source_binding_sha256':sha(H/'source_binding.json'),'upstream_binding_sha256':EXPECTED,'engine':'NOT_RUN_BY_AUTHOR','normal_input':'NOT_RUN','art':'NOT_CREATED','production_ready':False,'ordinary_entry_ready':False}
 if args.write:(H/'source_result.json').write_text(dump(result))
 else:check(load(H/'source_result.json')==result,'stored source-only result reproducible')
 print(dump({**result,'source_checks':len(checks)}),end='')
if __name__=='__main__':main()
