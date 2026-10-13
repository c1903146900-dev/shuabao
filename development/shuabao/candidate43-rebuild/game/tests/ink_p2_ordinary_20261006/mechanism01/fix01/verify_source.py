#!/usr/bin/env python3
"""Source-only pinned successor verification. Never starts an engine."""
from pathlib import Path
import hashlib,json,re
D=Path(__file__).resolve().parent
R=D.parents[3]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def relative(p): return p.removeprefix('res://')
def verify():
 b=json.loads((D/'source_binding.json').read_text())
 for path,digest in b['files_sha256'].items(): assert sha(R/relative(path))==digest,path
 for path,digest in b['frozen_inputs_sha256'].items(): assert sha(R/relative(path))==digest,path
 for number in (1,2):
  saved=json.loads((D.parent/f'checkpoint_core{number:02d}'/'MANIFEST.json').read_text())
  for name,digest in saved['files_sha256'].items(): assert sha(D.parent/f'checkpoint_core{number:02d}'/name)==digest,(number,name)
 sim=(D.parent/'sim.gd').read_text(); bridge=(D.parent/'p2_common_bridge.gd').read_text(); state=(D.parent/'p2_state.gd').read_text()
 assert sim.splitlines()[0]=='extends "res://tests/ink_e3_ordinary_20261006/ordinary01/sim.gd"'
 assert 'exchange_common_bridge.gd' in bridge.splitlines()[0]
 assert '"e3":"successful_second_frame_completion"' in state
 assert 'h.stats.ap += float(h.projected_base_stats.ap)' in bridge and '_last_stats = h.stats.duplicate(true)' in bridge
 assert '"no_reactions"' not in sim
 assert '_p2_complete(state.context,"e3")' in sim
 gate=(D/'finite_gate.gd').read_text(); body=gate[gate.index('func run() -> void:'):]
 for group in b['required_groups']:
  assert f'func {group}() -> void:' in gate and f' {group}()' in body,group
 assert 'groups.count(group) == 1' in body
 for name in ('finite_gate.gd','parse_gate.gd'):
  for target in re.findall(r'(?:preload|load)\("res://([^\"]+)"\)',(D/name).read_text()): assert (R/target).is_file(),(name,target)
 return {'schema':'ink-p2-mechanism-fixture-fix01-source-check','passed':True,'source_binding_sha256':sha(D/'source_binding.json'),'new_source_files':len(b['files_sha256']),'frozen_input_files':len(b['frozen_inputs_sha256']),'required_groups':b['required_groups'],'godot_parse':'NOT_RUN','finite_runtime':'NOT_RUN','ordinary_admission':False,'production_entry_changed':False}
if __name__=='__main__': print(json.dumps(verify(),ensure_ascii=False,indent=2))
