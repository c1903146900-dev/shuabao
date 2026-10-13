#!/usr/bin/env python3
"""Verify the full frozen Rest/P1/R1 closure plus exact E2 donors; no engine."""
from pathlib import Path
import ast, hashlib, importlib.util, json, re
D = Path(__file__).resolve().parent
R = D.parents[2]
ADAPTER = 'res://scripts/integration/yanguizhou_first_floor.gd'
REST = 'tests/ink_rest_service_20261006/candidate01/ordinary01/source_binding.json'
BOUNDARY = 'tests/ink_e2_boundary_20261006/candidate01/source_binding.json'
REST_SHA = 'e32a9951aa51f970ce85b84d956f4da9ca3f9f10c1997ffed9a8af89c4e971fc'
BOUNDARY_SHA = 'c91e4c0ba04d2c4bf50387249a1074b20d2b188b031ec7f50b4e2e9da34cbe01'
BEFORE = '8509e03edea0bbc5df7f063431ee637713d44673223eeac34869b63be0650801'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def relative(path):
    p = Path(path.removeprefix('res://'))
    assert not p.is_absolute() and '..' not in p.parts and '.godot' not in p.parts
    return p
def parents():
    assert sha(R/REST) == REST_SHA and sha(R/BOUNDARY) == BOUNDARY_SHA
    spec = importlib.util.spec_from_file_location('frozen_rest_audit', R/Path(REST).parent/'verify_source.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    old, closure, aliases = module.collect()
    assert closure[str(relative(ADAPTER))] == BEFORE
    pins = {'res://'+REST: REST_SHA,'res://'+BOUNDARY: BOUNDARY_SHA}
    pins.update({'res://'+str(relative(p)):h for p,h in old['parent_bindings'].items()})
    boundary = json.loads((R/BOUNDARY).read_text())
    def add(path,digest):
        key = str(relative(path))
        assert key not in closure or closure[key] == digest, 'Conflicting frozen source: '+key
        closure[key] = digest
    for field in ['authoring_files','preserved_inputs','production_sentinels']:
        for path,digest in boundary[field].items(): add(path,digest)
    stage = json.loads((R/'tests/ink_e2_boundary_20261006/candidate01/stage_manifest.json').read_text())
    for path,item in stage['runtime_map'].items():
        add(path,item['sha256'])
        if path != item['source']:
            assert path not in aliases or aliases[path] == item['source']
            aliases[path] = item['source']
    for path,digest in pins.items(): add(path,digest)
    return old,closure,aliases,pins
def expected():
    old,closure,aliases,pins = parents()
    closure[str(relative(ADAPTER))] = sha(R/relative(ADAPTER))
    for path in sorted(D.rglob('*')):
        if path.is_file() and '__pycache__' not in path.parts and path.name not in ['source_binding.json','source_audit_result.json']:
            closure[str(path.relative_to(R))] = sha(path)
    return old,closure,aliases,pins
def collect():
    b = json.loads((D/'source_binding.json').read_text())
    old,closure,aliases,pins = expected()
    assert b['runtime_map'] == {'res://'+p:h for p,h in sorted(closure.items())}, 'Exact complete runtime map changed'
    assert b['parent_bindings'] == pins
    assert b['source_aliases'] == aliases
    assert b['ancestor_pin_replacements'] == {ADAPTER:{'before':BEFORE,'after':closure[str(relative(ADAPTER))],'scope':'first extends line only'}}
    return b,closure,aliases
def verify():
    b,closure,aliases = collect()
    assert b['runtime_candidates'] == ['Q1','Q2','Q3','E1','E2','P1','R1']
    assert len(b['supported_hex_hooks']) == 10 and not any('h09' in h or 'h10' in h for h in b['supported_hex_hooks'])
    for path,digest in closure.items():
        assert sha(R/relative(aliases.get(path,path))) == digest, 'Runtime source changed: '+path
    pre = json.loads((D/'preimage_manifest.json').read_text())
    for path,digest in pre['production_files'].items():
        assert sha(D/'preimage_production'/path) == digest
        if 'res://'+path != ADAPTER: assert sha(R/path) == digest, 'Production scope exceeded: '+path
    before = (D/'preimage_production'/relative(ADAPTER)).read_text().splitlines()
    after = (R/relative(ADAPTER)).read_text().splitlines()
    assert before[1:] == after[1:] and after[0] == 'extends "res://tests/ink_e2_boundary_20261006/ordinary01/host.gd"'
    for entry in pre['transplants']:
        src=(R/entry['source']).read_text().splitlines(); dst=(R/entry['destination']).read_text().splitlines()
        assert src[1:] == dst[1:] and dst[0] == 'extends "'+entry['parent']+'"', 'E2 donor beyond inheritance changed'
    for path in D.glob('*.py'): ast.parse(path.read_text(),filename=str(path))
    for path in D.glob('*.gd'):
        methods=re.findall(r'^func (\w+)\(',path.read_text(),re.M)
        assert len(methods) == len(set(methods)), 'Duplicate local methods: '+path.name
    finite=(D/'finite_gate.gd').read_text()
    for group in b['required_groups']: assert 'groups.append("'+group+'")' in finite
    assert b['native_input'] is False and b['historical_matrices_rerun'] is False
    return {'status':'E2_ORDINARY_SOURCE_IDENTITY_PASS','passed':True,'binding_sha256':sha(D/'source_binding.json'),'closure_files':len(closure),'parse':'NOT_RUN','finite':'NOT_RUN','native_input':False,'engine_invocations':0}
if __name__ == '__main__': print(json.dumps(verify(),ensure_ascii=False,indent=2))
