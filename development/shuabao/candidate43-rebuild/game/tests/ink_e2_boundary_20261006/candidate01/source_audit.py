#!/usr/bin/env python3
"""Read-only source/pin/closure audit. Does not invoke or parse with Godot."""
import ast
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
REL = HERE.relative_to(ROOT).as_posix()
RESOURCE = re.compile(r'''["']res://([^"'\n]+)["']''')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def path_at(base, relative):
    path = Path(relative)
    if path.is_absolute() or '..' in path.parts:
        raise ValueError('Unsafe relative path: ' + relative)
    result = (base / path).resolve()
    if not result.is_relative_to(base.resolve()):
        raise ValueError('Escaping relative path: ' + relative)
    return result


def audit():
    binding = json.loads((HERE / 'source_binding.json').read_text())
    manifest = json.loads((HERE / 'stage_manifest.json').read_text())
    for group in ['authoring_files', 'preserved_inputs', 'production_sentinels']:
        for relative, expected in binding[group].items():
            if sha(path_at(ROOT, relative)) != expected:
                raise ValueError('Changed ' + group + ': ' + relative)
    for file in HERE.glob('*.py'):
        ast.parse(file.read_text(), filename=str(file))
    records = manifest['runtime_map']
    implicit = set(manifest['metadata_copies'])
    for logical, item in records.items():
        source = path_at(ROOT, item['source'])
        path_at(ROOT, logical)
        if sha(source) != item['sha256'] or source.stat().st_size != item['bytes']:
            raise ValueError('Changed mapped source: ' + logical)
        if source.suffix in ['.gd', '.tscn', '.tres']:
            for dependency in RESOURCE.findall(source.read_text()):
                if dependency not in records and dependency not in implicit:
                    raise ValueError('Unmapped resource: ' + logical + ' -> ' + dependency)
    decision = json.loads((ROOT / binding['decision']['path']).read_text())
    assert decision['rules']['ink_e2_arena_edge']['on_reaching_room_boundary'] == 'stop_and_remain_at_boundary'
    assert binding['decision']['sha256'] == sha(ROOT / binding['decision']['path'])
    source = (HERE / 'sim.gd').read_text()
    assert 'arena_route_outside_fixture' not in source
    assert 'boundary_clock_target = finish' in source
    assert 'super._e2_outward_finished(state,clock_target)' in source
    geometry = (HERE / 'boat_boundary.gd').read_text()
    assert 'Geometry.EPS' not in geometry and 'hero_radius' not in geometry
    return {'schema': 'ink-e2-boundary-source-audit-1', 'status': 'SOURCE_ONLY_VERIFIED',
            'mapped_files': len(records), 'source_binding_sha256': sha(HERE / 'source_binding.json'),
            'stage_manifest_sha256': sha(HERE / 'stage_manifest.json'),
            'python_syntax': 'PASS', 'exact_pins': 'PASS', 'literal_resource_closure': 'PASS',
            'godot_parse': 'NOT_RUN', 'finite_runtime': 'NOT_RUN', 'cua': 'NOT_RUN',
            'blender': 'NOT_RUN', 'uploads': 0, 'production_changed': False,
            'historical_passes_promoted': False, 'ordinary_E2_enabled': False}


if __name__ == '__main__':
    print(json.dumps(audit(), ensure_ascii=False, indent=2))
