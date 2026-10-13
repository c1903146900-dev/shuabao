#!/usr/bin/env python3
"""Read-only r09 preparation checks. Does not launch or parse with Godot."""
from pathlib import Path
import ast
import hashlib
import json
import re
import sys

HERE = Path(__file__).resolve().parent
BASE = HERE.parent
OLD = BASE / 'natural_route_r06_prepare'
checks = []

def check(value, name, detail=None):
    checks.append({'passed': bool(value), 'label': name, 'detail': detail})

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def functions(text):
    return dict(re.findall(r'^func (\w+)\([^\n]*\n(.*?)(?=^func |\Z)', text, re.M | re.S))

def stripped(text):
    """Remove comments/strings and check paired delimiters; not a GD parser."""
    out, stack = [], []
    quote = None
    comment = False
    escape = False
    matches = {')': '(', ']': '[', '}': '{'}
    for c in text:
        if comment:
            if c == '\n': comment = False; out.append(c)
            else: out.append(' ')
            continue
        if quote:
            if escape: escape = False
            elif c == '\\': escape = True
            elif c == quote: quote = None
            out.append('\n' if c == '\n' else ' ')
            continue
        if c == '#': comment = True; out.append(' ')
        elif c in ('"', "'"): quote = c; out.append(' ')
        else:
            out.append(c)
            if c in '([{': stack.append(c)
            elif c in ')]}':
                if not stack or stack.pop() != matches[c]: return ''.join(out), False
    return ''.join(out), not stack and quote is None

m = (HERE / 'natural_route_r09.gd').read_text()
d = (HERE / 'visible_route_r09.gd').read_text()
om = (OLD / 'natural_route_r06.gd').read_text()
od = (OLD / 'visible_route_r06.gd').read_text()
check(sha(OLD / 'natural_route_r06.gd') == '69aa48269d746c4321a10053d2aa4ba02eab39242292f472bf31b3eb001d845e', 'exact verified r06 observer baseline')
check(sha(OLD / 'visible_route_r06.gd') == '20441c2960f5f2d1edaddc888f86a78dba65ad26142a352cd9c430d0bd97f34f', 'exact verified safe-step04 r06 driver baseline')
check(d == od.replace('"service" if row in [3,4,6] else "combat"', '"service" if row in [3,4,6,9] else "combat"'), 'driver has only the r09 service-status extension')
old_funcs, new_funcs = functions(om), functions(m)
unchanged = [name for name in old_funcs if name not in ('finish', 'run')]
check(all(old_funcs[name] == new_funcs.get(name) for name in unchanged), 'all inherited observer functions except run/finish remain byte-for-byte identical', unchanged)
check(set(new_funcs) - set(old_funcs) == {'upgrade_after_original_row', 'potion_course_summary', 'verify_r09_success'}, 'only three new observer/helper functions')
protected = json.loads((HERE / 'protected_baseline.json').read_text())
changed = [path for path, expected in protected.items() if not Path(path).is_file() or sha(Path(path)) != expected]
check(not changed, 'protected first-room, r03, r06, route and source-binding files unchanged', changed)
binding_path = BASE / 'visual_rework_20261009/binding/source_binding.json'
check(sha(binding_path) == 'da26defba5cbdcf2ca2b0a7e51d03ed0345f2525336d3543598df5090c001360', 'exact sealed production source binding')
binding = json.loads(binding_path.read_text())
bad = []
for path, expected in binding['runtime_map'].items():
    target = BASE / path.removeprefix('res://')
    if not target.is_file() or sha(target) != expected: bad.append(path)
check(not bad, 'all sealed production runtime-map paths match', {'count': len(binding['runtime_map']), 'mismatches': bad})
route = json.loads((BASE / 'tests/ink_first_floor_user_route_20261005/runtime01/first_floor.json').read_text())
nodes = ast.literal_eval(re.search(r'^const ROUTE_NODES := (.+)$', m, re.M).group(1))
rosters = ast.literal_eval(re.search(r'^const EXPECTED_ROSTERS := (.+)$', m, re.M).group(1))
check(nodes == [f'r{i:02d}a' for i in range(1, 10)], 'only original connected r01a through r09a')
actual_rosters, service_rows = {}, []
connected = True
for i, node_id in enumerate(nodes):
    row = route['rows'][i]
    node = next(n for n in row['nodes'] if n['id'] == node_id)
    payload = route['payloads'][node['payload_ref']]
    if i < len(nodes) - 1: connected = connected and nodes[i+1] in node['next']
    if payload['node_type'] == 'combat': actual_rosters[i+1] = sorted(e['kind'] for e in payload['roster'])
    else: service_rows.append(i+1)
check(connected, 'all eight transitions are original authored route edges')
check(rosters == actual_rosters, 'all five expected rosters match the original route', actual_rosters)
check(service_rows == [3, 4, 6, 9], 'service statuses match original route payloads')
check('const WALL_MS := 100000' in m and m.count('started_ms=Time.get_ticks_msec()') == 1 and 'started_ms+WALL_MS' in m and 'int(state.wall_elapsed_ms)<WALL_MS' in m, 'single unchanged100-second observer deadline, including final observation')
check('const INPUT_INTERVAL_MS := 120' in d, 'unchanged120ms input interval')
check('r06_verified=verify_r06_success(r06_observation)' in m and m.index('r06_verified=verify_r06_success(r06_observation)') < m.index('await upgrade_after_original_row(6,3)'), 'original r06 success gate precedes any new action')
check('await upgrade_after_original_row(7,4)' in m and '"upgraded":result.get("upgraded",false)' in m and '"SP_before":before.model_state.points' in m and '"SP_after":after.model_state.points' in m, 'later optional upgrade retains actual outcome/rank/SP')
check('var required: Dictionary=await driver.resolve_visible_required_hexes()' in new_funcs['upgrade_after_original_row'] and new_funcs['upgrade_after_original_row'].index('resolve_visible_required_hexes') < new_funcs['upgrade_after_original_row'].index('upgrade_earned_Q1_once'), 'later earned upgrade follows original required visible-Hex resolution')
check('"last_observed_active"' in m and '"terminal_actual_exposed"]=false' in m and '"inferred_heal_total":false' in m, 'potion course retains actual/left and discloses absent terminal total')
check('rewards.size()==20 and kill_count()==20' in m and 'combat_rows==[1,2,5,7,8]' in m and 'settlements.size()==2' in m and 'rows.size()==9' in m, 'five scoped combat records and exact r09 service evidence required')
check('"full_floor_victory":false' in m and '"native_input":false' in m and '"checkpoint_state_restored":false' in m, 'scope and provenance remain explicit')
for name, code in [('observer', m), ('driver', d)]:
    clean, balanced = stripped(code)
    check(balanced, f'{name}: balanced delimiters and closed strings (not engine syntax validation)')
    forbidden_calls = re.findall(r'\.(?:step|damage|damage_enemy|heal|heal_actor|use_potion|accept_committed_event|restore|restore_state|update_held_basic|training_pay|training_select|set_seed)\s*\(', clean)
    check(not forbidden_calls, f'{name}: no extra tick/damage/heal/potion/training/restore direct calls', forbidden_calls)
    writes = re.findall(r'\b(?:host\.)?(?:sim|session|model)\.[\w.\[\]]+\s*(?:=(?!=)|\+=|-=|\*=|/=)', clean)
    check(not writes, f'{name}: no direct gameplay-authority state assignments', writes)
    check(not re.search(r'\b(?:seed|randomize|randi|randf)\s*\(', clean), f'{name}: no RNG control')
clean_driver, _ = stripped(d)
check(not re.search(r'\b(?:enemies|living|enemy_by_id)\b', clean_driver), 'driver never reads hidden source enemy lists or actors')
check(functions(d)['prepare_first_room'] == functions(od)['prepare_first_room'], 'first-room input sequence unchanged')
result = {'passed': all(x['passed'] for x in checks), 'checks': checks, 'engine_started': False, 'engine_parser_run': False, 'production_runtime_map_count': len(binding['runtime_map'])}
print(json.dumps(result, indent=2, ensure_ascii=False))
sys.exit(0 if result['passed'] else 1)
