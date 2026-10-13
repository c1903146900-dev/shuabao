#!/usr/bin/env python3
"""Copy only pinned E2-boundary resources to a fresh separate stage. No engine."""
import argparse
import json
import shutil
import sys
from pathlib import Path
sys.dont_write_bytecode = True
from source_audit import HERE, ROOT, audit, path_at, sha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', type=Path, required=True)
    stage = parser.parse_args().stage.expanduser().resolve()
    if stage.exists() or stage.is_relative_to(ROOT) or ROOT.is_relative_to(stage):
        raise SystemExit('Require a fresh nonexistent stage separate from production source')
    result = audit()
    manifest = json.loads((HERE / 'stage_manifest.json').read_text())
    copies = dict(manifest['runtime_map'])
    for logical in manifest['metadata_copies']:
        source = path_at(ROOT, logical)
        copies[logical] = {'source': logical, 'sha256': sha(source)}
    for logical, item in copies.items():
        path_at(stage, logical)
        if sha(path_at(ROOT, item['source'])) != item['sha256']:
            raise SystemExit('Preflight source changed: ' + logical)
    stage.mkdir(parents=True)
    for logical, item in copies.items():
        output = path_at(stage, logical)
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path_at(ROOT, item['source']), output)
        if sha(output) != item['sha256']:
            raise SystemExit('Staged readback differs: ' + logical)
    (stage / 'project.godot').write_text(manifest['project_godot'])
    receipt = {'schema': 'ink-e2-boundary-stage-1', 'stage': str(stage),
               'status': 'SOURCE_MATERIALIZED_ONLY', 'copied_files': len(copies),
               'source_binding_sha256': result['source_binding_sha256'],
               'stage_manifest_sha256': result['stage_manifest_sha256'],
               'project_sha256': sha(stage / 'project.godot'),
               'godot': 'NOT_RUN', 'runtime': 'NOT_RUN', 'production_promotion': False}
    (stage / 'staging_receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__':
    main()
