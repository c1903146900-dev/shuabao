#!/usr/bin/env python3
"""Append only fix01 to an exact existing original stage. No engine or overwrite."""
from pathlib import Path
import argparse,hashlib,json,shutil
F=Path(__file__).resolve().parent;H=F.parent;R=F.parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True);a=p.parse_args()
assert a.stage.is_dir(),'Existing original source stage required'
original=json.loads((H/'source_binding.json').read_text());binding=json.loads((F/'source_binding.json').read_text())
assert sha(H/'source_binding.json')==binding['original_failed_source_binding']
for target,entry in original['runtime_map'].items():
 path=a.stage/target;assert path.is_file() and sha(path)==entry['sha256'],'Original stage changed/missing '+target
assert sha(a.stage/H.relative_to(R)/'source_binding.json')==binding['original_failed_source_binding'],'Original staged identity changed'
for rel,h in binding['files'].items():assert sha(R/rel)==h,'Fixed source changed '+rel
fix_prefix=F.relative_to(R).as_posix()+'/'
outroot=a.stage/F.relative_to(R);assert not outroot.exists(),'Existing fix stages are immutable'
# Every preexisting dependency must already match; write only the new fix subtree.
for target,entry in binding['runtime_map'].items():
 if target.startswith(fix_prefix):continue
 path=a.stage/target;assert path.is_file() and sha(path)==entry['sha256'],'Required original stage identity missing/changed '+target
mapping={k:v for k,v in binding['runtime_map'].items() if k.startswith(fix_prefix)}
for name in ['source_binding.json','authoring_manifest.json','authoring_manifest.sha256','source_result.json']:
 rel=(F/name).relative_to(R).as_posix();mapping[rel]={'source':rel,'sha256':sha(F/name)}
for target,entry in mapping.items():
 path=a.stage/target;path.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/entry['source'],path);assert sha(path)==entry['sha256']
(outroot/'staging_receipt.json').write_text(json.dumps({'source_binding_sha256':sha(F/'source_binding.json'),'original_failed_source_binding':binding['original_failed_source_binding'],'added_map':mapping,'old_stage_sources_overwritten':0,'engine_invocations':0},indent=2)+'\n')
print(json.dumps({'stage':str(a.stage),'added_directory':str(outroot),'added_files':len(mapping),'source_binding_sha256':sha(F/'source_binding.json'),'old_stage_sources_overwritten':0,'engine':'NOT_STARTED'}))
