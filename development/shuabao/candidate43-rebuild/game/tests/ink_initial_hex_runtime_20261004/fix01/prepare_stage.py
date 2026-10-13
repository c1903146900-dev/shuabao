#!/usr/bin/env python3
"""Copy exact fix01 dependency map to a fresh main-owned stage. Never launch an engine."""
from pathlib import Path
import argparse,json,hashlib,shutil
H=Path(__file__).resolve().parent;R=H.parents[2];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--dest',type=Path,required=True);a=p.parse_args();assert not a.dest.exists()
b=json.loads((H/'source_binding.json').read_text());mapping=b['runtime_map'].copy()
for rel,h in b['files'].items():assert sha(R/rel)==h,rel
rel=(H/'source_binding.json').relative_to(R).as_posix();mapping[rel]={'source':rel,'sha256':sha(H/'source_binding.json')}
for target,e in mapping.items():
 out=a.dest/target;out.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/e['source'],out);assert sha(out)==e['sha256']
(a.dest/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Ink initial Hex sink fix01 finite gate"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
(a.dest/'staging_receipt.json').write_text(json.dumps({'source_binding_sha256':sha(H/'source_binding.json'),'runtime_map':mapping,'author_engine_invocations':0},indent=2)+'\n')
print(json.dumps({'stage':str(a.dest),'files':len(mapping),'binding':sha(H/'source_binding.json')}))
