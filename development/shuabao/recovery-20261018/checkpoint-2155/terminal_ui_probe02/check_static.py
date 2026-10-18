from pathlib import Path
import ast
import difflib
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
SOURCE = ROOT / 'worldfx_ui_source01/source/game'
UPSTREAM = ROOT / 'terminal_ui_upstream/full_floor07'
CANDIDATE = ROOT / 'terminal_ui_candidate01'
PAYLOAD = HERE / 'payload'
checks = []

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def check(label, passed):
    checks.append({'check': label, 'accepted': bool(passed)})
    assert passed, label

pins = json.loads((ROOT / 'worldfx_ui_source01/SOURCE_PINS.json').read_text())
actual = {str(p.relative_to(SOURCE)): digest(p) for p in SOURCE.rglob('*') if p.is_file()}
check('actual_3046_parent_is_exact', actual == pins and len(actual) == 3046)
expected = json.loads((CANDIDATE / 'SOURCE_PINS.expected.json').read_text())
virtual = dict(pins)
for row in json.loads((CANDIDATE / 'MANIFEST.json').read_text())['payload']:
    p = CANDIDATE / row['payload']
    check('candidate_payload_' + row['target'], digest(p) == row['sha256'] and p.stat().st_size == row['bytes'])
    virtual[row['target'][6:]] = digest(p)
check('virtual_candidate_matches_recovered_3047_inventory', virtual == expected and len(virtual) == 3047)
check('only_presenter_changes_on_world_parent', [k for k in pins if pins[k] != virtual.get(k)] == ['yan_trial_ui_20261018/presenter.gd'])
check('only_summary_added_on_world_parent', [k for k in virtual if k not in pins] == ['yan_trial_ui_20261018/result_summary.gd'])
binding_file = PAYLOAD / 'yan_terminal_full_floor_20261018c/binding.json'
binding = json.loads(binding_file.read_text())
bound = {'res://' + k: v for k, v in expected.items()}
for rel in ['yan_terminal_full_floor_20261018c/driver.gd', 'yan_terminal_ui_probe_20261018/probe.gd']:
    bound['res://' + rel] = digest(PAYLOAD / rel)
check('binding_exact_3047_production_plus_two_helpers', binding['files'] == dict(sorted(bound.items())) and len(bound) == 3049)
check('binding_names_exact_candidate_inventory', binding['source_inventory_sha256'] == digest(CANDIDATE / 'SOURCE_PINS.expected.json'))
runner = (PAYLOAD / 'yan_terminal_full_floor_20261018c/runner.gd').read_text()
old = (UPSTREAM / 'runner.gd').read_text()
check('runner_names_exact_binding', f'const BINDING_SHA = "{digest(binding_file)}"' in runner)
check('route_driver_is_exact', digest(PAYLOAD / 'yan_terminal_full_floor_20261018c/driver.gd') == 'f1129fb1fa57305f938af3685759674b3731500e687d95a2fd75f19d41eaec29')
check('passive_summary_helper_is_exact', digest(PAYLOAD / 'yan_terminal_ui_probe_20261018/probe.gd') == 'cef056ef326b307604bf1ba1d45a07b42554b5f411649e2e476ae7f7e083234a')
check('upstream_runner_is_exact', digest(UPSTREAM / 'runner.gd') == 'efa0a30b681051fdad434a953f68d8ec18edc89b185573402fdfa5f0bcd1f881')

def functions(text):
    matches = list(re.finditer(r'^func (\w+)\(', text, re.M))
    return {m[1]: text[m.start():matches[i + 1].start() if i + 1 < len(matches) else len(text)].strip() for i, m in enumerate(matches)}

before, after = functions(old), functions(runner)
changed_allowed = {'_initialize', '_hex', '_run', '_finish', '_completed_ui', '_hero_cancel', '_full_route', '_next_node'}
for name, body in before.items():
    if name not in changed_allowed:
        check('preserved_original_function_' + name, after.get(name) == body)
# _next_node is the old final function: comments for new functions follow it.
check('original_next_node_body_retained', after['_next_node'].startswith(before['_next_node']))
check('only_three_new_fixture_functions', set(after) - set(before) == {'_summary_check', '_summary_roundtrip', '_natural_defeat'})
check('actual_thin_entry_script_required', 'actual_thin_entry_required' in runner)
check('final_hex_yield_is_required_not_optional', 'if coverage.last_hex_summary_yield!="PASS"' in runner)
check('original_async_hex_receipt_checks_retained', 'receipt.request.get("milestone",-1)==milestone' in runner and 'view.choosing' in after['_hex'])
check('original_completed_12_rows_and_pending_checks_retained', 'ui.pending.is_empty() and not ui.hex_visible' in after['_completed_ui'] and 'ui.rows==12' in after['_completed_ui'] and 'ui.next_disabled' in after['_completed_ui'])
check('shop_uses_original_shortcut', 'host._input(event)' in after['_summary_roundtrip'] and 'host._input(release)' in after['_summary_roundtrip'])
check('defeat_mode_has_no_combat_driver_advancement', 'advance_inputs' not in after['_natural_defeat'])
check('defeat_requires_real_source_terminal', 'session.status=="defeated" and sim.phase=="true_dead" and hero.dead' in after['_natural_defeat'])
check('final_success_requires_unfired_watchdog_and_budget', 'if watchdog_fired or finishing: return' in after['_run'] and 'deadline_before_terminal_coverage' in after['_run'])
check('no_added_gameplay_state_assignment', re.search(r'(?:hero\.(?:hp|position|dead)|sim\.(?:hero_time|phase|paused)|model\.state|session\.(?:status|settlement))\s*=(?!=)', '\n'.join(after[n] for n in set(after) - set(before))) is None)
check('actual_original_P_shortcut_present', 'if key == KEY_P: _shop(not shop_session.panel_open)' in (SOURCE / 'tests/ink_first_floor_user_route_20261005/runtime01/host.gd').read_text())
check('actual_original_chooser_hides_CanvasLayers', 'if node is CanvasLayer:' in (SOURCE / 'scripts/integration/hero_entry.gd').read_text())
ast.parse((HERE / 'build_runner.py').read_text())
check('build_script_python_syntax', True)
diff = ''.join(difflib.unified_diff(old.splitlines(True), runner.splitlines(True), fromfile='full_floor07/runner.gd', tofile='terminal_ui_probe02/runner.gd'))
(HERE / 'RUNNER_DELTA_FROM_FULL_FLOOR07.diff').write_text(diff)
result = {'status': 'STATIC_BYTES_AND_CONTRACT_CHECKS_ONLY', 'accepted': all(c['accepted'] for c in checks), 'checks': checks, 'production_candidate_applied': False, 'GDScript_parse': 'NOT_RUN', 'engine': 'NOT_RUN', 'art_acceptance': 'NOT_REVIEWED'}
(HERE / 'STATIC_CHECKS.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'accepted': result['accepted'], 'checks': len(checks)}, ensure_ascii=False))
