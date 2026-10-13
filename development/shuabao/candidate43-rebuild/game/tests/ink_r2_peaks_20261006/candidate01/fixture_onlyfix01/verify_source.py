#!/usr/bin/env python3
"""Fixture-only source preflight; retains and rejects the actual parse-red form."""
from pathlib import Path
import hashlib, json, re
D = Path(__file__).resolve().parent
R = D.parents[3]
BASE = D.parent
GROUPS = ['r2_source_admission_schedule','r2_density_locked_footprint',
          'r2_pause_and_retirement','r2_world_clock_and_passives']

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def relative(path):
    return path.removeprefix('res://')

def bad_multiline_closures(text):
    """Check only this fixture's multiline signal-lambda closing indentation."""
    lines = text.splitlines()
    bad = []
    for start, line in enumerate(lines):
        if line != ' sim.combat_event.connect(func(event: Dictionary):':
            continue
        end = start+1
        while end < len(lines) and (lines[end].startswith('  ') or not lines[end].strip()):
            end += 1
        if end >= len(lines) or lines[end] != ' )':
            bad.append(start+1)
    return bad

def expected_fixture(old):
    before = '''  match kind:
   "cancel": sim.cancel_cast(int(result.cast_id))
   "death": sim.damage_hero(100000.0,Vector3.ZERO,0.0,true,true)
   "room": sim.end_encounter("cleared"); sim.begin_encounter("replacement-r2-room",[]))'''
    after = '''  match kind:
   "cancel":
    sim.cancel_cast(int(result.cast_id))
   "death":
    sim.damage_hero(100000.0,Vector3.ZERO,0.0,true,true)
   "room":
    sim.end_encounter("cleared")
    sim.begin_encounter("replacement-r2-room",[])
 )'''
    assert old.count(before) == 1
    text = old.replace(before,after)
    for ending in [
        '  if int(hook.count) == after_count and not hook.fired: hook.fired = true; sim.paused = true)',
        '  if event.kind == "damage" and event.get("source","") == "r2" and not hook.fired: hook.fired = true; sim.paused = true)']:
        assert text.count(ending) == 1
        text = text.replace(ending,ending[:-1]+'\n )')
    return text.replace('res://tests/ink_r2_peaks_20261006/candidate01/source_binding.json',
                        'res://tests/ink_r2_peaks_20261006/candidate01/fixture_onlyfix01/source_binding.json')

def verify():
    binding = json.loads((D/'source_binding.json').read_text())
    for field in ('files_sha256','frozen_inputs_sha256','source_inputs_sha256'):
        for name,digest in binding[field].items():
            assert sha(R/relative(name)) == digest, (field,name)
    changes = json.loads((D/'CHANGE.json').read_text())
    for name,digest in changes['evidence_sha256'].items():
        assert sha(D/name) == digest, name
    raw = (D/'evidence_before/parse_raw.log').read_text()
    assert 'Expected expression for match pattern.' in raw
    assert 'finite_gate.gd:278' in raw
    assert '"passed":false' in raw and '"failures":["res://tests/ink_r2_peaks_20261006/candidate01/finite_gate.gd"]' in raw
    old = (BASE/'finite_gate.gd').read_text()
    current = (D/'finite_gate.gd').read_text()
    assert current == expected_fixture(old), 'more than the explicit fixture-only substitutions'
    assert bad_multiline_closures(old) == [235,272,298], 'original closure counterexamples changed'
    assert bad_multiline_closures(current) == [], 'multiline signal closure remains unsafe'
    assert old.count('\n  match kind:') == current.count('\n  match kind:') == 1
    assert old.count('check(') == current.count('check(')
    assert old.count('near(') == current.count('near(')
    assert binding['required_groups'] == GROUPS
    body = current[current.index('func run() -> void:'):]
    for group in GROUPS:
        assert f'func {group}() -> void:' in current and f' {group}()' in body
    assert 'groups.count(group) == 1' in body
    for name in ('sim.gd','tuning.gd','peak_geometry.gd'):
        assert sha(BASE/name) == changes['unchanged_mechanism_sha256'][name]
    for path in D.glob('*.gd'):
        text = path.read_text()
        reserved = {'Projection','Basis','Transform2D','Transform3D','Vector2','Vector3',
                    'Vector4','Rect2','Plane','Quaternion','AABB','Color','Dictionary',
                    'Array','Signal','Callable','String','Object','Node','Resource','GDScript','Script'}
        for identifier in re.findall(r'\b(?:const|var)\s+(\w+)\s*(?::|=)',text):
            assert identifier not in reserved, (path.name,'built-in name collision',identifier)
        for identifier in re.findall(r'\bconst\s+(\w+)\s*(?::=|=)\s*preload\("[^\"]+\.gd"\)',text):
            assert not re.search(r'\b'+re.escape(identifier)+r'\.(?:get_base_script|can_instantiate|resource_path)\b',text), (path.name,'class constant reflection',identifier)
        for ref in re.findall(r'(?:extends|preload\(|load\()\s*"res://([^\"]+)"',text):
            assert (R/ref).is_file(), (path.name,ref)
    return {'schema':'ink-r2-fixture-onlyfix01-source-audit-1','source_audit':'PASS',
            'source_binding_sha256':sha(D/'source_binding.json'),'required_groups':GROUPS,
            'original_parse':'FAIL','original_finite':'NOT_RUN','original_red_preserved':True,
            'original_bad_closure_counterexamples':bad_multiline_closures(old),
            'new_bad_closure_counterexamples':[], 'assertions_removed':0,
            'mechanism_sources_unchanged':True,'godot_parse':'NOT_RUN','finite_runtime':'NOT_RUN',
            'native_input':False,'ordinary_admission':False,'production_entry_changed':False}

if __name__ == '__main__':
    print(json.dumps(verify(),ensure_ascii=False,indent=2))
