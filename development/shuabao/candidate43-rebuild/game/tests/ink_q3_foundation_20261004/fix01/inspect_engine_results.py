#!/usr/bin/env python3
"""Audit supplied main logs/results only. No subprocess or engine invocation."""
from pathlib import Path
import argparse,hashlib,json,re
H=Path(__file__).resolve().parent;R=H.parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True);p.add_argument('--runs',type=Path,required=True);p.add_argument('--output',type=Path);a=p.parse_args()
binding=json.loads((H/'source_binding.json').read_text());identity=sha(H/'source_binding.json');expectations=json.loads((H/'gate_expectations.json').read_text());problems=[];results=[];seen=set()
for target,entry in binding['runtime_map'].items():
 f=a.stage/target
 if not f.is_file() or sha(f)!=entry['sha256']:problems.append('changed/missing staged source: '+target)
for name in ['source_binding.json','authoring_manifest.json']:
 f=a.stage/H.relative_to(R)/name
 if not f.is_file() or sha(f)!=sha(H/name):problems.append('changed/missing staged identity: '+name)
for row in json.loads(a.runs.read_text()):
 name=Path(row['script']).name;errors=[]
 if name not in expectations:problems.append('unknown gate '+name);continue
 if name in seen:problems.append('duplicate gate '+name);continue
 seen.add(name);spec=expectations[name]
 if row.get('exit_code')!=0:errors.append('exit must be zero')
 log=Path(row['log_path']);log=log if log.is_absolute() else a.runs.parent/log
 content=log.read_text(errors='replace') if log.is_file() else ''
 if not log.is_file():errors.append('full merged log missing')
 if re.search(r'SCRIPT ERROR|Parse Error|ERROR:|Assertion failed|Exception|Traceback',content,re.I):errors.append('engine/script/error in full log')
 result_file=a.stage/H.relative_to(R)/spec['result']
 if not result_file.is_file():errors.append('result missing')
 else:
  try:
   result=json.loads(result_file.read_text());terminal=re.findall(r'^'+re.escape(spec['marker'])+r' (\{.*\})$',content,re.M)
   if len(terminal)!=1 or json.loads(terminal[0])!=result:errors.append('exactly one matching terminal report required')
   if result.get('passed',True) is not True or result.get('failures')!=[] or not isinstance(result.get('checks'),int) or result['checks']<=0:errors.append('invalid/failed result')
   if result.get('source_binding_id')!=identity:errors.append('result binding mismatch')
   if 'expected_checks' in spec and result.get('checks')!=spec['expected_checks']:errors.append('retained full check count mismatch')
   if 'completed' in spec and (set(result.get('completed',[]))!=set(spec['completed']) or len(result.get('completed',[]))!=len(spec['completed'])):errors.append('case completion mismatch')
   if name=='common_regression_gate.gd':
    required={'old_spacing_refusal','personal','G01','G05','G06','G15','G24','G30'}
    if set(result.get('case_status',{}))!=required or not all(x.get('completed') and x.get('passed') for x in result.get('case_status',{}).values()):errors.append('common case completion mismatch')
  except (ValueError,KeyError,TypeError) as exc:errors.append('invalid result '+str(exc))
 results.append({'script':name,'passed':not errors,'errors':errors,'log_path':str(log),'result_path':str(result_file)})
for name in set(expectations)-seen:problems.append('required gate never executed: '+name)
report={'passed':not problems and all(x['passed'] for x in results),'source_binding_id':identity,'problems':problems,'runs':results,'scope':'finite actual gate only; not normal input/art/production/full floor acceptance'}
if a.output:
 out=a.output.resolve();assert out.is_relative_to(H);out.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2));raise SystemExit(0 if report['passed'] else 1)
