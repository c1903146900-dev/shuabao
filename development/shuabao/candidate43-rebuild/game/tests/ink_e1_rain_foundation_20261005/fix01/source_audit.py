#!/usr/bin/env python3
"""Source-only E1/H07/H08 oracle. Run explicitly; never launches an engine.

Default is read-only. --write records this invocation in source_result.json only.
A source PASS is not a Godot parse, runtime, input, host or production acceptance.
"""
import argparse
import ast
import hashlib
import json
import posixpath
import re
import sys
from pathlib import Path, PurePosixPath
from zipfile import ZipFile
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True
D = Path(__file__).resolve().parent
R = D.parents[2]
FAMILY = 'tests/ink_e_family_contracts_20261005/'
CURRENT_MAP = 'tests/ink_q3_input_growth_20261004/runtime_binding.json'
HOST_MAP = 'tests/ink_normal_floor_host_20261004/source_binding.json'
DOCX = 'data/final_design/sources/heroes_mechanics_no_values_v03(1).docx'
XLSX = 'data/final_design/sources/heroes_balance_values_v03(1).xlsx'
PINS = {
    DOCX: '21cf67cc0ed3d020831d23ef2cb31c5fca5d8fa8ca3f429e1415df608c9405fb',
    XLSX: '33b3c40ab4417519a4ea412a20fb54fc2bd8995ec148abd19f8e71f29d3ed894',
    CURRENT_MAP: 'ba92830cf08fb056a23e831e1b86f1ab398feb81e5f36680d7cf97aa90c06504',
    HOST_MAP: 'a8caaa02f737908dc5eb48ce5dbecfac9904e2cbd579402b0971e87648f1af4e',
    FAMILY + 'CONTRACT.md': '9e146323125e3b668f607c5b617556988e0a365ca595f747cea2870262b28b78',
    FAMILY + 'SOURCE_INDEX.md': '354fa163cbf4aae49b8568ec606d4c4669d378be435ddd23081bb54f45c12cd6',
    FAMILY + 'source_contract.json': '9b3fe4d318e25a2257384023666b7a8f0314aed834b2756df62a25588dccc342',
    FAMILY + 'implementation_contract.json': '17b580da8d6ca1e1b6443a17fc5e199ec39e66ce249de169363d58af1c74422e',
}
PINS.update(json.loads((D / 'failed_parent_pins.json').read_text())['files'])
FIXTURE_MAP = json.loads((D / 'fixture_dependencies.json').read_text())['runtime_map']
if set(FIXTURE_MAP) != {'tests/ink_q3_input_growth_20261004/live_binding.gd', CURRENT_MAP}:
    raise ValueError('Only exact read-only negative-admission fixture dependencies are permitted')
PINS.update({entry['source']: entry['sha256'] for entry in FIXTURE_MAP.values()})
W = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
S = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
REL = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
PARAGRAPHS = {
    'E1': (73, '按住E化作烟雨墨点，最长持续[E1-1]秒；期间无法普通攻击、无法使用Q/R，可以移动并穿过普通敌人，获得[E1-2]%减伤和[E1-3]%移动速度。穿过敌人时为其留下「雨痕」，每名敌人每次施法最多获得[E1-4]层。松开E或持续结束时聚形，对自身半径[E1-5]米内的敌人造成[E1-6]+[E1-7]%AP普通伤害；带有雨痕的敌人额外受到[E1-8]+[E1-9]%AP普通伤害。基础冷却[E1-10]秒。'),
    'H07': (95, 'H07｜竹杖芒鞋　「一蓑烟雨」可在被控制时使用；进入烟雨时解除已有减速与控制。'),
    'H08': (96, 'H08｜也无风雨　进入「一蓑烟雨」后的[H08-1]秒内，不受到任何伤害。'),
}
# Independent literal oracle: token, worksheet row, label, unit, all ranks.
E1_ROWS = [
    ('E1-1', 35, '烟雨最长持续', '秒', [2.5, 2.54, 2.6, 2.7, 2.83, 3]),
    ('E1-2', 36, '最终减伤', '%', [70, 71, 72, 74, 77, 80]),
    ('E1-3', 37, '移动速度加成', '%', [35, 37, 39, 43, 48, 55]),
    ('E1-4', 38, '每敌雨痕上限', '层', [1, 1, 1, 1, 1, 1]),
    ('E1-5', 39, '聚形爆炸半径', '米', [2.5, 2.57, 2.68, 2.86, 3.1, 3.4]),
    ('E1-6', 40, '聚形固定伤害', '点', [40, 53, 72, 104, 147, 200]),
    ('E1-7', 41, '聚形AP系数', '%AP', [55, 58, 63, 71, 82, 95]),
    ('E1-8', 42, '雨痕固定追加伤害', '点', [20, 27, 38, 56, 80, 110]),
    ('E1-9', 43, '雨痕AP系数', '%AP', [30, 32, 36, 42, 50, 60]),
    ('E1-10', 44, '基础冷却', '秒', [17, 16.72, 16.3, 15.6, 14.65, 13.5]),
]
E1_RULES = {
    'rain_mark_bonus_targets': 'marked_by_this_cast_and_inside_final_reform_explosion_radius',
    'radius_parameter': 'E1-5', 'bonus_damage_parameters': ['E1-8', 'E1-9'],
    'outside_radius_mark_bonus': False,
    'mark_cleanup': 'clear_all_marks_of_this_cast_after_reform_settlement',
    'new_tracking_range': False, 'original_source_numbers': 'unchanged',
}
RESULT_NAMES = {'source_result.json', 'finite_result.json', 'runtime_result.json',
                'engine_result.json', 'staging_receipt.json'}
SOURCE_SUFFIXES = {'.gd', '.gdshader', '.tscn', '.tres', '.py', '.md', '.json', '.svg', '.png'}
BINDING_NAMES = {'source_binding.json', 'runtime_binding.json'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def encode(value):
    return json.dumps(value, ensure_ascii=False, indent=2) + '\n'


def path_at(root, relative):
    """Reject traversal, alternate projects and symlink escape before reading."""
    rel = PurePosixPath(relative)
    if rel.is_absolute() or not relative or any(p in ('..', '.') for p in rel.parts):
        raise ValueError('unsafe source path: ' + relative)
    if 'sandbox' in relative.lower():
        raise ValueError('sandbox is outside this task: ' + relative)
    result = root / Path(*rel.parts)
    if not result.resolve().is_relative_to(root.resolve()):
        raise ValueError('source escaped approved root: ' + relative)
    return result


def load(relative):
    return json.loads(path_at(R, relative).read_text(encoding='utf-8'))


def own_source_files():
    parent_runtime = [D.parent / name for name in ['ink_e1_sim.gd', 'input_adapter.gd', 'rain_actor.gd', 'rain_common_bridge.gd']]
    files = parent_runtime + [p for p in D.rglob('*') if p.is_file()]
    return {p.relative_to(R).as_posix(): sha(p) for p in sorted(files)
            if p.is_file() and '__pycache__' not in p.parts
            and p.suffix in SOURCE_SUFFIXES
            and p.name not in RESULT_NAMES | BINDING_NAMES
            and not p.name.endswith('_result.json')}


def workbook_cells(path):
    """Decode OOXML values directly, without openpyxl/importer side effects."""
    with ZipFile(path) as archive:
        shared = []
        if 'xl/sharedStrings.xml' in archive.namelist():
            shared = [''.join(t.text or '' for t in si.findall('.//s:t', S))
                      for si in ET.fromstring(archive.read('xl/sharedStrings.xml')).findall('s:si', S)]
        rels = {r.attrib['Id']: r.attrib['Target']
                for r in ET.fromstring(archive.read('xl/_rels/workbook.xml.rels'))}
        result = {}
        for sheet in ET.fromstring(archive.read('xl/workbook.xml')).findall('s:sheets/s:sheet', S):
            target = rels[sheet.attrib['{' + REL + '}id']]
            part = target.lstrip('/') if target.startswith('/') else posixpath.normpath('xl/' + target)
            cells = {}
            for cell in ET.fromstring(archive.read(part)).findall('.//s:sheetData/s:row/s:c', S):
                node = cell.find('s:v', S)
                kind = cell.attrib.get('t', 'n')
                if kind == 's':
                    value = shared[int(node.text)] if node is not None else None
                elif kind == 'inlineStr':
                    value = ''.join(t.text or '' for t in cell.findall('.//s:t', S))
                elif kind == 'n' and node is not None:
                    value = float(node.text)
                    value = int(value) if value.is_integer() else value
                else:
                    value = node.text if node is not None else None
                cells[cell.attrib['r']] = {'value': value, 'formula': cell.find('s:f', S) is not None}
            result[sheet.attrib['name']] = cells
    return result


def audit():
    checks = []
    def check(ok, label):
        checks.append({'passed': bool(ok), 'label': label})
        if not ok:
            raise AssertionError(label)

    for rel, digest in PINS.items():
        check(sha(path_at(R, rel)) == digest, 'fixed source identity: ' + rel)
    family = load(FAMILY + 'source_contract.json')
    protected = dict(family['input_sha256'])
    protected.update(PINS)
    before = {rel: sha(path_at(R, rel)) for rel in sorted(protected)}
    check(before == protected, 'all protected original/current files retain their expected bytes')
    maps = {}
    for rel, count in [(CURRENT_MAP, 214), (HOST_MAP, 524)]:
        binding = load(rel)
        maps[rel] = binding
        check(len(binding['runtime_map']) == count, 'exact mapped source count: ' + rel)
        for target, entry in binding['runtime_map'].items():
            path_at(R, target)  # Validate destination, but never hash this alias.
            check(sha(path_at(R, entry['source'])) == entry['sha256'],
                  'mapped R/entry.source bytes: ' + target + ' <- ' + entry['source'])
    current = maps[CURRENT_MAP]
    for target, entry in FIXTURE_MAP.items():
        check(maps[HOST_MAP]['runtime_map'].get(target) == entry,
              'exact host-pinned read-only fixture source: ' + target)
        check(target not in current['runtime_map'], 'fixture is explicit and does not replace current mapped source: ' + target)
    check(current['runtime_candidates'] == ['Q1', 'Q3'], 'frozen current Q1/Q3 admission unchanged')
    check(len(current['source_implemented_hooks']) == 10, 'current ten hooks remain unchanged')
    check(all('yanguizhou_h07' not in h and 'yanguizhou_h08' not in h
              for h in current['source_implemented_hooks']), 'no H07/H08 host admission')

    hero = load('data/final_design/catalog.json')['heroes']['yanguizhou']
    check(len(hero['skills']) == 11 and len(hero['hexes']) == 16, 'retain all eleven/sixteen source definitions')
    with ZipFile(path_at(R, DOCX)) as archive:
        paragraphs = ET.fromstring(archive.read('word/document.xml')).findall('.//w:body//w:p', W)
        comments = {c.attrib['{' + W['w'] + '}id']: ''.join(t.text or '' for t in c.findall('.//w:t', W))
                    for c in ET.fromstring(archive.read('word/comments.xml')).findall('w:comment', W)}
    for key, (number, exact) in PARAGRAPHS.items():
        group = 'skills' if key == 'E1' else 'hexes'
        entry = hero[group][key]
        para = paragraphs[number - 1]
        text = ''.join(t.text or '' for t in para.findall('.//w:t', W))
        prefix = '' if key == 'E1' else key + '｜' + entry['name'] + '　'
        check(text == exact == prefix + entry['template'], key + ' original literal paragraph')
        check(entry['source']['paragraph_all_body_descendants'] == number, key + ' original paragraph address')
        check(family['records'][key]['original_full_paragraph'] == exact, key + ' family paragraph contract')
        check(family['records'][key]['source_definition'] == entry, key + ' imported definition exactly retained')
        ids = sorted({n.attrib['{' + W['w'] + '}id'] for n in para.findall('.//w:commentReference', W)})
        check(ids == entry['comment_ids'], key + ' original comment identity')
        check({cid: comments[cid] for cid in ids} == family['records'][key]['original_comments'], key + ' original comment text')
        if key != 'E1':
            check(entry['skill_dependencies'] == ['E1'] and entry['requires'] == 'E1', key + ' exact parent dependency')
            check(entry['required_hooks'] == ['hex.final_design.yanguizhou_' + key.lower() + '.v1'], key + ' exact hook identity')
    check(list(hero['skills']['E1']['parameters']) == [r[0] for r in E1_ROWS], 'ten and only ten E1 parameters')
    check(not hero['hexes']['H07']['parameters'], 'H07 has no invented numeric parameter')
    check(list(hero['hexes']['H08']['parameters']) == ['H08-1'], 'H08 exact parameter identity')
    cells = workbook_cells(path_at(R, XLSX))
    parameters = []
    numeric_count = 0
    numeric_rows = [('E1', '晏归舟技能', row, 'EFGHIJ') for row in E1_ROWS]
    numeric_rows.append(('H08', '专属海克斯', ('H08-1', 51, '进入烟雨无伤持续', '秒', [1]), 'F'))
    for key, sheet, (token, row, label, unit, expected), columns in numeric_rows:
        group = 'skills' if key == 'E1' else 'hexes'
        parameter = hero[group][key]['parameters'][token]
        addresses = [col + str(row) for col in columns]
        token_col = 'A' if key == 'E1' else 'C'
        check(cells[sheet][token_col + str(row)]['value'] == '[' + token + ']', token + ' original token cell')
        values = []
        for address in addresses:
            cell = cells[sheet][address]
            check(not cell['formula'] and isinstance(cell['value'], (int, float)) and not isinstance(cell['value'], bool),
                  token + ' literal numeric cell ' + sheet + '!' + address)
            values.append(cell['value'])
        check(values == expected == parameter['values'], token + ' every rank equals original and literal oracle')
        check(parameter['source']['sheet'] == sheet and parameter['source']['row'] == row and parameter['source']['cells'] == addresses,
              token + ' exact workbook address')
        check(parameter['label'] == label and parameter['unit'] == unit and parameter['rank_count'] == len(expected),
              token + ' exact label/unit/rank count')
        check(parameter['overrides'] == [], token + ' no numeric override')
        direct = {'token': token, 'sheet': sheet, 'row': row, 'cells': addresses, 'values': values}
        check(direct in family['records'][key]['direct_numeric_oracle'], token + ' family direct oracle agrees')
        parameters.append(direct)
        numeric_count += len(values)
    check(len(parameters) == 11 and numeric_count == 61, 'exact eleven parameter IDs and sixty-one numeric cells')
    for key in ['H07', 'H08']:
        for row in family['records'][key]['original_workbook_rows']:
            check({a: cells['专属海克斯'].get(a, {}).get('value') for a in row['source']['cells']} == row['values'],
                  key + ' complete original workbook row')
    check(cells['专属海克斯']['F50']['value'] is None and not cells['专属海克斯']['F50']['formula'], 'H07 original value remains empty')
    check(cells['规则待确认']['D20']['value'] == '未增加正文之外的控制免疫、次数上限或Boss免伤；仍需实机验证组合强度。',
          'no unsourced control immunity, caps or Boss protection')
    for sheet, expected_cells in family['original_workbook_global_rows'].items():
        for address, expected in expected_cells.items():
            check(cells[sheet][address] == expected, 'original workbook global convention ' + sheet + '!' + address)
    for row in family['original_rule_rows']:
        check([cells[row['source']['sheet']][a]['value'] for a in row['source']['cells']] ==
              [row[k] for k in ['subject', 'topic', 'question', 'source_handling']], 'original rule row ' + str(row['source']['row']))
    resolutions = load('data/final_design/effective_rule_resolutions.json')['resolutions']
    for expected in family['effective_decisions']:
        found = [x for x in resolutions if x['id'] == expected['id']]
        check(found == [expected], 'effective decision retained exactly: ' + expected['id'])
        check(expected['authority']['user_message_id'] == 'Sentinel_4287cd498e008191a0e0d57ccbcd1b9c'
              and expected['authority']['user_quote'] == '1.可以。2.后者', 'exact E1/P1 approval provenance')
        if expected['id'] == 'yanguizhou_e1_reform_radius_marks':
            check(expected['rules'] == E1_RULES, 'approved final radius and cast-wide cleanup exact rules')
    check(load('data/final_design/effective_overrides.json').get('heroes', {}).get('yanguizhou', {}) == {}, 'no effective Ink numeric override')
    check(load(FAMILY + 'implementation_contract.json') == family['implementation_contract'], 'exact family implementation contract')

    # Local candidate identity is intentionally separate from host admission.
    local = json.loads((D / 'source_binding.json').read_text())
    runtime = json.loads((D / 'runtime_binding.json').read_text())
    own = own_source_files()
    check(local['own_files'] == own, 'exact complete own-source inventory')
    check(local['upstream'] == PINS, 'only explicitly pinned upstream identities')
    for rel, digest in local['upstream'].items():
        check(sha(path_at(R, rel)) == digest, 'candidate upstream identity: ' + rel)
    combined = dict(current['runtime_map'])
    combined.update(FIXTURE_MAP)
    combined.update({rel: {'source': rel, 'sha256': digest} for rel, digest in own.items()})
    check(local['runtime_map'] == combined == runtime['runtime_map'], 'stage map is exact current chain plus pinned read-only fixtures and own directory')
    check(local.get('read_only_fixture_map') == FIXTURE_MAP == runtime.get('read_only_fixture_map'), 'explicit read-only fixture inventory has no capability semantics')
    check(local['runtime_binding_sha256'] == sha(D / 'runtime_binding.json'), 'candidate runtime-map identity')
    check(runtime['runtime_candidates'] == current['runtime_candidates'] and
          runtime['source_implemented_hooks'] == current['source_implemented_hooks'], 'local stage cannot widen host skill/hook admission')
    check(runtime['candidate_mechanics'] == ['E1', 'H07', 'H08'], 'only isolated E1/H07/H08 mechanics candidate')
    check(runtime['host_capabilities_added'] == [] and runtime['production_promotion'] is False,
          'no host capabilities or production promotion')
    for rel, digest in own.items():
        path = path_at(R, rel)
        check(sha(path) == digest, 'own source identity: ' + rel)
        if path.suffix == '.py':
            ast.parse(path.read_text(encoding='utf-8'), filename=rel)
            check(True, 'Python syntax only: ' + rel)
        if path.suffix in {'.gd', '.gdshader', '.tscn', '.tres'}:
            for dependency in re.findall(r'res://([^"\s]+)', path.read_text(encoding='utf-8')):
                path_at(R, dependency)
                if dependency.endswith('_result.json'):
                    check(dependency.startswith(D.relative_to(R).as_posix() + '/'), 'output path confined to new directory')
                    continue
                check(dependency in combined or dependency in {(D / n).relative_to(R).as_posix() for n in BINDING_NAMES},
                      'exact mapped dependency: ' + dependency)
    check(before == {rel: sha(path_at(R, rel)) for rel in before}, 'all protected input bytes unchanged after source audit')
    return {'schema_version': 1, 'status': 'SOURCE_ONLY_PASS', 'passed': True,
            'scope': 'original OOXML, exact effective rules, protected mapped-source identity and local source binding only',
            'counts': {'original_paragraphs': 3, 'parameter_ids': 11, 'numeric_cells': 61,
                       'current_q1_q3_mapped_files': 214, 'current_host_mapped_files': 524, 'read_only_fixture_dependencies': len(FIXTURE_MAP),
                       'protected_files': len(before), 'own_files': len(own)},
            'source_binding_sha256': sha(D / 'source_binding.json'),
            'runtime_binding_sha256': sha(D / 'runtime_binding.json'),
            'original_parameters': parameters, 'checks': checks,
            'Godot_parse': 'NOT_RUN', 'engine': 'NOT_RUN', 'runtime': 'NOT_RUN',
            'native_input': 'NOT_RUN', 'visual': 'NOT_RUN', 'audio': 'NOT_RUN',
            'whole_hero_acceptance': 'NOT_RUN',
            'limitations': {'ordinary_enemy_only_phasing': 'NOT_PASSED_PENDING_TECHNICAL_REVIEW'},
            'full_E1_acceptance': False, 'host_capabilities_added': [], 'production_promotion': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='record source-only outcome in this candidate directory')
    args = parser.parse_args()
    try:
        result = audit()
    except Exception as error:
        result = {'schema_version': 1, 'status': 'SOURCE_ONLY_FAIL', 'passed': False,
                  'error': type(error).__name__ + ': ' + str(error),
                  'Godot_parse': 'NOT_RUN', 'engine': 'NOT_RUN', 'runtime': 'NOT_RUN',
                  'native_input': 'NOT_RUN', 'host_capabilities_added': [], 'production_promotion': False}
        if args.write:
            (D / 'source_result.json').write_text(encode(result), encoding='utf-8')
        print(encode(result), end='')
        return 1
    if args.write:
        (D / 'source_result.json').write_text(encode(result), encoding='utf-8')
    print(encode({k: v for k, v in result.items() if k not in {'checks', 'original_parameters'}}), end='')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
