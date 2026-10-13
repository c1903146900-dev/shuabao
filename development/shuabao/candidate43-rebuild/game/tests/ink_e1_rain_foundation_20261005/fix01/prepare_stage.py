#!/usr/bin/env python3
"""Materialize an exact pinned chain into a fresh isolated stage. No engine.

Copies each current-map entry from R / entry.source to its logical destination;
then copies only this new directory's bound sources. No host capability changes.
"""
import argparse
import json
import shutil
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from source_audit import (CURRENT_MAP, D, FIXTURE_MAP, PINS, R, encode, load,
                          own_source_files, path_at, sha)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', type=Path, required=True, help='fresh nonexistent directory outside this repository')
    args = parser.parse_args()
    stage = args.stage.expanduser().resolve()
    if stage.exists():
        raise SystemExit('Fresh nonexistent stage required; refusing overwrite: ' + str(stage))
    if stage == R or stage.is_relative_to(R) or R.is_relative_to(stage):
        raise SystemExit('Stage must be separate from the current repository and its ancestors')
    if 'sandbox' in str(stage).lower():
        raise SystemExit('Sandbox project is outside this task')
    binding = json.loads((D / 'source_binding.json').read_text())
    runtime = json.loads((D / 'runtime_binding.json').read_text())
    if binding['upstream'] != PINS or sha(D / 'runtime_binding.json') != binding['runtime_binding_sha256']:
        raise SystemExit('Candidate binding identity mismatch')
    for relative, expected in PINS.items():
        if sha(path_at(R, relative)) != expected:
            raise SystemExit('Pinned upstream changed: ' + relative)
    current = load(CURRENT_MAP)
    own = own_source_files()
    combined = dict(current['runtime_map'])
    combined.update(FIXTURE_MAP)
    combined.update({rel: {'source': rel, 'sha256': digest} for rel, digest in own.items()})
    if own != binding['own_files'] or binding['runtime_map'] != combined or runtime['runtime_map'] != combined:
        raise SystemExit('Stage source inventory changed; explicit author re-freeze required')
    if runtime.get('read_only_fixture_map') != FIXTURE_MAP or binding.get('read_only_fixture_map') != FIXTURE_MAP:
        raise SystemExit('Explicit read-only fixture map changed')
    if runtime['runtime_candidates'] != current['runtime_candidates'] or runtime['source_implemented_hooks'] != current['source_implemented_hooks']:
        raise SystemExit('Candidate may not widen current host admission')
    if runtime['host_capabilities_added'] != [] or runtime['production_promotion'] is not False:
        raise SystemExit('Candidate is not an isolated unpromoted stage')
    # Validate all source bytes before creating any stage file.
    for target, entry in combined.items():
        path_at(stage, target)
        if sha(path_at(R, entry['source'])) != entry['sha256']:
            raise SystemExit('Bound R/entry.source changed: ' + target)
    if 'project.godot' in combined:
        raise SystemExit('Refusing to replace a mapped project.godot with test harness settings')
    stage.mkdir(parents=True)
    for target, entry in combined.items():
        out = path_at(stage, target)
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path_at(R, entry['source']), out)
        if sha(out) != entry['sha256']:
            raise SystemExit('Staged copy digest mismatch: ' + target)
    for name in ['source_binding.json', 'runtime_binding.json']:
        out = stage / D.relative_to(R) / name
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(D / name, out)
    (stage / 'project.godot').write_text(
        'config_version=5\n[application]\nconfig/name="Ink E1 isolated mechanics gate"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
    # Neither copied historical results nor a materialization receipt are runtime evidence.
    receipt = {
        'schema_version': 1, 'stage': str(stage), 'status': 'SOURCE_MATERIALIZED_ONLY',
        'source_binding_sha256': sha(D / 'source_binding.json'),
        'runtime_binding_sha256': sha(D / 'runtime_binding.json'),
        'current_chain_files': len(current['runtime_map']), 'read_only_fixture_files': len(FIXTURE_MAP), 'own_source_files': len(own),
        'total_mapped_files': len(combined), 'path_resolution': 'R / entry.source -> stage / logical target',
        'engine_invocations': 0, 'imports': 0, 'source_audit': 'NOT_RUN_BY_STAGER',
        'Godot_parse': 'NOT_RUN', 'engine': 'NOT_RUN', 'runtime': 'NOT_RUN',
        'native_input': 'NOT_RUN', 'host_capabilities_added': [], 'production_promotion': False,
    }
    (stage / 'staging_receipt.json').write_text(encode(receipt), encoding='utf-8')
    print(encode(receipt), end='')


if __name__ == '__main__':
    main()
