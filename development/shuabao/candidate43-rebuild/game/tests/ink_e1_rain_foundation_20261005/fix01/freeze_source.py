#!/usr/bin/env python3
"""Bind the author's finished isolated sources; does not run an audit or engine.

Run after ink_e1_sim.gd and finite_gate.gd are final. This never rewrites a frozen
upstream candidate, enables a host capability, or claims test acceptance.
"""
import argparse
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from source_audit import (BINDING_NAMES, CURRENT_MAP, D, FAMILY, FIXTURE_MAP, PINS, R,
                          encode, load, own_source_files, path_at, sha)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--replace-author-owned', action='store_true',
                        help='replace only these new candidate sidecars and reset its source result to NOT_RUN')
    args = parser.parse_args()
    if not args.replace_author_owned and any((D / name).exists() for name in BINDING_NAMES):
        raise SystemExit('Candidate sidecars already exist; no silent re-freeze. Use a new version or explicit --replace-author-owned.')
    for name in ['ink_e1_sim.gd', 'finite_gate.gd', 'source_audit.py', 'prepare_stage.py', 'source_basis.md']:
        if not (D / name).is_file():
            raise SystemExit('Required author source is not ready: ' + name)
    for relative, expected in PINS.items():
        if sha(path_at(R, relative)) != expected:
            raise SystemExit('Fixed upstream changed: ' + relative)
    family = load(FAMILY + 'source_contract.json')
    for relative, expected in family['input_sha256'].items():
        if sha(path_at(R, relative)) != expected:
            raise SystemExit('Protected current source changed: ' + relative)
    current = load(CURRENT_MAP)
    own = own_source_files()
    runtime_map = dict(current['runtime_map'])
    runtime_map.update(FIXTURE_MAP)
    for target, entry in runtime_map.items():
        path_at(R, target)
        if sha(path_at(R, entry['source'])) != entry['sha256']:
            raise SystemExit('Current R/entry.source changed: ' + target)
    for relative, digest in own.items():
        if relative in runtime_map:
            raise SystemExit('Own directory would replace a current mapped source: ' + relative)
        runtime_map[relative] = {'source': relative, 'sha256': digest}
    for relative in own:
        path = path_at(R, relative)
        if path.suffix not in {'.gd', '.gdshader', '.tscn', '.tres'}:
            continue
        for ref in re.findall(r'res://([^"\s]+)', path.read_text(encoding='utf-8')):
            path_at(R, ref)
            if ref.endswith('_result.json') and ref.startswith(D.relative_to(R).as_posix() + '/'):
                continue
            if ref not in runtime_map and ref not in {(D / name).relative_to(R).as_posix() for name in BINDING_NAMES}:
                raise SystemExit('Unmapped dependency; do not silently expand the current chain: ' + ref)
    runtime = {
        'schema_version': 1,
        'scope': 'isolated mechanics-stage map; not a live-binding or host admission manifest',
        'upstream': PINS, 'read_only_fixture_map': FIXTURE_MAP,
        'runtime_candidates': current['runtime_candidates'],
        'source_implemented_hooks': current['source_implemented_hooks'],
        'candidate_mechanics': ['E1', 'H07', 'H08'],
        'candidate_admission': 'DIRECT_FINITE_FIXTURE_ONLY_NOT_HOST',
        'host_capabilities_added': [], 'production_promotion': False,
        'runtime_map': dict(sorted(runtime_map.items())),
        'source_audit': 'NOT_RUN', 'Godot_parse': 'NOT_RUN', 'engine': 'NOT_RUN',
        'runtime': 'NOT_RUN', 'native_input': 'NOT_RUN',
    }
    (D / 'runtime_binding.json').write_text(encode(runtime), encoding='utf-8')
    binding = {
        'schema_version': 1,
        'scope': 'isolated E1/H07/H08 source freeze only; no engine/native/host acceptance',
        'upstream': PINS, 'read_only_fixture_map': FIXTURE_MAP, 'own_files': own,
        'runtime_binding_sha256': sha(D / 'runtime_binding.json'),
        'runtime_map': dict(sorted(runtime_map.items())),
        'host_capabilities_added': [], 'production_promotion': False,
        'source_audit': 'NOT_RUN', 'Godot_parse': 'NOT_RUN', 'engine': 'NOT_RUN',
        'runtime': 'NOT_RUN', 'native_input': 'NOT_RUN',
    }
    (D / 'source_binding.json').write_text(encode(binding), encoding='utf-8')
    result = {
        'schema_version': 1, 'status': 'NOT_RUN', 'passed': None,
        'scope': 'E1/H07/H08 isolated candidate; source binding prepared but not audited',
        'expected_coverage': {'original_paragraphs': 3, 'parameter_ids': 11, 'numeric_cells': 61},
        'source_binding_sha256': sha(D / 'source_binding.json'),
        'runtime_binding_sha256': sha(D / 'runtime_binding.json'),
        'source_audit': 'NOT_RUN', 'Godot_parse': 'NOT_RUN', 'engine': 'NOT_RUN',
        'runtime': 'NOT_RUN', 'native_input': 'NOT_RUN', 'visual': 'NOT_RUN',
        'audio': 'NOT_RUN', 'whole_hero_acceptance': 'NOT_RUN',
        'limitations': {'ordinary_enemy_only_phasing': 'NOT_PASSED_PENDING_TECHNICAL_REVIEW'},
        'full_E1_acceptance': False,
        'host_capabilities_added': [], 'production_promotion': False,
    }
    (D / 'source_result.json').write_text(encode(result), encoding='utf-8')
    print(encode({'status': 'SOURCE_BOUND_NOT_AUDITED', 'source_audit': 'NOT_RUN',
                  'source_binding_sha256': sha(D / 'source_binding.json'),
                  'runtime_binding_sha256': sha(D / 'runtime_binding.json'),
                  'mapped_files': len(runtime_map), 'own_files': len(own),
                  'engine': 'NOT_RUN', 'runtime': 'NOT_RUN', 'production_promotion': False}), end='')


if __name__ == '__main__':
    main()
