#!/usr/bin/env python3
"""Verify fixture-only changes separately from local G22 metadata snapshot."""
from pathlib import Path
import argparse,copy,difflib,hashlib,json,re
F=Path(__file__).resolve().parent;B=F.parent/'fix01';R=F.parents[2]
EXPECTED='9ea60f4fdc07d0b868ea2d903790f6a95a7d301f30743b8afd96d5581d9c3d42'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text())
dump=lambda v:json.dumps(v,ensure_ascii=False,indent=2)+'\n'
checks=[]
def check(ok,label):checks.append(label);assert ok,label
def main():
 p=argparse.ArgumentParser();p.add_argument('--write',action='store_true');args=p.parse_args()
 check(sha(B/'source_binding.json')==EXPECTED,'preserved failed fix01 binding')
 upstream=load(B/'source_binding.json')
 for rel,h in upstream['files'].items():check(sha(R/rel)==h,'unchanged inherited source '+rel)
 original=(B/'ink_q3_sim.gd').read_text();actual=(F/'ink_q3_sim.gd').read_text()
 insertion=''' var targets:Array=shape_targets(origin,direction,shape)
 # Each raise/collapse is one simultaneous area batch. Re-evaluate for the next
 # independent segment, but never let this batch's first kill change later hits.
 # These are the existing Wind R1/common/Ink damage-pipeline snapshot interfaces.
 common.refresh_stats()
 var live:Array=common.runtime._enemies(common.context())
 var mode:String="horde" if live.size()>=int(common.runtime.parameter("g22",1)) else "duel" if live.size()==1 and not ordinary(live[0]) else "none"
 var impact:Dictionary={"g22_mode_snapshot":mode,"impact_penetration":float(hero.stats.penetration),"impact_lifesteal_rate":hero.lifesteal()}
 var hit_count:int=0
'''
 wanted=original.replace(' var targets:Array=shape_targets(origin,direction,shape)\n var hit_count:int=0\n',insertion,1).replace('  damage_enemy(enemy,amount,"q3",int(state.cast_id),false,false,metadata)','  metadata.merge(impact,false)\n  damage_enemy(enemy,amount,"q3",int(state.cast_id),false,false,metadata)',1)
 check(actual==wanted,'runtime delta only the existing three G22 snapshot interfaces')
 patch=''.join(difflib.unified_diff(original.splitlines(True),actual.splitlines(True),fromfile=str(B.relative_to(R)/'ink_q3_sim.gd'),tofile=str(F.relative_to(R)/'ink_q3_sim.gd')))
 check((F/'g22_runtime_only.patch').read_text()==patch,'runtime patch isolated from test correction')
 check((F/'ink_q3_bridge.gd').read_text()==(B/'ink_q3_bridge.gd').read_text().replace('fix01/ink_q3_sim.gd','fix02/ink_q3_sim.gd'),'bridge only new exact Sim identity')
 prefix='res://tests/ink_q3_foundation_20261004/fix01/';newprefix=prefix.replace('fix01/','fix02/')
 specs=load(B/'gate_expectations.json');patches=[]
 for gate,spec in specs.items():
  old=(B/gate).read_text();expected=old
  for name in ['source_binding.json',spec['result']]:expected=expected.replace(prefix+name,newprefix+name)
  expected=expected.replace(prefix+'ink_q3_sim.gd',newprefix+'ink_q3_sim.gd').replace(prefix+'ink_q3_bridge.gd',newprefix+'ink_q3_bridge.gd')
  current=(F/gate).read_text()
  if gate!='q3_gate.gd':check(current==expected,'unchanged assertions '+gate)
  else:
   # Unaffected function bodies byte-identical after path normalization.
   before={s.split('(',1)[0]:s for s in re.split(r'^func ',expected,flags=re.M)[1:]}
   after={s.split('(',1)[0]:s for s in re.split(r'^func ',current,flags=re.M)[1:]}
   check(before.keys()==after.keys(),'no original Q3 cases removed')
   for name in before:
    if name not in ['test_lifecycle_and_clocks','test_callbacks']:check(before[name]==after[name],'untouched Q3 function '+name)
    else:
     for line in before[name].splitlines():
      if 'check(' not in line and 'near(' not in line:continue
      # All original assertion labels retained, including callback success.
      for label in re.findall(r'"([^"\n]+)"',line):
       if label not in ['q','next-q3','safe']:check('"'+label+'"' in after[name],'retained lifecycle/callback assertion '+label)
   check('adapter.handle_event(keyup).accepted and sim.hero.move_intent==Vector3.ZERO' in current,'normal D keyup, no gameplay movement override')
   check('near(sim.hero.cooldowns.q,0,"real inherited CD reset reached zero before rebuild")' in current,'real reset asserted')
   check('actual.begin_result.reason=="invalid_phase"' in current and 'var rebuilt:Dictionary=sim.begin_encounter' in current,'transaction rejection explicitly proved then legitimate later begin')
  patches.extend(difflib.unified_diff(old.splitlines(True),current.splitlines(True),fromfile=str(B.relative_to(R)/gate),tofile=str(F.relative_to(R)/gate)))
 check((F/'fixture_only.patch').read_text()==''.join(patches),'all fixture and identity deltas explicit')
 expected=load(F/'gate_expectations.json');check(len(expected)==9 and all(expected[k]==v for k,v in specs.items()),'original seven gate expectations retained plus two focused gates')
 reference=load(F/'diagnosis.json')['production_delta'];check(sha(R/'scripts/combat/fengli_ultimates.gd')==reference['reference_sha256'],'unchanged existing Wind R1 interface source')
 mapping=copy.deepcopy(upstream['runtime_map'])
 for name in ['source_binding.json','authoring_manifest.json','authoring_manifest.sha256','source_result.json']:
  rel=(B/name).relative_to(R).as_posix();mapping[rel]={'source':rel,'sha256':sha(B/name)}
 excluded={'source_binding.json','source_result.json','authoring_manifest.json','authoring_manifest.sha256','.gdignore'};authored={}
 for file in sorted(F.iterdir()):
  if not file.is_file() or file.name in excluded or file.name.endswith('_result.json'):continue
  rel=file.relative_to(R).as_posix();authored[rel]={'sha256':sha(file),'bytes':file.stat().st_size};mapping[rel]={'source':rel,'sha256':sha(file)}
 outputs={'source_binding.json'}|{x['result'] for x in expected.values()}
 for file in F.glob('*.gd'):
  for ref in re.findall(r'res://([^"\n]+)',file.read_text()):
   if ref.startswith(F.relative_to(R).as_posix()+'/') and Path(ref).name in outputs:continue
   check(ref in mapping,'bound dependency '+ref)
 manifest={'schema':1,'source_only':True,'original_failed_source_binding':EXPECTED,'authored_files':authored,'production_delta':'only Q3 per-segment G22 mode/penetration/lifesteal metadata snapshot','test_delta':'normal movement key-up and legal post-transaction room restart','shared_core_edited':False,'original_five_retained_gate_assertions':'unchanged','author_engine_invocations':0,'production_ready':False}
 binding={'schema':1,'version':'ink-q3-fix02-fixtures-and-g22-batch','original_failed_source_binding':EXPECTED,'upstream_binding_sha256':upstream['upstream_binding_sha256'],'files':{x['source']:x['sha256'] for x in mapping.values()},'runtime_map':dict(sorted(mapping.items())),'authoring_manifest_sha256':hashlib.sha256(dump(manifest).encode()).hexdigest(),'author_engine_invocations':0,'ordinary_entry_ready':False,'production_ready':False}
 if args.write:
  for name in ['source_binding.json','source_result.json','authoring_manifest.json']:check(not (F/name).exists(),'never overwrite frozen '+name)
  (F/'authoring_manifest.json').write_text(dump(manifest));(F/'authoring_manifest.sha256').write_text(sha(F/'authoring_manifest.json')+'  authoring_manifest.json\n');(F/'source_binding.json').write_text(dump(binding))
 else:check(load(F/'authoring_manifest.json')==manifest,'manifest unchanged');check(load(F/'source_binding.json')==binding,'binding unchanged')
 result={'passed':True,'mode':'source_only_not_engine','source_binding_sha256':sha(F/'source_binding.json'),'original_failed_source_binding':EXPECTED,'runtime_files':len(mapping),'new_authored_files':len(authored),'shared_core_unchanged':True,'five_retained_gates_assertions_unchanged':True,'engine':'NOT_RUN_BY_AUTHOR','fixture_reasons':'AWAITING_MAIN_ACTUAL','G22_batch':'AWAITING_MAIN_ACTUAL','production_ready':False}
 if args.write:(F/'source_result.json').write_text(dump(result))
 else:check(load(F/'source_result.json')==result,'source result reproducible')
 print(dump({**result,'source_checks':len(checks)}),end='')
if __name__=='__main__':main()
