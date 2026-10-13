#!/usr/bin/env python3
"""Freeze/verify isolated one-line initializer repair. No engine invocation."""
from pathlib import Path
import argparse,copy,difflib,hashlib,json,re
F=Path(__file__).resolve().parent;H=F.parent;R=F.parents[2]
EXPECTED='041a5b5bea1c0797308e6a06cbddf4bd27d1bf0bb6d90ee7e99cdeb2fefb1795'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text())
dump=lambda v:json.dumps(v,ensure_ascii=False,indent=2)+'\n'
checks=[]
def check(ok,label):
 checks.append(label);assert ok,label

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--write',action='store_true');a=parser.parse_args()
 check(sha(H/'source_binding.json')==EXPECTED,'original failed source binding unchanged')
 original=load(H/'source_binding.json')
 for rel,h in original['files'].items():check(sha(R/rel)==h,'original unchanged '+rel)
 prefix='res://'+H.relative_to(R).as_posix()+'/';newprefix=prefix+'fix01/'
 old=(H/'ink_q3_sim.gd').read_text()
 wanted=old.replace('func _init()->void:\n enemy_director=MountainDirector.new()','func _init()->void:\n super._init()\n enemy_director=MountainDirector.new()',1)
 check((F/'ink_q3_sim.gd').read_text()==wanted,'entire original runtime differs by one genuine super initializer call only')
 patches=list(difflib.unified_diff(old.splitlines(True),wanted.splitlines(True),fromfile=str(H.relative_to(R)/'ink_q3_sim.gd'),tofile=str(F.relative_to(R)/'ink_q3_sim.gd')))
 old=(H/'ink_q3_bridge.gd').read_text();wanted=old.replace(prefix+'ink_q3_sim.gd',newprefix+'ink_q3_sim.gd')
 check((F/'ink_q3_bridge.gd').read_text()==wanted,'bridge exact fixed-script admission path only')
 patches.extend(difflib.unified_diff(old.splitlines(True),wanted.splitlines(True),fromfile=str(H.relative_to(R)/'ink_q3_bridge.gd'),tofile=str(F.relative_to(R)/'ink_q3_bridge.gd')))
 specs=load(H/'gate_expectations.json')
 for gate,spec in specs.items():
  old=(H/gate).read_text();wanted=old
  for path in ['ink_q3_sim.gd','ink_q3_bridge.gd','source_binding.json',spec['result']]:wanted=wanted.replace(prefix+path,newprefix+path)
  check((F/gate).read_text()==wanted,'all original assertions preserved '+gate)
  patches.extend(difflib.unified_diff(old.splitlines(True),wanted.splitlines(True),fromfile=str(H.relative_to(R)/gate),tofile=str(F.relative_to(R)/gate)))
 check((F/'minimal_fix.patch').read_text()==''.join(patches),'exact one-line runtime repair plus report/script path patch')
 expectations=load(F/'gate_expectations.json')
 check(all(expectations[k]==v for k,v in specs.items()) and len(expectations)==7,'original six gate expectations unchanged plus diagnostic')
 diagnostic=(F/'diagnostic_gate.gd').read_text()
 for literal in ['source_binding_mismatch','bad.source_rules_hash.is_empty()','sim.hero.actor_id=="yanguizhou"','sim.hero.hp==360','sim.common.get_script().resource_path==INK_BRIDGE','fixed_q1.event_log==old.event_log','fixed_q3.cast_serial==1']:
  check(literal in diagnostic,'diagnostic proves real initializer/admission '+literal)
 check('hero.initialize_stats(' not in diagnostic and not re.search(r'source_rules_hash\s*=(?!=)',diagnostic),'diagnostic never patches initialized HP/hash')
 mapping=copy.deepcopy(original['runtime_map'])
 for name in ['source_binding.json','authoring_manifest.json','authoring_manifest.sha256','source_result.json']:
  rel=(H/name).relative_to(R).as_posix();mapping[rel]={'source':rel,'sha256':sha(H/name)}
 excluded={'source_binding.json','source_result.json','authoring_manifest.json','authoring_manifest.sha256','.gdignore'}
 authored={}
 for p in sorted(F.iterdir()):
  if not p.is_file() or p.name in excluded or p.name.endswith('_result.json'):continue
  rel=p.relative_to(R).as_posix();authored[rel]={'sha256':sha(p),'bytes':p.stat().st_size};mapping[rel]={'source':rel,'sha256':sha(p)}
 outputs={'source_binding.json'}|{v['result'] for v in expectations.values()}
 for p in F.glob('*.gd'):
  for ref in re.findall(r'res://([^"\n]+)',p.read_text()):
   if ref.startswith(F.relative_to(R).as_posix()+'/') and Path(ref).name in outputs:continue
   check(ref in mapping,'exact bound dependency '+ref)
 manifest={'schema':1,'source_only':True,'original_failed_source_binding':EXPECTED,'authored_files':authored,'only_runtime_delta':'super._init() before original director replacement','original_q3_and_five_retained_assertions':'unchanged','author_engine_invocations':0,'production_host_changes':False,'capability_promotions':False}
 binding={'schema':1,'version':'ink-q3-foundation-fix01-parent-init','original_failed_source_binding':EXPECTED,'upstream_binding_sha256':original['upstream_binding_sha256'],'scope':'one-line parent initialization repair; all actual gates main-owned','files':{e['source']:e['sha256'] for e in mapping.values()},'runtime_map':dict(sorted(mapping.items())),'authoring_manifest_sha256':hashlib.sha256(dump(manifest).encode()).hexdigest(),'author_engine_invocations':0,'ordinary_entry_ready':False,'production_ready':False}
 if a.write:
  for name in ['source_binding.json','source_result.json','authoring_manifest.json']:check(not (F/name).exists(),'never overwrite frozen '+name)
  (F/'authoring_manifest.json').write_text(dump(manifest));(F/'authoring_manifest.sha256').write_text(sha(F/'authoring_manifest.json')+'  authoring_manifest.json\n');(F/'source_binding.json').write_text(dump(binding))
 else:
  check(load(F/'authoring_manifest.json')==manifest,'frozen fix manifest unchanged');check(load(F/'source_binding.json')==binding,'frozen fix binding unchanged')
 result={'passed':True,'mode':'source_only_not_parse_or_runtime','source_binding_sha256':sha(F/'source_binding.json'),'original_failed_source_binding':EXPECTED,'runtime_files':len(mapping),'new_authored_files':len(authored),'one_runtime_line_added':True,'original_six_gates_assertions_unchanged':True,'engine':'NOT_RUN_BY_AUTHOR','diagnostic_actual_reason':'AWAITING_MAIN','production_ready':False}
 if a.write:(F/'source_result.json').write_text(dump(result))
 else:check(load(F/'source_result.json')==result,'source result reproducible')
 print(dump({**result,'source_checks':len(checks)}),end='')
if __name__=='__main__':main()
