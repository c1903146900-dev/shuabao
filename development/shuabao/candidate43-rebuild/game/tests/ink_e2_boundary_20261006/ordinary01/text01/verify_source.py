#!/usr/bin/env python3
"""Presentation-only closure check. No engine, gameplay replay or new framework."""
from pathlib import Path
import ast,hashlib,json,re
D=Path(__file__).resolve().parent
R=D.parents[3]
P=D.parent
PARENT_SHA='b0c0ffe609fe3e0170614b6be4bb0b441f97ea3f6ad07b6f989d4dfa7df5bdd5'
ADAPTER='res://scripts/integration/yanguizhou_first_floor.gd'
CHOOSER='res://scripts/ui/hero_chooser.gd'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def relative(path):
    p=Path(path.removeprefix('res://'))
    assert not p.is_absolute() and '..' not in p.parts and '.godot' not in p.parts
    return p
def expected():
    assert sha(P/'source_binding.json')==PARENT_SHA
    parent=json.loads((P/'source_binding.json').read_text())
    mapped=dict(parent['runtime_map'])
    changes={}
    for path in [ADAPTER,CHOOSER]:
        changes[path]={'before':mapped[path],'after':sha(R/relative(path)),'scope':'presentation_only'}
        mapped[path]=changes[path]['after']
    mapped['res://'+str((P/'source_binding.json').relative_to(R))]=PARENT_SHA
    for file in sorted(D.rglob('*')):
        if file.is_file() and '__pycache__' not in file.parts and file not in [D/'source_binding.json',D/'source_audit_result.json']:
            mapped['res://'+str(file.relative_to(R))]=sha(file)
    return parent,mapped,changes
def collect():
    b=json.loads((D/'source_binding.json').read_text())
    parent,mapped,changes=expected()
    assert b['runtime_map']==dict(sorted(mapped.items()))
    assert b['ancestor_pin_replacements']==changes
    assert b['runtime_candidates']==parent['runtime_candidates']
    assert b['supported_hex_hooks']==parent['supported_hex_hooks']
    assert b['source_aliases']==parent['source_aliases']
    return b,mapped,parent['source_aliases']
def verify():
    b,mapped,aliases=collect()
    for path,digest in mapped.items():
        source=aliases.get(str(relative(path)),str(relative(path)))
        assert sha(R/relative(source))==digest,'Exact source changed: '+path
    pre=json.loads((D/'preimage_manifest.json').read_text())
    for path,digest in pre['files'].items():
        assert sha(D/'preimage_native01'/path)==digest
        if 'res://'+path not in [ADAPTER,CHOOSER]: assert sha(R/path)==digest,'Native-tested source changed: '+path
    before=(D/'preimage_native01'/relative(ADAPTER)).read_text().splitlines()
    after=(R/relative(ADAPTER)).read_text().splitlines()
    assert before[1:]==after[1:] and after[0]=='extends "res://tests/ink_e2_boundary_20261006/ordinary01/text01/host.gd"'
    chooser=(R/relative(CHOOSER)).read_text()
    assert 'button.tooltip_text = hero_note(hero_id)' in chooser and 'note_label.text = hero_note(hero_id)' in chooser
    assert 'skill_label.text = InkRuntimeText.skill_line()' in chooser and '休息节点暂不恢复生命' not in chooser
    bridge=(P/'bridge.gd').read_text().replace('BoatOrdinaryBinding','TextBinding').replace('res://tests/ink_e2_boundary_20261006/ordinary01/live_binding.gd','res://tests/ink_e2_boundary_20261006/ordinary01/text01/live_binding.gd')
    assert bridge==(D/'bridge.gd').read_text(),'Bridge changed beyond exact Binding selection'
    nav=(P/'navigation_install.gd').read_text().replace('res://tests/ink_e2_boundary_20261006/ordinary01/live_binding.gd','res://tests/ink_e2_boundary_20261006/ordinary01/text01/live_binding.gd')
    assert nav==(D/'navigation_install.gd').read_text(),'Navigation body changed'
    text=(D/'runtime_text.gd').read_text()
    assert 'RuntimeCatalog.FIRST_SLICE_ALLOWED_CANDIDATES' in text and 'if skill not in RuntimeCatalog.FIRST_SLICE_ALLOWED_CANDIDATES: return description' in text
    assert not any(token in text for token in ['request_action(','.step(','.heal(','.damage_enemy(','set_hexes('])
    finite=(D/'finite_gate.gd').read_text()
    for group in b['required_groups']: assert 'groups.append("'+group+'")' in finite
    for path in D.glob('*.py'): ast.parse(path.read_text())
    for path in D.glob('*.gd'):
        names=re.findall(r'^func (\w+)\(',path.read_text(),re.M)
        assert len(names)==len(set(names))
    assert b['text_only'] and not b['mechanic_matrices_rerun'] and not b['native_input']
    return {'status':'E2_TEXT_SOURCE_PASS','passed':True,'binding_sha256':sha(D/'source_binding.json'),'closure_files':len(mapped),'unchanged_parent_runtime_except_two_presentation_leaves':True,'engine_invocations':0,'parse':'NOT_RUN','finite':'NOT_RUN'}
if __name__=='__main__': print(json.dumps(verify(),ensure_ascii=False,indent=2))
