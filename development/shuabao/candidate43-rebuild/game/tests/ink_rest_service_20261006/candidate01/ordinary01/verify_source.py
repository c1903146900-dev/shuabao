#!/usr/bin/env python3
"""Exact Rest ordinary closure audit. Reads bytes only; never invokes Godot."""
from pathlib import Path
import ast, hashlib, json, re
D = Path(__file__).resolve().parent
R = D.parents[3]
ADAPTER = 'res://scripts/integration/yanguizhou_first_floor.gd'
REPLACEABLE = {ADAPTER, 'res://scripts/ui/hero_chooser.gd'}
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def relative(path):
    result = Path(path.removeprefix('res://'))
    if result.is_absolute() or '..' in result.parts or '.godot' in result.parts:
        raise ValueError('Invalid source path: ' + path)
    return result

def collect():
    b = json.loads((D/'source_binding.json').read_text())
    manifests = {}
    for path, digest in b['parent_bindings'].items():
        assert sha(R/relative(path)) == digest, 'Frozen binding changed: ' + path
        manifests[path] = json.loads((R/relative(path)).read_text())
    p1 = manifests['tests/ink_p1_ordinary_20261006/candidate01/ordinary01/source_binding.json']
    rest = manifests['tests/ink_rest_service_20261006/candidate01/source_binding.json']
    r1 = manifests['tests/ink_r1_ordinary_20261005/candidate01/ordinary01/source_binding.json']
    e1 = manifests['tests/ink_e1_ordinary_20261005/candidate01/source_binding.json']
    q2 = manifests['tests/ink_q2_ordinary_20261005/candidate01/source_binding.json']
    assert b['runtime_candidates'] == p1['runtime_candidates'] == ['Q1','Q2','Q3','E1','P1','R1']
    assert b['supported_hex_hooks'] == p1['supported_hex_hooks'] and len(b['supported_hex_hooks']) == 10
    assert set(b['ancestor_pin_replacements']) == {ADAPTER}, 'Rest may replace only production adapter'
    assert b['ancestor_pin_replacements'][ADAPTER]['before'] == p1['runtime_map'][ADAPTER]
    closure, aliases = {}, {}
    def add(path, digest):
        target = str(relative(path))
        assert target not in closure or closure[target] == digest, 'Conflicting exact pin: ' + target
        closure[target] = digest
    def checked_map(mapped, successors):
        for path, digest in mapped.items():
            for successor in successors:
                change = successor.get('ancestor_pin_replacements', {}).get(path)
                if change:
                    assert path in REPLACEABLE and change['before'] == digest and change['after'] == successor['runtime_map'][path], 'Invalid replacement chain: ' + path
                    digest = change['after']
            add(path, digest)
    checked_map(b['runtime_map'], [])
    checked_map(p1['runtime_map'], [b])
    checked_map(r1['runtime_map'], [p1,b])
    checked_map(e1['runtime_map'], [r1,p1,b])
    checked_map(q2['runtime_map'], [e1,r1,p1,b])
    checked_map({'res://'+p:h for p,h in rest['parent_pins'].items()}, [b])
    for path,digest in rest['candidate_files'].items(): add(path,digest)
    for label in ['tests/ink_p1_ordinary_20261006/candidate01/source_binding.json','tests/ink_p1_ordinary_20261006/candidate01/lifesteal01/source_binding.json']:
        doc = manifests[label]
        for key in ['candidate_files','extra_reused_sources','frozen_parent_pins']:
            for path,digest in doc.get(key,{}).items(): add(path,digest)
    core = manifests['tests/ink_r1_ordinary_20261005/candidate01/source_binding.json']
    for name,digest in core['candidate_files'].items(): add('tests/ink_r1_ordinary_20261005/candidate01/'+name,digest)
    for path,digest in e1['parent_runtime_maps'].items():
        add(path,digest)
        assert sha(R/relative(path)) == digest, 'Parent runtime map changed: ' + path
        doc = json.loads((R/relative(path)).read_text())
        for target,item in doc['runtime_map'].items(): add(target,item['sha256'])
    # Retain the full already-staged renderer/runtime closure, including the two
    # documented source aliases. No cache/import artifacts enter the stage plan.
    stage = manifests['tests/ink_e1_ordinary_20261005/candidate01/stage_receipt.json']
    checked_map({'res://'+p:item['sha256'] for p,item in stage['closure'].items()}, [r1,p1,b])
    for target,item in stage['closure'].items():
        if target != item['source']: aliases[target] = item['source']
    for path,digest in b['parent_bindings'].items(): add(path,digest)
    add(str((D/'source_binding.json').relative_to(R)),sha(D/'source_binding.json'))
    return b, closure, aliases

def verify():
    b,closure,aliases = collect()
    for path,digest in closure.items():
        assert sha(R/relative(aliases.get(path,path))) == digest, 'Source closure changed: ' + path
    pre = json.loads((D/'preimage_manifest.json').read_text())
    for path,digest in pre['production_files'].items():
        assert sha(D/'preimage_production'/path) == digest, 'Production preimage changed: ' + path
        if 'res://'+path != ADAPTER: assert sha(R/path) == digest, 'Unchanged production leaf moved: ' + path
    old = (D/'preimage_production'/relative(ADAPTER)).read_text()
    now = (R/relative(ADAPTER)).read_text()
    assert old.splitlines()[1:] == now.splitlines()[1:], 'Production methods changed'
    assert now.splitlines()[0] == 'extends "res://tests/ink_rest_service_20261006/candidate01/ordinary01/host.gd"'
    original = (R/'tests/ink_p1_ordinary_20261006/candidate01/ordinary01/bridge.gd').read_text()
    leaf = (D/'bridge.gd').read_text()
    assert original[original.index('func initialize_runtime_fixture('):].replace('VerifiedBinding.read_capabilities','RestOrdinaryBinding.read_capabilities') == leaf[leaf.index('func initialize_runtime_fixture('):], 'Bridge startup changed beyond exact admission selection'
    original_nav = (R/'tests/ink_p1_ordinary_20261006/candidate01/ordinary01/navigation_install.gd').read_text()
    assert original_nav.replace('res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/live_binding.gd','res://tests/ink_rest_service_20261006/candidate01/ordinary01/live_binding.gd') == (D/'navigation_install.gd').read_text(), 'Navigation changed beyond Binding selection'
    for path in D.glob('*.py'): ast.parse(path.read_text(),filename=str(path))
    for path in D.glob('*.gd'):
        text = path.read_text(); methods = re.findall(r'^func (\w+)\(',text,re.M)
        assert len(methods) == len(set(methods)), 'Duplicate method: '+path.name
        assert not re.search(r'\b(?:Production|FixtureHost|Session|Finite|OldSim)\.(?:resource_path|get_base_script|can_instantiate)',text), 'Untyped class reflection: '+path.name
    finite = (D/'finite_gate.gd').read_text()
    for group in b['required_groups']: assert 'groups.append("'+group+'")' in finite, 'Required group absent: '+group
    assert 'frontdoor_suspend()' in finite and 'frontdoor_resume()' in finite and '_create_session_controls()' in finite
    assert b['service_85_matrix_rerun'] is False and b['native_input'] is False and b['flask_consumer_opened'] is False
    return {'status':'REST_ORDINARY_SOURCE_TEXT_IDENTITY_PASS','passed':True,'closure_files':len(closure),'binding_sha256':sha(D/'source_binding.json'),'production_sha256':sha(R/relative(ADAPTER)),'engine_invocations':0,'parse':'NOT_RUN','finite':'NOT_RUN','native_input':False}
if __name__ == '__main__':
    print(json.dumps(verify(),ensure_ascii=False,indent=2))
