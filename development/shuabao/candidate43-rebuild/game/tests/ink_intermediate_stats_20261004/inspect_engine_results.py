#!/usr/bin/env python3
"""Audit MAIN-supplied finite run receipts/logs/results. Starts no subprocess.

runs.json is a list of {script, exit_code, log_path}; paths may be absolute or
relative to the receipt. Stage owns generated results. Prints a JSON audit only.
Use --output to save it explicitly under this candidate directory.
"""
from pathlib import Path
import argparse,json,hashlib,re
H=Path(__file__).resolve().parent;R=H.parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True);p.add_argument('--runs',type=Path,required=True);p.add_argument('--output',type=Path);a=p.parse_args()
binding=H/'source_binding.json';identity=sha(binding);b=json.loads(binding.read_text())
problems=[];results=[]
for target,entry in b['runtime_map'].items():
 path=a.stage/target
 if not path.is_file() or sha(path)!=entry['sha256']:problems.append('changed/missing staged source: '+target)
for name in ['source_binding.json','live_binding.gd','capabilities.json']:
 path=a.stage/H.relative_to(R)/name
 if not path.is_file() or sha(path)!=sha(H/name):problems.append('changed/missing staged identity: '+name)
markers={'intermediate_gate.gd':'INK_INTERMEDIATE_REPORT','common_regression_gate.gd':'INK_INITIAL_SINK_REPORT','hp_regression_gate.gd':'INK_HP_UNDO_REPORT','selector_regression_gate.gd':'INK_INITIAL_SELECTOR_REPORT'}
reference_counts={'common_regression_gate.gd':905,'hp_regression_gate.gd':185,'selector_regression_gate.gd':25349}
expected={'intermediate_gate.gd':'intermediate_result.json','common_regression_gate.gd':'common_regression_result.json','hp_regression_gate.gd':'hp_regression_result.json','selector_regression_gate.gd':'selector_regression_result.json'}
runs=json.loads(a.runs.read_text());seen=set()
for row in runs:
 name=Path(row['script']).name;errors=[]
 if name not in expected:problems.append('unknown gate: '+name);continue
 if name in seen:problems.append('duplicate gate receipt: '+name);continue
 seen.add(name)
 if row.get('exit_code')!=0:errors.append('exit code is not zero')
 log=Path(row['log_path']);log=log if log.is_absolute() else a.runs.parent/log
 log_text=log.read_text(errors='replace') if log.is_file() else ''
 if not log.is_file():errors.append('log missing')
 elif re.search(r'SCRIPT ERROR|Parse Error|ERROR:|Assertion failed|Exception|Traceback',log_text,re.I):errors.append('engine/script/assertion error appears in full log')
 output=a.stage/H.relative_to(R)/expected[name]
 if not output.is_file():errors.append('required result missing')
 else:
  try:
   d=json.loads(output.read_text())
   reports=re.findall(r'^'+re.escape(markers[name])+r' (\{.*\})$',log_text,re.M)
   if len(reports)!=1 or json.loads(reports[0])!=d:errors.append('one matching terminal report required in merged log')
   if name in reference_counts and d.get('checks')!=reference_counts[name]:errors.append('copied regression complete check count mismatch')
   if name=='selector_regression_gate.gd' and d.get('runs')!=288:errors.append('selector did not complete all288 runs')
   if d.get('failures')!=[] or d.get('passed',True) is not True or not isinstance(d.get('checks'),int) or d['checks']<=0:errors.append('result failures/invalid checks')
   if d.get('source_binding_id')!=identity:errors.append('result candidate digest mismatch')
   if name=='intermediate_gate.gd':
    required={'mapping','partial_full','hp_inverse','dependencies','room_commit','G24','G30','combat_sinks'}|set(b['supported_intermediate_ids'])
    if set(d.get('completed',[]))!=required or len(d.get('completed',[]))!=len(required):errors.append('new finite case completion mismatch')
   if name=='common_regression_gate.gd':
    required={'old_spacing_refusal','personal','G01','G05','G06','G15','G24','G30'}
    if set(d.get('case_status',{}))!=required or not all(x.get('completed') and x.get('passed') for x in d.get('case_status',{}).values()):errors.append('common hook case completion mismatch')
  except (ValueError,TypeError,KeyError) as exc:errors.append('invalid result: '+str(exc))
 results.append({'script':name,'passed':not errors,'errors':errors,'log_path':str(log),'result_path':str(output)})
for missing in set(expected)-seen:problems.append('required gate not executed: '+missing)
report={'passed':not problems and all(r['passed'] for r in results),'source_binding_id':identity,'problems':problems,'runs':results,'scope':'finite engine/source audit only; no UI/balance/full-floor approval'}
if a.output:
 dest=a.output.resolve();assert dest.is_relative_to(H),'Output must stay within candidate directory';dest.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2));raise SystemExit(0 if report['passed'] else 1)
