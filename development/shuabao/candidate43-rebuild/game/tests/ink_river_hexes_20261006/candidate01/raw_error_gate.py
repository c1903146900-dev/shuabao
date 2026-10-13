#!/usr/bin/env python3
"""Read real finite/parse evidence and exact process exit receipts; no engine."""
import argparse,hashlib,json,re
from pathlib import Path
D=Path(__file__).resolve().parent
ERRORS=re.compile(r'SCRIPT ERROR|PARSE ERROR|Parse Error|ERROR:|FATAL|CRASH|Segmentation fault',re.I)
def require(ok,label):
 if not ok:raise ValueError(label)
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(raw_path,exit_path,marker):
 raw=raw_path.read_text();exit=json.loads(exit_path.read_text())
 require(exit.get('exit')==0 and exit.get('reaped') is True,'process must exit zero and be reaped')
 require(not exit.get('errors') and not exit.get('reason'),'process receipt reports failure')
 require(not ERRORS.search(raw),'raw engine/script error')
 lines=[x[len(marker):] for x in raw.splitlines() if x.startswith(marker)]
 require(len(lines)==1,'missing/duplicate completion marker')
 report=json.loads(lines[0]);require(report.get('passed') is True and report.get('failures')==[],'report is not complete PASS')
 return raw,report
def validate(a):
 binding=json.loads(a.binding.read_text());digest=sha(a.binding)
 require(digest==sha(D/'source_binding.json'),'stage/source binding mismatch')
 _,parse=read(a.parse_raw,a.parse_exit,'INK_RIVER_HEX_PARSE ')
 raw,result=read(a.finite_raw,a.finite_exit,'INK_RIVER_HEX_RESULT ')
 require(parse.get('source_binding_sha256')==digest and parse.get('runtime_pass') is False,'parse identity/scope differs')
 scripts=json.loads(re.search(r'const FILES = (\[[^\n]+\])',(D/'parse_gate.gd').read_text()).group(1))
 require(parse.get('scripts')==scripts,'parse missing exact candidate scripts')
 require(result.get('source_binding_sha256')==digest,'finite identity differs')
 groups=binding['required_groups'];require(result.get('completed')==groups,'finite groups incomplete')
 require([x.split(' ',1)[1] for x in raw.splitlines() if x.startswith('INK_RIVER_HEX_GROUP ')]==groups,'raw group evidence incomplete')
 require(result.get('checks',0)>=75,'finite assertions incomplete')
 require(json.loads(a.finite_report.read_text())==result,'file/raw result differs')
 require(result.get('ordinary_admission') is False and result.get('P1_P2_H04_ownership')=='HOLD','scope widened')
 require(result.get('native_input')=='NOT_RUN' and result.get('art_audio_accepted') is False and result.get('real_multiplayer') is False,'unverified acceptance widened')
 return {'schema':'ink-river-hex-raw-gate-1','passed':True,'source_binding_sha256':digest,'checks':result['checks'],'groups':groups,'strict_raw_gate':'PASS','ordinary_admission':False,'P1_P2_H04_ownership':'HOLD','native_input':'NOT_RUN','art_audio_accepted':False,'real_multiplayer':False}
if __name__=='__main__':
 p=argparse.ArgumentParser()
 for name in ['binding','parse_raw','parse_exit','finite_raw','finite_exit','finite_report','output']:p.add_argument('--'+name.replace('_','-'),type=Path,required=True)
 a=p.parse_args()
 try:out=validate(a)
 except (ValueError,KeyError,TypeError,OSError,AttributeError) as e:out={'schema':'ink-river-hex-raw-gate-1','passed':False,'failure':str(e)}
 a.output.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print(json.dumps(out,ensure_ascii=False,indent=2));raise SystemExit(0 if out['passed'] else 1)
