#!/usr/bin/env python3
from pathlib import Path
import argparse,hashlib,json,re
D=Path(__file__).resolve().parent
ERROR=re.compile(r'SCRIPT ERROR|PARSE ERROR|Parse Error|Compile Error|ERROR:|FATAL|CRASH|Segmentation fault|resources still in use|ObjectDB instances leaked',re.I)
def require(ok,label):
 if not ok:raise ValueError(label)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(raw_file,exit_file,marker):
 raw=raw_file.read_text();ex=json.loads(exit_file.read_text())
 require(ex.get('exit')==0 and ex.get('reaped') is True and ex.get('cleanup_group_empty') is True and ex.get('group_final')==[],'process not zero/reaped/empty')
 require(not ex.get('reason') and not ex.get('errors') and not ERROR.search(raw),'raw/process error')
 rows=[json.loads(line[len(marker):]) for line in raw.splitlines() if line.startswith(marker)]
 require(len(rows)==1 and rows[0].get('passed') is True and rows[0].get('failures')==[],'missing or failed completion')
 return raw,rows[0]
def verify(a):
 b=json.loads(a.binding.read_text());digest=sha(a.binding);require(digest==sha(D/'source_binding.json'),'binding mismatch')
 _,parsed=read(a.parse_raw,a.parse_exit,'INK_RIVER_FRONTDOOR_PARSE ')
 raw,result=read(a.finite_raw,a.finite_exit,'INK_RIVER_FRONTDOOR_RESULT ')
 require(parsed.get('source_binding_sha256')==digest and parsed.get('runtime_pass') is False,'parse identity/scope mismatch')
 files=json.loads(re.search(r'const FILES = (\[[^\n]+\])',(D/'parse_gate.gd').read_text()).group(1));require(parsed.get('scripts')==files,'parse omitted a source')
 require(result.get('source_binding_sha256')==digest and json.loads(a.finite_report.read_text())==result,'finite binding/file mismatch')
 require(result.get('completed')==b['required_groups'] and [x.split(' ',1)[1] for x in raw.splitlines() if x.startswith('INK_RIVER_FRONTDOOR_GROUP ')]==b['required_groups'],'lifecycle groups incomplete')
 require(result.get('checks',0)>=35,'finite lifecycle assertions incomplete')
 for field in ['gameplay_matrix_rerun','graphics_warmup','default_click_native','window_close_signal','other_heroes_played','production_R_changed','full_floor','art_audio_accepted','real_multiplayer']:require(result.get(field) is False,'scope widened:'+field)
 require(result.get('same_ordinary_sim') is True and result.get('diagnostic_sink_stubbed') is True and result.get('temporary_stage_aliases') is True,'fixture/temporary scope missing')
 restored=json.loads(a.restore_receipt.read_text())
 require(restored.get('status')=='TWO_STAGE_ENTRY_PREIMAGES_RESTORED' and restored.get('previous_parent_runtime_map_restored') is True and restored.get('source_binding_sha256')==digest,'stage entries not proven restored')
 require(restored.get('entries_after')=={key:value['before'] for key,value in b['ancestor_pin_replacements'].items()},'restored two preimage hashes differ')
 return {'schema':'ink-river-frontdoor-raw-gate-1','passed':True,'source_binding_sha256':digest,'checks':result['checks'],'groups':b['required_groups'],'strict_raw_gate':'PASS','two_stage_preimages_restored':True,'ordinary_gameplay_matrix_rerun':False,'default_click_native':False,'graphics_warmup':False,'diagnostic_sink_stubbed':True,'production_R_changed':False}
if __name__=='__main__':
 p=argparse.ArgumentParser()
 for name in ['binding','parse_raw','parse_exit','finite_raw','finite_exit','finite_report','restore_receipt','output']:p.add_argument('--'+name.replace('_','-'),type=Path,required=True)
 a=p.parse_args()
 try:out=verify(a)
 except (ValueError,KeyError,TypeError,OSError) as e:out={'schema':'ink-river-frontdoor-raw-gate-1','passed':False,'failure':str(e)}
 a.output.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print(json.dumps(out,ensure_ascii=False,indent=2));raise SystemExit(0 if out['passed'] else 1)
