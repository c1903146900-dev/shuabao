#!/usr/bin/env python3
"""Reuse Q2 canonical target/source staging for the small E1 successor; no apps."""
import argparse,hashlib,json,re,shutil
from pathlib import Path
O=Path(__file__).resolve().parent;R=O.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--dest',required=True);a=p.parse_args();dest=Path(a.dest).resolve()
if not (dest/'project.godot').is_file():raise SystemExit('Existing ordinary stage required')
if dest==R or R in dest.parents:raise SystemExit('Stage must be separate from source')
plan={};remaps={}
def add(target,source,expected=None):
 for name in [target,source]:
  path=Path(name)
  if path.is_absolute() or '.godot' in path.parts or '..' in path.parts:raise SystemExit('Invalid source closure path '+name)
 actual=sha(R/source)
 if expected is not None and actual!=expected:raise SystemExit('Source pin changed '+source)
 if target in plan and plan[target]['sha256']!=actual:raise SystemExit('Conflicting canonical target '+target)
 plan[target]={'source':source,'sha256':actual}
manifest=json.loads((O/'source_binding.json').read_text())
for name,expected in manifest['parent_runtime_maps'].items():
 rel=name.removeprefix('res://');add(rel,rel,expected)
 for target,item in json.loads((R/rel).read_text())['runtime_map'].items():
  source=item.get('source',target);add(target,source,item['sha256'])
  if source!=target:remaps[target]=source
parent='tests/ink_q2_ordinary_20261005/candidate01/source_binding.json';add(parent,parent)
for name,expected in json.loads((R/parent).read_text())['runtime_map'].items():
 rel=name.removeprefix('res://')
 if name in manifest['ancestor_pin_replacements']:expected=manifest['ancestor_pin_replacements'][name]['after']
 add(rel,rel,expected)
for rel in ['tests/ink_e1_rain_foundation_20261005/fix01/source_binding.json','tests/ink_q2_foundation_20261005/fix01/source_binding.json','tests/ink_q2_foundation_20261005/fix01/capabilities.json','tests/ink_q2_foundation_20261005/fix01/live_binding.gd']:
 add(rel,rel)
for name,expected in manifest['runtime_map'].items():
 rel=name.removeprefix('res://');add(rel,rel,expected)
for source in O.iterdir():
 if source.is_file() and source.name!='stage_receipt.json':
  rel=str(source.relative_to(R));add(rel,rel)
references=set()
for item in list(plan.values()):
 source=R/item['source']
 if source.suffix in ['.gd','.tscn','.tres','.json','.gdshader']:
  references.update(re.findall(r'"res://([^"\n]+)"',source.read_text()))
retained=[]
for source in sorted(set(remaps.values())):
 if source in references and source not in plan:add(source,source);retained.append(source)
for target,item in sorted(plan.items()):
 out=dest/target
 if not out.is_file() or sha(out)!=item['sha256']:
  out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/item['source'],out)
 if sha(out)!=item['sha256']:raise SystemExit('Stage mismatch '+target)
result={'status':'E1_CANONICAL_DELTA_SHA_VERIFIED_NOT_ENGINE_RUN','stage':str(dest),'files':len(plan),'closure':plan,'canonical_remaps':remaps,'referenced_aliases':retained,'baseline':'existing ordinary frontdoor stage prerequisite','copy_godot_cache':False,'engine_or_import_invoked':False,'binding_sha256':sha(O/'source_binding.json')}
(O/'stage_receipt.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='closure'}))
