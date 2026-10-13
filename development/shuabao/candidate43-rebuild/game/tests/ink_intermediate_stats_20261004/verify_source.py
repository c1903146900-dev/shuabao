#!/usr/bin/env python3
"""Source-only checks and bounded independent arithmetic; no engine invocation."""
from pathlib import Path
import json,hashlib,re,copy
H=Path(__file__).resolve().parent;R=H.parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
checks=[]
def check(ok,label):
 checks.append({'label':label,'passed':bool(ok)})
 assert ok,label
up=R/'tests/ink_initial_hex_runtime_20261004/fix01/source_binding.json'
b=json.loads(up.read_text());mapping=copy.deepcopy(b['runtime_map'])
check(b['runtime_source_binding_id']=='c997eab5df81084d7ca970c76464389e4cf47954ae8271c1b18ae3a8b27cec7a','exact c997 initial runtime ancestry')
for rel,h in b['files'].items():check(sha(R/rel)==h,'unchanged upstream '+rel)
for rel in ['tests/ink_initial_hex_runtime_20261004/fix01/source_binding.json','docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json','tests/equipment_editable_tables_20261004/immutable_baseline.json','tests/equipment_editable_tables_20261004/source_lock.json']:
 mapping[rel]={'source':rel,'sha256':sha(R/rel)}
source=json.loads((R/'docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json').read_text())
num=json.loads((R/'tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json').read_text())
fixture=json.loads((R/'tests/equipment_shop_transactions_20261004/fixtures/source_prices.json').read_text())
rows=json.loads((H/'source_map.json').read_text())['rows'];byid={r['id']:r for r in rows}
expected={f'intermediate:I{x:02}' for x in range(1,19) if x!=12}
check({r['id'] for r in rows if r['tier']=='intermediate' and r['supported']}==expected,'exact17 intermediate allowlist')
check(len([r for r in rows if r['supported']])==28,'exact11 base +17 intermediate')
check(all(not e['mechanism_ids'] and not e['source_effects'] for e in source['equipment'] if e['tier']=='intermediate'),'all18 source intermediates have no new mechanisms')
for row in rows:
 original=next(e for e in source['equipment'] if e['id']==row['id'])
 parts=[c['item_id'] for c in original['components'] for _ in range(c['quantity'])]
 check(parts==row['components']==fixture['items'][row['id']]['components'],'fixed source recipe '+row['id'])
 check(row['price']==num['parameters'][row['id']+'.price']['value'],'formal price '+row['id'])
 check(row['combine_fee']==row['price']-sum(num['parameters'][p+'.price']['value'] for p in parts),'derived fee '+row['id'])
 if row['id'] in expected:check(all(p.startswith('base:') and byid[p]['supported'] for p in parts),'supported component closure '+row['id'])
 for field in row['parameter_mapping']:
  parameter=num['parameters'][field['parameter']]
  check(all(field[k]==parameter[k] for k in ['value','unit','source_value','source_ref']),'formal numeric provenance '+field['parameter'])
 if row['supported']:
  derived={f['runtime_stat']:f['value']*f['scale'] for f in row['parameter_mapping']}
  check(derived==row['expected_stats'],'unit-scaled independent expected stats '+row['id'])
 else:check(row['expected_stats']=={} and row['hold_reason']=='regen_time_unit_unresolved','all-or-nothing regen HOLD '+row['id'])
# Parse literal GDScript JSON map, independently compare source parameter fields.
text=(H/'intermediate_stat_adapter.gd').read_text()
adapter=json.loads(text.split('const INTERMEDIATE_MAPPING=',1)[1].split('\nstatic func build',1)[0])
for id,fields in adapter.items():
 check([x[0] for x in fields]==[p['parameter'].split('.stat.')[1] for p in byid[id]['parameter_mapping']],'actual adapter field names '+id)
 for field,p in zip(fields,byid[id]['parameter_mapping']):check(field[1:]==[p['unit'],p['runtime_stat'],p['scale']],'actual adapter unit/sink/scale '+id+'.'+field[0])
check('BaseAdapter.build(numeric)' in text and 'if not supported:stats.clear()' in text,'preserve base adapter and wholly block unresolved I12')
model=(H/'ink_intermediate_model.gd').read_text();bridge=(H/'ink_intermediate_bridge.gd').read_text();sim=(H/'ink_intermediate_sim.gd').read_text();gate=(H/'intermediate_gate.gd').read_text()
for name,body in [('adapter',text),('model',model),('bridge',bridge),('sim',sim)]:
 check(not re.search(r'state\.(gold|points|inventory)\s*=',body),'no new '+name+' wallet/inventory/SP writes')
 check(not re.search(r'func (command|_apply_commerce|damage_hero|heal|_buy|_undo|restore)\b',body),'no new '+name+' transaction/health authority')
check('IntermediateAdapter.build(numeric)' in bridge and 'IntermediateModel.new' in bridge,'new adapter actually used by fresh bridge')
check('bind_health_sim(sim)' in bridge and 'InitialConsumer.new()' in bridge,'same health wrapper and six-hook consumer')
check('ink_initial_model.gd' in model and 'ink_initial_sim.gd' in sim,'retain exact initial selector/HP/H02/common composition')
check('source_fixture_path' in bridge and 'NumericAdapter.build(fixture, numeric)' in bridge,'original ledger recipes and numeric prices remain authoritative')
check('"craft"' in gate and 'undo_restored_own_clamp,35' in gate and 'case reached final assertion' in gate,'real craft/G30 clamp gate with completion markers')
check('state.gold=gold' in gate and 'ordinary defaults unchanged before explicit test funding' in gate,'funds explicitly confined to test gate after default assertion')
check('e.dead=' not in gate and 'credit_reward' not in gate,'no forced kill or alternate reward funding')
# Independent per-instance patch arithmetic for each exact original recipe at
# every finite ownership prefix; source algebra only, NOT a GDScript pass.
paths=0
for id in sorted(expected):
 row=byid[id]
 for owned in range(len(row['components'])+1):
  before=[{'uid':i+1,'id':p,'invested':byid[p]['price'],'lineage':[i+1]} for i,p in enumerate(row['components'][:owned])]
  original=copy.deepcopy(before);gold=10000-sum(x['invested'] for x in before)
  charge=row['price']-sum(byid[x['id']]['price'] for x in before)
  item={'uid':99,'id':id,'invested':charge+sum(x['invested'] for x in before),'lineage':[99]+[x['uid'] for x in before]}
  after=[item];after_gold=gold-charge
  check(item['invested']==row['price'] and after_gold==10000-row['price'],'partial recipe net original total '+id+':'+str(owned))
  after.remove(item);after.extend(copy.deepcopy(original));after_gold+=charge
  check(after==original and after_gold==gold,'exact inverse algebra '+id+':'+str(owned));paths+=1
check((360+35)-35==360 and 360+35==395,'G30 600-to400 exact35 clamp arithmetic')
check(360*(1+2*.06)==403.20000000000005,'G24 six-to-four inventory source arithmetic')
# Rebindings must differ ONLY at explicit script/result/provenance substitutions.
for src,dst in [('tests/ink_initial_hex_runtime_20261004/fix01/sink_gate.gd','common_regression_gate.gd'),('tests/ink_initial_hex_runtime_20261004/hp_regression_gate.gd','hp_regression_gate.gd'),('tests/ink_initial_hex_runtime_20261004/selector_gate.gd','selector_regression_gate.gd')]:
 original=(R/src).read_text();wanted=original
 for a,c in [('ink_initial_sim.gd','ink_intermediate_sim.gd'),('ink_initial_bridge.gd','ink_intermediate_bridge.gd'),('ink_initial_model.gd','ink_intermediate_model.gd')]:wanted=wanted.replace('res://tests/ink_initial_hex_runtime_20261004/'+a,'res://tests/ink_intermediate_stats_20261004/'+c)
 wanted=wanted.replace('res://tests/ink_initial_hex_runtime_20261004/fix01/source_binding.json','res://tests/ink_intermediate_stats_20261004/source_binding.json')
 wanted=wanted.replace('res://tests/ink_initial_hex_runtime_20261004/source_binding.json','res://tests/ink_intermediate_stats_20261004/source_binding.json')
 for a in ['fix01/sink_result.json','hp_result.json','selector_result.json']:wanted=wanted.replace('res://tests/ink_initial_hex_runtime_20261004/'+a,'res://tests/ink_intermediate_stats_20261004/'+dst.replace('_gate.gd','_result.json'))
 wanted=wanted.replace('"runtime_source_binding_id":"c997','"upstream_runtime_source_binding_id":"c997')
 wanted=wanted.replace('"suite":"ink_same_visit_exact_hp_clamp_undo"','"suite":"ink_same_visit_exact_hp_clamp_undo","source_binding_id":FileAccess.get_sha256("res://tests/ink_intermediate_stats_20261004/source_binding.json")')
 check((H/dst).read_text()==wanted,'only declared exact rebindings '+dst)
# Add local inputs to runtime map; outputs and self-referential identity sidecars
# are excluded here and appended, with exact hashes, by prepare_stage.
excluded={'.gdignore','source_binding.json','source_result.json','capabilities.json','live_binding.gd'}
for f in sorted(H.iterdir()):
 if f.is_file() and f.name not in excluded and not f.name.endswith('_result.json'):
  rel=f.relative_to(R).as_posix();mapping[rel]={'source':rel,'sha256':sha(f)}
output_names={'source_binding.json','capabilities.json','live_binding.gd','intermediate_result.json','common_regression_result.json','hp_regression_result.json','selector_regression_result.json'}
for f in H.glob('*.gd'):
 if f.name=='live_binding.gd':continue
 for ref in re.findall(r'res://([^"\n]+)',f.read_text()):
  if Path(ref).name in output_names:continue
  check(ref in mapping,'bound direct dependency '+ref)
files={e['source']:e['sha256'] for e in mapping.values()}
files[(H/'.gdignore').relative_to(R).as_posix()]=sha(H/'.gdignore')
binding={'schema':1,'scope':'base11 intermediate17 source candidate; exact c997 plus HP and six common hooks; engine pending main','upstream_initial_runtime_binding':'c997eab5df81084d7ca970c76464389e4cf47954ae8271c1b18ae3a8b27cec7a','upstream_fixed_sink_binding':sha(up),'supported_intermediate_ids':sorted(expected),'held_ids':['base:B12','intermediate:I12'],'files':dict(sorted(files.items())),'runtime_map':dict(sorted(mapping.items())),'author_engine_invocations':0}
(H/'source_binding.json').write_text(json.dumps(binding,ensure_ascii=False,indent=2)+'\n')
identity=sha(H/'source_binding.json')
manifest=json.loads((R/'tests/ink_initial_hex_runtime_20261004/capabilities.json').read_text());manifest.update(version='ink-base11-intermediate17-source-v1',source_binding_id=identity,scope='exact source candidate; all engine/native acceptance separate',supported_intermediate_ids=sorted(expected),held_equipment_ids=['base:B12','intermediate:I12'],required_finite_results=['intermediate_result.json','common_regression_result.json','hp_regression_result.json','selector_regression_result.json'])
(H/'capabilities.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
live=(R/'tests/ink_initial_hex_runtime_20261004/live_binding.gd').read_text()
live=live.replace('res://tests/ink_initial_hex_runtime_20261004/ink_initial_sim.gd','res://tests/ink_intermediate_stats_20261004/ink_intermediate_sim.gd')
for f in ['source_binding.json','capabilities.json']:live=live.replace('res://tests/ink_initial_hex_runtime_20261004/'+f,'res://tests/ink_intermediate_stats_20261004/'+f)
live=live.replace('c997eab5df81084d7ca970c76464389e4cf47954ae8271c1b18ae3a8b27cec7a',identity).replace('Lv1 eight source candidates; finite results and normal UI acceptance separate','Lv1 eight Hex + base11/intermediate17 source candidates; finite and normal UI acceptance separate')
(H/'live_binding.gd').write_text(live)
result={'passed':True,'checks':len(checks),'checks_detail':checks,'independent_recipe_ownership_paths':paths,'source_binding_sha256':identity,'runtime_files':len(mapping),'engine':'NOT_RUN_BY_AUTHOR','production_ready':False,'ordinary_entry_ready':False}
(H/'source_result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='checks_detail'}))
