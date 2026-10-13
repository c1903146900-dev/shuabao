#!/usr/bin/env python3
"""Exact P2 ordinary closure, including reviewable production source aliases."""
from pathlib import Path
import argparse,ast,hashlib,json,re
D=Path(__file__).resolve().parent;R=D.parents[2]
P=R/'tests/ink_e3_ordinary_20261006/ordinary01'
PARENT_SHA='9a0c1e1c5a57d041fb443ce96190dbd5d113de2e1e0d5be1c16da188b3cafb1c'
MECHANISM=R/'tests/ink_p2_ordinary_20261006/mechanism01/fix01/source_binding.json'
MECHANISM_SHA='93016946fb9868a86154669fec19865f1fb6d14f582062f5ced127f03a7edd9b'
ADAPTER='res://scripts/integration/yanguizhou_first_floor.gd';CHOOSER='res://scripts/ui/hero_chooser.gd'
CANDIDATES=['Q1','Q2','Q3','E1','E2','E3','P1','P2','R1']
RESOURCE=re.compile(r'''["']res://([^"'\n]+)["']''')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def relative(path):
 p=Path(path.removeprefix('res://'));assert not p.is_absolute() and '..' not in p.parts and '.godot' not in p.parts;return p
def encode(obj):return json.dumps(obj,ensure_ascii=False,indent=2)+'\n'
def expected():
 assert sha(P/'source_binding.json')==PARENT_SHA
 assert sha(MECHANISM)==MECHANISM_SHA
 parent=json.loads((P/'source_binding.json').read_text());mechanism=json.loads(MECHANISM.read_text())
 mapped=parent['runtime_map'].copy();aliases=parent['source_aliases'].copy();changes={}
 for target,name in [(ADAPTER,'production_adapter.gd'),(CHOOSER,'production_chooser.gd')]:
  replacement=D/name
  changes[target]={'before':mapped[target],'after':sha(replacement),'scope':'reviewed_P2_ordinary_leaf_or_catalog_text_only'}
  mapped[target]=sha(replacement);aliases[str(relative(target))]=str(replacement.relative_to(R))
 for file in [P/'source_binding.json',MECHANISM]:mapped['res://'+str(file.relative_to(R))]=sha(file)
 for path,digest in {**mechanism['frozen_inputs_sha256'],**mechanism['files_sha256']}.items():
  if path in changes:continue
  if path in mapped:assert mapped[path]==digest,('parent/mechanism mismatch',path)
  mapped[path]=digest
 for file in sorted(D.iterdir()):
  if file.is_file() and file.suffix in ['.gd','.py','.md']:
   mapped['res://'+str(file.relative_to(R))]=sha(file)
 queue=[path for path in mapped if path.startswith('res://'+str(D.relative_to(R))+'/') and path.endswith(('.gd','.tscn','.tres')) and not path.endswith('/production_chooser.gd')];seen=set()
 own_binding='res://'+str((D/'source_binding.json').relative_to(R))
 # The chooser's unchanged other-hero factories are not new P2 dependencies.
 # Its sole changed RuntimeText is already an explicit new top-level source.
 while queue:
  path=queue.pop()
  if path in seen:continue
  seen.add(path)
  source=R/relative(aliases.get(str(relative(path)),str(relative(path))))
  for ref in RESOURCE.findall(source.read_text()):
   if ref.endswith('/'):continue
   target='res://'+ref
   if target==own_binding:continue
   fresh=target not in mapped
   if fresh:
    file=R/relative(aliases.get(ref,ref));assert file.is_file(),(path,target)
    mapped[target]=sha(file)
   if fresh and target.endswith(('.gd','.tscn','.tres')):queue.append(target)
 return parent,dict(sorted(mapped.items())),changes,aliases

def collect():
 b=json.loads((D/'source_binding.json').read_text());parent,mapped,changes,aliases=expected()
 assert b['runtime_map']==mapped and b['ancestor_pin_replacements']==changes and b['source_aliases']==aliases
 assert b['runtime_candidates']==CANDIDATES and b['supported_hex_hooks']==parent['supported_hex_hooks']
 return b,mapped,aliases

def verify():
 b,mapped,aliases=collect()
 for path,digest in mapped.items():assert sha(R/relative(aliases.get(str(relative(path)),str(relative(path)))))==digest,path
 for target,name in [(ADAPTER,'production_adapter.gd'),(CHOOSER,'production_chooser.gd')]:
  before=(R/relative(target)).read_text();after=(D/name).read_text()
  # Source may later be deliberately cut over by the coordinator, but no third
  # bytes are accepted. The frozen parent preimage is already hash-pinned.
  assert sha(R/relative(target)) in [b['ancestor_pin_replacements'][target]['before'],b['ancestor_pin_replacements'][target]['after']]
  if sha(R/relative(target))==b['ancestor_pin_replacements'][target]['before']:
   if target==ADAPTER:assert before.splitlines()[1:]==after.splitlines()[1:] and after.splitlines()[0]=='extends "res://tests/ink_p2_ordinary_20261006/ordinary01/host.gd"'
   else:assert before.replace('res://tests/ink_e3_ordinary_20261006/ordinary01/runtime_text.gd','res://tests/ink_p2_ordinary_20261006/ordinary01/runtime_text.gd')==after
 for path in D.glob('*.py'):ast.parse(path.read_text())
 assert (D/'sim.gd').read_text().splitlines()[0]=='extends "res://tests/ink_p2_ordinary_20261006/mechanism01/sim.gd"'
 assert (D/'input_adapter.gd').read_text().splitlines()[0]=='extends "res://tests/ink_e3_ordinary_20261006/ordinary01/input_adapter.gd"'
 assert '旧E1原伤回调暂停' not in (D/'catalog.gd').read_text()
 assert len(b['required_groups'])==5 and not b['new_hex_admission']
 gate=(D/'finite_gate.gd').read_text();assert 'groups.count(group) == 1' in gate and 'old_full_matrices_rerun' in gate
 # Mechanism source, its accepted test binding and current ordinary parent are
 # all immutable dependencies. This author does not convert actual evidence.
 return {'schema':'ink-p2-ordinary-source-check-1','passed':True,'source_binding_sha256':sha(D/'source_binding.json'),'closure_files':len(mapped),'planned_production_leaf_changes':list(b['ancestor_pin_replacements']),'godot_parse':'NOT_RUN','finite_runtime':'NOT_RUN','native_input':'NOT_RUN','e1_original_pause_remainder_fixed':False}

def freeze():
 assert not (D/'source_binding.json').exists(),'create successor instead of overwriting frozen binding'
 parent,mapped,changes,aliases=expected()
 group_source=re.search(r'const REQUIRED_GROUPS: Array = (\[[^\n]+\])',(D/'finite_gate.gd').read_text()).group(1)
 b={'schema':'ink-p2-ordinary-composition-1','status':'SOURCE_ONLY_NOT_RUN','parent_binding_sha256':PARENT_SHA,'mechanism_binding_sha256':MECHANISM_SHA,'runtime_candidates':CANDIDATES,'supported_hex_hooks':parent['supported_hex_hooks'],'runtime_map':mapped,'ancestor_pin_replacements':changes,'source_aliases':aliases,'required_groups':json.loads(group_source),'new_hex_admission':False,'production_source_cutover':False,'native_input':'NOT_RUN','e1_original_pause_remainder_fixed':False}
 (D/'source_binding.json').write_text(encode(b))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--freeze',action='store_true');a=p.parse_args()
 if a.freeze:freeze()
 print(encode(verify()),end='')
