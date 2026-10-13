#!/usr/bin/env python3
"""Copy immutable exact source to a new stage; never launches or imports engine."""
from pathlib import Path
import argparse, hashlib, json, shutil
H = Path(__file__).resolve().parent; R = H.parents[2]
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
p = argparse.ArgumentParser(); p.add_argument('--dest', type=Path, required=True); args = p.parse_args()
assert not args.dest.exists(), 'Refuse to reuse or overwrite an existing stage'
binding = json.loads((H/'source_binding.json').read_text())
for rel,item in binding['authored_files'].items(): assert sha(R/rel) == item['sha256'], 'Authored source changed: '+rel
mapping = dict(binding['runtime_map'])
for name in ['source_binding.json','source_result.json','manifest.sha256']:
    source = H/name; rel = source.relative_to(R).as_posix(); mapping[rel] = {'source':rel,'sha256':sha(source)}
for rel,item in mapping.items():
    assert not Path(rel).is_absolute() and '..' not in Path(rel).parts
    assert sha(R/item['source']) == item['sha256'], 'Bound input changed: '+item['source']
    out = args.dest/rel; out.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(R/item['source'],out); assert sha(out) == item['sha256']
(args.dest/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Ink Q2 isolated finite mechanics"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
receipt = {'source_binding_sha256':sha(H/'source_binding.json'),'runtime_binding_sha256':sha(H/'runtime_binding.json'),'files':len(mapping),'runtime_map':mapping,'engine_invocations':0,'ordinary_entry_ready':False}
(args.dest/'staging_receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'stage':str(args.dest),'files':len(mapping),'binding':receipt['source_binding_sha256'],'engine':'NOT_STARTED'}))
