#!/usr/bin/env python3
"""Narrow byte/source preflight. Does not launch an engine or prove runtime."""
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as ET
import hashlib, json, re

D = Path(__file__).resolve().parent
R = D.parents[2]
GROUPS = ['r2_source_admission_schedule', 'r2_density_locked_footprint',
          'r2_pause_and_retirement', 'r2_world_clock_and_passives']

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def relative(path):
    return path.removeprefix('res://')

def verify():
    binding = json.loads((D/'source_binding.json').read_text())
    for field in ('files_sha256', 'frozen_inputs_sha256', 'source_inputs_sha256'):
        for name, digest in binding[field].items():
            assert sha(R/relative(name)) == digest, (field, name)
    table = json.loads((R/'data/combat/ink_r2_peak_authoring.json').read_text())
    catalog = json.loads((R/'data/final_design/catalog.json').read_text())['heroes']['yanguizhou']
    decision = json.loads((R/'docs/source_decisions/20261006-ink-five-resolutions.json').read_text())
    assert table['user_peak_counts'] == decision['rules']['ink_r2_mountain_eruptions']['base_peak_count_by_rank'] == [7,9,13,20]
    for field, token in table['authority']['original_tokens'].items():
        assert catalog['skills']['R2']['parameters'][token]['values'] == table['retained_original'][field]
    assert catalog['hexes']['H15']['parameters']['H15-1']['values'] == [25]
    assert catalog['hexes']['H15']['parameters']['H15-2']['values'] == [30]
    assert catalog['hexes']['H16']['parameters']['H16-1']['values'] == [4]
    assert catalog['hexes']['H16']['parameters']['H16-2']['values'] == [0.4]
    assert catalog['hexes']['H16']['parameters']['H16-3']['values'] == [50]
    ns = {'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    doc = ET.fromstring(ZipFile(R/'data/final_design/sources/heroes_mechanics_no_values_v03(1).docx').read('word/document.xml'))
    paragraphs = doc.findall('.//w:body//w:p',ns)
    original = ''.join(t.text or '' for t in paragraphs[86].findall('.//w:t',ns))
    assert original == catalog['skills']['R2']['template'], 'DOCX paragraph 87 differs'
    # XML-only original worksheet check; no openpyxl requirement in runtime stage.
    with ZipFile(R/'data/final_design/sources/heroes_balance_values_v03(1).xlsx') as archive:
        main_ns = {'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
        relationships = ET.fromstring(archive.read('xl/_rels/workbook.xml.rels'))
        rels = {item.attrib['Id']:item.attrib['Target'] for item in relationships}
        book = ET.fromstring(archive.read('xl/workbook.xml'))
        sheet = next(x for x in book.findall('s:sheets/s:sheet',main_ns) if x.attrib['name']=='晏归舟技能')
        rel_id = sheet.attrib['{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id']
        target = rels[rel_id]
        entry = target.lstrip('/') if target.startswith('/') else 'xl/'+target
        xml = ET.fromstring(archive.read(entry))
        cells = {x.attrib['r']:x.findtext('s:v',namespaces=main_ns) for x in xml.findall('.//s:c',main_ns)}
        for number in range(1,13):
            values = [float(cells[f'{col}{86+number}']) for col in 'EFGH']
            assert values == catalog['skills']['R2']['parameters'][f'R2-{number}']['values']
    sim = (D/'sim.gd').read_text()
    geometry = (D/'peak_geometry.gd').read_text()
    assert sim.splitlines()[0] == 'extends "res://tests/ink_e1_reform_pause_20261006/candidate01/sim.gd"'
    assert sim.count('super._fixed_step(real_dt)') == 1
    for forbidden in ('Engine.time_scale','start_presentation(', 'Timer.new(', '_e3_point_legal(', 'func damage_enemy(', 'clock.world_time +=', 'hero_time +='):
        assert forbidden not in sim, forbidden
    for fragment in ('"born_at":clock.world_time', '"r2",int(state.cast_id),false,false,metadata)',
                     'work.cursor = int(work.cursor)+1', 'state.work = {}; state.cursor = int(state.cursor)+1',
                     'if not _r2_current(state) or paused: return', 'is_same(enemy,enemy_by_id',
                     'seen[str(enemy.actor_id)] = true', 'state.cast_finished = true',
                     'state.rollups = int(state.rollups)+1', 'not ink_peaks.is_empty() or _r2_draining',
                     'epoch != _r2_epoch', 'real_accumulator += real_dt'):
        assert fragment in sim, fragment
    assert 'Vector2(' not in geometry and 'ROUND_EPS' not in geometry
    assert 'return dx*dx+dz*dz <= radius*radius' in geometry
    assert 'if dx*dx+dz*dz > sum_radius*sum_radius: return false' in geometry
    assert '64.0*DOUBLE_EPSILON*scale*scale' in geometry
    gate = (D/'finite_gate.gd').read_text()
    assert binding['required_groups'] == GROUPS
    body = gate[gate.index('func run() -> void:'):]
    for group in GROUPS:
        assert f'func {group}() -> void:' in gate and f' {group}()' in body
    assert 'groups.count(group) == 1' in body
    for fragment in ('for rank: int in range(1,5)', '10.000000953674316',
                     '1.5588457', 'for after_count: int in [1,2]',
                     'for kind: String in ["cancel","death","room"]',
                     'replacement.actor_id = old.actor_id', 'fill_p2(sim)',
                     'for parent: bool in [true,false]', 'move_during_hitstop(0.2,Vector3.RIGHT)'):
        assert fragment in gate, fragment
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
    return {'schema':'ink-r2-peaks-source-audit-1','source_audit':'PASS',
            'source_binding_sha256':sha(D/'source_binding.json'),
            'candidate_source_files':len(binding['files_sha256']),
            'frozen_runtime_inputs':len(binding['frozen_inputs_sha256']),
            'source_inputs':len(binding['source_inputs_sha256']),
            'original_docx_and_xlsx_match':True,'required_groups':GROUPS,
            'godot_parse':'NOT_RUN','finite_runtime':'NOT_RUN','native_input':False,
            'ordinary_admission':False,'production_entry_changed':False,'balance_accepted':False}

if __name__ == '__main__':
    print(json.dumps(verify(),ensure_ascii=False,indent=2))
