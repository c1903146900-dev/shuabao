#!/usr/bin/env python3
"""Source and integer allocation checks only. Never runs/imports Godot or edits old files."""
from pathlib import Path
import argparse,hashlib,json,re,itertools,zipfile,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent;R=H.parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
checks=[]
def check(ok,label):
 checks.append({'check':label,'passed':bool(ok)})
 assert ok,label
ids=['G01','G05','G06','G15','G24','G30'];personal=['yanguizhou_h01','yanguizhou_h02']
hooks=['hex.final_design.'+x+'.v1' for x in personal+['common_'+x.lower() for x in ids]]
catalog=json.loads((R/'data/final_design/catalog.json').read_text())
rules=json.loads((R/'data/final_design/runtime_rules.json').read_text())
check({'common_g24','common_g30'} <= {h for a in rules['amendments'] if a['status']=='user_confirmed' for h in a.get('rules',{}).get('enabled_common_hexes',[])},'G24/G30 explicitly user-confirmed formal proposals')
# Follow the existing tested runtime alias map; never replace original bytes.
old=R/'tests/ink_shop_runtime_stats_20261004/hp_undo_fix01/source_binding.json'
old_binding=json.loads(old.read_text());mapping=old_binding['runtime_map'].copy()
for target,e in mapping.items():check(sha(R/e['source'])==e['sha256'],'preserved HP dependency '+target)
h02=R/'tests/ink_q1_h02_20261004/source_binding.json'
for target,e in json.loads(h02.read_text())['runtime_map'].items():
 check(sha(R/e['source'])==e['sha256'],'preserved H02 dependency '+target)
 mapping[target]=e
source_map=[]
with zipfile.ZipFile(R/'data/final_design/sources/heroes_mechanics_no_values_v03(1).docx') as z:
 doc=ET.fromstring(z.read('word/document.xml'));ns={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
 paragraphs=[''.join(p.itertext()) for p in doc.findall('.//w:body//w:p',ns)]
with zipfile.ZipFile(R/'data/final_design/sources/heroes_balance_values_v03(1).xlsx') as z:
 ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
 workbook=ET.fromstring(z.read('xl/workbook.xml'))
 rels=ET.fromstring(z.read('xl/_rels/workbook.xml.rels'));links={x.attrib['Id']:x.attrib['Target'] for x in rels}
 sheet=next(x for x in workbook.findall('.//s:sheet',ns) if x.attrib['name']=='通用海克斯')
 target=links[sheet.attrib['{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id']]
 path=target.lstrip('/') if target.startswith('/') else 'xl/'+target
 cells={x.attrib['r']:x.find('s:v',ns).text for x in ET.fromstring(z.read(path)).findall('.//s:c',ns) if x.find('s:v',ns) is not None}
 for id in ids:
  d=catalog['common_hexes'][id];p=d['source']['paragraph_all_body_descendants']
  check(d['template'] in paragraphs[p-1],'DOCX '+id+' mechanism paragraph')
  for token,v in d['parameters'].items():check(float(cells[v['source']['cells'][0]])==v['values'][0],'XLSX '+token+' exact source')
  source_map.append({'id':d['id'],'description':d['description'],'mechanics':d['source'],'parameters':d['parameters']})
# Finite integer mirror of the actual GDScript allocator, all24 orders. This is not engine evidence.
def draw(state,hero_only,excluded,reserve,P,C,learned):
 pool=[];total=0;possible=[x for x in P+C if x not in set(excluded)|state['selected']]
 if hero_only:possible=[x for x in possible if x in P]
 if not hero_only and reserve:
  remain=[x for x in possible if x in P]
  if len(remain)==1:possible.remove(remain[0])
 for x in possible:
  weight=max(1,100//(1+state['seen'].get(x,0)))
  if x in P and not learned:weight=max(1,int(weight*.5))
  total+=weight;pool.append((x,total))
 if not pool:return ''
 state['rng']=state['rng']*48271%2147483647
 x=next(x for x,weight in pool if state['rng']%total<weight)
 state['seen'][x]=state['seen'].get(x,0)+1
 return x
runs=0
for count in [2,16]:
 P=['p'+str(i) for i in range(count)];C=['c'+str(i) for i in range(6)]
 for learned,seed,order in itertools.product([False,True],range(1,129),itertools.permutations(range(4))):
  state={'selected':set(),'seen':{},'rng':seed};slots=['']*4;excluded=[];used=[False]*4;seen=set()
  for slot in [3,0,1,2]:slots[slot]=draw(state,slot==3,slots,True,P,C,learned)
  assert '' not in slots and len(set(slots))==4 and slots[3] in P
  seen.update(slots)
  for slot in order:
   excluded.append(slots[slot]);slots[slot]=draw(state,slot==3,slots+excluded,not used[3],P,C,learned);used[slot]=True
   assert '' not in slots and len(set(slots))==4 and slots[3] in P and not set(slots)&set(excluded)
   seen.update(slots)
  assert len(seen)==8
  runs+=1
check(runs==12288,'12288 integer paths: both pool sizes, learned/dormant,128 seeds,24 orders')
text=(H/'ink_initial_model.gd').read_text()
check('_reserve_personal_refresh=previous' in text,'temporary selector context always restored')
check('state.gold=' not in text and 'state.points=' not in text and 'state.selected_hex=' not in text,'no grants or fabricated selections in new model')
check('personal.size()==1' in text and 'not bool(offer.refresh_used[3])' in text,'reserve last personal until right refresh consumed')
bridge=(H/'ink_initial_bridge.gd').read_text()
check('get_script().resource_path != "res://tests/ink_initial_hex_runtime_20261004/ink_initial_sim.gd"' in bridge,'exact composed Sim script required')
check('bind_health_sim(sim)' in bridge and 'bind_commerce(owner' in bridge,'same HP observer and economic ledger')
check('InitialConsumer.new()' in text and 'InitialConsumer.new()' in bridge,'explicit versioned consumer on both health and bridge paths')
check('"G17"' not in text and '"G18"' not in text,'no placeholder unsupported hooks')
(H/'source_map.json').write_text(json.dumps({'schema':1,'rows':source_map,'sinks':{'G01':'common.before_hit -> runtime.before_damage -> guarded actual Q1 damage','G05':'actual kill -> runtime.enemy_died -> cdr -> effective_cd -> Q1 cooldown','G06':'hero.speed and enemy speed/slow -> before_damage -> actual BASIC/Q1','G15':'capped cdr -> common.project_stats move_speed -> hero.speed -> locomotion','G24':'same ledger inventory count -> common_damage_multiplier and max_hp -> damage/HP observer','G30':'same ledger gold -> defence/max_hp -> incoming mitigation/HP observer'},'scope':'source mapping, finite runtime scripts pending main execution'},ensure_ascii=False,indent=2)+'\n')
outputs={'source_binding.json','capabilities.json','selector_result.json','sink_result.json','hp_result.json','live_binding.gd'}
queue=list(H.glob('*.gd'));seen=set()
while queue:
 f=queue.pop();rel=f.relative_to(R).as_posix()
 if rel in seen or f.name in outputs:continue
 seen.add(rel)
 source=R/mapping.get(rel,{'source':rel})['source'];check(source.is_file(),'dependency exists '+rel)
 mapping[rel]={'source':source.relative_to(R).as_posix(),'sha256':sha(source)}
 if source.suffix not in ['.gd','.json']:continue
 for ref in re.findall(r'res://([^"\n]+)',source.read_text()):
  if Path(ref).name in outputs or '%' in ref:continue
  queue.append(R/ref)
for f in [H/'source_map.json',H/'verify_source.py']:
 rel=f.relative_to(R).as_posix();mapping[rel]={'source':rel,'sha256':sha(f)}
files={e['source']:e['sha256'] for e in mapping.values()}
binding={'schema':1,'scope':'Lv1 eight-source-Hex candidate, main finite runtime pending','upstream_hp_binding':sha(old),'upstream_h02_binding':sha(h02),'files':dict(sorted(files.items())),'runtime_map':dict(sorted(mapping.items())),'author_engine_invocations':0}
(H/'source_binding.json').write_text(json.dumps(binding,ensure_ascii=False,indent=2)+'\n')
manifest={'schema':1,'hero_id':'yanguizhou','version':'ink-initial-hex-runtime-v1','runtime_candidates':['Q1'],'source_implemented_hooks':hooks,'runtime_verified_hooks':[],'source_binding_id':sha(H/'source_binding.json'),'common_pool_full_validation':False,'ink_g18_capture':False,'ordinary_entry_ready':False,'scope':'Lv1 candidate8, source gates only until main serial Godot and native HexUI acceptance','required_finite_results':['selector_result.json','sink_result.json','hp_result.json']}
(H/'capabilities.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
result={'passed':True,'checks':len(checks),'results':checks,'integer_paths':runs,'source_binding_sha256':sha(H/'source_binding.json'),'engine':'NOT_RUN_BY_WORKER','ordinary_entry_ready':False,'runtime_files':len(mapping)}
(H/'source_result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='results'}))
