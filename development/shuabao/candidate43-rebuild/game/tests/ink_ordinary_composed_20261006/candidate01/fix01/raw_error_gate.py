#!/usr/bin/env python3
"""Inspect actual ordinary parse/finite evidence. Does not run or import Godot."""
import argparse, hashlib, json, re
from pathlib import Path
HERE=Path(__file__).resolve().parent
ERRORS=re.compile(r'SCRIPT ERROR|PARSE ERROR|Parse Error|ERROR:|FATAL|CRASH|Segmentation fault',re.I)
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def require(ok,label):
 if not ok: raise ValueError(label)
def process(raw_path,receipt_path,marker):
 raw=raw_path.read_text(); receipt=json.loads(receipt_path.read_text())
 require(receipt.get('exit')==0 and receipt.get('reaped') is True,'process not exit-zero/reaped: '+str(receipt_path))
 require(not receipt.get('errors') and not receipt.get('reason'),'process receipt reports error')
 require(not ERRORS.search(raw),'raw contains script/parse/engine error')
 lines=[line[len(marker):] for line in raw.splitlines() if line.startswith(marker)]
 require(len(lines)==1,'completion marker absent/duplicated: '+marker)
 value=json.loads(lines[0]);require(value.get('passed') is True and value.get('failures')==[],'incomplete PASS report')
 return raw,value
def validate(a):
 binding=json.loads(a.binding.read_text());sha=digest(a.binding)
 require(sha==digest(HERE/'source_binding.json'),'stage/source binding differs')
 parse_raw,parsed=process(a.parse_raw,a.parse_exit,'INK_COMPOSED_PARSE ')
 finite_raw,finite=process(a.finite_raw,a.finite_exit,'INK_COMPOSED_REPORT ')
 require(parsed.get('source_binding_sha256')==sha and parsed.get('runtime_pass') is False,'parse binding/scope differs')
 source=(HERE/'parse_gate.gd').read_text()
 scripts=json.loads(re.search(r'const FILES := (\[[^\n]+\])',source).group(1))
 require(parsed.get('scripts')==scripts,'parse omitted an exact source script')
 require(finite.get('source_binding_sha256')==sha,'finite source binding differs')
 require(parsed.get('runtime_source_binding_sha256')==binding['runtime_source_binding_sha256'] and finite.get('runtime_source_binding_sha256')==binding['runtime_source_binding_sha256'],'runtime composition binding differs')
 groups=binding['required_groups'];require(len(groups)==4,'expected four cross-component groups')
 require(finite.get('completed')==groups,'finite completed group list differs')
 actual=[line.split(' ',1)[1] for line in finite_raw.splitlines() if line.startswith('INK_COMPOSED_GROUP ')]
 require(actual==groups,'required raw group marker absent/duplicated/out of order')
 require(finite.get('checks',0)>=80,'finite check count incomplete')
 require(json.loads(a.finite_report.read_text())==finite,'written report differs from raw completion')
 for field in ['new_hex_admission','old_full_matrices_rerun','native_input','natural_progression','full_floor','final_presentation_animation','real_multiplayer']:
  require(finite.get(field) is False,'runtime report scope widened/missing: '+field)
 return {'schema':'ink-ordinary-composed-raw-gate-1','passed':True,'source_binding_sha256':sha,'finite_checks':finite['checks'],'required_groups':groups,'parse_and_finite_exit_zero_reaped':True,'raw_error_gate':'PASS','native_input':False,'natural_progression':False,'full_floor':False,'new_hex_admission':False,'final_presentation_animation':False,'real_multiplayer':False,'evidence':{n:{'path':str(getattr(a,n)),'sha256':digest(getattr(a,n))} for n in ['parse_raw','parse_exit','finite_raw','finite_exit','finite_report']}}
def main():
 p=argparse.ArgumentParser(description=__doc__)
 for n in ['binding','parse_raw','parse_exit','finite_raw','finite_exit','finite_report','output']: p.add_argument('--'+n.replace('_','-'),type=Path,required=True)
 a=p.parse_args()
 try: out=validate(a)
 except (ValueError,KeyError,TypeError,OSError,AttributeError) as e:out={'schema':'ink-ordinary-composed-raw-gate-1','passed':False,'failure':str(e)}
 a.output.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print(json.dumps(out,ensure_ascii=False,indent=2));raise SystemExit(0 if out['passed'] else 1)
if __name__=='__main__':main()
