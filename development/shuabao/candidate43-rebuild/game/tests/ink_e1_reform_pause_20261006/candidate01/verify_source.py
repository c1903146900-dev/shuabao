#!/usr/bin/env python3
"""Narrow actual-byte source audit. Does not launch Godot or claim runtime PASS."""
from pathlib import Path
import hashlib, json, re

D = Path(__file__).resolve().parent
R = D.parents[2]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def relative(path):
    return path.removeprefix('res://')

def verify():
    binding = json.loads((D/'source_binding.json').read_text())
    for field in ('files_sha256', 'frozen_inputs_sha256'):
        for name, digest in binding[field].items():
            assert sha(R/relative(name)) == digest, (field, name)
    sim = (D/'sim.gd').read_text()
    assert sim.splitlines()[0] == 'extends "res://tests/ink_p2_ordinary_20261006/mechanism01/sim.gd"'
    assert 'func _e1_damage_batch(' not in sim, 'original damage pipeline must remain inherited'
    assert '_e1_damage_batch(state,[enemy],segment,amount,work.origin,float(work.at),work.impact)' in sim
    assert sim.count('super._fixed_step(real_dt)') == 1
    for fragment in ('p1.enter(id)', 'p1.leave(id)', '_p2_source_frames.append(frame)',
                     'is_same(_p2_source_frames.back(),frame)', 'or paused or int(work.stage) < 2',
                     '_e1_reform_pending.is_empty() or _e1_reform_draining',
                     'epoch != _e1_reform_epoch', 'real_accumulator += real_dt'):
        assert fragment in sim, fragment
    gate = (D/'finite_gate.gd').read_text()
    assert binding['required_groups'] == ['original_e1_reform_remainder']
    body = gate[gate.index('func run() -> void:'):]
    for group in binding['required_groups']:
        assert f'func {group}() -> void:' in gate and f' {group}()' in body
    assert 'groups.count(group) == 1' in body
    for fragment in ('compare_unpaused()', 'for pause_after: int in [1,3]',
                     'for retirement: String in ["cancel","death","room","rest"]',
                     'for on_resume: bool in [false,true]', 'victory_waits_for_terminal()',
                     'move_during_hitstop(0.02,Vector3.RIGHT)', 'sim._hit_claims.has(key)',
                     'resumed.contact_amounts.size() == resumed.original_amounts.size()'):
        assert fragment in gate, fragment
    for name in ('sim.gd', 'finite_gate.gd', 'parse_gate.gd'):
        text = (D/name).read_text()
        reserved = {'Projection', 'Basis', 'Transform2D', 'Transform3D', 'Vector2', 'Vector3',
                    'Vector4', 'Rect2', 'Plane', 'Quaternion', 'AABB', 'Color', 'Dictionary',
                    'Array', 'Signal', 'Callable', 'String', 'Object', 'Node', 'Resource',
                    'GDScript', 'Script'}
        for identifier in re.findall(r'\b(?:const|var)\s+(\w+)\s*(?::|=)', text):
            assert identifier not in reserved, (name, 'built-in name collision', identifier)
        for identifier in re.findall(r'\bconst\s+(\w+)\s*(?::=|=)\s*preload\("[^\"]+\.gd"\)', text):
            assert not re.search(r'\b'+re.escape(identifier)+r'\.(?:get_base_script|can_instantiate|resource_path)\b', text), (name, 'class constant reflection', identifier)
        for ref in re.findall(r'(?:extends|preload\(|load\()\s*"res://([^\"]+)"', text):
            assert (R/ref).is_file(), (name, ref)
    return {'schema':'ink-e1-reform-source-audit-1', 'source_audit':'PASS',
            'source_binding_sha256':sha(D/'source_binding.json'),
            'candidate_source_files':len(binding['files_sha256']),
            'frozen_runtime_inputs':len(binding['frozen_inputs_sha256']),
            'required_groups':binding['required_groups'], 'godot_parse':'NOT_RUN',
            'finite_runtime':'NOT_RUN', 'native_input':False,
            'ordinary_admission':False, 'production_entry_changed':False}

if __name__ == '__main__':
    print(json.dumps(verify(), ensure_ascii=False, indent=2))
