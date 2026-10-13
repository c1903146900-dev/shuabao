#!/usr/bin/env python3
"""Verify this ordinary R1 leaf's exact source, without Godot or source mutation."""
from pathlib import Path
import hashlib
import json
import re
import sys
D=Path(__file__).resolve().parent
R=D.parents[3]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
checks=[]
def check(ok,label):checks.append((bool(ok),label))
b=json.loads((D/'source_binding.json').read_text())
check(b['schema']=='ink-r1-ordinary-overlay-1','new distinct ordinary binding schema')
for path,digest in b['runtime_map'].items():
 check(sha(R/path.removeprefix('res://'))==digest,'new source pin '+path)
e_path=R/'tests/ink_e1_ordinary_20261005/candidate01/source_binding.json'
core_path=D.parent/'source_binding.json'
check(sha(e_path)==b['parent_e1_sha256'],'exact frozen E1 parent')
check(sha(core_path)==b['parent_core_sha256'],'exact598-source core parent')
e=json.loads(e_path.read_text());core=json.loads(core_path.read_text())
for name,digest in core['candidate_files'].items():check(sha(D.parent/name)==digest,'unchanged verified core input '+name)
for path,digest in e['runtime_map'].items():
 replacement=b['ancestor_pin_replacements'].get(path,{})
 if replacement:
  check(path in ['res://scripts/integration/yanguizhou_first_floor.gd','res://scripts/ui/hero_chooser.gd'] and replacement['before']==digest and replacement['after']==b['runtime_map'][path],'explicit narrow successor '+path)
  digest=replacement['after']
 check(sha(R/path.removeprefix('res://'))==digest,'retained E1 source '+path)
for path,digest in e['parent_runtime_maps'].items():
 p=R/path.removeprefix('res://');check(sha(p)==digest,'retained canonical manifest '+path)
 for target,item in json.loads(p.read_text())['runtime_map'].items():
  check(sha(R/item.get('source',target))==item['sha256'],'retained mapped SOURCE '+target)
before=json.loads((D/'preimage_manifest.json').read_text())
for path,digest in before.items():check(sha(D/'preimage'/path)==digest,'preserved entry preimage '+path)
check(sha(R/'scripts/integration/hero_entry.gd')==before['scripts/integration/hero_entry.gd'],'true E-up forwarding and other hero entry branches unchanged')
old=(D/'preimage/scripts/integration/yanguizhou_first_floor.gd').read_text()
expected=old.replace('res://tests/ink_e1_ordinary_20261005/candidate01/host.gd','res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/host.gd',1).replace('\tinput_router.clear_q2_frontdoor_latches()\n','\tinput_router.clear_q2_frontdoor_latches()\n\tinput_router.clear_r1_frontdoor_latches()\n',1)
check((R/'scripts/integration/yanguizhou_first_floor.gd').read_text()==expected,'adapter only extends plus R input latch clear')
check(b['runtime_candidates']==['Q1','Q2','Q3','E1','R1'],'only R1 added to candidate scope')
check(b['supported_hex_hooks']==e['supported_hex_hooks'] and len(b['supported_hex_hooks'])==10,'ten original hooks unchanged')
for path in D.glob('*.gd'):
 text=path.read_text()
 classes=re.findall(r'const\s+(\w+)\s*(?::=|=)\s*preload\("res://[^"\n]+\.gd"\)',text)
 illegal=[name for name in classes if re.search(r'\b'+re.escape(name)+r'\.(?:resource_path|get_base_script|can_instantiate|get_instance_id)\b',text)]
 check(not illegal,'typed Script-resource reflection '+path.name)
 if path.name not in ['finite_gate.gd','parse_gate.gd']:
  code='\n'.join(x for x in text.splitlines() if not x.lstrip().startswith('#'))
  check(not re.search(r'\bstate\.(?:points|level|xp|gold)\s*=(?!=)',code),'no ordinary level/resource assignment '+path.name)
check('Rect2(746,640,46,58)' in (D/'r_hud.gd').read_text(),'R uses reserved slot without Q/E expansion')
check('Vector2(420,280)' in (D/'growth_hud.gd').read_text(),'R grows menu upward within original width')
check('temporary_functional_circle_art_incomplete' in (D/'domain_view.gd').read_text(),'functional circle has explicit art limit')
out={'suite':'ink_r1_ordinary_source','passed':all(x[0] for x in checks),'checks':len(checks),'failures':[x[1] for x in checks if not x[0]],'binding_sha256':sha(D/'source_binding.json'),'scope':'source identities and structural checks only; no GDScript parse or runtime','engine_passed':False,'native_input':False,'natural_level6':False,'art_audio':False}
print(json.dumps(out,ensure_ascii=False,indent=2));sys.exit(0 if out['passed'] else 1)
